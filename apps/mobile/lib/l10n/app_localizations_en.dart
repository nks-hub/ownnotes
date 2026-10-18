// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'OwnNotes';

  @override
  String get addAccount => 'Add account';

  @override
  String get serverUrl => 'Nextcloud server URL';

  @override
  String get connect => 'Connect';

  @override
  String get cancel => 'Cancel';

  @override
  String get waitingLogin => 'Complete login in your browser…';

  @override
  String get loginFailed =>
      'Login failed. Check the server address and start again.';

  @override
  String get noAccounts => 'Connect your Nextcloud account.';

  @override
  String get noNotes => 'No notes yet. Create one or synchronize.';

  @override
  String get newNote => 'New note';

  @override
  String get untitled => 'Untitled';

  @override
  String get search => 'Search notes';

  @override
  String get sync => 'Synchronize';

  @override
  String get syncFailed => 'Synchronization failed. Local notes are preserved.';

  @override
  String get loadFailed => 'Could not load local data.';

  @override
  String get retry => 'Retry';

  @override
  String get title => 'Title';

  @override
  String get content => 'Markdown text';

  @override
  String get category => 'Category';

  @override
  String get favorite => 'Favorite';

  @override
  String get preview => 'Preview';

  @override
  String get edit => 'Edit source';

  @override
  String get save => 'Save locally';

  @override
  String get saved => 'Saved locally';

  @override
  String get saving => 'Saving…';

  @override
  String get saveFailed =>
      'Save failed. Keep this editor open and copy your text.';

  @override
  String get decisionRequired =>
      'Synchronization needs a decision. Your local text is preserved.';

  @override
  String get readonly => 'Read-only note';

  @override
  String get selectNote => 'Select a note';

  @override
  String get imageUnavailable => 'Image not loaded';

  @override
  String get startupFailed =>
      'Local storage could not be opened. Retry without clearing app data.';

  @override
  String get resolve => 'Resolve synchronization';

  @override
  String get readServer => 'Compare server version';

  @override
  String get localVersion => 'Local version';

  @override
  String get serverVersion => 'Server version';

  @override
  String get useServer => 'Use server version';

  @override
  String get keepLocal => 'Keep local changes';

  @override
  String get newCopy => 'Create a separate copy';

  @override
  String get copyWarning =>
      'The server may already contain this note. Creating a separate copy can produce a duplicate. The original recovery record will be retained.';

  @override
  String get confirm => 'Confirm';

  @override
  String get copyMarkdown => 'Copy Markdown';

  @override
  String get decisionFailed =>
      'Could not apply the decision. Reload and compare again.';
}
