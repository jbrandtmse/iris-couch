# Story 5.3: Attachment Retrieval Options & Multipart Response

Status: done

## Story

As a client,
I want to control how attachments are included in document responses (stubs, full content, conditional by revision, multipart/mixed),
so that I can optimize bandwidth and retrieve only the attachment data I need.

## Acceptance Criteria

1. Default `?attachments=false` (or omitted): GET `/{db}/{docid}` returns `_attachments` with stubs only (content_type, length, digest, revpos, stub:true) — no binary data
2. `?attachments=true`: GET `/{db}/{docid}?attachments=true` includes base64-encoded `data` field for each attachment in `_attachments`
3. `?atts_since=["2-abc"]`: only attachments added/modified after the listed revisions include full content; unchanged attachments return as stubs
4. `Accept: multipart/mixed` with `?open_revs=all`: response is multipart/mixed MIME with each revision as a JSON part followed by its attachment binary parts, with correct MIME boundaries and Content-Type headers
5. All existing 197 tests pass with zero regressions
6. New unit and HTTP integration tests cover all 4 retrieval modes

## Tasks / Subtasks

- [x] Task 1: Add `_attachments` stubs to document GET response (AC: #1)
  - [x] 1.1 In `DocumentHandler.HandleGet()`, after building response object, call `Storage.Attachment.GetMetadata(pDB, pDocId, tRev)` to get attachment stubs
  - [x] 1.2 If metadata is non-empty, set `_attachments` on the response object
  - [x] 1.3 Also add `_attachments` stubs in the `open_revs` response path (each revision in the array)
  - [x] 1.4 Compile and verify existing tests pass

- [x] Task 2: Support `?attachments=true` for full content inclusion (AC: #2)
  - [x] 2.1 Check `%request.Data("attachments", 1)` — if `"true"`, include base64-encoded attachment data
  - [x] 2.2 For each attachment in metadata, call `Storage.Attachment.Get()` to retrieve the stream
  - [x] 2.3 Read stream, base64-encode via `$System.Encryption.Base64Encode()`, set `"data"` field on attachment object
  - [x] 2.4 Remove `"stub":true` when `"data"` is present (CouchDB convention)
  - [x] 2.5 Compile and verify

- [x] Task 3: Support `?atts_since=["rev1","rev2"]` conditional retrieval (AC: #3)
  - [x] 3.1 Parse `atts_since` query parameter as JSON array of revision strings
  - [x] 3.2 Extract generation number from each revision (e.g., `"2-abc"` → generation 2)
  - [x] 3.3 Find the maximum generation across all atts_since revisions
  - [x] 3.4 For each attachment: if `revpos > maxGeneration`, include full base64 data; otherwise return as stub
  - [x] 3.5 Compile and verify

- [x] Task 4: Support `Accept: multipart/mixed` with `open_revs` (AC: #4)
  - [x] 4.1 In `DocumentHandler.HandleGet()`, when `open_revs` is specified, check `%request.GetCgiEnv("HTTP_ACCEPT")` for `multipart/mixed`
  - [x] 4.2 When multipart/mixed requested, generate MIME response instead of JSON array:
    - Generate unique MIME boundary string
    - Set `%response.ContentType = "multipart/mixed; boundary=" _ tBoundary`
    - For each revision: write boundary, write `Content-Type: application/json`, write JSON body
    - For each attachment on that revision: write boundary, write Content-Type + Content-Disposition, stream binary content
    - Write closing boundary
  - [x] 4.3 Write directly to `%response` output stream — do NOT buffer entire response
  - [x] 4.4 Compile and verify

- [x] Task 5: Unit tests (AC: #5, #6)
  - [x] 5.1 Create `src/IRISCouch/Test/AttachmentRetrievalTest.cls`:
    - GetMetadata returns correct stubs for document with attachments
    - Base64 encoding of attachment content matches original data
    - atts_since filtering: newer attachment gets data, older gets stub
  - [x] 5.2 Create `src/IRISCouch/Test/AttachmentRetrievalHttpTest.cls`:
    - GET document with attachment returns `_attachments` stubs by default
    - GET with `?attachments=true` returns base64 data
    - GET with `?atts_since=["old-rev"]` returns new attachment as data, old as stub
    - GET with `Accept: multipart/mixed` and `?open_revs=all` returns valid multipart response
    - Multipart response has correct boundaries and Content-Type headers
  - [x] 5.3 Run full test suite — confirm 197+ tests pass, 0 regressions

### Review Findings

- [x] [Review][Patch] Inconsistent property access `tStub.stub` vs `tStub.%Get("stub")` in test [AttachmentRetrievalHttpTest.cls:69] — fixed, changed to %Get() for consistency
- [x] [Review][Defer] Attachment buffering in base64 paths (`?attachments=true`, `?atts_since`) reads entire stream into memory — deferred, spec-acknowledged CouchDB design limitation
- [x] [Review][Defer] Multipart boundary generated from Base64Encode may contain MIME-special characters (+, /, =) — deferred, low risk since boundary is quoted in Content-Type header
- [x] [Review][Defer] Invalid `?atts_since` JSON silently falls back to stubs instead of returning 400 — deferred, defensive behavior acceptable for alpha
- [x] [Review][Defer] No `?attachments=true` support for open_revs JSON response path — deferred, not in AC and rarely used in CouchDB clients
- [x] [Review][Defer] No multipart test with multiple conflicting revisions — deferred, test coverage expansion item

## Dev Notes

### Architecture Overview

Story 5.3 modifies the document retrieval path (`DocumentHandler.HandleGet()`) to support 4 attachment inclusion modes. The primary changes are all in the response generation — no writes or storage changes needed.

### Files to Create

| File | Class | Purpose |
|------|-------|---------|
| `src/IRISCouch/Test/AttachmentRetrievalTest.cls` | `IRISCouch.Test.AttachmentRetrievalTest` | Unit tests for retrieval options |
| `src/IRISCouch/Test/AttachmentRetrievalHttpTest.cls` | `IRISCouch.Test.AttachmentRetrievalHttpTest` | HTTP integration tests |

### Files to Modify

| File | Changes |
|------|---------|
| `src/IRISCouch/API/DocumentHandler.cls` | Extend HandleGet for `_attachments` stubs, `?attachments=true`, `?atts_since`, and `Accept: multipart/mixed` |

### Critical: HandleGet Extension Points

The current HandleGet method at lines 405-528 has two paths:
1. **open_revs path** (lines 414-462): Returns array of revisions — add `_attachments` to each, add multipart/mixed option
2. **single document path** (lines 464-528): Returns single document — add `_attachments` stubs/content based on query params

**Extension for single document path (after line 520):**
```objectscript
; Get attachment metadata
Set tAttMeta = ##class(IRISCouch.Storage.Attachment).GetMetadata(pDB, pDocId, tRev)
If $IsObject(tAttMeta) && (tAttMeta.%Size() > 0) {
    ; Check attachments=true
    If $Get(%request.Data("attachments", 1)) = "true" {
        ; Include full base64 content for each attachment
        ; ... iterate and encode
    }
    ; Check atts_since
    ElseIf $Data(%request.Data("atts_since", 1)) {
        ; Conditional inclusion based on revpos
        ; ... parse array, compare generations
    }
    Do tRespObj.%Set("_attachments", tAttMeta)
}
```

### Critical: Base64 Encoding for attachments=true

```objectscript
; For each attachment in metadata:
Set tIter = tAttMeta.%GetIterator()
While tIter.%GetNext(.tAttName, .tAttStub) {
    Set tSC = ##class(IRISCouch.Storage.Attachment).Get(pDB, pDocId, tAttName, .tStream, .tCT, .tLen, .tDig, tRev)
    If $$$ISOK(tSC) && $IsObject(tStream) {
        ; Read stream and base64 encode
        Do tStream.Rewind()
        Set tBinary = tStream.Read()
        Set tB64 = $System.Encryption.Base64Encode(tBinary)
        Do tAttStub.%Set("data", tB64)
        Do tAttStub.%Remove("stub")
    }
}
```
**Note**: For very large attachments, this buffers the full content. Acceptable for `?attachments=true` (CouchDB behavior), but document the limitation. CouchDB recommends standalone GET for large attachments.

### Critical: atts_since Logic

CouchDB's `atts_since` parameter compares attachment `revpos` against the generations in the provided revision list:
```objectscript
; Parse atts_since JSON array
Set tAttsSince = ##class(%DynamicArray).%FromJSON(tAttsSinceParam)
; Find max generation
Set tMaxGen = 0
For tI = 0:1:(tAttsSince.%Size()-1) {
    Set tSinceRev = tAttsSince.%Get(tI)
    Set tGen = +$Piece(tSinceRev, "-", 1)
    If tGen > tMaxGen Set tMaxGen = tGen
}
; For each attachment: if revpos > tMaxGen, include data; else stub
```

### Critical: Multipart/Mixed MIME Format

CouchDB multipart/mixed format for `open_revs`:
```
Content-Type: multipart/mixed; boundary=abc123

--abc123
Content-Type: application/json

{"_id":"doc1","_rev":"2-def","field":"value","_attachments":{"file.txt":{"content_type":"text/plain","follows":true,"length":5,"digest":"md5-xxx"}}}
--abc123
Content-Type: text/plain
Content-Disposition: attachment; filename="file.txt"

hello
--abc123
Content-Type: application/json

{"_id":"doc1","_rev":"1-abc","field":"old"}
--abc123--
```

**Key rules:**
- Each revision is a JSON part followed by its attachment binary parts
- Attachment stubs in the JSON use `"follows":true` instead of `"stub":true` or `"data":"..."`
- Binary parts follow their owning revision's JSON part
- `Content-Disposition: attachment; filename="<attname>"` identifies the binary part
- Final boundary has `--` suffix

### Writing Multipart Response Directly

Do NOT use `Response.JSON()` — write directly to output:
```objectscript
Set %response.ContentType = "multipart/mixed; boundary=" _ tBoundary
Set %response.Status = "200 OK"
; Write each part directly
Write "--" _ tBoundary _ $Char(13,10)
Write "Content-Type: application/json" _ $Char(13,10)
Write $Char(13,10)  ; blank line
Write tJsonBody _ $Char(13,10)
; ... attachment parts ...
Write "--" _ tBoundary _ "--" _ $Char(13,10)
```

### Existing Storage.Attachment.GetMetadata Pattern

Already returns CouchDB-compatible stubs. From Story 5.1:
```json
{
  "file.txt": {
    "content_type": "text/plain",
    "revpos": 2,
    "digest": "md5-abc123==",
    "length": 1234,
    "stub": true
  }
}
```

### Previous Story Intelligence

- `%request.MimeData` used for multipart/related input (5.2) — do NOT use for output
- `$System.Encryption.Base64Encode()` and `Base64Decode()` confirmed working
- `Storage.Attachment.Get()` returns stream + metadata — reuse for content inclusion
- Handler error pattern: `Error.Render()` + `Return $$$OK`; `RenderInternal()` for 500s
- Test count: 197 passing

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic 5, Story 5.3]
- [Source: _bmad-output/planning-artifacts/prd.md#FR35-FR38]
- [Source: _bmad-output/planning-artifacts/architecture.md#Multipart/mixed response, MIMEWriter]
- [Source: src/IRISCouch/API/DocumentHandler.cls#HandleGet]
- [Source: src/IRISCouch/Storage/Attachment.cls#GetMetadata, Get]
- [Source: src/IRISCouch/API/AttachmentHandler.cls#HandleGet streaming pattern]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

None needed — all tasks compiled and tested on first pass.

### Completion Notes List

- Task 1: Extended DocumentHandler.HandleGet() to call Storage.Attachment.GetMetadata() and include _attachments stubs in both single-document and open_revs JSON response paths.
- Task 2: Added ?attachments=true support — iterates attachment metadata, retrieves streams, base64-encodes via $System.Encryption.Base64Encode(), sets "data" field and removes "stub" per CouchDB convention.
- Task 3: Added ?atts_since support — parses JSON array of revision strings, extracts max generation, conditionally includes base64 data only for attachments with revpos > maxGeneration.
- Task 4: Added Accept: multipart/mixed support for open_revs — generates MIME response with boundary, writes JSON parts with "follows":true attachment stubs, followed by binary attachment parts with Content-Disposition headers. Streams directly to response output.
- Task 5: Created 5 unit tests (AttachmentRetrievalTest) and 6 HTTP integration tests (AttachmentRetrievalHttpTest). All 11 new tests pass. Full suite passes with 0 regressions.

### Change Log

- 2026-04-12: Implemented all 4 attachment retrieval modes (stubs, attachments=true, atts_since, multipart/mixed) in DocumentHandler.HandleGet(). Created unit and HTTP integration test classes. All tests pass.

### File List

- src/IRISCouch/API/DocumentHandler.cls (modified)
- src/IRISCouch/Test/AttachmentRetrievalTest.cls (created)
- src/IRISCouch/Test/AttachmentRetrievalHttpTest.cls (created)
