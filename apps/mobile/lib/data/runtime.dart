import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import 'account_transport.dart';

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
  /// [serverChecks] adds the Notes settings check before each pull and the
  /// shared-with-me listing; tests with a fake server leave them off.
  AppRuntime(
    this.database,
    this.vault, {
    http.Client Function()? transport,
    bool serverChecks = false,
    http.Client Function(http.Client)? decorateTransport,
    // Public injection names stay separate from their private fields.
    // ignore: prefer_initializing_formals
  }) : _transport = transport,
       // ignore: prefer_initializing_formals
       _decorateTransport = decorateTransport {
    accounts = AccountRepository(database, vault);
    sync = SyncCoordinator(
      database,
      clientFor,
      sharingFor: serverChecks ? sharingFor : null,
      scopeFor: serverChecks
          ? (account) async => (await clientFor(account)).scope()
          : null,
    );
    attention = AttentionFeed(database);
  }

  /// The app and the background worker may run in one process; sharing the
  /// connection there lets the note list see the worker's writes at once.
  factory AppRuntime.production({
    http.Client Function()? transport,
    http.Client Function(http.Client)? decorateTransport,
  }) => AppRuntime(
    NotesDatabase(
      driftDatabase(
        name: 'ownnotes_candidate',
        native: const DriftNativeOptions(shareAcrossIsolates: true),
      ),
    ),
    const SecureVault(),
    transport: transport,
    decorateTransport: decorateTransport,
    serverChecks: true,
  );
  final NotesDatabase database;
  final CredentialVault vault;
  late final AccountRepository accounts;
  late final SyncCoordinator sync;
  late final AttentionFeed attention;
  final http.Client Function()? _transport;
  final http.Client Function(http.Client)? _decorateTransport;

  http.Client createAccountTransport(Account account) {
    final client = _transport?.call() ?? AccountTransport(database, account.id);
    return _decorateTransport?.call(client) ?? client;
  }

  final _clients = <String, http.Client>{};
  Future<NotesClient> clientFor(Account account) async {
    final password = await vault.read(account.credentialRef);
    if (password == null) throw StateError('reauth_required');
    return NotesClient(
      base: ServerBase.parse(account.server),
      transport: _clients.putIfAbsent(
        account.id,
        () => createAccountTransport(account),
      ),
      loginName: account.loginName,
      appPassword: password,
    );
  }

  Future<SharingClient> sharingFor(Account account) async {
    final password = await vault.read(account.credentialRef);
    if (password == null) throw StateError('reauth_required');
    return SharingClient(
      base: ServerBase.parse(account.server),
      transport: _clients.putIfAbsent(
        account.id,
        () => createAccountTransport(account),
      ),
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
