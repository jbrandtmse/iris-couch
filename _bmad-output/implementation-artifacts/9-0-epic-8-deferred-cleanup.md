# Story 9.0: Epic 8 Deferred Cleanup

Status: done

## Story

As a developer,
I want to address audit findings from the Epic 8 retrospective codebase audit,
so that Epic 9 (Observability & Audit Trail) builds on correct foundations.

## Acceptance Criteria

1. **Given** the `DocumentEngine.SaveDeleted()` method
   **When** a document is deleted from the `_users` database
   **Then** the `OnUserDocDelete` hook runs BEFORE `Winners.Upsert` clears the body

2. **Given** a new database is created via `Storage.Database.Create()`
   **When** the `created` timestamp is stored
   **Then** it is in ISO-8601 format with T separator and Z suffix (e.g., `2026-04-14T10:30:45Z`)

3. **Given** a database is deleted via `Storage.Database.Delete()`
   **When** any cleanup call fails
   **Then** the error is captured (not silently discarded) and cleanup continues best-effort

4. **Given** all changes are compiled
   **When** the full test suite runs
   **Then** all existing tests pass with 0 failures and 0 regressions

## Tasks / Subtasks

- [x] Task 1: Fix SaveDeleted _users hook ordering (AC: #1)
  - [x] Read `src/IRISCouch/Core/DocumentEngine.cls` SaveDeleted method (starts at line 357)
  - [x] Current step ordering at lines 376-419:
    - Steps 1-5: tombstone write, rev tree, changes feed, metadata
    - Step 6 (line 408-410): _replicator hook (CORRECT — before Winners)
    - Step 7 (line 412): Winners.Upsert (clears body to "")
    - Step 8 (line 414): MangoIndex.DeleteForDocument
    - Step 9 (line 417-419): _users hook (WRONG — after body cleared)
  - [x] Move the _users hook (step 9) to BEFORE Winners.Upsert, directly after the _replicator hook:
    ```
    Step 6: _replicator hook (line 408-410) — keep as-is
    Step 7: _users hook (MOVED from step 9)
    Step 8: Winners.Upsert
    Step 9: MangoIndex.DeleteForDocument
    ```
  - [x] Renumber step comments accordingly
  - [x] Compile via MCP

- [x] Task 2: Fix ISO-8601 timestamp in Database.Create() (AC: #2)
  - [x] Read `src/IRISCouch/Storage/Database.cls` line 27
  - [x] Current code: `Set ^IRISCouch.DB(pName, "created") = $ZDateTime($Horolog, 3)`
  - [x] Fix to: `Set ^IRISCouch.DB(pName, "created") = $Translate($ZDateTime($Horolog, 3, 1), " ", "T") _ "Z"`
  - [x] Compile via MCP

- [x] Task 3: Add status checking to Database.Delete() cleanup calls (AC: #3)
  - [x] Read `src/IRISCouch/Storage/Database.cls` Delete() method (lines 61-75)
  - [x] Current code uses `Do` (discards status) for 6 cleanup calls at lines 67-75:
    ```objectscript
    Do ##class(IRISCouch.Storage.Attachment).CleanupDatabase(pName)
    Do ##class(IRISCouch.Projection.Winners).DeleteAll(pName)
    Do ##class(IRISCouch.Projection.MangoIndex).DeleteAll(pName)
    Do ##class(IRISCouch.Projection.MangoIndexDef).DeleteAll(pName)
    Do ##class(IRISCouch.Auth.Security).Delete(pName)
    Do ##class(IRISCouch.Storage.Local).DeleteAll(pName)
    ```
  - [x] Change to best-effort pattern: check each status, accumulate errors, continue cleanup:
    ```objectscript
    Set tErrors = ""
    Set tSC2 = ##class(IRISCouch.Storage.Attachment).CleanupDatabase(pName)
    If $$$ISERR(tSC2) Set tErrors = tErrors _ "Attachment cleanup failed; "
    Set tSC2 = ##class(IRISCouch.Projection.Winners).DeleteAll(pName)
    If $$$ISERR(tSC2) Set tErrors = tErrors _ "Winners cleanup failed; "
    ; ... etc for all 6 calls ...
    If tErrors '= "" {
        Set tSC = $$$ERROR($$$GeneralError, "Database deletion had cleanup errors: " _ tErrors)
    }
    ```
  - [x] Compile via MCP

- [x] Task 4: Add unit test for timestamp format (AC: #2)
  - [x] In existing `src/IRISCouch/Test/DatabaseTest.cls`, add `TestCreateTimestampFormat()`:
    - Create a database
    - Read the `created` field from `^IRISCouch.DB(db, "created")`
    - Assert it contains "T" separator and ends with "Z"
    - Clean up
  - [x] Compile and run tests

- [x] Task 5: Full regression (AC: #4)
  - [x] Run all test classes — verify all existing tests pass, 0 regressions

## Dev Notes

### SaveDeleted Hook Ordering Fix

The _replicator delete hook was correctly placed before Winners.Upsert in Story 8.5's code review. But the _users delete hook (from Story 7.3) was never reordered. Both hooks should run before Winners.Upsert clears the body.

Currently `OnUserDocDelete` only uses `pDocId` (extracts username from doc ID format `org.couchdb.user:alice`), so it doesn't actually need the body today. But the ordering is architecturally wrong and fragile — if the hook ever needs body data, it would silently get empty string.

### ISO-8601 Timestamp

`$ZDateTime($Horolog, 3)` produces `"2026-04-14 10:30:45"` (space, no TZ).
`$Translate($ZDateTime($Horolog, 3, 1), " ", "T") _ "Z"` produces `"2026-04-14T10:30:45Z"`.

This same fix was applied in `Replication/Manager.cls` during Story 8.5.

### Database.Delete() Best-Effort Pattern

The 6 cleanup calls should continue even if one fails (e.g., attachment cleanup fails but we still want to delete MangoIndex data). Use best-effort: capture each error, continue, then return aggregated error at end.

### Storage Methods Used

- `Storage.Database.cls` — Create() line 27, Delete() lines 61-75
- `DocumentEngine.cls` — SaveDeleted() lines 376-419

### References

- [Source: _bmad-output/implementation-artifacts/epic-8-retro-2026-04-13.md#Action Items — retro audit findings]
- [Source: src/IRISCouch/Core/DocumentEngine.cls:408-419 — SaveDeleted hook ordering]
- [Source: src/IRISCouch/Storage/Database.cls:27 — Create() timestamp]
- [Source: src/IRISCouch/Storage/Database.cls:67-75 — Delete() cleanup calls]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

No debug globals needed — all changes were straightforward edits verified by compilation and test execution.

### Completion Notes List

- Task 1: Moved _users delete hook (OnUserDocDelete) from step 9 to step 7 in SaveDeleted(), placing it before Winners.Upsert (step 8). Renumbered steps 7-9 accordingly. Both _replicator and _users hooks now execute before body is cleared.
- Task 2: Changed timestamp format in Database.Create() from `$ZDateTime($Horolog, 3)` to `$Translate($ZDateTime($Horolog, 3, 1), " ", "T") _ "Z"` producing ISO-8601 format (e.g., `2026-04-14T10:30:45Z`).
- Task 3: Converted 5 of 6 cleanup calls in Database.Delete() from `Do` to `Set tSC2 =` with `$$$ISERR` checks and error accumulation. Auth.Security.Delete was kept as `Do` because it has no return value (method signature has no return type — it only does `Kill ^IRISCouch.Security(pDB)`). All other 5 methods return %Status and are now checked.
- Task 4: Added TestCreateTimestampFormat() test to DatabaseTest.cls — verifies created timestamp contains "T" separator, ends with "Z", is 20 characters, and T is at position 11.
- Task 5: Full regression across 12 test classes (107 tests total), all passed with 0 failures.

### File List

- src/IRISCouch/Core/DocumentEngine.cls (modified — reordered _users hook in SaveDeleted)
- src/IRISCouch/Storage/Database.cls (modified — ISO-8601 timestamp, best-effort cleanup)
- src/IRISCouch/Test/DatabaseTest.cls (modified — added TestCreateTimestampFormat)

### Change Log

- 2026-04-13: Story 9.0 implementation — 3 audit fixes from Epic 8 retrospective: SaveDeleted hook reordering, ISO-8601 timestamp fix, Database.Delete() best-effort error capture. Added timestamp format unit test. All tests pass.

### Review Findings

- [x] [Review][Defer] $Horolog returns local time but timestamps append "Z" (UTC) suffix [Storage/Database.cls:27, Replication/Manager.cls:70,170] — deferred, pre-existing pattern from Story 8.5
