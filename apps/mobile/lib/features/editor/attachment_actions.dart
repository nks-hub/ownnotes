import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_store/notes_store.dart';

import '../../core/markdown/live_controller.dart';
import '../../data/runtime.dart';
import '../attachments/attachments_sheet.dart';
import 'edit_history.dart';

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
