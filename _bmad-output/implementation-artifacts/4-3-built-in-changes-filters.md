# Story 4.3: Built-In Changes Filters

Status: done

## Story

As a client,
I want to filter the changes feed by document IDs, Mango selector, or design-document-only,
so that I receive only the changes relevant to my application.

## Acceptance Criteria

1. **Given** a database with various documents, **When** the client sends `GET /iris-couch/{db}/_changes?filter=_doc_ids` with `{"doc_ids":["doc1","doc2"]}` in the request body (or as POST body), **Then** only changes for the specified document IDs are returned.

2. **Given** a database with various documents, **When** the client sends `POST /iris-couch/{db}/_changes?filter=_selector` with a Mango selector body (e.g., `{"selector":{"type":"order"}}`), **Then** only changes for documents matching the selector are returned.

3. **Given** a database with both regular and design documents, **When** the client sends `GET /iris-couch/{db}/_changes?filter=_design`, **Then** only changes for design documents (IDs starting with `_design/`) are returned.

4. **Given** a client specifies an unsupported or non-existent filter, **When** the changes request is processed, **Then** the response is 404 Not Found with an appropriate error envelope.

5. **Given** filters are applied, **When** the changes feed is in `feed=longpoll` mode, **Then** the filter is applied to the longpoll response as well, returning only matching changes.

6. **Given** all changes are compiled and tested, **Then** all existing 149 tests pass with zero regressions, and new tests cover all acceptance criteria.

## Tasks / Subtasks

