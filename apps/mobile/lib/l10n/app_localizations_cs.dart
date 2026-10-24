// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class AppLocalizationsCs extends AppLocalizations {
  AppLocalizationsCs([String locale = 'cs']) : super(locale);

  @override
  String get appTitle => 'OwnNotes';

  @override
  String get addAccount => 'Přidat účet';

  @override
  String get serverUrl => 'Adresa serveru Nextcloud';

  @override
  String get connect => 'Pokračovat';

  @override
  String get cancel => 'Zrušit';

  @override
  String get waitingLogin => 'Dokonči přihlášení v prohlížeči…';

  @override
  String get loginFailed =>
      'Přihlášení selhalo. Zkontroluj adresu serveru a zkus to znovu.';

  @override
  String get noAccounts => 'Připoj svůj účet Nextcloud.';

  @override
  String get noNotes =>
      'Zatím žádné poznámky. Vytvoř novou nebo spusť synchronizaci.';

  @override
  String get newNote => 'Nová poznámka';

  @override
  String get untitled => 'Bez názvu';

  @override
  String get search => 'Hledat poznámky';

  @override
  String get sync => 'Synchronizovat';

  @override
  String get syncFailed =>
      'Synchronizace selhala. Lokální poznámky zůstaly uložené.';

  @override
  String get loadFailed => 'Nepodařilo se načíst lokální data.';

  @override
  String get retry => 'Zkusit znovu';

  @override
  String get title => 'Název';

  @override
  String get content => 'Text Markdown';

  @override
  String get category => 'Kategorie';

  @override
  String get favorite => 'Oblíbená';

  @override
  String get preview => 'Náhled';

  @override
  String get edit => 'Upravit zdroj';

  @override
  String get save => 'Uložit lokálně';

  @override
  String get saved => 'Uloženo lokálně';

  @override
  String get saving => 'Ukládání…';

  @override
  String get saveFailed =>
      'Uložení selhalo. Nezavírej editor a zkopíruj si text.';

  @override
  String get decisionRequired =>
      'Synchronizace vyžaduje rozhodnutí. Lokální text je zachovaný.';

  @override
  String get readonly => 'Poznámka pouze pro čtení';

  @override
  String get selectNote => 'Vyber poznámku';

  @override
  String get imageUnavailable => 'Obrázek není načtený';

  @override
  String get startupFailed =>
      'Lokální úložiště se nepodařilo otevřít. Zkus to znovu bez mazání dat aplikace.';

  @override
  String get resolve => 'Vyřešit synchronizaci';

  @override
  String get readServer => 'Porovnat verzi na serveru';

  @override
  String get localVersion => 'Lokální verze';

  @override
  String get serverVersion => 'Verze na serveru';

  @override
  String get useServer => 'Použít verzi ze serveru';

  @override
  String get keepLocal => 'Zachovat lokální změny';

  @override
  String get newCopy => 'Vytvořit samostatnou kopii';

  @override
  String get copyWarning =>
      'Na serveru už tato poznámka může existovat. Samostatná kopie může vytvořit duplicitu. Původní záznam pro obnovu zůstane zachovaný.';

  @override
  String get confirm => 'Potvrdit';

  @override
  String get copyMarkdown => 'Zkopírovat Markdown';

  @override
  String get decisionFailed =>
      'Rozhodnutí se nepodařilo použít. Načti poznámku a porovnej ji znovu.';

  @override
  String get importKeep => 'Importovat z Google Keep (zip z Takeoutu)';

  @override
  String importDone(int count) {
    return 'Importováno poznámek: $count';
  }

  @override
  String get importFailed =>
      'Import se nepovedl. Soubor není zip z Google Takeoutu s poznámkami Keep.';

  @override
  String get delete => 'Smazat';

  @override
  String get deleteConfirm => 'Smazat poznámku? Smaže se i na serveru.';

  @override
  String get allCategories => 'Vše';

  @override
  String unsent(int count) {
    return 'Zatím neodesláno: $count';
  }

  @override
  String get reasonOffline =>
      'Bez připojení. Poznámky se odešlou samy, až bude síť.';

  @override
  String get reasonAuth =>
      'Server odmítl přihlášení. Přihlas se znovu v Účtech.';

  @override
  String get reasonLocked =>
      'Soubor je na serveru zamčený. Zkusí se to znovu za chvíli.';

  @override
  String get reasonStorageFull => 'Na serveru došlo místo.';

  @override
  String get reasonServer =>
      'Server odpověděl chybou. Zkusí se to znovu za chvíli.';

  @override
  String get sortByTitle => 'Řadit podle názvu';

  @override
  String get sortByModified => 'Řadit podle poslední změny';

  @override
  String get settings => 'Nastavení';

  @override
  String get monospace => 'Neproporcionální písmo v editoru';

  @override
  String get textSize => 'Velikost textu v editoru';

  @override
  String get appLock => 'Zámek aplikace';

  @override
  String get appLockHint =>
      'Po návratu do aplikace chce otisk prstu, obličej nebo PIN telefonu.';

  @override
  String get appLockUnavailable => 'Telefon nemá nastavený zámek obrazovky.';

  @override
  String get blockScreenshots => 'Zakázat snímky obrazovky';

  @override
  String get exportNotes => 'Exportovat poznámky (zip)';

  @override
  String exportDone(int count) {
    return 'Exportováno poznámek: $count';
  }

  @override
  String get exportFailed => 'Export se nepovedl.';

  @override
  String get removeAccount => 'Odebrat účet z telefonu';

  @override
  String get removeAccountConfirm =>
      'Odebrat účet z tohoto telefonu a zrušit jeho heslo aplikace na serveru? Poznámky na serveru zůstanou.';

  @override
  String removeAccountUnsent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count poznámek ještě není na serveru a ztratí se.',
      few: '$count poznámky ještě nejsou na serveru a ztratí se.',
      one: '1 poznámka ještě není na serveru a ztratí se.',
    );
    return 'Odebrat účet? $_temp0 Nejdřív je můžeš exportovat.';
  }

  @override
  String get unlockReason => 'Odemkni OwnNotes';

  @override
  String get unlock => 'Odemknout';

  @override
  String get findInNote => 'Hledat v poznámce';

  @override
  String get findNext => 'Další výskyt';

  @override
  String get notFound => 'Nenalezeno';

  @override
  String get shareTo => 'Kam uložit sdílený text?';

  @override
  String get remoteDeleted =>
      'Na serveru tuto poznámku mezitím někdo smazal. Text v telefonu zůstal.';

  @override
  String get uploadAgain => 'Nahrát znovu na server';

  @override
  String get deleteHere => 'Smazat i v telefonu';

  @override
  String get mergeBoth => 'Spojit obě verze';

  @override
  String get settingSaveFailed =>
      'Nastavení se nepodařilo uložit. Zůstává původní.';

  @override
  String get lockUnavailable =>
      'Zámek se teď nepodařilo ověřit. Zkus to znovu.';

  @override
  String get lockDeviceRemoved =>
      'Zámek obrazovky telefonu byl odstraněn, zámek aplikace proto nemůže fungovat.';

  @override
  String get lockTurnOff => 'Vypnout zámek aplikace a pokračovat';

  @override
  String get editNote => 'Upravit';

  @override
  String get fmtBold => 'Tučně';

  @override
  String get fmtItalic => 'Kurzíva';

  @override
  String get fmtHeading => 'Nadpis';

  @override
  String get fmtList => 'Seznam';

  @override
  String get fmtChecklist => 'Úkoly';

  @override
  String get fmtLink => 'Odkaz';

  @override
  String get allNotes => 'Všechny poznámky';

  @override
  String get favorites => 'Oblíbené';

  @override
  String get uncategorised => 'Bez kategorie';

  @override
  String get categories => 'Kategorie';

  @override
  String get switchAccount => 'Přepnout účet';

  @override
  String get clearSearch => 'Zrušit hledání';

  @override
  String get noMatches => 'Hledání nic nenašlo.';

  @override
  String get noNotesHere => 'V této kategorii zatím nejsou poznámky.';

  @override
  String get newNoteHere => 'Nová poznámka sem';

  @override
  String get stateWaiting => 'Čeká';

  @override
  String get stateSending => 'Odesílá se';

  @override
  String get stateNeedsDecision => 'Čeká na rozhodnutí';

  @override
  String get relNow => 'Právě teď';

  @override
  String relMinutes(int count) {
    return 'před $count min';
  }

  @override
  String relHours(int count) {
    return 'před $count h';
  }

  @override
  String get relYesterday => 'Včera';

  @override
  String relDays(int count) {
    return 'před $count dny';
  }

  @override
  String conflictsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count poznámek čeká na rozhodnutí',
      few: '$count poznámky čekají na rozhodnutí',
      one: '1 poznámka čeká na rozhodnutí',
    );
    return '$_temp0';
  }

  @override
  String get signInAgain => 'Přihlásit znovu';

  @override
  String get resolveNow => 'Vyřešit';

  @override
  String get syncStatus => 'Stav synchronizace';

  @override
  String tasksDone(int done, int total) {
    return 'Splněno $done z $total úkolů';
  }

  @override
  String get hasAttachments => 'Obsahuje přílohy';

  @override
  String get serverEmpty => 'Zadej adresu svého serveru Nextcloud.';

  @override
  String get serverInsecure =>
      'Podporované jsou jen servery s https://. Jinak by přihlášení šlo sítí nešifrovaně.';

  @override
  String get serverInvalid =>
      'Tohle není platná adresa serveru. Příklad: cloud.example.com';

  @override
  String get serverNoLogin =>
      'Tento server nenabídl přihlášení Nextcloud. Zkontroluj adresu.';

  @override
  String get serverUnreachable =>
      'Server se nepodařilo zastihnout. Zkontroluj adresu a připojení.';

  @override
  String get browserUnavailable =>
      'Přihlašovací stránku se nepodařilo otevřít.';

  @override
  String get loginExpired => 'Přihlášení trvalo moc dlouho. Začni znovu.';

  @override
  String get scannedLoginRejected =>
      'Načtený přihlašovací kód se nepodařilo použít. Vytvořte na serveru nový.';

  @override
  String get onboardingTitle => 'Všechny poznámky v jedné aplikaci';

  @override
  String get onboardingBody =>
      'Připojte libovolný podporovaný Nextcloud server. Účty, jejich uložená data i práce na pozadí zůstávají přísně oddělené.';

  @override
  String get multiAccountTitle => 'Více účtů';

  @override
  String get multiAccountBody =>
      'Přidej další servery nebo uživatele a přepínej mezi nimi kdykoli.';

  @override
  String get secureLoginTitle => 'Žádné heslo v aplikaci';

  @override
  String get secureLoginBody =>
      'Přihlásíš se v prohlížeči. Telefon si ponechá jen heslo aplikace, které můžeš zrušit.';

  @override
  String get checkingServer => 'Kontrola serveru…';

  @override
  String get waitingForLogin => 'Dokončete přihlášení v prohlížeči';

  @override
  String get waitingForLoginBody =>
      'Po schválení aplikace v Nextcloudu bude tato obrazovka automaticky pokračovat.';

  @override
  String get savingAccount => 'Přihlašuji…';

  @override
  String get scanLoginCode => 'Načíst přihlašovací kód';

  @override
  String get scanLoginCodeHint =>
      'Namiřte fotoaparát na QR kód, který server ukáže v Nastavení, Zabezpečení, Vytvořit nové heslo aplikace.';

  @override
  String get scanLoginCodeUnreadable =>
      'Tohle není přihlašovací kód Nextcloudu.';

  @override
  String get scanCameraDenied =>
      'Přístup ke kameře je vypnutý. Povol ho v nastavení aplikace, aby šel kód naskenovat.';

  @override
  String get scanCameraUnavailable => 'Kameru se nepodařilo spustit.';

  @override
  String get openAppSettings => 'Otevřít nastavení';

  @override
  String get accounts => 'Účty';

  @override
  String get currentAccount => 'Aktuální účet';

  @override
  String get accountRemovedRevoked =>
      'Účet je odebraný. Jeho heslo aplikace je na serveru zrušené.';

  @override
  String get accountRemovedNotRevoked =>
      'Účet je odebraný z telefonu. Server to nepotvrdil, proto zruš heslo aplikace v Nextcloudu v Nastavení, Zabezpečení.';

  @override
  String get accountRemoveFailed => 'Účet se nepodařilo odebrat.';

  @override
  String get serverCertificate =>
      'Certifikát serveru se nepodařilo ověřit. Zkontroluj adresu, nebo oprav certifikát na serveru.';

  @override
  String get serverTimeout => 'Server odpovídal příliš dlouho. Zkus to znovu.';

  @override
  String get notesAppMissing =>
      'Aplikace Notes na tomto serveru není dostupná. Nainstaluj nebo zapni Nextcloud Notes.';

  @override
  String get reauthMismatch =>
      'Toto přihlášení patří jinému serveru nebo uživateli. Přihlas se stejným účtem, aby poznámky zůstaly.';

  @override
  String get recTitle => 'Porovnání verzí';

  @override
  String get recTabDevice => 'Zařízení';

  @override
  String get recTabServer => 'Server';

  @override
  String get recTabResult => 'Výsledek';

  @override
  String get recUseResult => 'Použít výsledek';

  @override
  String get recKeepSeparate => 'Ponechat jako samostatnou poznámku';

  @override
  String get recUseServer => 'Použít verzi ze serveru';

  @override
  String get recLeave => 'Nechat nevyřešené';

  @override
  String get recFillDevice => 'Dát do výsledku text ze zařízení';

  @override
  String get recFillServer => 'Dát do výsledku text ze serveru';

  @override
  String get recFillBoth => 'Dát do výsledku obojí';

  @override
  String get recResultReplaced => 'Výsledek byl nahrazen';

  @override
  String get recUndo => 'Zpět';

  @override
  String get recReasonConflict => 'Poznámku změnil tento telefon i server.';

  @override
  String get recReasonUnknown =>
      'Výsledek posledního odeslání není znám. Před rozhodnutím verze porovnej.';

  @override
  String get recReasonReadonly =>
      'Server ti už tuto poznámku upravovat nedovolí. Tvůj text zůstává, ulož ho jako vlastní poznámku.';

  @override
  String get recReasonMove =>
      'Poznámka s přílohami tady nemůže změnit kategorii. Ponech kategorii ze serveru, nebo ulož text jako samostatnou poznámku.';

  @override
  String get recReasonGeneric => 'Tato poznámka čeká na tvé rozhodnutí.';

  @override
  String recChangeCounter(int number, int total) {
    return 'Změna $number z $total';
  }

  @override
  String get recNoChanges => 'Text na zařízení a na serveru je stejný.';

  @override
  String get recPrevChange => 'Předchozí změna';

  @override
  String get recNextChange => 'Další změna';

  @override
  String get recServerChanged =>
      'Verze na serveru se mezitím znovu změnila. Porovnání teď ukazuje novější verzi, tvůj výsledek zůstává. Projdi ji a rozhodni znovu.';

  @override
  String get recKept =>
      'Obě verze zůstanou uložené v telefonu, dokud je sám neodstraníš.';

  @override
  String get recSaveAsNew => 'Uložit jako novou poznámku';

  @override
  String get recKeepCategory =>
      'Použít výsledek, ponechat kategorii ze serveru';

  @override
  String get recReadFailed => 'Verzi ze serveru se nepodařilo načíst.';

  @override
  String get recKeepRecovery => 'Ponechat v záchraně';

  @override
  String get settingsAppearance => 'Vzhled';

  @override
  String get settingsWriting => 'Psaní';

  @override
  String get settingsPrivacy => 'Soukromí';

  @override
  String get settingsSync => 'Synchronizace a úložiště';

  @override
  String get settingsTransfer => 'Import a export';

  @override
  String get settingsAbout => 'O aplikaci';

  @override
  String get settingsDeviceOnly =>
      'Tato nastavení platí jen pro toto zařízení.';

  @override
  String get theme => 'Motiv';

  @override
  String get themeSystem => 'Systémový';

  @override
  String get themeLight => 'Světlý';

  @override
  String get themeDark => 'Tmavý';

  @override
  String get language => 'Jazyk';

  @override
  String get languageSystem => 'Systémový';

  @override
  String get exportMarkdown => 'Exportovat Markdown';

  @override
  String get exportMarkdownHint =>
      'Poznámky jako soubory Markdown v ZIPu. Přílohy a záchranné kopie se neexportují.';

  @override
  String get widgetPolicyTitle => 'Widgety na ploše';

  @override
  String get widgetPolicyBody =>
      'Při zapnutém zámku aplikace widgety skrývají obsah poznámek, i když je aplikace odemčená.';

  @override
  String storageNotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count poznámek v tomto zařízení',
      few: '$count poznámky v tomto zařízení',
      one: '1 poznámka v tomto zařízení',
    );
    return '$_temp0';
  }

  @override
  String storageUnsent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count poznámek ještě není odeslaných',
      few: '$count poznámky ještě nejsou odeslané',
      one: '1 poznámka ještě není odeslaná',
      zero: 'Vše je odesláno na server',
    );
    return '$_temp0';
  }

  @override
  String get syncHint =>
      'Poznámky se synchronizují při otevření aplikace. Kdy poběží synchronizace na pozadí, rozhoduje systém.';

  @override
  String get exportUnsent => 'Exportovat neodeslané poznámky';

  @override
  String get removeFromDevice => 'Odebrat z tohoto zařízení';

  @override
  String get accountDetails => 'Podrobnosti účtu';

  @override
  String get accountUserLabel => 'Uživatel';

  @override
  String get accountServerLabel => 'Server';

  @override
  String get accountStatusLabel => 'Stav';

  @override
  String get accountSignedIn => 'Přihlášen';

  @override
  String get accountsManage => 'Spravovat účty';

  @override
  String get accountSwitchBlocked =>
      'Nepodařilo se uložit na zařízení, účet se proto nepřepnul.';

  @override
  String get removeLocalNote =>
      'Týká se to jen tohoto zařízení. Poznámky na serveru se nemažou.';

  @override
  String get loginCancelled => 'Přihlášení bylo zrušeno. Nic se neuložilo.';

  @override
  String get reauthExplain =>
      'Přihlas se jako stejný účet, aby zůstaly jeho poznámky a neodeslané změny.';

  @override
  String get scanConfirmTitle => 'Přihlásit se tímto kódem?';

  @override
  String scanConfirmBody(String user, String host) {
    return '$user na $host';
  }

  @override
  String get scanEnterAddress => 'Zadat adresu serveru';

  @override
  String get appLocked => 'OwnNotes je zamčené';

  @override
  String get undo => 'Zpět';

  @override
  String get redo => 'Znovu';

  @override
  String get dockFormat => 'Formát';

  @override
  String get dockTask => 'Úkol';

  @override
  String get dockAttach => 'Příloha';

  @override
  String get dockInsert => 'Vložit';

  @override
  String get fmtStrike => 'Přeškrtnutí';

  @override
  String get fmtQuote => 'Citace';

  @override
  String get fmtNumbered => 'Číslovaný seznam';

  @override
  String get fmtCode => 'Kód';

  @override
  String get fmtIndent => 'Odsadit';

  @override
  String get fmtOutdent => 'Předsadit';

  @override
  String get insertMention => 'Zmínka';

  @override
  String get insertEmoji => 'Emoji';

  @override
  String get smartPicker => 'Chytrý výběr';

  @override
  String get smartPickerNone =>
      'Tento server nenabízí nic, co by chytrý výběr uměl hledat.';

  @override
  String get attachPhoto => 'Fotka';

  @override
  String get attachCamera => 'Fotoaparát';

  @override
  String get attachFile => 'Soubor';

  @override
  String get attachVoice => 'Hlas';

  @override
  String get suggestSearching => 'Hledám…';

  @override
  String get suggestError => 'Návrhy teď nejsou k dispozici. Můžeš psát dál.';

  @override
  String suggestCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count návrhů',
      few: '$count návrhy',
      one: '1 návrh',
    );
    return '$_temp0';
  }

  @override
  String get suggestInsert => 'Vložit';

  @override
  String get cmdToday => 'Dnešní datum';

  @override
  String get cmdTime => 'Aktuální čas';

  @override
  String get cmdTable => 'Tabulka';

  @override
  String get cmdDivider => 'Oddělovač';

  @override
  String get calloutInfo => 'Informace';

  @override
  String get calloutWarning => 'Upozornění';

  @override
  String get calloutError => 'Chyba';

  @override
  String get calloutSuccess => 'Úspěch';

  @override
  String get detailsDefault => 'Podrobnosti';

  @override
  String mentionLabel(String name) {
    return 'Zmínka: $name';
  }

  @override
  String attachmentLabel(String name) {
    return 'Příloha: $name';
  }

  @override
  String tableLabel(int rows, int columns) {
    String _temp0 = intl.Intl.pluralLogic(
      rows,
      locale: localeName,
      other: '$rows řádků',
      few: '$rows řádky',
      one: '1 řádek',
    );
    String _temp1 = intl.Intl.pluralLogic(
      columns,
      locale: localeName,
      other: '$columns sloupců',
      few: '$columns sloupce',
      one: '1 sloupec',
    );
    return 'Tabulka, $_temp0 a $_temp1';
  }

  @override
  String get editSection => 'Upravit tuto část';

  @override
  String get checklistMarkdown => 'Markdown';

  @override
  String get checklistEmpty =>
      'Zatím tu nejsou žádné úkoly. První položku přidej dole.';

  @override
  String get checklistAdd => 'Přidat položku';

  @override
  String checklistCompletedGroup(int count) {
    return 'Hotovo ($count)';
  }

  @override
  String get clearCompleted => 'Odstranit hotové položky';

  @override
  String clearCompletedConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Odstranit z poznámky $count hotových položek?',
      few: 'Odstranit z poznámky $count hotové položky?',
      one: 'Odstranit z poznámky 1 hotovou položku?',
    );
    return '$_temp0';
  }

  @override
  String clearedCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Odstraněno $count položek',
      few: 'Odstraněny $count položky',
      one: 'Odstraněna 1 položka',
    );
    return '$_temp0';
  }

  @override
  String checklistPosition(int position, int total) {
    return '$position z $total';
  }

  @override
  String get checklistItemMenu => 'Možnosti položky';

  @override
  String get moveUp => 'Posunout nahoru';

  @override
  String get moveDown => 'Posunout dolů';

  @override
  String get shareTitle => 'Sdílet';

  @override
  String get shareSendCopy => 'Odeslat kopii';

  @override
  String get shareAsText => 'Odeslat jako text';

  @override
  String get shareAsFile => 'Odeslat jako soubor Markdown';

  @override
  String get shareWithPeople => 'Sdílet s lidmi';

  @override
  String get sharePeopleWithAccess => 'Lidé s přístupem';

  @override
  String get shareSearchHint => 'Hledat lidi';

  @override
  String get sharePermissionView => 'Může zobrazit';

  @override
  String get sharePermissionEdit => 'Může upravovat';

  @override
  String get shareRemove => 'Odebrat přístup';

  @override
  String get sharePending => 'Sdílím…';

  @override
  String get shareRemoving => 'Odebírám přístup…';

  @override
  String get shareFailed =>
      'Nepodařilo se. Zkontroluj připojení a zkus to znovu.';

  @override
  String get shareNotUploaded =>
      'Poznámka ještě není na serveru. Nejdřív se nahraje, potom ji lze sdílet.';

  @override
  String get shareUploadFirst => 'Nahrát a pokračovat';

  @override
  String get shareUploading => 'Nahrávám poznámku…';

  @override
  String get shareUploadFailed =>
      'Poznámku se zatím nepodařilo nahrát. Zůstává uložená v tomto zařízení.';

  @override
  String get shareIncoming =>
      'Tuto poznámku s tebou někdo sdílí. Dál ji může sdílet jen její vlastník.';

  @override
  String get shareAttachmentsWarning =>
      'Poznámka má přílohy. Lidé, se kterými ji sdílíš, je nemusí umět otevřít.';

  @override
  String get shareNone => 'Zatím s nikým nesdíleno.';

  @override
  String get shareNoResults => 'Nikdo takový nenalezen.';

  @override
  String get shareChecking => 'Zjišťuji sdílení…';

  @override
  String shareWithName(String name) {
    return 'Sdílet s uživatelem $name';
  }

  @override
  String get moreOptions => 'Další možnosti';

  @override
  String get openDetails => 'Podrobnosti';

  @override
  String get unfavorite => 'Odebrat z oblíbených';

  @override
  String get openChecklist => 'Otevřít seznam úkolů';

  @override
  String get attachments => 'Přílohy';

  @override
  String get historyRecovery => 'Historie a obnova';

  @override
  String get exportNote => 'Exportovat';

  @override
  String findCount(int index, int total) {
    return '$index z $total';
  }

  @override
  String get findPrevious => 'Předchozí shoda';

  @override
  String get saveFailedTitle => 'Nepodařilo se uložit v tomto zařízení';

  @override
  String get noteUnreadable =>
      'Server nevydal text této poznámky. Poslední kopie je uložená. Zkus to znovu, nebo si text zkopíruj.';

  @override
  String get exportDraft => 'Exportovat koncept';

  @override
  String get attachmentsNone => 'Poznámka nemá žádné přílohy.';

  @override
  String get attachmentImage => 'Obrázek';

  @override
  String get attachmentFile => 'Soubor';

  @override
  String get templates => 'Šablony';

  @override
  String get templatesEmpty => 'Zatím žádné šablony.';

  @override
  String get templatesManage => 'Spravovat šablony';

  @override
  String get templateNew => 'Nová šablona';

  @override
  String get templateEdit => 'Upravit šablonu';

  @override
  String get templateSave => 'Uložit';

  @override
  String get templateName => 'Název šablony';

  @override
  String templatePlaceholders(String placeholders) {
    return 'Doplní se při vytvoření poznámky: $placeholders';
  }

  @override
  String templateDeleteConfirm(String name) {
    return 'Smazat šablonu „$name“?';
  }

  @override
  String get templatesDeviceOnly =>
      'Šablony a denní poznámka zůstávají jen v tomto zařízení.';

  @override
  String get dailyNote => 'Denní poznámka';

  @override
  String get dailyNotePattern => 'Vzor názvu (například yyyy-MM-dd)';

  @override
  String get dailyNoteTemplate => 'Šablona';

  @override
  String get dailyNoteNoTemplate => 'Bez šablony';

  @override
  String dailyNotePreview(String title, String category) {
    return 'Dnes: „$title“ v kategorii $category';
  }

  @override
  String get categoriesMenu => 'Kategorie';

  @override
  String get syncNow => 'Synchronizovat hned';

  @override
  String get syncDetails => 'Podrobnosti synchronizace';

  @override
  String get selectNotes => 'Vybrat poznámky';

  @override
  String get sortAndFilter => 'Řazení a filtry';

  @override
  String accountSyncHint(String account) {
    return 'Podrobnosti synchronizace pro $account';
  }

  @override
  String get checkingForUpdates => 'Kontrola aktualizací';

  @override
  String syncSavedWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Uloženo v zařízení · čeká $count',
      few: 'Uloženo v zařízení · čekají $count',
      one: 'Uloženo v zařízení · čeká 1',
    );
    return '$_temp0';
  }

  @override
  String syncUploading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Odesílá se $count změn',
      few: 'Odesílají se $count změny',
      one: 'Odesílá se 1 změna',
    );
    return '$_temp0';
  }

  @override
  String syncUpToDate(String time) {
    return 'Aktuální · zkontrolováno $time';
  }

  @override
  String get syncOffline => 'Offline · změny jsou uložené v zařízení';

  @override
  String get syncOfflineShort => 'Offline';

  @override
  String get syncAuthFailure => 'Přihlas se znovu · místní poznámky zůstávají';

  @override
  String get syncSaveFailure => 'Uložení v tomto zařízení se nepodařilo';

  @override
  String get needsAttention => 'Vyžaduje pozornost';

  @override
  String get sharedWithMe => 'Sdíleno se mnou';

  @override
  String get savedViews => 'Uložená zobrazení';

  @override
  String get onThisDevice => 'V tomto zařízení';

  @override
  String get saveView => 'Uložit toto zobrazení';

  @override
  String get saveViewName => 'Název zobrazení';

  @override
  String get deleteView => 'Smazat uložené zobrazení';

  @override
  String get sheetUploads => 'Odesílání';

  @override
  String get sheetDownloads => 'Stahování';

  @override
  String get sheetDecisions => 'Rozhodnutí';

  @override
  String get sheetDeletions => 'Mazání';

  @override
  String get uploadsNone => 'Nic nečeká na odeslání';

  @override
  String get downloadsNever => 'Zatím nezkontrolováno';

  @override
  String downloadsUnreadable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count poznámek nelze obnovit',
      few: '$count poznámky nelze obnovit',
      one: '1 poznámku nelze obnovit',
    );
    return '$_temp0';
  }

  @override
  String downloadsMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count poznámek server už nevypisuje',
      few: '$count poznámky server už nevypisuje',
      one: '1 poznámku server už nevypisuje',
    );
    return '$_temp0';
  }

  @override
  String get decisionsNone => 'Žádná poznámka nečeká na rozhodnutí';

  @override
  String get deletionsNone => 'Žádné mazání nečeká';

  @override
  String deletionsWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count smazání čeká na server',
      few: '$count smazání čekají na server',
      one: '1 smazání čeká na server',
    );
    return '$_temp0';
  }

  @override
  String deletionsFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count smazání selhalo',
      few: '$count smazání selhala',
      one: '1 smazání selhalo',
    );
    return '$_temp0';
  }

  @override
  String get reviewItems => 'Zkontrolovat';

  @override
  String get rowSavedWaiting => 'Uloženo v zařízení · Čeká na odeslání';

  @override
  String get rowUploading => 'Odesílají se změny';

  @override
  String get rowNeedsDecision => 'Čeká na tvé rozhodnutí';

  @override
  String get rowUnavailable => 'Tuto poznámku nelze obnovit';

  @override
  String get rowMissing => 'Server ji už nevypisuje';

  @override
  String get rowSharedEdit => 'Sdíleno · Lze upravovat';

  @override
  String get rowSharedView => 'Sdíleno · Jen pro čtení';

  @override
  String attachmentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count příloh',
      few: '$count přílohy',
      one: '1 příloha',
    );
    return '$_temp0';
  }

  @override
  String rowMenu(String title) {
    return 'Akce pro $title';
  }

  @override
  String get openNote => 'Otevřít';

  @override
  String get moveNote => 'Přesunout';

  @override
  String get rowDeletionWaiting => 'Smazání čeká';

  @override
  String rowDeletionFailed(String reason) {
    return 'Smazání selhalo · $reason';
  }

  @override
  String get undoAction => 'Zpět';

  @override
  String get saveCopy => 'Uložit kopii';

  @override
  String categoryCount(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count poznámek',
      few: '$count poznámky',
      one: '1 poznámka',
    );
    return '$name, $_temp0 včetně podkategorií';
  }

  @override
  String expandCategory(String name) {
    return 'Rozbalit $name';
  }

  @override
  String collapseCategory(String name) {
    return 'Sbalit $name';
  }

  @override
  String openSubtree(String name) {
    return 'Zobrazit $name samostatně';
  }

  @override
  String get allCategoriesUp => 'Všechny kategorie';

  @override
  String get createNote => 'Poznámka';

  @override
  String get createChecklist => 'Seznam úkolů';

  @override
  String get createTemplate => 'Šablona';

  @override
  String get createDaily => 'Denní poznámka';

  @override
  String get createWhere => 'Do které kategorie poznámka patří?';

  @override
  String get createNoteAction => 'Vytvořit poznámku';

  @override
  String get createHere => 'Vytvořit zde';

  @override
  String get filterTasks => 'Nedokončené úkoly';

  @override
  String get filterAttachments => 'S přílohami';

  @override
  String get filterShared => 'Sdílené';

  @override
  String get filterWaiting => 'Ještě neodesláno';

  @override
  String get filterDecision => 'Čeká na rozhodnutí';

  @override
  String get filterSharing => 'Sdílení';

  @override
  String get filterSync => 'Stav synchronizace';

  @override
  String get clearFilters => 'Zrušit filtry';

  @override
  String get sortTitle => 'Řazení';

  @override
  String get sortFavoritesFirst => 'Nejdřív oblíbené';

  @override
  String get emptyFavoritesTitle => 'Zatím žádné oblíbené';

  @override
  String get emptyFavoritesBody =>
      'Označ poznámku hvězdičkou a najdeš ji tady. Použij nabídku poznámky nebo ji přejeďte.';

  @override
  String get emptySharedTitle => 'Nic s tebou není sdíleno';

  @override
  String get emptySharedBody =>
      'Poznámky, které s tímto účtem sdílejí ostatní, se zobrazí tady.';

  @override
  String get emptyAttentionTitle => 'Nic nevyžaduje tvou pozornost';

  @override
  String get emptyAttentionBody =>
      'Rozhodnutí, nezdařená mazání a poznámky, které nelze obnovit, se zobrazí tady.';

  @override
  String emptyCategoryTitle(String category) {
    return 'Kategorie $category je prázdná';
  }

  @override
  String get downloadingTitle => 'Stahují se tvoje poznámky';

  @override
  String downloadingBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zatím staženo $count poznámek',
      few: 'Zatím staženy $count poznámky',
      one: 'Zatím stažena 1 poznámka',
    );
    return '$_temp0';
  }

  @override
  String get connectNextcloud => 'Připojit Nextcloud';

  @override
  String get scanLoginQr => 'Naskenovat přihlašovací QR kód';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vybráno $count',
      few: 'vybrány $count',
      one: 'vybrána 1',
    );
    return '$_temp0';
  }

  @override
  String get bulkFavorite => 'Oblíbit';

  @override
  String get bulkUnfavorite => 'Odebrat z oblíbených';

  @override
  String get bulkMove => 'Přesunout';

  @override
  String get bulkExport => 'Exportovat';

  @override
  String get bulkMixedMove =>
      'Přesun není dostupný, protože některé vybrané poznámky jsou jen pro čtení, sdílené nebo mají přílohy.';

  @override
  String get bulkMixedDelete =>
      'Smazání není dostupné, protože některé vybrané poznámky jsou jen pro čtení, sdílené nebo se právě odesílají.';

  @override
  String get bulkMixedFavorite =>
      'Oblíbení není dostupné, protože některé vybrané poznámky jsou sdílené.';

  @override
  String bulkDeleteConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Smazat $count poznámek?',
      few: 'Smazat $count poznámky?',
      one: 'Smazat 1 poznámku?',
    );
    return '$_temp0';
  }

  @override
  String get bulkDeleteBody =>
      'Poznámky se smažou i na serveru. Do provedení na serveru to můžeš vrátit zpět.';

  @override
  String notesDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Smazáno $count poznámek',
      few: 'Smazány $count poznámky',
      one: 'Smazána 1 poznámka',
    );
    return '$_temp0';
  }

  @override
  String notesMoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Přesunuto $count poznámek',
      few: 'Přesunuty $count poznámky',
      one: 'Přesunuta 1 poznámka',
    );
    return '$_temp0';
  }

  @override
  String bulkFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count poznámek se nepodařilo změnit',
      few: '$count poznámky se nepodařilo změnit',
      one: '1 poznámku se nepodařilo změnit',
    );
    return '$_temp0';
  }

  @override
  String get moveTitle => 'Přesunout do kategorie';

  @override
  String get moveNewCategory => 'Nová kategorie';

  @override
  String get moveNewCategoryHint => 'Název, podkategorie oddělte /';

  @override
  String get clearSelection => 'Zrušit výběr';

  @override
  String get rowFavoriteOn => 'Přidat do oblíbených';

  @override
  String get rowFavoriteOff => 'Odebrat z oblíbených';

  @override
  String get attachmentsTitle => 'Přílohy';

  @override
  String get attachmentsEmpty => 'Tato poznámka nemá žádné přílohy.';

  @override
  String get attachStored => 'Uloženo v zařízení';

  @override
  String get attachWaiting => 'Čeká na nahrání';

  @override
  String get attachWaitingNote => 'Čeká na nahrání poznámky';

  @override
  String get attachUploading => 'Nahrává se';

  @override
  String get attachOffline => 'K dispozici offline';

  @override
  String get attachOnServer => 'Na serveru';

  @override
  String get attachUnavailable => 'Nedostupné';

  @override
  String attachFailedState(String reason) {
    return 'Selhalo: $reason';
  }

  @override
  String get attachErrOffline => 'Server není dostupný.';

  @override
  String get attachErrAuth => 'Pro nahrání se přihlas znovu.';

  @override
  String get attachErrTooLarge =>
      'Server soubor odmítl, protože je příliš velký.';

  @override
  String get attachErrDenied => 'Server nahrání nepovolil.';

  @override
  String get attachErrNoteGone => 'Poznámka už na serveru neexistuje.';

  @override
  String get attachErrServer => 'Server vrátil chybu.';

  @override
  String get attachRemoveQueue => 'Odebrat z fronty';

  @override
  String get attachRemoveLink => 'Odebrat odkaz z poznámky';

  @override
  String get attachRemoveLinkHelp =>
      'Odebráním odkazu se upraví jen tato poznámka. Soubor zůstane na serveru.';

  @override
  String get attachDeleteFile => 'Smazat soubor na serveru';

  @override
  String get attachDeleteTitle => 'Smazat soubor na serveru?';

  @override
  String get attachDeleteBody =>
      'Soubor se ze serveru nenávratně odstraní. Jiné poznámky a zařízení, které na něj odkazují, ukážou chybějící soubor.';

  @override
  String get attachDeleteFileOnly => 'Smazat soubor';

  @override
  String get attachDeleteFileAndLink => 'Smazat soubor i odkaz';

  @override
  String get attachDeleteUnsupported =>
      'Tato verze serveru nepodporuje mazání příloh. Odeberte jen odkaz; soubor na serveru zůstane.';

  @override
  String get attachDeleteFailed => 'Soubor se nepodařilo smazat.';

  @override
  String get attachKeepOffline => 'Uložit offline';

  @override
  String get attachUploadFailedTitle => 'Nahrání selhalo';

  @override
  String get attachKeepForLater => 'Nechat na později';

  @override
  String get attachSavedWaiting =>
      'Uloženo v zařízení. Nahraje se, až bude poznámka na serveru, a odkaz se do ní doplní.';

  @override
  String get attachSavedQueued =>
      'Uloženo v zařízení. Odkaz se do poznámky doplní po nahrání.';

  @override
  String get attachTooLarge => 'Soubor je větší než 64 MB a nebyl připojen.';

  @override
  String get attachReadFailed => 'Soubor se nepodařilo přečíst.';

  @override
  String get attachWorking => 'Přidávám přílohu…';

  @override
  String get voiceTitle => 'Hlasový záznam';

  @override
  String get voiceReady => 'Připraveno k nahrávání';

  @override
  String get voiceRecording => 'Nahrává se';

  @override
  String get voicePaused => 'Pozastaveno';

  @override
  String get voiceStopped => 'Nahrávání zastaveno';

  @override
  String get voiceStart => 'Spustit nahrávání';

  @override
  String get voicePause => 'Pozastavit';

  @override
  String get voiceResume => 'Pokračovat';

  @override
  String get voiceStop => 'Zastavit';

  @override
  String get voiceListen => 'Poslechnout';

  @override
  String get voiceStopListening => 'Zastavit přehrávání';

  @override
  String get voiceAttach => 'Připojit';

  @override
  String get voiceDiscard => 'Zahodit';

  @override
  String get voiceDiscardTitle => 'Zahodit tento záznam?';

  @override
  String get voiceDiscardBody => 'Záznam se smaže z tohoto zařízení.';

  @override
  String get voiceMicDenied =>
      'Přístup k mikrofonu je vypnutý. Povol ho v nastavení systému.';

  @override
  String get voiceInterrupted =>
      'Nahrávání se pozastavilo, protože byla aplikace přerušena. Záznam zůstává zachován.';

  @override
  String get voiceRecovered => 'Obnoven dřívější záznam.';

  @override
  String get voiceFailed => 'Nahrávání se nezdařilo.';

  @override
  String voiceElapsed(String time) {
    return 'Délka záznamu $time';
  }

  @override
  String get captureTitle => 'Sdílený obsah';

  @override
  String get captureAccount => 'Účet';

  @override
  String get captureChooseAccount => 'Vyber účet pro tento obsah.';

  @override
  String get captureUnknownAccount =>
      'Odesílatel uvedl účet, který tu není přihlášen. Vyber jiný.';

  @override
  String get captureNewNote => 'Nová poznámka';

  @override
  String get captureAppend => 'Připojit k poznámce';

  @override
  String get captureCategory => 'Kategorie (volitelné)';

  @override
  String get captureSearchTarget => 'Hledat poznámku, ke které připojit';

  @override
  String get captureNoTarget => 'Vyber poznámku, ke které se připojí.';

  @override
  String get captureNoMatches => 'Žádná shodná poznámka.';

  @override
  String get captureSave => 'Uložit do zařízení';

  @override
  String get captureDiscard => 'Zahodit';

  @override
  String get captureDiscardTitle => 'Zahodit sdílený obsah?';

  @override
  String get captureDiscardBody =>
      'Smaže se z tohoto zařízení a poznámka se nevytvoří.';

  @override
  String get captureKept =>
      'Zavřením obrazovky se obsah ponechá, dokud se nerozhodneš.';

  @override
  String get captureNoText => 'Bez textu, jen soubory.';

  @override
  String get captureSaveFailed =>
      'Do zařízení se nepodařilo uložit. Obsah zůstává zachován.';

  @override
  String captureFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count souborů',
      few: '$count soubory',
      one: '1 soubor',
    );
    return '$_temp0';
  }

  @override
  String importKeepAttachments(int notes, int files, int skipped) {
    return 'Importováno poznámek: $notes, příloh: $files, přeskočených souborů: $skipped.';
  }

  @override
  String get attachMoreOptions => 'Další možnosti';

  @override
  String get widgetConfigTitle => 'Nastavení widgetu';

  @override
  String get widgetTypeLabel => 'Typ widgetu';

  @override
  String get widgetTypeList => 'Seznam poznámek';

  @override
  String get widgetTypeNote => 'Jedna poznámka';

  @override
  String get widgetTypeChecklist => 'Úkoly';

  @override
  String get widgetTypeQuick => 'Rychlá poznámka';

  @override
  String get widgetAccountLabel => 'Účet';

  @override
  String get widgetCollectionLabel => 'Zobrazené poznámky';

  @override
  String get widgetNoteLabel => 'Poznámka';

  @override
  String get widgetNoChecklistNotes => 'Tento účet nemá poznámku s úkoly.';

  @override
  String get widgetAppearanceLabel => 'Vzhled';

  @override
  String get widgetAdd => 'Přidat widget';

  @override
  String get widgetNoAccount => 'Před přidáním widgetu se přihlas v OwnNotes.';

  @override
  String get widgetSaveFailed => 'Widget se nepodařilo nastavit.';

  @override
  String aboutVersion(String version, String build) {
    return 'Verze $version ($build)';
  }

  @override
  String get aboutFormatTitle => 'Obyčejné soubory Markdown';

  @override
  String get aboutFormatBody =>
      'Poznámky jsou soubory Markdown ve složce Notes a kategorie jsou složky. Otevře je i webová aplikace Notes, aplikace Text a další klienti.';

  @override
  String get aboutServer => 'Server';

  @override
  String get aboutServerUnknown => 'Server svou verzi neuvedl.';

  @override
  String get aboutWebsite => 'Web aplikace';

  @override
  String get aboutPrivacy => 'Zásady ochrany soukromí';

  @override
  String get aboutSupport => 'Napsat podpoře';

  @override
  String get aboutLicenses => 'Licence open-source součástí';

  @override
  String get aboutCopyright => '© 2026 NKS Hub';

  @override
  String get rowSharedByYou => 'Sdílíš s ostatními';

  @override
  String get shareOtherMethods =>
      'Poznámka je sdílená i jiným způsobem, například přes složku, odkaz nebo skupinu. Toto sdílení spravuješ v Nextcloudu.';

  @override
  String get backgroundSyncTitle => 'Synchronizace na pozadí';

  @override
  String get backgroundSyncOff => 'Vypnuto';

  @override
  String backgroundSyncMinutes(int minutes) {
    return 'Každých $minutes minut';
  }

  @override
  String backgroundSyncHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Každých $hours hodin',
      few: 'Každé $hours hodiny',
      one: 'Každou hodinu',
    );
    return '$_temp0';
  }

  @override
  String get backgroundSyncWifi => 'Jen Wi-Fi';

  @override
  String get backgroundSyncHint =>
      'Platí při zavřené aplikaci, včetně změn z widgetů. Otevřená aplikace používá dostupnou síť. Čas spuštění na pozadí určuje Android.';

  @override
  String get backgroundSyncLoadFailed =>
      'Nastavení synchronizace nelze načíst. Klepnutím zkuste znovu.';

  @override
  String get backgroundSyncSaveFailed =>
      'Nastavení synchronizace se nepodařilo uložit nebo použít.';

  @override
  String get telemetryTitle => 'Diagnostika a používání aplikace';

  @override
  String get telemetryDescription =>
      'Odesílá chyby a názvy obrazovek do Sentry a Rybbit. Texty poznámek ani přihlašovací údaje se neodesílají. Vypnutí platí ihned, zapnutí po novém spuštění.';

  @override
  String get telemetryRestart =>
      'Diagnostika se zapne při příštím spuštění aplikace.';

  @override
  String get telemetrySaveFailed => 'Volbu diagnostiky se nepodařilo uložit.';

  @override
  String get addServerTitle => 'Přidat Nextcloud server';

  @override
  String certificateChangedBody(String host) {
    return 'Server $host nyní předkládá jiný certifikát, než kterému tento účet důvěřuje. Pokud jste certifikát vyměnili vy, účet odeberte a přidejte znovu.';
  }

  @override
  String get certificateChangedTitle => 'Certifikát serveru se změnil';

  @override
  String get certificateFingerprintLabel => 'Otisk SHA-256';

  @override
  String get certificateTrustAction => 'Důvěřovat a pokračovat';

  @override
  String certificateUnverifiedBody(String host) {
    return 'Server $host předložil certifikát, který zařízení neumí ověřit. Pokračujte jen tehdy, když otisk níže odpovídá tomu, co ukazuje váš server.';
  }

  @override
  String get certificateUnverifiedTitle => 'Neověřený certifikát serveru';

  @override
  String get close => 'Zavřít';

  @override
  String get invalidResponse =>
      'Server vrátil odpověď, kterou aplikace nemůže bezpečně použít.';

  @override
  String get invalidServer => 'Zadejte platnou HTTPS adresu Nextcloud serveru.';

  @override
  String get localPersistenceFailed =>
      'Účet se nepodařilo bezpečně uložit do tohoto zařízení.';

  @override
  String get loginTimedOut =>
      'Požadavek na přihlášení vypršel. Spusťte jej znovu.';

  @override
  String get multiServerBody =>
      'Přidejte osobní i pracovní účty bez nového sestavení aplikace a bez sdílení jejich dat.';

  @override
  String get multiServerTitle => 'Připraveno pro více serverů';

  @override
  String get openingLogin => 'Otevírá se bezpečné přihlášení…';

  @override
  String get reauthenticateAccountAction => 'Přihlásit se znovu';

  @override
  String get reauthenticateAccountMismatch =>
      'Přihlaste se ke stejnému účtu. Uložený účet nebyl změněn.';

  @override
  String get reauthenticateAccountTitle => 'Znovu se přihlásit k tomuto účtu';

  @override
  String get scanLoginCodeCameraDenied =>
      'Přístup k fotoaparátu je vypnutý. Povolte jej v nastavení systému, aby šlo kód načíst.';

  @override
  String get scanLoginCodeCameraUnavailable =>
      'Toto zařízení nemá fotoaparát, kterým by šlo kód načíst.';

  @override
  String get secureBody =>
      'Hesla aplikace se ukládají do systémového Keychainu nebo Keystoru, nikdy do databáze poznámek.';

  @override
  String get secureTitle => 'Přihlašovací údaje zůstávají v zařízení';

  @override
  String get serverAddressHint => 'cloud.example.com';

  @override
  String get serverAddressLabel => 'Adresa serveru';

  @override
  String get serverMaintenance => 'Server je právě v režimu údržby.';

  @override
  String get serverNotInstalled =>
      'Nextcloud na tomto serveru zatím není nainstalovaný.';

  @override
  String get serverUnavailable =>
      'Server se nepodařilo kontaktovat. Zkontrolujte adresu a připojení.';

  @override
  String get serverUpgrade =>
      'Server musí nejdřív dokončit aktualizaci databáze.';

  @override
  String get unexpectedError => 'Něco se nepodařilo. Data účtu nebyla změněna.';
}
