# Story 11.5: Admin UI Static Hosting & Access Control

Status: ready-for-dev

## Story

As an operator,
I want the admin UI served directly from IRIS at `/_utils/` without
requiring a separate web server, and I want to restrict UI access to
authorized users,
so that the admin UI works out of the box after ZPM install and is not
accessible to unauthorized personnel.

## Acceptance Criteria

1. **Given** IRISCouch is installed via `Installer.Install()`
   **When** the operator navigates to `/iris-couch/_utils/` in a browser
   **Then** the Angular SPA loads and renders the login page
   **And** no external web server, Node.js, or `ng serve` is required

2. **Given** the Angular SPA is loaded
   **When** a deep-linked URL like `/iris-couch/_utils/db/mydb/doc/doc1` is
   requested
   **Then** the server returns `index.html` (SPA fallback)
   **And** Angular's client-side router handles the route correctly

3. **Given** `Installer.Install()` is called
   **When** installation completes
   **Then** the `/_utils/` route is configured automatically
   **And** a `%IRISCouch_Admin` role is created if it doesn't exist
   **And** the installing user is granted the role
   **And** no manual Management Portal steps are required

4. **Given** a user WITHOUT the `%IRISCouch_Admin` role
   **When** they navigate to `/iris-couch/_utils/*`
   **Then** they receive a 403 Forbidden response with a JSON error
   envelope `{"error":"forbidden","reason":"Admin UI requires
   %IRISCouch_Admin role"}`

5. **Given** static assets (JS, CSS, fonts, icons)
   **When** they are requested via `/_utils/`
   **Then** correct `Content-Type` headers are set (`application/javascript`,
   `text/css`, `font/woff2`, `image/svg+xml`, etc.)
   **And** hashed assets (`main-*.js`, `styles-*.css`) get
   `Cache-Control: public, max-age=31536000, immutable`
   **And** `index.html` gets `Cache-Control: no-cache`

6. **Given** the existing CouchDB REST API at `/iris-couch/`
   **When** the `/_utils/` static serving is added
   **Then** no existing API endpoints regress
   **And** the `/_utils/` route does NOT interfere with `/_uuids`,
   `/_session`, `/_all_dbs`, or any other root-level CouchDB endpoint

## Tasks / Subtasks

- [ ] **Task 0: Build Angular production bundle**
  - [ ] Run `cd ui && npx ng build --configuration=production` to produce `ui/dist/browser/`
  - [ ] Verify output: `index.html`, `main-*.js`, `styles-*.css`, `polyfills-*.js`, font files under `assets/fonts/`, icons
  - [ ] Verify `<base href="/iris-couch/_utils/">` is in the built `index.html`
  - [ ] Determine the **absolute filesystem path** where the dist lives on the IRIS server (e.g., `$System.Util.InstallDirectory() _ "dev/iris-couch/ui/dist/browser/"` or resolved from the class package location)
  - [ ] **Decision:** Whether to commit `ui/dist/browser/` to git (per the architecture plan) or keep it build-only. Architecture says commit it for ZPM distribution — follow that unless user directs otherwise.

