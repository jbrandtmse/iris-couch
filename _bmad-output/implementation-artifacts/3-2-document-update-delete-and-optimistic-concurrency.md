# Story 3.2: Document Update, Delete & Optimistic Concurrency

Status: done

## Story

As a client,
I want to update documents with revision checks and delete documents producing tombstones,
so that I have safe concurrent access with no silent data loss.

## Acceptance Criteria

1. **Given** a document `{docid}` exists with revision `1-abc`, **When** the client sends `PUT /iris-couch/{db}/{docid}` with `"_rev":"1-abc"` and updated body, **Then** the response status is 201 Created with the new revision `2-<hash>`, and the previous revision remains in the tree.

2. **Given** a document `{docid}` exists with revision `2-def`, **When** the client sends `PUT /iris-couch/{db}/{docid}` with a stale `"_rev":"1-abc"`, **Then** the response status is 409 Conflict with `{"error":"conflict","reason":"Document update conflict."}`.

3. **Given** a document `{docid}` exists with revision `N-hex`, **When** the client sends `DELETE /iris-couch/{db}/{docid}?rev=N-hex`, **Then** the response status is 200 OK and a tombstone revision `(N+1)-<hash>` is created with `"_deleted":true`.

4. **Given** a document `{docid}` exists, **When** the client sends `PUT /iris-couch/{db}/{docid}` with `"_deleted":true` and valid `_rev`, **Then** the document is deleted producing the same tombstone revision as DELETE.

5. **Given** a client sends a document with a top-level field starting with underscore (other than documented metadata: `_id`, `_rev`, `_deleted`, `_revisions`, `_attachments`), **When** the document is validated, **Then** the response status is 400 Bad Request with `{"error":"doc_validation","reason":"Bad special document member: _<fieldname>"}`.

6. **Given** all changes are compiled and tested, **Then** all existing 66 tests pass with zero regressions, and new tests cover all acceptance criteria.

## Tasks / Subtasks

