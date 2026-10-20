import 'dart:async';

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

  final _saveFailures = StreamController<void>.broadcast();

  /// Resolves once stored values are applied; the lock waits for it.
  late final Future<void> loaded;

  /// True while the stored values could not be read. The real lock setting is
  /// then unknown, so the app lock must stay closed instead of assuming off.
  bool loadFailed = false;

  /// Fires when a security preference could not be saved and was reverted.
  Stream<void> get saveFailures => _saveFailures.stream;

  @override
  AppSettings build() {
    ref.onDispose(_saveFailures.close);
    // _load reads state, which exists only once build has returned.
    loaded = Future.microtask(reload);
    return const AppSettings();
  }

  /// Reads the stored values again; sets [loadFailed] when that fails.
  Future<void> reload() async {
    try {
      final prefs = SharedPreferencesAsync();
      state = AppSettings(
        monospace: await prefs.getBool('monospace') ?? false,
        fontSize: await prefs.getDouble('fontSize') ?? 16,
        lock: await prefs.getBool('lock') ?? false,
        secure: await prefs.getBool('secure') ?? false,
      );
      loadFailed = false;
    } catch (_) {
      loadFailed = true;
    }
    // Not awaited: the lock screen must not wait for the window flag.
    _applySecure().ignore();
  }

  /// Applies and stores [value]. When storing fails, lock and secure go back
  /// to their previous values (so a switch never shows an unsaved state) and
  /// [saveFailures] fires. Other preferences are kept for this run only.
  Future<void> update(AppSettings value) async {
    final previous = state;
    state = value;
    if (value.secure != previous.secure) await _applySecure();
    try {
      final prefs = SharedPreferencesAsync();
      await prefs.setBool('monospace', value.monospace);
      await prefs.setDouble('fontSize', value.fontSize);
      await prefs.setBool('lock', value.lock);
      await prefs.setBool('secure', value.secure);
    } catch (_) {
      if (value.lock != previous.lock || value.secure != previous.secure) {
        state = value.copyWith(lock: previous.lock, secure: previous.secure);
        if (value.secure != previous.secure) await _applySecure();
        _saveFailures.add(null);
      }
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
