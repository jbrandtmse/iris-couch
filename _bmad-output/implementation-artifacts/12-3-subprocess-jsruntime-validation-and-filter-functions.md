# Story 12.3: Subprocess JSRuntime - Validation & Filter Functions

Status: done

## Story

As an operator,
I want `validate_doc_update` hooks and custom changes-feed filter functions to execute via the subprocess runtime,
so that I can enforce document validation rules and filter changes using user-supplied JavaScript.

## Acceptance Criteria

1. **Given** a database containing one or more design documents with `validate_doc_update` function source, and `JSRuntime.Subprocess` is the active backend (`Config.Get("JSRUNTIME") = "Subprocess"`)
   **When** any document write (`Save`, `SaveDeleted`, `SaveWithHistory`, `SaveWithAttachments`) is processed by `DocumentEngine`
   **Then** every matching `validate_doc_update` function is executed **inside the TSTART/TCOMMIT transaction** via `IRISCouch.JSRuntime.Factory.GetSandbox().ExecuteValidateDocUpdate(pValidateFn, pNewDoc, pOldDoc, pUserCtx, pSecObj)`, and if any validate call throws:
   - A JSON object with a `forbidden` key → HTTP **403 Forbidden** with body `{"error":"forbidden","reason":"<thrown-reason>"}`
   - A JSON object with an `unauthorized` key → HTTP **401 Unauthorized** with body `{"error":"unauthorized","reason":"<thrown-reason>"}`
   - Any other throw → HTTP **500** with the exception message rendered via `Util.Error.RenderInternal`
   - On rejection, `TROLLBACK` fires and the write does not persist

2. **Given** a design document with a `validate_doc_update` function that approves the write (does not throw)
   **When** the validation function returns normally
   **Then** the document write proceeds through the remaining save pipeline (write body, update RevTree, record change, update metadata, update projections, …) and returns the normal `{"ok":true,"id":"…","rev":"…"}` response

3. **Given** a changes-feed request with `filter={ddoc}/{filtername}` (where `{ddoc}` is a short name; the full id is `_design/{ddoc}`), and `JSRuntime.Subprocess` is active
   **When** changes are streamed or returned as normal feed mode
   **Then** for each change the custom filter function is executed via `Sandbox.ExecuteFilter(pFilterFn, pDoc, pReq)`, the function's boolean return drives inclusion (truthy = include, falsy = skip), and the response body contains only the changes the filter approved (plus any sequence-only entries CouchDB's semantics dictate; at minimum, `last_seq` is the highest seq processed whether approved or rejected)

4. **Given** `JSRuntime.None` is the active backend (Story 12.1 default)
   **When** a request would invoke `validate_doc_update` (document write against a DB that has a `validate_doc_update`-containing design doc) or a custom filter (`filter=ddoc/name` on changes feed)
   **Then** the response for writes is HTTP 501 with body `{"error":"not_implemented","reason":"validate_doc_update hooks require a JSRuntime backend; set ^IRISCouch.Config(\"JSRUNTIME\") to Subprocess or Python. See documentation/js-runtime.md."}` — this supersedes the Story 12.1 "migration-friendly no-op" semantics for the specific case where a `validate_doc_update` is actually present and would fire (if no design doc in the DB defines a validate function, writes still pass without JS work)

5. **Given** the Subprocess backend's existing `Pipe` infrastructure (Story 12.2)
   **When** `ExecuteValidateDocUpdate` or `ExecuteFilter` is invoked
   **Then** they reuse the same `$ZF(-100)` pipe + couchjs line protocol, following the CouchDB dispatcher commands per `sources/couchdb/share/server/loop.js` `ddoc_dispatch`:
   - Validate: `["ddoc", "new", "_design/<name>", <ddoc-body-json>]` to register → `["ddoc", "_design/<name>", ["validate_doc_update"], [newDoc, oldDoc, userCtx, secObj]]` to invoke → response is `1` on success or `{"forbidden":"..."}`/`{"unauthorized":"..."}` on rejection
   - Filter: `["ddoc", "new", "_design/<name>", <ddoc-body-json>]` to register → `["ddoc", "_design/<name>", ["filters","<fname>"], [[<doc>], <req>]]` to invoke → response is `[true, [<bool-per-doc>]]`

6. **Given** multiple design documents in the same database each define a `validate_doc_update`
   **When** a document write is processed
   **Then** every validate function runs sequentially; if any single one rejects, the first rejection is returned and subsequent validates do not run (fail-fast, matches CouchDB semantics in `couch_doc.erl::validate_doc_update`)

7. **Given** the replication write path (`SaveWithHistory` / `new_edits=false`)
   **When** a document is pulled from a remote source and replicated in
   **Then** `validate_doc_update` still runs per AC #1 — replication writes are NOT exempt (matches CouchDB behaviour; prevents hostile peers from bypassing validation)

## Tasks / Subtasks

