import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> openLoginBrowser(Uri uri, Future<void> cancelled) async {
  final mobile =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  if (!mobile) return launchUrl(uri, mode: LaunchMode.externalApplication);
  final returned = Completer<void>();
  var hidden = false;
  final lifecycle = AppLifecycleListener(
    onHide: () => hidden = true,
    onResume: () {
      if (hidden && !returned.isCompleted) returned.complete();
    },
  );
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) return false;
    // Split-screen browsers may never emit hide/resume; polling still starts.
    await Future.any([
      returned.future,
      cancelled,
    ]).timeout(const Duration(minutes: 5), onTimeout: () {});
    return true;
  } finally {
    lifecycle.dispose();
  }
}
