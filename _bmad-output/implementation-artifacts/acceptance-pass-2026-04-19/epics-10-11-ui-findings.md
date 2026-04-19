# Epics 10-11 Admin UI Acceptance Test Report — 2026-04-19

Tester: Claude (Opus 4.7) via Chrome DevTools MCP
Target: `http://localhost:52773/iris-couch/_utils/`
Auth: `_system` / `SYS`
Throwaway DB: `accui19_db` (created and deleted during the run)

## Summary

- Stories tested: **12 / 12** (10-1, 10-2, 10-3, 10-4, 10-5, 10-6, 10-7, 11-1, 11-2, 11-3, 11-4, 11-5)
- PASS: **12**
- FAIL: **0**
- Issues found: **0 functional defects.** One minor UX observation noted below
  (refresh-required after out-of-band data change), not a regression.

All twelve user stories' core acceptance criteria render and function as
specified. The UI is responsive, free of JS errors, and Lighthouse
accessibility/best-practices both score 100.

## Console / Network Audit

- **JS errors:** none.
- **Failed requests:** only the two intentional ones —
  - `GET /iris-couch/accui19_db/nonexistent` → 404 (story 10-7 error path)
  - `POST /iris-couch/_session` → 401 (story 10-7 wrong-password path)
- All other XHR/fetch calls returned 200. No 500-class responses observed
  across the entire session (login, 60-doc list, 3-rev revisions tree,
  design-doc create, security edit, delete).

## Story-by-Story Results

### Story 10-1: Angular Scaffold, Design Tokens, Icons — PASS
- App boots at `/iris-couch/_utils/` with `<base href="/iris-couch/_utils/">`,
  Angular routing in effect (deep-link navigation worked throughout).
- Design tokens visible (consistent typography, spacing, button styling
  across login, list, detail, dialog screens). See `ui-01-login.png`,
  `ui-02-database-list.png`.

### Story 10-2: Core UI Components — PASS
- Buttons (primary/secondary), text inputs, table, modal dialog (create-db,
  create-design-doc, delete-confirm), badges (winner badge in revision
  tree), and inline alert (login error, doc-not-found error) all render and
  behave consistently. See `ui-03-create-db-dialog.png`,
  `ui-15-revision-history.png`, `ui-19-delete-confirm.png`.

### Story 10-3: AppShell, Navigation & Login — PASS
- AC1 login form renders with Username + Password + Sign-in: PASS —
  `ui-01-login.png`.
- AC2 successful login redirects to `/databases` and AppShell renders:
  PASS — `ui-02-database-list.png` shows banner with "iris-couch", user
  badge "_system", Sign-out button, primary nav (Databases / Active tasks
  / Setup / About), and "Skip to content" a11y link.
- AC3 sign-out returns to login route: PASS (verified before login-error
  test).

### Story 10-4: Database List, Create, Delete — PASS
- AC1 list renders with name/docs/update-seq/size columns: PASS —
  `ui-02-database-list.png`.
- AC2 Create button opens modal with input + validation (Create button
  disabled until name is valid): PASS — `ui-03-create-db-dialog.png`.
- AC3 created DB appears in list: PASS — `ui-04-db-created.png` (accui19_db
  visible in list with 0 docs).
- AC4 Delete with type-to-confirm guard: PASS — `ui-19-delete-confirm.png`
  shows "Delete" disabled until name typed; after confirm, DB returns 404
  on subsequent API probe (`ui-20-after-delete.png`).

### Story 10-5: Document List with Filtering & Pagination — PASS
- AC1 list of docs with `_id` + `_rev` columns: PASS —
  `ui-05-document-list.png` (15 docs).
- AC2 prefix filter narrows results: PASS — typing `doc-01` filtered to
  6 rows (`ui-06-document-list-filtered.png`); URL reflects
  `?filter=doc-01`; clear-filter button present.
- AC3 pagination with Previous/Next + row-count indicator: PASS — after
  seeding 60 docs, list shows "rows 1–25 of ~60"
  (`ui-07-document-list-page1.png`); Next button advances to "rows 26–50"
  (`ui-08-document-list-page2.png`); URL uses `startkey=...` cursor.

### Story 10-6: Document Detail — PASS
- AC1 detail shows `_id`, `_rev`, body JSON: PASS —
  `ui-09-document-detail.png` (full doc-001 body with all fields and
  syntax-highlighted line numbers).
- AC2 sub-nav (Documents / Design Documents / Security / Revision History):
  PASS — Revision History becomes enabled when a doc is selected (was
  disabled with description "Select a document first" in DB-level views).
- AC3 utility actions (Copy ID, Copy revision, Copy raw JSON, Refresh,
  Revisions): all rendered.

### Story 10-7: Error Handling, Accessibility — PASS
- AC1 friendly error display for 404 doc: PASS —
  `ui-17-doc-not-found.png` shows status `404`, code `not_found`,
  reason `missing`, plus a Retry button. Inline alert (`role="alert"`,
  `aria-live="assertive"`).
- AC2 login-error display for wrong password: PASS —
  `ui-18-login-error.png` shows `401 / unauthorized / Name or password is
  incorrect.` with both fields marked `aria-invalid="true"`.
