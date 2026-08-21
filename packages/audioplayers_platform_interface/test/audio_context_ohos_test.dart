//ignore_for_file: avoid_redundant_argument_values

import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:audioplayers_platform_interface/src/api/audio_context_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioContextOhos', () {
    test('should provide sensible defaults', () {
      const ohos = AudioContextOhos();
      expect(ohos.isSpeakerphoneOn, isTrue);
      expect(ohos.audioScene, OhosAudioScene.normal);
      expect(ohos.rendererFlags, 0);
      expect(ohos.stayAwake, isTrue);
      expect(ohos.usageType, OhosUsageType.music);
    });

    test('should keep the configured constructor values', () {
      const ohos = AudioContextOhos(
        isSpeakerphoneOn: false,
        audioScene: OhosAudioScene.phoneCall,
        rendererFlags: 1,
        stayAwake: false,
        usageType: OhosUsageType.alarm,
      );
      expect(ohos.isSpeakerphoneOn, isFalse);
      expect(ohos.audioScene, OhosAudioScene.phoneCall);
      expect(ohos.rendererFlags, 1);
      expect(ohos.stayAwake, isFalse);
      expect(ohos.usageType, OhosUsageType.alarm);
    });

    test('copy should override only the provided fields', () {
      const ohos = AudioContextOhos();
      final copied = ohos.copy(
        isSpeakerphoneOn: false,
        usageType: OhosUsageType.game,
      );
      expect(copied.isSpeakerphoneOn, isFalse);
      expect(copied.usageType, OhosUsageType.game);
      // Untouched fields keep their original value.
      expect(copied.audioScene, OhosAudioScene.normal);
      expect(copied.rendererFlags, 0);
      expect(copied.stayAwake, isTrue);
    });

    test('toJson should serialize the configured values', () {
      const ohos = AudioContextOhos(
        isSpeakerphoneOn: false,
        audioScene: OhosAudioScene.ringing,
        rendererFlags: 0,
        stayAwake: false,
        usageType: OhosUsageType.ringtone,
      );
      final json = ohos.toJson();
      expect(json, isA<Map<String, dynamic>>());
      expect(json['isSpeakerphoneOn'], false);
      expect(json['rendererFlags'], 0);
      expect(json['audioScene'], OhosAudioScene.ringing.value);
      expect(json['usageType'], OhosUsageType.ringtone.value);
      expect(json['stayAwake'], false);
    });
  });

  group('OhosUsageType', () {
    test('should map each value to its numeric code', () {
      expect(OhosUsageType.unknown.value, 0);
      expect(OhosUsageType.music.value, 1);
      expect(OhosUsageType.voiceCommunication.value, 2);
      expect(OhosUsageType.voiceAssistant.value, 3);
      expect(OhosUsageType.alarm.value, 4);
      expect(OhosUsageType.voiceMessage.value, 5);
      expect(OhosUsageType.ringtone.value, 6);
      expect(OhosUsageType.notification.value, 7);
      expect(OhosUsageType.accessibility.value, 8);
      expect(OhosUsageType.moive.value, 10);
      expect(OhosUsageType.game.value, 11);
      expect(OhosUsageType.audiobook.value, 12);
      expect(OhosUsageType.navigation.value, 13);
    });
  });

  group('OhosAudioScene', () {
    test('should map each value to its numeric code', () {
      expect(OhosAudioScene.normal.value, 0);
      expect(OhosAudioScene.ringing.value, 1);
      expect(OhosAudioScene.phoneCall.value, 2);
      expect(OhosAudioScene.voiceChat.value, 3);
    });
  });

  group('AudioContext (ohos / copy / toJson)', () {
    test('should expose the ohos field and default to AudioContextOhos', () {
      final context = AudioContext();
      expect(context.ohos, isA<AudioContextOhos>());
      expect(context.ohos.usageType, OhosUsageType.music);
    });

    test('copy should override the ohos field', () {
      final context = AudioContext();
      final copied = context.copy(
        ohos: const AudioContextOhos(usageType: OhosUsageType.alarm),
      );
      expect(copied.ohos.usageType, OhosUsageType.alarm);
    });

    test('toJson should delegate to ohos.toJson on the OHOS platform', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.ohos;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final context = AudioContext(
        ohos: const AudioContextOhos(usageType: OhosUsageType.ringtone),
      );
      final json = context.toJson();
      expect(json['usageType'], OhosUsageType.ringtone.value);
    });
  });

  group('AudioContextConfig (route / focus / build*)', () {
    test('should expose the route and focus fields', () {
      final config = AudioContextConfig(
        route: AudioContextConfigRoute.speaker,
        focus: AudioContextConfigFocus.duckOthers,
      );
      expect(config.route, AudioContextConfigRoute.speaker);
      expect(config.focus, AudioContextConfigFocus.duckOthers);
    });

    test('buildAndroid should map route and focus', () {
      final config = AudioContextConfig(
        route: AudioContextConfigRoute.speaker,
        focus: AudioContextConfigFocus.gain,
      );
      final android = config.buildAndroid();
      expect(android.isSpeakerphoneOn, isTrue);
      expect(android.usageType, AndroidUsageType.media);
      expect(android.audioFocus, AndroidAudioFocus.gain);
    });

    test('buildAndroid should respect respectSilence', () {
      final config = AudioContextConfig(
        route: AudioContextConfigRoute.system,
        focus: AudioContextConfigFocus.gain,
        respectSilence: true,
      );
      expect(
        config.buildAndroid().usageType,
        AndroidUsageType.notificationRingtone,
      );
    });

    test('buildOhos should map route to isSpeakerphoneOn', () {
      final config = AudioContextConfig(
        route: AudioContextConfigRoute.speaker,
      );
      final ohos = config.buildOhos();
      expect(ohos.isSpeakerphoneOn, isTrue);
      expect(ohos.usageType, OhosUsageType.music);
    });

    test('buildOhos should respect respectSilence', () {
      final config = AudioContextConfig(
        route: AudioContextConfigRoute.system,
        respectSilence: true,
      );
      expect(config.buildOhos().usageType, OhosUsageType.ringtone);
    });

    test('buildIOS should return null off the iOS platform', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final config = AudioContextConfig();
      expect(config.buildIOS(), isNull);
    });

    test('buildIOS should return a config on the iOS platform', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final config = AudioContextConfig(route: AudioContextConfigRoute.speaker);
      final ios = config.buildIOS();
      expect(ios, isNotNull);
      expect(ios!.category, AVAudioSessionCategory.playAndRecord);
    });

    test('build should assemble an AudioContext for every platform', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final config = AudioContextConfig();
      final context = config.build();
      expect(context, isA<AudioContext>());
      expect(context.ohos, isA<AudioContextOhos>());
      expect(context.android, isA<AudioContextAndroid>());
    });
  });

  group('toJson coverage', () {
    test('AudioContextAndroid.toJson should serialize fields', () {
      const android = AudioContextAndroid();
      final json = android.toJson();
      expect(json['isSpeakerphoneOn'], false);
      // toJson serializes enums by their numeric code (see .value), not name.
      expect(json['usageType'], AndroidUsageType.media.value);
    });

    test('AudioContextIOS.toJson should serialize category and options', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final ios = AudioContextIOS(
        category: AVAudioSessionCategory.playback,
      );
      final json = ios.toJson();
      expect(json['category'], 'playback');
      expect(json['options'], isA<List>());
    });

    test('AudioEvent.toString / equality should work for all fields', () {
      const a = AudioEvent(
        eventType: AudioEventType.duration,
        duration: Duration(seconds: 1),
      );
      const b = AudioEvent(
        eventType: AudioEventType.duration,
        duration: Duration(seconds: 1),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('duration'));
    });
  });
}
