# JSRuntime Backends

IRISCouch executes the JavaScript-dependent parts of the CouchDB protocol
(map/reduce views, `validate_doc_update` hooks, custom filter functions,
show/list/update functions) through a pluggable "sandbox" abstraction. The
active backend is selected by a single configuration value.

## Selecting a backend

The backend is controlled by the `JSRUNTIME` configuration key. Valid
values:

| Value         | Status              | Story |
| ------------- | ------------------- | ----- |
| `None`        | Shipped default     | 12.1  |
| `Subprocess`  | Shipped (map/reduce) | 12.2  |
| `Python`      | Not yet implemented | 12.4  |

Read the current value:

```objectscript
Write ##class(IRISCouch.Config).Get("JSRUNTIME")
```

Override it at runtime:

```objectscript
Do ##class(IRISCouch.Config).Set("JSRUNTIME", "Subprocess")
```

The override is stored in `^IRISCouch.Config("JSRUNTIME")` and takes
precedence over the `Parameter JSRUNTIME = "None"` default defined on
`IRISCouch.Config`.

## What each backend does

### None (default)

- Design documents can be written, read, replicated, and deleted normally.
  The write path never invokes JavaScript.
- Any request that *would* execute JavaScript returns HTTP 501
  Not Implemented with a reason that names the blocked subsystem:
  - `GET /{db}/_design/{ddoc}/_view/{view}` — view execution
  - `GET|POST /{db}/_changes?filter={ddoc}/{name}` — custom filter functions
  - Future: show/list/update function endpoints
- `validate_doc_update` functions embedded in design docs are accepted on
  write but are **not** evaluated against subsequent document writes. This
  makes `None` a migration-friendly default: design docs can be staged
  before a runtime is installed.

### Subprocess (Stories 12.2 + 12.3 — shipped)

Executes JavaScript via an out-of-process `couchjs`-compatible sandbox.
Any of Node 18+, Bun 1+, Deno 1.40+, or a packaged `couchjs` binary will
work — each is driven through the same dispatcher-entry script, which
implements the CouchDB query-server line protocol on top of Node's
`vm.runInNewContext` (a documented replacement for SpiderMonkey's
`evalcx`).

**Enabling the Subprocess backend:**

```objectscript
Do ##class(IRISCouch.Config).Set("JSRUNTIME", "Subprocess")
Do ##class(IRISCouch.Config).Set("JSRUNTIMESUBPROCESSPATH", "C:\Program Files\nodejs\node.exe")
```

On Linux/macOS set `JSRUNTIMESUBPROCESSPATH` to a full path like
`/usr/bin/node` or `/usr/local/bin/bun`. If your interpreter is on
PATH under the IRIS service account, just the binary name works too —
but the full path avoids PATH-related surprises when the service runs
under a restricted user.

**Entry-point script.** The Subprocess backend invokes the interpreter
with `documentation/couchjs/couchjs-entry.js`. This ships with the
repository under the IRISCouch layout. Custom deployments can override
with `JSRUNTIMESUBPROCESSENTRY`.

**Execution model (Story 12.2).** A subprocess is spawned per view
query, issued the command stream over file-based stdin, and captured
from file-based stdout. The pipe file (`Pipe.cls`) uses `$ZF(-100)` with
`/STDIN`/`/STDOUT`/`/STDERR` redirection — the canonical IRIS pattern
per `irislib/%Net/Remote/Utility.cls::RunCommandViaZF`. This avoids
the well-known Windows IRIS fragility of real-time bidirectional stdio
via `$ZF(-1)`. Story 12.5 will add a persistent subprocess pool on
top of the same Pipe API; the pool is an additive change — no
changes to calling code.

**Supported CouchDB protocol commands:**

- `reset` — reset per-query state
- `add_fun` — compile a map or reduce function (Story 12.2)
- `map_doc` — run every registered map function against a document (Story 12.2)
- `reduce` — run one or more reduce functions over `[key, value]` pairs (Story 12.2)
- `rereduce` — rereduce intermediate results (Story 12.2)
- `ddoc` — register (`new`) and invoke design-doc-scoped functions:
  `validate_doc_update` and `filters.<name>` (Story 12.3)

**Out of scope for Stories 12.2 / 12.3:**

