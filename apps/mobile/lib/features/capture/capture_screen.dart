import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_store/notes_store.dart';

import '../../data/attachments/providers.dart';
import '../../data/capture/capture_inbox.dart';
import '../../data/capture/capture_store.dart';
import '../../data/capture/providers.dart';
import '../../data/runtime.dart';
import '../../design/design.dart';
import '../../l10n/app_localizations.dart';

enum _Mode { create, append }

/// Where content shared from another app goes. Pops with true once the
/// capture became local data; any other way out leaves it pending.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({required this.capture, super.key});
  final Capture capture;

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureState();
}

class _CaptureState extends ConsumerState<CaptureScreen> {
  String? _accountId;
  _Mode _mode = _Mode.create;
  final _category = TextEditingController();
  final _search = TextEditingController();
  String? _target;
  bool _busy = false;
  bool _failed = false;

  @override
  void dispose() {
    _category.dispose();
    _search.dispose();
    super.dispose();
  }

  /// The chosen account, the only account, or the one the sender named when
  /// it is signed in. Never a silent fallback for an unknown hint.
  String? _effective(List<Account> accounts) {
    if (_accountId != null) return _accountId;
    final hint = widget.capture.accountHint;
    if (hint != null) {
      return accounts.any((a) => a.id == hint) ? hint : null;
    }
    return accounts.length == 1 ? accounts.first.id : null;
  }

