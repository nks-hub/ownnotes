import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:test/test.dart';

const dav = '/sub/remote.php/dav/files/user';
String entry(
  String path,
  int id, {
  bool folder = false,
  bool writable = false,
}) =>
    '<d:response><d:href>$dav${Uri(pathSegments: path.split('/')).toString()}</d:href>'
    '<d:propstat><d:prop><d:resourcetype>${folder ? '<d:collection/>' : ''}</d:resourcetype>'
    '<oc:fileid>$id</oc:fileid><oc:permissions>G${writable ? 'W' : ''}</oc:permissions>'
    '</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>';
String listing(List<String> rows) =>
    '<d:multistatus xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns">${rows.join()}</d:multistatus>';
http.Response response(String xml) =>
    http.Response(xml, 207, headers: {'content-type': 'application/xml'});
IncomingShare share(int id, String path, {bool folder = false}) =>
    IncomingShare(
      id: '$id',
      fileId: id,
      path: path,
      ownerId: 'owner',
      ownerName: 'Owner',
      permissions: 31,
      isFolder: folder,
    );
SharingClient client(Future<http.Response> Function(http.Request) handler) =>
    SharingClient(
      base: ServerBase.parse('https://cloud.test/sub'),
      transport: MockClient(handler),
      loginName: 'user',
      appPassword: 'secret',
    );
Future<void> renew() async {}

