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
  });

  group('AudioLogger.errorToString', () {
    test('formats plain objects as throw', () {
      final result = AudioLogger.errorToString('boom');
      expect(result, 'AudioPlayers throw: boom');
    });

    test('formats Exception instances', () {
      final result = AudioLogger.errorToString(const FormatException('bad'));
      expect(result, startsWith('AudioPlayers Exception:'));
      expect(result, contains('bad'));
    });

    test('formats Error instances with stack trace', () {
      final StateError err;
      try {
        throw StateError('wrong state');
      } on StateError catch (e) {
        err = e;
      }
      final result = AudioLogger.errorToString(err);
      expect(result, startsWith('AudioPlayers Error:'));
      expect(result, contains('wrong state'));
      // Error 分支会附加 o.stackTrace，Dart 堆栈文本以帧标记 "#0" 开头
      expect(result, contains('\n#0'));
    });

    test('appends provided stack trace', () {
      final st = StackTrace.current;
      final result = AudioLogger.errorToString('oops', st);
      expect(result, startsWith('AudioPlayers throw: oops\n'));
      expect(result, contains(st.toString()));
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
