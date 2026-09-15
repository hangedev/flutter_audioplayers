## 6.5.1-ohos-1.0.1 - 2026.9

### Fixed
* Resolve sibling `audioplayers_*` packages from pub version constraints (and local `path` for `audioplayers_ohos`) instead of git, so `flutter pub get` no longer clones this repository and fails on missing Git LFS objects. ([!84](https://gitcode.com/CPF-Flutter/flutter_audioplayers/merge_requests/84))
* Remove unused legacy OHOS example scaffold file `example/ohos/dta/icudtl.dat` and its Git LFS tracking to fix clone/checkout failures when the remote LFS object is missing. ([!81](https://gitcode.com/CPF-Flutter/flutter_audioplayers/merge_requests/81))
* Complete MethodChannel success/error replies for global and player calls, and return `MethodResult.error` for non-playable `text/*` sources instead of hanging the Dart Future. ([!75](https://gitcode.com/CPF-Flutter/flutter_audioplayers/merge_requests/75))
* Make `onDetachedFromEngine` tear down continuous tasks, AVSession, players, FocusManager, and channel handlers asynchronously with epoch guards to avoid races and resource leaks. ([!75](https://gitcode.com/CPF-Flutter/flutter_audioplayers/merge_requests/75))
* Unsubscribe AVPlayer event listeners via `off()`, clear BytesSource `dataSrc` callbacks, and close local UrlSource/SoundPool file descriptors on release/reset/source switch. ([!75](https://gitcode.com/CPF-Flutter/flutter_audioplayers/merge_requests/75))
* Await `setSource`/`prepare` until AVPlayer reaches the `prepared` state to avoid cold-start races and premature MethodChannel completion. ([!75](https://gitcode.com/CPF-Flutter/flutter_audioplayers/merge_requests/75))
* Harden FocusManager with lazy AudioSessionManager init, try-catch focus callbacks, dispose cleanup, and snapshot iteration over subscribed players. ([!75](https://gitcode.com/CPF-Flutter/flutter_audioplayers/merge_requests/75))
* Validate player creation (max 32), `audioFocus` range, and URL arguments before calling native APIs. ([!75](https://gitcode.com/CPF-Flutter/flutter_audioplayers/merge_requests/75))
* Fix SoundPool source cache dispose, continuous-task start/stop epoch races, and playing/prepared state consistency after start or setSource failures. ([!75](https://gitcode.com/CPF-Flutter/flutter_audioplayers/merge_requests/75))
* Point `path_provider` at the CPF-Flutter OHOS-adapted git dependency with ref `provider-v2.1.5-ohos-1.0.0`. ([!75](https://gitcode.com/CPF-Flutter/flutter_audioplayers/merge_requests/75))
* Override transitive `win32` to `5.5.4` so OHOS Flutter (Dart language ≤ 3.6) can resolve `file_picker_ohos` without language-version / `UnmodifiableUint8ListView` build failures. ([!75](https://gitcode.com/CPF-Flutter/flutter_audioplayers/merge_requests/75))

## 6.5.1-ohos-1.0.0

* TAG 6.5.1-ohos-1.0.0.