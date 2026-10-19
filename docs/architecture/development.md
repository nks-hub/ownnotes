# Development and release workflow

## Git identity

All commits must use exactly `LuRy <lury@lury.cz>` as both author and
committer. Do not use bot, assistant or GitHub noreply identities. Verify both
fields before pushing.

```bash
git config user.name LuRy
git config user.email lury@lury.cz
git config core.hooksPath .githooks
git log -1 --format=fuller
```

The pre-push hook and CI verify author and committer on every reachable commit.
CI checks the PR head rather than GitHub's synthetic merge commit. New clones
must install the hook with the command above. Prepare merges locally with the
required identity instead of using GitHub-generated merge commits.

## Structure and verification

`packages/notes_protocol` contains no Flutter, storage or UI dependencies.
`apps/mobile` owns accounts, Drift, synchronization, features and native
adapters. No screen calls Notes REST directly. Avoid large mixed-responsibility
files; keep logical changes independently reviewable.

Run formatter, analyzer and meaningful tests before a commit. Verify changed
mobile flows with a fresh application run, not only hot reload. Track analyzed,
designed, implemented, automated and live-device evidence separately. Do not
mark unused helpers or unconnected screens as completed features.

For Flutter tests use one runner per checkout. The Linux verification script `tool/check_mobile.sh` uses an exclusive file
lock. Other hosts must preserve the same single-runner rule. Never kill every dart/flutter process by image name.
Stop only positively identified workers of the affected checkout.

`packages/notes_protocol/test/live_server_test.dart` runs the client against a
real server when `OWNNOTES_LIVE_URL`, `OWNNOTES_LIVE_USER` and
`OWNNOTES_LIVE_PASSWORD` are set; otherwise it is skipped. Use a dedicated
account without 2FA. The test creates and deletes its own notes. Never commit
the credentials.

Use `.candidate` test identities with isolated data. Test upgrade installation
without clearing production accounts. Include actual HTTP-to-DB-to-UI paths,
offline edits, process death, account switches and schema upgrades.

## UI and localization

Use ARB localization from the first mobile screen. Check key completeness,
placeholder compatibility and generated localization output. Test both themes,
200% text, TalkBack/VoiceOver, native back navigation and adaptive layouts.
Measure rendered contrast including alpha compositing: ordinary text 4.5:1 and
meaningful UI graphics 3:1. Use 48 dp Android/44 pt iOS touch targets. Bottom
navigation requires at least three peer top-level destinations.

## Telemetry

Configure the project's own Sentry and Rybbit integrations through an ignored
`telemetry.env` and a checked-in empty example. Names: SENTRY_DSN, RYBBIT_HOST,
RYBBIT_SITE_ID, TELEMETRY_ENVIRONMENT. No configured endpoint means no SDK
initialization. Build-time values are embedded in binaries, not a secret vault.

Strip note content/titles, searches, app passwords, authorization, upload bodies
and tokenized URLs from events/breadcrumbs. Use static route names without note
text or remote identifiers. Keep Rybbit automatic error capture disabled when
Sentry owns error handling. Verify actual receipt of a synthetic event and the
absence of sensitive markers. Define opt-out and truthful store disclosures.
Do not reuse reference-app telemetry identifiers.

## Builds and release

Use the Flutter version from `.flutter-version`; the mobile lockfile does not
resolve with older SDKs. On the reference Windows workstation it lives in
C:\work\sources\flutter-sdk-3.47.7\flutter, separate from the shared SDK.
Apple builds run on the build Mac under a regular user, not root. Native tools, SDK versions,
minimum OS versions and signing profiles must be inspected at build time.
Historical simulator failures are not permanent compatibility facts.

Build from an exact commit and lockfile. Record version/build number, Git tag,
signing identity, artifact hash and build-time configuration validation without
printing values. Keep scripts in tool/ or scripts/, never disposable build/.

Google Play upload and App Store Connect/TestFlight upload are separate from
availability. Verify the processing/review/group/track state after upload. Write
user-facing release notes from changes since the preceding tag, in supported
languages. Remove only the exact temporary files produced by that build; keep
installed app data, signing material and evidence. No release is performed by
the initial protocol workflow.
