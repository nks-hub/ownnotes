import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:notes_protocol/notes_protocol.dart';

/// Safe error code only: never carries URLs, bodies or credentials.
final class AccountApiException implements Exception {
  const AccountApiException(this.code);

  /// `rejected` (401/403), `server` (other answer) or `network`.
  final String code;
  @override
  String toString() => 'AccountApiException($code)';
}

/// The few Nextcloud OCS calls account management needs besides Notes itself.
final class AccountApi {
  AccountApi(this.transport, {this.timeout = const Duration(seconds: 15)});
  final http.Client transport;
  final Duration timeout;

  Uri _ocs(ServerBase server, List<String> path) => server.uri.replace(
    pathSegments: [
      ...server.uri.pathSegments.where((s) => s.isNotEmpty),
      'ocs',
      'v2.php',
      ...path,
    ],
    queryParameters: const {'format': 'json'},
  );

  Future<http.Response> _send(
    String method,
    Uri uri,
    String loginName,
    String password,
  ) async {
    final request = http.Request(method, uri)
      ..followRedirects = false
      ..headers.addAll({
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$loginName:$password'))}',
        'OCS-APIRequest': 'true',
        'Accept': 'application/json',
        'User-Agent': 'OwnNotes',
      });
    try {
      return await (() async {
        final response = await transport.send(request);
        return http.Response.fromStream(response);
      })().timeout(timeout);
    } catch (_) {
      throw const AccountApiException('network');
    }
  }

  Object? _data(http.Response response) {
    try {
      final root = jsonDecode(utf8.decode(response.bodyBytes));
      return ((root as Map<String, Object?>)['ocs']
          as Map<String, Object?>)['data'];
    } catch (_) {
      return null;
    }
  }

  void _expectOk(http.Response response) {
    if (response.statusCode == 200) return;
    final rejected = response.statusCode == 401 || response.statusCode == 403;
    throw AccountApiException(rejected ? 'rejected' : 'server');
  }

  /// Proves the credentials work and returns the display name, if any.
  Future<String?> signIn(
    ServerBase server,
    String loginName,
    String password,
  ) async {
    final response = await _send(
      'GET',
      _ocs(server, ['cloud', 'user']),
      loginName,
      password,
    );
    _expectOk(response);
    final data = _data(response);
    final name = data is Map<String, Object?> ? data['displayname'] : null;
    return name is String && name.trim().isNotEmpty ? name : null;
  }

  /// Display name for the account list; null whenever it cannot be read.
  Future<String?> displayName(
    ServerBase server,
    String loginName,
    String password,
  ) async {
    try {
      return await signIn(server, loginName, password);
    } on AccountApiException {
      return null;
    }
  }

  /// Turns the single-use token of an `nc://onetime-login/` code into an app
  /// password. The token is spent by this call, so it is never retried.
  Future<String> exchangeOneTime(
    ServerBase server,
    String loginName,
    String token,
  ) async {
    final response = await _send(
      'GET',
      _ocs(server, ['core', 'getapppassword-onetime']),
      loginName,
      token,
    );
    _expectOk(response);
    final data = _data(response);
    final password = data is Map<String, Object?> ? data['apppassword'] : null;
    if (password is! String || password.isEmpty) {
      throw const AccountApiException('server');
    }
    return password;
  }

  /// Destroys this app password on the server.
  Future<void> revoke(
    ServerBase server,
    String loginName,
    String password,
  ) async {
    final response = await _send(
      'DELETE',
      _ocs(server, ['core', 'apppassword']),
      loginName,
      password,
    );
    _expectOk(response);
  }
}
