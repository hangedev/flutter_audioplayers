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

import AudioContextOhos from '../AudioContextOhos';
import Source from '../source/Source';
import UrlSource from '../source/UrlSource';
import BytesSource from '../source/BytesSource';
import Player from './Player';
import WrappedPlayer from './WrappedPlayer'
import media from '@ohos.multimedia.media';
import { BusinessError } from '@ohos.base';
import { Log } from '@ohos/flutter_ohos';
import { window } from '@kit.ArkUI'
import common from '@ohos.app.ability.common';

const TAG = 'MediaPlayerPlayer'
// === 通用错误码 ===
const PARAM_ERROR: number = 401; 
const OPERATE_ERROR: number = 801; 
const PERMISSION_DENIED: number = 1000001; 

// === AVPlayer 相关错误码 ===
const AVPLAYER_STATE_ERROR: number = 5400102; 
const AVPLAYER_IO_ERROR: number = 5400103; 
const AVPLAYER_TIMEOUT_ERROR: number = 5400104; 
const AVPLAYER_UNSUPPORTED_OPERATION: number = 5400105; 
const AVPLAYER_FORMAT_ERROR: number = 5400106;
const AVPLAYER_NETWORK_ERROR: number = 5400107;

// === 音频相关错误码 ===
const AUDIO_STATE_ERROR: number = 6800101;
const AUDIO_IO_ERROR: number = 6800102; 
const AUDIO_PERMISSION_DENIED: number = 6800103; 
const AUDIO_UNSUPPORTED_FORMAT: number = 6800104; 
const AUDIO_SYSTEM_ERROR: number = 6800105; 

// === 媒体库相关错误码 ===
const MEDIALIB_PERMISSION_DENIED: number = 5411001; 
const MEDIALIB_IO_ERROR: number = 5411002; 
const MEDIALIB_FORMAT_ERROR: number = 5411003; 
const MEDIALIB_NETWORK_ERROR: number = 5411004; 
const MEDIALIB_TIMEOUT: number = 5411005; 
const MEDIALIB_REQUEST_DENIED: number = 5411006; 

// === 文件系统相关错误码 ===
const FILE_PERMISSION_DENIED: number = 13900001; 
const FILE_NOT_EXIST: number = 13900002;
const FILE_IO_ERROR: number = 13900003; 
const FILESYSTEM_ERROR: number = 13900004; 

// === 网络相关错误码 ===
const NETWORK_CONNECTION_ERROR: number = 2300001; 
const NETWORK_TIMEOUT: number = 2300002; 
const NETWORK_UNAVAILABLE: number = 2300003; 
const NETWORK_PROTOCOL_ERROR: number = 2300004; 
const NETWORK_DNS_ERROR: number = 2300005;
const NETWORK_SSL_ERROR: number = 2300006; 

export default class MediaPlayerPlayer implements Player {
  private wrappedPlayer: WrappedPlayer;
  private mediaPlayer?: media.AVPlayer | null = null;
  private isLooping: boolean = false;
  private volume: number = 1;
  private needPrepare: boolean = false;
  private stayAwake: boolean = false;
  private speed = media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
  // 当前播放源引用，用于在切换源/释放时关闭本地 fd，避免文件描述符泄漏
  private currentSource: Source | null = null;
  // 保存回调引用，便于在 release() 中精确 off() 取消订阅，避免闭包循环引用与监听器泄漏
  private seekDoneCallback?: (seekDoneTime: number) => void;
  private bufferingUpdateCallback?: (infoType: media.BufferingInfoType, value: number) => void;
  private speedDoneCallback?: (speed: number) => void;
  private errorCallback?: (err: BusinessError) => void;
  private stateChangeCallback?: (state: string, reason: media.StateChangeReason) => void;
  // 显式追踪事件订阅状态，便于防御性检查与调试
  private isCallbackRegistered: boolean = false;
  // prepare() 需等到 stateChange='prepared' 才结束；冷启动首次否则会提前返回，Dart 侧丢 toast
  private preparePromise: Promise<void> | null = null;
  private prepareDoneResolve: (() => void) | null = null;
  private prepareDoneReject: ((err: Error) => void) | null = null;

