import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:test/test.dart';

NotesClient client(http.Response Function(http.Request) respond) => NotesClient(
  base: ServerBase.parse('https://cloud.test/'),
  transport: MockClient((r) async => respond(r)),
  loginName: 'user',
  appPassword: 'secret',
);

void main() {
  test('conditional listing validates the complete, identical query', () async {
    final api = client((r) {
      expect(r.url.queryParameters, {'chunkSize': '0', 'pruneBefore': '100'});
      expect(r.headers['If-None-Match'], 'W/"list-a"');
      return http.Response('', 304, headers: {'etag': '"list-a"'});
    });
    expect(
      await api.listIfChanged(ifNoneMatch: 'W/"list-a"', pruneBefore: 100),
      isA<NotesListNotModified>(),
    );
  });

  test(
    'a changed conditional listing returns its new representation',
    () async {
      final api = client(
        (_) => http.Response(
          '[{"id":4}]',
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      final page = await api.listIfChanged(ifNoneMatch: '"a"') as NotesPage;
      expect(page.notes.single.id, 4);
    },
  );

  test('unconditional 304 cannot stand for an empty collection', () async {
    final api = client((_) => http.Response('', 304));
    await expectLater(api.list(), throwsA(isA<NotesHttpException>()));
  });

  test('chunk size zero requests an unchunked list', () async {
    final api = client((r) {
      expect(r.url.queryParameters['chunkSize'], '0');
      expect(r.headers.containsKey('If-None-Match'), isFalse);
      return http.Response(
        '[]',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    expect((await api.list(chunkSize: 0)).notes, isEmpty);
  });

  for (final headers in [
    {'etag': '"different"'},
    {'x-notes-chunk-cursor': 'next'},
  ]) {
    test('rejects 304 with inconsistent headers $headers', () async {
      final api = client((_) => http.Response('', 304, headers: headers));
      await expectLater(
        api.listIfChanged(ifNoneMatch: '"a"'),
        throwsA(isA<NotesProtocolException>()),
      );
    });
  }

  test('only one quoted HTTP validator may reach the transport', () {
    final api = client((_) => throw StateError('must not send'));
    for (final value in ['*', 'abc', '"a", "b"', '"a"\n', '"a\rb"']) {
      expect(() => api.listIfChanged(ifNoneMatch: value), throwsArgumentError);
    }
    expect(isListEtag('""'), isTrue);
    expect(isListEtag('W/"abc"'), isTrue);
  });
}
