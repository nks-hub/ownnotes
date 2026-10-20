import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_store/notes_store.dart';
import 'package:nextcloudnotes/data/keep_import.dart';

import 'support/transfer_fixtures.dart';

void main() {
  test('text, checklist, label and trash are converted', () {
    final text = keepNoteFromJson({
      'title': 'Nákup',
      'textContent': 'Na víkend',
      'listContent': [
        {'text': 'mléko', 'isChecked': false},
        {'text': 'chleba', 'isChecked': true},
      ],
      'labels': [
        {'name': 'Domov'},
        {'name': 'Druhý'},
      ],
    })!;
    expect(text.title, 'Nákup');
    expect(text.content, 'Na víkend\n\n- [ ] mléko\n- [x] chleba');
    expect(text.category, 'Domov');
    expect(keepNoteFromJson({'title': 'x', 'isTrashed': true}), isNull);
    expect(keepNoteFromJson({'title': '', 'textContent': ''}), isNull);
  });

  test('a Takeout zip yields only Keep notes', () {
    List<int> bytes(Object value) => utf8.encode(jsonEncode(value));
    final archive = Archive()
      ..addFile(
        ArchiveFile.bytes(
          'Takeout/Keep/a.json',
          bytes({'title': 'A', 'textContent': 'one'}),
        ),
      )
      ..addFile(
        ArchiveFile.bytes('Takeout/Keep/b.json', bytes({'textContent': 'two'})),
      )
      ..addFile(ArchiveFile.bytes('Takeout/Keep/broken.json', [0x7b]))
      ..addFile(
        ArchiveFile.bytes('Takeout/Drive/c.json', bytes({'title': 'C'})),
      );
    final notes = readKeepTakeout(
      ZipDecoder().decodeBytes(ZipEncoder().encode(archive)),
    );
    expect(notes.map((n) => n.content), ['one', 'two']);
  });
  test('a note with only a picture is kept and lists its files', () {
    final note = keepNoteFromJson({
      'title': '',
      'textContent': '',
      'attachments': [
        {'filePath': 'a.jpg', 'mimetype': 'image/jpeg'},
        {'filePath': 'v.3gp', 'mimetype': 'audio/3gpp'},
      ],
    }, folder: 'Takeout/Keep/')!;
    expect(note.attachments.map((a) => a.fileName), ['a.jpg', 'v.3gp']);
    expect(note.folder, 'Takeout/Keep/');
  });

  test(
    'images and audio become staged attachments of the imported drafts',
    () async {
      List<int> json(Object value) => utf8.encode(jsonEncode(value));
      final archive = Archive()
        ..addFile(
          ArchiveFile.bytes(
            'Takeout/Keep/a.json',
            json({
              'title': 'Foto',
              'textContent': 'dole',
              'attachments': [
                {'filePath': 'img.jpg', 'mimetype': 'image/jpeg'},
                {'filePath': 'gone.png', 'mimetype': 'image/png'},
              ],
            }),
          ),
        )
        ..addFile(ArchiveFile.bytes('Takeout/Keep/img.jpeg', [1, 2, 3]))
        ..addFile(
          ArchiveFile.bytes(
            'Takeout/Keep/b.json',
            json({
              'title': '',
              'textContent': '',
              'attachments': [
                {'filePath': 'rec.3gp', 'mimetype': 'audio/3gpp'},
              ],
            }),
          ),
        )
        ..addFile(ArchiveFile.bytes('Takeout/Keep/rec.3gp', [9, 9]));
      final env = await TransferEnv.create();
      addTearDown(env.dispose);
      final zip = File('${env.dir.path}/takeout.zip')
        ..writeAsBytesSync(ZipEncoder().encode(archive));

      final result = await importKeepTakeout(
        zipPath: zip.path,
        database: env.db,
        attachments: env.service,
        accountId: env.accountId,
      );
      expect(result.notes, 2);
      expect(result.attachments, 2);
      expect(result.skippedAttachments, 1);

      final notes = await env.db.select(env.db.localNotes).get();
      final withText = notes.firstWhere((n) => n.title == 'Foto');
      final staged = await env.service.pending(env.accountId, withText.id);
      expect(staged.single.name, 'img.jpg');
      expect(staged.single.mime, 'image/jpeg');
      expect(
        await env.service.staging.dataFile(staged.single.id).readAsBytes(),
        [1, 2, 3],
      );
      final onlyAudio = notes.firstWhere((n) => n.id != withText.id);
      expect(
        (await env.service.pending(env.accountId, onlyAudio.id)).single.mime,
        'audio/3gpp',
      );

      // Once the drafts have server ids the references land in the notes.
      for (final n in notes) {
        await (env.db.update(
          env.db.localNotes,
        )..where((t) => t.id.equals(n.id))).write(
          LocalNotesCompanion(remoteId: Value(n.id == withText.id ? 42 : 43)),
        );
      }
      expect(await env.service.flush(env.accountId), 2);
      expect(
        (await env.db.note(env.accountId, withText.id))!.content,
        'dole\n\n![img.jpg](.attachments.42/img.jpg)',
      );
    },
  );
}
