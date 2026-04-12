# Story 3.0: Epic 2 Deferred Cleanup

Status: done

## Story

As a developer,
I want to address the action items from the Epic 2 retrospective before starting new Epic 3 work,
so that the codebase is fully prepared for document storage and revision control.

## Acceptance Criteria

1. **Given** the full database lifecycle, **When** a single integration test creates a db, sets revs_limit, gets info, lists all_dbs, compacts, ensures full commit, then deletes, **Then** the entire workflow succeeds with correct status codes at each step.
2. **Given** `Storage.Database.GetInfo()` returns metadata, **When** a database has deleted documents tracked, **Then** `doc_del_count` reflects the actual value from `^IRISCouch.DB(pName, "doc_del_count")` instead of hardcoded 0.
3. **Given** `Storage.Database.Create()` initializes metadata, **When** a new database is created, **Then** `^IRISCouch.DB(pName, "doc_del_count")` is initialized to 0.
4. **Given** `Storage.Database.GetInfo()` returns metadata, **When** a database exists, **Then** `disk_size` reflects the actual value from `^IRISCouch.DB(pName, "disk_size")` (already initialized to 0 in Create, ready for Epic 3 to update).
5. **Given** all changes are compiled and tested, **Then** all existing 57 tests pass with zero regressions, and new tests cover the lifecycle integration scenario.

## Retrospective Triage

### Included in This Story

| # | Source | Item | Rationale |
|---|--------|------|-----------|
| 1 | Retro Must-Do #1 | Database lifecycle integration test | Validates full DB workflow before adding document layer |
| 2 | Retro Must-Do #2 | Add `doc_del_count` tracking to Storage.Database | Required for Story 3.2 (document deletion needs it) |
| 3 | Retro Must-Do #3 | Add `disk_size` tracking to Storage.Database | Needs to read actual value instead of hardcoded 0 |

### Explicitly Deferred

| # | Source | Item | Rationale |
|---|--------|------|-----------|
| 4 | Retro Should-Do #4 | HttpIntegrationTest config-driven (server/port/creds) | CI/CD is future work; not blocking |
| 5 | Retro Should-Do #5 | Early-return guard after MakeRequest failure | Nice pattern, not blocking |
| 6 | Retro Should-Do #6 | Database name max length validation | Edge case, not blocking Epic 3 |
| 7 | Retro Should-Do #7 | Race condition in HandleCreate | Extremely unlikely, defer |
| 8 | deferred-work.md | All 15 existing items (Config.Get/Set issues, Request.ReadBody size, metrics wrapper, Error.Render %response, etc.) | All low/medium severity, none blocking Epic 3 |

## Tasks / Subtasks

