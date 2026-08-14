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

  AudioPlayer createPlayer({required String playerId}) {
    final player = AudioPlayer(playerId: playerId);
    player.positionUpdater = null;
    return player;
  }

  group('Source.mimeType', () {
    test('UrlSource should expose the provided mime type', () {
      expect(UrlSource('a').mimeType, isNull);
      expect(UrlSource('a', mimeType: 'audio/mpeg').mimeType, 'audio/mpeg');
    });

    test('DeviceFileSource should expose the provided mime type', () {
      expect(DeviceFileSource('/x').mimeType, isNull);
      expect(
        DeviceFileSource('/x', mimeType: 'audio/wav').mimeType,
        'audio/wav',
      );
    });

    test('AssetSource should expose the provided mime type', () {
      expect(AssetSource('a').mimeType, isNull);
      expect(
        AssetSource('a', mimeType: 'audio/ogg').mimeType,
        'audio/ogg',
      );
    });

    test('BytesSource should expose the provided mime type', () {
      final bytes = Uint8List.fromList(<int>[1, 2, 3]);
      expect(BytesSource(bytes).mimeType, isNull);
      expect(
        BytesSource(bytes, mimeType: 'audio/flac').mimeType,
        'audio/flac',
      );
    });
  });

  group('Source.setOnPlayer', () {
    test('UrlSource should call setSourceUrl on the player', () async {
      final player = createPlayer(playerId: 'pUrl');
      await UrlSource('https://example.com/a.mp3').setOnPlayer(player);

      // Creating the player also records create/getEventStream calls, so match
      // the specific source call instead of asserting an exact call count.
      final call = platform.calls.firstWhere((c) => c.method == 'setSourceUrl');
      expect(call.id, 'pUrl');
      await player.dispose();
    });

    test('DeviceFileSource should call setSourceDeviceFile on the player',
        () async {
      final player = createPlayer(playerId: 'pFile');
      await DeviceFileSource('/data/a.mp3').setOnPlayer(player);

      // setSourceDeviceFile forwards to setSourceUrl with isLocal = true.
      final call = platform.calls.firstWhere((c) => c.method == 'setSourceUrl');
      expect(call.id, 'pFile');
      await player.dispose();
    });

    test('BytesSource should call setSourceBytes on the player', () async {
      final player = createPlayer(playerId: 'pBytes');
      await BytesSource(Uint8List.fromList(<int>[0, 1, 2, 3]))
          .setOnPlayer(player);

      final call =
          platform.calls.firstWhere((c) => c.method == 'setSourceBytes');
      expect(call.id, 'pBytes');
      await player.dispose();
    });
  });

  group('Source subtypes values', () {
    test('UrlSource should keep the url value', () {
      final source = UrlSource('https://e.com/x.mp3', mimeType: 'audio/mpeg');
      expect(source.url, 'https://e.com/x.mp3');
    });

    test('DeviceFileSource should keep the path value', () {
      final source = DeviceFileSource('/music/a.wav', mimeType: 'audio/wav');
      expect(source.path, '/music/a.wav');
    });

    test('AssetSource should keep the path value', () {
      final source = AssetSource('audio/sample.mp3', mimeType: 'audio/mpeg');
      expect(source.path, 'audio/sample.mp3');
    });

    test('BytesSource should keep the bytes value', () {
      final data = Uint8List.fromList(<int>[9, 9, 9]);
      final source = BytesSource(data, mimeType: 'audio/flac');
      expect(source.bytes, data);
    });
  });
}
