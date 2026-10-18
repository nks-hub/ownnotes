import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import 'package:test/test.dart';

final class MemoryVault implements CredentialVault {
  final data = <String, String>{};
  bool failWrite = false;
  @override
  Future<void> write(String reference, String password) async {
    if (failWrite) throw StateError('locked');
    data[reference] = password;
  }

  @override
  Future<String?> read(String reference) async => data[reference];
  @override
  Future<void> delete(String reference) async {
    data.remove(reference);
  }

  @override
  Future<Set<String>> references() async => data.keys.toSet();
}

LoginCredentials get credentials => LoginCredentials(
  server: ServerBase.parse('https://cloud.test/nc'),
  loginName: 'user',
  appPassword: 'password-marker',
);
RemoteNote remote(int id, String content) => RemoteNote(
  id: id,
  etag: 'v1',
  title: 'Remote',
  content: content,
  category: '',
  favorite: false,
  readonly: false,
  modified: 1,
);
void main() {
  late NotesDatabase db;
  late MemoryVault vault;
  late AccountRepository accounts;
  setUp(() {
    db = NotesDatabase(NativeDatabase.memory());
    vault = MemoryVault();
    accounts = AccountRepository(db, vault);
  });
  tearDown(() async {
    await db.close();
  });
  test('secure write failure creates no account', () async {
    vault.failWrite = true;
    await expectLater(accounts.add(credentials), throwsStateError);
    expect(await db.select(db.accounts).get(), isEmpty);
  });
  test(
    'orphan cleanup is namespaced; missing secret requires reauth',
    () async {
      final id = await accounts.add(credentials);
      vault.data.clear();
      vault.data['ownnotes.account.orphan'] = 'orphan';
      vault.data['other.application'] = 'retain';
      await accounts.recover();
      expect(vault.data, {'other.application': 'retain'});
      expect((await db.account(id))!.state, 'reauthRequired');
    },
  );
  test(
    'account isolation, optimistic editor revisions and cascading removal',
    () async {
      final a = await accounts.add(credentials);
      final b = await accounts.add(credentials);
      final id = await db.createDraft(a);
      expect(await db.note(b, id), isNull);
      expect(
        await db.saveDraft(
          accountId: a,
          id: id,
          revision: 1,
          title: 'A',
          content: '# raw\r\n🙂',
          category: '',
          favorite: true,
        ),
        2,
      );
      await expectLater(
        db.saveDraft(
          accountId: a,
          id: id,
          revision: 1,
          title: 'stale',
          content: '',
          category: '',
          favorite: false,
        ),
        throwsStateError,
      );
      expect((await db.note(a, id))!.content, '# raw\r\n🙂');
      await accounts.remove(a);
      expect(await db.note(a, id), isNull);
      expect(await db.account(b), isNotNull);
      expect(vault.data.length, 1);
    },
  );
  test(
    'pull preserves dirty draft and rejects old read after mutation epoch',
    () async {
      final a = await accounts.add(credentials);
      expect(await db.applyPull(a, 0, [remote(7, 'base')]), isTrue);
      final note = (await db.select(db.localNotes).get()).single;
      await db.saveDraft(
        accountId: a,
        id: note.id,
        revision: note.revision,
        title: note.title,
        content: 'local',
        category: '',
        favorite: false,
      );
      await db.applyPull(a, 0, [remote(7, 'remote')]);
      expect((await db.note(a, note.id))!.content, 'local');
      await (db.update(db.accounts)..where((r) => r.id.equals(a))).write(
        const AccountsCompanion(mutationEpoch: Value(1)),
      );
      expect(await db.applyPull(a, 0, [remote(8, 'late')]), isFalse);
      expect((await db.select(db.localNotes).get()).length, 1);
      await accounts.remove(a);
      expect(await db.applyPull(a, 1, [remote(8, 'late')]), isFalse);
    },
  );
  test(
    'draft survives database close and reopen without password in SQLite',
    () async {
      final directory = await Directory.systemTemp.createTemp('ownnotes-test-');
      final file = File('${directory.path}/notes.sqlite');
      final disk = NotesDatabase(NativeDatabase(file));
      final repository = AccountRepository(disk, vault);
      final a = await repository.add(credentials);
      final id = await disk.createDraft(a);
      await disk.saveDraft(
        accountId: a,
        id: id,
        revision: 1,
        title: 'Offline',
        content: 'saved',
        category: '',
        favorite: false,
      );
      await disk.close();
      final reopened = NotesDatabase(NativeDatabase(file));
      try {
        expect((await reopened.note(a, id))!.content, 'saved');
        expect(
          String.fromCharCodes(await file.readAsBytes()),
          isNot(contains('password-marker')),
        );
      } finally {
        await reopened.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
