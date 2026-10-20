import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notes_store/notes_store.dart';
import '../../l10n/app_localizations.dart';

const shareChannel = MethodChannel('com.nkshub.nextcloudnotes/share');

/// Asks the platform for text waiting from another app; null when nothing is
/// waiting or the platform has no share target.
Future<Map<String, String>?> fetchSharedText() async {
  try {
    return await shareChannel.invokeMapMethod<String, String>('takeShared');
  } on MissingPluginException {
    return null; // Only Android and iOS register the share target.
  }
}

/// Text shared from another app (Google Keep, Samsung Notes, ...) becomes a
/// new note of [accountId] or is appended to a recent one. Returns after the
/// note was created or opened.
Future<void> takeSharedText({
  required BuildContext context,
  required NotesDatabase db,
  required String accountId,
  required Map<String, String> shared,
  required Future<List<LocalNote>> Function() recent,
  required Future<void> Function({
    required String title,
    required String content,
  })
  create,
  required Future<void> Function(LocalNote note) edit,
}) async {
  final text = shared['text'] ?? '';
  final title = shared['title'] ?? '';
  final notes = (await recent())
      .where(
        (n) =>
            !n.readonly && (n.syncState == 'clean' || n.syncState == 'draft'),
      )
      .take(8)
      .toList();
  if (!context.mounted) return;
  final l = AppLocalizations.of(context)!;
  // Dismissing the dialog still keeps the text, as a new note.
  final target = notes.isEmpty
      ? null
      : await showDialog<LocalNote>(
          context: context,
          builder: (dialog) => SimpleDialog(
            title: Text(l.shareTo),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.of(dialog).pop(),
                child: Text(l.newNote),
              ),
              for (final note in notes)
                SimpleDialogOption(
                  onPressed: () => Navigator.of(dialog).pop(note),
                  child: Text(
                    _shownTitle(note, l),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        );
  if (target == null) {
    await create(title: _titleOr(title, text), content: text);
    return;
  }
  try {
    final current = (await db.note(accountId, target.id))!;
    await db.saveDraft(
      accountId: accountId,
      id: current.id,
      revision: current.revision,
      title: current.title,
      content: current.content.isEmpty
          ? text
          : '${current.content.trimRight()}\n\n$text',
      category: current.category,
      favorite: current.favorite,
    );
    final updated = await db.note(accountId, current.id);
    if (updated != null) await edit(updated);
  } catch (_) {
    // The note changed meanwhile; the text is not lost, it becomes a note.
    await create(title: '', content: text);
  }
}

String titleOr(String title, String text) => _titleOr(title, text);

String _titleOr(String title, String text) =>
    title.trim().isNotEmpty ? title : titleFromContent(text);

/// A note not uploaded yet shows the name the server will give it.
String _shownTitle(LocalNote n, AppLocalizations l) {
  final title = n.title.trim().isEmpty ? titleFromContent(n.content) : n.title;
  return title.isEmpty ? l.untitled : title;
}
