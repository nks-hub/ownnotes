import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextcloudnotes/features/login_browser.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  final uri = Uri.parse('https://cloud.example.invalid/login/v2/flow/token');

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('iOS opens an in-app browser and returns without waiting', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    LaunchMode? used;
    final opened = await openLoginBrowser(
      uri,
      Completer<void>().future,
      launcher: (_, mode) async {
        used = mode;
        return true;
      },
    );
    expect(opened, isTrue);
    expect(used, LaunchMode.inAppBrowserView);
  });

  test('iOS closes the in-app browser, other platforms do not', () async {
    var closed = 0;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await closeLoginBrowser(close: () async => closed++);
    expect(closed, 1);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await closeLoginBrowser(close: () async => closed++);
    expect(closed, 1);
  });

  test('desktop keeps the external browser', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    LaunchMode? used;
    await openLoginBrowser(
      uri,
      Completer<void>().future,
      launcher: (_, mode) async {
        used = mode;
        return true;
      },
    );
    expect(used, LaunchMode.externalApplication);
  });
}
