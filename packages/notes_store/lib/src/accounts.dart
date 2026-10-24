import 'package:drift/drift.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:uuid/uuid.dart';
import 'database.dart';

abstract interface class CredentialVault {
  Future<void> write(String reference, String password);
  Future<String?> read(String reference);
  Future<void> delete(String reference);
  Future<Set<String>> references();
}

/// Serialize onboarding and recovery; never fall back to plaintext storage.
final class AccountRepository {
  AccountRepository(this.database, this.vault);
  final NotesDatabase database;
  final CredentialVault vault;
  Future<void> _tail = Future<void>.value();
  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<String> add(
    LoginCredentials credentials, {
    String? certificateFingerprint,
    bool Function()? canCommit,
  }) => _serialize(() async {
    final id = const Uuid().v4();
    final reference = 'ownnotes.account.$id';
    _checkCommit(canCommit);
    await vault.write(reference, credentials.appPassword);
    try {
      await database.transaction(() async {
        _checkCommit(canCommit);
        await database
            .into(database.accounts)
            .insert(
              AccountsCompanion.insert(
                id: id,
                server: credentials.server.uri.toString(),
                loginName: credentials.loginName,
                credentialRef: reference,
                certificateFingerprint: Value(certificateFingerprint),
              ),
            );
        _checkCommit(canCommit);
      });
    } catch (_) {
      // Failed deletion is repaired by the next startup recovery.
      try {
        await vault.delete(reference);
      } catch (_) {}
      rethrow;
    }
    return id;
  });

  /// Signs an existing account in again without touching its notes: same id,
  /// same credential reference, only the secret is replaced. Refuses a login
  /// for another server or user.
  Future<void> reauthenticate(
    String id,
    LoginCredentials credentials, {
    String? certificateFingerprint,
    bool Function()? canCommit,
  }) => _serialize(() async {
    final account = await database.account(id);
    if (account == null) throw StateError('account_missing');
    if (account.server != credentials.server.uri.toString() ||
        account.loginName != credentials.loginName) {
      throw StateError('identity_mismatch');
    }
    if (account.certificateFingerprint != null &&
        certificateFingerprint != null &&
        account.certificateFingerprint != certificateFingerprint) {
      throw StateError('certificate_changed');
    }
    final previous = await vault.read(account.credentialRef);
    _checkCommit(canCommit);
    await vault.write(account.credentialRef, credentials.appPassword);
    try {
      await database.transaction(() async {
        _checkCommit(canCommit);
        await (database.update(
          database.accounts,
        )..where((a) => a.id.equals(id))).write(
          AccountsCompanion(
            state: const Value('capabilitiesPending'),
            certificateFingerprint: Value(
              certificateFingerprint ?? account.certificateFingerprint,
            ),
          ),
        );
        _checkCommit(canCommit);
      });
    } catch (_) {
      if (previous == null) {
        await vault.delete(account.credentialRef);
      } else {
        await vault.write(account.credentialRef, previous);
      }
      rethrow;
    }
  });

  static void _checkCommit(bool Function()? canCommit) {
    if (canCommit?.call() == false) throw StateError('onboarding_cancelled');
  }

  Future<void> remove(String id) => _serialize(() async {
    final account = await database.account(id);
    if (account == null) return;
    // Remove identity first. Late results cannot recreate the account.
    await (database.delete(
      database.accounts,
    )..where((a) => a.id.equals(id))).go();
    await vault.delete(account.credentialRef);
  });
  Future<void> recover() => _serialize(() async {
    final accounts = await database.select(database.accounts).get();
    final retained = accounts.map((a) => a.credentialRef).toSet();
    for (final reference in await vault.references()) {
      if (reference.startsWith('ownnotes.account.') &&
          !retained.contains(reference)) {
        await vault.delete(reference);
      }
    }
    for (final account in accounts) {
      if (await vault.read(account.credentialRef) == null) {
        await (database.update(database.accounts)
              ..where((a) => a.id.equals(account.id)))
            .write(const AccountsCompanion(state: Value('reauthRequired')));
      }
    }
  });
}
