import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-device preferences; none of them is synchronized to the server.
final class AppSettings {
  const AppSettings({
    this.monospace = false,
    this.fontSize = 16,
    this.lock = false,
    this.secure = false,
  });
  final bool monospace;
  final double fontSize;
  final bool lock;
  final bool secure;

  AppSettings copyWith({
    bool? monospace,
    double? fontSize,
    bool? lock,
    bool? secure,
  }) => AppSettings(
    monospace: monospace ?? this.monospace,
    fontSize: fontSize ?? this.fontSize,
    lock: lock ?? this.lock,
    secure: secure ?? this.secure,
  );
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class SettingsController extends Notifier<AppSettings> {
  static const _window = MethodChannel('com.nkshub.nextcloudnotes/window');

  /// Resolves once stored values are applied; the lock waits for it.
  late final Future<void> loaded;

  @override
  AppSettings build() {
    // _load reads state, which exists only once build has returned.
    loaded = Future.microtask(_load);
    return const AppSettings();
  }

  Future<void> _load() async {
    try {
      final prefs = SharedPreferencesAsync();
      state = AppSettings(
        monospace: await prefs.getBool('monospace') ?? false,
        fontSize: await prefs.getDouble('fontSize') ?? 16,
        lock: await prefs.getBool('lock') ?? false,
        secure: await prefs.getBool('secure') ?? false,
      );
    } catch (_) {
      // Preferences are unavailable (tests, broken storage): defaults apply.
    }
    // Not awaited: the lock screen must not wait for the window flag.
    _applySecure().ignore();
  }

  Future<void> update(AppSettings value) async {
    final secureChanged = value.secure != state.secure;
    state = value;
    if (secureChanged) await _applySecure();
    try {
      final prefs = SharedPreferencesAsync();
      await prefs.setBool('monospace', value.monospace);
      await prefs.setDouble('fontSize', value.fontSize);
      await prefs.setBool('lock', value.lock);
      await prefs.setBool('secure', value.secure);
    } catch (_) {
      // Kept for this run only.
    }
  }

  Future<void> _applySecure() async {
    try {
      await _window.invokeMethod<void>('setSecure', state.secure);
    } on MissingPluginException {
      // Only Android can keep the window out of screenshots.
    }
  }
}
