# Story 10.6: Document Detail View

Status: done

## Story

As an operator,
I want to view a document's full JSON body, metadata, and attachments,
so that I can inspect document content and state.

## Acceptance Criteria

1. **Given** a document exists
   **When** the document detail view is displayed
   **Then** the header zone shows breadcrumb, `_id` in large monospace with CopyButton, full `_rev` in monospace with CopyButton, and fetched-at timestamp with refresh button

2. **Given** a document with special states
   **When** the header is rendered
   **Then** appropriate badges are shown: `[deleted]` (warn), `[has conflicts: N]` (warn), `[has attachments: N]` (info)

3. **Given** a document's JSON body
   **When** the body zone is rendered
   **Then** JsonDisplay shows the document in read-only pre-formatted monospace with palette-based syntax coloring (keys in neutral-700, strings in neutral-900, numbers in neutral-800, booleans/null in info)
   **And** non-selectable line numbers appear on the left
   **And** the content is the exact bytes of the HTTP response, pretty-printed with 2-space indent, no key reordering, no type coercion
   **And** `role="textbox" aria-readonly="true" aria-label="Document JSON"` is set
   **And** a "Copy raw JSON" button strip appears above the JSON display

4. **Given** a document with attachments
   **When** the attachment zone is rendered
   **Then** a compact list shows each attachment's name (monospace), content-type, length (human-readable), and digest (monospace, truncated)
   **And** a download button links directly to `GET /{db}/{docid}/{attname}`

5. **Given** a document with conflicts and `[has conflicts: N]` badge
   **When** the badge is clicked
   **Then** all conflicting revisions are listed with the ability to click through and inspect each one

6. **Given** every `_id`, `_rev`, database name, and JSON body on the page
   **When** the user wants to copy
   **Then** a CopyButton is available next to each value
   **And** "Copy raw JSON" produces byte-identical output to `curl /db/id`

7. **Given** a document that does not exist (404)
   **When** the detail view is loaded
   **Then** an ErrorDisplay shows the verbatim JSON error envelope in-place where the document would appear with a 404 Badge

8. **Given** the URL `/_utils/db/{dbname}/doc/{docid}`
   **When** it is loaded directly
   **Then** the view renders correctly as a standalone entry point

## Tasks / Subtasks

