//ignore_for_file: avoid_redundant_argument_values, comment_references, lines_longer_than_80_chars

import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:audioplayers_platform_interface/src/api/audio_context_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Coverage for the OHOS-specific audio context surface that was previously
/// untested: [AudioContextOhos] (all members), [AudioContext.ohos]/[toJson]
/// on the OHOS platform, [AudioContextConfig.buildOhos], and [AudioEvent.position].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioContextOhos', () {
    test('should use default values when constructed without arguments', () {
      const ctx = AudioContextOhos();
      expect(ctx.isSpeakerphoneOn, isTrue);
      expect(ctx.rendererFlags, 0);
      expect(ctx.usageType, OhosUsageType.music);
      expect(ctx.audioScene, OhosAudioScene.normal);
      expect(ctx.stayAwake, isTrue);
      expect(ctx.audioFocus, AudioContextConfigFocus.gain);
    });

    test('should respect custom arguments when provided', () {
      const ctx = AudioContextOhos(
        isSpeakerphoneOn: false,
        rendererFlags: 1,
        usageType: OhosUsageType.alarm,
        audioScene: OhosAudioScene.ringing,
        stayAwake: false,
        audioFocus: AudioContextConfigFocus.duckOthers,
      );
      expect(ctx.isSpeakerphoneOn, isFalse);
      expect(ctx.rendererFlags, 1);
      expect(ctx.usageType, OhosUsageType.alarm);
      expect(ctx.audioScene, OhosAudioScene.ringing);
      expect(ctx.stayAwake, isFalse);
      expect(ctx.audioFocus, AudioContextConfigFocus.duckOthers);
    });

    test('should override only provided fields when copy() is called', () {
      const ctx = AudioContextOhos(usageType: OhosUsageType.music);
      final copied = ctx.copy(usageType: OhosUsageType.alarm, stayAwake: false);
      expect(copied.usageType, OhosUsageType.alarm);
      expect(copied.stayAwake, isFalse);
      // Untouched fields keep the original values.
      expect(copied.rendererFlags, ctx.rendererFlags);
      expect(copied.audioScene, ctx.audioScene);
      expect(copied.isSpeakerphoneOn, ctx.isSpeakerphoneOn);
      expect(copied.audioFocus, ctx.audioFocus);
    });

    test('should serialize every field when toJson() is called', () {
      const ctx = AudioContextOhos(
        isSpeakerphoneOn: false,
        rendererFlags: 1,
        usageType: OhosUsageType.alarm,
        audioScene: OhosAudioScene.voiceChat,
        stayAwake: false,
        audioFocus: AudioContextConfigFocus.mixWithOthers,
      );
      final json = ctx.toJson();
      expect(json['isSpeakerphoneOn'], isFalse);
      expect(json['rendererFlags'], 1);
      expect(json['usageType'], OhosUsageType.alarm.value);
      expect(json['audioScene'], OhosAudioScene.voiceChat.value);
      expect(json['stayAwake'], isFalse);
      // audioFocus is serialized via its enum index.
      expect(json['audioFocus'], AudioContextConfigFocus.mixWithOthers.index);
    });

    test('should map every OhosUsageType to its numeric value', () {
      // Locks in the mapping consumed by the ArkTS side via usageType numbers.
      const expected = <OhosUsageType, int>{
        OhosUsageType.unknown: 0,
        OhosUsageType.music: 1,
        OhosUsageType.voiceCommunication: 2,
        OhosUsageType.voiceAssistant: 3,
        OhosUsageType.alarm: 4,
        OhosUsageType.voiceMessage: 5,
        OhosUsageType.ringtone: 6,
        OhosUsageType.notification: 7,
        OhosUsageType.accessibility: 8,
        OhosUsageType.moive: 10,
        OhosUsageType.game: 11,
        OhosUsageType.audiobook: 12,
        OhosUsageType.navigation: 13,
      };
      for (final type in OhosUsageType.values) {
        expect(type.value, expected[type], reason: 'value for $type');
      }
    });

    test('should map every OhosAudioScene to its numeric value', () {
      expect(OhosAudioScene.normal.value, 0);
      expect(OhosAudioScene.ringing.value, 1);
      expect(OhosAudioScene.phoneCall.value, 2);
      expect(OhosAudioScene.voiceChat.value, 3);
    });
  });

  group('AudioContext (OHOS integration)', () {
    test('should default to an OHOS context when ohos is omitted', () {
      final context = AudioContext();
      expect(context.ohos, isA<AudioContextOhos>());
      expect(context.ohos.usageType, OhosUsageType.music);
    });

    test('should expose the provided ohos configuration', () {
      const ohos = AudioContextOhos(usageType: OhosUsageType.game);
      final context = AudioContext(ohos: ohos);
      expect(context.ohos, same(ohos));
    });

    test('should serialize the ohos branch when target platform is ohos', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.ohos;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      const ohos = AudioContextOhos(
        isSpeakerphoneOn: true,
        rendererFlags: 0,
        usageType: OhosUsageType.music,
        audioScene: OhosAudioScene.normal,
        stayAwake: true,
        audioFocus: AudioContextConfigFocus.gain,
      );
      final context = AudioContext(ohos: ohos);
      final json = context.toJson();

      // On OHOS, toJson() must delegate to the ohos configuration.
      expect(json, ohos.toJson());
      expect(json['usageType'], OhosUsageType.music.value);
      expect(json['isSpeakerphoneOn'], isTrue);
    });

    test('should return an empty map on unsupported platforms', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final context = AudioContext(
        ohos: const AudioContextOhos(usageType: OhosUsageType.alarm),
      );
      expect(context.toJson(), <String, dynamic>{});
    });
  });

  group('AudioContextConfig.buildOhos', () {
    test('should build a music/gain context by default', () {
      final ohos = AudioContextConfig().buildOhos();
      expect(ohos.usageType, OhosUsageType.music);
      expect(ohos.audioFocus, AudioContextConfigFocus.gain);
      expect(ohos.isSpeakerphoneOn, isFalse); // route=system
      expect(ohos.stayAwake, isFalse);
    });

    test('should map respectSilence to the ringtone usage type', () {
      final ohos = AudioContextConfig(respectSilence: true).buildOhos();
      expect(ohos.usageType, OhosUsageType.ringtone);
    });

    test('should enable speakerphone when route is speaker', () {
      final ohos = AudioContextConfig(
        route: AudioContextConfigRoute.speaker,
      ).buildOhos();
      expect(ohos.isSpeakerphoneOn, isTrue);
    });

    test('should forward the focus strategy directly', () {
      final duck = AudioContextConfig(
        focus: AudioContextConfigFocus.duckOthers,
      ).buildOhos();
      expect(duck.audioFocus, AudioContextConfigFocus.duckOthers);

      final mix = AudioContextConfig(
        focus: AudioContextConfigFocus.mixWithOthers,
      ).buildOhos();
      expect(mix.audioFocus, AudioContextConfigFocus.mixWithOthers);
    });

    test('should propagate stayAwake into the built context', () {
      final ohos = AudioContextConfig(stayAwake: true).buildOhos();
      expect(ohos.stayAwake, isTrue);
    });

    test('should include an OHOS context when building the full AudioContext',
        () {
      final context = AudioContextConfig(
        route: AudioContextConfigRoute.speaker,
        focus: AudioContextConfigFocus.duckOthers,
      ).build();
      expect(context.ohos.isSpeakerphoneOn, isTrue);
      expect(context.ohos.audioFocus, AudioContextConfigFocus.duckOthers);
    });
  });

  group('AudioEvent.position', () {
    test('should expose the position field when provided', () {
      const event = AudioEvent(
        eventType: AudioEventType.position,
        position: Duration(seconds: 5),
      );
      expect(event.eventType, AudioEventType.position);
      expect(event.position, const Duration(seconds: 5));
    });

    test('should default to a null position when omitted', () {
      const event = AudioEvent(eventType: AudioEventType.log);
      expect(event.position, isNull);
    });

    test('should treat events as equal when their positions match', () {
      const a = AudioEvent(
        eventType: AudioEventType.position,
        position: Duration(milliseconds: 250),
      );
      const b = AudioEvent(
        eventType: AudioEventType.position,
        position: Duration(milliseconds: 250),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('should differ when positions differ', () {
      const a = AudioEvent(
        eventType: AudioEventType.position,
        position: Duration(seconds: 1),
      );
      const b = AudioEvent(
        eventType: AudioEventType.position,
        position: Duration(seconds: 2),
      );
      expect(a == b, isFalse);
    });
  });

  group('AudioContextConfig.buildOhos', () {
    test('should map defaults to the OHOS context', () {
      final ohos = AudioContextConfig().buildOhos();
      expect(ohos.isSpeakerphoneOn, isFalse);
      expect(ohos.stayAwake, isFalse);
      expect(ohos.usageType, OhosUsageType.music);
      expect(ohos.audioFocus, AudioContextConfigFocus.gain);
    });

    test('should map speaker route, respectSilence and stayAwake', () {
      final ohos = AudioContextConfig(
        route: AudioContextConfigRoute.speaker,
        respectSilence: true,
        stayAwake: true,
      ).buildOhos();
      expect(ohos.isSpeakerphoneOn, isTrue);
      expect(ohos.stayAwake, isTrue);
      expect(ohos.usageType, OhosUsageType.ringtone);
    });
  });
}
