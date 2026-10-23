import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_store/notes_store.dart';

import '../../core/markdown/live_controller.dart';
import '../../data/runtime.dart';
import '../../data/attachments/attachment_insertion.dart';
import '../../data/attachments/providers.dart';
import '../attachments/attachments_sheet.dart';
import 'edit_history.dart';
import 'format_dock.dart';

class EditorAttachmentDelivery {
  final _pending = <AttachmentInsertion>{};
  int _picking = 0;
  bool _closing = false;

  bool beginClosing() {
    if (_closing || _picking != 0) return false;
    _closing = true;
    return true;
  }

  void cancelClosing() => _closing = false;

  Future<void> insert(
    AttachKind kind,
    AttachHandler pick, {
    required bool Function() editable,
    required void Function(String) apply,
    required Future<void> Function() save,
  }) async {
    if (_closing || !editable()) return;
    _picking++;
    try {
      final insertion = await pick(kind);
      if (insertion == null) return;
      if (!editable()) {
        insertion.release();
        return;
      }
      _pending.add(insertion);
      apply(insertion.markdown);
      await save();
    } finally {
      _picking--;
    }
  }

  /// A write may finish after another file was inserted; confirm only its snapshot.
  List<AttachmentInsertion> snapshot() => _pending.toList();

  Future<void> saved(List<AttachmentInsertion> snapshot) async {
    for (final insertion in snapshot) {
      if (!_pending.contains(insertion)) continue;
      await insertion.acknowledge();
      _pending.remove(insertion);
    }
  }

  void dispose() {
    for (final insertion in _pending) {
      insertion.release();
    }
    _pending.clear();
  }
}

Future<void> discardEmptyEditorDraft(WidgetRef ref, LocalNote note) async {
  try {
    final database = ref.read(runtimeProvider).database;
    final attachments = await ref.read(attachmentServiceProvider.future);
    if ((await attachments.pending(
      note.accountId,
      note.id,
      strict: true,
    )).isNotEmpty) {
      return;
    }
    await database.discardEmptyDraft(note.accountId, note.id);
  } on Object {
    // Cleanup is optional; unknown staging or database state must retain the draft.
  }
}

Future<void> showEditorAttachments(
  BuildContext context,
  WidgetRef ref,
  LocalNote note,
  MarkdownTextController text,
  EditHistory history,
  Future<void> Function() save,
) => showAttachmentsSheet(
  context,
  ref,
  note,
  onRemoveReference: note.readonly
      ? null
      : (reference) async {
          final current = await ref
              .read(runtimeProvider)
              .database
              .note(note.accountId, note.id);
          if (!context.mounted || current == null || current.readonly) return;
          // A pull may have shifted the old range while the sheet was open.
          final found = text.document.attachments
              .where((r) => r.path == reference.path)
              .firstOrNull;
          if (found == null) return;
          final range = found.range;
          history.apply(
            TextEditingValue(
              text: text.text.replaceRange(range.start, range.end, ''),
              selection: TextSelection.collapsed(offset: range.start),
            ),
          );
          await save();
        },
);
