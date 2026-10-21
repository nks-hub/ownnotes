import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:test/test.dart';

AttachmentsClient client(
  Future<http.Response> Function(http.Request) handle, {
  AttachmentRoute route = AttachmentRoute.current,
  void Function(http.Request)? seen,
}) => AttachmentsClient(
  base: ServerBase.parse('https://cloud.test/sub'),
  transport: MockClient((r) {
    seen?.call(r);
    return handle(r);
  }),
  loginName: 'anna',
  appPassword: 'secret',
  route: route,
);

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Stream<List<int>> bytes(String s) => Stream.value(utf8.encode(s));

void main() {
  group('route by Notes version', () {
    test('6.0.x and unknown versions use v1.4 without delete', () {
      for (final v in ['6.0.2', '5.9.0', null, 'dev']) {
        final route = AttachmentRoute.forNotesVersion(v);
        expect(route.apiVersion, 'v1.4', reason: v);
        expect(route.canDelete, isFalse);
      }
    });
    test('6.1 and newer use v1 with delete', () {
      for (final v in ['6.1.0', '6.2.3', '7.0.0']) {
        final route = AttachmentRoute.forNotesVersion(v);
        expect(route.apiVersion, 'v1', reason: v);
        expect(route.canDelete, isTrue);
      }
    });
  });

  test('reads the Notes version from the capabilities', () async {
    late Uri url;
    final api = client((r) async {
      url = r.url;
      expect(r.headers['OCS-APIRequest'], 'true');
      return json({
        'ocs': {
          'data': {
            'version': {'string': '34.0.4'},
            'capabilities': {
              'notes': {'version': '6.1.0'},
            },
          },
        },
      });
    });
    expect(await api.notesVersion(), '6.1.0');
    expect(await api.versions(), (nextcloud: '34.0.4', notes: '6.1.0'));
    expect(url.path, '/sub/ocs/v2.php/cloud/capabilities');
    expect(
      await client(
        (r) async => json({'ocs': <String, Object>{}}),
      ).notesVersion(),
      isNull,
    );
  });

  test('uploads a multipart file field and returns the server path', () async {
    late http.Request seen;
    final api = client((r) async {
      seen = r;
      return json({'filename': '.attachments.42/photo (1).png'});
    }, route: AttachmentRoute.legacy);
    final up = await api.upload(
      42,
      fileName: 'photo.png',
      content: bytes('PNGDATA'),
      length: 7,
    );
    expect(up.path, '.attachments.42/photo (1).png');
    expect(seen.method, 'POST');
    expect(seen.url.path, '/sub/index.php/apps/notes/api/v1.4/attachment/42');
    expect(seen.headers['Authorization'], startsWith('Basic '));
    expect(seen.headers['content-type'], startsWith('multipart/form-data'));
    expect(seen.body, contains('name="file"'));
    expect(seen.body, contains('filename="photo.png"'));
    expect(seen.body, contains('PNGDATA'));
  });

  test('upload rejects names with separators and foreign folders', () async {
    final api = client((r) async => json({'filename': '.attachments.7/x.png'}));
    await expectLater(
      api.upload(42, fileName: '../x.png', content: bytes(''), length: 0),
      throwsA(isA<NotesProtocolException>()),
    );
    // The server answered with another note's folder: the write is uncertain.
    await expectLater(
      api.upload(42, fileName: 'x.png', content: bytes(''), length: 0),
      throwsA(isA<MutationUncertain>()),
    );
  });

  test('upload errors keep the status and say the write may have applied', () {
    final api = client((r) async => json({'message': 'big'}, 413));
    expect(
      api.upload(1, fileName: 'a.png', content: bytes(''), length: 0),
      throwsA(
        isA<NotesHttpException>()
            .having((e) => e.statusCode, 'status', 413)
            .having((e) => e.mayHaveApplied, 'mayHaveApplied', true),
      ),
    );
  });

  test('transport failure during upload is uncertain', () {
    final api = AttachmentsClient(
      base: ServerBase.parse('https://cloud.test'),
      transport: MockClient((_) async => throw Exception('down')),
      loginName: 'anna',
      appPassword: 'secret',
    );
    expect(
      api.upload(1, fileName: 'a.png', content: bytes(''), length: 0),
      throwsA(isA<MutationUncertain>()),
    );
  });

  test('delete needs Notes 6.1 and sends the relative path', () async {
    late http.Request seen;
    final api = client((r) async {
      seen = r;
      return json([]);
    });
    await api.delete(42, '.attachments.42/photo.png');
    expect(seen.method, 'DELETE');
    expect(seen.url.path, '/sub/index.php/apps/notes/api/v1/attachment/42');
    expect(seen.url.queryParameters['path'], '.attachments.42/photo.png');
    await expectLater(
      client(
        (r) async => json([]),
        route: AttachmentRoute.legacy,
      ).delete(42, '.attachments.42/photo.png'),
      throwsA(isA<NotesProtocolException>()),
    );
    await expectLater(
      api.delete(42, '../../etc/passwd'),
      throwsA(isA<NotesProtocolException>()),
    );
  });

  test('downloads any content type within the size limit', () async {
    final api = client(
      (r) async => http.Response.bytes(
        [1, 2, 3],
        200,
        headers: {'content-type': 'audio/mp4; charset=x'},
      ),
    );
    final file = await api.download(42, '.attachments.42/memo.m4a');
    expect(file.bytes, [1, 2, 3]);
    expect(file.contentType, 'audio/mp4');
    final small = AttachmentsClient(
      base: ServerBase.parse('https://cloud.test'),
      transport: MockClient((_) async => http.Response('12345', 200)),
      loginName: 'anna',
      appPassword: 'secret',
      maxDownloadBytes: 3,
    );
    await expectLater(
      small.download(1, '.attachments.1/a.bin'),
      throwsA(isA<NotesProtocolException>()),
    );
  });
}
