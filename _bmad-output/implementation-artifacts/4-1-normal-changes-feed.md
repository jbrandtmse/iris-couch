# Story 4.1: Normal Changes Feed

Status: done

## Story

As a client,
I want to retrieve a snapshot of database changes via `GET /{db}/_changes` in `feed=normal` mode,
so that I can see all document changes up to the current sequence.

## Acceptance Criteria

1. **Given** a database `{db}` with documents that have been created, updated, or deleted, **When** the client sends `GET /iris-couch/{db}/_changes`, **Then** the response status is 200 OK and the response body contains `{"results":[{"seq":N,"id":"...","changes":[{"rev":"..."}]}],"last_seq":N,"pending":0}` and each change has a monotonically increasing sequence number.

2. **Given** a database with changes, **When** the client sends `GET /iris-couch/{db}/_changes?since=5`, **Then** only changes with sequence numbers greater than 5 are returned.

3. **Given** a database with many changes, **When** the client sends `GET /iris-couch/{db}/_changes?limit=10`, **Then** at most 10 change entries are returned and `pending` reflects the count of remaining changes.

4. **Given** a database with changes, **When** the client sends `GET /iris-couch/{db}/_changes?include_docs=true`, **Then** each change entry includes a `doc` field with the full document body.

5. **Given** a database with documents that have conflicts, **When** the client sends `GET /iris-couch/{db}/_changes?style=all_docs`, **Then** each change entry lists all leaf revisions in the `changes` array.

6. **Given** a database with changes, **When** the client sends `GET /iris-couch/{db}/_changes?descending=true`, **Then** changes are returned in reverse sequence order (highest seq first).

7. **Given** the client sends `POST /iris-couch/{db}/_changes` with query parameters in the JSON body, **Then** the behavior is identical to GET with those parameters.

8. **Given** all changes are compiled and tested, **Then** all existing 124 tests pass with zero regressions, and new tests cover all acceptance criteria.

## Tasks / Subtasks

