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

## PouchDB `skip_setup: true` — now a best-practice, not a workaround

Story 13.4 (2026-04-18) closed the trailing-slash routing bug:
`IRISCouch.API.Router.OnPreDispatch` now strips a single trailing slash
from non-root URLs before the UrlMap matches, so `PUT /{db}/`,
`GET /{db}/`, and `PUT /{db}/{docid}/` all route identically to their
no-slash counterparts. PouchDB's default-constructor probe (`PUT /{db}/`)
therefore succeeds without any workaround against α/β-releases or newer.

We keep `{ skip_setup: true }` in `run.mjs` anyway because it is a
standard PouchDB production best-practice — it saves a superfluous
round-trip on every remote-handle construction, regardless of server.
Apache CouchDB's documentation recommends the same pattern. Drop the flag
only if you explicitly want PouchDB's auto-create behaviour.

**Historical note:** the trailing-slash bug was tracked as
`deferred-work.md` → [HIGH] Story 13.3 and RESOLVED in Story 13.4
(2026-04-18). Adopters on pre-α snapshots that hit `ERR missing 404` from
PouchDB's probe should upgrade to a build that includes Story 13.4.

## Cross-references

- PouchDB remote options: [PouchDB API § constructor](https://pouchdb.com/api.html#create_database)
- CouchDB replication protocol: `sources/couchdb/src/docs/src/replication/protocol.rst`
- Compatibility matrix: `_bulk_docs`, `_changes`, `_revs_diff`, `_local/{id}`
  are all marked `supported` — the full protocol round-trip works, only the
  trailing-slash probe does not.

## Troubleshooting

- **`ERR missing 404`** — you're on a pre-Story-13.4 snapshot that still
  has the trailing-slash bug. Upgrade to α/β or keep `{ skip_setup: true }`
  in the PouchDB constructor.
- **`Cannot find package 'pouchdb'`** — run `npm install pouchdb` in this
  directory, or set `NODE_PATH` to point at a global install.
- **`ECONNREFUSED`** — IRIS is not running, or is on a non-default port.
  Set `IRISCOUCH_URL`.
- **Replication hangs forever** — usually a CORS / auth issue. This example
  is Node-only, so CORS shouldn't matter; check `IRISCOUCH_USER` /
  `IRISCOUCH_PASS`. See [troubleshooting runbook](../../documentation/troubleshooting.md).
