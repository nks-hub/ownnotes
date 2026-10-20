# Sharing a note with another Nextcloud user

Status: protocol, store and sync implemented and tested live; no UI yet.
Everything uses standard Nextcloud shares and WebDAV. No metadata and no extra
files are written next to notes, so the Notes web app, Files and Text show the
same text OwnNotes shows. App-only state lives in the local database.

## What the server does (verified on Nextcloud 34.0.4, Notes 6.1.0)

Test accounts A (owner) and B (recipient), both with the Notes app.

1. Share. `POST /ocs/v2.php/apps/files_sharing/api/v1/shares?format=json`
   with `path=/Notes/Cat/Title.md`, `shareType=0`, `shareWith=<uid>`,
   `permissions=3` (read + update) answers `ocs.meta.statuscode 200` and
   `data.id`, `data.file_source` (the file id), `data.permissions`. The path
   is `internalPath` of the Notes API note. Header `OCS-APIRequest: true`.
   Form values must be URL encoded; a wrong path answers `statuscode 404`.
2. Where the file lands. Notes 6.1.0 registers `BeforeShareCreatedListener`:
   a user share of a file inside the owner's notes folder gets the target
   `/<recipient notesPath>/<file name>`, and the recipient's notes folder is
   created if missing. So the file appears in B's Notes folder (category lost:
   it is `""` for B) and B's Notes API lists it as an ordinary note:
   same `id` as for A (the file id), `isShared: true`, `shareTypes: [0]`,
   `internalPath: /Notes/<name>.md`. `PUT` with `If-Match` through the Notes
   API works for B, and A sees the change at once. The Notes `etag` differs
   per user (it covers the category), so it is never compared across users.
3. Fallback. The listener swallows its errors. When it fails (B's quota is
   exhausted so the folder cannot be created: Notes API answers 500
   `{"errorType":"Exception"}` for B and `MKCOL` answers 507) or the file is
   outside A's notes folder, the file lands in B's files root
   (`file_target: "/name.md"`). The Notes API of B does not list it.
4. Incoming list. `GET .../shares?shared_with_me=true&format=json` lists
   `id`, `item_type` (`file`), `file_source` (file id = Notes id),
   `file_target` (mount path = WebDAV path in B's files), `uid_owner`,
   `displayname_owner`, `permissions`. Folders and room shares are in the same
   list and are skipped.
5. WebDAV of a mounted share, as B: `/remote.php/dav/files/<B>/<file_target>`.
   - `PROPFIND` Depth 0 with `d:getetag`, `d:getlastmodified`, `oc:fileid`,
     `oc:permissions`: 207; `oc:permissions` is `SGDNVW` for a share with
     update (`W` = writable), `oc:fileid` equals the Notes id.
   - `GET`: 200, header `ETag: "<hex>"`.
   - `PUT` with `If-Match: "<etag>"`: 204 with `OC-ETag`/`ETag` of the new
     version. A stale tag answers 412 with the current `ETag` header and
     writes nothing. B's exhausted quota did not block writes to the shared
     file (they count for the owner).
   - The WebDAV `ETag` differs from the Notes API `etag` of the same note.
6. Sharee search: `GET .../api/v1/sharees?search=<q>&itemType=file&format=json`
   gives `data.users[] = {label, value: {shareType: 0, shareWith: uid}}` and
   the same under `data.exact.users`. It includes the caller.
7. Ending a share: `DELETE .../shares/<id>` (owner or recipient). After it
   the note disappears from B's Notes listing (the ordinary census removes
   the clean copy) and from `shared_with_me`.
8. A moved received file: `MOVE` of a mounted share into B's `Notes` folder
   works (201) and turns it into a Notes API note. Not needed in practice
   because of 2, but it is the repair for a share that landed in the root.

Not verified: read-only shares against the live server (covered by fake
server tests only), groups, link shares, federated shares, share
acceptance workflows (`share_folder`, pending shares).

## Code

