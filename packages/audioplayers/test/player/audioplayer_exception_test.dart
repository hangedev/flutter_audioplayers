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

  group('AudioPlayerException', () {
    test('should keep a reference to the player and an optional cause', () {
      final player = createPlayer(playerId: 'pExc');
      final cause = Object();
      final exception = AudioPlayerException(player, cause: cause);

      expect(exception.player, same(player));
      expect(exception.cause, same(cause));
      expect(exception.toString(), contains('AudioPlayerException'));
      player.dispose();
    });

    test('should allow construction without a cause', () {
      final player = createPlayer(playerId: 'pExcNull');
      final exception = AudioPlayerException(player);

      expect(exception.player, same(player));
      expect(exception.cause, isNull);
      player.dispose();
    });
  });
}