  constructor(wrappedPlayer: WrappedPlayer, context: AudioContextOhos) {
    this.wrappedPlayer = wrappedPlayer;
    this.stayAwake = context.stayAwake;
  }

  async initMediaPlayer() {
    try {
      this.mediaPlayer = await media.createAVPlayer();
      this.setAVPlayerCallback(this.mediaPlayer)
      Log.d(TAG, 'initMediaPlayer');
    } catch (e) {
      this.mediaPlayer = null
      this.wrappedPlayer.onError(OPERATE_ERROR, `initMediaPlayer failed: ${e.message}`)
      Log.e(TAG, `initMediaPlayer failed: ${e.message}`);
    }
  }

  setAVPlayerCallback(avPlayer: media.AVPlayer) {
    // seek操作结果回调函数
    this.seekDoneCallback = (seekDoneTime: number) => {
      Log.d(TAG, `AVPlayer seek succeeded, seek time is ${seekDoneTime}`);
      this.wrappedPlayer.onSeekComplete()
    }
    avPlayer.on('seekDone', this.seekDoneCallback)

    this.bufferingUpdateCallback = (infoType: media.BufferingInfoType, value: number) => {
      Log.d(TAG, `AVPlayer bufferingUpdate value is ${value}`);
      this.wrappedPlayer.onBuffering(value)
    }
    avPlayer.on('bufferingUpdate', this.bufferingUpdateCallback)

    this.speedDoneCallback = (speed: number) => {
      console.info('speedDone called,and speed value is:' + speed)
    }
    avPlayer.on('speedDone', this.speedDoneCallback)

    // error回调监听函数,当avPlayer在操作过程中出现错误时调用 reset接口触发重置流程
    this.errorCallback = (err: BusinessError) => {
      try {
        const detail = `AVPlayer error code=${err.code}, message=${err.message}`
        if (err.code == OPERATE_ERROR || err.code == AVPLAYER_STATE_ERROR) {
          // 操作态瞬时错误：记录但不打断播放器状态机
          Log.e(TAG, `AvPlayer transient operate/state error: ${detail}`);
          return;
        }
        // IO / 权限 / 格式错误一律上抛到 Flutter，便于上层诊断
        Log.e(TAG, `Invoke avPlayer failed: ${detail}`);
        this.rejectPrepareWait(new Error(detail));
        this.wrappedPlayer.onError(err.code, detail)
      } catch (e) {
        Log.e(TAG, `AVPlayer error callback handle failed: ${e.message}`);
      }
    }
    avPlayer.on('error', this.errorCallback)

    // 状态机变化回调函数
    this.stateChangeCallback = (state: string, reason: media.StateChangeReason) => {
      switch (state) {
        case 'idle': // 成功调用reset接口后触发该状态机上报
          Log.d(TAG, 'AVPlayer state idle called.');
          break;
        case 'initialized': // avplayer 设置播放源后触发该状态上报
          Log.d(TAG, 'AVPlayer state initialized called.');
          try {
            this.wrappedPlayer.context?.setAttributesOnPlayer(this.mediaPlayer!)
          } catch (e) {
            Log.e(TAG, `setAttributesOnPlayer failed: ${(e as Error).message}`);
            this.wrappedPlayer.onError(OPERATE_ERROR, `setAttributesOnPlayer failed: ${(e as Error).message}`);
          }
          if (this.needPrepare) {
            this.needPrepare = false;
            // 不要递归 await this.prepare()（会覆盖 waiter）；此处直接触发底层 prepare
            this.mediaPlayer!.prepare().catch((e: Error) => {
              Log.e(TAG, `Auto-prepare failed: ${e.message}`);
              this.rejectPrepareWait(e);
              this.wrappedPlayer.onError(OPERATE_ERROR, `Auto-prepare failed: ${e.message}`);
            });
          }
          break;
        case 'prepared': // prepare调用成功后上报该状态机
          Log.d(TAG, 'AVPlayer state prepared called.');
          this.setVolume(this.volume, this.volume)
          this.setLooping(this.isLooping)
          this.setRate(this.speed);
          this.wrappedPlayer.onPrepared();
          this.resolvePrepareWait();
          break;
        case 'playing': // play成功调用后触发该状态机上报
          Log.d(TAG, 'AVPlayer state playing called.');
          break;
        case 'paused': // pause成功调用后触发该状态机上报
          Log.d(TAG, 'AVPlayer state paused called.');
          break;
        case 'completed': // 播放结束后触发该状态机上报
          Log.d(TAG, 'AVPlayer state completed called.');
          this.wrappedPlayer.onCompletion()
          break;
        case 'stopped': // stop接口成功调用后触发该状态机上报
          Log.d(TAG, 'AVPlayer state stopped called.');
          if (this.needPrepare) {
            this.needPrepare = false;
            this.mediaPlayer!.prepare().catch((e: Error) => {
              Log.e(TAG, `Auto-prepare failed: ${e.message}`);
              this.rejectPrepareWait(e);
              this.wrappedPlayer.onError(OPERATE_ERROR, `Auto-prepare failed: ${e.message}`);
            });
          }
          break;
        case 'released':
          Log.d(TAG, 'AVPlayer state released called.');
          break;
        default:
          Log.d(TAG, 'AVPlayer state unknown called.');
          break;
      }
    }
    avPlayer.on('stateChange', this.stateChangeCallback)
    this.isCallbackRegistered = true
  }

