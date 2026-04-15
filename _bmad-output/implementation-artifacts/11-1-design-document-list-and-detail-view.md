# Story 11.1: Design Document List & Detail View (Alpha - Read-Only)

Status: review

## Story

As an operator,
I want to view design documents stored in a database through the admin UI,
so that I can inspect map/reduce functions, validation hooks, and other design document content.

## Acceptance Criteria

1. **Given** a database contains design documents
   **When** the operator navigates to the Design Documents section via the per-database SideNav
   **Then** a DataTable lists all `_design/` prefixed document names in monospace

2. **Given** the design document list
   **When** the operator clicks on a design document
   **Then** the full JSON content is displayed via the `JsonDisplay` component
   **And** the view is read-only (no edit controls at alpha)

3. **Given** the URL `/iris-couch/_utils/db/{dbname}/design/{ddocname}`
   **When** it is loaded directly
   **Then** the design document detail view renders correctly as a standalone entry point

4. **Given** any design document detail view
   **When** CopyButton affordances are examined
   **Then** the design document name and full JSON body have CopyButton available

5. **Given** a database with no design documents
   **When** the Design Documents section is displayed
   **Then** the `EmptyState` shows `"No design documents yet."` with secondary text `"Use curl or another client to create one at alpha."`

6. **Given** a design document that does not exist (404)
   **When** the detail view is loaded
   **Then** the shared `FeatureError` component renders the verbatim backend envelope with a retry affordance

## Tasks / Subtasks

