# IRISCouch — Working Examples

Six runnable integration examples that demonstrate IRISCouch's core
capabilities against a live IRISCouch instance. Each example is
self-contained: a prerequisite list, a runnable script, an expected-output
fixture, and a README describing what it does and why. Run any one
individually or use the `run-all.sh` / `run-all.ps1` harness to run them
all back-to-back.

## The six examples

| Directory | What it demonstrates | Runtime |
|-----------|---------------------|---------|
| [`hello-document/`](hello-document/README.md) | Single-doc CRUD roundtrip: `PUT /{db}`, `PUT /{db}/{id}`, `GET`, update, `DELETE`, confirm 404 | `curl` |
| [`pouchdb-sync/`](pouchdb-sync/README.md) | Bidirectional PouchDB ↔ IRISCouch sync with observable convergence | Node 18+ + `npm install pouchdb` |
| [`replicate-from-couchdb/`](replicate-from-couchdb/README.md) | Pull a database from Apache CouchDB via `/_replicate` (matches [Migration Playbook Phase 3](../documentation/migration.md)) | `curl` + a reachable CouchDB 3.x |
| [`mango-query/`](mango-query/README.md) | Declarative `_index` / `_find` / `_explain` with `$eq` + `$gt` under `$and` | `curl` |
| [`attachment-upload/`](attachment-upload/README.md) | Binary attachment upload + download with SHA-256 round-trip check | Node 18+ (built-in `fetch` / `crypto`) |
| [`jsruntime-subprocess-node/`](jsruntime-subprocess-node/README.md) | JS map function executed by the Subprocess JSRuntime backend | Node 18+ and `JSRUNTIME=Subprocess` configured |

## Prerequisites

- **IRIS 2024.1+** with IRISCouch installed at `http://localhost:52773/iris-couch/`.
  See the [Getting Started guide](../documentation/getting-started.md) if you
  don't have that yet.
- **`curl`** on PATH (for curl-based examples; substitute `run.ps1` on Windows
  if you prefer PowerShell)
- **Node.js 18+** for the three Node examples
- **`npm install pouchdb`** inside `pouchdb-sync/` (only that one example
  needs the `pouchdb` npm package)
- **Apache CouchDB 3.x** reachable for `replicate-from-couchdb` (or accept
  the environmental skip)
- **`JSRUNTIME=Subprocess`** configured for `jsruntime-subprocess-node` (or
  accept the environmental skip)

The two environmental-prerequisite examples (`replicate-from-couchdb` and
`jsruntime-subprocess-node`) emit a `[SKIPPED]` message with setup
instructions if the prerequisite is missing and exit with status 2, which
the `run-all` harness treats as a pass-with-caveat.

## How to run

### One example

```bash
cd examples/hello-document
bash run.sh
# or on Windows:
.\run.ps1
```

Each example's README has the exact command and any environment-variable
overrides (URL, credentials, remote source for replicate-from-couchdb, etc.).

### All six at once

```bash
cd examples
bash run-all.sh
# or:
.\run-all.ps1

# Run a subset:
bash run-all.sh --filter hello       # just the hello-document example
bash run-all.sh --filter attach      # just attachment-upload
bash run-all.sh --quiet              # hide per-example stdout; keep summary
```

The harness captures each example's stdout/stderr into `_logs/<name>.log`
and prints a summary line for each run. Exit status is 0 if every
non-skipped example passed.

## CI / release-gate enforcement

Per [epics.md Story 13.3 AC #4](../_bmad-output/planning-artifacts/epics.md),
the `run-all` harness is the enforcement mechanism for the release-gate
commitment: "a broken example blocks the release." The
harness ships here today; **the GitHub Actions wiring is deferred** to an
infrastructure story before the α/β tagging gate (see
[`_bmad-output/implementation-artifacts/deferred-work.md`](../_bmad-output/implementation-artifacts/deferred-work.md)
§ Story 13.3). Until that infrastructure lands, the release gate is
dev-host-local — the author manually runs `run-all.sh` before tagging.

## Authentication — do not ship with defaults

Every example README repeats this warning; it's important enough to also
say once up front: **the examples use the default IRIS `_system` / `SYS`
credentials**, which is the out-of-the-box state documented in the Getting
Started guide. Before running IRISCouch in any production-adjacent
environment:

1. Rotate the IRIS admin password.
2. Create a dedicated IRISCouch user via the `/_users/` database (Story 7.3).
3. Assign the user a non-admin role (Story 7.4).
4. Override the examples' credentials via `IRISCOUCH_USER` and
   `IRISCOUCH_PASS` environment variables when running locally.

## Rev-hash and UUID tolerance in expected-output fixtures

CouchDB rev hashes are deterministic across identical bodies, but the
in-memory state across runs is not — a second run against a fresh database
will produce the same `1-<hash>` value as the first, but cross-checkout
comparisons and any UUID-generating endpoints (`/_uuids`, `POST /{db}` with
auto-generated ID) will differ. The `expected-output.txt` fixtures use
placeholders like `1-<hash>`, `<uuid>`, and `<seq>` that a regex-aware diff
can tolerate. See Epic 8's replicator-roundtrip tests for the full pattern.

## Cross-references

- [Getting Started guide](../documentation/getting-started.md) — install,
  topology options, first database, PouchDB snippet, JSRuntime setup
- [Compatibility Matrix](../documentation/compatibility-matrix.md) — per-endpoint
  `supported` / caveat / `501` / out-of-scope status
- [Migration Playbook](../documentation/migration.md) — eight-phase
  playbook for retiring a production Apache CouchDB onto IRISCouch
- [Troubleshooting Runbook](../documentation/troubleshooting.md) — five
  canonical incident classes with diagnostic / resolution / prevention
- [Deviations Log](../documentation/deviations.md) — every operator-observable
  difference between IRISCouch and CouchDB 3.x
