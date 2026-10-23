# History

Finished work with how it was verified. Newest first is not guaranteed; dates are exact.

- 2026-10-23 Nastavení Androidu nabízí vypnutí synchronizace na pozadí, interval 15/30 minut nebo 1/6 hodin a režim jen přes Wi-Fi. Stejná volba platí pro odesílání změn z widgetů. Kontrola před každým požadavkem čte aktuální nastavení; otevřená aplikace používá dostupnou síť. Změna intervalu zachová běžící práci, vypnutí zruší obě úlohy. Pravidelná úloha bez povolené sítě počká na svůj další interval, jednorázová opakuje pokus. Revize `73e1283`: celá mobilní sada 375 testů prošla; poslední úpravu řízení úloh ověřilo všech 12 cílených testů. Statická kontrola bez nálezů. Regresní test zachytil odchod z nastavení během zápisu; nový plán se nyní použije i po zavření obrazovky.
- 2026-10-23 Finální debug kandidát 0.2.3+6, SHA-256 `74bcad2093d5c9688373eacc1af9d1997e68290fe47ace415fed90a115300d95`, nainstalován na S9+ a S21. Na obou ověřena změna intervalu v databázi WorkManageru, uložení Wi-Fi režimu, zrušení úloh při vypnutí a zachování voleb přes aktualizaci aplikace. Obnoven výchozí interval 15 minut a libovolná síť. Mobilní síť a VPN pokrývají automatické testy, ne fyzický přenos přes mobilní data.
- 2026-10-23 S21 dokončil úlohu na pozadí. S9 měl v úsporném režimu zakázanou veškerou síť na pozadí (`REJECT_ALL`); běžné vypnutí úsporného režimu přes ADB se neuplatnilo. Po dočasném vypnutí přepínače `low_power_back_data_off` stáhl novou testovací poznámku, zatímco aplikace zůstala v pozadí, a jednorázová úloha skončila úspěšně. Testovací poznámka byla odstraněna. Původní blokování dat i úsporný režim byly vráceny na 1; Wi-Fi i mobilní data zůstaly zapnuté. Po dokončení zůstalo na S9/S21 212/224 místních záznamů a původní účty.

- 2026-10-23 Migrace na verzi databáze 7 uvolňuje vzdálené ID a ETag starých archivovaných konfliktů. Text, ostatní pole archivu a historie operací zůstávají zachované. Revize `50be047`: tři regresní testy před opravou selhaly, po opravě prošly; celá databázová sada má 100 úspěšných testů a tři přeskočené živé testy. Statická kontrola balíčku bez nálezů. Ověřena migrace z verzí 5 a 6, více účtů, zachování nevyřešeného konfliktu a nové načtení serverové poznámky místo skrytého archivu.
- 2026-10-23 Debug kandidát 0.2.3+6, SHA-256 `8a44dba881f3071be2042e2495f204b856d4e2f4e6a903152d0ed2f34fd9078f`, aktualizován na S9+ a S21 se zachováním účtů a 212/224 místních záznamů. Na S9 jsou všechny tři archivy i jejich historie zachované; bod synchronizace a ETag už vznikají. Po restartu aplikace proběhla úspěšná kontrola bez změny tohoto bodu a revizí poznámek. S21 zachoval svůj dosavadní ETag. Samostatný klient nad kopií databáze S9 proti skutečnému serveru ověřil přechod od celého stránkovaného seznamu přes stažení změn až k HTTP 304. Překážka starých archivů je odstraněna z TODO.

