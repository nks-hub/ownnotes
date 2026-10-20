import 'dart:convert';
import 'dart:io';
import 'package:home_widget/home_widget.dart';
import 'package:notes_store/notes_store.dart';

String? _published;

/// Empties the widget when it still shows [accountId], so titles of a removed
/// account do not stay on the home screen.
Future<void> clearNotesWidget(String accountId) async {
  if (!Platform.isAndroid) return;
  try {
    if (await HomeWidget.getWidgetData<String>('account') != accountId) return;
    _published = null;
    await HomeWidget.saveWidgetData<String>('account', '');
    await HomeWidget.saveWidgetData<String>('notes', '[]');
    await HomeWidget.updateWidget(
      qualifiedAndroidName: 'com.nkshub.nextcloudnotes.NotesWidget',
    );
  } catch (_) {
    // No widget support here; nothing is shown either.
  }
}

/// Writes the five latest notes of [accountId] for the Android home-screen
/// widget (`NotesWidget.kt`). With the app lock on no titles are written.
/// Runs from the app and from the background worker.
Future<void> publishNotesWidget(
  String accountId,
  List<LocalNote> notes, {
  required bool locked,
  required String untitled,
}) async {
  if (!Platform.isAndroid) return;
  String title(LocalNote n) {
    final title = n.title.trim().isEmpty
        ? titleFromContent(n.content)
        : n.title;
    return title.isEmpty ? untitled : title;
  }

  final data = jsonEncode([
    if (!locked)
      for (final n in notes.take(5)) {'id': n.id, 'title': title(n)},
  ]);
  final key = '$accountId$locked$data';
  if (key == _published) return;
  _published = key;
  try {
    await HomeWidget.saveWidgetData<String>('account', accountId);
    await HomeWidget.saveWidgetData<bool>('locked', locked);
    await HomeWidget.saveWidgetData<String>('notes', data);
    await HomeWidget.updateWidget(
      qualifiedAndroidName: 'com.nkshub.nextcloudnotes.NotesWidget',
    );
  } catch (_) {
    _published = null; // No widget support here; try again next time.
  }
}
