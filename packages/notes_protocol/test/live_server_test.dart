import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:notes_protocol/notes_protocol.dart';
import 'package:test/test.dart';

/// Runs against a real Nextcloud Notes server only when all three variables
/// are set. Use a dedicated account: the test creates and deletes notes.
void main() {
  final env = Platform.environment;
  final url = env['OWNNOTES_LIVE_URL'];
  final user = env['OWNNOTES_LIVE_USER'];
  final password = env['OWNNOTES_LIVE_PASSWORD'];
  final skip = url == null || user == null || password == null
      ? 'OWNNOTES_LIVE_URL/USER/PASSWORD not set'
      : null;

  late http.Client transport;
  late NotesClient api;
  final created = <int>{};

  setUp(() {
    transport = http.Client();
    api = NotesClient(
      base: ServerBase.parse(url!),
      transport: transport,
      loginName: user!,
      appPassword: password!,
    );
  });

  tearDown(() async {
    for (final id in created) {
      try {
        await api.delete(id);
      } on NotesHttpException {
        /* Already removed by the test. */
      }
    }
    created.clear();
    transport.close();
  });

  test(
    'create, read, conditional read, update, conflict, page, delete',
    () async {
      final title = 'ownnotes-live-${DateTime.now().microsecondsSinceEpoch}';
      const content =
          '# Živý test\n\n- [ ] úkol ✓\n\n```dart\nmain() {}\n```\n';
      final note =
          await api.create(content: content, title: title) as RemoteNote;
      created.add(note.id);
      expect(note.content, content);
      expect(note.readonly, isFalse);

      final read = await api.get(note.id) as RemoteNote;
      expect(read.etag, note.etag);
      expect(read.content, content);
      expect(
        await api.get(note.id, ifNoneMatch: note.etag),
        isA<NoteNotModified>(),
      );

      final updated =
          await api.update(
                note.id,
                etag: note.etag,
                patch: NotePatch(
                  content: '$content\nDruhá verze.',
                  favorite: true,
                ),
              )
              as RemoteNote;
      expect(updated.etag, isNot(note.etag));
      expect(updated.favorite, isTrue);
      expect(updated.content, endsWith('Druhá verze.'));

      await expectLater(
        api.update(
          note.id,
          etag: note.etag,
          patch: NotePatch(content: 'stale'),
        ),
        throwsA(
          isA<NoteConflict>().having(
            (c) => (c.remote as RemoteNote).etag,
            'remote etag',
            updated.etag,
          ),
        ),
      );

      final ids = <int>{};
      String? cursor;
      NotesPage page;
      do {
        page = await api.list(chunkSize: 1, cursor: cursor);
        ids.addAll(page.notes.map((n) => n.id));
        cursor = page.cursor;
      } while (!page.isLastPage);
      expect(ids, contains(note.id));

      await api.delete(note.id);
      created.remove(note.id);
      await expectLater(
        api.get(note.id),
        throwsA(
          isA<NotesHttpException>().having((e) => e.statusCode, 'status', 404),
        ),
      );
    },
    skip: skip,
  );

  test('pruneBefore lists unchanged notes as id only', () async {
    final first = await api.list();
    final since = first.lastModified!.millisecondsSinceEpoch ~/ 1000;
    // lastUpdate has second resolution; a change must land after `since`.
    await Future<void>.delayed(const Duration(seconds: 2));
    final note =
        await api.create(
              content: 'pruned',
              title: 'ownnotes-prune-${DateTime.now().microsecondsSinceEpoch}',
            )
            as RemoteNote;
    created.add(note.id);
    final later = await api.list(pruneBefore: since);
    expect(later.notes.whereType<RemoteNote>().map((n) => n.id), [note.id]);
    expect(
      later.notes.whereType<NoteIdOnly>().map((n) => n.id).toSet(),
      first.notes.map((n) => n.id).toSet(),
    );
  }, skip: skip);

  test('the server cleans titles and categories', () async {
    final note =
        await api.create(
              content: 'x',
              title: 'a: b? ${DateTime.now().microsecondsSinceEpoch}',
              category: 'Work//Sub/',
            )
            as RemoteNote;
    created.add(note.id);
    expect(note.title, startsWith('a b '));
    expect(note.category, 'Work/Sub');
  }, skip: skip);

  test('wrong password is rejected without a body leak', () async {
    final bad = NotesClient(
      base: ServerBase.parse(url!),
      transport: transport,
      loginName: user!,
      appPassword: 'definitely-wrong',
    );
    await expectLater(
      bad.list(),
      throwsA(
        isA<NotesHttpException>().having((e) => e.statusCode, 'status', 401),
      ),
    );
  }, skip: skip);
}
