//ignore_for_file: comment_references, lines_longer_than_80_chars

import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';

import 'audio_cache_test.dart';
import 'fake_audioplayers_platform.dart';
import 'fake_global_audioplayers_platform.dart';

/// Coverage for previously-uncovered public APIs:
/// - [AudioPlayerException] (constructor, player, cause)
/// - [AudioPlayer] static [preparationTimeout] / [seekingTimeout]
/// - [AudioPool.create] / [dispose] / [minPlayers] / [maxPlayers] / [audioContext]
/// - [GlobalAudioScope] constructor / [ensureInitialized]
/// - [AudioCache] [prefix] / [loadAsFile] / [loadAll] / [loadPath]
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final globalPlatform = FakeGlobalAudioplayersPlatform();
  GlobalAudioplayersPlatformInterface.instance = globalPlatform;

  setUp(() {
    AudioplayersPlatformInterface.instance = FakeAudioplayersPlatform();
    AudioCache.fileSystem = MemoryFileSystem.test();
  });

  group('AudioPlayerException', () {
    Future<AudioPlayer> createPlayer(String playerId) async {
      final player = AudioPlayer(playerId: playerId);
      player.positionUpdater = null;
      await player.creatingCompleter.future;
      return player;
    }

    test('should store the associated player and an optional cause', () async {
      final player = await createPlayer('exc-1');
      final exception = AudioPlayerException(player, cause: 'boom');

      expect(exception.player, same(player));
      expect(exception.cause, 'boom');
      await player.dispose();
    });

    test('should default to a null cause when none is provided', () async {
      final player = await createPlayer('exc-2');
      final exception = AudioPlayerException(player);

      expect(exception.cause, isNull);
      expect(exception.player, same(player));
      await player.dispose();
    });

    test('should mention the source and cause in its toString output', () async {
      final player = await createPlayer('exc-3');
      await player.setSource(UrlSource('internet.com/audio.mp3'));
      final exception = AudioPlayerException(player, cause: 'timeout');

      final text = exception.toString();
      expect(text, contains('AudioPlayerException'));
      expect(text, contains('timeout'));
      await player.dispose();
    });
  });

  group('AudioPlayer static timeouts', () {
    test('should expose configurable preparation/seeking timeouts', () {
      // Sanity-check the defaults exposed on the public API surface and that
      // they are assignable (which is how callers tune prepare/seek behavior).
      final originalPreparation = AudioPlayer.preparationTimeout;
      final originalSeeking = AudioPlayer.seekingTimeout;
      addTearDown(() {
        AudioPlayer.preparationTimeout = originalPreparation;
        AudioPlayer.seekingTimeout = originalSeeking;
      });

      AudioPlayer.preparationTimeout = const Duration(seconds: 5);
      AudioPlayer.seekingTimeout = const Duration(seconds: 8);

      expect(AudioPlayer.preparationTimeout, const Duration(seconds: 5));
      expect(AudioPlayer.seekingTimeout, const Duration(seconds: 8));
    });
  });

  group('AudioPool', () {
    test('should honor minPlayers/maxPlayers/audioContext when created', () async {
      final pool = await AudioPool.create(
        source: AssetSource('audio.mp3'),
        maxPlayers: 4,
        minPlayers: 2,
        audioCache: FakeAudioCache(),
      );
      addTearDown(pool.dispose);

      expect(pool.maxPlayers, 4);
      expect(pool.minPlayers, 2);
      expect(pool.audioContext, isNull);
      // minPlayers players are eagerly allocated on creation.
      expect(pool.availablePlayers.length, 2);
    });

    test('should default minPlayers to 1 when omitted', () async {
      final pool = await AudioPool.create(
        source: AssetSource('audio.mp3'),
        maxPlayers: 3,
        audioCache: FakeAudioCache(),
      );
      addTearDown(pool.dispose);

      expect(pool.minPlayers, 1);
      expect(pool.availablePlayers.length, 1);
    });

    test('should store a provided audioContext', () async {
      final context = AudioContext(
        ohos: const AudioContextOhos(usageType: OhosUsageType.game),
      );
      final pool = await AudioPool.create(
        source: AssetSource('audio.mp3'),
        maxPlayers: 2,
        audioContext: context,
        audioCache: FakeAudioCache(),
      );
      addTearDown(pool.dispose);

      expect(pool.audioContext, same(context));
    });

    test('should dispose all pooled players', () async {
      final pool = await AudioPool.create(
        source: AssetSource('audio.mp3'),
        maxPlayers: 3,
        minPlayers: 2,
        audioCache: FakeAudioCache(),
      );
      expect(pool.availablePlayers, isNotEmpty);
      final players = List<AudioPlayer>.from(pool.availablePlayers);

      await pool.dispose();
      // dispose() awaits each player's dispose(); players remain listed but are
      // marked disposed (lib does not clear availablePlayers).
      expect(pool.currentPlayers, isEmpty);
      for (final player in players) {
        expect(player.state, PlayerState.disposed);
      }
    });
  });

  group('GlobalAudioScope', () {
    test('should initialize the global platform on ensureInitialized', () async {
      // Reset so ensureInitialized performs a fresh platform init().
      // (AudioPlayer.global / prior tests may already have initialized once.)
      globalPlatform.clear();
      final scope = GlobalAudioScope();
      // Constructor always wires getGlobalEventStream.
      expect(globalPlatform.popCall().method, 'getGlobalEventStream');

      // Force re-init by swapping the platform instance identity check via a
      // second Fake that is assigned as the global instance.
      final fresh = FakeGlobalAudioplayersPlatform();
      GlobalAudioplayersPlatformInterface.instance = fresh;
      addTearDown(() {
        GlobalAudioplayersPlatformInterface.instance = globalPlatform;
      });

      final scope2 = GlobalAudioScope();
      expect(fresh.popCall().method, 'getGlobalEventStream');
      await scope2.ensureInitialized();
      expect(fresh.popCall().method, 'init');

      // Keep analyzer quiet about unused prior scope.
      expect(scope.eventStream, isA<Stream<GlobalAudioEvent>>());
    });

    test('should expose a non-empty global event stream', () {
      final scope = GlobalAudioScope();
      expect(scope.eventStream, isA<Stream<GlobalAudioEvent>>());
    });
  });

  group('AudioCache extended API', () {
    test('should use and update the configurable prefix', () async {
      final cache = FakeAudioCache(prefix: 'assets/audio/');
      expect(cache.prefix, 'assets/audio/');

      cache.prefix = 'sounds/';
      expect(cache.prefix, 'sounds/');
    });

    test('should return a File when loadAsFile is called', () async {
      final cache = FakeAudioCache();
      final file = await cache.loadAsFile('audio.mp3');
      expect(file.existsSync(), isTrue);
      expect(cache.loadedFiles.containsKey('audio.mp3'), isTrue);
    });

    test('should load multiple files in a single loadAll call', () async {
      final cache = FakeAudioCache();
      final uris = await cache.loadAll(['a.mp3', 'b.mp3', 'c.mp3']);
      expect(uris, hasLength(3));
      expect(cache.loadedFiles.keys, containsAll(['a.mp3', 'b.mp3', 'c.mp3']));
    });

    test('should return a decoded file path from loadPath', () async {
      final cache = FakeAudioCache(cacheId: 'cache-path');
      final path = await cache.loadPath('audio.mp3');
      // On non-web targets the path is URI-decoded and points into temp dir.
      expect(path, contains('cache-path'));
      expect(path, contains('audio.mp3'));
    });
  });
}
