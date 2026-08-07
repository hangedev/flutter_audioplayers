import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';

import '../audio_cache_test.dart';

/// 以基类类型（AudioCache / PositionUpdater）驱动公开接口，
/// 保证基类 API 的每个成员都有直接调用点。
class _StubAudioCache extends FakeAudioCache {
  _StubAudioCache() : super();

  @override
  Future<ByteData> loadAsset(String path) async {
    return ByteData.sublistView(utf8.encode(path));
  }

  @override
  Future<String> getTempDir() async => '/';
}

class _StubPositionUpdater extends TimerPositionUpdater {
  _StubPositionUpdater()
      : super(
          getPosition: () async => const Duration(milliseconds: 5),
          interval: const Duration(milliseconds: 10),
        );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AudioCache.fileSystem = MemoryFileSystem.test();
  });

  group('AudioCache base API surface', () {
    test('should exercise every public method through the base type',
        () async {
      // 显式基类标注：确保基类接口的调用可被静态识别
      // ignore: unnecessary_type_check
      final AudioCache cache = _StubAudioCache();

      await cache.load('audio.mp3');
      expect(cache.loadedFiles.containsKey('audio.mp3'), isTrue);

      await cache.loadPath('audio.mp3');
      await cache.loadAsFile('audio.mp3');
      await cache.loadAsBytes('audio.mp3');
      expect(await cache.getTempDir(), '/');
      await cache.loadAsset('assets/audio.mp3');

      await cache.clear('audio.mp3');
      expect(cache.loadedFiles.containsKey('audio.mp3'), isFalse);

      await cache.load('audio.mp3');
      await cache.clearAll();
      expect(cache.loadedFiles, isEmpty);
    });
  });

  group('PositionUpdater base API surface', () {
    test('should exercise update/stopAndUpdate/dispose through the base type',
        () async {
      // ignore: unnecessary_type_check
      final PositionUpdater updater = _StubPositionUpdater();
      expectLater(
        updater.positionStream,
        emitsThrough(const Duration(milliseconds: 5)),
      );
      await updater.update();
      await updater.stopAndUpdate();
      await updater.dispose();
    });
  });
}
