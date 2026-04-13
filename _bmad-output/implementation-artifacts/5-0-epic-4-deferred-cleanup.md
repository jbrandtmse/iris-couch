# Story 5.0: Epic 4 Deferred Cleanup

Status: done

## Story

As a developer,
I want to resolve all deferred technical debt from Epic 4 before starting new Epic 5 features,
so that the codebase remains clean, encapsulated, and maintainable as we add binary attachment management.

## Acceptance Criteria

1. Event name helper method exists in a shared location; all 4 duplicate event resource name constructions replaced with single helper call
2. DocumentEngine no longer directly writes to `^IRISCouch.Changes`, `^IRISCouch.Seq`, or `^IRISCouch.DB` globals — all access goes through Storage class methods
3. BulkHandler inner try/catch parse block uses `Return $$$OK` instead of `Quit` to prevent fall-through on JSON parse failure
4. RevTree.GetRevsInfo no longer cross-references `^IRISCouch.Docs` directly — uses Storage.Document method instead
5. All 162 existing tests still pass with zero regressions
6. New unit tests cover the refactored Storage methods (at least 2 new tests)

## Triage Table (Epic 4 Retro + Deferred Work)

| # | Item | Disposition | Rationale |
|---|------|------------|-----------|
| 1 | Extract event name helper (4 locations) | **Include** | HIGH from retro; reduces duplication, prevents drift |
| 2 | Encapsulate DocumentEngine global access (Changes/Seq/DB) | **Include** | HIGH from retro; largest storage encapsulation gap |
| 3 | Add Return-from-nested-block guideline | **Include** | HIGH from retro; fix BulkHandler + document pattern |
| 4 | RevTree.GetRevsInfo accesses `^IRISCouch.Docs` directly | **Include** | Storage encapsulation violation |
| 5 | Test files directly Kill `^IRISCouch.*` globals | **Defer** | Low risk, test-only code, acceptable for test isolation |
| 6 | Missing test: _selector filter with deleted docs | **Defer** | Low, edge case, can add in future story |
| 7 | No test for unsupported feed mode 400 response | **Defer** | Low, simple error path |
| 8 | Pre-existing storage encapsulation items (HandleGet, HandleAllDocs, SaveDeleted D-marker) | **Defer** | Medium, not blocking Epic 5, can address incrementally |

## Tasks / Subtasks