- [x] Task 1: Parse `filter` and `doc_ids` parameters in ChangesHandler (AC: #1, #3, #4)
  - [x] 1.1: Add parsing for `filter` parameter from query string and POST body (string, default "")
  - [x] 1.2: Add parsing for `doc_ids` parameter from query string (JSON array string) and POST body (array field)
  - [x] 1.3: Add parsing for `selector` from POST body (object field) — only used with `filter=_selector`
  - [x] 1.4: Validate `filter` value: accept `_doc_ids`, `_selector`, `_design`, or empty string. Return 404 for any other value with `{"error":"not_found","reason":"missing"}`.
  - [x] 1.5: Compile via MCP

- [x] Task 2: Implement `_doc_ids` filter (AC: #1)
  - [x] 2.1: After retrieving raw changes from `Storage.Changes.ListChanges()`, if `filter=_doc_ids`:
    - Parse `doc_ids` into a lookup structure. The doc_ids can come from:
      - Query string: `?doc_ids=["doc1","doc2"]` (JSON-encoded array string)
      - POST body: `{"doc_ids":["doc1","doc2"]}` (native array)
    - During post-processing loop, skip entries where `tDocId` is NOT in the doc_ids set
    - Use a local array `tDocIdFilter(docId) = 1` for O(1) lookup
  - [x] 2.2: Recompute `pending` after filtering — filter reduces the count but pending should reflect unfiltered remaining changes (CouchDB behavior: pending is unfiltered)
  - [x] 2.3: Compile via MCP

- [x] Task 3: Implement `_design` filter (AC: #3)
  - [x] 3.1: During post-processing loop, if `filter=_design`:
    - Skip entries where `tDocId` does NOT start with `_design/`
    - Use `$Extract(tDocId, 1, 8) = "_design/"` for the check
  - [x] 3.2: Compile via MCP

- [x] Task 4: Implement `_selector` filter (AC: #2)
  - [x] 4.1: The `_selector` filter requires matching document bodies against a Mango selector. Since the full Mango query engine (Epic 6) does not exist yet, implement a **simple subset matcher** that handles the most common cases:
    - **Equality**: `{"field": "value"}` — check if doc.field equals value
    - **Nested equality**: `{"a": {"b": "value"}}` — check nested field access (if the nested value is NOT an operator like $eq, treat as literal equality)
    - **$eq operator**: `{"field": {"$eq": "value"}}` — explicit equality
    - **$exists operator**: `{"field": {"$exists": true/false}}` — check field presence
    - **Unsupported operators**: `$gt`, `$lt`, `$in`, `$and`, `$or`, etc. — if encountered, the filter matches ALL documents (permissive fallback, logged as a limitation)
  - [x] 4.2: Create a helper method `ClassMethod MatchesSelector(pSelector As %DynamicObject, pDoc As %DynamicObject) As %Boolean` in ChangesHandler (or a separate utility class if it would exceed 500 lines):
    - Iterate selector keys
    - For each key, if value is a string/number/boolean → equality check against doc field
    - If value is an object with `$eq` → equality check
    - If value is an object with `$exists` → field presence check
    - If value is an object with unknown operator → return true (permissive)
    - All selector conditions must match (implicit $and)
  - [x] 4.3: During post-processing loop, if `filter=_selector`:
    - Read the document body via `Storage.Document.Read(pDB, tDocId, tRev)`
    - Parse the body and call `MatchesSelector(tSelector, tDocObj)`
    - Skip entries that don't match
    - For deleted documents, skip them (deleted docs can't match selectors)
  - [x] 4.4: Compile via MCP

- [x] Task 5: Apply filters to longpoll results (AC: #5)
  - [x] 5.1: The filtering logic in the post-processing loop already applies to ALL feed modes (normal and longpoll), since the longpoll path falls through to the same post-processing code after receiving changes. Verify this works correctly — no additional code should be needed.
  - [x] 5.2: Compile and verify

- [x] Task 6: Create unit tests `Test/ChangesFilterTest.cls` (AC: #1-#4)
  - [x] 6.1: Create `src/IRISCouch/Test/ChangesFilterTest.cls` extending `%UnitTest.TestCase`
  - [x] 6.2: `OnBeforeOneTest` / `OnAfterOneTest` — kill globals for "testfilterdb", create fresh db
  - [x] 6.3: `TestDocIdsFilter` — create 3 docs ("doc1", "doc2", "doc3"), get all changes, filter by doc_ids=["doc1","doc3"], assert only 2 results with matching IDs
  - [x] 6.4: `TestDesignFilter` — create docs "_design/myview" and "regular-doc", get all changes, filter by _design, assert only 1 result with ID starting with "_design/"
  - [x] 6.5: `TestSelectorFilterEquality` — create docs with body `{"type":"order"}` and `{"type":"user"}`, get all changes, filter with selector `{"type":"order"}`, assert only the order doc is returned
  - [x] 6.6: `TestSelectorFilterExists` — create docs with and without "email" field, filter with selector `{"email":{"$exists":true}}`, assert only docs with email field are returned
  - [x] 6.7: `TestUnsupportedFilter` — verify that filter="custom_filter" is treated as unsupported (test the validation logic)

- [x] Task 7: Create HTTP integration tests `Test/ChangesFilterHttpTest.cls` (AC: #1-#5)
  - [x] 7.1: Create `src/IRISCouch/Test/ChangesFilterHttpTest.cls` extending `%UnitTest.TestCase`
  - [x] 7.2: `OnBeforeOneTest` / `OnAfterOneTest` — kill globals for "testfilterhttpdb", create fresh db
  - [x] 7.3: `TestDocIdsFilterHttp` — create 3 docs, `POST /{db}/_changes?filter=_doc_ids` with body `{"doc_ids":["doc1","doc3"]}` → 200, verify 2 results
  - [x] 7.4: `TestDesignFilterHttp` — create "_design/test" and "normal-doc", `GET /{db}/_changes?filter=_design` → 200, verify 1 result
  - [x] 7.5: `TestSelectorFilterHttp` — create docs with different types, `POST /{db}/_changes?filter=_selector` with body `{"selector":{"type":"order"}}` → 200, verify only matching docs
  - [x] 7.6: `TestUnknownFilterHttp` — `GET /{db}/_changes?filter=my_custom_filter` → 404, verify error envelope
  - [x] 7.7: `TestDocIdsFilterQueryStringHttp` — `GET /{db}/_changes?filter=_doc_ids&doc_ids=["doc1"]` → 200, verify works with query string too
  - [x] 7.8: `TestLongpollWithFilterHttp` — create 2 docs ("doc1" with type=A, "doc2" with type=B), `GET /{db}/_changes?feed=longpoll&since=0&filter=_doc_ids` with body `{"doc_ids":["doc1"]}` → 200, verify only doc1 in results (immediate return since changes exist)

- [x] Task 8: Run full test suite (AC: #6)
  - [x] 8.1: All existing 149 tests pass (zero regressions)
  - [x] 8.2: All new tests pass

### Review Findings

- [x] [Review][Patch] Redundant document read when _selector + include_docs combined [ChangesHandler.cls:235,287] -- Auto-resolved: reuse parsed doc object from selector matching in include_docs path
- [x] [Review][Defer] Storage encapsulation: test files directly Kill ^IRISCouch.* globals [ChangesFilterTest.cls:19-24, ChangesFilterHttpTest.cls:19-24] -- deferred, pre-existing pattern used across all test files
- [x] [Review][Defer] Missing test: _selector filter with deleted documents [ChangesFilterTest.cls] -- deferred, edge case coverage gap; add when delete+filter interaction is explicitly specified

## Dev Notes

### Filter Parameter Parsing

The `filter` parameter specifies which built-in filter to apply:
- `filter=_doc_ids` — filter by document IDs (requires `doc_ids` parameter)
- `filter=_selector` — filter by Mango selector (requires `selector` in POST body)
- `filter=_design` — filter for design documents only (no extra params)
- `filter=` or absent — no filter (all changes returned)
- Any other value → 404 Not Found

### _doc_ids Filter

The `doc_ids` parameter can come from:
1. **POST body**: `{"doc_ids": ["doc1", "doc2"]}` — native JSON array
2. **Query string**: `?doc_ids=["doc1","doc2"]` — JSON-encoded string that needs parsing

For efficient lookup, build a local array:
```objectscript
; From %DynamicArray
Set tI = 0
While tI < tDocIds.%Size() {
    Set tDocIdFilter(tDocIds.%Get(tI)) = 1
    Set tI = tI + 1
}
; In the filter check:
If '$Data(tDocIdFilter(tDocId)) Continue
```

### _selector Filter — Simple Subset

The full Mango query engine is Epic 6. For Story 4.3, implement a minimal selector matcher:

```objectscript
; Selector: {"type": "order", "status": {"$eq": "active"}}
; For each key in selector:
;   If value is scalar → equality: doc.key must equal value
;   If value is object with $eq → equality: doc.key must equal $eq value
;   If value is object with $exists → presence: doc.key must exist (or not)
;   If value is object with unknown op → match all (permissive fallback)
```

The `_selector` filter requires reading the document body for each change entry. This is the same read used by `include_docs=true` — if both are specified, reuse the read.

### _design Filter

Simple prefix check:
```objectscript
If $Extract(tDocId, 1, 8) '= "_design/" Continue
```

Note: Design documents don't exist yet in IRISCouch (Epic 12+), but the filter should work correctly when they do. For testing, create documents with IDs starting with `_design/` — DocumentHandler.HandlePut doesn't currently block underscore-prefixed IDs.

### pending Count with Filters

CouchDB's `pending` field reflects UNFILTERED remaining changes. The filter only affects which entries appear in `results`, not the `pending` count. This means `pending` from `Storage.Changes.ListChanges()` is used as-is — no adjustment needed after filtering.

### Filter Application Point

Filters are applied in the post-processing loop (lines 164-226 of ChangesHandler). This loop already runs for both normal and longpoll modes, so filters automatically apply to both (AC #5).

The filter check should be the FIRST thing in the loop body — before style/include_docs processing — to skip filtered-out entries early:

```objectscript
While tI < tRawResults.%Size() {
    Set tEntry = tRawResults.%Get(tI)
    Set tI = tI + 1
    Set tDocId = tEntry.%Get("id")
    ; Apply filter early
    If tFilter = "_doc_ids" {
        If '$Data(tDocIdFilter(tDocId)) Continue
    } ElseIf tFilter = "_design" {
        If $Extract(tDocId, 1, 8) '= "_design/" Continue
    } ElseIf tFilter = "_selector" {
        ; Read doc and match selector...
    }
    ; ... rest of processing
}
```

### Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `src/IRISCouch/API/ChangesHandler.cls` | **Modify** | Add filter parameter parsing, _doc_ids/_design/_selector filtering, MatchesSelector helper |
| `src/IRISCouch/Test/ChangesFilterTest.cls` | **Create** | Unit tests for filter logic |
| `src/IRISCouch/Test/ChangesFilterHttpTest.cls` | **Create** | HTTP integration tests for filtered changes |

### Established Patterns

- Handler catch: `RenderInternal()` then `Quit $$$OK`
- Storage encapsulation: all `^IRISCouch.*` access through Storage.* classes only
- Response: `Response.JSON(tResult)` for 200
- Inner catch pattern: use `Return $$$OK` not `Quit` to exit method entirely
- Query params: `$Get(%request.Data("paramname", 1))`
- POST body parse: `%DynamicObject.%FromJSON(tContent)` with inner try/catch using `Return`
- Quit-in-loop: use `Continue` to skip entries in while loops

### Previous Story Intelligence (Story 4.2)

- 149 tests passing across 24 test classes
- ChangesHandler is 243 lines — well under 500 limit, room for filter logic
- POST body is already parsed into `tBodyObj` for parameter extraction — can also extract `doc_ids` and `selector` from it
- The post-processing loop (lines 164-226) is where filtering should be injected
- Longpoll falls through to the same post-processing code — filters apply automatically

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.3] — Acceptance criteria
- [Source: _bmad-output/planning-artifacts/architecture.md:714-717] — Changes/Filter.cls for built-in filters
- [Source: _bmad-output/planning-artifacts/architecture.md:880] — Changes.Filter mentioned
- [Source: src/IRISCouch/API/ChangesHandler.cls] — Current handler with normal + longpoll modes
- [Source: src/IRISCouch/Storage/Changes.cls] — ListChanges returns raw results for post-processing

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- Design doc HTTP test initially failed due to REST router not supporting slashes in document IDs (`/:db/:docid` can't handle `_design/test`). Fixed by creating design docs via DocumentEngine directly in HTTP tests.

### Completion Notes List
- Implemented `filter`, `doc_ids`, and `selector` parameter parsing in ChangesHandler for both GET query string and POST body
- Added filter validation: `_doc_ids`, `_selector`, `_design`, or empty are valid; any other value returns 404 `{"error":"not_found","reason":"missing"}`
- Implemented `_doc_ids` filter using local array `tDocIdFilter(docId)=1` for O(1) lookup, supporting both POST body arrays and query string JSON-encoded arrays
- Implemented `_design` filter using `$Extract(tDocId, 1, 8) = "_design/"` prefix check
- Implemented `_selector` filter with `MatchesSelector()` class method supporting equality, `$eq`, `$exists` operators, and permissive fallback for unsupported operators
- Selector filter skips deleted documents (they can't match selectors)
- Filters applied early in post-processing loop (before style/include_docs) for efficiency
- `pending` count remains unfiltered per CouchDB behavior
- Filters automatically apply to longpoll mode since both paths share the same post-processing loop
- 7 unit tests + 6 HTTP integration tests = 13 new tests
- All 149 existing tests pass with zero regressions (162 total)

### File List
- `src/IRISCouch/API/ChangesHandler.cls` — Modified: added filter/doc_ids/selector parameter parsing, _doc_ids/_design/_selector filter logic in post-processing loop, MatchesSelector() helper method
- `src/IRISCouch/Test/ChangesFilterTest.cls` — Created: 7 unit tests for filter logic (doc_ids, design, selector equality, selector $exists, unsupported filter validation, $eq operator, empty selector)
- `src/IRISCouch/Test/ChangesFilterHttpTest.cls` — Created: 6 HTTP integration tests (doc_ids POST, design, selector, unknown filter 404, doc_ids query string, longpoll with filter)

## Change Log
- 2026-04-12: Story 4.3 implemented — added _doc_ids, _design, and _selector built-in changes filters with 13 new tests (162 total, zero regressions)
