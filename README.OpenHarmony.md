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

dependencies:
  audioplayers:
    git:
      url: https://gitcode.com/CPF-Flutter/flutter_audioplayers.git
      path: packages/audioplayers
      # ref: Select the TAG version that matches your Flutter framework version from the table below
      ref: TAG  # Select a TAG from the TAG version mapping table below
```
### TAG Version Mapping Table

| Flutter Framework Version | TAG Name | Branch Name |
| --------------- | ----------------------- | ------ |
| 3.7             | 4.1.0-ohos-1.0.0-beta.1 | master |
| 3.22            | 6.1.0-ohos-1.0.1        | br_audioplayers-v6.1.0_ohos |
| 3.27            | 6.5.1-ohos-1.0.1        | br_v6.5.1_ohos               |
| 3.35            | 6.5.1-ohos-1.0.1        | br_v6.5.1_ohos               |

Execute Command

```bash
flutter pub get
```

<!-- tabs:end -->

### 1.2 OHOS Environment Setup

Before using this plugin, set up the HarmonyOS development environment:

1. **Install DevEco Studio**: Download and install DevEco Studio (5.1.0 or later) from the [HarmonyOS official site](https://developer.huawei.com/consumer/cn/deveco-studio/).
2. **Configure the SDK**: Install the HarmonyOS SDK (API 12 or later) via `File > Settings > HarmonyOS SDK`, and configure the `ohpm` and `hvigor` toolchains.
3. **Install the Flutter OHOS branch**: Follow [OpenHarmony Flutter](https://gitcode.com/openharmony-sig/flutter_flutter) to install an OHOS-capable Flutter branch (3.27.5-ohos-0.0.1 or later).
4. **Verify the toolchain**: Run `flutter doctor` and `ohpm -v` to confirm `flutter`, `ohpm`, and `hvigor` are on your PATH.
5. **Build configuration**: In `example/ohos/hvigor/hvigor-config.json5`, ensure `"execution": { "daemon": false }` for deterministic builds, then run `flutter build hap --debug` in the `example/` directory to verify.

**SDK / Flutter version mapping**:

| Flutter Framework Version | OHOS SDK Version (API) | DevEco Studio (verified) |
| ------------------------- | ---------------------- | ------------------------ |
| 3.22 / 3.27               | 5.0.0 (API 12)         | 5.1.0.828                |
| 3.35                      | 6.0.1 (API 21)         | 6.0.1.260                |

- `ohpm` setup: after installing DevEco Studio, `ohpm` is located at `<DevEco install dir>/tools/ohpm/bin`. Add it to PATH if the command is not found, or configure it via `File > Settings > Ohpm`.
- `hvigor` setup: prefer the build chain bundled with the Flutter OHOS branch / project scaffold (`example/ohos/hvigor/wrapper`); a global hvigor install is not required.
- Troubleshooting: if SDK download fails, switch the DevEco Studio proxy or mirror; if `ohpm install` fails, run `ohpm config set registry https://ohpm.openharmony.cn/ohpm/`.

### 1.3 Version Migration

When upgrading from older versions (4.1.0-ohos / 6.1.0-ohos) to 6.5.1-ohos:

- Update the `ref` in pubspec.yaml to `6.5.1-ohos-1.0.0` and switch the branch to `br_v6.5.1_ohos`.
- Older versions are not fully API-compatible; update business code that calls `AudioContext`, `setAudioContext`, etc.
- Run `flutter build hap --debug` in the `example/` directory before upgrading to verify the new version compiles.

**Key API changes (old → 6.5.1-ohos)**:

| Change | 4.1.0-ohos / 6.1.0-ohos | 6.5.1-ohos |
| ------ | ----------------------- | ---------- |
| AudioContext construction | Requires android/iOS params | Supports the `ohos` named param (`AudioContextOhos`) |
| setAudioContext | Player-level only | Player-level + `AudioPlayer.global.setAudioContext` (global, partially applied) |
| Event streams | onDurationChanged / onPlayerComplete | Adds the onLog log stream |

Migration example (AudioContext call update):

