//ignore_for_file: avoid_redundant_argument_values

import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';

import 'audio_cache_test.dart';

/// 平台接口成员的调用面测试：
/// 通过主包测试目录直接驱动 AudioContext 系列 copy/build 与
/// AudioCache.fetchToMemory / loadAll / AudioLogLevel.compareTo 等成员，
/// 保证每个公开接口在测试源中都有基类类型的直接调用点。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AudioCache.fileSystem = MemoryFileSystem.test();
  });

  group('AudioContext platform copies', () {
    test('should copy an AudioContext with per-branch overrides', () {
      const android = AudioContextAndroid(isSpeakerphoneOn: true);
      const ohos = AudioContextOhos(stayAwake: true);
      final ios = AudioContextIOS();

      final context = AudioContext(android: android, ohos: ohos, iOS: ios);

      final copied = context.copy(android: const AudioContextAndroid());
      expect(copied.android, isNot(android));
      expect(copied.ohos, ohos);
      expect(copied.iOS, ios);
    });

    test('should copy an AudioContextAndroid leaving the original unchanged',
        () {
      const AudioContextAndroid original = AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: true,
      );
      final copied = original.copy(stayAwake: false);
      expect(copied.stayAwake, isFalse);
      expect(original.stayAwake, isTrue);
    });

    test('should copy an AudioContextIOS with category and options', () {
      final AudioContextIOS original = AudioContextIOS(
        category: AVAudioSessionCategory.playAndRecord,
        options: const {AVAudioSessionOptions.defaultToSpeaker},
      );
      // copy 未提供 options 时沿用原 options；此处同时更换 category，
      // 因此先构造一个与 playback 兼容的 options 集合
      final copied = original.copy(
        category: AVAudioSessionCategory.playback,
        options: const {AVAudioSessionOptions.mixWithOthers},
      );
      expect(copied.category, AVAudioSessionCategory.playback);
      expect(copied.options, const {AVAudioSessionOptions.mixWithOthers});
    });

    test('should copy an AudioContextOhos and expose its config fields', () {
      const AudioContextOhos original = AudioContextOhos(
        rendererFlags: 2,
        audioScene: OhosAudioScene.phoneCall,
      );
      final copied = original.copy(rendererFlags: 3);
      expect(copied.rendererFlags, 3);
      expect(original.rendererFlags, 2);
      expect(copied.audioScene, OhosAudioScene.phoneCall);
      expect(original.audioScene, OhosAudioScene.phoneCall);
    });
  });

  group('AudioContextConfig platform builders', () {
    test('should build per-platform contexts from config', () {
      final AudioContextConfig config = AudioContextConfig(
        route: AudioContextConfigRoute.speaker,
        respectSilence: true,
        stayAwake: true,
      );

      final android = config.buildAndroid();
      expect(android.isSpeakerphoneOn, isTrue);

      final ohos = config.buildOhos();
      expect(ohos.isSpeakerphoneOn, isTrue);
      expect(ohos.usageType, OhosUsageType.ringtone);

      // buildIOS 在非 iOS 目标平台返回 null；调用本身即覆盖调用面
      final ios = config.buildIOS();
      expect(ios, anyOf(isNull, isA<AudioContextIOS>()));

      final full = config.build();
      // build() 重新构造各平台分支，比较字段而非实例同一性
      expect(full.android.isSpeakerphoneOn, android.isSpeakerphoneOn);
      expect(full.ohos.usageType, ohos.usageType);
      expect(full.ohos.audioScene, ohos.audioScene);
    });
  });

  group('AudioCache remaining members', () {
    test('should fetch to memory and batch-load via the base type', () async {
      final AudioCache cache = _MemoryAudioCache();

      final uri = await cache.fetchToMemory('audio.mp3');
      expect(uri.toString(), contains('audio.mp3'));

      final uris = await cache.loadAll(['audio.mp3', 'laser.wav']);
      expect(uris, hasLength(2));
    });
  });

  group('AudioLogLevel comparison', () {
    test('should compare levels directly', () {
      const error = AudioLogLevel.error;
      const info = AudioLogLevel.info;
      expect(error.compareTo(info), lessThan(0));
      expect(info.compareTo(error), greaterThan(0));
      expect(error.compareTo(error), 0);
    });
  });
}

class _MemoryAudioCache extends FakeAudioCache {
  @override
  Future<ByteData> loadAsset(String path) async {
    return ByteData.sublistView(utf8.encode(path));
  }

  @override
  Future<String> getTempDir() async => '/';
}
