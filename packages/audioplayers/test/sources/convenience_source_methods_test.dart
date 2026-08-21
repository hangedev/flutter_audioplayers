import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_audioplayers_platform.dart';
import '../fake_global_audioplayers_platform.dart';

class FakeAssetAudioCache extends AudioCache {
  FakeAssetAudioCache() : super(prefix: 'assets/');

  @override
  Future<ByteData> loadAsset(String path) async {
    return ByteData.sublistView(utf8.encode(path));
  }

  @override
  Future<String> getTempDir() async => '/';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final globalPlatform = FakeGlobalAudioplayersPlatform();
  GlobalAudioplayersPlatformInterface.instance = globalPlatform;

  late FakeAudioplayersPlatform platform;
  setUp(() {
    platform = FakeAudioplayersPlatform();
    AudioplayersPlatformInterface.instance = platform;
    AudioCache.fileSystem = MemoryFileSystem.test();
  });

  Future<AudioPlayer> createPlayer(String playerId) async {
    final player = AudioPlayer(playerId: playerId);
    player.positionUpdater = null;
    await player.creatingCompleter.future;
    expect(platform.popCall().method, 'create');
    expect(platform.popLastCall().method, 'getEventStream');
    return player;
  }

  group('AudioPlayer source convenience methods', () {
    late AudioPlayer player;

    setUp(() async {
      player = await createPlayer('p1');
    });

    tearDown(() => player.dispose());

    test('should set source from a device file via setSourceDeviceFile',
        () async {
      await player.setSourceDeviceFile('/data/local/tmp/a.mp3');
      final call = platform.popLastCall();
      expect(call.method, 'setSourceUrl');
      expect(call.value, '/data/local/tmp/a.mp3');
      final source = player.source as DeviceFileSource?;
      expect(source, isNotNull);
      expect(source!.path, '/data/local/tmp/a.mp3');
    });

    test('should set source from an asset via setSourceAsset', () async {
      player.audioCache = FakeAssetAudioCache();
      await player.setSourceAsset('audio.mp3');
      final call = platform.popLastCall();
      expect(call.method, 'setSourceUrl');
      expect((call.value as String).endsWith('audio.mp3'), isTrue);
      expect(player.source, isInstanceOf<AssetSource>());
      expect((player.source as AssetSource?)!.path, 'audio.mp3');
    });

    test('should set source from bytes via setSourceBytes', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      await player.setSourceBytes(bytes);
      final call = platform.popLastCall();
      expect(call.method, 'setSourceBytes');
      expect(call.value, same(bytes));
      expect(player.source, isInstanceOf<BytesSource>());
      expect((player.source as BytesSource?)!.bytes, same(bytes));
    });

    test('should forward mimeType in setSourceDeviceFile', () async {
      await player.setSourceDeviceFile(
        '/data/local/tmp/a.mp3',
        mimeType: 'audio/mpeg',
      );
      expect(platform.popLastCall().method, 'setSourceUrl');
      expect((player.source as DeviceFileSource?)!.mimeType, 'audio/mpeg');
    });

    test('should forward mimeType in setSourceBytes', () async {
      final bytes = Uint8List.fromList([5, 6, 7, 8]);
      await player.setSourceBytes(bytes, mimeType: 'audio/mpeg');
      expect(platform.popLastCall().method, 'setSourceBytes');
      expect((player.source as BytesSource?)!.mimeType, 'audio/mpeg');
    });
  });
}
