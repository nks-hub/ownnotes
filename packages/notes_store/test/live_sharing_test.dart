import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import 'package:test/test.dart';

/// Runs against a real Nextcloud only when OWNNOTES_LIVE_URL and the two
/// dedicated accounts are set: OWNNOTES_LIVE_USER / _PASSWORD (the owner A)
/// and OWNNOTES_LIVE_USER2 / _PASSWORD2 (the recipient B). It creates, shares
/// and deletes one file per test.
///
/// Two paths exist on the server. A note inside A's Notes folder shared with
/// B lands in B's Notes folder (the Notes app rewrites the share target), so
/// B's Notes API lists it and the ordinary sync handles it. Any other
/// Markdown file lands in B's files root; B reaches it over WebDAV.
void main() {
  final env = Platform.environment;
  final url = env['OWNNOTES_LIVE_URL'];
  final userA = env['OWNNOTES_LIVE_USER'];
  final passA = env['OWNNOTES_LIVE_PASSWORD'];
  final userB = env['OWNNOTES_LIVE_USER2'];
  final passB = env['OWNNOTES_LIVE_PASSWORD2'];
  final skip =
      url == null ||
          userA == null ||
          passA == null ||
          userB == null ||
          passB == null
      ? 'OWNNOTES_LIVE_URL/USER/PASSWORD/USER2/PASSWORD2 not set'
      : null;

  late http.Client transport;
  late ServerBase base;
  late NotesClient notesA;
  late SharingClient sharingA;
  late SharingClient sharingB;
  late NotesDatabase db;
  late SyncCoordinator syncB;
  final cleanup = <Future<void> Function()>[];

  setUp(() async {
    transport = http.Client();
    base = ServerBase.parse(url!);
    notesA = NotesClient(
      base: base,
      transport: transport,
      loginName: userA!,
      appPassword: passA!,
    );
    sharingA = SharingClient(
      base: base,
      transport: transport,
      loginName: userA,
      appPassword: passA,
    );
    sharingB = SharingClient(
      base: base,
      transport: transport,
      loginName: userB!,
      appPassword: passB!,
    );
    db = NotesDatabase(NativeDatabase.memory());
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'b',
            server: url,
            loginName: userB,
            credentialRef: 'live',
          ),
        );
    syncB = SyncCoordinator(
      db,
      (_) async => NotesClient(
        base: base,
        transport: transport,
        loginName: userB,
        appPassword: passB,
      ),
      sharingFor: (_) async => sharingB,
      shareListInterval: Duration.zero,
    );
  });

  tearDown(() async {
    for (final undo in cleanup.reversed) {
      try {
        await undo();
      } on Object {
        /* Already gone. */
      }
    }
    cleanup.clear();
    await db.close();
    transport.close();
  });

  /// The recipient's copy, whichever way it arrived.
  Future<LocalNote> recipient(int fileId) => (db.select(
    db.localNotes,
  )..where((n) => n.remoteId.equals(fileId))).getSingle();

  Future<void> editB(int fileId, String content) async {
    final n = await recipient(fileId);
    await db.saveDraft(
      accountId: 'b',
      id: n.id,
      revision: n.revision,
      title: n.title,
      content: content,
      category: n.category,
      favorite: n.favorite,
    );
  }

  /// Edits, merges and a decision, as seen from B, with A as the other side.
  Future<void> sequence({
    required int fileId,
    required Future<String> Function() contentA,
    required Future<void> Function(String) editA,
    required String kind,
  }) async {
    await syncB.sync('b');
    var b = await recipient(fileId);
    expect(b.kind, kind);
    expect(b.content, 'milk\nbread\neggs\n');
    expect(b.readonly, isFalse);

    await editB(fileId, 'milk\nbread\neggs\nbutter\n');
    await syncB.sync('b');
    expect(await contentA(), 'milk\nbread\neggs\nbutter\n');
    expect((await recipient(fileId)).syncState, 'clean');

    await editA('milk\nbread\neggs\nbutter\ncoffee\n');
    await syncB.sync('b');
    b = await recipient(fileId);
    expect(b.content, 'milk\nbread\neggs\nbutter\ncoffee\n');
    expect(b.syncState, 'clean');

    await editB(fileId, 'oat milk\nbread\neggs\nbutter\ncoffee\n');
    await editA('milk\nbread\neggs\nbutter\ncoffee\ntea\n');
    await syncB.sync('b');
    expect(await contentA(), 'oat milk\nbread\neggs\nbutter\ncoffee\ntea\n');
    b = await recipient(fileId);
    expect(b.syncState, 'clean');
    expect(b.content, await contentA());

    await editB(fileId, 'oat milk\nrye bread\neggs\nbutter\ncoffee\ntea\n');
    await editA('oat milk\nwhite bread\neggs\nbutter\ncoffee\ntea\n');
    await syncB.sync('b');
    b = await recipient(fileId);
    expect(b.syncState, 'needsDecision');
    expect(await contentA(), contains('white bread'));
    final RemoteNote remote;
    if (kind == 'shared') {
      remote = await syncB.readShared(b);
    } else {
      remote =
          await NotesClient(
                base: base,
                transport: transport,
                loginName: userB!,
                appPassword: passB!,
              ).get(fileId)
              as RemoteNote;
    }
    await NoteRecovery(db).useRemote(
      expected: b,
      remote: remote,
      keepLocal: true,
      content: mergeVersions(b.content, remote.content),
    );
    await syncB.sync('b');
    b = await recipient(fileId);
    expect(b.syncState, 'clean');
    final end = await contentA();
    expect(end, contains('rye bread'));
    expect(end, contains('white bread'));
    expect(end, b.content);
  }

  test(
    'a note shared from the Notes folder arrives as an ordinary note',
    () async {
      final title = 'ownnotes-share-${DateTime.now().microsecondsSinceEpoch}';
      final note =
          await notesA.create(
                title: title,
                content: 'milk\nbread\neggs\n',
                category: 'OwnNotes live',
              )
              as RemoteNote;
      cleanup.add(() => notesA.delete(note.id));
      expect(await sharingA.searchSharees(userB!), isNotEmpty);
      final share = await sharingA.shareWithUser(note.internalPath!, userB);
      cleanup.add(() => sharingA.unshare(share.id));
      expect(await sharingA.sharesOf(note.internalPath!), hasLength(1));

      await sequence(
        fileId: note.id,
        kind: 'note',
        contentA: () async =>
            ((await notesA.get(note.id)) as RemoteNote).content,
        editA: (text) async {
          final current = (await notesA.get(note.id)) as RemoteNote;
          await notesA.update(
            note.id,
            etag: current.etag,
            patch: NotePatch(content: text),
          );
        },
      );

      await sharingA.unshare(share.id);
      await syncB.sync('b');
      expect(await db.select(db.localNotes).get(), isEmpty);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'a Markdown file shared from outside the Notes folder syncs over WebDAV',
    () async {
      final path =
          '/ownnotes-share-${DateTime.now().microsecondsSinceEpoch}.md';
      final put = await transport.put(
        base.davFile(userA!, path.substring(1).split('/')),
        headers: {
          'Authorization':
              'Basic ${base64Encode(utf8.encode('$userA:$passA'))}',
        },
        body: 'milk\nbread\neggs\n',
      );
      expect(put.statusCode, 201);
      cleanup.add(() async {
        await transport.delete(
          base.davFile(userA, path.substring(1).split('/')),
          headers: {
            'Authorization':
                'Basic ${base64Encode(utf8.encode('$userA:$passA'))}',
          },
        );
      });
      final share = await sharingA.shareWithUser(path, userB!);
      cleanup.add(() => sharingA.unshare(share.id));
      final fileId = (await sharingA.stat(path)).fileId!;

      await sequence(
        fileId: fileId,
        kind: 'shared',
        contentA: () async => (await sharingA.read(path)).content,
        editA: (text) async {
          final current = await sharingA.read(path);
          await sharingA.write(path, text, etag: current.etag);
        },
      );

      await sharingA.unshare(share.id);
      await syncB.sync('b');
      expect(await db.select(db.localNotes).get(), isEmpty);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
