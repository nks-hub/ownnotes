# Foreground candidate implementation

## Components

- `notes_protocol`: bounded HTTP and Login Flow v2, no automatic mutation retry.
- `notes_store`: Drift schema version 1, accounts, raw note drafts, mutation intent
  journal, foreground coordinator and explicit recovery transitions.
- `apps/mobile`: Riverpod stream projections, secure storage, system-browser login,
  localized notes list, raw Markdown editor, preview and recovery screen.

## Account lifetime

A random account ID owns a namespaced secure-storage reference. Onboarding writes
and verifies the secret before inserting account metadata. Failed insertion
attempts secret cleanup; startup cleans orphaned namespaced entries and marks
accounts with missing secrets for reauthentication. No secret is copied to SQLite.
The credential vault is not transactionally atomic with SQLite. The repository
serializes its own recovery/onboarding/removal calls. The runtime creates one
repository. Removal deletes account identity before vault cleanup, preventing
late receipts from recreating it. Account removal UI is not yet exposed.

## Local durability

Editor changes are debounced for 350 ms and then written with revision comparison.
The UI reports saved only after the write completes. Back navigation waits for
save; lifecycle transitions request a flush. Process death before a pending write
is acknowledged can lose that pending edit. Confirmed draft persistence is tested
by closing and reopening a file-backed SQLite database. Recovery archive rows
remain retained as evidence and are hidden from the normal list.

## Synchronization state transitions

`draft → sending → clean` is the normal path. An edit during sending remains in
the local row and returns to `draft` after receipt. The receipt updates the remote
base, not newer local text. `sending → needsDecision` covers lost responses,
conflicts, partial/nonmatching receipts and interrupted startup operations.
No such operation is replayed automatically.

The coordinator coalesces concurrent calls for one account. Across processes
(the app and the Android WorkManager worker) a per-account lease in
`sync_leases` decides who may send: it is taken with one upsert statement,
renewed before every request (lease 2 min, request timeout 30 s) and released
at the end. A sync that cannot take the lease does nothing. Only the lease
holder turns leftover `sending` operations into `interrupted_write`
decisions, so a worker that is still running is never declared interrupted;
a receipt arriving after that no longer matches `sending` and is ignored.
A receipt journal for such late receipts is not implemented.

Every accepted mutation receipt increments an account mutation epoch. Reads
capture that epoch, and application rejects obsolete epochs. Dirty rows are not
overwritten by pulls. There is no census-based deletion or hiding. A full pull
currently processes pages incrementally; it is not a snapshot of server scope.

A receipt for an existing remote ID reconciles with the original draft. A clean
fetched duplicate is removed; a dirty duplicate becomes an unbound recovery copy.
Foreign-key relations are currently limited to mutation operations; additional
entities must extend reconciliation transactionally when introduced.

Title/category changes are sent like other fields; the server's resulting file
name (it may add "(2)") is adopted. Only notes that reference `.attachments.`
hold such a change for a decision until attachment move verification exists.
Updates use a partial PUT and quoted If-Match. All
unconfirmed outcomes remain explicit decisions. Server normalization can also
produce a nonmatching receipt; this is presented for review, not silently ignored.

## Recovery decisions

The user can inspect the current remote detail and choose server data or rebase
local changes onto the inspected ETag. The decision verifies local revision and
remote identity transactionally and fences old reads. A later server change is
still protected by If-Match on the next PUT. Read-only remote notes cannot be
selected for local overwrite. Another option explicitly creates a separate copy,
warns of possible remote duplication, and archives the old recovery record.
Copying raw Markdown to the clipboard is available on the recovery screen.

## Not implemented / not verified

OCS bootstrap and canonical DAV UID, complete capabilities matrix, settings scope
tracking, remote deletion, authenticated images, attachment integrity, native
background/share/widget integrations, encryption policy, telemetry and signed
release are not complete. No test credentials were supplied and no live server
has been mutated. UI tests use an HTTP mock with the real SQLite and widgets;
they do not establish real Keychain/Keystore, browser/2FA or native build behavior.