- 2026-10-23 Bod synchronizace přežije restart; databáze má verzi 6. ETag ověřuje celý seznam se stejným `pruneBefore`, nikdy jen první stránku. Přerušené stahování a přeskočené místní změny neposunou uložený bod. Příliš velká odpověď vrací klienta ke stránkování. Revize `0d508b9`: 102 protokolových a 97 databázových testů prošlo; osm živých testů se bez přístupů přeskočilo. Celá mobilní sada prošla se 363 testy, následně prošlo všech osm posílených testů příloh. Statické kontroly bez nálezů. Test menu příloh už nečeká na dokončení animace načítaného obrázku; čekání na opakované načtení ověřuje zobrazení obrázku.
- 2026-10-23 Samostatné procesy proti skutečnému Nextcloudu ověřily první seznam, další stažení jen změn a HTTP 304 po restartu klienta. Pro tři testovací poznámky měla těla odpovědí 1 073, 37 a 0 bajtů. Nová dočasná poznámka byla při změně stažena a po odstranění zmizela ze seznamu. Jde o tento konkrétní vzorek, ne obecné měření výkonu.
- 2026-10-23 Debug kandidát 0.2.3+6 ze stejného kódu, SHA-256 `3170056e31e66617e0b159c14a9350f535661f0db751d78aac0ff43853ac6a7b`, nainstalován přes předchozí verzi na S9+ a S21. Migrace zachovala 1/3 účty a 212/224 místních záznamů. Oba testované účty synchronizovaly bez chyby. Na S21 zůstal po restartu bod synchronizace i revize uložených poznámek stejné a čas úspěšné kontroly se posunul. Na S9 optimalizaci blokuje starý archivovaný konflikt se vzdáleným ID; jeho oprava je v TODO. Kontrolní součty všech tří archivovaných textů zůstaly stejné.


- 2026-10-23 Vykreslování editoru a hlavní obrazovky je oddělené od jejich stavu. `editor.dart` má 908 řádků, `home.dart` 954; pohledy mají 368 a 696 řádků. Místní příkazy editoru a výpočet seznamu poznámek mají vlastní soubory. Řadiče, historie změn a ukládání zůstaly u původních vlastníků. Revize `a25bb36`: 363 mobilních testů prošlo, statická kontrola bez nálezů.
- 2026-10-23 Debug kandidát 0.2.3+6, SHA-256 `76dc8dafa5751831b965c68e4b1f743798c75cc3618cdb7cb9ac71cf95561813`, ověřen na S9+ a S21. Na obou prošlo otevření poznámky, vložení znaku, vrácení původního textu, náhled a návrat do seznamu; na S9+ i zobrazení obrázkové přílohy. Testovací texty byly obnoveny.


- 2026-10-23 Poznámky přijaté přes Notes API mají označení sdílení a patří také do „Sdíleno se mnou“. Vlastní sdílené poznámky mají samostatný štítek a zůstávají ve svých kategoriích. Směr sdílení se ukládá odděleně od synchronizačního rozhraní; databáze se rozšiřuje na verzi 5. Dialog upozorní i na další způsoby sdílení, například skupiny a odkazy. Načítání sdílených souborů bylo odděleno ze `sync.dart`, který má nyní méně než 1 000 řádků.
- 2026-10-23 Revize `95d5888`: 363 mobilních, 95 protokolových a 76 databázových testů prošlo, osm živých testů bez přístupů se přeskočilo; statické kontroly bez nálezů. Ověřeny migrace verzí 1–4, souběh uživatelského a skupinového sdílení, zachování starých údajů při chybě odchozího seznamu, zrušení sdílení a český štítek při 200% písmu na šířce 320 bodů.
- 2026-10-23 Debug kandidát 0.2.3+6, SHA-256 `3bba1b886109e5f791ee71c1d616b7442c48591355e5c1898e67080a4e19a28d`, ověřen na S9+ jako příjemci a S21 jako vlastníkovi. Testovací soubor byl u příjemce přesunut do Notes: staré APK ho neoznačovalo, nové ukázalo sdílení i ve filtru. Po odebrání přístupu na S21 server potvrdil odstranění sdílení, zmizel štítek vlastníka a po obnovení seznamu se vyprázdnil filtr příjemce. Děděné sdílení složek zůstává samostatně v TODO.


- 2026-10-23 Prázdný koncept se při zavření ponechá, pokud má čekající přílohu nebo nelze frontu spolehlivě přečíst. Automatické mazání kontroluje aktuální řádek v databázové transakci a nikdy nezadá smazání na serveru. Výběr přílohy se nemůže rozběhnout během zavírání. Regresní test před opravou ztratil koncept s přílohou; po opravě prošel i s nečitelným úložištěm a poškozenými metadaty. Revize `7baad8f`: 360 mobilních a 74 databázových testů prošlo, tři živé databázové testy bez přístupů se přeskočily; statická kontrola bez nálezů.
- 2026-10-23 Debug kandidát 0.2.3+6, SHA-256 `9898592ca768c359aa52aa8bb3027fa099fbde24dd0fe1dd081afa90c433c083`, ověřen na S9+ a S21. Na S9+ bez aktivní sítě vznikl prázdný koncept s přílohou 4 524 B; po zavření zůstal v seznamu. Po ukončení aplikace, dalším spuštění a obnovení sítě se koncept otevřel a příloha se nahrála a zobrazila. Čistě offline nové spuštění nebylo tímto fyzickým během prokázáno. Wi-Fi i mobilní data byly obnoveny. Na S21 prošlo otevření a zrušení systémového výběru souboru i následné zavření editoru.


