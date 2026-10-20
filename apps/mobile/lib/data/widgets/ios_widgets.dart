import 'dart:convert';
import 'dart:io';

import 'package:home_widget/home_widget.dart';
import 'package:notes_store/notes_store.dart';

import '../../core/markdown/markdown_document.dart';
import 'widget_model.dart';
import 'widget_snapshots.dart';

const iosAppGroup = 'group.com.nkshub.nextcloudnotes';
const _commandsKey = 'commands';

/// App Group instance id and WidgetKit kind of one widget type. The iOS
/// extension has one widget kind per type and reads `snapshot.<instanceId>`.
String iosInstanceId(WidgetType type) => 'ios.${type.name}';
String iosWidgetKind(WidgetType type) => 'OwnNotes.${type.name}';

/// The configuration each iOS widget kind shows for [accountId]: all notes,
/// the latest note, and the latest note that has tasks.
List<WidgetConfig> iosWidgetConfigs(String accountId, List<LocalNote> notes) {
  final own = [
    for (final n in notes)
      if (n.accountId == accountId) n,
  ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  final withTasks = own
      .where((n) => MarkdownDocument.parse(n.content).tasks.isNotEmpty)
      .firstOrNull;
  WidgetConfig config(WidgetType type, {String? noteId}) => WidgetConfig(
    instanceId: iosInstanceId(type),
    type: type,
    accountId: accountId,
    collection: type == WidgetType.notesList
        ? const WidgetCollection(WidgetScope.all)
        : null,
    noteId: noteId,
  );
  return [
    config(WidgetType.notesList),
    config(WidgetType.singleNote, noteId: own.firstOrNull?.id),
    config(WidgetType.checklist, noteId: withTasks?.id),
    config(WidgetType.quickNote),
  ];
}

/// Writes one snapshot per iOS widget kind to the App Group and asks
/// WidgetKit to reload. With the app lock on ([locked]) every snapshot is the
/// redacted one. [accountId] null (no account) also writes redacted data.
Future<void> publishIosWidgets(
  String? accountId,
  List<LocalNote> notes, {
  required bool locked,
  required String untitled,
  String? accountLabel,
}) async {
  if (!Platform.isIOS) return;
  final now = DateTime.now().millisecondsSinceEpoch;
  try {
    await HomeWidget.setAppGroupId(iosAppGroup);
    final configs = accountId == null
        ? [
            for (final t in WidgetType.values)
              WidgetConfig(instanceId: iosInstanceId(t), type: t),
          ]
        : iosWidgetConfigs(accountId, notes);
    for (final config in configs) {
      final snapshot = buildWidgetSnapshot(
        config,
        notes,
        locked: locked || accountId == null,
        untitled: untitled,
        now: now,
        accountLabel: accountLabel,
      );
      await HomeWidget.saveWidgetData<String>(
        'snapshot.${config.instanceId}',
        snapshot.encode(),
      );
      await HomeWidget.updateWidget(iOSName: iosWidgetKind(config.type));
    }
  } catch (_) {
    // No widget support here; nothing is shown either.
  }
}

/// Takes the checklist commands the widget extension queued in the App Group.
/// Feed each through `resolveWidgetCommand`; the queue is cleared here, so a
/// command is delivered once.
Future<List<WidgetCommand>> takeIosWidgetCommands() async {
  if (!Platform.isIOS) return const [];
  try {
    await HomeWidget.setAppGroupId(iosAppGroup);
    final raw = await HomeWidget.getWidgetData<String>(_commandsKey);
    if (raw == null || raw.isEmpty) return const [];
    await HomeWidget.saveWidgetData<String>(_commandsKey, '[]');
    return [
      for (final e in jsonDecode(raw) as List)
        WidgetCommand.fromJson(Map<String, Object?>.from(e as Map)),
    ];
  } catch (_) {
    return const [];
  }
}