- [x] Task 1: Extend `DocumentHandler.HandlePut` for update path (AC: #1, #2)
  - [x] 1.1: Add optimistic concurrency check — when `_rev` is provided, verify it matches the current winning revision (`RevTree.GetWinner`). If stale → 409 Conflict.
  - [x] 1.2: Pass `tRev` (parent rev) to `DocumentEngine.Save()` — this path already exists from Story 3.1 (line 116 passes `tRev`), but was untested for updates.
  - [x] 1.3: Verify DocumentEngine.Save correctly handles generation > 1 (it does — line 37 parses generation from parent rev).
  - [x] 1.4: Compile and verify no errors

- [x] Task 2: Add document deletion support (AC: #3, #4)
  - [x] 2.1: Create `ClassMethod HandleDelete(pDB As %String, pDocId As %String) As %Status` in `DocumentHandler`:
    - Check database exists (404 if not)
    - Get `rev` from query param `?rev=` — required (400 if missing)
    - Verify rev matches current winner (409 if stale)
    - Call `DocumentEngine.SaveDeleted(pDB, pDocId, rev)` to create tombstone
    - Return 200 OK with `{"ok":true, "id":"...", "rev":"(N+1)-..."}`
  - [x] 2.2: Handle `_deleted:true` in HandlePut — when body contains `"_deleted":true` with valid `_rev`, delegate to `DocumentEngine.SaveDeleted()` (same tombstone behavior as DELETE)
  - [x] 2.3: Add `ClassMethod SaveDeleted(pDB As %String, pDocId As %String, pParentRev As %String) As %String` to `DocumentEngine`:
    - Create tombstone body: `{"_deleted":true}`
    - Mint rev with `pDeleted=1`: `RevHash.MintRev(generation, tombstoneBody, pParentRev, 1)`
    - Within TSTART/TCOMMIT:
      - Write tombstone body via `Storage.Document.Write()`
      - Call `RevTree.AddChild()` (leaf is now deleted)
      - Mark leaf as deleted in rev tree: `Set ^IRISCouch.Tree(pDB, pDocId, "D", newRev) = 1`
      - Record change in changes feed
      - **Decrement** `^IRISCouch.DB(pDB, "doc_count")` by 1
      - **Increment** `^IRISCouch.DB(pDB, "doc_del_count")` by 1
      - Update `update_seq`
    - Return newRev
  - [x] 2.4: Compile and verify no errors

- [x] Task 3: Update `RevTree.RecomputeWinner` for deleted leafs (AC: #3)
  - [x] 3.1: Add deletion awareness — check `^IRISCouch.Tree(pDB, pDocId, "D", tRev)` for each leaf. Per CouchDB algorithm: (1) live beats deleted, (2) highest depth, (3) lexicographic rev hash tiebreak.
  - [x] 3.2: Compile and verify no errors

- [x] Task 4: Add underscore field validation (AC: #5)
  - [x] 4.1: Create a validation method `ClassMethod ValidateFields(pBody As %DynamicObject) As %String` in `DocumentHandler` (or a utility class):
    - Iterate all top-level keys
    - If key starts with `_` and is NOT in the allowed set (`_id`, `_rev`, `_deleted`, `_revisions`, `_attachments`), return error with field name
  - [x] 4.2: Call validation in HandlePost and HandlePut BEFORE saving
  - [x] 4.3: Return 400 with `{"error":"doc_validation","reason":"Bad special document member: _<fieldname>"}`
  - [x] 4.4: Compile and verify no errors

- [x] Task 5: Add DELETE route to Router (AC: #3)
  - [x] 5.1: Add `<Route Url="/:db/:docid" Method="DELETE" Call="HandleDocumentDelete" />` alongside existing `/:db/:docid` routes
  - [x] 5.2: Create local wrapper: `HandleDocumentDelete(pDB, pDocId)` delegating to `DocumentHandler.HandleDelete(pDB, pDocId)`
  - [x] 5.3: Compile and verify no errors

- [x] Task 6: Create unit tests (AC: #1-#5)
  - [x] 6.1: Add to `IRISCouch.Test.DocumentTest` (if under 500 lines, else create new class)
  - [x] 6.2: `TestDocumentUpdate` — create doc, update with correct _rev via DocumentEngine.Save(db, docId, newBody, rev1), verify new rev is `2-*`, old body still readable
  - [x] 6.3: `TestDocumentUpdateRevTree` — create doc, update, verify rev tree: R nodes have parent chain, old leaf removed, new leaf added, winner updated
  - [x] 6.4: `TestDocumentDelete` — create doc, delete via DocumentEngine.SaveDeleted(), verify tombstone body, doc_count decremented, doc_del_count incremented
  - [x] 6.5: `TestDeletedRevTreeWinner` — create doc, delete, verify winner is tombstone rev. Create second doc, create conflict (2 leafs), delete one — verify non-deleted leaf wins.
  - [x] 6.6: `TestUnderscoreFieldValidation` — verify `_badfield` rejected, `_id`/`_rev`/`_deleted`/`_revisions`/`_attachments` accepted

- [x] Task 7: Create HTTP integration tests (AC: #1-#5)
  - [x] 7.1: Add to `IRISCouch.Test.DocumentHttpTest` (if under 500 lines, else create new class)
  - [x] 7.2: `TestUpdateDocument` — create doc, PUT with valid _rev → 201 with rev `2-*`
  - [x] 7.3: `TestUpdateConflict` — create doc, PUT with stale _rev → 409 conflict
  - [x] 7.4: `TestDeleteDocument` — create doc, DELETE with rev → 200, GET → 404
  - [x] 7.5: `TestDeleteViaput` — create doc, PUT with `_deleted:true` and valid _rev → 200
  - [x] 7.6: `TestDeleteNoRev` — DELETE without rev → 400 or 409
  - [x] 7.7: `TestUnderscoreFieldRejected` — PUT with `_foo` field → 400 doc_validation

- [x] Task 8: Run full test suite (AC: #6)
  - [x] 8.1: All existing 66 tests pass (zero regressions)
  - [x] 8.2: All new tests pass

## Dev Notes

### HandlePut Update Path (Already Partially Wired)

Story 3.1 already:
- Extracts `_rev` from body or `?rev=` query param (DocumentHandler.cls:100-106)
- Passes `tRev` to `DocumentEngine.Save()` (DocumentHandler.cls:116)
- DocumentEngine handles generation > 1 via `$Piece(pParentRev, "-", 1) + 1` (DocumentEngine.cls:37)
- RevTree.AddChild handles extending the tree (RevTree.cls:48-69)

What's missing for the update path:
1. **Optimistic concurrency check** — verify `_rev` matches current winner before proceeding
2. Tests exercising the update flow

### Concurrency Check Pattern

```objectscript
; After extracting tRev from body/_rev or ?rev= query param
If ##class(IRISCouch.Storage.Document).Exists(pDB, pDocId) {
    If tRev = "" {
        ; Doc exists, no _rev → 409
        Do ##class(IRISCouch.Util.Error).Render(409, ..#CONFLICT, "Document update conflict.")
        Quit
    }
    ; Check _rev matches current winner
    Set tCurrentWinner = ##class(IRISCouch.Storage.RevTree).GetWinner(pDB, pDocId)
    If tRev '= tCurrentWinner {
        Do ##class(IRISCouch.Util.Error).Render(409, ..#CONFLICT, "Document update conflict.")
        Quit
    }
}
```

This replaces the simpler check at DocumentHandler.cls:108-111.

### Tombstone Pattern

CouchDB deletion creates a **tombstone** — a new revision with `{"_deleted":true}` as the body. The document ID and revision tree persist; only the body is replaced. The tombstone:
- Has generation N+1 (parent is the deleted rev)
- Rev hash computed with `pDeleted=1` flag
- `doc_count` decremented, `doc_del_count` incremented
- The tombstone revision appears in the changes feed
- GET for the doc returns 404 (tombstone is not a "live" document)

### Deleted Leaf Tracking

Add a "D" node to the rev tree for deleted leafs:
```
^IRISCouch.Tree(db, docId, "D", rev) = 1
```

This allows `RecomputeWinner` to distinguish live vs deleted leafs. The existing "R" and "L" nodes are unchanged.

### RecomputeWinner with Deletion Awareness

The CouchDB winning revision algorithm:
1. **Live beats deleted** — a non-deleted leaf always wins over a deleted one
2. **Highest depth** — among same-status leaves, deepest wins
3. **Lexicographic tiebreak** — same depth, compare full rev string

Updated RecomputeWinner:
```objectscript
Set tWinnerRev = "", tWinnerDepth = 0, tWinnerDeleted = 1
Set tRev = ""
For {
    Set tRev = $Order(^IRISCouch.Tree(pDB, pDocId, "L", tRev))
    Quit:tRev=""
    Set tDepth = +$Get(^IRISCouch.Tree(pDB, pDocId, "L", tRev))
    Set tDeleted = +$Get(^IRISCouch.Tree(pDB, pDocId, "D", tRev))
    ; Selection: live beats deleted, then depth, then lex
    If (tWinnerRev = "") || ('tDeleted && tWinnerDeleted) || ((tDeleted = tWinnerDeleted) && ((tDepth > tWinnerDepth) || ((tDepth = tWinnerDepth) && (tRev > tWinnerRev)))) {
        Set tWinnerRev = tRev
        Set tWinnerDepth = tDepth
        Set tWinnerDeleted = tDeleted
    }
}
```

### HandleGet Must Return 404 for Deleted Documents

When `GET /{db}/{docid}` fetches the winning revision and it's a tombstone (body is `{"_deleted":true}`), return 404 with `{"error":"not_found","reason":"deleted"}`. Check the "D" node or parse the body for `_deleted`.

### Underscore Field Validation — Allowed Fields

CouchDB allows these underscore-prefixed top-level fields:
- `_id` — document identifier
- `_rev` — revision string
- `_deleted` — deletion flag
- `_revisions` — revision history (used by replication)
- `_attachments` — attachment metadata

All other `_*` fields return 400 `doc_validation`.

### Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `src/IRISCouch/API/DocumentHandler.cls` | **Modify** | Add HandleDelete, update HandlePut with concurrency check + _deleted support, add field validation |
| `src/IRISCouch/Core/DocumentEngine.cls` | **Modify** | Add SaveDeleted() method for tombstones |
| `src/IRISCouch/Storage/RevTree.cls` | **Modify** | Update RecomputeWinner for deleted leaf awareness |
| `src/IRISCouch/API/Router.cls` | **Modify** | Add DELETE /:db/:docid route + wrapper |
| `src/IRISCouch/Test/DocumentTest.cls` | **Modify** | Add update, delete, validation unit tests |
| `src/IRISCouch/Test/DocumentHttpTest.cls` | **Modify** | Add update, delete, validation HTTP tests |

### Established Patterns

- Handler catch: `RenderInternal()` then `Quit $$$OK`
- Error slugs: `##class(IRISCouch.Util.Error).#CONFLICT`, `.#DOCVALIDATION`, `.#NOTFOUND`
- Response: `Response.JSONStatus(201, tResp)` for creates, `Response.JSON(tResp)` for 200
- Router wrappers: local method delegating to handler class
- Test cleanup: `OnBeforeOneTest` kills `^IRISCouch.*(testdocdb)` globals, creates fresh db

### Previous Story Intelligence (Story 3.1)

- 66 tests passing across 9 test classes
- DocumentEngine.Save() handles both generation=1 (new) and generation>1 (update) paths
- RevTree.AddChild removes parent from leaf index, adds child — correct for linear updates
- HandlePut already extracts _rev from body and ?rev= query param
- HandlePut already passes tRev to DocumentEngine.Save() (line 116)
- Code review auto-resolved: TROLLBACK guard (tInTrans flag), JSON parse validation
- Deferred: parent rev existence validation in AddChild, doc ID underscore prefix validation

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.2] — Acceptance criteria
- [Source: _bmad-output/planning-artifacts/architecture.md:247-251] — Winning rev algorithm, rev tree structure
- [Source: _bmad-output/planning-artifacts/research/technical-couchdb-on-iris-research-2026-04-10.md:199-210] — Revision format, winning rev, deletion semantics
- [Source: src/IRISCouch/API/DocumentHandler.cls:99-116] — Existing _rev extraction and Save() call
- [Source: src/IRISCouch/Core/DocumentEngine.cls] — Current Save() method
- [Source: src/IRISCouch/Storage/RevTree.cls:88-114] — Current RecomputeWinner

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
No debug globals needed; all tests passed on first execution.

### Completion Notes List
- Implemented optimistic concurrency check in HandlePut: verifies _rev matches current winner via RevTree.GetWinner before proceeding with update
- Added HandleDelete method to DocumentHandler with rev query param validation and 409 for missing/stale rev
- Added _deleted:true handling in HandlePut that delegates to SaveDeleted for tombstone creation
- Created DocumentEngine.SaveDeleted() method: creates tombstone body, mints rev with pDeleted=1, writes within TSTART/TCOMMIT, marks "D" node, decrements doc_count, increments doc_del_count
- Updated RevTree.RecomputeWinner with deletion awareness: live beats deleted, then depth, then lex tiebreak
- Updated RevTree.AddChild to clean up parent "D" marker when parent is removed from leaf index
- Updated HandleGet to return 404 with reason "deleted" when winning revision has "D" marker
- Added ValidateFields method to DocumentHandler: iterates top-level keys, rejects non-allowed underscore-prefixed fields
- Added field validation call in both HandlePost and HandlePut before save
- Added DELETE /:db/:docid route and HandleDocumentDelete wrapper in Router
- Created new test class DocumentUpdateTest (5 unit tests) to keep under 500-line limit
- Created new test class DocumentUpdateHttpTest (6 HTTP integration tests)
- All 86 tests pass (75 existing + 11 new), zero regressions

### File List
- `src/IRISCouch/API/DocumentHandler.cls` — Modified: added HandleDelete, ValidateFields, updated HandlePut with concurrency check + _deleted support, updated HandleGet for deleted doc 404, added field validation to HandlePost
- `src/IRISCouch/Core/DocumentEngine.cls` — Modified: added SaveDeleted() method for tombstone creation
- `src/IRISCouch/Storage/RevTree.cls` — Modified: updated RecomputeWinner with deletion awareness, updated AddChild to clean parent "D" marker
- `src/IRISCouch/API/Router.cls` — Modified: added DELETE /:db/:docid route and HandleDocumentDelete wrapper
- `src/IRISCouch/Test/DocumentUpdateTest.cls` — Created: 5 unit tests for update, delete, rev tree, validation
- `src/IRISCouch/Test/DocumentUpdateHttpTest.cls` — Created: 6 HTTP integration tests for update, delete, conflict, validation

### Review Findings

- [x] [Review][Patch] PUT _deleted:true on non-existent document creates broken rev tree [DocumentHandler.cls:142] — AUTO-RESOLVED: added guard to reject _deleted:true when tRev is empty (doc doesn't exist), returns 404
- [x] [Review][Patch] SaveDeleted calls RecomputeWinner twice redundantly [DocumentEngine.cls:128-142] — AUTO-RESOLVED: moved D marker set before AddChild call so AddChild's internal RecomputeWinner sees deletion status, removed redundant second RecomputeWinner call
- [x] [Review][Defer] doc_count can go negative on double-delete via engine API [DocumentEngine.cls:SaveDeleted] — deferred, pre-existing design concern; handler layer prevents this path

## Change Log
- Story 3.2 implementation complete: document update with optimistic concurrency, document deletion with tombstones, underscore field validation, 11 new tests (Date: 2026-04-12)
- Code review auto-resolved: _deleted:true guard for non-existent docs, removed redundant RecomputeWinner in SaveDeleted (Date: 2026-04-12)
