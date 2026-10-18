import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:test/test.dart';

http.Response jsonResponse(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);
Map<String, Object> startBody({String? endpoint, String? login}) => {
  'login': login ?? 'https://cloud.test/nc/login/v2/flow/secret',
  'poll': {
    'token': 'secret+token&',
    'endpoint': endpoint ?? 'https://cloud.test/nc/login/v2/poll',
  },
};
Map<String, String> credentials({String server = 'https://cloud.test/nc'}) => {
  'server': server,
  'loginName': 'user@example.test',
  'appPassword': 'secret',
};
Matcher errorCode(String code) =>
    isA<LoginException>().having((e) => e.code, 'code', code);

void main() {
  final base = ServerBase.parse('https://cloud.test/nc');
  test(
    'subdirectory, anonymous POST, form token, pending then single receipt',
    () async {
      var calls = 0;
      final client = LoginClient(
        base: base,
        transport: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.followRedirects, isFalse);
          expect(request.headers.containsKey('authorization'), isFalse);
          calls++;
          if (calls == 1) {
            expect(request.url.path, '/nc/index.php/login/v2');
            return jsonResponse(startBody());
          }
          expect(request.url.query, isEmpty);
          expect(request.bodyFields, {'token': 'secret+token&'});
          return calls == 2
              ? http.Response('', 404)
              : jsonResponse(credentials());
        }),
      );
      final session = await client.start();
      expect(await session.poll(), isNull);
      final result = (await session.poll())!;
      expect(result.loginName, 'user@example.test');
      expect(result.server.uri, base.uri);
      expect(result.toString(), isNot(contains('secret')));
      expect(session.toString(), isNot(contains('secret')));
      await expectLater(session.poll(), throwsA(errorCode('flow_closed')));
      expect(calls, 3);
    },
  );
  for (final address in [
    'https://evil.test/nc/poll',
    'http://cloud.test/nc/poll',
    '/nc/poll',
    'https://cloud.test/other/poll',
    'https://user@cloud.test/nc/poll',
    'https://cloud.test/nc/poll?token=x',
    'https://cloud.test/nc/%2fother/poll',
  ]) {
    test('rejects untrusted endpoint $address before sending token', () async {
      var calls = 0;
      final client = LoginClient(
        base: base,
        transport: MockClient((r) async {
          calls++;
          return jsonResponse(startBody(endpoint: address));
        }),
      );
      await expectLater(
        client.start(),
        throwsA(errorCode('untrusted_endpoint')),
      );
      expect(calls, 1);
    });
  }
  test('rejects foreign login URL', () async {
    final client = LoginClient(
      base: base,
      transport: MockClient(
        (r) async => jsonResponse(startBody(login: 'https://evil.test/login')),
      ),
    );
    await expectLater(client.start(), throwsA(errorCode('untrusted_endpoint')));
  });
  test('one in-flight poll; cancellation discards late credentials', () async {
    final response = Completer<http.Response>();
    var calls = 0;
    final client = LoginClient(
      base: base,
      transport: MockClient(
        (r) async => ++calls == 1 ? jsonResponse(startBody()) : response.future,
      ),
    );
    final session = await client.start();
    final pending = session.poll();
    await expectLater(session.poll(), throwsA(errorCode('poll_in_progress')));
    session.cancel();
    response.complete(jsonResponse(credentials()));
    await expectLater(pending, throwsA(errorCode('flow_closed')));
    expect(calls, 2);
  });
  test('server change in receipt is terminal', () async {
    var calls = 0;
    final client = LoginClient(
      base: base,
      transport: MockClient(
        (r) async => ++calls == 1
            ? jsonResponse(startBody())
            : jsonResponse(credentials(server: 'https://evil.test')),
      ),
    );
    final session = await client.start();
    await expectLater(
      session.poll(),
      throwsA(errorCode('server_identity_changed')),
    );
    expect(session.isClosed, isTrue);
  });
  test('lost response closes flow and masks transport secrets', () async {
    var calls = 0;
    final client = LoginClient(
      base: base,
      transport: MockClient((r) async {
        if (++calls == 1) return jsonResponse(startBody());
        throw Exception('secret token and password');
      }),
    );
    final session = await client.start();
    await expectLater(session.poll(), throwsA(errorCode('transport_failed')));
    await expectLater(session.poll(), throwsA(errorCode('flow_closed')));
    expect(calls, 2);
  });
  test('redirect is not followed', () async {
    final client = LoginClient(
      base: base,
      transport: MockClient(
        (r) async =>
            http.Response('', 302, headers: {'location': 'https://evil.test'}),
      ),
    );
    await expectLater(client.start(), throwsA(errorCode('start_rejected')));
  });
  test('bounded response and invalid JSON produce safe errors', () async {
    final client = LoginClient(
      base: base,
      transport: MockClient((r) async => http.Response('x' * 65537, 200)),
    );
    await expectLater(client.start(), throwsA(errorCode('response_too_large')));
  });
}