- 2026-10-23 Potvrzení nové přílohy se maže až po zápisu poznámky do SQLite. Otevřený editor dočasně drží své přenosy, aby souběžná synchronizace nevložila odkaz podruhé. Po restartu lze obnovit odkaz z uloženého potvrzení serveru bez nového odesílání souboru. Starší zápis potvrzuje jen přílohy, které do něj patřily. Revize `d86cd81`: 355 mobilních testů prošlo, statická kontrola bez nálezů; testy pokrývají restart před i po zápisu, odmítnutý zápis do SQLite, opakování uložení a vrácení vloženého odkazu.
- 2026-10-23 Debug kandidát 0.2.3+6, SHA-256 `f14ef52f47f80555297d2136a35b361d95ab39215fd5db76a05d53dd684ee60d`, ověřen na S9+ a S21: výběr skutečného souboru, vložení odkazu a prázdná fronta po uložení. Na S9+ navíc ukončení aplikace a nové spuštění bez aktivní sítě po dokončeném uložení; odkaz zůstal zachovaný. Síťová nastavení byla obnovena. Výpadky přesně mezi zápisy byly ověřeny automatickými testy, nikoli fyzickým přerušením v těchto bodech.


- 2026-10-23 Menu příloh v editoru otevírá skutečný přehled fronty a souborů místo prostého seznamu názvů. Opakování přenosu vloží odkaz do poznámky; odstranění odkazu zachová soubor a lze ho vrátit. Poznámka jen pro čtení nenabízí změny příloh. Dva současné pokusy o opakování už nezapisují tentýž dočasný soubor. Oba regresní testy před opravou selhaly, po opravě prošly. Test už nevkládá odkazy skrytým ručním voláním `flush`; čtení adresářů se dokončí před úklidem testu.
- 2026-10-23 Spodní panely respektují systémovou navigační lištu. Překrytí textu bylo nalezeno na S21 a reprodukováno testem s dolním okrajem 48 bodů. Revize `378592f`: celá mobilní sada 348 testů prošla, statická kontrola bez nálezů.
- 2026-10-23 Debug kandidát 0.2.3+6, SHA-256 `39ce1ccfa6d0139171aa4743f5a2ebf883cd2703f66eeb4cf0612db2053fa59a`, nainstalován a spuštěn na S9+ (Android 10) i S21 (Android 15). Na obou ověřen přehled příloh a jeho spodní okraj; na S9+ navíc odebrání a vrácení odkazu na testovací poznámce. Opakování přenosu a souběh dvou pokusů jsou ověřené automatickými testy, ne tímto fyzickým během. Předčasné potvrzení při vložení nové přílohy zůstává v TODO.


- 2026-10-23 Náhled obrázků používá společnou mezipaměť příloh. Chybu stažení lze zopakovat přímo v náhledu. Poškozené UTF-8 v adrese obrázku nevyvolá pád a chyba zápisu do mezipaměti nezakryje už stažený obrázek. Revize `22cb98e`: 342 mobilních testů prošlo při jednom testovacím procesu, kontrola změněných souborů bez nálezů.
- 2026-10-23 Ověřeno nové debug APK 0.2.3+6, SHA-256 `2de991625484f315eb813b6b61dee23a4811b2bcff99512e216d3a60068e4010`. S9+ zobrazil uložený obrázek bez aktivní sítě po novém spuštění; původní APK ve stejném scénáři selhalo. Wi-Fi i mobilní data byly obnoveny. Na S21 prošlo opakování chybějícího obrázku po jeho nahrání na server a načtení z disku po ukončení a novém spuštění aplikace, když soubor na serveru vracel 404. Testovací obrázek byl poté na server vrácen. S21 zůstal během testu připojený k síti; ověřena byla nedostupnost souboru, nikoli celé sítě.