```dart
// Old
final ctx = AudioContext(android: AudioContextAndroid(...));

// 6.5.1-ohos: use the ohos named param directly
final ctx = AudioContext(
  ohos: AudioContextOhos(
    usageType: OhosUsageType.music,
    stayAwake: true,
  ),
);
await player.setAudioContext(ctx);
```

### 1.4 Usage

For use cases [ohos/example](./packages/audioplayers/example/lib/main.dart)

Core usage example:

```dart
import 'package:audioplayers/audioplayers.dart';

final player = AudioPlayer();

// Set the playback source (network or local URL)
await player.setSourceUrl('https://example.com/audio.mp3', isLocal: false);

// Play, pause, stop
await player.resume();
await player.pause();
await player.stop();

// Set volume (0.0 ~ 1.0), channel balance (-1.0 ~ 1.0), playback rate (>0)
await player.setVolume(0.8);
await player.setBalance(0.0);
await player.setPlaybackRate(1.0);

// Listen to streams for state, position, completion, etc.
player.onPlayerStateChanged.listen((state) { /* ... */ });
player.onPositionChanged.listen((pos) { /* ... */ });
player.onPlayerComplete.listen((_) { /* ... */ });

// Release resources
await player.release();
await player.dispose();
```

AudioCache example:

```dart
// Load assets into the cache (default prefix: assets/)
final cache = AudioCache(prefix: 'assets/audio/');
final uri = await cache.load('beep.mp3');             // single load
final uris = await cache.loadAll(['a.mp3', 'b.mp3']); // batch load
final bytes = await cache.loadAsBytes('beep.mp3');    // bytes load

// Clear the cache
await cache.clear('beep.mp3');  // single entry
await cache.clearAll();         // everything
```

AudioPool example (low-latency overlapping playback):

```dart
// Create a pool for rapid overlapping playback of the same asset
final pool = await AudioPool.createFromAsset(
  path: 'assets/audio/beep.mp3',
  maxPlayers: 3,   // at most 3 players kept in the pool
);

// start() returns a stop handle (StopFunction)
final stop = await pool.start(volume: 1.0);
// ... call start() multiple times for overlapping playback
await stop();      // stop and return the player to the pool

// Dispose when done
await pool.dispose();
```

Low-latency mode example:

```dart
// PlayerMode.lowLatency maps to SoundPool, suited to short sound effects
await player.setPlayerMode(PlayerMode.lowLatency);
await player.play(AssetSource('audio/beep.mp3'));
```

## 2. Constraints

### 2.1 Compatibility

This document is verified based on the following versions:

Flutter: 3.27.5-ohos-0.0.1; SDK: 5.0.0(12); IDE: DevEco Studio: 5.1.0.828; ROM: 5.1.0.130 SP8;
Flutter: 3.35.7-ohos-0.0.1; SDK: 6.0.1(21); IDE: DevEco Studio: 6.0.1.260; ROM: 6.0.0.120 SP6;

### 2.2 Permission Requirements

#### 2.2.1 Add permissions to the module.json5 file in the entry directory.

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

#### 2.2.2 Add the permission reason to string.json in the entry directory

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
| play               | Play audio (requests audio focus and starts the background task) | function | Source source, {double? volume, double? balance, AudioContext? ctx, Duration? position, PlayerMode? mode} | Future<void> | yes |
| setSourceUrl       | Set the url playback source            | string    | String url, {String? mimeType}      | Future<void>      | yes          |
| setSourceBytes     | Set the byte stream source             | uint8List | Uint8List bytes, {String? mimeType} | Future<void>      | yes          |
| setSource          | Set a generic playback source (DeviceFile/Asset) | function | Source source        | Future<void>      | yes          |
| setSourceDeviceFile| Set a device-local file playback source | function | DeviceFileSource source            | Future<void>      | yes          |
| setSourceAsset     | Set an asset playback source           | function  | AssetSource source                  | Future<void>      | yes          |
| resume             | Resume paused playback                 | function  | /                                   | Future<void>      | yes          |
| pause              | Pause playback                         | function  | /                                   | Future<void>      | yes          |
| stop               | Stop Playing                           | function  | /                                   | Future<void>      | yes          |
| seek               | Jump to the specified position         | function  | Duration position                   | Future<void>      | yes          |
| setVolume          | Setting the volume                     | function  | double volume                       | Future<void>      | yes          |
| setBalance         | Set the left and right channel balance | function  | double balance                      | Future<void>      | yes          |
| setPlaybackRate    | Set the playback rate                  | function  | double playbackRate                 | Future<void>      | yes          |
| setReleaseMode     | Set the release mode (STOP / LOOP / RELEASE) | function | ReleaseMode mode               | Future<void>      | yes          |
| release            | Release player resources               | function  | /                                   | Future<void>      | yes          |
| dispose            | Destroy the player instance            | function  | /                                   | Future<void>      | yes          |
| getDuration        | Get total duration                     | function  | /                                   | Future<Duration?> | yes          |
| getCurrentPosition | Get the current playback position      | function  | /                                   | Future<Duration?> | yes          |
| setPlayerMode      | Set the playback mode                  | function  | PlayerMode mode                     | Future<void>      | yes          |
| setAudioContext    | Set playback parameters                | function  | AudioContext ctx                    | Future<void>      | yes          |

