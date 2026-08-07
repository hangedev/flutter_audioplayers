import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AudioLogLevel', () {
    test('should expose the numeric level of each value', () {
      expect(AudioLogLevel.none.level, 0);
      expect(AudioLogLevel.error.level, 1);
      expect(AudioLogLevel.info.level, 2);
    });

    test('should order values via compareTo', () {
      const levels = [
        AudioLogLevel.none,
        AudioLogLevel.error,
        AudioLogLevel.info,
      ];
      for (var i = 0; i < levels.length - 1; i++) {
        expect(levels[i].compareTo(levels[i + 1]), lessThan(0));
        expect(levels[i + 1].compareTo(levels[i]), greaterThan(0));
      }
      expect(AudioLogLevel.info.compareTo(AudioLogLevel.info), 0);
    });

    test('should map integers back to levels via fromInt', () {
      expect(AudioLogLevel.fromInt(0), AudioLogLevel.none);
      expect(AudioLogLevel.fromInt(1), AudioLogLevel.error);
      expect(AudioLogLevel.fromInt(2), AudioLogLevel.info);
    });
  });
}