- 2026-10-23 Hledání v poznámce obnovuje shody po změně textu i po zavření a otevření. Dotaz má vlastní řádek, počet a obě šipky jsou pod ním; hledání text nemění. Ověřeno na Galaxy S9+ (Android 10) a S21 (Android 15): oba směry, přechod přes konec, opětovné otevření a přepočítání po psaní. Původní chybu po otevření se podařilo zopakovat na S9+ před aktualizací.
- 2026-10-23 Ověření kódu `436f304`: 339 mobilních, 93 protokolových a 73 databázových testů prošlo, statická kontrola bez nálezů. Osm živých testů se bez přístupů přeskočilo. První mobilní běh zůstal na testu opakování uploadu; samostatný test i další celá sada prošly, občasné zablokování zůstává v TODO.
- 2026-10-23 Na telefonech byl testován debug kandidát 0.2.3+6, SHA-256 `c3a1fbe41cced28e18cb91f4a0a73313795e4b8dae567a900c5a79d417c10cac`. Aktualizace zachovala účty a poznámky. Release APK pro ARM64 se také sestavilo, SHA-256 `b34f66875232040d56e2218a472fd5fb8f0daa07e3bb24a6b5f5ee150ce41bd8`; jeho instalaci přes dosavadní debug aplikace Android odmítl kvůli podpisu. Nejde o vydání do obchodů ani fyzické ověření release režimu.
- 2026-10-23 Aktualizováno srovnání Nextcloud Notes, Joplinu a Simplenote v existujícím auditu a zastaralý seznam funkcí v README.

- 2026-10-21 About screen instead of the bare licence page: version and
  build (`package_info_plus`), what the app does and that notes stay plain
  Markdown files, the account's server with its Nextcloud and Notes versions
  (from the capabilities, `AttachmentsClient.versions()`), website, privacy
  policy, support e-mail with the version in the subject, open source
  licences. Settings show the version under the app name. Widget tests for
  both a reachable and an unreachable server and at 200 % text.

- 2026-10-21 Foldables: list and editor side by side from 600 dp (the inner
  display of a book foldable is about 670–830 dp), split exactly at a
  vertical fold or hinge, and in the half-open laptop posture the note sits
  above the fold with the list below, where the keyboard comes up. The new
  note button stays on the list pane. Checked on an Android emulator
  "7.6in Foldable" (API 34): flat, half open as a book, landscape half open
  with the note above the fold and the keyboard below; the emulator reports
  that posture as flat, so the posture check was bypassed for that run.
  Widget tests cover the fold split, the laptop posture and the cover screen.

- 2026-10-21 Real-phone checks on the Docker test server. Galaxy S9: photo,
  camera, voice and file attachments upload into `.attachments.<id>` and go on
  their own line after the caret's line (`7a46696`); "sign in again" after the
  app password was revoked keeps local notes, now syncs at once so the banner
  goes away (`6774dac`) and reloads the display name (`4a9814e`). Galaxy S21
  with a second account: a note shared from the Notes folder and a `.md`
  shared from another folder both open, edits flow both ways (also into an
  open editor), simultaneous edits end in the comparison screen with nothing
  lost, removing the share hides or flags the note, sharing from the app works;
  the undo snack bar of the comparison screen no longer outlives it
  (`4da34ff`); a sync the user starts reads new shares at once (`264dcd6`).
- 2026-10-21 Widget and launcher-shortcut links open in a running app
  (`03d3b40`). Flutter's own deep linking pushed a second home screen over the
  one that opened the note or search; it is off on Android and iOS, and a link
  that arrives while Flutter starts is read once at start. iOS gets widget
  links through `SceneDelegate` and the share channel (not compiled yet).
  Galaxy S9: "Hledat" and `ownnotes://new` with the app in front, in the
  background and during a cold start; one note per link, no duplicates.
- 2026-10-21 Tablet layout on the S9 set to tablet size (`wm size`): 800 dp
  portrait keeps one list column, 1280 dp landscape shows navigation, list
  and editor side by side. The navigation pane is 300 dp now, at 240 its
  Czech labels wrapped (`8d168ab`).
- 2026-10-21 Google Play closed testing: 0.2.0 (2) with the redesign, then
  0.2.1 (3) with shortcuts, the quick settings tile and the fixes above.
