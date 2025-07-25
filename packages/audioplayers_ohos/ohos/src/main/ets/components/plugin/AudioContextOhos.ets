// Copyright (c) 2025 Huawei Device Co., Ltd.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE_HW file.
// Based on Camera.java originally written by
// Copyright 2013 The Flutter Authors.
 
import media from '@ohos.multimedia.media';
import audio from '@ohos.multimedia.audio';
import { Log } from '@ohos/flutter_ohos';

export default class AudioContextOhos {
  rendererFlags: number = 0;
  usageType: number = 1;
  isSpeakerphoneOn: boolean = true;
  audioScene: number = 0;
  stayAwake: boolean = false;

  copy(): AudioContextOhos {
    let context = new AudioContextOhos()
    context.rendererFlags = this.rendererFlags;
    context.usageType = this.usageType;
    context.isSpeakerphoneOn = this.isSpeakerphoneOn;
    context.audioScene = this.audioScene;
    context.stayAwake = this.stayAwake;
    return context;
  }

  setAttributesOnPlayer(mediaPlayer: media.AVPlayer) {
    mediaPlayer.audioRendererInfo = {
      content: 2,
      usage: this.usageType, rendererFlags: this.rendererFlags
    }
  }

  buildAttributes(): audio.AudioRendererInfo {
    return {
      content: 2,
      usage: this.usageType,
      rendererFlags: this.rendererFlags
    }
  }

  equals(context: AudioContextOhos) {
    return context.rendererFlags == this.rendererFlags && context.usageType == this.usageType;
  }
}