- [x] Task 1: Document detail API method (AC: #1, #2, #3, #4, #5)
  - [x] Add to `DocumentService`:
    - `getDocument(db, docid, options?): Observable<any>` — GET `/{db}/{docid}?conflicts=true&attachments=false`
    - Always request `?conflicts=true` to detect conflict state
    - Returns full document body with `_id`, `_rev`, `_conflicts`, `_attachments` metadata

- [x] Task 2: JsonDisplay component (AC: #3, #6)
  - [x] Create `src/app/couch-ui/json-display/json-display.component.ts` as standalone
  - [x] Input: `json: string` — raw JSON string (exact bytes from HTTP response)
  - [x] Pretty-print with 2-space indent via `JSON.stringify(JSON.parse(json), null, 2)`
  - [x] Syntax coloring using design tokens (tiny custom tokenizer, NOT Prism/Highlight.js):
    - Keys: `--color-neutral-700`
    - Strings: `--color-neutral-900`
    - Numbers: `--color-neutral-800`
    - Booleans/null: `--color-info`
  - [x] Non-selectable line numbers on the left (CSS `user-select: none` on line number gutter)
  - [x] Monospace font throughout (`--font-mono`)
  - [x] `role="textbox" aria-readonly="true" aria-label="Document JSON"`
  - [x] Selectable text in the JSON content area (operators copy sub-regions)
  - [x] "Copy raw JSON" CopyButton (block variant) above the display
  - [x] Create spec with syntax coloring verification + axe-core

- [x] Task 3: Document detail feature component (AC: #1, #2, #4, #5, #7, #8)
  - [x] Replace placeholder `src/app/features/document/document-detail.component.ts`
  - [x] Route: `/db/:dbname/doc/:docid` — reads both params
  - [x] On init: fetch document via `GET /{db}/{docid}?conflicts=true`
  - [x] Header zone:
    - Breadcrumb: [Databases > {dbname} > {docid}]
    - `_id` in large monospace (`--font-size-lg`) with CopyButton
    - Full `_rev` in monospace with CopyButton
    - Fetched-at timestamp with refresh button (PageHeader)
  - [x] Status badges:
    - `[deleted]` (warn) if doc has `_deleted: true`
    - `[has conflicts: N]` (warn) if `_conflicts` array exists and non-empty
    - `[has attachments: N]` (info) if `_attachments` object exists and non-empty
  - [x] Body zone: JsonDisplay with the raw document JSON
  - [x] Attachment zone (if `_attachments` exists):
    - Compact list/table: name (mono), content_type, length (human-readable), digest (mono, truncated to 12 chars)
    - Download button: links to `/{db}/{docid}/{attname}` (standard `<a>` tag)
  - [x] Conflicts zone (if `_conflicts` exists):
    - Clickable badge reveals list of conflicting rev strings
    - Each conflict rev is clickable — fetches that revision via `GET /{db}/{docid}?rev={conflictRev}`
    - Displays the conflicting revision's body in a secondary JsonDisplay
  - [x] Error handling: 404 shows ErrorDisplay in-place with verbatim error envelope
  - [x] Deep-linkable: `/_utils/db/{dbname}/doc/{docid}` works as standalone entry point
  - [x] Create spec with document rendering, badges, attachments, conflicts, 404 error + axe-core

- [x] Task 4: Integration and verification
  - [x] Update barrel exports for JsonDisplay
  - [x] Run `ng test` — all tests pass (395 total, 0 failures)
  - [x] Run `ng build --configuration=production` — clean build (124.91KB gzip)
  - [x] Verify via `ng serve` + Chrome DevTools MCP:
    - Deep-linking verified: /_utils/db/{dbname}/doc/{docid} correctly redirects to login with returnUrl preserved
    - Browser verification of live data blocked by missing proxy config (no IRIS backend accessible from dev server)
    - All functionality verified through comprehensive unit/integration tests (46 new tests)

## Dev Notes

### CouchDB API: Document GET

- `GET /{db}/{docid}` — returns full document body
- `?conflicts=true` — includes `_conflicts` array with conflicting leaf revisions
- `?rev={rev}` — retrieves a specific revision
- `_attachments` is included in the response as stubs: `{"{name}": {content_type, length, digest, stub: true}}`
- Attachment download: `GET /{db}/{docid}/{attname}` — returns raw binary
- 404 response: `{"error":"not_found","reason":"missing"}`

### JsonDisplay Syntax Coloring (from UX spec)

- Keys: `--color-neutral-700` (#374050)
- Strings: `--color-neutral-900` (#12161F)
- Numbers: `--color-neutral-800` (#242B38)
- Booleans/null: `--color-info` (#3C5A9E)
- All weight 400, no bold, no italic
- No rainbow coloring — palette-only

### Architecture Compliance

- JsonDisplay in `src/app/couch-ui/` (domain-free, reused for design docs in Epic 11)
- Document detail feature in `src/app/features/document/`
- Document service method added to existing `src/app/services/document.service.ts`

### Previous Story Intelligence (10.5)

- DocumentService exists with `listDocuments()`, add `getDocument()` method
- DataTable, PageHeader, Breadcrumb, Badge, CopyButton, ErrorDisplay all available
- 349 tests passing, 122.37KB gzip
- Routes already configured: `/db/:dbname/doc/:docid` maps to placeholder

### References

- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#JsonDisplay]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 10.6]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
N/A - no debugging issues encountered

### Completion Notes List
- Task 1: Added `getDocument(db, docid, options?)` method to DocumentService with `?conflicts=true` default. Added `GetDocumentOptions` interface. 7 new unit tests covering normal docs, conflicts, attachments, special characters, and 404 errors.
- Task 2: Created JsonDisplayComponent as standalone in `couch-ui/json-display/`. Tiny custom tokenizer produces spans for keys, strings, numbers, booleans, null, and punctuation. Palette-based syntax coloring via CSS custom properties. Non-selectable line numbers with `user-select: none`. Copy raw JSON button strip above display. 17 new unit tests including axe-core accessibility.
- Task 3: Replaced placeholder DocumentDetailComponent with full implementation. Header zone with _id (large mono + CopyButton), _rev (mono + CopyButton), breadcrumbs, PageHeader with refresh. Status badges: [deleted] warn, [has conflicts: N] warn, [has attachments: N] info. Body zone with JsonDisplay. Attachment table with name, content_type, human-readable size, truncated digest, download links. Conflicts zone with clickable badge toggle and per-revision fetch with secondary JsonDisplay. 404 error handling with ErrorDisplay. 22 new unit tests including axe-core accessibility.
- Task 4: Updated barrel exports. Full test suite: 395 tests, 0 failures (up from 349). Production build: 124.91KB gzip. Deep-linking verified via Chrome DevTools MCP (returnUrl correctly preserved in auth redirect).
- Production build shows 2 CSS budget warnings (button 2.28KB and document-detail 2.41KB vs 2.05KB warn threshold) -- warnings only, not errors.

### File List
- ui/src/app/services/document.service.ts (modified - added getDocument method and GetDocumentOptions interface)
- ui/src/app/services/document.service.spec.ts (modified - added 7 getDocument tests)
- ui/src/app/couch-ui/json-display/json-display.component.ts (new - JsonDisplay component)
- ui/src/app/couch-ui/json-display/json-display.component.spec.ts (new - 17 tests)
- ui/src/app/couch-ui/index.ts (modified - added JsonDisplayComponent export)
- ui/src/app/features/document/document-detail.component.ts (modified - replaced placeholder with full implementation)
- ui/src/app/features/document/document-detail.component.spec.ts (new - 22 tests)

### Review Findings
- [x] [Review][Patch] Copy raw JSON copies pretty-printed instead of raw input [json-display.component.ts:37] -- Fixed: CopyButton now binds to `json` (raw input) instead of `prettyJson`
- [x] [Review][Patch] Conflict rev subscription leak on rapid clicks [document-detail.component.ts:388] -- Fixed: added `conflictRequest` tracking with unsubscribe before new request + cleanup in ngOnDestroy
- [x] [Review][Patch] Attachment download URL missing leading slash [document-detail.component.ts:414] -- Fixed: added leading `/` to `getAttachmentUrl` return value
- [x] [Review][Patch] No test for conflict rev fetch-and-display (AC #5) [document-detail.component.spec.ts] -- Fixed: added test that clicks conflict rev button, flushes HTTP request, verifies secondary JsonDisplay
- [x] [Review][Defer] Design doc ID double-encoding in getDocument/getAttachmentUrl -- deferred, design docs handled in Epic 11

### Change Log
- 2026-04-14: Implemented Story 10.6 Document Detail View - all 4 tasks complete, 46 new tests, 395 total passing
- 2026-04-14: Code review - 4 patches applied (copy raw JSON, subscription leak, attachment URL, missing test), 1 deferred, 6 dismissed. 396 tests passing.
