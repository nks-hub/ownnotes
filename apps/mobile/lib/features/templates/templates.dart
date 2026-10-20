import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/runtime.dart';

/// A note skeleton kept on this device. Creating a note from it produces
/// ordinary Markdown; nothing about the template is written to the server.
final class NoteTemplate {
  const NoteTemplate({
    required this.id,
    required this.name,
    this.title = '',
    this.content = '',
    this.category = '',
  });

  final String id;
  final String name;

  /// Title of a note made from it; may contain the placeholders below.
  final String title;
  final String content;
  final String category;

  NoteTemplate copyWith({
    String? name,
    String? title,
    String? content,
    String? category,
  }) => NoteTemplate(
    id: id,
    name: name ?? this.name,
    title: title ?? this.title,
    content: content ?? this.content,
    category: category ?? this.category,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'title': title,
    'content': content,
    'category': category,
  };

  static NoteTemplate? fromJson(Object? json) {
    if (json case {'id': final String id, 'name': final String name}) {
      final m = json as Map;
      String s(String k) => m[k] is String ? m[k] as String : '';
      return NoteTemplate(
        id: id,
        name: name,
        title: s('title'),
        content: s('content'),
        category: s('category'),
      );
    }
    return null;
  }
}

/// Settings of the daily note.
final class DailyNoteConfig {
  const DailyNoteConfig({
    this.category = '',
    this.titlePattern = 'yyyy-MM-dd',
    this.templateId,
  });

  /// Category (folder) the daily notes go to; empty is uncategorized.
  final String category;

  /// `intl` date pattern of the title, for example `yyyy-MM-dd`.
  final String titlePattern;
  final String? templateId;

  DailyNoteConfig copyWith({
    String? category,
    String? titlePattern,
    String? templateId,
    bool clearTemplate = false,
  }) => DailyNoteConfig(
    category: category ?? this.category,
    titlePattern: titlePattern ?? this.titlePattern,
    templateId: clearTemplate ? null : templateId ?? this.templateId,
  );
}

const _templatesKey = 'templates';
const _dailyKey = 'dailyNote';

/// Device-local storage of the templates and the daily-note settings.
class TemplateStore {
  const TemplateStore();

  Future<List<NoteTemplate>> templates() async {
    final raw = await SharedPreferencesAsync().getString(_templatesKey);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw);
      return [
        if (list is List)
          for (final e in list) ?NoteTemplate.fromJson(e),
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<void> saveTemplates(List<NoteTemplate> list) =>
      SharedPreferencesAsync().setString(
        _templatesKey,
        jsonEncode([for (final t in list) t.toJson()]),
      );

  Future<DailyNoteConfig> daily() async {
    final raw = await SharedPreferencesAsync().getString(_dailyKey);
    if (raw == null) return const DailyNoteConfig();
    try {
      if (jsonDecode(raw) case final Map m) {
        return DailyNoteConfig(
          category: m['category'] is String ? m['category'] as String : '',
          titlePattern: m['titlePattern'] is String &&
                  (m['titlePattern'] as String).trim().isNotEmpty
              ? m['titlePattern'] as String
              : 'yyyy-MM-dd',
          templateId: m['templateId'] is String ? m['templateId'] as String : null,
        );
      }
    } on FormatException {
      // Falls back to the defaults.
    }
    return const DailyNoteConfig();
  }

  Future<void> saveDaily(DailyNoteConfig c) => SharedPreferencesAsync().setString(
    _dailyKey,
    jsonEncode({
      'category': c.category,
      'titlePattern': c.titlePattern,
      'templateId': c.templateId,
    }),
  );
}

String _format(String pattern, DateTime when) {
  try {
    return DateFormat(pattern, 'en').format(when);
  } on Object {
    return DateFormat('yyyy-MM-dd', 'en').format(when);
  }
}

/// Replaces `{{date}}` (yyyy-MM-dd), `{{time}}` (HH:mm) and `{{title}}`.
String expandTemplate(String source, DateTime when, {String title = ''}) =>
    source
        .replaceAll('{{date}}', _format('yyyy-MM-dd', when))
        .replaceAll('{{time}}', _format('HH:mm', when))
        .replaceAll('{{title}}', title);

/// What a daily note would be called and where it would go.
final class DailyNotePlan {
  const DailyNotePlan(this.title, this.category);
  final String title;
  final String category;
}

DailyNotePlan planDailyNote(DailyNoteConfig config, DateTime now) =>
    DailyNotePlan(_format(config.titlePattern, now), config.category);

/// Creates a local note from [template] in [accountId]; the note uploads like
/// any other. Returns its local id. [category] overrides the template's.
Future<String> createFromTemplate(
  AppRuntime runtime,
  String accountId,
  NoteTemplate template, {
  String? category,
  DateTime? now,
}) {
  final when = now ?? DateTime.now();
  final title = expandTemplate(template.title, when);
  return runtime.database.createDraft(
    accountId,
    title: title,
    content: expandTemplate(template.content, when, title: title),
    category: category ?? template.category,
  );
}

final class DailyNoteResult {
  const DailyNoteResult(this.noteId, {required this.created, required this.plan});

  /// Local id of the note to open.
  final String noteId;

  /// False when today's note already existed and is opened instead of a
  /// second one being made.
  final bool created;
  final DailyNotePlan plan;
}

/// Opens today's daily note, creating it first when the account has none with
/// the same title and category. [config] and [template] default to the stored
/// settings.
Future<DailyNoteResult> createDailyNote(
  AppRuntime runtime,
  String accountId, {
  DailyNoteConfig? config,
  NoteTemplate? template,
  DateTime? now,
  TemplateStore store = const TemplateStore(),
}) async {
  final when = now ?? DateTime.now();
  final settings = config ?? await store.daily();
  final plan = planDailyNote(settings, when);
  final existing = (await runtime.database.watchNotes(accountId).first)
      .where((n) => n.title == plan.title && n.category == plan.category)
      .firstOrNull;
  if (existing != null) {
    return DailyNoteResult(existing.id, created: false, plan: plan);
  }
  NoteTemplate? chosen = template;
  if (chosen == null && settings.templateId != null) {
    chosen = (await store.templates())
        .where((t) => t.id == settings.templateId)
        .firstOrNull;
  }
  final id = await runtime.database.createDraft(
    accountId,
    title: plan.title,
    content: chosen == null
        ? ''
        : expandTemplate(chosen.content, when, title: plan.title),
    category: plan.category,
  );
  return DailyNoteResult(id, created: true, plan: plan);
}
