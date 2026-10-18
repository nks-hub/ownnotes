# Evidence and remaining gates

Date: 2026-10-18. This candidate is not the completed product plan.

## Local evidence

- Flutter 3.47.7, framework `abaf9c523780a608bd46686fd5e53740a07077f8`.
- Dart 3.13.5, Linux x64. Dependency resolutions are committed separately for
  protocol, storage and mobile packages.
- Protocol: 67 passing tests, including 14 Login Flow tests and four real
  loopback HTTP transport tests. No live Nextcloud tests.
- Storage/synchronization: 13 passing tests using real SQLite. Covers close/reopen
  persistence, account isolation, secure-store failure, orphan recovery, stale
  local edits, late reads, lost CREATE response, interrupted operation, identity
  reconciliation, removal during mutation and explicit recovery decisions.
- Mobile: two passing widget tests. One covers account onboarding entry; one
  exercises mocked HTTP → NotesClient → real SQLite → Riverpod → UI → editor save.
- Analyzer: clean for all three packages after fixes; verification scripts enforce
  formatting and fatal analyzer infos.
- Android/iOS project generated. Neither Android APK nor iOS app has been built
  locally. No Android SDK/device or Apple build environment is configured here.
- Private GitHub repository exists; source push and remote CI have not happened.

## Remaining acceptance gates

- Live Nextcloud Notes server matrix, browser/2FA, real secure storage and restart.
- OCS capabilities/user identity, settings scope and full wire fault harness.
- Background lease fencing and durable late-receipt journal across workers.
- Attachment move integrity, images/uploads, remote deletion and full recovery UX.
- Native integrations, app lock, telemetry, adaptive tablet UI and complete
  accessibility/contrast verification.
- Export/backup/encryption policy, upgrade migrations and physical-device IME.
- Production identity/license, signing, reproducible artifacts and store release.

Flutter tooling initially triggered blocked cloud detection and analytics requests.
Source inspection identified its Azure detector; standard `CI=true` short-circuits
that probe. `FLUTTER_SUPPRESS_ANALYTICS=true` selects NoOpAnalytics. Verification
scripts use both settings. No metadata endpoint or analytics access was authorized.