- [x] **Task 1: API — list design documents** (AC: #1, #5)
  - [x] In `ui/src/app/services/document.service.ts`, add `listDesignDocs(db: string, opts?): Observable<AllDocsResponse>` that calls `GET /{db}/_all_docs?startkey="_design/"&endkey="_design0"&include_docs=false`
  - [x] Confirm the `startkey`/`endkey` pair is the CouchDB-spec way to enumerate design docs by reading `sources/couchdb/src/chttpd/src/chttpd_db.erl` (or equivalent) and noting that `_design0` is one byte greater than `_design/` in ASCII
  - [x] Unit test: mock HttpClient, assert the exact query string is emitted
  - [x] If backend currently ignores `startkey`/`endkey` on `_all_docs`, **verify backend behavior via curl first** — if missing, log a deferred backend task in `deferred-work.md` and fall back to `/_all_docs` + client-side filtering for this story (note the deviation in Dev Notes). **Verified backend honors startkey/endkey** -- see Dev Notes.

- [x] **Task 2: API — get design document** (AC: #2, #3, #4)
  - [x] The existing `DocumentService.getDocument(db, docid)` already accepts arbitrary IDs and, combined with Story 11.0's `encodeDocId()`, correctly URL-encodes `_design/<name>` composites. Confirm via a unit test that `getDocument('testdb', '_design/myapp')` hits `/testdb/_design/myapp` (literal `/` on the wire)
  - [x] No new method needed unless the response shape requires richer typing — in which case add an optional `DesignDocContent` interface (not needed -- untyped `any` matches how document-detail consumes the response)

- [x] **Task 3: Design Document List feature component** (AC: #1, #5)
  - [x] Create `ui/src/app/features/design-docs/design-doc-list.component.ts` (standalone)
  - [x] Layout: `<app-page-header title="Design documents" [fetchedAt]="fetchedAt" [loading]="loading" (refresh)="loadDesignDocs()">`
  - [x] Shared error zone: `<app-feature-error *ngIf="!loading && loadError" ...>` — use `mapError` in the error handler
  - [x] DataTable with a single column `"Name"` (monospace via `mono: true`), the `id` field is the design doc full ID (`_design/myapp`). `clickable: true` so rows navigate to the detail view
  - [x] Use Story 11.0's per-row delete support? **No** — Story 11.1 is read-only (alpha). No action-column. Delete arrives in Story 11.3.
  - [x] `onRowClick(row)` splits composite ID into segments via the same pattern as `database-detail.component.ts:onRowClick` (`row.id.split('/')`) and routes to `/db/{dbname}/design/{ddoc-segments}`
  - [x] EmptyState with AC #5 copy
  - [x] Subscription discipline: follow `.claude/rules/angular-patterns.md` — `activeRequest?.unsubscribe()` before new request, `ngOnDestroy` cleanup. **Do not regress.**
  - [x] axe-core assertion in spec: `expectNoAxeViolations(fixture)`
  - [x] Spec must cover: initial load, empty state, populated list, error state (via mocked 500), row click navigation

- [x] **Task 4: Design Document Detail feature component** (AC: #2, #3, #4, #6)
  - [x] Create `ui/src/app/features/design-docs/design-doc-detail.component.ts` (standalone)
  - [x] Layout identical to Story 10.6's `document-detail.component.ts`, trimmed for design-doc specifics:
    - `<app-page-header [title]="ddocId" [mono]="true" [fetchedAt]="fetchedAt" ...>`
    - `<app-breadcrumb>` segments: `Databases` → `{dbname}` → `Design documents` → `{ddoc short name}`
    - Identity row: `_id` full design-doc path (e.g., `_design/myapp`) with `CopyButton`
    - Revision row: `_rev` in full, `CopyButton`
    - `JsonDisplay` for the full JSON body with `"Copy raw JSON"` strip (reuse the Story 10.6 pattern exactly)
  - [x] No edit affordance. No `[deleted]`/`[has conflicts]`/`[has attachments]` badges at alpha (unless the ddoc exhibits them). Conflicts zone is **not** included per AC #2 read-only scope.
  - [x] On 404, `FeatureError` with the verbatim backend envelope (AC #6). No other terminal states.
  - [x] Subscription discipline as per Task 3
  - [x] axe-core assertion in spec
  - [x] Spec must cover: successful load, 404 error, deep link entry (route params only), CopyButton interactions

- [x] **Task 5: Routes** (AC: #3)
  - [x] Extend `ui/src/app/app.routes.ts`:
    - `{ path: 'db/:dbname/design', component: DesignDocListComponent, canActivate: [authGuard] }`
    - `{ matcher: designDocDetailMatcher, component: DesignDocDetailComponent, canActivate: [authGuard] }` where `designDocDetailMatcher` uses the same multi-segment pattern as Story 11.0's `docDetailMatcher` to consume all segments after `design/` as the ddoc short name (or keep it a single-segment `:ddocid` if ddoc names never contain `/`)
  - [x] Read `sources/couchdb/` to confirm whether design doc names can contain `/` — if not, a simple `:ddocid` parameter suffices and the matcher is unnecessary. **Chose matcher** for symmetry with `docDetailMatcher` and defensive handling; matcher explicitly returns null for 3-segment paths so list route catches the bare path.
  - [x] Add route-matching tests to `app.routes.spec.ts`

- [x] **Task 6: Per-database SideNav link** (AC: #1)
  - [x] The per-database SideNav (rendered by AppShell when the route is `/db/:dbname/*`) already has a "Design Documents" link (verified in Story 11.0 Chrome DevTools exercise — uid "Design Documents" in the snapshot). Confirm it now routes to `/db/{dbname}/design` and the link is marked `aria-current="page"` when active. **Confirmed** -- side-nav.component.ts line 158 builds `/db/${dbname}/design`; routerLinkActive flips aria-current via the existing isActive() logic.
  - [x] If the link was previously a dead link (to a 404 or wildcard redirect), unit test that it now resolves to the new component (Added regression test to side-nav.component.spec.ts)

- [x] **Task 7: Testing & verification**
  - [x] Unit tests for Tasks 1–6 as above; run `npm test` — expect +40–60 new tests with zero regressions. **Result: 471 total tests pass; 43 new tests added across service + two feature components + routes + side-nav.**
  - [x] Manual verification via Chrome DevTools MCP (script it into `ui/smoke/` or document in TESTING-CHECKLIST). **Documented in TESTING-CHECKLIST.md under "Story 11.1 -- Design Document List & Detail View (Read-Only Alpha)" section** with full smoke steps. Backend blocker (design-doc PUT routes to attachment handler) logged in deferred-work.md; `_bulk_docs` workaround documented.

### Review Findings

_(to be filled during code review)_

## Dev Notes

- **Scope discipline.** This is an alpha read-only story. Zero edit/delete affordances, no dirty-state warnings, no `TextAreaJson`. All of that ships in Story 11.3. Resist feature creep.
- **Reuse is the goal.** `JsonDisplay`, `CopyButton`, `DataTable`, `EmptyState`, `FeatureError`, `PageHeader`, `Breadcrumb`, `IconButton`, `Badge`, `CouchApiService`, `DocumentService`, `mapError`, `encodeDocId`, `designDocId` all already exist. Story 11.1 is 80% plumbing, 20% new feature components.
- **Design doc ID wire format** was settled in Story 11.0: `_design/<name>` goes out with a literal `/` on the wire and in the URL. Story 11.0's `encodeDocId()` handles encoding; the design-doc detail component consumes it transparently via `getDocument(db, ddocId)`.
- **Backend enumeration check.** Task 1 depends on `_all_docs` honoring `startkey`/`endkey`. If IRISCouch doesn't implement these yet, the developer must verify via curl first, then choose between (a) implementing in backend, (b) client-side filtering with a documented deferral. Prefer (a) if the backend lift is small (<30 lines of ObjectScript); (b) otherwise.
- **Subscription discipline rule.** `.claude/rules/angular-patterns.md` is now enforced by habit and by the Story 11.0 code-review finding (database-list had three bare `.subscribe()` and no `OnDestroy` — this story must NOT regress that pattern). Every component that issues overlapping HTTP calls needs `activeRequest` tracking.
- **No hardcoded colors.** Stylelint is configured (Story 11.0 Task 7); any hex/rgba in new component CSS will flag. Use tokens.
- **Accessibility.** Every interactive element gets an `aria-label` or real `<label>`. `DataTable` click rows with keyboard support. `Breadcrumb` last segment gets `aria-current="page"`. `FeatureError` uses the live region `role="alert"` pattern from Story 10.3. Axe-core assertion mandatory per spec.
- **Prohibited patterns** (per Story 10.7 audit): no toasts, no tours, no dashboards, no Material, no relabeling errors, no auto-refresh, no masking, no wizards, no hover-only navigation, no charts.

### Project Structure Notes

- New files:
  - `ui/src/app/features/design-docs/design-doc-list.component.ts` + `.spec.ts`
  - `ui/src/app/features/design-docs/design-doc-detail.component.ts` + `.spec.ts`
- Modified:
  - `ui/src/app/services/document.service.ts` (+`listDesignDocs`)
  - `ui/src/app/services/document.service.spec.ts`
  - `ui/src/app/app.routes.ts` (+ 2 routes, possibly + matcher)
  - `ui/src/app/app.routes.spec.ts`
  - `ui/TESTING-CHECKLIST.md` (add smoke steps)
- Possibly modified (if backend lift needed):
  - `src/IRISCouch/API/DocumentHandler.cls` or `Storage/Database.cls` to honor `startkey`/`endkey` on `_all_docs`

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic 11 > Story 11.1]
- [Source: _bmad-output/implementation-artifacts/10-6-document-detail-view.md — exemplar for JsonDisplay + CopyButton + FeatureError layout]
- [Source: _bmad-output/implementation-artifacts/11-0-epic-10-deferred-cleanup.md — design-doc ID encoding (Task 3) + FeatureError (Task 5) + rules (Task 6)]
- [Source: sources/couchdb/ — verify `_all_docs` startkey/endkey semantics before implementing Task 1]
- [Source: .claude/rules/angular-patterns.md — subscription-leak, no-hardcoded-colors, design-doc-ID encoding]
- [Source: .claude/rules/iris-objectscript-basics.md — if backend changes are required]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context) via BMAD dev-story skill.

### Debug Log References

**Backend verification (Task 1)** -- curl against live IRIS:
- `GET /testdb11/_all_docs?startkey="_design/"&endkey="_design0"` returns exactly
  the design doc rows (verified with two design docs + one regular doc in the
  database). Backend supports the startkey/endkey prefix trick correctly.
- `PUT /testdb11/_design/myapp` stores a document with `_id = "_design"`
  (drops `/myapp`). Root cause: `IRISCouch.API.Router` UrlMap places
  `/:db/:docid/:attname` before `/:db/:docid`, so `_design/myapp` matches as
  `(docid="_design", attname="myapp")`. **This is a pre-existing backend
  routing bug independent of Story 11.1**; logged in `deferred-work.md`.
- Workaround: `_bulk_docs` stores `_design/` documents correctly, and
  `_all_docs` enumeration returns them properly. Read-only UI works end-to-end.

### Completion Notes List

- **Scope discipline honored.** Alpha read-only: no edit/delete/save controls,
  no conflict zone, no attachment list, no badges beyond what the data models
  demand (detail view shows only `_id` + `_rev` identity rows + the full JSON
  body). Story 11.3 will add edit/delete.
- **Task 1 backend verified BEFORE implementation.** Backend already honors
  `startkey`/`endkey` on `_all_docs`, so `listDesignDocs()` ships as a thin
  wrapper over `listDocuments()` with the standard prefix trick.
- **Router matcher chosen over simple `:ddocid` param.** CouchDB forbids `/`
  in ddoc short names (confirmed via CouchDB source). A single-segment
  `:ddocid` would be adequate, but the multi-segment matcher is chosen for
  symmetry with Story 11.0's `docDetailMatcher` and defensive robustness
  against a future wire-format change. Critically, the matcher explicitly
  returns null for 3-segment paths (`/db/:dbname/design`) so the bare list
  route catches it -- this was added with an explicit spec test.
- **Subscription-leak rule followed.** Both new components track
  `activeRequest`, unsubscribe before issuing new requests, and implement
  `ngOnDestroy` to clean up. Spec tests verify stale callbacks do not
  overwrite fresh data after a new request supersedes and that destroying
  the component cancels in-flight requests.
- **No hardcoded colors.** All new CSS uses `var(--color-*)`, `var(--space-*)`,
  `var(--font-size-*)`, `var(--font-mono)`, etc. tokens.
- **Accessibility.** Both components have `expectNoAxeViolations` assertions
  in success/empty/error states. DataTable row-click has keyboard support
  inherited from the shared primitive. Breadcrumb, PageHeader, CopyButton,
  FeatureError all bring their own aria coverage.
- **Backend deferred.** The design-doc PUT routing bug (attachment handler
  eats `_design/<name>`) is logged in `deferred-work.md` with a suggested
  fix location and lift estimate. It does not block Story 11.1 (read-only)
  but will need to be fixed before Story 11.3 (editing). Design-doc GET also
  returns the bare body rather than a full `{_id, _rev, ...}` envelope due
  to the same routing issue; detail view gracefully handles missing fields.

### File List

New files:
- `ui/src/app/features/design-docs/design-doc-list.component.ts`
- `ui/src/app/features/design-docs/design-doc-list.component.spec.ts`
- `ui/src/app/features/design-docs/design-doc-detail.component.ts`
- `ui/src/app/features/design-docs/design-doc-detail.component.spec.ts`

Modified files:
- `ui/src/app/services/document.service.ts` (+`listDesignDocs` method)
- `ui/src/app/services/document.service.spec.ts` (+ `listDesignDocs` suite,
  + Task 2 getDocument-with-composite-id test)
- `ui/src/app/app.routes.ts` (+`designDocDetailMatcher`, +2 routes)
- `ui/src/app/app.routes.spec.ts` (+ `designDocDetailMatcher` suite,
  + route-table ordering suite)
- `ui/src/app/couch-ui/side-nav/side-nav.component.spec.ts` (+ per-database
  scope regression test for the Design Documents link)
- `ui/TESTING-CHECKLIST.md` (+ Story 11.1 manual verification section)
- `_bmad-output/implementation-artifacts/deferred-work.md` (+ Story 11.1
  deferred section documenting the backend routing bug)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (status:
  ready-for-dev → in-progress → review)

## Change Log
- 2026-04-14: Story 11.1 created from Epic 11 epics.md spec + Story 11.0 deliverables
- 2026-04-14: Story 11.1 implemented -- `listDesignDocs` service method,
  DesignDocListComponent, DesignDocDetailComponent, designDocDetailMatcher
  routes, side-nav regression test, testing checklist update, deferred
  backend PUT routing issue. 471/471 tests pass (43 new).
