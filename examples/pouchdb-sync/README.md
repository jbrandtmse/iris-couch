# pouchdb-sync

> **Production warning.** This example uses the default IRIS `_system` / `SYS`
> credentials and embeds them in the remote PouchDB URL. **Before running
> IRISCouch in production**, rotate the IRIS admin password, create a
> dedicated IRISCouch user via `/_users/` (Story 7.3), assign a non-admin
> role (Story 7.4), and prefer cookie / JWT auth over basic-in-URL for any
> browser client. See the [getting-started](../../documentation/getting-started.md)
> auth section.

Bidirectional sync between a local PouchDB instance and a remote IRISCouch
database. This is the canonical integration shape for offline-first web apps:
PouchDB drives the app's data model; the remote IRISCouch handles durable
storage and server-side replication targets.

## What it demonstrates

- Constructing a PouchDB remote handle against IRISCouch
- `PouchDB#sync()` — the one-call push-and-pull convenience wrapper
- Observable convergence: 5 local docs push up, then a direct `PUT` on
  IRISCouch pulls back down, confirming bidirectional replication
- `_bulk_docs`, `_revs_diff`, `_local/{id}` checkpoint, and `_changes` are
  all exercised automatically by `sync()` without you touching them

## Prerequisites

### Node + pouchdb

- **Node.js 18+**. Node 18 introduced built-in `fetch`, which this example
  uses for the direct-PUT step. (`run.mjs` is an ES module.)
- **pouchdb** package. Install locally inside this directory:

  ```bash
  cd examples/pouchdb-sync
  npm install pouchdb
  ```

  The package will land in `./node_modules/`. This example's `package.json`
  (if present) is for convenience only — adopters copy-pasting the pattern
  into their own app should add `pouchdb` to their own `package.json`.

### IRISCouch

- IRIS 2024.1+ with IRISCouch installed at `http://localhost:52773/iris-couch/`
- Default IRIS credentials (or override via env vars below)

## How to run

```bash
cd examples/pouchdb-sync
node run.mjs
```

**Override the URL or credentials:**

```bash
IRISCOUCH_URL=http://example.com:52773/iris-couch \
IRISCOUCH_USER=myuser \
IRISCOUCH_PASS=mypass \
node run.mjs
```

## Expected output

See [`expected-output.txt`](expected-output.txt). No rev-hash tolerance is
needed — PouchDB's sync internals don't emit rev strings in the summary,
and the `_all_docs` row ids are the deterministic ones we seeded. The
`push_docs_written` / `pull_docs_written` counts are stable across runs.

## Known IRISCouch interop note

IRISCouch's current Router UrlMap does not match the trailing-slash variant
of database URLs: `PUT /{db}/` and `GET /{db}/` both return 404, whereas
`PUT /{db}` (no trailing slash) succeeds. PouchDB, when you construct a
remote `new PouchDB(url)`, probes the database by issuing
`PUT /{db}/` (with a trailing slash) and treats a non-success response as
"database does not exist, and I can't create it" — which is how this example
initially failed.

**Workaround used in `run.mjs`:** pass `{ skip_setup: true }` to the PouchDB
constructor. This tells PouchDB to skip the probe and assume the database
already exists — which is true because we created it explicitly with a
direct `PUT /{db}` (no trailing slash) beforehand. This is a standard
PouchDB option and not specific to IRISCouch; it is also the recommended
pattern for production use even against Apache CouchDB, because it avoids
a superfluous round-trip on every handle construction.

**Tracked as:** `deferred-work.md` → **[HIGH] Story 13.3** IRISCouch
returns 404 for `PUT /{db}/` and `GET /{db}/` (trailing-slash variants of
the database-level endpoints). The fix is a one-line addition of two
`/:db/` routes to the Router UrlMap, delegating to the same handlers as
`/:db`. Deferred to a backend cleanup story; the workaround for adopters
today is `skip_setup: true`.

## Cross-references

- PouchDB remote options: [PouchDB API § constructor](https://pouchdb.com/api.html#create_database)
- CouchDB replication protocol: `sources/couchdb/src/docs/src/replication/protocol.rst`
- Compatibility matrix: `_bulk_docs`, `_changes`, `_revs_diff`, `_local/{id}`
  are all marked `supported` — the full protocol round-trip works, only the
  trailing-slash probe does not.

## Troubleshooting

- **`ERR missing 404`** — you hit the trailing-slash bug above without the
  `skip_setup: true` workaround. Check you copied the full `run.mjs`.
- **`Cannot find package 'pouchdb'`** — run `npm install pouchdb` in this
  directory, or set `NODE_PATH` to point at a global install.
- **`ECONNREFUSED`** — IRIS is not running, or is on a non-default port.
  Set `IRISCOUCH_URL`.
- **Replication hangs forever** — usually a CORS / auth issue. This example
  is Node-only, so CORS shouldn't matter; check `IRISCOUCH_USER` /
  `IRISCOUCH_PASS`. See [troubleshooting runbook](../../documentation/troubleshooting.md).
