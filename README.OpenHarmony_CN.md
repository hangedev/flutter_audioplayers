> 模板版本: v0.0.1

<p align="center">
  <h1 align="center"> <code>audioplayers</code> </h1>
</p>

本项目基于 [audioplayers](https://pub.dev/packages/audioplayers) 开发。

## 1. 安装与使用

### 1.1 安装方式

进入到工程目录并在 pubspec.yaml 中添加以下依赖：

<!-- tabs:start -->

#### pubspec.yaml

```yaml

dependencies:
  audioplayers:
    git:
      url: https://gitcode.com/CPF-Flutter/flutter_audioplayers.git
      path: packages/audioplayers
      # ref: 根据下方表格选择不同框架适配的TAG版本
      ref: TAG # 根据下方表格选择不同框架适配的TAG版本
```

### TAG 版本对应表

| Flutter 框架版本 | TAG 名称 | 分支名 |
| --------------- | ----------------------- | ------ |
| 3.7             | 4.1.0-ohos-1.0.0-beta.1 | master |
| 3.22            | 6.1.0-ohos-1.0.1        | br_audioplayers-v6.1.0_ohos |
| 3.27            | 6.5.1-ohos-1.0.1        | br_v6.5.1_ohos               |
| 3.35            | 6.5.1-ohos-1.0.1        | br_v6.5.1_ohos               |


执行命令

```bash
flutter pub get
```

<!-- tabs:end -->

### 1.2 OHOS 环境配置

使用本插件前，需先搭建 HarmonyOS 开发环境：

1. **安装 DevEco Studio**：从 [HarmonyOS 官网](https://developer.huawei.com/consumer/cn/deveco-studio/) 下载并安装 DevEco Studio（建议 5.1.0 及以上版本）。
2. **配置 SDK**：在 DevEco Studio 中通过 `File > Settings > HarmonyOS SDK` 安装 HarmonyOS SDK（API 12 及以上），并配置 `ohpm` 与 `hvigor` 工具链。
3. **安装 Flutter OHOS 分支**：参照 [OpenHarmony Flutter](https://gitcode.com/openharmony-sig/flutter_flutter) 安装支持 OHOS 的 Flutter 分支（3.27.5-ohos-0.0.1 及以上）。
4. **检查工具链**：执行 `flutter doctor` 与 `ohpm -v` 确认 `flutter`、`ohpm`、`hvigor` 均在 PATH 中。
5. **编译配置**：进入 `example/ohos/hvigor/hvigor-config.json5`，确保 `"execution": { "daemon": false }` 以保证构建确定性，随后在 `example/` 目录执行 `flutter build hap --debug` 进行验证。

**SDK 与 Flutter 版本对应关系**：

| Flutter 框架版本 | OHOS SDK 版本 (API) | DevEco Studio 版本（已验证） |
| ---------------- | ------------------- | ---------------------------- |
| 3.22 / 3.27      | 5.0.0 (API 12)      | 5.1.0.828                    |
| 3.35             | 6.0.1 (API 21)      | 6.0.1.260                    |

- `ohpm` 配置：DevEco Studio 安装后位于 `<DevEco 安装目录>/tools/ohpm/bin`，若命令行找不到 `ohpm`，请将该目录加入 PATH，或在 DevEco Studio 的 `File > Settings > Ohpm` 中配置。
- `hvigor` 配置：优先使用 Flutter OHOS 分支 / 工程脚手架自带构建链（`example/ohos/hvigor/wrapper`），无需单独安装全局 hvigor。
- 常见问题排查：SDK 下载失败可切换 DevEco Studio 代理或镜像源；`ohpm install` 失败可执行 `ohpm config set registry https://ohpm.openharmony.cn/ohpm/` 切换官方源。

### 1.3 版本迁移说明

从旧版本（4.1.0-ohos / 6.1.0-ohos）升级到 6.5.1-ohos 时：

- 更新 pubspec.yaml 中的 `ref` 为 `6.5.1-ohos-1.0.0`，并将分支切换到 `br_v6.5.1_ohos`。
- 旧版本之间 API 不完全兼容，升级后请同步更新业务代码中对 `AudioContext`、`setAudioContext` 等接口的调用方式。
- 升级前请在 `example/` 目录执行 `flutter build hap --debug` 验证新版本可正常编译运行。

**主要 API 变更对比（旧版 → 6.5.1-ohos）**：

| 变更点 | 4.1.0-ohos / 6.1.0-ohos | 6.5.1-ohos |
| ------ | ----------------------- | ---------- |
| AudioContext 构造 | 需同时传 android/iOS 参数 | 支持 `ohos` 命名参数（`AudioContextOhos`），仅传所需平台 |
| setAudioContext | 仅播放器级 | 播放器级 + `AudioPlayer.global.setAudioContext`（全局，部分透传） |
| 事件流 | onDurationChanged / onPlayerComplete | 新增 onLog 日志事件流 |

迁移示例（AudioContext 调用方式更新）：

```dart
// 旧版
final ctx = AudioContext(android: AudioContextAndroid(...));

// 6.5.1-ohos：直接使用 ohos 命名参数
final ctx = AudioContext(
  ohos: AudioContextOhos(
    usageType: OhosUsageType.music,
    stayAwake: true,
  ),
);
await player.setAudioContext(ctx);
```

### 1.4 使用案例

使用案例详见 [ohos/example](./packages/audioplayers/example/lib/main.dart)

核心调用示例：

```dart
import 'package:audioplayers/audioplayers.dart';

final player = AudioPlayer();

// 设置播放源（网络或本地 URL）
await player.setSourceUrl('https://example.com/audio.mp3', isLocal: false);

// 播放、暂停、停止
await player.resume();
await player.pause();
await player.stop();

// 设置音量（0.0 ~ 1.0）、左右声道平衡（-1.0 ~ 1.0）、播放速率（>0）
await player.setVolume(0.8);
await player.setBalance(0.0);
await player.setPlaybackRate(1.0);

// 监听播放状态、进度、完成等事件流
player.onPlayerStateChanged.listen((state) { /* ... */ });
player.onPositionChanged.listen((pos) { /* ... */ });
player.onPlayerComplete.listen((_) { /* ... */ });

// 释放资源
await player.release();
await player.dispose();
```

```dart
// 通过 setAudioContext 配置 OHOS 音频上下文（usageType/rendererFlags/stayAwake 等）
final ctx = AudioContext(
  ohos: AudioContextOhos(
    usageType: OhosUsageType.music,  // OHOS 音频用途枚举
    rendererFlags: 0,
    stayAwake: true,
  ),
);
await AudioPlayer.global.setAudioContext(ctx);
```

AudioCache 音频缓存示例：

```dart
// 加载 asset 到缓存（默认前缀 assets/，返回可直接播放的 URI）
final cache = AudioCache(prefix: 'assets/audio/');
final uri = await cache.load('beep.mp3');       // 单个加载
final uris = await cache.loadAll(['a.mp3', 'b.mp3']); // 批量加载
final bytes = await cache.loadAsBytes('beep.mp3');    // 字节流加载

// 清理缓存
await cache.clear('beep.mp3');  // 清除单个
await cache.clearAll();         // 清除全部
```

AudioPool 音频池示例（低延迟重叠播放）：

```dart
// 创建音频池：同一路径的多次快速重叠播放
final pool = await AudioPool.createFromAsset(
  path: 'assets/audio/beep.mp3',
  maxPlayers: 3,   // 池中最多保留 3 个播放器
);

// start() 返回停止句柄（StopFunction）
final stop = await pool.start(volume: 1.0);
// ... 可同时多次 start() 实现重叠播放
await stop();      // 停止并回收播放器到池中

// 不再使用时销毁池
await pool.dispose();
```

低延迟模式示例：

```dart
// PlayerMode.lowLatency 走 SoundPool 实现，适合短促音效
await player.setPlayerMode(PlayerMode.lowLatency);
await player.play(AssetSource('audio/beep.mp3'));
```

## 2. 约束与限制

### 2.1 兼容性

在以下版本中已测试通过

Flutter: 3.27.5-ohos-0.0.1; SDK: 5.0.0(12); IDE: DevEco Studio: 5.1.0.828; ROM: 5.1.0.130 SP8;
Flutter: 3.35.7-ohos-0.0.1; SDK: 6.0.1(21); IDE: DevEco Studio: 6.0.1.260; ROM: 6.0.0.120 SP6;
### 2.2 权限要求

#### 2.2.1 在 entry 目录下的 module.json5 中添加权限

打开 `entry/src/main/module.json5`，添加：

```diff
...
"abilities": [
    {
+     "backgroundModes": [
+        "audioPlayback",
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

#### 2.2.2 在 entry 目录下的 string.json 添加申请以上权限的原因

打开 `entry/src/main/resources/base/element/string.json`，添加：

```diff
...
{
  "string": [
+    {
+      "name": "background_running_reason",
+      "value": "后台运行"
+    }
  ]
}
```

## 3. API

> [!TIP] "鸿蒙支持"列为 yes 表示 ohos 平台支持该属性；no 则表示不支持；partially 表示部分支持。使用方法跨平台一致，效果对标 iOS 或 Android 的效果。

| Name               | Description      | Type      | Input                               | Output            | 鸿蒙支持 |
| ------------------ | ---------------- | --------- | ----------------------------------- | ----------------- | ------------ |
| play               | 播放音频（含焦点申请与后台任务启动） | function | Source source, {double? volume, double? balance, AudioContext? ctx, Duration? position, PlayerMode? mode} | Future<void> | yes |
| setSourceUrl       | 设置 url 播放源  | string    | String url, {String? mimeType}      | Future<void>      | yes          |
| setSourceBytes     | 设置字节流播放源 | uint8List | Uint8List bytes, {String? mimeType} | Future<void>      | yes          |
| setSource          | 设置通用播放源（DeviceFile/Asset）| function | Source source | Future<void> | yes |
| setSourceDeviceFile| 设置设备本地文件播放源 | function | DeviceFileSource source | Future<void> | yes |
| setSourceAsset     | 设置资源文件播放源 | function | AssetSource source | Future<void> | yes |
| resume             | 恢复暂停的播放   | function  | /                                   | Future<void>      | yes          |
| pause              | 暂停播放         | function  | /                                   | Future<void>      | yes          |
| stop               | 停止播放         | function  | /                                   | Future<void>      | yes          |
| seek               | 跳转到指定位置   | function  | Duration position                   | Future<void>      | yes          |
| setVolume          | 设置音量         | function  | double volume                       | Future<void>      | yes          |
| setBalance         | 设置左右声道平衡 | function  | double balance                      | Future<void>      | yes          |
| setPlaybackRate    | 设置播放速率     | function  | double playbackRate                 | Future<void>      | yes          |
| setReleaseMode     | 设置释放模式（STOP / LOOP / RELEASE） | function | ReleaseMode mode | Future<void> | yes |
| release            | 释放播放器资源   | function  | /                                   | Future<void>      | yes          |
| dispose            | 销毁播放器实例   | function  | /                                   | Future<void>      | yes          |
| getDuration        | 获取总时长       | function  | /                                   | Future<Duration?> | yes          |
| getCurrentPosition | 获取当前播放位置 | function  | /                                   | Future<Duration?> | yes          |
| setPlayerMode      | 设置播放模式     | function  | PlayerMode mode                     | Future<void>      | yes          |
| setAudioContext    | 设置播放参数     | function  | AudioContext ctx                    | Future<void>      | yes          |

### 3.1 事件流（Streams）

> [!TIP] 鸿蒙化实现对事件流的支持与上游一致，使用 `Stream` 监听播放器/全局事件。

| Name                   | Description          | 鸿蒙支持 |
| ---------------------- | -------------------- | ------------ |
| onPlayerStateChanged   | 播放器状态变化事件流 | yes          |
| onPositionChanged      | 播放进度变化事件流   | yes          |
| onDurationChanged      | 总时长变化事件流     | yes          |
| onPlayerComplete       | 播放完成事件流       | yes          |
| onSeekComplete         | 跳转完成事件流       | yes          |
| onLog                  | 日志事件流           | yes          |

### 3.2 枚举类型

| 枚举            | 取值                                   | 鸿蒙支持 |
| --------------- | -------------------------------------- | ------------ |
| PlayerMode      | mediaPlayer / lowLatency               | yes          |
| PlayerState     | stopped / playing / paused / completed | yes          |
| ReleaseMode     | release / stop / loop                  | yes          |
| OhosUsageType   | unknown(0) / music(1) / voiceCommunication(2) / voiceAssistant(3) / alarm(4) / voiceMessage(5) / ringtone(6) / notification(7) / accessibility(8) / moive(10) / game(11) / audiobook(12) / navigation(13) | yes |
| OhosAudioScene  | normal / ringing / phoneCall / voiceChat | yes      |
| AudioLogLevel   | none(0) / error(1) / info(2)           | yes          |
| AudioEventType  | log / duration / position / seekComplete / complete / prepared | yes |
| GlobalAudioEventType | log                             | yes          |

### 3.3 上游公共类

> [!TIP] 以下为上游 `audioplayers` 的 Dart 公共类。其在 OHOS 平台的行为与上游一致，均通过同一套 MethodChannel/EventChannel 桥接驱动，除特别说明外无鸿蒙侧差异。

| 类 / 类别 | 主要成员 | 说明 | 鸿蒙支持 |
| --------- | -------- | ---- | ------------ |
| AudioCache       | load / loadPath / loadAsFile / loadAsBytes / loadAll / clear / clearAll / fileSystem / loadedFiles / prefix / singleInstance | 预加载并缓存音频源，将 asset/URL 解析为可播放源。 | yes |
| AudioPool        | create / createFromAsset / start / dispose / source / minPlayers / maxPlayers / audioCache / audioContext | 同一源的多次重叠播放（基于 `PlayerMode.lowLatency` / SoundPool 实现）。`start()` 返回 `StopFunction` 停止句柄。 | yes |
| StopFunction     | （typedef）`Future<void> Function()` | `AudioPool.start()` 返回的停止函数，调用后回收播放器到池中。 | yes |
| GlobalAudioScope | ensureInitialized / setAudioContext / eventStream / onLog | 全局作用域工具（`AudioPlayer.global`）。`setAudioContext` 受系统 API 限制仅本地缓存。 | partially |
| AudioLogger      | logLevel / log / error / errorToString | 开关/采集插件内部日志，经 `onLog` 事件流上报。 | yes |
| Source（抽象类） | setOnPlayer / mimeType | 供 `setSource*` 使用的播放源描述基类。 | yes |
| UrlSource       | url / mimeType | URL 播放源（网络或本地路径）。 | yes |
| DeviceFileSource | path / mimeType | 设备本地文件播放源。 | yes |
| AssetSource      | path / mimeType | asset 资源播放源。 | yes |
| BytesSource      | bytes / mimeType | 字节流播放源。 | yes |
| AudioPlayerException | player / cause | 播放器异常包装（含关联播放器与原因）。 | yes |
| AudioEvent       | eventType / isPrepared / duration / position / seekComplete / logMessage / code / message | 播放器事件（经 `eventStream` 上报）。 | yes |
| GlobalAudioEvent | eventType / logMessage / code / message | 全局事件（经 `AudioPlayer.global.eventStream` 上报）。 | yes |
| PositionUpdater  | start / stop / update / dispose / positionStream | 位置更新器抽象基类，驱动 `onPositionChanged`。 | yes |
| TimerPositionUpdater | period / positionStream | 基于定时器的位置更新器实现。 | yes |
| FramePositionUpdater | （默认实现） | 每帧同步位置的位置更新器（默认）。 | yes |

### 3.4 配置与上下文类

| 类 | 主要成员 | 说明 | 鸿蒙支持 |
| -- | -------- | ---- | ------------ |
| AudioContext      | android / iOS / ohos / copy / toJson | 平台音频上下文聚合，`toJson` 按当前平台序列化。 | yes |
| AudioContextOhos  | usageType / rendererFlags / stayAwake / audioFocus / isSpeakerphoneOn / audioScene / copy / toJson | OHOS 平台音频上下文配置。 | yes |
| AudioContextConfig | route / focus / keyboardType / respectSystem / isSpeakerphoneOn | 通用音频上下文配置（上游公共配置项，序列化后映射到各平台）。 | yes |
| AudioContextAndroid | usageType / audioFocus / contentType / mode / isSpeakerphoneOn / stayAwake / audioFocusGain / copy / toJson | Android 平台配置（OHOS 侧不生效，仅保持上游兼容）。 | yes |
| AudioContextIOS   | category / options / copy / toJson | iOS 平台配置（OHOS 侧不生效，仅保持上游兼容）。 | yes |

配置相关枚举：

| 枚举 | 取值 | 说明 |
| ---- | ---- | ---- |
| AudioContextConfigRoute  | system / earpiece / speaker | 音频路由（系统默认 / 听筒 / 扬声器） |
| AudioContextConfigFocus  | gain / duckOthers / mixWithOthers | 焦点获取策略（对应 OHOS CONCURRENCY_DEFAULT / DUCK_OTHERS / MIX_WITH_OTHERS） |
| OhosUsageType            | unknown(0) / music(1) / voiceCommunication(2) / voiceAssistant(3) / alarm(4) / voiceMessage(5) / ringtone(6) / notification(7) / accessibility(8) / moive(10) / game(11) / audiobook(12) / navigation(13) | OHOS 音频用途（`AudioContextOhos.usageType`） |
| OhosAudioScene           | normal / ringing / phoneCall / voiceChat | OHOS 音频场景（`AudioContextOhos.audioScene`） |

## 4. 属性

> [!TIP] "鸿蒙支持"列为 yes 表示 ohos 平台支持该属性；no 则表示不支持；partially 表示部分支持。使用方法跨平台一致，效果对标 iOS 或 Android 的效果。

### setAudioContext Parameters

| Name          | Description                        | Type            | Input | Output | 鸿蒙支持 |
| ------------- | ---------------------------------- | --------------- | ----- | ------ | ------------ |
| rendererFlags | 设置播放参数                       | int             | /     | /      | yes          |
| usageType     | 定义音频用途类型（对应 OhosUsageType 枚举） | OhosUsageType | /     | /      | yes          |
| stayAwake     | 控制是否在播放期间保持设备唤醒状态 | boolean         | /     | /      | yes          |
| audioFocus    | 焦点策略（0: gain, 1: duckOthers, 2: mixWithOthers） | int  | /     | /      | yes          |
| isSpeakerphoneOn | 是否开启扬声器                  | boolean         | /     | /      | yes          |
| audioScene    | 音频场景                           | int             | /     | /      | yes          |

## 5. 遗留问题

## 6. 其他

如遇问题，可参考上游 [troubleshooting.md](./troubleshooting.md) 或通过 Issue 反馈。鸿蒙化实现位于 `packages/audioplayers_ohos/`，核心 ArkTS 文件包括 `AudioplayersPlugin.ets`、`WrappedPlayer.ets`、`MediaPlayerPlayer.ets`、`SoundPoolPlayer.ets`、`FocusManager.ets`。

## 7. 开源协议

本项目基于 [The MIT License (MIT)](./LICENSE) ，请自由地享受和参与开源。
