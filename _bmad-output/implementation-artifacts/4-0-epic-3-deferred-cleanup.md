# Story 4.0: Epic 3 Deferred Cleanup

Status: done

## Story

As a developer,
I want to address deferred work from Epic 3 before starting Epic 4 stories,
so that the codebase is clean, encapsulated, and ready for the changes feed implementation.

## Acceptance Criteria

1. **Given** DocumentHandler.cls is currently 1009 lines, **When** the refactoring is complete, **Then** DocumentHandler.cls contains only HandlePost, HandlePut, HandleGet, HandleDelete, and ValidateFields (under 500 lines), and two new handler classes exist: BulkHandler.cls (HandleBulkDocs, HandleBulkGet) and AllDocsHandler.cls (HandleAllDocs, HandleAllDocsPost).

2. **Given** Router.cls delegates to DocumentHandler for bulk and all_docs endpoints, **When** the split is complete, **Then** Router wrapper methods delegate to BulkHandler and AllDocsHandler respectively, and all existing HTTP tests pass with zero regressions.

3. **Given** DocumentEngine.SaveDeleted sets `^IRISCouch.Tree(pDB, pDocId, "D", tNewRev) = 1` directly, **When** the encapsulation fix is applied, **Then** SaveDeleted calls `RevTree.MarkDeleted(pDB, pDocId, pRev)` instead.

4. **Given** DocumentEngine.SaveWithHistory checks `$Data(^IRISCouch.Tree(pDB, pDocId, "R", pRev))` directly, **When** the encapsulation fix is applied, **Then** SaveWithHistory calls `RevTree.RevExists(pDB, pDocId, pRev)` instead.

5. **Given** DocumentEngine.SaveWithHistory checks `$Data(^IRISCouch.Tree(pDB, pDocId))` directly, **When** the encapsulation fix is applied, **Then** SaveWithHistory calls `RevTree.TreeExists(pDB, pDocId)` instead.

6. **Given** HandleGet scans `^IRISCouch.Changes(pDB)` directly for local_seq, **When** the encapsulation fix is applied, **Then** HandleGet calls a new `Storage.Changes.GetDocSeq(pDB, pDocId)` method instead.

7. **Given** HandleAllDocs iterates `^IRISCouch.Docs(pDB)` directly via `$Order`, **When** the encapsulation fix is applied, **Then** AllDocsHandler uses `Storage.Document` methods for document iteration (the existing `$Order` loop is acceptable inside a Storage class but not in a handler/engine class).

8. **Given** RevTreeTest only tests `available` status in GetRevsInfo, **When** new tests are added, **Then** there are unit tests covering `deleted` and `missing` status paths in GetRevsInfo.

9. **Given** all changes are compiled and tested, **Then** all existing 122 tests pass with zero regressions, and new tests cover all acceptance criteria.

## Deferred Work Triage

### Included in Story 4.0

| # | Item | Source |
|---|------|--------|
| 1 | Split DocumentHandler into BulkHandler + AllDocsHandler | Epic 3 retro action #1 |
| 2 | Add Quit-in-loop coding guideline | Epic 3 retro action #2 |
| 3 | Add GetRevsInfo test coverage for deleted/missing status paths | Epic 3 retro action #3, deferred from 3.3 |
| 4 | HandleGet local_seq scans ^IRISCouch.Changes directly | Epic 3 retro storage encapsulation |
| 5 | HandleAllDocs iterates ^IRISCouch.Docs directly | Epic 3 retro storage encapsulation |
| 6 | DocumentEngine.SaveDeleted sets ^IRISCouch.Tree D-marker directly | Epic 3 retro storage encapsulation |
| 7 | DocumentEngine.SaveWithHistory checks ^IRISCouch.Tree for idempotency | Epic 3 retro storage encapsulation |
| 8 | DocumentEngine.SaveWithHistory checks ^IRISCouch.Tree for new-doc detection | Epic 3 retro storage encapsulation |

### Explicitly Deferred (Not in 4.0)

