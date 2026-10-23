import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

bool get hasAndroidBackgroundSync =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

final class BackgroundSyncPreferences {
  const BackgroundSyncPreferences({this.minutes = 15, this.wifiOnly = false});

  static const intervals = [0, 15, 30, 60, 360];
  static const _key = 'backgroundSync';
  final int minutes;
  final bool wifiOnly;
  bool get enabled => minutes != 0;

  static Future<BackgroundSyncPreferences> load() async {
    final stored = await SharedPreferencesAsync().getString(_key);
    if (stored == null) return const BackgroundSyncPreferences();
    final values = jsonDecode(stored) as Map<String, dynamic>;
    final minutes = values['minutes'];
    final wifiOnly = values['wifiOnly'];
    if (!intervals.contains(minutes) || wifiOnly is! bool) {
      throw const FormatException('Invalid background sync preferences');
    }
    return BackgroundSyncPreferences(
      minutes: minutes as int,
      wifiOnly: wifiOnly,
    );
  }

  Future<void> save() {
    if (!intervals.contains(minutes)) throw ArgumentError.value(minutes);
    return SharedPreferencesAsync().setString(
      _key,
      jsonEncode({'minutes': minutes, 'wifiOnly': wifiOnly}),
    );
  }
}

/// Read uncached preferences in each isolate before starting network work.
Future<bool> backgroundSyncAllowed() async {
  if (!hasAndroidBackgroundSync) return true;
  final preferences = await BackgroundSyncPreferences.load();
  if (!preferences.enabled) return false;
  if (!preferences.wifiOnly) return true;
  final networks = await Connectivity().checkConnectivity();
  return networks.contains(ConnectivityResult.wifi);
}

/// A worker may outlive a settings or network change. Gate every request, not
/// just the start of the worker, while leaving ordinary foreground clients alone.
final class BackgroundSyncClient extends http.BaseClient {
  BackgroundSyncClient(this._inner);
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!await backgroundSyncAllowed()) {
      throw http.ClientException('background_sync_paused');
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
