
// Copyright (c) 2025 Huawei Device Co., Ltd.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE_HW file.
// Based on Camera.java originally written by
// Copyright 2013 The Flutter Authors.
 
 export enum PlayerMode {
  MEDIA_PLAYER = 1,
  LOW_LATENCY = 2
}

export const parsePlayerMode = (mode: string) => {
  if (mode == "PlayerMode.lowLatency") {
    return PlayerMode.LOW_LATENCY
  }
  return PlayerMode.MEDIA_PLAYER;
}