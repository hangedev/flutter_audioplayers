import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_audioplayers_platform.dart';
import '../fake_global_audioplayers_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioplayersPlatform platform;

  setUp(() {
    platform = FakeAudioplayersPlatform();
    AudioplayersPlatformInterface.instance = platform;
    GlobalAudioplayersPlatformInterface.instance =
        FakeGlobalAudioplayersPlatform();
    AudioCache.fileSystem = MemoryFileSystem.test();
  });

  group('AudioPool.create', () {
    test('should create a pool from a Source and preallocate minPlayers',
        () async {
      final pool = await AudioPool.create(
        source: UrlSource('https://example.com/a.mp3'),
        maxPlayers: 3,
        minPlayers: 2,
      );

      expect(pool.minPlayers, 2);
      expect(pool.maxPlayers, 3);
      expect(pool.availablePlayers.length, 2);
      expect(pool.currentPlayers, isEmpty);

      await pool.dispose();
    });

    test('should default minPlayers to 1 when omitted', () async {
      final pool = await AudioPool.create(
        source: UrlSource('https://example.com/b.mp3'),
        maxPlayers: 4,
      );

      expect(pool.minPlayers, 1);
      expect(pool.availablePlayers.length, 1);

      await pool.dispose();
    });
  });

  group('AudioPool.minPlayers', () {
    test('should expose the configured minimum players count', () async {
      final pool = await AudioPool.create(
        source: UrlSource('https://example.com/c.mp3'),
        maxPlayers: 5,
        minPlayers: 3,
      );

      expect(pool.minPlayers, 3);

      await pool.dispose();
    });
  });

  group('AudioPool.dispose', () {
    test('should dispose all available players', () async {
      final pool = await AudioPool.create(
        source: UrlSource('https://example.com/d.mp3'),
        maxPlayers: 2,
        minPlayers: 2,
      );

      platform.clear();
      await pool.dispose();

      // Each preallocated player is disposed on pool.dispose().
      final disposeCalls =
          platform.calls.where((c) => c.method == 'dispose').toList();
      expect(disposeCalls.length, 2);
    });
  });
}
