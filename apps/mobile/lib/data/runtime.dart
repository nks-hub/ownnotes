import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';

final runtimeProvider = Provider<AppRuntime>(
  (ref) => throw StateError('runtime_missing'),
);
final accountsProvider = StreamProvider(
  (ref) => ref.watch(runtimeProvider).database.watchAccounts(),
);
final notesProvider = StreamProvider.family<List<LocalNote>, String>(
  (ref, accountId) => ref.watch(runtimeProvider).database.watchNotes(accountId),
);

final class SecureVault implements CredentialVault {
  const SecureVault();
  static const _storage = FlutterSecureStorage();
  @override
  Future<void> write(String reference, String password) =>
      _storage.write(key: reference, value: password);
  @override
  Future<String?> read(String reference) => _storage.read(key: reference);
  @override
  Future<void> delete(String reference) => _storage.delete(key: reference);
  @override
  Future<Set<String>> references() async =>
      (await _storage.readAll()).keys.toSet();
}

final class AppRuntime {
  AppRuntime(this.database, this.vault, {http.Client Function()? transport})
    : _transport = transport ?? http.Client.new {
    accounts = AccountRepository(database, vault);
    sync = SyncCoordinator(database, clientFor);
  }

  /// The app and the background worker may run in one process; sharing the
  /// connection there lets the note list see the worker's writes at once.
  factory AppRuntime.production() => AppRuntime(
    NotesDatabase(
      driftDatabase(
        name: 'ownnotes_candidate',
        native: const DriftNativeOptions(shareAcrossIsolates: true),
      ),
    ),
    const SecureVault(),
  );
  final NotesDatabase database;
  final CredentialVault vault;
  late final AccountRepository accounts;
  late final SyncCoordinator sync;
  final http.Client Function() _transport;
  final _clients = <String, http.Client>{};
  Future<NotesClient> clientFor(Account account) async {
    final password = await vault.read(account.credentialRef);
    if (password == null) throw StateError('reauth_required');
    return NotesClient(
      base: ServerBase.parse(account.server),
      transport: _clients.putIfAbsent(account.id, _transport),
      loginName: account.loginName,
      appPassword: password,
    );
  }

  Future<void> initialize() async {
    await accounts.recover();
    await sync.recoverInterruptedWrites();
  }

  Future<void> close() async {
    for (final client in _clients.values) {
      client.close();
    }
    await database.close();
  }
}
