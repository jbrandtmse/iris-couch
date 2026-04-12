# Story 2.1: Create and Delete Databases

Status: done

## Story

As an operator,
I want to create databases via `PUT /{db}` and delete them via `DELETE /{db}`,
so that I can provision and decommission data stores for my applications.

## Acceptance Criteria

1. **Given** an authenticated client, **When** the client sends `PUT /iris-couch/{db}` with a valid database name, **Then** the response status is 201 Created, the response body is `{"ok":true}`, the `^IRISCouch.DB(db)` global is initialized with database metadata, and empty globals are prepared for the new database's documents, rev-tree, changes, and sequences.
2. **Given** a database with name `{db}` already exists, **When** the client sends `PUT /iris-couch/{db}`, **Then** the response status is 412 Precondition Failed and the response body contains `{"error":"file_exists","reason":"The database could not be created, the file already exists."}`.
3. **Given** an existing database `{db}`, **When** the client sends `DELETE /iris-couch/{db}`, **Then** the response status is 200 OK, the response body is `{"ok":true}`, and all globals associated with the database are removed.
4. **Given** no database named `{db}` exists, **When** the client sends `DELETE /iris-couch/{db}`, **Then** the response status is 404 Not Found and the response body contains `{"error":"not_found","reason":"Database does not exist."}`.
5. **Given** a client sends `PUT /iris-couch/{db}` with an invalid database name (uppercase, spaces, special chars), **Then** the response status is 400 Bad Request and the response body contains `{"error":"illegal_database_name","reason":"..."}`.
6. **Given** all changes are compiled and tested, **Then** all existing tests (30) continue to pass with zero regressions, and new unit + integration tests cover all acceptance criteria.

## Tasks / Subtasks

