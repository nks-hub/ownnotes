// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'OwnNotes';

  @override
  String get addAccount => 'Konto hinzufügen';

  @override
  String get serverUrl => 'Nextcloud-Serveradresse';

  @override
  String get connect => 'Weiter';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get waitingLogin => 'Schließe die Anmeldung im Browser ab …';

  @override
  String get loginFailed =>
      'Anmeldung fehlgeschlagen. Prüfe die Serveradresse und starte erneut.';

  @override
  String get noAccounts => 'Verbinde dein Nextcloud-Konto.';

  @override
  String get noNotes =>
      'Noch keine Notizen. Erstelle eine oder synchronisiere.';

  @override
  String get newNote => 'Neue Notiz';

  @override
  String get untitled => 'Unbenannt';

  @override
  String get search => 'Notizen durchsuchen';

  @override
  String get sync => 'Synchronisieren';

  @override
  String get syncFailed =>
      'Synchronisierung fehlgeschlagen. Lokale Notizen bleiben erhalten.';

  @override
  String get loadFailed => 'Lokale Daten konnten nicht geladen werden.';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get title => 'Titel';

  @override
  String get content => 'Markdown-Text';

  @override
  String get category => 'Kategorie';

  @override
  String get favorite => 'Favorit';

  @override
  String get preview => 'Vorschau';

  @override
  String get edit => 'Quelltext bearbeiten';

  @override
  String get save => 'Lokal speichern';

  @override
  String get saved => 'Lokal gespeichert';

  @override
  String get saving => 'Speichern …';

  @override
  String get saveFailed =>
      'Speichern fehlgeschlagen. Lass den Editor offen und kopiere deinen Text.';

  @override
  String get decisionRequired =>
      'Die Synchronisierung braucht eine Entscheidung. Dein lokaler Text bleibt erhalten.';

  @override
  String get readonly => 'Schreibgeschützte Notiz';

  @override
  String get selectNote => 'Wähle eine Notiz';

  @override
  String get imageUnavailable => 'Bild nicht geladen';

  @override
  String get startupFailed =>
      'Der lokale Speicher konnte nicht geöffnet werden. Versuche es erneut, ohne die App-Daten zu löschen.';

  @override
  String get resolve => 'Konflikt lösen';

  @override
  String get readServer => 'Serverversion vergleichen';

  @override
  String get localVersion => 'Lokale Version';

  @override
  String get serverVersion => 'Serverversion';

  @override
  String get useServer => 'Serverversion verwenden';

  @override
  String get keepLocal => 'Lokale Änderungen behalten';

  @override
  String get newCopy => 'Separate Kopie erstellen';

  @override
  String get copyWarning =>
      'Die Notiz ist möglicherweise schon auf dem Server. Eine separate Kopie kann ein Duplikat erzeugen. Der ursprüngliche Wiederherstellungseintrag bleibt erhalten.';

  @override
  String get confirm => 'Bestätigen';

  @override
  String get copyMarkdown => 'Markdown kopieren';

  @override
  String get decisionFailed =>
      'Die Entscheidung konnte nicht angewendet werden. Lade neu und vergleiche erneut.';

  @override
  String get importKeep => 'Aus Google Keep importieren (Takeout-.zip)';

  @override
  String importDone(int count) {
    return 'Importierte Notizen: $count';
  }

  @override
  String get importFailed =>
      'Import fehlgeschlagen. Die Datei ist kein Google-Takeout-Zip mit Keep-Notizen.';

  @override
  String get delete => 'Löschen';

  @override
  String get deleteConfirm =>
      'Diese Notiz löschen? Sie wird auch auf dem Server gelöscht.';

  @override
  String get allCategories => 'Alle';

  @override
  String unsent(int count) {
    return 'Noch nicht gesendet: $count';
  }

  @override
  String get reasonOffline =>
      'Keine Verbindung. Notizen werden automatisch hochgeladen, sobald sie wieder da ist.';

  @override
  String get reasonAuth =>
      'Der Server hat die Anmeldung abgelehnt. Melde dich unter Konten erneut an.';

  @override
  String get reasonLocked =>
      'Die Datei ist auf dem Server gesperrt. Neuer Versuch in Kürze.';

  @override
  String get reasonStorageFull => 'Der Speicher auf dem Server ist voll.';

  @override
  String get reasonServer =>
      'Der Server hat mit einem Fehler geantwortet. Neuer Versuch in Kürze.';

  @override
  String get sortByTitle => 'Nach Titel sortieren';

  @override
  String get sortByModified => 'Nach letzter Änderung sortieren';

  @override
  String get settings => 'Einstellungen';

  @override
  String get monospace => 'Festbreitenschrift im Editor';

  @override
  String get textSize => 'Textgröße im Editor';

  @override
  String get appLock => 'App-Sperre';

  @override
  String get appLockHint =>
      'Fragt nach Fingerabdruck, Gesicht oder Geräte-PIN, wenn du zur App zurückkehrst.';

  @override
  String get appLockUnavailable =>
      'Auf diesem Gerät ist keine Displaysperre eingerichtet.';

  @override
  String get blockScreenshots => 'Bildschirmfotos blockieren';

  @override
  String get exportNotes => 'Notizen exportieren (Zip)';

  @override
  String exportDone(int count) {
    return 'Exportierte Notizen: $count';
  }

  @override
  String get exportFailed => 'Export fehlgeschlagen.';

  @override
  String get removeAccount => 'Konto von diesem Gerät entfernen';

  @override
  String get removeAccountConfirm =>
      'Das Konto von diesem Gerät entfernen und sein App-Passwort auf dem Server widerrufen? Die Notizen auf dem Server bleiben erhalten.';

  @override
  String removeAccountUnsent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Notizen sind noch nicht auf dem Server und gehen verloren.',
      one: '1 Notiz ist noch nicht auf dem Server und geht verloren.',
    );
    return 'Konto entfernen? $_temp0 Du kannst sie vorher exportieren.';
  }

  @override
  String get unlockReason => 'OwnNotes entsperren';

  @override
  String get unlock => 'Entsperren';

  @override
  String get findInNote => 'In Notiz suchen';

  @override
  String get findNext => 'Nächster Treffer';

  @override
  String get notFound => 'Nicht gefunden';

  @override
  String get shareTo => 'Wohin soll der geteilte Text?';

  @override
  String get remoteDeleted =>
      'Diese Notiz wurde inzwischen auf dem Server gelöscht. Der Text auf diesem Gerät bleibt erhalten.';

  @override
  String get uploadAgain => 'Erneut auf den Server hochladen';

  @override
  String get deleteHere => 'Auch auf diesem Gerät löschen';

  @override
  String get mergeBoth => 'Beide Versionen zusammenführen';

  @override
  String get settingSaveFailed =>
      'Die Einstellung konnte nicht gespeichert werden. Sie bleibt unverändert.';

  @override
  String get lockUnavailable =>
      'Die Sperre konnte gerade nicht geprüft werden. Versuche es erneut.';

  @override
  String get lockDeviceRemoved =>
      'Die Displaysperre dieses Geräts wurde entfernt, daher kann die App-Sperre nicht funktionieren.';

  @override
  String get lockTurnOff => 'App-Sperre ausschalten und fortfahren';

  @override
  String get editNote => 'Bearbeiten';

  @override
  String get fmtBold => 'Fett';

  @override
  String get fmtItalic => 'Kursiv';

  @override
  String get fmtHeading => 'Überschrift';

  @override
  String get fmtList => 'Liste';

  @override
  String get fmtChecklist => 'Checkliste';

  @override
  String get fmtLink => 'Link';

  @override
  String get allNotes => 'Alle Notizen';

  @override
  String get favorites => 'Favoriten';

  @override
  String get uncategorised => 'Nicht kategorisiert';

  @override
  String get categories => 'Kategorien';

  @override
  String get switchAccount => 'Konto wechseln';

  @override
  String get clearSearch => 'Suche löschen';

  @override
  String get noMatches => 'Keine Notiz passt zu deiner Suche.';

  @override
  String get noNotesHere => 'Noch keine Notizen in dieser Kategorie.';

  @override
  String get newNoteHere => 'Neue Notiz hier';

  @override
  String get stateWaiting => 'Wartet';

  @override
  String get stateSending => 'Wird gesendet';

  @override
  String get stateNeedsDecision => 'Entscheidung nötig';

  @override
  String get relNow => 'Gerade eben';

  @override
  String relMinutes(int count) {
    return 'vor $count Min.';
  }

  @override
  String relHours(int count) {
    return 'vor $count Std.';
  }

  @override
  String get relYesterday => 'Gestern';

  @override
  String relDays(int count) {
    return 'vor $count Tagen';
  }

  @override
  String conflictsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Notizen brauchen eine Entscheidung',
      one: '1 Notiz braucht eine Entscheidung',
    );
    return '$_temp0';
  }

  @override
  String get signInAgain => 'Erneut anmelden';

  @override
  String get resolveNow => 'Lösen';

  @override
  String get syncStatus => 'Synchronisierungsstatus';

  @override
  String tasksDone(int done, int total) {
    return '$done von $total Aufgaben erledigt';
  }

  @override
  String get hasAttachments => 'Hat Anhänge';

  @override
  String get serverEmpty => 'Gib die Adresse deines Nextcloud-Servers ein.';

  @override
  String get serverInsecure =>
      'Nur https://-Server werden unterstützt. Sonst würde deine Anmeldung unverschlüsselt übertragen.';

  @override
  String get serverInvalid =>
      'Das ist keine gültige Serveradresse. Beispiel: cloud.example.com';

  @override
  String get serverNoLogin =>
      'Dieser Server bietet keine Nextcloud-Anmeldung an. Prüfe die Adresse.';

  @override
  String get serverUnreachable =>
      'Der Server ist nicht erreichbar. Prüfe die Adresse und deine Verbindung.';

  @override
  String get browserUnavailable =>
      'Die Anmeldeseite konnte nicht geöffnet werden.';

  @override
  String get loginExpired =>
      'Die Anmeldung hat zu lange gedauert. Starte erneut.';

  @override
  String get scannedLoginRejected =>
      'Der gescannte Anmeldecode konnte nicht verwendet werden. Erstellen Sie einen neuen auf dem Server.';

  @override
  String get onboardingTitle => 'Alle Notizen in einer App';

  @override
  String get onboardingBody =>
      'Verbinden Sie einen beliebigen unterstützten Nextcloud-Server. Konten, ihre gespeicherten Daten und die Hintergrundarbeit bleiben strikt getrennt.';

  @override
  String get multiAccountTitle => 'Mehrere Konten';

  @override
  String get multiAccountBody =>
      'Füge weitere Server oder Benutzer hinzu und wechsle jederzeit zwischen ihnen.';

  @override
  String get secureLoginTitle => 'Kein Passwort in der App';

  @override
  String get secureLoginBody =>
      'Du meldest dich im Browser an. Das Gerät speichert nur ein App-Passwort, das du widerrufen kannst.';

  @override
  String get checkingServer => 'Server wird geprüft…';

  @override
  String get waitingForLogin => 'Schließen Sie die Anmeldung im Browser ab';

  @override
  String get waitingForLoginBody =>
      'Dieser Bildschirm fährt automatisch fort, sobald Nextcloud die App bestätigt.';

  @override
  String get savingAccount => 'Anmeldung läuft …';

  @override
  String get scanLoginCode => 'Anmeldecode scannen';

  @override
  String get scanLoginCodeHint =>
      'Richten Sie die Kamera auf den QR-Code, den Ihr Server unter Einstellungen, Sicherheit, Neues App-Passwort erstellen anzeigt.';

  @override
  String get scanLoginCodeUnreadable => 'Dies ist kein Nextcloud-Anmeldecode.';

  @override
  String get scanCameraDenied =>
      'Der Kamerazugriff ist aus. Erlaube ihn in den App-Einstellungen, um den Code zu scannen.';

  @override
  String get scanCameraUnavailable =>
      'Die Kamera konnte nicht gestartet werden.';

  @override
  String get openAppSettings => 'Einstellungen öffnen';

  @override
  String get accounts => 'Konten';

  @override
  String get currentAccount => 'Aktuelles Konto';

  @override
  String get accountRemovedRevoked =>
      'Konto entfernt. Sein App-Passwort ist auf dem Server widerrufen.';

  @override
  String get accountRemovedNotRevoked =>
      'Konto von diesem Gerät entfernt. Der Server hat es nicht bestätigt, widerrufe das App-Passwort daher in Nextcloud unter Einstellungen, Sicherheit.';

  @override
  String get accountRemoveFailed => 'Das Konto konnte nicht entfernt werden.';

  @override
  String get serverCertificate =>
      'Das Serverzertifikat konnte nicht überprüft werden. Prüfe die Adresse oder repariere das Zertifikat auf dem Server.';

  @override
  String get serverTimeout =>
      'Der Server hat zu lange nicht geantwortet. Versuche es erneut.';

  @override
  String get notesAppMissing =>
      'Die App Notes ist auf diesem Server nicht verfügbar. Installiere oder aktiviere zuerst Nextcloud Notes.';

  @override
  String get reauthMismatch =>
      'Diese Anmeldung gehört zu einem anderen Server oder Benutzer. Melde dich mit demselben Konto an, um seine Notizen zu behalten.';

  @override
  String get recTitle => 'Versionen vergleichen';

  @override
  String get recTabDevice => 'Gerät';

  @override
  String get recTabServer => 'Server';

  @override
  String get recTabResult => 'Ergebnis';

  @override
  String get recUseResult => 'Ergebnis verwenden';

  @override
  String get recKeepSeparate => 'Als separate Notiz behalten';

  @override
  String get recUseServer => 'Serverversion verwenden';

  @override
  String get recLeave => 'Ungelöst lassen';

  @override
  String get recFillDevice => 'Gerätetext ins Ergebnis übernehmen';

  @override
  String get recFillServer => 'Servertext ins Ergebnis übernehmen';

  @override
  String get recFillBoth => 'Beide ins Ergebnis übernehmen';

  @override
  String get recResultReplaced => 'Ergebnis ersetzt';

  @override
  String get recUndo => 'Rückgängig';

  @override
  String get recReasonConflict =>
      'Sowohl dieses Gerät als auch der Server haben diese Notiz geändert.';

  @override
  String get recReasonUnknown =>
      'Das Ergebnis des letzten Hochladens ist unbekannt. Vergleiche die Versionen, bevor du wählst.';

  @override
  String get recReasonReadonly =>
      'Der Server lässt dich diese Notiz nicht mehr bearbeiten. Dein Text bleibt erhalten; speichere ihn als eigene Notiz.';

  @override
  String get recReasonMove =>
      'Eine Notiz mit Anhängen kann hier ihre Kategorie nicht ändern. Behalte die Kategorie vom Server oder speichere deinen Text als separate Notiz.';

  @override
  String get recReasonGeneric => 'Diese Notiz braucht deine Entscheidung.';

  @override
  String recChangeCounter(int number, int total) {
    return 'Änderung $number von $total';
  }

  @override
  String get recNoChanges => 'Geräte- und Servertext sind gleich.';

  @override
  String get recPrevChange => 'Vorherige Änderung';

  @override
  String get recNextChange => 'Nächste Änderung';

  @override
  String get recServerChanged =>
      'Die Serverversion hat sich erneut geändert. Der Vergleich zeigt jetzt die neuere Version; dein Ergebnis bleibt erhalten. Prüfe es und entscheide erneut.';

  @override
  String get recKept =>
      'Beide Versionen bleiben auf diesem Gerät gespeichert, bis du sie entfernst.';

  @override
  String get recSaveAsNew => 'Als neue Notiz speichern';

  @override
  String get recKeepCategory => 'Ergebnis verwenden, Serverkategorie behalten';

  @override
  String get recReadFailed => 'Die Serverversion konnte nicht gelesen werden.';

  @override
  String get recKeepRecovery => 'In der Wiederherstellung behalten';

  @override
  String get settingsAppearance => 'Darstellung';

  @override
  String get settingsWriting => 'Schreiben';

  @override
  String get settingsPrivacy => 'Datenschutz';

  @override
  String get settingsSync => 'Synchronisierung und Speicher';

  @override
  String get settingsTransfer => 'Import und Export';

  @override
  String get settingsAbout => 'Über';

  @override
  String get settingsDeviceOnly =>
      'Diese Einstellungen gelten nur für dieses Gerät.';

  @override
  String get theme => 'Design';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get language => 'Sprache';

  @override
  String get languageSystem => 'System';

  @override
  String get exportMarkdown => 'Markdown exportieren';

  @override
  String get exportMarkdownHint =>
      'Notizen als Markdown-Dateien in einem ZIP. Anhänge und Wiederherstellungskopien sind nicht enthalten.';

  @override
  String get widgetPolicyTitle => 'Widgets auf dem Startbildschirm';

  @override
  String get widgetPolicyBody =>
      'Bei aktiver App-Sperre blenden Widgets Notizinhalte aus, auch wenn die App entsperrt ist.';

  @override
  String storageNotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Notizen auf diesem Gerät',
      one: '1 Notiz auf diesem Gerät',
    );
    return '$_temp0';
  }

  @override
  String storageUnsent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Notizen noch nicht gesendet',
      one: '1 Notiz noch nicht gesendet',
      zero: 'Alles ist an den Server gesendet',
    );
    return '$_temp0';
  }

  @override
  String get syncHint =>
      'Notizen werden beim Öffnen der App synchronisiert. Wann die Synchronisierung im Hintergrund läuft, entscheidet das System.';

  @override
  String get exportUnsent => 'Nicht gesendete Notizen exportieren';

  @override
  String get removeFromDevice => 'Von diesem Gerät entfernen';

  @override
  String get accountDetails => 'Kontodetails';

  @override
  String get accountUserLabel => 'Benutzer';

  @override
  String get accountServerLabel => 'Server';

  @override
  String get accountStatusLabel => 'Status';

  @override
  String get accountSignedIn => 'Angemeldet';

  @override
  String get accountsManage => 'Konten verwalten';

  @override
  String get accountSwitchBlocked =>
      'Speichern auf diesem Gerät nicht möglich, daher wurde das Konto nicht gewechselt.';

  @override
  String get removeLocalNote =>
      'Betrifft nur dieses Gerät. Notizen auf dem Server werden nicht gelöscht.';

  @override
  String get loginCancelled =>
      'Anmeldung abgebrochen. Nichts wurde gespeichert.';

  @override
  String get reauthExplain =>
      'Melde dich mit diesem Konto an, um seine Notizen und nicht gesendeten Änderungen zu behalten.';

  @override
  String get scanConfirmTitle => 'Mit diesem Code anmelden?';

  @override
  String scanConfirmBody(String user, String host) {
    return '$user auf $host';
  }

  @override
  String get scanEnterAddress => 'Serveradresse eingeben';

  @override
  String get appLocked => 'OwnNotes ist gesperrt';

  @override
  String get undo => 'Rückgängig';

  @override
  String get redo => 'Wiederholen';

  @override
  String get dockFormat => 'Format';

  @override
  String get dockTask => 'Aufgabe';

  @override
  String get dockAttach => 'Anhängen';

  @override
  String get dockInsert => 'Einfügen';

  @override
  String get fmtStrike => 'Durchgestrichen';

  @override
  String get fmtQuote => 'Zitat';

  @override
  String get fmtNumbered => 'Nummerierte Liste';

  @override
  String get fmtCode => 'Code';

  @override
  String get fmtIndent => 'Einrücken';

  @override
  String get fmtOutdent => 'Ausrücken';

  @override
  String get insertMention => 'Erwähnung';

  @override
  String get insertEmoji => 'Emoji';

  @override
  String get smartPicker => 'Intelligente Auswahl';

  @override
  String get smartPickerNone =>
      'Dieser Server bietet nichts, was die intelligente Auswahl durchsuchen kann.';

  @override
  String get attachPhoto => 'Foto';

  @override
  String get attachCamera => 'Kamera';

  @override
  String get attachFile => 'Datei';

  @override
  String get attachVoice => 'Sprachnotiz';

  @override
  String get suggestSearching => 'Suche …';

  @override
  String get suggestError =>
      'Vorschläge sind gerade nicht verfügbar. Du kannst weiterschreiben.';

  @override
  String suggestCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Vorschläge',
      one: '1 Vorschlag',
    );
    return '$_temp0';
  }

  @override
  String get suggestInsert => 'Einfügen';

  @override
  String get cmdToday => 'Heutiges Datum';

  @override
  String get cmdTime => 'Aktuelle Uhrzeit';

  @override
  String get cmdTable => 'Tabelle';

  @override
  String get cmdDivider => 'Trennlinie';

  @override
  String get calloutInfo => 'Info';

  @override
  String get calloutWarning => 'Warnung';

  @override
  String get calloutError => 'Fehler';

  @override
  String get calloutSuccess => 'Erfolg';

  @override
  String get detailsDefault => 'Details';

  @override
  String mentionLabel(String name) {
    return 'Erwähnung: $name';
  }

  @override
  String attachmentLabel(String name) {
    return 'Anhang: $name';
  }

  @override
  String tableLabel(int rows, int columns) {
    String _temp0 = intl.Intl.pluralLogic(
      rows,
      locale: localeName,
      other: '$rows Zeilen',
      one: '1 Zeile',
    );
    String _temp1 = intl.Intl.pluralLogic(
      columns,
      locale: localeName,
      other: '$columns Spalten',
      one: '1 Spalte',
    );
    return 'Tabelle mit $_temp0 und $_temp1';
  }

  @override
  String get editSection => 'Diesen Abschnitt bearbeiten';

  @override
  String get checklistMarkdown => 'Markdown';

  @override
  String get checklistEmpty =>
      'Noch keine Aufgaben. Füge unten den ersten Eintrag hinzu.';

  @override
  String get checklistAdd => 'Eintrag hinzufügen';

  @override
  String checklistCompletedGroup(int count) {
    return 'Erledigt ($count)';
  }

  @override
  String get clearCompleted => 'Erledigte Einträge entfernen';

  @override
  String clearCompletedConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count erledigte Einträge aus der Notiz entfernen?',
      one: '1 erledigten Eintrag aus der Notiz entfernen?',
    );
    return '$_temp0';
  }

  @override
  String clearedCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge entfernt',
      one: '1 Eintrag entfernt',
    );
    return '$_temp0';
  }

  @override
  String checklistPosition(int position, int total) {
    return '$position von $total';
  }

  @override
  String get checklistItemMenu => 'Eintragsoptionen';

  @override
  String get moveUp => 'Nach oben';

  @override
  String get moveDown => 'Nach unten';

  @override
  String get shareTitle => 'Teilen';

  @override
  String get shareSendCopy => 'Kopie senden';

  @override
  String get shareAsText => 'Als Text senden';

  @override
  String get shareAsFile => 'Als Markdown-Datei senden';

  @override
  String get shareWithPeople => 'Mit Personen teilen';

  @override
  String get sharePeopleWithAccess => 'Personen mit Zugriff';

  @override
  String get shareSearchHint => 'Personen suchen';

  @override
  String get sharePermissionView => 'Kann ansehen';

  @override
  String get sharePermissionEdit => 'Kann bearbeiten';

  @override
  String get shareRemove => 'Zugriff entfernen';

  @override
  String get sharePending => 'Wird geteilt …';

  @override
  String get shareRemoving => 'Zugriff wird entfernt …';

  @override
  String get shareFailed =>
      'Das hat nicht geklappt. Prüfe die Verbindung und versuche es erneut.';

  @override
  String get shareNotUploaded =>
      'Diese Notiz ist noch nicht auf dem Server. Sie wird zuerst hochgeladen, dann kann sie geteilt werden.';

  @override
  String get shareUploadFirst => 'Hochladen und fortfahren';

  @override
  String get shareUploading => 'Notiz wird hochgeladen …';

  @override
  String get shareUploadFailed =>
      'Die Notiz konnte noch nicht hochgeladen werden. Sie bleibt auf diesem Gerät gespeichert.';

  @override
  String get shareIncoming =>
      'Jemand hat diese Notiz mit dir geteilt. Nur der Besitzer kann sie weiter teilen.';

  @override
  String get shareAttachmentsWarning =>
      'Diese Notiz hat Anhänge. Personen, mit denen du sie teilst, können sie eventuell nicht öffnen.';

  @override
  String get shareNone => 'Noch mit niemandem geteilt.';

  @override
  String get shareNoResults => 'Keine passenden Personen.';

  @override
  String get shareChecking => 'Freigaben werden geprüft …';

  @override
  String shareWithName(String name) {
    return 'Mit $name teilen';
  }

  @override
  String get moreOptions => 'Weitere Optionen';

  @override
  String get openDetails => 'Details';

  @override
  String get unfavorite => 'Aus Favoriten entfernen';

  @override
  String get openChecklist => 'Checkliste öffnen';

  @override
  String get attachments => 'Anhänge';

  @override
  String get historyRecovery => 'Verlauf und Wiederherstellung';

  @override
  String get exportNote => 'Exportieren';

  @override
  String findCount(int index, int total) {
    return '$index von $total';
  }

  @override
  String get findPrevious => 'Vorheriger Treffer';

  @override
  String get saveFailedTitle => 'Speichern auf diesem Gerät nicht möglich';

  @override
  String get noteUnreadable =>
      'Der Server konnte den Text dieser Notiz nicht liefern. Deine letzte Kopie bleibt erhalten. Versuche es erneut oder kopiere deinen Text.';

  @override
  String get exportDraft => 'Entwurf exportieren';

  @override
  String get attachmentsNone => 'Keine Anhänge in dieser Notiz.';

  @override
  String get attachmentImage => 'Bild';

  @override
  String get attachmentFile => 'Datei';

  @override
  String get templates => 'Vorlagen';

  @override
  String get templatesEmpty => 'Noch keine Vorlagen.';

  @override
  String get templatesManage => 'Vorlagen verwalten';

  @override
  String get templateNew => 'Neue Vorlage';

  @override
  String get templateEdit => 'Vorlage bearbeiten';

  @override
  String get templateSave => 'Speichern';

  @override
  String get templateName => 'Name der Vorlage';

  @override
  String templatePlaceholders(String placeholders) {
    return 'Wird beim Erstellen einer Notiz ausgefüllt: $placeholders';
  }

  @override
  String templateDeleteConfirm(String name) {
    return 'Die Vorlage „$name“ löschen?';
  }

  @override
  String get templatesDeviceOnly =>
      'Vorlagen und die Tagesnotiz bleiben auf diesem Gerät.';

  @override
  String get dailyNote => 'Tagesnotiz';

  @override
  String get dailyNotePattern => 'Titelmuster (zum Beispiel yyyy-MM-dd)';

  @override
  String get dailyNoteTemplate => 'Vorlage';

  @override
  String get dailyNoteNoTemplate => 'Keine Vorlage';

  @override
  String dailyNotePreview(String title, String category) {
    return 'Heute: „$title“ in $category';
  }

  @override
  String get categoriesMenu => 'Kategorien';

  @override
  String get syncNow => 'Jetzt synchronisieren';

  @override
  String get syncDetails => 'Synchronisierungsdetails';

  @override
  String get selectNotes => 'Notizen auswählen';

  @override
  String get sortAndFilter => 'Sortieren und filtern';

  @override
  String accountSyncHint(String account) {
    return 'Synchronisierungsdetails für $account';
  }

  @override
  String get checkingForUpdates => 'Nach Aktualisierungen suchen';

  @override
  String syncSavedWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Auf dem Gerät gespeichert · $count warten',
      one: 'Auf dem Gerät gespeichert · 1 wartet',
    );
    return '$_temp0';
  }

  @override
  String syncUploading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Änderungen werden hochgeladen',
      one: '1 Änderung wird hochgeladen',
    );
    return '$_temp0';
  }

  @override
  String syncUpToDate(String time) {
    return 'Aktuell · geprüft $time';
  }

  @override
  String get syncOffline => 'Offline · Änderungen auf dem Gerät gespeichert';

  @override
  String get syncOfflineShort => 'Offline';

  @override
  String get syncAuthFailure =>
      'Erneut anmelden · lokale Notizen bleiben erhalten';

  @override
  String get syncSaveFailure => 'Speichern auf diesem Gerät nicht möglich';

  @override
  String get needsAttention => 'Erfordert Aufmerksamkeit';

  @override
  String get sharedWithMe => 'Mit mir geteilt';

  @override
  String get savedViews => 'Gespeicherte Ansichten';

  @override
  String get onThisDevice => 'Auf diesem Gerät';

  @override
  String get saveView => 'Diese Ansicht speichern';

  @override
  String get saveViewName => 'Name der Ansicht';

  @override
  String get deleteView => 'Gespeicherte Ansicht löschen';

  @override
  String get sheetUploads => 'Uploads';

  @override
  String get sheetDownloads => 'Downloads';

  @override
  String get sheetDecisions => 'Entscheidungen';

  @override
  String get sheetDeletions => 'Löschungen';

  @override
  String get uploadsNone => 'Nichts wartet auf das Hochladen';

  @override
  String get downloadsNever => 'Noch nicht geprüft';

  @override
  String downloadsUnreadable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Notizen können nicht aktualisiert werden',
      one: '1 Notiz kann nicht aktualisiert werden',
    );
    return '$_temp0';
  }

  @override
  String downloadsMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Notizen werden vom Server nicht mehr aufgeführt',
      one: '1 Notiz wird vom Server nicht mehr aufgeführt',
    );
    return '$_temp0';
  }

  @override
  String get decisionsNone => 'Keine Notiz braucht eine Entscheidung';

  @override
  String get deletionsNone => 'Keine Löschungen ausstehend';

  @override
  String deletionsWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Löschungen warten auf den Server',
      one: '1 Löschung wartet auf den Server',
    );
    return '$_temp0';
  }

  @override
  String deletionsFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Löschungen fehlgeschlagen',
      one: '1 Löschung fehlgeschlagen',
    );
    return '$_temp0';
  }

  @override
  String get reviewItems => 'Prüfen';

  @override
  String get rowSavedWaiting =>
      'Auf dem Gerät gespeichert · Warten auf das Hochladen';

  @override
  String get rowUploading => 'Änderungen werden hochgeladen';

  @override
  String get rowNeedsDecision => 'Benötigt deine Entscheidung';

  @override
  String get rowUnavailable => 'Diese Notiz kann nicht aktualisiert werden';

  @override
  String get rowMissing => 'Vom Server nicht mehr aufgeführt';

  @override
  String get rowSharedEdit => 'Geteilt · Kann bearbeiten';

  @override
  String get rowSharedView => 'Geteilt · Nur ansehen';

  @override
  String attachmentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Anhänge',
      one: '1 Anhang',
    );
    return '$_temp0';
  }

  @override
  String rowMenu(String title) {
    return 'Aktionen für $title';
  }

  @override
  String get openNote => 'Öffnen';

  @override
  String get moveNote => 'Verschieben';

  @override
  String get rowDeletionWaiting => 'Löschung ausstehend';

  @override
  String rowDeletionFailed(String reason) {
    return 'Löschung fehlgeschlagen · $reason';
  }

  @override
  String get undoAction => 'Rückgängig';

  @override
  String get saveCopy => 'Kopie speichern';

  @override
  String categoryCount(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Notizen',
      one: '1 Notiz',
    );
    return '$name, $_temp0 einschließlich Unterkategorien';
  }

  @override
  String expandCategory(String name) {
    return '$name aufklappen';
  }

  @override
  String collapseCategory(String name) {
    return '$name zuklappen';
  }

  @override
  String openSubtree(String name) {
    return 'Nur $name anzeigen';
  }

  @override
  String get allCategoriesUp => 'Alle Kategorien';

  @override
  String get createNote => 'Notiz';

  @override
  String get createChecklist => 'Checkliste';

  @override
  String get createTemplate => 'Vorlage';

  @override
  String get createDaily => 'Tagesnotiz';

  @override
  String get createWhere => 'In welche Kategorie soll die Notiz?';

  @override
  String get createNoteAction => 'Notiz erstellen';

  @override
  String get createHere => 'Hier erstellen';

  @override
  String get filterTasks => 'Offene Aufgaben';

  @override
  String get filterAttachments => 'Mit Anhängen';

  @override
  String get filterShared => 'Geteilt';

  @override
  String get filterWaiting => 'Noch nicht hochgeladen';

  @override
  String get filterDecision => 'Entscheidung nötig';

  @override
  String get filterSharing => 'Teilen';

  @override
  String get filterSync => 'Sync-Status';

  @override
  String get clearFilters => 'Filter zurücksetzen';

  @override
  String get sortTitle => 'Sortieren';

  @override
  String get sortFavoritesFirst => 'Favoriten zuerst';

  @override
  String get emptyFavoritesTitle => 'Noch keine Favoriten';

  @override
  String get emptyFavoritesBody =>
      'Markiere eine Notiz mit einem Stern, um sie hier zu finden. Nutze das Notizmenü oder wische über eine Notiz.';

  @override
  String get emptySharedTitle => 'Nichts mit dir geteilt';

  @override
  String get emptySharedBody =>
      'Notizen, die andere mit diesem Konto teilen, erscheinen hier.';

  @override
  String get emptyAttentionTitle => 'Nichts erfordert deine Aufmerksamkeit';

  @override
  String get emptyAttentionBody =>
      'Entscheidungen, fehlgeschlagene Löschungen und Notizen, die nicht aktualisiert werden können, erscheinen hier.';

  @override
  String emptyCategoryTitle(String category) {
    return '$category ist leer';
  }

  @override
  String get downloadingTitle => 'Deine Notizen werden heruntergeladen';

  @override
  String downloadingBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bisher $count Notizen heruntergeladen',
      one: 'Bisher 1 Notiz heruntergeladen',
    );
    return '$_temp0';
  }

  @override
  String get connectNextcloud => 'Nextcloud verbinden';

  @override
  String get scanLoginQr => 'Anmelde-QR-Code scannen';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ausgewählt',
      one: '1 ausgewählt',
    );
    return '$_temp0';
  }

  @override
  String get bulkFavorite => 'Favorisieren';

  @override
  String get bulkUnfavorite => 'Aus Favoriten entfernen';

  @override
  String get bulkMove => 'Verschieben';

  @override
  String get bulkExport => 'Exportieren';

  @override
  String get bulkMixedMove =>
      'Verschieben ist nicht möglich, weil einige ausgewählte Notizen schreibgeschützt oder geteilt sind oder Anhänge haben.';

  @override
  String get bulkMixedDelete =>
      'Löschen ist nicht möglich, weil einige ausgewählte Notizen schreibgeschützt oder geteilt sind oder gerade gesendet werden.';

  @override
  String get bulkMixedFavorite =>
      'Favorisieren ist nicht möglich, weil einige ausgewählte Notizen geteilt sind.';

  @override
  String bulkDeleteConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Notizen löschen?',
      one: '1 Notiz löschen?',
    );
    return '$_temp0';
  }

  @override
  String get bulkDeleteBody =>
      'Die Notizen werden auch auf dem Server gelöscht. Du kannst das rückgängig machen, bis der Server es ausgeführt hat.';

  @override
  String notesDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Notizen gelöscht',
      one: '1 Notiz gelöscht',
    );
    return '$_temp0';
  }

  @override
  String notesMoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Notizen verschoben',
      one: '1 Notiz verschoben',
    );
    return '$_temp0';
  }

  @override
  String bulkFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Notizen konnten nicht geändert werden',
      one: '1 Notiz konnte nicht geändert werden',
    );
    return '$_temp0';
  }

  @override
  String get moveTitle => 'In Kategorie verschieben';

  @override
  String get moveNewCategory => 'Neue Kategorie';

  @override
  String get moveNewCategoryHint => 'Name, / für Unterkategorien';

  @override
  String get clearSelection => 'Auswahl aufheben';

  @override
  String get rowFavoriteOn => 'Zu Favoriten hinzufügen';

  @override
  String get rowFavoriteOff => 'Aus Favoriten entfernen';

  @override
  String get attachmentsTitle => 'Anhänge';

  @override
  String get attachmentsEmpty => 'Keine Anhänge in dieser Notiz.';

  @override
  String get attachStored => 'Auf dem Gerät gespeichert';

  @override
  String get attachWaiting => 'Warten auf das Hochladen';

  @override
  String get attachWaitingNote => 'Wartet, bis die Notiz hochgeladen ist';

  @override
  String get attachUploading => 'Wird hochgeladen';

  @override
  String get attachOffline => 'Offline verfügbar';

  @override
  String get attachOnServer => 'Auf dem Server';

  @override
  String get attachUnavailable => 'Nicht verfügbar';

  @override
  String attachFailedState(String reason) {
    return 'Fehlgeschlagen: $reason';
  }

  @override
  String get attachErrOffline => 'Der Server war nicht erreichbar.';

  @override
  String get attachErrAuth => 'Melde dich erneut an, um hochzuladen.';

  @override
  String get attachErrTooLarge =>
      'Der Server hat die Datei als zu groß abgelehnt.';

  @override
  String get attachErrDenied => 'Der Server hat das Hochladen nicht erlaubt.';

  @override
  String get attachErrNoteGone =>
      'Die Notiz existiert auf dem Server nicht mehr.';

  @override
  String get attachErrServer => 'Der Server hat einen Fehler gemeldet.';

  @override
  String get attachRemoveQueue => 'Aus der Warteschlange entfernen';

  @override
  String get attachRemoveLink => 'Link aus der Notiz entfernen';

  @override
  String get attachRemoveLinkHelp =>
      'Das Entfernen des Links ändert nur diese Notiz. Die Datei bleibt auf dem Server.';

  @override
  String get attachDeleteFile => 'Datei auf dem Server löschen';

  @override
  String get attachDeleteTitle => 'Die Datei auf dem Server löschen?';

  @override
  String get attachDeleteBody =>
      'Die Datei wird endgültig vom Server entfernt. Andere Notizen und Geräte, die darauf verlinken, zeigen dann eine fehlende Datei.';

  @override
  String get attachDeleteFileOnly => 'Datei löschen';

  @override
  String get attachDeleteFileAndLink => 'Datei und Link löschen';

  @override
  String get attachDeleteUnsupported =>
      'Diese Serverversion kann keine Anhänge löschen. Entferne stattdessen den Link; die Datei bleibt auf dem Server.';

  @override
  String get attachDeleteFailed => 'Die Datei konnte nicht gelöscht werden.';

  @override
  String get attachKeepOffline => 'Offline behalten';

  @override
  String get attachUploadFailedTitle => 'Hochladen fehlgeschlagen';

  @override
  String get attachKeepForLater => 'Für später behalten';

  @override
  String get attachSavedWaiting =>
      'Auf dem Gerät gespeichert. Die Datei wird hochgeladen, sobald die Notiz auf dem Server ist, dann wird der Link in die Notiz eingefügt.';

  @override
  String get attachSavedQueued =>
      'Auf dem Gerät gespeichert. Der Link wird nach dem Hochladen in die Notiz eingefügt.';

  @override
  String get attachTooLarge =>
      'Diese Datei ist größer als 64 MB und wurde nicht angehängt.';

  @override
  String get attachReadFailed => 'Die Datei konnte nicht gelesen werden.';

  @override
  String get attachWorking => 'Anhang wird hinzugefügt …';

  @override
  String get voiceTitle => 'Sprachaufnahme';

  @override
  String get voiceReady => 'Bereit zur Aufnahme';

  @override
  String get voiceRecording => 'Aufnahme läuft';

  @override
  String get voicePaused => 'Pausiert';

  @override
  String get voiceStopped => 'Aufnahme beendet';

  @override
  String get voiceStart => 'Aufnahme starten';

  @override
  String get voicePause => 'Pausieren';

  @override
  String get voiceResume => 'Fortsetzen';

  @override
  String get voiceStop => 'Stoppen';

  @override
  String get voiceListen => 'Anhören';

  @override
  String get voiceStopListening => 'Wiedergabe stoppen';

  @override
  String get voiceAttach => 'Anhängen';

  @override
  String get voiceDiscard => 'Verwerfen';

  @override
  String get voiceDiscardTitle => 'Diese Aufnahme verwerfen?';

  @override
  String get voiceDiscardBody => 'Die Aufnahme wird von diesem Gerät gelöscht.';

  @override
  String get voiceMicDenied =>
      'Der Mikrofonzugriff ist aus. Erlaube ihn in den Systemeinstellungen, um aufzunehmen.';

  @override
  String get voiceInterrupted =>
      'Die Aufnahme wurde pausiert, weil die App unterbrochen wurde. Sie bleibt erhalten.';

  @override
  String get voiceRecovered => 'Eine frühere Aufnahme wurde wiederhergestellt.';

  @override
  String get voiceFailed => 'Aufnahme nicht möglich.';

  @override
  String voiceElapsed(String time) {
    return 'Aufnahmedauer $time';
  }

  @override
  String get captureTitle => 'Geteilte Inhalte';

  @override
  String get captureAccount => 'Konto';

  @override
  String get captureChooseAccount => 'Wähle das Konto für diese Inhalte.';

  @override
  String get captureUnknownAccount =>
      'Der Absender hat ein Konto angegeben, das hier nicht angemeldet ist. Wähle eines aus.';

  @override
  String get captureNewNote => 'Neue Notiz';

  @override
  String get captureAppend => 'An eine Notiz anhängen';

  @override
  String get captureCategory => 'Kategorie (optional)';

  @override
  String get captureSearchTarget => 'Notiz zum Anhängen suchen';

  @override
  String get captureNoTarget =>
      'Wähle die Notiz, an die angehängt werden soll.';

  @override
  String get captureNoMatches => 'Keine passenden Notizen.';

  @override
  String get captureSave => 'Auf dem Gerät speichern';

  @override
  String get captureDiscard => 'Verwerfen';

  @override
  String get captureDiscardTitle => 'Geteilte Inhalte verwerfen?';

  @override
  String get captureDiscardBody =>
      'Sie werden von diesem Gerät gelöscht und es wird keine Notiz erstellt.';

  @override
  String get captureKept =>
      'Wenn du diesen Bildschirm schließt, bleiben die Inhalte erhalten, bis du entscheidest.';

  @override
  String get captureNoText => 'Kein Text, nur Dateien.';

  @override
  String get captureSaveFailed =>
      'Speichern auf diesem Gerät nicht möglich. Die Inhalte bleiben erhalten.';

  @override
  String captureFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien',
      one: '1 Datei',
    );
    return '$_temp0';
  }

  @override
  String importKeepAttachments(int notes, int files, int skipped) {
    return 'Importierte Notizen: $notes, Anhänge: $files, übersprungene Dateien: $skipped.';
  }

  @override
  String get attachMoreOptions => 'Weitere Optionen';

  @override
  String get widgetConfigTitle => 'Widget einrichten';

  @override
  String get widgetTypeLabel => 'Widget-Typ';

  @override
  String get widgetTypeList => 'Notizliste';

  @override
  String get widgetTypeNote => 'Einzelne Notiz';

  @override
  String get widgetTypeChecklist => 'Checkliste';

  @override
  String get widgetTypeQuick => 'Schnelle Notiz';

  @override
  String get widgetAccountLabel => 'Konto';

  @override
  String get widgetCollectionLabel => 'Angezeigte Notizen';

  @override
  String get widgetNoteLabel => 'Notiz';

  @override
  String get widgetNoChecklistNotes =>
      'Dieses Konto hat keine Notiz mit Aufgaben.';

  @override
  String get widgetAppearanceLabel => 'Darstellung';

  @override
  String get widgetAdd => 'Widget hinzufügen';

  @override
  String get widgetNoAccount =>
      'Melde dich in OwnNotes an, bevor du ein Widget hinzufügst.';

  @override
  String get widgetSaveFailed => 'Das Widget konnte nicht eingerichtet werden.';

  @override
  String aboutVersion(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String get aboutFormatTitle => 'Einfache Markdown-Dateien';

  @override
  String get aboutFormatBody =>
      'Notizen sind Markdown-Dateien im Ordner Notes, Kategorien sind Ordner. Die Notes-Web-App, die App Text und andere Clients öffnen sie ebenfalls.';

  @override
  String get aboutServer => 'Server';

  @override
  String get aboutServerUnknown =>
      'Der Server hat seine Version nicht angegeben.';

  @override
  String get aboutWebsite => 'Website';

  @override
  String get aboutPrivacy => 'Datenschutzerklärung';

  @override
  String get aboutSupport => 'Support kontaktieren';

  @override
  String get aboutLicenses => 'Open-Source-Lizenzen';

  @override
  String get aboutCopyright => '© 2026 NKS Hub';

  @override
  String get rowSharedByYou => 'Von dir geteilt';

  @override
  String get shareOtherMethods =>
      'Diese Notiz wird auch auf andere Weise geteilt, etwa über Ordner, Links oder Gruppen. Verwalte diese Freigaben in Nextcloud.';

  @override
  String get backgroundSyncTitle => 'Hintergrundsynchronisierung';

  @override
  String get backgroundSyncOff => 'Aus';

  @override
  String backgroundSyncMinutes(int minutes) {
    return 'Alle $minutes Minuten';
  }

  @override
  String backgroundSyncHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Alle $hours Stunden',
      one: 'Jede Stunde',
    );
    return '$_temp0';
  }

  @override
  String get backgroundSyncWifi => 'Nur WLAN';

  @override
  String get backgroundSyncHint =>
      'Gilt bei geschlossener App, auch für Widget-Änderungen. Die geöffnete App nutzt jedes verfügbare Netzwerk. Android bestimmt den Zeitpunkt der Hintergrundausführung.';

  @override
  String get backgroundSyncLoadFailed =>
      'Synchronisierungseinstellungen können nicht gelesen werden. Zum Wiederholen tippen.';

  @override
  String get backgroundSyncSaveFailed =>
      'Synchronisierungseinstellungen konnten nicht gespeichert oder angewendet werden.';

  @override
  String get telemetryTitle => 'Diagnose und App-Nutzung';

  @override
  String get telemetryDescription =>
      'Sendet Fehler und Bildschirmnamen an Sentry und Rybbit. Notiztexte und Zugangsdaten werden nicht gesendet. Ausschalten gilt sofort, Einschalten nach einem Neustart.';

  @override
  String get telemetryRestart =>
      'Die Diagnose startet beim nächsten Öffnen der App.';

  @override
  String get telemetrySaveFailed =>
      'Die Diagnoseeinstellung konnte nicht gespeichert werden.';

  @override
  String get addServerTitle => 'Nextcloud-Server hinzufügen';

  @override
  String certificateChangedBody(String host) {
    return '$host verwendet jetzt ein anderes Zertifikat als das, dem dieses Konto vertraut. Wenn Sie das Zertifikat selbst ersetzt haben, entfernen Sie das Konto und fügen Sie es erneut hinzu.';
  }

  @override
  String get certificateChangedTitle => 'Serverzertifikat geändert';

  @override
  String get certificateFingerprintLabel => 'SHA-256-Fingerabdruck';

  @override
  String get certificateTrustAction => 'Vertrauen und fortfahren';

  @override
  String certificateUnverifiedBody(String host) {
    return '$host hat ein Zertifikat vorgelegt, das dieses Gerät nicht überprüfen kann. Fahren Sie nur fort, wenn der folgende Fingerabdruck mit dem Ihres Servers übereinstimmt.';
  }

  @override
  String get certificateUnverifiedTitle =>
      'Nicht verifiziertes Serverzertifikat';

  @override
  String get close => 'Schließen';

  @override
  String get invalidResponse =>
      'Der Server hat eine Antwort gesendet, die diese App nicht sicher verarbeiten kann.';

  @override
  String get invalidServer =>
      'Geben Sie eine gültige HTTPS-Adresse von Nextcloud ein.';

  @override
  String get localPersistenceFailed =>
      'Das Konto konnte nicht sicher auf diesem Gerät gespeichert werden.';

  @override
  String get loginTimedOut =>
      'Die Anmeldeanfrage ist abgelaufen. Starten Sie sie erneut.';

  @override
  String get multiServerBody =>
      'Fügen Sie private und berufliche Konten hinzu, ohne die App neu zu erstellen oder ihre Daten zu teilen.';

  @override
  String get multiServerTitle => 'Für mehrere Server geeignet';

  @override
  String get openingLogin => 'Sichere Anmeldung wird geöffnet…';

  @override
  String get reauthenticateAccountAction => 'Erneut anmelden';

  @override
  String get reauthenticateAccountMismatch =>
      'Melden Sie sich mit demselben Konto an. Das gespeicherte Konto wurde nicht geändert.';

  @override
  String get reauthenticateAccountTitle => 'Erneut bei diesem Konto anmelden';

  @override
  String get scanLoginCodeCameraDenied =>
      'Der Kamerazugriff ist deaktiviert. Erlauben Sie ihn in den Systemeinstellungen, um einen Anmeldecode zu scannen.';

  @override
  String get scanLoginCodeCameraUnavailable =>
      'Dieses Gerät hat keine Kamera, die einen Anmeldecode lesen kann.';

  @override
  String get secureBody =>
      'App-Passwörter werden im Keychain oder Keystore des Systems gespeichert, niemals in der Notizdatenbank.';

  @override
  String get secureTitle => 'Zugangsdaten bleiben auf diesem Gerät';

  @override
  String get serverAddressHint => 'cloud.example.com';

  @override
  String get serverAddressLabel => 'Serveradresse';

  @override
  String get serverMaintenance =>
      'Dieser Server befindet sich im Wartungsmodus.';

  @override
  String get serverNotInstalled =>
      'Nextcloud ist auf diesem Server noch nicht installiert.';

  @override
  String get serverUnavailable =>
      'Der Server konnte nicht erreicht werden. Prüfen Sie die Adresse und Ihre Verbindung.';

  @override
  String get serverUpgrade =>
      'Der Server muss zuerst die Aktualisierung seiner Datenbank abschließen.';

  @override
  String get unexpectedError =>
      'Ein Fehler ist aufgetreten. Es wurden keine Kontodaten geändert.';
}