  /**
   * 取消已注册的 AVPlayer 事件监听器，避免监听器泄漏与闭包循环引用。
   * 每个 off() 单独 try-catch：即使单个 off 失败（如 AVPlayer 已失效），
   * 回调引用仍会被置空，确保循环引用在异常路径下也能断开。
   */
  private removeAVPlayerCallback(avPlayer: media.AVPlayer) {
    if (this.seekDoneCallback) {
      try {
        avPlayer.off('seekDone', this.seekDoneCallback)
      } catch (e) {
        Log.e(TAG, `off seekDone failed: ${(e as Error).message}`)
      }
      this.seekDoneCallback = undefined
    }
    if (this.bufferingUpdateCallback) {
      try {
        avPlayer.off('bufferingUpdate', this.bufferingUpdateCallback)
      } catch (e) {
        Log.e(TAG, `off bufferingUpdate failed: ${(e as Error).message}`)
      }
      this.bufferingUpdateCallback = undefined
    }
    if (this.speedDoneCallback) {
      try {
        avPlayer.off('speedDone', this.speedDoneCallback)
      } catch (e) {
        Log.e(TAG, `off speedDone failed: ${(e as Error).message}`)
      }
      this.speedDoneCallback = undefined
    }
    if (this.errorCallback) {
      try {
        avPlayer.off('error', this.errorCallback)
      } catch (e) {
        Log.e(TAG, `off error failed: ${(e as Error).message}`)
      }
      this.errorCallback = undefined
    }
    if (this.stateChangeCallback) {
      try {
        avPlayer.off('stateChange', this.stateChangeCallback)
      } catch (e) {
        Log.e(TAG, `off stateChange failed: ${(e as Error).message}`)
      }
      this.stateChangeCallback = undefined
    }
    this.isCallbackRegistered = false
  }

  getDuration(): number | null {
    if (!this.mediaPlayer) {
      return null
    }
    const duration = this.mediaPlayer.duration
    // AVPlayer 用 -1 表示未知；对齐 Android/Dart 的 null 语义
    return duration < 0 ? null : duration
  }

  getCurrentPosition(): number | null {
    if (!this.mediaPlayer) {
      return null
    }
    const position = this.mediaPlayer.currentTime
    return position < 0 ? null : position
  }

  isActuallyPlaying(): boolean {
    return this.mediaPlayer ? this.mediaPlayer!.state == 'playing' : false
  }

