# Implementation plan — revision 2

Date: 2026-10-18. This document applies the review of the supplied revision 1
and the established OwnTalk development workflow. It does not mark proposed
features as implemented.

## Product baseline

Keep the standard Nextcloud Notes backend. Preserve raw Markdown as the document
source. Write locally first, synchronize later. Android and iOS use one Flutter
application with an adaptive list/detail layout. Drift is the account-scoped
source of truth; Riverpod provides projections and coordination. Credentials
belong in platform secure storage. Notes HTTP is a standalone Dart package.

Current OwnTalk `apps/mobile/pubspec.yaml`, inspected on 2026-10-18, uses
`flutter_riverpod ^2.6.1`, `http ^1.6.0`, `drift ^2.34.3`,
`drift_flutter ^0.3.1`, `flutter_secure_storage ^11.0.0`,
`sentry_flutter ^9.7.0` and `rybbit_flutter_sdk ^0.3.0`.
These are observed reference constraints, not an already resolved OwnNotes
mobile dependency set. Its documentation and older memories disagree on some
versions and OS minima. Resolve these from native builds, not recollection.

## Delivery slices

| Slice | Deliverable | Completion gate | Current state |
| --- | --- | --- | --- |
| 00a | Strict Dart Notes transport, synthetic fixtures and CI recipe | Analyzer and executable adapter tests | Implemented locally; see evidence |
| 00b | Full wire matrix and disposable server fault harness | Pinned server tests, lost-response injection, partial-write reproduction | Open |
| 01 | Flutter Android/iOS, Login Flow v2, persisted account metadata and secure storage, startup recovery | Real login, two accounts, restart and identity verification | Open |
| 02 | Drift note/snapshot/outbox schema, migrations, local draft/export | Confirmed draft survives process death and upgrade | Open |
| 03 | Pull coordinator, final-page census, causal read barriers and scope changes | Old GET/census cannot roll back a confirmed mutation | Open |
| 04 | Durable CREATE/PUT/DELETE, identity reconciliation, receipt journal and lease recovery | Lost response, duplicate local identities, partial write and late receipt cases | Open |
| 05 | Conflict/decision UI and explicit recovery transitions | Every unresolved operation has a safe, persistent exit | Open |
| 06 | Raw Markdown editor, preview, authenticated image reading, IME/undo | Physical-device text corpus and source preservation | Open |
| 07 | Lists/search/categories/settings, localization, telemetry and accessibility | Complete P0 user flows | Open |
| 08 | Android background, sharing, widgets and app lock | Candidate device scenarios and interruption recovery | Open |
| 09 | iOS extensions, widgets, background and lock | Signed extension/App Group tests | Open |
| 10 | Attachment uploads/cache management/deletion | Per-profile fault tests and move integrity | Open |
| 11 | OCS sharing, templates, DAV versions and cross-account copies | Per-protocol permission and recovery tests | Open |
| 12 | Signed distribution and migration | Exact build evidence and store availability | Open |

The 00a package also starts the protocol portion of slice 01. It does not close
00b or claim that a live server has passed the contract.

## Corrections to revision 1

1. Read/write causal coordination must cover GET, list pages and final census,
   not only local edit revisions and account generations.
2. CREATE binding must merge an already fetched remote identity into the original
   local draft atomically; UNIQUE alone is not recovery.
3. Expired workers cannot update operation state, but their trusted late identity
   receipts may be journaled for the active reconciler of the same live account.
4. Move confirmation includes attachment integrity where attachments exist.
   A matching category does not prove that the attachment folder moved.
5. Define decisions and successor operations for partial PUT and uncertain POST.
6. Public settings equality is an observation, not a server scope version.
7. Secure credential/account persistence moves into slice 01.
8. Read-only authenticated image resolution moves into slice 06; upload and
   cache management remain in slice 10.
9. Localization and telemetry architecture start in slice 01, with complete
   integration gates in slice 07. They are not optional post-release extras.
10. Candidate app identity, pixel contrast checks and exact-source release
    verification are part of the initial project workflow.

## Open product/build decisions

- Choose final license before public distribution or importing third-party code.
  GPL-3.0-or-later follows OwnTalk but has not been granted by this scaffold.
- Confirm store identifiers and platform minima with dependency/native builds.
- Define local backup/encryption policy before database schema stabilization.
- Provision OwnNotes-specific Sentry/Rybbit projects; never reuse OwnTalk IDs.
- Select the real supported Nextcloud/Notes matrix after slice 00b, not from XML
  ranges alone. Estimates remain provisional until protocol/editor spikes pass.
