import 'package:notes_store/notes_store.dart';
import '../../core/markdown/markdown_document.dart';
import 'widget_model.dart';

const _listLimit = 8;

String _titleOf(LocalNote n, String untitled) {
  final title = n.title.trim().isEmpty ? titleFromContent(n.content) : n.title;
  return title.isEmpty ? untitled : title;
}

bool _inCollection(LocalNote n, WidgetCollection c) => switch (c.scope) {
  WidgetScope.all => true,
  WidgetScope.favorites => n.favorite,
  WidgetScope.uncategorised => n.category.isEmpty,
  WidgetScope.category =>
    n.category == c.category || n.category.startsWith('${c.category}/'),
};

/// Builds the snapshot for one widget [config] from the notes of its account.
///
/// While the app lock is on ([locked]) the result is always the redacted
/// snapshot, whatever the configuration; callers pass the current lock state
/// at publish time, so a late publisher cannot write content.
WidgetSnapshot buildWidgetSnapshot(
  WidgetConfig config,
  List<LocalNote> notes, {
  required bool locked,
  required String untitled,
  required int now,
  String? accountLabel,
}) {
  if (locked) {
    return WidgetSnapshot.redacted(
      instanceId: config.instanceId,
      type: config.type,
      capturedAt: now,
    );
  }
  final own = [
    for (final n in notes)
      if (n.accountId == config.accountId) n,
  ];
  WidgetSnapshot make({
    LocalNote? note,
    String? title,
    String? excerpt,
    List<WidgetNoteEntry> entries = const [],
    List<WidgetTaskEntry> tasks = const [],
  }) => WidgetSnapshot(
    instanceId: config.instanceId,
    type: config.type,
    capturedAt: now,
    accountId: config.accountId,
    accountLabel: accountLabel,
    noteId: note?.id,
    revision: note?.revision,
    title: title,
    excerpt: excerpt,
    notes: entries,
    tasks: tasks,
  );

  switch (config.type) {
    case WidgetType.notesList:
      final collection = config.collection ?? const WidgetCollection(WidgetScope.all);
      final shown = [
        for (final n in own)
          if (_inCollection(n, collection)) n,
      ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return make(
        entries: [
          for (final n in shown.take(_listLimit))
            WidgetNoteEntry(
              id: n.id,
              title: _titleOf(n, untitled),
              favorite: n.favorite,
            ),
        ],
      );
    case WidgetType.singleNote || WidgetType.checklist:
      final note = own.where((n) => n.id == config.noteId).firstOrNull;
      if (note == null) return make();
      final title = _titleOf(note, untitled);
      final doc = MarkdownDocument.parse(note.content);
      return make(
        note: note,
        title: title,
        excerpt: config.type == WidgetType.singleNote
            ? doc.excerpt(title, maxLength: 400)
            : null,
        tasks: config.type == WidgetType.checklist
            ? [
                for (final t in doc.tasks)
                  WidgetTaskEntry(WidgetTaskKey(t.label, t.occurrence), t.checked),
              ]
            : const [],
      );
    case WidgetType.quickNote:
      return make();
  }
}

sealed class WidgetCommandResult {
  const WidgetCommandResult();
}

/// Write [content] as the note's new text.
final class ApplyCommand extends WidgetCommandResult {
  const ApplyCommand(this.content);
  final String content;
}

/// Already applied, or the note already has the requested state: do nothing.
final class DuplicateCommand extends WidgetCommandResult {
  const DuplicateCommand();
}

/// The note moved on or the task cannot be told apart: open the app at the
/// note instead of changing something that merely looks similar.
final class OpenNoteCommand extends WidgetCommandResult {
  const OpenNoteCommand();
}

/// The app lock is on; background mutation is disabled.
final class BlockedCommand extends WidgetCommandResult {
  const BlockedCommand();
}

/// Decides what a widget [command] does to the note it targets.
///
/// [applied] holds the ids of commands already accepted; [locked] is the lock
/// state now, not when the widget was drawn. The checked state is set to what
/// the command asks for, never toggled, so a repeat cannot flip it back.
WidgetCommandResult resolveWidgetCommand(
  WidgetCommand command, {
  required LocalNote? note,
  required Set<String> applied,
  required bool locked,
}) {
  if (locked) return const BlockedCommand();
  if (applied.contains(command.commandId)) return const DuplicateCommand();
  if (note == null ||
      note.accountId != command.accountId ||
      note.id != command.noteId ||
      note.revision != command.expectedRevision) {
    return const OpenNoteCommand();
  }
  final doc = MarkdownDocument.parse(note.content);
  final wanted = alnum(command.task.label);
  final matches = [
    for (final t in doc.tasks)
      if (alnum(t.label) == wanted && t.occurrence == command.task.occurrence)
        t,
  ];
  if (matches.length != 1 || wanted.isEmpty) return const OpenNoteCommand();
  final task = matches.single;
  if (task.checked == command.checked) return const DuplicateCommand();
  final next = doc.toggled(note.content, task);
  return next == null ? const OpenNoteCommand() : ApplyCommand(next);
}
