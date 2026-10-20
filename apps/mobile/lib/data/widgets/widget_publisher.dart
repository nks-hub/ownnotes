import 'dart:convert';
import 'package:notes_store/notes_store.dart';
import 'widget_model.dart';
import 'widget_snapshots.dart';
import 'widget_storage.dart';

/// One account's notes and, when known, its display name. A missing name keeps
/// the one the instance's last snapshot carried.
final class WidgetSource {
  const WidgetSource(this.notes, {this.label});
  final String? label;
  final List<LocalNote> notes;
}

/// Name a widget shows for [account]; the server host tells two accounts of
/// one login apart.
String widgetAccountLabel(Account account) {
  final host = Uri.tryParse(account.server)?.host ?? '';
  return host.isEmpty ? account.loginName : '${account.loginName} · $host';
}

/// Configurations of the placed instances; instances still waiting for their
/// first configuration are left out.
Future<List<WidgetConfig>> readWidgetConfigs(WidgetStorage storage) async {
  final configs = <WidgetConfig>[];
  for (final id in await storage.instanceIds()) {
    final raw = await storage.read(WidgetKeys.config(id));
    if (raw == null) continue;
    try {
      configs.add(WidgetConfig.decode(raw));
    } catch (_) {
      // An unreadable configuration shows "Configure widget" until replaced.
    }
  }
  return configs;
}

String _content(Map<String, Object?> json) =>
    jsonEncode(Map.of(json)..remove('capturedAt'));

Future<String?> _storedLabel(WidgetStorage storage, String id) async {
  try {
    final raw = await storage.read(WidgetKeys.snapshot(id));
    final json = jsonDecode(raw ?? 'null');
    return json is Map ? json['accountLabel'] as String? : null;
  } catch (_) {
    return null;
  }
}

/// Writes [next] (or removes the snapshot when null). Returns whether the
/// stored content changed; a new capture time alone is not a change.
Future<bool> _store(
  WidgetStorage storage,
  String id,
  WidgetSnapshot? next,
) async {
  final key = WidgetKeys.snapshot(id);
  final raw = await storage.read(key);
  if (next == null) {
    if (raw == null) return false;
    await storage.write(key, null);
    return true;
  }
  if (raw != null) {
    try {
      final stored = Map<String, Object?>.from(jsonDecode(raw) as Map);
      if (_content(stored) == _content(next.toJson())) return false;
    } catch (_) {
      // Rewrite what cannot be read.
    }
  }
  await storage.write(key, next.encode());
  return true;
}

/// Rebuilds the snapshot of every placed widget and asks the launcher to redraw
/// the ones that changed.
///
/// While [locked] every instance gets the redacted snapshot, whatever it was
/// configured to show. With [onlyAccount] only that account's instances are
/// rebuilt (the app knows the notes of the account on screen); the others keep
/// their snapshot until the background run. [source] returns null for an
/// account that no longer exists; its widgets lose the account.
Future<void> publishWidgets(
  WidgetStorage storage, {
  required Future<WidgetSource?> Function(String accountId) source,
  required bool locked,
  required String untitled,
  String? onlyAccount,
  int? now,
}) async {
  final stamp = now ?? DateTime.now().millisecondsSinceEpoch;
  var changed = false;
  if (await storage.isLocked() != locked) {
    await storage.setLocked(locked);
    // The widgets draw from this flag alone while locked; redraw before the
    // snapshots are rewritten.
    await storage.refresh();
    changed = true;
  }
  if (await storage.read(WidgetKeys.untitled) != untitled) {
    await storage.write(WidgetKeys.untitled, untitled);
  }
  final sources = <String, WidgetSource?>{};
  for (final config in await readWidgetConfigs(storage)) {
    final id = config.instanceId;
    final account = config.accountId;
    WidgetSnapshot? next;
    if (locked) {
      next = WidgetSnapshot.redacted(
        instanceId: id,
        type: config.type,
        capturedAt: stamp,
      );
    } else if (account != null) {
      if (onlyAccount != null && account != onlyAccount) continue;
      if (!sources.containsKey(account)) sources[account] = await source(account);
      final src = sources[account];
      if (src == null) {
        await storage.write(
          WidgetKeys.config(id),
          config.withoutAccount().encode(),
        );
        changed = true;
      } else {
        next = buildWidgetSnapshot(
          config,
          src.notes,
          locked: false,
          untitled: untitled,
          now: stamp,
          accountLabel: src.label ?? await _storedLabel(storage, id),
        );
      }
    }
    changed |= await _store(storage, id, next);
    final marker = await storage.read(WidgetKeys.stale(id));
    if (marker != null && marker != '${next?.revision}') {
      await storage.write(WidgetKeys.stale(id), null);
      changed = true;
    }
  }
  if (changed) await storage.refresh();
}

