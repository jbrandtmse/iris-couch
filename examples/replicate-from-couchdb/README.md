# replicate-from-couchdb

> **Production warning.** This example uses the default IRIS `_system` / `SYS`
> credentials AND a default `admin` / `couchdb` user on the Apache CouchDB
> source. **Before running this pattern in production**, use dedicated,
> short-lived replication credentials on both sides; embed them in the
> `/_replicate` source URL rather than in the target database ACLs; and
> rotate after every migration milestone. See Stories 7.3 and 7.4.

Pulls a database from a running Apache CouchDB 3.x instance into IRISCouch
using the built-in `/_replicate` endpoint. This is the concrete, runnable
realisation of **Phase 3 ("Replicate-in") of the
[Migration Playbook](../../documentation/migration.md)** — if you are
retiring a production CouchDB deployment onto IRISCouch, this example is the
template for your cutover script.

## What it demonstrates

- Pointing IRISCouch's `/_replicate` at a remote CouchDB source
- One-shot (non-continuous) replication — synchronous from the caller's
  perspective; the POST returns only after replication completes
- `doc_count` parity check as the migration completion criterion
- Credential handling: basic-auth embedded in the source URL (the CouchDB
  `_replicate` spec requires this — CouchDB does not forward arbitrary
  headers to replicator workers)

## Prerequisites

### Apache CouchDB 3.x (the source)

- A running CouchDB 3.x instance at `$COUCHDB_URL` (default
  `http://localhost:5984`) with admin credentials
- The quickest way to satisfy this locally is Docker:

  ```bash
  docker run --rm -d -p 5984:5984 \
    -e COUCHDB_USER=admin -e COUCHDB_PASSWORD=couchdb \
    --name couchdb-for-examples couchdb:3.3
  ```

  The script creates the source database inside this CouchDB (`replicate-source`),
  seeds five docs, replicates, then drops both the source and target.

- If your CouchDB is elsewhere, override with env vars:

  ```bash
  COUCHDB_URL=http://your-couch-host:5984 \
  COUCHDB_USER=youruser \
  COUCHDB_PASS=yourpass \
    bash run.sh
  ```

- If no CouchDB is reachable, the script prints a clear guidance message
  naming the `COUCHDB_URL` env var and exits with status **2** — which the
  `run-all` harness treats as a conditional skip (not a failure). You can
  see the full happy-path expected output in [`expected-output.txt`](expected-output.txt)
  regardless.

### IRISCouch (the target)

- IRIS 2024.1+ with IRISCouch installed at `http://localhost:52773/iris-couch/`
- Default IRIS credentials (or override via `IRISCOUCH_USER` / `IRISCOUCH_PASS`)

## How to run

```bash
bash run.sh
# or
.\run.ps1
```

## Expected output

See [`expected-output.txt`](expected-output.txt). Tolerance placeholders:

- `<history>` — the `history` array in the `_replicate` response includes a
  session record with timestamps; the diff harness tolerates the full array.
- `<n>` — `replication_id_version` is currently `4`; listed as `<n>` so
  future protocol version bumps don't break the diff.
- `<uuid>` — `session_id` is a fresh v4 UUID per run.
- `<seq>` — `source_last_seq` is the CouchDB-side update_seq at completion
  (`5-...` for a five-doc source).
- `1-<hash>` — rev hash on the replicated document body.

## Cross-references

- [Migration Playbook § Phase 3: Replicate-in](../../documentation/migration.md)
  — the operational context this example scripts
- Compatibility matrix: `/_replicate` is marked `supported` with full
  bidirectional parity tested against CouchDB 3.3.3 in Epic 8
- Epic 8 Story [8.4 Bidirectional Replication Protocol](../../_bmad-output/implementation-artifacts/8-4-bidirectional-replication-protocol.md)
  — the full-round-trip test harness, including wire-shape assertions

## Troubleshooting

- **`[SKIPPED]` message** — no CouchDB at `$COUCHDB_URL`. See the Docker
  command above or set the env var. Not a failure.
- **`doc_count mismatch`** — a doc failed to replicate. Check
  `/_active_tasks` during the run to see if the replicator reported errors;
  check IRIS's `^IRISCouch.Log` global for subprocess crashes.
- **`401 Unauthorized`** on CouchDB side — CouchDB admin credentials don't
  match `$COUCHDB_USER` / `$COUCHDB_PASS`.
- **`401 Unauthorized`** on IRISCouch side — IRIS credentials wrong; override
  with env vars.
- **Replication hangs** — IRISCouch expects the source URL to be reachable
  from the IRIS process (not your client). If IRIS is in a container or on
  a different host, confirm it can `curl $COUCHDB_URL` directly.
- **Anything else** — the [troubleshooting runbook](../../documentation/troubleshooting.md)
  covers replication-lag and checkpoint-corruption patterns specifically.