- [x] **Task 0: Backend-surface probe (per `.claude/rules/research-first.md::Task 0 backend-surface probe`)** (AC: all)
  - [x] Set `^IRISCouch.Config("JSRUNTIME") = "None"` (default). Probe current behaviour:
    ```
    # Write with a design doc that has validate_doc_update should still 201 (Story 12.1 no-op)
    $ curl -u _SYSTEM:SYS -X PUT /iris-couch/testdb123/_design/val -d '{"validate_doc_update":"function(newDoc,oldDoc,userCtx,secObj){throw({forbidden:\"nope\"});}"}'
    # Then write a normal doc — should still 201 under None (the hook is skipped)
    $ curl -u _SYSTEM:SYS -X PUT /iris-couch/testdb123/foo -d '{}'
    ```
    Paste verbatim output into this Task block.
  - [x] With `^IRISCouch.Config("JSRUNTIME") = "Subprocess"` set and `JSRUNTIMESUBPROCESSPATH` pointing at Node, probe the custom filter endpoint:
    ```
    # Should return 501 not_yet_implemented (Story 12.1 stub until this story lands)
    $ curl -u _SYSTEM:SYS "/iris-couch/testdb123/_changes?filter=val/even"
    ```
    Paste verbatim output.
  - [x] Reset to `^IRISCouch.Config("JSRUNTIME") = "None"` after probes.
  - [x] Cite references read:
    - `sources/couchdb/share/server/loop.js` — `ddoc` dispatcher (lines 55–130), specifically the `ddoc_dispatch["validate_doc_update"]` and `ddoc_dispatch["filters"]` entries
    - `sources/couchdb/share/server/validate.js` — exception-as-rejection semantics (entire file, 25 lines)
    - `sources/couchdb/share/server/filter.js` — per-doc filter evaluation (entire file, 41 lines)
    - `sources/couchdb/src/couch/src/couch_doc.erl::validate_doc_update` — iteration across multiple validate functions (fail-fast on first rejection)
  - [x] Paste all probe outputs + reference line ranges into Dev Notes

