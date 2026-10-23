/// Data types shared by the Android and iOS widgets (spec section 9.1):
/// per-instance configuration, the snapshot a widget renders, and the
/// command a widget sends back. Plain JSON in both directions, no Flutter
/// or platform imports.
library;

import 'dart:convert';

const widgetSchema = 1;

enum WidgetType { notesList, singleNote, checklist, quickNote }

enum WidgetScope { all, favorites, uncategorised, category }

enum WidgetAppearance { system, light, dark }

/// Which notes a list widget shows.
final class WidgetCollection {
  const WidgetCollection(this.scope, [this.category = '']);
  final WidgetScope scope;

  /// Category path (`A/B`) when [scope] is [WidgetScope.category].
  final String category;

  Map<String, Object?> toJson() => {
    'scope': scope.name,
    if (scope == WidgetScope.category) 'category': category,
  };

  factory WidgetCollection.fromJson(Map<String, Object?> json) =>
      WidgetCollection(
        _enum(WidgetScope.values, json['scope']) ?? WidgetScope.all,
        json['category'] as String? ?? '',
      );
}

/// Configuration of one widget instance. It belongs to the instance: changing
/// the app's selected account never retargets a widget. A widget without a
/// reliable [accountId] shows "Configure widget".
final class WidgetConfig {
  const WidgetConfig({
    required this.instanceId,
    required this.type,
    this.accountId,
    this.collection,
    this.noteId,
    this.appearance = WidgetAppearance.system,
  });

  /// Platform identity of the instance (Android appWidgetId, iOS widget
  /// configuration identifier).
  final String instanceId;
  final WidgetType type;
  final String? accountId;
  final WidgetCollection? collection;
  final String? noteId;
  final WidgetAppearance appearance;

  /// Account and, where the type needs one, the collection or note are set.
  bool get isConfigured =>
      accountId != null &&
      accountId!.isNotEmpty &&
      switch (type) {
        WidgetType.notesList => collection != null,
        WidgetType.singleNote || WidgetType.checklist => noteId != null,
        WidgetType.quickNote => true,
      };

  /// The same instance after its account was removed: type and appearance
  /// stay, everything that pointed at the account goes.
  WidgetConfig withoutAccount() =>
      WidgetConfig(instanceId: instanceId, type: type, appearance: appearance);

  Map<String, Object?> toJson() => {
    'schema': widgetSchema,
    'instanceId': instanceId,
    'type': type.name,
    'accountId': ?accountId,
    if (collection != null) 'collection': collection!.toJson(),
    'noteId': ?noteId,
    'appearance': appearance.name,
  };

  factory WidgetConfig.fromJson(Map<String, Object?> json) => WidgetConfig(
    instanceId: json['instanceId']! as String,
    type: _enum(WidgetType.values, json['type']) ?? WidgetType.notesList,
    accountId: json['accountId'] as String?,
    collection: json['collection'] is Map
        ? WidgetCollection.fromJson(
            Map<String, Object?>.from(json['collection']! as Map),
          )
        : null,
    noteId: json['noteId'] as String?,
    appearance:
        _enum(WidgetAppearance.values, json['appearance']) ??
        WidgetAppearance.system,
  );

  String encode() => jsonEncode(toJson());
  factory WidgetConfig.decode(String source) => WidgetConfig.fromJson(
    Map<String, Object?>.from(jsonDecode(source) as Map),
  );
}

/// A task identified by its text and which repeat of that text it is, never by
/// position alone: "milk" twice are `(milk, 0)` and `(milk, 1)`.
final class WidgetTaskKey {
  const WidgetTaskKey(this.label, this.occurrence);
  final String label;
  final int occurrence;

  Map<String, Object?> toJson() => {'label': label, 'occurrence': occurrence};

  factory WidgetTaskKey.fromJson(Map<String, Object?> json) => WidgetTaskKey(
    json['label']! as String,
    (json['occurrence'] as num?)?.toInt() ?? 0,
  );

