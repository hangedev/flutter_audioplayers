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
import fs from '@ohos.file.fs';
import request from '@ohos.request';
import { Log } from '@ohos/flutter_ohos';

const TAG = 'UrlSource';

export default class UrlSource implements Source {
  url: string
  private isLocal: boolean
  // 记录通过 fs.openSync 打开的文件描述符，播放器释放后由应用负责关闭，避免 fd 泄漏
  private openedFds: number[] = []

  constructor(url: string, isLocal: boolean) {
    this.url = url;
    this.isLocal = isLocal;
  }

  setForMediaPlayer(mediaPlayer: media.AVPlayer): void {
    if (this.isLocal) {
      // 重复设置音源时先关闭上一轮遗留的 fd，避免同一 UrlSource 多次打开导致 fd 累积
      this.closeFd();
      // 打开相应的资源文件地址获取fd，并为url赋值触发initialized状态机上报
      let file = fs.openSync(this.url);
      this.openedFds.push(file.fd);
      mediaPlayer.url = 'fd://' + file.fd;
    } else {
      mediaPlayer.url = this.url;
    }
  }

  async setForSoundPool(soundPoolPlayer: SoundPoolPlayer): Promise<void> {
    await soundPoolPlayer.setUrlSource(this);
  }

  getAudioPathForSoundPool(context: Context): Promise<string> {
    return new Promise<string>((resolve, reject) => {
      if (this.isLocal) {
        // 重复设置音源时先关闭上一轮遗留的 fd，避免 fd 累积
        this.closeFd();
        // 打开相应的资源文件地址获取fd，并为url赋值触发initialized状态机上报
        let file = fs.openSync(this.url);
        this.openedFds.push(file.fd);
        resolve('fd://' + file.fd)
      } else {
        let tempFile = context.tempDir + '/sound.data'
        if (fs.accessSync(tempFile)) {
          fs.rmdirSync(tempFile)
        }
        request.downloadFile(context, {
          url: this.url,
          filePath: tempFile
        }).then((downloadTask: request.DownloadTask) => {
          let onComplete = () => {
            let file = fs.openSync(tempFile);
            this.openedFds.push(file.fd);
            // 回调完成后及时取消订阅，避免 DownloadTask 残留回调引用
            downloadTask.off('complete', onComplete)
            downloadTask.off('fail', onFail)
            resolve('fd://' + file.fd)
          }
          let onFail = (err: number) => {
            downloadTask.off('complete', onComplete)
            downloadTask.off('fail', onFail)
            // 下载失败时清理临时文件，避免 tempDir 残留累积
            try {
              if (fs.accessSync(tempFile)) {
                fs.unlinkSync(tempFile)
              }
            } catch (e) {
              Log.e(TAG, `cleanup temp file on download fail failed: ${(e as Error).message ?? String(e)}`);
            }
            reject(new Error(`Download failed with error code: ${err}`))
          }
          downloadTask.on('complete', onComplete)
          downloadTask.on('fail', onFail)
        }).catch((e: Error) => {
          reject(new Error(`Download request failed: ${e.message ?? String(e)}`))
        })
      }
    })
  }

  // 关闭本 UrlSource 持有的所有文件描述符。应在播放器释放后调用。
  closeFd(): void {
    while (this.openedFds.length > 0) {
      let fd = this.openedFds.pop();
      if (fd != null) {
        try {
          fs.closeSync(fd);
        } catch (e) {
          Log.e(TAG, `close fd ${fd} failed: ${(e as Error).message ?? String(e)}`);
        }
      }
    }
  }
}
