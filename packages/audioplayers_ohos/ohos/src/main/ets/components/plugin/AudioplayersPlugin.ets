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
import audio from '@ohos.multimedia.audio';
import fs from '@ohos.file.fs';
import UrlSource from './source/UrlSource';
import BytesSource from './source/BytesSource';
import { parseReleaseMode } from './ReleaseMode';
import { parsePlayerMode } from './PlayerMode';
import { WantAgent, wantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { avSession as AVSessionManager } from '@kit.AVSessionKit';

const TAG = 'AudioplayersPlugin';
// players 缓存上限，避免 Flutter 层频繁 create 不 dispose 导致 HashMap 无限增长
const MAX_PLAYERS = 128;

export default class AudioplayersPlugin implements FlutterPlugin, AbilityAware, UpdateCallback {
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

  getUniqueClassName(): string {
    return 'AudioplayersPlugin'
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
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
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    // 停止后台任务，避免 AVSession/长时任务残留导致泄漏
    this.stopContinuousTask()
    this.stopUpdates()
    this.players.forEach((value: WrappedPlayer, key: string) => value.dispose())
    this.players.clear()
    this.soundPoolManager?.dispose()
    this.soundPoolManager = undefined
    this.globalEvents?.dispose()
    this.globalEvents = undefined
    // 清除 MethodChannel handler，避免引擎重新绑定后旧 handler 残留
    this.methods?.setMethodCallHandler(null)
    this.globalMethods?.setMethodCallHandler(null)
    this.methods = undefined
    this.globalMethods = undefined
    this.binaryMessenger = undefined
    this.context = undefined
    this.abilityBinding = undefined
  }

  private globalMethodCall(call: MethodCall, result: MethodResult): void {
    try {
      switch (call.method) {
        case 'setAudioContext':
          // TODO 没有相关API
          //let audioManager = this.getAudioManager()
          //audioManager.mode = defaultAudioContext.audioMode
          //audioManager.isSpeakerphoneOn = defaultAudioContext.isSpeakerphoneOn
          this.defaultAudioContext = this.getAudioContext(call)
          break;
        case 'emitLog': {
          let message = this.getObjectValue(call, 'message', 'message is required') as string;
          this.handleGlobalLog(message);
          break;
        }
        case 'emitError': {
          let code = this.getObjectValue(call, 'code', 'code is required') as string;
          let errMsg = this.getObjectValue(call, 'message', 'message is required') as string;
          this.handleGlobalError(code, errMsg, null)
          break;
        }
        default:
          result.notImplemented()
          return;
      }
      if (call.method !== 'emitError' && call.method !== 'emitLog') {
        result.success(1);
      }
    } catch (e) {
      let errMsg = (e as Error).message ?? String(e);
      result.error(`OhosAudioError.${call.method}`, errMsg, e)
    }
  }

  private async methodCall(call: MethodCall, response: MethodResult) {
    let playerId = call.argument('playerId') as string
    if (playerId == null || playerId == undefined) {
      response.success(1)
      return;
    }
    try {
      if (call.method == 'create') {
        // 超出上限时释放最早创建的播放器，避免缓存无限增长导致内存泄漏
        if (this.players.length >= MAX_PLAYERS) {
          Log.e(TAG, `players cache reached MAX_PLAYERS(${MAX_PLAYERS}), evicting the oldest one`);
          let oldestPlayerId: string | null = null;
          this.players.forEach((value: WrappedPlayer, key: string) => {
            if (oldestPlayerId == null) {
              oldestPlayerId = key;
            }
          });
          if (oldestPlayerId != null) {
            let evicted = this.players.get(oldestPlayerId);
            evicted?.dispose();
            this.players.remove(oldestPlayerId);
          }
        }
        let messenger = this.binaryMessenger;
        let soundPoolManager = this.soundPoolManager;
        if (messenger == null || soundPoolManager == null) {
          response.error('OhosAudioError.create', 'Engine not attached', null);
          return;
        }
        let eventHandler = new EventHandler(new EventChannel(messenger, `xyz.luan/audioplayers/events/${playerId}`))
        this.players.set(playerId, new WrappedPlayer(this, eventHandler, this.defaultAudioContext.copy(), soundPoolManager))
        response.success(1);
        return;
      }
      let player = this.getPlayer(playerId)
      if (player == null) {
        response.error(`OhosAudioError.${call.method}`, 'not find player', Error('not find player'))
        return;
      }
      switch (call.method) {
        case 'setSourceUrl':
          let url = this.getObjectValue(call, 'url', 'url is required') as string;
          let isLocal = call.hasArgument('isLocal') ? (call.argument('isLocal') as boolean) : false;
          // 本地文件源先做存在性预检，与 Android 的 FileNotFoundException 错误消息对齐，
          // 提前给出明确的 'File not found' 而非底层 fd 打开失败的模糊错误
          if (isLocal && !fs.accessSync(url)) {
            throw new Error(`File not found: ${url}`);
          }
          let mimeType = this.getMimeType(url);
          Log.d(TAG, `Detected MIME type: ${mimeType}`);
          if (mimeType.startsWith('text/')) {
            // 必须 response.error：仅 handleError 会让 MethodChannel 挂起，Dart 等不到失败结果
            let msg =
              'Failed to set source: text/* is not a playable audio type. For troubleshooting, https://github.com/bluefireteam/audioplayers/blob/main/troubleshooting.md';
            player.handleError('AudioError', msg, null)
            response.error('AudioError', msg, null)
            return;
          }
          await player!.setSource(new UrlSource(url, isLocal));
          break;
        case 'setSourceBytes':
          let bytes = this.getObjectValue(call, 'bytes', 'bytes are required') as ArrayBuffer
          await player.setSource(new BytesSource(bytes))
          break;
        case 'resume':
          if (player.context.stayAwake) {
            await this.startContinuousTask();
          }
          await player.play();
          break;
        case 'pause':
          await player.pause();
          if (player.context.stayAwake) {
            await this.stopContinuousTask();
          }
          break;
        case 'stop':
          await player.stop();
          break;
        case 'release':
          await player.release();
          break;
        case 'seek':
          let position = this.getObjectValue(call, 'position', 'position is required') as number;
          player.seek(position);
          break;
        case 'setVolume': {
          let volume = this.getObjectValue(call, 'volume', 'volume is required') as number;
          // clamp 到 0~1 范围，避免非法值传入底层
          player.setVolume(this.clampVolume(volume));
          break;
        }
        case 'setBalance': {
          let balance = this.getObjectValue(call, 'balance', 'balance is required') as number;
          // clamp 到 -1~1 范围，避免非法值传入底层
          player.setBalance(this.clampBalance(balance));
          break;
        }
        case 'setPlaybackRate':
          let rate = this.getObjectValue(call, 'playbackRate', 'playbackRate is required') as number;
          player.setRate(rate);
          break;
        case 'getDuration':
          // 保留 null 语义（未知时长），与 Android/iOS 的 int? 返回一致
          response.success(player.getDuration());
          return;
        case 'getCurrentPosition':
          // 保留 null 语义（未知位置），与 Android/iOS 的 int? 返回一致
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
          player.dispose()
          this.players.remove(playerId)
          break;
        default:
          response.notImplemented()
          return;
      }
      response.success(1)
    } catch (e) {
      let errMsg = (e as Error).message ?? String(e);
      // 错误码附带方法名，便于上层区分错误来源（如 setSourceUrl / seek 等）
      response.error(`OhosAudioError.${call.method}`, errMsg, e)
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
    return this.context!
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
    map.set('value', duration ? duration : 0);
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
    let map = new Map<string, string>();
    map.set('value', message);
    this.globalEvents!.success('audio.onLog', map);
  }

  handleError(player: WrappedPlayer, errorCode?: string, errorMessage?: string, errorDetails?: ESObject) {
    player.eventHandler.error(errorCode, errorMessage, errorDetails)
  }

  handleGlobalError(errorCode?: string, errorMessage?: string, errorDetails?: ESObject) {
    this.globalEvents!.error(errorCode, errorMessage, errorDetails)
  }

  handleSeekComplete(player: WrappedPlayer) {
    // 与 Android 实现一致：onSeekComplete 事件不携带参数
    player.eventHandler.success('audio.onSeekComplete')
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
      try {
        // 仅用于判断是否仍有播放器在播放，以决定是否继续轮询；
        // 当前播放位置通过 getCurrentPosition 按需获取，无需向 Flutter 推送位置事件。
        if (player.isActuallyPlaying()) {
          isAnyPlaying = true
        }
      } catch (e) {
        // 单个 player 异常不应中断整轮轮询
        Log.e(TAG, `updateCallback error for player ${key}: ${(e as Error).message ?? String(e)}`);
      }
    })
    if (!isAnyPlaying) {
      this.stopUpdates()
    }
  }

  private getAudioContext(call: MethodCall): AudioContextOhos {
    let contextOhos = new AudioContextOhos();
    contextOhos.isSpeakerphoneOn = this.getObjectValue(call, 'isSpeakerphoneOn', 'isSpeakerphoneOn is required') as boolean
    contextOhos.rendererFlags = this.getObjectValue(call, 'rendererFlags', 'rendererFlags is required') as number
    contextOhos.usageType = this.getObjectValue(call, 'usageType', 'usageType is required') as number
    contextOhos.audioScene = this.getObjectValue(call, 'audioScene', 'audioScene is required') as number
    contextOhos.stayAwake =  this.getObjectValue(call, 'stayAwake', 'stayAwake is required') as boolean
    return contextOhos;
  }

  private getMimeType(url: string): string {
    let parts = url.split('.');
    let extension = '';
    if (parts.length > 1) {
      extension = parts[parts.length - 1].toLowerCase();
    }
    if (extension == 'txt') {
      return 'text/plain';
    }
    if (extension == 'mp3') {
      return 'audio/mpeg';
    }
    if (extension == 'wav') {
      return 'audio/wav';
    }
    if (extension == 'ogg') {
      return 'audio/ogg';
    }
    if (extension == 'mp4') {
      return 'video/mp4';
    }
    if (extension == 'avi') {
      return 'video/x-msvideo';
    }
    return 'application/octet-stream';
  }

  private getObjectValue(call: MethodCall, key: string, error: string): ESObject {
    if (call.hasArgument(key)) {
      return call.argument(key);
    }
    this.error(error)
  }

  private error(msg: string) {
    throw new Error(msg);
  }

  // 将音量限制在 [0, 1] 范围内
  private clampVolume(volume: number): number {
    let v = volume as number;
    if (isNaN(v)) {
      return 1;
    }
    return Math.min(1, Math.max(0, v));
  }

  // 将左右平衡限制在 [-1, 1] 范围内
  private clampBalance(balance: number): number {
    let b = balance as number;
    if (isNaN(b)) {
      return 0;
    }
    return Math.min(1, Math.max(-1, b));
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.abilityBinding = binding
  }

  onDetachedFromAbility(): void {
    this.abilityBinding = undefined
    this.stopContinuousTask()
  }

  async startContinuousTask() {
    Log.d(TAG, 'startContinuousTask');
    if(this.isStartContinuousTask){
      return;
    }
    let context = this.abilityBinding?.getAbility().context;
    if (context == null) {
      Log.e(TAG, 'startContinuousTask: abilityBinding is null, skip');
      return;
    }
    this.isStartContinuousTask = true;

    let type: AVSessionManager.AVSessionType = 'audio';

    try {
      this.session = await AVSessionManager.createAVSession(context, 'audioplayers', type);
      // 激活接口要在元数据、控制命令注册完成之后再执行
      await this.session?.activate();
      Log.d(TAG, `session create done : sessionId : ${this.session?.sessionId}`);
    } catch (error) {
      Log.e(TAG,`session create failed. code is ${(error as BusinessError).code} message is ${(error as BusinessError).message}`);
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
    } catch (error) {
      Log.e(TAG,`startBackgroundRunning failed. code is ${(error as BusinessError).code} message is ${(error as BusinessError).message}`);
    }
  }

  async stopContinuousTask() {
    Log.d(TAG, 'stopContinuousTask');
    if(!this.isStartContinuousTask){
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

interface UpdateCallback {
  stopUpdates(): void

  startUpdates(): void
}