import 'package:http/http.dart' as http;
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';

typedef PinnedClientFactory =
    http.Client Function(Uri server, String? fingerprint);

/// Cached callers still observe pin changes and account removal before sending.
final class AccountTransport extends http.BaseClient {
  AccountTransport(
    this.database,
    this.accountId, {
    PinnedClientFactory? createClient,
  }) : _createClient =
           createClient ??
           ((server, pin) =>
               CertificateHttpClient(server: server, fingerprint: pin));

  final NotesDatabase database;
  final String accountId;
  final PinnedClientFactory _createClient;
  http.Client? _client;
  String? _identity;
  bool _closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed) throw http.ClientException('client_closed');
    final account = await database.account(accountId);
    if (_closed) throw http.ClientException('client_closed');
    if (account == null) {
      close();
      throw http.ClientException('account_removed');
    }
    final server = ServerBase.parse(account.server).uri;
    if (request.url.origin != server.origin) {
      throw http.ClientException('untrusted_request_origin');
    }
    final identity =
        '${account.server}\n${account.certificateFingerprint ?? ''}';
    if (_identity != identity) {
      _client?.close();
      _client = _createClient(server, account.certificateFingerprint);
      _identity = identity;
    }
    return _client!.send(request);
  }

  @override
  void close() {
    _closed = true;
    _client?.close();
  }
}
