import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import 'package:share_plus/share_plus.dart';
import '../../design/design.dart';
import '../../data/runtime.dart';
import '../../l10n/app_localizations.dart';

/// Sends the note out through the platform share sheet. Tests replace it.
typedef CopySender =
    Future<void> Function({
      required String title,
      required String text,
      required bool asFile,
    });

/// A file name for [title]: no path separators or characters Android and iOS
/// refuse, never empty.
String markdownFileName(String title) {
  final clean = title
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return '${clean.isEmpty ? 'note' : clean}.md';
}

final copySenderProvider = Provider<CopySender>(
  (ref) =>
      ({required title, required text, required asFile}) async {
        if (asFile) {
          final name = markdownFileName(title);
          await SharePlus.instance.share(
            ShareParams(
              subject: title,
              files: [
                XFile.fromData(
                  Uint8List.fromList(utf8.encode(text)),
                  mimeType: 'text/markdown',
                  name: name,
                ),
              ],
              fileNameOverrides: [name],
            ),
          );
        } else {
          await SharePlus.instance.share(ShareParams(text: text, subject: title));
        }
      },
);

/// The share surface of the editor (spec 7.3): send a copy, share with
/// people, and the people who already have access.
Future<void> showShareSheet(
  BuildContext context, {
  required LocalNote note,
  required String title,
  required String Function() text,
  required Future<void> Function() flush,
  required bool hasAttachments,
}) => showOwnSheet<void>(
  context: context,
  title: AppLocalizations.of(context)!.shareTitle,
  builder: (_) => ShareSheetBody(
    note: note,
    title: title,
    text: text,
    flush: flush,
    hasAttachments: hasAttachments,
  ),
);

enum _Phase { checking, notUploaded, uploading, ready, incoming, failed }

/// A change to the shares that is not finished or did not work.
class _Operation {
  _Operation(this.userId, this.label, {required this.remove, this.canEdit = false});
  final String userId;
  final String label;
  final bool remove;
  final bool canEdit;
  bool failed = false;
}

class ShareSheetBody extends ConsumerStatefulWidget {
  const ShareSheetBody({
    required this.note,
    required this.title,
    required this.text,
    required this.flush,
    required this.hasAttachments,
    super.key,
  });
  final LocalNote note;
  final String title;
  final String Function() text;
  final Future<void> Function() flush;
  final bool hasAttachments;

  @override
  ConsumerState<ShareSheetBody> createState() => _ShareSheetBodyState();
}

class _ShareSheetBodyState extends ConsumerState<ShareSheetBody> {
  _Phase _phase = _Phase.checking;
  SharingClient? _sharing;
  String? _path;
  List<FileShare> _shares = const [];
  final _search = TextEditingController();
  List<Sharee> _found = const [];
  bool _searching = false;
  bool _searchFailed = false;
  Sharee? _picked;
  bool _canEdit = false;
  final _operations = <_Operation>[];
  Timer? _timer;
  int _generation = 0;
  late LocalNote _note = widget.note;

