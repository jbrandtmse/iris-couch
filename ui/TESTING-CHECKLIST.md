# iris-couch Admin UI -- Alpha Release Testing Checklist

This checklist covers manual QA verification for the iris-couch admin UI.
Each section must be completed before an alpha release is approved.

---

## 1. Keyboard-Only Smoke Test

Unplug the mouse (or disable the trackpad). Complete the entire flow using only keyboard.

- [ ] **Login**: Tab to username field, type username, Tab to password, type password, Tab to Sign In, press Enter
- [ ] **Database list**: Verify page loads after login, Tab to "Create database" button, press Enter
- [ ] **Create database dialog**: Tab to input, type name, Tab to Create button, press Enter; verify dialog closes
- [ ] **Delete database**: Tab to a table row, press Enter to navigate, navigate back; open delete dialog via context
- [ ] **Database detail / Document list**: Tab through filter input, table rows; press Enter on a row to navigate to document detail
- [ ] **Filter**: Press `/` to focus filter input; type prefix; press Escape to clear
- [ ] **Document detail**: Tab through breadcrumbs, copy buttons, conflict toggle (if present), attachment download links
- [ ] **Dialogs**: Press Escape to close any open dialog
- [ ] **Side navigation**: Use Arrow Up/Down to move between nav items; Enter to activate
- [ ] **Skip-to-content**: Press Tab immediately after page load; verify "Skip to content" link appears; press Enter to jump to main content

**Result**: [ ] PASS / [ ] FAIL

---

## 2. Screen Reader Smoke Test

Use NVDA (Windows), VoiceOver (macOS), or JAWS. Verify the following announcements.

- [ ] **ErrorDisplay**: role="alert" and aria-live="assertive" are announced immediately when an error appears
- [ ] **CopyButton**: "Copied." is announced via LiveAnnouncer after clicking a copy button
- [ ] **Database list load**: "Loaded database list" is announced on navigation to /databases
- [ ] **Document detail load**: "Loaded document {id}" is announced on navigation to a document
- [ ] **Dialog open**: Dialog title is announced when a confirm dialog opens (aria-labelledby)
- [ ] **Dialog close**: Focus returns to the triggering element after dialog closes
- [ ] **Navigation**: aria-current="page" is set on the active SideNav item

**Result**: [ ] PASS / [ ] FAIL

---

## 3. Color-Blind Simulation

Use Chrome DevTools > Rendering > "Emulate vision deficiencies" for each mode.

- [ ] **Protanopia** (red-blind): All badges remain distinguishable via text labels; error states are readable
- [ ] **Deuteranopia** (green-blind): Success and error badges are distinguishable via text, not color alone
- [ ] **Tritanopia** (blue-blind): Info badges remain readable
- [ ] **Achromatopsia** (no color): All semantic information is conveyed by text and/or icons, not color alone

**Result**: [ ] PASS / [ ] FAIL

---

## 4. Reduced-Motion Toggle

Enable "Reduce motion" in OS accessibility settings, or use Chrome DevTools > Rendering > "Emulate CSS media feature prefers-reduced-motion".

- [ ] **Button loading spinner**: Spinner is static (no rotation animation)
- [ ] **CopyButton icon transition**: Icon swap is instant (no fade/transition)
- [ ] **ConfirmDialog open**: Dialog appears instantly (no scale/opacity animation)
- [ ] **PageHeader loading bar**: Loading bar is static (no progress animation)
- [ ] **SideNav hover**: No transition on hover state change
- [ ] **All interactive elements**: No visible transitions on any hover, focus, or state change

**Result**: [ ] PASS / [ ] FAIL

---

## 5. Cross-Browser Test

Complete the login -> database list -> document detail flow in each browser.