  isLiveStream(): boolean {
    let duration = this.getDuration();
    return duration == null || duration == 0
  }

  async start() {
    if (this.mediaPlayer) {
      try {
        await this.mediaPlayer.play();
      } catch (e) {
        const detail = `AVPlayer start failed: ${(e as Error).message}`
        Log.e(TAG, detail);
        this.wrappedPlayer.onError(OPERATE_ERROR, detail);
      }
    }
  }

  async pause() {
    if (this.mediaPlayer && this.mediaPlayer.state == 'playing') {
      try {
        await this.mediaPlayer.pause();
      } catch (e) {
        const detail = `AVPlayer pause failed: ${(e as Error).message}`
        Log.e(TAG, detail);
        this.wrappedPlayer.onError(OPERATE_ERROR, detail);
      }
    }
  }

  async stop() {
    this.needPrepare = false;
    if (this.mediaPlayer) {
      try {
        await this.mediaPlayer.stop();
      } catch (e) {
        const detail = `AVPlayer stop failed: ${(e as Error).message}`
        Log.e(TAG, detail);
        this.wrappedPlayer.onError(OPERATE_ERROR, detail);
      }
    }
  }

  seekTo(position: number) {
    this.mediaPlayer && this.mediaPlayer.seek(position);
  }

  async release() {
    try {
      if (this.mediaPlayer) {
        this.removeAVPlayerCallback(this.mediaPlayer)
        // reset 前显式清除 BytesSource 的 dataSrc 回调，断开对 bytes 的引用链
        if (this.currentSource instanceof BytesSource) {
          (this.currentSource as BytesSource).clearForMediaPlayer(this.mediaPlayer)
        }
        try {
          await this.mediaPlayer.reset()
        } catch (e) {
          Log.e(TAG, `mediaPlayer.reset failed: ${(e as Error).message}`)
        }
        try {
          await this.mediaPlayer.release()
        } catch (e) {
          Log.e(TAG, `mediaPlayer.release failed: ${(e as Error).message}`)
        }
        this.mediaPlayer = null
      }
    } finally {
      // 无论 reset/release 是否抛错，都关闭本地源 fd，避免泄漏
      this.closeCurrentSourceFd()
    }
  }

  setVolume(leftVolume: number, rightVolume: number) {
    // OHOS AVPlayer 仅支持单声道音量；取左右声道均值以贴近双声道语义
    this.volume = (leftVolume + rightVolume) / 2;
    if (this.isReadyState()) {
      try {
        this.mediaPlayer?.setVolume(this.volume);
      } catch (e) {
        this.wrappedPlayer.handleError('MediaVolumeError', (e as Error).message, null)
      }
    }
  }

  setRate(rate: number) {
    if (rate < 0) {
      throw new Error('Invalid rate input: ' + rate);
    }
    if(rate == 0){
      this.mediaPlayer?.pause();
      return;
    }
    this.speed = media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
    if (rate <= 0.5) {
      this.speed = media.PlaybackSpeed.SPEED_FORWARD_0_50_X;
    } else if (rate <= 0.75) {
      this.speed = media.PlaybackSpeed.SPEED_FORWARD_0_75_X;
    } else if (rate <= 1.0) {
      this.speed = media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
    } else if (rate <= 1.25) {
      this.speed = media.PlaybackSpeed.SPEED_FORWARD_1_25_X;
    } else if (rate <= 1.5) {
      this.speed = media.PlaybackSpeed.SPEED_FORWARD_1_50_X;
    } else if (rate <= 1.75) {
      this.speed = media.PlaybackSpeed.SPEED_FORWARD_1_75_X;
    } else {
      this.speed = media.PlaybackSpeed.SPEED_FORWARD_2_00_X
    }
    this.mediaPlayer && this.mediaPlayer.setSpeed(this.speed);
  }

  setLooping(looping: boolean) {
    this.isLooping = looping;
    if (this.isReadyState()) {
      this.mediaPlayer!.loop = looping;
    }
  }

