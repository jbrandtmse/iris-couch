# mango-query

> **Production warning.** This example uses the default IRIS `_system` / `SYS`
> credentials. **Before running IRISCouch in production**, rotate the IRIS
> admin password, create a dedicated IRISCouch user via `/_users/`, and assign
> a non-admin role. See Stories 7.3 / 7.4 and the
> [Getting Started guide](../../documentation/getting-started.md#create-a-database).

Demonstrates IRISCouch's Mango query engine — CouchDB's declarative
selector-based query language — running entirely over native ObjectScript
and the synchronously-maintained IRIS SQL projection. No JavaScript runtime
required; Mango is index-and-scan over globals, not a view.

## What it demonstrates

- `POST /{db}/_index` — declare a compound index on `(status, created_at)`
- `POST /{db}/_find` — run a selector that combines `$eq` and `$gt` under `$and`
- `_find`'s `execution_stats` payload — `total_keys_examined`,
  `total_docs_examined`, `results_returned`, `execution_time_ms`
- `POST /{db}/_explain` — planner output showing the index was picked (its
  `analysis.ranking` > the `_all_docs` special index; `reasons:[]` means no
  disqualifying factors)

The selector returns the subset of `active` documents created after
2026-01-01 — 5 of the 10 seeded docs, deterministically, because IDs are
`doc-001` through `doc-010` with known status/timestamp values.

## Prerequisites

- IRIS 2024.1+ with IRISCouch installed at `http://localhost:52773/iris-couch/`
- `curl` on PATH (or run `run.ps1`)
- Default IRIS credentials (or override via `IRISCOUCH_USER` / `IRISCOUCH_PASS`)

## How to run

**bash:**

```bash
bash run.sh
```

**PowerShell:**

```powershell
.\run.ps1
```

## Expected output

See [`expected-output.txt`](expected-output.txt). Tolerances:

- `_design/<hash>` — Mango indexes are addressed by a deterministic digest
  over the fields list; the digest is stable run-to-run, but the fixture
  uses `<hash>` to avoid over-asserting on an implementation detail.
- `execution_time_ms:<ms>` — varies per run; the harness ignores this value.

## Cross-references

- [Epic 6 Mango story set](../../_bmad-output/implementation-artifacts/6-2-mango-query-execution-selectors-and-query-plan.md)
  — the feature-level design notes
- [Compatibility matrix `_find` / `_index` / `_explain` rows](../../documentation/compatibility-matrix.md#database-level-endpoints)
- CouchDB source `sources/couchdb/src/docs/src/api/database/find.rst`

## Troubleshooting

- **`400 Bad Request` from `_find`** — selector JSON malformed. `curl -v` to
  see the full request body.
- **`execution_stats:{...}` missing** — add `"execution_stats":true` at the
  top level of the `_find` body; off by default.
- **Planner picks `_all_docs` instead of your index** — see the `reasons[]`
  array in the explain output for the disqualifying factor (common: field
  order in the index does not match the selector).
- **`$regex` / `$text` selectors fail** — `$text` requires a Lucene-backed
  index (not implemented in α/β, see the compatibility matrix). `$regex`
  works against declared indexes when the regex is anchored.
