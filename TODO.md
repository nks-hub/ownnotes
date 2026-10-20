# TODO

Rule for every change: no lost text, every conflict has a way out, the editor
stays raw Markdown and never switches to preview on its own.

Finished items go to [docs/history.md](docs/history.md). Codex review with file
references: [docs/research/review-2026-10-20.md](docs/research/review-2026-10-20.md).

## Now

- [ ] Note list stutters while scrolling
- [ ] Compact list header, account switcher and search in the app bar
- [ ] Categories as a tree (drawer), with All, Favorites, Uncategorised
- [ ] Richer note rows: excerpt, time, category, task progress, attachments
- [ ] Sync status in the list also without unsent notes
- [ ] Widget and share links open the right account
- [ ] Login and accounts like OwnTalk (QR login, accounts screen, remove)
- [ ] Sign in again to an existing account without losing its drafts
- [ ] Login: clear error reasons, cancel that really stops the flow
- [ ] Edit from the Markdown preview (tap opens the editor at that spot)
- [ ] Live Markdown styling while typing
- [ ] Preview checkboxes tick the right task (parser-based mapping)
- [ ] Overlapping edits during typing become a decision, not merged text
- [ ] Open editor follows readonly and conflict changes live
- [ ] Links in the preview open
- [ ] Share a note with another user and edit it live together
- [ ] App lock never opens on an error
- [ ] Unsupported languages fall back to English; Face ID text in Czech

## Next

- [ ] Shopping list mode for checklist notes
- [ ] Add attachments (photo, file); Keep import brings images and audio
- [ ] Shared text is stored before the share is acknowledged (Android, iOS)
- [ ] Failed deletions stay visible with retry and undo
- [ ] Read server capabilities and Notes settings; attachment route by version
- [ ] Sync errors persist per account; unreadable notes shown with retry
- [ ] System integration: share out, quick actions, shortcuts, quick tile
- [ ] iOS background sync and WidgetKit widget
- [ ] Remaining slices from [implementation plan](docs/architecture/implementation-plan.md)

## Later

- [ ] Safe census: check sync scope before deleting rows that vanished
- [ ] Attachment moves: explain the decision and give a way out
- [ ] Share the current note out, single-note export
- [ ] Markdown actions: list continuation, indent, links, undo/redo
- [ ] In-note search with previous match and count
- [ ] Tablet list/detail layout
- [ ] Android sync preferences (interval, Wi-Fi only)
- [ ] Configurable Android widgets (account, category, single note)
- [ ] Restorable backups with metadata and attachments
- [ ] File versions and trash through DAV
- [ ] Bulk actions in the list
- [ ] Persist pruneBefore watermarks, use list If-None-Match

## Ideas

- [ ] Templates and a daily note
- [ ] Saved views: unfinished tasks, recent, sync problems
- [ ] Quick capture into an inbox note
- [ ] Spotlight / Android search indexing, Siri / App Intents
- [ ] Links between notes and backlinks
- [ ] Online search through Nextcloud unified search
- [ ] Notification when a conflict needs a decision
- [ ] Grid layout, word and character count