  @override
  void initState() {
    super.initState();
    if (widget.note.kind == 'shared') {
      _phase = _Phase.incoming;
    } else if (widget.note.remoteId == null) {
      _phase = _Phase.notUploaded;
    } else {
      _prepare();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _upload() async {
    setState(() => _phase = _Phase.uploading);
    final runtime = ref.read(runtimeProvider);
    try {
      await widget.flush();
      await runtime.sync.sync(_note.accountId);
      final fresh = await runtime.database.note(_note.accountId, _note.id);
      if (fresh == null || fresh.remoteId == null) throw StateError('not_uploaded');
      _note = fresh;
      await _prepare();
    } on Object {
      if (mounted) setState(() => _phase = _Phase.notUploaded);
      if (mounted) {
        showOwnSnackBar(context, AppLocalizations.of(context)!.shareUploadFailed);
      }
    }
  }

  Future<void> _prepare() async {
    setState(() => _phase = _Phase.checking);
    final runtime = ref.read(runtimeProvider);
    try {
      final account = await runtime.database.account(_note.accountId);
      if (account == null) throw StateError('account_missing');
      final client = await runtime.clientFor(account);
      final remote = await client.get(_note.remoteId!);
      final path = remote is RemoteNote ? remote.internalPath : null;
      if (path == null) throw StateError('no_path');
      final sharing = await runtime.sharingFor(account);
      final shares = await sharing.sharesOf(path);
      if (!mounted) return;
      setState(() {
        _sharing = sharing;
        _path = path;
        _shares = shares;
        _phase = _Phase.ready;
      });
    } on Object {
      if (mounted) setState(() => _phase = _Phase.failed);
    }
  }

  Future<void> _refreshShares() async {
    final sharing = _sharing, path = _path;
    if (sharing == null || path == null) return;
    final shares = await sharing.sharesOf(path);
    if (mounted) setState(() => _shares = shares);
  }

  void _onSearch(String value) {
    _timer?.cancel();
    final generation = ++_generation;
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _found = const [];
        _searching = false;
        _searchFailed = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchFailed = false;
    });
    _timer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final found = await _sharing!.searchSharees(query);
        if (!mounted || generation != _generation) return;
        setState(() {
          _found = found;
          _searching = false;
        });
      } on Object {
        if (!mounted || generation != _generation) return;
        setState(() {
          _searching = false;
          _searchFailed = true;
        });
      }
    });
  }

  Future<void> _share(Sharee who, bool canEdit) async {
    final op = _Operation(who.userId, who.label, remove: false, canEdit: canEdit);
    setState(() {
      _operations.add(op);
      _picked = null;
      _search.clear();
      _found = const [];
    });
    await _run(op, () => _sharing!.shareWithUser(_path!, who.userId, canEdit: canEdit));
  }

  Future<void> _unshare(FileShare share) async {
    final op = _Operation(share.shareWith, share.shareWith, remove: true);
    setState(() => _operations.add(op));
    await _run(op, () => _sharing!.unshare(share.id), share: share);
  }

  Future<void> _run(
    _Operation op,
    Future<Object?> Function() action, {
    FileShare? share,
  }) async {
    try {
      await action();
      await _refreshShares();
      // Lets the next sync list the new share.
      ref.read(runtimeProvider).sync.sync(_note.accountId, relist: true).ignore();
      if (mounted) setState(() => _operations.remove(op));
    } on Object {
      if (mounted) setState(() => op.failed = true);
    }
  }

  Future<void> _retry(_Operation op) async {
    setState(() => op.failed = false);
    final sharing = _sharing, path = _path;
    if (sharing == null || path == null) return;
    if (op.remove) {
      final share = _shares.where((s) => s.shareWith == op.userId).firstOrNull;
      if (share == null) {
        setState(() => _operations.remove(op));
        return;
      }
      await _run(op, () => sharing.unshare(share.id));
    } else {
      await _run(op, () => sharing.shareWithUser(path, op.userId, canEdit: op.canEdit));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final send = ref.watch(copySenderProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, l.shareSendCopy),
        ListTile(
          minTileHeight: OwnShape.target,
          leading: const Icon(Icons.text_snippet_outlined),
          title: Text(l.shareAsText),
          onTap: () => send(title: widget.title, text: widget.text(), asFile: false),
        ),
        ListTile(
          minTileHeight: OwnShape.target,
          leading: const Icon(Icons.description_outlined),
          title: Text(l.shareAsFile),
          onTap: () => send(title: widget.title, text: widget.text(), asFile: true),
        ),
        const SizedBox(height: 8),
        _header(context, l.shareWithPeople),
        if (widget.hasAttachments)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OwnBanner(
              tone: OwnTone.info,
              message: l.shareAttachmentsWarning,
            ),
          ),
        ..._people(context, l),
      ],
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    ),
  );

  List<Widget> _people(BuildContext context, AppLocalizations l) {
    switch (_phase) {
      case _Phase.checking:
      case _Phase.uploading:
        return [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _phase == _Phase.uploading ? l.shareUploading : l.shareChecking,
                  ),
                ),
              ],
            ),
          ),
        ];
      case _Phase.notUploaded:
        return [
          OwnBanner(tone: OwnTone.info, message: l.shareNotUploaded),
          const SizedBox(height: 8),
          OwnButton.primary(
            label: l.shareUploadFirst,
            icon: Icons.cloud_upload_outlined,
            fullWidth: true,
            onPressed: _upload,
          ),
        ];
      case _Phase.incoming:
        return [OwnBanner(tone: OwnTone.info, message: l.shareIncoming)];
      case _Phase.failed:
        return [
          OwnBanner(
            tone: OwnTone.error,
            message: l.shareFailed,
            actions: [OwnButton.text(label: l.retry, icon: Icons.refresh, onPressed: _prepare)],
          ),
        ];
      case _Phase.ready:
        break;
    }
    final already = {for (final s in _shares) s.shareWith};
    return [
      TextField(
        controller: _search,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: l.shareSearchHint,
          prefixIcon: const Icon(Icons.person_search_outlined),
        ),
        onChanged: _onSearch,
      ),
      if (_searching)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        )
      else if (_searchFailed)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: OwnBanner(tone: OwnTone.error, message: l.shareFailed),
        )
      else if (_search.text.trim().isNotEmpty &&
          _found.where((s) => !already.contains(s.userId)).isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(l.shareNoResults),
        ),
      for (final s in _found.where((s) => !already.contains(s.userId)))
        ListTile(
          minTileHeight: OwnShape.target,
          leading: const Icon(Icons.person_outline),
          title: Text(s.label),
          subtitle: s.label == s.userId ? null : Text(s.userId),
          selected: _picked?.userId == s.userId,
          onTap: () => setState(() => _picked = s),
        ),
      if (_picked != null) _picker(context, l, _picked!),
      const SizedBox(height: 8),
      _header(context, l.sharePeopleWithAccess),
      if (_shares.isEmpty && _operations.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(l.shareNone),
        ),
      for (final s in _shares) _shareRow(context, l, s),
      for (final op in _operations.where((o) => !o.remove)) _operationRow(context, l, op),
    ];
  }

  Widget _picker(BuildContext context, AppLocalizations l, Sharee who) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.visibility_outlined),
                label: Text(l.sharePermissionView),
              ),
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.edit_outlined),
                label: Text(l.sharePermissionEdit),
              ),
            ],
            selected: {_canEdit},
            onSelectionChanged: (v) => setState(() => _canEdit = v.first),
          ),
          const SizedBox(height: 8),
          OwnButton.primary(
            label: l.shareWithName(who.label),
            icon: Icons.person_add_alt_outlined,
            fullWidth: true,
            onPressed: () => _share(who, _canEdit),
          ),
        ],
      ),
    );
  }

  Widget _shareRow(BuildContext context, AppLocalizations l, FileShare s) {
    final op = _operations.where((o) => o.remove && o.userId == s.shareWith).firstOrNull;
    if (op != null) return _operationRow(context, l, op);
    return ListTile(
      minTileHeight: OwnShape.target,
      leading: const Icon(Icons.person_outline),
      title: Text(s.shareWith),
      subtitle: Row(
        children: [
          Icon(
            s.canEdit ? Icons.edit_outlined : Icons.visibility_outlined,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(s.canEdit ? l.sharePermissionEdit : l.sharePermissionView),
        ],
      ),
      trailing: IconButton(
        tooltip: l.shareRemove,
        icon: const Icon(Icons.person_remove_outlined),
        onPressed: () => _unshare(s),
      ),
    );
  }

  Widget _operationRow(BuildContext context, AppLocalizations l, _Operation op) {
    if (op.failed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: OwnBanner(
          tone: OwnTone.error,
          title: op.label,
          message: l.shareFailed,
          actions: [
            OwnButton.text(label: l.retry, icon: Icons.refresh, onPressed: () => _retry(op)),
            OwnButton.text(
              label: l.cancel,
              icon: Icons.close,
              onPressed: () => setState(() => _operations.remove(op)),
            ),
          ],
        ),
      );
    }
    return ListTile(
      minTileHeight: OwnShape.target,
      leading: const SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      title: Text(op.label),
      subtitle: Text(op.remove ? l.shareRemoving : l.sharePending),
    );
  }
}
