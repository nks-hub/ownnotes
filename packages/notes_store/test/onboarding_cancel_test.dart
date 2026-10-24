import 'dart:async';

import 'package:drift/native.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import 'package:test/test.dart';

class DelayedVault implements CredentialVault {
  final values = <String, String>{};
  Completer<void>? writing;
  Completer<void>? release;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String password) async {
    values[key] = password;
    writing?.complete();
    writing = null;
    final wait = release;
    release = null;
    await wait?.future;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<Set<String>> references() async => values.keys.toSet();
}

LoginCredentials credentials(String secret) => LoginCredentials(
  server: ServerBase.parse('https://cloud.example.com'),
  loginName: 'user',
  appPassword: secret,
);

void main() {
  late NotesDatabase db;
  late DelayedVault vault;
  late AccountRepository accounts;
  setUp(() {
    db = NotesDatabase(NativeDatabase.memory());
    vault = DelayedVault();
    accounts = AccountRepository(db, vault);
  });
  tearDown(() => db.close());

  test(
    'cancel during vault write does not insert an account or retain the secret',
    () async {
      final writing = Completer<void>(), release = Completer<void>();
      vault
        ..writing = writing
        ..release = release;
      var allowed = true;
      final result = accounts.add(credentials('new'), canCommit: () => allowed);
      final rejected = expectLater(result, throwsStateError);
      await writing.future;
      allowed = false;
      release.complete();
      await rejected;
      expect(await db.watchAccounts().first, isEmpty);
      expect(vault.values, isEmpty);
    },
  );

  test(
    'cancel during reauthentication restores the old credential and pin',
    () async {
      final firstPin = 'a' * 64;
      final id = await accounts.add(
        credentials('old'),
        certificateFingerprint: firstPin,
      );
      final writing = Completer<void>(), release = Completer<void>();
      vault
        ..writing = writing
        ..release = release;
      var allowed = true;
      final result = accounts.reauthenticate(
        id,
        credentials('new'),
        canCommit: () => allowed,
      );
      final rejected = expectLater(result, throwsStateError);
      await writing.future;
      allowed = false;
      release.complete();
      await rejected;
      final account = (await db.account(id))!;
      expect(vault.values[account.credentialRef], 'old');
      expect(account.certificateFingerprint, firstPin);
    },
  );

  test(
    'reauthentication never silently replaces an existing certificate pin',
    () async {
      final id = await accounts.add(
        credentials('old'),
        certificateFingerprint: 'a' * 64,
      );
      await expectLater(
        accounts.reauthenticate(
          id,
          credentials('new'),
          certificateFingerprint: 'b' * 64,
        ),
        throwsStateError,
      );
      expect((await db.account(id))!.certificateFingerprint, 'a' * 64);
      expect(vault.values.values.single, 'old');
      await accounts.reauthenticate(id, credentials('new'));
      expect((await db.account(id))!.certificateFingerprint, 'a' * 64);
    },
  );
}
