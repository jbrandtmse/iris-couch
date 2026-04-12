# Story 3.4: Bulk Document Operations

Status: done

## Story

As a client,
I want to submit multiple document writes in a single request and retrieve multiple documents by ID in bulk,
so that I can efficiently perform batch operations.

## Acceptance Criteria

1. **Given** an existing database `{db}`, **When** the client sends `POST /iris-couch/{db}/_bulk_docs` with `{"docs":[{...},{...}]}`, **Then** the response status is 201 Created and the response body is a JSON array with per-document results (`{"ok":true,"id":"...","rev":"..."}` or `{"error":"conflict","id":"...","reason":"..."}`), and each document write is processed through `DocumentEngine.Save()`.

2. **Given** documents exist in database `{db}`, **When** the client sends `POST /iris-couch/{db}/_bulk_get` with `{"docs":[{"id":"doc1"},{"id":"doc2","rev":"1-abc"}]}`, **Then** the response status is 200 OK and the response body contains `{"results":[{"id":"doc1","docs":[{"ok":{...}}]},{"id":"doc2","docs":[{"ok":{...}}]}]}`, with missing documents returning `{"error":{"id":"...","rev":"...","error":"not_found","reason":"missing"}}` in their docs entry.

3. **Given** a `_bulk_get` request includes `revs=true` query parameter, **When** the response is generated, **Then** each document includes its revision history in the `_revisions` field.

4. **Given** a `_bulk_docs` request contains documents with `_id` specified, **When** the documents are saved, **Then** each uses the client-specified ID. Documents without `_id` get a server-generated UUID.

5. **Given** a `_bulk_docs` request contains a document with a conflicting `_rev`, **When** the document is processed, **Then** that document returns `{"id":"...","error":"conflict","reason":"Document update conflict."}` and other documents in the batch still succeed.

6. **Given** all changes are compiled and tested, **Then** all existing 97 tests pass with zero regressions, and new tests cover all acceptance criteria.

## Tasks / Subtasks

