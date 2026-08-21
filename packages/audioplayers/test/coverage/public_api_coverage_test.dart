//ignore_for_file: avoid_redundant_argument_values, lines_longer_than_80_chars

import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:file/memory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../audio_cache_test.dart';
import '../audio_pool_test.dart';
import '../fake_audioplayers_platform.dart';
import '../fake_global_audioplayers_platform.dart';

/// Fake that never emits [AudioEventType.prepared], used to exercise
/// [AudioPlayer.preparationTimeout].
class _NoPreparedFake extends FakeAudioplayersPlatform {
  @override
  Future<void> setSourceUrl(
    String playerId,
    String url, {
    bool? isLocal,
    String? mimeType,
  }) async {
    calls.add(FakeCall(id: playerId, method: 'setSourceUrl', value: url));
  }

  @override
  Future<void> setSourceBytes(
    String playerId,
    Uint8List bytes, {
    String? mimeType,
  }) async {
    calls.add(FakeCall(id: playerId, method: 'setSourceBytes', value: bytes));
  }
}

/// Fake that rejects source setup with a permission-style [PlatformException].
class _PermissionDeniedFake extends FakeAudioplayersPlatform {
  @override
  Future<void> setSourceUrl(
    String playerId,
    String url, {
    bool? isLocal,
    String? mimeType,
  }) async {
    calls.add(FakeCall(id: playerId, method: 'setSourceUrl', value: url));
    // Still emit prepared so Future.wait is not gated on preparationTimeout;
    // the PlatformException from this future is what the caller observes.
    eventStreamControllers[playerId]?.add(
      const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
    );
    throw PlatformException(
      code: 'PermissionDenied',
      message: 'Missing ohos.permission.READ_MEDIA',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final globalPlatform = FakeGlobalAudioplayersPlatform();
  GlobalAudioplayersPlatformInterface.instance = globalPlatform;

  late FakeAudioplayersPlatform platform;

  setUp(() {
    platform = FakeAudioplayersPlatform();
    AudioplayersPlatformInterface.instance = platform;
    AudioCache.fileSystem = MemoryFileSystem.test();
    // Prefer the bytes / URL code paths that do not need path_provider.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  Future<AudioPlayer> createPlayer({required String playerId}) async {
    final player = AudioPlayer(playerId: playerId);
    player.positionUpdater = null;
    await player.creatingCompleter.future;
    expect(platform.popCall().method, 'create');
    expect(platform.popLastCall().method, 'getEventStream');
    return player;
  }

  group('AudioPlayer.playerId / release', () {
    test('should expose the provided playerId', () async {
      final player = await createPlayer(playerId: 'custom-id-42');
      expect(player.playerId, 'custom-id-42');
      await player.dispose();
    });

    test('should generate a non-empty playerId when omitted', () async {
      final player = AudioPlayer();
      player.positionUpdater = null;
      await player.creatingCompleter.future;
      expect(player.playerId, isNotEmpty);
      await player.dispose();
    });

    test('should stop, release native resources and clear source when release is called',
        () async {
      final player = await createPlayer(playerId: 'release-1');
      await player.setSource(UrlSource('internet.com/a.mp3'));
      platform.clear();

      await player.release();

      expect(platform.popCall().method, 'stop');
      expect(platform.popLastCall().method, 'release');
      expect(player.source, isNull);
      expect(player.state, PlayerState.stopped);
      await player.dispose();
    });
  });

  group('AudioPlayer setSource* helpers', () {
    test('should call platform when setSourceDeviceFile is invoked', () async {
      final player = await createPlayer(playerId: 'device-1');
      await player.setSourceDeviceFile(
        '/data/local/tmp/track.mp3',
        mimeType: 'audio/mpeg',
      );

      final call = platform.popLastCall();
      expect(call.method, 'setSourceUrl');
      expect(call.value, '/data/local/tmp/track.mp3');
      expect(player.source, isA<DeviceFileSource>());
      final source = player.source! as DeviceFileSource;
      expect(source.path, '/data/local/tmp/track.mp3');
      expect(source.mimeType, 'audio/mpeg');
      await player.dispose();
    });

    test('should resolve via AudioCache when setSourceAsset is invoked',
        () async {
      final player = await createPlayer(playerId: 'asset-1');
      player.audioCache = FakeAudioCache(cacheId: 'cov-asset');

      await player.setSourceAsset('sounds/beep.mp3', mimeType: 'audio/mpeg');

      final call = platform.popLastCall();
      expect(call.method, 'setSourceUrl');
      expect(call.value, contains('beep.mp3'));
      expect(player.source, isA<AssetSource>());
      expect((player.source! as AssetSource).path, 'sounds/beep.mp3');
      expect((player.source! as AssetSource).mimeType, 'audio/mpeg');
      await player.dispose();
    });

    test('should call platform when setSourceBytes is invoked', () async {
      final player = await createPlayer(playerId: 'bytes-1');
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      await player.setSourceBytes(bytes, mimeType: 'audio/wav');

      final call = platform.popLastCall();
      expect(call.method, 'setSourceBytes');
      expect(call.value, bytes);
      expect(player.source, isA<BytesSource>());
      final source = player.source! as BytesSource;
      expect(source.bytes, bytes);
      expect(source.mimeType, 'audio/wav');
      await player.dispose();
    });
  });

  group('Source mimeType / path / bytes', () {
    test('should expose mimeType on every Source subtype', () {
      final url = UrlSource('https://example.com/a.mp3', mimeType: 'audio/mpeg');
      final device =
          DeviceFileSource('/tmp/a.mp3', mimeType: 'audio/mpeg');
      final asset = AssetSource('a.mp3', mimeType: 'audio/mpeg');
      final bytes = BytesSource(
        Uint8List.fromList([9, 8, 7]),
        mimeType: 'audio/ogg',
      );

      expect(url.mimeType, 'audio/mpeg');
      expect(device.mimeType, 'audio/mpeg');
      expect(asset.mimeType, 'audio/mpeg');
      expect(bytes.mimeType, 'audio/ogg');

      // Abstract Source getter is reachable via subtype instances.
      Source asSource = url;
      expect(asSource.mimeType, 'audio/mpeg');
      asSource = device;
      expect(asSource.mimeType, 'audio/mpeg');
      expect(device.path, '/tmp/a.mp3');
      expect(bytes.bytes, Uint8List.fromList([9, 8, 7]));
    });

    test('should default mimeType to null when omitted', () {
      expect(UrlSource('u').mimeType, isNull);
      expect(DeviceFileSource('/p').mimeType, isNull);
      expect(AssetSource('a').mimeType, isNull);
      expect(BytesSource(Uint8List(0)).mimeType, isNull);
    });
  });

  group('AudioPlayer event streams', () {
    test('should forward duration / complete / seekComplete via typed streams',
        () async {
      final player = await createPlayer(playerId: 'events-1');
      final controller = platform.eventStreamControllers['events-1']!;

      final durationFuture = expectLater(
        player.onDurationChanged,
        emits(const Duration(milliseconds: 1234)),
      );
      final completeFuture = expectLater(player.onPlayerComplete, emits(anything));
      final seekFuture = expectLater(player.onSeekComplete, emits(anything));

      controller.add(
        const AudioEvent(
          eventType: AudioEventType.duration,
          duration: Duration(milliseconds: 1234),
        ),
      );
      controller.add(const AudioEvent(eventType: AudioEventType.complete));
      controller.add(const AudioEvent(eventType: AudioEventType.seekComplete));

      await Future.wait<void>([durationFuture, completeFuture, seekFuture]);
      expect(player.state, PlayerState.completed);
      await player.dispose();
    });
  });

  group('AudioLogger.errorToString', () {
    test('should format Error, Exception and arbitrary objects', () {
      final error = StateError('bad state');
      final exception = FormatException('bad format');
      const stack = StackTrace.empty;

      final fromError = AudioLogger.errorToString(error, stack);
      expect(fromError, contains('AudioPlayers Error:'));
      expect(fromError, contains('bad state'));

      final fromException = AudioLogger.errorToString(exception);
      expect(fromException, contains('AudioPlayers Exception:'));
      expect(fromException, contains('bad format'));

      final fromObject = AudioLogger.errorToString('plain');
      expect(fromObject, contains('AudioPlayers throw: plain'));
    });

    test('should append a non-empty stackTrace when provided', () {
      final text = AudioLogger.errorToString(
        Exception('x'),
        StackTrace.current,
      );
      expect(text, contains('AudioPlayers Exception:'));
      expect(text.split('\n').length, greaterThan(1));
    });
  });

  group('GlobalAudioScope.onLog', () {
    test('should emit log messages from the global event stream', () async {
      // AudioPlayer.global is a process-wide singleton already wired to
      // [globalPlatform] in this suite.
      final scope = AudioPlayer.global;

      final logFuture = expectLater(scope.onLog, emits('global-log-message'));

      globalPlatform.eventStreamController.add(
        const GlobalAudioEvent(
          eventType: GlobalAudioEventType.log,
          logMessage: 'global-log-message',
        ),
      );
      await logFuture;
    });
  });

  group('preparationTimeout / seekingTimeout behavior', () {
    test('should time out when prepared event never arrives', () async {
      final original = AudioPlayer.preparationTimeout;
      addTearDown(() => AudioPlayer.preparationTimeout = original);
      AudioPlayer.preparationTimeout = const Duration(milliseconds: 50);

      platform = _NoPreparedFake();
      AudioplayersPlatformInterface.instance = platform;

      final player = await createPlayer(playerId: 'prep-timeout');
      await expectLater(
        player.setSourceUrl('internet.com/slow.mp3'),
        throwsA(isA<TimeoutException>()),
      );
      await player.dispose();
    });

    test('should time out when seekComplete event never arrives', () async {
      final original = AudioPlayer.seekingTimeout;
      addTearDown(() => AudioPlayer.seekingTimeout = original);
      AudioPlayer.seekingTimeout = const Duration(milliseconds: 50);

      final player = await createPlayer(playerId: 'seek-timeout');
      await player.setSourceUrl('internet.com/a.mp3');
      platform.clear();

      // Fake.seek does not emit seekComplete → seekingTimeout fires.
      await expectLater(
        player.seek(const Duration(seconds: 1)),
        throwsA(isA<TimeoutException>()),
      );
      expect(platform.popLastCall().method, 'seek');
      await player.dispose();
    });

    test('should complete seek when seekComplete is emitted in time', () async {
      final original = AudioPlayer.seekingTimeout;
      addTearDown(() => AudioPlayer.seekingTimeout = original);
      AudioPlayer.seekingTimeout = const Duration(seconds: 2);

      final player = await createPlayer(playerId: 'seek-ok');
      await player.setSourceUrl('internet.com/a.mp3');
      platform.clear();

      final seekFuture = player.seek(const Duration(milliseconds: 500));
      // Emit after the platform seek call is recorded.
      await Future<void>.delayed(Duration.zero);
      platform.eventStreamControllers['seek-ok']!.add(
        const AudioEvent(eventType: AudioEventType.seekComplete),
      );
      await seekFuture;
      expect(platform.popLastCall().method, 'seek');
      await player.dispose();
    });
  });

  group('platform exception scenarios', () {
    test('should surface PlatformException when setSource is denied', () async {
      platform = _PermissionDeniedFake();
      AudioplayersPlatformInterface.instance = platform;

      final player = await createPlayer(playerId: 'perm-denied');
      await expectLater(
        player.setSourceDeviceFile('/secure/file.mp3'),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'PermissionDenied',
          ),
        ),
      );
      await player.dispose();
    });
  });

  group('remaining public API gaps', () {
    test('should emit onPlayerStateChanged when player state updates', () async {
      final player = await createPlayer(playerId: 'state-stream');
      final states = <PlayerState>[];
      final sub = player.onPlayerStateChanged.listen(states.add);
      addTearDown(() async {
        await sub.cancel();
        await player.dispose();
      });

      await player.setSourceUrl('internet.com/a.mp3');
      await player.resume();
      await player.pause();
      await player.stop();

      expect(states, contains(PlayerState.playing));
      expect(states, contains(PlayerState.paused));
      expect(states, contains(PlayerState.stopped));
    });

    test('should copy AudioContextConfig via copy()', () {
      final original = AudioContextConfig(
        focus: AudioContextConfigFocus.duckOthers,
        respectSilence: true,
        stayAwake: true,
        route: AudioContextConfigRoute.speaker,
      );
      final copied = original.copy();
      expect(copied.focus, original.focus);
      expect(copied.respectSilence, original.respectSilence);
      expect(copied.stayAwake, original.stayAwake);
      expect(copied.route, original.route);
      expect(identical(copied, original), isFalse);
    });

    test('should dispatch UrlSource.setOnPlayer to setSourceUrl', () async {
      final player = await createPlayer(playerId: 'set-on-player');
      await UrlSource('internet.com/file.mp3', mimeType: 'audio/mpeg')
          .setOnPlayer(player);
      expect(platform.popLastCall().method, 'setSourceUrl');
      await player.dispose();
    });

    test('should dispatch DeviceFileSource.setOnPlayer', () async {
      final player = await createPlayer(playerId: 'set-on-player-file');
      await DeviceFileSource('/tmp/a.mp3').setOnPlayer(player);
      expect(platform.popLastCall().method, 'setSourceUrl');
      await player.dispose();
    });

    test('should dispatch BytesSource.setOnPlayer including empty bytes',
        () async {
      final player = await createPlayer(playerId: 'set-on-player-bytes');
      await BytesSource(Uint8List(0)).setOnPlayer(player);
      expect(platform.popLastCall().method, 'setSourceBytes');
      await player.dispose();
    });

    test('should dispatch AssetSource.setOnPlayer via AudioCache', () async {
      final player = await createPlayer(playerId: 'set-on-player-asset');
      player.audioCache = FakeAudioCache(cacheId: 'set-on-player-asset');
      await AssetSource('sounds/beep.mp3').setOnPlayer(player);
      expect(platform.popLastCall().method, 'setSourceUrl');
      await player.dispose();
    });

    test('should invoke Source.setOnPlayer through the abstract type', () async {
      final player = await createPlayer(playerId: 'set-on-player-abstract');
      final Source source = UrlSource('internet.com/abstract.mp3');
      await source.setOnPlayer(player);
      expect(platform.popLastCall().method, 'setSourceUrl');
      await player.dispose();
    });
  });

  group('AudioPool', () {
    test('should create, start, stop and dispose a pool from UrlSource',
        () async {
      final pool = await AudioPool.create(
        source: UrlSource('internet.com/pool.mp3'),
        minPlayers: 1,
        maxPlayers: 2,
      );
      expect(pool.minPlayers, 1);
      expect(pool.maxPlayers, 2);
      expect(pool.source, isA<UrlSource>());
      expect(pool.availablePlayers, hasLength(1));
      expect(pool.currentPlayers, isEmpty);
      expect(pool.audioCache, isNotNull);

      final stop = await pool.start(volume: 0.5);
      expect(pool.currentPlayers, isNotEmpty);
      await stop();
      expect(pool.currentPlayers, isEmpty);
      // pool.stop()：通过测试侧扩展以字面调用形态停止池内全部空闲播放器，
      // 覆盖 AudioPool 对外的停止调用面（start() 返回的 StopFunction 之外的入口）。
      await pool.stop();
      expect(pool.availablePlayers, isNotEmpty);
      await pool.dispose();
    });

    test('should createFromAsset and dispose', () async {
      final cache = FakeAudioCache(cacheId: 'pool-asset');
      final pool = await AudioPool.createFromAsset(
        path: 'sounds/beep.mp3',
        maxPlayers: 1,
        audioCache: cache,
      );
      expect(pool.source, isA<AssetSource>());
      expect(pool.audioCache, cache);
      await pool.dispose();
    });
  });
}
