# OwnNotes

Independent offline-first Flutter client for Nextcloud Notes. Android and iOS
candidate projects are included. This is an executable development foundation,
not a production-ready implementation of the complete product plan.

## Implemented

- Login Flow v2 in the system browser, same-origin/path checks, single poller,
  bounded responses and terminal handling of lost credential responses.
- Secure credential adapter, account metadata in Drift, orphan recovery and
  explicit missing-credential state. No plaintext password fallback.
- Account-scoped SQLite notes, raw Markdown, local revision checks, autosave,
  search, categories, favorites and preview. Passwords are excluded from SQLite.
- Foreground synchronization: durable intent before CREATE/PUT, uncertain write
  recovery, partial content/favorite updates, quoted ETags and conflict decisions.
- Mutation epochs reject stale reads; CREATE receipts preserve newer local edits
  and reconcile already fetched remote identities. Pull never deletes by census.
- Conflict comparison and explicit server/local/copy decisions. Original uncertain
  records remain retained when the user creates a separate recovery copy.
- English/Czech ARB localization, light/dark themes and candidate native identities.
- Dart/SQLite/widget tests, including an HTTP adapter → database → UI/editor flow.

## Deliberate limits of this candidate

Only one foreground sync coordinator is enabled. Native background workers and
cross-process leases are not implemented. Renaming/moving existing notes pauses
for a decision because attachment movement requires separate integrity checks.
Remote DELETE, authenticated images, attachment uploads, OCS capabilities/DAV UID,
advanced sharing/version history, widgets, app lock, telemetry and full adaptive
tablet layout remain open. Preview currently shows placeholders for images.

The database is sandboxed SQLite, not an encrypted database. Production backup,
encryption and export policy remains an explicit release gate. No release is
signed with a debug key. No live Nextcloud/device compatibility claim is made.

## Run and verify

Flutter is pinned to **3.47.7** (`.flutter-version`), Dart **3.13.5**. Use the
committed dependency lockfiles. Install hooks after cloning:

```bash
git config user.name LuRy
git config user.email lury@lury.cz
git config core.hooksPath .githooks
bash tool/check.sh
bash tool/check_mobile.sh
cd apps/mobile
flutter run
```

`check_mobile.sh` serializes Flutter tests using `flock` on Linux/macOS systems
with that command installed. Windows runners must serialize this checkout too.
Build-host SDK telemetry is suppressed by the verification scripts. On restricted
root containers, `TAR_OPTIONS=--no-same-owner` may be needed for SDK extraction.

Android and iOS candidate identifier: `cz.lury.ownnotes.candidate`. Production
identifiers, signing and distribution remain unconfigured. GitHub CI includes
an Android debug build, but no remote CI result exists until source is pushed.

## Documentation

- [Implementation plan](docs/architecture/implementation-plan.md)
- [Synchronization invariants](docs/architecture/synchronization.md)
- [Development workflow](docs/architecture/development.md)
- [Candidate behavior and limitations](docs/architecture/candidate.md)
- [Evidence and remaining gates](docs/acceptance/status.md)
- [Protocol sources](contracts/notes/README.md)
- [Original supplied research](docs/research/original-plan.cs.md)

The private repository `nks-hub/ownnotes` exists. Local Git push authentication
is still unavailable; source publication must be verified separately. All commits
must have author and committer `LuRy <lury@lury.cz>`. Final licensing is undecided.
