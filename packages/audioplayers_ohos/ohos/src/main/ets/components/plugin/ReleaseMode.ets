// Copyright (c) 2025 Huawei Device Co., Ltd.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE_HW file.
// Based on Camera.java originally written by
// Copyright 2013 The Flutter Authors.
 
export enum ReleaseMode {
  RELEASE = 1,
  LOOP = 2,
  STOP = 3
}

export const parseReleaseMode = (mode: string) => {
  if (mode == "ReleaseMode.stop") {
    return ReleaseMode.STOP
  } else if (mode == "ReleaseMode.loop") {
    return ReleaseMode.LOOP
  }
  return ReleaseMode.RELEASE;
}