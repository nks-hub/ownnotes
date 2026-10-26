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

- [x] Login sjednocený s OwnTalkem včetně rozložení, ikon, CS/EN textů a odpovídajících DE překladů; QR server-only/app-password/one-time, kontrola serveru, browser návrat, cancel, účtový TLS pin, SAN a přístupné chyby jsou implementované v `d324696` (nevydáno do obchodů).
- [x] Login ověření: 54 cílených mobilních testů a analyzátor prošly na `d324696`; 135 protokolových a 116 databázových testů prošlo na `52b63bd`, příslušné package stromy se nezměnily. Osm live testů bez přístupů bylo přeskočeno. Testy běžely na pozadí v oddělených neměnných worktrees.
- [ ] S9+ login průchod zatím neověřený: candidate `d324696` se aktualizoval původním signerem bez mazání dat, ale ovladač nenašel přepínač účtu označený ve stromu jen iniciálami. Browser/QR/persistovaný pin na telefonu nejsou potvrzené; žádný fixture účet nevznikl. Lokální HTTPS fixture byl ukončen a jeho ADB reverse odstraněn.
- [x] Windows souběh `AttachmentCache` opraven sdílenou frontou a souborovým zámkem mezi izoláty; zápisy, čtení a promazávání stejné cache se nepřekrývají. Původní AccessDenied při `File.rename` reprodukován na `39c0a72` příkazem `flutter test test/attachment_cache_test.dart --plain-name "independent cache instances never share a temporary write file"` z `apps/mobile`; nešlo o regresi loginu.
- [x] Ověření cache na Windows: všech 402 mobilních testů a analyzátor prošly na `773f941` v odděleném neměnném worktree. Sada zahrnuje 12 cache testů, souběh dvou instancí i tří izolátů, promazávání a nedostupné úložiště; test editoru před smazáním fixture počká na dokončení práce cache. Nové vydání do obchodů neproběhlo.

- [ ] Real Galaxy Fold: open flat, half open like a book and like a laptop
      (Flex mode), folded to the cover screen with a note open. The
      emulator reports the laptop posture as flat, so that layout was only
      seen with the posture check bypassed.
- [ ] iOS on a real iPhone (TestFlight build 8): add each widget, tap it
      with the app closed and open, tick a task in the checklist widget,
      quick actions on the app icon, share text from another app. The
      simulator run covered only start-up and the `ownnotes://` scheme.
