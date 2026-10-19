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

- [ ] Keep import: images and audio from Takeout are skipped until
      attachment upload exists (slice 10).
- [ ] iOS share extension for the same "Share to OwnNotes" flow (needs an
      extension target and App Group).
- [ ] Remaining delivery slices from
      [implementation plan](docs/architecture/implementation-plan.md) and
      gates in [status](docs/acceptance/status.md).

## Done

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