### 3.1 Event Streams

> [!TIP] The HarmonyOS implementation supports event streams consistently with upstream, via `Stream` listeners for player/global events.

| Name                   | Description                          | ohos Support |
| ---------------------- | ------------------------------------ | ------------ |
| onPlayerStateChanged   | Player state change event stream     | yes          |
| onPositionChanged      | Playback position change event stream | yes         |
| onDurationChanged      | Duration change event stream         | yes          |
| onPlayerComplete       | Playback completion event stream     | yes          |
| onSeekComplete         | Seek completion event stream         | yes          |
| onLog                  | Log event stream                     | yes          |

### 3.2 Enumerations

| Enum           | Values                                | ohos Support |
| --------------- | ------------------------------------- | ------------ |
| PlayerMode      | mediaPlayer / lowLatency              | yes          |
| PlayerState     | stopped / playing / paused / completed | yes         |
| ReleaseMode     | release / stop / loop                 | yes          |
| OhosUsageType   | unknown(0) / music(1) / voiceCommunication(2) / voiceAssistant(3) / alarm(4) / voiceMessage(5) / ringtone(6) / notification(7) / accessibility(8) / moive(10) / game(11) / audiobook(12) / navigation(13) | yes |
| OhosAudioScene  | normal / ringing / phoneCall / voiceChat | yes      |
| AudioLogLevel   | none(0) / error(1) / info(2)           | yes          |
| AudioEventType  | log / duration / position / seekComplete / complete / prepared | yes |
| GlobalAudioEventType | log                             | yes          |

### 3.3 Upstream Public Classes

> [!TIP] The classes below are upstream `audioplayers` Dart APIs. Their OHOS behavior is consistent with upstream and is driven by the same MethodChannel/EventChannel bridge — no OHOS-specific divergence unless noted.

| Class / Category | Main Members | Description | ohos Support |
| ---------------- | ------------ | ----------- | ------------ |
| AudioCache       | load / loadPath / loadAsFile / loadAsBytes / loadAll / clear / clearAll / fileSystem / loadedFiles / prefix / singleInstance | Pre-loads and caches audio sources; resolves assets/URLs to a playable source. | yes |
| AudioPool        | create / createFromAsset / start / dispose / source / minPlayers / maxPlayers / audioCache / audioContext | Plays multiple overlapping instances of the same source (built on `PlayerMode.lowLatency` / SoundPool). `start()` returns a `StopFunction` handle. | yes |
| StopFunction     | (typedef) `Future<void> Function()` | The stop function returned by `AudioPool.start()`; calling it returns the player to the pool. | yes |
| GlobalAudioScope | ensureInitialized / setAudioContext / eventStream / onLog | Global scope helpers (`AudioPlayer.global`). `setAudioContext` is cached locally (system API limitation). | partially |
| AudioLogger      | logLevel / log / error / errorToString | Toggle/capture internal plugin logs; surfaced via the `onLog` event stream. | yes |
| Source (abstract) | setOnPlayer / mimeType | Playback source descriptor base class. | yes |
| UrlSource       | url / mimeType | URL playback source (network or local path). | yes |
| DeviceFileSource | path / mimeType | Device-local file playback source. | yes |
| AssetSource      | path / mimeType | Asset playback source. | yes |
| BytesSource      | bytes / mimeType | Byte-stream playback source. | yes |
| AudioPlayerException | player / cause | Player exception wrapper (associated player + cause). | yes |
| AudioEvent       | eventType / isPrepared / duration / position / seekComplete / logMessage / code / message | Player event (surfaced via `eventStream`). | yes |
| GlobalAudioEvent | eventType / logMessage / code / message | Global event (surfaced via `AudioPlayer.global.eventStream`). | yes |
| PositionUpdater  | start / stop / update / dispose / positionStream | Position updater abstract base driving `onPositionChanged`. | yes |
| TimerPositionUpdater | period / positionStream | Timer-based position updater implementation. | yes |
| FramePositionUpdater | (default implementation) | Frame-synced position updater (default). | yes |

