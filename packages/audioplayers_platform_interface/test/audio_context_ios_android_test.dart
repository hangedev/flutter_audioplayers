//ignore_for_file: avoid_redundant_argument_values, lines_longer_than_80_chars

import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:audioplayers_platform_interface/src/api/audio_context_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Coverage for [AudioContextIOS.toJson], [AudioContextConfig.buildAndroid]
/// and [AudioContextConfig.buildIOS] — previously uncovered public builders.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('AudioContextIOS.toJson', () {
    test('should serialize category and options', () {
      final ios = AudioContextIOS(
        category: AVAudioSessionCategory.playAndRecord,
        options: const {
          AVAudioSessionOptions.defaultToSpeaker,
          AVAudioSessionOptions.mixWithOthers,
        },
      );

      final json = ios.toJson();
      expect(json['category'], AVAudioSessionCategory.playAndRecord.name);
      expect(
        json['options'],
        unorderedEquals([
          AVAudioSessionOptions.defaultToSpeaker.name,
          AVAudioSessionOptions.mixWithOthers.name,
        ]),
      );
    });

    test('should serialize empty options as an empty list', () {
      final ios = AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: const {},
      );
      final json = ios.toJson();
      expect(json['category'], 'playback');
      expect(json['options'], isEmpty);
    });
  });

  group('AudioContextConfig.buildAndroid', () {
    test('should build media/gain defaults', () {
      final android = AudioContextConfig().buildAndroid();
      expect(android.isSpeakerphoneOn, isFalse);
      expect(android.stayAwake, isFalse);
      expect(android.usageType, AndroidUsageType.media);
      expect(android.audioFocus, AndroidAudioFocus.gain);
    });

    test('should map route speaker to isSpeakerphoneOn', () {
      final android = AudioContextConfig(
        route: AudioContextConfigRoute.speaker,
      ).buildAndroid();
      expect(android.isSpeakerphoneOn, isTrue);
    });

    test('should map route earpiece to voiceCommunication usage', () {
      final android = AudioContextConfig(
        route: AudioContextConfigRoute.earpiece,
      ).buildAndroid();
      expect(android.usageType, AndroidUsageType.voiceCommunication);
    });

    test('should map respectSilence to notificationRingtone usage', () {
      final android = AudioContextConfig(respectSilence: true).buildAndroid();
      expect(android.usageType, AndroidUsageType.notificationRingtone);
    });

    test('should map focus strategies to AndroidAudioFocus', () {
      expect(
        AudioContextConfig(focus: AudioContextConfigFocus.duckOthers)
            .buildAndroid()
            .audioFocus,
        AndroidAudioFocus.gainTransientMayDuck,
      );
      expect(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
            .buildAndroid()
            .audioFocus,
        AndroidAudioFocus.none,
      );
    });

    test('should propagate stayAwake', () {
      final android = AudioContextConfig(stayAwake: true).buildAndroid();
      expect(android.stayAwake, isTrue);
    });
  });

  group('AudioContextConfig.buildIOS', () {
    test('should return null when not running on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(AudioContextConfig().buildIOS(), isNull);
    });

    test('should build playback category by default on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final ios = AudioContextConfig().buildIOS();
      expect(ios, isNotNull);
      expect(ios!.category, AVAudioSessionCategory.playback);
      expect(ios.options, isEmpty);
    });

    test('should use ambient when respectSilence is set', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final ios = AudioContextConfig(respectSilence: true).buildIOS();
      expect(ios!.category, AVAudioSessionCategory.ambient);
    });

    test('should use playAndRecord + defaultToSpeaker for speaker route', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final ios = AudioContextConfig(
        route: AudioContextConfigRoute.speaker,
      ).buildIOS();
      expect(ios!.category, AVAudioSessionCategory.playAndRecord);
      expect(ios.options, contains(AVAudioSessionOptions.defaultToSpeaker));
    });

    test('should use playAndRecord for earpiece route', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final ios = AudioContextConfig(
        route: AudioContextConfigRoute.earpiece,
      ).buildIOS();
      expect(ios!.category, AVAudioSessionCategory.playAndRecord);
    });

    test('should add duckOthers / mixWithOthers options from focus', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final duck = AudioContextConfig(
        focus: AudioContextConfigFocus.duckOthers,
      ).buildIOS();
      expect(duck!.options, contains(AVAudioSessionOptions.duckOthers));

      final mix = AudioContextConfig(
        focus: AudioContextConfigFocus.mixWithOthers,
      ).buildIOS();
      expect(mix!.options, contains(AVAudioSessionOptions.mixWithOthers));
    });

    test('should include iOS context when building full AudioContext on iOS',
        () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final context = AudioContextConfig(
        route: AudioContextConfigRoute.speaker,
        focus: AudioContextConfigFocus.duckOthers,
      ).build();
      expect(context.iOS.category, AVAudioSessionCategory.playAndRecord);
      expect(
        context.iOS.options,
        containsAll([
          AVAudioSessionOptions.defaultToSpeaker,
          AVAudioSessionOptions.duckOthers,
        ]),
      );
      expect(context.android.isSpeakerphoneOn, isTrue);
    });
  });

  group('AudioContext.copy', () {
    test('should copy platform branches independently', () {
      const android = AudioContextAndroid(stayAwake: true);
      const ohos = AudioContextOhos(stayAwake: false);
      final ios = AudioContextIOS(category: AVAudioSessionCategory.ambient);
      final original = AudioContext(android: android, ohos: ohos, iOS: ios);

      final copied = original.copy();
      expect(copied.android, original.android);
      expect(copied.ohos, original.ohos);
      expect(copied.iOS, original.iOS);
      expect(identical(copied, original), isFalse);

      const patchedAndroid = AudioContextAndroid(isSpeakerphoneOn: true);
      final patched = original.copy(android: patchedAndroid);
      expect(patched.android.isSpeakerphoneOn, isTrue);
      expect(original.android.isSpeakerphoneOn, isFalse);
      expect(patched.iOS, original.iOS);
    });
  });

  group('AudioContextAndroid.copy / toJson', () {
    test('should copy fields and leave the original unchanged', () {
      const original = AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: true,
        usageType: AndroidUsageType.alarm,
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
      );
      final copied = original.copy(stayAwake: false);
      expect(copied.isSpeakerphoneOn, isTrue);
      expect(copied.stayAwake, isFalse);
      expect(original.stayAwake, isTrue);
      expect(copied.usageType, AndroidUsageType.alarm);
    });

    test('should serialize android fields via toJson', () {
      const android = AudioContextAndroid(
        isSpeakerphoneOn: true,
        audioMode: AndroidAudioMode.inCommunication,
        stayAwake: true,
        contentType: AndroidContentType.speech,
        usageType: AndroidUsageType.voiceCommunication,
        audioFocus: AndroidAudioFocus.gainTransient,
      );
      final json = android.toJson();
      expect(json['isSpeakerphoneOn'], isTrue);
      expect(json['audioMode'], AndroidAudioMode.inCommunication.value);
      expect(json['stayAwake'], isTrue);
      expect(json['contentType'], AndroidContentType.speech.value);
      expect(json['usageType'], AndroidUsageType.voiceCommunication.value);
      expect(json['audioFocus'], AndroidAudioFocus.gainTransient.value);
    });
  });

  group('AudioContextIOS.copy', () {
    test('should copy category and options independently', () {
      final original = AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: const {AVAudioSessionOptions.mixWithOthers},
      );
      final copied = original.copy(
        category: AVAudioSessionCategory.playAndRecord,
      );
      expect(copied.category, AVAudioSessionCategory.playAndRecord);
      expect(copied.options, original.options);
      expect(original.category, AVAudioSessionCategory.playback);
    });
  });

  group('AudioContextOhos.copy / toJson', () {
    test('should copy ohos fields and serialize via toJson', () {
      const original = AudioContextOhos(
        isSpeakerphoneOn: false,
        rendererFlags: 0,
        usageType: OhosUsageType.game,
        audioScene: OhosAudioScene.voiceChat,
        stayAwake: false,
        audioFocus: AudioContextConfigFocus.duckOthers,
      );
      final copied = original.copy(stayAwake: true);
      expect(copied.stayAwake, isTrue);
      expect(original.stayAwake, isFalse);
      expect(copied.usageType, OhosUsageType.game);

      final json = original.toJson();
      expect(json['isSpeakerphoneOn'], isFalse);
      expect(json['rendererFlags'], 0);
      expect(json['usageType'], OhosUsageType.game.value);
      expect(json['audioScene'], OhosAudioScene.voiceChat.value);
      expect(json['stayAwake'], isFalse);
      expect(json['audioFocus'], AudioContextConfigFocus.duckOthers.index);
    });
  });
}