| # | Item | Rationale |
|---|------|-----------|
| 1 | doc_count negative on double-delete via engine API | Handler layer prevents this path; low risk |
| 2 | Race condition on doc_count in SaveWithHistory | Single-process architecture; address for concurrency |
| 3 | _local_seq omitted when no changes entry found | Alpha-acceptable; will be revisited when Changes storage is hardened |
| 4 | HandleBulkGet silently skips empty id entries | Edge case; CouchDB behavior unspecified |
| 5 | Repetitive error-entry construction in HandleBulkDocs | Code quality; addressed partially by split to BulkHandler |
| 6 | No underscore-prefix validation on document IDs | Address with _design/_local docs in later epic |

## Tasks / Subtasks

- [x] Task 1: Create `Storage.Changes` class with `GetDocSeq` method (AC: #6)
  - [x] 1.1: Create `src/IRISCouch/Storage/Changes.cls` with `ClassMethod GetDocSeq(pDB As %String, pDocId As %String) As %String` — scans `^IRISCouch.Changes(pDB)` backwards via `$Order(..., -1)` to find the latest seq entry matching pDocId. Returns seq as string, or "" if not found. Uses same logic currently in DocumentHandler.HandleGet lines 361-369.
  - [x] 1.2: Compile via MCP

- [x] Task 2: Add `RevTree.MarkDeleted`, `RevTree.RevExists`, `RevTree.TreeExists` methods (AC: #3, #4, #5)
  - [x] 2.1: Add `ClassMethod MarkDeleted(pDB As %String, pDocId As %String, pRev As %String) As %Status` to RevTree.cls — sets `^IRISCouch.Tree(pDB, pDocId, "D", pRev) = 1`. Returns $$$OK.
  - [x] 2.2: Add `ClassMethod RevExists(pDB As %String, pDocId As %String, pRev As %String) As %Boolean` to RevTree.cls — returns `$Data(^IRISCouch.Tree(pDB, pDocId, "R", pRev)) > 0`.
  - [x] 2.3: Add `ClassMethod TreeExists(pDB As %String, pDocId As %String) As %Boolean` to RevTree.cls — returns `$Data(^IRISCouch.Tree(pDB, pDocId)) > 0`.
  - [x] 2.4: Compile via MCP

- [x] Task 3: Fix encapsulation in DocumentEngine (AC: #3, #4, #5)
  - [x] 3.1: In `DocumentEngine.SaveDeleted` line 129, replace `Set ^IRISCouch.Tree(pDB, pDocId, "D", tNewRev) = 1` with `Set tSC = ##class(IRISCouch.Storage.RevTree).MarkDeleted(pDB, pDocId, tNewRev)` and add error handling similar to nearby pattern.
  - [x] 3.2: In `DocumentEngine.SaveWithHistory` line 192, replace `If $Data(^IRISCouch.Tree(pDB, pDocId, "R", pRev)) > 0` with `If ##class(IRISCouch.Storage.RevTree).RevExists(pDB, pDocId, pRev)`.
  - [x] 3.3: In `DocumentEngine.SaveWithHistory` line 212, replace `Set tIsNewDoc = '$Data(^IRISCouch.Tree(pDB, pDocId))` with `Set tIsNewDoc = '##class(IRISCouch.Storage.RevTree).TreeExists(pDB, pDocId)`.
  - [x] 3.4: Compile via MCP

- [x] Task 4: Create `BulkHandler.cls` — extract bulk operations from DocumentHandler (AC: #1, #2)
  - [x] 4.1: Create `src/IRISCouch/API/BulkHandler.cls` with `Class IRISCouch.API.BulkHandler Extends %RegisteredObject`
  - [x] 4.2: Move `HandleBulkDocs` (lines 391-616) from DocumentHandler to BulkHandler as-is
  - [x] 4.3: Move `HandleBulkGet` (lines 623-744) from DocumentHandler to BulkHandler as-is
  - [x] 4.4: Compile via MCP

- [x] Task 5: Create `AllDocsHandler.cls` — extract _all_docs from DocumentHandler (AC: #1, #2, #7)
  - [x] 5.1: Create `src/IRISCouch/API/AllDocsHandler.cls` with `Class IRISCouch.API.AllDocsHandler Extends %RegisteredObject`
  - [x] 5.2: Move `HandleAllDocs` (lines 752-891) from DocumentHandler to AllDocsHandler
  - [x] 5.3: Move `HandleAllDocsPost` (lines 898-986) from DocumentHandler to AllDocsHandler
  - [x] 5.4: **IMPORTANT**: The `$Order(^IRISCouch.Docs(...))` iteration in HandleAllDocs is a storage encapsulation violation. Encapsulate this by adding a `Storage.Document.ListDocIds(pDB, pStartKey, pEndKey, pDirection)` helper or move the iteration logic to use an iterator pattern in Storage.Document. Alternatively, since this is complex pagination logic, it's acceptable to have AllDocsHandler call Storage methods for individual doc lookups while keeping the $Order iteration, as long as the iteration is clearly documented. The simplest correct approach: keep the $Order loop but note it as a known encapsulation exception documented in deferred-work.md.
  - [x] 5.5: Compile via MCP

- [x] Task 6: Fix local_seq encapsulation in DocumentHandler.HandleGet (AC: #6)
  - [x] 6.1: In DocumentHandler.HandleGet lines 358-373, replace the direct `^IRISCouch.Changes` scan with: `Set tLocalSeq = ##class(IRISCouch.Storage.Changes).GetDocSeq(pDB, pDocId)`. Keep the `If tLocalSeq '= ""` guard.
  - [x] 6.2: Compile via MCP

- [x] Task 7: Remove moved methods from DocumentHandler (AC: #1)
  - [x] 7.1: Delete HandleBulkDocs, HandleBulkGet, HandleAllDocs, HandleAllDocsPost methods from DocumentHandler.cls
  - [x] 7.2: Verify DocumentHandler.cls is under 500 lines
  - [x] 7.3: Compile via MCP

- [x] Task 8: Update Router.cls wrapper methods (AC: #2)
  - [x] 8.1: Change `HandleBulkDocs` wrapper to delegate to `##class(IRISCouch.API.BulkHandler).HandleBulkDocs(pDB)`
  - [x] 8.2: Change `HandleBulkGet` wrapper to delegate to `##class(IRISCouch.API.BulkHandler).HandleBulkGet(pDB)`
  - [x] 8.3: Change `HandleAllDocs` wrapper to delegate to `##class(IRISCouch.API.AllDocsHandler).HandleAllDocs(pDB)`
  - [x] 8.4: Change `HandleAllDocsPost` wrapper to delegate to `##class(IRISCouch.API.AllDocsHandler).HandleAllDocsPost(pDB)`
  - [x] 8.5: Compile via MCP

- [x] Task 9: Add GetRevsInfo unit tests for deleted and missing statuses (AC: #8)
  - [x] 9.1: In `RevTreeTest.cls`, add `TestGetRevsInfoDeleted` — create doc "revinfodoc" with rev 1-aaa, add child 2-bbb with D-marker (deleted), call GetRevsInfo(db, "revinfodoc", "2-bbb"), assert first entry has status="deleted", second has status="available".
  - [x] 9.2: In `RevTreeTest.cls`, add `TestGetRevsInfoMissing` — create doc "revinfomissing" with Init(1-aaa), then AddChild(1-aaa, 2-bbb) which writes R-node but we manually kill `^IRISCouch.Docs(db, "revinfomissing", "1-aaa")` to simulate missing body. Call GetRevsInfo, assert the root entry has status="missing".
  - [x] 9.3: Compile via MCP

- [x] Task 10: Run full test suite (AC: #9)
  - [x] 10.1: All 122 existing tests pass (zero regressions)
  - [x] 10.2: New GetRevsInfo tests pass (2 new tests, 124 total)

## Dev Notes

### DocumentHandler Split Plan

Current DocumentHandler (1009 lines) contains 9 methods. After split:

| Class | Methods | Est. Lines |
|-------|---------|------------|
| DocumentHandler | HandlePost, HandlePut, HandleGet, HandleDelete, ValidateFields | ~400 |
| BulkHandler | HandleBulkDocs, HandleBulkGet | ~350 |
| AllDocsHandler | HandleAllDocs, HandleAllDocsPost | ~250 |

### Quit-in-Loop Coding Guideline

Add this guideline knowledge: `Quit` inside a `While`/`For` loop exits only the loop, NOT the enclosing `Try` block. To exit the method after an error inside a loop, use a flag variable:

```objectscript
Set tValidationError = 0
While condition {
    If error {
        Set tValidationError = 1
        Quit  ; exits loop only
    }
}
If tValidationError Quit  ; exits Try block
```

This was already applied in Story 3.5 (HandleBulkDocs new_edits=false path). No code changes needed — this is a documented pattern.

### Storage.Changes Class

New class at `src/IRISCouch/Storage/Changes.cls`:

```objectscript
Class IRISCouch.Storage.Changes Extends %RegisteredObject
{
    /// Get the latest sequence number for a specific document.
    ClassMethod GetDocSeq(pDB As %String, pDocId As %String) As %String
    {
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
        Quit tLocalSeq
    }
}
```

### RevTree New Methods

```objectscript
ClassMethod MarkDeleted(pDB As %String, pDocId As %String, pRev As %String) As %Status
{
    Set ^IRISCouch.Tree(pDB, pDocId, "D", pRev) = 1
    Quit $$$OK
}

ClassMethod RevExists(pDB As %String, pDocId As %String, pRev As %String) As %Boolean
{
    Quit $Data(^IRISCouch.Tree(pDB, pDocId, "R", pRev)) > 0
}

ClassMethod TreeExists(pDB As %String, pDocId As %String) As %Boolean
{
    Quit $Data(^IRISCouch.Tree(pDB, pDocId)) > 0
}
```

### Router Wrapper Changes

```objectscript
; Before:
ClassMethod HandleBulkDocs(pDB As %String) As %Status { Quit ##class(IRISCouch.API.DocumentHandler).HandleBulkDocs(pDB) }
; After:
ClassMethod HandleBulkDocs(pDB As %String) As %Status { Quit ##class(IRISCouch.API.BulkHandler).HandleBulkDocs(pDB) }
```

Same pattern for HandleBulkGet, HandleAllDocs, HandleAllDocsPost.

### _all_docs Iteration Encapsulation

The `$Order(^IRISCouch.Docs(...))` loop in HandleAllDocs is a known storage encapsulation exception. Creating a full iterator abstraction adds complexity without clear value for _all_docs. The loop logic is tightly coupled to pagination parameters (skip, limit, startkey, endkey, descending). Options:
1. Leave as-is in AllDocsHandler with comment — simplest, acceptable for alpha
2. Create `Storage.Document.ListDocIds()` returning a dynamic array — loses lazy iteration benefits
3. Create callback-based iterator — over-engineering for one caller

**Decision**: Option 1. Document in deferred-work.md as a known exception.

### Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `src/IRISCouch/Storage/Changes.cls` | **Create** | New storage class for changes feed access |
| `src/IRISCouch/Storage/RevTree.cls` | **Modify** | Add MarkDeleted, RevExists, TreeExists methods |
| `src/IRISCouch/Core/DocumentEngine.cls` | **Modify** | Replace direct global access with Storage method calls |
| `src/IRISCouch/API/BulkHandler.cls` | **Create** | Extracted bulk operations handler |
| `src/IRISCouch/API/AllDocsHandler.cls` | **Create** | Extracted _all_docs handler |
| `src/IRISCouch/API/DocumentHandler.cls` | **Modify** | Remove moved methods, fix local_seq encapsulation |
| `src/IRISCouch/API/Router.cls` | **Modify** | Update 4 wrapper methods to new handler classes |
| `src/IRISCouch/Test/RevTreeTest.cls` | **Modify** | Add GetRevsInfo deleted/missing status tests |

### Established Patterns

- Handler catch: `RenderInternal()` then `Quit $$$OK`
- Storage encapsulation: all global access through Storage.* classes
- Response: `Response.JSON(tResult)` for 200, `Response.JSONStatus(code, tResult)` for non-200
- Router wrappers: local method delegating to handler class
- Test cleanup: `OnBeforeOneTest` kills globals, creates fresh db
- Constructor: `%OnNew(initvalue As %String = "")` with `##super(initvalue)` call

### Previous Story Intelligence (Story 3.6)

- 122 tests passing across 20 test classes
- DocumentHandler at 1009 lines — confirmed too large
- HandleAllDocs uses `$Order(^IRISCouch.Docs(pDB, tDocId), tDirection)` for iteration
- HandleGet local_seq uses `$Order(^IRISCouch.Changes(pDB, tSeq), -1)` backward scan
- `Storage.Document.CountNonDeleted(pDB)` already exists and uses `^IRISCouch.DB(pDB, "doc_count")`
- RevTreeTest has 11 tests, needs 2 more for deleted/missing status paths

### References

- [Source: _bmad-output/implementation-artifacts/epic-3-retro-2026-04-13.md] — Action items and storage violations
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] — Full deferred work list
- [Source: src/IRISCouch/API/DocumentHandler.cls] — Current handler (1009 lines)
- [Source: src/IRISCouch/Core/DocumentEngine.cls:129,192,212] — Storage encapsulation violations
- [Source: src/IRISCouch/Storage/RevTree.cls] — Existing RevTree methods
- [Source: src/IRISCouch/API/Router.cls] — Current routing configuration

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

No debug globals needed; all changes compiled and passed on first attempt.

### Completion Notes List

- Created Storage.Changes class with GetDocSeq method for encapsulated changes feed access
- Added MarkDeleted, RevExists, TreeExists methods to RevTree for storage encapsulation
- Replaced 3 direct global accesses in DocumentEngine (SaveDeleted D-marker, SaveWithHistory idempotency check, SaveWithHistory new-doc detection) with Storage method calls
- Created BulkHandler class extracting HandleBulkDocs and HandleBulkGet from DocumentHandler
- Created AllDocsHandler class extracting HandleAllDocs and HandleAllDocsPost from DocumentHandler
- Replaced direct ^IRISCouch.Changes scan in DocumentHandler.HandleGet with Storage.Changes.GetDocSeq call
- Removed 4 methods from DocumentHandler, reducing from 1009 lines to 396 lines
- Updated Router.cls to delegate bulk and all_docs routes to new handler classes
- Added TestGetRevsInfoDeleted and TestGetRevsInfoMissing to RevTreeTest
- BulkHandler calls DocumentHandler.ValidateFields (cross-class call, not ..ValidateFields) since ValidateFields stayed in DocumentHandler
- AllDocsHandler retains $Order(^IRISCouch.Docs) iteration as documented encapsulation exception
- All 124 tests pass (122 existing + 2 new, zero regressions)

### Review Findings

- [x] [Review][Defer] RevTree.GetRevsInfo accesses ^IRISCouch.Docs directly [RevTree.cls:227] -- deferred, pre-existing cross-storage-domain access
- [x] [Review][Defer] DocumentEngine direct global access to ^IRISCouch.Changes/Seq/DB [DocumentEngine.cls:65-72,143-150,234-241] -- deferred, pre-existing and not in scope for this story
- [x] [Review][Defer] Inner try/catch Quit in HandleBulkDocs new_edits path falls through to normal path [BulkHandler.cls:36] -- deferred, pre-existing from original code

### Change Log

- 2026-04-12: Story 4.0 implemented - DocumentHandler split, storage encapsulation fixes, GetRevsInfo test coverage

### File List

- src/IRISCouch/Storage/Changes.cls (created)
- src/IRISCouch/Storage/RevTree.cls (modified)
- src/IRISCouch/Core/DocumentEngine.cls (modified)
- src/IRISCouch/API/BulkHandler.cls (created)
- src/IRISCouch/API/AllDocsHandler.cls (created)
- src/IRISCouch/API/DocumentHandler.cls (modified)
- src/IRISCouch/API/Router.cls (modified)
- src/IRISCouch/Test/RevTreeTest.cls (modified)
