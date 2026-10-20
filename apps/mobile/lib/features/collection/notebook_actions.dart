import 'package:notes_store/notes_store.dart';
import '../note_rows.dart';

/// Which bulk and row actions a note allows. The server lets a read-only
/// note change its favorite star only, and a note shared with the account
/// lives outside the Notes folder (no category, no deletion).
bool canFavorite(LocalNote n) => n.kind == 'note';
bool canMove(NoteRow r) =>
    !r.note.readonly &&
    r.note.kind == 'note' &&
    !r.attachments &&
    r.note.syncState != 'sending';
bool canDelete(LocalNote n) =>
    !n.readonly && n.kind == 'note' && n.syncState != 'sending';

/// The writes behind row menus, swipes and bulk actions. Every method reads
/// the note again first, so a revision changed by a sync meanwhile does not
/// fail the whole batch; it returns the notes that could not be changed.
class NotebookActions {
  const NotebookActions(this.db);
  final NotesDatabase db;

  Future<String> create(
    String accountId, {
    String title = '',
    String content = '',
    String category = '',
    bool favorite = false,
  }) async {
    final id = await db.createDraft(
      accountId,
      title: title,
      content: content,
      category: category,
    );
    if (favorite) {
      final note = await db.note(accountId, id);
      if (note != null) {
        await db.saveDraft(
          accountId: accountId,
          id: id,
          revision: note.revision,
          title: note.title,
          content: note.content,
          category: note.category,
          favorite: true,
        );
      }
    }
    return id;
  }

  Future<List<LocalNote>> _each(
    Iterable<LocalNote> notes,
    Future<void> Function(LocalNote current) change,
  ) async {
    final failed = <LocalNote>[];
    for (final n in notes) {
      try {
        final current = await db.note(n.accountId, n.id);
        if (current == null) throw StateError('note_missing');
        await change(current);
      } catch (_) {
        failed.add(n);
      }
    }
    return failed;
  }

  Future<List<LocalNote>> setFavorite(Iterable<LocalNote> notes, bool value) =>
      _each(notes, (c) async {
        if (c.favorite == value) return;
        await db.saveDraft(
          accountId: c.accountId,
          id: c.id,
          revision: c.revision,
          title: c.title,
          content: c.content,
          category: c.category,
          favorite: value,
        );
      });

  Future<List<LocalNote>> move(Iterable<LocalNote> notes, String category) =>
      _each(notes, (c) async {
        if (c.category == category) return;
        await db.saveDraft(
          accountId: c.accountId,
          id: c.id,
          revision: c.revision,
          title: c.title,
          content: c.content,
          category: category,
          favorite: c.favorite,
        );
      });

  /// Deletes [notes]; the returned list holds those that were deleted, so
  /// the caller can offer Undo for exactly them.
  Future<({List<LocalNote> deleted, List<LocalNote> failed})> delete(
    Iterable<LocalNote> notes,
  ) async {
    final deleted = <LocalNote>[];
    final failed = await _each(notes, (c) async {
      await db.markDeleted(c.accountId, c.id);
      deleted.add(c);
    });
    return (deleted: deleted, failed: failed);
  }

  /// Undo of [delete]. A note the server still has is un-deleted in place; a
  /// note that was never uploaded is gone from the table, so its text comes
  /// back as a new note.
  Future<void> restore(Iterable<LocalNote> notes) async {
    for (final n in notes) {
      try {
        if (await db.undoDelete(n.accountId, n.id)) continue;
        if (await db.note(n.accountId, n.id) != null) continue;
        await create(
          n.accountId,
          title: n.title,
          content: n.content,
          category: n.category,
          favorite: n.favorite,
        );
      } catch (_) {
        // The note stays in recovery; the snackbar cannot report each one.
      }
    }
  }
}
