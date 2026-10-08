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
import Player from './Player';
import WrappedPlayer from './WrappedPlayer'
import media from '@ohos.multimedia.media';
import audio from '@ohos.multimedia.audio';
import { BusinessError } from '@ohos.base';
import { Log } from '@ohos/flutter_ohos';
import window from '@ohos.window';
import common from '@ohos.app.ability.common';
import { appInfoManager } from '@kit.StoreKit';

const TAG = 'MediaPlayerPlayer'
const OPERATE_ERROR: number = 801;
const AVPLAYER_STATE_ERROR: number = 5400102;
const AVPLAYER_IO_ERROR: number = 5400103;

export default class MediaPlayerPlayer implements Player {
  private wrappedPlayer: WrappedPlayer;
  private mediaPlayer?: media.AVPlayer | null = null;
  private isLooping: boolean = false;
  private volume: number = 1;
  private needPrepare: boolean = false;
  private stayAwake: boolean = false;
  private speed = media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
  // 显式追踪事件是否已注册，避免 release 中 off() 异常被吞掉后回调仍残留
  private isCallbacksRegistered: boolean = false;
  // 焦点打断回调，保存引用以便精确取消，并在 release 时打断循环引用
  private interruptListener: ((event: audio.InterruptEvent) => void) | null = null;
  // prepare() 需等到 stateChange='prepared' 才结束；冷启动首次否则会提前返回，Dart 侧丢 toast
  private preparePromise: Promise<void> | null = null;
  private prepareDoneResolve: (() => void) | null = null;
  private prepareDoneReject: ((err: Error) => void) | null = null;

  constructor(wrappedPlayer: WrappedPlayer, context: AudioContextOhos) {
    this.wrappedPlayer = wrappedPlayer;
    this.stayAwake = context.stayAwake;
  }

  async initMediaPlayer() {
    this.mediaPlayer = await media.createAVPlayer();
    this.setAVPlayerCallback(this.mediaPlayer)
    this.isCallbacksRegistered = true;
    Log.d(TAG, 'initMediaPlayer');
  }

