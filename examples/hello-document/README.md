# hello-document

> **Production warning.** This example uses the default IRIS `_system` / `SYS`
> credentials because that is the out-of-the-box state documented in
> [Getting Started](../../documentation/getting-started.md). **Before running
> IRISCouch in production**, rotate the IRIS admin password, create a dedicated
> IRISCouch user via the `/_users/` database (Story 7.3), and assign a
> non-admin role (Story 7.4). Shipping a public-facing IRIS with the default
> credentials is a silent-compromise class of incident.

The minimum viable CouchDB roundtrip: create a database, put one document,
update it, delete it, confirm the delete took, drop the database. If
`hello-document` does not run cleanly against your IRISCouch, nothing else
in this `examples/` tree will either — start your troubleshooting here.

## What it demonstrates

- `PUT /{db}` — create a database (returns `{"ok":true}`)
- `PUT /{db}/{docid}` — create a document, server generates `_rev`
- `GET /{db}/{docid}` — read back the stored document
- `PUT /{db}/{docid}?rev=<prev>` — update with MVCC optimistic-concurrency check
- `DELETE /{db}/{docid}?rev=<prev>` — soft-delete (tombstone)
- `GET /{db}/{docid}` on a deleted doc — confirms `404 Not Found`
- `DELETE /{db}` — drop the database

The whole thing runs in under a second against a local IRISCouch.

## Prerequisites

- IRIS 2024.1+ with IRISCouch installed at `http://localhost:52773/iris-couch/`
  ([Getting Started § Install](../../documentation/getting-started.md#install))
- `curl` on PATH (default on macOS/Linux; use `winget install curl` on Windows
  or run `run.ps1` instead)
- Default IRIS credentials `_system` / `SYS` (or override via env vars below)

## How to run

**bash / zsh (macOS / Linux / Git Bash):**

```bash
bash run.sh
```

**PowerShell (Windows):**

```powershell
.\run.ps1
```

**Override the URL or credentials:**

```bash
IRISCOUCH_URL=http://example.com:52773/iris-couch \
IRISCOUCH_USER=myuser \
IRISCOUCH_PASS=mypass \
bash run.sh
```

## Expected output

See [`expected-output.txt`](expected-output.txt). Rev hashes (`1-<hash>`,
`2-<hash>`, `3-<hash>`) vary per run — the example-runner diff tolerates those
placeholders. The deterministic parts are the HTTP method/path labels, the
`{"ok":true}` envelopes, the `id:"greeting"` field, and the `HTTP 404` line
on Step 6.

## Troubleshooting

- **`Connection refused` / `curl: (7)`** — IRIS is not running. Start it.
- **`401 Unauthorized`** — credentials wrong. Use `IRISCOUCH_USER` /
  `IRISCOUCH_PASS` env vars or edit `run.sh` / `run.ps1` at the top.
- **`404 Not Found` on Step 1** — IRISCouch is not installed at the expected
  path. See [Getting Started](../../documentation/getting-started.md).
- **`409 Conflict` on Step 4** — a previous failed run left the DB behind. The
  script pre-cleans; if you still see this, manually `curl -u _system:SYS -X
  DELETE http://localhost:52773/iris-couch/hello-document-example` and retry.
- **Anything else** — the [troubleshooting runbook](../../documentation/troubleshooting.md)
  has the full list of known incident classes.
