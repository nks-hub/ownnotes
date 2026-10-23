import 'package:notes_protocol/notes_protocol.dart';
import 'database.dart';
import 'pull_checkpoint.dart';

/// A page ETag is never a validator for the complete collection. Conditional
/// requests use chunkSize=0; oversized responses fall back to bounded chunks.
Future<void> pullNotes({
  required NotesDatabase database,
  required NotesClient client,
  required String accountId,
  required Future<void> Function() keepLease,
  required Future<String?> Function(Account)? scopeFor,
  required bool forceFull,
}) async {
  final account = await database.account(accountId);
  if (account == null) return;
  String? scope;
  var scopeKnown = scopeFor == null;
  if (scopeFor != null) {
    try {
      scope = await scopeFor(account);
      scopeKnown = scope != null;
    } on Object {
      // Without a verified scope, an older listing cannot validate this one.
    }
  }
  final checkpoint = await database.pullCheckpoint(accountId);
  final usable =
      !forceFull &&
      scopeKnown &&
      checkpoint != null &&
      checkpoint.generation == account.generation &&
      checkpoint.scope == scope;
  final watermark = usable ? checkpoint.watermark : null;
  final conditional =
      usable &&
      checkpoint.listEtag != null &&
      isListEtag(checkpoint.listEtag!) &&
      await database.canReuseList(checkpoint);
  final pruneBefore = conditional ? checkpoint.etagPruneBefore : watermark;
  final etag = conditional ? checkpoint.listEtag : null;

  Future<bool> read({
    int? prune,
    String? validator,
    required bool unchunked,
  }) async {
    final started = await database.account(accountId);
    if (started == null) return true;
    String? cursor;
    DateTime? modified;
    String? responseEtag;
    var pages = 0;
    final cursors = <String>{};
    final listed = <int>{};
    final sent = <int>{};
    do {
      await keepLease();
      final result = validator != null && pages == 0
          ? await client.listIfChanged(
              ifNoneMatch: validator,
              pruneBefore: prune,
            )
          : await client.list(
              cursor: cursor,
              pruneBefore: prune,
              chunkSize: unchunked ? 0 : 100,
            );
      if (result is NotesListNotModified) {
        // Recheck after the request: a recovery action may have changed the cache.
        return checkpoint != null && await database.canReuseList(checkpoint);
      }
      final page = result as NotesPage;
      if (pages++ == 0) {
        await database.invalidateListEtag(accountId);
        modified = page.lastModified;
        responseEtag = page.etag;
        if (prune != null &&
            modified != null &&
            modified.millisecondsSinceEpoch ~/ 1000 < prune) {
          return false;
        }
      }
      if (!await database.applyPull(
        accountId,
        started.mutationEpoch,
        page.notes,
      )) {
        return true;
      }
      listed.addAll(page.notes.map((n) => n.id));
      sent.addAll(page.notes.where((n) => n is! NoteIdOnly).map((n) => n.id));
      cursor = page.cursor;
      if (cursor != null && !cursors.add(cursor)) {
        throw const NotesProtocolException('repeated_chunk_cursor');
      }
    } while (cursor != null);
    final known = await database.storedRemoteIds(accountId);
    if (!known.containsAll(listed.difference(sent))) return false;
    await database.finishPull(
      started: started,
      ids: listed,
      scope: scope,
      scopeKnown: scopeKnown,
      watermark: modified == null
          ? null
          : modified.millisecondsSinceEpoch ~/ 1000,
      // Rotate the prune point after a changed conditional response. The next
      // pass obtains an ETag for the newer, smaller representation.
      etag:
          unchunked &&
              pages == 1 &&
              validator == null &&
              responseEtag != null &&
              isListEtag(responseEtag)
          ? responseEtag
          : null,
      etagPruneBefore: prune,
    );
    return true;
  }

  var complete = false;
  try {
    complete = await read(
      prune: pruneBefore,
      validator: etag,
      unchunked: watermark != null,
    );
  } on NotesProtocolException catch (error) {
    if (watermark == null ||
        !{'response_too_large', 'invalid_list_304'}.contains(error.code)) {
      rethrow;
    }
    await database.invalidateListEtag(accountId);
    complete = await read(prune: watermark, unchunked: false);
  }
  if (!complete) {
    await database.invalidateListEtag(accountId);
    if (!await read(unchunked: false)) {
      throw const NotesProtocolException('incomplete_full_listing');
    }
  }
}
