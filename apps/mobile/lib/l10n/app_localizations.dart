import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_cs.dart';
import 'app_localizations_de.dart';
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
    Locale('de'),
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
  /// **'Continue'**
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
  /// **'The sign-in page could not be opened.'**
  String get browserUnavailable;

  /// No description provided for @loginExpired.
  ///
  /// In en, this message translates to:
  /// **'The login took too long. Start again.'**
  String get loginExpired;

  /// No description provided for @scannedLoginRejected.
  ///
  /// In en, this message translates to:
  /// **'The scanned login code could not be used. Create a new one on the server.'**
  String get scannedLoginRejected;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Your notes, one app'**
  String get onboardingTitle;

  /// No description provided for @onboardingBody.
  ///
  /// In en, this message translates to:
  /// **'Connect any supported Nextcloud server. Accounts, their stored data and background work stay strictly separated.'**
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
  /// **'Checking the server…'**
  String get checkingServer;

  /// No description provided for @waitingForLogin.
  ///
  /// In en, this message translates to:
  /// **'Finish signing in in your browser'**
  String get waitingForLogin;

  /// No description provided for @waitingForLoginBody.
  ///
  /// In en, this message translates to:
  /// **'This screen will continue automatically after Nextcloud approves the app.'**
  String get waitingForLoginBody;

  /// No description provided for @savingAccount.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get savingAccount;

  /// Button that opens the camera to scan a Nextcloud login QR code
  ///
  /// In en, this message translates to:
  /// **'Scan a login code'**
  String get scanLoginCode;

  /// No description provided for @scanLoginCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the QR code your server shows under Settings, Security, Create new app password.'**
  String get scanLoginCodeHint;

  /// No description provided for @scanLoginCodeUnreadable.
  ///
  /// In en, this message translates to:
  /// **'This is not a Nextcloud login code.'**
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
  /// **'Open settings'**
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

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// No description provided for @dockFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get dockFormat;

  /// No description provided for @dockTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get dockTask;

  /// No description provided for @dockAttach.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get dockAttach;

  /// No description provided for @dockInsert.
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get dockInsert;

  /// No description provided for @fmtStrike.
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get fmtStrike;

  /// No description provided for @fmtQuote.
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get fmtQuote;

  /// No description provided for @fmtNumbered.
  ///
  /// In en, this message translates to:
  /// **'Numbered list'**
  String get fmtNumbered;

  /// No description provided for @fmtCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get fmtCode;

  /// No description provided for @fmtIndent.
  ///
  /// In en, this message translates to:
  /// **'Indent'**
  String get fmtIndent;

  /// No description provided for @fmtOutdent.
  ///
  /// In en, this message translates to:
  /// **'Outdent'**
  String get fmtOutdent;

  /// No description provided for @insertMention.
  ///
  /// In en, this message translates to:
  /// **'Mention'**
  String get insertMention;

  /// No description provided for @insertEmoji.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get insertEmoji;

  /// No description provided for @smartPicker.
  ///
  /// In en, this message translates to:
  /// **'Smart picker'**
  String get smartPicker;

  /// No description provided for @smartPickerNone.
  ///
  /// In en, this message translates to:
  /// **'This server offers nothing the smart picker can search.'**
  String get smartPickerNone;

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

  /// No description provided for @suggestSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get suggestSearching;

  /// No description provided for @suggestError.
  ///
  /// In en, this message translates to:
  /// **'Suggestions are not available right now. You can keep writing.'**
  String get suggestError;

  /// No description provided for @suggestCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 suggestion} other{{count} suggestions}}'**
  String suggestCount(int count);

  /// No description provided for @suggestInsert.
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get suggestInsert;

  /// No description provided for @cmdToday.
  ///
  /// In en, this message translates to:
  /// **'Today\'s date'**
  String get cmdToday;

  /// No description provided for @cmdTime.
  ///
  /// In en, this message translates to:
  /// **'Current time'**
  String get cmdTime;

  /// No description provided for @cmdTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get cmdTable;

  /// No description provided for @cmdDivider.
  ///
  /// In en, this message translates to:
  /// **'Divider'**
  String get cmdDivider;

  /// No description provided for @calloutInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get calloutInfo;

  /// No description provided for @calloutWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get calloutWarning;

  /// No description provided for @calloutError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get calloutError;

  /// No description provided for @calloutSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get calloutSuccess;

  /// No description provided for @detailsDefault.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get detailsDefault;

  /// No description provided for @mentionLabel.
  ///
  /// In en, this message translates to:
  /// **'Mention: {name}'**
  String mentionLabel(String name);

  /// No description provided for @attachmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Attachment: {name}'**
  String attachmentLabel(String name);

  /// No description provided for @tableLabel.
  ///
  /// In en, this message translates to:
  /// **'Table with {rows, plural, one{1 row} other{{rows} rows}} and {columns, plural, one{1 column} other{{columns} columns}}'**
  String tableLabel(int rows, int columns);

  /// No description provided for @editSection.
  ///
  /// In en, this message translates to:
  /// **'Edit this section'**
  String get editSection;

  /// No description provided for @checklistMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Markdown'**
  String get checklistMarkdown;

  /// No description provided for @checklistEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet. Add the first item below.'**
  String get checklistEmpty;

  /// No description provided for @checklistAdd.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get checklistAdd;

  /// No description provided for @checklistCompletedGroup.
  ///
  /// In en, this message translates to:
  /// **'Completed ({count})'**
  String checklistCompletedGroup(int count);

  /// No description provided for @clearCompleted.
  ///
  /// In en, this message translates to:
  /// **'Clear completed items'**
  String get clearCompleted;

  /// No description provided for @clearCompletedConfirm.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Remove 1 completed item from the note?} other{Remove {count} completed items from the note?}}'**
  String clearCompletedConfirm(int count);

  /// No description provided for @clearedCompleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 item removed} other{{count} items removed}}'**
  String clearedCompleted(int count);

  /// No description provided for @checklistPosition.
  ///
  /// In en, this message translates to:
  /// **'{position} of {total}'**
  String checklistPosition(int position, int total);

  /// No description provided for @checklistItemMenu.
  ///
  /// In en, this message translates to:
  /// **'Item options'**
  String get checklistItemMenu;

  /// No description provided for @moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDown;

  /// No description provided for @shareTitle.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareTitle;

  /// No description provided for @shareSendCopy.
  ///
  /// In en, this message translates to:
  /// **'Send a copy'**
  String get shareSendCopy;

  /// No description provided for @shareAsText.
  ///
  /// In en, this message translates to:
  /// **'Send as text'**
  String get shareAsText;

  /// No description provided for @shareAsFile.
  ///
  /// In en, this message translates to:
  /// **'Send as Markdown file'**
  String get shareAsFile;

  /// No description provided for @shareWithPeople.
  ///
  /// In en, this message translates to:
  /// **'Share with people'**
  String get shareWithPeople;

  /// No description provided for @sharePeopleWithAccess.
  ///
  /// In en, this message translates to:
  /// **'People with access'**
  String get sharePeopleWithAccess;

  /// No description provided for @shareSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search people'**
  String get shareSearchHint;

  /// No description provided for @sharePermissionView.
  ///
  /// In en, this message translates to:
  /// **'Can view'**
  String get sharePermissionView;

  /// No description provided for @sharePermissionEdit.
  ///
  /// In en, this message translates to:
  /// **'Can edit'**
  String get sharePermissionEdit;

  /// No description provided for @shareRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove access'**
  String get shareRemove;

  /// No description provided for @sharePending.
  ///
  /// In en, this message translates to:
  /// **'Sharing…'**
  String get sharePending;

  /// No description provided for @shareRemoving.
  ///
  /// In en, this message translates to:
  /// **'Removing access…'**
  String get shareRemoving;

  /// No description provided for @shareFailed.
  ///
  /// In en, this message translates to:
  /// **'This did not work. Check the connection and try again.'**
  String get shareFailed;

  /// No description provided for @shareNotUploaded.
  ///
  /// In en, this message translates to:
  /// **'This note is not on the server yet. It is uploaded first, then it can be shared.'**
  String get shareNotUploaded;

  /// No description provided for @shareUploadFirst.
  ///
  /// In en, this message translates to:
  /// **'Upload and continue'**
  String get shareUploadFirst;

  /// No description provided for @shareUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading the note…'**
  String get shareUploading;

  /// No description provided for @shareUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'The note could not be uploaded yet. It stays saved on this device.'**
  String get shareUploadFailed;

  /// No description provided for @shareIncoming.
  ///
  /// In en, this message translates to:
  /// **'Somebody shared this note with you. Only its owner can share it further.'**
  String get shareIncoming;

  /// No description provided for @shareAttachmentsWarning.
  ///
  /// In en, this message translates to:
  /// **'This note has attachments. People you share it with may not be able to open them.'**
  String get shareAttachmentsWarning;

  /// No description provided for @shareNone.
  ///
  /// In en, this message translates to:
  /// **'Not shared with anyone yet.'**
  String get shareNone;

  /// No description provided for @shareNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching people.'**
  String get shareNoResults;

  /// No description provided for @shareChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking the shares…'**
  String get shareChecking;

  /// No description provided for @shareWithName.
  ///
  /// In en, this message translates to:
  /// **'Share with {name}'**
  String shareWithName(String name);

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @openDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get openDetails;

  /// No description provided for @unfavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get unfavorite;

  /// No description provided for @openChecklist.
  ///
  /// In en, this message translates to:
  /// **'Open checklist'**
  String get openChecklist;

  /// No description provided for @attachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get attachments;

  /// No description provided for @historyRecovery.
  ///
  /// In en, this message translates to:
  /// **'History and recovery'**
  String get historyRecovery;

  /// No description provided for @exportNote.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportNote;

  /// No description provided for @findCount.
  ///
  /// In en, this message translates to:
  /// **'{index} of {total}'**
  String findCount(int index, int total);

  /// No description provided for @findPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous match'**
  String get findPrevious;

  /// No description provided for @saveFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not save on this device'**
  String get saveFailedTitle;

  /// No description provided for @noteUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The server could not hand out this note\'s text. Your last copy is kept. Retry, or copy your text.'**
  String get noteUnreadable;

  /// No description provided for @exportDraft.
  ///
  /// In en, this message translates to:
  /// **'Export draft'**
  String get exportDraft;

  /// No description provided for @attachmentsNone.
  ///
  /// In en, this message translates to:
  /// **'No attachments in this note.'**
  String get attachmentsNone;

  /// No description provided for @attachmentImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get attachmentImage;

  /// No description provided for @attachmentFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get attachmentFile;

  /// No description provided for @templates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get templates;

  /// No description provided for @templatesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No templates yet.'**
  String get templatesEmpty;

  /// No description provided for @templatesManage.
  ///
  /// In en, this message translates to:
  /// **'Manage templates'**
  String get templatesManage;

  /// No description provided for @templateNew.
  ///
  /// In en, this message translates to:
  /// **'New template'**
  String get templateNew;

  /// No description provided for @templateEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit template'**
  String get templateEdit;

  /// No description provided for @templateSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get templateSave;

  /// No description provided for @templateName.
  ///
  /// In en, this message translates to:
  /// **'Template name'**
  String get templateName;

  /// No description provided for @templatePlaceholders.
  ///
  /// In en, this message translates to:
  /// **'Filled in when a note is created: {placeholders}'**
  String templatePlaceholders(String placeholders);

  /// No description provided for @templateDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete the template \"{name}\"?'**
  String templateDeleteConfirm(String name);

  /// No description provided for @templatesDeviceOnly.
  ///
  /// In en, this message translates to:
  /// **'Templates and the daily note stay on this device.'**
  String get templatesDeviceOnly;

  /// No description provided for @dailyNote.
  ///
  /// In en, this message translates to:
  /// **'Daily note'**
  String get dailyNote;

  /// No description provided for @dailyNotePattern.
  ///
  /// In en, this message translates to:
  /// **'Title pattern (for example yyyy-MM-dd)'**
  String get dailyNotePattern;

  /// No description provided for @dailyNoteTemplate.
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get dailyNoteTemplate;

  /// No description provided for @dailyNoteNoTemplate.
  ///
  /// In en, this message translates to:
  /// **'No template'**
  String get dailyNoteNoTemplate;

  /// No description provided for @dailyNotePreview.
  ///
  /// In en, this message translates to:
  /// **'Today: \"{title}\" in {category}'**
  String dailyNotePreview(String title, String category);

  /// No description provided for @categoriesMenu.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesMenu;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @syncDetails.
  ///
  /// In en, this message translates to:
  /// **'Sync details'**
  String get syncDetails;

  /// No description provided for @selectNotes.
  ///
  /// In en, this message translates to:
  /// **'Select notes'**
  String get selectNotes;

  /// No description provided for @sortAndFilter.
  ///
  /// In en, this message translates to:
  /// **'Sort and filter'**
  String get sortAndFilter;

  /// No description provided for @accountSyncHint.
  ///
  /// In en, this message translates to:
  /// **'Sync details for {account}'**
  String accountSyncHint(String account);

  /// No description provided for @checkingForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates'**
  String get checkingForUpdates;

  /// No description provided for @syncSavedWaiting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Saved on device · 1 waiting} other{Saved on device · {count} waiting}}'**
  String syncSavedWaiting(int count);

  /// No description provided for @syncUploading.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Uploading 1 change} other{Uploading {count} changes}}'**
  String syncUploading(int count);

  /// No description provided for @syncUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Up to date · checked {time}'**
  String syncUpToDate(String time);

  /// No description provided for @syncOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline · changes saved on device'**
  String get syncOffline;

  /// No description provided for @syncOfflineShort.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get syncOfflineShort;

  /// No description provided for @syncAuthFailure.
  ///
  /// In en, this message translates to:
  /// **'Sign in again · local notes retained'**
  String get syncAuthFailure;

  /// No description provided for @syncSaveFailure.
  ///
  /// In en, this message translates to:
  /// **'Could not save on this device'**
  String get syncSaveFailure;

  /// No description provided for @needsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get needsAttention;

  /// No description provided for @sharedWithMe.
  ///
  /// In en, this message translates to:
  /// **'Shared with me'**
  String get sharedWithMe;

  /// No description provided for @savedViews.
  ///
  /// In en, this message translates to:
  /// **'Saved views'**
  String get savedViews;

  /// No description provided for @onThisDevice.
  ///
  /// In en, this message translates to:
  /// **'On this device'**
  String get onThisDevice;

  /// No description provided for @saveView.
  ///
  /// In en, this message translates to:
  /// **'Save this view'**
  String get saveView;

  /// No description provided for @saveViewName.
  ///
  /// In en, this message translates to:
  /// **'Name of the view'**
  String get saveViewName;

  /// No description provided for @deleteView.
  ///
  /// In en, this message translates to:
  /// **'Delete saved view'**
  String get deleteView;

  /// No description provided for @sheetUploads.
  ///
  /// In en, this message translates to:
  /// **'Uploads'**
  String get sheetUploads;

  /// No description provided for @sheetDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get sheetDownloads;

  /// No description provided for @sheetDecisions.
  ///
  /// In en, this message translates to:
  /// **'Decisions'**
  String get sheetDecisions;

  /// No description provided for @sheetDeletions.
  ///
  /// In en, this message translates to:
  /// **'Deletions'**
  String get sheetDeletions;

  /// No description provided for @uploadsNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing waiting to upload'**
  String get uploadsNone;

  /// No description provided for @downloadsNever.
  ///
  /// In en, this message translates to:
  /// **'Not checked yet'**
  String get downloadsNever;

  /// No description provided for @downloadsUnreadable.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 note cannot be refreshed} other{{count} notes cannot be refreshed}}'**
  String downloadsUnreadable(int count);

  /// No description provided for @downloadsMissing.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 note is no longer listed by the server} other{{count} notes are no longer listed by the server}}'**
  String downloadsMissing(int count);

  /// No description provided for @decisionsNone.
  ///
  /// In en, this message translates to:
  /// **'No notes need a decision'**
  String get decisionsNone;

  /// No description provided for @deletionsNone.
  ///
  /// In en, this message translates to:
  /// **'No deletions waiting'**
  String get deletionsNone;

  /// No description provided for @deletionsWaiting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 deletion waiting for the server} other{{count} deletions waiting for the server}}'**
  String deletionsWaiting(int count);

  /// No description provided for @deletionsFailed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 deletion failed} other{{count} deletions failed}}'**
  String deletionsFailed(int count);

  /// No description provided for @reviewItems.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get reviewItems;

  /// No description provided for @rowSavedWaiting.
  ///
  /// In en, this message translates to:
  /// **'Saved on device · Waiting to upload'**
  String get rowSavedWaiting;

  /// No description provided for @rowUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading changes'**
  String get rowUploading;

  /// No description provided for @rowNeedsDecision.
  ///
  /// In en, this message translates to:
  /// **'Needs your decision'**
  String get rowNeedsDecision;

  /// No description provided for @rowUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Cannot refresh this note'**
  String get rowUnavailable;

  /// No description provided for @rowMissing.
  ///
  /// In en, this message translates to:
  /// **'No longer listed by the server'**
  String get rowMissing;

  /// No description provided for @rowSharedEdit.
  ///
  /// In en, this message translates to:
  /// **'Shared · Can edit'**
  String get rowSharedEdit;

  /// No description provided for @rowSharedView.
  ///
  /// In en, this message translates to:
  /// **'Shared · View only'**
  String get rowSharedView;

  /// No description provided for @attachmentsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 attachment} other{{count} attachments}}'**
  String attachmentsCount(int count);

  /// No description provided for @rowMenu.
  ///
  /// In en, this message translates to:
  /// **'Actions for {title}'**
  String rowMenu(String title);

  /// No description provided for @openNote.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openNote;

  /// No description provided for @moveNote.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get moveNote;

  /// No description provided for @rowDeletionWaiting.
  ///
  /// In en, this message translates to:
  /// **'Deletion waiting'**
  String get rowDeletionWaiting;

  /// No description provided for @rowDeletionFailed.
  ///
  /// In en, this message translates to:
  /// **'Deletion failed · {reason}'**
  String rowDeletionFailed(String reason);

  /// No description provided for @undoAction.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undoAction;

  /// No description provided for @saveCopy.
  ///
  /// In en, this message translates to:
  /// **'Save a copy'**
  String get saveCopy;

  /// No description provided for @categoryCount.
  ///
  /// In en, this message translates to:
  /// **'{name}, {count, plural, one{1 note} other{{count} notes}} including subcategories'**
  String categoryCount(String name, int count);

  /// No description provided for @expandCategory.
  ///
  /// In en, this message translates to:
  /// **'Expand {name}'**
  String expandCategory(String name);

  /// No description provided for @collapseCategory.
  ///
  /// In en, this message translates to:
  /// **'Collapse {name}'**
  String collapseCategory(String name);

  /// No description provided for @openSubtree.
  ///
  /// In en, this message translates to:
  /// **'Show {name} on its own'**
  String openSubtree(String name);

  /// No description provided for @allCategoriesUp.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get allCategoriesUp;

  /// No description provided for @createNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get createNote;

  /// No description provided for @createChecklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get createChecklist;

  /// No description provided for @createTemplate.
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get createTemplate;

  /// No description provided for @createDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily note'**
  String get createDaily;

  /// No description provided for @createWhere.
  ///
  /// In en, this message translates to:
  /// **'Which category should the note go to?'**
  String get createWhere;

  /// No description provided for @createNoteAction.
  ///
  /// In en, this message translates to:
  /// **'Create note'**
  String get createNoteAction;

  /// No description provided for @createHere.
  ///
  /// In en, this message translates to:
  /// **'Create here'**
  String get createHere;

  /// No description provided for @filterTasks.
  ///
  /// In en, this message translates to:
  /// **'Unfinished tasks'**
  String get filterTasks;

  /// No description provided for @filterAttachments.
  ///
  /// In en, this message translates to:
  /// **'With attachments'**
  String get filterAttachments;

  /// No description provided for @filterShared.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get filterShared;

  /// No description provided for @filterWaiting.
  ///
  /// In en, this message translates to:
  /// **'Not uploaded yet'**
  String get filterWaiting;

  /// No description provided for @filterDecision.
  ///
  /// In en, this message translates to:
  /// **'Needs a decision'**
  String get filterDecision;

  /// No description provided for @filterSharing.
  ///
  /// In en, this message translates to:
  /// **'Sharing'**
  String get filterSharing;

  /// No description provided for @filterSync.
  ///
  /// In en, this message translates to:
  /// **'Sync state'**
  String get filterSync;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @sortTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortTitle;

  /// No description provided for @sortFavoritesFirst.
  ///
  /// In en, this message translates to:
  /// **'Favorites first'**
  String get sortFavoritesFirst;

  /// No description provided for @emptyFavoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get emptyFavoritesTitle;

  /// No description provided for @emptyFavoritesBody.
  ///
  /// In en, this message translates to:
  /// **'Star a note to find it here. Use the note menu or swipe a note.'**
  String get emptyFavoritesBody;

  /// No description provided for @emptySharedTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing shared with you'**
  String get emptySharedTitle;

  /// No description provided for @emptySharedBody.
  ///
  /// In en, this message translates to:
  /// **'Notes that other people share with this account appear here.'**
  String get emptySharedBody;

  /// No description provided for @emptyAttentionTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing needs your attention'**
  String get emptyAttentionTitle;

  /// No description provided for @emptyAttentionBody.
  ///
  /// In en, this message translates to:
  /// **'Decisions, failed deletions and notes that cannot be refreshed appear here.'**
  String get emptyAttentionBody;

  /// No description provided for @emptyCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'{category} is empty'**
  String emptyCategoryTitle(String category);

  /// No description provided for @downloadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloading your notes'**
  String get downloadingTitle;

  /// No description provided for @downloadingBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 note downloaded so far} other{{count} notes downloaded so far}}'**
  String downloadingBody(int count);

  /// No description provided for @connectNextcloud.
  ///
  /// In en, this message translates to:
  /// **'Connect Nextcloud'**
  String get connectNextcloud;

  /// No description provided for @scanLoginQr.
  ///
  /// In en, this message translates to:
  /// **'Scan login QR code'**
  String get scanLoginQr;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 selected} other{{count} selected}}'**
  String selectedCount(int count);

  /// No description provided for @bulkFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get bulkFavorite;

  /// No description provided for @bulkUnfavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get bulkUnfavorite;

  /// No description provided for @bulkMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get bulkMove;

  /// No description provided for @bulkExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get bulkExport;

  /// No description provided for @bulkMixedMove.
  ///
  /// In en, this message translates to:
  /// **'Move is unavailable because some selected notes are read-only, shared or have attachments.'**
  String get bulkMixedMove;

  /// No description provided for @bulkMixedDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete is unavailable because some selected notes are read-only, shared or being sent.'**
  String get bulkMixedDelete;

  /// No description provided for @bulkMixedFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite is unavailable because some selected notes are shared.'**
  String get bulkMixedFavorite;

  /// No description provided for @bulkDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Delete 1 note?} other{Delete {count} notes?}}'**
  String bulkDeleteConfirm(int count);

  /// No description provided for @bulkDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The notes are also deleted on the server. You can undo this until the server has carried it out.'**
  String get bulkDeleteBody;

  /// No description provided for @notesDeleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 note deleted} other{{count} notes deleted}}'**
  String notesDeleted(int count);

  /// No description provided for @notesMoved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 note moved} other{{count} notes moved}}'**
  String notesMoved(int count);

  /// No description provided for @bulkFailed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 note could not be changed} other{{count} notes could not be changed}}'**
  String bulkFailed(int count);

  /// No description provided for @moveTitle.
  ///
  /// In en, this message translates to:
  /// **'Move to category'**
  String get moveTitle;

  /// No description provided for @moveNewCategory.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get moveNewCategory;

  /// No description provided for @moveNewCategoryHint.
  ///
  /// In en, this message translates to:
  /// **'Name, use / for subcategories'**
  String get moveNewCategoryHint;

  /// No description provided for @clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Cancel selection'**
  String get clearSelection;

  /// No description provided for @rowFavoriteOn.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get rowFavoriteOn;

  /// No description provided for @rowFavoriteOff.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get rowFavoriteOff;

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

  /// No description provided for @widgetConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Configure widget'**
  String get widgetConfigTitle;

  /// No description provided for @widgetTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Widget type'**
  String get widgetTypeLabel;

  /// No description provided for @widgetTypeList.
  ///
  /// In en, this message translates to:
  /// **'Notes list'**
  String get widgetTypeList;

  /// No description provided for @widgetTypeNote.
  ///
  /// In en, this message translates to:
  /// **'Single note'**
  String get widgetTypeNote;

  /// No description provided for @widgetTypeChecklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get widgetTypeChecklist;

  /// No description provided for @widgetTypeQuick.
  ///
  /// In en, this message translates to:
  /// **'Quick note'**
  String get widgetTypeQuick;

  /// No description provided for @widgetAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get widgetAccountLabel;

  /// No description provided for @widgetCollectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes shown'**
  String get widgetCollectionLabel;

  /// No description provided for @widgetNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get widgetNoteLabel;

  /// No description provided for @widgetNoChecklistNotes.
  ///
  /// In en, this message translates to:
  /// **'This account has no note with tasks.'**
  String get widgetNoChecklistNotes;

  /// No description provided for @widgetAppearanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get widgetAppearanceLabel;

  /// No description provided for @widgetAdd.
  ///
  /// In en, this message translates to:
  /// **'Add widget'**
  String get widgetAdd;

  /// No description provided for @widgetNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in to OwnNotes before adding a widget.'**
  String get widgetNoAccount;

  /// No description provided for @widgetSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The widget could not be configured.'**
  String get widgetSaveFailed;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version} ({build})'**
  String aboutVersion(String version, String build);

  /// No description provided for @aboutFormatTitle.
  ///
  /// In en, this message translates to:
  /// **'Plain Markdown files'**
  String get aboutFormatTitle;

  /// No description provided for @aboutFormatBody.
  ///
  /// In en, this message translates to:
  /// **'Notes are Markdown files in the Notes folder and categories are folders. The Notes web app, the Text app and other clients open them too.'**
  String get aboutFormatBody;

  /// No description provided for @aboutServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get aboutServer;

  /// No description provided for @aboutServerUnknown.
  ///
  /// In en, this message translates to:
  /// **'The server did not report its version.'**
  String get aboutServerUnknown;

  /// No description provided for @aboutWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get aboutWebsite;

  /// No description provided for @aboutPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get aboutPrivacy;

  /// No description provided for @aboutSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get aboutSupport;

  /// No description provided for @aboutLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open source licenses'**
  String get aboutLicenses;

  /// No description provided for @aboutCopyright.
  ///
  /// In en, this message translates to:
  /// **'© 2026 NKS Hub'**
  String get aboutCopyright;

  /// No description provided for @rowSharedByYou.
  ///
  /// In en, this message translates to:
  /// **'Shared by you'**
  String get rowSharedByYou;

  /// No description provided for @shareOtherMethods.
  ///
  /// In en, this message translates to:
  /// **'This note also uses other sharing methods, such as folders, links or groups. Manage those in Nextcloud.'**
  String get shareOtherMethods;

  /// No description provided for @backgroundSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Background sync'**
  String get backgroundSyncTitle;

  /// No description provided for @backgroundSyncOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get backgroundSyncOff;

  /// No description provided for @backgroundSyncMinutes.
  ///
  /// In en, this message translates to:
  /// **'Every {minutes} minutes'**
  String backgroundSyncMinutes(int minutes);

  /// No description provided for @backgroundSyncHours.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, one {Every hour} other {Every {hours} hours}}'**
  String backgroundSyncHours(int hours);

  /// No description provided for @backgroundSyncWifi.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi only'**
  String get backgroundSyncWifi;

  /// No description provided for @backgroundSyncHint.
  ///
  /// In en, this message translates to:
  /// **'Applies while the app is closed, including widget changes. The open app uses any available network. Android decides when background work runs.'**
  String get backgroundSyncHint;

  /// No description provided for @backgroundSyncLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot read sync settings. Tap to retry.'**
  String get backgroundSyncLoadFailed;

  /// No description provided for @backgroundSyncSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save or apply sync settings.'**
  String get backgroundSyncSaveFailed;

  /// No description provided for @telemetryTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics and app usage'**
  String get telemetryTitle;

  /// No description provided for @telemetryDescription.
  ///
  /// In en, this message translates to:
  /// **'Sends errors and screen names to Sentry and Rybbit. Note text and credentials are excluded. Disabling takes effect now; enabling takes effect after restarting.'**
  String get telemetryDescription;

  /// No description provided for @telemetryRestart.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics will start the next time you open the app.'**
  String get telemetryRestart;

  /// No description provided for @telemetrySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the diagnostics setting.'**
  String get telemetrySaveFailed;

  /// No description provided for @addServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a Nextcloud server'**
  String get addServerTitle;

  /// No description provided for @certificateChangedBody.
  ///
  /// In en, this message translates to:
  /// **'{host} now presents a different certificate than the one this account trusts. If you replaced the certificate yourself, remove the account and add it again.'**
  String certificateChangedBody(String host);

  /// No description provided for @certificateChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Server certificate changed'**
  String get certificateChangedTitle;

  /// No description provided for @certificateFingerprintLabel.
  ///
  /// In en, this message translates to:
  /// **'SHA-256 fingerprint'**
  String get certificateFingerprintLabel;

  /// No description provided for @certificateTrustAction.
  ///
  /// In en, this message translates to:
  /// **'Trust and continue'**
  String get certificateTrustAction;

  /// No description provided for @certificateUnverifiedBody.
  ///
  /// In en, this message translates to:
  /// **'{host} presented a certificate this device cannot verify. Continue only if the fingerprint below is the one your server shows.'**
  String certificateUnverifiedBody(String host);

  /// No description provided for @certificateUnverifiedTitle.
  ///
  /// In en, this message translates to:
  /// **'Unverified server certificate'**
  String get certificateUnverifiedTitle;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @invalidResponse.
  ///
  /// In en, this message translates to:
  /// **'The server returned a response this app cannot safely use.'**
  String get invalidResponse;

  /// No description provided for @invalidServer.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid HTTPS Nextcloud address.'**
  String get invalidServer;

  /// No description provided for @localPersistenceFailed.
  ///
  /// In en, this message translates to:
  /// **'The account could not be stored securely on this device.'**
  String get localPersistenceFailed;

  /// No description provided for @loginTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The sign-in request expired. Start it again.'**
  String get loginTimedOut;

  /// No description provided for @multiServerBody.
  ///
  /// In en, this message translates to:
  /// **'Add personal and work accounts without rebuilding the app or sharing their data.'**
  String get multiServerBody;

  /// No description provided for @multiServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Built for multiple servers'**
  String get multiServerTitle;

  /// No description provided for @openingLogin.
  ///
  /// In en, this message translates to:
  /// **'Opening secure sign-in…'**
  String get openingLogin;

  /// No description provided for @reauthenticateAccountAction.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get reauthenticateAccountAction;

  /// No description provided for @reauthenticateAccountMismatch.
  ///
  /// In en, this message translates to:
  /// **'Sign in with the same account. The stored account was not changed.'**
  String get reauthenticateAccountMismatch;

  /// No description provided for @reauthenticateAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to this account again'**
  String get reauthenticateAccountTitle;

  /// No description provided for @scanLoginCodeCameraDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera access is turned off. Allow it in system settings to scan a login code.'**
  String get scanLoginCodeCameraDenied;

  /// No description provided for @scanLoginCodeCameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This device has no camera that can read a login code.'**
  String get scanLoginCodeCameraUnavailable;

  /// No description provided for @secureBody.
  ///
  /// In en, this message translates to:
  /// **'App passwords are stored in the system Keychain or Keystore, never in the notes database.'**
  String get secureBody;

  /// No description provided for @secureTitle.
  ///
  /// In en, this message translates to:
  /// **'Credentials stay on this device'**
  String get secureTitle;

  /// No description provided for @serverAddressHint.
  ///
  /// In en, this message translates to:
  /// **'cloud.example.com'**
  String get serverAddressHint;

  /// No description provided for @serverAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get serverAddressLabel;

  /// No description provided for @serverMaintenance.
  ///
  /// In en, this message translates to:
  /// **'This server is currently in maintenance mode.'**
  String get serverMaintenance;

  /// No description provided for @serverNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'Nextcloud is not installed on this server yet.'**
  String get serverNotInstalled;

  /// No description provided for @serverUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The server could not be reached. Check the address and your connection.'**
  String get serverUnavailable;

  /// No description provided for @serverUpgrade.
  ///
  /// In en, this message translates to:
  /// **'The server must finish its database upgrade first.'**
  String get serverUpgrade;

  /// No description provided for @unexpectedError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. No account data was changed.'**
  String get unexpectedError;
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
      <String>['cs', 'de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'cs':
      return AppLocalizationsCs();
    case 'de':
      return AppLocalizationsDe();
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
