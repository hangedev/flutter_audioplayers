/**
 * Copyright (c) 2024 Hunan OpenValley Digital Industry Development Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import {
  FlutterPlugin,
  FlutterPluginBinding
} from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import MethodChannel, { MethodResult, } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import { EventSink, StreamHandler } from '@ohos/flutter_ohos/src/main/ets/plugin/common/EventChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import { AbilityAware, AbilityPluginBinding, BinaryMessenger, EventChannel, Log } from '@ohos/flutter_ohos';
import { HashMap } from '@kit.ArkTS';
import AudioContextOhos from './AudioContextOhos';
import { SoundPoolManager } from './player/SoundPoolPlayer';
import WrappedPlayer from './player/WrappedPlayer';
import FocusManager from './player/FocusManager';
import audio from '@ohos.multimedia.audio';
import UrlSource from './source/UrlSource';
import BytesSource from './source/BytesSource';
import { parseReleaseMode } from './ReleaseMode';
import { parsePlayerMode } from './PlayerMode';
import { WantAgent, wantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { avSession as AVSessionManager } from '@kit.AVSessionKit';

const TAG = 'AudioplayersPlugin';

export default class AudioplayersPlugin implements FlutterPlugin, AbilityAware, IUpdateCallback {
  private methods?: MethodChannel = undefined;
  private globalMethods?: MethodChannel = undefined;
  private globalEvents?: EventHandler = undefined;
  private context?: Context = undefined;
  private binaryMessenger?: BinaryMessenger = undefined;
  private soundPoolManager?: SoundPoolManager = undefined;
  private players = new HashMap<string, WrappedPlayer>();
  private defaultAudioContext = new AudioContextOhos();
  private updateInterval: number | null = null;
  private abilityBinding?: AbilityPluginBinding = undefined;
  private session?: AVSessionManager.AVSession = undefined;
  private isStartContinuousTask = false;
  // 用于取消进行中的 start/stop 后台任务，避免 AVSession 竞态泄漏
  private continuousTaskEpoch: number = 0;
  private detachEpoch: number = 0;
  private static readonly MAX_PLAYERS: number = 32;

  getUniqueClassName(): string {
    return 'AudioplayersPlugin'
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.detachEpoch++
    const epoch = this.detachEpoch
    // 同步先解除 MethodChannel handler，避免卸载期间再收到新的方法调用
    this.methods?.setMethodCallHandler(null)
    this.globalMethods?.setMethodCallHandler(null)
    // 异步完整卸载：先停后台任务/销毁 AVSession，再释放播放器，避免竞态
    this.detachFromEngineAsync(epoch).catch((e: Error) => {
      Log.e(TAG, `detachFromEngineAsync failed: ${e.message}`)
    })
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.detachEpoch++
    this.context = binding.getApplicationContext()
    this.binaryMessenger = binding.getBinaryMessenger()
    this.soundPoolManager = new SoundPoolManager(this)
    this.methods = new MethodChannel(binding.getBinaryMessenger(), 'xyz.luan/audioplayers')
    this.methods.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult) => {
        this.methodCall(call, result)
      }
    })
    this.globalMethods = new MethodChannel(binding.getBinaryMessenger(), 'xyz.luan/audioplayers.global')
    this.globalMethods.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult) => {
        this.globalMethodCall(call, result)
      }
    })
    this.globalEvents = new EventHandler(new EventChannel(binding.getBinaryMessenger(), 'xyz.luan/audioplayers.global/events'))
    // FocusManager 是进程级单例，重新绑定引擎时需重新订阅音频焦点事件
    FocusManager.getInstance().init()
  }

  private async detachFromEngineAsync(epoch: number): Promise<void> {
    this.stopUpdates()
    try {
      await this.stopContinuousTask()
    } catch (e) {
      Log.e(TAG, `stopContinuousTask on detach failed: ${(e as Error).message}`)
    }
    if (epoch != this.detachEpoch) {
      Log.d(TAG, 'detachFromEngineAsync aborted: engine re-attached')
      return
    }
    const playerIds: string[] = []
    this.players.forEach((_value: WrappedPlayer, key: string) => {
      playerIds.push(key)
    })
    for (let i = 0; i < playerIds.length; i++) {
      if (epoch != this.detachEpoch) {
        return
      }
      const player = this.players.get(playerIds[i])
      if (player != null) {
        try {
          await player.dispose()
        } catch (e) {
          Log.e(TAG, `dispose player ${playerIds[i]} failed: ${(e as Error).message}`)
        }
      }
    }
    if (epoch != this.detachEpoch) {
      return
    }
    this.players.clear()
    this.soundPoolManager?.dispose()
    this.soundPoolManager = undefined
    this.globalEvents?.dispose()
    this.globalEvents = undefined
    FocusManager.getInstance().dispose()
    this.methods?.setMethodCallHandler(null)
    this.globalMethods?.setMethodCallHandler(null)
    this.methods = undefined
    this.globalMethods = undefined
    this.context = undefined
    this.binaryMessenger = undefined
    this.session = undefined
    this.defaultAudioContext = new AudioContextOhos()
  }

  private async globalMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      switch (call.method) {
        case 'init': {
          const ids: string[] = []
          this.players.forEach((_value: WrappedPlayer, key: string) => {
            ids.push(key)
          })
          for (let i = 0; i < ids.length; i++) {
            const p = this.players.get(ids[i])
            if (p != null) {
              try {
                await p.dispose()
              } catch (e) {
                Log.e(TAG, `init dispose ${ids[i]} failed: ${(e as Error).message}`)
              }
            }
          }
          this.players.clear()
          await this.stopContinuousTask()
          break;
        }
        case 'setAudioContext':
          this.defaultAudioContext = this.getAudioContext(call)
          // OHOS 无完整 AudioManager.mode / isSpeakerphoneOn 等价 API，尽量应用扬声器路由
          this.applyGlobalAudioContext(this.defaultAudioContext)
          break;
        case 'emitLog':
          let message = this.getObjectValue(call, 'message', 'message is required') as string;
          this.handleGlobalLog(message);
          break;
        case 'emitError':
          let code = this.getObjectValue(call, 'code', 'code is required') as string;
          message = this.getObjectValue(call, 'message', 'message is required') as string;
          this.handleGlobalError(code, message, null)
          break;
        default:
          result.notImplemented()
          return;
      }
      result.success(1)
    } catch (e) {
      Log.e(TAG, `globalMethodCall error: ${e.message}`)
      result.error('OhosAudioError', e.message, e)
    }
  }

  /**
   * 将全局 AudioContext 尽量落到系统音频路由。
   * OHOS 缺少 Android 同款 AudioManager.mode，通过 AudioSessionManager 设置默认输出设备。
   */
  private applyGlobalAudioContext(ctx: AudioContextOhos): void {
    try {
      const sessionManager = this.getAudioManager().getSessionManager()
      const deviceType = ctx.isSpeakerphoneOn ? audio.DeviceType.SPEAKER : audio.DeviceType.EARPIECE
      sessionManager.setDefaultOutputDevice(deviceType).then(() => {
        Log.d(TAG, `setDefaultOutputDevice ${deviceType} ok`)
      }).catch((err: BusinessError) => {
        Log.e(TAG, `setDefaultOutputDevice failed: ${err.code} ${err.message}`)
      })
    } catch (e) {
      Log.e(TAG, `applyGlobalAudioContext error: ${(e as Error).message}`)
    }
  }

  private getMimeType(url: string): string {
      const extension = url.split('.').pop()?.toLowerCase();
      const mimeTypes: Record<string, string> = {
          'mp3': 'audio/mpeg',
          'wav': 'audio/wav',
          'ogg': 'audio/ogg',
          'mp4': 'video/mp4',
          'avi': 'video/x-msvideo',
          'txt': 'text/plain',  // txt 不是媒体文件
      };
      return mimeTypes[extension || ''] || 'application/octet-stream';
  }

  private async methodCall(call: MethodCall, response: MethodResult) {
    let playerId = call.argument('playerId') as string
    if (playerId == null || playerId == undefined) {
      response.success(1)
      return;
    }
    try {
      if (call.method == 'create') {
        if (this.players.length >= AudioplayersPlugin.MAX_PLAYERS) {
          response.error('OhosAudioError', `player limit reached (${AudioplayersPlugin.MAX_PLAYERS})`, null)
          return;
        }
        let eventHandler = new EventHandler(new EventChannel(this.binaryMessenger!, `xyz.luan/audioplayers/events/${playerId}`))
        this.players.set(playerId, new WrappedPlayer(this, eventHandler, this.defaultAudioContext.copy(), this.soundPoolManager!))
        response.success(1);
        return;
      }
      let player = this.getPlayer(playerId)
      if (player == null) {
        response.error('OhosAudioError', 'not find player', Error('not find player'))
        return;
      }
      switch (call.method) {
        case 'setSourceUrl':
          let url = this.getObjectValue(call, 'url', 'url is required') as string;
          // 基础 URL 校验：非空且不含空白字符，避免无效 URL 传入 AVPlayer 导致不可预期错误
          if (url == null || url.trim().length == 0 || /\s/.test(url)) {
            response.error('OhosAudioError', 'url must be a non-empty string without whitespace', null)
            return;
          }
          let isLocal = call.hasArgument('isLocal') ? (call.argument('isLocal') as boolean) : false;
          let mimeTypeArg = call.hasArgument('mimeType') ? (call.argument('mimeType') as string) : undefined;
          const mimeType = (mimeTypeArg && mimeTypeArg.length > 0) ? mimeTypeArg : this.getMimeType(url);
          Log.d(TAG, `Detected MIME type: ${mimeType}`);
          if (mimeType.startsWith('text/')) {
              // 必须 response.error：仅 handleError 会让 MethodChannel 挂起，Dart 等不到失败结果
              const msg =
                'Failed to set source: text/* is not a playable audio type. For troubleshooting, https://github.com/bluefireteam/audioplayers/blob/main/troubleshooting.md';
              player.handleError('AudioError', msg, null)
              response.error('AudioError', msg, null)
              return;
          }
          await player!.setSource(new UrlSource(url, isLocal, mimeType));
          break;
        case 'setSourceBytes':
          let bytes = this.getObjectValue(call, 'bytes', 'bytes are required') as ArrayBuffer
          if (bytes == null || bytes.byteLength === 0) {
            response.error('OhosAudioError', 'bytes must be a non-empty ArrayBuffer', null)
            return;
          }
          let bytesMime = call.hasArgument('mimeType') ? (call.argument('mimeType') as string) : undefined;
          await player.setSource(new BytesSource(bytes, bytesMime));
          break;
        case 'resume':
          await this.startContinuousTask();
          player.play();
          break;
        case 'pause':
          player.pause();
          await this.stopContinuousTask();
          break;
        case 'stop':
          await player.stop();
          await this.stopContinuousTask();
          break;
        case 'release':
          await player.release();
          await this.stopContinuousTask();
          break;
        case 'seek':
          let position = this.getObjectValue(call, 'position', 'position is required') as number;
          if (!this.isFiniteNumber(position) || position < 0) {
            response.error('OhosAudioError', 'position must be a non-negative number', null)
            return;
          }
          player.seek(position);
          break;
        case 'setVolume':
          let volume = this.getObjectValue(call, 'volume', 'volume is required') as number;
          player.setVolume(this.clamp(volume, 0.0, 1.0));
          break;
        case 'setBalance':
          let balance = this.getObjectValue(call, 'balance', 'balance is required') as number;
          player.setBalance(this.clamp(balance, -1.0, 1.0));
          break;
        case 'setPlaybackRate':
          let rate = this.getObjectValue(call, 'playbackRate', 'playbackRate is required') as number;
          if (!this.isFiniteNumber(rate) || rate <= 0) {
            response.error('OhosAudioError', 'playbackRate must be a positive number', null)
            return;
          }
          player.setRate(rate);
          break;
        case 'getDuration':
          // 与 Android/iOS 一致：未知时返回 null，已就绪返回毫秒数（可为 0）
          response.success(player.getDuration());
          return;
        case 'getCurrentPosition':
          response.success(player.getCurrentPosition());
          return;
        case 'setReleaseMode':
          let releaseMode = this.getObjectValue(call, 'releaseMode', 'releaseMode is required') as string
          player.setReleaseMode(parseReleaseMode(releaseMode));
          break;
        case 'setPlayerMode':
          let playerMode = this.getObjectValue(call, 'playerMode', 'playerMode is required') as string
          player.setPlayerMode(parsePlayerMode(playerMode));
          break;
        case 'setAudioContext':
          let audioContext = this.getAudioContext(call);
          player.updateAudioContext(audioContext)
          break;
        case 'emitLog':
          let message = this.getObjectValue(call, 'message', 'message is required') as string
          player.handleLog(message)
          break;
        case 'emitError':
          let code = this.getObjectValue(call, 'code', 'code is required') as string
          message = this.getObjectValue(call, 'message', 'message is required') as string
          player.handleError(code, message, null)
          break;
        case 'dispose':
          await player.dispose()
          this.players.remove(playerId)
          await this.stopContinuousTask();
          break;
        default:
          response.notImplemented()
          return;
      }
      response.success(1)
    } catch (e) {
      response.error('OhosAudioError', e.message, e)
    }
  }

  private getPlayer(playerId: string): WrappedPlayer | null {
    if (this.players.hasKey(playerId)) {
      return this.players.get(playerId)
    }
    this.error('Player has not yet been created or has already been disposed.')
    return null
  }

  getApplicationContext(): Context {
    if (!this.context) {
      throw new Error('Application context is not initialized. Ensure the plugin is attached to the engine.')
    }
    return this.context
  }

  private clamp(value: number, min: number, max: number): number {
    if (!this.isFiniteNumber(value)) {
      return min;
    }
    return Math.min(max, Math.max(min, value));
  }

  private isFiniteNumber(value: number): boolean {
    return Number.isFinite(value);
  }

  getAudioManager(): audio.AudioManager {
    return audio.getAudioManager();
  }

  handleIsPlaying() {
    this.startUpdates()
  }

  handleDuration(player: WrappedPlayer) {
    let map = new Map<string, number>();
    let duration = player.getDuration();
    map.set('value', duration != null ? duration : 0);
    player.eventHandler.success('audio.onDuration', map);
  }

  handleComplete(player: WrappedPlayer) {
    player.eventHandler.success('audio.onComplete');
  }

  handlePrepared(player: WrappedPlayer, isPrepared: boolean) {
    let map = new Map<string, boolean>();
    map.set('value', isPrepared);
    player.eventHandler.success('audio.onPrepared', map);
  }

  handleLog(player: WrappedPlayer, message: string) {
    let map = new Map<string, string>();
    map.set('value', message);
    player.eventHandler.success('audio.onLog', map);
  }

  handleGlobalLog(message: string) {
    if (!this.globalEvents) {
      return;
    }
    let map = new Map<string, string>();
    map.set('value', message);
    this.globalEvents.success('audio.onLog', map);
  }

  handleError(player: WrappedPlayer, errorCode?: string, errorMessage?: string, errorDetails?: ESObject) {
    player.eventHandler.error(errorCode, errorMessage, errorDetails)
  }

  handleGlobalError(errorCode?: string, errorMessage?: string, errorDetails?: ESObject) {
    if (!this.globalEvents) {
      return;
    }
    this.globalEvents.error(errorCode, errorMessage, errorDetails)
  }

  handleSeekComplete(player: WrappedPlayer) {
    let map = new Map<string, number>();
    let position = player.getCurrentPosition();
    map.set('value', position ? position : 0);
    player.eventHandler.success('audio.onSeekComplete')
    player.eventHandler.success('audio.onCurrentPosition', map)
  }

  startUpdates() {
    this.stopUpdates();
    this.updateInterval = setInterval(() => {
      this.updateCallback();
    }, 200)
  }

  stopUpdates() {
    if (this.updateInterval) {
      clearInterval(this.updateInterval)
      this.updateInterval = null
    }
  }

  private updateCallback() {
    let mediaPlayers = this.players;
    let channel = this.methods;
    if (mediaPlayers == null || channel == null) {
      this.stopUpdates()
      return
    }
    let isAnyPlaying = false
    mediaPlayers.forEach((player: WrappedPlayer, key: string) => {
      if (player.isActuallyPlaying()) {
        isAnyPlaying = true
        let time = player.getCurrentPosition()

        let map = new Map<string, number>();
        map.set('value', time ? time : 0);
        player.eventHandler.success('audio.onCurrentPosition', map)
      }
    })
    if (!isAnyPlaying) {
      this.stopUpdates()
    }
  }

  private getAudioContext(call: MethodCall): AudioContextOhos {
    let contextOhos = new AudioContextOhos();
    contextOhos.isSpeakerphoneOn = this.getObjectValue(call, 'isSpeakerphoneOn', 'isSpeakerphoneOn is required') as boolean
    let rendererFlags = this.getObjectValue(call, 'rendererFlags', 'rendererFlags is required') as number
    let usageType = this.getObjectValue(call, 'usageType', 'usageType is required') as number
    let audioScene = this.getObjectValue(call, 'audioScene', 'audioScene is required') as number
    contextOhos.stayAwake = this.getObjectValue(call, 'stayAwake', 'stayAwake is required') as boolean
    let audioFocus = this.getObjectValue(call, 'audioFocus', 'audioFocus is required') as number
    if (!this.isFiniteNumber(rendererFlags) || rendererFlags < 0) {
      throw new Error('rendererFlags must be a non-negative number')
    }
    if (!this.isFiniteNumber(usageType)) {
      throw new Error('usageType must be a finite number')
    }
    if (!this.isFiniteNumber(audioScene)) {
      throw new Error('audioScene must be a finite number')
    }
    if (!this.isFiniteNumber(audioFocus) || audioFocus < 0 || audioFocus > 2) {
      throw new Error('audioFocus must be 0, 1 or 2')
    }
    contextOhos.rendererFlags = rendererFlags
    contextOhos.usageType = usageType
    contextOhos.audioScene = audioScene
    contextOhos.audioFocus = audioFocus
    return contextOhos;
  }

  private getObjectValue(call: MethodCall, key: string, error: string): ESObject {
    if (call.hasArgument(key)) {
      return call.argument(key);
    }
    throw new Error(error);
  }

  private error(msg: string) {
    throw new Error(msg);
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.abilityBinding = binding
  }

  onDetachedFromAbility(): void {
    this.pauseAllPlayers()
    // 先停后台任务（仍持有 abilityBinding），再清空 binding
    this.stopContinuousTask().catch((e: Error) => {
      Log.e(TAG, `stopContinuousTask onDetachedFromAbility failed: ${e.message}`)
    }).then(() => {
      this.abilityBinding = undefined
    })
    // Ability 销毁后释放底层播放器资源，避免系统媒体资源被持续占用
    const playerIds: string[] = []
    this.players.forEach((_value: WrappedPlayer, key: string) => {
      playerIds.push(key)
    })
    for (let i = 0; i < playerIds.length; i++) {
      const player = this.players.get(playerIds[i])
      if (player != null) {
        player.release().catch((e: Error) => {
          Log.e(TAG, `release player ${playerIds[i]} onDetachedFromAbility failed: ${e.message}`)
        })
      }
    }
  }

  pauseOtherPlayers(currentPlayer: WrappedPlayer): void {
    Log.d(TAG, `Pausing other players, current player: ${currentPlayer ? 'valid' : 'null'}`);
    let pausedCount = 0;
    this.players.forEach((player: WrappedPlayer, playerId: string) => {
      if (player !== currentPlayer && player.isPlaying()) {
        player.pause();
        pausedCount++;
        Log.d(TAG, `Paused player ${playerId} due to audio focus change`);
      }
    });
    Log.d(TAG, `Total ${pausedCount} players paused`);
  }

  pauseAllPlayers(): void {
    this.players.forEach((player: WrappedPlayer, playerId: string) => {
      if (player.isPlaying()) {
        player.pause()
      }
    })
  }

  async startContinuousTask() {
    Log.d(TAG, `startContinuousTask`);
    if(this.isStartContinuousTask){
      return;
    }
    if (!this.abilityBinding) {
      Log.e(TAG, 'startContinuousTask: ability binding is not available, skip background task');
      return;
    }
    const epoch = ++this.continuousTaskEpoch

    let context = this.abilityBinding.getAbility().context;
    let type: AVSessionManager.AVSessionType = 'audio';

    try {
      this.session = await AVSessionManager.createAVSession(context, 'audioplayers', type);
      if (epoch != this.continuousTaskEpoch) {
        try {
          await this.session?.deactivate()
          await this.session?.destroy()
        } catch (_) {
          // ignore
        }
        this.session = undefined
        return
      }
      // 激活接口要在元数据、控制命令注册完成之后再执行
      await this.session?.activate();
      Log.d(TAG, `session create done : sessionId : ${this.session?.sessionId}`);
    } catch (error) {
      Log.e(TAG,`session create failed. code is ${(error as BusinessError).code} message is ${(error as BusinessError).message}`);
      this.session = undefined
      // 创建失败时不置 isStartContinuousTask，避免标志与实际状态不一致
      return;
    }

    if (epoch != this.continuousTaskEpoch) {
      try {
        await this.session?.deactivate()
        await this.session?.destroy()
      } catch (_) {
        // ignore
      }
      this.session = undefined
      return
    }

    let wantAgentInfo: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: context?.abilityInfo.bundleName,
          abilityName: context?.abilityInfo.name
        }
      ],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };

    try {
      let wantAgentObj: WantAgent = await wantAgent.getWantAgent(wantAgentInfo);
      await backgroundTaskManager.startBackgroundRunning(context, backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, wantAgentObj);
      if (epoch != this.continuousTaskEpoch) {
        try {
          await backgroundTaskManager.stopBackgroundRunning(context)
          await this.session?.deactivate()
          await this.session?.destroy()
        } catch (_) {
          // ignore
        }
        this.session = undefined
        return
      }
      this.isStartContinuousTask = true;
    } catch (error) {
      Log.e(TAG,`startBackgroundRunning failed. code is ${(error as BusinessError).code} message is ${(error as BusinessError).message}`);
      try {
        await this.session?.deactivate();
        await this.session?.destroy();
      } catch (_) {
        // ignore cleanup errors
      }
      this.session = undefined
    }
  }

  async stopContinuousTask() {
    Log.d(TAG, `stopContinuousTask`);
    // 递增 epoch，使进行中的 startContinuousTask 在 await 后自动清理并退出
    this.continuousTaskEpoch++
    if(!this.isStartContinuousTask && this.session == undefined){
      return;
    }
    this.isStartContinuousTask = false;

    try {
      await this.session?.deactivate();
      await this.session?.destroy();
    } catch (error) {
      Log.e(TAG,`session destroy failed. code is ${(error as BusinessError).code} message is ${(error as BusinessError).message}`);
    }
    this.session = undefined

    try {
      await backgroundTaskManager.stopBackgroundRunning(this.abilityBinding?.getAbility().context);
    } catch (error) {
      Log.e(TAG,`stopBackgroundRunning failed. code is ${(error as BusinessError).code} message is ${(error as BusinessError).message}`);
    }
  }
}

export class EventHandler implements StreamHandler {
  private eventChannel?: EventChannel = undefined;
  private eventSink: EventSink | null = null

  constructor(eventChannel: EventChannel) {
    this.eventChannel = eventChannel;
    this.eventChannel.setStreamHandler(this)
  }

  onListen(args: ESObject, events: EventSink): void {
    this.eventSink = events
  }

  onCancel(args: ESObject): void {
    this.eventSink = null
  }

  success(method: string, args: Map<string, ESObject> = new Map<string, ESObject>()) {
    args.set('event', method)
    this.eventSink?.success(args)
  }

  error(errorCode?: string, errorMessage?: string, errorDetails?: ESObject) {
    this.eventSink?.error(errorCode, errorMessage, errorDetails)
  }

  dispose() {
    if (this.eventSink) {
      this.eventSink.endOfStream();
      this.onCancel(null);
    }
    this.eventChannel?.setStreamHandler(null)
  }
}

interface IUpdateCallback {
  stopUpdates(): void

  startUpdates(): void
}