# TODO

Working list for OwnNotes. Newest requests first inside each section. Move an
item to "Done" with the date and commit once it is implemented and verified.

## Product goals (why the rewrite exists)

The previous Notes app on Android:

1. sometimes did not save a note;
2. created conflicts it could not resolve;
3. switched Markdown editing into a rendered web view on its own.

Every change is checked against these three points: no lost text, every
conflict has a resolvable outcome, the editor stays raw Markdown and never
switches to preview without the user asking.

## Open

- [ ] Import from other note apps on Android: Google Keep and the system
      notes app (Samsung Notes). Keep has no public API for personal
      accounts; investigate Android share target ("Share to OwnNotes") and
      Google Takeout Keep export import.
- [ ] Login screen: offer a restart when the browser flow fails on the server
      side (seen on Samsung Internet: "State token missing" after the browser
      session asked for a fresh login during grant).
- [ ] Login screen: widget test for poll retry; needs injectable HTTP client
      and URL launcher.
- [ ] Verify the three product goals on devices: process death during save,
      offline edit + server edit conflict, editor never auto-switching.
- [ ] Remaining delivery slices from
      [implementation plan](docs/architecture/implementation-plan.md) and
      gates in [status](docs/acceptance/status.md).

## Done

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
