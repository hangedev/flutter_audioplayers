// Copyright (c) 2025 Huawei Device Co., Ltd.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE_HW file.
// Based on Camera.java originally written by
// Copyright 2013 The Flutter Authors.
 
import SoundPoolPlayer from '../player/SoundPoolPlayer';
import Source from './Source';
import media from '@ohos.multimedia.media';

export default class BytesSource implements Source {
  private bytes: ArrayBuffer

  constructor(bytes: ArrayBuffer) {
    this.bytes = bytes;
  }

  setForMediaPlayer(mediaPlayer: media.AVPlayer): void {
    let src: media.AVDataSrcDescriptor = {
      fileSize: this.bytes.byteLength,
      callback: (buf: ArrayBuffer, length: number, pos: number | undefined) => {
        if (buf == undefined || length == undefined || pos == undefined) {
          return -1;
        }
        if (pos >= src.fileSize) {
          return -1
        }
        let remainingSize = this.computeRemainingSize(length, pos);
        if (remainingSize < 0) {
          return -1;
        }
        const view = new Uint8Array(buf);
        const dataToCopy = this.bytes.slice(pos, pos + remainingSize);
        const dataView = new Uint8Array(dataToCopy);
        // 复制数据到ArrayBuffer
        view.set(dataView);

        if (remainingSize > 0 && (src.fileSize >= pos)) {
          return remainingSize;
        }
        return -1;
      }
    }
    mediaPlayer.dataSrc = src
  }

  setForSoundPool(soundPoolPlayer: SoundPoolPlayer): void {
    throw new Error("Bytes sources are not supported on LOW_LATENCY mode yet.")
  }

  private computeRemainingSize(length: number, position: number): number {
    let remainingSize = length
    if (position + remainingSize > this.bytes.byteLength) {
      remainingSize -= position + remainingSize - this.bytes.byteLength
    }
    return remainingSize
  }
}