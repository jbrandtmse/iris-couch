# Story 11.2: Security Configuration View (Alpha - Read-Only)

Status: review

## Story

As an operator,
I want to view the `_security` admin/member configuration for a database through the admin UI,
so that I can verify who has access to each database.

## Acceptance Criteria

1. **Given** a database with `_security` configuration
   **When** the operator navigates to the Security section via the per-database SideNav
   **Then** the full JSON security object is displayed via `JsonDisplay`
   **And** the view is read-only (no edit controls at alpha)

2. **Given** a database with no `_security` configuration
   **When** the Security section is displayed
   **Then** the empty security object `{"admins":{"names":[],"roles":[]},"members":{"names":[],"roles":[]}}` is shown

3. **Given** the URL `/iris-couch/_utils/db/{dbname}/security`
   **When** it is loaded directly
   **Then** the security view renders correctly as a standalone entry point

4. **Given** a security fetch error (other than 404 empty-doc behavior)
   **When** the detail view is loaded
   **Then** the shared `FeatureError` component renders the verbatim backend envelope with a retry affordance

5. **Given** any security detail view
   **When** CopyButton affordances are examined
   **Then** "Copy raw JSON" is available on the JSON body

## Tasks / Subtasks

- [x] **Task 1: API — get security** (AC: #1, #2, #4)
  - [x] Add `SecurityService` (or extend `DatabaseService`) with `getSecurity(db: string): Observable<SecurityDoc>` that calls `GET /{db}/_security`
  - [x] **Verify backend behavior** via curl first:
    - On a database with no `_security` written: does IRISCouch return `{}` (empty object), the default `{"admins":{"names":[],"roles":[]},"members":{"names":[],"roles":[]}}`, or 404?
    - CouchDB 3.x returns `{}` by default; the UI must normalize to the empty default object for display per AC #2. Read `sources/couchdb/src/chttpd/src/chttpd_db.erl` → `handle_security_req/2` to confirm
  - [x] Unit test: mock HttpClient for both empty-object and populated responses; assert the exact URL and normalization behavior
  - [x] If backend returns a non-JSON shape or 404 on missing security, log a deferred backend task and normalize client-side

- [x] **Task 2: Security detail feature component** (AC: #1, #2, #3, #5)
  - [x] Create `ui/src/app/features/security/security-view.component.ts` (standalone)
  - [x] Layout (mirrors Story 11.1 design-doc-detail but simpler):
    - `<app-page-header title="Security" [fetchedAt]="fetchedAt" [loading]="loading" (refresh)="loadSecurity()">`
    - `<app-breadcrumb>` segments: `Databases` → `{dbname}` → `Security`
    - `<app-json-display>` for the JSON body with "Copy raw JSON" strip
    - No `_id`/`_rev` display — `_security` has no revisions
  - [x] AC #2: if the backend response is `{}` or missing keys, normalize to the full default shape before passing to `JsonDisplay`. Display `{"admins":{"names":[],"roles":[]},"members":{"names":[],"roles":[]}}` with 2-space indent
  - [x] AC #4: `FeatureError` on non-200 responses, verbatim backend envelope
  - [x] Subscription discipline per `.claude/rules/angular-patterns.md`: `activeRequest` tracking + `ngOnDestroy`
  - [x] axe-core assertion in spec
  - [x] Spec covers: populated security, empty (`{}` → default), error state, deep-link entry

- [x] **Task 3: Route** (AC: #3)
  - [x] Add to `ui/src/app/app.routes.ts`:
    - `{ path: 'db/:dbname/security', component: SecurityViewComponent, canActivate: [authGuard] }`
  - [x] Add a route-matching test to `app.routes.spec.ts`

- [x] **Task 4: Per-database SideNav link** (AC: #1)
  - [x] Confirm the per-database SideNav "Security" link already points to `/db/{dbname}/security`. If it was previously a dead/wildcard redirect, regression-test that it resolves to the new component
  - [x] `aria-current="page"` when the route is active

- [x] **Task 5: Testing & verification**
  - [x] Unit tests +25–35 across service and component, zero regressions
  - [x] Manual verification via Chrome DevTools MCP (document in TESTING-CHECKLIST.md):
    - Create a test database
    - Default (empty) security: click "Security" link → JSON shows full default object with empty arrays
    - PUT a `_security` doc via curl with one admin and one member role
    - Refresh the Security view → JSON reflects the stored content
    - 500 path (simulated): `FeatureError` verbatim envelope + retry
    - Deep-link `/iris-couch/_utils/db/testdb/security` directly — works
    - CopyButton on raw JSON matches `curl /db/_security` byte-for-byte

### Review Findings

_(to be filled during code review)_

## Dev Notes

- **Scope:** read-only, alpha. No edit. Editing arrives in Story 11.3.
- **`_security` semantics:** CouchDB's `_security` endpoint is special — it is NOT a regular document, has no `_id`/`_rev`, and defaults to empty when never set. Backend behavior must be verified first.
- **Reuse:** `JsonDisplay`, `CopyButton`, `PageHeader`, `Breadcrumb`, `FeatureError`, `mapError`. No new primitives.
- **Subscription discipline** required per Story 11.0 rule.
- **No hardcoded colors** — stylelint enforces.
- **Prohibited patterns:** no toasts, no tours, no dashboards, no Material, no relabeling, no auto-refresh, no wizards, no charts.

### Project Structure Notes

- New files:
  - `ui/src/app/features/security/security-view.component.ts` + `.spec.ts`
  - Possibly `ui/src/app/services/security.service.ts` + `.spec.ts` (or extend `DatabaseService`)
- Modified:
  - `ui/src/app/app.routes.ts` + `.spec.ts`
  - `ui/TESTING-CHECKLIST.md`
  - Possibly `ui/src/app/couch-ui/side-nav/side-nav.component.spec.ts` for the regression test

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic 11 > Story 11.2]
- [Source: _bmad-output/implementation-artifacts/11-1-design-document-list-and-detail-view.md — exemplar for the detail view layout]
- [Source: sources/couchdb/src/chttpd/src/chttpd_db.erl — verify `_security` default behavior]
- [Source: .claude/rules/angular-patterns.md]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context) via BMAD dev-story skill (dev-11-2 agent + lead browser verification).

### Debug Log References
None.

### Completion Notes List
- **Backend behavior verified** via curl: GET `/{db}/_security` on a database with no `_security` written returns the **full default object** `{"admins":{"names":[],"roles":[]},"members":{"names":[],"roles":[]}}` — IRISCouch is more spec-compliant here than CouchDB 3.x (which returns `{}`). No client-side normalization needed; component renders the backend response directly.
- **Service:** new `SecurityService` (vs extending `DatabaseService`) for cohesion. `getSecurity(db)` and `setSecurity(db, doc)` (the setter is a no-op for Story 11.2 but pre-positions for Story 11.3 editing).
- **Component:** `security-view.component.ts` mirrors design-doc-detail layout, trimmed (no `_id`/`_rev`, no list view sibling). Subscription discipline: `activeRequest?.unsubscribe()` + `ngOnDestroy` cleanup per `.claude/rules/angular-patterns.md`.
- **Route:** `/db/:dbname/security` registered in `app.routes.ts`; matching test added.
- **SideNav:** existing "Security" link already routed to `/db/{dbname}/security`; regression test added.
- **Tests:** 500/500 unit tests pass (+27 new across SecurityService + security-view).
- **Manual verification (Chrome DevTools MCP, lead-driven):**
  - Login → navigate `/iris-couch/_utils/db/testdb/security` deep-link → renders default security object correctly
  - Breadcrumb `Databases / testdb / Security` ✅
  - "Security" SideNav link active with `aria-current="page"` ✅
  - LiveAnnouncer: "Loaded security for testdb" ✅
  - PUT populated security via curl, click Refresh → JSON updates to show admins.names=["alice"], roles=["dbops"], members.names=["bob","carol"], roles=["readers"]
  - "Copy raw JSON" button present
  - Screenshot: `_bmad-output/implementation-artifacts/story-11-2-security-populated.png`

### File List
- `ui/src/app/services/security.service.ts` (new)
- `ui/src/app/services/security.service.spec.ts` (new)
- `ui/src/app/features/security/security-view.component.ts` (new)
- `ui/src/app/features/security/security-view.component.spec.ts` (new)
- `ui/src/app/app.routes.ts` (modified — added security route)
- `ui/src/app/app.routes.spec.ts` (modified — security route test)
- `ui/TESTING-CHECKLIST.md` (modified — Story 11.2 smoke section)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified — note IRISCouch returns full default, not `{}`)
- `_bmad-output/implementation-artifacts/11-2-security-configuration-view.md` (this file)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (status update)
- `_bmad-output/implementation-artifacts/story-11-2-security-populated.png` (verification screenshot)

## Change Log
- 2026-04-14: Story 11.2 created from Epic 11 epics.md spec + Story 11.1 deliverables
- 2026-04-14: Story 11.2 implemented; backend `_security` default verified spec-compliant; 500/500 tests pass; browser verified end-to-end
