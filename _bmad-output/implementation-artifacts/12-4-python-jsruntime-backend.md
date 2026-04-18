# Story 12.4: Python JSRuntime Backend

Status: deferred (2026-04-17) — IRIS embedded Python unavailable on dev host. README updated naming Subprocess/Node as the single supported JS runtime for α/β milestones. Revisit when a Python-enabled IRIS image is available or a customer deployment specifically requires the Python backend.

## Story

As an operator,
I want an alternative JSRuntime backend that uses IRIS embedded Python with an embedded JavaScript engine (QuickJS or py_mini_racer),
so that I can run design-document JavaScript without installing Node, Bun, Deno, or an external couchjs binary on the server.

## Acceptance Criteria

1. **Given** `Config.Get("JSRUNTIME") = "Python"`, IRIS embedded Python is available (`%SYS.Python` responds to `Import("sys")`), and a suitable Python JS-engine package (either `quickjs` or `py_mini_racer`) is installed in the IRIS Python environment
   **When** a client requests a view, validate_doc_update, or custom-filter execution
   **Then** the JavaScript function is executed via `%SYS.Python` + the chosen JS-engine binding, and the returned result is structurally identical to the result produced by `JSRuntime.Subprocess` for the same input (byte-for-byte JSON equivalence on the visible API; internal representations may differ)

2. **Given** the `IRISCouch.JSRuntime.Python` class
   **When** it is invoked via `Factory.GetSandbox().Execute*(...)`
   **Then** it uses the same `Sandbox` abstract interface from Story 12.1 — callers (`ViewHandler` / `QueryEngine`, `DocumentEngine`, `ChangesHandler`) do **not** branch on backend identity; the `IsAvailable()` check is the only polymorphic decision point

3. **Given** IRIS embedded Python is not available on the host instance (older IRIS build, Python not installed, or `%SYS.Python.Import("sys")` throws)
   **When** `Config.Get("JSRUNTIME") = "Python"` and a JS-execution path is hit
   **Then** `IRISCouch.JSRuntime.Python.IsAvailable()` returns 0, the Factory resolver / caller falls through to a clear 501 error with body `{"error":"not_implemented","reason":"Python JSRuntime backend requires IRIS embedded Python which is not available on this instance. Install a Python-enabled IRIS build or set ^IRISCouch.Config(\"JSRUNTIME\") to \"Subprocess\" or \"None\". See documentation/js-runtime.md."}` — NOT a 500 and NOT a silent crash

4. **Given** IRIS embedded Python is available but the required JS engine library is not installed (`quickjs` and `py_mini_racer` both absent)
   **When** `Config.Get("JSRUNTIME") = "Python"` and a JS-execution path is hit
   **Then** `IsAvailable()` returns 0 and the 501 response names the missing package explicitly: `reason: "Python JSRuntime backend requires one of the Python packages 'quickjs' or 'py_mini_racer' installed in the IRIS Python environment (neither is present). Install with 'irispip install quickjs' or set ^IRISCouch.Config(\"JSRUNTIME\") to \"Subprocess\" or \"None\"."`

5. **Given** the Python JS-engine wrapper needs to be shared across invocations within a single request (view evaluating N docs, filter across K changes)
   **When** `ExecuteMap` / `ExecuteReduce` / `ExecuteValidateDocUpdate` / `ExecuteFilter` are called
   **Then** each invocation compiles the function source lazily (first-use cache within the method call) and reuses it for every doc in the same call; compilation/call overhead per document is bounded by the JS engine itself (QuickJS compiles in ~1ms for typical map functions)

6. **Given** a map or reduce function throws a JavaScript exception during Python-backend execution
   **When** the error propagates back to ObjectScript
   **Then** the Python layer captures the JS exception's `.name`, `.message`, and (if available) `.stack`, converts to a `%Exception.General` in ObjectScript, and the caller renders it identically to the Subprocess-backend error path — per-doc map errors swallowed with `Util.Log.Warn`, validate errors classified by `{forbidden}`/`{unauthorized}` keys, etc.

