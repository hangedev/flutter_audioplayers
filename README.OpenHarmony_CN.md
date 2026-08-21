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
...

dependencies:
  audioplayers:
    git:
      url: https://gitcode.com/CPF-Flutter/flutter_audioplayers.git
      path: packages/audioplayers
      # ref: 根据下方表格选择不同框架适配的TAG版本
      ref: TAG # 根据下方表格选择不同框架适配的TAG版本
...
```

执行命令

```bash
flutter pub get
```

#### 版本对应表

| Flutter 框架版本 | TAG 名称 | 分支名 |
| --------------- | ----------------------- | ------ |
| 3.22            | 6.1.0-ohos-1.0.1        | br_audioplayers-v6.1.0_ohos  |

<!-- tabs:end -->

### 1.2 使用案例

导入库、创建播放器并播放一个音频源：

```dart
import 'package:audioplayers/audioplayers.dart';

final player = AudioPlayer();

// 播放远程 URL 音频源。
await player.play(UrlSource('https://example.com/audio.mp3'));

// 或播放本地 asset（需在 pubspec.yaml 的 assets 中声明）。
await player.play(AssetSource('audio/sample.mp3'));

// 播放控制。
await player.pause();
await player.resume();
await player.stop();
await player.seek(const Duration(seconds: 5));