  @override
  bool operator ==(Object other) =>
      other is WidgetTaskKey &&
      other.label == label &&
      other.occurrence == occurrence;

  @override
  int get hashCode => Object.hash(label, occurrence);
}

final class WidgetTaskEntry {
  const WidgetTaskEntry(this.key, this.checked);
  final WidgetTaskKey key;
  final bool checked;

  String get label => key.label;

  Map<String, Object?> toJson() => {'key': key.toJson(), 'checked': checked};

  factory WidgetTaskEntry.fromJson(Map<String, Object?> json) =>
      WidgetTaskEntry(
        WidgetTaskKey.fromJson(Map<String, Object?>.from(json['key']! as Map)),
        json['checked'] == true,
      );
}

final class WidgetNoteEntry {
  const WidgetNoteEntry({
    required this.id,
    required this.title,
    this.favorite = false,
  });
  final String id;
  final String title;
  final bool favorite;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    if (favorite) 'favorite': true,
  };

  factory WidgetNoteEntry.fromJson(Map<String, Object?> json) =>
      WidgetNoteEntry(
        id: json['id']! as String,
        title: json['title']! as String,
        favorite: json['favorite'] == true,
      );
}

enum WidgetPrivacy { visible, redacted }

/// What a widget renders. Built from local data only; rendering never needs
/// the network.
///
/// A [WidgetPrivacy.redacted] snapshot carries nothing but the instance, its
/// type and the capture time: no account or category names, titles,
/// excerpts, task counts, note ids or revisions.
final class WidgetSnapshot {
  const WidgetSnapshot({
    required this.instanceId,
    required this.type,
    required this.capturedAt,
    this.privacy = WidgetPrivacy.visible,
    this.accountId,
    this.accountLabel,
    this.noteId,
    this.revision,
    this.contentHash,
    this.title,
    this.excerpt,
    this.notes = const [],
    this.tasks = const [],
  });

  /// The snapshot every publisher writes while the app lock is on.
  const WidgetSnapshot.redacted({
    required this.instanceId,
    required this.type,
    required this.capturedAt,
  }) : privacy = WidgetPrivacy.redacted,
       accountId = null,
       accountLabel = null,
       noteId = null,
       revision = null,
       contentHash = null,
       title = null,
       excerpt = null,
       notes = const [],
       tasks = const [];

  final String instanceId;
  final WidgetType type;

  /// Milliseconds since the epoch.
  final int capturedAt;
  final WidgetPrivacy privacy;
  final String? accountId;

  /// Display name of the account, for the widget header.
  final String? accountLabel;
  final String? noteId;

  /// Note revision the content was read at; commands carry it back.
  final int? revision;

  /// Digest of the note text the snapshot shows (see `widgetContentHash`). A
  /// command whose revision is behind still applies when the text is the same,
  /// e.g. after a sync that only changed the sync state.
  final String? contentHash;
  final String? title;
  final String? excerpt;
  final List<WidgetNoteEntry> notes;
  final List<WidgetTaskEntry> tasks;

  bool get isRedacted => privacy == WidgetPrivacy.redacted;
  int get tasksDone => tasks.where((t) => t.checked).length;
  int get tasksTotal => tasks.length;

  Map<String, Object?> toJson() => {
    'schema': widgetSchema,
    'instanceId': instanceId,
    'type': type.name,
    'capturedAt': capturedAt,
    'privacy': privacy.name,
    if (!isRedacted) ...{
      'accountId': ?accountId,
      'accountLabel': ?accountLabel,
      'noteId': ?noteId,
      'revision': ?revision,
      'contentHash': ?contentHash,
      'title': ?title,
      'excerpt': ?excerpt,
      if (notes.isNotEmpty) 'notes': [for (final n in notes) n.toJson()],
      if (tasks.isNotEmpty) 'tasks': [for (final t in tasks) t.toJson()],
    },
  };

