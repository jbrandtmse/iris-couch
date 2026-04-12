# Story 2.2: List Databases and Retrieve Metadata

Status: done

## Story

As a client,
I want to list all databases via `GET /_all_dbs` and retrieve per-database metadata via `GET /{db}`,
so that I can discover available databases and inspect their state.

## Acceptance Criteria

1. **Given** one or more databases exist, **When** the client sends `GET /iris-couch/_all_dbs`, **Then** the response status is 200 OK and the response body is a JSON array of database name strings sorted alphabetically.
2. **Given** no databases exist, **When** the client sends `GET /iris-couch/_all_dbs`, **Then** the response status is 200 OK and the response body is an empty JSON array `[]`.
3. **Given** a database `{db}` exists, **When** the client sends `GET /iris-couch/{db}`, **Then** the response status is 200 OK and the response body includes `db_name`, `doc_count`, `doc_del_count`, `update_seq`, `disk_size`, `data_size`, `purge_seq`, `compact_running`, `instance_start_time`, `disk_format_version`, and `committed_update_seq` fields.
4. **Given** no database named `{db}` exists, **When** the client sends `GET /iris-couch/{db}`, **Then** the response status is 404 Not Found with `{"error":"not_found","reason":"Database does not exist."}`.
5. **Given** all changes are compiled and tested, **Then** all existing tests (41) continue to pass with zero regressions, and new unit + integration tests cover all acceptance criteria.

## Tasks / Subtasks

