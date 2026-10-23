# OwnNotes

OwnNotes je mobilní klient Nextcloud Notes ve Flutteru pro Android a iOS.
Poznámky ukládá také do zařízení, aby šly upravovat bez připojení.
Na serveru zůstávají obyčejné soubory Markdown a kategorie odpovídají složkám.

## Co je implementované

- Více účtů, přihlášení přes Nextcloud Login Flow v2 a bezpečné úložiště přístupových údajů.
- Lokální databáze SQLite, průběžné ukládání, synchronizace a ruční řešení konfliktů.
- Editor Markdownu, výslovně zapínaný náhled, seznamy úkolů, šablony, historie úprav a hledání v poznámce.
- Kategorie, oblíbené, uložené pohledy a filtry pro přílohy, úkoly a stav synchronizace.
- Přílohy s frontou přenosů a lokální mezipamětí, sdílení přes Nextcloud a příjem obsahu z jiných aplikací.
- Widgety, zámek aplikace, světlý a tmavý vzhled, čeština, angličtina a němčina.
- Rozložení se seznamem a editorem vedle sebe na širších obrazovkách.
- Synchronizace na pozadí v Androidu přes WorkManager; systém rozhoduje o skutečném čase spuštění.
- Volitelné Sentry a Rybbit, zapínané nastavením při sestavení.

Tento seznam popisuje kód. Rozsah automatických a fyzických testů je uveden
v [historii](docs/history.md); otevřené úkoly jsou v [TODO.md](TODO.md).
Starší audity popisují své uvedené revize, nikoli vždy dnešní stav.

## Otevřené části

Export ZIP obsahuje poznámky Markdown, ale zatím nejde o úplnou obnovitelnou
zálohu s metadaty a přílohami. Otevřené jsou také serverová historie a koš,
nastavení intervalu a Wi-Fi pro Android, synchronizace na pozadí v iOS,
`notify_push` a desktopové sestavení.

SQLite databáze není šifrovaná. Fyzický Fold, tablet, QR přihlášení kamerou
a některé scénáře iOS stále vyžadují ověření podle TODO. Sestavení aplikace
samo o sobě nedokládá funkčnost těchto scénářů.

## Run and verify

Flutter is pinned to **3.47.7** (`.flutter-version`), Dart **3.13.5**. Use the
committed dependency lockfiles. Install hooks after cloning:

```bash
git config user.name LuRy
git config user.email lury@lury.cz
git config core.hooksPath .githooks
bash tool/check.sh
bash tool/check_mobile.sh
cd apps/mobile
flutter run
```

`check_mobile.sh` serializes Flutter tests using `flock` on Linux/macOS systems
with that command installed. Windows runners must serialize this checkout too.
Build-host SDK telemetry is suppressed by the verification scripts. On restricted
root containers, `TAR_OPTIONS=--no-same-owner` may be needed for SDK extraction.

The app is **OwnNotes**, `com.nkshub.nextcloudnotes` on Android and iOS, and
ships through Google Play. A build to test beside the installed app uses
`--android-project-arg=candidate=true`, which gives
`com.nkshub.nextcloudnotes.candidate` labelled "OwnNotes Candidate". Release
builds need `apps/mobile/android/key.properties` (gitignored) pointing at the
upload keystore; there is no fallback to the debug key. GitHub CI includes an
Android debug build.

## Documentation

- [Implementation plan](docs/architecture/implementation-plan.md)
- [Synchronization invariants](docs/architecture/synchronization.md)
- [Development workflow](docs/architecture/development.md)
- [Candidate behavior and limitations](docs/architecture/candidate.md)
- [Evidence and remaining gates](docs/acceptance/status.md)
- [Protocol sources](contracts/notes/README.md)
- [Original supplied research](docs/research/original-plan.cs.md)

Source is published in the private repository `nks-hub/ownnotes`. All commits
must have author and committer `LuRy <lury@lury.cz>`. Final licensing is undecided.