  private isReadyState() {
    return this.mediaPlayer && (this.mediaPlayer!.state == 'prepared' || this.mediaPlayer!.state == 'playing'
      || this.mediaPlayer!.state == 'paused' || this.mediaPlayer!.state == 'completed')
  }

  async updateContext(context: AudioContextOhos) {
    try {
      this.mediaPlayer && this.mediaPlayer!.state == 'initialized' && context.setAttributesOnPlayer(this.mediaPlayer);
      if (context.stayAwake != this.stayAwake) {
        let uiContext = getContext(this) as common.UIAbilityContext
        let windowClass: window.Window = await window.getLastWindow(uiContext)
        windowClass.setWindowKeepScreenOn(context.stayAwake);
        this.stayAwake = context.stayAwake
      }
    } catch (e) {
      this.wrappedPlayer.onError(OPERATE_ERROR, `updateContext failed: ${e.message}`)
      Log.e(TAG, `updateContext failed: ${e.message}`);
    }
  }

  async setSource(source: Source): Promise<void> {
    await this.reset()
    // 切换源前关闭上一个本地源打开的文件描述符，避免 fd 累积泄漏
    this.closeCurrentSourceFd()
    this.currentSource = source
    if (this.mediaPlayer) {
      try {
        source.setForMediaPlayer(this.mediaPlayer);
      } catch (e) {
        this.wrappedPlayer.onError(OPERATE_ERROR, `setSource failed: ${e.message}`)
        Log.e(TAG, `setSource failed: ${e.message}`);
        throw e as Error;
      }
    }
  }

  /**
   * 关闭当前本地源（UrlSource）打开的文件描述符并清空源引用。
   * 应在 AVPlayer release/reset 后调用：此时 AVPlayer 已不再需要该 fd。
   */
  private closeCurrentSourceFd() {
    if (this.currentSource instanceof UrlSource) {
      (this.currentSource as UrlSource).closeOpenedFile()
    }
    this.currentSource = null
  }

  async prepare(): Promise<void> {
    if (this.isReadyState()) {
      return;
    }
    // 已有进行中的 prepare：合并等待，避免覆盖 resolve/reject
    if (this.preparePromise != null) {
      return this.preparePromise;
    }

    this.preparePromise = new Promise<void>((resolve: () => void, reject: (err: Error) => void) => {
      this.prepareDoneResolve = resolve;
      this.prepareDoneReject = reject;
    });

    try {
      if (this.canPrepare()) {
        this.needPrepare = false;
        this.mediaPlayer!.prepare().catch((e: Error) => {
          this.rejectPrepareWait(e);
        });
      } else {
        // 等 initialized/stopped 后再真正 prepare；在 stateChange 里触发
        this.needPrepare = true;
      }
    } catch (e) {
      this.rejectPrepareWait(e as Error);
    }

    return this.preparePromise;
  }

  private resolvePrepareWait() {
    if (this.prepareDoneResolve != null) {
      const resolve = this.prepareDoneResolve;
      this.prepareDoneResolve = null;
      this.prepareDoneReject = null;
      this.preparePromise = null;
      resolve();
    }
  }

  private rejectPrepareWait(err: Error) {
    if (this.prepareDoneReject != null) {
      const reject = this.prepareDoneReject;
      this.prepareDoneResolve = null;
      this.prepareDoneReject = null;
      this.preparePromise = null;
      reject(err);
    }
  }

  private canPrepare() {
    return this.mediaPlayer != null &&
      (this.mediaPlayer!.state == 'stopped' || this.mediaPlayer!.state == 'initialized')
  }

  async reset(): Promise<void> {
    // reset 会打断进行中的 prepare
    this.needPrepare = false;
    if (this.preparePromise != null) {
      // 避免无人 await 时出现未处理的 Promise rejection
      this.preparePromise.catch(() => {});
      this.rejectPrepareWait(new Error('AVPlayer reset before prepare completed'));
    }
    if (this.mediaPlayer) {
      await this.mediaPlayer.reset()
    }
  }
}