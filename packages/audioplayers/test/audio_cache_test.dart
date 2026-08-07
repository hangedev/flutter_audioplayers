import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAudioCache extends AudioCache {
  List<String> called = [];

  FakeAudioCache({super.prefix, super.cacheId});

  @override
  Future<Uri> fetchToMemory(String fileName) async {
    called.add(fileName);
    return super.fetchToMemory(fileName);
  }

  @override
  Future<ByteData> loadAsset(String path) async {
    return ByteData.sublistView(utf8.encode(path));
  }

  @override
  Future<String> getTempDir() async => '/';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AudioCache.fileSystem = MemoryFileSystem.test();
  });

  group('AudioCache', () {
    test('sets cache', () async {
      final cache = FakeAudioCache();
      await cache.load('audio.mp3');
      expect(cache.loadedFiles['audio.mp3'], isNotNull);
      expect(cache.called, hasLength(1));
      cache.called.clear();

      await cache.load('audio.mp3');
      expect(cache.called, hasLength(0));
    });

    test('clear cache', () async {
      final cache = FakeAudioCache();
      await cache.load('audio.mp3');
      expect(cache.loadedFiles['audio.mp3'], isNotNull);
      await cache.clearAll();
      expect(cache.loadedFiles, <String, Uri>{});
      await cache.load('audio.mp3');
      expect(cache.loadedFiles.isNotEmpty, isTrue);
      await cache.clear('audio.mp3');
      expect(cache.loadedFiles, <String, Uri>{});
    });

    test('should load asset bytes via loadAsBytes', () async {
      final cache = FakeAudioCache();
      final bytes = await cache.loadAsBytes('audio.mp3');
      expect(bytes, isA<Uint8List>());
      expect(bytes, isNotEmpty);
      // loadAsBytes should also populate the in-memory cache.
      expect(cache.loadedFiles['audio.mp3'], isNotNull);
      await cache.clearAll();
    });

    test('should loadPath, loadAll and expose prefix / cacheId', () async {
      final cache = FakeAudioCache(prefix: 'sfx/', cacheId: 'id-1');
      expect(cache.prefix, 'sfx/');
      expect(cache.cacheId, 'id-1');

      final path = await cache.loadPath('audio.mp3');
      expect(path, contains('audio.mp3'));

      final uris = await cache.loadAll(['audio.mp3', 'laser.wav']);
      expect(uris, hasLength(2));
      expect(cache.loadedFiles.length, greaterThanOrEqualTo(2));

      final file = await cache.loadAsFile('audio.mp3');
      expect(file.path, contains('audio.mp3'));
      await cache.clearAll();
    });

    test('Use different location for two audio caches', () async {
      const fileName = 'audio.mp3';
      final cacheA = FakeAudioCache(cacheId: 'cache-path-A');
      await cacheA.load(fileName);
      expect(cacheA.loadedFiles[fileName]?.path, '//cache-path-A/audio.mp3');

      final cacheB = FakeAudioCache(cacheId: 'cache-path-B');
      await cacheB.load(fileName);
      expect(cacheB.loadedFiles[fileName]?.path, '//cache-path-B/audio.mp3');

      await cacheA.clearAll();
      await cacheB.clearAll();
    });
  });
}
