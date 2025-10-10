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
import audio from '@ohos.multimedia.audio'
import { Log } from '@ohos/flutter_ohos'

const TAG = "FocusManager";

export default class FocusManager {
  private player: WrappedPlayer | null = null;
  private audioManager: audio.AudioManager | null = null;
  private hasAudioFocus: boolean = false;
  private audioRenderer: audio.AudioRenderer | null = null;

  constructor(player: WrappedPlayer) {
    this.player = player;
    this.audioManager = audio.getAudioManager();
  }

  handleStop() {
    this.abandonAudioFocus();
  }

  maybeRequestAudioFocus(andThen: Function) {
    this.requestAudioFocus().then(() => {
      andThen();
    }).catch((error: Error) => {
      Log.e(TAG, `Failed to request audio focus: ${error.message}`);
      andThen(); // 即使获取焦点失败也继续播放
    });
  }

  private async requestAudioFocus(): Promise<void> {
    try {
      Log.d(TAG, "Requesting audio focus...");
      
      // 先暂停其他音频源
      this.pauseOtherAudioSources();
      
      // 如果已经有音频焦点，先释放旧的渲染器
      if (this.hasAudioFocus && this.audioRenderer) {
        Log.d(TAG, "Releasing existing audio renderer before requesting new focus");
        try {
          this.audioRenderer.release();
          this.audioRenderer = null;
        } catch (releaseError) {
          Log.w(TAG, `Failed to release existing audio renderer: ${releaseError}`);
        }
      }
      
      // 创建音频渲染器来管理音频焦点
      await this.createAudioRenderer();
      
      this.hasAudioFocus = true;
      Log.d(TAG, "Audio focus granted successfully");
    } catch (error) {
      Log.e(TAG, `Failed to request audio focus: ${error}`);
      this.hasAudioFocus = false;
      //
      // throw error;
    }
  }

  private async createAudioRenderer(): Promise<void> {
    if (this.audioRenderer) {
      return;
    }

    try {
      let audioStreamInfo: audio.AudioStreamInfo = {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_44100,
        channels: audio.AudioChannel.CHANNEL_2,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      };

      let audioRendererInfo: audio.AudioRendererInfo = {
        content: audio.ContentType.CONTENT_TYPE_MUSIC,
        usage: audio.StreamUsage.STREAM_USAGE_MEDIA,
        rendererFlags: 0
      };

      let audioRendererOptions: audio.AudioRendererOptions = {
        streamInfo: audioStreamInfo,
        rendererInfo: audioRendererInfo
      };

      this.audioRenderer = await audio.createAudioRenderer(audioRendererOptions);
      
      // 设置音频中断监听器
      this.audioRenderer.on('audioInterrupt', (interruptEvent: audio.InterruptEvent) => {
        this.handleAudioInterrupt(interruptEvent);
      });

      Log.d(TAG, "Audio renderer created successfully");
    } catch (error) {
      Log.e(TAG, `Failed to create audio renderer: ${error}`);
      // throw error;
    }
  }

  private handleAudioInterrupt(interruptEvent: audio.InterruptEvent): void {
    Log.d(TAG, `Audio interrupt event: ${JSON.stringify(interruptEvent)}`);

    if (interruptEvent.forceType === audio.InterruptForceType.INTERRUPT_FORCE) {
      // 强制中断，暂停播放
      if (interruptEvent.hintType === audio.InterruptHint.INTERRUPT_HINT_PAUSE ||
          interruptEvent.hintType === audio.InterruptHint.INTERRUPT_HINT_STOP) {
        this.player?.pause();
      }
    }
  }

  private pauseOtherAudioSources(): void {
    try {
      Log.d(TAG, "Pausing other audio sources...");
      // 通知插件暂停其他播放器
      if (this.player) {
        this.player.pauseOtherPlayers();
        Log.d(TAG, "Other audio sources paused successfully");
      } else {
        Log.w(TAG, "Player is null, cannot pause other audio sources");
      }
    } catch (error) {
      Log.e(TAG, `Error pausing other audio sources: ${error}`);
    }
  }

  private abandonAudioFocus(): void {
    if (!this.hasAudioFocus) {
      return;
    }

    try {
      if (this.audioRenderer) {
        // 移除音频中断监听器
        // this.audioRenderer.off('outputDeviceChange');
        this.audioRenderer.release();
        this.audioRenderer = null;
      }
      
      this.hasAudioFocus = false;
      Log.d(TAG, "Audio focus abandoned");
    } catch (error) {
      Log.e(TAG, `Failed to abandon audio focus: ${error}`);
    }
  }

  dispose(): void {
    this.abandonAudioFocus();
    this.player = null;
    this.audioManager = null;
  }
}