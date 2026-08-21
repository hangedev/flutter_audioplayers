import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final printZone = OverridePrint();

  group('Logger', () {
    setUp(printZone.clear);

    test(
      'when set to INFO everything is logged',
      printZone.overridePrint(() {
        AudioLogger.logLevel = AudioLogLevel.info;

        AudioLogger.log('info');
        AudioLogger.error('error');

        expect(printZone.logs, [
          'AudioPlayers Log: info',
          '\x1B[31mAudioPlayers throw: error\x1B[0m',
        ]);
      }),
    );

    test(
      'when set to ERROR only errors are logged',
      printZone.overridePrint(() {
        AudioLogger.logLevel = AudioLogLevel.error;

        AudioLogger.log('info');
        AudioLogger.error('error');

        expect(printZone.logs, [
          '\x1B[31mAudioPlayers throw: error\x1B[0m',
        ]);
      }),
    );

    test(
      'when set to NONE nothing is logged',
      printZone.overridePrint(() {
        AudioLogger.logLevel = AudioLogLevel.none;

        AudioLogger.log('info');
        AudioLogger.error('error');

        expect(printZone.logs, <String>[]);
      }),
    );

    group('errorToString', () {
      test('should format a generic thrown object', () {
        final result = AudioLogger.errorToString('boom');
        expect(result, 'AudioPlayers throw: boom');
      });

      test('should format an Exception with its message', () {
        final result = AudioLogger.errorToString(const FormatException('bad'));
        expect(result, 'AudioPlayers Exception: FormatException: bad');
      });

      test('should append the stack trace when provided', () {
        final stackTrace = StackTrace.current;
        final result = AudioLogger.errorToString('boom', stackTrace);
        expect(result, startsWith('AudioPlayers throw: boom\n'));
        expect(result, contains(stackTrace.toString()));
      });
    });
  });
}

class OverridePrint {
  final logs = <String>[];

  void clear() => logs.clear();

  void Function() overridePrint(void Function() testFn) {
    return () {
      final spec = ZoneSpecification(
        print: (_, __, ___, String msg) {
          // Add to log instead of printing to stdout
          logs.add(msg);
        },
      );
      return Zone.current.fork(specification: spec).run<void>(testFn);
    };
  }
}
