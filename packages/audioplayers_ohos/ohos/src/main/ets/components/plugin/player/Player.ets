// Copyright (c) 2025 Huawei Device Co., Ltd.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE_HW file.
// Based on Camera.java originally written by
// Copyright 2013 The Flutter Authors.
 
import AudioContextOhos from '../AudioContextOhos'
import Source from '../source/Source'

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

  setSource(source: Source): void;

  prepare(): void;

  reset(): void;
}
