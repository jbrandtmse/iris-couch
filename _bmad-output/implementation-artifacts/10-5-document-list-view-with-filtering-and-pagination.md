# Story 10.5: Document List View with Filtering & Pagination

Status: done

## Story

As an operator,
I want to browse documents in a database with filtering and pagination,
so that I can find and navigate to specific documents.

## Acceptance Criteria

1. **Given** a database with documents
   **When** the document list is displayed
   **Then** a DataTable shows `_id` (monospace) and `_rev` (monospace, truncated to 8 chars with hover-for-full or click-to-copy) columns
   **And** default sort is `_id` ascending
   **And** design documents appear inline with a subtle `[design]` Badge
   **And** tombstoned documents show `[deleted]` Badge with greyed row

2. **Given** a filter bar above the document list
   **When** the operator types in the filter input labeled "filter by `_id` prefix"
   **Then** filtering uses `startkey`/`endkey` prefix matching with 150ms debounce
   **And** the filter state is reflected in the URL
   **And** a clear-filter IconButton appears inside the input's right edge

3. **Given** the `/` key is pressed on the document list
   **When** the key event fires
   **Then** focus moves to the filter input

4. **Given** the document list has more documents than the page size
   **When** pagination controls are displayed
   **Then** Pagination uses `startkey`-based forward/backward controls
   **And** shows range indicator ("rows 1-25 of ~42,187") with approximate total
   **And** no page numbers are shown
   **And** `startkey` is reflected in the URL query parameter for stable browser back

5. **Given** the operator navigates to a document detail and presses browser back
   **When** the document list is restored
   **Then** pagination, sort, filter, and scroll position are preserved via Angular router state

6. **Given** all URLs in the document list view
   **When** they are examined
   **Then** `/_utils/db/{dbname}/` is deep-linkable, bookmarkable, and survives browser refresh

## Tasks / Subtasks

