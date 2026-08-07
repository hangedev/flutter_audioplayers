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

export default class UrlSource implements Source {
  url: string
  mimeType?: string
  private isLocal: boolean
  // 本地资源打开后的文件描述符引用，由 AVPlayer 在播放期间持有；
  // AVPlayer release/reset 后需通过 closeOpenedFile() 显式关闭，避免 fd 泄漏。
  private openedFile: fs.File | null = null
  // SoundPool 路径打开的临时/本地 fd，需在 unload 后关闭
  private soundPoolOpenedFiles: Array<fs.File> = []
  private soundPoolTempPath: string | null = null
  private downloadTask: request.DownloadTask | null = null
  private downloadCompleteCallback: (() => void) | null = null
  private downloadFailCallback: ((err: number) => void) | null = null
  private disposed: boolean = false

  constructor(url: string, isLocal: boolean, mimeType?: string) {
    this.url = url;
    this.isLocal = isLocal;
    this.mimeType = mimeType;
  }

  setForMediaPlayer(mediaPlayer: media.AVPlayer): void {
    if (this.isLocal) {
      // 切换源前先关闭上一次打开的本地文件，避免文件描述符累积泄漏
      this.closeOpenedFile();
      let fdPath = 'fd://';
      // 打开相应的资源文件地址获取fd，并为url赋值触发initialized状态机上报
      let file = fs.openSync(this.url);
      fdPath = fdPath + '' + file.fd;
      try {
        mediaPlayer.url = fdPath;
        this.openedFile = file
      } catch (e) {
        // 设置 url 失败时关闭已打开的文件描述符，避免泄漏
        fs.closeSync(file);
        throw new Error('Failed to set local media source: ' + e.message);
      }
    } else {
      mediaPlayer.url = this.url;
    }
  }

  /**
   * 关闭本地源打开的文件描述符。应在 AVPlayer 不再需要该 fd（release/reset 之后）时调用。
   * 非本地源或已关闭则为空操作，可重复调用。
   */
  closeOpenedFile(): void {
    if (this.openedFile != null) {
      try {
        fs.closeSync(this.openedFile)
      } catch (e) {
        // 忽略重复关闭或已失效的 fd，避免影响主流程
      }
      this.openedFile = null
    }
  }

  async setForSoundPool(soundPoolPlayer: SoundPoolPlayer): Promise<void> {
    await soundPoolPlayer.setUrlSource(this);
  }

  getAudioPathForSoundPool(context: Context): Promise<string> {
    return new Promise<string>((resolve, reject) => {
      try {
        if (this.isLocal) {
          let file = fs.openSync(this.url);
          this.soundPoolOpenedFiles.push(file)
          resolve('fd://' + file.fd)
        } else {
          let tempFile = context.tempDir + '/sound_' + Date.now() + '.data'
          this.soundPoolTempPath = tempFile
          if (fs.accessSync(tempFile)) {
            try {
              fs.unlinkSync(tempFile)
            } catch (_) {
              // ignore stale temp cleanup errors
            }
          }
          request.downloadFile(context, {
            url: this.url,
            filePath: tempFile
          }).then((downloadTask: request.DownloadTask) => {
            if (this.disposed) {
              try {
                downloadTask.delete()
              } catch (_) {
                // ignore
              }
              reject(new Error('UrlSource already disposed'))
              return
            }
            this.downloadTask = downloadTask
            this.downloadCompleteCallback = () => {
              if (this.disposed) {
                return
              }
              try {
                let file = fs.openSync(tempFile);
                this.soundPoolOpenedFiles.push(file)
                resolve('fd://' + file.fd)
              } catch (e) {
                reject(new Error(`Failed to open downloaded file: ${(e as Error).message}`))
              } finally {
                this.clearDownloadListeners()
              }
            }
            this.downloadFailCallback = (err: number) => {
              this.cleanupSoundPoolTemp()
              this.clearDownloadListeners()
              reject(new Error(`Download failed: ${err}`))
            }
            downloadTask.on('complete', this.downloadCompleteCallback)
            downloadTask.on('fail', this.downloadFailCallback)
          }).catch((e: Error) => {
            this.cleanupSoundPoolTemp()
            reject(new Error(`Failed to start download: ${e.message}`))
          })
        }
      } catch (e) {
        reject(new Error(`Failed to get audio path: ${(e as Error).message}`))
      }
    })
  }

  /** 关闭 SoundPool 占用的 fd，并清理远端下载的临时文件 / 取消下载监听 */
  closeSoundPoolResources(): void {
    this.disposed = true
    this.cancelDownloadTask()
    for (let i = 0; i < this.soundPoolOpenedFiles.length; i++) {
      try {
        fs.closeSync(this.soundPoolOpenedFiles[i])
      } catch (_) {
        // ignore
      }
    }
    this.soundPoolOpenedFiles = []
    this.cleanupSoundPoolTemp()
  }

  private clearDownloadListeners(): void {
    if (this.downloadTask != null) {
      try {
        if (this.downloadCompleteCallback != null) {
          this.downloadTask.off('complete', this.downloadCompleteCallback)
        } else {
          this.downloadTask.off('complete')
        }
      } catch (_) {
        // ignore
      }
      try {
        if (this.downloadFailCallback != null) {
          this.downloadTask.off('fail', this.downloadFailCallback)
        } else {
          this.downloadTask.off('fail')
        }
      } catch (_) {
        // ignore
      }
    }
    this.downloadCompleteCallback = null
    this.downloadFailCallback = null
  }

  private cancelDownloadTask(): void {
    this.clearDownloadListeners()
    if (this.downloadTask != null) {
      try {
        this.downloadTask.delete()
      } catch (_) {
        // ignore cancel errors
      }
      this.downloadTask = null
    }
  }

  private cleanupSoundPoolTemp(): void {
    if (this.soundPoolTempPath != null) {
      try {
        if (fs.accessSync(this.soundPoolTempPath)) {
          fs.unlinkSync(this.soundPoolTempPath)
        }
      } catch (_) {
        // ignore
      }
      this.soundPoolTempPath = null
    }
  }
}