- [x] Task 1: Add `ListAll` and `GetInfo` methods to `IRISCouch.Storage.Database` (AC: #1, #2, #3)
  - [x] 1.1: Implement `ClassMethod ListAll() As %DynamicArray` — iterates `^IRISCouch.DB` using `$Order`, collects all database names, sorts alphabetically, returns a `%DynamicArray`
  - [x] 1.2: Implement `ClassMethod GetInfo(pName As %String) As %DynamicObject` — reads `^IRISCouch.DB(pName, ...)` subscripts and returns CouchDB-compatible metadata object (see Dev Notes for field mapping)
  - [x] 1.3: Compile and verify no errors

- [x] Task 2: Add `HandleInfo` and `HandleAllDbs` to `IRISCouch.API.DatabaseHandler` (AC: #1, #2, #3, #4)
  - [x] 2.1: Implement `ClassMethod HandleInfo(pDB As %String) As %Status` — checks existence (404 if missing), calls Storage.Database.GetInfo(), returns 200 with metadata JSON
  - [x] 2.2: Implement `ClassMethod HandleAllDbs() As %Status` — calls Storage.Database.ListAll(), returns 200 with JSON array
  - [x] 2.3: Use `RenderInternal()` in catch blocks with subsystem reasons `"database: info error"` / `"database: list error"`
  - [x] 2.4: Compile and verify no errors

- [x] Task 3: Add routes to Router (AC: #1, #3, #4)
  - [x] 3.1: Add `<Route Url="/_all_dbs" Method="GET" Call="HandleAllDbs" />` to UrlMap — MUST be BEFORE `/:db` routes
  - [x] 3.2: Add `<Route Url="/:db" Method="GET" Call="HandleDatabaseInfo" />` to UrlMap — alongside existing PUT/DELETE `/:db` routes
  - [x] 3.3: Create local wrapper `ClassMethod HandleAllDbs() As %Status` delegating to `DatabaseHandler.HandleAllDbs()`
  - [x] 3.4: Create local wrapper `ClassMethod HandleDatabaseInfo(pDB As %String) As %Status` delegating to `DatabaseHandler.HandleInfo(pDB)`
  - [x] 3.5: Compile Router and verify no errors

- [x] Task 4: Create unit tests (AC: #1, #2, #3, #4, #5)
  - [x] 4.1: Add tests to existing `IRISCouch.Test.DatabaseTest` (or create new if >500 lines)
  - [x] 4.2: `TestListAllEmpty` — clean all `^IRISCouch.DB`, call ListAll(), verify empty array
  - [x] 4.3: `TestListAllWithDatabases` — create 3 databases, call ListAll(), verify sorted alphabetically
  - [x] 4.4: `TestGetInfo` — create database, call GetInfo(), verify all metadata fields present with correct types
  - [x] 4.5: `TestGetInfoNotFound` — call GetInfo() on non-existent db, verify returns "" or error

- [x] Task 5: Add HTTP integration tests (AC: #1, #2, #3, #4)
  - [x] 5.1: Add to `IRISCouch.Test.DatabaseHttpTest` or create new class
  - [x] 5.2: `TestAllDbsEmptyHttp` — clean databases, `GET /_all_dbs` returns 200 with `[]`
  - [x] 5.3: `TestAllDbsWithDatabasesHttp` — create databases, `GET /_all_dbs` returns sorted array
  - [x] 5.4: `TestDatabaseInfoHttp` — create database, `GET /{db}` returns 200 with metadata fields
  - [x] 5.5: `TestDatabaseInfoNotFoundHttp` — `GET /nonexistent` returns 404, error `not_found`
  - [x] 5.6: Clean up test databases in `OnAfterOneTest`

- [x] Task 6: Update HttpIntegrationTest for GET /{db} behavior change
  - [x] 6.1: `TestNotFoundEndpoint` and `TestParameterizedRoutePattern` now expect different responses since GET `/:db` route exists — update if needed (GET to non-existent db should return 404 from DatabaseHandler, not from ReportHttpStatusCode)

- [x] Task 7: Run full test suite and verify
  - [x] 7.1: All existing 41 tests pass (zero regressions)
  - [x] 7.2: All new unit + integration tests pass

### Review Findings

Code review completed 2026-04-12. Three review layers applied (Blind Hunter, Edge Case Hunter, Acceptance Auditor).

- **0 decision-needed** findings
- **0 patch** findings (no HIGH or MEDIUM issues)
- **0 defer** findings
- **4 dismissed** findings (all LOW severity noise)

Dismissed findings:
- [x] [Review][Dismiss] Unused `tSC` variable in HandleInfo/HandleAllDbs — consistent with project pattern, no impact
- [x] [Review][Dismiss] Double existence check in HandleInfo + GetInfo — defensive coding, acceptable redundancy
- [x] [Review][Dismiss] Test cleanup loop + hard-coded index assertions — acceptable test isolation pattern
- [x] [Review][Dismiss] Theoretical race condition between Exists and $Get in GetInfo — $Get returns safe defaults, no crash risk

All 5 acceptance criteria verified. Route ordering correct. Error handling follows project patterns (RenderInternal in catch blocks, error slug constants, Quit $$$OK after catch). Router wrapper pattern followed.

## Dev Notes

### CouchDB GET /{db} Metadata Fields

CouchDB returns these fields for `GET /{db}`:

```json
{
  "db_name": "mydb",
  "doc_count": 0,
  "doc_del_count": 0,
  "update_seq": "0-g1AAAABXeJzLYWBg...",
  "purge_seq": "0-g1AAAA...",
  "compact_running": false,
  "disk_size": 8482,
  "data_size": 0,
  "instance_start_time": "0",
  "disk_format_version": 8,
  "committed_update_seq": "0-g1AAAA..."
}
```

**Field mapping from `^IRISCouch.DB` subscripts:**

| CouchDB Field | Source | Notes |
|---------------|--------|-------|
| `db_name` | Method parameter `pName` | String |
| `doc_count` | `^IRISCouch.DB(db,"doc_count")` | Integer |
| `doc_del_count` | 0 (hardcode for now) | Track deleted docs count in later epics |
| `update_seq` | `^IRISCouch.DB(db,"update_seq")` | Integer (CouchDB uses opaque strings, we use integers) |
| `purge_seq` | `^IRISCouch.DB(db,"purge_seq")` | Integer |
| `compact_running` | `false` (hardcode) | No compaction engine yet (Story 2.3 placeholder) |
| `disk_size` | `^IRISCouch.DB(db,"disk_size")` | Integer |
| `data_size` | 0 (hardcode for now) | Track actual data size in later epics |
| `instance_start_time` | `"0"` | CouchDB compatibility — deprecated field |
| `disk_format_version` | 1 | IRISCouch format version |
| `committed_update_seq` | Same as `update_seq` | IRIS journaling makes this identical |

### ListAll Implementation

Use `$Order` to iterate `^IRISCouch.DB`:
```objectscript
ClassMethod ListAll() As %DynamicArray
{
    Set tArr = []
    Set tName = ""
    For {
        Set tName = $Order(^IRISCouch.DB(tName))
        Quit:tName=""
        Do tArr.%Push(tName)
    }
    Quit tArr
}
```

`$Order` on globals returns keys in collation order, which for string keys is alphabetical — no explicit sort needed.

### Route Ordering (CRITICAL)

The UrlMap must have literal routes BEFORE parameterized `/:db` routes:
```xml
<Routes>
  <!-- System endpoints first -->
  <Route Url="/_uuids" Method="GET" Call="HandleUUIDs" />
  <Route Url="/_all_dbs" Method="GET" Call="HandleAllDbs" />
  <!-- Database endpoints (parameterized) -->
  <Route Url="/:db" Method="PUT" Call="HandleDatabaseCreate" />
  <Route Url="/:db" Method="DELETE" Call="HandleDatabaseDelete" />
  <Route Url="/:db" Method="GET" Call="HandleDatabaseInfo" />
  <!-- Welcome endpoint last -->
  <Route Url="/" Method="GET" Call="HandleWelcome" />
</Routes>
```

### Existing HttpIntegrationTest Behavior Change

With `GET /:db` route added, `TestNotFoundEndpoint` (GET /nonexistent) and `TestParameterizedRoutePattern` (GET /testdb123) will now hit `DatabaseHandler.HandleInfo()` instead of `ReportHttpStatusCode`. Both should still return 404 with `not_found` error, but the error will come from DatabaseHandler not from the router fallback. Verify these tests still pass — they should since the error slug and status code are the same.

### Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `src/IRISCouch/Storage/Database.cls` | **Modify** | Add `ListAll()` and `GetInfo()` methods |
| `src/IRISCouch/API/DatabaseHandler.cls` | **Modify** | Add `HandleInfo()` and `HandleAllDbs()` methods |
| `src/IRISCouch/API/Router.cls` | **Modify** | Add `/_all_dbs` and `GET /:db` routes + wrappers |
| `src/IRISCouch/Test/DatabaseTest.cls` | **Modify** | Add ListAll and GetInfo unit tests |
| `src/IRISCouch/Test/DatabaseHttpTest.cls` | **Modify** | Add _all_dbs and GET /{db} HTTP tests |

### Existing Code to Reuse

- `IRISCouch.Storage.Database` — Exists(), Create(), Delete() already implemented
- `IRISCouch.API.DatabaseHandler` — HandleCreate(), HandleDelete() as pattern reference
- `IRISCouch.Util.Response.JSON()` — for 200 responses
- `IRISCouch.Util.Error` — `.#NOTFOUND`, `.Render()`, `.RenderInternal()`
- `IRISCouch.Test.HttpIntegrationTest.MakeRequest()` — for HTTP tests
- Error slug constants — use `##class(IRISCouch.Util.Error).#NOTFOUND` not literal strings

### Previous Story Intelligence (Story 2.1)

- 41 tests passing across 8 test classes
- `Storage.Database` uses subscripted globals: `^IRISCouch.DB(name, "doc_count")` etc.
- `DatabaseHandler` follows Pattern 2 (pDB first param, Try/Catch, %Status return)
- Error slug constants used via `##class(IRISCouch.Util.Error).#SLUG` — never inline strings
- Router wrapper pattern: local method delegates to handler class
- `Quit $$$OK` after catch blocks (not `Quit tSC`)

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.2]
- [Source: _bmad-output/planning-artifacts/research/technical-couchdb-on-iris-research-2026-04-10.md] — GET /{db} field list
- [Source: src/IRISCouch/Storage/Database.cls] — existing storage methods
- [Source: src/IRISCouch/API/DatabaseHandler.cls] — existing handler pattern
- [Source: src/IRISCouch/API/Router.cls] — current route structure

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
No debug globals needed; all implementations compiled and passed tests on first attempt.

### Completion Notes List
- Implemented `ListAll()` using `$Order` on `^IRISCouch.DB` global; alphabetical order is guaranteed by global collation so no explicit sort needed.
- Implemented `GetInfo()` returning all 11 CouchDB-compatible metadata fields using `%DynamicObject.%Set()` with explicit type parameters for correct JSON serialization (numbers as numbers, booleans as booleans).
- `HandleInfo()` follows existing Pattern 2 (pDB first param, Try/Catch, `$$$OK` return after catch), with 404 for missing databases and `RenderInternal()` in catch blocks.
- `HandleAllDbs()` is a straightforward delegation to `Storage.Database.ListAll()` with `RenderInternal()` error handling.
- Router: `/_all_dbs` route placed before `/:db` routes to prevent parameterized capture. `GET /:db` added after PUT/DELETE.
- Updated `HttpIntegrationTest.TestNotFoundEndpoint` and `TestParameterizedRoutePattern` from expecting 405 to expecting 404, since `GET /:db` now routes to `DatabaseHandler.HandleInfo()`.
- Total test count: 49 (was 41, added 8 new tests). Zero regressions.

### Change Log
- 2026-04-12: Story 2.2 implementation complete. Added ListAll/GetInfo storage methods, HandleInfo/HandleAllDbs handler methods, /_all_dbs and GET /:db routes with wrappers, 4 unit tests, 4 HTTP integration tests, updated 2 existing tests for behavior change.

### File List
- src/IRISCouch/Storage/Database.cls (modified) - Added ListAll() and GetInfo() class methods
- src/IRISCouch/API/DatabaseHandler.cls (modified) - Added HandleInfo() and HandleAllDbs() class methods
- src/IRISCouch/API/Router.cls (modified) - Added /_all_dbs and GET /:db routes with wrapper methods
- src/IRISCouch/Test/DatabaseTest.cls (modified) - Added TestListAllEmpty, TestListAllWithDatabases, TestGetInfo, TestGetInfoNotFound
- src/IRISCouch/Test/DatabaseHttpTest.cls (modified) - Added TestAllDbsEmptyHttp, TestAllDbsWithDatabasesHttp, TestDatabaseInfoHttp, TestDatabaseInfoNotFoundHttp
- src/IRISCouch/Test/HttpIntegrationTest.cls (modified) - Updated TestNotFoundEndpoint and TestParameterizedRoutePattern for GET /:db behavior
