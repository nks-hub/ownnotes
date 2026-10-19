import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../data/settings.dart';
import '../l10n/app_localizations.dart';

/// Covers the app with a lock screen after it was in the background, when
/// the app lock is on. The app stays mounted underneath, so an open editor
/// keeps its text; it already saved it when the app was hidden.
class AppLock extends ConsumerStatefulWidget {
  const AppLock({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<AppLock> createState() => _AppLockState();
}

class _AppLockState extends ConsumerState<AppLock> {
  final _auth = LocalAuthentication();
  late final AppLifecycleListener _lifecycle;
  bool _ready = false;
  bool _locked = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () {
        if (ref.read(settingsProvider).lock) setState(() => _locked = true);
      },
      onShow: () {
        if (_locked) _unlock();
      },
    );
    ref.read(settingsProvider.notifier).loaded.then((_) {
      if (!mounted) return;
      setState(() {
        _ready = true;
        _locked = ref.read(settingsProvider).lock;
      });
      if (_locked) _unlock();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_checking) return;
    _checking = true;
    var ok = false;
    try {
      ok = await _auth.authenticate(
        localizedReason: AppLocalizations.of(context)!.unlockReason,
      );
    } catch (_) {
      // A device whose screen lock was removed cannot authenticate; the app
      // lock then protects nothing and must not shut the owner out.
      ok = !await _auth.isDeviceSupported().catchError((_) => false);
    } finally {
      _checking = false;
    }
    if (ok && mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const ColoredBox(color: Colors.black);
    final locked = _locked && ref.watch(settingsProvider).lock;
    if (!locked) return widget.child;
    final l = AppLocalizations.of(context)!;
    return Stack(
      children: [
        ExcludeSemantics(child: widget.child),
        Positioned.fill(
          child: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 48),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _unlock, child: Text(l.unlock)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
