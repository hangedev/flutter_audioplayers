import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

/// 数据类（AudioEvent / GlobalAudioEvent / PlayerState / AudioEventType）
/// 的属性级断言，补全公开接口覆盖。
void main() {
  group('AudioEvent', () {
    test('should expose isPrepared for prepared events', () {
      const event = AudioEvent(
        eventType: AudioEventType.prepared,
        isPrepared: true,
      );
      expect(event.eventType, AudioEventType.prepared);
      expect(event.isPrepared, isTrue);
    });

    test('should expose logMessage for log events', () {
      const event = AudioEvent(
        eventType: AudioEventType.log,
        logMessage: 'a log line',
      );
      expect(event.logMessage, 'a log line');
    });
  });

  group('AudioEventType', () {
    test('should expose the prepared event type', () {
      // prepared 事件类型用于 onPrepared 流
      expect(AudioEventType.prepared, isNotNull);
      expect(
        AudioEventType.values,
        contains(AudioEventType.prepared),
      );
    });
  });

  group('GlobalAudioEvent', () {
    test('should expose eventType', () {
      const event = GlobalAudioEvent(eventType: GlobalAudioEventType.log);
      expect(event.eventType, GlobalAudioEventType.log);
    });

    test('should expose logMessage', () {
      const event = GlobalAudioEvent(
        eventType: GlobalAudioEventType.log,
        logMessage: 'global log line',
      );
      expect(event.logMessage, 'global log line');
    });
  });

  group('PlayerState', () {
    test('should expose the disposed state', () {
      expect(PlayerState.values, contains(PlayerState.disposed));
    });
  });
}