### 3.4 Configuration & Context Classes

| Class | Main Members | Description | ohos Support |
| ----- | ------------ | ----------- | ------------ |
| AudioContext      | android / iOS / ohos / copy / toJson | Platform audio context aggregate; `toJson` serializes for the current platform. | yes |
| AudioContextOhos  | usageType / rendererFlags / stayAwake / audioFocus / isSpeakerphoneOn / audioScene / copy / toJson | OHOS audio context configuration. | yes |
| AudioContextConfig | route / focus / keyboardType / respectSystem / isSpeakerphoneOn | Generic audio context config (upstream common options, mapped onto each platform). | yes |
| AudioContextAndroid | usageType / audioFocus / contentType / mode / isSpeakerphoneOn / stayAwake / audioFocusGain / copy / toJson | Android config (no effect on OHOS; kept for upstream compatibility). | yes |
| AudioContextIOS   | category / options / copy / toJson | iOS config (no effect on OHOS; kept for upstream compatibility). | yes |

Configuration enums:

| Enum | Values | Description |
| ---- | ------ | ----------- |
| AudioContextConfigRoute  | system / earpiece / speaker | Audio route (system default / earpiece / speaker) |
| AudioContextConfigFocus  | gain / duckOthers / mixWithOthers | Focus strategy (maps to OHOS CONCURRENCY_DEFAULT / DUCK_OTHERS / MIX_WITH_OTHERS) |
| OhosUsageType            | unknown(0) / music(1) / voiceCommunication(2) / voiceAssistant(3) / alarm(4) / voiceMessage(5) / ringtone(6) / notification(7) / accessibility(8) / moive(10) / game(11) / audiobook(12) / navigation(13) | OHOS audio usage (`AudioContextOhos.usageType`) |
| OhosAudioScene           | normal / ringing / phoneCall / voiceChat | OHOS audio scene (`AudioContextOhos.audioScene`) |

## 4. Properties

### setAudioContext Parameters

> [!TIP] If the value of **ohos Support** is **yes**, it means that the ohos platform supports this property; **no** means the opposite; **partially** means some capabilities of this property are supported. The usage method is the same on different platforms and the effect is the same as that of iOS or Android.

| Name               | Description      | Type     | Input            | Output            | ohos Support |
| ------------------ | ---------------- | -------- | ---------------- | ----------------- | ------------ |
| rendererFlags    | Set playback parameters     | int | / | /      | yes          |
| usageType    | Define the audio usage type (maps to the OhosUsageType enum)     | OhosUsageType | / | /      | yes          |
| stayAwake    | Control whether to keep the device awake during playback     | boolean | / | /      | yes          |
| audioFocus    | Focus strategy (0: gain, 1: duckOthers, 2: mixWithOthers)     | int | / | /      | yes          |
| isSpeakerphoneOn    | Whether the speakerphone is on     | boolean | / | /      | yes          |
| audioScene    | Audio scene     | int | / | /      | yes          |

## 5. Known Issues / Platform Limitations (OHOS)

## 6. Others

For issues, refer to the upstream [troubleshooting.md](./troubleshooting.md) or report via an Issue. The HarmonyOS implementation lives under `packages/audioplayers_ohos/`; core ArkTS files include `AudioplayersPlugin.ets`, `WrappedPlayer.ets`, `MediaPlayerPlayer.ets`, `SoundPoolPlayer.ets`, and `FocusManager.ets`.

## 7. License

This project is licensed under [The MIT License (MIT)](./LICENSE).