- 2026-10-21 iOS: WidgetKit extension added to the Xcode project
  (`b71a567`, two compile errors fixed), `ownnotes://` scheme registered
  (`04885a7`). The widget App ID had App Groups on but no group, so its
  profiles carried none and Xcode failed with a misleading "Authentication
  failed"; the group was assigned in the developer portal. Release build,
  simulator start-up and `simctl openurl ownnotes://search` checked;
  TestFlight builds 3 and 4 uploaded with cs/en/de notes.

- 2026-10-21 Launcher shortcuts "New note" and "Search" (Android, dynamic, same
  `ownnotes://` links as the widgets, new `ownnotes://search`), quick settings tile
  "New note" (Android) and iOS quick actions (Info.plist + SceneDelegate, not compiled:
  the Mac was offline). Checked on emulators: shortcuts listed and opened from the
  launcher (cold and warm, Android 16), tile added and opened a new note on Android 16
  and 11; analyze clean, 327 tests.
- 2026-10-21 Redesign from the specification worked out with Codex
  ([docs/design/redesign.md](design/redesign.md)), built by parallel agents
  and merged in waves; 323 widget/unit tests, store 73, protocol 93:
  - design system (warm paper, ink, ochre; system fonts plus a subset mono
    font), one Markdown document model with source ranges;
  - login, accounts, settings (every row with an icon, theme and language
    choice), opaque app lock; Czech informal form throughout, German added;
  - persisted sync status, kept failed deletions with retry/undo,
    unreadable notes kept, census protected by the Notes `/settings` scope,
    conflict comparison with device/server/result and retained originals;
  - notebook: status in the app bar, Needs attention, Shared with me,
    search filters, saved views, bulk actions, swipes, tablet panes;
  - editor: compact top bar, header collapses with the keyboard (about 10
    body lines on the S21), formatting dock with undo/redo, `@` `:` `/`
    suggestions checked live, Text-compatible preview, checklist mode,
    templates and daily note, share sheet;
  - attachments and voice notes through the Notes attachment API (route by
    server version, checked live), durable incoming captures with account
    choice (checked on the S9), Keep import with attachments;
  - configurable Android widgets (list, note, checklist, quick note),
    redacted with the app lock, ticks through the durable command path
    (checked on the S21).

- 2026-10-20 Login and accounts like OwnTalk: onboarding screen, server
  address check (path trimmed to the host), separate error reasons, Cancel
  that also stops a browser about to open, QR login (camera + zxing2),
  accounts screen with server display name, switch, add and remove (revokes
  the app password on the server, clears the widget snapshot), sign in again
  that keeps the account's notes and drafts. Login and removal verified on
  Galaxy S21 against the Docker server; accounts screen on Galaxy S9.

- 2026-10-20 Note list, editor and app lock rework, verified on Galaxy S9
  (candidate build, Docker server, 208 notes):
  - scrolling no longer stutters: rows use a short excerpt computed once;
    frames over 33 ms dropped from about 12 % to 2.3 % (two runs each);
  - compact app bar with search, sync, account menu and status; category
    tree in a drawer (side panel from 840 dp) with All, Favorites,
    Uncategorised and virtual parents; rows with excerpt, time, category,
    task progress, attachment mark and sync state in words; sync banner
    also for failed downloads and sign-in problems;
  - tap in the preview opens the raw editor at the tapped line (checked on
    S9); live Markdown styling and a formatting bar above the keyboard;
    preview links open in the browser; checkboxes follow the Markdown
    parser; an overlapping pull during typing becomes a decision instead of
    merged text; the open editor follows readonly and conflict changes;
  - the app lock stays closed on errors and unreadable preferences;
    unsupported languages fall back to English; Face ID text in cs and en;
  - sharing with another user, protocol and sync (Notes 6.1 moves a note
    shared from the Notes folder into the recipient's Notes folder; other
    files sync over WebDAV), live-tested on the Docker server.

- 2026-10-19 Writing to one note from two devices at once, verified on
  Galaxy S21 and Galaxy S9 against the Docker server:
  - a rejected write (412) whose edits touch other lines than the other
    device's is combined with the server version and sent again; only the
    same lines changed differently still ask;
  - an open note syncs every 4 s while the app is in front; what arrives is
    combined with the text typed meanwhile, the cursor stays in place;
  - tapping the note text on the S21 in portrait opened the keyboard and
    closed it at once: the keyboard switched the editor to its scrolling
    layout, which rebuilt the focused field.

