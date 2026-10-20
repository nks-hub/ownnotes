import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_store/notes_store.dart';

import '../../core/markdown/markdown_document.dart';
import '../../data/attachments/attachment_service.dart';
import '../../data/attachments/providers.dart';
import '../../data/attachments/staging.dart';
import '../../data/runtime.dart';
import '../../design/design.dart';
import '../../l10n/app_localizations.dart';
import 'add_attachment.dart';

/// Opens the attachments of [note]: files waiting to upload, failed ones and
/// the files the Markdown links to.
///
/// [onRemoveReference] edits the note text to drop one link; the editor owns
/// that text. Without it the "Remove link" action is not offered. Deleting
/// the file on the server is a separate action and never edits the note.
Future<void> showAttachmentsSheet(
  BuildContext context,
  WidgetRef ref,
  LocalNote note, {
  Future<void> Function(AttachmentRef reference)? onRemoveReference,
}) {
  final l = AppLocalizations.of(context)!;
  return showOwnSheet<void>(
    context: context,
    title: l.attachmentsTitle,
    builder: (_) =>
        AttachmentsPanel(note: note, onRemoveReference: onRemoveReference),
  );
}

class AttachmentsPanel extends ConsumerStatefulWidget {
  const AttachmentsPanel({
    required this.note,
    this.onRemoveReference,
    super.key,
  });
  final LocalNote note;
  final Future<void> Function(AttachmentRef reference)? onRemoveReference;

  @override
  ConsumerState<AttachmentsPanel> createState() => _PanelState();
}

