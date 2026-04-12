# Story 3.1: Single Document Create & Read

Status: done

## Story

As a client,
I want to create documents via `POST /{db}` and `PUT /{db}/{docid}` and retrieve them via `GET /{db}/{docid}`,
so that I can store and access JSON data in the database.

## Acceptance Criteria

1. **Given** an existing database `{db}`, **When** the client sends `POST /iris-couch/{db}` with a JSON body, **Then** the response status is 201 Created with `{"ok":true,"id":"<server-generated-uuid>","rev":"1-<hash>"}`, the document body is stored in `^IRISCouch.Docs(db, docId, rev)` as raw JSON, and the revision tree is initialized in `^IRISCouch.Tree` with a single leaf node.

2. **Given** an existing database `{db}`, **When** the client sends `PUT /iris-couch/{db}/{docid}` with a JSON body and no `_rev` field, **Then** the response status is 201 Created, the document is stored with the client-specified `{docid}`, and the initial revision is `1-<deterministic-hash>`.

3. **Given** a document `{docid}` exists in database `{db}`, **When** the client sends `GET /iris-couch/{db}/{docid}`, **Then** the response status is 200 OK and the response body contains the document JSON with `_id` and `_rev` fields.

4. **Given** a document `{docid}` exists with multiple revisions, **When** the client sends `GET /iris-couch/{db}/{docid}?rev=N-hex`, **Then** the response returns the specific revision requested. If the revision does not exist, the response is 404.

5. **Given** the `DocumentEngine.Save()` classmethod is the single write orchestrator, **When** a document is written, **Then** the write is wrapped in `TSTART`/`TCOMMIT` ensuring atomicity (NFR-R2).

6. **Given** all changes are compiled and tested, **Then** all existing 49 tests pass with zero regressions, and new tests cover all acceptance criteria.

## Tasks / Subtasks