  Future<void> _save(String accountId) async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final store = await ref.read(captureStoreProvider.future);
      final attachments = await ref.read(attachmentServiceProvider.future);
      await convertCapture(
        database: ref.read(runtimeProvider).database,
        attachments: attachments,
        store: store,
        capture: widget.capture,
        accountId: accountId,
        target: _mode == _Mode.append && _target != null
            ? AppendTo(_target!)
            : NewNote(category: _category.text.trim()),
      );
      if (mounted) Navigator.pop(context, true);
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _discard() async {
    final l = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.captureDiscardTitle),
        content: Text(l.captureDiscardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.captureDiscard),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final store = await ref.read(captureStoreProvider.future);
    await store.complete(widget.capture.id);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    final accountId = _effective(accounts);
    final capture = widget.capture;
    final unknownHint =
        capture.accountHint != null &&
        _accountId == null &&
        accountId == null &&
        accounts.isNotEmpty;
    final canSave =
        !_busy &&
        accountId != null &&
        (_mode == _Mode.create || _target != null);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.captureTitle),
        actions: [
          IconButton(
            tooltip: l.captureDiscard,
            icon: const Icon(Icons.delete_outline),
            onPressed: _busy ? null : _discard,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: OwnShape.formWidth),
            child: ListView(
              padding: const EdgeInsets.all(OwnSpace.phoneInset),
              children: [
                _summary(l, capture),
                const SizedBox(height: OwnSpace.l),
                if (_failed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: OwnSpace.l),
                    child: OwnBanner(
                      tone: OwnTone.error,
                      message: l.captureSaveFailed,
                    ),
                  ),
                if (unknownHint)
                  Padding(
                    padding: const EdgeInsets.only(bottom: OwnSpace.l),
                    child: OwnBanner(
                      tone: OwnTone.decision,
                      message: l.captureUnknownAccount,
                    ),
                  ),
                _accountSection(l, accounts, accountId),
                if (accountId != null) ...[
                  const SizedBox(height: OwnSpace.l),
                  SegmentedButton<_Mode>(
                    segments: [
                      ButtonSegment(
                        value: _Mode.create,
                        icon: const Icon(Icons.note_add_outlined),
                        label: Text(l.captureNewNote),
                      ),
                      ButtonSegment(
                        value: _Mode.append,
                        icon: const Icon(Icons.playlist_add),
                        label: Text(l.captureAppend),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) => setState(() => _mode = s.first),
                  ),
                  const SizedBox(height: OwnSpace.l),
                  if (_mode == _Mode.create)
                    _categoryField(l, accountId)
                  else
                    _appendTargets(l, accountId),
                ],
                const SizedBox(height: OwnSpace.xl),
                OwnButton.primary(
                  label: l.captureSave,
                  icon: Icons.save_outlined,
                  fullWidth: true,
                  onPressed: canSave ? () => _save(accountId) : null,
                ),
                const SizedBox(height: OwnSpace.m),
                Text(
                  l.captureKept,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summary(AppLocalizations l, Capture capture) {
    final theme = Theme.of(context);
    final text = capture.text.trim();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(OwnSpace.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (capture.title.trim().isNotEmpty)
              Text(capture.title.trim(), style: theme.textTheme.titleMedium),
            if (text.isNotEmpty)
              Text(text, maxLines: 8, overflow: TextOverflow.ellipsis)
            else if (capture.files.isNotEmpty)
              Text(l.captureNoText),
            if (capture.files.isNotEmpty) ...[
              const SizedBox(height: OwnSpace.s),
              Text(
                l.captureFiles(capture.files.length),
                style: theme.textTheme.labelLarge,
              ),
              for (final f in capture.files)
                Row(
                  children: [
                    Icon(
                      f.mime.startsWith('image/')
                          ? Icons.image_outlined
                          : Icons.insert_drive_file_outlined,
                      size: 20,
                    ),
                    const SizedBox(width: OwnSpace.s),
                    Expanded(child: Text(f.name)),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _accountSection(
    AppLocalizations l,
    List<Account> accounts,
    String? chosen,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l.captureAccount, style: theme.textTheme.titleSmall),
        ),
        if (chosen == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: OwnSpace.xs),
            child: Text(l.captureChooseAccount),
          ),
        for (final a in accounts)
          ListTile(
            key: Key('account-${a.id}'),
            contentPadding: EdgeInsets.zero,
            selected: a.id == chosen,
            leading: Icon(
              a.id == chosen
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            title: Text(a.loginName),
            subtitle: Text(Uri.tryParse(a.server)?.host ?? a.server),
            onTap: () => setState(() {
              _accountId = a.id;
              _target = null;
            }),
          ),
      ],
    );
  }

  Widget _categoryField(AppLocalizations l, String accountId) {
    final categories = {
      for (final n
          in ref.watch(notesProvider(accountId)).valueOrNull ??
              const <LocalNote>[])
        if (n.category.isNotEmpty) n.category,
    }.take(8).toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _category,
          decoration: InputDecoration(labelText: l.captureCategory),
        ),
        if (categories.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: OwnSpace.s),
            child: Wrap(
              spacing: OwnSpace.s,
              children: [
                for (final c in categories)
                  ActionChip(
                    label: Text(c),
                    onPressed: () => setState(() => _category.text = c),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _appendTargets(AppLocalizations l, String accountId) {
    final query = _search.text.trim().toLowerCase();
    final notes = [
      for (final n
          in ref.watch(notesProvider(accountId)).valueOrNull ??
              const <LocalNote>[])
        if (!n.readonly &&
            (n.syncState == 'clean' || n.syncState == 'draft') &&
            (query.isEmpty ||
                n.title.toLowerCase().contains(query) ||
                n.category.toLowerCase().contains(query)))
          n,
    ].take(30).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _search,
          decoration: InputDecoration(
            labelText: l.captureSearchTarget,
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (_target == null)
          Padding(
            padding: const EdgeInsets.only(top: OwnSpace.s),
            child: Text(l.captureNoTarget),
          ),
        if (notes.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: OwnSpace.s),
            child: Text(l.captureNoMatches),
          ),
        for (final n in notes)
          ListTile(
            key: Key('target-${n.id}'),
            contentPadding: EdgeInsets.zero,
            selected: n.id == _target,
            leading: Icon(
              n.id == _target
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            title: Text(n.title.isEmpty ? l.untitled : n.title),
            subtitle: n.category.isEmpty ? null : Text(n.category),
            onTap: () => setState(() => _target = n.id),
          ),
      ],
    );
  }
}