- 2026-10-19 Collisions on one note between two phones (Galaxy S9 and a
  Pixel emulator, both on the Docker server; the S21 was off the network):
  - both edited at once: the second phone never overwrote the server, it
    showed both versions; "keep local" reached the server and the other
    phone;
  - new "Combine both versions": a line-by-line merge keeps the lines of
    both phones in their order; the result is shown before it is saved;
  - an open note now takes a version changed on the other phone when it has
    no local edits (before, the next keystroke started from the old text);
  - "separate copy" left the original server note hidden on that phone for
    good; the archived row now gives up the server id and the next pull
    brings the server version back;
  - a note edited offline and deleted on the other phone meanwhile: the
    conflict screen says it was deleted and offers "upload again" or
    "delete on this phone too" (before: "decision could not be applied").

- 2026-10-19 Android background sync and home-screen widget, verified on
  Galaxy S9 (`bc8b14c`, `8e3d490` and the WorkManager commit):
  - a per-account lease in the database lets the app and the WorkManager
    worker take turns; only the lease holder recovers interrupted writes;
    schema 1 databases gain the lease table on upgrade (tested);
  - periodic sync every 15 minutes with network, plus a one-off run queued
    when the app goes to the background. On S9 an edit made offline was
    uploaded by the worker while the app process was killed. With battery
    saver on, Android blocks background network for the app, so the run
    waits until saver is off or the app is opened;
  - widget with the five latest notes and "+"; a tap opens the note, "+"
    opens a new note also from a cold start; titles are hidden while the
    app lock is on; launcher shortcut "New note"; the background worker
    redraws the widget after its sync, since the app draws only while open;
  - a new note left empty is discarded instead of reaching the server as
    "New note".
  - iOS simulator build with all new plugins (local_auth, shared_preferences,
    workmanager, home_widget) builds on the build Mac and starts; Face ID usage text
    added to Info.plist.

- 2026-10-19 Second batch from the analysis, verified on Galaxy S9 (candidate
  build, Docker server):
  - Settings screen (`5885e3a`): monospace font and text size for the editor;
    app lock with fingerprint/face/phone PIN (cold start and return from the
    background ask, cancel leaves a lock screen, a phone without screen lock
    cannot turn it on, and removing the phone PIN later does not lock the
    owner out); block screenshots (Android, persists across restarts);
    export of all notes as a Markdown zip with category folders; removing
    the account warns how many notes are not on the server yet.
  - Find in the open note, share into an existing note (appended at the
    end) or a new one, favorite star on read-only notes (`207aed4`,
    `1e5adb7`).

- 2026-10-19 From the server and original-app analysis, verified on Galaxy S9
  (candidate build) against the Docker server:
  - a new note without a title takes its first line as the server would
    name it (`ecb141e`; on S9 "Nakup na S9" reached the server);
  - server-cleaned categories (`Work//Sub/` -> `Work/Sub`, checked live) and
    renames of notes with attachments no longer need a decision (`ecb141e`);
  - an update the server rejects (423 locked, 507, 500) is re-read; if
    nothing was applied, the note stays queued with a reason (`ecb141e`);
  - incremental pulls with `pruneBefore`, unknown id-only notes fall back to
    a full pull (`b47607f`, server behaviour checked live in `36627c1`);
  - checkboxes tick in preview and edit the raw Markdown (`63122a6`; on S9
    `- [x] chleba` reached the server);
  - banner "Not sent yet: N" with the reason, and an automatic retry every
    30 s while the app is open (`63122a6`; on S9 an offline edit uploaded
    24 s after the network came back, no tap);
  - sort by title or last change, remembered (`63122a6`).