- [x] Task 1: Create `IRISCouch.Storage.Document` class (AC: #1, #2, #3, #4)
  - [x] 1.1: Create `src/IRISCouch/Storage/Document.cls` extending `%RegisteredObject`
  - [x] 1.2: Implement `ClassMethod Write(pDB As %String, pDocId As %String, pRev As %String, pBody As %String) As %Status` — sets `^IRISCouch.Docs(pDB, pDocId, pRev) = pBody`
  - [x] 1.3: Implement `ClassMethod Read(pDB As %String, pDocId As %String, pRev As %String) As %String` — returns `$Get(^IRISCouch.Docs(pDB, pDocId, pRev))`, empty string if not found
  - [x] 1.4: Implement `ClassMethod Exists(pDB As %String, pDocId As %String) As %Boolean` — returns `$Data(^IRISCouch.Docs(pDB, pDocId))>0`
  - [x] 1.5: Compile and verify no errors

- [x] Task 2: Create `IRISCouch.Storage.RevTree` class (AC: #1, #2)
  - [x] 2.1: Create `src/IRISCouch/Storage/RevTree.cls` extending `%RegisteredObject`
  - [x] 2.2: Implement `ClassMethod Init(pDB As %String, pDocId As %String, pRev As %String) As %Status` — initialize a new revision tree for a new document:
    - Set `^IRISCouch.Tree(pDB, pDocId, "R", pRev) = ""` (no parent)
    - Set `^IRISCouch.Tree(pDB, pDocId, "L", pRev) = 1` (leaf at depth 1)
    - Set `^IRISCouch.Tree(pDB, pDocId, "W") = pRev` (winner)
  - [x] 2.3: Implement `ClassMethod AddChild(pDB As %String, pDocId As %String, pParentRev As %String, pChildRev As %String) As %Status` — add a child revision to an existing tree:
    - Set `^IRISCouch.Tree(pDB, pDocId, "R", pChildRev) = pParentRev`
    - Get parent depth from `^IRISCouch.Tree(pDB, pDocId, "L", pParentRev)`
    - Kill old leaf: `Kill ^IRISCouch.Tree(pDB, pDocId, "L", pParentRev)`
    - Set `^IRISCouch.Tree(pDB, pDocId, "L", pChildRev) = parentDepth + 1`
    - Call `..RecomputeWinner(pDB, pDocId)` to update "W" node
  - [x] 2.4: Implement `ClassMethod GetWinner(pDB As %String, pDocId As %String) As %String` — returns `$Get(^IRISCouch.Tree(pDB, pDocId, "W"))`
  - [x] 2.5: Implement `ClassMethod RecomputeWinner(pDB As %String, pDocId As %String) As %Status` — iterate all "L" leaf nodes, select winner by: (1) live beats deleted, (2) highest depth, (3) lexicographic rev hash. Set "W" node. For Story 3.1, no deleted leafs exist yet, so just pick highest depth then lex tiebreak.
  - [x] 2.6: Compile and verify no errors

- [x] Task 3: Create `IRISCouch.Core.RevHash` class (AC: #1, #2)
  - [x] 3.1: Create `src/IRISCouch/Core/RevHash.cls` extending `%RegisteredObject`
  - [x] 3.2: Implement `ClassMethod Generate(pBody As %String, pParentRev As %String = "", pDeleted As %Boolean = 0) As %String` — generates a revision hash:
    - Canonicalize JSON body: parse with `%DynamicObject.%FromJSON()`, remove `_id`, `_rev`, `_revisions`, `_deleted` metadata fields, then serialize back with `%ToJSON()` (keys sorted by %DynamicObject default behavior)
    - Compute: `Set tInput = canonicalBody _ pParentRev _ pDeleted`
    - Hash: `Set tHash = $System.Encryption.MD5HashString(tInput)`
    - Convert to lowercase hex: `Set tHex = $ZConvert($System.Encryption.Base64Encode(tHash),"L")` — NO, use `##class(%xsd.hexBinary).LogicalToDisplay(tHash)` and $ZConvert to lowercase
    - Return 32-char lowercase hex string
  - [x] 3.3: Implement `ClassMethod MintRev(pGeneration As %Integer, pBody As %String, pParentRev As %String = "", pDeleted As %Boolean = 0) As %String` — returns `pGeneration _ "-" _ ..Generate(pBody, pParentRev, pDeleted)`
  - [x] 3.4: Compile and verify no errors

- [x] Task 4: Create `IRISCouch.Core.DocumentEngine` class (AC: #1, #2, #5)
  - [x] 4.1: Create `src/IRISCouch/Core/DocumentEngine.cls` extending `%RegisteredObject`
  - [x] 4.2: Implement `ClassMethod Save(pDB As %String, pDocId As %String, pBody As %String, pParentRev As %String = "") As %String` — the single write orchestrator. Returns the new revision string on success, empty string on failure.
    - Validate database exists (return empty if not)
    - Determine generation: if pParentRev="", generation=1; else parse generation from pParentRev and add 1
    - Mint new revision: `##class(IRISCouch.Core.RevHash).MintRev(generation, pBody, pParentRev)`
    - `TSTART`
    - Write doc body: `##class(IRISCouch.Storage.Document).Write(pDB, pDocId, newRev, pBody)`
    - Update rev tree: if generation=1, `##class(IRISCouch.Storage.RevTree).Init(pDB, pDocId, newRev)`; else `##class(IRISCouch.Storage.RevTree).AddChild(pDB, pDocId, pParentRev, newRev)`
    - Record change: `$Increment(^IRISCouch.Seq(pDB))` and `Set ^IRISCouch.Changes(pDB, seq) = $ListBuild(pDocId, newRev)`
    - Update db metadata: `$Increment(^IRISCouch.DB(pDB, "doc_count"))` (only for new docs, generation=1), `Set ^IRISCouch.DB(pDB, "update_seq") = seq`
    - `TCOMMIT`
    - Return newRev
  - [x] 4.3: Wrap TSTART/TCOMMIT in try/catch with TROLLBACK on error
  - [x] 4.4: Compile and verify no errors

- [x] Task 5: Create `IRISCouch.API.DocumentHandler` class (AC: #1, #2, #3, #4)
  - [x] 5.1: Create `src/IRISCouch/API/DocumentHandler.cls` extending `%RegisteredObject`
  - [x] 5.2: Implement `ClassMethod HandlePost(pDB As %String) As %Status` — `POST /{db}` (create with server-generated ID):
    - Check database exists (404 if not)
    - Read JSON body via `Request.ReadBody()`
    - Generate UUID: `##class(IRISCouch.Util.UUID).Generate()`
    - Strip `_id` from body if present (POST ignores client _id); use the UUID
    - Call `DocumentEngine.Save(pDB, docId, body.%ToJSON())` — pass raw JSON string
    - Return 201 with `{"ok":true, "id":"...", "rev":"..."}`
  - [x] 5.3: Implement `ClassMethod HandlePut(pDB As %String, pDocId As %String) As %Status` — `PUT /{db}/{docid}` (create/update with client-specified ID):
    - Check database exists (404 if not)
    - Read JSON body
    - Extract `_rev` from body (if present) or from `?rev=` query param
    - If document exists AND no `_rev` provided → 409 Conflict
    - If `_rev` provided, verify it matches current winner rev → 409 if stale (this is Story 3.2 territory, but for 3.1 we need to handle the no-_rev new doc case)
    - For Story 3.1: only handle the **create** case (no `_rev`, doc doesn't exist)
    - Call `DocumentEngine.Save(pDB, pDocId, body.%ToJSON())`
    - Return 201 with `{"ok":true, "id":"...", "rev":"..."}`
  - [x] 5.4: Implement `ClassMethod HandleGet(pDB As %String, pDocId As %String) As %Status` — `GET /{db}/{docid}`:
    - Check database exists (404 if not)
    - Read `rev` query parameter: `$Get(%request.Data("rev", 1))`
    - If rev specified, read that specific revision; if not found → 404
    - If no rev, get winning rev from `RevTree.GetWinner(pDB, pDocId)` — if no winner → 404
    - Read document body from `Storage.Document.Read(pDB, pDocId, rev)`
    - Parse body, inject `_id` and `_rev` into response
    - Return 200 with document JSON
  - [x] 5.5: Use `RenderInternal()` in all catch blocks with subsystem "document: ..." reason
  - [x] 5.6: Compile and verify no errors

- [x] Task 6: Add routes to Router (AC: #1, #2, #3, #4)
  - [x] 6.1: Add `<Route Url="/:db" Method="POST" Call="HandleDocumentPost" />` — AFTER the `/:db/_xxx` sub-resource routes but BEFORE `/:db` PUT/DELETE/GET
  - [x] 6.2: Add `<Route Url="/:db/:docid" Method="PUT" Call="HandleDocumentPut" />` — AFTER `/:db` routes
  - [x] 6.3: Add `<Route Url="/:db/:docid" Method="GET" Call="HandleDocumentGet" />` — AFTER `/:db` routes
  - [x] 6.4: Create local wrapper methods: `HandleDocumentPost(pDB)`, `HandleDocumentPut(pDB, pDocId)`, `HandleDocumentGet(pDB, pDocId)` — each delegating to `DocumentHandler`
  - [x] 6.5: Compile and verify no errors

- [x] Task 7: Create unit tests (AC: #1, #2, #3, #4, #5)
  - [x] 7.1: Create `src/IRISCouch/Test/DocumentTest.cls` extending `%UnitTest.TestCase`
  - [x] 7.2: `TestRevHashGenerate` — verify `RevHash.Generate()` returns 32-char lowercase hex
  - [x] 7.3: `TestRevHashDeterministic` — same body + parent → same hash; different body → different hash
  - [x] 7.4: `TestMintRev` — verify format is `N-<hash>` (e.g., `1-abc123...`)
  - [x] 7.5: `TestDocumentWrite` — write doc body, read it back, verify identical
  - [x] 7.6: `TestDocumentExists` — write doc, verify Exists returns 1; non-existent returns 0
  - [x] 7.7: `TestRevTreeInit` — init tree, verify winner, leaf node, R node all correct
  - [x] 7.8: `TestDocumentEngineSave` — save a new doc, verify body in global, rev tree initialized, doc_count incremented, update_seq set, changes feed entry written
  - [x] 7.9: `TestDocumentEngineSaveTransaction` — verify all changes are atomic (check that all globals are set after save)
  - [x] 7.10: `OnBeforeOneTest` — create fresh test db; `OnAfterOneTest` — kill all `^IRISCouch.*("testdocdb_*")` globals

- [x] Task 8: Create HTTP integration tests (AC: #1, #2, #3, #4)
  - [x] 8.1: Create `src/IRISCouch/Test/DocumentHttpTest.cls` extending `%UnitTest.TestCase`
  - [x] 8.2: `TestPostDocument` — `POST /{db}` with JSON body → 201, response has ok/id/rev, GET by returned id → 200
  - [x] 8.3: `TestPutNewDocument` — `PUT /{db}/mydoc` with JSON body (no _rev) → 201, response has ok/id/rev
  - [x] 8.4: `TestGetDocument` — create doc, then `GET /{db}/{docid}` → 200 with _id and _rev and body fields
  - [x] 8.5: `TestGetDocumentSpecificRev` — create doc, `GET /{db}/{docid}?rev=1-<hash>` → 200 with that rev
  - [x] 8.6: `TestGetDocumentNotFound` — `GET /{db}/nonexistent` → 404 not_found
  - [x] 8.7: `TestGetDocumentMissingRev` — `GET /{db}/{docid}?rev=99-bad` → 404
  - [x] 8.8: `TestPostDocumentNoDb` — `POST /nonexistent_db` → 404
  - [x] 8.9: `OnBeforeOneTest` — create test db; `OnAfterOneTest` — delete test db and kill globals

- [x] Task 9: Run full test suite (AC: #6)
  - [x] 9.1: All existing 49 tests pass (zero regressions)
  - [x] 9.2: All new unit and HTTP tests pass

### Review Findings

- [x] [Review][Patch] TROLLBACK without active transaction in DocumentEngine.Save() catch block [DocumentEngine.cls:80] -- Fixed: added tInTrans guard flag
- [x] [Review][Patch] Invalid JSON body returns 500 instead of 400 in HandlePost/HandlePut [DocumentHandler.cls:35,88] -- Fixed: added nested try/catch around %FromJSON with 400 bad_request
- [x] [Review][Defer] RevTree.AddChild does not verify parent revision exists in leaf index [RevTree.cls:55] -- deferred, not reachable in Story 3.1 (create-only path uses Init)
- [x] [Review][Defer] No underscore-prefix validation on document IDs in HandlePut [DocumentHandler.cls:74] -- deferred, system doc ID validation is Epic 5+ territory

## Dev Notes

### Architecture: DocumentEngine as Single Write Orchestrator

Per architecture decision, `IRISCouch.Core.DocumentEngine.Save()` is the **only** method that writes documents. It wraps all subsystem calls in a single `TSTART`/`TCOMMIT`:

```
DocumentEngine.Save(db, docId, body, parentRev)
  TSTART
  1. Storage.Document.Write(db, docId, newRev, body)
  2. Storage.RevTree.Init/AddChild(db, docId, rev)
  3. $Increment(^IRISCouch.Seq(db)) → write ^IRISCouch.Changes(db, seq)
  4. Update ^IRISCouch.DB(db, "doc_count"), "update_seq"
  TCOMMIT
```

Steps 4-7 from the full architecture (Projection.UpdateWinners, Projection.UpdateMangoIndexes, Attachment.Store, Audit.EmitDocWrite) are **NOT implemented in Story 3.1**. They will be added in later epics. Document them as TODO comments in DocumentEngine.Save().

### Global Structure (Pattern 3: Storage Encapsulation)

| Storage Class | Global | Purpose |
|---|---|---|
| `Storage.Document` | `^IRISCouch.Docs(db, docId, rev)` | Raw JSON document body |
| `Storage.RevTree` | `^IRISCouch.Tree(db, docId, "R", rev)` | Child→parent pointers |
| `Storage.RevTree` | `^IRISCouch.Tree(db, docId, "L", rev)` | Leaf index with depth |
| `Storage.RevTree` | `^IRISCouch.Tree(db, docId, "W")` | Cached winning revision |
| (existing) `Storage.Database` | `^IRISCouch.DB(db, *)` | Database metadata |
| (existing) `Storage.Database` | `^IRISCouch.Seq(db)` | Sequence counter |
| (DocumentEngine directly) | `^IRISCouch.Changes(db, seq)` | Changes feed entries |

**Note on Changes**: The architecture specifies `IRISCouch.Storage.Changes` for changes feed access. For Story 3.1, the changes write is minimal (just one `Set` inside DocumentEngine's transaction). Create a `Storage.Changes` class or write directly — either is acceptable for 3.1 since the changes engine is Epic 4 territory. If writing directly, add a TODO comment.

### Revision Hash Algorithm

Per research doc B.6.1:
```
revId_new = MD5( canonicalJson(body_minus_rev) || parentRevId || deletedFlag || concat(attachment_digests) )
gen_new = gen_parent + 1
rev_new = gen_new _ "-" _ toHex(revId_new)
```

For Story 3.1 (no attachments, no deletion):
- Remove `_id`, `_rev`, `_revisions`, `_deleted` from body before hashing
- `tInput = canonicalBody _ parentRev _ "0"` (deleted=0)
- Hash with `$System.Encryption.MD5HashString(tInput)` — returns raw binary
- Convert to 32-char lowercase hex

**CRITICAL**: ObjectScript `$System.Encryption.MD5HashString()` returns raw binary bytes. To convert to hex, use:
```objectscript
Set tRawMD5 = $System.Encryption.MD5HashString(tInput)
Set tHex = ""
For tI = 1:1:$Length(tRawMD5) {
    Set tByte = $Ascii(tRawMD5, tI)
    Set tHex = tHex _ $Translate($Justify($ZHex(tByte), 2), " ", "0")
}
Set tHex = $ZConvert(tHex, "L")
```

### Canonical JSON for Hashing

Parse body with `%DynamicObject.%FromJSON()`, remove metadata fields (`_id`, `_rev`, `_revisions`, `_deleted`), then `%ToJSON()`. ObjectScript's `%DynamicObject` serializes keys in insertion order — for a canonical form, we should rely on this being consistent for the same input. For byte-compat with CouchDB (needed for `new_edits=false` in Story 3.5), the hash function must produce sorted keys. For Story 3.1, just removing metadata and using `%ToJSON()` is sufficient since we're not doing cross-system replication yet.

### Route Ordering (CRITICAL)

The new routes must be placed correctly:
```xml
<!-- Document sub-resource routes would go here in future stories -->
<!-- POST /:db for document creation - AFTER /:db/_xxx routes, BEFORE /:db PUT/DELETE/GET -->
<Route Url="/:db" Method="POST" Call="HandleDocumentPost" />
<!-- Existing database routes -->
<Route Url="/:db" Method="PUT" Call="HandleDatabaseCreate" />
<Route Url="/:db" Method="DELETE" Call="HandleDatabaseDelete" />
<Route Url="/:db" Method="GET" Call="HandleDatabaseInfo" />
<!-- Document endpoints (after database routes) -->
<Route Url="/:db/:docid" Method="PUT" Call="HandleDocumentPut" />
<Route Url="/:db/:docid" Method="GET" Call="HandleDocumentGet" />
```

`POST /:db` can go alongside the other `/:db` methods since `%CSP.REST` matches by both URL pattern and HTTP method. Place it near the other `/:db` routes.

`/:db/:docid` routes must be AFTER `/:db` to avoid matching database names as doc IDs.

### HandlePost Body Processing

When `POST /{db}` receives a document:
1. Parse body with `Request.ReadBody()`
2. If client sent `_id`, **ignore it** — POST always generates a server UUID
3. Remove `_id`, `_rev` from body before passing to DocumentEngine
4. DocumentEngine stores the raw JSON body (without metadata fields)
5. On read, `_id` and `_rev` are injected into the response

### HandleGet Response Construction

When building the GET response:
1. Read raw JSON body from `Storage.Document.Read()`
2. Parse with `%DynamicObject.%FromJSON()`
3. Set `_id` and `_rev` at the beginning: `Do tDoc.%Set("_id", pDocId)` then `Do tDoc.%Set("_rev", tRev)`
4. Return the complete JSON

**Note**: CouchDB returns `_id` and `_rev` as the first fields. ObjectScript `%DynamicObject` preserves insertion order, so set `_id`/`_rev` first, then copy other fields. Alternatively, store body without `_id`/`_rev` and inject them on read.

### doc_count Increment Logic

`doc_count` in `^IRISCouch.DB(db, "doc_count")` should only increment for **new documents** (generation=1), not for updates. For Story 3.1, all creates are generation=1, but the engine should already handle this correctly for Story 3.2.

### Changes Feed Entry

For the minimal changes feed entry in Story 3.1:
```objectscript
Set tSeq = $Increment(^IRISCouch.Seq(pDB))
Set ^IRISCouch.Changes(pDB, tSeq) = $ListBuild(pDocId, pNewRev)
Set ^IRISCouch.DB(pDB, "update_seq") = tSeq
```

This is sufficient for Story 3.1. The full changes feed engine (Epic 4) will read these entries.

### Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `src/IRISCouch/Storage/Document.cls` | **Create** | Document body storage (Write/Read/Exists) |
| `src/IRISCouch/Storage/RevTree.cls` | **Create** | Revision tree management (Init/AddChild/GetWinner/RecomputeWinner) |
| `src/IRISCouch/Core/RevHash.cls` | **Create** | Revision hash generation (Generate/MintRev) |
| `src/IRISCouch/Core/DocumentEngine.cls` | **Create** | Single write orchestrator with TSTART/TCOMMIT |
| `src/IRISCouch/API/DocumentHandler.cls` | **Create** | HTTP handlers for POST/PUT/GET document operations |
| `src/IRISCouch/API/Router.cls` | **Modify** | Add /:db POST and /:db/:docid GET/PUT routes + wrappers |
| `src/IRISCouch/Test/DocumentTest.cls` | **Create** | Unit tests for storage, rev tree, rev hash, engine |
| `src/IRISCouch/Test/DocumentHttpTest.cls` | **Create** | HTTP integration tests for document CRUD |

### Established Patterns to Follow

- **Handler catch blocks**: `RenderInternal()` then `Quit $$$OK` (feedback memory)
- **Storage encapsulation**: all `^IRISCouch.*` access in `Storage.*` classes (exception: `DocumentEngine` accesses `^IRISCouch.Changes` and `^IRISCouch.DB` for seq/count updates — acceptable per architecture since DocumentEngine is the orchestrator)
- **Error slugs**: use `##class(IRISCouch.Util.Error).#SLUG` constants
- **Response output**: use `Response.JSON()` or `Response.JSONStatus()` — never direct `Write`
- **Router wrappers**: every UrlMap route needs a local method delegating to handler class
- **Test cleanup**: `OnBeforeOneTest`/`OnAfterOneTest` for database creation/deletion

### Previous Story Intelligence (Story 3.0)

- 49 tests passing across 7 test classes
- `doc_del_count` now reads from global (no longer hardcoded)
- `disk_size` reads from global (ready for increment)
- Full database lifecycle test validates the complete DB workflow
- `MakeRequest()` helper supports GET/PUT/POST/DELETE with optional body

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.1] — Acceptance criteria
- [Source: _bmad-output/planning-artifacts/architecture.md:231-326] — Data architecture, transaction orchestration
- [Source: _bmad-output/planning-artifacts/research/technical-couchdb-on-iris-research-2026-04-10.md:784-798] — Rev hash algorithm
- [Source: src/IRISCouch/Storage/Database.cls] — Existing storage pattern reference
- [Source: src/IRISCouch/API/DatabaseHandler.cls] — Existing handler pattern reference
- [Source: src/IRISCouch/API/Router.cls] — Current route structure

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- Discovered `$System.Encryption.MD5HashString()` does not exist in this IRIS version; corrected to `$System.Encryption.MD5Hash()` which returns raw 16-byte binary as expected.

### Completion Notes List
- Implemented Storage.Document with Write/Read/Exists methods encapsulating ^IRISCouch.Docs global access
- Implemented Storage.RevTree with Init/AddChild/GetWinner/RecomputeWinner managing ^IRISCouch.Tree global
- Implemented Core.RevHash with Generate (MD5 hash to 32-char lowercase hex) and MintRev (generation-hash format)
- Implemented Core.DocumentEngine as single write orchestrator with TSTART/TCOMMIT atomicity, coordinating document storage, revision tree, changes feed, and metadata updates
- Implemented API.DocumentHandler with HandlePost (server-generated UUID), HandlePut (client-specified ID with 409 conflict check), and HandleGet (winning rev or specific rev with _id/_rev injection)
- Added 3 routes to Router (POST /:db, PUT /:db/:docid, GET /:db/:docid) with local wrapper methods
- Created 10 unit tests covering RevHash, Storage.Document, RevTree, DocumentEngine
- Created 7 HTTP integration tests covering POST/PUT/GET document operations and error cases
- Added bonus test TestRevHashStripsMetadata and TestDocumentEngineSaveNoDb for edge cases
- All 49 existing tests pass with zero regressions; 17 new tests all pass (total: 66)

### File List
- `src/IRISCouch/Storage/Document.cls` (created) - Document body storage layer
- `src/IRISCouch/Storage/RevTree.cls` (created) - Revision tree management layer
- `src/IRISCouch/Core/RevHash.cls` (created) - Revision hash generation
- `src/IRISCouch/Core/DocumentEngine.cls` (created) - Single write orchestrator with transaction support
- `src/IRISCouch/API/DocumentHandler.cls` (created) - HTTP handlers for POST/PUT/GET document operations
- `src/IRISCouch/API/Router.cls` (modified) - Added 3 document routes and 3 wrapper methods
- `src/IRISCouch/Test/DocumentTest.cls` (created) - 10 unit tests for document subsystem
- `src/IRISCouch/Test/DocumentHttpTest.cls` (created) - 7 HTTP integration tests for document endpoints

### Change Log
- 2026-04-12: Story 3.1 implementation complete - Single Document Create & Read with all ACs satisfied