- [x] Task 1: Add `_bulk_docs` and `_bulk_get` routes to Router (AC: #1, #2)
  - [x] 1.1: Add `<Route Url="/:db/_bulk_docs" Method="POST" Call="HandleBulkDocs" />` — BEFORE `/:db` routes, in the `/:db/_xxx` sub-resource block
  - [x] 1.2: Add `<Route Url="/:db/_bulk_get" Method="POST" Call="HandleBulkGet" />` — same location
  - [x] 1.3: Create local wrapper: `HandleBulkDocs(pDB)` delegating to `DocumentHandler.HandleBulkDocs(pDB)`
  - [x] 1.4: Create local wrapper: `HandleBulkGet(pDB)` delegating to `DocumentHandler.HandleBulkGet(pDB)`
  - [x] 1.5: Compile and verify

- [x] Task 2: Implement `HandleBulkDocs` in DocumentHandler (AC: #1, #4, #5)
  - [x] 2.1: Create `ClassMethod HandleBulkDocs(pDB As %String) As %Status`
  - [x] 2.2: Compile and verify

- [x] Task 3: Implement `HandleBulkGet` in DocumentHandler (AC: #2, #3)
  - [x] 3.1: Create `ClassMethod HandleBulkGet(pDB As %String) As %Status`
  - [x] 3.2: Compile and verify

- [x] Task 4: Create unit tests (AC: #1-#5)
  - [x] 4.1: Create `src/IRISCouch/Test/BulkOpsTest.cls` extending `%UnitTest.TestCase`
  - [x] 4.2: `TestBulkDocsCreate` — bulk create 3 docs, verify all return ok with id/rev
  - [x] 4.3: `TestBulkDocsWithId` — create docs with client-specified _id, verify IDs match
  - [x] 4.4: `TestBulkDocsConflict` — create doc, then bulk update with stale _rev → conflict error for that doc, other docs succeed
  - [x] 4.5: `TestBulkDocsDelete` — bulk create then bulk delete with _deleted:true

- [x] Task 5: Create HTTP integration tests (AC: #1-#5)
  - [x] 5.1: Create `src/IRISCouch/Test/BulkOpsHttpTest.cls` extending `%UnitTest.TestCase`
  - [x] 5.2: `TestBulkDocsHttp` — `POST /{db}/_bulk_docs` with 2 docs → 201, array of 2 results with ok
  - [x] 5.3: `TestBulkDocsConflictHttp` — create doc, bulk update with stale rev → result array has conflict error for that doc
  - [x] 5.4: `TestBulkGetHttp` — create 2 docs, `POST /{db}/_bulk_get` with both IDs → 200, results with both docs
  - [x] 5.5: `TestBulkGetMissingHttp` — `POST /{db}/_bulk_get` with non-existent ID → result has error entry
  - [x] 5.6: `TestBulkGetRevsHttp` — create doc, update, `POST /{db}/_bulk_get?revs=true` → result includes `_revisions`

- [x] Task 6: Run full test suite (AC: #6)
  - [x] 6.1: All existing 97 tests pass (zero regressions)
  - [x] 6.2: All new 9 tests pass (106 total)

## Dev Notes

### _bulk_docs Request/Response Format

**Request:**
```json
{
  "docs": [
    {"_id": "doc1", "name": "Alice"},
    {"_id": "doc2", "name": "Bob"},
    {"name": "Charlie"}
  ]
}
```

**Response (201):**
```json
[
  {"ok": true, "id": "doc1", "rev": "1-abc123..."},
  {"ok": true, "id": "doc2", "rev": "1-def456..."},
  {"ok": true, "id": "a1b2c3d4...", "rev": "1-ghi789..."}
]
```

### _bulk_docs Error Handling

Each document is processed independently. A conflict in one doc does NOT fail the entire batch. The response array has one entry per input doc, in the same order.

**Conflict entry:**
```json
{"id": "doc1", "error": "conflict", "reason": "Document update conflict."}
```

### _bulk_docs is NOT Atomic

Per CouchDB semantics, `_bulk_docs` with `new_edits=true` is NOT an all-or-nothing transaction. Each document is saved individually. Some can succeed while others fail. This is different from `new_edits=false` which is also non-atomic per CouchDB spec.

Each individual document write IS atomic (via DocumentEngine's TSTART/TCOMMIT), but the batch is not.

### _bulk_get Request/Response Format

**Request:**
```json
{
  "docs": [
    {"id": "doc1"},
    {"id": "doc2", "rev": "1-abc"},
    {"id": "nonexistent"}
  ]
}
```

**Response (200):**
```json
{
  "results": [
    {
      "id": "doc1",
      "docs": [{"ok": {"_id": "doc1", "_rev": "2-def", "name": "Alice"}}]
    },
    {
      "id": "doc2",
      "docs": [{"ok": {"_id": "doc2", "_rev": "1-abc", "name": "Bob"}}]
    },
    {
      "id": "nonexistent",
      "docs": [{"error": {"id": "nonexistent", "rev": "undefined", "error": "not_found", "reason": "missing"}}]
    }
  ]
}
```

### _bulk_get with revs=true

When `?revs=true` is passed as a query parameter, each document in the response includes `_revisions`:
```json
{
  "_id": "doc1",
  "_rev": "2-def",
  "_revisions": {"start": 2, "ids": ["def", "abc"]},
  "name": "Alice"
}
```

Use `RevTree.GetRevisions(pDB, docId, rev)` from Story 3.3.

### new_edits=false — Defer to Story 3.5

If the `_bulk_docs` body contains `"new_edits":false`, return 400 with `{"error":"bad_request","reason":"new_edits=false not yet implemented"}`. Story 3.5 will add this replication-format support.

### Route Ordering

`/_bulk_docs` and `/_bulk_get` are `/:db/_xxx` sub-resource routes — they MUST be placed BEFORE the `/:db` routes in the UrlMap, alongside `/_revs_limit`, `/_compact`, `/_ensure_full_commit`.

### HandleGet Deleted Doc Check

When building bulk_get responses, check `RevTree.IsDeleted()` for the winning revision. If deleted, return the error entry (same as regular GET returning 404 for deleted docs).

### Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `src/IRISCouch/API/Router.cls` | **Modify** | Add `_bulk_docs` and `_bulk_get` routes + wrappers |
| `src/IRISCouch/API/DocumentHandler.cls` | **Modify** | Add HandleBulkDocs and HandleBulkGet methods |
| `src/IRISCouch/Test/BulkOpsTest.cls` | **Create** | Unit tests for bulk operations |
| `src/IRISCouch/Test/BulkOpsHttpTest.cls` | **Create** | HTTP integration tests for bulk endpoints |

### Established Patterns

- Handler catch: `RenderInternal()` then `Quit $$$OK`
- Error slugs: `##class(IRISCouch.Util.Error).#CONFLICT`, `.#BADREQUEST`
- Response: `Response.JSONStatus(201, tArray)` for bulk_docs, `Response.JSON(tWrapper)` for bulk_get
- Router wrappers: local method delegating to handler class
- Test cleanup: `OnBeforeOneTest` kills globals, creates fresh db
- Body parsing: nested try/catch for `%FromJSON()` returning 400 on invalid JSON
- Underscore validation: `..ValidateFields(tBody)` before save

### Previous Story Intelligence (Story 3.3)

- 97 tests passing across 13 test classes
- RevTree has AddBranch, GetConflicts, GetRevisions, GetRevsInfo, GetLeafRevs, IsDeleted
- HandleGet supports conflicts, revs, revs_info, open_revs query params
- RecomputeWinner uses `]` operator for correct string tiebreaking
- DocumentEngine has Save and SaveDeleted with TSTART/TCOMMIT
- JSON parse validation in HandlePost/HandlePut (nested try/catch)

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.4] — Acceptance criteria
- [Source: _bmad-output/planning-artifacts/research/technical-couchdb-on-iris-research-2026-04-10.md:136-137] — _bulk_docs and _bulk_get endpoint specs
- [Source: _bmad-output/planning-artifacts/research/technical-couchdb-on-iris-research-2026-04-10.md:871-874] — _bulk_get response format
- [Source: src/IRISCouch/API/DocumentHandler.cls] — Existing handler patterns
- [Source: src/IRISCouch/Core/DocumentEngine.cls] — Save/SaveDeleted methods

### Review Findings

- [x] [Review][Patch] Missing test for new_edits=false rejection [BulkOpsHttpTest.cls] -- Added TestBulkDocsNewEditsFalseHttp (auto-resolved)
- [x] [Review][Defer] HandleBulkGet silently skips docs with empty id [DocumentHandler.cls:596] -- deferred, edge case not in AC
- [x] [Review][Defer] Repetitive error-entry construction in HandleBulkDocs [DocumentHandler.cls:433-530] -- deferred, code quality refactoring

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
No debug globals needed — all tests passed on first compile.

### Completion Notes List
- Implemented HandleBulkDocs: processes each doc independently, supports create/update/delete, returns per-doc ok/error results. Returns 400 for new_edits=false (deferred to Story 3.5).
- Implemented HandleBulkGet: retrieves multiple docs by ID, supports optional rev per doc, supports ?revs=true for revision history. Checks IsDeleted for tombstoned winning revisions.
- Added 2 routes to Router UrlMap in the /:db/_xxx sub-resource block before /:db routes.
- Created 4 unit tests and 6 HTTP integration tests covering all acceptance criteria.
- Full regression suite: 107 tests (97 existing + 10 new), all passing.

### Change Log
- 2026-04-12: Implemented Story 3.4 — Bulk Document Operations (_bulk_docs and _bulk_get endpoints)

### File List
- src/IRISCouch/API/Router.cls (modified — added 2 routes + 2 wrapper methods)
- src/IRISCouch/API/DocumentHandler.cls (modified — added HandleBulkDocs and HandleBulkGet methods)
- src/IRISCouch/Test/BulkOpsTest.cls (created — 4 unit tests)
- src/IRISCouch/Test/BulkOpsHttpTest.cls (created — 6 HTTP integration tests)
