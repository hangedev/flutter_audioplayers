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
 
import SoundPoolPlayer from '../player/SoundPoolPlayer';
import Source from './Source';
import media from '@ohos.multimedia.media';

export default class BytesSource implements Source {
  private bytes: ArrayBuffer
  private mimeType?: string

  constructor(bytes: ArrayBuffer, mimeType?: string) {
    this.bytes = bytes;
    this.mimeType = mimeType;
  }

  setForMediaPlayer(mediaPlayer: media.AVPlayer): void {
    const data = this.bytes
    const totalSize = data.byteLength
    let src: media.AVDataSrcDescriptor = {
      fileSize: totalSize,
      callback: (buf: ArrayBuffer, length: number, pos: number | undefined) => {
        if (buf == undefined || length == undefined || pos == undefined) {
          return -1;
        }
        if (pos >= totalSize) {
          return -1
        }
        let remainingSize = length
        if (pos + remainingSize > totalSize) {
          remainingSize -= pos + remainingSize - totalSize
        }
        if (remainingSize < 0) {
          return -1;
        }
        const view = new Uint8Array(buf);
        const dataToCopy = data.slice(pos, pos + remainingSize);
        const dataView = new Uint8Array(dataToCopy);
        view.set(dataView);

        if (remainingSize > 0 && (totalSize >= pos)) {
          return remainingSize;
        }
        return -1;
      }
    }
    mediaPlayer.dataSrc = src
  }

  /**
   * 在 AVPlayer release/reset 前显式清除 dataSrc 描述符，
   * 断开 AVPlayer 对数据回调闭包（持有 bytes 引用）的引用链。
   */
  clearForMediaPlayer(mediaPlayer: media.AVPlayer): void {
    try {
      mediaPlayer.dataSrc = undefined
    } catch (_) {
      // 忽略：AVPlayer 状态机可能已不接受 dataSrc 赋值
    }
  }

  async setForSoundPool(soundPoolPlayer: SoundPoolPlayer): Promise<void> {
    throw new Error('Bytes sources are not supported on LOW_LATENCY mode yet.')
  }
}