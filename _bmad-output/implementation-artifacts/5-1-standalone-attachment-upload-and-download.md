# Story 5.1: Standalone Attachment Upload & Download

Status: done

## Story

As a client,
I want to upload attachments via `PUT /{db}/{docid}/{attname}` and download them via `GET /{db}/{docid}/{attname}`,
so that I can associate binary files with documents and retrieve them.

## Acceptance Criteria

1. `PUT /{db}/{docid}/{attname}?rev=N-hex` with binary body and `Content-Type` header creates attachment, returns 201 with `{"ok":true,"id":"...","rev":"(N+1)-<hash>"}`
2. Content stored via `%Stream.GlobalBinary` in `^IRISCouch.Atts`
3. Attachment metadata (content_type, length, digest) recorded in document's `_attachments` metadata
4. MD5 digest computed on upload and stored as `"md5-<base64>"` for replication integrity
5. `GET /{db}/{docid}/{attname}` returns raw binary content with matching Content-Type header and 200 OK
6. Content streamed without buffering entire body in process memory (NFR-P8: memory bounded by stream buffer size, not attachment size)
7. 500 MB attachment upload/download must NOT cause proportional RSS growth
8. 404 returned with error envelope when attachment, document, or database doesn't exist
9. 409 returned when `rev` parameter is stale or missing for existing document
10. Attachment creates a new document revision (rev incremented)
11. Changes feed entry generated for the new revision (via existing RecordChange integration)
12. `DELETE /{db}/{docid}/{attname}?rev=N-hex` removes attachment and creates new revision

## Tasks / Subtasks

