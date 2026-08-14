import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_audioplayers_platform.dart';

void main() {
  late FakeAudioplayersPlatform platform;

  setUp(() {
    platform = FakeAudioplayersPlatform();
    AudioplayersPlatformInterface.instance = platform;
  });

  // Helper that builds a player with the position updater disabled, so tests
  // do not depend on frame scheduling.
  Future<AudioPlayer> createPlayer({required String playerId}) async {
    final player = AudioPlayer(playerId: playerId);
    // Disable the position updater to keep tests deterministic.
    player.positionUpdater = null;
    // AudioPlayer._create() wires the platform event stream asynchronously;
    // flush it so emitted events reach the player's event stream.
    await Future<void>.delayed(Duration.zero);
    return player;
  }

  group('AudioPlayer events', () {
    test(
        'should emit complete event when the platform sends a complete event',
        () async {
      final player = await createPlayer(playerId: 'pComplete');
      final received = <void>[];
      final sub = player.onPlayerComplete.listen(received.add);

      platform.eventStreamControllers['pComplete']?.add(
        const AudioEvent(eventType: AudioEventType.complete),
      );
      // Broadcast streams emit synchronously on listen; allow microtasks.
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));

      await sub.cancel();
      await player.dispose();
    });

    test(
        'should emit seek complete event when the platform sends a seekComplete',
        () async {
      final player = await createPlayer(playerId: 'pSeek');
      final received = <void>[];
      final sub = player.onSeekComplete.listen(received.add);

      platform.eventStreamControllers['pSeek']?.add(
        const AudioEvent(eventType: AudioEventType.seekComplete),
      );
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));

      await sub.cancel();
      await player.dispose();
    });

    test('should emit log message when the platform sends a log event',
        () async {
      final player = await createPlayer(playerId: 'pLog');
      final received = <String>[];
      final sub = player.onLog.listen(received.add);

      platform.eventStreamControllers['pLog']?.add(
        const AudioEvent(
          eventType: AudioEventType.log,
          logMessage: 'a log line',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(received, equals(<String>['a log line']));

      await sub.cancel();
      await player.dispose();
    });

    test('should filter events so that only the matching type is emitted',
        () async {
      final player = await createPlayer(playerId: 'pFilter');
      final completed = <void>[];
      final sub = player.onPlayerComplete.listen(completed.add);

      // Emit unrelated events that must be filtered out.
      platform.eventStreamControllers['pFilter']?.add(
        const AudioEvent(eventType: AudioEventType.log, logMessage: 'noise'),
      );
      platform.eventStreamControllers['pFilter']?.add(
        const AudioEvent(eventType: AudioEventType.complete),
      );
      await Future<void>.delayed(Duration.zero);

      expect(completed, hasLength(1));

      await sub.cancel();
      await player.dispose();
    });
  });

  group('AudioPlayer.release', () {
    test('should call stop and platform.release and clear the source',
        () async {
      final player = await createPlayer(playerId: 'pRelease');
      await player.setSourceUrl('https://example.com/a.mp3');
      platform.clear();

      await player.release();

      final methods =
          platform.calls.map((c) => c.method).toList(growable: false);
      expect(methods, containsAll(<String>['stop', 'release']));
      expect(player.source, isNull);

      await player.dispose();
    });
  });

  group('AudioPlayer.audioCache', () {
    test('should default to the global AudioCache instance', () async {
      final player = await createPlayer(playerId: 'pCache');
      expect(player.audioCache, same(AudioCache.instance));
      // It must be reassignable.
      final other = AudioCache(prefix: 'audio/');
      player.audioCache = other;
      expect(player.audioCache, same(other));
    });
  });

  group('AudioPlayer.setSourceDeviceFile', () {
    test('should set a DeviceFileSource and call setSourceUrl(isLocal: true)',
        () async {
      final player = await createPlayer(playerId: 'pDeviceFile');
      platform.clear();

      await player.setSourceDeviceFile('/tmp/audio.mp3');

      final call = platform.popLastCall();
      expect(call.method, 'setSourceUrl');
      expect(call.value, '/tmp/audio.mp3');
      expect(player.source, isA<DeviceFileSource>());
      expect((player.source as DeviceFileSource).path, '/tmp/audio.mp3');

      await player.dispose();
    });
  });

  group('AudioPlayer.setSourceAsset', () {
    test('should set an AssetSource and call setSourceUrl(isLocal: true)',
        () async {
      final player = await createPlayer(playerId: 'pAsset');
      // 用可预测的 Fake 缓存替代全局 AudioCache，避免依赖真实资源文件
      player.audioCache = _StubAssetCache();
      platform.clear();

      await player.setSourceAsset('audio/sample.mp3');

      final call = platform.popLastCall();
      expect(call.method, 'setSourceUrl');
      expect(call.value, 'file:///cached/audio/sample.mp3');
      expect(player.source, isA<AssetSource>());
      expect((player.source as AssetSource).path, 'audio/sample.mp3');

      await player.dispose();
    });
  });

  group('AudioPlayer.setSourceBytes', () {    test('should set a BytesSource and call setSourceBytes', () async {
      final player = await createPlayer(playerId: 'pBytes');
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      platform.clear();

      await player.setSourceBytes(bytes);

      final call = platform.popLastCall();
      expect(call.method, 'setSourceBytes');
      expect(call.value, same(bytes));
      expect(player.source, isA<BytesSource>());

      await player.dispose();
    });
  });

  group('AudioPlayer.onPlayerStateChanged', () {
    test('should emit player state changes via resume/pause', () async {
      final player = await createPlayer(playerId: 'pState');
      final received = <PlayerState>[];
      final sub = player.onPlayerStateChanged.listen(received.add);

      await player.resume();
      await Future<void>.delayed(Duration.zero);
      await player.pause();
      await Future<void>.delayed(Duration.zero);

      expect(received, contains(PlayerState.playing));
      expect(received, contains(PlayerState.paused));

      await sub.cancel();
      await player.dispose();
    });
  });

  group('AudioPlayer.onDurationChanged', () {
    test('should emit duration when the platform sends a duration event',
        () async {
      final player = await createPlayer(playerId: 'pDuration');
      final received = <Duration>[];
      final sub = player.onDurationChanged.listen(received.add);

      platform.eventStreamControllers['pDuration']?.add(
        const AudioEvent(
          eventType: AudioEventType.duration,
          duration: Duration(seconds: 42),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(received, [const Duration(seconds: 42)]);

      await sub.cancel();
      await player.dispose();
    });
  });
}

/// 可预测的 AudioCache 替身：loadPath 直接返回固定缓存路径，
/// 供 setSourceAsset 测试使用，避免依赖真实资源文件系统。
class _StubAssetCache extends AudioCache {
  @override
  Future<String> loadPath(String fileName) async =>
      'file:///cached/$fileName';
}