class _PanelState extends ConsumerState<AttachmentsPanel> {
  AttachmentService? _service;
  StreamSubscription<void>? _changes;
  List<StagedAttachment> _staged = const [];
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final service = await ref.read(attachmentServiceProvider.future);
    _changes = service.staging.changes.listen((_) => _reload());
    _service = service;
    _canDelete = await service.canDelete(widget.note.accountId);
    await _reload();
  }

  int _loads = 0;

  Future<void> _reload() async {
    final service = _service;
    if (service == null) return;
    final load = ++_loads;
    final staged = await service.pending(widget.note.accountId, widget.note.id);
    // A slower, older read must not replace a newer one.
    if (mounted && load == _loads) setState(() => _staged = staged);
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  LocalNote get _note =>
      ref
          .watch(notesProvider(widget.note.accountId))
          .valueOrNull
          ?.where((n) => n.id == widget.note.id)
          .firstOrNull ??
      widget.note;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final note = _note;
    final seen = <String>{};
    final refs = [
      for (final r in MarkdownDocument.parse(note.content).attachments)
        if (seen.add(r.path)) r,
    ];
    if (_staged.isEmpty && refs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: OwnSpace.xl),
        child: Text(l.attachmentsEmpty, textAlign: TextAlign.center),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in _staged) _stagedRow(l, note, item),
        for (final r in refs) _referenceRow(l, note, r),
        const SizedBox(height: OwnSpace.m),
        Text(
          l.attachRemoveLinkHelp,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _stagedRow(AppLocalizations l, LocalNote note, StagedAttachment item) {
    final status = switch (item.state) {
      StagedState.stored =>
        note.remoteId == null ? l.attachWaitingNote : l.attachWaiting,
      StagedState.uploading => l.attachUploading,
      StagedState.uploaded => l.attachOnServer,
      StagedState.failed => l.attachFailedState(attachErrorText(l, item.error)),
    };
    final failed = item.state == StagedState.failed;
    return ListTile(
      key: Key('staged-${item.id}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(_icon(item.mime)),
      title: Text(item.name),
      subtitle: Text(
        '${l.attachStored} · $status',
        style: failed
            ? TextStyle(color: Theme.of(context).colorScheme.error)
            : null,
      ),
      trailing: Wrap(
        children: [
          if (failed || item.state == StagedState.stored)
            IconButton(
              key: Key('retry-${item.id}'),
              tooltip: l.retry,
              icon: const Icon(Icons.refresh),
              onPressed: item.state == StagedState.uploading
                  ? null
                  : () => _service?.retry(item.id),
            ),
          IconButton(
            key: Key('unqueue-${item.id}'),
            tooltip: l.attachRemoveQueue,
            icon: const Icon(Icons.close),
            onPressed: () => _service?.discard(item.id),
          ),
        ],
      ),
    );
  }

  Widget _referenceRow(AppLocalizations l, LocalNote note, AttachmentRef ref0) {
    final name = ref0.path.split('/').last;
    final service = _service;
    return FutureBuilder<bool>(
      future: service?.isCached(note, ref0.path),
      builder: (context, cached) {
        final offline = cached.data == true;
        return ListTile(
          key: Key('ref-${ref0.path}'),
          contentPadding: EdgeInsets.zero,
          leading: ref0.isImage && service != null && note.remoteId != null
              ? _Thumb(service: service, note: note, path: ref0.path)
              : Icon(_icon(ref0.isImage ? 'image/' : '')),
          title: Text(name),
          subtitle: Text(offline ? l.attachOffline : l.attachOnServer),
          trailing: PopupMenuButton<String>(
            tooltip: l.attachMoreOptions,
            onSelected: (v) => _act(v, note, ref0),
            itemBuilder: (_) => [
              if (!offline && note.remoteId != null)
                PopupMenuItem(
                  value: 'offline',
                  child: Text(l.attachKeepOffline),
                ),
              if (widget.onRemoveReference != null)
                PopupMenuItem(value: 'link', child: Text(l.attachRemoveLink)),
              PopupMenuItem(value: 'delete', child: Text(l.attachDeleteFile)),
            ],
          ),
        );
      },
    );
  }

  Future<void> _act(String action, LocalNote note, AttachmentRef r) async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final service = _service;
    if (service == null) return;
    switch (action) {
      case 'offline':
        try {
          await service.load(note, r.path);
        } on Object {
          messenger.showSnackBar(SnackBar(content: Text(l.attachErrOffline)));
        }
        if (mounted) setState(() {});
      case 'link':
        await widget.onRemoveReference?.call(r);
      case 'delete':
        await _delete(l, note, r);
    }
  }

  Future<void> _delete(
    AppLocalizations l,
    LocalNote note,
    AttachmentRef r,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!_canDelete || note.remoteId == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.attachDeleteUnsupported)),
      );
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.attachDeleteTitle),
        content: Text('${r.path.split('/').last}\n\n${l.attachDeleteBody}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'file'),
            child: Text(l.attachDeleteFileOnly),
          ),
          if (widget.onRemoveReference != null)
            TextButton(
              onPressed: () => Navigator.pop(context, 'both'),
              child: Text(l.attachDeleteFileAndLink),
            ),
        ],
      ),
    );
    if (choice == null) return;
    try {
      await _service!.deleteRemote(note.accountId, note.remoteId!, r.path);
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l.attachDeleteFailed)));
      return;
    }
    if (choice == 'both') await widget.onRemoveReference?.call(r);
    if (mounted) setState(() {});
  }

  static IconData _icon(String mime) => mime.startsWith('image/')
      ? Icons.image_outlined
      : mime.startsWith('audio/')
      ? Icons.mic_none
      : Icons.insert_drive_file_outlined;
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.service, required this.note, required this.path});
  final AttachmentService service;
  final LocalNote note;
  final String path;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: OwnShape.target,
    height: OwnShape.target,
    child: FutureBuilder(
      future: service.load(note, path),
      builder: (context, snapshot) => snapshot.hasData
          ? ClipRRect(
              borderRadius: BorderRadius.circular(OwnShape.compactRadius),
              child: Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
                cacheWidth: 96,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.broken_image_outlined),
              ),
            )
          : Icon(
              snapshot.hasError
                  ? Icons.image_not_supported_outlined
                  : Icons.image_outlined,
            ),
    ),
  );
}
