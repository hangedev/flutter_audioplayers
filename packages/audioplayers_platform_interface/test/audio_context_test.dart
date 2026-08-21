//ignore_for_file: avoid_redundant_argument_values

import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:audioplayers_platform_interface/src/api/audio_context_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Create default AudioContext', () async {
    final context = AudioContext();
    expect(
      context,
      AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          audioMode: AndroidAudioMode.normal,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {},
        ),
      ),
    );
  });

  test('Check AudioContextConfig assertions', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    const boolValues = {true, false};
    const focusValues = AudioContextConfigFocus.values;
    const routeValues = AudioContextConfigRoute.values;

    final throwsAssertion = [];
    for (final focus in focusValues) {
      for (final isRespectSilence in boolValues) {
        for (final isStayAwake in boolValues) {
          for (final route in routeValues) {
            final config = AudioContextConfig(
              focus: focus,
              respectSilence: isRespectSilence,
              stayAwake: isStayAwake,
              route: route,
            );
            try {
              config.build();
              throwsAssertion.add(false);
            } on AssertionError catch (e) {
              if (e.message
                  .toString()
                  .startsWith('Invalid AudioContextConfig')) {
                throwsAssertion.add(true);
              } else {
                fail(
                  'Assertion of $config does not match the expected '
                  'description. See: $e',
                );
              }
            }
          }
        }
      }
    }

    // Ensure assertions keep thrown on the correct cases.
    expect(
      throwsAssertion,
      const [
        false,
        false,
        true,
        false,
        false,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
        true,
        true,
        true,
        true,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
        true,
        true,
        true,
        true,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
      ],
    );
  });

  test('Create invalid AudioContextIOS', () async {
    try {
      // Throws AssertionError:
      AudioContextIOS(
        category: AVAudioSessionCategory.ambient,
        options: const {AVAudioSessionOptions.mixWithOthers},
      );
      fail('AssertionError not thrown');
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      expect(e, isInstanceOf<AssertionError>());
      expect(
          (e as AssertionError).message,
          'You can set the option `mixWithOthers` explicitly only if the audio '
          'session category is `playAndRecord`, `playback`, or `multiRoute`.');
    }
  });

  test('Equality of AudioContextIOS', () async {
    final context1 = AudioContextIOS(
      category: AVAudioSessionCategory.playAndRecord,
      options: const {
        AVAudioSessionOptions.mixWithOthers,
        AVAudioSessionOptions.defaultToSpeaker,
      },
    );
    final context2 = AudioContextIOS(
      category: AVAudioSessionCategory.playAndRecord,
      options: const {
        AVAudioSessionOptions.defaultToSpeaker,
        AVAudioSessionOptions.mixWithOthers,
      },
    );
    expect(context1, context2);
  });

  test('AudioContextAndroid.copy keeps unspecified fields', () async {
    const original = AudioContextAndroid(
      isSpeakerphoneOn: true,
      audioMode: AndroidAudioMode.inCommunication,
      stayAwake: true,
      contentType: AndroidContentType.speech,
      usageType: AndroidUsageType.voiceCommunication,
      audioFocus: AndroidAudioFocus.gainTransient,
    );
    // 不传任何参数：全部字段保持不变
    final same = original.copy();
    expect(same, original);

    // 只覆盖部分字段：其余字段保持原值
    final partial = original.copy(isSpeakerphoneOn: false, stayAwake: false);
    expect(partial.isSpeakerphoneOn, isFalse);
    expect(partial.stayAwake, isFalse);
    expect(partial.audioMode, AndroidAudioMode.inCommunication);
    expect(partial.contentType, AndroidContentType.speech);
    expect(partial.usageType, AndroidUsageType.voiceCommunication);
    expect(partial.audioFocus, AndroidAudioFocus.gainTransient);
  });

  test('AudioContextIOS.copy keeps unspecified fields', () async {
    final original = AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {AVAudioSessionOptions.duckOthers},
    );
    final same = original.copy();
    expect(same.category, AVAudioSessionCategory.playback);
    expect(same.options, const {AVAudioSessionOptions.duckOthers});

    final partial = original.copy(
      category: AVAudioSessionCategory.playAndRecord,
    );
    expect(partial.category, AVAudioSessionCategory.playAndRecord);
    expect(partial.options, const {AVAudioSessionOptions.duckOthers});
  });

  test('AudioContextConfig.copy keeps unspecified fields', () async {
    final original = AudioContextConfig(
      route: AudioContextConfigRoute.speaker,
      focus: AudioContextConfigFocus.duckOthers,
      respectSilence: true,
      stayAwake: true,
    );
    final same = original.copy();
    expect(same.route, original.route);
    expect(same.focus, original.focus);
    expect(same.respectSilence, original.respectSilence);
    expect(same.stayAwake, original.stayAwake);

    final partial = original.copy(
      route: AudioContextConfigRoute.earpiece,
      respectSilence: false,
    );
    expect(partial.route, AudioContextConfigRoute.earpiece);
    expect(partial.respectSilence, isFalse);
    expect(partial.focus, AudioContextConfigFocus.duckOthers);
    expect(partial.stayAwake, isTrue);
  });
}
