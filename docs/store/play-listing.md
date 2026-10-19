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
- psaní bez připojení; změny se odešlou samy po návratu signálu
- editor zůstává v čistém Markdownu, náhled se zapíná jen tlačítkem
- když se stejná poznámka mezitím změnila jinde, aplikace ukáže obě verze
  a nechá vás vybrat, nic nepřepíše potichu
- hledání, kategorie, oblíbené, mazání
- obrázky z příloh poznámky v náhledu
- „Sdílet → OwnNotes“ z jiných aplikací, například z Google Keep
- import poznámek z Google Keep (zip z Google Takeout)
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
- works offline; changes upload on their own when the connection is back
- the editor stays raw Markdown, preview only with its button
- when the same note changed elsewhere, both versions are shown and you
  choose; nothing is overwritten silently
- search, categories, favorites, delete
- images attached to a note in preview
- "Share → OwnNotes" from other apps, such as Google Keep
- import from Google Keep (Google Takeout zip)
- several accounts at once

Requires a Nextcloud server with the Notes app.

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