- [ ] On a real phone: QR login (needs a code shown on another screen and
      the phone's camera). Tablet layout was checked only on the S9 with a
      tablet-sized display (`wm size`); a real tablet is still to do.
- [ ] S9 test phone: auto-rotate keeps switching itself back on
      (`accelerometer_rotation` returns to 1 within a minute), so the app
      opens in landscape. The app requests no orientation; the phone is
      rooted (Magisk, LSPosed), check its modules before the next device run.

## Next

- [ ] Mention notification: the Notes web app notifies a mentioned user
      through a Text session (`PUT /apps/text/session/{documentId}/mention`);
      check whether the app can do that without opening a full Text session.
- [ ] iOS background sync (BGTaskScheduler); needs a signed build on an
      iPhone, the simulator never runs it.
- [ ] Remaining slices from [implementation plan](docs/architecture/implementation-plan.md).

## Later


- [ ] Backups that can be restored: ZIP with metadata and attachments.
- [ ] File versions and trash from Nextcloud (DAV), restore keeps the draft.
- [ ] Instant updates through notify_push when the server has it, instead
      of asking every 4 s while a note is open.
- [ ] Desktop builds: see the Desktop section below.
- [ ] Fast start: measure cold start to a cursor in a new note and keep it
      under 1 s on the S9.

## Desktop

Breakdown from the audit of OwnTalk's desktop mode (summary in OwnDeck `docs/desktop.md`), in dependency order.

- [ ] DN01 Decide the desktop platforms (Windows and macOS, plus Linux like OwnTalk) and record the decision here.
- [ ] DN02 Create the desktop platforms in `apps/mobile` with bundle ID `com.nkshub.nextcloudnotes`, name OwnNotes and icons; proof: `flutter build <os> --release` and the window opens.
- [ ] DN03 Windows build workaround for `local_auth_windows` (`CL=/D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS`, as in OwnTalk CI) and Linux packages (gstreamer, libsecret, libcurl); proof: builds pass on windows-latest and ubuntu-latest.
- [ ] DN04 Workmanager, home_widget, QR camera and `setSecure` never run on desktop; proof: first-start log on Windows and macOS without MissingPluginException.
- [ ] DN05 Hide the Camera item where there is no camera (`format_dock.dart:153`, `attach_sources.dart:33`); proof: widget test for Windows, macOS and Linux, photo picking stays.
- [ ] DN06 Check `pickMultiImage` and `FilePicker.pickFiles` on desktop; proof: an image and a PDF attached on each OS reach the server.
- [ ] DN07 Check voice notes (`record`, `audioplayers`) on desktop, hide recording on Linux if `record` does not work there; proof: record and play a 10 s note on each supported OS.
- [ ] DN08 Check `share_plus` on desktop, fall back to copying on Linux if needed; proof: sharing text and a file opens the system dialog on Windows and macOS.
- [ ] DN09 macOS keychain: `MacOsOptions(usesDataProtectionKeychain: false)` in `data/runtime.dart` and macOS entitlements like OwnTalk; proof: sign-in survives a restart.
- [ ] DN10 A locked Linux keyring must not block startup (`accounts.recover` reads everything); port OwnTalk's marker-file pattern; proof: the window shows within 3 s with a locked keyring.
- [ ] DN11 Login Flow v2 in the system browser and the certificate prompt on desktop; proof: sign-in against a test server with a custom certificate on each OS.
- [ ] DN12 App lock with Windows Hello and Touch ID through `local_auth`, hidden on Linux; proof: lock and unlock on Windows and macOS, option absent on Linux.
- [ ] DN13 Secure window on desktop (`WDA_EXCLUDEFROMCAPTURE` on Windows, `sharingType = .none` on macOS) or hide the option there; proof: a screenshot of the protected window is blank.
- [ ] DN14 Window minimum size and remembered position (OwnTalk `MainFlutterWindow.swift`, `window_state.cpp`); proof: size and position survive a restart, shrinking stops at the minimum.
- [ ] DN15 Wide windows: list with the editor beside it at 720/1024/1440/1920 px and a remembered pane width; proof: widget tests without overflow, width survives a restart.
- [ ] DN16 Shortcuts Ctrl/Cmd+S (save and sync now), Ctrl/Cmd+W (close note) and Ctrl/Cmd+, (settings) next to the existing ones; proof: a widget test per shortcut.
- [ ] DN17 Right-click menu on a note row (pin, category, share, delete) and hover; proof: widget test with a secondary click.
- [ ] DN18 Drop files and text onto the editor and the list (OwnTalk `desktop_drop` fork): a file becomes an attachment, text a new note; proof: real drag from Explorer and Finder.
- [ ] DN19 Foreground sync loop on desktop instead of Workmanager (interval, wake-up, network change), optional autostart from OwnTalk; proof: a web edit shows up in the running app within the interval.
- [ ] DN20 Telemetry on desktop with uploaded debug symbols (`--split-debug-info`, sentry-cli); proof: a test crash from desktop is readable in Sentry and opting out works.
- [ ] DN21 Update check and install taken from OwnTalk with repository nks-hub/ownnotes, off by default; proof: ported tests pass and a real release query returns the right state.
- [ ] DN22 Single-user Inno Setup installer for Windows with a smoke test and a new AppId; proof: install, upgrade while running, refused downgrade and uninstall that keeps data.
- [ ] DN23 Authenticode signing with signtool in CI. BLOCKED: no Windows code-signing certificate. Proof: `Get-AuthenticodeSignature` returns Valid.
- [ ] DN24 macOS release script in `tool/` (sign inside-out, notarytool, stapler, `ownnotes-macos-<version>-<build>.zip`). BLOCKED: Developer ID and notarization access are held by the owner. Proof: spctl reports Notarized Developer ID and stapler validate passes.
- [ ] DN25 Sparkle for OwnNotes: its own EdDSA key pair, SUFeedURL on nks-hub/ownnotes, an appcast for every tag. BLOCKED: key generation in the release Mac keychain. Proof: build N updates to N+1 with the sandbox on.
- [ ] DN26 Linux (only if approved in item 1): tarball with `.desktop` file and icon plus OwnTalk's folder swap; proof: an update on real Linux works and a failed start restores the previous version.
- [ ] DN27 CI jobs for Windows and Linux (tests and artifacts) and a release with SHA256SUMS; proof: a green workflow_dispatch with all artifacts.
- [ ] DN28 Desktop tests: hidden camera, shortcuts, mouse, drop, foreground sync, updates, plus an integration test on Windows; proof: `flutter test` and `flutter test integration_test -d windows` pass.
- [ ] DN29 E2E on real machines: sign-in, new note, offline edit and sync, conflict, attachment, lock, update, restart. BLOCKED: a Mac with a display and native Linux. Proof: results recorded in `docs/history.md` with commit and build.
- [ ] DN30 First desktop release: tag, GitHub release with artifacts and SHA256SUMS, macOS ZIP with appcast; proof: download, install and start on each supported OS.

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