- [x] Task 1: Create `IRISCouch.Storage.Database` class (AC: #1, #3)
  - [x] 1.1: Create `src/IRISCouch/Storage/Database.cls` extending `%RegisteredObject`
  - [x] 1.2: Implement `ClassMethod Create(pName As %String) As %Status` — initializes `^IRISCouch.DB(pName)` with metadata (created timestamp, doc_count=0, update_seq=0, disk_size=0, purge_seq=0, revs_limit=1000)
  - [x] 1.3: Implement `ClassMethod Delete(pName As %String) As %Status` — kills `^IRISCouch.DB(pName)` and all associated globals (`^IRISCouch.Docs(pName,...)`, `^IRISCouch.Tree(pName,...)`, `^IRISCouch.Changes(pName,...)`, `^IRISCouch.Seq(pName)`)
  - [x] 1.4: Implement `ClassMethod Exists(pName As %String) As %Boolean` — returns `$Data(^IRISCouch.DB(pName))>0`
  - [x] 1.5: Implement `ClassMethod ValidateName(pName As %String) As %Status` — validates CouchDB naming rules (see Dev Notes)
  - [x] 1.6: Compile and verify no errors

- [x] Task 2: Create `IRISCouch.API.DatabaseHandler` class (AC: #1, #2, #3, #4, #5)
  - [x] 2.1: Create `src/IRISCouch/API/DatabaseHandler.cls` extending `%RegisteredObject`
  - [x] 2.2: Implement `ClassMethod HandleCreate(pDB As %String) As %Status` — validates name, checks existence, calls Storage.Database.Create(), returns 201 or 412/400
  - [x] 2.3: Implement `ClassMethod HandleDelete(pDB As %String) As %Status` — checks existence, calls Storage.Database.Delete(), returns 200 or 404
  - [x] 2.4: Use `RenderInternal()` in catch blocks with subsystem reason `"database: create error"` / `"database: delete error"`
  - [x] 2.5: Compile and verify no errors

- [x] Task 3: Add routes to Router (AC: #1, #3)
  - [x] 3.1: Add `<Route Url="/:db" Method="PUT" Call="HandleDatabaseCreate" />` to UrlMap — MUST be placed AFTER all underscore-prefixed routes (/_uuids, etc.) to avoid capturing system endpoints
  - [x] 3.2: Add `<Route Url="/:db" Method="DELETE" Call="HandleDatabaseDelete" />` to UrlMap
  - [x] 3.3: Create local wrapper `ClassMethod HandleDatabaseCreate(pDB As %String) As %Status` that delegates to `DatabaseHandler.HandleCreate(pDB)`
  - [x] 3.4: Create local wrapper `ClassMethod HandleDatabaseDelete(pDB As %String) As %Status` that delegates to `DatabaseHandler.HandleDelete(pDB)`
  - [x] 3.5: Compile Router and verify no errors

- [x] Task 4: Create `IRISCouch.Test.DatabaseTest` unit tests (AC: #1, #2, #3, #4, #5, #6)
  - [x] 4.1: Create `src/IRISCouch/Test/DatabaseTest.cls` extending `%UnitTest.TestCase`
  - [x] 4.2: Implement `OnBeforeOneTest` to clean `^IRISCouch.DB("testdb")` and related globals
  - [x] 4.3: Implement `OnAfterOneTest` to clean up test data
  - [x] 4.4: `TestCreateDatabase` — call Storage.Database.Create("testdb"), verify `^IRISCouch.DB("testdb")` exists with expected metadata
  - [x] 4.5: `TestCreateDatabaseAlreadyExists` — create, then create again, verify second returns error status
  - [x] 4.6: `TestDeleteDatabase` — create then delete, verify `^IRISCouch.DB("testdb")` is gone and associated globals are killed
  - [x] 4.7: `TestDeleteDatabaseNotFound` — delete non-existent, verify error status
  - [x] 4.8: `TestValidateNameValid` — verify lowercase, hyphens, underscores, numbers, leading underscore (system dbs) all pass
  - [x] 4.9: `TestValidateNameInvalid` — verify uppercase, spaces, special chars all fail
  - [x] 4.10: Compile and run all tests

- [x] Task 5: Add HTTP integration tests (AC: #1, #2, #3, #4, #5)
  - [x] 5.1: Add tests to `HttpIntegrationTest` or create `IRISCouch.Test.DatabaseHttpTest`
  - [x] 5.2: `TestCreateDatabaseHttp` — `PUT /testdb_http` returns 201, body `{"ok":true}`
  - [x] 5.3: `TestCreateDatabaseAlreadyExistsHttp` — second PUT returns 412, error `file_exists`
  - [x] 5.4: `TestDeleteDatabaseHttp` — `DELETE /testdb_http` returns 200, body `{"ok":true}`
  - [x] 5.5: `TestDeleteDatabaseNotFoundHttp` — DELETE non-existent returns 404, error `not_found`
  - [x] 5.6: `TestInvalidDatabaseNameHttp` — `PUT /UPPERCASE` returns 400, error `illegal_database_name`
  - [x] 5.7: Clean up test databases in `OnAfterOneTest`

- [x] Task 6: Run full test suite and verify
  - [x] 6.1: All existing 30 tests pass (zero regressions)
  - [x] 6.2: All new unit + integration tests pass

## Dev Notes

### Database Name Validation Rules (CouchDB compatible)

Valid names must match: `^[a-z][a-z0-9_$()+/-]*$` OR start with `_` for system databases (`_replicator`, `_users`, `_global_changes`).

Invalid names:
- Empty string
- Contains uppercase letters (A-Z)
- Starts with a number (unless special chars follow per CouchDB)
- Contains spaces, colons, backslashes, wildcards (`*`, `?`)
- Actually, CouchDB rules: must begin with lowercase letter, rest can be lowercase, digits, `_`, `$`, `(`, `)`, `+`, `-`, `/`
- Exception: names starting with `_` are reserved for system databases

### Global Structure for Database Metadata

```
^IRISCouch.DB(dbName) = $ListBuild(createdTimestamp, docCount, updateSeq, diskSize, purgeSeq, revsLimit)
```

Or use subscripts for clearer access:
```
^IRISCouch.DB(dbName, "created") = $ZDateTime($Horolog, 3)
^IRISCouch.DB(dbName, "doc_count") = 0
^IRISCouch.DB(dbName, "update_seq") = 0
^IRISCouch.DB(dbName, "disk_size") = 0
^IRISCouch.DB(dbName, "purge_seq") = 0
^IRISCouch.DB(dbName, "revs_limit") = 1000
```

Use subscripted approach for readability and individual field updates (doc_count, update_seq will change frequently in later epics).

### Associated Globals to Initialize on Create / Kill on Delete

| Global | Purpose | Init Value |
|--------|---------|------------|
| `^IRISCouch.DB(db, ...)` | Database metadata | Subscript nodes above |
| `^IRISCouch.Docs(db)` | Document storage | Empty (no init needed) |
| `^IRISCouch.Tree(db)` | Revision trees | Empty (no init needed) |
| `^IRISCouch.Changes(db)` | Changes feed | Empty (no init needed) |
| `^IRISCouch.Seq(db)` | Sequence counter | 0 |

On delete, use `Kill ^IRISCouch.DB(db)`, `Kill ^IRISCouch.Docs(db)`, `Kill ^IRISCouch.Tree(db)`, `Kill ^IRISCouch.Changes(db)`, `Kill ^IRISCouch.Seq(db)` to remove all data for the database.

### Architecture Pattern Compliance

**Pattern 2 (Handler Signature):** `HandleCreate(pDB As %String) As %Status` — pDB is first param, Try/Catch wraps logic, returns %Status.

**Pattern 3 (Storage Encapsulation):** ALL `^IRISCouch.*` access in `Storage.Database` only. DatabaseHandler calls Storage methods, never touches globals directly.

**Pattern 1 (Error Envelope):** Use `Error.Render()` for 400/404/412 errors. Use `Error.RenderInternal()` for 500s in catch blocks.

**Router Wrapper Pattern:** Every UrlMap route needs a local wrapper method on Router delegating to the handler class. The wrapper receives `pDB` from the URL regex capture.

### UrlMap Route Ordering (CRITICAL)

Routes with `/:db` capture pattern MUST come AFTER all literal routes starting with `/_` (like `/_uuids`). `%CSP.REST` evaluates routes top-to-bottom and the first match wins. If `/:db` is first, a request to `/_uuids` would match `:db = "_uuids"` instead of the UUID handler.

Current route order to maintain:
```xml
<Routes>
  <!-- System endpoints first (literal matches) -->
  <Route Url="/_uuids" Method="GET" Call="HandleUUIDs" />
  <!-- Database endpoints (parameterized - MUST be after system routes) -->
  <Route Url="/:db" Method="PUT" Call="HandleDatabaseCreate" />
  <Route Url="/:db" Method="DELETE" Call="HandleDatabaseDelete" />
  <!-- Welcome endpoint last (catch-all for GET /) -->
  <Route Url="/" Method="GET" Call="HandleWelcome" />
</Routes>
```

### Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `src/IRISCouch/Storage/Database.cls` | **Create** | Storage layer for `^IRISCouch.DB` globals |
| `src/IRISCouch/API/DatabaseHandler.cls` | **Create** | HTTP handler for PUT/DELETE /{db} |
| `src/IRISCouch/API/Router.cls` | **Modify** | Add /{db} routes + wrapper methods |
| `src/IRISCouch/Test/DatabaseTest.cls` | **Create** | Unit tests for Storage.Database and DatabaseHandler |
| `src/IRISCouch/Test/DatabaseHttpTest.cls` | **Create** | HTTP integration tests for database endpoints |

### Existing Code to Reuse

- `IRISCouch.Util.Error` — `Render()`, `RenderInternal()`, slug constants (`..#FILEEXISTS`, `..#NOTFOUND`, `..#BADREQUEST`)
- `IRISCouch.Util.Response` — `JSONStatus(201, {"ok":true})` for create success, `JSON({"ok":true})` for delete success
- `IRISCouch.Test.HttpIntegrationTest.MakeRequest()` — reuse for HTTP integration tests
- Error slug `"illegal_database_name"` needs to be added to `Error.cls` if not present — check first

### Previous Story Intelligence (Story 2.0)

- 30 tests passing across 6 test classes
- ServerHandler catch blocks now use `RenderInternal()` — follow same pattern in DatabaseHandler
- `HttpIntegrationTest.MakeRequest()` supports GET, PUT, DELETE, POST — ready for database endpoint tests
- Router uses local wrapper methods for UrlMap Call dispatch — NEVER use `Call="ClassName:Method"` cross-class syntax
- After `RenderInternal()`, always `Quit $$$OK` not `Quit tSC` to avoid %CSP.REST overlay

### Error Slug: illegal_database_name

Check if `Error.cls` already has an `ILLEGALDATABASENAME` parameter. If not, add:
```objectscript
Parameter ILLEGALDATABASENAME = "illegal_database_name";
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.1]
- [Source: _bmad-output/planning-artifacts/architecture.md#Pattern 2, Pattern 3]
- [Source: _bmad-output/planning-artifacts/prd.md#Error Slug Table]
- [Source: src/IRISCouch/API/Router.cls] — UrlMap to extend
- [Source: src/IRISCouch/Util/Error.cls] — error slug constants
- [Source: src/IRISCouch/Util/Response.cls] — JSONStatus for 201
- [Source: src/IRISCouch/Test/HttpIntegrationTest.cls] — MakeRequest helper to reuse
- [Memory: feedback_router_wrapper_pattern.md] — Every route needs local wrapper
- [Memory: feedback_catch_block_pattern.md] — Return $$$OK after RenderInternal
- [Memory: feedback_compile_after_edit.md] — Compile with 'ck' flags

### Review Findings

- [x] [Review][Patch] Use Error class parameter constants instead of hardcoded slug strings in DatabaseHandler [DatabaseHandler.cls:21,26,32,40,57,62,71] -- auto-resolved
- [x] [Review][Patch] Eliminate duplicated validation reason string by extracting from ValidateName status [DatabaseHandler.cls:21] -- auto-resolved
- [x] [Review][Defer] Race condition between Exists() and Create() in HandleCreate [DatabaseHandler.cls:25-28] -- deferred, pre-existing concurrency pattern
- [x] [Review][Defer] No maximum database name length validation [Storage/Database.cls:88-136] -- deferred, not in story AC

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- Compilation error: ObjectScript pattern match `'? 1(1L, 1N, 1"$", 1"(", ...)` fails due to parenthesis ambiguity. Resolved by using `$Find` against a valid characters string parameter instead.
- HTTP integration tests initially failed because webapp runs in IRISCOUCH namespace but tests/globals were in HSCUSTOM. Resolved by running tests in IRISCOUCH namespace.
- Two existing HttpIntegrationTest tests (TestNotFoundEndpoint, TestParameterizedRoutePattern) updated from expecting 404 to 405, since `/:db` PUT/DELETE routes now catch those URLs and %CSP.REST returns 405 for unsupported methods on matched routes.

### Completion Notes List
- Created `IRISCouch.Storage.Database` with Create, Delete, Exists, ValidateName class methods. Uses subscripted globals for metadata as specified in Dev Notes.
- Created `IRISCouch.API.DatabaseHandler` with HandleCreate (PUT /{db}) and HandleDelete (DELETE /{db}). Follows Pattern 2 (handler signature), Pattern 3 (storage encapsulation), and Pattern 1 (error envelope).
- Added `ILLEGALDATABASENAME` parameter to `IRISCouch.Util.Error`.
- Added PUT and DELETE `/:db` routes to Router after system `/_uuids` route but before catch-all `/`. Created local wrapper methods per router wrapper pattern.
- Updated 2 existing HttpIntegrationTest tests for expected behavior change (404 -> 405 on GET to db-like paths).
- 6 new unit tests in DatabaseTest covering create, delete, exists, validate name.
- 5 new HTTP integration tests in DatabaseHttpTest covering all acceptance criteria via live HTTP.
- Full suite: 41 tests across 8 classes, all passing, zero regressions.

### Change Log
- 2026-04-12: Story 2.1 implementation complete. Created Storage.Database, API.DatabaseHandler, DatabaseTest, DatabaseHttpTest. Modified Router.cls, Error.cls, HttpIntegrationTest.cls.

### File List
- `src/IRISCouch/Storage/Database.cls` (NEW) - Storage layer for database lifecycle globals
- `src/IRISCouch/API/DatabaseHandler.cls` (NEW) - HTTP handler for PUT/DELETE /{db}
- `src/IRISCouch/API/Router.cls` (MODIFIED) - Added /:db PUT/DELETE routes and wrapper methods
- `src/IRISCouch/Util/Error.cls` (MODIFIED) - Added ILLEGALDATABASENAME parameter
- `src/IRISCouch/Test/DatabaseTest.cls` (NEW) - Unit tests for Storage.Database
- `src/IRISCouch/Test/DatabaseHttpTest.cls` (NEW) - HTTP integration tests for database endpoints
- `src/IRISCouch/Test/HttpIntegrationTest.cls` (MODIFIED) - Updated 2 tests for new routing behavior (404 -> 405)
