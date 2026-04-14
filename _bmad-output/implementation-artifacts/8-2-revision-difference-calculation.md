# Story 8.2: Revision Difference Calculation

Status: done

## Story

As a replication client,
I want to retrieve which revisions the target already holds via `POST /{db}/_revs_diff`,
so that replication transfers only the missing data.

## Acceptance Criteria

1. **Given** a database with documents at various revisions
   **When** the client sends `POST /iris-couch/{db}/_revs_diff` with `{"doc1":["1-abc","2-def"],"doc2":["1-xyz"]}`
   **Then** the response status is 200 OK
   **And** the response body lists only the revisions not present locally: `{"doc1":{"missing":["2-def"]},"doc2":{"missing":["1-xyz"]}}`

2. **Given** all submitted revisions already exist locally
   **When** the `_revs_diff` request is processed
   **Then** the response body is an empty object `{}`

3. **Given** a document with a known revision tree
   **When** `_revs_diff` identifies missing revisions
   **Then** the response includes `possible_ancestors` listing known leaf revisions that could serve as a merge base

4. **Given** a non-existent document ID is submitted
   **When** the `_revs_diff` request is processed
   **Then** all revisions for that doc are reported as `missing` and no `possible_ancestors` are returned

5. **Given** an empty request body `{}`
   **When** the `_revs_diff` request is processed
   **Then** the response is `{}`

6. **Given** the database does not exist
   **When** the client sends `POST /{db}/_revs_diff`
   **Then** the response status is 404 with `{"error":"not_found","reason":"Database does not exist"}`

## Tasks / Subtasks