- [x] **Task 1: Fill `Subprocess.ExecuteValidateDocUpdate`** (AC: #1, #5)
  - [x] Replace `ThrowNotYetImplemented("validate_doc_update hooks")` in `src/IRISCouch/JSRuntime/Subprocess.cls::ExecuteValidateDocUpdate` with a real implementation
  - [x] Algorithm: (1) open Pipe; (2) send `["reset"]`, read ack; (3) build a minimal `<ddoc-body>` JSON that contains only `validate_doc_update: pValidateFn` (full ddoc not needed — CouchDB only accesses the named field); use a synthetic `_design/__iriscouch_validate__` id; (4) send `["ddoc", "new", "_design/__iriscouch_validate__", <ddoc-body>]`, read `true` ack; (5) send `["ddoc", "_design/__iriscouch_validate__", ["validate_doc_update"], [pNewDoc, pOldDoc, pUserCtx, pSecObj]]`; (6) read response line and parse: `1` or `true` → return `$$$OK`; `{"forbidden": reason}` → `$$$ERROR($$$GeneralError, "forbidden: " _ reason)`; `{"unauthorized": reason}` → `$$$ERROR($$$GeneralError, "unauthorized: " _ reason)`; other throw → `$$$ERROR($$$GeneralError, "validate_error: " _ <raw>)`
  - [x] Close the Pipe on every exit path (use a `Try`/`Catch` with a finally-equivalent)
  - [x] Handle null `pOldDoc` — when the document is being created (no prior rev), CouchDB passes `null`; emit JSON `null`, not the string `"null"`, per `.claude/rules/iris-objectscript-basics.md::feedback_json_null_pattern`
  - [x] Compile via `compile_objectscript_class` MCP tool

- [x] **Task 2: Fill `Subprocess.ExecuteFilter`** (AC: #3, #5)
  - [x] Replace `ThrowNotYetImplemented("custom filter functions")` in `Subprocess.cls::ExecuteFilter`
  - [x] Algorithm: (1) open Pipe; (2) send `["reset"]`, read ack; (3) send `["ddoc", "new", "_design/__iriscouch_filter__", <ddoc-body>]` where ddoc-body = `{"filters": {"fn": pFilterFn}}`, read `true` ack; (4) send `["ddoc", "_design/__iriscouch_filter__", ["filters","fn"], [[pDoc], pReq]]`; (5) read response `[true, [<bool>]]`; (6) return `<bool>` as `%Boolean`
  - [x] Close Pipe; Try/Catch; no leaks on error
  - [x] Note: ChangesHandler can choose to batch filter calls if performance matters — AC #3 does not preclude it, but for Story 12.3 MVP, one-filter-call-per-doc is acceptable. Log a follow-up LOW to defer batching to Story 12.5 pooling
  - [x] Compile

- [x] **Task 3: Design-doc enumeration helper** (AC: #1, #6)
  - [x] Add `ClassMethod ListValidateFunctions(pDB As %String, Output pList) As %Integer` to `src/IRISCouch/Core/DesignDocs.cls` (create the class if it does not exist, as a sibling to `DocumentEngine`)
  - [x] Implementation: iterate all `_design/*` documents in `pDB` via a new `Storage.Document.ListDesignDocIds(pDB, Output pIterator)` helper (add it if missing per Storage encapsulation rule), parse each body as JSON, extract `validate_doc_update` if present, push `{ddocId: <id>, source: <string>}` onto `pList`. Returns count
  - [x] Deleted/tombstoned design docs are excluded (use `Storage.RevTree.GetWinner` + `IsDeleted` guard, same pattern as `Storage.Document.ListLiveDocIds` from Story 12.2)
  - [x] Similar helper `ListFilterFunctions(pDB, pDDocShortName, pFilterName, Output pSource)` returns the single named filter function source (for ChangesHandler's ddoc/name path)
  - [x] Unit tests: `src/IRISCouch/Test/DesignDocsTest.cls`

- [x] **Task 4: DocumentEngine.Save validate_doc_update hook** (AC: #1, #2, #4, #6)
  - [x] Edit `src/IRISCouch/Core/DocumentEngine.cls::Save` — the `TODO Story 12.3` skeleton is at line 47–49
  - [x] Replace the no-op branch with:
    ```objectscript
    If ##class(IRISCouch.JSRuntime.Factory).GetSandbox().IsAvailable() {
        Set tSandbox = ##class(IRISCouch.JSRuntime.Factory).GetSandbox()
        Set tValidates = ##class(IRISCouch.Core.DesignDocs).ListValidateFunctions(pDB, .tVList)
        If tValidates > 0 {
            ; Load oldDoc if this is an update
            Set tOldDoc = $$$NULLOREF
            If pParentRev '= "" {
                Set tOldDoc = ##class(IRISCouch.Storage.Document).Read(pDB, pDocId, pParentRev)  ; returns %DynamicObject or null
            }
            ; Build userCtx from current %request auth context — roles[], name
            Set tUserCtx = ##class(IRISCouch.Auth.Session).BuildUserCtx()
            ; Load secObj from _security
            Set tSecObj = ##class(IRISCouch.Auth.Security).GetOrDefault(pDB)
            Set tNewDocObj = {}.%FromJSON(pBody)
            For i=1:1:tValidates {
                Set tVSC = tSandbox.ExecuteValidateDocUpdate(tVList(i,"source"), tNewDocObj, tOldDoc, tUserCtx, tSecObj)
                If $$$ISERR(tVSC) {
                    TROLLBACK  Set tInTrans = 0
                    Set tNewRev = ""
                    Set pValidateError = $System.Status.GetErrorText(tVSC)  ; propagate to caller
                    Quit
                }
            }
            If tNewRev = "" Quit
        }
    }
    ```
  - [x] Signature change: add an `Output pValidateError As %String` parameter to `Save` (and `SaveDeleted`, `SaveWithHistory`, `SaveWithAttachments`) so the DocumentHandler can render 403/401 per AC #1. Alternative: return the error via an existing `Output` parameter pattern — decide based on what callers expect. Grep existing callers first and propose the minimum-change signature
  - [x] **Pattern Replication Completeness (per `.claude/rules/iris-objectscript-basics.md`):** Apply the SAME hook body to `SaveDeleted` (tombstone writes still need validation), `SaveWithHistory` (replication; AC #7 is explicit — no exemption), `SaveWithAttachments` (attachment-bearing writes). Enumerate all four methods as a checklist in the PR description
  - [x] DocumentHandler callers must interpret `pValidateError` and render 401/403 accordingly. Helper: add `Util.Error.RenderValidateError(pValidateError)` that parses the error prefix (`"forbidden: "`, `"unauthorized: "`) and renders the matching status + envelope
  - [x] Compile

- [x] **Task 5: ChangesHandler custom filter integration** (AC: #3, #4)
  - [x] Edit `src/IRISCouch/API/ChangesHandler.cls` — the custom-filter branch that currently returns 501 (Story 12.1). Find via grep `custom filter functions`
  - [x] Replace 501-throw with:
    ```objectscript
    ; Lookup the filter function source from the referenced ddoc
    Set tSource = ""
    Set tSC = ##class(IRISCouch.Core.DesignDocs).ListFilterFunctions(pDB, tDDocShortName, tFilterName, .tSource)
    If $$$ISERR(tSC) || (tSource = "") {
        ; 404 — filter not found
        Do ##class(IRISCouch.Util.Error).Render(404, "not_found", "missing " _ tDDocShortName _ "/" _ tFilterName)
        Return $$$OK
    }
    Set tSandbox = ##class(IRISCouch.JSRuntime.Factory).GetSandbox()
    If 'tSandbox.IsAvailable() {
        ; Fall back to the 501 path — JSRUNTIME=None or Subprocess couldn't launch
        Do ##class(IRISCouch.Util.Error).Render501("custom filter functions", "custom filter functions require a JSRuntime backend; set ^IRISCouch.Config(""JSRUNTIME"") to Subprocess or Python.")
        Return $$$OK
    }
    ; Per-change filter loop; build a minimal pReq object per CouchDB docs (query, headers, method, path)
    Set tReq = ##class(IRISCouch.API.ChangesHandler).BuildFilterReq()
    ; … existing change-streaming loop …
    ;    For each change, load the doc body, call tSandbox.ExecuteFilter(tSource, tDocObj, tReq)
    ;    Include the change only if tSandbox.ExecuteFilter returns 1
    ```
  - [x] Define `BuildFilterReq()` — returns a `%DynamicObject` with at minimum `method`, `path`, `query` (derived from `%request`) — follows CouchDB's `chttpd_changes:handle_changes/3` builder
  - [x] Keep existing built-in filters (`_doc_ids`, `_selector`, `_design`) working without JSRuntime involvement — regression test is mandatory
  - [x] Compile

- [x] **Task 6: Validate-error envelope helper** (AC: #1, #4)
  - [x] Add `Util.Error.RenderValidateError(pValidateErrorMessage)` that:
    - Parses the prefix: `"forbidden: <reason>"` → `Render(403, "forbidden", reason)`; `"unauthorized: <reason>"` → `Render(401, "unauthorized", reason)`; anything else → `RenderInternal(ex)` with the raw message
  - [x] DocumentHandler's `HandlePut`, `HandleDelete`, `HandleBulkDocs`, `HandleDesignDocPut` call this helper when the engine signals a validate error

- [x] **Task 7: userCtx + secObj builders** (AC: #1)
  - [x] `Auth.Session.BuildUserCtx()` — returns a `%DynamicObject` `{"name": <username>, "roles": [<role>...]}` reading from the current `%request` auth context (session cookie, basic auth, or JWT). If no auth, return `{"name": null, "roles": ["_admin"]}` to match CouchDB admin-party default (trusted-admin deployment per `documentation/js-runtime.md`)
  - [x] `Auth.Security.GetOrDefault(pDB)` — returns the `_security` object for the DB (reusing Story 7.4's Security class); if missing, returns `{"admins":{"names":[],"roles":[]},"members":{"names":[],"roles":[]}}`
  - [x] Unit test each builder in `AuthTest.cls` (existing file or new `UserCtxTest.cls`)

- [x] **Task 8: Integration tests** (AC: all)
  - [x] Create `src/IRISCouch/Test/JSRuntimeValidateHttpTest.cls` extending `HttpIntegrationTest`:
    - `TestValidateApprovesWrite` — design doc validates by returning; PUT ordinary doc → 201
    - `TestValidateRejectsWithForbidden` — `throw({forbidden:"..."});` → 403
    - `TestValidateRejectsWithUnauthorized` — `throw({unauthorized:"..."});` → 401
    - `TestValidateRuns_On_SaveDeleted` — DELETE on an existing doc against a DB whose validate rejects deletes → 403 and the doc remains
    - `TestValidateRuns_On_SaveWithHistory` — replication-format write (new_edits=false) still triggers validate (AC #7)
    - `TestValidateRuns_On_SaveWithAttachments` — inline-attachment write still triggers validate
    - `TestMultipleValidates_FailFast` — two design docs, first rejects; assert second does not run (mock-trace or Log scraping)
    - `TestValidateReturns501WhenRuntimeIsNone_AndValidateIsPresent` — `JSRUNTIME=None`, DB has a validate-containing ddoc, PUT an ordinary doc → 501 per AC #4
    - `TestWritesWithoutValidateStillPassUnderNone` — `JSRUNTIME=None`, no ddoc with validate → 201 (regression for AC #4's exemption)
  - [x] Create `src/IRISCouch/Test/JSRuntimeFilterHttpTest.cls`:
    - `TestCustomFilterIncludesMatches` — filter fn `function(doc,req){return doc.public===true;}` — only public docs in the changes response
    - `TestCustomFilterExcludesAll` — always-false filter — empty `results`, correct `last_seq`
    - `TestCustomFilterMissingDocReturns404` — filter=`ddoc/missing` — HTTP 404
    - `TestBuiltinFiltersRegressGreen` — `_doc_ids`, `_selector`, `_design` still work unchanged
  - [x] Test classes watched for 500-line limit per `.claude/rules/object-script-testing.md`; split if needed
  - [x] All tests use `HttpIntegrationTest.GetTest*()` accessors — no hardcoded creds

- [x] **Task 9: Documentation update** (AC: #4, #5)
  - [x] Expand `documentation/js-runtime.md` with:
    - "Validate Document Update" subsection: how to author; what `throw({forbidden:"..."})` vs `throw({unauthorized:"..."})` mean; how multiple validates compose; that replication is NOT exempt
    - "Custom Filters" subsection: how to author; how the `req` object is shaped; how to reference via `filter=ddoc/name`
  - [x] Cross-link from the Config.cls JSRUNTIME doc comment

- [x] **Task 10: Audit events** (AC: #1)
  - [x] Register `validate_reject` and `filter_execute` in `Audit.Emit.EnsureEvents()` if missing
  - [x] Emit `validate_reject` with `{db, ddoc, docid, status_code, reason}` on every rejection; emit `validate_approve` on success (payload: `{db, ddoc, docid, duration_ms}`)
  - [x] Emit `filter_execute` with `{db, ddoc, filter, changes_in, changes_out, duration_ms}` per completed changes call

## Dev Notes

### Why this story is smaller than 12.2

12.2 built the entire subprocess pipeline from scratch. 12.3 reuses `Pipe`, `Factory`, `Sandbox`, and the couchjs protocol — just filling in the two remaining abstract methods and wiring them into DocumentEngine + ChangesHandler. The only net-new code is:
- The `DesignDocs` helper class (enumerate validate/filter functions per DB)
- `Auth.Session.BuildUserCtx()` + `Auth.Security.GetOrDefault(pDB)` builders
- The validate-error envelope helper
- Two new test files

### Reference reads (Task 0 mandatory per `.claude/rules/research-first.md`)

- **CouchDB validate semantics:** `sources/couchdb/share/server/validate.js` (25 lines) — thrown value is the response; named errors (`{forbidden}`, `{unauthorized}`) map to HTTP 403/401
- **CouchDB filter semantics:** `sources/couchdb/share/server/filter.js` (41 lines) — per-doc invocation, `respond([true, <bool-array>])`
- **CouchDB ddoc dispatch:** `sources/couchdb/share/server/loop.js` (dispatcher dict at ~line 60) — shows the full protocol for registering and invoking ddoc-scoped functions
- **CouchDB server-side fail-fast:** `sources/couchdb/src/couch/src/couch_doc.erl::validate_doc_update` — iterate validates sequentially; first rejection short-circuits
- **IRIS security context:** read `src/IRISCouch/Auth/Session.cls` for how user + roles are materialised; `src/IRISCouch/Auth/Security.cls` for per-DB `_security` object

### Previous Story Intelligence

- **Story 12.1** established `Sandbox` abstract with `ExecuteValidateDocUpdate` and `ExecuteFilter` signatures. DO NOT change them.
- **Story 12.1** seeded the `TODO Story 12.3` skeletons at four DocumentEngine save methods (lines 47, 400, 521, 681) — Task 4 fills these in.
- **Story 12.1** ChangesHandler custom-filter branch returns 501. Task 5 replaces this.
- **Story 12.2** established `Pipe.cls` + couchjs line protocol. Tasks 1 and 2 reuse the Pipe; do NOT reinvent subprocess lifecycle.
- **Story 12.2** established the one-Pipe-per-method-call pattern. Stories 12.3 continues this; pooling is Story 12.5.
- **Story 7.3 (_users hooks):** The "iterate design docs, extract function source, hook the save path" algorithm is a generalization of the existing `_users` password-hash hook. Read `DocumentEngine.Save` lines ~65–130 for the pattern (look for `##class(IRISCouch.Auth.Users)` calls).
- **Story 7.4 (per-DB security):** `_security` object shape and `Auth.Security.GetOrDefault` may already exist; grep before creating.

### Transaction safety

- Validate hook MUST fire **inside** the `TSTART`/`TCOMMIT` in Save (after database-exists check, before body write). A rejection must `TROLLBACK` before returning.
- Filter evaluation in ChangesHandler is read-only; no transaction concerns.
- Follow `.claude/rules/iris-objectscript-basics.md::Transaction Side Effects` — do not spawn jobs or signal events inside the validate block.

### Subscription leaks

ObjectScript story; subscription-leak rule (Angular) does not apply. Pipe lifecycle is the analogue — every `ExecuteValidateDocUpdate`/`ExecuteFilter` call must `Close` its Pipe on every exit path, same pattern as Story 12.2.

### Pattern Replication Completeness

Per `.claude/rules/iris-objectscript-basics.md::Pattern Replication Completeness`, when replicating the validate_doc_update hook from `Save` into the other three save methods, enumerate ALL downstream effects:

| Effect | Save | SaveDeleted | SaveWithHistory | SaveWithAttachments |
|--------|------|-------------|-----------------|---------------------|
| Validate hook | yes | yes (tombstone) | yes (AC #7) | yes |
| TROLLBACK on reject | yes | yes | yes | yes |
| pValidateError Output | yes | yes | yes | yes |
| Caller renders 401/403 | yes | yes | yes | yes |

### Namespace management

Auth.Security.GetOrDefault may need `%SYS` access for role lookups. Follow the explicit save/restore pattern per `.claude/rules/iris-objectscript-basics.md::Namespace Switching in REST Handlers`.

### Storage encapsulation

- `ListValidateFunctions` / `ListFilterFunctions` must iterate through `Storage.Document` or a new `Storage.Document.ListDesignDocIds` iterator — NO direct `^IRISCouch.*` access.
- `Storage.Document.Read(pDB, pDocId, pRev)` already exists (Story 3.1); reuse for parent-rev loading in Task 4.

### File List (expected)

**New:**
- `src/IRISCouch/Core/DesignDocs.cls` — enumeration helpers
- `src/IRISCouch/Test/DesignDocsTest.cls`
- `src/IRISCouch/Test/JSRuntimeValidateHttpTest.cls`
- `src/IRISCouch/Test/JSRuntimeFilterHttpTest.cls`
- Possibly `src/IRISCouch/Test/UserCtxTest.cls`

**Modified:**
- `src/IRISCouch/JSRuntime/Subprocess.cls` (fill in two Execute* bodies)
- `src/IRISCouch/Core/DocumentEngine.cls` (all four save methods + new output param)
- `src/IRISCouch/API/ChangesHandler.cls` (custom filter branch)
- `src/IRISCouch/API/DocumentHandler.cls` (render 401/403 from engine output)
- `src/IRISCouch/Util/Error.cls` (+RenderValidateError)
- `src/IRISCouch/Auth/Session.cls` (+BuildUserCtx)
- `src/IRISCouch/Auth/Security.cls` (verify GetOrDefault exists; if not, add)
- `src/IRISCouch/Storage/Document.cls` (+ListDesignDocIds iterator if missing)
- `src/IRISCouch/Audit/Emit.cls` (+validate_reject, +validate_approve, +filter_execute)
- `documentation/js-runtime.md` (expanded)

### Project Structure Notes

New `IRISCouch.Core.DesignDocs` class parallels `IRISCouch.Core.DocumentEngine` — both orchestrate DB-level concerns. Subsequent Story 12.5 (incremental indexing) may grow this into a `Core/DesignDocIndex.cls` for view-definition change detection.

### References

- Epic spec: `_bmad-output/planning-artifacts/epics.md` — Story 12.3 section (~lines 2152–2177)
- Previous stories: 12.1 (`JSRuntime/Sandbox.cls`), 12.2 (`JSRuntime/Subprocess/Pipe.cls`, `View/QueryEngine.cls`)
- CouchDB reference source: `sources/couchdb/share/server/{validate.js,filter.js,loop.js}`
- Project rules applied: all of `.claude/rules/iris-objectscript-basics.md`, `.claude/rules/object-script-testing.md`, `.claude/rules/research-first.md`

## Dev Agent Record

### Agent Model Used

_TBD_

### Debug Log References

#### Task 0 — Backend-surface probes (verbatim, 2026-04-17)

**Environment:** Windows 11, IRIS HSCUSTOM/IRISCOUCH namespaces, Node v22.19.0 at
`C:\Program Files\nodejs\node.exe`.

**Probe 1 — PUT `_design/val` with validate_doc_update body under JSRUNTIME=None:**
```
$ curl -s -u _SYSTEM:SYS -X PUT -H "Content-Type: application/json" \
    "http://localhost:52773/iris-couch/probe123task0/_design/val" \
    -d '{"validate_doc_update":"function(newDoc,oldDoc,userCtx,secObj){throw({forbidden:\"nope\"});}"}'
{"ok":true,"id":"_design/val","rev":"1-6e593c4e19a83fcc5da8e674060bb73a"}
HTTP_STATUS:201
```

**Probe 2 — PUT ordinary doc under JSRUNTIME=None (validate should be a no-op per
Story 12.1 AC #3/#6):**
```
$ curl -s -u _SYSTEM:SYS -X PUT -H "Content-Type: application/json" \
    "http://localhost:52773/iris-couch/probe123task0/foo" -d '{}'
{"ok":true,"id":"foo","rev":"1-02f9ba62f636a5c41a9c0060102a41bf"}
HTTP_STATUS:201
```

Confirmation: validate hook skeleton is a pure no-op under None even when a
design doc DOES define `validate_doc_update`. This is the Story 12.1 shipping
behaviour that Story 12.3 AC #4 changes — under None + present validate, Story
12.3 writes must return 501.

**Probe 3 — Custom filter changes feed under JSRUNTIME=Subprocess (before Story 12.3):**
```
$ curl -s -u _SYSTEM:SYS \
    "http://localhost:52773/iris-couch/probe123task0/_changes?filter=val/even"
{"error":"server_error","reason":"custom filter executor reached under Story 12.1 (unexpected)"}
HTTP_STATUS:500
```

Observation: the current ChangesHandler branch reports 500, not 501, when
Subprocess.IsAvailable()=1 but ExecuteFilter() is still unimplemented. The 500
is produced by the "unreachable" `RenderInternal` path on line 159 of
ChangesHandler. Under JSRUNTIME=None the same URL produces the expected 501:

**Probe 4 — Same URL under JSRUNTIME=None:**
```
{"error":"not_implemented","reason":"JSRuntime backend is set to None. Set ^IRISCouch.Config(\"JSRUNTIME\") to \"Subprocess\" or \"Python\" to enable custom filter functions. See documentation/js-runtime.md."}
HTTP_STATUS:501
```

**Reference reads:**
- `sources/couchdb/share/server/validate.js` (25 lines total) — `Validate.validate`
  wraps `fun.apply(ddoc, args)`; a thrown value with `.name` + `.stack` (i.e. a
  real Error) re-throws; otherwise `respond(error)` echoes the thrown value
  back (the `{forbidden:"..."}` / `{unauthorized:"..."}` envelopes).
- `sources/couchdb/share/server/filter.js` lines 21-29 — `Filter.filter` iterates
  `docs[]`, coerces return to boolean, and responds `[true, results]`.
- `sources/couchdb/share/server/loop.js` lines 57-122 — `DDoc.ddoc` dispatcher
  registers ddocs keyed by id in a `ddocs{}` map on the `["ddoc","new",id,body]`
  command, and dispatches `["ddoc", id, funPath, funArgs]` by looking up
  `ddoc_dispatch[funPath[0]]`.
- `sources/couchdb/src/couch/src/couch_doc.erl::validate_doc_update` —
  (inspected via source; fail-fast iteration: `lists:foreach` across the list of
  validate funs, first throw short-circuits.)

### Completion Notes List

**Story 12.3 delivery summary (2026-04-17):**

- Subprocess `ExecuteValidateDocUpdate` and `ExecuteFilter` now drive the
  `couchjs` `ddoc` dispatcher per `loop.js::DDoc`, reusing Story 12.2's Pipe
  / per-query lifecycle with no subprocess-pool changes (that lives in 12.5).
- Entry script `documentation/couchjs/couchjs-entry.js` extended with a
  `ddoc` command that registers design-doc bodies in-memory and dispatches
  `validate_doc_update` / `filters.<name>`. The `{forbidden: ...}` /
  `{unauthorized: ...}` thrown-value semantics are preserved verbatim
  from `share/server/validate.js`, and filter results wrap as
  `[true, [<bool>]]` per `share/server/filter.js`.
- `IRISCouch.Core.DesignDocs` adds `ListValidateFunctions` (fail-fast
  iteration of the winning rev of every `_design/*` doc that defines a
  `validate_doc_update` field) and `ListFilterFunctions` (single named
  filter lookup). Both ignore deleted / tombstoned design docs via the
  RevTree.GetWinner + IsDeleted guard.
- `IRISCouch.Core.DocumentEngine` gains a shared `RunValidateHook` called
  from all four save methods inside their TSTART/TCOMMIT blocks. The hook
  returns prefixed error messages (`forbidden:`, `unauthorized:`,
  `not_implemented:`, `validate_error:`) consumed by the new
  `Util.Error.RenderValidateError` / `RenderValidate501` helpers. `_local/*`
  and `_design/*` writes bypass the user hook — matches CouchDB
  `couch_db.erl::validate_doc_update`, and the `_design` bypass prevents
  lockout from repairing a buggy validator.
- All four save methods now accept `Output pValidateError As %String`. The
  change is backward compatible: every existing caller that does not pass
  the parameter keeps working (ObjectScript Output is ByRef-tolerant).
  DocumentHandler and BulkHandler were updated to pass it in the same
  commit; Replication callers left unchanged — they treat validate
  rejections as `tDocWriteFailures` increments, which is the correct
  behaviour per AC #7.
- BulkHandler carries rejections inline per the CouchDB `_bulk_docs`
  per-doc error envelope (`{id, error:"forbidden"|"unauthorized"|…, reason}`)
  via a new `BuildValidateErrorEntry` helper, so a single rejected doc in
  a batch does not fail the whole request.
- `ChangesHandler` wires custom filters: resolve the source from the
  referenced ddoc, 404 if absent, 501 if no runtime, otherwise invoke
  `ExecuteFilter` per candidate change. Deleted docs are rendered as
  `{_id,_rev,_deleted:true}` envelopes so filter fns can exclude
  tombstones cleanly. Audit `FilterExecute` tallies changes-in /
  changes-out per request.
- New audit event types `ValidateReject`, `ValidateApprove`, `FilterExecute`
  registered via `Audit.Emit.EnsureEvents`; all three emit from within
  the normal code paths (silently absorbed on failure per NFR-O6).
- `Auth.Session.BuildUserCtx()` emits CouchDB-shaped user context with
  admin-party default for anonymous requests (`name: null, roles: ["_admin"]`).
  `Auth.Security.Get()` already returned the empty-default secObj for
  databases without an explicit `_security` — no new helper needed.

**Pattern Replication Completeness checklist (per `.claude/rules/iris-objectscript-basics.md`):**

| Effect | Save | SaveDeleted | SaveWithHistory | SaveWithAttachments |
|--------|:----:|:-----------:|:---------------:|:-------------------:|
| Validate hook inside TSTART | OK | OK | OK | OK |
| TROLLBACK on reject | OK | OK | OK | OK |
| `pValidateError` Output param | OK | OK | OK | OK |
| DocumentHandler callers updated | OK | OK | n/a (repl) | OK |
| BulkHandler callers updated | OK | OK | n/a (new_edits=false drops silently per CouchDB spec) | n/a |
| `_design` / `_local` bypass | OK (shared via RunValidateHook) | OK | OK | OK |
| Audit ValidateReject/Approve | OK (shared) | OK | OK | OK |

**Key decisions:**

1. **Signature change vs. process-private:** added `Output pValidateError As
   %String` to all four Save methods. ObjectScript `Output` is ByRef-tolerant,
   so the 29 callers (27 are tests) that don't care about the new param keep
   working unchanged. Documented the contract in each method's docblock.
2. **`_design` write bypass:** writes to design docs themselves skip the user
   validate loop. Otherwise a ddoc with a rejecting validate would lock the
   database — operators could never fix the validator without direct global
   surgery. Matches CouchDB `couch_db.erl::validate_doc_update` which sends
   design-doc writes through `validate_ddoc` (structural check) rather than
   `validate_doc_update_int` (user hook).
3. **Peeling `ERROR #NNNN:`:** the dev-server locale is Arabic
   (`خطأ #5001:`) so prefix matching on `ERROR #` does not work. The peel is
   done once at the caller boundary (DocumentHandler.RenderValidate /
   BulkHandler.BuildValidateErrorEntry) by grabbing everything after the
   first `": "`. Util.Error.RenderValidateError expects an already-peeled
   message so it does not re-peel into the `forbidden:` prefix.
4. **Filter-result on tombstones:** the changes feed hands the filter a
   minimal envelope `{_id,_rev,_deleted:true}` for deletions so filters can
   still exclude them by id pattern without the body being available.
5. **req object shape:** minimal but CouchDB-compatible — method, path,
   query (parsed), info.db_name, userCtx, and a trimmed headers map
   (User-Agent, Content-Type). Matches the `chttpd_changes:handle_changes`
   shape. Additions are trivially backward-compatible via property addition.

**Test counts (all via `%UnitTest.Manager.DebugRunTestCase` with subscript
summary via `SubprocessValidateProbe.LastUnitTestSummary`):**

| Suite | Assertions | Pass | Fail |
|-------|-----------:|-----:|-----:|
| DesignDocsTest (new) | 39 | 39 | 0 |
| UserCtxTest (new) | 11 | 11 | 0 |
| JSRuntimeValidateHttpTest (new, 9 methods) | 40 | 40 | 0 |
| JSRuntimeFilterHttpTest (new, 4 methods) | 19 | 19 | 0 |
| DocumentTest (regression) | 46 | 46 | 0 |
| DocumentUpdateTest (regression) | 31 | 31 | 0 |
| DocumentHttpTest (regression) | 76 | 76 | 0 |
| BulkOpsTest (regression) | 24 | 24 | 0 |
| ChangesTest (regression) | 48 | 48 | 0 |
| ChangesFilterTest (regression) | 37 | 37 | 0 |
| ChangesFilterHttpTest (regression) | 44 | 44 | 0 |
| ReplicationTest (regression) | 48 | 48 | 0 |
| JSRuntimeSubprocessHttpTest (Story 12.2 regression) | 86 | 86 | 0 |
| AuditTest (regression) | 46 | 46 | 0 |
| InlineAttachmentTest (regression) | 50 | 50 | 0 |
| UsersTest (regression) | 54 | 54 | 0 |
| **Totals** | **699** | **699** | **0** |

- New story 12.3 assertions: 109 (across 4 new test classes / 20 test methods)
- Regression assertions unchanged: 590 (zero regressions)

**Scope cuts:** none. All 10 tasks landed.

### File List

**New:**
- `src/IRISCouch/Core/DesignDocs.cls`
- `src/IRISCouch/Test/DesignDocsTest.cls`
- `src/IRISCouch/Test/UserCtxTest.cls`
- `src/IRISCouch/Test/JSRuntimeValidateHttpTest.cls`
- `src/IRISCouch/Test/JSRuntimeFilterHttpTest.cls`
- `src/IRISCouch/Test/SubprocessValidateProbe.cls` (developer probe helper;
  intentionally retained as part of Dev Notes evidence — safe to delete
  after story close)

**Modified:**
- `src/IRISCouch/JSRuntime/Subprocess.cls` (ExecuteValidateDocUpdate +
  ExecuteFilter + encoders)
- `src/IRISCouch/Core/DocumentEngine.cls` (RunValidateHook helper;
  pValidateError output on all four Save* methods; hook wired inside
  each TSTART block)
- `src/IRISCouch/API/ChangesHandler.cls` (custom filter branch +
  BuildFilterReq helper + FilterExecute audit)
- `src/IRISCouch/API/DocumentHandler.cls` (RenderValidate helper +
  validate-error propagation at 4 call sites)
- `src/IRISCouch/API/BulkHandler.cls` (BuildValidateErrorEntry +
  validate-error propagation at 2 call sites)
- `src/IRISCouch/Util/Error.cls` (RenderValidateError + RenderValidate501)
- `src/IRISCouch/Auth/Session.cls` (BuildUserCtx)
- `src/IRISCouch/Audit/Emit.cls` (ValidateReject + ValidateApprove +
  FilterExecute + EnsureEvents registers the 3 new types)
- `documentation/couchjs/couchjs-entry.js` (ddoc dispatcher branch)
- `documentation/js-runtime.md` (Validate + Filter sections; Story 12.2
  header updated to 12.2+12.3; commands list and troubleshooting refreshed)

### Change Log

- 2026-04-17 Story 12.3 — Subprocess JSRuntime: Validation & Filter Functions
  (validate_doc_update hooks + custom changes-feed filters shipped). 699
  test assertions, 0 regressions.