/// Empties the widgets of a removed account: their content and the account
/// reference in their configuration go, so they ask to be configured again.
Future<void> clearWidgetsOfAccount(
  WidgetStorage storage,
  String accountId,
) async {
  var changed = false;
  for (final config in await readWidgetConfigs(storage)) {
    if (config.accountId != accountId) continue;
    final id = config.instanceId;
    await storage.write(WidgetKeys.config(id), config.withoutAccount().encode());
    await storage.write(WidgetKeys.snapshot(id), null);
    await storage.write(WidgetKeys.stale(id), null);
    changed = true;
  }
  if (changed) await storage.refresh();
}

const _appliedLimit = 200;

/// Applies the commands the widgets queued since the last run, through the
/// same local draft path the editor saves with.
///
/// A command is dropped without any change while the app lock is on, applied
/// once however often it is delivered, and turned into a "changed, open the
/// note" hint when the note moved on or the task cannot be told apart.
/// Returns the ids of the accounts whose notes changed.
Future<Set<String>> drainWidgetCommands(
  WidgetStorage storage,
  NotesDatabase db,
) async {
  final locked = await storage.isLocked();
  var applied = <String>[];
  try {
    applied = List<String>.from(
      jsonDecode(await storage.read(WidgetKeys.applied) ?? '[]') as List,
    );
  } catch (_) {
    // A damaged list only costs the duplicate guard for old commands.
  }
  final changed = <String>{};
  final ours = <String, (int, int)>{};
  var touched = false;
  for (final id in await storage.instanceIds()) {
    final done = int.tryParse(await storage.read(WidgetKeys.cmdDone(id)) ?? '');
    final queued = int.tryParse(await storage.read(WidgetKeys.cmdSeq(id)) ?? '');
    if (queued == null || queued <= (done ?? 0)) continue;
    for (var n = (done ?? 0) + 1; n <= queued; n++) {
      final raw = await storage.read(WidgetKeys.cmd(id, n));
      await storage.write(WidgetKeys.cmd(id, n), null);
      if (raw == null) continue;
      WidgetCommand command;
      try {
        command = WidgetCommand.decode(raw);
      } catch (_) {
        continue;
      }
      final note = await db.note(command.accountId, command.noteId);
      // Ticks tapped in a row all carry the revision they were drawn at; those
      // that follow our own save of the same note still count as current.
      final key = '${command.accountId}/${command.noteId}';
      final run = ours[key];
      if (run != null &&
          note != null &&
          command.expectedRevision == run.$1 &&
          note.revision == run.$2) {
        command = command.withRevision(note.revision);
      }
      var result = resolveWidgetCommand(
        command,
        note: note,
        applied: applied.toSet(),
        locked: locked,
      );
      if (result is ApplyCommand) {
        try {
          final next = await db.saveDraft(
            accountId: note!.accountId,
            id: note.id,
            revision: note.revision,
            title: note.title,
            content: result.content,
            category: note.category,
            favorite: note.favorite,
          );
          await storage.write(WidgetKeys.stale(command.instanceId), null);
          changed.add(note.accountId);
          ours[key] = (run?.$1 ?? note.revision, next);
        } on StateError {
          result = const OpenNoteCommand();
        }
      }
      if (result is OpenNoteCommand) {
        await storage.write(
          WidgetKeys.stale(command.instanceId),
          '${note?.revision}',
        );
      }
      if (result is! BlockedCommand) {
        applied.add(command.commandId);
        touched = true;
      }
    }
    await storage.write(WidgetKeys.cmdDone(id), '$queued');
  }
  if (touched) {
    final keep = applied.length > _appliedLimit
        ? applied.sublist(applied.length - _appliedLimit)
        : applied;
    await storage.write(WidgetKeys.applied, jsonEncode(keep));
  }
  return changed;
}