- 2026-10-20 Store distribution: Google Play closed testing published
  (versionCode 1, listing from [docs/store/play-listing.md](docs/store/play-listing.md),
  privacy policy https://ownnotes.nks-hub.cz/p/soukromi); iOS build 1 in
  TestFlight for internal testers and in beta review for the external group.
  App Group and ShareExtension bundle id registered in the Apple portal.
- 2026-10-19 Release identity: **OwnNotes**, `com.nkshub.nextcloudnotes` on Android and iOS, candidate builds via `--android-project-arg=candidate=true`; upload keystore and release signing without debug fallback; app icon (`tool/make_icons.py`); Play upload script (`tool/play_upload.py`, checked against the API: package not found until the app exists). Signed release APK verified on Galaxy S9: login, pull and a new note reached the server.
- 2026-10-19 Preview shows images attached to the note (`.attachments.<id>/...`) through the Notes attachment API with the account credentials (`74aee59`); remote http images stay placeholders. Verified on Galaxy S9 with a real attachment on the Docker server.
- 2026-10-19 Renaming a note or changing its category no longer ends as a
  decision for notes without attachments (`234cbb7`); verified on Galaxy S9:
  the file moved to `/Notes/Test/Renamed on S9.md`. Notes that reference
  `.attachments.` still ask, until attachment moves are verified.
- 2026-10-19 Category filter chips, pull to refresh, and an editor that
  scrolls instead of overflowing with the keyboard up in landscape (found on
  Galaxy S9) (`a42c75a`).
- 2026-10-19 iOS "Share → OwnNotes": ShareExtension target stores shared
  text (plus the page URL from Safari) in the App Group; the app turns it
  into a note when it comes to the front. Verified on the iPhone 17 Pro
  simulator (iOS 26.2, the build Mac) against the Docker server: shared page reached
  the server as a note with title and address. Target added by
  `apps/mobile/ios/tool/add_share_extension.rb`.
- 2026-10-19 Deleting notes (`d8df51f`): delete button with confirmation in
  the editor; an uploaded note is first re-read, so a version changed
  elsewhere comes back instead of being lost; notes deleted on the server
  disappear after the next full sync unless they have local edits. Verified
  on Galaxy S9 against the Docker server in both directions.
- 2026-10-19 Offline edits no longer turn into conflicts. Before, a write
  attempted without network was treated as "maybe applied" and needed a
  decision; now a sync first checks that the server answers and otherwise
  leaves the edit as a plain draft (`de675e4`). Verified on Galaxy S9: edit
  offline, force-stop, network back, relaunch, uploaded without a decision.
  Note: the earlier S9 "conflict" check went through this path as well.
- 2026-10-19 Login screen: "Cancel" while waiting for the browser, so a flow
  broken on the server side ("State token missing") can be restarted at once.
  Widget tests cover the poll retry after a network failure and the cancel.
- 2026-10-19 A new note without a title (or with a taken one) no longer ends
  as a conflict: the server names the file ("New note", "Title (2)") and the
  app adopts that name. Found on Galaxy S9, fixed in `157726d`.
- 2026-10-19 Import from other apps: Android "Share → OwnNotes" (Google
  Keep, Samsung Notes, anything sharing text) and Google Keep Takeout zip
  (menu ⋮). Checklists become `- [ ]`/`- [x]`, the first label becomes the
  category, trashed notes are skipped, a note without title takes its first
  line. Verified on Galaxy S9 against the Docker server.
- 2026-10-19 Product goals checked on Galaxy S9 (Android 10, Docker server):
  offline edit while the same note changed on the server, app force-stopped,
  network back, relaunch. The phone text survived, the server text was not
  overwritten, the note showed as a conflict with both versions side by side;
  "Keep local changes" uploaded the phone text and the note became clean.
  The editor opens in raw Markdown every time; preview only via its button.
- 2026-10-19 Telemetry like OwnTalk: Sentry (own self-hosted project) and
  Rybbit (own mobile site), configured only at build time from ignored
  `apps/mobile/telemetry.env`. Verified on Galaxy S21: release-gate error
  arrived in Sentry with only a random installation id; Rybbit received
  `app_open` and route names `/`, `/note`.
- 2026-10-19 Notes sync on their own: after login/start, after returning to
  the app and after leaving the editor (`400ce9e`). Before, an edit stayed
  local until the sync button was pressed. Verified on Galaxy S21 (Android
  15, a test Nextcloud server) and Galaxy S9 (Android 10, Docker test server).
- 2026-10-19 Empty-state text has side padding (was glued to the left edge).
- 2026-10-19 Login Flow v2 survives Android background network limits: a
  transport failure while the browser is in front no longer ends the login,
  polling resumes. Found on Galaxy S21 (Android 15).
- 2026-10-19 Keyboard action on the server URL field starts the login.
- 2026-10-19 Package renamed to `com.nkshub.nextcloudnotes` (`b3fe611`).
- 2026-10-19 Opt-in live protocol test against real Nextcloud (`a7b1f2d`).
