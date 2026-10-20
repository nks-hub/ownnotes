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

### UI rework requested by the owner (2026-10-20)

- [ ] Note list stutters while scrolling. Rows lay out the whole note
      content for a two-line subtitle; use a short excerpt and keep heavy
      work out of `build`. Measure frame times on the S9 before and after.
- [ ] Compact list header like OwnTalk: account avatar and switcher in the
      app bar, search in the app bar instead of a permanent field.
- [ ] Categories as a collapsible tree (`/` nesting) in a drawer or side
      panel, with note counts, All, Favorites and Uncategorised.
- [ ] Richer note rows: excerpt, relative time, category, favorite, sync
      state, checklist progress ("3/7"), attachment indicator.
- [ ] Login and account management like OwnTalk: onboarding screen, server
      address check, Login Flow v2 progress, QR login, accounts screen with
      switch and remove (revoking the app password).
- [ ] Editing from the Markdown preview: a tap opens the raw editor at that
      place, plus an edit button. Notes still always open in the raw editor.
- [ ] Live Markdown styling while typing (headings, bold, code, lists,
      tasks) in the raw editor; markers stay visible.
- [ ] Adding attachments: photo or file into a note through the Notes
      attachment API, then the Keep import can bring images and audio too.
- [ ] Better system integration (share in and out, widgets, shortcuts,
      quick settings tile, search, iOS quick actions); scope from the
      review below.
- [ ] Shopping list mode for checklist notes: quick add of an item, tap to
      tick, ticked items drop to the bottom (with an option to clear them),
      reorder by dragging. Stays a plain Markdown task list on the server.
- [ ] Sharing a note with another Nextcloud user (for example a partner)
      and editing it live together. The open note already syncs live
      between devices of one account (`5d5c12f`); a note shared through the
      OCS share API lands outside the recipient's Notes folder, so the Notes
      API does not list it. Needs WebDAV access to shared files (ETag based
      polling or notify_push) and the same line merge after a 412.
- [ ] Full review with Codex: code and UX, Notes and Nextcloud API
      coverage, gaps versus notes-android and the iOS client, ideas from
      competing apps; results go into this file as items.

### From the Codex review (2026-10-20)

Full report with file references: [review-2026-10-20](docs/research/review-2026-10-20.md).
Items already handed to the UI rework above (checkbox source mapping,
overlapping-edit merge, live readonly/decision state in the editor,
re-login of an existing account, login errors and cancel, category tree
details, sync status in the list, account-aware widget links) are not
repeated here.

Next:

- [ ] Shared text is acknowledged before it is stored: Android clears its
      slot when Flutter reads it, iOS removes the inbox entry at once and
      keeps only 16 entries without a lock. Make share delivery a durable
      command with an id, acknowledged after the database commit.
- [ ] App lock can fail open: a second error while checking device support
      grants access, and an unreadable preference becomes `lock=false`.
- [ ] Failed deletions vanish: `deleting` rows are hidden from the list and
      export, non-404 failures are swallowed. Show pending deletion with the
      reason, retry and undo.
- [ ] Read OCS capabilities and Notes `/settings` (notesPath, fileSuffix,
      API versions). Attachments: Notes 6.0.x serves them only under
      `/api/v1.4/attachment/{id}`, 6.1 adds the `v1` alias and DELETE; pick
      the route by version instead of always using `v1`.
- [ ] Sync problems live in a process-local map: persist a safe error
      category per account and per unreadable note, and show stale or
      unreadable notes with a retry.
- [ ] Unsupported system languages fall back to Czech; fall back to
      English. Translate the Face ID usage text.

Later:

- [ ] Census deletes clean rows that disappear from a pull without a
      recovery copy; validate the sync scope (notesPath change) first and
      use the final page's membership of a chunked pull.
- [ ] Attachment moves end in a repeated decision; explain the cause and
      give a working way out.
- [ ] Share the current note out (text or `.md`), single-note export.
- [ ] Markdown text actions: list continuation, indent, link insert,
      explicit undo/redo; in-note search with previous and match count.
- [ ] Tablet list/detail layout that keeps the open editor across resizes.
- [ ] Android sync preferences (interval, Wi-Fi only).
- [ ] Configurable Android widgets (account, category, favorites, single
      note or checklist) and an iOS WidgetKit widget.
- [ ] Restorable backups: ZIP with a manifest, metadata and attachments,
      verified import.
- [ ] File versions and trash through DAV, with restore that keeps the
      current draft.
- [ ] Bulk actions in the list (delete, move to category, favorite).
- [ ] Persist `pruneBefore` watermarks; use the list `If-None-Match`.

Ideas:

- [ ] Templates and a daily note.
- [ ] Saved views: unfinished tasks, recent changes, sync problems.
- [ ] Quick capture: append to an inbox note, iOS quick actions, Android
      quick settings tile.
- [ ] Spotlight / Android search indexing (opt-in, respects the app lock)
      and Siri / App Intents (new note, append, open, search).
- [ ] Internal links between notes and backlinks.
- [ ] Optional online search through Nextcloud unified search.
- [ ] Notification when a new conflict needs a decision.
- [ ] Optional grid layout and word/character count.

### From the server and original-app analysis (2026-10-19)

Sources: Notes 6.1.0 server code (routes, `Helper.php`, `NoteUtil.php`,
`SettingsService.php`) and nextcloud/notes-android 35.1.0 with its issue
tracker. The original app sends no `If-Match` (last write wins), saves the
view mode per note, and can save an empty editor before the note has loaded.
OwnNotes keeps avoiding all three. Never add: a rich-text WebView editor, a
per-note remembered view mode, or honouring the server's `noteMode=preview`.

Everyday features the original app has:

- [ ] iOS: background sync (BGTaskScheduler) and a WidgetKit widget.
      Android has both. The App Group is registered; background tasks never
      run in the simulator, so both need a signed build on an iPhone.

### Earlier

- [ ] Keep import: images and audio from Takeout are skipped until
      attachment upload exists (slice 10).
- [ ] Remaining delivery slices from
      [implementation plan](docs/architecture/implementation-plan.md) and
      gates in [status](docs/acceptance/status.md).

## Done

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