void main() {
  test(
    'walks nested folders, decodes names and uses each file permission',
    () async {
      final requests = <String>[];
      final api = client((r) async {
        requests.add(r.url.path);
        expect(r.method, 'PROPFIND');
        expect(r.headers['Depth'], '1');
        if (r.url.path == '$dav/Shared') {
          return response(
            listing([
              entry('/Shared/', 40, folder: true),
              entry('/Shared/Root.md', 41),
              entry('/Shared/Sub/', 42, folder: true),
              entry('/Shared/photo.jpg', 43),
              entry('/Shared/.attachments.41/', 44, folder: true),
            ]),
          );
        }
        expect(r.url.path, '$dav/Shared/Sub');
        return response(
          listing([
            entry('/Shared/Sub/', 42, folder: true),
            entry('/Shared/Sub/Část 1.TXT', 45, writable: true),
          ]),
        );
      });
      final notes = await api.discoverSharedNotes([
        share(40, '/Shared', folder: true),
      ], beforeRequest: renew);
      expect(notes.map((n) => n.fileId), [41, 45]);
      expect(notes.first.writable, isFalse);
      expect(notes.last.writable, isTrue);
      expect(notes.last.path, '/Shared/Sub/Část 1.TXT');
      expect(requests, hasLength(2));
    },
  );

  test(
    'overlapping direct and folder shares choose a writable path once',
    () async {
      final api = client((r) async {
        if (r.headers['Depth'] == '0') {
          expect(r.url.path, '$dav/Direct.md');
          return response(listing([entry('/Direct.md', 41, writable: true)]));
        }
        return response(
          listing([
            entry('/Shared/', 40, folder: true),
            entry('/Shared/Note.md', 41),
          ]),
        );
      });
      final notes = await api.discoverSharedNotes([
        share(41, '/Direct.md'),
        share(40, '/Shared', folder: true),
        share(41, '/Direct.md'),
      ], beforeRequest: renew);
      expect(notes, hasLength(1));
      expect(notes.single.path, '/Direct.md');
      expect(notes.single.writable, isTrue);
    },
  );

  test(
    'known REST IDs do not become DAV notes or trigger direct metadata reads',
    () async {
      final api = client((r) async {
        expect(r.headers['Depth'], '1');
        return response(
          listing([
            entry('/Shared/', 40, folder: true),
            entry('/Shared/Note.md', 41),
          ]),
        );
      });
      expect(
        await api.discoverSharedNotes(
          [share(41, '/Direct.md'), share(40, '/Shared', folder: true)],
          notesApiIds: {41},
          beforeRequest: renew,
        ),
        isEmpty,
      );
    },
  );

  for (final href in [
    'https://other.test$dav/Shared/file.md',
    'http://cloud.test$dav/Shared/file.md',
    '$dav/Other/file.md',
    '$dav/SharedOther/file.md',
    '/sub/remote.php/dav/files/another/Shared/file.md',
    '$dav/Shared/%2e%2e/file.md',
    '$dav/Shared/%2foutside.md',
    '$dav/Shared/file.md?token=unexpected',
    '$dav/Shared/file.md#fragment',
    '$dav/Shared/Sub/deep.md',
    'file.md',
    '$dav/Shared/bad%zz.md',
  ]) {
    test('rejects an unrelated or ambiguous href: $href', () async {
      var requests = 0;
      final api = client((_) async {
        requests++;
        final bad = entry(
          '/Shared/file.md',
          41,
        ).replaceFirst('$dav/Shared/file.md', href);
        return response(listing([entry('/Shared/', 40, folder: true), bad]));
      });
      await expectLater(
        api.discoverSharedNotes([
          share(40, '/Shared', folder: true),
        ], beforeRequest: renew),
        throwsA(isA<NotesProtocolException>()),
      );
      expect(requests, 1);
    });
  }

  test(
    'accepts an absolute href only on the same endpoint and origin',
    () async {
      final api = client(
        (_) async => response(
          listing([
            entry('/Shared/', 40, folder: true),
            entry(
              '/Shared/a%20b.md',
              41,
            ).replaceFirst('<d:href>', '<d:href>https://cloud.test'),
          ]),
        ),
      );
      final notes = await api.discoverSharedNotes([
        share(40, '/Shared', folder: true),
      ], beforeRequest: renew);
      expect(notes.single.path, '/Shared/a%20b.md');
    },
  );

  for (final body in [
    listing([entry('/Shared/file.md', 41)]),
    listing([entry('/Shared/', 99, folder: true)]),
    listing([
      entry('/Shared/', 40, folder: true),
      '<d:response><d:href>$dav/Shared/lost.md</d:href><d:status>HTTP/1.1 403 Forbidden</d:status></d:response>',
    ]),
    listing([
      entry('/Shared/', 40, folder: true),
      entry('/Shared/file.md', 41).replaceAll('oc:fileid', 'd:fileid'),
    ]),
    listing([
      entry('/Shared/', 40, folder: true),
      entry(
        '/Shared/file.md',
        41,
      ).replaceAll('HTTP/1.1 200 OK', 'HTTP/1.1 404 Not Found'),
    ]),
    '<!DOCTYPE d:multistatus [<!ENTITY value "ignored">]>${listing([entry('/Shared/', 40, folder: true)])}',
  ]) {
    test(
      'an incomplete or unsafe multistatus never returns a partial list ${body.hashCode}',
      () async {
        final api = client((_) async => response(body));
        await expectLater(
          api.discoverSharedNotes([
            share(40, '/Shared', folder: true),
          ], beforeRequest: renew),
          throwsA(isA<NotesProtocolException>()),
        );
      },
    );
  }

  test(
    'folder count, depth, byte and entry limits fail without a partial result',
    () async {
      final api = client(
        (_) async => response(
          listing([
            entry('/Shared/', 40, folder: true),
            entry('/Shared/Sub/', 42, folder: true),
            entry('/Shared/Note.md', 41),
          ]),
        ),
      );
      final roots = [share(40, '/Shared', folder: true)];
      for (final request in [
        () =>
            api.discoverSharedNotes(roots, beforeRequest: renew, maxFolders: 1),
        () => api.discoverSharedNotes(roots, beforeRequest: renew, maxDepth: 0),
        () =>
            api.discoverSharedNotes(roots, beforeRequest: renew, maxEntries: 1),
        () =>
            api.discoverSharedNotes(roots, beforeRequest: renew, maxBytes: 20),
        () => api.discoverSharedNotes(
          roots,
          beforeRequest: renew,
          maxRequests: 1,
        ),
      ]) {
        await expectLater(
          request(),
          throwsA(
            isA<NotesProtocolException>().having(
              (e) => e.code,
              'code',
              'shared_folder_limit',
            ),
          ),
        );
      }
    },
  );

  test('folder IDs cannot cycle through longer paths', () async {
    var requests = 0;
    final api = client((_) async {
      requests++;
      return response(
        listing([
          entry('/Shared/', 40, folder: true),
          entry('/Shared/Loop/', 40, folder: true),
        ]),
      );
    });
    await expectLater(
      api.discoverSharedNotes([
        share(40, '/Shared', folder: true),
      ], beforeRequest: renew),
      throwsA(
        isA<NotesProtocolException>().having(
          (e) => e.code,
          'code',
          'cyclic_shared_folder',
        ),
      ),
    );
    expect(requests, 1);
  });
}
