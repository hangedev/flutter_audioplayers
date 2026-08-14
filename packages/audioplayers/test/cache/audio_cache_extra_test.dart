import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';

// FakeAudioCache is defined inside the upstream audio_cache_test.dart.
import '../audio_cache_test.dart' show FakeAudioCache;

void main() {
  setUp(() {
    AudioCache.fileSystem = MemoryFileSystem.test();
  });

  group('AudioCache.prefix', () {
    test('should default to assets/', () {
      final cache = AudioCache();
      expect(cache.prefix, 'assets/');
    });

    test('should accept a custom prefix', () {
      final cache = AudioCache(prefix: 'sounds/');
      expect(cache.prefix, 'sounds/');
    });

    test('should be mutable after construction', () {
      final cache = AudioCache();
      cache.prefix = 'audio/';
      expect(cache.prefix, 'audio/');
    });
  });

  group('AudioCache.loadAsFile', () {
    test('should load a file into the cache and return a File', () async {
      final cache = FakeAudioCache();
      final file = await cache.loadAsFile('beep.wav');

      expect(file.existsSync(), isTrue);
      // FakeAudioCache.loadAsset returns the utf8 bytes of the full asset path
      // (prefix + name); the cached content must correspond to the requested key.
      expect(utf8.decode(file.readAsBytesSync()), contains('beep.wav'));
    });
  });

  group('AudioCache.loadAsBytes', () {
    test('should load a file into the cache and return its bytes', () async {
      final cache = FakeAudioCache();
      final bytes = await cache.loadAsBytes('beep.wav');

      // FakeAudioCache.loadAsset returns the utf8 bytes of the full asset path
      // (prefix + name); the loaded bytes must decode back to that content.
      expect(bytes, isNotNull);
      expect(utf8.decode(bytes), contains('beep.wav'));
    });

    test('should return identical bytes on a second (cached) load', () async {
      final cache = FakeAudioCache();
      final first = await cache.loadAsBytes('beep.wav');
      final second = await cache.loadAsBytes('beep.wav');

      expect(second, first);
    });
  });

  group('AudioCache.loadAll', () {
    test('should load multiple files and return their uris', () async {
      final cache = FakeAudioCache();
      final uris = await cache.loadAll(<String>['a.wav', 'b.wav']);

      expect(uris, hasLength(2));
      expect(uris[0].path, contains('a.wav'));
      expect(uris[1].path, contains('b.wav'));
    });
  });
}
