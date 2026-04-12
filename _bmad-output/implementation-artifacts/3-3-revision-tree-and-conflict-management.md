# Story 3.3: Revision Tree & Conflict Management

Status: done

## Story

As a client,
I want the system to detect, store, and expose concurrent-update conflicts and compute the deterministic winning revision,
so that I can resolve conflicts without data loss.

## Acceptance Criteria

1. **Given** two clients concurrently update the same document from the same parent revision, **When** the second write arrives (via `new_edits=false` or replication), **Then** both revisions are stored as leaf nodes in `^IRISCouch.Tree`, the winning revision is computed deterministically (highest depth, then lexicographic rev hash), and the winning revision is cached in the "W" node.

2. **Given** a document with conflicts exists, **When** the client sends `GET /iris-couch/{db}/{docid}?conflicts=true`, **Then** the response includes a `_conflicts` array listing all non-winning, non-deleted leaf revisions.

3. **Given** a document exists with a multi-revision history, **When** the client sends `GET /iris-couch/{db}/{docid}?revs=true`, **Then** the response includes a `_revisions` object with `start` (integer generation) and `ids` array (hex hashes tracing the revision path from current rev to root).

4. **Given** a document exists, **When** the client sends `GET /iris-couch/{db}/{docid}?revs_info=true`, **Then** the response includes a `_revs_info` array with each revision's `rev` string and `status` (`available`, `missing`, or `deleted`).

5. **Given** a document exists, **When** the client sends `GET /iris-couch/{db}/{docid}?open_revs=all`, **Then** the response returns all leaf revisions as a JSON array of `{"ok":{...doc...}}` entries.

6. **Given** a document exists, **When** the client sends `GET /iris-couch/{db}/{docid}?open_revs=["1-abc","2-def"]`, **Then** the response returns the specified revisions as `{"ok":{...}}` or `{"missing":"N-hex"}` for revisions not found.

7. **Given** all changes are compiled and tested, **Then** all existing 86 tests pass with zero regressions, and new tests cover all acceptance criteria.

## Tasks / Subtasks

