import 'dart:io';
import 'dart:ui' show PluginUtilities;
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:notes_store/notes_store.dart';
import '../features/widgets/widget_config_main.dart' show widgetConfigMain;
import 'runtime.dart';
import 'background_policy.dart';
import 'widgets/ios_widgets.dart';
import 'widgets/widget_snapshots.dart';
import 'widgets/widget_publisher.dart';
import 'widgets/widget_storage.dart';

const _storage = HomeWidgetStorage();

int? _published;
bool? _lastLocked;
String? _lastLanguage;
bool _callbackRegistered = false;

/// Removes what the widgets of a removed account showed; they ask to be
/// configured again.
Future<void> clearNotesWidget(String accountId) async {
  if (!Platform.isAndroid) return;
  _published = null;
  try {
    await clearWidgetsOfAccount(_storage, accountId);
  } catch (_) {
    // No widget support here; nothing is shown either.
  }
}

/// Redraws the home-screen widgets from the notes of the account on screen
/// (`widget/**` in the Android project). Every widget keeps the account it was
/// configured with; the selected account only decides whose notes are at hand.
/// With the app lock on every widget gets the redacted snapshot. Runs from the
/// app; the background worker uses [publishAllWidgets].
///
/// With [database] the first publish and every change of the lock state or
/// [language] also
/// rebuild the widgets of the other accounts, so unlocking brings all of them
/// back at once.
Future<void> publishNotesWidget(
  String accountId,
  List<LocalNote> notes, {
  required bool locked,
  required String untitled,
  required String language,
  NotesDatabase? database,
}) async {
  if (Platform.isIOS) {
    await publishIosWidgets(
      accountId,
      notes,
      locked: locked,
      untitled: untitled,
    );
    return;
  }
  if (!Platform.isAndroid) return;
  final key = Object.hash(
    accountId,
    locked,
    untitled,
    language,
    Object.hashAll([
      for (final n in notes)
        Object.hash(n.id, n.revision, n.title, n.category, n.favorite),
    ]),
  );
  if (key == _published) return;
  _published = key;
  final everyAccount =
      database != null && (_lastLocked != locked || _lastLanguage != language);
  _lastLocked = locked;
  _lastLanguage = language;
  try {
    await _registerCallback();
    await publishWidgets(
      _storage,
      source: everyAccount
          ? (id) async {
              final account = await database.account(id);
              if (account == null) return null;
              return WidgetSource(
                id == accountId ? notes : await database.watchNotes(id).first,
                label: widgetAccountLabel(account),
              );
            }
          : (id) async => WidgetSource(notes),
      locked: locked,
      untitled: untitled,
      language: language,
      onlyAccount: everyAccount ? null : accountId,
    );
  } catch (_) {
    _published = null; // No widget support here; try again next time.
  }
}

/// Applies queued widget commands, then redraws every widget from the
/// database, for all accounts. Used by the background worker and by the
/// widget's own background callback. Returns the accounts whose notes a
/// command changed, so the caller can upload them.
Future<Set<String>> publishAllWidgets(NotesDatabase db) async {
  if (Platform.isIOS) return _applyIosCommands(db);
  if (!Platform.isAndroid) return {};
  final changed = await drainWidgetCommands(_storage, db);
  await publishWidgets(
    _storage,
    source: (id) async {
      final account = await db.account(id);
      if (account == null) return null;
      return WidgetSource(
        await db.watchNotes(id).first,
        label: widgetAccountLabel(account),
      );
    },
    locked: await _storage.isLocked(),
    untitled: await _storage.read(WidgetKeys.untitled) ?? '…',
    language: await _storage.read(WidgetKeys.language),
  );
  return changed;
}

/// iOS: applies the checklist ticks the widget extension queued in the App
/// Group through the same rules as Android; a tick that no longer fits the
/// note is dropped, the widget then shows the current state.
Future<Set<String>> _applyIosCommands(NotesDatabase db) async {
  final changed = <String>{};
  for (final command in await takeIosWidgetCommands()) {
    final note = await db.note(command.accountId, command.noteId);
    // The extension shows no tasks while the app lock is on, so a queued
    // tick was made while it was off.
    final result = resolveWidgetCommand(
      command,
      note: note,
      applied: const {},
      locked: false,
    );
    if (result is! ApplyCommand || note == null) continue;
    try {
      await db.saveDraft(
        accountId: note.accountId,
        id: note.id,
        revision: note.revision,
        title: note.title,
        content: result.content,
        category: note.category,
        favorite: note.favorite,
      );
      changed.add(note.accountId);
    } on StateError {
      // The note changed meanwhile; the widget redraws with its new state.
    }
  }
  return changed;
}

/// Tells the widget code which Dart functions to run: [widgetBackgroundCallback]
/// when a task is ticked while the app is closed, and the configuration screen
/// when a widget is placed. Handles may change with every build, so this runs
/// once per start of the app.
Future<void> _registerCallback() async {
  if (_callbackRegistered) return;
  _callbackRegistered = true;
  await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
  final config = PluginUtilities.getCallbackHandle(widgetConfigMain);
  await _storage.write(
    WidgetKeys.configHandle,
    config?.toRawHandle().toString(),
  );
}

/// Runs in the background engine the widget starts after a tap: takes the
/// queued commands, uploads what they changed and redraws the widgets.
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? _) {
  // Taps arrive faster than a run ends; one run at a time keeps two of them
  // from reading the same queue.
  final run = _tail.then((_) => _drainAndUpload());
  _tail = run.catchError((Object _) {});
  return run;
}

Future<void> _tail = Future<void>.value();

Future<void> _drainAndUpload() async {
  final runtime = AppRuntime.production(
    decorateTransport: BackgroundSyncClient.new,
  );
  try {
    final changed = await publishAllWidgets(runtime.database);
    if (!await backgroundSyncAllowed()) return;
    for (final account in changed) {
      try {
        await runtime.sync.sync(account).timeout(const Duration(seconds: 25));
      } catch (_) {
        // Offline or refused; the draft stays and the next sync sends it.
      }
    }
    if (changed.isNotEmpty) await publishAllWidgets(runtime.database);
  } finally {
    await runtime.close();
  }
}
