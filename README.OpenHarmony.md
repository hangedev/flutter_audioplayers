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
...

dependencies:
  audioplayers:
    git:
      url: https://gitcode.com/CPF-Flutter/flutter_audioplayers.git
      path: packages/audioplayers
      # ref: Select the TAG version that matches your Flutter framework version from the table below
      ref: TAG  # Select a TAG from the TAG version mapping table below
...
```

Execute Command

```bash
flutter pub get
```

#### Version Mapping

| Flutter Framework Version | TAG Name | Branch Name |
| --------------- | ----------------------- | ------ |
| 3.22            | 6.1.0-ohos-1.0.1        | br_audioplayers-v6.1.0_ohos  |

<!-- tabs:end -->

### 1.2 Usage

Import the library, create a player, and play a source:

```dart
import 'package:audioplayers/audioplayers.dart';

final player = AudioPlayer();

// Play a remote URL source.
await player.play(UrlSource('https://example.com/audio.mp3'));

// Or play a local asset (declared in pubspec.yaml assets).
await player.play(AssetSource('audio/sample.mp3'));

// Control playback.
await player.pause();
await player.resume();
await player.stop();
await player.seek(const Duration(seconds: 5));

// Release resources when done.
await player.dispose();
```

For more complete usage examples, see [ohos/example](./packages/audioplayers/example/lib/main.dart).

## 2. Constraints

### 2.1 Compatibility

This document is verified based on the following versions:

Flutter: 3.22.1-ohos-1.0.1; SDK: 5.0.0(12); IDE: DevEco Studio: 5.0.13.200; ROM: 5.1.0.120 SP3;

### 2.2 OHOS Development Environment

To build and run on HarmonyOS, prepare the following toolchain:

- Install **DevEco Studio** (verified version: 5.0.13.200) and start it once so that the bundled **OHOS SDK** (API 12 / 5.0.0) and **ohpm** package manager are registered.
- Install **Flutter OHOS edition** (verified version: 3.22.1-ohos-1.0.1) and confirm it is on PATH: `flutter --version`.
- Make sure `ohpm` and `hvigorw` are available. If `ohpm` is not found, add `<DevEco>/tools/ohpm/bin` to your PATH.
- Build the example app from its own directory (the `example/` folder contains the OHOS platform project under `example/ohos/`):

```bash
cd example
flutter pub get
flutter build hap --debug
```

- Disable the hvigor daemon for deterministic builds by setting `"execution": { "daemon": false }` in `example/ohos/hvigor/hvigor-config.json5`.

### 2.3 Permission Requirements

#### 2.3.1 Add permissions to the module.json5 file in the entry directory.

Open `entry/src/main/module.json5` and add the following information:

```diff
...
"abilities": [
    {
+     "backgroundModes": [
+        "audioPlayback"
+     ],
    }
],
...
"requestPermissions": [
+  {
+    "name": "ohos.permission.KEEP_BACKGROUND_RUNNING",
+    "reason": "$string:background_running_reason",
+    "usedScene": {
+      "abilities": [
+        "EntryAbility"
+      ],
+      "when":"inuse"
+    }
+  }
]
```

#### 2.3.2 Add the reason for applying for the above permissions in string.json in the entry directory.

Open `entry/src/main/resources/base/element/string.json` and add the following information:

```diff
...
{
  "string": [
+    {
+      "name": "background_running_reason",
+      "value": "background_running_reason"
+    }
  ]
}
```

## 3. API

> [!TIP] If the value of **ohos Support** is **yes**, it means that the ohos platform supports this property; **no** means the opposite; **partially** means some capabilities of this property are supported. The usage method is the same on different platforms and the effect is the same as that of iOS or Android.

| Name               | Description                            | Type      | Input                               | Output            | ohos Support |
| ------------------ | -------------------------------------- | --------- | ----------------------------------- | ----------------- | ------------ |
| setSourceUrl       | Set the url playback source            | string    | String url, {String? mimeType}      | Future<void>      | yes          |
| setSourceBytes     | Set the byte stream source             | uint8List | Uint8List bytes, {String? mimeType} | Future<void>      | yes          |
| resume             | Resume paused playback                 | function  | /                                   | Future<void>      | yes          |
| pause              | Pause playback                         | function  | /                                   | Future<void>      | yes          |
| stop               | Stop Playing                           | function  | /                                   | Future<void>      | yes          |
| seek               | Jump to the specified position         | function  | Duration position                   | Future<void>      | yes          |
| setVolume          | Setting the volume                     | function  | double volume                       | Future<void>      | yes          |
| setBalance         | Set the left and right channel balance | function  | double balance                      | Future<void>      | yes          |
| setPlaybackRate    | Set the playback rate                  | function  | double playbackRate                 | Future<void>      | yes          |
| release            | Release player resources               | function  | /                                   | Future<void>      | yes          |
| dispose            | Destroy the player instance            | function  | /                                   | Future<void>      | yes          |
| getDuration        | Get total duration                     | function  | /                                   | Future<Duration?> | yes          |
| getCurrentPosition | Get the current playback position      | function  | /                                   | Future<Duration?> | yes          |
| setPlayerMode      | Set the playback mode                  | function  | PlayerMode mode                     | Future<void>      | yes          |
| setAudioContext    | Set playback parameters                | function  | AudioContext ctx                    | Future<void>      | yes          |

## 4. Properties

### setAudioContext Parameters

`AudioContext` carries an `ohos` field of type `AudioContextOhos`, which configures OHOS-specific audio rendering attributes. You can build one conveniently via `AudioContextConfig().buildOhos()`.

> [!TIP] If the value of **ohos Support** is **yes**, it means that the ohos platform supports this property; **no** means the opposite; **partially** means some capabilities of this property are supported. The usage method is the same on different platforms and the effect is the same as that of iOS or Android.

| Name               | Description      | Type     | Default     | ohos Support |
| ------------------ | ---------------- | -------- | ----------- | ------------ |
| isSpeakerphoneOn  | Whether the speakerphone output route is forced on. Note: the OHOS default is `true`, which differs from Android (default `false`). | boolean | true  | yes          |
| audioScene        | The audio scene, which influences audio routing and focus behavior. See `OhosAudioScene`. | OhosAudioScene | normal | yes          |
| rendererFlags     | Audio renderer flags. `0` = normal renderer, `1` = low-latency renderer. **Low-latency rendering is not yet supported by the ArkTS API**, so only `0` is effective. | number | 0 | yes          |
| usageType         | The audio usage type ("why" the sound is played), used by the system for routing and volume decisions. See `OhosUsageType`. | OhosUsageType | music | yes          |
| stayAwake         | Whether to keep the device awake (run a background task + keep the screen on) during playback. Requires the background permission from section 2.3. | boolean | true  | yes          |

#### OhosUsageType

Defines the audio usage type passed to `usageType`. Values and their underlying numeric codes:

| Enum value          | Code | Description |
| ------------------- | ---- | ----------- |
| unknown             | 0    | Unknown usage |
| music               | 1    | Media or music (default) |
| voiceCommunication  | 2    | Telephony or VoIP |
| voiceAssistant      | 3    | Voice assistant broadcast |
| alarm               | 4    | Alarm (e.g. wake-up) |
| voiceMessage        | 5    | Voice message |
| ringtone            | 6    | Notification or ringtone |
| notification        | 7    | Notification |
| accessibility       | 8    | Accessibility (e.g. screen reader) |
| moive               | 10   | Movie audio |
| game                | 11   | Game audio |
| audiobook           | 12   | Audiobook audio |
| navigation          | 13   | Navigation |

#### OhosAudioScene

Defines the audio scene passed to `audioScene`:

| Enum value | Code | Description |
| ---------- | ---- | ----------- |
| normal     | 0    | Default audio scene (default) |
| ringing    | 1    | Ringing mode |
| phoneCall  | 2    | Phone call mode |
| voiceChat  | 3    | Voice chat mode |

## 5. Known Issues

- **Low-latency playback**: `rendererFlags = 1` (low-latency renderer) is defined for forward compatibility, but the ArkTS audio API does not yet support low-latency rendering. Setting it to `1` has no effect; use `0`.
- **`setAudioContext` global effect**: On OHOS there is no public API equivalent to Android's `AudioManager.mode` / `isSpeakerphoneOn`. `setAudioContext` is recorded but only `usageType` and `rendererFlags` are applied to the renderer attributes.
- **`seek` on low-latency mode**: Seeking is not supported in `PlayerMode.lowLatency` (SoundPool), consistent with the upstream limitation.

## 6. Others

### Migration from upstream audioplayers

This OHOS fork keeps the public Dart API of `audioplayers` unchanged, so existing application code (import paths, `AudioPlayer`, `UrlSource`, `AssetSource`, etc.) works without modification. To migrate:

1. Replace the `audioplayers` dependency in `pubspec.yaml` with the OHOS git dependency from section 1.1.
2. Run `flutter pub get`.
3. Add the OHOS background permission to `module.json5` (section 2.3) if you use `stayAwake` / background playback.
4. If you customize `AudioContext`, use the OHOS fields (`usageType`, `audioScene`, `isSpeakerphoneOn`, `rendererFlags`, `stayAwake`) instead of the Android-only fields.

## 7. License

This project is licensed under [The MIT License (MIT)](./LICENSE).