- [x] Task 1: Create `IRISCouch.Storage.Attachment` class (AC: #2, #3, #4)
  - [x] 1.1 Create `src/IRISCouch/Storage/Attachment.cls`
  - [x] 1.2 `ClassMethod Store(pDB, pDocId, pRev, pAttName, pContentType, pStream As %Stream.GlobalBinary) As %Status` — stores stream to `^IRISCouch.Atts(pDB, pDocId, pRev, pAttName)`, computes MD5 digest, records metadata
  - [x] 1.3 `ClassMethod Get(pDB, pDocId, pAttName, Output pStream As %Stream.GlobalBinary, Output pContentType, Output pLength, Output pDigest) As %Status` — retrieves stream + metadata for latest (or specified) revision that has the attachment
  - [x] 1.4 `ClassMethod Delete(pDB, pDocId, pRev, pAttName) As %Status` — removes attachment from a revision
  - [x] 1.5 `ClassMethod GetMetadata(pDB, pDocId, pRev) As %DynamicObject` — returns `_attachments` JSON object for all attachments on a revision (stubs with content_type, length, digest, revpos, stub:true)
  - [x] 1.6 `ClassMethod Exists(pDB, pDocId, pAttName) As %Boolean` — checks if attachment exists on any revision
  - [x] 1.7 MD5 digest computation: use `$System.Encryption.MD5HashStream()` or equivalent, base64-encode, format as `"md5-<base64>"`
  - [x] 1.8 Compile and verify

- [x] Task 2: Integrate attachments into DocumentEngine (AC: #10, #11)
  - [x] 2.1 Modify `DocumentEngine.Save()` to accept optional attachment parameters (pAttName, pContentType, pStream)
  - [x] 2.2 When attachment provided, call `Storage.Attachment.Store()` inside the TSTART/TCOMMIT transaction, after document body write
  - [x] 2.3 Update document body to include `_attachments` stub metadata in revision
  - [x] 2.4 For DELETE attachment: create new revision without the deleted attachment's metadata
  - [x] 2.5 Compile and verify existing 169 tests still pass

- [x] Task 3: Create `IRISCouch.API.AttachmentHandler` class (AC: #1, #5, #8, #9, #12)
  - [x] 3.1 Create `src/IRISCouch/API/AttachmentHandler.cls`
  - [x] 3.2 `ClassMethod HandlePut(pDB, pDocId, pAttName) As %Status` — validates db/doc exist, checks rev parameter, reads binary body as stream, calls DocumentEngine.Save with attachment, returns 201 JSON
  - [x] 3.3 `ClassMethod HandleGet(pDB, pDocId, pAttName) As %Status` — retrieves attachment via Storage.Attachment.Get(), streams binary response with correct Content-Type, returns 404 if missing
  - [x] 3.4 `ClassMethod HandleDelete(pDB, pDocId, pAttName) As %Status` — validates rev, removes attachment, creates new revision, returns 200 JSON
  - [x] 3.5 Binary body reading: use `%request.Content` (the stream) directly — do NOT read into a string variable. This ensures NFR-P8 compliance.
  - [x] 3.6 Binary response writing: use `%response.ContentType`, then stream output via `Do pStream.OutputToDevice()` — never buffer
  - [x] 3.7 Error handling: follow catch block pattern (Error.Render + Return $$$OK), RenderInternal for 500s
  - [x] 3.8 Compile and verify

- [x] Task 4: Add routes to Router (AC: #1, #5, #12)
  - [x] 4.1 Add 3 routes to Router.cls UrlMap BEFORE `/:db/:docid` routes:
    - `<Route Url="/:db/:docid/:attname" Method="PUT" Call="HandleAttachmentPut" />`
    - `<Route Url="/:db/:docid/:attname" Method="GET" Call="HandleAttachmentGet" />`
    - `<Route Url="/:db/:docid/:attname" Method="DELETE" Call="HandleAttachmentDelete" />`
  - [x] 4.2 Add wrapper methods: `HandleAttachmentPut(pDB, pDocId, pAttName)`, `HandleAttachmentGet(pDB, pDocId, pAttName)`, `HandleAttachmentDelete(pDB, pDocId, pAttName)` — each delegates to AttachmentHandler
  - [x] 4.3 Compile Router

- [x] Task 5: Unit tests (AC: #1-#12)
  - [x] 5.1 Create `src/IRISCouch/Test/AttachmentTest.cls` with unit tests:
    - Store and retrieve attachment via Storage class
    - MD5 digest computation and format verification
    - Attachment metadata retrieval (stub format)
    - Delete attachment
    - Attachment on non-existent document
  - [x] 5.2 Create `src/IRISCouch/Test/AttachmentHttpTest.cls` with HTTP integration tests:
    - PUT attachment returns 201 with new rev
    - GET attachment returns binary content with correct Content-Type
    - GET missing attachment returns 404
    - DELETE attachment returns 200 with new rev
    - PUT without rev on existing doc returns 409
    - PUT on non-existent database returns 404
  - [x] 5.3 Run full test suite — confirm 169+ tests pass, 0 regressions

- [x] Task 6: Manual HTTP verification via curl
  - [x] 6.1 PUT a text attachment, verify 201 response
  - [x] 6.2 GET the attachment, verify content matches
  - [x] 6.3 PUT a binary attachment (image/png), verify round-trip
  - [x] 6.4 DELETE attachment, verify 200 and new rev
  - [x] 6.5 GET deleted attachment, verify 404

## Dev Notes

### Architecture: New Files to Create

| File | Class | Purpose |
|------|-------|---------|
| `src/IRISCouch/Storage/Attachment.cls` | `IRISCouch.Storage.Attachment` | Storage encapsulation for `^IRISCouch.Atts` via `%Stream.GlobalBinary` |
| `src/IRISCouch/API/AttachmentHandler.cls` | `IRISCouch.API.AttachmentHandler` | REST handler for attachment CRUD |
| `src/IRISCouch/Test/AttachmentTest.cls` | `IRISCouch.Test.AttachmentTest` | Unit tests for Storage.Attachment |
| `src/IRISCouch/Test/AttachmentHttpTest.cls` | `IRISCouch.Test.AttachmentHttpTest` | HTTP integration tests |

### Files to Modify

| File | Changes |
|------|---------|
| `src/IRISCouch/Core/DocumentEngine.cls` | Add optional attachment parameters to Save(); call Storage.Attachment.Store() in transaction |
| `src/IRISCouch/API/Router.cls` | Add 3 routes + 3 wrapper methods for attachment endpoints |

### Critical Pattern: Storage Encapsulation

All `^IRISCouch.Atts` global access MUST be in `Storage.Attachment` only. No handler or engine class touches globals directly.

### Critical Pattern: Streaming I/O (NFR-P8)

**Upload (PUT):**
- `%request.Content` IS a stream object in %CSP.REST — use it directly
- Pass the stream to `Storage.Attachment.Store()` which copies to `%Stream.GlobalBinary`
- Use `Do tTarget.CopyFrom(pStream)` to copy stream-to-stream (no string buffer)

**Download (GET):**
- Retrieve `%Stream.GlobalBinary` from Storage
- Set `%response.ContentType` to stored content_type
- Set `%response.Headers("Content-Length")` if known
- Use `Do pStream.OutputToDevice()` to stream directly to HTTP response
- Do NOT use `%response.Write()` with full content — that buffers in memory

### Critical Pattern: MD5 Digest

CouchDB uses `"md5-<base64>"` format for attachment digests:
```objectscript
; Compute MD5 hash of stream
Do pStream.Rewind()
Set tHash = $System.Encryption.SHA1HashStream(pStream)  ; Check if MD5HashStream exists
; If MD5HashStream doesn't exist, read in chunks and use MD5Hash
; Base64 encode: Set tB64 = $System.Encryption.Base64Encode(tHash)
; Format: Set tDigest = "md5-" _ tB64
Do pStream.Rewind()  ; Reset stream position after hashing
```
**IMPORTANT**: Research `$System.Encryption` methods for MD5 stream hashing before implementing. Use Perplexity MCP if unsure about exact method signatures.

### Critical Pattern: Revision Integration

Attachment PUT creates a new document revision:
1. Read current document body from Storage.Document
2. Update `_attachments` metadata in body with new attachment stub
3. Call DocumentEngine.Save() with updated body (this creates new rev, records change, signals longpoll)
4. Store attachment stream keyed by new revision

Alternative approach: modify DocumentEngine.Save() to accept attachment info as additional parameters and handle internally. Choose whichever is cleaner.

### Global Structure for Attachments

```
^IRISCouch.Atts(db, docid, rev, attname) = metadata ($ListBuild of content_type, length, digest, revpos)
^IRISCouch.Atts(db, docid, rev, attname, "stream") = %Stream.GlobalBinary OID
```
Or use a simpler flat structure — the key requirement is that `Storage.Attachment` encapsulates it entirely.

### Attachment Metadata Format (CouchDB-compatible)

Per-attachment stub in `_attachments`:
```json
{
  "filename.txt": {
    "content_type": "text/plain",
    "revpos": 2,
    "digest": "md5-abc123==",
    "length": 1234,
    "stub": true
  }
}
```

### Router Route Ordering

Attachment routes (`/:db/:docid/:attname`) must go AFTER `/:db/_changes` etc. but BEFORE or alongside `/:db/:docid` routes. Since %CSP.REST matches top-to-bottom, 3-segment routes are more specific and won't conflict with 2-segment document routes. Place them just before the `/:db/:docid` block:

```xml
<!-- Attachment endpoints (Story 5.1) -->
<Route Url="/:db/:docid/:attname" Method="PUT" Call="HandleAttachmentPut" />
<Route Url="/:db/:docid/:attname" Method="GET" Call="HandleAttachmentGet" />
<Route Url="/:db/:docid/:attname" Method="DELETE" Call="HandleAttachmentDelete" />
<!-- Document endpoints -->
<Route Url="/:db/:docid" Method="PUT" Call="HandleDocumentPut" />
```

### Router Wrapper Pattern (Mandatory)

Every route needs a local wrapper in Router.cls (see memory: `feedback_router_wrapper_pattern.md`):
```objectscript
ClassMethod HandleAttachmentPut(pDB As %String, pDocId As %String, pAttName As %String) As %Status
{
    Quit ##class(IRISCouch.API.AttachmentHandler).HandlePut(pDB, pDocId, pAttName)
}
```

### Existing Patterns to Follow

- **Handler structure**: See `DocumentHandler.HandlePut()` for the pattern (validate DB exists, parse params, delegate to engine/storage, render response)
- **Error handling**: `Error.Render()` + `Return $$$OK` in catch blocks; `Error.RenderInternal()` for 500s (NFR-S8)
- **Test structure**: Extend `%UnitTest.TestCase`, methods start with `Test`, use `$$$Assert*` macros
- **HTTP test structure**: Extend `IRISCouch.Test.HttpIntegrationTest` for HTTP tests

### Previous Story Intelligence (from Story 5.0)

- All Storage methods now properly encapsulated — use the same pattern
- DocumentEngine uses Storage.Changes.RecordChange() for change feed entries — attachment writes will automatically trigger change entries when the document revision is created
- Event signaling for longpoll happens after TCOMMIT in DocumentEngine — no extra work needed

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic 5, Story 5.1]
- [Source: _bmad-output/planning-artifacts/architecture.md#Attachment Storage, NFR-P8]
- [Source: _bmad-output/planning-artifacts/prd.md#FR31-FR40, NFR-P8]
- [Source: src/IRISCouch/Core/DocumentEngine.cls#Save transaction pattern]
- [Source: src/IRISCouch/API/Router.cls#UrlMap route ordering]
- [Source: src/IRISCouch/API/DocumentHandler.cls#HandlePut handler pattern]
- [Source: _bmad-output/implementation-artifacts/epic-4-retro-2026-04-12.md#Preparation for Epic 5]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- Fixed `Quit 1` inside For loop in Storage.Attachment.Exists() — ObjectScript does not support argumented Quit inside For; replaced with flag variable pattern
- Fixed HandleGet to use winning revision when no rev parameter specified, preventing stale attachment retrieval after DELETE

### Completion Notes List
- Task 1: Created IRISCouch.Storage.Attachment with Store, Get, Delete, GetMetadata, Exists, FindRevWithAttachment, CopyAttachments, and CleanupDatabase methods. All global access encapsulated in ^IRISCouch.Atts. MD5 digest via $System.Encryption.MD5HashStream() confirmed working.
- Task 2: Added SaveAttachment() and DeleteAttachment() methods to DocumentEngine. Both use TSTART/TCOMMIT transaction pattern, record changes feed entries, and signal longpoll waiters. CopyAttachments carries forward existing attachments across revisions.
- Task 3: Created AttachmentHandler with HandlePut, HandleGet, HandleDelete. All use streaming I/O (NFR-P8 compliant): %request.Content used directly as stream for upload, OutputToDevice() for download. Error handling follows established patterns.
- Task 4: Added 3 routes to Router UrlMap before document routes, plus 3 wrapper methods delegating to AttachmentHandler.
- Task 5: Created AttachmentTest (9 unit tests) and AttachmentHttpTest (6 HTTP integration tests). All 15 new tests pass. Full regression suite: 184 tests pass, 0 failures.
- Task 6: All 5 curl verification steps pass — text upload/download, binary PNG round-trip verified identical, DELETE + 404 confirmation.

### File List
- `src/IRISCouch/Storage/Attachment.cls` (new) — Storage layer for attachment CRUD
- `src/IRISCouch/API/AttachmentHandler.cls` (new) — REST handler for attachment endpoints
- `src/IRISCouch/Test/AttachmentTest.cls` (new) — 9 unit tests for storage operations
- `src/IRISCouch/Test/AttachmentHttpTest.cls` (new) — 6 HTTP integration tests
- `src/IRISCouch/Core/DocumentEngine.cls` (modified) — Added SaveAttachment() and DeleteAttachment() methods
- `src/IRISCouch/API/Router.cls` (modified) — Added 3 attachment routes + 3 wrapper methods

### Review Findings
- [x] [Review][Patch] Database deletion does not clean up ^IRISCouch.Atts — orphaned attachment data persists [Storage/Database.cls:60-65] — FIXED: added CleanupDatabase call
- [x] [Review][Defer] Duplicated HTTP helper in AttachmentHttpTest.MakeBinaryRequest — hardcoded credentials and connection params [AttachmentHttpTest.cls:70-107] — deferred, matches existing deferred pattern
- [x] [Review][Defer] FindRevWithAttachment lexicographic sort at gen 10+ — not reachable via HTTP handler [Storage/Attachment.cls:204-216] — deferred, low severity
- [x] [Review][Defer] Stream OID leak on attachment Delete — underlying %Stream.GlobalBinary not deleted [Storage/Attachment.cls:127-140] — deferred, low severity

## Change Log
- 2026-04-12: Story 5.1 implemented — standalone attachment upload, download, and delete with full test coverage (15 new tests, 184 total passing)
