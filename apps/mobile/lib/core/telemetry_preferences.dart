import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TelemetryPreferences extends ChangeNotifier {
  TelemetryPreferences({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const key = 'telemetryEnabled';
  final SharedPreferencesAsync _preferences;
  bool enabled = false;
  bool loaded = false;

  Future<void> load() async {
    try {
      enabled = await _preferences.getBool(key) ?? true;
      loaded = true;
    } on Object {
      // An unreadable opt-out must not enable data collection.
      enabled = false;
      loaded = false;
    }
    notifyListeners();
  }

  Future<void> save(bool value) async {
    await _preferences.setBool(key, value);
    enabled = value;
    loaded = true;
    notifyListeners();
  }
}

final telemetryPreferences = TelemetryPreferences();
