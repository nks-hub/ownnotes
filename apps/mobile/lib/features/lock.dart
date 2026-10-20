import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../data/settings.dart';
import '../l10n/app_localizations.dart';

/// Replaceable in tests.
final localAuthProvider = Provider<LocalAuthentication>(
  (ref) => LocalAuthentication(),
);

enum _Problem { none, serviceUnavailable, noDeviceLock }

/// Covers the app with a lock screen after it was in the background, when
/// the app lock is on. The app stays mounted underneath, so an open editor
/// keeps its text; it already saved it when the app was hidden.
/// An exception never unlocks: it keeps the lock and offers a retry. Only the
/// owner, after the device lock was verifiably removed, can switch the app
/// lock off from the lock screen.
class AppLock extends ConsumerStatefulWidget {
  const AppLock({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<AppLock> createState() => _AppLockState();
}

class _AppLockState extends ConsumerState<AppLock> {
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<void>? _failures;
  bool _ready = false;
  bool _locked = false;
  bool _checking = false;
  _Problem _problem = _Problem.none;

  SettingsController get _controller => ref.read(settingsProvider.notifier);

  bool get _lockActive =>
      ref.read(settingsProvider).lock || _controller.loadFailed;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () {
        if (_lockActive) setState(() => _locked = true);
      },
      onShow: () {
        if (_locked) _unlock();
      },
    );
    _failures = _controller.saveFailures.listen((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.settingSaveFailed)),
      );
    });
    _controller.loaded.then((_) {
      if (!mounted) return;
      setState(() {
        _ready = true;
        _locked = _lockActive;
      });
      if (_locked) _unlock();
    });
  }

  @override
  void dispose() {
    _failures?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_checking) return;
    _checking = true;
    final reason = AppLocalizations.of(context)!.unlockReason;
    var problem = _Problem.none;
    var granted = false;
    try {
      if (_controller.loadFailed) {
        await _controller.reload();
        if (_controller.loadFailed) {
          problem = _Problem.serviceUnavailable;
        } else if (!ref.read(settingsProvider).lock) {
          granted = true;
        }
      }
      if (problem == _Problem.none && !granted) {
        granted = await ref
            .read(localAuthProvider)
            .authenticate(localizedReason: reason);
      }
    } catch (_) {
      problem = await _diagnose();
    } finally {
      _checking = false;
    }
    if (!mounted) return;
    setState(() {
      _problem = problem;
      if (granted) _locked = false;
    });
  }

  /// Tells a removed device lock apart from an unavailable service; any doubt
  /// counts as unavailable.
  Future<_Problem> _diagnose() async {
    try {
      final supported = await ref.read(localAuthProvider).isDeviceSupported();
      return supported ? _Problem.serviceUnavailable : _Problem.noDeviceLock;
    } catch (_) {
      return _Problem.serviceUnavailable;
    }
  }

  Future<void> _disableLock() async {
    await _controller.update(
      ref.read(settingsProvider).copyWith(lock: false),
    );
    if (mounted) {
      setState(() {
        _locked = false;
        _problem = _Problem.none;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const ColoredBox(color: Colors.black);
    ref.watch(settingsProvider);
    if (!(_locked && _lockActive)) return widget.child;
    final l = AppLocalizations.of(context)!;
    return Stack(
      children: [
        ExcludeSemantics(child: widget.child),
        Positioned.fill(
          child: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 48),
                    const SizedBox(height: 16),
                    if (_problem == _Problem.serviceUnavailable)
                      Text(l.lockUnavailable, textAlign: TextAlign.center),
                    if (_problem == _Problem.noDeviceLock)
                      Text(l.lockDeviceRemoved, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _unlock,
                      child: Text(
                        _problem == _Problem.none ? l.unlock : l.retry,
                      ),
                    ),
                    if (_problem == _Problem.noDeviceLock)
                      TextButton(
                        onPressed: _disableLock,
                        child: Text(l.lockTurnOff),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
