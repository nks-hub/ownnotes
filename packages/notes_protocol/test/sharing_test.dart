import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:test/test.dart';

http.Response ocs(Object? data, {int status = 200}) => http.Response(
  jsonEncode({
    'ocs': {
      'meta': {'statuscode': status},
      'data': data,
    },
  }),
  200,
  headers: {'content-type': 'application/json'},
);

SharingClient client(
  Future<http.Response> Function(http.Request) handle, {
  void Function(http.Request)? seen,
}) => SharingClient(
  base: ServerBase.parse('https://cloud.test/sub'),
  transport: MockClient((r) {
    seen?.call(r);
    return handle(r);
  }),
  loginName: 'anna',
  appPassword: 'secret',
);

const propfind =
    '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:" '
    'xmlns:oc="http://owncloud.org/ns"><d:response><d:propstat><d:prop>'
    '<d:getetag>&quot;abc123&quot;</d:getetag>'
    '<d:getlastmodified>Tue, 20 Oct 2026 19:42:26 GMT</d:getlastmodified>'
    '<oc:fileid>1480</oc:fileid><oc:permissions>SGDNVW</oc:permissions>'
    '</d:prop></d:propstat></d:response></d:multistatus>';

void main() {
  test('sharee search keeps users and drops the caller', () async {
    late http.Request sent;
    final api = client(
      (r) async => ocs({
        'exact': {'users': <Object?>[]},
        'users': [
          {
            'label': 'Bob',
            'value': {'shareType': 0, 'shareWith': 'bob'},
          },
          {
            'label': 'Anna',
            'value': {'shareType': 0, 'shareWith': 'anna'},
          },
        ],
        'groups': <Object?>[],
      }),
      seen: (r) => sent = r,
    );
    final found = await api.searchSharees('b');
    expect(found.map((s) => s.userId), ['bob']);
    expect(sent.url.path, '/sub/ocs/v2.php/apps/files_sharing/api/v1/sharees');
    expect(sent.headers['OCS-APIRequest'], 'true');
    expect(sent.url.queryParameters['itemType'], 'file');
  });

  test('share creation posts a user share with edit permission', () async {
    late http.Request sent;
    final api = client((r) async {
      sent = r;
      return ocs({
        'id': '5',
        'share_with': 'bob',
        'permissions': 3,
        'path': '/Notes/List.md',
      });
    });
    final share = await api.shareWithUser('/Notes/List.md', 'bob');
    expect(sent.method, 'POST');
    expect(sent.url.path, '/sub/ocs/v2.php/apps/files_sharing/api/v1/shares');
    expect(sent.bodyFields, {
      'path': '/Notes/List.md',
      'shareType': '0',
      'shareWith': 'bob',
      'permissions': '3',
    });
    expect(share.canEdit, isTrue);
    expect(share.id, '5');
  });

  test('an OCS failure inside a 200 response is an error', () async {
    final api = client((r) async => ocs([], status: 404));
    expect(
      api.shareWithUser('/Notes/x.md', 'bob'),
      throwsA(
        isA<NotesHttpException>().having((e) => e.statusCode, 'status', 404),
      ),
    );
  });

  test('shares of a file and unshare', () async {
    final seen = <String>[];
    final api = client((r) async {
      seen.add('${r.method} ${r.url.path}');
      return ocs(
        r.method == 'DELETE'
            ? []
            : [
                {
                  'id': 7,
                  'share_type': 0,
                  'share_with': 'bob',
                  'permissions': 1,
                  'path': '/Notes/List.md',
                },
                {
                  'id': 8,
                  'share_type': 3,
                  'share_with': null,
                  'permissions': 1,
                  'path': '/x',
                },
              ],
      );
    });
    final shares = await api.sharesOf('/Notes/List.md');
    expect(shares.single.canEdit, isFalse);
    await api.unshare('7');
    expect(
      seen.last,
      'DELETE /sub/ocs/v2.php/apps/files_sharing/api/v1/shares/7',
    );
    expect(() => api.unshare('../7'), throwsArgumentError);
  });

  test('shared with me lists files only', () async {
    final api = client(
      (r) async => ocs([
        {
          'id': '5',
          'share_type': 0,
          'item_type': 'file',
          'file_source': 1480,
          'file_target': '/share-probe.md',
          'uid_owner': 'ann',
          'displayname_owner': 'Ann',
          'permissions': 3,
        },
        {
          'id': '6',
          'share_type': 0,
          'item_type': 'folder',
          'file_source': 9,
          'file_target': '/Dir',
          'permissions': 31,
        },
      ]),
    );
    final incoming = (await api.sharedWithMe()).single;
    expect(incoming.fileId, 1480);
    expect(incoming.path, '/share-probe.md');
    expect(incoming.ownerName, 'Ann');
    expect(incoming.canEdit, isTrue);
  });

  test('stat reads etag, file id and write permission', () async {
    late http.Request sent;
    final api = client((r) async {
      sent = r;
      return http.Response(propfind, 207);
    }, seen: (r) => sent = r);
    final stat = await api.stat('/Kupní seznam.md');
    expect(sent.method, 'PROPFIND');
    expect(sent.headers['Depth'], '0');
    expect(
      sent.url.toString(),
      'https://cloud.test/sub/remote.php/dav/files/anna/'
      'Kupn%C3%AD%20seznam.md',
    );
    expect(stat.etag, 'abc123');
    expect(stat.fileId, 1480);
    expect(stat.writable, isTrue);
    expect(stat.modified, DateTime.utc(2026, 10, 20, 19, 42, 26));
  });

  test('read returns text and the DAV etag', () async {
    final api = client(
      (r) async => http.Response.bytes(
        utf8.encode('žluťoučký\n'),
        200,
        headers: {'etag': '"e1"'},
      ),
    );
    final file = await api.read('/a.md');
    expect(file.content, 'žluťoučký\n');
    expect(file.etag, 'e1');
  });

  test('write sends If-Match and returns the new etag', () async {
    late http.Request sent;
    final api = client((r) async {
      sent = r;
      return http.Response('', 204, headers: {'oc-etag': '"e2"'});
    });
    expect(await api.write('/a.md', 'text', etag: 'e1'), 'e2');
    expect(sent.method, 'PUT');
    expect(sent.headers['If-Match'], '"e1"');
    expect(sent.body, 'text');
  });

  test(
    'write maps 412 to a conflict and other failures to uncertain',
    () async {
      expect(
        client(
          (r) async => http.Response('', 412),
        ).write('/a.md', 't', etag: 'e1'),
        throwsA(isA<SharedConflict>()),
      );
      expect(
        client(
          (r) async => http.Response('', 423),
        ).write('/a.md', 't', etag: 'e1'),
        throwsA(
          isA<NotesHttpException>().having(
            (e) => e.mayHaveApplied,
            'applied',
            true,
          ),
        ),
      );
      expect(
        client(
          (r) async => throw http.ClientException('x'),
        ).write('/a.md', 't', etag: 'e1'),
        throwsA(isA<MutationUncertain>()),
      );
      expect(
        client((r) async => throw http.ClientException('x')).read('/a.md'),
        throwsA(isA<NotesTransportException>()),
      );
    },
  );

  test('move uses MOVE with an absolute Destination', () async {
    late http.Request sent;
    final api = client((r) async {
      sent = r;
      return http.Response('', 201);
    });
    await api.move('/a.md', '/Notes/a.md');
    expect(sent.method, 'MOVE');
    expect(
      sent.headers['Destination'],
      'https://cloud.test/sub/remote.php/dav/files/anna/Notes/a.md',
    );
  });

  test('paths cannot leave the files root', () async {
    final api = client((r) async => http.Response('', 200));
    expect(() => api.read('/../x'), throwsA(isA<NotesProtocolException>()));
    expect(() => api.read('x.md'), throwsA(isA<NotesProtocolException>()));
  });

  test('a note carries its path and shared flag', () {
    final note =
        parseNote({
              'id': 1,
              'etag': 'e',
              'title': 't',
              'content': '',
              'category': '',
              'favorite': false,
              'readonly': false,
              'modified': 1,
              'internalPath': '/Notes/t.md',
              'isShared': true,
            })
            as RemoteNote;
    expect(note.internalPath, '/Notes/t.md');
    expect(note.isShared, isTrue);
  });
}
