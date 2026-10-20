# Google Play listing

App: **OwnNotes**, package `com.nkshub.nextcloudnotes`, category Productivity.
Icon: `apps/mobile/assets/brand/play-store-icon.png` (512 × 512).

## cs-CZ

**Krátký popis** (max. 80 znaků)

Poznámky v Markdownu pro Nextcloud Notes, i bez připojení.

**Úplný popis**

OwnNotes je klient pro aplikaci Notes na vašem serveru Nextcloud. Poznámky
zůstávají obyčejné soubory Markdown na vašem serveru; aplikace je jen čte
a zapisuje.

Co umí:
- přihlášení přes prohlížeč (Nextcloud Login Flow), heslo se ukládá do
  zabezpečeného úložiště telefonu
- psaní bez připojení; změny se odešlou samy po návratu signálu, i když
  je aplikace zavřená
- editor zůstává v čistém Markdownu, náhled se zapíná jen tlačítkem
- úkoly `- [ ]` se dají odškrtávat přímo v náhledu
- když se stejná poznámka mezitím změnila jinde, aplikace ukáže obě verze
  a nechá vás vybrat, nic nepřepíše potichu
- hledání v seznamu i uvnitř poznámky, kategorie, oblíbené, řazení, mazání
- obrázky z příloh poznámky v náhledu
- „Sdílet → OwnNotes“ z jiných aplikací do nové nebo existující poznámky
- import poznámek z Google Keep (zip z Google Takeout), export do zipu
- widget na ploše s posledními poznámkami
- zámek aplikace otiskem prstu nebo PINem telefonu, zákaz snímků obrazovky
- více účtů najednou

Potřebujete server Nextcloud s nainstalovanou aplikací Notes.

## en-US

**Short description** (max. 80 characters)

Markdown notes for Nextcloud Notes, also offline.

**Full description**

OwnNotes is a client for the Notes app on your Nextcloud server. Notes stay
plain Markdown files on your server; the app reads and writes them.

What it does:
- signs in through the browser (Nextcloud Login Flow) and keeps the app
  password in the phone's secure storage
- works offline; changes upload on their own when the connection is back,
  also while the app is closed
- the editor stays raw Markdown, preview only with its button
- `- [ ]` tasks can be ticked in preview
- when the same note changed elsewhere, both versions are shown and you
  choose; nothing is overwritten silently
- search in the list and inside a note, categories, favorites, sorting,
  delete
- images attached to a note in preview
- "Share → OwnNotes" from other apps into a new or an existing note
- import from Google Keep (Google Takeout zip), export as a zip
- home-screen widget with the latest notes
- app lock with fingerprint or the phone PIN, screenshot blocking
- several accounts at once

Requires a Nextcloud server with the Notes app.

## de-DE

**Titel** (max. 30 Zeichen)

OwnNotes

**Kurzbeschreibung** (max. 80 Zeichen)

Markdown-Notizen für Nextcloud Notes, auch offline.

**Vollständige Beschreibung**

OwnNotes ist ein Client für die App Notes auf deinem Nextcloud-Server.
Die Notizen bleiben einfache Markdown-Dateien auf deinem Server; die App
liest und schreibt sie nur.

Was die App kann:
- Anmeldung über den Browser (Nextcloud Login Flow), das App-Passwort liegt
  im sicheren Speicher des Geräts
- Schreiben ohne Verbindung; Änderungen werden automatisch hochgeladen,
  sobald die Verbindung zurück ist, auch wenn die App geschlossen ist
- der Editor bleibt reines Markdown, die Vorschau nur per Schaltfläche
- Aufgaben `- [ ]` lassen sich direkt in der Vorschau abhaken
- wenn dieselbe Notiz inzwischen woanders geändert wurde, zeigt die App
  beide Versionen und du entscheidest; nichts wird still überschrieben
- Suche in der Liste und in einer Notiz, Kategorien, Favoriten, Sortierung,
  Löschen
- Bilder aus den Anhängen einer Notiz in der Vorschau
- „Teilen → OwnNotes“ aus anderen Apps in eine neue oder bestehende Notiz
- Import aus Google Keep (Zip aus Google Takeout), Export als Zip
- Widget auf dem Startbildschirm mit den neuesten Notizen
- App-Sperre per Fingerabdruck oder Geräte-PIN, Bildschirmfotos blockieren
- mehrere Konten gleichzeitig

Du brauchst einen Nextcloud-Server mit installierter App Notes.

## Data safety answers

Release builds made with `telemetry.env` send:

- **Crash logs and diagnostics** to the project's self-hosted Sentry: stack
  trace and error type, URLs cut to `scheme://<host>`, credentials removed, a
  random installation id; no note text, titles or server address.
- **App interactions** to the project's self-hosted Rybbit: screen names
  (`/`, `/note`, `/login`, `/recovery`) and app open, with the random
  installation id; Rybbit derives approximate location from the IP address.

Both: collected, not shared, encrypted in transit. Note content goes only to
the user's own Nextcloud server and is not collected by the developer.
A privacy policy URL is required before the listing can be published.
