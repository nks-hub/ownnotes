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

  @override
  String get importKeep => 'Import from Google Keep (Takeout .zip)';

  @override
  String importDone(int count) {
    return 'Imported $count notes';
  }

  @override
  String get importFailed =>
      'Import failed. The file is not a Google Takeout zip with Keep notes.';

  @override
  String get delete => 'Delete';

  @override
  String get deleteConfirm =>
      'Delete this note? It is also deleted on the server.';

  @override
  String get allCategories => 'All';

  @override
  String unsent(int count) {
    return 'Not sent yet: $count';
  }

  @override
  String get reasonOffline =>
      'No connection. Notes upload on their own when it is back.';

  @override
  String get reasonAuth =>
      'The server refused the login. Add the account again.';

  @override
  String get reasonLocked =>
      'The file is locked on the server. Trying again shortly.';

  @override
  String get reasonStorageFull => 'The server storage is full.';

  @override
  String get reasonServer =>
      'The server answered with an error. Trying again shortly.';

  @override
  String get sortByTitle => 'Sort by title';

  @override
  String get sortByModified => 'Sort by last change';

  @override
  String get settings => 'Settings';

  @override
  String get monospace => 'Monospace font in the editor';

  @override
  String get textSize => 'Editor text size';

  @override
  String get appLock => 'App lock';

  @override
  String get appLockHint =>
      'Asks for fingerprint, face or the phone PIN when you come back to the app.';

  @override
  String get appLockUnavailable => 'This phone has no screen lock set up.';

  @override
  String get blockScreenshots => 'Block screenshots';

  @override
  String get exportNotes => 'Export notes (zip)';

  @override
  String exportDone(int count) {
    return 'Exported $count notes';
  }

  @override
  String get exportFailed => 'Export failed.';

  @override
  String get removeAccount => 'Remove account from this phone';

  @override
  String get removeAccountConfirm =>
      'Remove the account from this phone? Notes on the server stay.';

  @override
  String removeAccountUnsent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes are not on the server yet and will be lost.',
      one: '1 note is not on the server yet and will be lost.',
    );
    return 'Remove the account? $_temp0 You can export them first.';
  }

  @override
  String get unlockReason => 'Unlock OwnNotes';

  @override
  String get unlock => 'Unlock';

  @override
  String get findInNote => 'Find in note';

  @override
  String get findNext => 'Next match';

  @override
  String get notFound => 'Not found';

  @override
  String get shareTo => 'Where should the shared text go?';

  @override
  String get remoteDeleted =>
      'This note was deleted on the server meanwhile. The text on this phone is kept.';

  @override
  String get uploadAgain => 'Upload it to the server again';

  @override
  String get deleteHere => 'Delete on this phone too';

  @override
  String get mergeBoth => 'Combine both versions';

  @override
  String get settingSaveFailed =>
      'Could not save the setting. It stays as it was.';

  @override
  String get lockUnavailable =>
      'The lock could not be checked right now. Try again.';

  @override
  String get lockDeviceRemoved =>
      'The screen lock of this phone was removed, so the app lock cannot work.';

  @override
  String get lockTurnOff => 'Turn off app lock and continue';

  @override
  String get editNote => 'Edit';

  @override
  String get fmtBold => 'Bold';

  @override
  String get fmtItalic => 'Italic';

  @override
  String get fmtHeading => 'Heading';

  @override
  String get fmtList => 'List';

  @override
  String get fmtChecklist => 'Checklist';

  @override
  String get fmtLink => 'Link';
}
