# Story 3.6: All Documents View

Status: done

## Story

As a client,
I want to list all documents via `GET /{db}/_all_docs` with pagination and key-range filtering, and query by specific keys via `POST /{db}/_all_docs`,
so that I can browse and look up documents in a database.

## Acceptance Criteria

1. **Given** a database `{db}` contains documents, **When** the client sends `GET /iris-couch/{db}/_all_docs`, **Then** the response status is 200 OK and the response body contains `{"total_rows":N,"offset":0,"rows":[{"id":"...","key":"...","value":{"rev":"..."}}]}` with rows sorted by document ID ascending.

2. **Given** a database contains many documents, **When** the client sends `GET /iris-couch/{db}/_all_docs?limit=10&skip=20`, **Then** the response returns at most 10 rows starting from offset 20.

3. **Given** a database contains documents, **When** the client sends `GET /iris-couch/{db}/_all_docs?startkey="doc-a"&endkey="doc-m"`, **Then** the response returns only documents with IDs in the specified range.

4. **Given** a database contains documents, **When** the client sends `GET /iris-couch/{db}/_all_docs?include_docs=true`, **Then** each row includes a `doc` field containing the full document body with `_id` and `_rev`.

5. **Given** a database contains documents, **When** the client sends `POST /iris-couch/{db}/_all_docs` with `{"keys":["doc1","doc2","doc3"]}`, **Then** the response returns rows for the specified document IDs and missing documents return a row with `{"key":"doc3","error":"not_found"}`.

6. **Given** a document exists, **When** the client sends `GET /iris-couch/{db}/{docid}?local_seq=true`, **Then** the response includes the `_local_seq` field with the document's sequence number.

7. **Given** all changes are compiled and tested, **Then** all existing 112+ tests pass with zero regressions, and new tests cover all acceptance criteria.

## Tasks / Subtasks

