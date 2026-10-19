import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextcloudnotes/data/export.dart';
import 'package:notes_store/notes_store.dart';

LocalNote note(String title, String content, [String category = '']) =>
    LocalNote(
      id: title + content,
      accountId: 'a',
      title: title,
      content: content,
      category: category,
      favorite: false,
      readonly: false,
      revision: 1,
      syncState: 'clean',
      updatedAt: 0,
    );

void main() {
  test('notes become Markdown files in category folders', () {
    final zip = ZipDecoder().decodeBytes(
      exportNotes([
        note('Shopping', '- [ ] milk', 'Home/Lists'),
        note('Shopping', 'second', 'Home/Lists'),
        note('', '# From text\nbody'),
        note('a/b: c?', 'x', '../evil'),
      ]),
    );
    expect(zip.files.map((f) => f.name), [
      'Home/Lists/Shopping.md',
      'Home/Lists/Shopping (2).md',
      'From text.md',
      'evil/ab c.md',
    ]);
    expect(utf8.decode(zip.files.first.content), '- [ ] milk');
  });
}