- [x] Task 1: Add `RevTree.AddBranch` for conflict creation (AC: #1)
  - [x] 1.1: Create `ClassMethod AddBranch(pDB As %String, pDocId As %String, pParentRev As %String, pChildRev As %String) As %Status` in `RevTree` — like `AddChild` but does NOT remove parent from leaf index (both parent's other children and new child are leaves, creating a branch/conflict)
    - Set `^IRISCouch.Tree(pDB, pDocId, "R", pChildRev) = pParentRev`
    - Get parent depth: if parent is a leaf, use leaf depth; otherwise walk R-chain from parent to count depth
    - Set `^IRISCouch.Tree(pDB, pDocId, "L", pChildRev) = parentDepth + 1`
    - Call `..RecomputeWinner(pDB, pDocId)`
  - [x] 1.2: Note: `AddBranch` is used by `new_edits=false` (Story 3.5) and for test setup here. Normal `new_edits=true` writes use `AddChild` which removes parent from leaf index.
  - [x] 1.3: Compile and verify

- [x] Task 2: Add `RevTree.GetConflicts` for `?conflicts=true` (AC: #2)
  - [x] 2.1: Create `ClassMethod GetConflicts(pDB As %String, pDocId As %String) As %DynamicArray` — returns array of non-winning, non-deleted leaf revisions:
    - Get winner from "W" node
    - Iterate all "L" leaves
    - For each leaf != winner, check "D" node; if not deleted, add to array
    - Return the array (empty if no conflicts)
  - [x] 2.2: Compile and verify

- [x] Task 3: Add `RevTree.GetRevisions` for `?revs=true` (AC: #3)
  - [x] 3.1: Create `ClassMethod GetRevisions(pDB As %String, pDocId As %String, pRev As %String) As %DynamicObject` — returns `{"start":N,"ids":["hash1","hash2",...]}`:
    - Parse generation from pRev: `$Piece(pRev, "-", 1)`
    - Extract hash: `$Piece(pRev, "-", 2)`
    - Walk R-chain backwards from pRev to root, collecting hash at each step
    - `start` = generation of pRev
    - `ids` = array of hashes from newest to oldest
  - [x] 3.2: Compile and verify

- [x] Task 4: Add `RevTree.GetRevsInfo` for `?revs_info=true` (AC: #4)
  - [x] 4.1: Create `ClassMethod GetRevsInfo(pDB As %String, pDocId As %String, pRev As %String) As %DynamicArray` — returns array of `{"rev":"N-hash","status":"available|missing|deleted"}`:
    - Walk R-chain from pRev to root (same as GetRevisions)
    - For each rev in the chain, check:
      - If `^IRISCouch.Docs(pDB, pDocId, rev)` exists AND not deleted → `"available"`
      - If deleted (D marker) → `"deleted"`
      - If body not found → `"missing"`
  - [x] 4.2: Compile and verify

- [x] Task 5: Add `RevTree.GetLeafRevs` for `?open_revs=all` (AC: #5)
  - [x] 5.1: Create `ClassMethod GetLeafRevs(pDB As %String, pDocId As %String) As %DynamicArray` — returns array of all leaf revision strings (including deleted):
    - Iterate "L" nodes, collect all rev strings
  - [x] 5.2: Compile and verify

- [x] Task 6: Update `DocumentHandler.HandleGet` for query parameters (AC: #2-#6)
  - [x] 6.1: After building the response object (`tRespObj`), check for query params:
    - `conflicts=true` → add `_conflicts` array from `RevTree.GetConflicts()`
    - `revs=true` → add `_revisions` object from `RevTree.GetRevisions()`
    - `revs_info=true` → add `_revs_info` array from `RevTree.GetRevsInfo()`
  - [x] 6.2: Handle `open_revs` parameter — this changes the entire response format:
    - `open_revs=all` → return JSON array of `{"ok":{...doc...}}` for each leaf
    - `open_revs=["rev1","rev2"]` → return JSON array with `{"ok":{...}}` or `{"missing":"rev"}` per requested rev
    - Parse open_revs value: if "all", get all leaves; otherwise parse JSON array of rev strings
    - For each rev: read body, inject `_id`/`_rev`, wrap in `{"ok":{...}}`; if body missing, use `{"missing":"rev"}`
    - Return the array directly (not wrapped in a document object)
    - `open_revs` processing should happen BEFORE the normal single-doc response path and return early
  - [x] 6.3: Compile and verify

- [x] Task 7: Create unit tests (AC: #1-#6)
  - [x] 7.1: Create `src/IRISCouch/Test/RevTreeTest.cls` extending `%UnitTest.TestCase`
  - [x] 7.2: `TestAddBranch` — create doc, add branch from same parent, verify 2 leaves, correct winner
  - [x] 7.3: `TestGetConflicts` — create doc with 2 leaves, verify conflicts array contains non-winner
  - [x] 7.4: `TestGetConflictsNoConflict` — single-leaf doc, verify empty conflicts array
  - [x] 7.5: `TestGetRevisions` — create chain of 3 revisions, verify `start=3` and `ids` has 3 hashes
  - [x] 7.6: `TestGetRevsInfo` — create chain, verify status is `available` for existing revs
  - [x] 7.7: `TestGetLeafRevs` — create doc with 2 leaves, verify both returned

- [x] Task 8: Create HTTP integration tests (AC: #2-#6)
  - [x] 8.1: Create `src/IRISCouch/Test/RevTreeHttpTest.cls` extending `%UnitTest.TestCase`
  - [x] 8.2: `TestConflictsParam` — create doc, update, `GET ?conflicts=true` → `_conflicts` is empty (no conflicts)
  - [x] 8.3: `TestRevsParam` — create doc, update, `GET ?revs=true` → `_revisions.start=2`, `_revisions.ids` has 2 entries
  - [x] 8.4: `TestRevsInfoParam` — create doc, `GET ?revs_info=true` → `_revs_info` array with `available` status
  - [x] 8.5: `TestOpenRevsAll` — create doc, `GET ?open_revs=all` → JSON array with one `{"ok":{...}}` entry
  - [x] 8.6: `TestOpenRevsSpecific` — create doc, `GET ?open_revs=["rev1"]` → `{"ok":{...}}`; `GET ?open_revs=["bad-rev"]` → `{"missing":"bad-rev"}`

- [x] Task 9: Run full test suite (AC: #7)
  - [x] 9.1: All existing 86 tests pass (zero regressions)
  - [x] 9.2: All new tests pass (11 new tests: 6 unit + 5 HTTP integration)

## Dev Notes

### Key Insight: This Story is Primarily About READ Operations

The core write mechanics (rev tree structure, winner computation, deletion awareness) already exist from Stories 3.1-3.2. Story 3.3 adds:
1. A way to **create conflicts** (`AddBranch`) — needed for testing and will be used by `new_edits=false` in Story 3.5
2. Query parameter handling in `HandleGet` to **expose** rev tree data
3. The `open_revs` parameter which changes the entire response format

### AddBranch vs AddChild

- **AddChild** (existing): removes parent from leaf index → parent is no longer a leaf. Used for normal sequential updates (`new_edits=true`).
- **AddBranch** (new): does NOT remove parent from leaf index → both branches remain as leaves, creating a conflict. Used for replication (`new_edits=false`) and for test setup.

The key difference is line 57-58 in RevTree.cls — `AddChild` does `Kill ^IRISCouch.Tree(pDB, pDocId, "L", pParentRev)`, `AddBranch` skips this.

However, `AddBranch` should handle the case where the parent IS a leaf (depth comes from "L" node) vs when the parent is NOT a leaf (need to compute depth from R-chain). For conflict scenarios, the parent is typically still a leaf (two writes from the same parent).

### GetRevisions Format (CouchDB `?revs=true`)

```json
{
  "_revisions": {
    "start": 3,
    "ids": ["hash3", "hash2", "hash1"]
  }
}
```

Walk backwards from the requested rev through R-chain:
```objectscript
Set tRev = pRev
Set tIds = []
For {
    Quit:tRev=""
    Do tIds.%Push($Piece(tRev, "-", 2))
    Set tRev = $Get(^IRISCouch.Tree(pDB, pDocId, "R", tRev))
}
Set tResult = {}
Do tResult.%Set("start", +$Piece(pRev, "-", 1), "number")
Do tResult.%Set("ids", tIds)
```

### GetRevsInfo Format (CouchDB `?revs_info=true`)

```json
{
  "_revs_info": [
    {"rev": "3-hash3", "status": "available"},
    {"rev": "2-hash2", "status": "available"},
    {"rev": "1-hash1", "status": "available"}
  ]
}
```

Status determination:
- Check `$Data(^IRISCouch.Docs(pDB, pDocId, tRev))` — if body exists
- Check `$Get(^IRISCouch.Tree(pDB, pDocId, "D", tRev))` — if deleted marker
- `"available"` = body exists and not deleted
- `"deleted"` = deleted marker exists
- `"missing"` = no body found (pruned or never stored)

### open_revs Response Format

`open_revs` changes the response to a JSON array (not a single document object):

```json
[
  {"ok": {"_id": "doc1", "_rev": "2-abc", "field": "value"}},
  {"ok": {"_id": "doc1", "_rev": "2-def", "field": "other"}},
  {"missing": "3-nonexistent"}
]
```

For `open_revs=all`, iterate all leaf revisions. For `open_revs=["rev1","rev2"]`, parse the JSON array of requested revs.

**Parsing open_revs value**: The value is either the string `"all"` or a JSON array string like `["1-abc","2-def"]`. Parse with:
```objectscript
Set tOpenRevs = $Get(%request.Data("open_revs", 1))
If tOpenRevs = "all" {
    ; Get all leaf revisions
    Set tRevArray = ##class(IRISCouch.Storage.RevTree).GetLeafRevs(pDB, pDocId)
} Else {
    ; Parse JSON array of rev strings
    Set tRevArray = ##class(%DynamicArray).%FromJSON(tOpenRevs)
}
```

### HandleGet Refactoring Strategy

The current HandleGet is ~50 lines. Adding query param handling will grow it significantly. Strategy:
- Check `open_revs` FIRST — if present, handle entirely differently and return early
- For normal single-doc GET, add `_conflicts`, `_revisions`, `_revs_info` AFTER building the response object
- Keep each query param handler as a simple if-check calling RevTree methods

### Direct Global Access in HandleGet (Pattern 3 Violation)

Line 273 of DocumentHandler.cls directly accesses `^IRISCouch.Tree` to check the D marker:
```objectscript
If +$Get(^IRISCouch.Tree(pDB, pDocId, "D", tRev)) {
```
This should be replaced with a RevTree method. Add `ClassMethod IsDeleted(pDB, pDocId, pRev) As %Boolean` to RevTree and use it instead. Fix this while modifying HandleGet.

### Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `src/IRISCouch/Storage/RevTree.cls` | **Modify** | Add AddBranch, GetConflicts, GetRevisions, GetRevsInfo, GetLeafRevs, IsDeleted |
| `src/IRISCouch/API/DocumentHandler.cls` | **Modify** | Add conflicts/revs/revs_info/open_revs query param handling in HandleGet |
| `src/IRISCouch/Test/RevTreeTest.cls` | **Create** | Unit tests for rev tree query methods |
| `src/IRISCouch/Test/RevTreeHttpTest.cls` | **Create** | HTTP integration tests for query params |

### Established Patterns

- Handler catch: `RenderInternal()` then `Quit $$$OK`
- Storage encapsulation: all `^IRISCouch.Tree` access in `Storage.RevTree`
- Response: `Response.JSON()` for 200 responses
- Test cleanup: `OnBeforeOneTest` kills globals, creates fresh db

### Previous Story Intelligence (Story 3.2)

- 86 tests passing across 11 test classes
- RevTree has Init, AddChild, GetWinner, RecomputeWinner (with deletion awareness)
- DocumentEngine has Save and SaveDeleted
- HandleGet checks D marker for deleted docs (line 273 — direct global access, fix it)
- HandlePut has full optimistic concurrency check
- Underscore field validation in place
- Code review fixed: D marker before AddChild, _deleted:true on non-existent doc guard

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.3] — Acceptance criteria
- [Source: _bmad-output/planning-artifacts/architecture.md:239-251] — Rev tree structure, R/L/W/D nodes
- [Source: _bmad-output/planning-artifacts/research/technical-couchdb-on-iris-research-2026-04-10.md:199-210] — Revision format, revisions, revs_info, open_revs
- [Source: src/IRISCouch/Storage/RevTree.cls] — Current rev tree implementation
- [Source: src/IRISCouch/API/DocumentHandler.cls:250-302] — Current HandleGet

### Review Findings

- [x] [Review][Patch] open_revs on non-existent document returns 200 with empty array instead of 404 [DocumentHandler.cls:264] — auto-fixed: added Document.Exists check before open_revs processing
- [x] [Review][Defer] No unit test for deleted or missing status in GetRevsInfo [RevTreeTest.cls] — deferred, incomplete test coverage (not a code bug)

## Change Log

- 2026-04-12: Implemented Story 3.3 — AddBranch, GetConflicts, GetRevisions, GetRevsInfo, GetLeafRevs, IsDeleted methods in RevTree; query param handling in HandleGet; fixed RecomputeWinner lexicographic tiebreak bug (used `]` operator instead of `>` for correct string comparison); replaced direct global access for D marker with RevTree.IsDeleted; 11 new tests added (6 unit + 5 HTTP integration); all 97 tests pass.

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- Fixed RecomputeWinner lexicographic tiebreak: ObjectScript `>` operator does numeric comparison on strings like "2-cccc" vs "2-bbbb" (both evaluate to number 2). Changed to `]` (follows) operator for correct string collation comparison. This was a latent bug in the existing code that was never triggered because prior stories had no multi-leaf scenarios requiring tiebreaking.

### Completion Notes List

- Added 6 new methods to RevTree.cls: AddBranch, IsDeleted, GetConflicts, GetRevisions, GetRevsInfo, GetLeafRevs
- Updated DocumentHandler.HandleGet to support conflicts, revs, revs_info, and open_revs query parameters
- Replaced direct `^IRISCouch.Tree` D-marker access in HandleGet with `RevTree.IsDeleted()` (Pattern 3 fix)
- Fixed RecomputeWinner lexicographic comparison bug (`>` to `]`)
- open_revs handling processes before normal GET path and returns early with JSON array format
- All 97 tests pass (86 existing + 11 new, zero regressions)

### File List

- src/IRISCouch/Storage/RevTree.cls (modified) — Added AddBranch, IsDeleted, GetConflicts, GetRevisions, GetRevsInfo, GetLeafRevs; fixed RecomputeWinner tiebreak
- src/IRISCouch/API/DocumentHandler.cls (modified) — Added conflicts/revs/revs_info/open_revs query param handling; replaced direct D-marker global access with RevTree.IsDeleted
- src/IRISCouch/Test/RevTreeTest.cls (created) — 6 unit tests for rev tree query methods
- src/IRISCouch/Test/RevTreeHttpTest.cls (created) — 5 HTTP integration tests for query parameters
