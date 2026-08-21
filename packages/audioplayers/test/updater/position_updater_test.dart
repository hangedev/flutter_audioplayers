import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PositionUpdater makeUpdater({
    required Future<Duration?> Function() getPosition,
  }) {
    return TimerPositionUpdater(
      getPosition: getPosition,
      interval: const Duration(milliseconds: 5),
    );
  }

  group('PositionUpdater', () {
    test('should expose the getPosition callback', () {
      Future<Duration?> getPosition() async => const Duration(seconds: 1);
      final updater = makeUpdater(getPosition: getPosition);

      expect(updater.getPosition, same(getPosition));
      updater.dispose();
    });

    test('should emit positions on positionStream after update', () async {
      final positions = <Duration>[];
      final updater = makeUpdater(
        getPosition: () async => const Duration(seconds: 3),
      );
      final sub = updater.positionStream.listen(positions.add);

      await updater.update();
      // Broadcast stream delivery is asynchronous; flush before asserting.
      await Future<void>.delayed(Duration.zero);

      expect(positions, equals(<Duration>[const Duration(seconds: 3)]));

      await sub.cancel();
      await updater.dispose();
    });

    test('should not emit when getPosition returns null', () async {
      final positions = <Duration>[];
      final updater = makeUpdater(getPosition: () async => null);
      final sub = updater.positionStream.listen(positions.add);

      await updater.update();

      expect(positions, isEmpty);

      await sub.cancel();
      await updater.dispose();
    });

    test('stopAndUpdate should stop and push a final position', () async {
      final positions = <Duration>[];
      final updater = makeUpdater(
        getPosition: () async => const Duration(seconds: 7),
      );
      final sub = updater.positionStream.listen(positions.add);

      await updater.stopAndUpdate();
      // Broadcast stream delivery is asynchronous; flush before asserting.
      await Future<void>.delayed(Duration.zero);

      expect(positions, equals(<Duration>[const Duration(seconds: 7)]));

      await sub.cancel();
      await updater.dispose();
    });

    test('dispose should close the position stream', () async {
      final updater = makeUpdater(getPosition: () async => Duration.zero);

      await updater.dispose();

      // A closed broadcast stream completes (onListen receives done).
      final done = Completer<bool>();
      updater.positionStream.listen(
        (_) {},
        onDone: () => done.complete(true),
      );
      expect(await done.future, isTrue);
    });

    test('start/stop should drive position emission through the base type',
        () async {
      final positions = <Duration>[];
      final updater = makeUpdater(
        getPosition: () async => const Duration(seconds: 1),
      );
      final sub = updater.positionStream.listen(positions.add);

      updater.start();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      updater.stop();

      expect(positions, isNotEmpty);

      await sub.cancel();
      await updater.dispose();
    });
  });

  group('TimerPositionUpdater', () {
    test('should expose the configured interval', () {
      final updater = TimerPositionUpdater(
        getPosition: () async => null,
        interval: const Duration(milliseconds: 42),
      );

      expect(updater.interval, const Duration(milliseconds: 42));

      updater.dispose();
    });

    test('start should periodically emit positions and stop should halt it',
        () async {
      var tick = 0;
      final positions = <Duration>[];
      final updater = TimerPositionUpdater(
        getPosition: () async {
          tick += 1;
          return Duration(seconds: tick);
        },
        interval: const Duration(milliseconds: 5),
      );
      final sub = updater.positionStream.listen(positions.add);

      updater.start();
      // Allow several timer ticks.
      await Future<void>.delayed(const Duration(milliseconds: 35));
      updater.stop();

      expect(positions, isNotEmpty);
      expect(positions.first, const Duration(seconds: 1));

      // After stop, no further positions should arrive.
      final lengthAfterStop = positions.length;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(positions.length, lengthAfterStop);

      await sub.cancel();
      await updater.dispose();
    });
  });

  group('FramePositionUpdater', () {
    test('start should kick an immediate update and stop should halt scheduling',
        () async {
      final positions = <Duration>[];
      final updater = FramePositionUpdater(
        getPosition: () async => const Duration(seconds: 1),
      );
      final sub = updater.positionStream.listen(positions.add);

      // start() runs an immediate update via _tick(null) and schedules the next
      // frame callback; stop() cancels further scheduling. In a unit test there
      // is no live frame loop, so we rely on the immediate update only.
      updater.start();
      updater.stop();
      await Future<void>.delayed(Duration.zero);

      expect(positions, contains(const Duration(seconds: 1)));

      await sub.cancel();
      await updater.dispose();
    });
  });
}
