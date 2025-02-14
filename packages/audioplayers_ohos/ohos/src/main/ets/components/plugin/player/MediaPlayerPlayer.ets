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
import { BusinessError } from '@ohos.base';
import { Log } from '@ohos/flutter_ohos';
import { window } from '@kit.ArkUI'
import common from '@ohos.app.ability.common';

const TAG = "MediaPlayerPlayer"
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

  constructor(wrappedPlayer: WrappedPlayer, context: AudioContextOhos) {
    this.wrappedPlayer = wrappedPlayer;
    this.stayAwake = context.stayAwake;
  }

  async initMediaPlayer() {
    this.mediaPlayer = await media.createAVPlayer();
    this.setAVPlayerCallback(this.mediaPlayer)
    Log.d(TAG, "initMediaPlayer");
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

    // error回调监听函数,当avPlayer在操作过程中出现错误时调用 reset接口触发重置流程
    avPlayer.on('error', (err: BusinessError) => {
      if(err.code == OPERATE_ERROR || err.code == AVPLAYER_STATE_ERROR || err.code == AVPLAYER_IO_ERROR) {
        Log.e(TAG, "AvPlayer Avoid Error Reporting: " + JSON.stringify(err));
        return;
      }
      Log.e(TAG, `Invoke avPlayer failed, code is ${err.code}, message is ${err.message}`);
      this.wrappedPlayer.onError(err.code, err.message)
    })
    // 状态机变化回调函数
    avPlayer.on('stateChange', async (state: string, reason: media.StateChangeReason) => {
      switch (state) {
        case 'idle': // 成功调用reset接口后触发该状态机上报
          Log.d(TAG, 'AVPlayer state idle called.');
          break;
        case 'initialized': // avplayer 设置播放源后触发该状态上报
          Log.d(TAG, 'AVPlayer state initialized called.');
          this.wrappedPlayer.context?.setAttributesOnPlayer(this.mediaPlayer!)
          this.needPrepare && this.prepare();
          break;
        case 'prepared': // prepare调用成功后上报该状态机
          Log.d(TAG, 'AVPlayer state prepared called.');
          this.setVolume(this.volume, this.volume)
          this.setLooping(this.isLooping)
          this.wrappedPlayer.onPrepared();
          break;
        case 'playing': // play成功调用后触发该状态机上报
          Log.d(TAG, 'AVPlayer state playing called.');
          this.wrappedPlayer.startContinuousTask();
          break;
        case 'paused': // pause成功调用后触发该状态机上报
          Log.d(TAG, 'AVPlayer state paused called.');
          this.wrappedPlayer.stopContinuousTask();
          break;
        case 'completed': // 播放结束后触发该状态机上报
          Log.d(TAG, 'AVPlayer state completed called.');
          this.wrappedPlayer.onCompletion()
          break;
        case 'stopped': // stop接口成功调用后触发该状态机上报
          Log.d(TAG, 'AVPlayer state stopped called.');
          this.wrappedPlayer.stopContinuousTask();
          this.needPrepare && this.prepare();
          break;
        case 'released':
          this.wrappedPlayer.stopContinuousTask();
          Log.d(TAG, 'AVPlayer state released called.');
          break;
        default:
          Log.d(TAG, 'AVPlayer state unknown called.');
          break;
      }
    })
  }

  getDuration(): number {
    // media player returns -1 if the duration is unknown
    return this.mediaPlayer ? this.mediaPlayer!.duration : -1
  }

  getCurrentPosition(): number {
    return this.mediaPlayer ? this.mediaPlayer!.currentTime : -1
  }

  isActuallyPlaying(): boolean {
    return this.mediaPlayer ? this.mediaPlayer!.state == 'playing' : false
  }

  isLiveStream(): boolean {
    let duration = this.getDuration();
    return duration == 0 || duration == -1
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
    if (this.mediaPlayer) {
      await this.mediaPlayer.reset()
      await this.mediaPlayer.release()
    }
  }

  setVolume(leftVolume: number, rightVolume: number) {
    this.volume = leftVolume;
    if (this.isReadyState()) {
      this.mediaPlayer!.setVolume(leftVolume);
    }
  }

  setRate(rate: number) {
    let speed = media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
    if (rate < 1) {
      speed = media.PlaybackSpeed.SPEED_FORWARD_0_75_X;
    } else if (rate == 1.25) {
      speed = media.PlaybackSpeed.SPEED_FORWARD_1_25_X;
    } else if (rate == 1.75) {
      speed = media.PlaybackSpeed.SPEED_FORWARD_1_75_X;
    } else if (rate >= 2) {
      speed = media.PlaybackSpeed.SPEED_FORWARD_2_00_X;
    }
    this.mediaPlayer && this.mediaPlayer.setSpeed(speed);
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
    this.mediaPlayer && this.mediaPlayer!.state == 'initialized' &&context.setAttributesOnPlayer(this.mediaPlayer);
    if (context.stayAwake != this.stayAwake) {
      let uiContext = getContext(this) as common.UIAbilityContext
      let windowClass:window.Window = await window.getLastWindow(uiContext)
      windowClass.setWindowKeepScreenOn(context.stayAwake);
      this.stayAwake = context.stayAwake
    }
  }

  async setSource(source: Source) {
    await this.reset()
    this.mediaPlayer && source.setForMediaPlayer(this.mediaPlayer);
  }

  async prepare() {
    if (this.canPrepare()) {
      this.needPrepare = false;
      await this.mediaPlayer!.prepare()
    } else {
      this.needPrepare = true
    }
  }

  private canPrepare() {
    return this.mediaPlayer && (this.mediaPlayer!.state == 'stopped' || this.mediaPlayer!.state == 'initialized')
  }

  async reset() {
    this.mediaPlayer && await this.mediaPlayer.reset()
  }
}