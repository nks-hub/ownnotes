# Evidence and remaining gates

Date: 2026-10-18.

This is a protocol foundation, not a completed PR-00 or mobile release.

## Evidence

Dart 3.13.5 was installed in the current Linux workspace. The locked package uses
http 1.6.0. Exact final analyzer/test results are recorded below after execution.
Source inspection confirms the pinned backend contracts; no real Nextcloud
instance has been mutated or tested in this slice.

## Open gates

- Repository creation and push to nks-hub/ownnotes.
- Disposable supported Nextcloud/Notes server with reproducible configuration.
- Response-loss and partial-write injection against that actual server.
- Persistent coordinator invariants from synchronization.md and their DB tests.
- Flutter/native scaffold, login, secure storage, telemetry and ARB setup.
- Physical Android/iOS tests, pixel contrast and signed release evidence.

Do not infer a completed gate from documentation, an HTTP mock or an existing
feature in OwnTalk. Each gate requires evidence from this project and revision.

## Local verification result

- Dart SDK: 3.13.5, Linux x64.
- `dart pub get --enforce-lockfile`: passed.
- `dart format --output=none --set-exit-if-changed lib test`: passed.
- `dart analyze --fatal-infos`: no issues.
- `dart test --reporter expanded`: 53 passed, 0 failed, 0 skipped.
- Four tests use a real loopback HTTP server: redirect rejection, socket loss
  after receiving POST, stalled response deadline, oversized response stream.
- The remaining tests cover wire parsing, request serialization, ETags, identity,
  sparse pages, error content, Unicode, 304, 412 and uncertain mutations.

Loopback transport evidence does not replace live Nextcloud compatibility or
fault-injection tests. GitHub Actions is configured but has not run remotely.