- [x] Task 1: Extract event name helper method (AC: #1)
  - [x] 1.1 Create `ClassMethod EventResourceName(pDB As %String) As %String` in `IRISCouch.Storage.Changes`
  - [x] 1.2 Method returns `"^IRISCouch.LPChanges(""" _ pDB _ """)"`
  - [x] 1.3 Replace in `DocumentEngine.Save()` (line ~78)
  - [x] 1.4 Replace in `DocumentEngine.SaveDeleted()` (line ~162)
  - [x] 1.5 Replace in `DocumentEngine.SaveWithHistory()` (line ~259)
  - [x] 1.6 Replace in `ChangesHandler.HandleChanges()` (line ~114)
  - [x] 1.7 Compile all modified classes and verify

- [x] Task 2: Encapsulate DocumentEngine global access (AC: #2)
  - [x] 2.1 Add `ClassMethod RecordChange(pDB, pDocId, pRev) As %Integer` to `Storage.Changes` — increments `^IRISCouch.Seq`, writes `^IRISCouch.Changes`, returns new seq
  - [x] 2.2 Add `ClassMethod IncrementDocCount(pDB, pDelta As %Integer = 1)` to `Storage.Database` — wraps `$Increment(^IRISCouch.DB(pDB, "doc_count"), pDelta)`
  - [x] 2.3 Add `ClassMethod IncrementDelCount(pDB)` to `Storage.Database` — wraps `$Increment(^IRISCouch.DB(pDB, "doc_del_count"))`
  - [x] 2.4 Add `ClassMethod SetUpdateSeq(pDB, pSeq)` to `Storage.Database` — wraps `Set ^IRISCouch.DB(pDB, "update_seq") = pSeq`
  - [x] 2.5 Refactor `DocumentEngine.Save()` lines 65-72 to use Storage methods
  - [x] 2.6 Refactor `DocumentEngine.SaveDeleted()` lines 149-156 to use Storage methods
  - [x] 2.7 Refactor `DocumentEngine.SaveWithHistory()` lines 246-253 to use Storage methods
  - [x] 2.8 Compile and verify all classes

- [x] Task 3: Fix BulkHandler inner catch Quit (AC: #3)
  - [x] 3.1 In `BulkHandler.HandleBulkDocs()` lines 33-38, change `Quit` to `Return $$$OK` in the inner catch block
  - [x] 3.2 Compile BulkHandler

- [x] Task 4: Fix RevTree.GetRevsInfo storage encapsulation (AC: #4)
  - [x] 4.1 Add `ClassMethod DocumentExists(pDB, pDocId, pRev) As %Boolean` to `Storage.Document` — wraps `$Data(^IRISCouch.Docs(pDB, pDocId, pRev))`
  - [x] 4.2 In `RevTree.GetRevsInfo()` line ~227, replace `$Data(^IRISCouch.Docs(...))` with `##class(IRISCouch.Storage.Document).DocumentExists(...)`
  - [x] 4.3 Compile both classes

- [x] Task 5: Add unit tests for new Storage methods (AC: #5, #6)
  - [x] 5.1 Add test for `Storage.Changes.RecordChange()` — verify seq increment and change entry written
  - [x] 5.2 Add test for `Storage.Changes.EventResourceName()` — verify format
  - [x] 5.3 Run full test suite — confirm 169 tests pass, 0 regressions

## Dev Notes

### Critical Patterns to Follow

- **Storage encapsulation rule**: No code outside `Storage.*` classes may reference `^IRISCouch.*` globals directly (see memory: `feedback_storage_encapsulation.md`)
- **Catch block pattern**: After `Error.Render()`, return `$$$OK` not `ex.AsStatus()` to avoid `%CSP.REST` overlay (see memory: `feedback_catch_block_pattern.md`)
- **Return vs Quit in nested blocks**: Use `Return $$$OK` to exit from inner try/catch blocks, never `Quit` (which only exits the catch, not the method)

### Source Files to Modify

| File | Path | Changes |
|------|------|---------|
| DocumentEngine.cls | `src/IRISCouch/Core/DocumentEngine.cls` | Replace 3 direct global blocks + 3 event name strings with Storage calls |
| Storage/Changes.cls | `src/IRISCouch/Storage/Changes.cls` | Add `RecordChange()` and `EventResourceName()` methods |
| Storage/Database.cls | `src/IRISCouch/Storage/Database.cls` | Add `IncrementDocCount()`, `IncrementDelCount()`, `SetUpdateSeq()` methods |
| Storage/Document.cls | `src/IRISCouch/Storage/Document.cls` | Add `DocumentExists()` method |
| Storage/RevTree.cls | `src/IRISCouch/Storage/RevTree.cls` | Replace `$Data(^IRISCouch.Docs(...))` with Storage call |
| API/BulkHandler.cls | `src/IRISCouch/API/BulkHandler.cls` | Change inner catch `Quit` to `Return $$$OK` |
| API/ChangesHandler.cls | `src/IRISCouch/API/ChangesHandler.cls` | Replace event name construction with helper call |
| Test class (new or existing) | `src/IRISCouch/Test/` | Add tests for RecordChange, EventResourceName |

### Existing Storage.Changes Methods (for reference)

Already encapsulated in `Storage.Changes`:
- `GetDocSeq(pDB, pDocId)` — find latest seq for a document
- `GetLastSeq(pDB)` — returns last sequence number
- `ReadEntry(pDB, pSeq)` — read single change entry
- `ListChanges(pDB, pSince, pLimit, pDescending)` — paginated results
- `CountSince(pDB, pSince)` — count changes after a seq

### DocumentEngine Global Access to Replace

**Save() method (lines 65-72):**
```objectscript
Set tSeq = $Increment(^IRISCouch.Seq(pDB))
Set ^IRISCouch.Changes(pDB, tSeq) = $ListBuild(pDocId, tNewRev)
If tGeneration = 1 {
    Set tCount = $Increment(^IRISCouch.DB(pDB, "doc_count"))
}
Set ^IRISCouch.DB(pDB, "update_seq") = tSeq
```
Replace with:
```objectscript
Set tSeq = ##class(IRISCouch.Storage.Changes).RecordChange(pDB, pDocId, tNewRev)
If tGeneration = 1 {
    Do ##class(IRISCouch.Storage.Database).IncrementDocCount(pDB)
}
Do ##class(IRISCouch.Storage.Database).SetUpdateSeq(pDB, tSeq)
```

**SaveDeleted() method (lines 149-156):**
```objectscript
Set tSeq = $Increment(^IRISCouch.Seq(pDB))
Set ^IRISCouch.Changes(pDB, tSeq) = $ListBuild(pDocId, tNewRev)
Set tCount = $Increment(^IRISCouch.DB(pDB, "doc_count"), -1)
Set tDelCount = $Increment(^IRISCouch.DB(pDB, "doc_del_count"))
Set ^IRISCouch.DB(pDB, "update_seq") = tSeq
```
Replace with:
```objectscript
Set tSeq = ##class(IRISCouch.Storage.Changes).RecordChange(pDB, pDocId, tNewRev)
Do ##class(IRISCouch.Storage.Database).IncrementDocCount(pDB, -1)
Do ##class(IRISCouch.Storage.Database).IncrementDelCount(pDB)
Do ##class(IRISCouch.Storage.Database).SetUpdateSeq(pDB, tSeq)
```

**SaveWithHistory() method (lines 246-253):**
```objectscript
Set tSeq = $Increment(^IRISCouch.Seq(pDB))
Set ^IRISCouch.Changes(pDB, tSeq) = $ListBuild(pDocId, pRev)
If tIsNewDoc {
    Set tCount = $Increment(^IRISCouch.DB(pDB, "doc_count"))
}
Set ^IRISCouch.DB(pDB, "update_seq") = tSeq
```
Replace with:
```objectscript
Set tSeq = ##class(IRISCouch.Storage.Changes).RecordChange(pDB, pDocId, pRev)
If tIsNewDoc {
    Do ##class(IRISCouch.Storage.Database).IncrementDocCount(pDB)
}
Do ##class(IRISCouch.Storage.Database).SetUpdateSeq(pDB, tSeq)
```

### Event Name Pattern to Extract

Current (4 locations):
```objectscript
Set tEventName = "^IRISCouch.LPChanges(""" _ pDB _ """)"
If ##class(%SYSTEM.Event).Defined(tEventName) { Do ##class(%SYSTEM.Event).Signal(tEventName) }
```
Replace with:
```objectscript
Set tEventName = ##class(IRISCouch.Storage.Changes).EventResourceName(pDB)
If ##class(%SYSTEM.Event).Defined(tEventName) { Do ##class(%SYSTEM.Event).Signal(tEventName) }
```

### BulkHandler Fix

**Current (line 37):**
```objectscript
Catch tParseEx {
    Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#BADREQUEST, "invalid UTF-8 JSON")
    Quit    ; ← BUG: exits catch only, falls through
}
```
**Fix:**
```objectscript
Catch tParseEx {
    Do ##class(IRISCouch.Util.Error).Render(400, ##class(IRISCouch.Util.Error).#BADREQUEST, "invalid UTF-8 JSON")
    Return $$$OK    ; ← exits method entirely
}
```

### RevTree.GetRevsInfo Fix

**Current (line ~227):**
```objectscript
} ElseIf $Data(^IRISCouch.Docs(pDB, pDocId, tRev)) {
```
**Fix:**
```objectscript
} ElseIf ##class(IRISCouch.Storage.Document).DocumentExists(pDB, pDocId, tRev) {
```

### Project Structure Notes

- All source files are in `src/IRISCouch/` with auto-sync to IRIS
- Compile via MCP tools with `ck` flags after edits
- Test classes go in `src/IRISCouch/Test/`
- Follow existing naming: `ClassMethod` with camelCase, `p` prefix for parameters, `t` prefix for locals

### References

- [Source: _bmad-output/implementation-artifacts/epic-4-retro-2026-04-12.md#Must-Do Action Items]
- [Source: _bmad-output/implementation-artifacts/deferred-work.md#Epic 4 Items]
- [Source: src/IRISCouch/Core/DocumentEngine.cls#Save,SaveDeleted,SaveWithHistory]
- [Source: src/IRISCouch/Storage/Changes.cls#existing methods]
- [Source: src/IRISCouch/API/BulkHandler.cls#HandleBulkDocs inner catch]
- [Source: src/IRISCouch/Storage/RevTree.cls#GetRevsInfo]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

No debug globals needed; all changes compiled and tested cleanly on first pass.

### Completion Notes List

- Task 1: Added `EventResourceName()` to Storage.Changes; replaced 4 inline event name constructions in DocumentEngine (Save, SaveDeleted, SaveWithHistory) and ChangesHandler.HandleChanges.
- Task 2: Added `RecordChange()` to Storage.Changes, `IncrementDocCount()`, `IncrementDelCount()`, `SetUpdateSeq()` to Storage.Database. Refactored all 3 DocumentEngine methods (Save, SaveDeleted, SaveWithHistory) to use Storage methods instead of direct global access.
- Task 3: Changed `Quit` to `Return $$$OK` in BulkHandler.HandleBulkDocs inner JSON parse catch block to prevent fall-through on parse failure.
- Task 4: Added `DocumentExists()` to Storage.Document; replaced `$Data(^IRISCouch.Docs(...))` in RevTree.GetRevsInfo with Storage call.
- Task 5: Created StorageCleanupTest with 7 tests covering RecordChange, EventResourceName, IncrementDocCount, IncrementDelCount, SetUpdateSeq, DocumentExists, and end-to-end Save integration. Full suite: 169 tests pass, 0 regressions.

### Review Findings

- [x] [Review][Defer] DocumentExists naming inconsistent with sibling Exists method [Storage/Document.cls:69] — deferred, naming preference not a bug; method checks revision-level existence but name implies document-level. Consider renaming to RevisionExists in a future cleanup pass.
- [x] [Review][Defer] Unused local variables in IncrementDocCount/IncrementDelCount [Storage/Database.cls:175,183] — deferred, harmless; ObjectScript requires assignment for $Increment but return values are unused. Cosmetic only.
- [x] [Review][Defer] RecordChange lacks documentation about transaction requirement [Storage/Changes.cls:150] — deferred, all current callers wrap in TSTART/TCOMMIT. Add a doc note when Storage API docs are formalized.
- [x] [Review][Defer] Test file directly kills ^IRISCouch.* globals [StorageCleanupTest.cls:22-26,34-38] — deferred, pre-existing pattern across all 24+ test files. Address project-wide when test infrastructure is refactored.

### Change Log

- 2026-04-12: Implemented Story 5.0 — Epic 4 deferred cleanup. Extracted event name helper, encapsulated DocumentEngine globals, fixed BulkHandler catch fall-through, fixed RevTree storage encapsulation. Added 7 new tests. 169 total tests pass.

### File List

- src/IRISCouch/Storage/Changes.cls (modified: added EventResourceName, RecordChange methods)
- src/IRISCouch/Storage/Database.cls (modified: added IncrementDocCount, IncrementDelCount, SetUpdateSeq methods)
- src/IRISCouch/Storage/Document.cls (modified: added DocumentExists method)
- src/IRISCouch/Core/DocumentEngine.cls (modified: replaced direct global access with Storage calls in Save, SaveDeleted, SaveWithHistory; replaced event name construction with helper)
- src/IRISCouch/API/BulkHandler.cls (modified: changed inner catch Quit to Return $$$OK)
- src/IRISCouch/API/ChangesHandler.cls (modified: replaced event name construction with EventResourceName helper)
- src/IRISCouch/Storage/RevTree.cls (modified: replaced $Data(^IRISCouch.Docs) with Storage.Document.DocumentExists call)
- src/IRISCouch/Test/StorageCleanupTest.cls (new: 7 unit tests for new Storage methods)
