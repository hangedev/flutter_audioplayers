//ignore_for_file: lines_longer_than_80_chars, cancel_subscriptions

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal [PositionUpdater] subclass used to exercise the abstract base class
/// lifecycle methods (start/stop/update/stopAndUpdate/dispose) in isolation.
class _FakePositionUpdater extends PositionUpdater {
  int startCount = 0;
  int stopCount = 0;

  _FakePositionUpdater({required super.getPosition});

  @override
  void start() => startCount++;

  @override
  void stop() => stopCount++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PositionUpdater', () {
    test('should expose a broadcast positionStream', () {
      final updater = _FakePositionUpdater(getPosition: () async => null);
      expect(updater.positionStream, isA<Stream<Duration>>());
      // isBroadcast guarantees multiple listeners can subscribe independently.
      expect(updater.positionStream.isBroadcast, isTrue);
      updater.dispose();
    });

    test('should emit the position returned by getPosition when updating',
        () async {
      final updater = _FakePositionUpdater(
        getPosition: () async => const Duration(seconds: 3),
      );

      expectLater(
        updater.positionStream,
        emits(const Duration(seconds: 3)),
      );
      await updater.update();
      await updater.dispose();
    });

    test('should not emit when getPosition resolves to null', () async {
      final updater = _FakePositionUpdater(getPosition: () async => null);
      final emitted = <Duration>[];
      final subscription = updater.positionStream.listen(emitted.add);

      await updater.update();
      await Future<void>.delayed(Duration.zero);
      expect(emitted, isEmpty);

      await subscription.cancel();
      await updater.dispose();
    });

    test('should call stop then update when stopAndUpdate is invoked', () async {
      final updater = _FakePositionUpdater(
        getPosition: () async => const Duration(milliseconds: 10),
      );

      expectLater(
        updater.positionStream,
        emits(const Duration(milliseconds: 10)),
      );
      await updater.stopAndUpdate();
      expect(updater.stopCount, 1);
      await updater.dispose();
    });

    test('should close the stream when disposed', () async {
      final updater = _FakePositionUpdater(getPosition: () async => null);
      expectLater(updater.positionStream, emitsDone);
      await updater.dispose();
    });

    test('should stop before closing when disposed', () async {
      final updater = _FakePositionUpdater(getPosition: () async => null);
      await updater.dispose();
      expect(updater.stopCount, 1);
    });

    test('should invoke the subclass start/stop hooks', () {
      final updater = _FakePositionUpdater(getPosition: () async => null);
      updater.start();
      updater.start();
      updater.stop();
      expect(updater.startCount, 2);
      expect(updater.stopCount, 1);
      updater.dispose();
    });
  });

  group('TimerPositionUpdater', () {
    test('should expose the configured interval', () {
      final updater = TimerPositionUpdater(
        getPosition: () async => null,
        interval: const Duration(milliseconds: 50),
      );
      expect(updater.interval, const Duration(milliseconds: 50));
      updater.dispose();
    });

    test('should emit periodic updates while started', () async {
      var tick = 0;
      final updater = TimerPositionUpdater(
        getPosition: () async => Duration(seconds: tick++),
        interval: const Duration(milliseconds: 20),
      );
      final emitted = <Duration>[];
      final subscription = updater.positionStream.listen(emitted.add);

      updater.start();
      // Allow at least two timer ticks to fire.
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await updater.stopAndUpdate();

      expect(emitted, isNotEmpty);
      // Each tick produces a strictly increasing position.
      for (var i = 1; i < emitted.length; i++) {
        expect(emitted[i] > emitted[i - 1], isTrue);
      }

      await subscription.cancel();
      await updater.dispose();
    });

    test('should cancel the running timer when stop is called', () async {
      final updater = TimerPositionUpdater(
        getPosition: () async => const Duration(seconds: 1),
        interval: const Duration(milliseconds: 10),
      );
      updater.start();
      updater.stop();
      // Stopping again must be a safe no-op (no state left behind).
      updater.stop();
      await updater.dispose();
    });
  });

  group('FramePositionUpdater', () {
    test('should construct and expose a broadcast stream', () {
      final updater = FramePositionUpdater(getPosition: () async => null);
      expect(updater.positionStream.isBroadcast, isTrue);
      // start/stop must not throw when no frame callback is scheduled.
      updater.stop();
      updater.dispose();
    });

    test('should invoke getPosition when start is called', () async {
      // start() immediately runs _tick → update(); assert that public start()
      // path without depending on SchedulerBinding frame pumps (which can loop
      // forever under testWidgets when callbacks reschedule themselves).
      var calls = 0;
      final updater = FramePositionUpdater(
        getPosition: () async {
          calls++;
          return Duration(milliseconds: calls * 10);
        },
      );

      final emittedFuture = expectLater(
        updater.positionStream,
        emits(const Duration(milliseconds: 10)),
      );
      updater.start();
      await emittedFuture;
      updater.stop();

      expect(calls, greaterThanOrEqualTo(1));
      await updater.dispose();
    });
  });
}