7. **Given** the admin UI and CouchDB operator documentation
   **When** an operator is choosing between backends
   **Then** `documentation/js-runtime.md` explains when to pick Python over Subprocess: (a) Python for single-file deployment with no external Node dependency; (b) Subprocess when the operator wants Node/Bun compatibility or plans to scale to many parallel runtimes; (c) None for migration staging; and the doc calls out Python's limitations (sandbox is in-process; a hostile `while(true){}` can freeze the IRIS process — use with trusted design docs only until Story 12.5 sandboxing lands)

## Tasks / Subtasks

- [ ] **Task 0: Backend-surface probe (per `.claude/rules/research-first.md::Task 0 backend-surface probe`)** (AC: all)
  - [ ] Probe IRIS embedded Python availability via MCP `iris_execute_command`:
    ```objectscript
    Do ##class(%SYS.Python).Import("sys")
    Write ##class(%SYS.Python).GetPythonVersion()
    ```
    Paste verbatim output (should print a version string, e.g. `3.11.x`).
  - [ ] Probe whether `quickjs` or `py_mini_racer` is installed:
    ```objectscript
    Try { Set qjs = ##class(%SYS.Python).Import("quickjs")  Write "quickjs: OK" }
    Catch ex { Write "quickjs: MISSING - "_ex.DisplayString() }
    Try { Set pmr = ##class(%SYS.Python).Import("py_mini_racer")  Write "py_mini_racer: OK" }
    Catch ex { Write "py_mini_racer: MISSING - "_ex.DisplayString() }
    ```
    Paste verbatim output.
  - [ ] If neither package is installed: use `irispip install quickjs` (the project-documented irispip pattern) to install QuickJS. Document the exact install command and its output.
  - [ ] **Mandatory research read (per project rule `.claude/rules/iris-objectscript-basics.md::Python Integration`):**
    - Perplexity MCP query: "IRIS embedded Python %SYS.Python.Import execute function QuickJS binding" — capture the authoritative call pattern
    - Perplexity MCP query: "Python quickjs library vs py_mini_racer: feature comparison, performance, sandboxing" — record which backend is chosen and why
    - Check if `documentation/IRIS_Embedded_Python_Complete_Manual.md` exists; it currently does NOT (only `js-runtime.md` and `couchjs/` are in `documentation/`). Seed a placeholder note so future stories know.
  - [ ] Cite references read:
    - `irislib/%SYS/Python.cls` — `%SYS.Python.Import()`, `%SYS.Python.Run()`, `%SYS.Python.GetPythonVersion()` — confirm signatures before calling
    - Perplexity research links (2–4 authoritative sources)
    - `sources/couchdb/share/server/loop.js` — reference semantics for map/reduce/validate/filter dispatch that the Python backend must match
  - [ ] Paste all probe outputs + research summary into Dev Notes

