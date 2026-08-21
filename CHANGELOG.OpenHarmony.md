## v6.1.0-ohos-1.0.1 - 2026.8

### Added

- Added audio focus interrupt handling for media player (`AVPlayer`): pause on interrupt, stop on focus loss, and auto-resume when focus is restored. ([#76](https://gitcode.com/CPF-Flutter/flutter_audioplayers/pull/76))

### Changed

- Changed the `AudioContextOhos.stayAwake` default from `false` to `true` to match the Dart layer. ([#76](https://gitcode.com/CPF-Flutter/flutter_audioplayers/pull/76))
- Changed `getDuration` and `getCurrentPosition` to return `null` when the value is unknown, instead of `0`. ([#76](https://gitcode.com/CPF-Flutter/flutter_audioplayers/pull/76))
- Changed low-latency (`SoundPool`) `seek` to throw an unsupported-operation error instead of silently ignoring the call. ([#76](https://gitcode.com/CPF-Flutter/flutter_audioplayers/pull/76))

### Fixed

- Fixed resource leaks on engine detach by stopping the background task, clearing MethodChannel handlers, and disposing players, SoundPool, and the event sink. ([#76](https://gitcode.com/CPF-Flutter/flutter_audioplayers/pull/76))
- Fixed unbounded player cache growth by capping the cache at 128 and evicting the oldest player. ([#76](https://gitcode.com/CPF-Flutter/flutter_audioplayers/pull/76))
- Fixed local file playback errors by checking file existence first and returning `File not found`. ([#76](https://gitcode.com/CPF-Flutter/flutter_audioplayers/pull/76))
- Fixed `setSourceUrl` hanging on `text/*` sources by returning a MethodChannel error instead of only emitting an event. ([#76](https://gitcode.com/CPF-Flutter/flutter_audioplayers/pull/76))
- Fixed invalid volume and balance values by clamping volume to `[0, 1]` and balance to `[-1, 1]`. ([#76](https://gitcode.com/CPF-Flutter/flutter_audioplayers/pull/76))
- Fixed file-descriptor leaks by tracking and closing fds when replacing or releasing a `UrlSource`. ([#76](https://gitcode.com/CPF-Flutter/flutter_audioplayers/pull/76))
- Fixed cold-start `prepared` event loss by waiting until `AVPlayer` reaches the `prepared` state before completing `prepare`. ([#76](https://gitcode.com/CPF-Flutter/flutter_audioplayers/pull/76))
- Fixed `AVPlayer` listener leaks by unregistering callbacks on `release`. ([#76](https://gitcode.com/CPF-Flutter/flutter_audioplayers/pull/76))
- Fixed `AudioContext` updates being skipped by comparing all fields in `equals`. ([#76](https://gitcode.com/CPF-Flutter/flutter_audioplayers/pull/76))
- Fixed `SoundPoolPlayer.setAudioContext` never recreating the pool because it compared the context with itself. ([#76](https://gitcode.com/CPF-Flutter/flutter_audioplayers/pull/76))
- Fixed `setSource` race conditions by awaiting `setSource`/`prepare` and rolling back player state on failure. ([#76](https://gitcode.com/CPF-Flutter/flutter_audioplayers/pull/76))
- Fixed `stop` in `ReleaseMode.STOP` and `ReleaseMode.LOOP` so the player pauses and seeks to 0 instead of releasing resources. ([#76](https://gitcode.com/CPF-Flutter/flutter_audioplayers/pull/76))
- Fixed remote `SoundPool` download failures being treated as success, and cleaned up temp files and `DownloadTask` listeners. ([#76](https://gitcode.com/CPF-Flutter/flutter_audioplayers/pull/76))
- Fixed `OhosAudioError` codes so they include the MethodChannel method name. ([#76](https://gitcode.com/CPF-Flutter/flutter_audioplayers/pull/76))
- Fixed `AudioContextConfig.buildOhos` mapping `isSpeakerphoneOn` from `route == speaker` instead of `forceSpeaker`. ([#76](https://gitcode.com/CPF-Flutter/flutter_audioplayers/pull/76))
- Fixed a circular reference in the `BytesSource` `AVDataSrcDescriptor` callback. ([#76](https://gitcode.com/CPF-Flutter/flutter_audioplayers/pull/76))
- Fixed `startContinuousTask` crashing when `abilityBinding` is null. ([#76](https://gitcode.com/CPF-Flutter/flutter_audioplayers/pull/76))
- Fixed `FocusManager` circular references by adding `dispose`. ([#76](https://gitcode.com/CPF-Flutter/flutter_audioplayers/pull/76))
- Fixed `SoundPool` `loadComplete` accessing a player that was already released. ([#76](https://gitcode.com/CPF-Flutter/flutter_audioplayers/pull/76))
