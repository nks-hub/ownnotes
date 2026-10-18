# Synchronization invariants

Status: required design for the future coordinator, not implemented by the HTTP
adapter. All state and foreign keys are scoped by account identity.

## Causal reads and mutations

Use one per-account coordinator. For the first implementation, serialize pulls
and mutation dispatch for an account, including detail reads used by recovery.
Local edits remain available while network work runs. All background triggers
must join this coordinator rather than start a second network writer.

Persist a mutation epoch. Every read ticket records account generation, settings
epoch, mutation epoch and run identity. In one database transaction, check those
values again before applying a snapshot or census. A successful mutation or an
uncertain dispatch invalidates older read tickets. A stale response schedules a
fresh read; it cannot overwrite the current remote baseline or hide newly
created notes. ETags are opaque and cannot be chronologically ordered.

Crash recovery must not allow an expired network worker to overlap a new mutation
of the same note. An HTTP timeout/abort only stops local waiting; it does not
prove that the server stopped. Uncertainty blocks dependent writes.

External writers remain outside this ordering. Standard Notes does not provide
an atomic, cross-interface compare-and-swap guarantee for the whole operation.

## CREATE identity binding

When a trusted CREATE receipt supplies remote ID R for local draft L:

1. Verify original account identity, operation/attempt and request destination.
2. Find a local row already bound to R in the same account.
3. In one transaction preserve L as the draft identity; consolidate the fetched
   remote row, snapshots, references, pending edits and tombstone state.
4. If the other row was independently edited, retain its draft as a conflict,
   never silently delete it. Resolve the unique remote binding only once.
5. Accept the sent revision as acknowledged only after value validation; preserve
   newer local edits. An unreadable receipt supplies identity, not content.

A content/title hash is not operation identity. Candidate selection by the user
must also use this transaction and retain competing drafts.

## Leases and late receipts

A fenced-out worker cannot confirm an operation. It may append a validated
receipt to the immutable receipt journal if the original account identity still
exists. The current reconciler decides whether it is usable. The journal must
not restore an account removed by the user, cross an account rebind, or promote
old credentials to a new trust scope. Receipt arrival is itself idempotent by
operation/attempt and validated response identity.

## Explicit recovery transitions

| Observation | Action |
| --- | --- |
| PUT target fields reached | Validate identity and required side effects, confirm sent revision, retain newer draft |
| PUT partly applied; remaining fields still equal base | Build a new operation for only remaining intent using the newly observed ETag |
| A remaining field differs from both base and intent | Keep all versions and request conflict resolution |
| PUT body unreadable or identity invalid | Preserve receipt if trustworthy; stay in reconciliation |
| Uncertain CREATE with trustworthy receipt | Bind identity, fetch detail, validate intended values |
| Uncertain CREATE without trustworthy identity | Offer candidate binding, local-only preservation, or explicit new creation with duplicate warning |
| User selects candidate | Bind atomically; mark the old operation resolved by decision without pretending server causality was proved |
| User chooses local-only | Close network dependencies as cancelled-by-decision; retain the draft and original receipt history |
| User chooses new creation | Create a distinct successor operation, retain unresolved predecessor evidence |
| DELETE followed by 404 | Record unavailable identity, not proof of physical file deletion |

Do not reuse a sent operation ID with a changed payload. Read-only/access loss
keeps drafts. All state transitions and dependent-operation changes are atomic.

## Scope and membership

Only a valid final page supplies a membership census. Membership is evidence of
visibility in this account/range, not physical deletion. Compare public settings
before/after, but do not call that a complete scope version: internal custom
suffixes, permissions, and changes that return to their initial value can escape
it. Keep recovery copies and use a fresh full pass after observed changes.
Previously unavailable known IDs must become visible again when a new valid
census includes them, even when represented by ID-only records.

## Move integrity

Notes 6.1 moves the note first and its attachment folder afterwards. A failure
can leave the category updated and attachments at the old path. An identical
category PUT may not repeat the missing side effect. An existing destination
attachment folder can also cause the server helper to skip the folder move.

Keep the original category/path and attachment observations in the operation.
For known attachments, verify accessibility/identity in the new scope before
confirming the complete move. On ambiguity, report partial completion and retain
recovery state. Do not silently issue arbitrary DAV repairs or delete either
folder. A dedicated repair contract is a separate feature. P0 must account for
existing attachments even before it implements uploads.

## Additional acceptance scenarios

- GET A starts, PUT B is confirmed, late GET A arrives: B remains current.
- Final census starts before CREATE confirmation: new identity is not hidden.
- Pull materializes remote R before CREATE response binds L: one binding, drafts kept.
- A stale worker returns the only CREATE ID: receipt survives, worker cannot commit.
- Category changes but attachment move fails: operation remains partially complete.
- Each needs-decision choice survives restart and releases only valid dependencies.
- Hidden/custom-suffix membership changes without distinguishable public settings.
- A known unavailable ID reappears as ID-only and regains visibility.
