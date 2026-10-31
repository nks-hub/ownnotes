import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

typedef LoginLauncher = Future<bool> Function(Uri uri, LaunchMode mode);

Future<bool> _launch(Uri uri, LaunchMode mode) => launchUrl(uri, mode: mode);

bool get _isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Opens the Nextcloud login page. On iOS it is shown in an in-app Safari view
/// that never leaves the app, so there is no hide/resume pair to wait for; the
/// caller dismisses it with [closeLoginBrowser]. On Android the external
/// browser is used and the future completes once the app returns or
/// [cancelled] fires.
Future<bool> openLoginBrowser(
  Uri uri,
  Future<void> cancelled, {
  LoginLauncher launcher = _launch,
}) async {
  if (_isIos) return launcher(uri, LaunchMode.inAppBrowserView);
  final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  if (!android) return launcher(uri, LaunchMode.externalApplication);
  final returned = Completer<void>();
  var hidden = false;
  final lifecycle = AppLifecycleListener(
    onHide: () => hidden = true,
    onResume: () {
      if (hidden && !returned.isCompleted) returned.complete();
    },
  );
  try {
    final opened = await launcher(uri, LaunchMode.externalApplication);
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

/// Dismisses the in-app login view opened by [openLoginBrowser] on iOS.
Future<void> closeLoginBrowser({
  Future<void> Function() close = closeInAppWebView,
}) async {
  if (_isIos) await close();
}
