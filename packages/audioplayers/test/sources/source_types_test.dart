import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_audioplayers_platform.dart';
import '../fake_global_audioplayers_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final globalPlatform = FakeGlobalAudioplayersPlatform();
  GlobalAudioplayersPlatformInterface.instance = globalPlatform;

  late FakeAudioplayersPlatform platform;
  setUp(() {
    platform = FakeAudioplayersPlatform();
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

  group('Source types', () {
    late AudioPlayer player;

    setUp(() async {
      player = await createPlayer('p1');
    });

    tearDown(() => player.dispose());

    group('UrlSource', () {
      test('should expose url and explicit mimeType', () {
        final source = UrlSource(
          'internet.com/file.mp3',
          mimeType: 'audio/mpeg',
        );
        expect(source.url, 'internet.com/file.mp3');
        expect(source.mimeType, 'audio/mpeg');
      });

      test('should default mimeType to null when not provided', () {
        final source = UrlSource('internet.com/file.ogg');
        expect(source.mimeType, isNull);
      });

      test('should dispatch to setSourceUrl when set on a player', () async {
        await UrlSource('internet.com/file.mp3').setOnPlayer(player);
        final call = platform.popLastCall();
        expect(call.method, 'setSourceUrl');
        expect(call.value, 'internet.com/file.mp3');
      });
    });

    group('DeviceFileSource', () {
      test('should expose path and mimeType', () {
        final source = DeviceFileSource(
          '/data/local/tmp/a.mp3',
          mimeType: 'audio/mpeg',
        );
        expect(source.path, '/data/local/tmp/a.mp3');
        expect(source.mimeType, 'audio/mpeg');
      });

      test('should default mimeType to null when not provided', () {
        final source = DeviceFileSource('/data/local/tmp/a.wav');
        expect(source.mimeType, isNull);
      });

      test('should dispatch to setSourceDeviceFile when set on a player',
          () async {
        await DeviceFileSource('/data/local/tmp/a.mp3').setOnPlayer(player);
        final call = platform.popLastCall();
        expect(call.method, 'setSourceUrl');
        expect(call.value, '/data/local/tmp/a.mp3');
      });
    });

    group('AssetSource', () {
      test('should expose path and mimeType', () {
        final source = AssetSource('assets/audio.mp3', mimeType: 'audio/mpeg');
        expect(source.path, 'assets/audio.mp3');
        expect(source.mimeType, 'audio/mpeg');
      });

      test('should default mimeType to null when not provided', () {
        final source = AssetSource('assets/audio.wav');
        expect(source.mimeType, isNull);
      });
    });

    group('BytesSource', () {
      test('should expose bytes and mimeType', () {
        final bytes = Uint8List.fromList([1, 2, 3, 4]);
        final source = BytesSource(bytes, mimeType: 'audio/mpeg');
        expect(source.bytes, same(bytes));
        expect(source.mimeType, 'audio/mpeg');
      });

      test('should default mimeType to null when not provided', () {
        final source = BytesSource(Uint8List.fromList([1, 2, 3]));
        expect(source.mimeType, isNull);
      });
    });

    group('Source base interface', () {
      test('should expose mimeType through the Source base type', () {
        final sources = <Source>[
          UrlSource('internet.com/a.mp3', mimeType: 'audio/mpeg'),
          DeviceFileSource('/tmp/a.mp3', mimeType: 'audio/mpeg'),
          AssetSource('assets/a.mp3', mimeType: 'audio/mpeg'),
          BytesSource(Uint8List.fromList([1]), mimeType: 'audio/mpeg'),
        ];
        for (final source in sources) {
          expect(source.mimeType, 'audio/mpeg');
        }
      });

      test('should dispatch setOnPlayer through the Source base type',
          () async {
        final Source source =
            DeviceFileSource('/data/local/tmp/base.mp3');
        await source.setOnPlayer(player);
        final call = platform.popLastCall();
        expect(call.method, 'setSourceUrl');
        expect(call.value, '/data/local/tmp/base.mp3');
      });
    });
  });
}
