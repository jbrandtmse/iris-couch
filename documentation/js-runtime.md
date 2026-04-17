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
| `Subprocess`  | Not yet implemented | 12.2  |
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

### Subprocess (Story 12.2 — in progress)

Executes JavaScript via an out-of-process `couchjs`-compatible sandbox
using the Mozilla SpiderMonkey interpreter. Configured by
`JSRUNTIMESUBPROCESSPATH` (path to the executable) and
`JSRUNTIMETIMEOUT` (per-call wall-clock limit).

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
- If `Subprocess` is configured and still returns 501, Story 12.2 has not
  yet landed; fall back to `None` until it ships.
- If the response names `custom filter functions` but you expected a
  built-in filter, verify the `filter` query parameter is one of
  `_doc_ids`, `_selector`, or `_design`. Anything else of the shape
  `ddoc/name` is treated as a custom JS filter.

**Unexpected backend.** The factory falls back to `None` and logs a
warning to the structured log if `JSRUNTIME` holds an unrecognised value.
Grep the IRIS console log for `Unrecognised JSRUNTIME value` to find
typos.
