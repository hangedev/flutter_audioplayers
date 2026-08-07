import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers_example/components/tabs.dart';
import 'package:audioplayers_example/components/tgl.dart';
import 'package:audioplayers_example/tabs/audio_context.dart';
import 'package:audioplayers_example/tabs/controls.dart';
import 'package:audioplayers_example/tabs/logger.dart';
import 'package:audioplayers_example/tabs/sources.dart';
import 'package:audioplayers_example/tabs/streams.dart';
import 'package:audioplayers_example/utils.dart';
import 'package:flutter/material.dart';

const defaultPlayerCount = 4;

typedef OnError = void Function(Exception exception);

/// The app is deployed at: https://bluefireteam.github.io/audioplayers/
///
/// ## OHOS (HarmonyOS) platform notes
///
/// This example runs on HarmonyOS via the `audioplayers_ohos` native implementation
/// (MethodChannel + EventChannel, ArkTS layer on top of `@ohos.multimedia.media`).
/// HarmonyOS-specific considerations:
///
/// - **Platform detection**: detect OHOS with `Platform.isOhos` (supported natively by
///   the Flutter OHOS branch), not via exclusion logic.
/// - **Background playback**: requires the `ohos.permission.KEEP_BACKGROUND_RUNNING`
///   permission and the `audioPlayback` background mode in `module.json5`; otherwise
///   playback is suspended when the app goes to the background. See README.OpenHarmony.md.
/// - **Audio context**: configure OHOS-specific fields via `AudioContextOhos`
///   (`usageType`, `rendererFlags`, `stayAwake`, `audioFocus`). `setGlobalAudioContext`
///   is cached locally due to a system API limitation.
/// - **Low-latency mode**: `PlayerMode.lowLatency` maps to the OHOS SoundPool, which
///   does not support `seek`/`getDuration` and treats `reset` as a no-op.
/// - **Build**: run `flutter build hap --debug` inside `example/` with the hvigor
///   daemon disabled (`execution.daemon = false`).
void main() {
  runApp(const MaterialApp(home: _ExampleApp()));
}

class _ExampleApp extends StatefulWidget {
  const _ExampleApp();

  @override
  _ExampleAppState createState() => _ExampleAppState();
}

class _ExampleAppState extends State<_ExampleApp> {
  List<AudioPlayer> audioPlayers = List.generate(
    defaultPlayerCount,
    (_) => AudioPlayer()..setReleaseMode(ReleaseMode.stop),
  );
  int selectedPlayerIdx = 0;

  AudioPlayer get selectedAudioPlayer => audioPlayers[selectedPlayerIdx];
  List<StreamSubscription> streams = [];

  @override
  void initState() {
    super.initState();
    audioPlayers.asMap().forEach((index, player) {
      PlayerState? previousState = player.state;
      streams.add(
        player.onPlayerStateChanged.listen(
          (it) {
            final prev = previousState;
            previousState = it;
            switch (it) {
              case PlayerState.stopped:
                // Play 会先无条件 stop()；已是 stopped 时再 emit 一次会误导（如 Invalid Asset）
                if (prev == PlayerState.playing || prev == PlayerState.paused) {
                  toast(
                    'Player stopped!',
                    textKey: Key('toast-player-stopped-$index'),
                  );
                }
              case PlayerState.completed:
                toast(
                  'Player complete!',
                  textKey: Key('toast-player-complete-$index'),
                );
              default:
            }
          },
        ),
      );
      streams.add(
        player.onSeekComplete.listen(
          (it) => toast(
            'Seek complete!',
            textKey: Key('toast-seek-complete-$index'),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    streams.forEach((it) => it.cancel());
    super.dispose();
  }

  void _handleAction(PopupAction value) {
    switch (value) {
      case PopupAction.add:
        setState(() {
          audioPlayers.add(AudioPlayer()..setReleaseMode(ReleaseMode.stop));
        });
      case PopupAction.remove:
        setState(() {
          if (audioPlayers.isNotEmpty) {
            selectedAudioPlayer.dispose();
            audioPlayers.removeAt(selectedPlayerIdx);
          }
          // Adjust index to be in valid range
          if (audioPlayers.isEmpty) {
            selectedPlayerIdx = 0;
          } else if (selectedPlayerIdx >= audioPlayers.length) {
            selectedPlayerIdx = audioPlayers.length - 1;
          }
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AudioPlayers example'),
        actions: [
          PopupMenuButton<PopupAction>(
            onSelected: _handleAction,
            itemBuilder: (BuildContext context) {
              return PopupAction.values.map((PopupAction choice) {
                return PopupMenuItem<PopupAction>(
                  value: choice,
                  child: Text(
                    choice == PopupAction.add
                        ? 'Add player'
                        : 'Remove selected player',
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Tgl(
                  key: const Key('playerTgl'),
                  options: [for (var i = 1; i <= audioPlayers.length; i++) i]
                      .asMap()
                      .map((key, val) => MapEntry('player-$key', 'P$val')),
                  selected: selectedPlayerIdx,
                  onChange: (v) => setState(() => selectedPlayerIdx = v),
                ),
              ),
            ),
          ),
          Expanded(
            child: audioPlayers.isEmpty
                ? const Text('No AudioPlayer available!')
                : IndexedStack(
                    index: selectedPlayerIdx,
                    children: audioPlayers
                        .map(
                          (player) => Tabs(
                            key: GlobalObjectKey(player),
                            tabs: [
                              TabData(
                                key: 'sourcesTab',
                                label: 'Src',
                                content: SourcesTab(
                                  player: player,
                                ),
                              ),
                              TabData(
                                key: 'controlsTab',
                                label: 'Ctrl',
                                content: ControlsTab(
                                  player: player,
                                ),
                              ),
                              TabData(
                                key: 'streamsTab',
                                label: 'Stream',
                                content: StreamsTab(
                                  player: player,
                                ),
                              ),
                              TabData(
                                key: 'audioContextTab',
                                label: 'Ctx',
                                content: AudioContextTab(
                                  player: player,
                                ),
                              ),
                              TabData(
                                key: 'loggerTab',
                                label: 'Log',
                                content: LoggerTab(
                                  player: player,
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

enum PopupAction {
  add,
  remove,
}