- [x] Task 1: Add `_all_docs` routes to Router (AC: #1, #5)
  - [x] 1.1: Add `<Route Url="/:db/_all_docs" Method="GET" Call="HandleAllDocs" />` in the `/:db/_xxx` sub-resource block
  - [x] 1.2: Add `<Route Url="/:db/_all_docs" Method="POST" Call="HandleAllDocsPost" />` in the same block
  - [x] 1.3: Create local wrappers: `HandleAllDocs(pDB)` and `HandleAllDocsPost(pDB)` delegating to `DocumentHandler`
  - [x] 1.4: Compile and verify

- [x] Task 2: Create `DocumentHandler.HandleAllDocs` for GET (AC: #1, #2, #3, #4)
  - [x] 2.1: Create `ClassMethod HandleAllDocs(pDB As %String) As %Status`:
    - Check database exists (404 if not)
    - Parse query parameters: `limit`, `skip`, `startkey`, `endkey`, `include_docs`, `descending`, `inclusive_end`
    - `startkey`/`endkey` values may be JSON-encoded strings (with quotes) — strip outer quotes if present
    - Iterate `^IRISCouch.Docs(pDB)` using `$Order` to enumerate all document IDs
    - For each docId:
      - Get winning rev from `RevTree.GetWinner()`
      - Skip deleted documents (check `RevTree.IsDeleted()`)
      - Apply startkey/endkey filtering
      - Apply skip/limit pagination
    - Build response: `{"total_rows":N,"offset":skipCount,"rows":[...]}`
    - Each row: `{"id":"docId","key":"docId","value":{"rev":"winningRev"}}`
    - If `include_docs=true`, add `"doc":{...full doc with _id and _rev...}` to each row
    - `total_rows` = total number of non-deleted documents (not affected by limit/skip/key range)
    - `offset` = number of rows skipped
    - If `descending=true`, iterate in reverse order
  - [x] 2.2: Compile and verify

- [x] Task 3: Create `DocumentHandler.HandleAllDocsPost` for POST with keys (AC: #5)
  - [x] 3.1: Create `ClassMethod HandleAllDocsPost(pDB As %String) As %Status`:
    - Check database exists (404 if not)
    - Read and parse JSON body
    - Extract `keys` array from body
    - Parse query parameters same as GET (include_docs, etc.)
    - For each key in keys array:
      - Look up document by ID
      - If found and not deleted: add normal row
      - If not found or deleted: add error row `{"key":"docId","error":"not_found"}`
    - Build response same format as GET: `{"total_rows":N,"offset":0,"rows":[...]}`
    - `total_rows` = total non-deleted docs in db (same as GET)
  - [x] 3.2: Compile and verify

- [x] Task 4: Add `local_seq` support to HandleGet (AC: #6)
  - [x] 4.1: In `DocumentHandler.HandleGet`, check for `local_seq=true` query parameter
  - [x] 4.2: If present, find the document's sequence number by scanning `^IRISCouch.Changes(pDB)` for the latest entry matching this docId
  - [x] 4.3: Add `_local_seq` field to the response with the sequence number as a string
  - [x] 4.4: Compile and verify

- [x] Task 5: Create `Storage.Document.CountNonDeleted` helper (AC: #1)
  - [x] 5.1: Create `ClassMethod CountNonDeleted(pDB As %String) As %Integer` — returns the count of non-deleted documents. Can use `^IRISCouch.DB(pDB, "doc_count")` since doc_count is already maintained (incremented on create, decremented on delete).
  - [x] 5.2: Compile and verify

- [x] Task 6: Create unit tests (AC: #1-#6)
  - [x] 6.1: Create `src/IRISCouch/Test/AllDocsTest.cls` extending `%UnitTest.TestCase`
  - [x] 6.2: `TestAllDocsBasic` — create 3 docs, call internal _all_docs logic, verify 3 rows sorted by ID
  - [x] 6.3: `TestAllDocsSkipLimit` — create 5 docs, verify skip=2, limit=2 returns correct 2 rows
  - [x] 6.4: `TestAllDocsKeyRange` — create docs with IDs "aaa","bbb","ccc","ddd", verify startkey="bbb"&endkey="ccc" returns 2 rows
  - [x] 6.5: `TestAllDocsExcludesDeleted` — create doc, delete it, verify it doesn't appear in _all_docs

- [x] Task 7: Create HTTP integration tests (AC: #1-#6)
  - [x] 7.1: Create `src/IRISCouch/Test/AllDocsHttpTest.cls` extending `%UnitTest.TestCase`
  - [x] 7.2: `TestAllDocsGetHttp` — create 2 docs, `GET /_all_docs` → 200, total_rows=2, 2 rows with id/key/value.rev
  - [x] 7.3: `TestAllDocsLimitSkipHttp` — create 3 docs, `GET /_all_docs?limit=1&skip=1` → 1 row
  - [x] 7.4: `TestAllDocsIncludeDocsHttp` — create doc, `GET /_all_docs?include_docs=true` → row has `doc` field with full body
  - [x] 7.5: `TestAllDocsPostKeysHttp` — create 2 docs, `POST /_all_docs` with `{"keys":["doc1","nonexistent"]}` → 1 ok row, 1 error row
  - [x] 7.6: `TestAllDocsKeyRangeHttp` — create docs "aaa","bbb","ccc", `GET /_all_docs?startkey="aaa"&endkey="bbb"` → 2 rows
  - [x] 7.7: `TestLocalSeqHttp` — create doc, `GET /{db}/{docid}?local_seq=true` → response has `_local_seq`

- [x] Task 8: Run full test suite (AC: #7)
  - [x] 8.1: All existing 112+ tests pass (zero regressions)
  - [x] 8.2: All new tests pass

### Review Findings

- [x] [Review][Patch] HandleAllDocs and HandleAllDocsPost bypass CountNonDeleted, violating storage encapsulation [DocumentHandler.cls:780,932] -- AUTO-RESOLVED: replaced direct `^IRISCouch.DB(pDB, "doc_count")` access with `##class(IRISCouch.Storage.Document).CountNonDeleted(pDB)` calls
- [x] [Review][Defer] _local_seq field omitted when no changes entry found for document [DocumentHandler.cls:370] -- deferred, CouchDB always returns _local_seq when requested but current impl skips if empty; acceptable for alpha

## Dev Notes

### _all_docs Response Format

```json
{
  "total_rows": 3,
  "offset": 0,
  "rows": [
    {"id": "doc1", "key": "doc1", "value": {"rev": "1-abc"}},
    {"id": "doc2", "key": "doc2", "value": {"rev": "2-def"}},
    {"id": "doc3", "key": "doc3", "value": {"rev": "1-ghi"}}
  ]
}
```

- `id` and `key` are both the document ID (for `_all_docs`, key=id always)
- `value` contains `{"rev":"winningRev"}` only
- Rows sorted by `id` ascending (natural `$Order` on `^IRISCouch.Docs` gives this)
- Deleted documents are EXCLUDED from results

### Iterating Documents with $Order

`^IRISCouch.Docs(pDB)` has subscripts at the docId level. Use `$Order` to enumerate:
```objectscript
Set tDocId = ""
For {
    Set tDocId = $Order(^IRISCouch.Docs(pDB, tDocId))
    Quit:tDocId=""
    ; Get winning rev and check not deleted
    Set tWinRev = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, tDocId)
    If tWinRev = "" Continue
    If ##class(IRISCouch.Storage.RevTree).IsDeleted(pDB, tDocId, tWinRev) Continue
    ; Build row...
}
```

### startkey/endkey Filtering

CouchDB passes startkey and endkey as JSON-encoded values. For `_all_docs`, these are always strings. The query string may contain the value with or without quotes: `?startkey="doc-a"` or `?startkey=doc-a`.

Strip surrounding quotes from the query parameter value:
```objectscript
Set tStartKey = $Get(%request.Data("startkey", 1))
If $Extract(tStartKey, 1) = """" {
    Set tStartKey = $Extract(tStartKey, 2, $Length(tStartKey) - 1)
}
```

For filtering with `$Order`:
- If `startkey` provided, start `$Order` from `startkey` (using `$Order(^...(pDB, startkey), 1, startkey)` or just compare after iterating)
- If `endkey` provided, stop when `tDocId` exceeds `endkey`
- `inclusive_end` (default true) — if false, exclude exact `endkey` match
- `descending=true` — use `$Order(..., -1)` for reverse iteration; swap startkey/endkey semantics

### POST _all_docs with keys

The POST variant accepts `{"keys":["doc1","doc2",...]}`. Unlike GET, it returns results in the ORDER of the keys array (not sorted by ID). Missing documents get an error row:
```json
{"key": "nonexistent", "error": "not_found"}
```

### include_docs=true

When `include_docs=true`, each row gets a `doc` field containing the full document body with `_id` and `_rev` injected:
```json
{
  "id": "doc1",
  "key": "doc1",
  "value": {"rev": "1-abc"},
  "doc": {"_id": "doc1", "_rev": "1-abc", "name": "Alice", "age": 30}
}
```

Read body from `Storage.Document.Read()`, parse with `%FromJSON()`, inject `_id`/`_rev`.

### local_seq Support

The `local_seq` parameter on `GET /{db}/{docid}` adds the document's update sequence number. Scan `^IRISCouch.Changes(pDB)` backwards from the latest seq to find the most recent entry for this docId:
```objectscript
Set tLocalSeq = ""
Set tSeq = ""
For {
    Set tSeq = $Order(^IRISCouch.Changes(pDB, tSeq), -1)
    Quit:tSeq=""
    Set tEntry = ^IRISCouch.Changes(pDB, tSeq)
    If $ListGet(tEntry, 1) = pDocId {
        Set tLocalSeq = tSeq
        Quit
    }
}
```

Return as a string in the response: `Do tRespObj.%Set("_local_seq", tLocalSeq)`.

Note: This is O(n) in the changes feed length. For alpha, this is acceptable. A forward index (`^IRISCouch.DocSeq(pDB, pDocId) = seq`) can be added later for O(1) lookups.

### total_rows

`total_rows` is the total count of non-deleted documents in the database, regardless of limit/skip/key range filters. Use `^IRISCouch.DB(pDB, "doc_count")` which is already maintained by DocumentEngine.

### Route Ordering

`/_all_docs` is a `/:db/_xxx` sub-resource route — place BEFORE `/:db` routes alongside other sub-resource routes.

### Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `src/IRISCouch/API/Router.cls` | **Modify** | Add `_all_docs` GET/POST routes + wrappers |
| `src/IRISCouch/API/DocumentHandler.cls` | **Modify** | Add HandleAllDocs, HandleAllDocsPost; add local_seq to HandleGet |
| `src/IRISCouch/Test/AllDocsTest.cls` | **Create** | Unit tests for _all_docs |
| `src/IRISCouch/Test/AllDocsHttpTest.cls` | **Create** | HTTP integration tests for _all_docs and local_seq |

### Established Patterns

- Handler catch: `RenderInternal()` then `Quit $$$OK`
- Storage encapsulation: doc body via `Storage.Document`, tree via `Storage.RevTree`
- Response: `Response.JSON(tResult)` for 200
- Router wrappers: local method delegating to handler class
- Test cleanup: `OnBeforeOneTest` kills globals, creates fresh db
- Query params: `$Get(%request.Data("paramname", 1))`

### Previous Story Intelligence (Story 3.5)

- 112+ tests passing across 17 test classes
- DocumentHandler is getting large — HandleAllDocs may push it close to 500 lines. Consider keeping methods concise.
- RevTree has GetWinner, IsDeleted, GetConflicts, GetRevisions, GetRevsInfo, GetLeafRevs, AddBranch, GraftChain
- Storage.Document has Write, Read, Exists
- `^IRISCouch.Docs(pDB, docId, rev)` — iterate at docId level for _all_docs
- `^IRISCouch.Changes(pDB, seq) = $ListBuild(docId, rev)` — scan for local_seq

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.6] — Acceptance criteria
- [Source: _bmad-output/planning-artifacts/research/technical-couchdb-on-iris-research-2026-04-10.md:133] — _all_docs endpoint spec
- [Source: _bmad-output/planning-artifacts/architecture.md:292] — DocumentHandler handles _all_docs
- [Source: src/IRISCouch/API/Router.cls] — Current route structure
- [Source: src/IRISCouch/API/DocumentHandler.cls] — Existing handler patterns

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
No debug globals needed; all implementations compiled and tested on first pass.

### Completion Notes List
- Task 1: Added GET and POST routes for `/_all_docs` to Router UrlMap with wrapper methods delegating to DocumentHandler
- Task 2: Implemented `HandleAllDocs` with full support for limit, skip, startkey, endkey, inclusive_end, descending, include_docs query parameters. Uses $Order for sorted iteration, strips JSON-encoded quotes from key params
- Task 3: Implemented `HandleAllDocsPost` accepting `{"keys":[...]}` body, returning rows in keys order with `not_found` error rows for missing/deleted documents
- Task 4: Added `local_seq=true` support to HandleGet, scanning ^IRISCouch.Changes backwards for the document's latest sequence number
- Task 5: Added `CountNonDeleted` helper to Storage.Document using existing doc_count global
- Task 6: Created AllDocsTest.cls with 4 unit tests covering basic enumeration, skip/limit, key range, and deleted document exclusion
- Task 7: Created AllDocsHttpTest.cls with 6 HTTP integration tests covering GET _all_docs, limit/skip, include_docs, POST with keys, key range, and local_seq
- Task 8: Full regression suite passed -- 122 tests across 20 test classes, zero failures

### File List
- `src/IRISCouch/API/Router.cls` (modified) — Added _all_docs GET/POST routes and wrapper methods
- `src/IRISCouch/API/DocumentHandler.cls` (modified) — Added HandleAllDocs, HandleAllDocsPost methods; added local_seq support to HandleGet
- `src/IRISCouch/Storage/Document.cls` (modified) — Added CountNonDeleted class method
- `src/IRISCouch/Test/AllDocsTest.cls` (created) — Unit tests for _all_docs functionality
- `src/IRISCouch/Test/AllDocsHttpTest.cls` (created) — HTTP integration tests for _all_docs and local_seq

## Change Log
- 2026-04-12: Implemented Story 3.6 - All Documents View. Added GET/POST _all_docs endpoints with pagination, key-range filtering, include_docs, descending support. Added local_seq support to GET /{db}/{docid}. Added CountNonDeleted helper. Created 10 new tests (4 unit + 6 HTTP). Total test count: 122, all passing.
