import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:test/test.dart';

Map<String, Object> fullNote({int id = 42}) => {
  'id': id,
  'etag': 'abc123',
  'title': 'Test',
  'content': '# Draft\n',
  'category': '',
  'favorite': false,
  'readonly': false,
  'modified': 1792300100,
};
http.Response jsonResponse(
  Object body, {
  int status = 200,
  Map<String, String> headers = const {},
}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json', ...headers},
);
NotesClient client(
  Future<http.Response> Function(http.Request) handler, {
  Duration timeout = const Duration(seconds: 1),
  int limit = 8388608,
}) => NotesClient(
  base: ServerBase.parse('https://cloud.example.invalid/nextcloud'),
  transport: MockClient(handler),
  loginName: 'test-user',
  appPassword: 'test-secret',
  timeout: timeout,
  maxResponseBytes: limit,
);

void main() {
  test('scope joins the Notes folder and file suffix', () async {
    final api = client((request) async {
      expect(
        request.url.path,
        '/nextcloud/index.php/apps/notes/api/v1/settings',
      );
      return jsonResponse({'notesPath': 'Notes', 'fileSuffix': '.md'});
    });
    expect(await api.scope(), 'Notes|.md');
    final broken = client((_) async => jsonResponse({'notesPath': 'Notes'}));
    await expectLater(broken.scope(), throwsA(isA<NotesProtocolException>()));
  });
  group('server boundary', () {
    test('keeps a Unicode subdirectory, IPv6 and port', () {
      final base = ServerBase.parse('https://[::1]:8443/poznámky/');
      final uri = base.notesEndpoint(['notes', '42']);
      expect(uri.host, '::1');
      expect(uri.port, 8443);
      expect(uri.pathSegments, [
        'poznámky',
        'index.php',
        'apps',
        'notes',
        'api',
        'v1',
        'notes',
        '42',
      ]);
    });
    for (final input in [
      'http://cloud.test',
      'ftp://cloud.test',
      '/nextcloud',
      'https://user:secret@cloud.test',
      'https://cloud.test/?token=x',
      'https://cloud.test/#x',
      'https://cloud.test/a/%2f/b',
      'https://cloud.test/a/%5c/b',
      'https://cloud.test/a//b',
    ]) {
      test('rejects unsafe base $input', () {
        expect(() => ServerBase.parse(input), throwsFormatException);
      });
    }
    test('allows explicitly selected insecure development origin', () {
      expect(
        ServerBase.parse(
          'http://localhost:8080/nc',
          allowInsecureHttp: true,
        ).uri.scheme,
        'http',
      );
    });
  });

  group('wire records', () {
    test('ID-only cannot erase content', () {
      expect(parseNote({'id': 42}), isA<NoteIdOnly>());
    });
    test('empty content and false are real values', () {
      final note = parseNote({...fullNote(), 'content': ''}) as RemoteNote;
      expect(note.content, '');
      expect(note.favorite, false);
    });
    test('error body is discarded', () {
      final result = parseNote({
        'id': 42,
        'error': true,
        'content': 'SECRET DIAGNOSTIC',
      });
      expect(result, isA<UnreadableNote>());
      expect(result.toString(), isNot(contains('SECRET')));
    });
    test(
      'unexpected projection fails rather than defaulting missing fields',
      () {
        expect(
          () => parseNote({'id': 42, 'title': 'Test'}),
          throwsA(isA<NotesProtocolException>()),
        );
      },
    );
    test('64-bit identity is retained', () {
      expect(parseNote({'id': 9007199254740993}).id, 9007199254740993);
    });
    for (final id in [0, -1, 1.0, '42', null]) {
      test('rejects invalid id $id (${id.runtimeType})', () {
        expect(
          () => parseNote({'id': id}),
          throwsA(isA<NotesProtocolException>()),
        );
      });
    }
    for (final etag in ['', '"abc"', 'W/abc', 'abc\r\nx: y']) {
      test('rejects unsafe ETag ${etag.length}', () {
        expect(() => quoteEtag(etag), throwsA(isA<NotesProtocolException>()));
      });
    }
    test('quotes once', () => expect(quoteEtag('abc'), '"abc"'));
  });

  group('list', () {
    test('final census includes full and sparse records', () async {
      final api = client((request) async {
        expect(
          request.url.path,
          '/nextcloud/index.php/apps/notes/api/v1/notes',
        );
        expect(request.url.queryParameters, {
          'chunkSize': '1',
          'pruneBefore': '123',
        });
        return jsonResponse(
          [
            fullNote(),
            {'id': 73},
          ],
          headers: {
            'last-modified': 'Sun, 18 Oct 2026 12:00:00 GMT',
            'etag': '"list"',
          },
        );
      });
      final page = await api.list(chunkSize: 1, pruneBefore: 123);
      expect(page.finalIds, {42, 73});
      expect(page.lastModified, DateTime.utc(2026, 10, 18, 12));
    });
    test('intermediate page cannot authorize absence', () async {
      final page = await client(
        (_) async => jsonResponse(
          [fullNote()],
          headers: {'x-notes-chunk-cursor': 'opaque+/='},
        ),
      ).list();
      expect(page.isLastPage, false);
      expect(() => page.finalIds, throwsStateError);
    });
    test('cursor remains opaque', () async {
      await client((r) async {
        expect(r.url.queryParameters['chunkCursor'], 'opaque+/=');
        return jsonResponse([]);
      }).list(cursor: 'opaque+/=');
    });
    test('bad watermark is not replaced with device time', () async {
      final page = await client(
        (_) async => jsonResponse([], headers: {'last-modified': 'invalid'}),
      ).list();
      expect(page.lastModified, null);
    });
    test('duplicate identities fail the page', () async {
      await expectLater(
        client(
          (_) async => jsonResponse([
            {'id': 42},
            {'id': 42},
          ]),
        ).list(),
        throwsA(isA<NotesProtocolException>()),
      );
    });
    test('304 is never an empty list', () async {
      await expectLater(
        client((_) async => http.Response('', 304)).list(),
        throwsA(isA<NotesHttpException>()),
      );
    });
    test('HTML and malformed JSON cannot become an empty census', () async {
      for (final response in [
        http.Response('<html>secret</html>', 200),
        http.Response('{', 200, headers: {'content-type': 'application/json'}),
      ]) {
        await expectLater(
          client((_) async => response).list(),
          throwsA(isA<NotesProtocolException>()),
        );
      }
    });
  });

  group('detail and mutations', () {
    test('GET 304 has an explicit typed result', () async {
      final result = await client((r) async {
        expect(r.headers['If-None-Match'], '"abc123"');
        return http.Response('', 304);
      }).get(42, ifNoneMatch: 'abc123');
      expect(result, isA<NoteNotModified>());
    });
    test('unsolicited 304 is rejected', () async {
      await expectLater(
        client((_) async => http.Response('', 304)).get(42),
        throwsA(isA<NotesProtocolException>()),
      );
    });
    test('CREATE puts Unicode text in JSON, never URL', () async {
      final note = await client((r) async {
        expect(r.method, 'POST');
        expect(r.url.hasQuery, false);
        expect(jsonDecode(utf8.decode(r.bodyBytes)), {
          'content': 'Žluťoučký 📝',
          'title': 'Návrh',
          'category': '',
          'favorite': false,
        });
        expect(r.followRedirects, false);
        return jsonResponse(fullNote());
      }).create(content: 'Žluťoučký 📝', title: 'Návrh');
      expect(note.id, 42);
    });
    test('PUT sends only changed fields and quoted Notes ETag', () async {
      await client((r) async {
        expect(r.headers['If-Match'], '"abc123"');
        expect(jsonDecode(r.body), {'favorite': false});
        return jsonResponse(fullNote());
      }).update(42, etag: 'abc123', patch: NotePatch(favorite: false));
    });
    test('empty patch is rejected', () {
      expect(() => NotePatch(), throwsArgumentError);
    });
    test('412 returns a typed conflict without text in exception', () async {
      await expectLater(
        client((_) async => jsonResponse(fullNote(), status: 412)).update(
          42,
          etag: 'old',
          patch: NotePatch(content: 'new'),
        ),
        throwsA(
          isA<NoteConflict>()
              .having((e) => e.remote.id, 'id', 42)
              .having((e) => e.toString(), 'safe message', 'NoteConflict'),
        ),
      );
    });
    test(
      'error:true preserves identity without promoting error content',
      () async {
        final note = await client(
          (_) async => jsonResponse({
            'id': 42,
            'error': true,
            'content': 'server exception',
          }),
        ).create(content: 'draft', title: 'title');
        expect(note, isA<UnreadableNote>());
        expect(note.id, 42);
      },
    );
    test('unexpected PUT identity is uncertain', () async {
      await expectLater(
        client((_) async => jsonResponse(fullNote(id: 73))).update(
          42,
          etag: 'abc',
          patch: NotePatch(title: 'new'),
        ),
        throwsA(isA<MutationUncertain>()),
      );
    });
    test('lost CREATE response is not retried', () async {
      var calls = 0;
      final api = client((_) async {
        calls++;
        throw http.ClientException('private server response');
      });
      await expectLater(
        api.create(content: 'draft', title: 'title'),
        throwsA(isA<MutationUncertain>()),
      );
      expect(calls, 1);
    });
    test('timeout is uncertain without automatic replay', () async {
      var calls = 0;
      final completion = Completer<http.Response>();
      final api = client((_) {
        calls++;
        return completion.future;
      }, timeout: const Duration(milliseconds: 20));
      await expectLater(
        api.create(content: 'draft', title: 'title'),
        throwsA(isA<MutationUncertain>()),
      );
      completion.complete(jsonResponse(fullNote()));
      expect(calls, 1);
    });
    test('redirect is surfaced and cannot leak authentication', () async {
      await expectLater(
        client((r) async {
          expect(r.followRedirects, false);
          return http.Response(
            '',
            302,
            headers: {'location': 'https://other.invalid/'},
          );
        }).get(42),
        throwsA(
          isA<NotesHttpException>().having((e) => e.statusCode, 'status', 302),
        ),
      );
    });
    test('response size is bounded for reads and writes', () async {
      final api = client((_) async => jsonResponse(fullNote()), limit: 8);
      await expectLater(api.get(42), throwsA(isA<NotesProtocolException>()));
      await expectLater(
        api.create(content: 'draft', title: 'title'),
        throwsA(isA<MutationUncertain>()),
      );
    });
    test('403 mutation still may have partially applied', () async {
      await expectLater(
        client((_) async => jsonResponse({}, status: 403)).update(
          42,
          etag: 'abc',
          patch: NotePatch(content: 'new', category: 'other'),
        ),
        throwsA(
          isA<NotesHttpException>().having(
            (e) => e.mayHaveApplied,
            'mayHaveApplied',
            true,
          ),
        ),
      );
    });
    test('DELETE does not pretend to support If-Match', () async {
      await client((r) async {
        expect(r.method, 'DELETE');
        expect(r.headers.containsKey('If-Match'), false);
        return jsonResponse([]);
      }).delete(42);
    });
    test('invalid DELETE success must be reconciled', () async {
      await expectLater(
        client((_) async => jsonResponse({'ok': true})).delete(42),
        throwsA(isA<MutationUncertain>()),
      );
    });
  });

  group('attachment', () {
    test('reads an image by its Markdown path', () async {
      final api = client((r) async {
        expect(r.method, 'GET');
        expect(
          r.url.path,
          '/nextcloud/index.php/apps/notes/api/v1/attachment/7',
        );
        expect(r.url.queryParameters['path'], '.attachments.7/a b.png');
        return http.Response.bytes(
          [1, 2, 3],
          200,
          headers: {'content-type': 'image/png'},
        );
      });
      expect(await api.attachment(7, '.attachments.7/a b.png'), [1, 2, 3]);
    });

    test('refuses paths that leave the note folder and non-images', () async {
      final api = client(
        (r) async => http.Response(
          '<html>',
          200,
          headers: {'content-type': 'text/html'},
        ),
      );
      for (final path in [
        '../secret.png',
        '/etc/x.png',
        'https://evil.test/x.png',
        '.attachments.7//x.png',
      ]) {
        await expectLater(
          api.attachment(7, path),
          throwsA(isA<NotesProtocolException>()),
        );
      }
      await expectLater(
        api.attachment(7, '.attachments.7/x.png'),
        throwsA(
          isA<NotesProtocolException>().having(
            (e) => e.code,
            'code',
            'not_an_image',
          ),
        ),
      );
    });
  });
  test('checked-in wire fixtures are parsed through production decoder', () {
    final fixtures = Directory('../../contracts/notes/fixtures');
    for (final file in fixtures.listSync().whereType<File>()) {
      final value = jsonDecode(file.readAsStringSync());
      if (value is List<Object?>) {
        for (final item in value) {
          parseNote(item);
        }
      } else {
        parseNote(value);
      }
    }
  });
}