// 使用完毕后释放资源。
await player.dispose();
```

更多完整使用示例请参见 [ohos/example](./packages/audioplayers/example/lib/main.dart)。

## 2. 约束与限制

### 2.1 兼容性

在以下版本中已测试通过

Flutter: 3.22.1-ohos-1.0.1; SDK: 5.0.0(12); IDE: DevEco Studio: 5.0.13.200; ROM: 5.1.0.120 SP3;

### 2.2 OHOS 开发环境

在鸿蒙平台构建与运行前，请准备以下工具链：

- 安装 **DevEco Studio**（已验证版本：5.0.13.200），并启动一次，使其自带的 **OHOS SDK**（API 12 / 5.0.0）与 **ohpm** 包管理器完成注册。
- 安装 **Flutter OHOS 版**（已验证版本：3.22.1-ohos-1.0.1），确认已在 PATH 中：`flutter --version`。
- 确认 `ohpm` 与 `hvigorw` 可用。若找不到 `ohpm`，请将 `<DevEco>/tools/ohpm/bin` 加入 PATH。
- 在示例工程目录内构建（`example/` 目录下包含 OHOS 平台工程 `example/ohos/`）：

```bash
cd example
flutter pub get
flutter build hap --debug
```

- 为保证构建确定性，请在 `example/ohos/hvigor/hvigor-config.json5` 中设置 `"execution": { "daemon": false }` 关闭 hvigor daemon。

### 2.3 权限要求

#### 2.3.1 在 entry 目录下的 module.json5 中添加权限

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

#### 2.3.2 在 entry 目录下的 string.json 添加申请以上权限的原因

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

> [!TIP] "ohos Support"列为 yes 表示 ohos 平台支持该属性；no 则表示不支持；partially 表示部分支持。使用方法跨平台一致，效果对标 iOS 或 Android 的效果。

| Name               | Description      | Type      | Input                               | Output            | ohos Support |
| ------------------ | ---------------- | --------- | ----------------------------------- | ----------------- | ------------ |
| setSourceUrl       | 设置 url 播放源  | string    | String url, {String? mimeType}      | Future<void>      | yes          |
| setSourceBytes     | 设置字节流播放源 | uint8List | Uint8List bytes, {String? mimeType} | Future<void>      | yes          |
| resume             | 恢复暂停的播放   | function  | /                                   | Future<void>      | yes          |
| pause              | 暂停播放         | function  | /                                   | Future<void>      | yes          |
| stop               | 停止播放         | function  | /                                   | Future<void>      | yes          |
| seek               | 跳转到指定位置   | function  | Duration position                   | Future<void>      | yes          |
| setVolume          | 设置音量         | function  | double volume                       | Future<void>      | yes          |
| setBalance         | 设置左右声道平衡 | function  | double balance                      | Future<void>      | yes          |
| setPlaybackRate    | 设置播放速率     | function  | double playbackRate                 | Future<void>      | yes          |
| release            | 释放播放器资源   | function  | /                                   | Future<void>      | yes          |
| dispose            | 销毁播放器实例   | function  | /                                   | Future<void>      | yes          |
| getDuration        | 获取总时长       | function  | /                                   | Future<Duration?> | yes          |
| getCurrentPosition | 获取当前播放位置 | function  | /                                   | Future<Duration?> | yes          |
| setPlayerMode      | 设置播放模式     | function  | PlayerMode mode                     | Future<void>      | yes          |
| setAudioContext    | 设置播放参数     | function  | AudioContext ctx                    | Future<void>      | yes          |

## 4. 属性

`AudioContext` 携带一个 `AudioContextOhos` 类型的 `ohos` 字段，用于配置 OHOS 专属的音频渲染属性。可通过 `AudioContextConfig().buildOhos()` 便捷构建。

> [!TIP] "ohos Support"列为 yes 表示 ohos 平台支持该属性；no 则表示不支持；partially 表示部分支持。使用方法跨平台一致，效果对标 iOS 或 Android 的效果。

### setAudioContext Parameters

| Name          | Description                        | Type    | 默认值 | ohos Support |
| ------------- | ---------------------------------- | ------- | ------ | ------------ |
| isSpeakerphoneOn | 是否强制开启扬声器输出路由。注意：OHOS 默认值为 `true`，与 Android（默认 `false`）不同。 | boolean | true   | yes          |
| audioScene    | 音频场景，影响音频路由与焦点行为。见 `OhosAudioScene`。 | OhosAudioScene | normal | yes          |
| rendererFlags | 音频渲染器标志。`0` = 普通渲染器，`1` = 低时延渲染器。**ArkTS 接口暂不支持低时延渲染**，因此仅 `0` 生效。 | number  | 0      | yes          |
| usageType     | 音频用途类型（"为什么"播放此声音），系统据此进行路由与音量决策。见 `OhosUsageType`。 | OhosUsageType | music  | yes          |
| stayAwake     | 控制是否在播放期间保持设备唤醒（启动后台任务 + 保持屏幕常亮）。需配合第 2.3 节的后台权限。 | boolean | true   | yes          |

#### OhosUsageType

定义 `usageType` 的音频用途类型，各枚举值及对应的底层编码如下：

| 枚举值             | 编码 | 说明 |
| ------------------ | ---- | ---- |
| unknown            | 0    | 未知用途 |
| music              | 1    | 媒体或音乐（默认） |
| voiceCommunication | 2    | 电话或 VoIP 通话 |
| voiceAssistant     | 3    | 语音助手播报 |
| alarm              | 4    | 闹钟（如起床闹钟） |
| voiceMessage       | 5    | 语音留言 |
| ringtone           | 6    | 通知或铃声 |
| notification       | 7    | 通知 |
| accessibility      | 8    | 无障碍（如屏幕朗读） |
| moive              | 10   | 电影音频 |
| game               | 11   | 游戏音频 |
| audiobook          | 12   | 有声书音频 |
| navigation         | 13   | 导航 |

#### OhosAudioScene

定义 `audioScene` 的音频场景：

| 枚举值    | 编码 | 说明 |
| --------- | ---- | ---- |
| normal    | 0    | 默认音频场景（默认） |
| ringing   | 1    | 响铃模式 |
| phoneCall | 2    | 电话模式 |
| voiceChat | 3    | 语音聊天模式 |

## 5. 遗留问题

- **低时延播放**：`rendererFlags = 1`（低时延渲染器）为前向兼容而保留，但 ArkTS 音频接口暂不支持低时延渲染，设为 `1` 无效果，请使用 `0`。
- **`setAudioContext` 全局生效范围**：OHOS 目前没有与 Android `AudioManager.mode` / `isSpeakerphoneOn` 等价的公开接口，`setAudioContext` 会被记录，但仅 `usageType` 与 `rendererFlags` 会应用到渲染器属性。
- **低时延模式的 seek**：`PlayerMode.lowLatency`（SoundPool）不支持 seek，与上游限制一致。
- **音频焦点（Audio Focus）**：鸿蒙不提供 Android `AudioManager.requestAudioFocus/abandonAudioFocus` 式的显式焦点申请接口；焦点由系统按渲染器属性（`usageType` 等）自动仲裁。`MediaPlayer` 模式已通过 `audioInterrupt` 事件实现焦点打断响应（失去焦点自动暂停、焦点恢复自动续播）。`PlayerMode.lowLatency`（SoundPool）底层未提供 `audioInterrupt` 事件，焦点变化仅由系统自动处理（如自动压低音量/暂停），应用层无法感知焦点事件。
- **SoundPool 暂停不可恢复**：鸿蒙 `SoundPool` 无 `pause(streamId)` / `resume(streamId)` 接口，`PlayerMode.lowLatency` 模式下的 `pause()` 实际为停止该流，恢复播放需重新 `play`。
- **低时延模式的 seek**：`PlayerMode.lowLatency`（SoundPool）不支持 seek，调用 `seek` 将抛出 `LOW_LATENCY mode does not support: seek` 异常，与 Android 行为一致。

## 6. 其他

### 从上游 audioplayers 迁移

本 OHOS 分支保持 `audioplayers` 的公开 Dart API 不变，因此现有应用代码（导入路径、`AudioPlayer`、`UrlSource`、`AssetSource` 等）无需修改即可使用。迁移步骤：

1. 将 `pubspec.yaml` 中的 `audioplayers` 依赖替换为第 1.1 节的 OHOS git 依赖。
2. 执行 `flutter pub get`。
3. 若使用 `stayAwake` / 后台播放，请在 `module.json5` 中添加第 2.3 节的 OHOS 后台权限。
4. 若需自定义 `AudioContext`，请使用 OHOS 专属字段（`usageType`、`audioScene`、`isSpeakerphoneOn`、`rendererFlags`、`stayAwake`），而非 Android 专属字段。

## 7. 开源协议

本项目基于 [The MIT License (MIT)](./LICENSE) ，请自由地享受和参与开源。