  setAVPlayerCallback(avPlayer: media.AVPlayer) {
    // seek操作结果回调函数
    avPlayer.on('seekDone', (seekDoneTime: number) => {
      Log.d(TAG, `AVPlayer seek succeeded, seek time is ${seekDoneTime}`);
      this.wrappedPlayer.onSeekComplete()
    })

    avPlayer.on('bufferingUpdate', (infoType: media.BufferingInfoType, value: number) => {
      Log.d(TAG, `AVPlayer bufferingUpdate value is ${value}`);
      this.wrappedPlayer.onBuffering(value)
    })
    avPlayer.on('speedDone', (speed: number) => {
      console.info('speedDone called,and speed value is:' + speed)
    })
    // error回调监听函数,当avPlayer在操作过程中出现错误时调用 reset接口触发重置流程
    avPlayer.on('error', (err: BusinessError) => {
      let detail = `AVPlayer error code=${err.code}, message=${err.message}`;
      this.rejectPrepareWait(new Error(detail));
      if (err.code == OPERATE_ERROR || err.code == AVPLAYER_STATE_ERROR || err.code == AVPLAYER_IO_ERROR) {
        Log.e(TAG, 'AvPlayer Avoid Error Reporting: ' + JSON.stringify(err));
        return;
      }
      Log.e(TAG, `Invoke avPlayer failed, code is ${err.code}, message is ${err.message}`);
      this.wrappedPlayer.onError(err.code, err.message)
    })
    // 状态机变化回调函数
    avPlayer.on('stateChange', (state: string, reason: media.StateChangeReason) => {
      switch (state) {
        case 'idle': // 成功调用reset接口后触发该状态机上报
          Log.d(TAG, 'AVPlayer state idle called.');
          break;
        case 'initialized': // avplayer 设置播放源后触发该状态上报
          Log.d(TAG, 'AVPlayer state initialized called.');
          this.wrappedPlayer.context?.setAttributesOnPlayer(this.mediaPlayer!)
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
    })
  }

  getDuration(): number | null {
    // 与 Dart 的 int? 语义对齐：时长未知时返回 null，而不是 -1
    if (!this.mediaPlayer) {
      return null;
    }
    let duration = this.mediaPlayer!.duration;
    // AVPlayer 在时长未知时返回 -1（直播流可能为 0），统一转换为 null
    return duration >= 0 ? duration : null;
  }

  getCurrentPosition(): number | null {
    // 与 Dart 的 int? 语义对齐：未知时返回 null，而不是 -1
    if (!this.mediaPlayer) {
      return null;
    }
    let position = this.mediaPlayer!.currentTime;
    return position >= 0 ? position : null;
  }

  isActuallyPlaying(): boolean {
    return this.mediaPlayer ? this.mediaPlayer!.state == 'playing' : false
  }

  isLiveStream(): boolean {
    let duration = this.getDuration();
    // duration 为 null（未知，含 AVPlayer 的 -1）或 0（直播流）视为直播
    return duration == null || duration == 0
  }

  async start() {
    this.mediaPlayer && await this.mediaPlayer.play();
  }

  async pause() {
    this.mediaPlayer && this.mediaPlayer!.state == 'playing' && await this.mediaPlayer.pause();
  }

  async stop() {
    this.needPrepare = false;
    this.mediaPlayer && await this.mediaPlayer.stop();
  }

  seekTo(position: number) {
    this.mediaPlayer && this.mediaPlayer.seek(position);
  }

  async release() {
    this.needPrepare = false;
    if (this.preparePromise != null) {
      this.preparePromise.catch(() => {});
      this.rejectPrepareWait(new Error('AVPlayer released before prepare completed'));
    }
    if (this.mediaPlayer) {
      // 显式取消所有事件监听，避免 reset/release 失败或回调触发时访问已释放资源导致泄漏
      if (this.isCallbacksRegistered) {
        try {
          this.mediaPlayer.off('seekDone')
          this.mediaPlayer.off('bufferingUpdate')
          this.mediaPlayer.off('speedDone')
          this.mediaPlayer.off('error')
          this.mediaPlayer.off('stateChange')
          this.mediaPlayer.off('audioInterrupt')
        } catch (e) {
          Log.e(TAG, `AVPlayer off listeners failed: ${(e as Error).message ?? String(e)}`);
        }
        this.isCallbacksRegistered = false;
      }
      await this.mediaPlayer.reset()
      await this.mediaPlayer.release()
      this.mediaPlayer = null
    }
    this.interruptListener = null;
  }

  // 注册音频焦点打断回调。AVPlayer 根据 audioRendererInfo 自动管理焦点请求/释放，
  // 这里只订阅其 audioInterrupt 事件并把焦点变化回传给 FocusManager。
  setInterruptListener(listener: (event: audio.InterruptEvent) => void): boolean {
    this.interruptListener = listener;
    if (this.mediaPlayer) {
      try {
        this.mediaPlayer.on('audioInterrupt', listener);
        return true;
      } catch (e) {
        Log.e(TAG, `AVPlayer on audioInterrupt failed: ${(e as Error).message ?? String(e)}`);
      }
    }
    return false;
  }

  clearInterruptListener(): void {
    if (this.mediaPlayer && this.interruptListener != null) {
      try {
        this.mediaPlayer.off('audioInterrupt', this.interruptListener);
      } catch (e) {
        Log.e(TAG, `AVPlayer off audioInterrupt failed: ${(e as Error).message ?? String(e)}`);
      }
    }
    this.interruptListener = null;
  }

  setVolume(leftVolume: number, rightVolume: number) {
    this.volume = leftVolume;
    if (this.isReadyState()) {
      this.mediaPlayer!.setVolume(leftVolume);
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
      this.speed = media.PlaybackSpeed.SPEED_FORWARD_2_00_X;
    }
    if (this.mediaPlayer && this.isReadyState()) {
      this.mediaPlayer.setSpeed(this.speed);
    }
    if(this.mediaPlayer?.state == 'paused'){
      this.start();
    }
  }

  setLooping(looping: boolean) {
    this.isLooping = looping;
    if (this.isReadyState() && !this.isLiveStream()) {
      this.mediaPlayer!.loop = looping;
    }
  }

  private isReadyState() {
    return this.mediaPlayer && (this.mediaPlayer!.state == 'prepared' || this.mediaPlayer!.state == 'playing'
      || this.mediaPlayer!.state == 'paused' || this.mediaPlayer!.state == 'completed')
  }

  async updateContext(context: AudioContextOhos) {
    if (this.mediaPlayer && this.mediaPlayer!.state == 'initialized') {
      context.setAttributesOnPlayer(this.mediaPlayer);
    }
    if (context.stayAwake != this.stayAwake) {
      try {
        let uiContext = getContext(this) as common.UIAbilityContext
        let windowClass: window.Window = await window.getLastWindow(uiContext)
        windowClass.setWindowKeepScreenOn(context.stayAwake);
        this.stayAwake = context.stayAwake
      } catch (e) {
        Log.e(TAG, `updateContext setWindowKeepScreenOn failed: ${(e as Error).message ?? String(e)}`);
      }
    }
  }

  async setSource(source: Source): Promise<void> {
    await this.reset()
    if (this.mediaPlayer) {
      try {
        source.setForMediaPlayer(this.mediaPlayer);
      } catch (e) {
        this.wrappedPlayer.onError(OPERATE_ERROR, `setSource failed: ${(e as Error).message}`)
        Log.e(TAG, `setSource failed: ${(e as Error).message}`);
        throw e as Error;
      }
    }
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

  private resolvePrepareWait(): void {
    if (this.prepareDoneResolve != null) {
      let resolve = this.prepareDoneResolve;
      this.prepareDoneResolve = null;
      this.prepareDoneReject = null;
      this.preparePromise = null;
      resolve();
    }
  }

  private rejectPrepareWait(err: Error): void {
    if (this.prepareDoneReject != null) {
      let reject = this.prepareDoneReject;
      this.prepareDoneResolve = null;
      this.prepareDoneReject = null;
      this.preparePromise = null;
      reject(err);
    }
  }

  private canPrepare(): boolean {
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