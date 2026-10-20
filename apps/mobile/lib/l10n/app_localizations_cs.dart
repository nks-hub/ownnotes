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
  String get connect => 'Připojit';

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
      'Prohlížeč se pro přihlášení nepodařilo otevřít.';

  @override
  String get loginExpired => 'Přihlášení trvalo moc dlouho. Začni znovu.';

  @override
  String get scannedLoginRejected =>
      'Server naskenovaný kód odmítl. Možná je starý nebo zrušený. Vytvoř nový.';

  @override
  String get onboardingTitle => 'Tvoje poznámky na tvém Nextcloudu';

  @override
  String get onboardingBody =>
      'OwnNotes synchronizuje poznámky v Markdownu s aplikací Nextcloud Notes. Jdou na tvůj server a nikam jinam.';

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
  String get checkingServer => 'Kontroluji server…';

  @override
  String get waitingForLogin => 'Čekám na přihlášení';

  @override
  String get waitingForLoginBody =>
      'Schval přístup v prohlížeči a vrať se do aplikace.';

  @override
  String get savingAccount => 'Přihlašuji…';

  @override
  String get scanLoginCode => 'Skenovat QR kód';

  @override
  String get scanLoginCodeHint =>
      'Namiř kameru na přihlašovací QR kód z Nextcloudu (Nastavení, Zabezpečení, hesla aplikací).';

  @override
  String get scanLoginCodeUnreadable =>
      'Tohle není přihlašovací kód Nextcloudu.';

  @override
  String get scanCameraDenied =>
      'Přístup ke kameře je vypnutý. Povol ho v nastavení aplikace, aby šel kód naskenovat.';

  @override
  String get scanCameraUnavailable => 'Kameru se nepodařilo spustit.';

  @override
  String get openAppSettings => 'Otevřít nastavení aplikace';

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
}
