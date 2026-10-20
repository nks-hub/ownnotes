import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:notes_protocol/notes_protocol.dart';
import 'package:test/test.dart';

/// Runs against a real Notes server only when OWNNOTES_LIVE_URL/USER/PASSWORD
/// are set. Creates one note, attaches files to it and deletes it again.
void main() {
  final env = Platform.environment;
  final url = env['OWNNOTES_LIVE_URL'];
  final user = env['OWNNOTES_LIVE_USER'];
  final password = env['OWNNOTES_LIVE_PASSWORD'];
  final skip = url == null || user == null || password == null
      ? 'OWNNOTES_LIVE_URL/USER/PASSWORD not set'
      : null;

  test('upload, download, delete with the route of the server', () async {
    final transport = http.Client();
    addTearDown(transport.close);
    final base = ServerBase.parse(url!);
    final notes = NotesClient(
      base: base,
      transport: transport,
      loginName: user!,
      appPassword: password!,
    );
    AttachmentsClient attachments(AttachmentRoute route) => AttachmentsClient(
      base: base,
      transport: transport,
      loginName: user,
      appPassword: password,
      route: route,
    );
    final version = await attachments(AttachmentRoute.legacy).notesVersion();
    final route = AttachmentRoute.forNotesVersion(version);
    // ignore: avoid_print
    print('Notes $version -> ${route.apiVersion}, delete ${route.canDelete}');
    final api = attachments(route);

    final note =
        await notes.create(
              content: 'attachment test',
              title: 'ownnotes-att-${DateTime.now().microsecondsSinceEpoch}',
            )
            as RemoteNote;
    addTearDown(() => notes.delete(note.id));

    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    final image = await api.upload(
      note.id,
      fileName: 'pixel ü.png',
      content: Stream.value(png),
      length: png.length,
    );
    expect(image.path, startsWith('.attachments.${note.id}/'));
    expect(image.path, endsWith('.png'));

    final text = utf8.encode('voice memo stand-in');
    final file = await api.upload(
      note.id,
      fileName: 'memo.m4a',
      content: Stream.value(text),
      length: text.length,
    );
    expect(file.path, startsWith('.attachments.${note.id}/'));

    // The same name again is renamed by the server, not overwritten.
    final again = await api.upload(
      note.id,
      fileName: 'memo.m4a',
      content: Stream.value(text),
      length: text.length,
    );
    expect(again.path, isNot(file.path));

    final got = await api.download(note.id, image.path);
    expect(got.bytes, png);
    expect((await api.download(note.id, file.path)).bytes, text);

    if (route.canDelete) {
      await api.delete(note.id, image.path);
      await expectLater(
        api.download(note.id, image.path),
        throwsA(
          isA<NotesHttpException>().having((e) => e.statusCode, 's', 404),
        ),
      );
    }
  }, skip: skip);
}
