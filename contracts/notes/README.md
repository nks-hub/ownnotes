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

## Rozsah dokumentu

Výše je základní kontrakt Notes REST API. Další části jsou implementované v
[Login Flow v2](../../packages/notes_protocol/lib/src/login.dart),
[sdílení a WebDAV](../../packages/notes_protocol/lib/src/sharing.dart) a
[přílohách](../../packages/notes_protocol/lib/src/attachments.dart).
Ukládání a synchronizaci zajišťuje `notes_store`, obrazovky `apps/mobile`.
Otevřené části jsou v [TODO](../../TODO.md).

Označení sdílení používá [OCS Share API](https://docs.nextcloud.com/server/latest/developer_manual/client_apis/OCS/ocs-share-api.html).
Příchozí a odchozí přímá souborová sdílení mají vlastní údaje v místní databázi;
`kind` dál určuje pouze rozhraní Notes nebo WebDAV. Pole `isShared` v odpovědi
Notes samo nerozlišuje tyto směry a ořezaný seznam může vrátit jen ID;
[implementace Notes 6.1](https://github.com/nextcloud/notes/blob/v6.1.0/lib/Service/NoteUtil.php)
počítá sdílení souboru jeho vlastníkem.

Fixtures are synthetic. They contain no production data. Adapter tests inspect
actual serialized HTTP requests, rather than mocking the resulting DTO alone.