| Browser          | Login | DB List | Create DB | Doc List | Doc Detail | Notes |
|------------------|-------|---------|-----------|----------|------------|-------|
| Chrome (latest)  | [ ]   | [ ]     | [ ]       | [ ]      | [ ]        |       |
| Firefox (latest) | [ ]   | [ ]     | [ ]       | [ ]      | [ ]        |       |
| Safari (macOS)   | [ ]   | [ ]     | [ ]       | [ ]      | [ ]        |       |
| Edge (latest)    | [ ]   | [ ]     | [ ]       | [ ]      | [ ]        |       |

**Result**: [ ] PASS / [ ] FAIL

---

## 6. Error Handling Verification

- [ ] **Network error**: Stop the IRIS server, navigate to /databases; verify "Cannot reach `/iris-couch/`. Check that the server is running." message with Retry button
- [ ] **5xx error on database list**: Verify ErrorDisplay appears in-place (not a toast)
- [ ] **5xx error on document detail**: Verify ErrorDisplay appears in-place with Retry button
- [ ] **404 error on document detail**: Verify ErrorDisplay shows "not_found" verbatim
- [ ] **Retry**: Click Retry button; verify it re-fetches the failed request

**Result**: [ ] PASS / [ ] FAIL

---

## 6. Chrome DevTools MCP Smoke Script (Story 11.0 AC #7 / Task 8)

This section documents the same steps that the CI dev-server smoke test
(`ui/smoke/smoke.mjs`, Story 11.0 Task 4) automates. Developers can run the
flow locally via the Chrome DevTools MCP to verify end-to-end wiring before
pushing a PR.

Prerequisites:
- IRIS running locally on `localhost:52773`, `iris-couch` web application
  exposing `/iris-couch/_utils/`
- Dev server running: `npm run start` in `ui/` (ng serve on port 4200 with
  the `proxy.conf.js` rewriting `/iris-couch/*` to IRIS)
- Test credentials: `_system / SYS` (or any role-mapped user)

Steps (use the `mcp__chrome-devtools-mcp__*` tool family):
1. `new_page` → navigate to `http://localhost:4200/iris-couch/_utils/`
2. `take_snapshot` → confirm the login form is rendered, fields `Name` and
   `Password` are present
3. `fill_form` with `{Name: "_system", Password: "SYS"}`
4. `click` the "Sign In" button
5. `wait_for` the `/databases` route (URL contains `#/databases` or
   `/databases`)