- [x] Task 1: Implement `HandleRevsDiff` in ReplicationHandler (AC: #1-#5)
  - [x] Read `src/IRISCouch/API/ReplicationHandler.cls` fully
  - [x] Read `src/IRISCouch/Storage/RevTree.cls` — understand `RevExists()` and `GetLeafRevs()` methods
  - [x] Add `ClassMethod HandleRevsDiff(pDB As %String) As %Status` to ReplicationHandler:
    - Validate database exists → 404 if not
    - Read request body, parse JSON as `%DynamicObject`
    - Handle empty body `{}` → return `{}`
    - Iterate over each key (docId) in the request object:
      - Get the array of revision strings for this docId
      - For each revision, call `Storage.RevTree.RevExists(pDB, docId, rev)`
      - Collect missing revisions into a `%DynamicArray`
      - If any missing: also collect `possible_ancestors` via `Storage.RevTree.GetLeafRevs(pDB, docId)`
      - Only include `possible_ancestors` if the array is non-empty (doc has known revisions)
    - Build response: only include docIds that have missing revisions
    - Return 200 with response JSON
  - [x] Compile via MCP

- [x] Task 2: Add route to Router (AC: #1)
  - [x] Open `src/IRISCouch/API/Router.cls`
  - [x] Add `_revs_diff` route in UrlMap after `_bulk_get` and `_changes`, before `_security`:
    ```xml
    <!-- Replication endpoints (Story 8.2) -->
    <Route Url="/:db/_revs_diff" Method="POST" Call="HandleRevsDiff" />
    ```
  - [x] Add wrapper method in Router:
    ```objectscript
    ClassMethod HandleRevsDiff(pDB As %String) As %Status { Quit ##class(IRISCouch.API.ReplicationHandler).HandleRevsDiff(pDB) }
    ```
  - [x] Compile Router via MCP

- [x] Task 3: Create unit tests (AC: #1-#5)
  - [x] Create `src/IRISCouch/Test/RevsDiffTest.cls` extending `%UnitTest.TestCase`
  - [x] Setup: create test database, populate with known documents and revision trees using `DocumentEngine.Save()`
  - [x] `TestAllRevsExist` — submit revisions that all exist locally → response is `{}`
  - [x] `TestSomeMissing` — submit mix of existing and non-existing revisions → only missing returned
  - [x] `TestNonExistentDoc` — submit revisions for a docId with no tree → all missing, no possible_ancestors
  - [x] `TestPossibleAncestors` — submit missing revisions for doc with known tree → `possible_ancestors` lists leaf revs
  - [x] `TestEmptyBody` — submit `{}` → response is `{}`
  - [x] `TestMultipleDocs` — submit multiple docIds in one request → correct per-doc results
  - [x] Teardown: clean up test database globals
  - [x] Compile and run tests — 6/6 pass

- [x] Task 4: Create HTTP integration tests (AC: #1-#6)
  - [x] Create `src/IRISCouch/Test/RevsDiffHttpTest.cls` extending `%UnitTest.TestCase`
  - [x] `TestRevsDiffAllExist` — POST _revs_diff with known revisions → 200 + `{}`
  - [x] `TestRevsDiffMissing` — POST _revs_diff with unknown revisions → 200 + missing array
  - [x] `TestRevsDiffDatabaseNotFound` — POST _revs_diff on non-existent db → 404
  - [x] `TestRevsDiffEmptyBody` — POST _revs_diff with `{}` → 200 + `{}`
  - [x] `TestRevsDiffWithAncestors` — POST with missing revs on doc that has a tree → includes possible_ancestors
  - [x] Compile and run tests — 5/5 pass

- [x] Task 5: Full regression (AC: all)
  - [x] Run all test classes — verify existing tests + new tests pass, 0 regressions

### Review Findings

- [x] [Review][Defer] possible_ancestors returns all leaf revisions without generation filtering [ReplicationHandler.cls:190-193] -- deferred, spec-level simplification vs CouchDB behavior (couch_db.erl:2159-2170)

## Dev Notes

### CouchDB _revs_diff Protocol (from `sources/couchdb/src/docs/src/replication/protocol.rst`)

**Request format:**
```json
POST /{db}/_revs_diff
Content-Type: application/json

{
    "doc1": ["1-abc", "2-def", "3-ghi"],
    "doc2": ["1-xyz"]
}
```

**Response format (missing revisions found):**
```json
{
    "doc1": {
        "missing": ["2-def", "3-ghi"],
        "possible_ancestors": ["1-abc"]
    },
    "doc2": {
        "missing": ["1-xyz"]
    }
}
```

**Response format (all revisions exist):**
```json
{}
```

**Key rules:**
- Only include docIds in response that have at least one missing revision
- `possible_ancestors` is included only when doc has known revisions locally (from `GetLeafRevs`)
- If doc doesn't exist at all, no `possible_ancestors` (empty leaf set)
- Empty request `{}` returns `{}`

### RevTree Methods to Use

From `src/IRISCouch/Storage/RevTree.cls`:
- `RevExists(pDB, pDocId, pRev) As %Boolean` (line 125) — checks `^IRISCouch.Tree(db, docId, "R", rev)` existence
- `GetLeafRevs(pDB, pDocId) As %DynamicArray` (line 238) — returns all leaf revisions via `$Order` on "L" nodes
- `TreeExists(pDB, pDocId) As %Boolean` (line 135) — checks if any tree exists for doc

### Algorithm

```
For each docId in request:
  missing = []
  For each rev in request[docId]:
    If NOT RevTree.RevExists(db, docId, rev):
      missing.push(rev)
  If missing is not empty:
    response[docId] = {"missing": missing}
    leaves = RevTree.GetLeafRevs(db, docId)
    If leaves is not empty:
      response[docId]["possible_ancestors"] = leaves
Return response
```

### Handler Pattern (from existing ReplicationHandler)

The `HandleRevsDiff` method follows the same pattern as `HandleLocalPut`:
- Extends existing `ReplicationHandler` (already created in Story 8.1)
- Uses `Error.Render()` for client errors (404, 400)
- Uses `Error.RenderInternal()` in catch blocks per NFR-S8
- Uses `Response.JSON()` for success responses
- Returns `$$$OK` after rendering (per `feedback_catch_block_pattern.md`)

### Router Route Placement

Add `_revs_diff` route after `_changes` routes and before `_security` routes, alongside other replication-related endpoints:

```xml
<!-- _changes routes -->
<Route Url="/:db/_changes" Method="GET" Call="HandleChangesGet" />
<Route Url="/:db/_changes" Method="POST" Call="HandleChangesPost" />
<!-- Replication endpoints (Story 8.2) -->
<Route Url="/:db/_revs_diff" Method="POST" Call="HandleRevsDiff" />
<!-- Per-database security (Story 7.4) -->
<Route Url="/:db/_security" Method="GET" Call="HandleSecurityGet" />
```

### Project Structure Notes

- Modified files: `src/IRISCouch/API/ReplicationHandler.cls` (add HandleRevsDiff), `src/IRISCouch/API/Router.cls` (add route + wrapper)
- New files: `src/IRISCouch/Test/RevsDiffTest.cls`, `src/IRISCouch/Test/RevsDiffHttpTest.cls`

### References

- [Source: sources/couchdb/src/docs/src/replication/protocol.rst:897-943 — _revs_diff protocol spec]
- [Source: sources/couchdb/src/chttpd/src/chttpd_db.erl:833-859 — CouchDB _revs_diff implementation]
- [Source: sources/couchdb/src/chttpd/test/eunit/chttpd_revs_diff_tests.erl — CouchDB test patterns]
- [Source: src/IRISCouch/Storage/RevTree.cls:125-142 — RevExists and TreeExists methods]
- [Source: src/IRISCouch/Storage/RevTree.cls:238-253 — GetLeafRevs method]
- [Source: src/IRISCouch/API/ReplicationHandler.cls — existing handler pattern from Story 8.1]
- [Source: src/IRISCouch/API/Router.cls — UrlMap route ordering]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

No debug globals needed; all tests passed on first run.

### Completion Notes List

- Implemented `HandleRevsDiff` in `ReplicationHandler` following existing handler patterns (Try/Catch, Error.Render for 404, Error.RenderInternal in catch, Response.JSON for success, return $$$OK)
- Algorithm iterates each docId in request, checks RevExists for each revision, collects missing revs, and includes possible_ancestors from GetLeafRevs when doc has a known tree
- Empty request body and empty JSON `{}` both return `{}`; non-existent database returns 404
- Added POST route `/:db/_revs_diff` to Router UrlMap after `_changes` routes and before `_security` routes
- Added Router wrapper method delegating to `ReplicationHandler.HandleRevsDiff`
- Unit tests (6/6 pass): TestAllRevsExist, TestSomeMissing, TestNonExistentDoc, TestPossibleAncestors, TestEmptyBody, TestMultipleDocs
- HTTP integration tests (5/5 pass): TestRevsDiffAllExist, TestRevsDiffMissing, TestRevsDiffDatabaseNotFound, TestRevsDiffEmptyBody, TestRevsDiffWithAncestors
- Full regression: 0 failures across HttpIntegrationTest (4), LocalDocTest (9), LocalDocHttpTest (3), RevTreeTest (8), RouterTest (5), DocumentTest (10), ReplicationTest (6), DatabaseTest (13), RevsDiffTest (6), RevsDiffHttpTest (5)

### Change Log

- 2026-04-13: Story 8.2 implementation — Added HandleRevsDiff to ReplicationHandler, route to Router, unit tests and HTTP integration tests

### File List

- src/IRISCouch/API/ReplicationHandler.cls (modified — added HandleRevsDiff method)
- src/IRISCouch/API/Router.cls (modified — added _revs_diff route and wrapper method)
- src/IRISCouch/Test/RevsDiffTest.cls (new — 6 unit tests)
- src/IRISCouch/Test/RevsDiffHttpTest.cls (new — 5 HTTP integration tests)
