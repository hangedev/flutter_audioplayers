import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers_example/components/dlg.dart';
import 'package:flutter/material.dart';

extension StateExt<T extends StatefulWidget> on State<T> {
  /// Shows a single, visible snackbar.
  ///
  /// Clears any queued/current snackbars first so rapid events (e.g. stopped +
  /// set-source) do not stack into multiple toasts. Uses a minimum duration and
  /// floating placement so the message is not hidden behind the Src-tab FAB.
  void toast(String message, {Key? textKey}) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    // Keep at least ~2s visible; previously `length * 25ms` made short messages
    // (e.g. "Completed setting source.") disappear in ~650ms and easy to miss.
    final durationMs = (message.length * 40).clamp(2000, 4000);
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, key: textKey),
        duration: Duration(milliseconds: durationMs),
        behavior: SnackBarBehavior.floating,
        // Leave room for the bottom FAB on the Sources tab.
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      ),
    );
  }

  void simpleDialog(String message, [String action = 'Ok']) {
    showDialog<void>(
      context: context,
      builder: (_) {
        return SimpleDlg(message: message, action: action);
      },
    );
  }

  void dialog(Widget child) {
    showDialog<void>(
      context: context,
      builder: (_) {
        return Dlg(child: child);
      },
    );
  }
}

extension PlayerStateIcon on PlayerState {
  IconData getIcon() {
    return this == PlayerState.playing
        ? Icons.play_arrow
        : (this == PlayerState.paused
            ? Icons.pause
            : (this == PlayerState.stopped ? Icons.stop : Icons.stop_circle));
  }
}