6. `list_network_requests` → confirm a `GET /iris-couch/_all_dbs` request
   returned 200 and a `GET /iris-couch/{db}` request for each row returned
   200 with a `sizes` object in the response body (Story 11.0 AC #1)
7. `click` on "Create database", type a test name, submit — confirm the
   row appears
8. `click` the per-row delete icon on the test database, type to confirm,
   click Delete — confirm the row disappears (Story 11.0 AC #2)
9. `list_console_messages` → should be empty (no unhandled exceptions)

Pass criteria: all steps complete without errors and without red entries
in the console message list.

**Result**: [ ] PASS / [ ] FAIL

---

## Story 11.1 -- Design Document List & Detail View (Read-Only Alpha)

Setup:
- Create a test database via curl:
  ```
  curl -u _system:SYS -X PUT http://localhost:52773/iris-couch/testdb11
  ```
- Insert a design doc via `_bulk_docs` (PUT `/db/_design/<name>` is currently
  routed as an attachment write -- see deferred-work.md for context):
  ```
  curl -u _system:SYS -X POST http://localhost:52773/iris-couch/testdb11/_bulk_docs \
    -H 'Content-Type: application/json' \
    -d '{"docs":[{"_id":"_design/myapp","views":{"by_name":{"map":"function(doc){emit(doc.name,null);}"}}}]}'
  ```

Smoke steps:
- [ ] **Navigate to list**: from /db/testdb11, click "Design Documents" in the
      per-database SideNav. URL should become `/db/testdb11/design`. DataTable
      shows `_design/myapp` in monospace.
- [ ] **Empty state**: on a fresh database with no design docs, the empty-state
      panel shows `"No design documents yet."` and `"Use curl or another client
      to create one at alpha."`
- [ ] **Row navigation**: click the `_design/myapp` row. URL becomes
      `/db/testdb11/design/myapp`. Detail view renders the full JSON.
- [ ] **Deep link**: paste `/iris-couch/_utils/db/testdb11/design/myapp` into
      the browser address bar (no list view visited). Detail view renders.
- [ ] **CopyButton -- _id**: click the CopyButton next to `_design/myapp`.
      Clipboard contains the literal string `_design/myapp` (with `/`, not `%2F`).
- [ ] **CopyButton -- raw JSON**: click the JsonDisplay Copy button. Clipboard
      JSON matches the output of
      `curl -u _system:SYS http://localhost:52773/iris-couch/testdb11/_design/myapp`
      byte-for-byte.
- [ ] **404 path**: navigate to `/db/testdb11/design/does-not-exist`. A
      FeatureError panel renders the verbatim backend envelope
      (`{"error":"not_found","reason":"..."}`), with a Retry button.
- [ ] **Read-only**: no Edit, Delete, or Save affordance is visible anywhere
      in the list or detail view at alpha.

**Result**: [ ] PASS / [ ] FAIL

---

## Story 11.2 -- Security Configuration View (Read-Only Alpha)

Setup:
- Create a test database via curl:
  ```
  curl -u _system:SYS -X PUT http://localhost:52773/iris-couch/testsec12
  ```
- (Optional) Populate `_security` so the populated path can be exercised:
  ```
  curl -u _system:SYS -X PUT http://localhost:52773/iris-couch/testsec12/_security \
    -H 'Content-Type: application/json' \
    -d '{"admins":{"names":["alice"],"roles":["admin"]},"members":{"names":["bob"],"roles":["reader"]}}'
  ```

Backend behavior verified during Story 11.2 dev (2026-04-14):
- `GET /db/_security` on an unset database returns the full default object
  `{"admins":{"names":[],"roles":[]},"members":{"names":[],"roles":[]}}` (HTTP 200).
  This diverges from CouchDB 3.x which returns `{}` -- see deferred-work.md.
  SecurityService normalizes both shapes so UI behavior is identical either way.

Smoke steps:
- [ ] **Default (empty) security**: from `/db/testsec12`, click "Security" in
      the per-database SideNav. URL becomes `/db/testsec12/security`. JsonDisplay
      shows the full default object with empty `names` and `roles` arrays.
- [ ] **Populated security**: after the PUT above, click Refresh in the page
      header (or reload). JsonDisplay body reflects `alice`/`admin` and
      `bob`/`reader`.
- [ ] **Deep link**: paste `/iris-couch/_utils/db/testsec12/security` into the
      browser address bar (no list view visited). View renders the JSON body.
- [ ] **CopyButton -- raw JSON**: click the JsonDisplay Copy button. Clipboard
      JSON matches the output of
      `curl -u _system:SYS http://localhost:52773/iris-couch/testsec12/_security`
      byte-for-byte.
- [ ] **Read-only**: no Edit, Delete, or Save affordance visible on the view.
      There are no `_id`/`_rev` identity rows (security has no revisions).
- [ ] **Error path (simulated)**: stop the IRIS node or block the endpoint,
      then reload. `FeatureError` renders the verbatim backend envelope with
      a Retry button. Restoring the endpoint + clicking Retry returns the
      populated JSON.
- [ ] **SideNav regression**: the per-database SideNav Security link now
      resolves to the new component (not a redirect/wildcard fallback).
      `aria-current="page"` is set on the Security item when the route is
      active.

**Result**: [ ] PASS / [ ] FAIL

---

## Sign-Off

| Tester | Date | Overall Result |
|--------|------|----------------|
|        |      | [ ] PASS / [ ] FAIL |
