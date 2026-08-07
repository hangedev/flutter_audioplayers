//ignore_for_file: avoid_redundant_argument_values
import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_audioplayers_platform.dart';
import '../fake_global_audioplayers_platform.dart';

/// 并发场景测试：
/// - 同一播放器实例上的并发 API 调用（参数设置 / 播放与暂停竞态 / dispose 竞态）
/// - 并发 AudioContext 修改（全局作用域 + 播放器级别同时下发）
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
    // Avoid unpredictable position updates
    player.positionUpdater = null;
    await player.creatingCompleter.future;
    platform.clear();
    return player;
  }

  group('concurrent calls on a single player', () {
    test('concurrent parameter updates all reach the platform', () async {
      final player = await createPlayer('concurrent-params');
      await Future.wait([
        player.setVolume(0.3),
        player.setBalance(-0.5),
        player.setPlaybackRate(1.5),
        player.setReleaseMode(ReleaseMode.loop),
        player.setPlayerMode(PlayerMode.lowLatency),
      ]);

      final methods = platform.calls.map((c) => c.method).toSet();
      expect(
        methods,
        containsAll([
          'setVolume',
          'setBalance',
          'setPlaybackRate',
          'setReleaseMode',
          'setPlayerMode',
        ]),
      );
      await player.dispose();
    });

    test('play and pause issued concurrently settle without errors', () async {
      final player = await createPlayer('concurrent-play-pause');
      await Future.wait([
        player.play(UrlSource('internet.com/concurrent.mp3')),
        player.pause(),
      ]);

      // 并发竞态下最终状态可为 paused 或 playing，
      // 关键是双方调用均到达平台且不抛异常
      expect(platform.calls.map((c) => c.method), contains('pause'));
      expect(player.state, anyOf(PlayerState.paused, PlayerState.playing));
      await player.dispose();
    });

    test('dispose while parameter calls are in flight does not throw',
        () async {
      final player = await createPlayer('concurrent-dispose');
      final inFlight = Future.wait([
        player.setVolume(0.8),
        player.setBalance(0.25),
        player.setPlaybackRate(2.0),
      ]);
      await player.dispose();
      // dispose 后等待在途调用完成，不应有未处理异常
      await inFlight;
    });
  });

  group('concurrent AudioContext updates', () {
    test('global and per-player contexts applied concurrently', () async {
      final player = await createPlayer('concurrent-context');
      final playerCtx = AudioContext(
        ohos: const AudioContextOhos(usageType: OhosUsageType.game),
      );
      final globalCtx1 = AudioContext();
      final globalCtx2 = AudioContext();

      await Future.wait([
        AudioPlayer.global.setAudioContext(globalCtx1),
        AudioPlayer.global.setAudioContext(globalCtx2),
        player.setAudioContext(playerCtx),
        player.setAudioContext(playerCtx),
      ]);

      // 全局作用域应收到两次全局上下文设置（init 幂等）
      final globalMethods = globalPlatform.calls.map((c) => c.method).toList();
      expect(
        globalMethods.where((m) => m == 'setGlobalAudioContext').length,
        2,
      );
      // 播放器级别两次设置均到达平台
      expect(
        platform.calls.where((c) => c.method == 'setAudioContext').length,
        2,
      );
      await player.dispose();
    });
  });
}
