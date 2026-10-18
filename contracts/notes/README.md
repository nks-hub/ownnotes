# Notes wire contract, initial executable subset

Reference: nextcloud/notes 6.1.0, commit
`0c3dd46dbd781b780c1ea60a13873198609bb98d`.
Sources inspected through GitHub on 2026-10-18:

- [Controller](https://github.com/nextcloud/notes/blob/0c3dd46dbd781b780c1ea60a13873198609bb98d/lib/Controller/NotesApiController.php)
- [ETag and pagination helper](https://github.com/nextcloud/notes/blob/0c3dd46dbd781b780c1ea60a13873198609bb98d/lib/Controller/Helper.php)
- [Note mutations](https://github.com/nextcloud/notes/blob/0c3dd46dbd781b780c1ea60a13873198609bb98d/lib/Service/Note.php)
- [Attachment movement](https://github.com/nextcloud/notes/blob/0c3dd46dbd781b780c1ea60a13873198609bb98d/lib/Service/NoteUtil.php)
- [Routes](https://github.com/nextcloud/notes/blob/0c3dd46dbd781b780c1ea60a13873198609bb98d/appinfo/routes.php)

## Implemented contract

| Operation | Request | Result |
| --- | --- | --- |
| List | GET api/v1/notes, chunkSize, optional pruneBefore/cursor | 200 list, opaque next cursor, optional server Last-Modified |
| Detail | GET api/v1/notes/id, optional quoted If-None-Match | Validated identity or explicit 304 |
| Create | POST api/v1/notes, JSON | 200 full note or unreadable identity receipt |
| Update | PUT api/v1/notes/id, JSON changed fields, quoted If-Match | 200 note, 412 typed remote conflict |
| Delete | DELETE api/v1/notes/id | 200 empty JSON array, no conditional-deletion guarantee |

The adapter requires the full API >=1.2 fields and does not negotiate capabilities
yet. It never requests `exclude`; unexpected projections fail closed. List 304
optimization is intentionally disabled. Empty content/false are explicit values;
missing fields are not defaulted. Unreadable content is discarded, preserving ID.
Duplicate IDs within one page fail; IDs may legitimately repeat across pages.

Transport limits are configurable, default 8 MiB/30 seconds. Requests disable
redirects and signal abortion on timeout/completion. The injected HTTP client
must honor the package:http redirect/abort contract; it must not be wrapped by
a retrying client for mutations. Timeout does not disprove a remote write.
All failed mutation HTTP statuses are conservatively marked mayHaveApplied;
the coordinator can refine that only with independently verified evidence.

Successful intended-value validation belongs to the coordinator. The adapter
never claims a 200 body is sufficient to mark a local revision synchronized.
Error bodies, credentials and note text are absent from exception strings.

## Not implemented

Login Flow v2, capabilities, settings, explicit exclude projections, attachment
transport, persistent cache/outbox, synchronization coordinator, Flutter screens,
OpenAPI coverage of the complete server, live server/fault tests.

Fixtures are synthetic. They contain no production data. Adapter tests inspect
actual serialized HTTP requests, rather than mocking the resulting DTO alone.
