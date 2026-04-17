# Story 12.1: JSRuntime Sandbox Interface & None Backend

Status: done

## Story

As an operator,
I want IRISCouch to accept and store design documents regardless of JSRuntime configuration, with clear 501 responses when JS execution is unavailable,
so that I can migrate design documents into place before enabling a runtime and know exactly which subsystem is blocked.

## Acceptance Criteria

1. **Given** the abstract class `IRISCouch.JSRuntime.Sandbox`
   **When** it is compiled
   **Then** it declares four abstract methods covering the CouchDB JavaScript surface: `ExecuteMap(pMapFn, pDoc)`, `ExecuteReduce(pReduceFn, pKeys, pValues, pRereduce)`, `ExecuteValidateDocUpdate(pValidateFn, pNewDoc, pOldDoc, pUserCtx, pSecObj)`, and `ExecuteFilter(pFilterFn, pDoc, pReq)` — each abstract method has the shape and return type documented per the couchjs line protocol (`sources/couchdb/share/server/{views.js,validate.js,filter.js}`), and each returns a valid default value per `.claude/rules/iris-objectscript-basics.md` (`Quit ""` / `Quit $$$NULLOREF` / etc.)

2. **Given** `Config.Get("JSRUNTIME")` returns `"None"` (the shipped default per `IRISCouch.Config.Parameter JSRUNTIME = "None"`)
   **When** a client issues `GET /iris-couch/{db}/_design/{ddoc}/_view/{view}`
   **Then** the response is HTTP 501 Not Implemented with Content-Type `application/json` and body exactly `{"error":"not_implemented","reason":"JSRuntime backend is set to None. Set ^IRISCouch.Config(\"JSRUNTIME\") to \"Subprocess\" or \"Python\" to enable view execution. See documentation/js-runtime.md."}`

3. **Given** any JSRuntime backend (including `None`)
   **When** a client creates or updates a design document via `PUT /iris-couch/{db}/_design/{ddoc}` with a body that includes `views`, `validate_doc_update`, or `filters` source
   **Then** the design document is stored normally, returns 201 with `{"ok":true,"id":"_design/<ddoc>","rev":"1-..."}`, appears in `_all_docs`, is reachable via `GET /{db}/_design/{ddoc}`, and replicates via the existing bulk_docs + _changes paths — no JavaScript execution is attempted during the write path

4. **Given** `JSRuntime.None` is the active backend
   **When** any of the four JS-dependent paths are invoked: (a) `GET /{db}/_design/{ddoc}/_view/{view}`, (b) a document write whose target `_design/<ddoc>` has a `validate_doc_update` function, (c) a changes-feed request with `filter={ddoc}/{filter_name}`, or (d) a reduce-only request `?group=true` on a missing view
   **Then** each path returns 501 Not Implemented with a reason string that (i) names the subsystem being blocked (`"view execution"` / `"validate_doc_update hooks"` / `"custom filter functions"`), (ii) points at the documentation link `documentation/js-runtime.md`, and (iii) uses the canonical error code `"not_implemented"` — the reason strings for each subsystem are distinct enough that an operator reading the response can identify which subsystem is blocked

5. **Given** the factory class `IRISCouch.JSRuntime.Factory`
   **When** `Factory.GetSandbox()` is called
   **Then** it reads `Config.Get("JSRUNTIME")`, instantiates the appropriate concrete subclass (`IRISCouch.JSRuntime.None` for `"None"`, placeholders that return 501 with a `"not_yet_implemented"` reason for `"Subprocess"` and `"Python"` until Stories 12.2/12.4), and returns it cast as `IRISCouch.JSRuntime.Sandbox` — callers (`DocumentHandler`, `DocumentEngine`, `ChangesHandler`, future `ViewHandler`) **only** depend on the abstract Sandbox type and never on the concrete subclass

