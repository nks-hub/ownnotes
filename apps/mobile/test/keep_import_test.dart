import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextcloudnotes/data/keep_import.dart';

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
}