  /// Reads a snapshot. A redacted one never yields content, whatever else the
  /// stored map holds.
  factory WidgetSnapshot.fromJson(Map<String, Object?> json) {
    final type = _enum(WidgetType.values, json['type']) ?? WidgetType.notesList;
    final instance = json['instanceId']! as String;
    final at = (json['capturedAt'] as num?)?.toInt() ?? 0;
    if (_enum(WidgetPrivacy.values, json['privacy']) != WidgetPrivacy.visible) {
      return WidgetSnapshot.redacted(
        instanceId: instance,
        type: type,
        capturedAt: at,
      );
    }
    List<T> list<T>(String key, T Function(Map<String, Object?>) read) => [
      for (final e in (json[key] as List?) ?? const [])
        read(Map<String, Object?>.from(e as Map)),
    ];
    return WidgetSnapshot(
      instanceId: instance,
      type: type,
      capturedAt: at,
      accountId: json['accountId'] as String?,
      accountLabel: json['accountLabel'] as String?,
      noteId: json['noteId'] as String?,
      revision: (json['revision'] as num?)?.toInt(),
      contentHash: json['contentHash'] as String?,
      title: json['title'] as String?,
      excerpt: json['excerpt'] as String?,
      notes: list('notes', WidgetNoteEntry.fromJson),
      tasks: list('tasks', WidgetTaskEntry.fromJson),
    );
  }

  String encode() => jsonEncode(toJson());
  factory WidgetSnapshot.decode(String source) => WidgetSnapshot.fromJson(
    Map<String, Object?>.from(jsonDecode(source) as Map),
  );
}

enum WidgetCommandKind { setTask }

/// A request from a widget. [commandId] is unique per tap, so delivering the
/// same command twice changes the note once.
final class WidgetCommand {
  const WidgetCommand({
    required this.commandId,
    required this.instanceId,
    required this.accountId,
    required this.noteId,
    required this.expectedRevision,
    required this.task,
    required this.checked,
    this.contentHash,
    this.kind = WidgetCommandKind.setTask,
  });

  final String commandId;
  final String instanceId;
  final String accountId;
  final String noteId;

  /// Revision of the snapshot the user tapped in.
  final int expectedRevision;
  final WidgetCommandKind kind;
  final WidgetTaskKey task;

  /// The requested result, not a toggle.
  final bool checked;

  /// Digest of the note text the user tapped in, when the snapshot had one.
  final String? contentHash;

  WidgetCommand withRevision(int revision) => WidgetCommand(
    commandId: commandId,
    instanceId: instanceId,
    accountId: accountId,
    noteId: noteId,
    expectedRevision: revision,
    task: task,
    checked: checked,
    contentHash: contentHash,
    kind: kind,
  );

  Map<String, Object?> toJson() => {
    'schema': widgetSchema,
    'commandId': commandId,
    'instanceId': instanceId,
    'accountId': accountId,
    'noteId': noteId,
    'expectedRevision': expectedRevision,
    'kind': kind.name,
    'task': task.toJson(),
    'checked': checked,
    'contentHash': ?contentHash,
  };

  factory WidgetCommand.fromJson(Map<String, Object?> json) => WidgetCommand(
    commandId: json['commandId']! as String,
    instanceId: json['instanceId']! as String,
    accountId: json['accountId']! as String,
    noteId: json['noteId']! as String,
    expectedRevision: (json['expectedRevision']! as num).toInt(),
    kind:
        _enum(WidgetCommandKind.values, json['kind']) ??
        WidgetCommandKind.setTask,
    task: WidgetTaskKey.fromJson(
      Map<String, Object?>.from(json['task']! as Map),
    ),
    checked: json['checked'] == true,
    contentHash: json['contentHash'] as String?,
  );

  String encode() => jsonEncode(toJson());
  factory WidgetCommand.decode(String source) => WidgetCommand.fromJson(
    Map<String, Object?>.from(jsonDecode(source) as Map),
  );
}

T? _enum<T extends Enum>(List<T> values, Object? name) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}