6. **Given** the `validate_doc_update` integration point in `DocumentEngine.Save()` / `SaveDeleted()` / `SaveWithHistory()` / `SaveWithAttachments()`
   **When** `JSRuntime.None` is active and any write would otherwise invoke a `validate_doc_update` function sourced from the target database's design docs
   **Then** the write path performs no JS work and no 501 is surfaced on writes (writes succeed) — the 501 only fires when a **client-facing read/query path** attempts to execute JS, so `None` is a "migration-friendly" default that permits design docs to be staged before a runtime is installed (per AC #3's migration intent)

7. **Given** the ChangesHandler filter evaluation path
   **When** a changes request arrives with `filter={ddoc}/{filtername}` (custom filter, not a built-in `_doc_ids`/`_selector`/`_design`) and `JSRuntime.None` is active
   **Then** the response is 501 with reason `"custom filter functions require a JSRuntime backend..."`, **not** a 400 or a silent pass-through — the existing `_doc_ids` / `_selector` / `_design` built-in filter paths continue to work unchanged (no JSRuntime involvement)

## Tasks / Subtasks

- [x] **Task 0: Backend-surface probe (per `.claude/rules/research-first.md`)** (AC: all)
  - [x] Probe current behaviour for `GET /iris-couch/{db}/_design/{ddoc}/_view/{view}` — expected: 404 (route does not exist yet) or whatever the %CSP.REST `Http404()` emits. Paste verbatim output into this Task block:
    ```
    $ curl -u _system:SYS -i http://localhost:52773/iris-couch/testdb/_design/any/_view/any
    <paste actual response here>
    ```
  - [x] Probe current behaviour for `POST /iris-couch/{db}/_changes` with `filter=ddoc/name` — expected: the existing `ChangesHandler.HandleChanges()` returns either 400 or silently falls through (verify which)
  - [x] Probe current behaviour for `PUT /iris-couch/{db}/_design/ddoc` with a body containing `validate_doc_update` — expected: 201 OK (writes do not invoke JS currently); confirm this baseline so AC #3 is regression-safe
  - [x] Cite references read:
    - `sources/couchdb/share/server/views.js` (map/reduce protocol shape)
    - `sources/couchdb/share/server/validate.js` (validate_doc_update args: `newDoc, oldDoc, userCtx, secObj`)
    - `sources/couchdb/share/server/filter.js` (filter args: `doc, req`; returns bool per doc)
    - `irislib/` → read whatever %SYS class the factory will return (likely `%RegisteredObject` for plain OO) before implementation
  - [x] Paste all four probe outputs and reference-file line ranges into the Dev Notes of this story as the audit trail

- [x] **Task 1: Abstract `IRISCouch.JSRuntime.Sandbox` class** (AC: #1)
  - [x] Create `src/IRISCouch/JSRuntime/Sandbox.cls` extending `%RegisteredObject` with `[ Abstract ]` class-level keyword
  - [x] Define four abstract methods, each with `[ Abstract ]` in the signature and a body that returns a valid default (per `.claude/rules/iris-objectscript-basics.md` — abstract methods MUST have `{}` and MUST return the default for their declared type):
    - `ExecuteMap(pMapFn As %String, pDoc As %DynamicObject) As %DynamicArray [ Abstract ]` — returns emitted key/value pairs as a `%DynamicArray` of `[key, value]` pairs (shape matches `sources/couchdb/share/server/views.js::map_doc` output)
    - `ExecuteReduce(pReduceFn As %String, pKeys As %DynamicArray, pValues As %DynamicArray, pRereduce As %Boolean) As %DynamicObject [ Abstract ]` — returns `{"ok": true, "value": <scalar>}` on success
    - `ExecuteValidateDocUpdate(pValidateFn As %String, pNewDoc As %DynamicObject, pOldDoc As %DynamicObject, pUserCtx As %DynamicObject, pSecObj As %DynamicObject) As %Status [ Abstract ]` — returns `$$$OK` on approval; returns an error `%Status` whose message carries the rejection reason (to be surfaced as 403 Forbidden by the caller)
    - `ExecuteFilter(pFilterFn As %String, pDoc As %DynamicObject, pReq As %DynamicObject) As %Boolean [ Abstract ]` — returns 1 if the document passes the filter, 0 otherwise
  - [x] Each abstract body: `Quit $$$NULLOREF` for oref-return methods, `Quit $$$OK` for %Status, `Quit 0` for %Boolean (per the rules file examples)
  - [x] Document each method with HTML/DocBook doc comments naming the corresponding couchjs protocol operation and its arg order
  - [x] Compile via the `compile_objectscript_class` MCP tool; confirm no compile errors

- [x] **Task 2: Concrete `IRISCouch.JSRuntime.None` backend** (AC: #1, #2, #4)
  - [x] Create `src/IRISCouch/JSRuntime/None.cls` extending `IRISCouch.JSRuntime.Sandbox`
  - [x] Override each abstract method; each override THROWS a `%Exception.General` with a canonical error envelope the caller can render verbatim — propose exception `code = "not_implemented"`, `name = "<subsystem>"` (one of `view execution`, `reduce function`, `validate_doc_update hooks`, `custom filter functions`), and `data` as the full reason string including the pointer to `documentation/js-runtime.md`
  - [x] Alternative pattern: instead of throwing, methods return a sentinel that the caller must inspect — **prefer throwing** so every caller fails fast and cannot accidentally use a None-sandbox result as real data. The caller catches and renders the 501.
  - [x] Add an introspection method `IsAvailable() As %Boolean` that returns 0 for None and will return 1 for Subprocess/Python when implemented; callers can branch on this before calling an Execute* method when they want to short-circuit to 501 without a try/catch
  - [x] Compile and confirm no errors

- [x] **Task 3: Placeholder `Subprocess` and `Python` stubs** (AC: #5)
  - [x] Create `src/IRISCouch/JSRuntime/Subprocess.cls` extending `Sandbox`; each override throws with a reason like `"Subprocess JSRuntime backend is not yet implemented (Story 12.2). Set JSRUNTIME to None to disable."`
  - [x] Create `src/IRISCouch/JSRuntime/Python.cls` extending `Sandbox`; each override throws with a reason like `"Python JSRuntime backend is not yet implemented (Story 12.4). Set JSRUNTIME to None to disable."`
  - [x] These stubs exist so the Factory resolves every documented value of `Config.Get("JSRUNTIME")` without crashing; Stories 12.2 and 12.4 will replace the bodies
  - [x] `IsAvailable()` returns 0 on both stubs until their respective stories land
  - [x] Compile and confirm no errors

- [x] **Task 4: `IRISCouch.JSRuntime.Factory` class** (AC: #5)
  - [x] Create `src/IRISCouch/JSRuntime/Factory.cls` extending `%RegisteredObject`
  - [x] Implement `ClassMethod GetSandbox() As IRISCouch.JSRuntime.Sandbox` that reads `Config.Get("JSRUNTIME")` and returns a new instance of the matching backend — map `"None"` → `IRISCouch.JSRuntime.None`, `"Subprocess"` → `IRISCouch.JSRuntime.Subprocess`, `"Python"` → `IRISCouch.JSRuntime.Python`
  - [x] For any other value (misspelling, legacy value), return `IRISCouch.JSRuntime.None` and log a Warn via `Util.Log.Warn()` naming the unrecognised value — **do not** crash; keeps config typos from taking the server down
  - [x] Optional micro-cache: store the current sandbox instance in a process-private variable keyed by the active `JSRUNTIME` config value; the cache invalidates when Config.Set changes the value. This is a micro-optimisation; only add if test timings indicate Factory.GetSandbox() is being called in a hot loop (e.g., per document during filter eval). Otherwise, construct fresh each call.
  - [x] Compile and confirm no errors

- [x] **Task 5: View endpoint 501 handler** (AC: #2, #4, #7)
  - [x] Add routes to `src/IRISCouch/API/Router.cls` UrlMap for `GET` and `POST` on `/:db/_design/:ddocid/_view/:viewname` — **must** be placed before the generic `_design/:ddocid/:attname` attachment routes (lesson from Story 11.3 Task 0's routing bug). Follow the existing wrapper-method pattern: each route's `Call=` attribute points at a local method in `Router.cls` that delegates to the real handler class
  - [x] Create `src/IRISCouch/API/ViewHandler.cls` extending `%Atelier.REST` with a `ClassMethod HandleView(pDB As %String, pDDocId As %String, pViewName As %String) As %Status`
  - [x] Handler logic: (a) load the design doc body to confirm it exists (404 if not, use `Storage.Document` API — never touch globals directly per `.claude/rules/iris-objectscript-basics.md`); (b) call `Factory.GetSandbox()`; (c) if the sandbox throws `not_implemented`, render 501 with the thrown reason; (d) otherwise would execute the map/reduce — for Story 12.1 the sandbox is always None so step (d) is unreachable; keep the code structure so Story 12.2 can replace the else-branch
  - [x] Use `Response.JSONStatus(501, tBody)` with a `%DynamicObject` shaped `{"error":"not_implemented","reason":"<subsystem-specific reason>"}` — never hand-write the content-type or status
  - [x] Add a local wrapper method in `Router.cls` per the project pattern: `ClassMethod HandleView(pDB, pDDocId, pViewName) As %Status { Set tSC = ##class(IRISCouch.API.ViewHandler).HandleView(pDB, "_design/" _ pDDocId, pViewName) Quit $$$OK }`
  - [x] Integration test: `src/IRISCouch/Test/JSRuntimeHttpTest.cls` adds `TestViewReturns501WhenRuntimeIsNone` — curl-equivalent via `HttpIntegrationTest.MakeRequest`, assert status 501, assert Content-Type `application/json`, assert body shape
  - [x] Negative test: probe the view endpoint on a non-existent design doc → must return 404 before falling into the JSRuntime path

- [x] **Task 6: ChangesHandler custom filter 501** (AC: #4, #7)
  - [x] Locate the custom filter branch in `src/IRISCouch/API/ChangesHandler.cls` — currently ~line 232 skips `_design/` docs for `_selector`; the custom `ddoc/name` path is either not implemented or silently returns empty. Find it via Task 0 probe
  - [x] Add a branch: when `filter` parameter is of the form `{ddoc}/{filtername}` (no leading underscore, contains exactly one `/`), invoke `Factory.GetSandbox()`; if the sandbox throws `not_implemented` on a try-catch-guarded call to `ExecuteFilter`, return 501 with the "custom filter functions..." reason
  - [x] Built-in filters (`_doc_ids`, `_selector`, `_design`) continue to work with no JSRuntime involvement — regression test: add `TestBuiltinFiltersStillWorkWhenRuntimeIsNone` that exercises `filter=_selector` under `JSRUNTIME=None`
  - [x] Positive 501 test: `TestCustomFilterReturns501WhenRuntimeIsNone`
  - [x] Be careful with namespace management (per `.claude/rules/iris-objectscript-basics.md::Namespace Switching in REST Handlers`) — ChangesHandler is a REST dispatch handler; if the custom-filter branch does any `%SYS` work (it should not), use the explicit `Set tOrigNS = $NAMESPACE` save/restore pattern

- [x] **Task 7: DocumentEngine validate_doc_update wiring stub** (AC: #3, #6)
  - [x] In `DocumentEngine.Save()` / `SaveDeleted()` / `SaveWithHistory()` / `SaveWithAttachments()`, add a guarded call site that would evaluate `validate_doc_update` from the target DB's active design docs — for Story 12.1 the code path MUST be a no-op when `Factory.GetSandbox().IsAvailable() = 0` (i.e., None); this is what allows design docs with `validate_doc_update` to be migrated into place without executing (AC #3, AC #6)
  - [x] Do NOT actually iterate design docs or extract `validate_doc_update` source in 12.1 — that is Story 12.3 scope. In 12.1, just add a short comment block at each write method describing where the future hook will fire, and a single `If Factory.GetSandbox().IsAvailable() { ... TODO Story 12.3 ... }` skeleton that is a pure no-op when the condition fails
  - [x] Unit test: `TestDesignDocWithValidateCanBeStoredUnderNoneBackend` — PUT a design doc with `"validate_doc_update": "function(doc){throw({unauthorized: 'nope'});}"`, verify 201, then PUT an ordinary doc under the same DB, verify 201 (validation is not invoked)
  - [x] Regression test: the existing `DocumentEngineTest` suite passes unchanged

- [x] **Task 8: Error envelope rendering helper** (AC: #2, #4)
  - [x] Decide: should the 501 envelope construction live in `Util.Error.cls` (the existing helper class) as a new `Render501(pSubsystem, pReason)` method, or duplicate inline across ViewHandler, ChangesHandler, DocumentEngine?
  - [x] Recommendation: add `ClassMethod Render501(pSubsystem As %String, pReason As %String)` to `Util.Error.cls` to DRY the envelope. Every 501-emitter calls this. One test asserts the exact JSON shape
  - [x] If Util.Error already has a helper that generates the error envelope with a passable status code, reuse it and just add a convenience Render501 wrapper

- [x] **Task 9: Integration tests via `HttpIntegrationTest`** (AC: #2, #3, #4, #7)
  - [x] Create `src/IRISCouch/Test/JSRuntimeHttpTest.cls` extending `IRISCouch.Test.HttpIntegrationTest`
  - [x] Test methods (each using `HttpIntegrationTest.MakeRequest` with the configurable `GetTest*()` accessors per `.claude/rules/iris-objectscript-basics.md::feedback_always_http_test`):
    - `TestViewReturns501WhenRuntimeIsNone` — PUT a design doc with a `views` object, GET `/_view/<name>`, assert 501 + exact body shape
    - `TestValidateDocUpdateSilentlyAllowedWhenRuntimeIsNone` — PUT design doc with `validate_doc_update`, PUT ordinary doc, assert 201
    - `TestCustomFilterReturns501WhenRuntimeIsNone` — POST `/_changes?filter=ddoc/name`, assert 501
    - `TestBuiltinFiltersStillWorkWhenRuntimeIsNone` — POST `/_changes?filter=_doc_ids` with `doc_ids` array, assert 200 and correct filtered results
    - `TestDesignDocStorageIsJsRuntimeIndependent` — PUT, GET, DELETE a design doc under `JSRUNTIME=None`; assert every operation succeeds
    - `TestFactoryResolvesAllConfiguredBackends` — set `^IRISCouch.Config("JSRUNTIME")` to each of `"None"`, `"Subprocess"`, `"Python"`, `"garbage"`; assert `Factory.GetSandbox()` returns the expected concrete class name (None for None and garbage; Subprocess for Subprocess; Python for Python)
  - [x] Setup/teardown: OnBeforeOneTest creates a temp DB; OnAfterOneTest deletes it. Reset `^IRISCouch.Config("JSRUNTIME")` to `"None"` after tests that mutate it (so unrelated tests aren't affected)

- [x] **Task 10: Documentation stub `documentation/js-runtime.md`** (AC: #2, #4)
  - [x] Create `documentation/js-runtime.md` with a short "JSRuntime Backends" overview: what None means, how to enable Subprocess/Python (subsequent stories), and the `^IRISCouch.Config("JSRUNTIME")` override mechanism
  - [x] Story 12.1 only seeds the file; full content arrives in Epic 13 (docs stories). For now, a 20–40 line placeholder that the 501 reason strings can point at
  - [x] Reference it from the relevant Config parameter doc comment in `Config.cls` (inline one-liner pointing at `documentation/js-runtime.md`)

## Dev Notes

### Why this story is "interface only" and still has 10 tasks

Story 12.1 is deliberately light on JS execution (zero lines of actual JS eval) but heavy on **wiring surface**: the abstract interface, the factory, and the three integration points (ViewHandler, ChangesHandler custom filter, DocumentEngine validate hook) all need their guard edges in place before Stories 12.2/12.3/12.4 can replace the None-backend with real execution without touching caller code. The entire point of the Sandbox abstraction is that Story 12.2 only touches `Subprocess.cls`, not any of the callers.

### Reference reads (required per `.claude/rules/research-first.md::Task 0 backend-surface probe`)

- **CouchDB views protocol:** `sources/couchdb/share/server/views.js` — map/reduce signature, emit() semantics, result shape
- **CouchDB validate protocol:** `sources/couchdb/share/server/validate.js` — args order: `newDoc, oldDoc, userCtx, secObj`; throw for rejection; `respond(1)` for approval
- **CouchDB filter protocol:** `sources/couchdb/share/server/filter.js` — filter fn takes `(doc, req)`, returns truthy for pass, results pushed to array per-doc
- **IRIS abstract method requirements:** `.claude/rules/iris-objectscript-basics.md::Abstract Methods in ObjectScript` — abstract methods MUST have `{}` and return a valid default value; `[ Abstract ]` keyword mandatory
- **IRIS Response helper:** existing `IRISCouch.Util.Response` (check class for `JSONStatus` method); `IRISCouch.Util.Error.RenderInternal` for unexpected exceptions
- **Config parameter default:** `IRISCouch.Config.Parameter JSRUNTIME = "None"` (already exists, line 49 in current Config.cls) — no schema change needed

### Previous Story Intelligence

- **Story 11.3 Task 0 (design-doc routing fix):** Epic 11 established that `Router.cls` must place more-specific routes BEFORE `_design/:ddocid/:attname` or the attachment route will swallow them. Task 5's `_view` routes must respect this ordering. The Task 0 regression test pattern (`TestGetDesignDoc`, `TestLocalDocStillRoutes`) is the template — add similar routing tests here.
- **Story 7.3 (_users hooks):** The "hook fires inside Save() / SaveWithHistory() / SaveWithAttachments()" pattern is the template for Task 7's validate_doc_update skeleton. Read `DocumentEngine.Save()` lines ~65–130 for the `_users` hook pattern. Note that the `_users` hook has been a source of pattern-replication bugs (see `.claude/rules/iris-objectscript-basics.md::Pattern Replication Completeness`) — when adding the `validate_doc_update` skeleton, enumerate every save method and confirm the no-op branch is present in each.
- **Story 9.2 (audit events):** Every new handler should emit a basic audit event on entry (per the Security.Events pre-registration rule). Task 5's ViewHandler should emit a `view_attempt` event on every call (even 501s); check `IRISCouch.Audit.Emit.EnsureEvents()` for the registration pattern — if `view_attempt` is not registered, Task 5 must add it to `EnsureEvents()`. Story 9.2 codified this as non-optional.
- **Story 11.0 (stylelint / UI-side rule codification):** No UI work in 12.1 — this is pure backend. Skip.

### Transaction side-effects

Task 7's `validate_doc_update` skeleton is a no-op in Story 12.1, so no transaction concerns. When Story 12.3 wires actual execution, the validation call MUST happen **inside** TSTART/TCOMMIT (we want the write to roll back on rejection), but the skeleton in 12.1 just adds the code site, not the call. Follow `.claude/rules/iris-objectscript-basics.md::Transaction Side Effects` for Story 12.3.

### Namespace Switching

None of the 12.1 work should touch `%SYS`. The `Config.Get()` path reads `^IRISCouch.Config` directly without namespace switch. If Task 7's stub for future use ever needs `%SYS` access (e.g., for security context in validate_doc_update's `userCtx`), follow the explicit save/restore pattern in `.claude/rules/iris-objectscript-basics.md::Namespace Switching in REST Handlers`.

### Storage encapsulation

Task 5's handler must not touch `^IRISCouch.*` globals directly — use `Storage.Document.Read()` / `Storage.Document.Exists()` / equivalent. If a new Storage method is needed (e.g., `Storage.Document.ReadDesignDoc()`), add it rather than shortcutting through global access. Per `.claude/rules/iris-objectscript-basics.md::feedback_storage_encapsulation`.

### File List (expected)

**New ObjectScript classes:**
- `src/IRISCouch/JSRuntime/Sandbox.cls` (abstract, ~80 lines)
- `src/IRISCouch/JSRuntime/None.cls` (~80 lines)
- `src/IRISCouch/JSRuntime/Subprocess.cls` (placeholder stub, ~30 lines)
- `src/IRISCouch/JSRuntime/Python.cls` (placeholder stub, ~30 lines)
- `src/IRISCouch/JSRuntime/Factory.cls` (~60 lines)
- `src/IRISCouch/API/ViewHandler.cls` (~100 lines)
- `src/IRISCouch/Test/JSRuntimeHttpTest.cls` (~200 lines, 6+ test methods)

**Modified ObjectScript classes:**
- `src/IRISCouch/API/Router.cls` — add `_view` routes + local wrapper method
- `src/IRISCouch/API/ChangesHandler.cls` — custom filter 501 branch
- `src/IRISCouch/Core/DocumentEngine.cls` — `validate_doc_update` skeleton (no-op)
- `src/IRISCouch/Util/Error.cls` — add `Render501(pSubsystem, pReason)` helper
- `src/IRISCouch/Audit/Emit.cls` — register `view_attempt` event in `EnsureEvents()` (if not already)

**New docs:**
- `documentation/js-runtime.md` — stub (20–40 lines)

### Project Structure Notes

- New `JSRuntime/` package under `src/IRISCouch/` is the first new top-level package since `Replication/` in Epic 8. Follow the existing package pattern: a root class (`Sandbox.cls`), concrete implementations as siblings, and a Factory. Subsequent stories (12.2, 12.4, 12.5) will extend this package.
- No UI changes in 12.1. The admin UI's Design Document detail view (Story 11.1) already renders design docs regardless of JSRuntime state, so AC #3 is already UI-satisfied.

### References

- Epic spec: `_bmad-output/planning-artifacts/epics.md#Story-121-JSRuntime-Sandbox-Interface-None-Backend` (lines ~2089–2121)
- CouchDB protocol: `sources/couchdb/share/server/views.js`, `validate.js`, `filter.js`
- Config: `src/IRISCouch/Config.cls:49` (`Parameter JSRUNTIME = "None"`)
- Router patterns: `src/IRISCouch/API/Router.cls:59-70` (design-doc routes, Story 11.3 fix)
- DocumentEngine save methods: `src/IRISCouch/Core/DocumentEngine.cls` (Save, SaveDeleted, SaveWithHistory, SaveWithAttachments)
- Project rules invoked: `.claude/rules/iris-objectscript-basics.md` (all of it — this is an ObjectScript story), `.claude/rules/object-script-testing.md` (Test class patterns), `.claude/rules/research-first.md::Task 0 backend-surface probe` (new Story 12.0 rule)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.7 (1M context)

### Debug Log References

**Task 0 backend-surface probes (curl, JSRUNTIME=None before the story):**

```
$ curl -u _system:SYS -i http://localhost:52773/iris-couch/testdb/_design/any/_view/any
HTTP/1.1 404 Not Found
Content-Type: application/json
{"error":"not_found","reason":"missing"}
```

(Non-existent DB path produces a generic "missing" 404; creating `probedb` and
retrying the view route also produces the same 404 because no `/_view/` route
existed yet — confirms AC #2 baseline: the route must be added.)

```
$ curl -u _system:SYS -i -X POST \
    "http://localhost:52773/iris-couch/probedb/_changes?filter=ddoc/name"
HTTP/1.1 404 Not Found
Content-Type: application/json
{"error":"not_found","reason":"missing"}
```

(Confirmed AC #7 baseline: the existing ChangesHandler validates the filter
name against a hard-coded allowlist of built-ins and returns 404 for
anything else — there is no silent pass-through.)

```
$ curl -u _system:SYS -i -X PUT \
    -H "Content-Type: application/json" \
    -d '{"validate_doc_update":"function(doc){throw({unauthorized:\"nope\"});}"}' \
    http://localhost:52773/iris-couch/probedb/_design/probe
HTTP/1.1 201 Created
Content-Type: application/json
{"ok":true,"id":"_design/probe","rev":"1-f7485b6526f365fd072f724805a7931e"}
```

(Confirmed AC #3 regression-baseline: writes of design docs carrying
`validate_doc_update` already succeed because the write path never touches
JS. AC #6 requires this to remain true under None.)

**Reference reads cited (Task 0 — reference audit trail):**

- `sources/couchdb/share/server/views.js` — map/reduce protocol shape:
  `emit(key, value)` pushes `[key, value]` into `map_results`; `mapDoc`
  returns an array of arrays of pairs (one per function per doc);
  `runReduce` returns `[true, reduceLine]`.
- `sources/couchdb/share/server/validate.js` — `validate(fun, ddoc, args)`
  calls `fun.apply(ddoc, args)` where `args = [newDoc, oldDoc, userCtx,
  secObj]`; approval = respond(1), rejection = throw.
- `sources/couchdb/share/server/filter.js` — `filter(fun, ddoc, args)`
  calls `fun.apply(ddoc, [doc, req])` and coerces the result to a bool.
- `irislib/%Exception/General.cls` — `%OnNew(pName, pCode, pLocation,
  pData, pInnerException)`. Note the argument order — `Name` is first,
  `Code` second. The factory's `ThrowNotImplemented` uses
  `%New(subsystem, "not_implemented", "", reason)` so `ex.Name=subsystem`
  and `ex.Code="not_implemented"`.

### Completion Notes List

**Architectural decisions:**

1. **Exception-based 501 signalling (Task 2 — chose throw over sentinel).**
   `IRISCouch.JSRuntime.None` throws `%Exception.General` with
   `Code="not_implemented"` on every `Execute*` call rather than returning
   a sentinel. Rationale: throwing forces every caller to either
   short-circuit via `IsAvailable()` or handle the exception explicitly; a
   caller who forgets the guard fails fast with a clear message instead of
   silently producing bogus data. Subprocess and Python stubs use the same
   pattern for consistency.

2. **`IsAvailable()` as the preferred guard path.**
   Callers that want to return 501 without raising an exception check
   `Factory.GetSandbox().IsAvailable()` first. This keeps try/catch out of
   the hot path for `ViewHandler` and `ChangesHandler`, and makes the
   501-producing branch symmetrical with the future-story executor branch
   that Stories 12.2/12.4 will plug in.

3. **No Factory caching.**
   `Factory.GetSandbox()` constructs a fresh sandbox each call. Concrete
   backends are zero-state `%RegisteredObject`s and None's methods throw
   immediately without touching any resource, so construction is cheap. A
   process-private cache can be added in Story 12.2 if benchmarks show the
   factory being called in a hot loop.

4. **`validate_doc_update` skeleton — pure `If IsAvailable()` no-op.**
   All four `DocumentEngine.Save*` methods gain a 4-line guarded block
   that is unreachable under Story 12.1 (None never reports available) but
   is placed in the exact spot Story 12.3 needs. Zero behaviour change to
   the write path under JSRUNTIME=None — confirmed by AC #3/AC #6 curl
   probe showing a `validate_doc_update`-carrying design doc plus a
   subsequent ordinary write both succeed.

5. **Custom-filter shape detection in `ChangesHandler`.**
   A filter value is treated as a custom JS filter iff it contains
   exactly one `/`, has non-empty segments on both sides, and the first
   character is not `_` (to guard against misspelled built-ins like
   `_doc_id/stray`). Anything else (garbage single-token, multi-slash,
   etc.) preserves the pre-existing 404 "missing" behaviour — verified by
   existing `TestUnknownFilterHttp` which still passes.

6. **Route ordering respected (Story 11.3 Task 0 lesson).**
   The two `_view` routes (`GET` and `POST`) are registered BEFORE the
   generic `_design/:ddocid/:attname` attachment routes in `Router.UrlMap`.
   A dedicated regression test (`TestViewRouteOrdersBeforeAttachmentRoute`)
   asserts the view route reaches `ViewHandler` and returns `501
   not_implemented` rather than a 404 from the attachment route.

**Issues encountered and resolved:**

1. **Test runner ran in wrong namespace.**
   First test run in HSCUSTOM failed because the `/iris-couch` web app
   dispatches to the `IRISCOUCH` namespace, where the test DB created by
   `OnBeforeOneTest` was invisible. Resolved by running tests in
   IRISCOUCH; all 11 pass.

2. **Underscore in property name trapped ObjectScript concat operator.**
   `tBody.validate_doc_update` is parsed as `tBody.validate _
   doc_update`. Fixed by switching to `tBody.%Get("validate_doc_update")`
   in `TestDesignDocWithValidateCanBeStoredUnderNoneBackend`.

3. **%Exception.General arg order.**
   First pass had `Code` / `Name` swapped. Fixed and re-documented inline
   in each `ThrowNotImplemented` / `ThrowNotYetImplemented` comment with
   the actual signature from `irislib/%Exception/General.cls:17`.

**Test results (IRIS %UnitTest, namespace IRISCOUCH):**

- `IRISCouch.Test.JSRuntimeHttpTest`: **11/11 pass** (verified via
  `SELECT ID, Status FROM %UnitTest_Result.TestMethod WHERE ID LIKE
  '%JSRuntimeHttpTest%'`).
- Regression: `IRISCouch.Test.DocumentTest` 10/10 pass — DocumentEngine
  skeleton additions did not break existing write tests.
- Regression: `IRISCouch.Test.ChangesTest` 8/8 pass — ChangesHandler
  edits did not break built-in filter/feed logic.
- Regression: `IRISCouch.Test.ChangesFilterHttpTest` 6/6 pass —
  including `TestUnknownFilterHttp` which confirms the 404 "missing"
  path for malformed filter names is preserved.
- Regression: `IRISCouch.Test.RouterTest` 5/5 pass.
- Regression: `IRISCouch.Test.HttpIntegrationTest` 4/4 pass.

### File List

**New ObjectScript classes:**

- `src/IRISCouch/JSRuntime/Sandbox.cls`
- `src/IRISCouch/JSRuntime/None.cls`
- `src/IRISCouch/JSRuntime/Subprocess.cls`
- `src/IRISCouch/JSRuntime/Python.cls`
- `src/IRISCouch/JSRuntime/Factory.cls`
- `src/IRISCouch/API/ViewHandler.cls`
- `src/IRISCouch/Test/JSRuntimeHttpTest.cls`

**Modified ObjectScript classes:**

- `src/IRISCouch/Config.cls` — inline pointer to `documentation/js-runtime.md`
- `src/IRISCouch/Util/Error.cls` — new `Render501(pSubsystem, pReason)` helper
- `src/IRISCouch/API/Router.cls` — `_view` routes + `HandleView` wrapper method
- `src/IRISCouch/API/ChangesHandler.cls` — custom-filter 501 branch
- `src/IRISCouch/Core/DocumentEngine.cls` — `validate_doc_update` no-op skeleton in Save / SaveDeleted / SaveWithHistory / SaveWithAttachments

**New documentation:**

- `documentation/js-runtime.md` — JSRuntime backends overview (Epic 12)

### Change Log

- 2026-04-17: Implemented Story 12.1. Added abstract
  `IRISCouch.JSRuntime.Sandbox` with four abstract methods, concrete
  `None` backend (throws `not_implemented`), placeholder `Subprocess` and
  `Python` backends, and a `Factory`. Added `ViewHandler` returning 501
  for view execution; patched `ChangesHandler` to return 501 for custom
  filters; added `validate_doc_update` skeleton to DocumentEngine Save*
  methods (no-op under None). Added `Util.Error.Render501` DRY helper.
  Seeded `documentation/js-runtime.md`. Added 11 integration tests,
  all passing; no regressions in DocumentTest / ChangesTest /
  ChangesFilterHttpTest / RouterTest / HttpIntegrationTest.
