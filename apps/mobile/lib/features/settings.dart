import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_store/notes_store.dart';
import '../data/export.dart';
import '../data/runtime.dart';
import '../data/settings.dart';
import '../l10n/app_localizations.dart';
import 'about.dart';
import 'accounts.dart';
import 'lock.dart' show localAuthProvider;
import 'templates/templates_screen.dart';

/// Languages the user can pick; null follows the system. Each is shown in
/// its own language. German is listed ahead of its translation files.
const _languages = <(String?, String)>[
  (null, ''),
  ('cs', 'Čeština'),
  ('en', 'English'),
  ('de', 'Deutsch'),
];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({required this.account, super.key});
  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final notes = ref.watch(notesProvider(account.id)).valueOrNull;
    final unsent = notes?.where((n) => n.syncState != 'clean').length ?? 0;
    final themeNames = {
      ThemeMode.system: l.themeSystem,
      ThemeMode.light: l.themeLight,
      ThemeMode.dark: l.themeDark,
    };
    String languageName(String? code) {
      final name = _languages.firstWhere((e) => e.$1 == code).$2;
      return name.isEmpty ? l.languageSystem : name;
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  l.settingsDeviceOnly,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              _Section(l.settingsAppearance),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: Text(l.theme),
                subtitle: Text(themeNames[settings.themeMode]!),
                onTap: () async {
                  final picked = await _pick<ThemeMode>(
                    context,
                    l.theme,
                    themeNames.entries.map((e) => (e.key, e.value)).toList(),
                    settings.themeMode,
                  );
                  if (picked != null) {
                    await controller.update(
                      ref.read(settingsProvider).copyWith(themeMode: picked.$1),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.language_outlined),
                title: Text(l.language),
                subtitle: Text(languageName(settings.languageCode)),
                onTap: () async {
                  final picked = await _pick<String?>(context, l.language, [
                    for (final e in _languages) (e.$1, languageName(e.$1)),
                  ], settings.languageCode);
                  if (picked != null) {
                    await controller.update(
                      ref
                          .read(settingsProvider)
                          .copyWith(
                            languageCode: picked.$1,
                            systemLanguage: picked.$1 == null,
                          ),
                    );
                  }
                },
              ),
              _Section(l.settingsWriting),
              SwitchListTile(
                secondary: const Icon(Icons.code_outlined),
                title: Text(l.monospace),
                value: settings.monospace,
                onChanged: (v) =>
                    controller.update(settings.copyWith(monospace: v)),
              ),
              ListTile(
                leading: const Icon(Icons.format_size_outlined),
                title: Text(l.textSize),
                trailing: Text('${settings.fontSize.round()}'),
              ),
              Slider(
                min: 12,
                max: 28,
                divisions: 8,
                label: '${settings.fontSize.round()}',
                semanticFormatterCallback: (v) => '${v.round()}',
                value: settings.fontSize,
                onChanged: (v) =>
                    controller.update(settings.copyWith(fontSize: v)),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(l.templatesManage),
                subtitle: Text(l.templatesDeviceOnly),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    settings: const RouteSettings(name: '/templates'),
                    builder: (_) => const TemplatesScreen(),
                  ),
                ),
              ),
              _Section(l.settingsPrivacy),
              SwitchListTile(
                secondary: const Icon(Icons.lock_outline),
                title: Text(l.appLock),
                subtitle: Text(l.appLockHint),
                value: settings.lock,
                onChanged: (v) async {
                  final messenger = ScaffoldMessenger.of(context);
                  if (v && !await _canLock(ref)) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(l.appLockUnavailable)),
                    );
                    return;
                  }
                  await controller.update(
                    ref.read(settingsProvider).copyWith(lock: v),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.widgets_outlined),
                title: Text(l.widgetPolicyTitle),
                subtitle: Text(l.widgetPolicyBody),
              ),
              if (Platform.isAndroid)
                SwitchListTile(
                  secondary: const Icon(Icons.visibility_off_outlined),
                  title: Text(l.blockScreenshots),
                  value: settings.secure,
                  onChanged: (v) =>
                      controller.update(settings.copyWith(secure: v)),
                ),
              _Section(l.settingsSync),
              ListTile(
                leading: const Icon(Icons.storage_outlined),
                title: Text(l.storageNotes(notes?.length ?? 0)),
                subtitle: Text('${l.storageUnsent(unsent)}\n${l.syncHint}'),
                isThreeLine: true,
              ),
              _Section(l.settingsTransfer),
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: Text(l.exportMarkdown),
                subtitle: Text(l.exportMarkdownHint),
                onTap: () => _export(context, ref),
              ),
              _Section(l.accounts),
              ListTile(
                leading: const Icon(Icons.manage_accounts_outlined),
                title: Text(l.accounts),
                subtitle: Text(
                  '${account.loginName} · ${Uri.parse(account.server).host}',
                ),
                onTap: () => _accounts(context, ref),
              ),
              _Section(l.settingsAbout),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l.appTitle),
                subtitle: Text(
                  ref.watch(packageInfoProvider).whenOrNull(
                        data: (i) => l.aboutVersion(i.version, i.buildNumber),
                      ) ??
                      l.settingsAbout,
                ),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    settings: const RouteSettings(name: '/about'),
                    builder: (_) => AboutScreen(account: account),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<bool> _canLock(WidgetRef ref) async {
    try {
      return await ref.read(localAuthProvider).isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Returns the chosen value in a record so that a null value (the system
  /// default) can be told apart from a dismissed dialog.
  static Future<(T,)?> _pick<T>(
    BuildContext context,
    String title,
    List<(T, String)> options,
    T current,
  ) => showDialog<(T,)>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: [
        for (final o in options)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop((o.$1,)),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: o.$1 == current
                      ? const Icon(Icons.check, size: 20)
                      : null,
                ),
                Expanded(child: Text(o.$2)),
              ],
            ),
          ),
      ],
    ),
  );

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

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