- `shows` / `lists` / `updates` / `rewrites` dispatchers — deferred until
  a consumer asks for them; most CouchDB deployments migrated off show/list
  once mango + client-side rendering matured.
- Incremental view indexing, ETag/304 caching, persistent pool — **Story 12.5**
- HyperLogLog for `_approx_count_distinct` — **Epic 14**

**Builtin reduce functions** (`_sum`, `_count`, `_stats`,
`_approx_count_distinct`) execute **natively in ObjectScript** (via
`IRISCouch.View.BuiltinReduce`), bypassing the subprocess entirely.
User-supplied reduce functions execute via the subprocess.

### Python (Story 12.4 — not yet implemented)

Executes JavaScript via the embedded Python interpreter using a Node.js-
compatible JS engine binding. Useful when deploying to hosts that cannot
run a separate subprocess.

## Validate Document Update (Story 12.3)

Write a CouchDB-style `validate_doc_update` function by storing its source in
a design doc:

```json
{
  "_id": "_design/only_admins",
  "validate_doc_update": "function(newDoc, oldDoc, userCtx, secObj) { if (userCtx.roles.indexOf('_admin') === -1) throw({forbidden: 'admins only'}); }"
}
```

**Semantics:**

- The function runs on every document write to the database (`PUT`, `POST`,
  `DELETE`, `_bulk_docs`, replication) **except** writes whose id is
  `_local/*` or `_design/*` (CouchDB compatibility — design-doc writes are
  validated structurally rather than through the user hook).
- To approve a write, return normally (or return `undefined`). The write
  proceeds through the remaining save pipeline.
- To reject a write, `throw` an object:
  - `throw({forbidden: "<reason>"})` → HTTP **403 Forbidden** with the
    CouchDB envelope `{"error":"forbidden","reason":"<reason>"}`
  - `throw({unauthorized: "<reason>"})` → HTTP **401 Unauthorized** with
    `{"error":"unauthorized","reason":"<reason>"}`
  - Any other throw → HTTP **500** with a generic reason; the full detail
    is written to the structured log, not the HTTP response (NFR-S8).
- Multiple design docs each defining a `validate_doc_update` are run
  **sequentially in subscript-id order**. The first rejection wins
  (fail-fast), and subsequent functions do not run. Matches CouchDB's
  `couch_db.erl::validate_doc_update_int`.
- **Replication is not exempt.** Replicated writes (via `new_edits=false`
  `_bulk_docs` or the native `_replicate` path) still run validate; this
  is a deliberate divergence from CouchDB's `{internal_repl, _} -> ok`
  short-circuit, chosen to prevent a hostile peer from bypassing validate
  rules by replicating.

**userCtx / secObj shape.** Story 12.3 hands the function a CouchDB-compatible
user context and security object:

- `userCtx = {"name": "<username>" | null, "roles": ["<role>", ...]}`
  - `name` is `null` for an anonymous request (admin-party default)
  - `roles` includes `"_admin"` for server admins (IRIS `%All` role or CouchDB
    `_admin` role)
- `secObj` is the per-database `_security` object with `admins` and
  `members` sub-objects. Empty arrays when no security has been configured.

