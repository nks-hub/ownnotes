/// Errors intentionally omit remote bodies, titles and credentials.
final class NotesProtocolException implements Exception {
  const NotesProtocolException(this.code);
  final String code;
  @override
  String toString() => 'NotesProtocolException($code)';
}

sealed class NoteReadResult {
  const NoteReadResult();
}

final class NoteNotModified extends NoteReadResult {
  const NoteNotModified();
}

sealed class NoteRecord extends NoteReadResult {
  const NoteRecord(this.id);
  final int id;
}

final class NoteIdOnly extends NoteRecord {
  const NoteIdOnly(super.id);
}

/// Error text in the server's content field is deliberately discarded.
final class UnreadableNote extends NoteRecord {
  const UnreadableNote(super.id);
}

final class RemoteNote extends NoteRecord {
  const RemoteNote({
    required int id,
    required this.etag,
    required this.title,
    required this.content,
    required this.category,
    required this.favorite,
    required this.readonly,
    required this.modified,
    this.internalPath,
    this.isShared = false,
  }) : super(id);

  /// The file path in the account's files (`/Notes/Cat/Title.md`); what a
  /// share of the note needs.
  final String? internalPath;
  final bool isShared;
  final String etag;
  final String title;
  final String content;
  final String category;
  final bool favorite;
  final bool readonly;
  final int modified;
}

int noteId(Object? value) {
  if (value is! int || value <= 0 || value > 9223372036854775807) {
    throw const NotesProtocolException('invalid_note_id');
  }
  return value;
}

String quoteEtag(String value) {
  // Notes supplies an opaque, unquoted entity tag, not a header value.
  if (value.isEmpty ||
      value.runes.any((c) => c < 33 || c > 126 || c == 34) ||
      value.startsWith('W/')) {
    throw const NotesProtocolException('invalid_etag');
  }
  return '"$value"';
}

NoteRecord parseNote(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const NotesProtocolException('invalid_note_object');
  }
  final id = noteId(value['id']);
  if (value.length == 1) return NoteIdOnly(id);
  if (value['error'] == true) return UnreadableNote(id);
  if (value.containsKey('error') && value['error'] is! bool) {
    throw const NotesProtocolException('invalid_error_flag');
  }
  T field<T>(String key) {
    final field = value[key];
    if (field is! T) throw NotesProtocolException('invalid_$key');
    return field;
  }

  final etag = field<String>('etag');
  quoteEtag(etag);
  final modified = field<int>('modified');
  if (modified < 0) throw const NotesProtocolException('invalid_modified');
  return RemoteNote(
    id: id,
    etag: etag,
    title: field<String>('title'),
    content: field<String>('content'),
    category: field<String>('category'),
    favorite: field<bool>('favorite'),
    readonly: field<bool>('readonly'),
    modified: modified,
    internalPath: value['internalPath'] is String
        ? value['internalPath']! as String
        : null,
    isShared: value['isShared'] == true,
  );
}

/// Nullable constructor arguments mean omission; empty strings and false are
/// explicit changes. This type cannot accidentally serialize a full snapshot.
final class NotePatch {
  NotePatch({String? content, String? title, String? category, bool? favorite})
    : fields = Map.unmodifiable({
        'content': ?content,
        'title': ?title,
        'category': ?category,
        'favorite': ?favorite,
      }) {
    if (fields.isEmpty) throw ArgumentError('Empty note patch');
  }
  final Map<String, Object> fields;
}

sealed class NotesListResult {
  const NotesListResult();
}

final class NotesListNotModified extends NotesListResult {
  const NotesListNotModified();
}

/// One HTTP entity tag, including its quotes; lists may use weak validators.
bool isListEtag(String value) {
  final match = RegExp(r'(W/)?"[\x21\x23-\x7e]*"').matchAsPrefix(value);
  return match != null && match.end == value.length;
}

final class NotesPage extends NotesListResult {
  NotesPage({
    required List<NoteRecord> notes,
    required this.cursor,
    required this.lastModified,
    required this.etag,
  }) : notes = List.unmodifiable(notes);
  final List<NoteRecord> notes;
  final String? cursor;
  final DateTime? lastModified;
  final String? etag;
  bool get isLastPage => cursor == null;

  /// Membership is not deletion authority: the coordinator must still validate
  /// account, scope and overlapping mutations before committing this census.
  Set<int> get finalIds {
    if (!isLastPage) throw StateError('An intermediate page has no census');
    return Set.unmodifiable(notes.map((note) => note.id));
  }
}