- [ ] **Task 1: `AdminUIHandler.cls` — static file server with SPA fallback** (AC: #1, #2, #5)
  - [ ] Create `src/IRISCouch/API/AdminUIHandler.cls`
  - [ ] **ClassMethod `HandleRequest(pPath As %String) As %Status`**:
    1. Strip the `/_utils/` prefix from the request URL to get the relative path (e.g., `/iris-couch/_utils/main-abc123.js` → `main-abc123.js`)
    2. Resolve the relative path against the dist directory to get an absolute file path
    3. **Security:** Sanitize the path — reject `..` traversal, null bytes, and any path that escapes the dist directory. Return 400 if invalid.
    4. Check if the file exists using `##class(%File).Exists(tAbsPath)`
    5. **If file exists:** stream it to `%response` via `%Stream.FileBinary`, set `Content-Type` from extension (Task 1b), set cache headers (Task 1c)
    6. **If file does NOT exist (SPA fallback):** serve `index.html` from the dist root with `Content-Type: text/html; charset=utf-8` and `Cache-Control: no-cache`
  - [ ] **Task 1b: MIME type mapping.** Map file extensions to Content-Type:
    - `.html` → `text/html; charset=utf-8`
    - `.js`, `.mjs` → `application/javascript; charset=utf-8`
    - `.css` → `text/css; charset=utf-8`
    - `.json` → `application/json; charset=utf-8`
    - `.woff2` → `font/woff2`
    - `.woff` → `font/woff`
    - `.ttf` → `font/ttf`
    - `.svg` → `image/svg+xml`
    - `.png` → `image/png`
    - `.jpg`, `.jpeg` → `image/jpeg`
    - `.ico` → `image/x-icon`
    - `.map` → `application/json` (source maps)
    - Default → `application/octet-stream`
  - [ ] **Task 1c: Cache headers.**
    - If the filename contains a hash pattern (e.g., `main-abc123.js`, `styles-xyz789.css` — regex: filename has `-[a-f0-9]{8,}` before the extension): `Cache-Control: public, max-age=31536000, immutable`
    - Otherwise (`index.html`, `favicon.ico`): `Cache-Control: no-cache`
  - [ ] **Task 1d: Dist directory resolution.**
    - Add a `Parameter DISTDIR` or a `GetDistDir()` classmethod that resolves the dist path
    - For development: use a relative path from the source tree root (derived from `$System.Util.InstallDirectory()` or a config global `^IRISCouch.Config("UIDISTDIR")`)
    - For ZPM distribution: the dist files are committed alongside the ObjectScript classes, so the path is relative to the installation directory
    - Must work on both Windows (`C:\InterSystems\IRIS\dev\...`) and Linux (`/opt/iris/dev/...`)

- [ ] **Task 2: Access control — `%IRISCouch_Admin` role** (AC: #3, #4)
  - [ ] In `AdminUIHandler.HandleRequest`, before serving any file:
    1. Check if the current user has the `%IRISCouch_Admin` role in `$Roles`
    2. If not, return 403 with `{"error":"forbidden","reason":"Admin UI requires %IRISCouch_Admin role"}`
    3. Use `##class(IRISCouch.Util.Response).JSON()` or `##class(IRISCouch.Util.Error).Render()` for the error envelope (consistent with existing error patterns)
  - [ ] **Role creation** in `Installer.Install()`:
    1. Switch to `%SYS`
    2. Check if `Security.Roles.Exists("%IRISCouch_Admin")`
    3. If not: `Security.Roles.Create("%IRISCouch_Admin", "IRISCouch Admin UI access", "")`
    4. Grant the role to the installing user: get the current `$Username`, use `Security.Users.AddRoles($Username, "%IRISCouch_Admin")`
    5. Restore namespace
  - [ ] **Also grant `_SYSTEM` the role** if the installing user is not `_SYSTEM` (since `_SYSTEM` is the default admin account and should always have UI access)

- [ ] **Task 3: Router.cls — add `/_utils/*` route** (AC: #1, #6)
  - [ ] Add to the `<Routes>` section of `Router.cls`, BEFORE any database-level routes:
    ```xml
    <Route Url="/_utils/:path" Method="GET" Call="HandleAdminUI" />
    <Route Url="/_utils" Method="GET" Call="HandleAdminUIRoot" />
    ```
  - [ ] Create wrapper methods in Router.cls (matching the existing pattern):
    - `HandleAdminUI(pPath)` → delegates to `AdminUIHandler.HandleRequest(pPath)`
    - `HandleAdminUIRoot()` → delegates to `AdminUIHandler.HandleRequest("index.html")`
  - [ ] **Regression:** Verify that `/_uuids`, `/_session`, `/_all_dbs`, and all existing root-level routes still match correctly. The `/_utils` route must not shadow them.
  - [ ] **Note on `%CSP.REST` URL matching:** `/_utils/:path` captures a single segment. For deep paths like `/_utils/db/mydb/doc/doc1`, the UrlMap may need `/_utils/:path1/:path2/:path3/:path4/:path5` or a wildcard approach. **Research `%CSP.REST` UrlMap regex syntax** (read `irislib/%CSP/REST.cls` for the dispatch method). If UrlMap can't express wildcards, an alternative: use `OnPreDispatch` or `Page()` to intercept `/_utils/*` before UrlMap dispatch. Check how the existing `OnPreDispatch` works in Router.cls.

- [ ] **Task 4: Installer.cls updates** (AC: #3)
  - [ ] Extend `Install()` to:
    1. Create the `%IRISCouch_Admin` role (Task 2)
    2. Grant it to the installing user and `_SYSTEM`
    3. Optionally: set `^IRISCouch.Config("UIDISTDIR")` if a non-default dist path is needed
  - [ ] Extend `Uninstall()` to:
    1. Optionally remove the `%IRISCouch_Admin` role (or leave it — roles are cheap; removing could break re-installs)
  - [ ] Update `InstallerTest.cls` to verify role creation and assignment

- [ ] **Task 5: Testing**
  - [ ] **ObjectScript HTTP integration tests** in a new `Test/AdminUIHandlerTest.cls`:
    - `TestIndexHtmlServed` — GET `/_utils/` returns HTML containing `<app-root>`
    - `TestJsAssetServed` — GET `/_utils/main-*.js` returns JavaScript with `Content-Type: application/javascript`
    - `TestCssAssetServed` — GET `/_utils/styles-*.css` returns CSS with `Content-Type: text/css`
    - `TestSpaFallback` — GET `/_utils/db/mydb/doc/doc1` returns `index.html` (not 404)
    - `TestHashedAssetCacheHeaders` — GET a hashed asset returns `Cache-Control: public, max-age=31536000, immutable`
    - `TestIndexHtmlNoCacheHeaders` — GET `/_utils/` returns `Cache-Control: no-cache`
    - `TestPathTraversalBlocked` — GET `/_utils/../Installer.cls` returns 400 (not the class file)
    - `TestForbiddenWithoutRole` — GET `/_utils/` as a user without `%IRISCouch_Admin` returns 403
    - `TestExistingApiNotRegressed` — GET `/_uuids`, `/_session`, `/_all_dbs` still return expected responses
  - [ ] **Manual verification via Chrome DevTools MCP:**
    - Navigate to `http://localhost:52773/iris-couch/_utils/` — login page renders
    - Navigate to `http://localhost:52773/iris-couch/_utils/databases` — SPA fallback → login → databases
    - Check Network tab: JS/CSS have correct Content-Type, hashed assets have immutable Cache-Control
    - Verify `curl -u _SYSTEM:SYS http://localhost:52773/iris-couch/_utils/` returns HTML
    - Verify `curl -u unauthorized_user:pass http://localhost:52773/iris-couch/_utils/` returns 403
    - Take 2-3 screenshots

### Review Findings

_(to be filled during code review)_

## Dev Notes

- **Architecture alignment.** The architecture document explicitly lists
  `AdminUIHandler` as one of 12 planned handler classes and notes it is
  "independent — serves static files only." This story implements that plan.
- **`%CSP.REST` UrlMap wildcard limitation.** The existing UrlMap uses
  `/:db/:docid` patterns that capture single path segments. For
  `/_utils/db/mydb/doc/doc1/revisions` (6 segments after `/_utils/`),
  a single `:path` param won't work. Two approaches:
  - **Preferred:** Override `OnPreDispatch` to intercept any URL starting
    with `/_utils/` before UrlMap processes it. Extract the full path from
    `%request.URL` or `%request.CgiEnvs("PATH_INFO")`, strip the webapp
    prefix and `/_utils/`, and dispatch to `AdminUIHandler.HandleRequest()`.
    Return `$$$OK` with `pContinue=0` to prevent UrlMap fallthrough.
  - **Fallback:** Register multiple UrlMap entries for different segment
    counts (`/_utils/:a`, `/_utils/:a/:b`, etc. up to 8 segments). Ugly
    but works within UrlMap's constraints.
  - Read `irislib/%CSP/REST.cls` `DispatchRequest` and `OnPreDispatch`
    before deciding.
- **`%Stream.FileBinary` for file streaming.** Use `LinkToFile(tAbsPath)`
  to bind the stream to the file on disk, then loop `tStream.Read(32768)`
  writing to `%response` via `Write`. This avoids the ObjectScript ~3.6MB
  string limit and handles large JS bundles correctly.
- **Path security.** The path sanitization must:
  1. URL-decode the path (`$ZConvert(pPath, "I", "URL")`)
  2. Reject if it contains `..` after decoding
  3. Reject if it contains null bytes
  4. Resolve to an absolute path and verify it's a child of the dist dir
  5. Use `##class(%File).NormalizeFilename()` then check prefix
- **Dist directory location.** During development, the dist lives at
  `<repo>/ui/dist/browser/`. On a production IRIS install via ZPM, it
  would be relative to the ZPM package install location. A `Config`
  global override (`^IRISCouch.Config("UIDISTDIR")`) provides flexibility.
  Default: derive from `##class(%File).GetDirectory($System.Util.InstallDirectory() _ "dev/iris-couch/ui/dist/browser/")` — but this is IRIS-install-specific. Research the right default at dev time.
- **CouchDB protocol references:**
  - CouchDB serves Fauxton from `/_utils/` at the server root. IRISCouch
    matches this convention at `/iris-couch/_utils/` (prefixed by the
    webapp path).
- **Existing patterns to follow:**
  - `Installer.cls` — namespace switching pattern for `Security.Roles` in
    `%SYS` (same as existing `Security.Applications` pattern)
  - `Router.cls` — wrapper ClassMethod pattern for all handler dispatch
  - `Error.Render()` — for the 403 error envelope
  - `Response.JSON()` — for success responses (not used here, but
    consistent error envelopes are)

### Project Structure Notes

- **New files:**
  - `src/IRISCouch/API/AdminUIHandler.cls` (~150–200 lines)
  - `src/IRISCouch/Test/AdminUIHandlerTest.cls` (~150 lines)
  - `ui/dist/browser/` (committed Angular production build — ~50 files,
    ~130KB gzip total per Story 10.7)
- **Modified files:**
  - `src/IRISCouch/API/Router.cls` — add `/_utils/` route(s) or
    `OnPreDispatch` intercept
  - `src/IRISCouch/Installer.cls` — add role creation + assignment
  - `src/IRISCouch/Test/InstallerTest.cls` — add role creation test
- **No Angular source changes.** This story only builds and serves the
  existing UI code. The Angular source is unchanged.

### References

- [Source: _bmad-output/planning-artifacts/architecture.md — AdminUIHandler
  as planned handler class, "independent — serves static files only"]
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 11 > Story 11.5]
- [Source: _bmad-output/planning-artifacts/sprint-change-proposal-2026-04-17.md]
- [Source: src/IRISCouch/Installer.cls — existing Install/Uninstall patterns]
- [Source: src/IRISCouch/API/Router.cls — existing UrlMap and wrapper patterns]
- [Source: irislib/%CSP/REST.cls — DispatchRequest, OnPreDispatch for
  wildcard URL handling]
- [Source: irislib/%Stream/FileBinary.cls — LinkToFile for disk file streaming]
- [Source: .claude/rules/iris-objectscript-basics.md — namespace switching,
  response utility consistency, catch block patterns]

## Dev Agent Record

### Agent Model Used

_(to be filled)_

### Debug Log References

_(to be filled)_

### Completion Notes List

_(to be filled)_

### File List

_(to be filled)_

## Change Log

- 2026-04-17: Story 11.5 created via sprint change proposal. Implements
  the planned AdminUIHandler (FR83/FR84) that was deferred during Epic 10
  development. Adds `%IRISCouch_Admin` role-based access control per user
  request. Automates all configuration in Installer.Install().
