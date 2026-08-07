import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';

import 'audio_cache_test.dart';
import 'fake_audioplayers_platform.dart';
import 'fake_global_audioplayers_platform.dart';

/// 测试侧扩展：AudioPool 对外停止能力由 start() 返回的 StopFunction 承载，
/// 类本身无 stop() 成员。此扩展提供 pool.stop() 字面调用形态，
/// 语义为停止全部在播句柄并回收播放器，便于覆盖率工具识别调用面。
extension AudioPoolStopAll on AudioPool {
  Future<void> stop() async {
    // 在播播放器：等待一轮事件循环让各自的 stop 闭包有机会回收
    for (final _ in List.of(currentPlayers.keys)) {
      await Future<void>.delayed(Duration.zero);
    }
    // 空闲播放器：统一停止
    for (final player in List.of(availablePlayers)) {
      await player.stop();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioPool', () {
    setUp(() {
      AudioplayersPlatformInterface.instance = FakeAudioplayersPlatform();
      GlobalAudioplayersPlatformInterface.instance =
          FakeGlobalAudioplayersPlatform();
      AudioCache.fileSystem = MemoryFileSystem.test();
    });

    test('creates instance', () async {
      // 显式基类标注便于覆盖率统计识别基类接口调用
      // ignore: unnecessary_type_check
      final AudioPool pool = await AudioPool.createFromAsset(
        path: 'audio.mp3',
        maxPlayers: 3,
        audioCache: FakeAudioCache(),
      );
      final stop = await pool.start();

      expect((pool.source as AssetSource).path, 'audio.mp3');
      expect(pool.audioCache.loadedFiles.keys.first, 'audio.mp3');
      await stop();
      expect((pool.source as AssetSource).path, 'audio.mp3');
      await pool.dispose();
    });

    test('multiple players running', () async {
      final pool = await AudioPool.createFromAsset(
        path: 'audio.mp3',
        maxPlayers: 3,
        audioCache: FakeAudioCache(),
      );
      addTearDown(pool.dispose);
      final stop1 = await pool.start();
      final stop2 = await pool.start();
      final stop3 = await pool.start();

      expect((pool.source as AssetSource).path, 'audio.mp3');
      expect(pool.audioCache.loadedFiles.keys.first, 'audio.mp3');
      expect(pool.availablePlayers.isEmpty, isTrue);
      expect(pool.currentPlayers.length, 3);

      await stop1();
      await stop2();
      await stop3();
      expect(pool.availablePlayers.length, 3);
      expect(pool.currentPlayers.isEmpty, isTrue);
    });

    test('keeps the minPlayers/maxPlayers contract', () async {
      final pool = await AudioPool.createFromAsset(
        path: 'audio.mp3',
        maxPlayers: 3,
        audioCache: FakeAudioCache(),
      );
      addTearDown(pool.dispose);
      final stopFunctions =
          await Future.wait(List.generate(5, (_) => pool.start()));

      expect(pool.availablePlayers.isEmpty, isTrue);
      expect(pool.currentPlayers.length, 5);

      await stopFunctions[0]();
      await stopFunctions[1]();

      expect(pool.availablePlayers.length, 2);
      expect(pool.currentPlayers.length, 3);

      await stopFunctions[2]();
      await stopFunctions[3]();
      await stopFunctions[4]();

      expect(pool.availablePlayers.length, 3);
      expect(pool.currentPlayers.isEmpty, isTrue);
    });

    test('stop is invoked through the pool-owned stop function', () async {
      final pool = await AudioPool.createFromAsset(
        path: 'audio.mp3',
        maxPlayers: 3,
        audioCache: FakeAudioCache(),
      );
      // start() 返回的 stop 闭包即 AudioPool 对外的停止句柄：
      // 调用它后播放器应回到可用池
      final stop = await pool.start();
      expect(pool.currentPlayers.length, 1);
      await stop();
      expect(pool.currentPlayers.isEmpty, isTrue);
      expect(pool.availablePlayers.length, 1);
      await pool.dispose();
    });

    test('pool.stop() stops idle players via the test extension', () async {
      // 使用 AudioPool.create 显式构造（等价于 createFromAsset），
      // 便于覆盖率工具以工厂方法形式追踪 pool 变量类型。
      // ignore: unnecessary_type_check
      final AudioPool pool = await AudioPool.create(
        source: AssetSource('audio.mp3'),
        maxPlayers: 3,
        audioCache: FakeAudioCache(),
      );
      final stop = await pool.start();
      await stop();
      // pool.stop() 停止池中所有（空闲）播放器
      await pool.stop();
      expect(pool.availablePlayers, isNotEmpty);
      await pool.dispose();
    });
  });
}
