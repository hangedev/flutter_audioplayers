//ignore_for_file: lines_longer_than_80_chars

import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:audioplayers_platform_interface/src/api/audio_context_config.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dart-side smoke tests for the OHOS federated implementation package.
///
/// `audioplayers_ohos` is a native-only plugin (ArkTS). These tests verify:
/// 1. The package can be loaded under `flutter test` with flutter_test.
/// 2. MethodChannel name/dispatch used by the platform interface is consistent
///    with the OHOS plugin registration surface (`xyz.luan/audioplayers`).
/// 3. OHOS-specific [AudioContext] serialization stays reachable from this
///    package's dependency on [audioplayers_platform_interface].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const playerChannel = MethodChannel('xyz.luan/audioplayers');
  const globalChannel = MethodChannel('xyz.luan/audioplayers.global');

  final playerCalls = <MethodCall>[];
  final globalCalls = <MethodCall>[];

  setUp(() {
    playerCalls.clear();
    globalCalls.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(playerChannel, (call) async {
      playerCalls.add(call);
      switch (call.method) {
        case 'getDuration':
        case 'getCurrentPosition':
          return 0;
        default:
          return null;
      }
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(globalChannel, (call) async {
      globalCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(playerChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(globalChannel, null);
  });

  group('OHOS plugin MethodChannel dispatch', () {
    test('should dispatch player methods on xyz.luan/audioplayers', () async {
      final platform = AudioplayersPlatformInterface.instance;

      await platform.create('ohos-p1');
      expect(playerCalls.single.method, 'create');
      expect(
        (playerCalls.single.arguments as Map)['playerId'],
        'ohos-p1',
      );
      playerCalls.clear();

      await platform.setSourceUrl(
        'ohos-p1',
        'https://example.com/a.mp3',
        mimeType: 'audio/mpeg',
      );
      expect(playerCalls.single.method, 'setSourceUrl');
      final args = playerCalls.single.arguments as Map;
      expect(args['url'], 'https://example.com/a.mp3');
      expect(args['mimeType'], 'audio/mpeg');
      playerCalls.clear();

      await platform.resume('ohos-p1');
      expect(playerCalls.single.method, 'resume');
      playerCalls.clear();

      await platform.release('ohos-p1');
      expect(playerCalls.single.method, 'release');
      playerCalls.clear();

      await platform.dispose('ohos-p1');
      expect(playerCalls.single.method, 'dispose');
    });

    test('should dispatch global audio context on the global channel', () async {
      final global = GlobalAudioplayersPlatformInterface.instance;

      await global.init();
      expect(globalCalls.single.method, 'init');
      globalCalls.clear();

      final ctx = AudioContext(
        ohos: const AudioContextOhos(
          usageType: OhosUsageType.music,
          isSpeakerphoneOn: true,
        ),
      );
      await global.setGlobalAudioContext(ctx);
      expect(globalCalls.single.method, 'setAudioContext');
    });
  });

  group('OHOS AudioContext surface', () {
    test('should serialize AudioContextOhos fields for native hand-off', () {
      const ohos = AudioContextOhos(
        isSpeakerphoneOn: true,
        rendererFlags: 0,
        usageType: OhosUsageType.game,
        stayAwake: true,
        audioFocus: AudioContextConfigFocus.gain,
      );
      final json = ohos.toJson();
      expect(json['usageType'], OhosUsageType.game.value);
      expect(json['isSpeakerphoneOn'], isTrue);
      expect(json['stayAwake'], isTrue);
      expect(json['audioFocus'], AudioContextConfigFocus.gain.index);
    });

    test('should expose a default AudioplayersPlatformInterface instance', () {
      expect(AudioplayersPlatformInterface.instance, isNotNull);
      expect(GlobalAudioplayersPlatformInterface.instance, isNotNull);
    });
  });
}
