import 'package:flutter/material.dart';

import '../../core/telemetry.dart';
import '../../core/telemetry_bootstrap.dart';
import '../../core/telemetry_preferences.dart';
import '../../l10n/app_localizations.dart';

class TelemetryControls extends StatefulWidget {
  const TelemetryControls({this.config, super.key});

  final TelemetryConfig? config;

  @override
  State<TelemetryControls> createState() => _TelemetryControlsState();
}

class _TelemetryControlsState extends State<TelemetryControls> {
  bool _saving = false;

  Future<void> _save(bool enabled) async {
    setState(() => _saving = true);
    try {
      await telemetryPreferences.save(enabled);
      if (!enabled) await stopTelemetry();
      if (mounted && enabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.telemetryRestart),
          ),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.telemetrySaveFailed),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config ?? TelemetryConfig.fromEnvironment();
    if (!config.crashReportingEnabled && !config.analyticsEnabled) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: telemetryPreferences,
      builder: (context, _) => SwitchListTile(
        secondary: const Icon(Icons.bug_report_outlined),
        title: Text(l.telemetryTitle),
        subtitle: Text(l.telemetryDescription),
        value: telemetryPreferences.enabled,
        onChanged: _saving ? null : _save,
      ),
    );
  }
}
