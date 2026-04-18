# jsruntime-subprocess-node

> **Production warning.** This example uses the default IRIS `_system` / `SYS`
> credentials. **Before running IRISCouch in production**, rotate the IRIS
> admin password, create a dedicated IRISCouch user via `/_users/` (Story 7.3),
> and assign a non-admin role (Story 7.4). Separately, the `JSRUNTIME=Subprocess`
> backend executes user-supplied JavaScript in a sandboxed Node process — the
> sandbox flags are strict by default, but any tightening of trust boundaries
> for views should be reviewed against `documentation/js-runtime.md` §
> Security Model before production deployment.

The most-prerequisite-dense example in this tree: exercises IRISCouch's
**Subprocess JSRuntime** backend (Story 12.2 + 12.5) by posting a design
document with a JavaScript `map` function and issuing a view query. The
subprocess path uses the vendored `documentation/couchjs/couchjs-entry.js`
driver verbatim — this example does NOT fork or re-implement the couchjs
protocol; its contribution is the orchestration around it.

## What it demonstrates

- `IRISCouch.Config("JSRUNTIME")="Subprocess"` is actually wired up and
  returns results (not a `501 not_implemented` envelope)
- `PUT /{db}/_design/{ddoc}` with a `views.<name>.map` function body
- `GET /{db}/_design/{ddoc}/_view/{view}?reduce=false` — map-only query;
  IRIS spawns Node, pipes `map_doc` commands over stdin, collects emitted
  rows
- `GET /{db}/_design/{ddoc}/_view/{view}` — default reduce path (ungrouped);
  uses the built-in `_count` reduce which runs in native ObjectScript
  (no subprocess spawn on the reduce side)

## Prerequisites — longer list than other examples

### 1. Node.js 18+

Verify `node --version` reports 18.x or higher. Bun 1+ and Deno 1.40+ also
work; update `JSRUNTIMESUBPROCESSPATH` to point at the chosen interpreter.

### 2. IRISCouch configured for Subprocess

In the IRIS terminal, in the namespace where IRISCouch is installed
(typically `IRISCOUCH`):

```objectscript
Do ##class(IRISCouch.Config).Set("JSRUNTIME", "Subprocess")
Do ##class(IRISCouch.Config).Set("JSRUNTIMESUBPROCESSPATH", "C:\Program Files\nodejs\node.exe")
```

On macOS / Linux the path is typically `/usr/bin/node` or
`/usr/local/bin/node`. The `probe` step of this example will detect the
None-default state and print the configuration commands if needed.

### 3. Entry script present

This example expects `documentation/couchjs/couchjs-entry.js` to exist at
`../../documentation/couchjs/couchjs-entry.js` relative to the example
directory. Story 12.2 shipped that file; confirm with `ls ../../documentation/couchjs/`.

### 4. IRISCouch server

IRIS 2024.1+ with IRISCouch installed at `http://localhost:52773/iris-couch/`.

## How to run

```bash
bash run.sh
# or
.\run.ps1
```

If the probe detects `JSRUNTIME=None`, the script exits with status 2
(conditional skip) and prints the exact `IRISCouch.Config.Set` commands you
need. The `run-all` harness treats this as an environmental skip, not a
failure.

## Expected output

See [`expected-output.txt`](expected-output.txt). Tolerance placeholders:

- `<path>` — absolute path to `documentation/couchjs/couchjs-entry.js`;
  varies per checkout location

The deterministic parts: 5 rows for the map query (one per seeded doc) with
key `"even"` or `"odd"`, and `{"key":null,"value":5}` for the reduce output.

## View-query parameter coverage

Per the compatibility matrix: under `JSRUNTIME=Subprocess`, `reduce` and
`include_docs` are fully supported; `group`, `group_level`, `startkey`,
`endkey`, `limit`, `skip`, `descending`, `inclusive_end`, `startkey_docid`,
`endkey_docid`, `key`, and `keys` are **silently ignored** per the Story
12.2a scope cut. This example deliberately uses only supported params.
Adopters needing the deferred params should pull them client-side for now
and re-check the matrix once Story 12.2a lands.

## Three documented Subprocess deviations from CouchDB

Per [compatibility matrix § JSRuntime state rows](../../documentation/compatibility-matrix.md#designdesigndocsname_viewview-per-jsruntime-backend):

1. **Mixed-type key collation** — IRISCouch sorts by JSON lexicographic
   string compare; CouchDB uses typed collation (`couch_ejson_compare`).
   For mixed-type keys the two orderings can differ.
2. **`_approx_count_distinct`** — exact distinct count in IRISCouch; HLL
   estimate in CouchDB. Byte-identical at small cardinality.
3. **Per-query subprocess spawn** — ~130 ms cold-start on Windows. Story
   12.5 incremental indexing removes this from the hot path for writes;
   first query after a design-doc change still pays it.

## Cross-references

- [`documentation/js-runtime.md`](../../documentation/js-runtime.md) — full
  backend semantics, sandbox flags, timeout enforcement, pool API
- [Getting Started § JavaScript Runtime Requirements](../../documentation/getting-started.md#javascript-runtime-requirements)
- [Troubleshooting § JS sandbox errors](../../documentation/troubleshooting.md)
- [`documentation/couchjs/README.md`](../../documentation/couchjs/README.md)
  — entry-script protocol details
- Story [12.2 Subprocess JSRuntime](../../_bmad-output/implementation-artifacts/12-2-subprocess-jsruntime-map-reduce-views.md)
  and [12.5 Incremental indexing + sandbox safety](../../_bmad-output/implementation-artifacts/12-5-incremental-view-indexing-caching-and-sandbox-safety.md)

## Troubleshooting

- **`[SKIPPED]` with `FAIL: JSRUNTIME is set to None`** — the probe detected
  the default backend. Run the `IRISCouch.Config.Set` commands above.
- **`subprocess_error` in view response** — the Node process spawned but
  exited non-zero. Check `^IRISCouch.Log` for the `jsruntime` structured
  log entry — it names the interpreter, the stderr tail, and the exit code.
- **Timeout after Nms** — `JSRUNTIMETIMEOUT` (default 5000 ms) expired. A
  map function that runs longer than that will be killed. Usually indicates
  an infinite loop or an unterminated async await. Simplify the map; views
  should be pure functions with no I/O.
- **Interpreter path wrong** — the Subprocess backend logs the probe error
  to `^IRISCouch.Log`. On Windows, note that IRIS spawns from the service
  account, not your interactive shell; `where node` in cmd gives you the
  path your user sees, but IRIS may need a different absolute path.
