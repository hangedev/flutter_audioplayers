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
 
import AudioContextOhos from '../AudioContextOhos'
import Source from '../source/Source'
import audio from '@ohos.multimedia.audio';

export default interface Player {
  getDuration(): number | null;

  getCurrentPosition(): number | null;

  isActuallyPlaying(): boolean;

  isLiveStream(): boolean;

  start(): void;

  pause(): void;

  stop(): void;

  seekTo(position: number): void;

  release(): void;

  setVolume(leftVolume: number, rightVolume: number): void;

  setRate(rate: number): void;

  setLooping(looping: boolean): void;

  updateContext(context: AudioContextOhos): void;

  setSource(source: Source): Promise<void>;

  prepare(): Promise<void>;

  reset(): Promise<void>;

  // 注册音频焦点打断回调，由底层 AVPlayer/SoundPool 的 audioInterrupt 事件驱动。
  // 返回 true 表示该播放器支持焦点监听并已注册，false 表示不支持。
  setInterruptListener(listener: (event: audio.InterruptEvent) => void): boolean;

  // 取消音频焦点打断回调，释放时调用，避免回调访问已释放资源。
  clearInterruptListener(): void;
}
