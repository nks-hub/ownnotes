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
  String get reasonAuth => 'Server odmítl přihlášení. Přidej účet znovu.';

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
      'Odebrat účet z tohoto telefonu? Poznámky na serveru zůstanou.';

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
}
