//ignore_for_file: avoid_redundant_argument_values
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'fake_global_audioplayers_platform.dart';

/// 基于 mockito 的平台接口 Mock：
/// 使用手写 Mock 类（非代码生成），验证 AudioPlayer 对平台调用的编排逻辑。
///
/// mockito 空安全要求：非空返回类型的方法必须显式 override 并转发到
/// `super.noSuchMethod`，`when`/`verify` 才能捕获调用。
class MockAudioplayersPlatform extends Mock
    implements AudioplayersPlatformInterface {
  final Map<String, StreamController<AudioEvent>> _eventControllers = {};

  StreamController<AudioEvent> eventController(String playerId) {
    return _eventControllers.putIfAbsent(
      playerId,
      StreamController<AudioEvent>.broadcast,
    );
  }

  void closeAll() {
    for (final controller in _eventControllers.values) {
      controller.close();
    }
    _eventControllers.clear();
  }

  @override
  Future<void> create(String playerId) => super.noSuchMethod(
        Invocation.method(#create, [playerId]),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      ) as Future<void>;

  @override
  Future<void> dispose(String playerId) => super.noSuchMethod(
        Invocation.method(#dispose, [playerId]),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      ) as Future<void>;

  @override
  Future<void> pause(String playerId) => super.noSuchMethod(
        Invocation.method(#pause, [playerId]),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      ) as Future<void>;

  @override
  Future<void> stop(String playerId) => super.noSuchMethod(
        Invocation.method(#stop, [playerId]),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      ) as Future<void>;

  @override
  Future<void> resume(String playerId) => super.noSuchMethod(
        Invocation.method(#resume, [playerId]),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      ) as Future<void>;

  @override
  Future<void> release(String playerId) => super.noSuchMethod(
        Invocation.method(#release, [playerId]),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      ) as Future<void>;

  @override
  Future<void> seek(String playerId, Duration position) => super.noSuchMethod(
        Invocation.method(#seek, [playerId, position]),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      ) as Future<void>;

  @override
  Future<void> setVolume(String playerId, double volume) => super.noSuchMethod(
        Invocation.method(#setVolume, [playerId, volume]),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      ) as Future<void>;

  @override
  Future<void> setSourceUrl(
    String playerId,
    String url, {
    bool? isLocal,
    String? mimeType,
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #setSourceUrl,
          [playerId, url],
          {#isLocal: isLocal, #mimeType: mimeType},
        ),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      ) as Future<void>;

  @override
  Future<void> setSourceBytes(
    String playerId,
    Uint8List bytes, {
    String? mimeType,
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #setSourceBytes,
          [playerId, bytes],
          {#mimeType: mimeType},
        ),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      ) as Future<void>;

  @override
  Stream<AudioEvent> getEventStream(String playerId) => super.noSuchMethod(
        Invocation.method(#getEventStream, [playerId]),
        returnValue: const Stream<AudioEvent>.empty(),
        returnValueForMissingStub: const Stream<AudioEvent>.empty(),
      ) as Stream<AudioEvent>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final globalPlatform = FakeGlobalAudioplayersPlatform();
  GlobalAudioplayersPlatformInterface.instance = globalPlatform;

  late MockAudioplayersPlatform platform;

  setUp(() {
    platform = MockAudioplayersPlatform();
    AudioplayersPlatformInterface.instance = platform;
  });

  tearDown(() {
    platform.closeAll();
  });

  Future<AudioPlayer> createPlayer(String playerId) async {
    // 平台基础桩：create / getEventStream / dispose 等均成功完成
    when(platform.create(playerId)).thenAnswer((_) async {});
    when(platform.getEventStream(playerId)).thenAnswer(
      (_) => platform.eventController(playerId).stream,
    );
    when(platform.dispose(playerId)).thenAnswer((_) async {});
    when(platform.stop(playerId)).thenAnswer((_) async {});
    when(platform.release(playerId)).thenAnswer((_) async {});

    final player = AudioPlayer(playerId: playerId);
    player.positionUpdater = null;
    await player.creatingCompleter.future;
    clearInteractions(platform);
    return player;
  }

  group('AudioPlayer orchestrated platform calls (mockito)', () {
    test('setVolume delegates to platform once with the given value', () async {
      final player = await createPlayer('mock-volume');
      await player.setVolume(0.42);

      verify(platform.setVolume('mock-volume', 0.42)).called(1);
      verifyNoMoreInteractions(platform);
      await player.dispose();
    });

    test('pause then resume map to the matching platform calls', () async {
      final player = await createPlayer('mock-pause-resume');
      await player.pause();
      await player.resume();

      verifyInOrder([
        platform.pause('mock-pause-resume'),
        platform.resume('mock-pause-resume'),
      ]);
      verifyNever(platform.stop('mock-pause-resume'));
      await player.dispose();
    });

    test('setSourceUrl emits prepared event and resolves setSource', () async {
      final player = await createPlayer('mock-source-url');
      when(
        platform.setSourceUrl(
          'mock-source-url',
          'internet.com/mocked.mp3',
          isLocal: false,
          mimeType: null,
        ),
      ).thenAnswer((_) async {
        platform.eventController('mock-source-url').add(
              const AudioEvent(
                eventType: AudioEventType.prepared,
                isPrepared: true,
              ),
            );
      });

      await player.setSourceUrl('internet.com/mocked.mp3');

      verify(
        platform.setSourceUrl(
          'mock-source-url',
          'internet.com/mocked.mp3',
          isLocal: false,
          mimeType: null,
        ),
      ).called(1);
      expect(player.source, isA<UrlSource>());
      await player.dispose();
    });

    test('setSourceBytes propagates the byte payload', () async {
      final player = await createPlayer('mock-source-bytes');
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      when(
        platform.setSourceBytes(
          'mock-source-bytes',
          bytes,
          mimeType: null,
        ),
      ).thenAnswer((_) async {
        platform.eventController('mock-source-bytes').add(
              const AudioEvent(
                eventType: AudioEventType.prepared,
                isPrepared: true,
              ),
            );
      });

      await player.setSourceBytes(bytes);

      verify(
        platform.setSourceBytes(
          'mock-source-bytes',
          bytes,
          mimeType: null,
        ),
      ).called(1);
      expect(player.source, isA<BytesSource>());
      await player.dispose();
    });

    test('platform errors from seek surface to the caller', () async {
      final player = await createPlayer('mock-seek-error');
      when(
        platform.seek('mock-seek-error', const Duration(seconds: 1)),
      ).thenAnswer((_) async {
        // 先补发 seekComplete 事件满足 AudioPlayer.seek 的事件等待，再抛错
        platform.eventController('mock-seek-error').add(
              const AudioEvent(eventType: AudioEventType.seekComplete),
            );
        throw PlatformException(code: 'SeekError', message: 'seek failed');
      });

      await expectLater(
        player.seek(const Duration(seconds: 1)),
        throwsA(isA<PlatformException>()),
      );
      verify(
        platform.seek('mock-seek-error', const Duration(seconds: 1)),
      ).called(1);
      await player.dispose();
    });
  });
}
