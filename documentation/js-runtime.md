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

### Subprocess (Story 12.2 — shipped)

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

**Supported CouchDB protocol commands (Story 12.2):**

- `reset` — reset per-query state
- `add_fun` — compile a map or reduce function
- `map_doc` — run every registered map function against a document
- `reduce` — run one or more reduce functions over `[key, value]` pairs
- `rereduce` — rereduce intermediate results

**Out of scope for Story 12.2:**

- `validate_doc_update` and custom changes filters — **Story 12.3**
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
  `validate_doc_update hooks`, those subsystems land in Story 12.3 and
  stay 501 today even under `JSRUNTIME=Subprocess`.

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

**Protocol reference.** The CouchDB query-server line protocol is
documented in `sources/couchdb/share/server/loop.js` (dispatcher) and
`sources/couchdb/share/server/views.js` (map/reduce semantics). The
IRISCouch entry script matches this behaviour on Node/Bun/Deno.

**Unexpected backend.** The factory falls back to `None` and logs a
warning to the structured log if `JSRUNTIME` holds an unrecognised value.
Grep the IRIS console log for `Unrecognised JSRUNTIME value` to find
typos.
