import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:notes_store/notes_store.dart';

/// A zip with one Markdown file per note, categories as folders, the same
/// layout the Notes server keeps. Duplicate names get " (2)", " (3)", ...
Uint8List exportNotes(Iterable<LocalNote> notes) {
  String clean(String name) =>
      name.replaceAll(RegExp(r'[*|/\\:"<>?]'), '').trim();
  final archive = Archive();
  final used = <String>{};
  for (final note in notes) {
    final title = clean(
      note.title.trim().isNotEmpty
          ? note.title
          : titleFromContent(note.content),
    );
    final folders = note.category
        .split('/')
        .map(clean)
        .where((s) => s.isNotEmpty && s != '.' && s != '..');
    final base = [...folders, title.isEmpty ? 'note' : title].join('/');
    var path = '$base.md';
    for (var i = 2; !used.add(path); i++) {
      path = '$base ($i).md';
    }
    archive.addFile(ArchiveFile.bytes(path, utf8.encode(note.content)));
  }
  return ZipEncoder().encodeBytes(archive);
}