- [ ] **Task 1: Python bridge module** (AC: #1, #5)
  - [ ] Create `documentation/quickjs-bridge/jsruntime.py` — a Python module that exposes four top-level functions called from ObjectScript:
    - `execute_map(map_fn_source: str, doc: dict) -> list[list[Any]]` — compile map fn, run it against doc, collect `emit(key, value)` calls, return list of `[key, value]` pairs
    - `execute_reduce(reduce_fn_source: str, keys: list, values: list, rereduce: bool) -> Any` — call reduce fn, return scalar result
    - `execute_validate(validate_fn_source: str, new_doc: dict, old_doc: Optional[dict], user_ctx: dict, sec_obj: dict) -> dict` — call validate fn; return `{"ok": True}` on pass, `{"forbidden": reason}` / `{"unauthorized": reason}` / `{"error": message}` on reject
    - `execute_filter(filter_fn_source: str, doc: dict, req: dict) -> bool` — call filter fn, coerce truthy return to bool
  - [ ] Implementation uses the JS engine chosen in Task 0 (prefer `quickjs` for lighter footprint; fall back to `py_mini_racer` if QuickJS has issues). Compile each function source via the engine's compile API; run with the supplied args.
  - [ ] Provide a `sandbox_globals()` helper that seeds `emit`, `sum`, `log`, `JSON.stringify`, `toJSON`, and `isArray` into the JS engine — same surface as `sources/couchdb/share/server/loop.js::create_sandbox()`
  - [ ] Marshalling: ObjectScript `%DynamicObject` → Python dict → JS object. Python should use standard `json.loads(obj_json)` + `json.dumps` for round-trip rather than traversing IRIS objects directly, because `%SYS.Python` proxies can be slow. ObjectScript side serializes via `obj.%ToJSON()` before the call, Python deserializes.
  - [ ] Error propagation: any exception from the JS engine should be converted to a JSON-serializable error object `{"error": "...", "message": "...", "stack": "..."}` and returned (NOT raised as a Python exception, which would surface as a generic `%Exception.General` on the ObjectScript side — losing the forbidden/unauthorized classification)
  - [ ] Self-test at the bottom of the file (in `if __name__ == "__main__":`) so the module can be smoke-tested via `python jsruntime.py`

- [ ] **Task 2: Fill `IRISCouch.JSRuntime.Python` implementation** (AC: #1, #2)
  - [ ] Replace the `ThrowNotYetImplemented` stubs in `src/IRISCouch/JSRuntime/Python.cls` with real bodies
  - [ ] ClassMethod `GetBridgeModule() As %SYS.Python [Private]` — lazy-load the bridge module from `documentation/quickjs-bridge/jsruntime.py`. Requires `sys.path.append(<bridge-dir>)` before import; standard `%SYS.Python` pattern
  - [ ] `IsAvailable() As %Boolean` — try to import sys, then try to import the bridge (which tries to import quickjs); return 1 iff both succeed. Cache the result in a process-private `^||IRISCouch.JSRuntime.Python.IsAvailable` global so the check runs at most once per process (invalidate on Config.Set) — or simpler: just cache in a class-level `ClassMethod` using a PPG. Discuss cache invalidation in Dev Notes
  - [ ] `ExecuteMap(pMapFn, pDoc)` — call `bridge.execute_map(pMapFn, pDoc.%ToJSON())`; parse the Python list of `[key, value]` pairs back into a `%DynamicArray`; return
  - [ ] `ExecuteReduce(pReduceFn, pKeys, pValues, pRereduce)` — similar pattern; call `bridge.execute_reduce(...)`; wrap result in `{"ok": true, "value": <result>}`
  - [ ] `ExecuteValidateDocUpdate(pValidateFn, pNewDoc, pOldDoc, pUserCtx, pSecObj)` — call `bridge.execute_validate(...)`; parse `{"ok": true}` → $$$OK; `{"forbidden": r}` → $$$ERROR named forbidden; `{"unauthorized": r}` → $$$ERROR named unauthorized; `{"error": r}` → $$$ERROR generic
  - [ ] `ExecuteFilter(pFilterFn, pDoc, pReq)` — call `bridge.execute_filter(...)`; cast bool return to `%Boolean`
  - [ ] Compile via `compile_objectscript_class` MCP tool

- [ ] **Task 3: Extend `IRISCouch.JSRuntime.Factory`** (AC: #2, #3, #4)
  - [ ] The Factory already resolves `"Python"` to `IRISCouch.JSRuntime.Python` (Story 12.1). Verify no change needed
  - [ ] Consider: when `IsAvailable()` returns 0 on the resolved backend, should Factory fall back to None? Current Story 12.1 behaviour returns the configured class regardless; the caller checks IsAvailable before calling Execute*. Keep this contract — do NOT change Factory semantics in 12.4
  - [ ] Document the IsAvailable semantics in `Factory.cls` doc comment so future backends don't violate the contract

- [ ] **Task 4: ViewHandler / QueryEngine / DocumentEngine / ChangesHandler integration** (AC: #1, #2, #6)
  - [ ] **No call-site changes expected.** Callers already use `Factory.GetSandbox().IsAvailable()` and `Factory.GetSandbox().Execute*`. Story 12.4's Python backend should be transparent per AC #2
  - [ ] Add one new integration test per call site that sets `JSRUNTIME=Python` and runs the same test as the Subprocess backend, asserting byte-identical API output
  - [ ] Any call site that branches on "is this the Subprocess backend" (probably none, by design) is a bug — fix with an abstract-method addition

- [ ] **Task 5: Error-classification parity** (AC: #6)
  - [ ] Ensure Python-backend validate errors produce the SAME `$$$ERROR` status text as Subprocess-backend so `Util.Error.RenderValidateError` can classify them
  - [ ] Integration test: create a validate fn that throws `{forbidden: "x"}`, run it under Python, assert 403. Same throw under Subprocess → 403. Assert the response bodies are byte-identical (except possibly timing/trace metadata)
  - [ ] Integration test: per-doc map error under Python — verify Util.Log.Warn fires with the same format as Subprocess

- [ ] **Task 6: Integration tests** (AC: all)
  - [ ] Create `src/IRISCouch/Test/JSRuntimePythonHttpTest.cls` extending `HttpIntegrationTest`:
    - `TestPythonMapSimpleView` — same payload as `TestSubprocessMapSimpleView`, but under `JSRUNTIME=Python`; assert same response
    - `TestPythonMapWithReduce` — builtin reduce via the Python path (should short-circuit to `BuiltinReduce` natively; verify)
    - `TestPythonMapWithCustomReduce` — user JS reduce via Python
    - `TestPythonValidateApprovesWrite` — validate approves
    - `TestPythonValidateRejectsWithForbidden` — `throw({forbidden:"..."})` → 403
    - `TestPythonValidateRejectsWithUnauthorized` — `throw({unauthorized:"..."})` → 401
    - `TestPythonCustomFilterIncludesMatches` — filter fn on changes feed
    - `TestPythonBackendFallsBackTo501WhenPyLibMissing` — force `IsAvailable()=0` via a test hook; assert 501 with the AC #4 reason string
    - `TestPythonBackendFallsBackTo501WhenEmbeddedPythonMissing` — mock/hook `%SYS.Python.Import` to throw; assert 501 with AC #3 reason string
    - `TestPythonResultByteEqualSubprocess` — run the same map function under both backends in sequence, diff the JSON bodies, assert equal (AC #1)
  - [ ] Each test checks `JSRuntime.Python.IsAvailable()` first and skips gracefully (`$$$AssertTrue(1, "SKIP: embedded Python or quickjs unavailable")`) if either is missing — CI portability
  - [ ] Setup/teardown: set `^IRISCouch.Config("JSRUNTIME")="Python"` per test; reset to None in OnAfterOneTest

- [ ] **Task 7: Documentation update** (AC: #7)
  - [ ] Expand `documentation/js-runtime.md` with a "Python Backend" section covering:
    - How to enable (`^IRISCouch.Config("JSRUNTIME")="Python"` + `irispip install quickjs`)
    - How availability detection works (2-step check: embedded Python + Python JS-engine package)
    - **Limitations:** in-process execution means a hostile or buggy JS function can freeze the IRIS process (`while(true){}` is fatal); use only with trusted design docs until Story 12.5 sandboxing lands
    - **Performance:** per-doc overhead is ObjectScript → Python FFI + JS compile; QuickJS is ~1ms per compile, execution is native-Python fast
    - **When to choose Python vs Subprocess:** Python for single-file deployment; Subprocess for Node/Bun compat and parallelism
  - [ ] Create `documentation/quickjs-bridge/README.md` — short "how to install quickjs in the IRIS Python env" note (using `irispip` per IRIS standard pattern)
  - [ ] Link from `Config.cls` JSRUNTIME doc comment

- [ ] **Task 8: Audit events + metrics** (AC: #1)
  - [ ] The Python backend should emit the same audit events as Subprocess (`view_execute`, `view_error`, `validate_reject`, `validate_approve`, `filter_execute`). Since these are emitted by the caller (ViewHandler, DocumentEngine, ChangesHandler), not the Sandbox, no changes needed — but verify every audit call site fires correctly under `JSRUNTIME=Python` via a smoke test
  - [ ] Add a `jsruntime_backend` label to the metrics so `Metrics.Collector` can track per-backend view-query counts. Update `Metrics.Collector` to extract the current `Config.Get("JSRUNTIME")` and tag counters accordingly. (Optional; degrade gracefully if Metrics.Collector API does not support labels yet.)

## Dev Notes

### Why this story is smaller than 12.2

12.2 built the entire subprocess pipeline from scratch. 12.4 reuses:
- `Sandbox` abstract interface (Story 12.1)
- `Factory` resolver (Story 12.1)
- `ViewHandler` + `QueryEngine` + `BuiltinReduce` (Story 12.2)
- `DocumentEngine` validate hook (Story 12.3)
- `ChangesHandler` filter branch (Story 12.3)
- `Util.Error.RenderValidateError` (Story 12.3)
- `Audit.Emit` events (Stories 12.2/12.3)

The only net-new code is:
- Python bridge module (`jsruntime.py`)
- `IRISCouch.JSRuntime.Python.cls` bodies (stubs exist from 12.1)
- `JSRuntimePythonHttpTest.cls`

Expect ~300 lines of Python, ~150 lines of ObjectScript, ~250 lines of test. Much less than 12.2's 3K-line landing.

### Reference reads (Task 0 mandatory)

- **IRIS embedded Python:** `irislib/%SYS/Python.cls` — confirm `Import()`, `Run()`, `GetPythonVersion()` signatures. If `documentation/IRIS_Embedded_Python_Complete_Manual.md` does not exist, use Perplexity per the project rule (it currently does not exist — this is the expected path)
- **QuickJS Python binding:** https://github.com/PetterS/quickjs (primary) or equivalent; research via Perplexity for current best-of-breed
- **py_mini_racer:** https://github.com/bpcreech/PyMiniRacer (fallback) — embeds V8; heavier but more compat
- **CouchDB dispatch semantics:** `sources/couchdb/share/server/loop.js` — sandbox globals surface (`emit`, `sum`, `log`, `JSON`, `toJSON`, `isArray`) that Python bridge must seed

### Python integration guardrails (from `.claude/rules/iris-objectscript-basics.md::Python Integration`)

- `##class(%SYS.Python).IsAvailable()` does NOT exist. Use `Import("sys")` + check via `GetPythonVersion()`.
- `%SYS.Python.Import()` returns a proxy; all Python calls go through the proxy pattern
- Use `import iris` inside Python code when calling ObjectScript from Python (not needed for this story; bridge is one-way — OBJ→PY)
- Marshal via JSON strings to avoid slow attribute traversal on `%SYS.Python` proxies

### Previous Story Intelligence

- **Story 12.1** created the `Python.cls` stub. Bodies need filling. Abstract method signatures are fixed.
- **Story 12.2** established `Pipe.cls` subprocess lifecycle and the couchjs line protocol — Story 12.4 does NOT use either; the Python backend is in-process.
- **Story 12.3** established `Util.Error.RenderValidateError` and the `{forbidden}`/`{unauthorized}` parsing — Python backend must produce identically-shaped error statuses so this helper works unchanged.
- **Story 12.3** established `Auth.Session.BuildUserCtx` — Python backend reuses this.

### Python availability caching

`IsAvailable()` caches its result in a process-private global `^||IRISCouch.JSRuntime.Python.IsAvailable`. The cache is invalidated on the first call after an IRIS-restart (PPGs clear) and on `Config.Set("JSRUNTIME", ...)` (add a hook in `Config.Set` to kill the PPG). Alternative: no caching, re-check on every call — safer but slower. Recommend caching with a Config.Set hook. Document the choice.

### Sandbox hardening

**IMPORTANT:** AC #7 explicitly calls out that Python backend is **in-process** — a hostile or buggy `while(true){}` can freeze IRIS. Story 12.5 adds timeout enforcement (for both backends), but for 12.4 this is a known limitation. Document loudly in `js-runtime.md`:

> **WARNING:** The Python backend executes JavaScript **in-process** with IRIS. A buggy or malicious design document function can freeze the IRIS worker process. Only enable the Python backend for trusted design documents until Story 12.5's sandbox timeout lands.

This matches CouchDB's own caveat about the default couchjs setup (no timeout in the JS engine itself; the wrapper enforces it).

### irispip and package installation

IRIS's `irispip` is the CLI wrapper around `pip` that targets the IRIS Python environment. Dev should:
1. Check if `irispip` is on PATH (`which irispip` via bash)
2. Run `irispip install quickjs` (trial); if it fails, fall back to `irispip install py_mini_racer`
3. Document the successful install in the story Dev Notes

If the dev machine's IRIS instance does not have `irispip` wired up, there's usually a direct path like `<iris-install>/bin/irispip` or `<iris-install>/mgr/python/bin/pip`. Task 0 probe must find it.

### Storage encapsulation

No direct `^IRISCouch.*` access from the Python backend. Python bridge is pure JS-engine wrapping; it never touches IRIS state. ObjectScript side serializes inputs via `%ToJSON()` and hands JSON strings to Python.

### File List (expected)

**New:**
- `documentation/quickjs-bridge/jsruntime.py` — ~300 lines Python
- `documentation/quickjs-bridge/README.md` — ~50 lines install doc
- `src/IRISCouch/Test/JSRuntimePythonHttpTest.cls` — ~300 lines, 10 test methods

**Modified:**
- `src/IRISCouch/JSRuntime/Python.cls` (stub → implementation)
- `src/IRISCouch/JSRuntime/Factory.cls` (doc-comment clarification on IsAvailable contract; no code change expected)
- `documentation/js-runtime.md` (expanded Python section)
- `src/IRISCouch/Metrics/Collector.cls` (optional jsruntime_backend label)

### Project Structure Notes

- `documentation/quickjs-bridge/` parallels `documentation/couchjs/` from Story 12.2. Each backend gets its own bridge artifact directory.
- No new top-level package in `src/IRISCouch/`. All work is in existing JSRuntime package.

### References

- Epic spec: `_bmad-output/planning-artifacts/epics.md` — Story 12.4 (~lines 2178–2199)
- Previous stories: 12.1 (Python stub), 12.2 (Subprocess reference), 12.3 (validate + filter wiring)
- Project rules: `.claude/rules/iris-objectscript-basics.md::Python Integration`, `.claude/rules/research-first.md::Task 0 backend-surface probe`, `.claude/rules/object-script-testing.md`
- External: QuickJS-Python binding or py_mini_racer — resolve via Perplexity at Task 0

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (1M context) — bmad-dev-story workflow attempt 1, 2026-04-17

### Debug Log References

Task 0 probe output (via temporary `IRISCouch.JSRuntime.PythonProbe.cls`, deleted after the probe):

```
sys import: FAIL (<OBJECT DISPATCH> 230 Probe+6^IRISCouch.JSRuntime.PythonProbe.1
   Failed to Load Python: Check documentation and messages.log,
   Check CPF parameters:[PythonRuntimeLibrary,PythonRuntimeLibraryVersion],
   Check sys.path setup in: $INSTANCE/lib/python/iris_site.py)
version: Not Loaded
quickjs: MISSING (same dispatch error)
py_mini_racer: MISSING (same dispatch error)
exe: unknown
```

`%SYS.Python.GetPythonInfo(.info)` output:

```
AllowAnyPythonForIntegratedML=0
BuildVersion=3.13.0 (tags/v3.13.0:60403a5, Oct  7 2024, 09:38:07) [MSC v.1941 64 bit (AMD64)]
BuildVersionShort=3.13.0
CPF_PythonPath=Not Set in CPF
CPF_PythonRuntimeLibrary=Not Set in CPF
CPF_PythonRuntimeLibraryVersion=Not Set in CPF
IRISInsidePython=0
PythonInsideIRIS=0
RunningLibrary=
RunningVersion=Not Loaded
iris_site.py_platform=winamd64
```

`C:\InterSystems\IRISHealth\iris.cpf` (current):

```
PythonPath=
PythonRuntimeLibrary=
PythonRuntimeLibraryVersion=
```

`messages.log` (steady-state):

```
[Generic.Event] CPF settings (PythonRuntimeLibraryVersion) do not specify python correctly - Python can not be loaded
[Generic.Event] CPF settings (PythonRuntimeLibrary) do not specify python correctly - Python can not be loaded
```

Attempts to set CPF values at runtime via `##class(Config.config).Modify("PythonRuntimeLibrary", ...)` returned validation errors:

- `C:\Python313\python313.dll` → #404 "No version information found in file ... file may be corrupt"
- `C:\Python313\python3.dll` → same #404 (the stable-ABI stub DLL also has no version info)
- `PythonRuntimeLibraryVersion=3.13` → #5012 "File 'C:\InterSystems\IRISHealth\3.13' does not exist" (IRIS's validation interprets the value as a path relative to the install dir)

`PerProcessRuntimeLibraryStart("OSDefault")` and `PerProcessRuntimeLibraryStart("UserPerProcess")` both raise the same "Failed to Load Python" dispatch exception — the per-process overrides require libpython to be loadable in the first place.

Environment facts confirmed via filesystem:

- IRIS 2025.1 Build 230.2U (HealthShare) compiled against Python 3.13 (`pythonint313.pyd` ships in `C:\InterSystems\IRISHealth\bin`, also `pythonint39.pyd`, `pythonint310.pyd`, `pythonint311.pyd`, `pythonint312.pyd`).
- `C:\Python313\python313.dll` exists (6.1 MB, dated Aug 14 2025) but has no PE VERSIONINFO resource, which IRIS's CPF validation refuses.
- `C:\InterSystems\IRISHealth\mgr\python\` contains 234 installed Python packages (aiohttp, numpy, etc.) — indicating embedded Python was functional at some prior point on this host, but the CPF is currently blank.
- Perplexity research (InterSystems Community, docs): Python 3.13 is flagged as incompatible in at least one community post; IRIS 2024.2+ on Windows *requires* PythonRuntimeLibrary + PythonRuntimeLibraryVersion both to be set in CPF.
- `irispython.exe --version` → "Can't get python path from CPF" (confirms CPF is the blocker).

### Completion Notes List

**2026-04-17 — BLOCKED at Task 0: embedded Python unloadable on this host.**

Story 12.4 cannot be started without at least one of `quickjs` or `py_mini_racer` installed in the IRIS Python environment, which itself requires embedded Python to load. On this IRIS 2025.1 instance the CPF `PythonRuntimeLibrary` / `PythonRuntimeLibraryVersion` fields are blank, and every attempt to set them at runtime via `Config.config.Modify` or to bypass them via `%SYS.Python.PerProcessRuntimeLibraryStart("OSDefault"|"UserPerProcess")` failed. The available host-side Python (3.13 at `C:\Python313\`) lacks PE version info that IRIS's CPF validator demands, and Python 3.13 is flagged as problematic in at least one InterSystems Community post — so even with a CPF edit + service restart there is no guarantee the loader will accept it.

**Per the story's Scope management clause ("If Python + quickjs install fails on this IRIS instance, STOP and send a clarification to the lead ... Do NOT silently skip tests or mark the story done"), this is exactly the STOP condition.** No code, tests, docs, or config were written for Python.cls beyond the probe attempt. The pre-existing `IRISCouch.JSRuntime.Python` stub (from Story 12.1) remains unchanged and still returns 0 from `IsAvailable()` + throws `not_yet_implemented` from every `Execute*` method.

**What the lead needs to decide:**

1. Install a supported Python on this dev host (e.g., Python 3.12 at `C:\Program Files\Python312\` with "install for all users") AND edit the IRIS CPF to point at it AND restart the IRIS service. This is a disruptive operation that takes IRISCouch and every other namespace offline for ~30 seconds, and requires local admin on the Windows box.
2. Defer Story 12.4 to a host where embedded Python is already working (a Docker IRIS image has Python pre-configured by default), OR
3. Re-scope Story 12.4 to deliver only the documentation + class-docstring clarifications + Factory-contract comment (Tasks 3 partial and 7 partial), leaving the Python.cls stubs and test class for a later pass once a Python-enabled IRIS is available. This would be an ~8-line change to Factory.cls docstring + a ~30-line Python Backend section in `documentation/js-runtime.md` that documents the intended design *and* the "not yet deployable on Windows without Python 3.11/3.12 + CPF config" caveat.

**Recommendation:** option (3) plus tracking a new Epic 12 sub-story "12.4a: enable IRIS embedded Python on dev/CI hosts" as a prerequisite to resuming 12.4.

**Cleanup:** The temporary `IRISCouch.JSRuntime.PythonProbe.cls` used for the probe was deleted from both the repo (`src/IRISCouch/JSRuntime/PythonProbe.cls`) and the IRIS server. The `^ClineDebug` globals used for diagnostic capture in HSCUSTOM and %SYS were killed.

### File List

No files modified in this attempt — everything was reverted. The only delta is the sprint-status entry and this Dev Agent Record section of the story file, both updated to record the BLOCKED state.

- _Modified (metadata only)_: `_bmad-output/implementation-artifacts/sprint-status.yaml` (Story 12.4 annotation), `_bmad-output/implementation-artifacts/12-4-python-jsruntime-backend.md` (Status + Dev Agent Record).
