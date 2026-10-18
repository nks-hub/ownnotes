# OwnNotes

An independent, offline-first Flutter client for Nextcloud Notes.

**Current status:** implementation has started with the standalone Dart wire
protocol and executable contract tests. There is no runnable mobile app yet.
Android and iOS are the first targets; desktop is a later milestone.

## Implemented

- HTTPS installation URLs that preserve a Nextcloud subdirectory.
- Notes API v1 list/detail/create/update/delete transport with JSON request bodies.
- Full, ID-only and unreadable note records, explicit detail 304 responses.
- Quoted Notes ETags, partial update payloads and typed 412 conflicts.
- Bounded responses, request timeout/abort signalling, no redirects or retries.
- Synthetic fixtures, HTTP adapter tests and a reproducible locked Dart package.

A successful transport response is **not** a synchronization acknowledgement.
The future coordinator must validate intended field values, account generations,
operation receipts and local revisions before committing the response.

## Verify

Install Dart 3.13.5, then run from the repository root:

```bash
./tool/check.sh
```

The SDK is pinned for this initial package. The mobile Flutter toolchain will be
pinned separately against actual Android/iOS builds. Do not substitute package
versions from historical memory for the dependency lockfile.

## Documentation

- [Implementation plan](docs/architecture/implementation-plan.md)
- [Synchronization invariants](docs/architecture/synchronization.md)
- [Development and release workflow](docs/architecture/development.md)
- [Protocol scope and sources](contracts/notes/README.md)
- [Evidence and open gates](docs/acceptance/status.md)
- [Original research supplied by the project owner](docs/research/original-plan.cs.md)

The original research is preserved as a historical input. The implementation
plan and synchronization invariants supersede its conflicting recommendations.

## Repository and distribution

Intended repository: `nks-hub/ownnotes`, initially private. Repository creation
is an external setup step and must be verified before claiming publication.
No production credentials, signing keys, telemetry identifiers or user notes
belong in this repository. Final licensing and store identity remain open;
no third-party application source has been copied into the implementation.