**JSRUNTIME=None semantics.** Under the default `None` backend, writes
against a database that has a `validate_doc_update`-defining design doc
return HTTP **501 Not Implemented** with a reason pointing at this page
(Story 12.3 AC #4). Writes against databases with no validate hook continue
to pass normally — the backend is genuinely a no-op when nothing needs to run.

## Custom Filters (Story 12.3)

Author a filter function in `filters.<name>` of a design doc:

```json
{
  "_id": "_design/feed",
  "filters": {
    "publics": "function(doc, req) { return doc.public === true; }"
  }
}
```

Invoke it on the changes feed:

```
GET /{db}/_changes?filter=feed/publics
```

**Semantics:**

- The function is called **once per candidate change**. Truthy returns
  include the change in the response; falsy returns skip it. The final
  `last_seq` reflects the highest seq processed whether approved or skipped.
- `req` is shaped like CouchDB's `chttpd_changes` request: at minimum
  `method`, `path`, `query` (parsed query-string parameters), `headers`
  (trimmed to `User-Agent` + `Content-Type`), `userCtx`, and `info.db_name`.
- `filter=<ddoc>/<missing>` or `filter=<missing>/<name>` returns HTTP
  **404 Not Found**.
- Under JSRUNTIME=None, custom filters return HTTP **501** with a reason
  field pointing at this file (the built-in filters `_doc_ids`, `_selector`,
  and `_design` continue to work without any JS runtime).

**Performance note.** Story 12.3 spawns one subprocess per `_changes`
request (same process-per-query model as Story 12.2). For high-fan-out
feeds this is acceptable but not ideal — Story 12.5 adds a persistent
subprocess pool on top of the same protocol and will reuse interpreters
across requests. Batching multiple docs into one `ddoc` invocation is an
additive change that can follow pooling without touching caller code.

## The abstract Sandbox interface

All callers depend on the abstract class `IRISCouch.JSRuntime.Sandbox` and
never on any concrete subclass. The `IRISCouch.JSRuntime.Factory` resolves
the active backend and returns an instance of the correct subclass.

Abstract methods:

- `ExecuteMap(mapFn, doc)` → array of `[key, value]` pairs
- `ExecuteReduce(reduceFn, keys, values, rereduce)` → reduced value
- `ExecuteValidateDocUpdate(validateFn, newDoc, oldDoc, userCtx, secObj)` → `%Status`
- `ExecuteFilter(filterFn, doc, req)` → boolean

See `src/IRISCouch/JSRuntime/Sandbox.cls` for full method documentation and
the matching CouchDB line-protocol references in `sources/couchdb/share/server/`.

## Troubleshooting

**501 Not Implemented response.** The `reason` field identifies the blocked
subsystem. Typical remedies:

- Confirm the configured backend: `Config.Get("JSRUNTIME")`.
- If `Subprocess` is configured and still returns 501 for views, confirm
  `JSRUNTIMESUBPROCESSPATH` points at a real interpreter and
  `documentation/couchjs/couchjs-entry.js` is accessible to the IRIS
  service account. `Subprocess.IsAvailable()` short-circuits to 0 when
  either file is missing.
- If the response names `custom filter functions` or
  `validate_doc_update hooks` under `JSRUNTIME=None`, either flip the
  backend to `Subprocess` (Story 12.3 shipped) or remove the
  validate/filter function from the referenced design doc.

**Subprocess fails to launch.** The 500 response's log includes the
interpreter path, exit code, and first 512 bytes of stderr. Run the
interpreter manually with `--version` from the same shell IRIS spawns
from to verify PATH and permissions — Windows service accounts often
differ from interactive logins.

**Map function throws on a specific document.** Per CouchDB semantics,
per-document map errors are logged via `Util.Log.Warn` and the document
is skipped from the result set. The view query continues with the
remaining documents. See `IRISCouch.Util.Log` / `cconsole.log` for the
warn entry naming the failed doc id.

**Timeout after Nms.** `JSRUNTIMETIMEOUT` (default 5000 ms) caps the
per-query interpreter wall-clock. Long-running reduces should use a
builtin (`_sum`, `_count`, `_stats`) which bypasses the subprocess.
Story 12.5 enforces this cap two ways: (a) the couchjs entry script
sets a `setTimeout(..., JSRUNTIMETIMEOUT).unref()` that exits with code
124 if the event loop yields past the deadline; (b) the IRIS side
launches the subprocess via `$ZF(-100,"/ASYNC")` and polls via
`tasklist` (Windows) / `kill -0` (Unix), killing the child via
`taskkill /F` / `kill -9` on expiry. A tight synchronous JS loop
(e.g., `while(true){}`) that never yields is caught by (b); an async-
yielding runaway is caught by (a).

## Security Model (Story 12.5)

**Sandbox surface area.** Every subprocess JS call inherits the following
interpreter-specific flags applied by
`IRISCouch.JSRuntime.Subprocess.Pipe.BuildSandboxFlags`:

- **Node.js:** `--disable-proto=delete --no-experimental-global-webcrypto
  --no-warnings`. `--disable-proto` blocks `__proto__` re-assignment
  escapes. `--no-experimental-global-webcrypto` denies the subprocess
  WebCrypto APIs (user map/reduce functions have no legitimate need for
  them and they expose timing-side-channel surface). `--no-warnings`
  suppresses ExperimentalWarning noise that would otherwise pollute
  stderr.
- **Deno:** `run --allow-read --deny-net --deny-write --deny-run
  --deny-env --deny-ffi --deny-sys`. Read is required so Deno can load
  the entry script; every other capability is explicitly denied.
- **Bun:** no per-command sandbox flags documented as of 2026-04; rely
  on OS-level Job Object / `ulimit` backstops.
- **Other interpreters:** pass-through with no flags; a Warn is logged
  (`Unrecognised JSRUNTIME value` in the structured log) so operators
  notice the lack of sandbox.

**Path-traversal guard.** `Pipe.Open` rejects `JSRUNTIMESUBPROCESSPATH`
containing `..` or missing on disk. The entry script path is likewise
validated. Closes the Story 12.2 NFR-S9 MED.

**Timeout enforcement.** See the troubleshooting entry above. Two-layer:
JS-side `setTimeout` self-kill + IRIS-side `/ASYNC` polling with OS
kill. The OS kill is the authoritative timeout — a hostile
`while(true){}` that cannot be interrupted from JS is terminated at
`JSRUNTIMETIMEOUT` regardless. Write-path timeouts roll back the host
transaction so the index stays consistent.

**Memory pressure.** `JSRUNTIMEMAXRSSMB` (default 256 MB) is the target
RSS ceiling per pooled subprocess. In Story 12.5, enforcement is
conservative: the pool terminates an entry exceeding this on its next
health check. Windows-native Job Object enforcement (hard kill on
commit exceed) is deferred to Story 12.5a because it requires a signed
helper binary or a PowerShell script with P/Invoke; the current
release relies on the 256 MB soft-cap and the timeout backstop for
runaway memory allocators. See `deferred-work.md` for the Story 12.5a
entry.

**Known limitations.**

- Synchronous tight loops in JS cannot be interrupted from JS; the OS
  kill is required and runs on the IRIS polling cadence (100 ms).
- Node's `vm` module runs user code in a new `Context` but shares the
  Node process with the entry script; a sufficiently motivated attacker
  could escape via `Reflect`/`Proxy` tricks. We do not claim sandbox
  security beyond "defense-in-depth against honest-but-buggy code"
  until a full Deno-or-equivalent migration completes.
- View map and reduce functions run IN the same subprocess as
  `validate_doc_update` / `filter` callbacks. They are logically
  isolated via fresh `vm.Context` objects per invocation but share the
  Node heap. No evidence this has been exploited in the wild, but
  operators concerned about cross-hook interference should use a
  separate Subprocess backend instance per workload.

## Pool (Story 12.5)

**Why pool?** Story 12.2's process-per-call model pays ~137 ms of
cold-start per subprocess launch. Incremental indexing (Story 12.5
Task 2) removes that cost from the query path by populating the index
at write time. The pool amortises cold-start across the remaining
call paths (validate, filter).

**Current implementation.** `IRISCouch.JSRuntime.Subprocess.Pool` keeps
the API surface (`Acquire` / `Release`) stable but in Story 12.5 does
NOT maintain long-lived OS subprocesses because `$ZF(-100)` is
synchronous-per-command. Each `Acquire` allocates a fresh Pipe
instance; real long-lived subprocesses are tracked as Story 12.5b
follow-up and depend on a true `$ZF(-100,"/ASYNC")` bidirectional
stdio pattern.

**Config knobs.**

- `JSRUNTIMEPOOLMAX` (default 4): max concurrent subprocesses. In 12.5
  the knob is informational; Story 12.5b will enforce.
- `JSRUNTIMEPOOLIDLEMS` (default 60000): idle-reap threshold.
- `JSRUNTIMEMAXRSSMB` (default 256): RSS ceiling per subprocess.

**Protocol reference.** The CouchDB query-server line protocol is
documented in `sources/couchdb/share/server/loop.js` (dispatcher) and
`sources/couchdb/share/server/views.js` (map/reduce semantics). The
IRISCouch entry script matches this behaviour on Node/Bun/Deno.

**Unexpected backend.** The factory falls back to `None` and logs a
warning to the structured log if `JSRUNTIME` holds an unrecognised value.
Grep the IRIS console log for `Unrecognised JSRUNTIME value` to find
typos.
