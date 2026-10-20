import '../note_rows.dart';

/// Sync-state filter of a search or saved view.
enum SyncFilter { waiting, decision }

enum SortMode { modified, title, favoritesFirst }

/// Local filters of the list: they combine with the scope and the query.
/// Value-comparable so a saved view and the current state can be compared.
class NoteFilters {
  const NoteFilters({
    this.favorites = false,
    this.unfinishedTasks = false,
    this.attachments = false,
    this.shared = false,
    this.sync,
  });

  static const none = NoteFilters();

  final bool favorites;
  final bool unfinishedTasks;
  final bool attachments;
  final bool shared;
  final SyncFilter? sync;

  bool get isEmpty =>
      !favorites && !unfinishedTasks && !attachments && !shared && sync == null;

  NoteFilters copyWith({
    bool? favorites,
    bool? unfinishedTasks,
    bool? attachments,
    bool? shared,
    SyncFilter? sync,
    bool clearSync = false,
  }) => NoteFilters(
    favorites: favorites ?? this.favorites,
    unfinishedTasks: unfinishedTasks ?? this.unfinishedTasks,
    attachments: attachments ?? this.attachments,
    shared: shared ?? this.shared,
    sync: clearSync ? null : sync ?? this.sync,
  );

  bool matches(NoteRow row) {
    if (favorites && !row.note.favorite) return false;
    if (unfinishedTasks && !row.hasOpenTasks) return false;
    if (attachments && !row.attachments) return false;
    if (shared && !row.isShared) return false;
    final state = row.note.syncState;
    return switch (sync) {
      null => true,
      SyncFilter.waiting => state == 'draft' || state == 'sending',
      SyncFilter.decision => state == 'needsDecision',
    };
  }

  Map<String, Object?> toJson() => {
    if (favorites) 'favorites': true,
    if (unfinishedTasks) 'tasks': true,
    if (attachments) 'attachments': true,
    if (shared) 'shared': true,
    if (sync != null) 'sync': sync!.name,
  };

  factory NoteFilters.fromJson(Map<String, Object?> json) => NoteFilters(
    favorites: json['favorites'] == true,
    unfinishedTasks: json['tasks'] == true,
    attachments: json['attachments'] == true,
    shared: json['shared'] == true,
    sync: SyncFilter.values.where((s) => s.name == json['sync']).firstOrNull,
  );

  @override
  bool operator ==(Object other) =>
      other is NoteFilters &&
      other.favorites == favorites &&
      other.unfinishedTasks == unfinishedTasks &&
      other.attachments == attachments &&
      other.shared == shared &&
      other.sync == sync;

  @override
  int get hashCode =>
      Object.hash(favorites, unfinishedTasks, attachments, shared, sync);
}

/// Rows of [rows] that pass the scope, the filters and the query, in the
/// order of [sort]. [untitled] stands in for notes without a title.
List<NoteRow> selectRows(
  Iterable<NoteRow> rows, {
  required NoteScope scope,
  String category = '',
  NoteFilters filters = NoteFilters.none,
  String query = '',
  SortMode sort = SortMode.modified,
  String untitled = '',
}) {
  final q = query.trim().toLowerCase();
  final out = [
    for (final r in rows)
      if (r.inScope(scope, category) &&
          filters.matches(r) &&
          (q.isEmpty || r.haystack.contains(q)))
        r,
  ];
  switch (sort) {
    case SortMode.modified:
      return out;
    case SortMode.title:
      final u = untitled.toLowerCase();
      final keys = {
        for (final r in out) r: r.title.isEmpty ? u : r.title.toLowerCase(),
      };
      out.sort((a, b) => keys[a]!.compareTo(keys[b]!));
      return out;
    case SortMode.favoritesFirst:
      // Stable: the modified order stays inside each group.
      return [
        ...out.where((r) => r.note.favorite),
        ...out.where((r) => !r.note.favorite),
      ];
  }
}
