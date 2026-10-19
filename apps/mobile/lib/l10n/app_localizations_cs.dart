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
}
