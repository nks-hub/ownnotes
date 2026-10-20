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

- [ ] Finish the redesign on iOS on the Mac (the build Mac was offline): run
      `apps/mobile/ios/tool/add_widget_extension.rb`, give the bundle id
      `com.nkshub.nextcloudnotes.Widgets` the App Group in the developer
      portal, build and run on the simulator, signed archive, then a
      TestFlight build. The Swift share extension changes and the
      WidgetKit sources are not compiled yet.
- [ ] New store screenshots of the redesigned app (cs, en, de; light and
      dark) and upload the German Play listing.
- [ ] On real phones: camera, microphone and file attachments; sharing a
      note with a second account and editing it from both; QR login and
      "sign in again"; widgets on Android 10 (S9) with the fallback colours;
      tablet layout on a large screen.
- [ ] S9 test phone: auto-rotate keeps switching itself back on
      (`accelerometer_rotation` returns to 1 within a minute), so the app
      opens in landscape. The app requests no orientation; the phone is
      rooted (Magisk, LSPosed), check its modules before the next device run.

## Next

- [ ] Mention notification: the Notes web app notifies a mentioned user
      through a Text session (`PUT /apps/text/session/{documentId}/mention`);
      check whether the app can do that without opening a full Text session.
- [ ] System integration: iOS quick actions, Android shortcuts and a quick
      settings tile for a new note.
- [ ] iOS background sync (BGTaskScheduler); needs a signed build on an
      iPhone, the simulator never runs it.
- [ ] Remaining slices from [implementation plan](docs/architecture/implementation-plan.md).

## Later

- [ ] Find in note: previous match and match count.
- [ ] Android sync settings (interval, Wi-Fi only).
- [ ] Backups that can be restored: ZIP with metadata and attachments.
- [ ] File versions and trash from Nextcloud (DAV), restore keeps the draft.
- [ ] Keep the incremental-pull marker across restarts; use the list ETag.
- [ ] Instant updates through notify_push when the server has it, instead
      of asking every 4 s while a note is open.
- [ ] Desktop builds (Windows, macOS) like OwnTalk.
- [ ] Fast start: measure cold start to a cursor in a new note and keep it
      under 1 s on the S9.

## Ideas

- [ ] Quick capture appended to an inbox note.
- [ ] Spotlight and Android search indexing (opt-in, hidden while locked),
      Siri / App Intents: new note, append, open, search.
- [ ] Links between notes and backlinks, written as relative Markdown
      links that the Notes web app and the Text app also open (check first).
- [ ] Online search through Nextcloud unified search.
- [ ] Notification when a conflict needs a decision.
- [ ] Grid layout, word and character count.
- [ ] A sketch as an attachment.
- [ ] `#tags` written in the note text as a filter next to categories.
      Notes has no tags; they stay plain text, so other clients see them.
- [ ] Text recognition in attached images and PDFs for search, on the
      device (ML Kit, Apple Vision), never sent anywhere.
- [ ] Summary and grammar check through the Nextcloud Assistant of the
      user's own server, only when the server offers it.
- [ ] Lock chosen categories separately with biometrics.
