import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/capture/capture_inbox.dart';
import '../../data/capture/providers.dart';
import '../../data/runtime.dart';
import 'capture_screen.dart';

bool _running = false;
final _dismissed = <String>{};

/// Takes what other apps shared since the last call into durable storage,
/// acknowledges it to the platform, and shows the capture screen for each
/// waiting capture, oldest first.
///
/// Call it on start, on resume and from the platform's "shared" callback.
/// Without a signed-in account nothing is shown and the captures wait.
/// Closing the screen keeps the capture; it is not shown again by later
/// automatic calls in this session. Pass [includeDismissed] from an explicit
/// "waiting shared content" entry to open it again. Returns whether at least
/// one capture was stored as a note.
Future<bool> handleIncomingCaptures(
  BuildContext context,
  WidgetRef ref, {
  bool includeDismissed = false,
}) async {
  if (_running) return false;
  _running = true;
  var stored = false;
  try {
    final store = await ref.read(captureStoreProvider.future);
    try {
      await drainCaptures(await ref.read(captureSourceProvider.future), store);
    } on MissingPluginException {
      // Only Android and iOS have a share target.
    }
    final accounts = await ref.read(accountsProvider.future);
    if (accounts.isEmpty) return false;
    while (context.mounted) {
      final next = (await store.pending())
          .where((c) => includeDismissed || !_dismissed.contains(c.id))
          .firstOrNull;
      if (next == null || !context.mounted) return stored;
      // An open editor saved its text when the app went to the background.
      Navigator.of(context).popUntil((route) => route.isFirst);
      final done = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/capture'),
          builder: (_) => CaptureScreen(capture: next),
        ),
      );
      if (done != true) {
        _dismissed.add(next.id);
        return stored;
      }
      stored = true;
    }
    return stored;
  } finally {
    _running = false;
  }
}
