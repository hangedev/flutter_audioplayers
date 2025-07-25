// Copyright (c) 2025 Huawei Device Co., Ltd.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE_HW file.
// Based on Camera.java originally written by
// Copyright 2013 The Flutter Authors.
 
import media from '@ohos.multimedia.media';
import SoundPoolPlayer from '../player/SoundPoolPlayer';

export default interface Source {
  setForMediaPlayer(mediaPlayer: media.AVPlayer): void;

  setForSoundPool(soundPoolPlayer: SoundPoolPlayer): void;
}