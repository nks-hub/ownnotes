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
  /// **'The server refused the login. Add the account again.'**
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
  /// **'Remove the account from this phone? Notes on the server stay.'**
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
