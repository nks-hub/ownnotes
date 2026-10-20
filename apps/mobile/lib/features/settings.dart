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
import 'accounts.dart';

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
            leading: const Icon(Icons.manage_accounts_outlined),
            title: Text(l.accounts),
            subtitle: Text(
              '${account.loginName} · ${Uri.parse(account.server).host}',
            ),
            onTap: () => _accounts(context, ref),
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

  /// Settings belong to one account, so leave them when the user switched to
  /// another one or removed this one.
  Future<void> _accounts(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final picked = await openAccounts(context, currentId: account.id);
    final stillThere =
        await ref.read(runtimeProvider).database.account(account.id) != null;
    if (navigator.mounted &&
        (!stillThere || (picked ?? account.id) != account.id)) {
      navigator.pop();
    }
  }
}
