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

- [ ] Complete review and redesign of the app and the widgets from scratch,
      worked out together with Codex. The current look is not a constraint;
      the rules above (Nextcloud compatibility, raw Markdown editor) are.
      Covers every screen (onboarding, list, categories, editor, preview,
      conflicts, settings, accounts), Android and iOS widgets, light/dark,
      tablet, accessibility, cs/en/de text lengths.

- [ ] Shared text from another app goes to the account shown in the list.
      It carries no note id; ask which account when there are several.
- [ ] Check QR login and "sign in again" on a real phone.
      Both pass widget tests; there was no login QR code at hand and no
      broken account to repair on the devices.
- [ ] Sharing in the app: Share button in the editor (pick a user, list
      and remove shares), a "Shared with me" view, conflict screen for
      shared files. Server side and sync are done, see
      [docs/architecture/sharing.md](docs/architecture/sharing.md).
- [ ] German translation next to Czech and English: app texts (ARB),
      iOS system texts (Face ID, share extension) and the store listings.
      Done after the UI rework, so the new texts are translated too.

## Next

- [ ] Shopping list mode for checklist notes: quick add, tap to tick,
      ticked items drop to the bottom and can be cleared, drag to reorder.
      On the server it stays a plain Markdown task list.
- [ ] Suggestions while typing, same as the Notes web app (it uses the
      Nextcloud Text editor when Text is installed):
      - `@` mention: users from `/ocs/v2.php/core/autocomplete/get`, saved
        exactly as Text saves it, `@[Name](mention://user/<id>)`. The web
        notifies the user through a Text session
        (`PUT /apps/text/session/{documentId}/mention`); check whether the
        app can do that without opening a full Text session.
      - `:` emoji suggestions.
      - `/` smart picker: links to files, Deck cards, Talk and other
        reference providers, saved as a plain link.
- [ ] Preview renders what Text writes: mentions as chips, callouts
      (`::: info`), tables, collapsible details, link previews.
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