- [x] Task 1: Document API service (AC: #1, #2, #4)
  - [x] Create `src/app/services/document.service.ts`:
    - `listDocuments(db, options): Observable<AllDocsResponse>` — GET `/{db}/_all_docs` with query params
    - Options: `limit`, `skip`, `startkey`, `endkey`, `include_docs`, `descending`
    - Define `AllDocsResponse` interface: `{total_rows, offset, rows: [{id, key, value: {rev, deleted?}}]}`
  - [x] Create spec with mock HTTP tests

- [x] Task 2: Pagination component (AC: #4)
  - [x] Create `src/app/couch-ui/pagination/pagination.component.ts` as standalone
  - [x] Inputs: `startIndex`, `endIndex`, `totalRows` (approximate), `hasNext`, `hasPrevious`
  - [x] Outputs: `next`, `previous` events
  - [x] Range indicator: "rows 1-25 of ~42,187" with tabular-nums
  - [x] Previous/Next buttons with `aria-label`, disabled at boundaries
  - [x] No page numbers (CouchDB `startkey`-based pagination)
  - [x] Create spec with axe-core

- [x] Task 3: Document list feature component (AC: #1, #2, #3, #4, #5, #6)
  - [x] Replace placeholder `src/app/features/database/database-detail.component.ts` or create `src/app/features/documents/document-list.component.ts`
  - [x] Route: `/db/:dbname` — reads dbname from route params
  - [x] On init: fetch documents via `_all_docs?limit=25&include_docs=false`
  - [x] DataTable columns:
    - `_id`: monospace, left-aligned (with `[design]` Badge for `_design/` prefix)
    - `_rev`: monospace, truncated to 8 chars, hover shows full rev, CopyButton inline
  - [x] Tombstoned rows: `[deleted]` Badge (warn variant), greyed row styling
  - [x] Default sort: `_id` ascending (server-side via `_all_docs` natural order)
  - [x] Row click: navigate to `/db/{dbname}/doc/{docid}`
  - [x] PageHeader: title is database name (mono), breadcrumb [Databases > {dbname}], fetched-at, refresh
  - [x] Filter bar:
    - TextInput labeled "filter by _id prefix"
    - 150ms debounce on input
    - Converts to `startkey="{prefix}"&endkey="{prefix}\ufff0"` (CouchDB prefix trick)
    - Clear-filter IconButton (x icon) inside input right edge
    - Filter state reflected in URL query param `?filter={prefix}`
  - [x] `/` key focuses the filter input
  - [x] Pagination:
    - Page size: 25 rows
    - Forward: use last row's key as startkey for next page
    - Backward: use first row's key with descending=true, then reverse
    - `startkey` in URL query param for stable browser back
    - Range indicator with approximate total from `total_rows`
  - [x] Router state preservation: filter, pagination startkey, scroll position survive back navigation
  - [x] Create spec with table rendering, filtering, pagination, badge display + axe-core

- [x] Task 4: Route configuration update (AC: #6)
  - [x] Ensure `/db/:dbname` route maps to document list component
  - [x] Ensure URLs are deep-linkable with query params (filter, startkey)
  - [x] Verify browser refresh preserves state

- [x] Task 5: Integration and verification
  - [x] Update barrel exports
  - [x] Run `ng test` — all tests pass (345 tests, 0 failures)
  - [x] Run `ng build --configuration=production` — clean build (122.37 kB gzip)
  - [x] Verify via `ng serve` + Chrome DevTools MCP:
    - Document list renders with real data
    - Filter by _id prefix works with debounce
    - Pagination forward/backward works
    - Design doc and deleted doc badges display correctly
    - Row click navigates to document detail
    - Browser back preserves state
    - URL is deep-linkable

### Review Findings
- [x] [Review][Patch] HTTP subscription leak in loadDocuments() -- rapid calls (pagination, filter) could overlap requests and show stale data [database-detail.component.ts:265] -- FIXED: cancel previous request via activeRequest?.unsubscribe()
- [x] [Review][Patch] Error handler swallows all errors silently -- no user feedback on API failure [database-detail.component.ts:301] -- FIXED: added errorMessage state and error display EmptyState
- [x] [Review][Patch] Missing Escape key handler -- aria hint promises Escape clears filter but no handler exists [database-detail.component.ts:239] -- FIXED: added Escape key handling in onKeyDown
- [x] [Review][Patch] Unused DataTableComponent import -- imported but custom table used instead [database-detail.component.ts:7,35] -- FIXED: removed dead import
- [x] [Review][Defer] paginationStart assumes linear page history -- range indicator math uses pageHistory.length * PAGE_SIZE, inaccurate if any page had fewer rows -- deferred, cosmetic only for approximate indicator
- [x] [Review][Defer] totalRows reflects total DB doc count not filtered count -- CouchDB _all_docs total_rows is always full DB count, range indicator shows approximate total even with filter active -- deferred, by design per CouchDB API

## Dev Notes

### CouchDB API: `_all_docs`

- `GET /{db}/_all_docs?limit=25&include_docs=false` — returns `{total_rows, offset, rows: [{id, key, value: {rev}}]}`
- Prefix filter: `startkey="prefix"&endkey="prefix\ufff0"` — the `\ufff0` high Unicode char ensures all keys with the prefix are included
- Pagination: `startkey` for forward, `startkey` + `descending=true` for backward (then reverse the results)
- Deleted docs: `value.deleted` is `true` for tombstoned documents
- Design docs: `_id` starts with `_design/`
- `total_rows` is the total doc count in the database (approximate for filtered results)

### Architecture Compliance

- Document service in `src/app/services/`
- Pagination component in `src/app/couch-ui/`
- Document list feature in `src/app/features/documents/` or `src/app/features/database/`
- All components standalone with colocated specs and axe-core assertions

### Previous Story Intelligence (10.4)

- DataTable, EmptyState, ConfirmDialog, PageHeader all exist in couch-ui/
- DatabaseService in services/
- CouchApiService with get/post/put/delete
- 283 tests passing, 116.10KB gzip
- DataTable supports columns, sorting, row click — reuse directly
- PageHeader supports title, fetchedAt, loading, refresh, content projection

### References

- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#DataTable, Pagination]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 10.5]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- Fixed HttpTestingController URL matching (URLSearchParams builds query string into URL path)
- Fixed axe-core color contrast violation on filter shortcut hint (color-neutral-400 -> color-neutral-600)
- Fixed fakeAsync periodic timer leak from PageHeader's setInterval (added discardPeriodicTasks)
- Optimized component CSS to stay under 2KB budget warning threshold

### Completion Notes List
- Task 1: Created DocumentService with typed AllDocsResponse, AllDocsRow, and ListDocumentsOptions interfaces. Uses URLSearchParams to build query strings with JSON-encoded startkey/endkey. 10 tests.
- Task 2: Created PaginationComponent as standalone couch-ui primitive. Range indicator with tabular-nums, chevron left/right navigation, disabled states at boundaries. 15 tests including axe-core.
- Task 3: Replaced placeholder DatabaseDetailComponent with full document list view. Custom table (not DataTable component) for rich cell content with badges and copy buttons. Filter bar with 150ms debounce using RxJS Subject. Pagination via startkey with page history stack for backward navigation. Design doc badge (info), deleted doc badge (warn) with greyed row. URL query params for filter and startkey. '/' keyboard shortcut for filter focus. 37 tests including axe-core.
- Task 4: Route configuration already correct from Story 10.4. Verified /db/:dbname maps to DatabaseDetailComponent with authGuard. Query params supported by Angular router.
- Task 5: Added PaginationComponent to couch-ui barrel exports. All 345 tests pass. Production build clean at 122.37 kB gzip.

### Change Log
- 2026-04-14: Story 10.5 implemented - Document list view with filtering and pagination

### File List
- ui/src/app/services/document.service.ts (new)
- ui/src/app/services/document.service.spec.ts (new)
- ui/src/app/couch-ui/pagination/pagination.component.ts (new)
- ui/src/app/couch-ui/pagination/pagination.component.spec.ts (new)
- ui/src/app/features/database/database-detail.component.ts (modified - replaced placeholder)
- ui/src/app/features/database/database-detail.component.spec.ts (new)
- ui/src/app/couch-ui/index.ts (modified - added PaginationComponent export)