- AC3 a11y baseline: Lighthouse desktop snapshot scored
  **Accessibility 100, Best Practices 100, SEO 75** (SEO failure is a
  missing meta-description, expected for an admin-only SPA). Skip-to-content
  link present, live regions for status announcements (e.g., "Loaded
  database list", "Loaded 3 revisions for doc-001").

### Story 11-1: Design Document List & Detail — PASS
- AC1 Design Documents tab lists ddocs (or empty state): PASS — initial
  view showed "No design documents yet. Use Create to add one."
  (`ui-10-design-docs-empty.png`); after create, list shows
  `_design/myviews` (`ui-11-design-docs-list.png`).
- AC2 Click into ddoc shows detail with `_id`, `_rev`, body: PASS —
  `ui-12-design-doc-detail.png`.

### Story 11-2: Security Configuration View — PASS
- AC1 Security tab shows admins/members JSON: PASS —
  `ui-13-security-view.png` shows the full `{admins:{names,roles},
  members:{names,roles}}` structure with Edit + Copy buttons.

### Story 11-3: Design Doc & Security Editing — PASS
- AC1 Design-doc create dialog with name + body: PASS —
  pre-fills `{"language":"javascript","views":{}}` template.
- AC2 Edit security and save: PASS — `ui-14-security-saved.png` shows the
  edited security doc with `alice` admin / `dbadmin` role / `bob` member
  reflected after save; UI returned to read-only view with the new values.

### Story 11-4: Revision History — PASS
- AC1 Revision tree visible for doc with multiple revs: PASS — after
  putting 3 revisions of doc-001 via curl,
  `ui-15-revision-history.png` shows tree with 3 nodes, winner badged
  on rev-3, "available" status on each.
- AC2 Selecting a non-winner rev loads that body: PASS —
  `ui-16-revision-history-old-rev.png` shows rev-1's body (no `version`
  field) when selecting rev-1, URL updates to
  `?rev=1-6bec9b...`. Aria tree role used (`role="tree"`,
  `treeitem`s with level + selected state).

### Story 11-5: Admin UI Handler & Security — PASS
- AC1 SPA loads from `/iris-couch/_utils/`: PASS — initial nav succeeded
  with Basic auth realm `IRISCouch Admin` (`curl -i` confirmed
  `WWW-Authenticate: Basic realm="IRISCouch Admin"`).
- AC2 SPA fallback for deep links: PASS — `/_utils/db/accui19_db`,
  `/_utils/db/.../doc/doc-001`, `/_utils/db/.../revisions`, and
  `/_utils/db/.../doc/doc-001/revisions?rev=1-...` all rendered without
  the server returning 404 for the SPA route (verified by deep-link
  navigation throughout the test).
- AC4 Authorization gate: confirmed indirectly — `_system` (with admin
  role granted by Installer) sees the UI; the 401 challenge surfaced
  by the browser's auth dialog earlier confirms unauthenticated access
  is blocked.

## Lighthouse Audit (snapshot, desktop, /databases page)

- **Accessibility: 100**
- **Best Practices: 100**
- **SEO: 75** (single failure: missing `<meta name="description">`. Not
  applicable for an admin-only SPA; recommend ignoring or adding a static
  one in `index.html` if SEO score must read 100.)
- Total time: 2.14 s.

## Minor UX Observation (non-blocking)

- The database-list view does not auto-poll. After bulk-seeding 45 more
  docs out-of-band via curl, the doc-list still showed "rows 1–15 of ~15"
  until the user clicked **Refresh data**, after which it correctly showed
  "rows 1–25 of ~60". This matches typical CouchDB Fauxton behavior and
  the explicit "Refresh data" button is the documented pattern; not a
  defect — flagging only as something an operator unfamiliar with the
  pattern might trip on. No story AC requires polling.

## Screenshots produced (20)

1. `ui-01-login.png` — login page
2. `ui-02-database-list.png` — post-login database list
3. `ui-03-create-db-dialog.png` — create-db modal
4. `ui-04-db-created.png` — accui19_db in list
5. `ui-05-document-list.png` — empty doc list (15 seeded)
6. `ui-06-document-list-filtered.png` — filter `doc-01` → 6 rows
7. `ui-07-document-list-page1.png` — pagination page 1 (60 docs)
8. `ui-08-document-list-page2.png` — pagination page 2
9. `ui-09-document-detail.png` — doc-001 detail
10. `ui-10-design-docs-empty.png` — empty design-doc view
11. `ui-11-design-docs-list.png` — design-doc list with `_design/myviews`
12. `ui-12-design-doc-detail.png` — design-doc detail with Edit/Delete
13. `ui-13-security-view.png` — security read view
14. `ui-14-security-saved.png` — security after save (alice/bob/dbadmin)
15. `ui-15-revision-history.png` — 3-rev tree, winner badged
16. `ui-16-revision-history-old-rev.png` — rev-1 selected, body diffs
17. `ui-17-doc-not-found.png` — 404 friendly error
18. `ui-18-login-error.png` — 401 login error
19. `ui-19-delete-confirm.png` — delete-with-confirm dialog
20. `ui-20-after-delete.png` — list after deletion (accui19_db gone)