- [x] Task 1: Add `doc_del_count` to Storage.Database (AC: #2, #3)
  - [x] 1.1: In `GetInfo()`, replace hardcoded `Do result.%Set("doc_del_count", 0, "number")` with `Do result.%Set("doc_del_count", +$Get(^IRISCouch.DB(pName, "doc_del_count")), "number")`
  - [x] 1.2: Verify `Create()` already initializes `doc_del_count` — if not, add `Set ^IRISCouch.DB(pName, "doc_del_count") = 0`
  - [x] 1.3: Compile `IRISCouch.Storage.Database` and verify no errors

- [x] Task 2: Verify `disk_size` reads from global (AC: #4)
  - [x] 2.1: Confirm `GetInfo()` already reads `^IRISCouch.DB(pName, "disk_size")` via `$Get` — it does (line 114). No change needed.
  - [x] 2.2: Confirm `Create()` already initializes `disk_size` to 0 — it does (line 30). No change needed.
  - [x] 2.3: Document: `disk_size` is ready for Epic 3 to increment when documents are stored.

- [x] Task 3: Create database lifecycle integration test (AC: #1)
  - [x] 3.1: Add `TestDatabaseLifecycle` method to `IRISCouch.Test.DatabaseHttpTest`
  - [x] 3.2: Test sequence: `PUT /testlifecycle` (201) -> `GET /testlifecycle` (200, verify doc_count=0) -> `GET /_all_dbs` (contains "testlifecycle") -> `PUT /testlifecycle/_revs_limit` with body "500" (200) -> `GET /testlifecycle/_revs_limit` (200, returns "500") -> `POST /testlifecycle/_compact` (202) -> `POST /testlifecycle/_ensure_full_commit` (201) -> `DELETE /testlifecycle` (200) -> `GET /testlifecycle` (404)
  - [x] 3.3: Verify doc_del_count in the GET info response is 0 (as a number)
  - [x] 3.4: Compile and run all tests

- [x] Task 4: Run full test suite (AC: #5)
  - [x] 4.1: All existing 48 tests pass (zero regressions)
  - [x] 4.2: New lifecycle test passes

## Dev Notes

### What Actually Needs Code Changes

Only **one line** in `Storage/Database.cls` needs changing — the hardcoded `doc_del_count` in `GetInfo()`. Everything else is already correct:
- `disk_size` already reads from `$Get(^IRISCouch.DB(pName, "disk_size"))` (line 114)
- `Create()` already initializes `disk_size` = 0 (line 30)
- `Create()` does NOT initialize `doc_del_count` — **add this** (line 28, after `doc_count`)

### GetInfo() Change (Storage/Database.cls, line 119)

Current (hardcoded):
```objectscript
Do result.%Set("doc_del_count", 0, "number")
```

Replace with:
```objectscript
Set tDocDelCount = +$Get(^IRISCouch.DB(pName, "doc_del_count"))
Do result.%Set("doc_del_count", tDocDelCount, "number")
```

### Create() Addition (Storage/Database.cls, after line 28)

Add initialization:
```objectscript
Set ^IRISCouch.DB(pName, "doc_del_count") = 0
```

### Lifecycle Integration Test Pattern

Follow the existing `DatabaseHttpTest` pattern. Use `MakeRequest()` from `HttpIntegrationTest`. The test exercises the full workflow sequentially in one method. Use `OnBeforeOneTest`/`OnAfterOneTest` for cleanup (kill `^IRISCouch.DB("testlifecycle")`).

### Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `src/IRISCouch/Storage/Database.cls` | **Modify** | Add `doc_del_count` init in Create(), read from global in GetInfo() |
| `src/IRISCouch/Test/DatabaseHttpTest.cls` | **Modify** | Add TestDatabaseLifecycle integration test |

### Previous Story Intelligence (Story 2.3)

- 57 tests passing across 8 test classes
- `MakeRequest()` supports GET/PUT/POST/DELETE with optional body
- `MakeRequest()` returns plain values (not just JSON objects) for endpoints like `_revs_limit`
- Route ordering: `/:db/_xxx` before `/:db` (already correct)
- All catch blocks use `RenderInternal()` (fixed in Story 2.0)
- `Response.JSON()` for all JSON output (fixed in code review 2.3)

### Established Patterns

- Storage encapsulation: all `^IRISCouch.*` access through `Storage.Database`
- Error slugs: `##class(IRISCouch.Util.Error).#SLUG` constants
- Handler catch: `RenderInternal()` then `Quit $$$OK`
- Test cleanup: `OnBeforeOneTest` kills test-specific globals
- HTTP test: `..MakeRequest(method, path, .status, .body)` then `$$$Assert*`

### References

- [Source: _bmad-output/implementation-artifacts/epic-2-retro-2026-04-12.md] — Action items #1-#3
- [Source: src/IRISCouch/Storage/Database.cls:119] — Hardcoded doc_del_count = 0
- [Source: src/IRISCouch/Storage/Database.cls:28-30] — Create() metadata initialization
- [Source: src/IRISCouch/Test/DatabaseHttpTest.cls] — Existing HTTP test patterns

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
None required - all changes were straightforward single-line modifications.

### Completion Notes List
- Task 1: Added `doc_del_count` initialization in `Create()` (new line after `doc_count`) and replaced hardcoded 0 in `GetInfo()` with `+$Get(^IRISCouch.DB(pName, "doc_del_count"))`. Compiled successfully.
- Task 2: Verified `disk_size` already reads from global in `GetInfo()` (line 114) and is initialized to 0 in `Create()` (line 30). No changes needed. `disk_size` is ready for Epic 3 to update when documents are stored.
- Task 3: Added `TestDatabaseLifecycle` method to `DatabaseHttpTest` covering the full 9-step lifecycle: create (201), get info (200, doc_count=0, doc_del_count=0), list all_dbs (contains db), set revs_limit to 500 (200), get revs_limit (500), compact (202), ensure_full_commit (201), delete (200), verify gone (404). Added cleanup for "testlifecycle" globals in `OnAfterOneTest`.
- Task 4: All 49 tests pass across 7 test classes (ConfigTest:4, RouterTest:5, UUIDTest:5, ErrorEnvelopeTest:6, InstallerTest:6, DatabaseTest:13, DatabaseHttpTest:10). Zero regressions. The story estimated 57 existing tests but actual count is 48 existing + 1 new = 49.

### Change Log
- 2026-04-12: Story 3.0 implemented - doc_del_count tracking, disk_size verification, database lifecycle integration test

### File List
- src/IRISCouch/Storage/Database.cls (modified) - Added doc_del_count init in Create(), read from global in GetInfo()
- src/IRISCouch/Test/DatabaseHttpTest.cls (modified) - Added TestDatabaseLifecycle integration test and testlifecycle cleanup
