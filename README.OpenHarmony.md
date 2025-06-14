> Template version: v0.0.1

<p align="center">
  <h1 align="center"> <code>audioplayers</code> </h1>
</p>

This project is based on [audioplayers](https://pub.dev/packages/audioplayers).

## 1. Installation and Usage

### 1.1 Installation

Go to the project directory and add the following dependencies in pubspec.yaml

<!-- tabs:start -->

#### pubspec.yaml

```yaml
---
dependencies:
  audioplayers:
    git:
      url: https://gitcode.com/openharmony-sig/flutter_audioplayers.git
      path: packages/audioplayers
      ref: br_audioplayers-v6.1.0_ohos
```

Execute Command

```bash
flutter pub get
```

<!-- tabs:end -->

### 1.2 Usage

For use cases [ohos/example](./packages/audioplayers/example/lib/main.dart)

## 2. Constraints

### 2.1 Compatibility

This document is verified based on the following versions:

1. Flutter: 3.7.12-ohos-1.0.6; SDK: 5.0.0(12); IDE: DevEco Studio: 5.0.13.200; ROM: 5.1.0.120 SP3;
2. Flutter: 3.22.1-ohos-1.0.1; SDK: 5.0.0(12); IDE: DevEco Studio: 5.0.13.200; ROM: 5.1.0.120 SP3;

## 3. Properties

> [!TIP] If the value of **ohos Support** is **yes**, it means that the ohos platform supports this property; **no** means the opposite; **partially** means some capabilities of this property are supported. The usage method is the same on different platforms and the effect is the same as that of iOS or Android.

| Name               | Description                       | Type     | Input            | Output            | ohos Support |
| ------------------ | --------------------------------- | -------- | ---------------- | ----------------- | ------------ |
| getDuration        | Get total duration                | function | /                | Future<Duration?> | yes          |
| getCurrentPosition | Get the current playback position | function | /                | Future<Duration?> | yes          |
| setPlayerMode      | Set the playback mode             | function | PlayerMode mode  | Future<void>      | yes          |
| setAudioContext    | Set playback parameters           | function | AudioContext ctx | Future<void>      | yes          |

## 4. API

> [!TIP] If the value of **ohos Support** is **yes**, it means that the ohos platform supports this property; **no** means the opposite; **partially** means some capabilities of this property are supported. The usage method is the same on different platforms and the effect is the same as that of iOS or Android.

| Name            | Description                            | Type      | Input                               | Output       | ohos Support |
| --------------- | -------------------------------------- | --------- | ----------------------------------- | ------------ | ------------ |
| setSourceUrl    | Set the url playback source            | string    | String url, {String? mimeType}      | Future<void> | yes          |
| setSourceBytes  | Set the byte stream source             | uint8List | Uint8List bytes, {String? mimeType} | Future<void> | yes          |
| resume          | Resume paused playback                 | function  | /                                   | Future<void> | yes          |
| pause           | Pause playback                         | function  | /                                   | Future<void> | yes          |
| stop            | Stop Playing                           | function  | /                                   | Future<void> | yes          |
| seek            | Jump to the specified position         | function  | Duration position                   | Future<void> | yes          |
| setVolume       | Setting the volume                     | function  | double volume                       | Future<void> | yes          |
| setBalance      | Set the left and right channel balance | function  | double balance                      | Future<void> | yes          |
| setPlaybackRate | Set the playback rate                  | function  | double playbackRate                 | Future<void> | yes          |
| release         | Release player resources               | function  | /                                   | Future<void> | yes          |
| dispose         | Destroy the player instance            | function  | /                                   | Future<void> | yes          |

## 5. Known Issues

## 6. Others

In ohos, the parameters supported by setAudioContext are isSpeakerphoneOn, rendererFlags, audioScene, usageType, stayAwake.

## 7. License

This project is licensed under [The MIT License (MIT)](./LICENSE).
