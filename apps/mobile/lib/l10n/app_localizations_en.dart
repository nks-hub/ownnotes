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

  @override
  String get categoriesMenu => 'Categories';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncDetails => 'Sync details';

  @override
  String get selectNotes => 'Select notes';

  @override
  String get sortAndFilter => 'Sort and filter';

  @override
  String accountSyncHint(String account) {
    return 'Sync details for $account';
  }

  @override
  String get checkingForUpdates => 'Checking for updates';

  @override
  String syncSavedWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Saved on device · $count waiting',
      one: 'Saved on device · 1 waiting',
    );
    return '$_temp0';
  }

  @override
  String syncUploading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Uploading $count changes',
      one: 'Uploading 1 change',
    );
    return '$_temp0';
  }

  @override
  String syncUpToDate(String time) {
    return 'Up to date · checked $time';
  }

  @override
  String get syncOffline => 'Offline · changes saved on device';

  @override
  String get syncOfflineShort => 'Offline';

  @override
  String get syncAuthFailure => 'Sign in again · local notes retained';

  @override
  String get syncSaveFailure => 'Could not save on this device';

  @override
  String get needsAttention => 'Needs attention';

  @override
  String get sharedWithMe => 'Shared with me';

  @override
  String get savedViews => 'Saved views';

  @override
  String get onThisDevice => 'On this device';

  @override
  String get saveView => 'Save this view';

  @override
  String get saveViewName => 'Name of the view';

  @override
  String get deleteView => 'Delete saved view';

  @override
  String get sheetUploads => 'Uploads';

  @override
  String get sheetDownloads => 'Downloads';

  @override
  String get sheetDecisions => 'Decisions';

  @override
  String get sheetDeletions => 'Deletions';

  @override
  String get uploadsNone => 'Nothing waiting to upload';

  @override
  String get downloadsNever => 'Not checked yet';

  @override
  String downloadsUnreadable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes cannot be refreshed',
      one: '1 note cannot be refreshed',
    );
    return '$_temp0';
  }

  @override
  String downloadsMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes are no longer listed by the server',
      one: '1 note is no longer listed by the server',
    );
    return '$_temp0';
  }

  @override
  String get decisionsNone => 'No notes need a decision';

  @override
  String get deletionsNone => 'No deletions waiting';

  @override
  String deletionsWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count deletions waiting for the server',
      one: '1 deletion waiting for the server',
    );
    return '$_temp0';
  }

  @override
  String deletionsFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count deletions failed',
      one: '1 deletion failed',
    );
    return '$_temp0';
  }

  @override
  String get reviewItems => 'Review';

  @override
  String get rowSavedWaiting => 'Saved on device · Waiting to upload';

  @override
  String get rowUploading => 'Uploading changes';

  @override
  String get rowNeedsDecision => 'Needs your decision';

  @override
  String get rowUnavailable => 'Cannot refresh this note';

  @override
  String get rowMissing => 'No longer listed by the server';

  @override
  String get rowSharedEdit => 'Shared · Can edit';

  @override
  String get rowSharedView => 'Shared · View only';

  @override
  String attachmentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attachments',
      one: '1 attachment',
    );
    return '$_temp0';
  }

  @override
  String rowMenu(String title) {
    return 'Actions for $title';
  }

  @override
  String get openNote => 'Open';

  @override
  String get moveNote => 'Move';

  @override
  String get rowDeletionWaiting => 'Deletion waiting';

  @override
  String rowDeletionFailed(String reason) {
    return 'Deletion failed · $reason';
  }

  @override
  String get undoAction => 'Undo';

  @override
  String get saveCopy => 'Save a copy';

  @override
  String categoryCount(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 note',
    );
    return '$name, $_temp0 including subcategories';
  }

  @override
  String expandCategory(String name) {
    return 'Expand $name';
  }

  @override
  String collapseCategory(String name) {
    return 'Collapse $name';
  }

  @override
  String openSubtree(String name) {
    return 'Show $name on its own';
  }

  @override
  String get allCategoriesUp => 'All categories';

  @override
  String get createNote => 'Note';

  @override
  String get createChecklist => 'Checklist';

  @override
  String get createTemplate => 'Template';

  @override
  String get createDaily => 'Daily note';

  @override
  String get createWhere => 'Which category should the note go to?';

  @override
  String get createNoteAction => 'Create note';

  @override
  String get createHere => 'Create here';

  @override
  String get filterTasks => 'Unfinished tasks';

  @override
  String get filterAttachments => 'With attachments';

  @override
  String get filterShared => 'Shared';

  @override
  String get filterWaiting => 'Not uploaded yet';

  @override
  String get filterDecision => 'Needs a decision';

  @override
  String get filterSharing => 'Sharing';

  @override
  String get filterSync => 'Sync state';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get sortTitle => 'Sort';

  @override
  String get sortFavoritesFirst => 'Favorites first';

  @override
  String get emptyFavoritesTitle => 'No favorites yet';

  @override
  String get emptyFavoritesBody =>
      'Star a note to find it here. Use the note menu or swipe a note.';

  @override
  String get emptySharedTitle => 'Nothing shared with you';

  @override
  String get emptySharedBody =>
      'Notes that other people share with this account appear here.';

  @override
  String get emptyAttentionTitle => 'Nothing needs your attention';

  @override
  String get emptyAttentionBody =>
      'Decisions, failed deletions and notes that cannot be refreshed appear here.';

  @override
  String emptyCategoryTitle(String category) {
    return '$category is empty';
  }

  @override
  String get downloadingTitle => 'Downloading your notes';

  @override
  String downloadingBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes downloaded so far',
      one: '1 note downloaded so far',
    );
    return '$_temp0';
  }

  @override
  String get connectNextcloud => 'Connect Nextcloud';

  @override
  String get scanLoginQr => 'Scan login QR code';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String get bulkFavorite => 'Favorite';

  @override
  String get bulkUnfavorite => 'Remove from favorites';

  @override
  String get bulkMove => 'Move';

  @override
  String get bulkExport => 'Export';

  @override
  String get bulkMixedMove =>
      'Move is unavailable because some selected notes are read-only, shared or have attachments.';

  @override
  String get bulkMixedDelete =>
      'Delete is unavailable because some selected notes are read-only, shared or being sent.';

  @override
  String get bulkMixedFavorite =>
      'Favorite is unavailable because some selected notes are shared.';

  @override
  String bulkDeleteConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count notes?',
      one: 'Delete 1 note?',
    );
    return '$_temp0';
  }

  @override
  String get bulkDeleteBody =>
      'The notes are also deleted on the server. You can undo this until the server has carried it out.';

  @override
  String notesDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes deleted',
      one: '1 note deleted',
    );
    return '$_temp0';
  }

  @override
  String notesMoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes moved',
      one: '1 note moved',
    );
    return '$_temp0';
  }

  @override
  String bulkFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes could not be changed',
      one: '1 note could not be changed',
    );
    return '$_temp0';
  }

  @override
  String get moveTitle => 'Move to category';

  @override
  String get moveNewCategory => 'New category';

  @override
  String get moveNewCategoryHint => 'Name, use / for subcategories';

  @override
  String get clearSelection => 'Cancel selection';

  @override
  String get rowFavoriteOn => 'Add to favorites';

  @override
  String get rowFavoriteOff => 'Remove from favorites';

  @override
  String get attachmentsTitle => 'Attachments';

  @override
  String get attachmentsEmpty => 'No attachments in this note.';

  @override
  String get attachStored => 'Stored on device';

  @override
  String get attachWaiting => 'Waiting to upload';

  @override
  String get attachWaitingNote => 'Waiting for the note to be uploaded';

  @override
  String get attachUploading => 'Uploading';

  @override
  String get attachOffline => 'Available offline';

  @override
  String get attachOnServer => 'On the server';

  @override
  String get attachUnavailable => 'Unavailable';

  @override
  String attachFailedState(String reason) {
    return 'Failed: $reason';
  }

  @override
  String get attachErrOffline => 'The server could not be reached.';

  @override
  String get attachErrAuth => 'Sign in again to upload.';

  @override
  String get attachErrTooLarge => 'The server refused the file as too large.';

  @override
  String get attachErrDenied => 'The server did not allow the upload.';

  @override
  String get attachErrNoteGone => 'The note no longer exists on the server.';

  @override
  String get attachErrServer => 'The server returned an error.';

  @override
  String get attachRemoveQueue => 'Remove from queue';

  @override
  String get attachRemoveLink => 'Remove link from note';

  @override
  String get attachRemoveLinkHelp =>
      'Removing the link only edits this note. The file stays on the server.';

  @override
  String get attachDeleteFile => 'Delete file on server';

  @override
  String get attachDeleteTitle => 'Delete the file on the server?';

  @override
  String get attachDeleteBody =>
      'The file is removed from the server for good. Other notes and devices that link to it will show a missing file.';

  @override
  String get attachDeleteFileOnly => 'Delete file';

  @override
  String get attachDeleteFileAndLink => 'Delete file and link';

  @override
  String get attachDeleteUnsupported =>
      'This server version cannot delete attachments. Remove the link instead; the file stays on the server.';

  @override
  String get attachDeleteFailed => 'Could not delete the file.';

  @override
  String get attachKeepOffline => 'Keep offline';

  @override
  String get attachUploadFailedTitle => 'Upload failed';

  @override
  String get attachKeepForLater => 'Keep for later';

  @override
  String get attachSavedWaiting =>
      'Saved on device. It uploads once the note is on the server, and the link is added to the note.';

  @override
  String get attachSavedQueued =>
      'Saved on device. The link is added to the note after the upload.';

  @override
  String get attachTooLarge =>
      'This file is larger than 64 MB and was not attached.';

  @override
  String get attachReadFailed => 'Could not read the file.';

  @override
  String get attachWorking => 'Adding attachment…';

  @override
  String get voiceTitle => 'Voice recording';

  @override
  String get voiceReady => 'Ready to record';

  @override
  String get voiceRecording => 'Recording';

  @override
  String get voicePaused => 'Paused';

  @override
  String get voiceStopped => 'Recording stopped';

  @override
  String get voiceStart => 'Start recording';

  @override
  String get voicePause => 'Pause';

  @override
  String get voiceResume => 'Resume';

  @override
  String get voiceStop => 'Stop';

  @override
  String get voiceListen => 'Listen';

  @override
  String get voiceStopListening => 'Stop playback';

  @override
  String get voiceAttach => 'Attach';

  @override
  String get voiceDiscard => 'Discard';

  @override
  String get voiceDiscardTitle => 'Discard this recording?';

  @override
  String get voiceDiscardBody => 'The recording is deleted from this device.';

  @override
  String get voiceMicDenied =>
      'Microphone access is off. Allow it in the system settings to record.';

  @override
  String get voiceInterrupted =>
      'The recording was paused because the app was interrupted. It is kept.';

  @override
  String get voiceRecovered => 'Recovered an earlier recording.';

  @override
  String get voiceFailed => 'Could not record.';

  @override
  String voiceElapsed(String time) {
    return 'Recording time $time';
  }

  @override
  String get captureTitle => 'Shared content';

  @override
  String get captureAccount => 'Account';

  @override
  String get captureChooseAccount => 'Choose the account for this content.';

  @override
  String get captureUnknownAccount =>
      'The sender named an account that is not signed in here. Choose one.';

  @override
  String get captureNewNote => 'New note';

  @override
  String get captureAppend => 'Append to a note';

  @override
  String get captureCategory => 'Category (optional)';

  @override
  String get captureSearchTarget => 'Search notes to append to';

  @override
  String get captureNoTarget => 'Choose the note to append to.';

  @override
  String get captureNoMatches => 'No matching notes.';

  @override
  String get captureSave => 'Save on device';

  @override
  String get captureDiscard => 'Discard';

  @override
  String get captureDiscardTitle => 'Discard shared content?';

  @override
  String get captureDiscardBody =>
      'It is deleted from this device and no note is created.';

  @override
  String get captureKept =>
      'Closing this screen keeps the content until you decide.';

  @override
  String get captureNoText => 'No text, only files.';

  @override
  String get captureSaveFailed =>
      'Could not save on this device. The content is kept.';

  @override
  String captureFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0';
  }

  @override
  String importKeepAttachments(int notes, int files, int skipped) {
    return '$notes notes and $files attachments imported, $skipped files skipped.';
  }

  @override
  String get attachMoreOptions => 'More options';

  @override
  String get widgetConfigTitle => 'Configure widget';

  @override
  String get widgetTypeLabel => 'Widget type';

  @override
  String get widgetTypeList => 'Notes list';

  @override
  String get widgetTypeNote => 'Single note';

  @override
  String get widgetTypeChecklist => 'Checklist';

  @override
  String get widgetTypeQuick => 'Quick note';

  @override
  String get widgetAccountLabel => 'Account';

  @override
  String get widgetCollectionLabel => 'Notes shown';

  @override
  String get widgetNoteLabel => 'Note';

  @override
  String get widgetNoChecklistNotes => 'This account has no note with tasks.';

  @override
  String get widgetAppearanceLabel => 'Appearance';

  @override
  String get widgetAdd => 'Add widget';

  @override
  String get widgetNoAccount => 'Sign in to OwnNotes before adding a widget.';

  @override
  String get widgetSaveFailed => 'The widget could not be configured.';

  @override
  String aboutVersion(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String get aboutFormatTitle => 'Plain Markdown files';

  @override
  String get aboutFormatBody =>
      'Notes are Markdown files in the Notes folder and categories are folders. The Notes web app, the Text app and other clients open them too.';

  @override
  String get aboutServer => 'Server';

  @override
  String get aboutServerUnknown => 'The server did not report its version.';

  @override
  String get aboutWebsite => 'Website';

  @override
  String get aboutPrivacy => 'Privacy policy';

  @override
  String get aboutSupport => 'Contact support';

  @override
  String get aboutLicenses => 'Open source licenses';

  @override
  String get aboutCopyright => '© 2026 NKS Hub';

  @override
  String get rowSharedByYou => 'Shared by you';

  @override
  String get shareOtherMethods =>
      'This note also uses other sharing methods, such as links or groups. Manage those in Nextcloud.';

  @override
  String get backgroundSyncTitle => 'Background sync';

  @override
  String get backgroundSyncOff => 'Off';

  @override
  String backgroundSyncMinutes(int minutes) {
    return 'Every $minutes minutes';
  }

  @override
  String backgroundSyncHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Every $hours hours',
      one: 'Every hour',
    );
    return '$_temp0';
  }

  @override
  String get backgroundSyncWifi => 'Wi-Fi only';

  @override
  String get backgroundSyncHint =>
      'Applies while the app is closed, including widget changes. The open app uses any available network. Android decides when background work runs.';

  @override
  String get backgroundSyncLoadFailed =>
      'Cannot read sync settings. Tap to retry.';

  @override
  String get backgroundSyncSaveFailed =>
      'Could not save or apply sync settings.';
}
