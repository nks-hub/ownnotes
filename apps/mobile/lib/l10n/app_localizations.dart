import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_cs.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('cs'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'OwnNotes'**
  String get appTitle;

  /// No description provided for @addAccount.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get addAccount;

  /// No description provided for @serverUrl.
  ///
  /// In en, this message translates to:
  /// **'Nextcloud server URL'**
  String get serverUrl;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @waitingLogin.
  ///
  /// In en, this message translates to:
  /// **'Complete login in your browser…'**
  String get waitingLogin;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Check the server address and start again.'**
  String get loginFailed;

  /// No description provided for @noAccounts.
  ///
  /// In en, this message translates to:
  /// **'Connect your Nextcloud account.'**
  String get noAccounts;

  /// No description provided for @noNotes.
  ///
  /// In en, this message translates to:
  /// **'No notes yet. Create one or synchronize.'**
  String get noNotes;

  /// No description provided for @newNote.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get newNote;

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search notes'**
  String get search;

  /// No description provided for @sync.
  ///
  /// In en, this message translates to:
  /// **'Synchronize'**
  String get sync;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Synchronization failed. Local notes are preserved.'**
  String get syncFailed;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load local data.'**
  String get loadFailed;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @content.
  ///
  /// In en, this message translates to:
  /// **'Markdown text'**
  String get content;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @favorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get favorite;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit source'**
  String get edit;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save locally'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved locally'**
  String get saved;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed. Keep this editor open and copy your text.'**
  String get saveFailed;

  /// No description provided for @decisionRequired.
  ///
  /// In en, this message translates to:
  /// **'Synchronization needs a decision. Your local text is preserved.'**
  String get decisionRequired;

  /// No description provided for @readonly.
  ///
  /// In en, this message translates to:
  /// **'Read-only note'**
  String get readonly;

  /// No description provided for @selectNote.
  ///
  /// In en, this message translates to:
  /// **'Select a note'**
  String get selectNote;

  /// No description provided for @imageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Image not loaded'**
  String get imageUnavailable;

  /// No description provided for @startupFailed.
  ///
  /// In en, this message translates to:
  /// **'Local storage could not be opened. Retry without clearing app data.'**
  String get startupFailed;

  /// No description provided for @resolve.
  ///
  /// In en, this message translates to:
  /// **'Resolve synchronization'**
  String get resolve;

  /// No description provided for @readServer.
  ///
  /// In en, this message translates to:
  /// **'Compare server version'**
  String get readServer;

  /// No description provided for @localVersion.
  ///
  /// In en, this message translates to:
  /// **'Local version'**
  String get localVersion;

  /// No description provided for @serverVersion.
  ///
  /// In en, this message translates to:
  /// **'Server version'**
  String get serverVersion;

  /// No description provided for @useServer.
  ///
  /// In en, this message translates to:
  /// **'Use server version'**
  String get useServer;

  /// No description provided for @keepLocal.
  ///
  /// In en, this message translates to:
  /// **'Keep local changes'**
  String get keepLocal;

  /// No description provided for @newCopy.
  ///
  /// In en, this message translates to:
  /// **'Create a separate copy'**
  String get newCopy;

  /// No description provided for @copyWarning.
  ///
  /// In en, this message translates to:
  /// **'The server may already contain this note. Creating a separate copy can produce a duplicate. The original recovery record will be retained.'**
  String get copyWarning;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @copyMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Copy Markdown'**
  String get copyMarkdown;

  /// No description provided for @decisionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not apply the decision. Reload and compare again.'**
  String get decisionFailed;

  /// No description provided for @importKeep.
  ///
  /// In en, this message translates to:
  /// **'Import from Google Keep (Takeout .zip)'**
  String get importKeep;

  /// No description provided for @importDone.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} notes'**
  String importDone(int count);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed. The file is not a Google Takeout zip with Keep notes.'**
  String get importFailed;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this note? It is also deleted on the server.'**
  String get deleteConfirm;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allCategories;

  /// No description provided for @unsent.
  ///
  /// In en, this message translates to:
  /// **'Not sent yet: {count}'**
  String unsent(int count);

  /// No description provided for @reasonOffline.
  ///
  /// In en, this message translates to:
  /// **'No connection. Notes upload on their own when it is back.'**
  String get reasonOffline;

  /// No description provided for @reasonAuth.
  ///
  /// In en, this message translates to:
  /// **'The server refused the login. Sign in again from Accounts.'**
  String get reasonAuth;

  /// No description provided for @reasonLocked.
  ///
  /// In en, this message translates to:
  /// **'The file is locked on the server. Trying again shortly.'**
  String get reasonLocked;

  /// No description provided for @reasonStorageFull.
  ///
  /// In en, this message translates to:
  /// **'The server storage is full.'**
  String get reasonStorageFull;

  /// No description provided for @reasonServer.
  ///
  /// In en, this message translates to:
  /// **'The server answered with an error. Trying again shortly.'**
  String get reasonServer;

  /// No description provided for @sortByTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort by title'**
  String get sortByTitle;

  /// No description provided for @sortByModified.
  ///
  /// In en, this message translates to:
  /// **'Sort by last change'**
  String get sortByModified;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @monospace.
  ///
  /// In en, this message translates to:
  /// **'Monospace font in the editor'**
  String get monospace;

  /// No description provided for @textSize.
  ///
  /// In en, this message translates to:
  /// **'Editor text size'**
  String get textSize;

  /// No description provided for @appLock.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get appLock;

  /// No description provided for @appLockHint.
  ///
  /// In en, this message translates to:
  /// **'Asks for fingerprint, face or the phone PIN when you come back to the app.'**
  String get appLockHint;

  /// No description provided for @appLockUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This phone has no screen lock set up.'**
  String get appLockUnavailable;

  /// No description provided for @blockScreenshots.
  ///
  /// In en, this message translates to:
  /// **'Block screenshots'**
  String get blockScreenshots;

  /// No description provided for @exportNotes.
  ///
  /// In en, this message translates to:
  /// **'Export notes (zip)'**
  String get exportNotes;

  /// No description provided for @exportDone.
  ///
  /// In en, this message translates to:
  /// **'Exported {count} notes'**
  String exportDone(int count);

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed.'**
  String get exportFailed;

  /// No description provided for @removeAccount.
  ///
  /// In en, this message translates to:
  /// **'Remove account from this phone'**
  String get removeAccount;

  /// No description provided for @removeAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove the account from this phone and revoke its app password on the server? Notes on the server stay.'**
  String get removeAccountConfirm;

  /// No description provided for @removeAccountUnsent.
  ///
  /// In en, this message translates to:
  /// **'Remove the account? {count, plural, one{1 note is not on the server yet and will be lost.} other{{count} notes are not on the server yet and will be lost.}} You can export them first.'**
  String removeAccountUnsent(int count);

  /// No description provided for @unlockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock OwnNotes'**
  String get unlockReason;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @findInNote.
  ///
  /// In en, this message translates to:
  /// **'Find in note'**
  String get findInNote;

  /// No description provided for @findNext.
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get findNext;

  /// No description provided for @notFound.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get notFound;

  /// No description provided for @shareTo.
  ///
  /// In en, this message translates to:
  /// **'Where should the shared text go?'**
  String get shareTo;

  /// No description provided for @remoteDeleted.
  ///
  /// In en, this message translates to:
  /// **'This note was deleted on the server meanwhile. The text on this phone is kept.'**
  String get remoteDeleted;

  /// No description provided for @uploadAgain.
  ///
  /// In en, this message translates to:
  /// **'Upload it to the server again'**
  String get uploadAgain;

  /// No description provided for @deleteHere.
  ///
  /// In en, this message translates to:
  /// **'Delete on this phone too'**
  String get deleteHere;

  /// No description provided for @mergeBoth.
  ///
  /// In en, this message translates to:
  /// **'Combine both versions'**
  String get mergeBoth;

  /// No description provided for @settingSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the setting. It stays as it was.'**
  String get settingSaveFailed;

  /// No description provided for @lockUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The lock could not be checked right now. Try again.'**
  String get lockUnavailable;

  /// No description provided for @lockDeviceRemoved.
  ///
  /// In en, this message translates to:
  /// **'The screen lock of this phone was removed, so the app lock cannot work.'**
  String get lockDeviceRemoved;

  /// No description provided for @lockTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off app lock and continue'**
  String get lockTurnOff;

  /// No description provided for @editNote.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editNote;

  /// No description provided for @fmtBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get fmtBold;

  /// No description provided for @fmtItalic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get fmtItalic;

  /// No description provided for @fmtHeading.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get fmtHeading;

  /// No description provided for @fmtList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get fmtList;

  /// No description provided for @fmtChecklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get fmtChecklist;

  /// No description provided for @fmtLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get fmtLink;

  /// No description provided for @allNotes.
  ///
  /// In en, this message translates to:
  /// **'All notes'**
  String get allNotes;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @uncategorised.
  ///
  /// In en, this message translates to:
  /// **'Uncategorised'**
  String get uncategorised;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @switchAccount.
  ///
  /// In en, this message translates to:
  /// **'Switch account'**
  String get switchAccount;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'No note matches your search.'**
  String get noMatches;

  /// No description provided for @noNotesHere.
  ///
  /// In en, this message translates to:
  /// **'No notes in this category yet.'**
  String get noNotesHere;

  /// No description provided for @newNoteHere.
  ///
  /// In en, this message translates to:
  /// **'New note here'**
  String get newNoteHere;

  /// No description provided for @stateWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get stateWaiting;

  /// No description provided for @stateSending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get stateSending;

  /// No description provided for @stateNeedsDecision.
  ///
  /// In en, this message translates to:
  /// **'Needs decision'**
  String get stateNeedsDecision;

  /// No description provided for @relNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get relNow;

  /// No description provided for @relMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String relMinutes(int count);

  /// No description provided for @relHours.
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String relHours(int count);

  /// No description provided for @relYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get relYesterday;

  /// No description provided for @relDays.
  ///
  /// In en, this message translates to:
  /// **'{count} d ago'**
  String relDays(int count);

  /// No description provided for @conflictsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 note needs a decision} other{{count} notes need a decision}}'**
  String conflictsCount(int count);

  /// No description provided for @signInAgain.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get signInAgain;

  /// No description provided for @resolveNow.
  ///
  /// In en, this message translates to:
  /// **'Resolve'**
  String get resolveNow;

  /// No description provided for @syncStatus.
  ///
  /// In en, this message translates to:
  /// **'Synchronization status'**
  String get syncStatus;

  /// No description provided for @tasksDone.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} tasks done'**
  String tasksDone(int done, int total);

  /// No description provided for @hasAttachments.
  ///
  /// In en, this message translates to:
  /// **'Has attachments'**
  String get hasAttachments;

  /// No description provided for @serverEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter the address of your Nextcloud server.'**
  String get serverEmpty;

  /// No description provided for @serverInsecure.
  ///
  /// In en, this message translates to:
  /// **'Only https:// servers are supported. Your login would travel unencrypted otherwise.'**
  String get serverInsecure;

  /// No description provided for @serverInvalid.
  ///
  /// In en, this message translates to:
  /// **'That is not a valid server address. Example: cloud.example.com'**
  String get serverInvalid;

  /// No description provided for @serverNoLogin.
  ///
  /// In en, this message translates to:
  /// **'This server did not offer the Nextcloud login. Check the address.'**
  String get serverNoLogin;

  /// No description provided for @serverUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Check the address and your connection.'**
  String get serverUnreachable;

  /// No description provided for @browserUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not open the browser for the login.'**
  String get browserUnavailable;

  /// No description provided for @loginExpired.
  ///
  /// In en, this message translates to:
  /// **'The login took too long. Start again.'**
  String get loginExpired;

  /// No description provided for @scannedLoginRejected.
  ///
  /// In en, this message translates to:
  /// **'The server refused the scanned code. It may be old or revoked. Create a new one.'**
  String get scannedLoginRejected;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Your notes on your own Nextcloud'**
  String get onboardingTitle;

  /// No description provided for @onboardingBody.
  ///
  /// In en, this message translates to:
  /// **'OwnNotes syncs Markdown notes with the Nextcloud Notes app. They go to your server and nowhere else.'**
  String get onboardingBody;

  /// No description provided for @multiAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Several accounts'**
  String get multiAccountTitle;

  /// No description provided for @multiAccountBody.
  ///
  /// In en, this message translates to:
  /// **'Add more servers or users and switch between them any time.'**
  String get multiAccountBody;

  /// No description provided for @secureLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'No password in the app'**
  String get secureLoginTitle;

  /// No description provided for @secureLoginBody.
  ///
  /// In en, this message translates to:
  /// **'You sign in in your browser. The phone keeps only an app password that you can revoke.'**
  String get secureLoginBody;

  /// No description provided for @checkingServer.
  ///
  /// In en, this message translates to:
  /// **'Checking server…'**
  String get checkingServer;

  /// No description provided for @waitingForLogin.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the login'**
  String get waitingForLogin;

  /// No description provided for @waitingForLoginBody.
  ///
  /// In en, this message translates to:
  /// **'Approve the access in your browser, then come back to the app.'**
  String get waitingForLoginBody;

  /// No description provided for @savingAccount.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get savingAccount;

  /// No description provided for @scanLoginCode.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get scanLoginCode;

  /// No description provided for @scanLoginCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the login QR code from Nextcloud (Settings, Security, app passwords).'**
  String get scanLoginCodeHint;

  /// No description provided for @scanLoginCodeUnreadable.
  ///
  /// In en, this message translates to:
  /// **'That is not a Nextcloud login code.'**
  String get scanLoginCodeUnreadable;

  /// No description provided for @scanCameraDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera access is off. Allow it in the app settings to scan the code.'**
  String get scanCameraDenied;

  /// No description provided for @scanCameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The camera could not be started.'**
  String get scanCameraUnavailable;

  /// No description provided for @openAppSettings.
  ///
  /// In en, this message translates to:
  /// **'Open app settings'**
  String get openAppSettings;

  /// No description provided for @accounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accounts;

  /// No description provided for @currentAccount.
  ///
  /// In en, this message translates to:
  /// **'Current account'**
  String get currentAccount;

  /// No description provided for @accountRemovedRevoked.
  ///
  /// In en, this message translates to:
  /// **'Account removed. Its app password is revoked on the server.'**
  String get accountRemovedRevoked;

  /// No description provided for @accountRemovedNotRevoked.
  ///
  /// In en, this message translates to:
  /// **'Account removed from this phone. The server did not confirm it, so revoke the app password in Nextcloud under Settings, Security.'**
  String get accountRemovedNotRevoked;

  /// No description provided for @accountRemoveFailed.
  ///
  /// In en, this message translates to:
  /// **'The account could not be removed.'**
  String get accountRemoveFailed;

  /// No description provided for @serverCertificate.
  ///
  /// In en, this message translates to:
  /// **'The server certificate could not be verified. Check the address, or fix the certificate on the server.'**
  String get serverCertificate;

  /// No description provided for @serverTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server took too long to answer. Try again.'**
  String get serverTimeout;

  /// No description provided for @notesAppMissing.
  ///
  /// In en, this message translates to:
  /// **'The Notes app is not available on this server. Install or enable Nextcloud Notes first.'**
  String get notesAppMissing;

  /// No description provided for @reauthMismatch.
  ///
  /// In en, this message translates to:
  /// **'That login belongs to another server or user. Sign in as the same account to keep its notes.'**
  String get reauthMismatch;

  /// No description provided for @recTitle.
  ///
  /// In en, this message translates to:
  /// **'Compare versions'**
  String get recTitle;

  /// No description provided for @recTabDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get recTabDevice;

  /// No description provided for @recTabServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get recTabServer;

  /// No description provided for @recTabResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get recTabResult;

  /// No description provided for @recUseResult.
  ///
  /// In en, this message translates to:
  /// **'Use result'**
  String get recUseResult;

  /// No description provided for @recKeepSeparate.
  ///
  /// In en, this message translates to:
  /// **'Keep as separate note'**
  String get recKeepSeparate;

  /// No description provided for @recUseServer.
  ///
  /// In en, this message translates to:
  /// **'Use server version'**
  String get recUseServer;

  /// No description provided for @recLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave unresolved'**
  String get recLeave;

  /// No description provided for @recFillDevice.
  ///
  /// In en, this message translates to:
  /// **'Put device text in Result'**
  String get recFillDevice;

  /// No description provided for @recFillServer.
  ///
  /// In en, this message translates to:
  /// **'Put server text in Result'**
  String get recFillServer;

  /// No description provided for @recFillBoth.
  ///
  /// In en, this message translates to:
  /// **'Put both in Result'**
  String get recFillBoth;

  /// No description provided for @recResultReplaced.
  ///
  /// In en, this message translates to:
  /// **'Result replaced'**
  String get recResultReplaced;

  /// No description provided for @recUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get recUndo;

  /// No description provided for @recReasonConflict.
  ///
  /// In en, this message translates to:
  /// **'Both this phone and the server changed this note.'**
  String get recReasonConflict;

  /// No description provided for @recReasonUnknown.
  ///
  /// In en, this message translates to:
  /// **'The outcome of the last upload is unknown. Compare the versions before you choose.'**
  String get recReasonUnknown;

  /// No description provided for @recReasonReadonly.
  ///
  /// In en, this message translates to:
  /// **'The server no longer lets you edit this note. Your text is kept; save it as your own note.'**
  String get recReasonReadonly;

  /// No description provided for @recReasonMove.
  ///
  /// In en, this message translates to:
  /// **'A note with attachments cannot change its category here. Keep the category from the server, or save your text as a separate note.'**
  String get recReasonMove;

  /// No description provided for @recReasonGeneric.
  ///
  /// In en, this message translates to:
  /// **'This note needs your decision.'**
  String get recReasonGeneric;

  /// No description provided for @recChangeCounter.
  ///
  /// In en, this message translates to:
  /// **'Change {number} of {total}'**
  String recChangeCounter(int number, int total);

  /// No description provided for @recNoChanges.
  ///
  /// In en, this message translates to:
  /// **'Device and server text are the same.'**
  String get recNoChanges;

  /// No description provided for @recPrevChange.
  ///
  /// In en, this message translates to:
  /// **'Previous change'**
  String get recPrevChange;

  /// No description provided for @recNextChange.
  ///
  /// In en, this message translates to:
  /// **'Next change'**
  String get recNextChange;

  /// No description provided for @recServerChanged.
  ///
  /// In en, this message translates to:
  /// **'The server version changed again. The comparison now shows the newer version; your Result is kept. Review it and decide again.'**
  String get recServerChanged;

  /// No description provided for @recKept.
  ///
  /// In en, this message translates to:
  /// **'Both versions stay saved on this phone until you remove them.'**
  String get recKept;

  /// No description provided for @recSaveAsNew.
  ///
  /// In en, this message translates to:
  /// **'Save as new note'**
  String get recSaveAsNew;

  /// No description provided for @recKeepCategory.
  ///
  /// In en, this message translates to:
  /// **'Use result, keep server category'**
  String get recKeepCategory;

  /// No description provided for @recReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the server version.'**
  String get recReadFailed;

  /// No description provided for @recKeepRecovery.
  ///
  /// In en, this message translates to:
  /// **'Keep in recovery'**
  String get recKeepRecovery;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsWriting.
  ///
  /// In en, this message translates to:
  /// **'Writing'**
  String get settingsWriting;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacy;

  /// No description provided for @settingsSync.
  ///
  /// In en, this message translates to:
  /// **'Sync and storage'**
  String get settingsSync;

  /// No description provided for @settingsTransfer.
  ///
  /// In en, this message translates to:
  /// **'Import and export'**
  String get settingsTransfer;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsDeviceOnly.
  ///
  /// In en, this message translates to:
  /// **'These settings apply to this device only.'**
  String get settingsDeviceOnly;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @exportMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Export Markdown'**
  String get exportMarkdown;

  /// No description provided for @exportMarkdownHint.
  ///
  /// In en, this message translates to:
  /// **'Notes as Markdown files in a ZIP. Attachments and recovery copies are not included.'**
  String get exportMarkdownHint;

  /// No description provided for @widgetPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Home-screen widgets'**
  String get widgetPolicyTitle;

  /// No description provided for @widgetPolicyBody.
  ///
  /// In en, this message translates to:
  /// **'With app lock on, widgets hide note content, even while the app is unlocked.'**
  String get widgetPolicyBody;

  /// No description provided for @storageNotes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 note on this device} other{{count} notes on this device}}'**
  String storageNotes(int count);

  /// No description provided for @storageUnsent.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Everything is sent to the server} one{1 note not sent yet} other{{count} notes not sent yet}}'**
  String storageUnsent(int count);

  /// No description provided for @syncHint.
  ///
  /// In en, this message translates to:
  /// **'Notes sync when you open the app. The system decides when background sync runs.'**
  String get syncHint;

  /// No description provided for @exportUnsent.
  ///
  /// In en, this message translates to:
  /// **'Export unsent notes'**
  String get exportUnsent;

  /// No description provided for @removeFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Remove from this device'**
  String get removeFromDevice;

  /// No description provided for @accountDetails.
  ///
  /// In en, this message translates to:
  /// **'Account details'**
  String get accountDetails;

  /// No description provided for @accountUserLabel.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get accountUserLabel;

  /// No description provided for @accountServerLabel.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get accountServerLabel;

  /// No description provided for @accountStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get accountStatusLabel;

  /// No description provided for @accountSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get accountSignedIn;

  /// No description provided for @accountsManage.
  ///
  /// In en, this message translates to:
  /// **'Manage accounts'**
  String get accountsManage;

  /// No description provided for @accountSwitchBlocked.
  ///
  /// In en, this message translates to:
  /// **'Could not save on this device, so the account was not switched.'**
  String get accountSwitchBlocked;

  /// No description provided for @removeLocalNote.
  ///
  /// In en, this message translates to:
  /// **'Only this device is affected. Notes on the server are not deleted.'**
  String get removeLocalNote;

  /// No description provided for @loginCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sign-in cancelled. Nothing was saved.'**
  String get loginCancelled;

  /// No description provided for @reauthExplain.
  ///
  /// In en, this message translates to:
  /// **'Sign in as this account to keep its notes and unsent changes.'**
  String get reauthExplain;

  /// No description provided for @scanConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with this code?'**
  String get scanConfirmTitle;

  /// No description provided for @scanConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{user} on {host}'**
  String scanConfirmBody(String user, String host);

  /// No description provided for @scanEnterAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter server address'**
  String get scanEnterAddress;

  /// No description provided for @appLocked.
  ///
  /// In en, this message translates to:
  /// **'OwnNotes is locked'**
  String get appLocked;

  /// No description provided for @attachPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get attachPhoto;

  /// No description provided for @attachCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get attachCamera;

  /// No description provided for @attachFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get attachFile;

  /// No description provided for @attachVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get attachVoice;

  /// No description provided for @attachmentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get attachmentsTitle;

  /// No description provided for @attachmentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No attachments in this note.'**
  String get attachmentsEmpty;

  /// No description provided for @attachStored.
  ///
  /// In en, this message translates to:
  /// **'Stored on device'**
  String get attachStored;

  /// No description provided for @attachWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting to upload'**
  String get attachWaiting;

  /// No description provided for @attachWaitingNote.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the note to be uploaded'**
  String get attachWaitingNote;

  /// No description provided for @attachUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get attachUploading;

  /// No description provided for @attachOffline.
  ///
  /// In en, this message translates to:
  /// **'Available offline'**
  String get attachOffline;

  /// No description provided for @attachOnServer.
  ///
  /// In en, this message translates to:
  /// **'On the server'**
  String get attachOnServer;

  /// No description provided for @attachUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get attachUnavailable;

  /// No description provided for @attachFailedState.
  ///
  /// In en, this message translates to:
  /// **'Failed: {reason}'**
  String attachFailedState(String reason);

  /// No description provided for @attachErrOffline.
  ///
  /// In en, this message translates to:
  /// **'The server could not be reached.'**
  String get attachErrOffline;

  /// No description provided for @attachErrAuth.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to upload.'**
  String get attachErrAuth;

  /// No description provided for @attachErrTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The server refused the file as too large.'**
  String get attachErrTooLarge;

  /// No description provided for @attachErrDenied.
  ///
  /// In en, this message translates to:
  /// **'The server did not allow the upload.'**
  String get attachErrDenied;

  /// No description provided for @attachErrNoteGone.
  ///
  /// In en, this message translates to:
  /// **'The note no longer exists on the server.'**
  String get attachErrNoteGone;

  /// No description provided for @attachErrServer.
  ///
  /// In en, this message translates to:
  /// **'The server returned an error.'**
  String get attachErrServer;

  /// No description provided for @attachRemoveQueue.
  ///
  /// In en, this message translates to:
  /// **'Remove from queue'**
  String get attachRemoveQueue;

  /// No description provided for @attachRemoveLink.
  ///
  /// In en, this message translates to:
  /// **'Remove link from note'**
  String get attachRemoveLink;

  /// No description provided for @attachRemoveLinkHelp.
  ///
  /// In en, this message translates to:
  /// **'Removing the link only edits this note. The file stays on the server.'**
  String get attachRemoveLinkHelp;

  /// No description provided for @attachDeleteFile.
  ///
  /// In en, this message translates to:
  /// **'Delete file on server'**
  String get attachDeleteFile;

  /// No description provided for @attachDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the file on the server?'**
  String get attachDeleteTitle;

  /// No description provided for @attachDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The file is removed from the server for good. Other notes and devices that link to it will show a missing file.'**
  String get attachDeleteBody;

  /// No description provided for @attachDeleteFileOnly.
  ///
  /// In en, this message translates to:
  /// **'Delete file'**
  String get attachDeleteFileOnly;

  /// No description provided for @attachDeleteFileAndLink.
  ///
  /// In en, this message translates to:
  /// **'Delete file and link'**
  String get attachDeleteFileAndLink;

  /// No description provided for @attachDeleteUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This server version cannot delete attachments. Remove the link instead; the file stays on the server.'**
  String get attachDeleteUnsupported;

  /// No description provided for @attachDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the file.'**
  String get attachDeleteFailed;

  /// No description provided for @attachKeepOffline.
  ///
  /// In en, this message translates to:
  /// **'Keep offline'**
  String get attachKeepOffline;

  /// No description provided for @attachUploadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get attachUploadFailedTitle;

  /// No description provided for @attachKeepForLater.
  ///
  /// In en, this message translates to:
  /// **'Keep for later'**
  String get attachKeepForLater;

  /// No description provided for @attachSavedWaiting.
  ///
  /// In en, this message translates to:
  /// **'Saved on device. It uploads once the note is on the server, and the link is added to the note.'**
  String get attachSavedWaiting;

  /// No description provided for @attachSavedQueued.
  ///
  /// In en, this message translates to:
  /// **'Saved on device. The link is added to the note after the upload.'**
  String get attachSavedQueued;

  /// No description provided for @attachTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This file is larger than 64 MB and was not attached.'**
  String get attachTooLarge;

  /// No description provided for @attachReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the file.'**
  String get attachReadFailed;

  /// No description provided for @attachWorking.
  ///
  /// In en, this message translates to:
  /// **'Adding attachment…'**
  String get attachWorking;

  /// No description provided for @voiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice recording'**
  String get voiceTitle;

  /// No description provided for @voiceReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to record'**
  String get voiceReady;

  /// No description provided for @voiceRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get voiceRecording;

  /// No description provided for @voicePaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get voicePaused;

  /// No description provided for @voiceStopped.
  ///
  /// In en, this message translates to:
  /// **'Recording stopped'**
  String get voiceStopped;

  /// No description provided for @voiceStart.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get voiceStart;

  /// No description provided for @voicePause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get voicePause;

  /// No description provided for @voiceResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get voiceResume;

  /// No description provided for @voiceStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get voiceStop;

  /// No description provided for @voiceListen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get voiceListen;

  /// No description provided for @voiceStopListening.
  ///
  /// In en, this message translates to:
  /// **'Stop playback'**
  String get voiceStopListening;

  /// No description provided for @voiceAttach.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get voiceAttach;

  /// No description provided for @voiceDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get voiceDiscard;

  /// No description provided for @voiceDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this recording?'**
  String get voiceDiscardTitle;

  /// No description provided for @voiceDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'The recording is deleted from this device.'**
  String get voiceDiscardBody;

  /// No description provided for @voiceMicDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is off. Allow it in the system settings to record.'**
  String get voiceMicDenied;

  /// No description provided for @voiceInterrupted.
  ///
  /// In en, this message translates to:
  /// **'The recording was paused because the app was interrupted. It is kept.'**
  String get voiceInterrupted;

  /// No description provided for @voiceRecovered.
  ///
  /// In en, this message translates to:
  /// **'Recovered an earlier recording.'**
  String get voiceRecovered;

  /// No description provided for @voiceFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not record.'**
  String get voiceFailed;

  /// No description provided for @voiceElapsed.
  ///
  /// In en, this message translates to:
  /// **'Recording time {time}'**
  String voiceElapsed(String time);

  /// No description provided for @captureTitle.
  ///
  /// In en, this message translates to:
  /// **'Shared content'**
  String get captureTitle;

  /// No description provided for @captureAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get captureAccount;

  /// No description provided for @captureChooseAccount.
  ///
  /// In en, this message translates to:
  /// **'Choose the account for this content.'**
  String get captureChooseAccount;

  /// No description provided for @captureUnknownAccount.
  ///
  /// In en, this message translates to:
  /// **'The sender named an account that is not signed in here. Choose one.'**
  String get captureUnknownAccount;

  /// No description provided for @captureNewNote.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get captureNewNote;

  /// No description provided for @captureAppend.
  ///
  /// In en, this message translates to:
  /// **'Append to a note'**
  String get captureAppend;

  /// No description provided for @captureCategory.
  ///
  /// In en, this message translates to:
  /// **'Category (optional)'**
  String get captureCategory;

  /// No description provided for @captureSearchTarget.
  ///
  /// In en, this message translates to:
  /// **'Search notes to append to'**
  String get captureSearchTarget;

  /// No description provided for @captureNoTarget.
  ///
  /// In en, this message translates to:
  /// **'Choose the note to append to.'**
  String get captureNoTarget;

  /// No description provided for @captureNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching notes.'**
  String get captureNoMatches;

  /// No description provided for @captureSave.
  ///
  /// In en, this message translates to:
  /// **'Save on device'**
  String get captureSave;

  /// No description provided for @captureDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get captureDiscard;

  /// No description provided for @captureDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard shared content?'**
  String get captureDiscardTitle;

  /// No description provided for @captureDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'It is deleted from this device and no note is created.'**
  String get captureDiscardBody;

  /// No description provided for @captureKept.
  ///
  /// In en, this message translates to:
  /// **'Closing this screen keeps the content until you decide.'**
  String get captureKept;

  /// No description provided for @captureNoText.
  ///
  /// In en, this message translates to:
  /// **'No text, only files.'**
  String get captureNoText;

  /// No description provided for @captureSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save on this device. The content is kept.'**
  String get captureSaveFailed;

  /// No description provided for @captureFiles.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{count} files}}'**
  String captureFiles(int count);

  /// No description provided for @importKeepAttachments.
  ///
  /// In en, this message translates to:
  /// **'{notes} notes and {files} attachments imported, {skipped} files skipped.'**
  String importKeepAttachments(int notes, int files, int skipped);

  /// No description provided for @attachMoreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get attachMoreOptions;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['cs', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'cs':
      return AppLocalizationsCs();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
