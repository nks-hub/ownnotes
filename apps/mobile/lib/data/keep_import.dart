import 'dart:convert';

import 'package:archive/archive.dart';

/// One note converted from a Google Keep Takeout export.
final class KeepNote {
  const KeepNote({
    required this.title,
    required this.content,
    required this.category,
  });
  final String title;
  final String content;
  final String category;
}

/// Reads every `Keep/*.json` note from a Google Takeout zip; only those
/// entries are decompressed.
///
/// Trashed notes are skipped. Images and audio stay behind: attachments are
/// not uploaded by this client yet.
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
      final note = keepNoteFromJson(json);
      if (note != null) notes.add(note);
    }
  }
  return notes;
}

/// Converts one Takeout note; returns null for trashed or empty notes.
KeepNote? keepNoteFromJson(Map<String, Object?> json) {
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
  if (title.isEmpty && content.isEmpty) return null;
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
  );
}
