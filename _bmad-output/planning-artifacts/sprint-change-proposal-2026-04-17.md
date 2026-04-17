# Sprint Change Proposal — AdminUIHandler + Web UI Security

**Date:** 2026-04-17
**Triggered by:** Manual UI testing revealed that the Angular SPA cannot be accessed without running `ng serve` — the planned AdminUIHandler (FR83/FR84) was never implemented.
**Scope:** Minor — add one story to an existing epic, no architectural changes.

---

## 1. Issue Summary

**Problem:** The Angular admin UI is fully functional (676 specs, 11 stories delivered across Epics 10–11) but can only be served via the Angular dev server (`ng serve` with proxy). The architecture planned an `AdminUIHandler` class to serve the pre-built SPA as static assets from IRIS at `/_utils/`, but this was never implemented. Operators deploying IRISCouch via ZPM cannot access the admin UI without installing Node.js and running a separate dev server — which defeats the "zero external tooling" promise (FR83, UX-DR61).

**Second issue:** There is no mechanism to restrict access to the admin UI to specific users or roles. The current web application uses password auth (AutheEnabled=64) which grants access to any valid IRIS user. Operators need the ability to limit `/_utils/` access to administrators only.

**Evidence:**
- Navigating to `http://localhost:52773/iris-couch/_utils/` returns `{"error":"not_found","reason":"missing"}`
- `AdminUIHandler` is listed in the architecture as one of 12 planned handler classes but does not exist in `src/IRISCouch/API/`
- `ui/dist/` directory does not exist (Angular app has never been built for production)
- `Installer.cls` creates the web application but has no static file serving configuration

---

## 2. Impact Analysis

### Epic Impact
- **Epic 11** (done → reopened): Add Story 11.5. Epic 11 was "Admin UI — Design Documents & Security Views" — this story is a natural fit since it completes the admin UI's deployment story.
- **Epic 12+**: No impact. Backend-focused epics don't depend on how the UI is served.

### Artifact Conflicts
- **PRD:** No conflict. FR83/FR84 already require this. The change fulfills existing requirements.
- **Architecture:** No conflict. `AdminUIHandler` is already listed. Implementation matches plan.
- **UX Design:** No conflict. UX-DR34 (deep-linkable URLs) and UX-DR61 (self-contained assets) are enabled by this change.
- **Epics file:** Epic 11 needs a new Story 11.5 entry added.
- **Sprint status:** `epic-11: done → in-progress`, add `11-5-admin-ui-handler-and-security: backlog`.

### Technical Impact
- **New files:** `src/IRISCouch/API/AdminUIHandler.cls` (static file serving + SPA fallback)
- **Modified files:** `src/IRISCouch/API/Router.cls` (add `/_utils/*` route), `src/IRISCouch/Installer.cls` (add `/_utils/` web app config or CSP page setup)
- **New artifact:** `ui/dist/browser/` (committed Angular production build)
- **New test:** `src/IRISCouch/Test/AdminUIHandlerTest.cls` or HTTP integration test

---

## 3. Recommended Approach: Direct Adjustment

Add **Story 11.5: Admin UI Static Hosting & Access Control** to Epic 11. This is the simplest path:

- **Effort:** Low — one handler class (~100 lines), installer update, `ng build`, route addition
- **Risk:** Low — no existing code is modified beyond adding a new route to Router.cls
- **Timeline:** Single story, fits in one dev cycle iteration

### Why not a new epic or 12.0 cleanup?
This is a deployment prerequisite, not technical debt. Every operator who installs IRISCouch will hit this gap on their first visit to `/_utils/`. It belongs in the epic that owns the admin UI, not in a cleanup story.

---

## 4. Detailed Change Proposals

### 4.1 Epics File Addition

**File:** `_bmad-output/planning-artifacts/epics.md`
**Section:** Epic 11, after Story 11.4