`packages/notes_protocol/lib/src/sharing.dart` - `SharingClient`:
`searchSharees`, `shareWithUser(path, uid, canEdit)`, `sharesOf(path)`,
`unshare(id)`, `sharedWithMe()`, `stat/read/write(path, etag)` (WebDAV,
`SharedConflict` on 412), `move`, `createFolder`. `RemoteNote` gained
`internalPath` and `isShared`. `ServerBase` gained `ocsSharing` and
`davFile`.

`packages/notes_store`:
- `local_notes.kind` (`note` | `shared`) and `dav_path`, schema version 3.
  A `shared` row has `remote_id` = file id and `etag` = WebDAV etag.
- `SyncCoordinator(..., sharingFor: ...)` syncs shared rows after the Notes
  pass, with the same states as ordinary notes: `draft`, `sending`,
  `needsDecision` (`remote_conflict`, `remote_deleted`,
  `write_outcome_unknown`, `missing_etag`), `clean`. A rejected `If-Match`
  (412) reads the file and runs the same line merge (`mergeThreeWay`) and one
  retry; the same line changed on both sides is a decision that
  `NoteRecovery.useRemote` resolves, with `SyncCoordinator.readShared(note)`
  supplying the remote text. Only the text is sent; a shared file is not
  renamed or moved.
- Live editing: every sync pass does one `PROPFIND` per shared note and
  downloads only when the ETag changed. The incoming share list is read at
  most every `shareListInterval` (60 s) or at once with
  `sync(id, relist: true)`. The editor's existing 4 s poll of
  `sync.sync(accountId)` therefore covers shared notes and ordinary shared
  notes alike (ordinary ones are pulled by the Notes API as any change).
- When the Notes API starts listing a file that was a `shared` row (the
  repair in 8), `applyPull` converts the row to `kind = note`.
- `markDeleted` refuses a shared row (`note_shared`); leaving a share is
  `SharingClient.unshare(incoming.id)`.
- Share ids of incoming shares are not stored; read them from
  `sharedWithMe()` (match on `fileId == note.remoteId`).

Tests: `packages/notes_protocol/test/sharing_test.dart` (fake client),
`packages/notes_store/test/shared_sync_test.dart` (real SQLite, fake server),
`packages/notes_store/test/live_sharing_test.dart` (skipped unless
`OWNNOTES_LIVE_URL`, `OWNNOTES_LIVE_USER`, `OWNNOTES_LIVE_PASSWORD`,
`OWNNOTES_LIVE_USER2`, `OWNNOTES_LIVE_PASSWORD2` are set; runs both paths:
note shared from the Notes folder, and a Markdown file outside it).

## What the UI needs

- Share button in the editor, for notes with a `remoteId` and
  `kind == 'note'`: read `NotesClient.get(remoteId)` for `internalPath`, open
  a sharee picker backed by `SharingClient.searchSharees` (debounced, minimum
  one character), call `shareWithUser(internalPath, uid)`, show current
  shares with `sharesOf(internalPath)` and `unshare`. Refuse a note that is
  not yet uploaded.
- "Shared with me" section in the list: rows with `isShared` are not exposed
  in `LocalNote` (the row has no flag for ordinary shared notes); to show the
  section, call `sharedWithMe()` at list refresh or add a `shared` boolean
  to `LocalNote` filled from `RemoteNote.isShared` in `applyPull` (not done:
  needs a decision on UI). `kind == 'shared'` rows are always shared-with-me.
  Show the owner (`IncomingShare.ownerName`) and a lock when `readonly`.
- Wire `SyncCoordinator(sharingFor: (account) async => SharingClient(...))`
  in `runtime.dart` next to `clientFor`; call `sync(id, relist: true)` after
  the user shares or accepts something.
- The recovery screen calls `client.get(remoteId)`; for `kind == 'shared'`
  it must call `sync.readShared(note)` instead.
- The editor opens shared notes like any other (raw Markdown). Title edits
  on a `shared` row are not sent. Deleting a shared note: confirm, then
  `unshare` for the recipient; show "note_shared" error otherwise.
- Quota: if sharing makes the recipient's Notes folder uncreatable the note
  appears as `kind == 'shared'` outside the Notes folder; the list should
  treat both kinds the same.
