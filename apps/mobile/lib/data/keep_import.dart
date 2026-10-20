import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:notes_store/notes_store.dart';

import 'attachments/attachment_service.dart';

/// A picture or recording of a Keep note; [fileName] is the name of the file
/// next to the note's JSON in the Takeout zip.
final class KeepAttachment {
  const KeepAttachment({required this.fileName, required this.mime});
  final String fileName;
  final String mime;
}

/// One note converted from a Google Keep Takeout export.
final class KeepNote {
  const KeepNote({
    required this.title,
    required this.content,
    required this.category,
    this.attachments = const [],
    this.folder = '',
  });
  final String title;
  final String content;
  final String category;
  final List<KeepAttachment> attachments;

  /// Zip folder of the note's JSON, with a trailing slash; its attachments
  /// are files in that folder.
  final String folder;
}

/// Reads every `Keep/*.json` note from a Google Takeout zip; only those
/// entries are decompressed.
///
/// Trashed notes are skipped. Images and audio are listed in
/// [KeepNote.attachments]; [importKeepTakeout] turns them into attachments.
List<KeepNote> readKeepTakeout(Archive takeout) {
  final notes = <KeepNote>[];
  for (final file in takeout) {
    final path = file.name.replaceAll('\\', '/');
    if (!file.isFile ||
        !path.endsWith('.json') ||
        !path.split('/').contains('Keep')) {
      continue;
    }
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(file.content));
    } on FormatException {
      continue;
    }
    if (json is Map<String, Object?>) {
      final slash = path.lastIndexOf('/');
      final note = keepNoteFromJson(
        json,
        folder: slash < 0 ? '' : path.substring(0, slash + 1),
      );
      if (note != null) notes.add(note);
    }
  }
  return notes;
}

/// Converts one Takeout note; returns null for trashed or empty notes. A note
/// with only a picture or recording is not empty.
KeepNote? keepNoteFromJson(Map<String, Object?> json, {String folder = ''}) {
  if (json['isTrashed'] == true) return null;
  final title = json['title'] is String ? json['title'] as String : '';
  final text = json['textContent'] is String
      ? json['textContent'] as String
      : '';
  final list = json['listContent'] is List
      ? (json['listContent'] as List)
            .whereType<Map<String, Object?>>()
            .map(
              (item) =>
                  '- [${item['isChecked'] == true ? 'x' : ' '}] '
                  '${item['text'] is String ? item['text'] : ''}',
            )
            .join('\n')
      : '';
  final content = [text, list].where((part) => part.isNotEmpty).join('\n\n');
  final attachments = json['attachments'] is List
      ? [
          for (final a in (json['attachments'] as List).whereType<Map>())
            if (a['filePath'] is String && (a['filePath'] as String).isNotEmpty)
              KeepAttachment(
                fileName: a['filePath'] as String,
                mime: a['mimetype'] is String
                    ? a['mimetype'] as String
                    : 'application/octet-stream',
              ),
        ]
      : const <KeepAttachment>[];
  if (title.isEmpty && content.isEmpty && attachments.isEmpty) return null;
  final labels = json['labels'] is List
      ? (json['labels'] as List)
            .whereType<Map<String, Object?>>()
            .map((label) => label['name'])
            .whereType<String>()
      : const <String>[];
  return KeepNote(
    title: title,
    content: content,
    // Notes has one category per note; Keep may have several labels.
    category: labels.firstOrNull ?? '',
    attachments: attachments,
    folder: folder,
  );
}

/// What a Keep import produced.
final class KeepImportResult {
  const KeepImportResult({
    required this.notes,
    required this.attachments,
    required this.skippedAttachments,
  });
  final int notes;

  /// Files copied into attachment staging, to upload once their notes exist
  /// on the server.
  final int attachments;

  /// Files a note names that are missing from the zip or could not be read.
  final int skippedAttachments;
}

/// Imports a Takeout zip into [accountId]: one draft per note, and every
/// picture or recording staged as an attachment of its draft. The zip is read
/// one file at a time.
Future<KeepImportResult> importKeepTakeout({
  required String zipPath,
  required NotesDatabase database,
  required AttachmentService attachments,
  required String accountId,
  String Function(String title, String content)? titleFor,
}) async {
  final input = InputFileStream(zipPath);
  try {
    final archive = ZipDecoder().decodeStream(input);
    final notes = readKeepTakeout(archive);
    if (notes.isEmpty) throw const FormatException('no_keep_notes');
    final entries = <String, ArchiveFile>{
      for (final f in archive)
        if (f.isFile) f.name.replaceAll('\\', '/'): f,
    };
    var staged = 0;
    var skipped = 0;
    for (final note in notes) {
      final id = await database.createDraft(
        accountId,
        title: titleFor != null
            ? titleFor(note.title, note.content)
            : note.title.trim().isNotEmpty
            ? note.title
            : titleFromContent(note.content),
        content: note.content,
        category: note.category,
      );
      for (final a in note.attachments) {
        final entry = _findEntry(entries, note.folder, a.fileName);
        if (entry == null) {
          skipped++;
          continue;
        }
        final tmp = await Directory.systemTemp.createTemp('keep');
        try {
          final file = File('${tmp.path}/data');
          await file.writeAsBytes(entry.content, flush: true);
          await attachments.stage(
            accountId: accountId,
            noteId: id,
            source: file,
            name: a.fileName,
            mime: a.mime,
          );
          staged++;
        } on Object {
          skipped++;
        } finally {
          await tmp.delete(recursive: true);
        }
      }
    }
    return KeepImportResult(
      notes: notes.length,
      attachments: staged,
      skippedAttachments: skipped,
    );
  } finally {
    await input.close();
  }
}

/// Keep names a picture `x.jpg` in the JSON but sometimes ships `x.jpeg`;
/// fall back to the same name without its extension.
ArchiveFile? _findEntry(
  Map<String, ArchiveFile> entries,
  String folder,
  String fileName,
) {
  final exact = entries['$folder$fileName'];
  if (exact != null) return exact;
  final dot = fileName.lastIndexOf('.');
  final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
  for (final e in entries.entries) {
    if (!e.key.startsWith('$folder$stem.')) continue;
    final rest = e.key.substring(folder.length + stem.length + 1);
    if (!rest.contains('/') && rest != 'json') return e.value;
  }
  return null;
}
