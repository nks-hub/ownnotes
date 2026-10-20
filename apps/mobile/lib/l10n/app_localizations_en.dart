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
      'The server refused the login. Sign in again from Accounts.';

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
      'Remove the account from this phone and revoke its app password on the server? Notes on the server stay.';

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

  @override
  String get allNotes => 'All notes';

  @override
  String get favorites => 'Favorites';

  @override
  String get uncategorised => 'Uncategorised';

  @override
  String get categories => 'Categories';

  @override
  String get switchAccount => 'Switch account';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get noMatches => 'No note matches your search.';

  @override
  String get noNotesHere => 'No notes in this category yet.';

  @override
  String get newNoteHere => 'New note here';

  @override
  String get stateWaiting => 'Waiting';

  @override
  String get stateSending => 'Sending';

  @override
  String get stateNeedsDecision => 'Needs decision';

  @override
  String get relNow => 'Just now';

  @override
  String relMinutes(int count) {
    return '$count min ago';
  }

  @override
  String relHours(int count) {
    return '$count h ago';
  }

  @override
  String get relYesterday => 'Yesterday';

  @override
  String relDays(int count) {
    return '$count d ago';
  }

  @override
  String conflictsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes need a decision',
      one: '1 note needs a decision',
    );
    return '$_temp0';
  }

  @override
  String get signInAgain => 'Sign in again';

  @override
  String get resolveNow => 'Resolve';

  @override
  String get syncStatus => 'Synchronization status';

  @override
  String tasksDone(int done, int total) {
    return '$done of $total tasks done';
  }

  @override
  String get hasAttachments => 'Has attachments';

  @override
  String get serverEmpty => 'Enter the address of your Nextcloud server.';

  @override
  String get serverInsecure =>
      'Only https:// servers are supported. Your login would travel unencrypted otherwise.';

  @override
  String get serverInvalid =>
      'That is not a valid server address. Example: cloud.example.com';

  @override
  String get serverNoLogin =>
      'This server did not offer the Nextcloud login. Check the address.';

  @override
  String get serverUnreachable =>
      'Could not reach the server. Check the address and your connection.';

  @override
  String get browserUnavailable => 'Could not open the browser for the login.';

  @override
  String get loginExpired => 'The login took too long. Start again.';

  @override
  String get scannedLoginRejected =>
      'The server refused the scanned code. It may be old or revoked. Create a new one.';

  @override
  String get onboardingTitle => 'Your notes on your own Nextcloud';

  @override
  String get onboardingBody =>
      'OwnNotes syncs Markdown notes with the Nextcloud Notes app. They go to your server and nowhere else.';

  @override
  String get multiAccountTitle => 'Several accounts';

  @override
  String get multiAccountBody =>
      'Add more servers or users and switch between them any time.';

  @override
  String get secureLoginTitle => 'No password in the app';

  @override
  String get secureLoginBody =>
      'You sign in in your browser. The phone keeps only an app password that you can revoke.';

  @override
  String get checkingServer => 'Checking server…';

  @override
  String get waitingForLogin => 'Waiting for the login';

  @override
  String get waitingForLoginBody =>
      'Approve the access in your browser, then come back to the app.';

  @override
  String get savingAccount => 'Signing in…';

  @override
  String get scanLoginCode => 'Scan QR code';

  @override
  String get scanLoginCodeHint =>
      'Point the camera at the login QR code from Nextcloud (Settings, Security, app passwords).';

  @override
  String get scanLoginCodeUnreadable => 'That is not a Nextcloud login code.';

  @override
  String get scanCameraDenied =>
      'Camera access is off. Allow it in the app settings to scan the code.';

  @override
  String get scanCameraUnavailable => 'The camera could not be started.';

  @override
  String get openAppSettings => 'Open app settings';

  @override
  String get accounts => 'Accounts';

  @override
  String get currentAccount => 'Current account';

  @override
  String get accountRemovedRevoked =>
      'Account removed. Its app password is revoked on the server.';

  @override
  String get accountRemovedNotRevoked =>
      'Account removed from this phone. The server did not confirm it, so revoke the app password in Nextcloud under Settings, Security.';

  @override
  String get accountRemoveFailed => 'The account could not be removed.';

  @override
  String get serverCertificate =>
      'The server certificate could not be verified. Check the address, or fix the certificate on the server.';

  @override
  String get serverTimeout => 'The server took too long to answer. Try again.';

  @override
  String get notesAppMissing =>
      'The Notes app is not available on this server. Install or enable Nextcloud Notes first.';

  @override
  String get reauthMismatch =>
      'That login belongs to another server or user. Sign in as the same account to keep its notes.';

  @override
  String get recTitle => 'Compare versions';

  @override
  String get recTabDevice => 'Device';

  @override
  String get recTabServer => 'Server';

  @override
  String get recTabResult => 'Result';

  @override
  String get recUseResult => 'Use result';

  @override
  String get recKeepSeparate => 'Keep as separate note';

  @override
  String get recUseServer => 'Use server version';

  @override
  String get recLeave => 'Leave unresolved';

  @override
  String get recFillDevice => 'Put device text in Result';

  @override
  String get recFillServer => 'Put server text in Result';

  @override
  String get recFillBoth => 'Put both in Result';

  @override
  String get recResultReplaced => 'Result replaced';

  @override
  String get recUndo => 'Undo';

  @override
  String get recReasonConflict =>
      'Both this phone and the server changed this note.';

  @override
  String get recReasonUnknown =>
      'The outcome of the last upload is unknown. Compare the versions before you choose.';

  @override
  String get recReasonReadonly =>
      'The server no longer lets you edit this note. Your text is kept; save it as your own note.';

  @override
  String get recReasonMove =>
      'A note with attachments cannot change its category here. Keep the category from the server, or save your text as a separate note.';

  @override
  String get recReasonGeneric => 'This note needs your decision.';

  @override
  String recChangeCounter(int number, int total) {
    return 'Change $number of $total';
  }

  @override
  String get recNoChanges => 'Device and server text are the same.';

  @override
  String get recPrevChange => 'Previous change';

  @override
  String get recNextChange => 'Next change';

  @override
  String get recServerChanged =>
      'The server version changed again. The comparison now shows the newer version; your Result is kept. Review it and decide again.';

  @override
  String get recKept =>
      'Both versions stay saved on this phone until you remove them.';

  @override
  String get recSaveAsNew => 'Save as new note';

  @override
  String get recKeepCategory => 'Use result, keep server category';

  @override
  String get recReadFailed => 'Could not read the server version.';

  @override
  String get recKeepRecovery => 'Keep in recovery';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsWriting => 'Writing';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsSync => 'Sync and storage';

  @override
  String get settingsTransfer => 'Import and export';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsDeviceOnly => 'These settings apply to this device only.';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get exportMarkdown => 'Export Markdown';

  @override
  String get exportMarkdownHint =>
      'Notes as Markdown files in a ZIP. Attachments and recovery copies are not included.';

  @override
  String get widgetPolicyTitle => 'Home-screen widgets';

  @override
  String get widgetPolicyBody =>
      'With app lock on, widgets hide note content, even while the app is unlocked.';

  @override
  String storageNotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes on this device',
      one: '1 note on this device',
    );
    return '$_temp0';
  }

  @override
  String storageUnsent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes not sent yet',
      one: '1 note not sent yet',
      zero: 'Everything is sent to the server',
    );
    return '$_temp0';
  }

  @override
  String get syncHint =>
      'Notes sync when you open the app. The system decides when background sync runs.';

  @override
  String get exportUnsent => 'Export unsent notes';

  @override
  String get removeFromDevice => 'Remove from this device';

  @override
  String get accountDetails => 'Account details';

  @override
  String get accountUserLabel => 'User';

  @override
  String get accountServerLabel => 'Server';

  @override
  String get accountStatusLabel => 'Status';

  @override
  String get accountSignedIn => 'Signed in';

  @override
  String get accountsManage => 'Manage accounts';

  @override
  String get accountSwitchBlocked =>
      'Could not save on this device, so the account was not switched.';

  @override
  String get removeLocalNote =>
      'Only this device is affected. Notes on the server are not deleted.';

  @override
  String get loginCancelled => 'Sign-in cancelled. Nothing was saved.';

  @override
  String get reauthExplain =>
      'Sign in as this account to keep its notes and unsent changes.';

  @override
  String get scanConfirmTitle => 'Sign in with this code?';

  @override
  String scanConfirmBody(String user, String host) {
    return '$user on $host';
  }

  @override
  String get scanEnterAddress => 'Enter server address';

  @override
  String get appLocked => 'OwnNotes is locked';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get dockFormat => 'Format';

  @override
  String get dockTask => 'Task';

  @override
  String get dockAttach => 'Attach';

  @override
  String get dockInsert => 'Insert';

  @override
  String get fmtStrike => 'Strikethrough';

  @override
  String get fmtQuote => 'Quote';

  @override
  String get fmtNumbered => 'Numbered list';

  @override
  String get fmtCode => 'Code';

  @override
  String get fmtIndent => 'Indent';

  @override
  String get fmtOutdent => 'Outdent';

  @override
  String get insertMention => 'Mention';

  @override
  String get insertEmoji => 'Emoji';

  @override
  String get smartPicker => 'Smart picker';

  @override
  String get smartPickerNone =>
      'This server offers nothing the smart picker can search.';

  @override
  String get attachPhoto => 'Photo';

  @override
  String get attachCamera => 'Camera';

  @override
  String get attachFile => 'File';

  @override
  String get attachVoice => 'Voice';

  @override
  String get suggestSearching => 'Searching…';

  @override
  String get suggestError =>
      'Suggestions are not available right now. You can keep writing.';

  @override
  String suggestCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count suggestions',
      one: '1 suggestion',
    );
    return '$_temp0';
  }

  @override
  String get suggestInsert => 'Insert';

  @override
  String get cmdToday => 'Today\'s date';

  @override
  String get cmdTime => 'Current time';

  @override
  String get cmdTable => 'Table';

  @override
  String get cmdDivider => 'Divider';

  @override
  String get calloutInfo => 'Info';

  @override
  String get calloutWarning => 'Warning';

  @override
  String get calloutError => 'Error';

  @override
  String get calloutSuccess => 'Success';

  @override
  String get detailsDefault => 'Details';

  @override
  String mentionLabel(String name) {
    return 'Mention: $name';
  }

  @override
  String attachmentLabel(String name) {
    return 'Attachment: $name';
  }

  @override
  String tableLabel(int rows, int columns) {
    String _temp0 = intl.Intl.pluralLogic(
      rows,
      locale: localeName,
      other: '$rows rows',
      one: '1 row',
    );
    String _temp1 = intl.Intl.pluralLogic(
      columns,
      locale: localeName,
      other: '$columns columns',
      one: '1 column',
    );
    return 'Table with $_temp0 and $_temp1';
  }

  @override
  String get editSection => 'Edit this section';

  @override
  String get checklistMarkdown => 'Markdown';

  @override
  String get checklistEmpty => 'No tasks yet. Add the first item below.';

  @override
  String get checklistAdd => 'Add item';

  @override
  String checklistCompletedGroup(int count) {
    return 'Completed ($count)';
  }

  @override
  String get clearCompleted => 'Clear completed items';

  @override
  String clearCompletedConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Remove $count completed items from the note?',
      one: 'Remove 1 completed item from the note?',
    );
    return '$_temp0';
  }

  @override
  String clearedCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items removed',
      one: '1 item removed',
    );
    return '$_temp0';
  }

  @override
  String checklistPosition(int position, int total) {
    return '$position of $total';
  }

  @override
  String get checklistItemMenu => 'Item options';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get shareTitle => 'Share';

  @override
  String get shareSendCopy => 'Send a copy';

  @override
  String get shareAsText => 'Send as text';

  @override
  String get shareAsFile => 'Send as Markdown file';

  @override
  String get shareWithPeople => 'Share with people';

  @override
  String get sharePeopleWithAccess => 'People with access';

  @override
  String get shareSearchHint => 'Search people';

  @override
  String get sharePermissionView => 'Can view';

  @override
  String get sharePermissionEdit => 'Can edit';

  @override
  String get shareRemove => 'Remove access';

  @override
  String get sharePending => 'Sharing…';

  @override
  String get shareRemoving => 'Removing access…';

  @override
  String get shareFailed =>
      'This did not work. Check the connection and try again.';

  @override
  String get shareNotUploaded =>
      'This note is not on the server yet. It is uploaded first, then it can be shared.';

  @override
  String get shareUploadFirst => 'Upload and continue';

  @override
  String get shareUploading => 'Uploading the note…';

  @override
  String get shareUploadFailed =>
      'The note could not be uploaded yet. It stays saved on this device.';

  @override
  String get shareIncoming =>
      'Somebody shared this note with you. Only its owner can share it further.';

  @override
  String get shareAttachmentsWarning =>
      'This note has attachments. People you share it with may not be able to open them.';

  @override
  String get shareNone => 'Not shared with anyone yet.';

  @override
  String get shareNoResults => 'No matching people.';

  @override
  String get shareChecking => 'Checking the shares…';

  @override
  String shareWithName(String name) {
    return 'Share with $name';
  }

  @override
  String get moreOptions => 'More options';

  @override
  String get openDetails => 'Details';

  @override
  String get unfavorite => 'Remove from favorites';

  @override
  String get openChecklist => 'Open checklist';

  @override
  String get attachments => 'Attachments';

  @override
  String get historyRecovery => 'History and recovery';

  @override
  String get exportNote => 'Export';

  @override
  String findCount(int index, int total) {
    return '$index of $total';
  }

  @override
  String get findPrevious => 'Previous match';

  @override
  String get saveFailedTitle => 'Could not save on this device';

  @override
  String get noteUnreadable =>
      'The server could not hand out this note\'s text. Your last copy is kept. Retry, or copy your text.';

  @override
  String get exportDraft => 'Export draft';

  @override
  String get attachmentsNone => 'No attachments in this note.';

  @override
  String get attachmentImage => 'Image';

  @override
  String get attachmentFile => 'File';

  @override
  String get templates => 'Templates';

  @override
  String get templatesEmpty => 'No templates yet.';

  @override
  String get templatesManage => 'Manage templates';

  @override
  String get templateNew => 'New template';

  @override
  String get templateEdit => 'Edit template';

  @override
  String get templateSave => 'Save';

  @override
  String get templateName => 'Template name';

  @override
  String templatePlaceholders(String placeholders) {
    return 'Filled in when a note is created: $placeholders';
  }

  @override
  String templateDeleteConfirm(String name) {
    return 'Delete the template \"$name\"?';
  }

  @override
  String get templatesDeviceOnly =>
      'Templates and the daily note stay on this device.';

  @override
  String get dailyNote => 'Daily note';

  @override
  String get dailyNotePattern => 'Title pattern (for example yyyy-MM-dd)';

  @override
  String get dailyNoteTemplate => 'Template';

  @override
  String get dailyNoteNoTemplate => 'No template';

  @override
  String dailyNotePreview(String title, String category) {
    return 'Today: \"$title\" in $category';
  }
}
