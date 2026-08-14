import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_global_audioplayers_platform.dart';

void main() {
  late FakeGlobalAudioplayersPlatform platform;
  late GlobalAudioScope scope;

  setUp(() {
    platform = FakeGlobalAudioplayersPlatform();
    GlobalAudioplayersPlatformInterface.instance = platform;
    // Build a fresh scope so it binds to the fake platform set above.
    scope = GlobalAudioScope();
  });

  group('GlobalAudioScope', () {
    test('onLog should emit global log messages', () async {
      final received = <String>[];
      final sub = scope.onLog.listen(received.add);

      platform.emitGlobalLog('a global log');
      await Future<void>.delayed(Duration.zero);

      expect(received, equals(<String>['a global log']));

      await sub.cancel();
    });

    test('eventStream should forward errors from the platform', () async {
      final errors = <Object>[];
      final sub = scope.eventStream.listen(
        (_) {},
        onError: errors.add,
      );

      platform.emitGlobalError('code', 'a global error');
      await Future<void>.delayed(Duration.zero);

      expect(errors, isNotEmpty);

      await sub.cancel();
    });

    test('setAudioContext should call the platform', () async {
      await scope.setAudioContext(AudioContext());

      expect(
        platform.calls.map((c) => c.method),
        contains('setGlobalAudioContext'),
      );
    });
  });
}