**ADD:**
```markdown
### Story 11.5: Admin UI Static Hosting & Access Control

As an operator,
I want the admin UI served directly from IRIS at /_utils/ without requiring
a separate web server, and I want to restrict UI access to authorized users,
so that the admin UI works out of the box after ZPM install and is not
accessible to unauthorized personnel.

**Acceptance Criteria:**

**Given** IRISCouch is installed via the Installer
**When** the operator navigates to /iris-couch/_utils/ in a browser
**Then** the Angular SPA loads and renders the login page
**And** no external web server, Node.js, or ng serve is required

**Given** the Angular SPA is loaded
**When** a deep-linked URL like /iris-couch/_utils/db/mydb/doc/doc1 is requested
**Then** the server returns index.html (SPA fallback)
**And** Angular's client-side router handles the route correctly

**Given** the Installer.Install() method is called
**When** installation completes
**Then** the /_utils/ web application (or route) is configured automatically
**And** no manual Management Portal steps are required

**Given** the admin UI security configuration
**When** an IRIS user without the designated admin role navigates to /_utils/
**Then** they receive a 403 Forbidden response
**And** only users with the configured role (e.g., %IRISCouch_Admin) can access the UI

**Given** static assets (JS, CSS, fonts, icons)
**When** they are requested via /_utils/
**Then** correct Content-Type headers are set (application/javascript, text/css, font/woff2, etc.)
**And** appropriate Cache-Control headers are set for immutable hashed assets
```

### 4.2 Sprint Status Updates

**File:** `_bmad-output/implementation-artifacts/sprint-status.yaml`

**CHANGE:**
```yaml
# Before:
  epic-11: done  # → change to: in-progress
  epic-11-retrospective: done
  # Add after 11-4:
  11-5-admin-ui-handler-and-security: backlog
```

Note: The retrospective stays `done` — it was valid for 11.0–11.4. Story 11.5 will get its own review.

### 4.3 No PRD or Architecture Changes Needed

FR83, FR84, UX-DR61, and the `AdminUIHandler` class are all already specified. This story implements them.

---

## 5. Implementation Handoff

**Scope classification:** Minor — direct implementation by Developer agent.

**Handoff:** Developer agent via `/bmad-create-story` → `/bmad-dev-story` → `/bmad-code-review` (standard cycle).

**Story implementation will cover:**

1. **`ng build --configuration=production`** — produce `ui/dist/browser/` and commit it
2. **`AdminUIHandler.cls`** — new handler class:
   - Resolves `/_utils/*` paths to files in the committed dist directory
   - SPA fallback: any path not matching a real file returns `index.html`
   - MIME type detection (`.js` → `application/javascript`, `.css` → `text/css`, `.woff2` → `font/woff2`, etc.)
   - Cache headers: hashed assets (`main-*.js`) get `Cache-Control: public, max-age=31536000, immutable`; `index.html` gets `no-cache`
   - Streams files via `%Stream.FileBinary` (no 3.6MB string limit)
3. **Access control** — enforce a role check (e.g., `%IRISCouch_Admin`) before serving any `/_utils/` content:
   - Create the role in the Installer if it doesn't exist
   - Check `$Roles` or `Security.Users` in the handler's dispatch
   - Return 403 with a clear JSON envelope if unauthorized
4. **Router.cls** — add `/_utils/*` GET route dispatching to `AdminUIHandler`
5. **Installer.cls** — update `Install()` to:
   - Create the `%IRISCouch_Admin` role if it doesn't exist
   - Assign the role to the installing user (typically `_SYSTEM`)
   - Configure any CSP application settings needed for static file serving
6. **Tests** — HTTP integration tests for: index.html served, JS/CSS served with correct MIME, deep-link fallback returns index.html, 403 for unauthorized user

**Success criteria:**
- `curl http://localhost:52773/iris-couch/_utils/` returns the Angular index.html
- `curl http://localhost:52773/iris-couch/_utils/db/mydb/doc/doc1` returns index.html (SPA fallback)
- `curl http://localhost:52773/iris-couch/_utils/main-*.js` returns JavaScript with correct Content-Type
- Unauthorized user gets 403 on `/_utils/` paths
- Zero manual Management Portal configuration steps after `Installer.Install()`

---

## 6. Summary

| Dimension | Value |
|-----------|-------|
| Change scope | Minor |
| Stories added | 1 (Story 11.5) |
| Stories modified | 0 |
| Epic impact | Epic 11 reopened (done → in-progress) |
| PRD impact | None (fulfills existing FR83/FR84) |
| Architecture impact | None (implements planned AdminUIHandler) |
| Risk | Low |
| Handoff | Developer agent (standard story cycle) |
