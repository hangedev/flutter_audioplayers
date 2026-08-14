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

import WrappedPlayer from './WrappedPlayer'
import audio from '@ohos.multimedia.audio';
import { Log } from '@ohos/flutter_ohos';

const TAG = 'FocusManager';

export default class FocusManager {
  private player: WrappedPlayer | null = null;
  // 焦点被打断时记录'应处于播放'的状态，焦点恢复(RESUME)后据此自动恢复播放
  private wasPlayingBeforeInterrupt: boolean = false;
  private interruptListener: ((event: audio.InterruptEvent) => void) | null = null;
  private isInterruptBound: boolean = false;

  constructor(player: WrappedPlayer) {
    this.player = player;
  }

  // 鸿蒙音频焦点由系统按 audioRendererInfo / audioInterruptMode 自动管理，
  // 不存在 requestAudioFocus/abandonAudioFocus 接口。此处仅保证播放回调按约定执行，
  // 实际焦点请求由底层 AVPlayer/SoundPool 在 prepare/play 时自动发起。
  maybeRequestAudioFocus(andThen: Function) {
    this.ensureInterruptBound()
    andThen()
  }

  // 暂停/释放播放时取消焦点打断监听，避免回调访问已释放资源。
  handleStop() {
    this.clearInterruptListener()
  }

  // 绑定底层播放器的 audioInterrupt 事件（幂等，重复调用安全）
  private ensureInterruptBound() {
    if (this.isInterruptBound || this.player == null) {
      return
    }
    let p = this.player;
    this.interruptListener = (event: audio.InterruptEvent) => {
      this.onInterrupt(event)
    }
    let registered = p.setInterruptListener(this.interruptListener!);
    this.isInterruptBound = registered;
    if (!registered) {
      this.interruptListener = null;
      Log.w(TAG, 'current player does not support audioInterrupt, focus handling skipped');
    }
  }

  private clearInterruptListener() {
    if (this.player != null && this.isInterruptBound) {
      this.player.clearInterruptListener()
    }
    this.isInterruptBound = false;
    this.interruptListener = null;
  }

  // 根据焦点事件驱动播放状态：失去焦点暂停，恢复焦点续播
  private onInterrupt(event: audio.InterruptEvent) {
    if (this.player == null) {
      return
    }
    let p = this.player;
    switch (event.hintType) {
      case audio.InterruptHint.INTERRUPT_HINT_PAUSE:
        // 失去焦点，先记住是否处于播放以便恢复
        this.wasPlayingBeforeInterrupt = p.isPlaying();
        if (this.wasPlayingBeforeInterrupt) {
          p.pause();
        }
        break;
      case audio.InterruptHint.INTERRUPT_HINT_STOP:
        // 彻底失去焦点，无需记住播放状态
        this.wasPlayingBeforeInterrupt = false;
        p.stop();
        break;
      case audio.InterruptHint.INTERRUPT_HINT_RESUME:
        // 焦点恢复，仅在被打断前处于播放时续播
        if (this.wasPlayingBeforeInterrupt) {
          this.wasPlayingBeforeInterrupt = false;
          p.play();
        }
        break;
      default:
        // DUCK/UNDUCK/MUTE/UNMUTE 等由系统自动处理音量，这里不干预
        break;
    }
  }

  // WrappedPlayer 释放时调用，解除双向引用避免循环引用
  dispose() {
    this.clearInterruptListener();
    this.player = null;
    this.wasPlayingBeforeInterrupt = false;
  }
}
