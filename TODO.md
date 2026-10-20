# TODO

Rule for every change: no lost text, every conflict has a way out, the editor
stays raw Markdown and never switches to preview on its own. Never add a
rich-text WebView editor, a per-note remembered view mode, or the server's
`noteMode=preview`.

Everything must stay compatible with Nextcloud: notes remain plain Markdown
files in the Notes folder, categories are folders, attachments live in the
note's `.attachments.<id>` folder, sharing uses the standard Nextcloud
shares. Nothing the Notes web app, the Text app or other clients cannot
read; app-only settings (views, locks, indexes) stay on the device.

Finished items go to [docs/history.md](docs/history.md). Codex review with file
references: [docs/research/review-2026-10-20.md](docs/research/review-2026-10-20.md).

## Now

- [ ] Note list stutters while scrolling.
      Each row lays out the whole note content for a two-line subtitle.
- [ ] Compact list header like OwnTalk: account switcher and search in the
      app bar instead of the dropdown and the permanent search field.
- [ ] Categories as a tree in a drawer, with All, Favorites, Uncategorised.
      Nesting comes from `/` in the category name; `Work/Project` also
      creates a selectable `Work`. A new note gets the selected category.
- [ ] Richer note rows: excerpt without the repeated title, relative time,
      category, task progress ("3/7"), attachment mark, sync state as a
      word (Waiting, Sending, Needs decision), not only an icon.
- [ ] Sync status in the list also when nothing is waiting to upload.
      Today a failed download or a revoked password shows nothing.
- [ ] Widget and share links open the right account.
      They carry only a note id and use whichever account is shown.
- [ ] Login and accounts like OwnTalk: onboarding screen, server address
      check, QR login, accounts screen with switch and remove (revokes the
      app password on the server).
- [ ] Sign in again to an existing account without losing its drafts.
      Today "add the account again" creates a new account and the unsent
      notes stay on the broken one.
- [ ] Login: say why it failed (unreachable, not Nextcloud, certificate,
      Notes app missing); Cancel must also stop a browser that is about to
      open.
- [ ] Edit from the Markdown preview: a tap opens the raw editor at that
      spot; an edit button in the preview.
- [ ] Live Markdown styling while typing; the Markdown marks stay visible.
- [ ] Preview checkboxes tick the right task.
      They are matched by order, so a code sample with `- [ ]` or a task in
      a quote shifts them; use the Markdown parser's source positions.
- [ ] Overlapping edits during typing become a decision.
      When the same line changed on the server while typing, the editor
      now puts both versions under each other and uploads that.
- [ ] Open editor follows readonly and conflict changes from the database.
- [ ] Links in the preview open in the browser.
- [ ] Share a note with another user (e.g. a partner) and edit it live.
      A note shared through the OCS share API lands outside the recipient's
      Notes folder, so the Notes API does not list it; needs WebDAV access
      to the shared file with ETag checks and the same line merge as a 412.
- [ ] App lock never opens on an error.
      A second error while checking the device lock lets the user in, and
      an unreadable preference turns the lock off.
- [ ] Unsupported phone languages fall back to English (today Czech);
      Face ID text in Czech too.
- [ ] German translation next to Czech and English: app texts (ARB),
      iOS system texts (Face ID, share extension) and the store listings.
      Done after the UI rework, so the new texts are translated too.

## Next

- [ ] Shopping list mode for checklist notes: quick add, tap to tick,
      ticked items drop to the bottom and can be cleared, drag to reorder.
      On the server it stays a plain Markdown task list.
- [ ] Add attachments (photo, file) to a note; then the Keep import can
      bring images and audio too (skipped today).
- [ ] Shared text must be stored before the share is acknowledged.
      Android forgets it when Flutter reads it, iOS deletes the inbox entry
      at once and keeps only 16 entries; a crash in between loses the text.
- [ ] Failed deletions stay visible with the reason, retry and undo.
      Today a note being deleted disappears even when the server refused.
- [ ] Read server capabilities and Notes `/settings` (notes folder, file
      suffix, API versions). Attachments: Notes 6.0 serves them only under
      `/api/v1.4/attachment/{id}`, 6.1 adds `/api/v1/...` and DELETE; the
      app always uses `v1`.
- [ ] Sync errors survive an app restart (kept per account), unreadable
      notes are shown with a retry instead of being skipped.
- [ ] System integration: share a note out, iOS quick actions, Android
      shortcuts and a quick settings tile for a new note.
- [ ] iOS background sync (BGTaskScheduler) and a WidgetKit widget; both
      need a signed build on an iPhone, the simulator never runs them.
- [ ] Remaining slices from [implementation plan](docs/architecture/implementation-plan.md).

## Later

- [ ] Notes missing from a pull are deleted locally without a copy.
      If the Notes folder setting changes, the whole offline copy goes.
      Check the sync scope first and keep a recovery copy.
- [ ] Changing the category of a note with attachments asks again and
      again; explain why and give a way out.
- [ ] Share the current note out as text or `.md`, export one note.
- [ ] Markdown actions: list continuation, indent, insert link, undo/redo.
- [ ] Find in note: previous match and match count.
- [ ] Tablet layout with list and editor side by side.
- [ ] Android sync settings (interval, Wi-Fi only).
- [ ] Android widgets configurable per widget (account, category, one note).
- [ ] Backups that can be restored: ZIP with metadata and attachments.
- [ ] File versions and trash from Nextcloud (DAV), restore keeps the draft.
- [ ] Bulk actions in the list (delete, move, favorite).
- [ ] Keep the incremental-pull marker across restarts; use the list ETag.
- [ ] Instant updates through notify_push when the server has it, instead
      of asking every 4 s while a note is open.
- [ ] Desktop builds (Windows, macOS) like OwnTalk.
- [ ] Fast start: measure cold start to a cursor in a new note and keep it
      under 1 s on the S9.

## Ideas

- [ ] Templates and a daily note.
- [ ] Saved views: unfinished tasks, recent changes, sync problems.
- [ ] Quick capture appended to an inbox note.
- [ ] Spotlight and Android search indexing (opt-in, hidden while locked),
      Siri / App Intents: new note, append, open, search.
- [ ] Links between notes and backlinks, written as relative Markdown
      links that the Notes web app and the Text app also open (check first).
- [ ] Online search through Nextcloud unified search.
- [ ] Notification when a conflict needs a decision.
- [ ] Grid layout, word and character count.
- [ ] Voice recording and a sketch as attachments.
- [ ] `#tags` written in the note text as a filter next to categories.
      Notes has no tags; they stay plain text, so other clients see them.
- [ ] Text recognition in attached images and PDFs for search, on the
      device (ML Kit, Apple Vision), never sent anywhere.
- [ ] Summary and grammar check through the Nextcloud Assistant of the
      user's own server, only when the server offers it.
- [ ] Lock chosen categories separately with biometrics.
