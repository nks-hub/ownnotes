import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/background.dart';
import '../../data/background_policy.dart';
import '../../l10n/app_localizations.dart';

final backgroundPreferencesProvider = FutureProvider.autoDispose(
  (_) => BackgroundSyncPreferences.load(),
);

class BackgroundSyncControls extends ConsumerStatefulWidget {
  const BackgroundSyncControls({super.key});

  @override
  ConsumerState<BackgroundSyncControls> createState() =>
      _BackgroundSyncControlsState();
}

class _BackgroundSyncControlsState
    extends ConsumerState<BackgroundSyncControls> {
  bool _saving = false;

  String _interval(AppLocalizations l, int minutes) => switch (minutes) {
    0 => l.backgroundSyncOff,
    < 60 => l.backgroundSyncMinutes(minutes),
    _ => l.backgroundSyncHours(minutes ~/ 60),
  };

  Future<void> _save(BackgroundSyncPreferences value) async {
    if (!mounted || _saving) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    setState(() => _saving = true);
    try {
      await value.save();
      if (mounted) ref.invalidate(backgroundPreferencesProvider);
      await scheduleBackgroundSync();
    } on Object {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        messenger.showSnackBar(
          SnackBar(
            content: Text(l.backgroundSyncSaveFailed),
            action: SnackBarAction(
              label: l.retry,
              onPressed: () => _save(value),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pick(BackgroundSyncPreferences current) async {
    final l = AppLocalizations.of(context)!;
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l.backgroundSyncTitle),
        children: [
          for (final value in BackgroundSyncPreferences.intervals)
            Semantics(
              selected: value == current.minutes,
              child: SimpleDialogOption(
                onPressed: () => Navigator.pop(context, value),
                child: Row(
                  children: [
                    Expanded(child: Text(_interval(l, value))),
                    if (value == current.minutes)
                      const Icon(Icons.check, size: 20),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    if (minutes != null && mounted) {
      await _save(
        BackgroundSyncPreferences(minutes: minutes, wifiOnly: current.wifiOnly),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!hasAndroidBackgroundSync) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    return ref
        .watch(backgroundPreferencesProvider)
        .when(
          loading: () => ListTile(
            title: Text(l.backgroundSyncTitle),
            subtitle: const LinearProgressIndicator(),
          ),
          error: (_, _) => ListTile(
            title: Text(l.backgroundSyncLoadFailed),
            trailing: const Icon(Icons.refresh),
            onTap: () => ref.invalidate(backgroundPreferencesProvider),
          ),
          data: (value) => Column(
            children: [
              ListTile(
                key: const Key('background-sync-interval'),
                leading: const Icon(Icons.schedule),
                title: Text(l.backgroundSyncTitle),
                subtitle: Text(_interval(l, value.minutes)),
                onTap: _saving ? null : () => _pick(value),
              ),
              SwitchListTile(
                key: const Key('background-sync-wifi'),
                secondary: const Icon(Icons.wifi),
                title: Text(l.backgroundSyncWifi),
                value: value.wifiOnly,
                onChanged: _saving || !value.enabled
                    ? null
                    : (wifiOnly) => _save(
                        BackgroundSyncPreferences(
                          minutes: value.minutes,
                          wifiOnly: wifiOnly,
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  l.backgroundSyncHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
  }
}
