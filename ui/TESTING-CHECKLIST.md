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

## Story 11.3 -- Design Document & Security Editing (Beta)

Setup:
- Create a test database via curl:
  ```
  curl -u _system:SYS -X PUT http://localhost:52773/iris-couch/testdb11x3
  ```
- Backend routing fix from Story 11.3 Task 0 is now in place, so the
  design-doc write paths below use the handler directly (no `_bulk_docs`
  workaround needed).

Smoke steps:
- [ ] **Create design doc (happy path)**: from `/db/testdb11x3/design`, click
      "Create design doc". Dialog opens with default body
      `{"language":"javascript","views":{}}`. Type name `myapp`. Create button
      enables. Click Create. Dialog closes, list refreshes, `_design/myapp`
      appears.
- [ ] **Create validation -- name**: re-open Create. Type `BAD NAME` -- inline
      error "Only lowercase letters, digits, hyphen, underscore allowed"
      shows, Create disabled. Fix to `otherapp`, Create enables.
- [ ] **Create validation -- JSON**: in the dialog, replace the body with
      `{invalid` -- inline `"Invalid JSON at line N"` appears under the
      textarea, Create disabled. Restore valid body, Create enables.
- [ ] **Create duplicate (409)**: with `_design/myapp` already existing,
      open Create and type `myapp`. Client-side "already exists" inline
      error appears before submit. If the client check is bypassed (e.g.,
      concurrent create), the verbatim 409 envelope shows inline in the
      dialog and the dialog stays open.
- [ ] **Edit design doc (happy)**: navigate to `_design/myapp`. Click Edit.
      JsonDisplay swaps to TextAreaJson pre-filled with the body (without
      `_id`/`_rev`). Add a view entry. Click Save. Returns to view mode,
      header rev updates (e.g., `1-...` -> `2-...`).
- [ ] **Edit dirty cancel**: Click Edit, change body, click Cancel. Warning
      dialog "You have unsaved changes. Discard?" appears. Click the
      Cancel button in the dialog -- returns to the editor with changes
      still in place. Click Cancel again and choose Discard -- returns to
      read-only view with the original body.
- [ ] **Edit invalid JSON**: Click Edit, break the body (e.g., add a stray
      `,`). Inline `"Invalid JSON at line N"` appears. Save is disabled.
      Fix the body. Save re-enables.
- [ ] **Edit 409 conflict**: open the same ddoc in two browser tabs. Edit
      and Save in tab 1. In tab 2, without refreshing, Edit + modify + Save.
      The inline FeatureError shows the verbatim 409 `conflict` envelope
      and the editor stays open. Click Cancel, reload, Edit again -- now
      saves cleanly.
- [ ] **Delete design doc**: in view mode, click Delete. Type-to-confirm
      dialog requires typing the exact short name (`myapp`). Delete is
      disabled until the name matches. Confirm -- DELETE fires, URL
      returns to `/db/testdb11x3/design`, ddoc is gone from the list.
- [ ] **Security edit (happy)**: navigate to `/db/testdb11x3/security`.
      Click Edit. TextAreaJson pre-filled with normalized body. Add a name
      to `admins.names`. Click Save. Returns to read-only view with the
      new admin listed.
- [ ] **Security dirty nav-away**: click Edit, mutate the body, click the
      "Documents" sidenav link. Warning dialog appears. Click Cancel in
      the dialog -- stay on the security editor with the change intact.
      Click the sidenav link again and choose Discard -- navigation
      proceeds and the edit is discarded.
- [ ] **Security edit 401/500 (simulated)**: stop the IRIS node or revoke
      admin rights. Edit + Save. Inline FeatureError shows the verbatim
      backend envelope; editor stays open. Restore admin rights and retry
      -- save succeeds.
- [ ] **Keyboard-only on dialogs**: all three dialogs (create, delete
      type-to-confirm, discard warning) are operable with Tab / Shift-Tab
      only. Focus is trapped in the dialog, restored to the trigger on
      close, Esc cancels.
- [ ] **axe-core via Chrome DevTools MCP**: run the axe scan against the
      detail view in all four states (view, edit-clean, edit-dirty-invalid,
      edit-saving) and the security view in view + edit modes. All four
      tests axe-clean apart from the known JsonDisplay contrast issue
      scoped in the component spec.

**Result**: [ ] PASS / [ ] FAIL

---

## 8. Story 11.4 — Revision History View

Manual verification scenarios for the new `/db/{dbname}/doc/{docid}/revisions`
view. Use Chrome DevTools MCP to drive each scenario against a running
iris-couch server and capture screenshots for the story deliverable.

- [ ] **Single-rev tree**: Create a fresh document. Navigate to its
      revision view (from document detail → "Revisions" button).
      Verify a single node renders with the ★ winner badge and that
      clicking it shows the body below. The `?rev=` query param updates.
- [ ] **Linear chain**: Update the same document 4 more times
      (PUT with the returned rev). Navigate to its revisions view.
      Verify all 5 nodes render top-to-bottom in one column with edges
      between them, winner at the bottom, and the body of the winning
      rev pre-selected.
- [ ] **2-leaf conflict**: Using a `?new_edits=false` bulk write or the
      `RevTree.AddBranch` helper (see `ChangesHttpTest` for the pattern),
      create a document with two rev-2 leaves sharing a rev-1 parent.
      Navigate to revisions. Verify two leaves render side-by-side,
      one ★-badged as winner, and the rev-1 ancestor collapses onto
      the winner's column.
- [ ] **Conflict + delete**: Mark one conflict branch as deleted
      (PUT `{"_deleted":true,"_rev":"<leaf>"}`). Navigate back. Verify
      the deleted leaf renders with strikethrough text and the deleted
      border style.
- [ ] **Selection deep-link**: Click a non-winner leaf. Copy the URL
      from the address bar (note the `?rev=` query param). Paste into
      a new tab. Verify the same node is pre-selected on load and its
      body renders beneath the tree.
- [ ] **Keyboard navigation**:
      - Tab from the tree container cycles through the leaves.
      - Arrow Up moves focus to the parent; Arrow Down to a child;
        Arrow Left/Right between siblings.
      - Enter / Space selects the focused node, updates URL + body.
      - Esc returns to the document detail view.
- [ ] **Popover on hover/focus**: Hover (or Tab to) a node. A popover
      appears with the full rev string, status, generation, parent rev,
      and role (winner / conflict leaf). Blur / move mouse dismisses.
- [ ] **401 error**: Log out, then paste a revisions URL into the
      address bar. Verify an inline `FeatureError` renders with the
      verbatim `{error:"unauthorized", reason:"..."}` envelope. No
      tree is shown.
- [ ] **SideNav Revision History entry**:
      - From `/db/{dbname}` (doc list), verify the "Revision History"
        entry is disabled (greyed out) with the tooltip "Select a
        document first to view its revisions".
      - From `/db/{dbname}/doc/{docid}`, verify the entry becomes
        enabled and links to the current doc's revisions.
- [ ] **axe-core via Chrome DevTools MCP**: run the axe scan against
      the revisions view in loading, loaded-with-selection, error,
      and single-rev states. All should be axe-clean apart from the
      known JsonDisplay contrast issue scoped in the component spec.
- [ ] **Subscription discipline regression (per `.claude/rules/angular-patterns.md`)**:
      rapidly click between multiple leaves and verify the final body
      shown matches the last click (not a stale prior fetch).

**Result**: [ ] PASS / [ ] FAIL

---

## Sign-Off

| Tester | Date | Overall Result |
|--------|------|----------------|
|        |      | [ ] PASS / [ ] FAIL |