- [x] Task 1: Add `_changes` routes to Router (AC: #1, #7)
  - [x] 1.1: Add `<Route Url="/:db/_changes" Method="GET" Call="HandleChangesGet" />` in the `/:db/_xxx` sub-resource block (before `/:db` routes)
  - [x] 1.2: Add `<Route Url="/:db/_changes" Method="POST" Call="HandleChangesPost" />` in the same block
  - [x] 1.3: Create local wrapper: `ClassMethod HandleChangesGet(pDB As %String) As %Status` delegating to `##class(IRISCouch.API.ChangesHandler).HandleChanges(pDB)`
  - [x] 1.4: Create local wrapper: `ClassMethod HandleChangesPost(pDB As %String) As %Status` delegating to `##class(IRISCouch.API.ChangesHandler).HandleChanges(pDB)` (same handler — POST sends params in body)
  - [x] 1.5: Compile via MCP

- [x] Task 2: Extend `Storage.Changes` with feed query methods (AC: #1, #2, #3)
  - [x] 2.1: Add `ClassMethod GetLastSeq(pDB As %String) As %Integer` — returns `+$Get(^IRISCouch.Seq(pDB))`. Returns 0 if no changes exist.
  - [x] 2.2: Add `ClassMethod ReadEntry(pDB As %String, pSeq As %Integer) As %List` — returns `$Get(^IRISCouch.Changes(pDB, pSeq))`. Returns "" if entry does not exist. Each entry is `$ListBuild(docId, rev)`.
  - [x] 2.3: Add `ClassMethod ListChanges(pDB As %String, pSince As %Integer = 0, pLimit As %Integer = 0, pDescending As %Boolean = 0) As %DynamicObject` — iterates `^IRISCouch.Changes(pDB)` starting after `pSince`, returns `{"results": [...], "lastSeq": N, "pending": N}`:
    - If `pDescending`: iterate from highest seq down using `$Order(..., -1)`, starting from last seq (or from pSince if provided)
    - If NOT `pDescending`: iterate forward using `$Order(...)`, starting from pSince
    - For each entry: extract docId and rev from `$ListBuild`, build `{"seq": seq, "id": docId, "changes": [{"rev": rev}]}`
    - Apply `pLimit`: stop after pLimit entries, compute `pending` = remaining entries beyond what was returned
    - `lastSeq`: the seq of the last entry returned (or pSince if no results)
    - `pending`: total changes after lastSeq
  - [x] 2.4: Add `ClassMethod CountSince(pDB As %String, pSince As %Integer = 0) As %Integer` — counts entries in `^IRISCouch.Changes(pDB)` with seq > pSince. Used for computing `pending`.
  - [x] 2.5: Compile via MCP

- [x] Task 3: Create `API/ChangesHandler.cls` (AC: #1-#7)
  - [x] 3.1: Create `src/IRISCouch/API/ChangesHandler.cls` with `Class IRISCouch.API.ChangesHandler Extends %RegisteredObject`
  - [x] 3.2: Create `ClassMethod HandleChanges(pDB As %String) As %Status`:
    - Check database exists (404 if not)
    - Parse parameters from query string OR POST body (POST body takes precedence for shared params)
    - Parameters to parse: `since` (integer, default 0), `limit` (integer, default 0=unlimited), `include_docs` (boolean), `style` ("main_only" default or "all_docs"), `descending` (boolean), `feed` (only "normal" supported in this story — return 400 for other values like "longpoll" or "continuous" with message "Feed mode not supported")
    - For POST: read and parse JSON body. Extract `since`, `limit`, `include_docs`, `style`, `descending` from body. Query string params override body params (CouchDB behavior).
    - Call `Storage.Changes.ListChanges(pDB, tSince, tLimit, tDescending)` to get raw results
    - Post-process each result entry:
      - If `style=all_docs`: replace `changes` array with all leaf revisions from `RevTree.GetLeafRevs(pDB, docId)`, formatted as `[{"rev":"rev1"},{"rev":"rev2"}]`
      - If `include_docs=true`: add `doc` field with full document body from `Storage.Document.Read()`, inject `_id` and `_rev`
      - If the change is for a deleted document (check `RevTree.IsDeleted`): add `"deleted":true` to the change entry and if include_docs, set doc to `{"_id":"...","_rev":"...","_deleted":true}`
    - Build response: `{"results":[...],"last_seq":N,"pending":N}`
    - `last_seq` comes from ListChanges result
    - `pending` comes from ListChanges result (adjusted if limit was applied)
    - Return 200 with `Response.JSON(tResp)`
  - [x] 3.3: Compile via MCP

- [x] Task 4: Create unit tests `Test/ChangesTest.cls` (AC: #1-#6)
  - [x] 4.1: Create `src/IRISCouch/Test/ChangesTest.cls` extending `%UnitTest.TestCase`
  - [x] 4.2: `OnBeforeOneTest` / `OnAfterOneTest` — kill globals for "testchangesdb", create fresh db
  - [x] 4.3: `TestBasicChangesFeed` — create 3 docs via DocumentEngine.Save(), call `Storage.Changes.ListChanges("testchangesdb")`, assert 3 results, monotonically increasing seq, correct docIds
  - [x] 4.4: `TestChangesSince` — create 3 docs, call ListChanges with pSince=1, assert only 2 results returned (seq > 1)
  - [x] 4.5: `TestChangesLimit` — create 5 docs, call ListChanges with pLimit=2, assert 2 results and pending=3
  - [x] 4.6: `TestChangesIncludesDeleted` — create doc, delete it via DocumentEngine.SaveDeleted(), verify the delete appears in changes with the tombstone revision
  - [x] 4.7: `TestChangesGetLastSeq` — create 3 docs, call GetLastSeq, assert returns 3

- [x] Task 5: Create HTTP integration tests `Test/ChangesHttpTest.cls` (AC: #1-#7)
  - [x] 5.1: Create `src/IRISCouch/Test/ChangesHttpTest.cls` extending `%UnitTest.TestCase`
  - [x] 5.2: `OnBeforeOneTest` / `OnAfterOneTest` — kill globals for "testchangeshttpdb", create fresh db
  - [x] 5.3: `TestChangesGetHttp` — create 2 docs, `GET /{db}/_changes` → 200, verify results array has 2 entries with seq/id/changes, last_seq present, pending=0
  - [x] 5.4: `TestChangesSinceHttp` — create 3 docs, `GET /{db}/_changes?since=1` → 200, verify only 2 results
  - [x] 5.5: `TestChangesLimitHttp` — create 3 docs, `GET /{db}/_changes?limit=1` → 200, verify 1 result, pending=2
  - [x] 5.6: `TestChangesIncludeDocsHttp` — create doc with body `{"name":"Alice"}`, `GET /{db}/_changes?include_docs=true` → 200, verify each entry has `doc` field with full body including `_id` and `_rev`
  - [x] 5.7: `TestChangesStyleAllDocsHttp` — create doc, create conflict via AddBranch + document write, `GET /{db}/_changes?style=all_docs` → 200, verify the conflicted doc's changes array has 2 entries
  - [x] 5.8: `TestChangesPostHttp` — create 2 docs, `POST /{db}/_changes` with body `{"since":0,"limit":1}` → 200, verify 1 result
  - [x] 5.9: `TestChangesDeletedHttp` — create doc, delete it, `GET /{db}/_changes` → 200, verify delete entry has `"deleted":true`

- [x] Task 6: Run full test suite (AC: #8)
  - [x] 6.1: All existing 124 tests pass (zero regressions)
  - [x] 6.2: All new tests pass (16 new tests: 8 unit + 8 HTTP)

## Dev Notes

### Changes Feed Response Format

```json
{
  "results": [
    {"seq": 1, "id": "doc1", "changes": [{"rev": "1-abc123"}]},
    {"seq": 2, "id": "doc2", "changes": [{"rev": "1-def456"}]},
    {"seq": 3, "id": "doc1", "changes": [{"rev": "2-ghi789"}]}
  ],
  "last_seq": 3,
  "pending": 0
}
```

Key points:
- `seq` is an integer (not a string) — CouchDB 2.x uses opaque strings but we use simple integers per architecture
- `changes` is always an array of `{"rev":"..."}` objects — for `style=main_only` (default), it contains only the winning rev; for `style=all_docs`, it contains all leaf revisions
- `last_seq` = seq of the last entry in results (or `since` value if results is empty)
- `pending` = count of changes remaining after `last_seq` (0 if all changes returned)
- A document may appear multiple times (once per write) — CouchDB does NOT deduplicate by docId in normal mode
- Deleted documents include `"deleted": true` in the change entry

### Global Structure (Already Populated)

`^IRISCouch.Changes(pDB, seq) = $ListBuild(pDocId, pRev)` — written by DocumentEngine.Save/SaveDeleted/SaveWithHistory within TSTART/TCOMMIT.

`^IRISCouch.Seq(pDB)` — monotonically increasing counter, incremented via `$Increment` in each write transaction.

These globals are already populated by all existing write paths. This story only READS them — no write-path changes needed.

### Storage.Changes Methods to Use

The `Storage.Changes` class already exists with `GetDocSeq`. New methods needed:
- `GetLastSeq(pDB)` — returns current seq counter
- `ReadEntry(pDB, pSeq)` — reads single entry
- `ListChanges(pDB, pSince, pLimit, pDescending)` — iterates and returns results + metadata
- `CountSince(pDB, pSince)` — counts entries for pending calculation

### style=all_docs Processing

When `style=all_docs`, each change entry must list ALL leaf revisions for that document:

```json
{"seq": 3, "id": "doc1", "changes": [{"rev": "2-aaa"}, {"rev": "2-bbb"}]}
```

Use `RevTree.GetLeafRevs(pDB, pDocId)` which returns a `%DynamicArray` of all leaf rev strings.

### include_docs=true Processing

When `include_docs=true`, add a `doc` field to each change entry:

```json
{"seq": 1, "id": "doc1", "changes": [{"rev": "1-abc"}], "doc": {"_id": "doc1", "_rev": "1-abc", "name": "Alice"}}
```

For deleted documents:
```json
{"seq": 2, "id": "doc1", "changes": [{"rev": "2-def"}], "deleted": true, "doc": {"_id": "doc1", "_rev": "2-def", "_deleted": true}}
```

Read body from `Storage.Document.Read(pDB, pDocId, pRev)`, parse with `%FromJSON`, inject `_id`/`_rev`.

### POST /{db}/_changes

POST accepts the same parameters as GET but in the JSON body. This allows filters to send complex parameters (important for Story 4.3). Query string parameters override body parameters per CouchDB behavior.

### descending=true

When `descending=true`, iterate `^IRISCouch.Changes` in reverse order. The `since` parameter semantics stay the same — it's a "starting point" anchor. With descending:
- Start from the latest seq and iterate backwards
- `since` acts as a lower bound — stop when reaching `since`

### Feed Mode Validation

This story only implements `feed=normal` (the default). If the client passes `feed=longpoll`, `feed=continuous`, or `feed=eventsource`, return 400 with `{"error":"bad_request","reason":"Feed mode not yet supported"}`. Story 4.2 adds longpoll.

### Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `src/IRISCouch/API/ChangesHandler.cls` | **Create** | New handler for GET/POST /_changes |
| `src/IRISCouch/Storage/Changes.cls` | **Modify** | Add GetLastSeq, ReadEntry, ListChanges, CountSince methods |
| `src/IRISCouch/API/Router.cls` | **Modify** | Add _changes GET/POST routes + wrapper methods |
| `src/IRISCouch/Test/ChangesTest.cls` | **Create** | Unit tests for changes feed |
| `src/IRISCouch/Test/ChangesHttpTest.cls` | **Create** | HTTP integration tests for _changes endpoint |

### Established Patterns

- Handler catch: `RenderInternal()` then `Quit $$$OK`
- Storage encapsulation: all `^IRISCouch.*` access through Storage.* classes only
- Response: `Response.JSON(tResult)` for 200
- Router wrappers: local method delegating to handler class
- Test cleanup: `OnBeforeOneTest` kills globals, creates fresh db
- Constructor: `%OnNew(initvalue As %String = "")` with `##super(initvalue)` call
- Query params: `$Get(%request.Data("paramname", 1))`
- Cross-class calls: `##class(ClassName).MethodName()` not `..MethodName()`

### Previous Story Intelligence (Story 4.0)

- 124 tests passing across 20 test classes
- DocumentHandler reduced to 396 lines after split
- BulkHandler and AllDocsHandler extracted as separate classes
- Storage.Changes created with GetDocSeq method
- RevTree has MarkDeleted, RevExists, TreeExists (new in 4.0)
- Router has 18 routes currently — add 2 more for _changes

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.1] — Acceptance criteria
- [Source: _bmad-output/planning-artifacts/architecture.md:293] — ChangesHandler handles GET/POST /{db}/_changes
- [Source: _bmad-output/planning-artifacts/architecture.md:503] — Storage.Changes owns ^IRISCouch.Changes and ^IRISCouch.Seq
- [Source: _bmad-output/planning-artifacts/architecture.md:316] — Changes.Record write path
- [Source: _bmad-output/planning-artifacts/architecture.md:954] — Replication pull path uses _changes
- [Source: src/IRISCouch/Storage/Changes.cls] — Existing Storage.Changes with GetDocSeq
- [Source: src/IRISCouch/Core/DocumentEngine.cls:65-66] — Changes global write: `$Increment(^IRISCouch.Seq), Set ^IRISCouch.Changes`
- [Source: src/IRISCouch/API/Router.cls] — Current route structure

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
No debug globals needed; all tests passed on first run.

### Completion Notes List
- Implemented Storage.Changes with 4 new methods: GetLastSeq, ReadEntry, ListChanges, CountSince
- Created ChangesHandler with unified GET/POST handler supporting since, limit, include_docs, style, descending, feed params
- POST body parameters serve as defaults; query string params override (CouchDB behavior)
- style=all_docs uses RevTree.GetLeafRevs to return all leaf revisions per doc
- include_docs injects _id/_rev into doc body; deleted docs get _deleted:true stub
- Unsupported feed modes (longpoll, continuous) return 400 bad_request
- Added 2 routes to Router with local wrapper methods following established pattern
- 16 new tests (8 unit + 8 HTTP integration), all passing
- 124 existing tests pass with zero regressions (140 total)

### File List
- src/IRISCouch/API/ChangesHandler.cls (created)
- src/IRISCouch/Storage/Changes.cls (modified)
- src/IRISCouch/API/Router.cls (modified)
- src/IRISCouch/Test/ChangesTest.cls (created)
- src/IRISCouch/Test/ChangesHttpTest.cls (created)

### Review Findings
- [x] [Review][Patch] POST body JSON parse error falls through to undefined tBodyObj [ChangesHandler.cls:42-45] — FIXED: inner catch Quit only exits inner try/catch; tBodyObj undefined causes 500 instead of 400. Changed to Return $$$OK.
- [x] [Review][Patch] Descending + limit produces incorrect pending count [Storage/Changes.cls:118] — FIXED: CountSince(tLastSeq) counts entries above last returned seq, but those were already returned in descending mode. Fixed to compute total - returned.
- [x] [Review][Defer] No test for unsupported feed mode 400 response — deferred, minor test coverage gap

### Change Log
- 2026-04-12: Story 4.1 implementation complete — normal changes feed with GET/POST /_changes, all 8 ACs satisfied, 16 new tests added
- 2026-04-12: Code review fixes — POST parse error flow-through bug, descending pending count bug
