import 'dart:io';
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import 'package:test/test.dart';

/// Runs against a real Nextcloud only when OWNNOTES_LIVE_URL, OWNNOTES_LIVE_USER
/// and OWNNOTES_LIVE_PASSWORD are set. Two stores stand for two phones of one
/// account: both edit the same line, the second upload meets the first, and
/// the store API resolves the conflict. The note is deleted at the end.
void main() {
  final env = Platform.environment;
  final url = env['OWNNOTES_LIVE_URL'];
  final user = env['OWNNOTES_LIVE_USER'];
  final password = env['OWNNOTES_LIVE_PASSWORD'];
  final skip = url == null || user == null || password == null
      ? 'OWNNOTES_LIVE_URL/USER/PASSWORD not set'
      : null;

  test(
    'a real conflict between two phones is compared and resolved',
    () async {
      final base = ServerBase.parse(url!);
      final transport = http.Client();
      addTearDown(transport.close);
      NotesClient client() => NotesClient(
        base: base,
        transport: transport,
        loginName: user!,
        appPassword: password!,
      );

      Future<NotesDatabase> phone() async {
        final db = NotesDatabase(NativeDatabase.memory());
        await db
            .into(db.accounts)
            .insert(
              AccountsCompanion.insert(
                id: 'a',
                server: url,
                loginName: user!,
                credentialRef: 'live',
              ),
            );
        return db;
      }

      final one = await phone();
      final two = await phone();
      addTearDown(one.close);
      addTearDown(two.close);
      final syncOne = SyncCoordinator(one, (_) async => client());
      final syncTwo = SyncCoordinator(two, (_) async => client());
      final marker = 'conflict ${DateTime.now().millisecondsSinceEpoch}';

      // Phone one creates the note.
      final id = await one.createDraft(
        'a',
        title: marker,
        content: 'shared line\nbase line\nlast line',
      );
      await syncOne.sync('a');
      final created = (await one.note('a', id))!;
      expect(created.syncState, 'clean');
      final remoteId = created.remoteId!;
      addTearDown(() async {
        try {
          await client().delete(remoteId);
        } catch (_) {}
      });

      // Phone two pulls it and changes the middle line, then uploads.
      await syncTwo.sync('a');
      final onTwo = await (two.select(
        two.localNotes,
      )..where((n) => n.remoteId.equals(remoteId))).getSingle();
      await two.saveDraft(
        accountId: 'a',
        id: onTwo.id,
        revision: onTwo.revision,
        title: onTwo.title,
        content: 'shared line\nphone two line\nlast line',
        category: '',
        favorite: false,
      );
      await syncTwo.sync('a');
      expect((await two.note('a', onTwo.id))!.syncState, 'clean');

      // Phone one changes the same line differently and uploads: 412, the
      // line merge fails, a decision is stored.
      await one.saveDraft(
        accountId: 'a',
        id: id,
        revision: created.revision,
        title: created.title,
        content: 'shared line\nphone one line\nlast line',
        category: '',
        favorite: false,
      );
      await syncOne.sync('a');
      final conflicted = (await one.note('a', id))!;
      expect(conflicted.syncState, 'needsDecision');
      final recovery = NoteRecovery(one);
      expect(await recovery.reason(conflicted), 'remote_conflict');
      final status = await one.syncStatus('a');
      expect(status.decisions, 1);
      expect(status.lastCheckedAt, isNotNull);

      Future<RemoteNote?> read() async {
        final r = await client().get(remoteId);
        return r is RemoteNote ? r : null;
      }

      final inspected = (await read())!;
      expect(inspected.content, contains('phone two line'));

      // Phone two moves on while phone one is deciding: nothing is applied.
      final again = await two.note('a', onTwo.id);
      await two.saveDraft(
        accountId: 'a',
        id: onTwo.id,
        revision: again!.revision,
        title: again.title,
        content: 'shared line\nphone two line\nlast line\nphone two added',
        category: '',
        favorite: false,
      );
      await syncTwo.sync('a');
      final stale = await recovery.resolve(
        expected: conflicted,
        inspected: inspected,
        readServer: read,
        choice: ConflictChoice.result,
        content: 'x',
      );
      expect(stale.status, ConflictStatus.serverChanged);
      expect((await one.note('a', id))!.syncState, 'needsDecision');

      // Reviewed again: the Result keeps both lines and goes up.
      final fresh = stale.server!;
      final result =
          'shared line\nphone one line\nphone two line\n'
          'last line\nphone two added';
      final applied = await recovery.resolve(
        expected: conflicted,
        inspected: fresh,
        readServer: read,
        choice: ConflictChoice.result,
        content: result,
      );
      expect(applied.status, ConflictStatus.applied);
      await syncOne.sync('a');
      final done = (await one.note('a', id))!;
      expect(done.syncState, 'clean');
      expect(done.content, result);
      expect((await read())!.content, result);
      final copies = await recovery.watchCopies('a').first;
      expect(
        copies.map((c) => c.content),
        containsAll([
          'shared line\nphone one line\nlast line',
          'shared line\nphone two line\nlast line',
          'shared line\nphone two line\nlast line\nphone two added',
        ]),
      );
      expect((await one.syncStatus('a')).decisions, 0);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
