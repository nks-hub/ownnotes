import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:notes_store/notes_store.dart';
import '../data/export.dart';
import '../data/runtime.dart';
import '../data/settings.dart';
import '../l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({required this.account, super.key});
  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(l.monospace),
            value: settings.monospace,
            onChanged: (v) =>
                controller.update(settings.copyWith(monospace: v)),
          ),
          ListTile(
            title: Text(l.textSize),
            trailing: Text('${settings.fontSize.round()}'),
          ),
          Slider(
            min: 12,
            max: 28,
            divisions: 8,
            label: '${settings.fontSize.round()}',
            value: settings.fontSize,
            onChanged: (v) => controller.update(settings.copyWith(fontSize: v)),
          ),
          SwitchListTile(
            title: Text(l.appLock),
            subtitle: Text(l.appLockHint),
            value: settings.lock,
            onChanged: (v) async {
              final messenger = ScaffoldMessenger.of(context);
              if (v && !await _canLock()) {
                messenger.showSnackBar(
                  SnackBar(content: Text(l.appLockUnavailable)),
                );
                return;
              }
              await controller.update(settings.copyWith(lock: v));
            },
          ),
          if (Platform.isAndroid)
            SwitchListTile(
              title: Text(l.blockScreenshots),
              value: settings.secure,
              onChanged: (v) => controller.update(settings.copyWith(secure: v)),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: Text(l.exportNotes),
            onTap: () => _export(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l.removeAccount),
            subtitle: Text(
              '${account.loginName} · ${Uri.parse(account.server).host}',
            ),
            onTap: () => _remove(context, ref),
          ),
        ],
      ),
    );
  }

  static Future<bool> _canLock() async {
    try {
      return await LocalAuthentication().isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final notes = await ref.read(notesProvider(account.id).future);
      final saved = await FilePicker.saveFile(
        fileName: 'ownnotes-${account.loginName}.zip',
        bytes: exportNotes(notes),
        mimeType: 'application/zip',
      );
      if (saved != null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.exportDone(notes.length))),
        );
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.exportFailed)));
    }
  }

  /// Notes that were never uploaded exist only on this device; the dialog
  /// says how many would be lost.
  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final notes = await ref.read(notesProvider(account.id).future);
    final unsent = notes.where((n) => n.syncState != 'clean').length;
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(
          unsent == 0 ? l.removeAccountConfirm : l.removeAccountUnsent(unsent),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.removeAccount),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(runtimeProvider).accounts.remove(account.id);
    navigator.pop();
  }
}
