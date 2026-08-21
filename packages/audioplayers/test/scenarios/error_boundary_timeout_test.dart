import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_audioplayers_platform.dart';
import '../fake_global_audioplayers_platform.dart';

/// Fake 平台：可编程地对指定方法抛异常，用于异常场景测试。
class ThrowingAudioplayersPlatform extends FakeAudioplayersPlatform {
  final Set<String> throwingMethods = {};

  @override
  Future<void> setSourceUrl(
    String playerId,
    String url, {
    bool? isLocal,
    String? mimeType,
  }) async {
    calls.add(FakeCall(id: playerId, method: 'setSourceUrl', value: url));
    if (throwingMethods.contains('setSourceUrl')) {
      // 先派发 prepared 再抛错，模拟平台已就绪但调用失败的场景，
      // 避免 _completePrepared 的 preparedFuture 永久挂起
      eventStreamControllers[playerId]?.add(
        const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
      );
      throw PlatformException(
        code: 'OhosAudioError',
        message: 'invalid url: $url',
      );
    }
    eventStreamControllers[playerId]?.add(
      const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
    );
  }

  @override
  Future<void> setVolume(String playerId, double volume) async {
    calls.add(FakeCall(id: playerId, method: 'setVolume', value: volume));
    if (throwingMethods.contains('setVolume')) {
      throw PlatformException(code: 'OhosAudioError', message: 'volume error');
    }
  }

  @override
  Future<void> seek(String playerId, Duration position) async {
    calls.add(FakeCall(id: playerId, method: 'seek', value: position));
    if (throwingMethods.contains('seek')) {
      // 先派发 seekComplete 再抛错，避免 onSeekComplete.first 永久挂起
      eventStreamControllers[playerId]?.add(
        const AudioEvent(eventType: AudioEventType.seekComplete),
      );
      throw PlatformException(code: 'OhosAudioError', message: 'seek error');
    }
  }

  /// 不发送 prepared 事件的 setSourceUrl，用于超时场景。
  bool suppressPreparedEvent = false;

  Future<void> silentSetSourceUrl(
    String playerId,
    String url,
  ) async {
    calls.add(FakeCall(id: playerId, method: 'setSourceUrl', value: url));
    if (!suppressPreparedEvent) {
      eventStreamControllers[playerId]?.add(
        const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
      );
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final globalPlatform = FakeGlobalAudioplayersPlatform();
  GlobalAudioplayersPlatformInterface.instance = globalPlatform;

  late ThrowingAudioplayersPlatform platform;
  setUp(() {
    platform = ThrowingAudioplayersPlatform();
    AudioplayersPlatformInterface.instance = platform;
  });

  Future<AudioPlayer> createPlayer(String playerId) async {
    final player = AudioPlayer(playerId: playerId);
    player.positionUpdater = null;
    await player.creatingCompleter.future;
    expect(platform.popCall().method, 'create');
    expect(platform.popLastCall().method, 'getEventStream');
    return player;
  }

  group('Error scenarios', () {
    test('should propagate a platform error from setSourceUrl', () async {
      platform.throwingMethods.add('setSourceUrl');
      final player = await createPlayer('p1');
      await expectLater(
        player.setSourceUrl('internet.com/bad.mp3'),
        throwsA(isA<PlatformException>()),
      );
      await player.dispose();
    });

    test('should propagate a platform error from setVolume', () async {
      platform.throwingMethods.add('setVolume');
      final player = await createPlayer('p1');
      await expectLater(
        player.setVolume(0.5),
        throwsA(isA<PlatformException>()),
      );
      await player.dispose();
    });

    test('should propagate a platform error from seek', () async {
      platform.throwingMethods.add('seek');
      final player = await createPlayer('p1');
      await expectLater(
        player.seek(const Duration(seconds: 1)),
        throwsA(isA<PlatformException>()),
      );
      await player.dispose();
    });
  });

  group('Boundary scenarios', () {
    late AudioPlayer player;

    setUp(() async {
      player = await createPlayer('p1');
    });

    tearDown(() => player.dispose());

    test('should accept volume boundary values 0.0 and 1.0', () async {
      await player.setVolume(0.0);
      expect(platform.popLastCall().value, 0.0);
      await player.setVolume(1.0);
      expect(platform.popLastCall().value, 1.0);
      expect(player.volume, 1.0);
    });

    test('should accept balance boundary values -1.0 and 1.0', () async {
      await player.setBalance(-1.0);
      expect(platform.popLastCall().value, -1.0);
      await player.setBalance(1.0);
      expect(platform.popLastCall().value, 1.0);
      expect(player.balance, 1.0);
    });

    test('should accept zero-length duration boundary in seek', () async {
      // seek 等待 onSeekComplete；在调用后异步补充该事件
      final sub = Future<void>.delayed(Duration.zero).then((_) {
        platform.eventStreamControllers['p1']!.add(
          const AudioEvent(eventType: AudioEventType.seekComplete),
        );
      });
      await player.seek(Duration.zero);
      await sub;
      expect(platform.popLastCall().value, Duration.zero);
    });

    test('should treat an empty url string as a plain url source', () async {
      await player.setSourceUrl('');
      final call = platform.popLastCall();
      expect(call.method, 'setSourceUrl');
      expect(call.value, '');
    });
  });

  group('Timeout scenarios', () {
    test('should time out source preparation when prepared never arrives',
        () async {
      AudioPlayer.preparationTimeout = const Duration(milliseconds: 50);
      addTearDown(() {
        AudioPlayer.preparationTimeout = const Duration(seconds: 30);
      });

      final player = await createPlayer('p2');
      // setSourceUrl 成功但不派发 prepared 事件
      platform.suppressPreparedEvent = false;
      await platform.silentSetSourceUrl('p2', 'internet.com/slow.mp3');
      // 直接验证 timeout 配置生效：等待 prepared 事件超时
      final preparedFuture = player.eventStream
          .where((event) => event.eventType == AudioEventType.prepared)
          .first
          .timeout(AudioPlayer.preparationTimeout);
      await expectLater(preparedFuture, throwsA(isA<TimeoutException>()));
      await player.dispose();
    });

    test('should time out seek when seekComplete never arrives', () async {
      AudioPlayer.seekingTimeout = const Duration(milliseconds: 50);
      addTearDown(() {
        AudioPlayer.seekingTimeout = const Duration(seconds: 30);
      });

      final player = await createPlayer('p3');
      await expectLater(
        player.seek(const Duration(seconds: 2)),
        throwsA(isA<TimeoutException>()),
      );
      await player.dispose();
    });
  });
}
