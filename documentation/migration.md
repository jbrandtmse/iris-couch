# Migration Playbook — Apache CouchDB 3.x → IRISCouch

**Last updated:** 2026-04-18 (Story 13.2)
**IRISCouch version:** 0.1.0 (α development, pre-release)
**Audience:** adopters retiring a production Apache CouchDB instance
in favor of IRISCouch.
**Companion docs:** [Getting Started](getting-started.md),
[Compatibility Matrix](compatibility-matrix.md),
[Deviations](deviations.md),
[Troubleshooting Runbook](troubleshooting.md).

---

## Shape of the plan

The playbook below is **eight phases** executed in order, with a
**symmetric rollback narrative** at the end. Every phase names four
things: (i) the command(s) to run, (ii) the success signal you verify
before moving on, (iii) the failure signal that pauses the playbook,
(iv) the rollback action if that phase fails.

The playbook is deliberately runnable, not aspirational — a reader
should be able to execute each step without extrapolating from the text.
Where the command shape depends on your environment (shell, DNS
provider, reverse-proxy vendor), the example uses the most common
shape and names the variable to substitute.

The symmetric-rollback design is informed by CouchDB's replication
protocol: replication is one-shot or continuous, session-ID-tracked
via `_local/_replicator_checkpoint_*` docs, and bidirectional
replication is just two one-directional replications running at once.
Rolling back Phase N means running Phase N in reverse. See the
CouchDB 3.x replication protocol (`sources/couchdb/src/docs/src/replication/protocol.rst`)
for the checkpoint semantics this playbook relies on.

---

## Pre-requisites

Before Phase 1:

- You have admin-level access to the source Apache CouchDB instance
  (can read `_replicator`, `_users`, `_security`; can delete `_local/*`
  checkpoint docs).
- You have a target IRIS 2024.1+ instance with network connectivity
  from the source CouchDB host.
- You have planned a maintenance window. Cutover (Phase 6) is the only
  step that requires client downtime; bulk replication (Phase 3) runs
  while clients continue writing to CouchDB.
- You have read [Deviations](deviations.md) and accepted the four
  Epic 12 deviations and the cross-epic items.

---

## Phase 1 — Pre-migration checklist

Goal: establish a known-good baseline so post-cutover parity is
verifiable.

Run on the source CouchDB host:

```bash
# Source CouchDB version
curl -u admin:PASS http://couchdb.example.com:5984/

# Document-count baseline per database
for db in $(curl -s -u admin:PASS http://couchdb.example.com:5984/_all_dbs | jq -r '.[]'); do
  curl -s -u admin:PASS http://couchdb.example.com:5984/$db | jq "{db:\"$db\",doc_count:.doc_count,doc_del_count:.doc_del_count}"
done

# Attachment-count baseline (sample — full scan is expensive on very
# large DBs; the goal is to capture the expected volume, not every doc)
curl -s -u admin:PASS 'http://couchdb.example.com:5984/mydb/_all_docs?include_docs=true&limit=5000' | \
  jq '[.rows[] | select(.doc._attachments != null) | {id:.id,n_atts:(.doc._attachments | length)}]'

# Replication volume estimate — rough bytes-in-motion via size_ext
curl -s -u admin:PASS http://couchdb.example.com:5984/mydb | jq '{sizes}'
```

Record the outputs to a run-log; every later phase compares against it.

Plan the rest of the checklist:

1. Source CouchDB version confirmed (3.3.3, 3.2.x, etc. — matters for
   `_local/_replicator_checkpoint_*` format compatibility; see
   Phase 3).
2. Per-database `doc_count` + `doc_del_count` baseline captured.
3. Attachment count and rough total size captured.
4. Estimated replication duration — rule-of-thumb ~100–500 docs/second
   for small docs with no attachments, slower for attachment-heavy
   databases. CouchDB `_active_tasks` will give you the live rate.
5. DNS / TLS / auth plan: where do clients connect today, where will
   they connect tomorrow, who owns the DNS record, what is the TTL?
6. Reverse-proxy / direct-mount topology chosen (see
   [Getting Started § Topology Options](getting-started.md)).
7. Maintenance window agreed with application owners. Cutover (Phase 6)
   is typically the only visible-downtime step.
8. Rollback owner identified (the person who will execute the symmetric-
   rollback narrative at the end of this document if cutover fails).

**Success signal:** all 8 items captured in the run-log, with timestamps.

**Failure signal:** any item unresolved. Pause; resolve before moving
on. Cutover without a baseline is unrecoverable.

**Rollback:** nothing to roll back; this phase is pure inventory.

---

## Phase 2 — Install IRISCouch on the target IRIS instance

Goal: a fresh IRISCouch responding with the welcome envelope and
admin-UI reachable.

```bash
# ZPM (recommended)
zpm "install iris-couch"

# Or manual import — see README.md § Installation § Option 2

# Create the web application
# (In an IRIS terminal session in the target namespace):
#   Do ##class(IRISCouch.Installer).Install($Namespace, "/iris-couch/")

# Verify
curl http://target.example.com:52773/iris-couch/
# Expect: {"couchdb":"Welcome","vendor":{"name":"IRISCouch"},"version":"0.1.0"}

# Verify admin UI
# Browse to http://target.example.com:52773/iris-couch/_utils/
```

Follow [Getting Started § Install](getting-started.md) for the full
version of this phase, including the reverse-proxy / direct-mount
topology decision, and [Getting Started § Edge-level trailing-slash
normalization](getting-started.md#edge-level-trailing-slash-normalization-optional)
for the optional 301-redirect edge rule (nginx / Apache) that complements
IRISCouch's transparent internal trailing-slash fix (Story 13.4).

**Success signal:** `GET /iris-couch/` returns the welcome envelope;
`/iris-couch/_utils/` loads the admin UI; the installing user sees
`IRISCouch_Admin` on `GET /iris-couch/_session`.

**Failure signal:** `zpm "install iris-couch"` aborts, or the welcome
envelope doesn't arrive. See
[Troubleshooting § ZPM install failure on older IRIS](troubleshooting.md)
and [Troubleshooting § `curl` returns 404 from `/iris-couch/`](troubleshooting.md)
for the two most common install-time failures.

**Rollback:** nothing to roll back — source CouchDB is still authoritative.
Uninstall via `Do ##class(IRISCouch.Installer).Uninstall("/iris-couch/")`
in the target namespace; no data has moved yet.

---

## Phase 3 — Replicate-in from source CouchDB

Goal: bulk-copy every document, revision, and attachment from the
source CouchDB into IRISCouch while clients continue writing to CouchDB.
Use the CouchDB replicator (not IRISCouch's), so the source is
authoritative during replication.

On the source CouchDB host, create a one-shot `_replicator` doc per
database. This uses CouchDB as the replicator; IRISCouch is only the
target:

```bash
# Create the target database on IRISCouch first (idempotent)
curl -X PUT -u _system:SYS http://target.example.com:52773/iris-couch/mydb

# Create the replicator doc on the source
curl -X PUT -u admin:PASS \
  http://couchdb.example.com:5984/_replicator/mydb-to-iriscouch \
  -H 'Content-Type: application/json' -d '{
    "source": "http://admin:PASS@couchdb.example.com:5984/mydb",
    "target": "http://_system:SYS@target.example.com:52773/iris-couch/mydb",
    "continuous": false,
    "create_target": false
  }'

# Watch progress
watch -n 2 "curl -s -u admin:PASS http://couchdb.example.com:5984/_active_tasks | jq '.[] | select(.type == \"replication\")'"
```

One-shot replication reports in `_active_tasks` until completion; the
job document in `_replicator` transitions to
`"_replication_state": "completed"` when done.

**Success signal:** three things, verified **together** — the
conjunction is the replication-complete guarantee:

1. `_active_tasks` no longer lists this replication (the job has
   transitioned out of the active pool).
2. Document-count parity: `GET /mydb` on both sides returns the same
   `doc_count`. Allow for the small delta from client writes that
   arrived during the replication window — the delta should be bounded
   by your client write rate × replication duration, and Phase 7 will
   capture them.
3. Revision-leaf parity: `curl /mydb/_all_docs?conflicts=true` on both
   sides returns the same row count and the same conflict annotations.

**Failure signal:** replication errors visible in the replicator
document (`GET /_replicator/mydb-to-iriscouch`), or `_active_tasks` shows
the job entering a `crashing` state, or partial document parity (source
has documents the target does not).

**Rollback:**

```bash
# Cancel and delete the replicator doc
curl -X DELETE -u admin:PASS http://couchdb.example.com:5984/_replicator/mydb-to-iriscouch?rev=<rev>

# Delete the target database on IRISCouch (or leave it empty for a retry)
curl -X DELETE -u _system:SYS http://target.example.com:52773/iris-couch/mydb
```

Repeat Phase 3 with a cleaned target. Intermittent network failures
often resolve on the second attempt; hard failures (e.g., attachment
stream failures) are documented in
[Troubleshooting § Attachment stream failures](troubleshooting.md).

---

## Phase 4 — Validation

Goal: prove source and target have the same data before moving clients.

Run three concrete validations on every migrated database:

**(a) Document count:**

```bash
SRC=$(curl -s -u admin:PASS http://couchdb.example.com:5984/mydb | jq .doc_count)
TGT=$(curl -s -u _system:SYS http://target.example.com:52773/iris-couch/mydb | jq .doc_count)
test "$SRC" = "$TGT" && echo "OK: $SRC == $TGT" || echo "FAIL: src=$SRC tgt=$TGT"
```

**(b) Revision-leaf parity:**

```bash
SRC=$(curl -s -u admin:PASS 'http://couchdb.example.com:5984/mydb/_all_docs?conflicts=true' | jq '.rows | length')
TGT=$(curl -s -u _system:SYS 'http://target.example.com:52773/iris-couch/mydb/_all_docs?conflicts=true' | jq '.rows | length')
test "$SRC" = "$TGT" && echo "OK: $SRC == $TGT" || echo "FAIL: src=$SRC tgt=$TGT"
```

The `conflicts=true` flag surfaces conflict revisions in the row shape;
the count comparison catches any conflict merge that differs between
source and target.

**(c) Attachment round-trip:**

Sample N (typically 10–50) documents that have attachments, fetch each
attachment from both source and target, byte-compare:

```bash
for docid in $(curl -s -u admin:PASS 'http://couchdb.example.com:5984/mydb/_all_docs?include_docs=true&limit=10000' | \
               jq -r '.rows[] | select(.doc._attachments != null) | .id' | head -50); do
  for attname in $(curl -s -u admin:PASS "http://couchdb.example.com:5984/mydb/$docid" | jq -r '._attachments | keys | .[]'); do
    SRC_SHA=$(curl -s -u admin:PASS "http://couchdb.example.com:5984/mydb/$docid/$attname" | sha256sum | awk '{print $1}')
    TGT_SHA=$(curl -s -u _system:SYS "http://target.example.com:52773/iris-couch/mydb/$docid/$attname" | sha256sum | awk '{print $1}')
    test "$SRC_SHA" = "$TGT_SHA" && echo "OK $docid/$attname" || echo "FAIL $docid/$attname src=$SRC_SHA tgt=$TGT_SHA"
  done
done
```

If all three checks pass, the data is in parity.

> **Note on the "document count parity + revision-leaf parity" claim.**
> These are *CouchDB replicator guarantees*, not IRISCouch invariants.
> The replicator ships every revision leaf from source to target
> (revision *tree* shape is preserved by the `_bulk_docs?new_edits=false`
> path). If you see parity here, the replicator has done its job; if
> you see divergence, the divergence points to the replicator's
> checkpoint state, not IRISCouch's storage.

**Success signal:** all three validations pass for every migrated
database. Record the pass state and timestamps in the run-log.

**Failure signal:** any validation returns `FAIL`. Do not proceed to
cutover.

**Rollback:** restart Phase 3 with a cleaned target database. Do not
attempt to hand-patch divergent documents; the replicator will correct
them if given a fresh target.

---

## Phase 5 — Optional dual-write window

Goal (optional, adopter's call based on risk tolerance): run a period
where new writes land on **both** source CouchDB and IRISCouch before
cutover. This lets the adopter exercise IRISCouch at production write
volume while the source is still the client-visible authority.

**Skip this phase** if your confidence from Phase 4 validation is
high, or if the complexity of dual-write plumbing is higher than the
risk it mitigates.

Implementation options:

- **PouchDB per-doc sync:** configure PouchDB clients to replicate
  changes to both CouchDB and IRISCouch. Writes land on CouchDB
  (primary) and PouchDB replicates them to IRISCouch within the
  normal sync interval. Effectively the same as Phase 3's continuous
  replication with tighter client-perceived latency.
- **Application-layer fork:** the application performs `PUT`/`_bulk_docs`
  against both endpoints. Harder to get right (failure of one side must
  not fail the request); typically not worth it.

For the PouchDB approach, convert the Phase 3 one-shot replicator doc
to continuous:

```bash
curl -X PUT -u admin:PASS \
  http://couchdb.example.com:5984/_replicator/mydb-continuous \
  -H 'Content-Type: application/json' -d '{
    "source": "http://admin:PASS@couchdb.example.com:5984/mydb",
    "target": "http://_system:SYS@target.example.com:52773/iris-couch/mydb",
    "continuous": true,
    "create_target": false
  }'
```

Watch lag via `_active_tasks`:

```bash
curl -s -u admin:PASS http://couchdb.example.com:5984/_active_tasks | \
  jq '.[] | select(.type == "replication" and .continuous) |
      {source:.source_id, target:.target_id, changes_pending, source_seq, checkpointed_source_seq}'
```

**Success signal:** `changes_pending` stays near 0 across the dual-write
window. Replication lag is bounded by your acceptable RPO (e.g., < 30
seconds during the window).

**Failure signal:** `changes_pending` grows without bound, indicating
IRISCouch cannot keep up with the write rate. Diagnose via
[Troubleshooting § Replication lag](troubleshooting.md).

**Rollback:**

```bash
# Remove the continuous replicator doc
curl -X DELETE -u admin:PASS \
  "http://couchdb.example.com:5984/_replicator/mydb-continuous?rev=<rev>"
```

Clients still pointing at CouchDB are unaffected. Return to Phase 4
validation to confirm parity is still good after the dual-write window.

---

## Phase 6 — Cutover (client repoint)

Goal: point production clients at IRISCouch. This is the only
user-visible step.

Execute the DNS flip or reverse-proxy swap:

```bash
# Option A: reverse proxy (if clients use couchdb.example.com:5984 today)
# Edit nginx / envoy / traefik config to proxy couchdb.example.com:5984
# → target.example.com:52773/iris-couch/, reload the proxy

# Option B: DNS flip (if clients resolve couchdb.example.com to an A record)
# Update the A record to the IRISCouch host; wait for TTL
```

Watch client error rates on both sides of the flip:

```bash
# CouchDB audit (during cutover window)
tail -f /var/log/couchdb/couchdb.log | grep -E 'GET|PUT|POST|DELETE'

# IRISCouch audit (should show client traffic arriving)
curl -s -u _system:SYS http://target.example.com:52773/iris-couch/_active_tasks
# Plus the audit events emitted by Epic 9 into the IRIS event log
```

**Success signal:** three conjoint:

1. Client error rates (HTTP 4xx/5xx ratios) on IRISCouch stay **at or
   below** the baseline you recorded pre-cutover.
2. `_active_tasks` shows expected write throughput on IRISCouch
   (the reads arrive without replicator traffic — Phase 5 kept source
   up to date).
3. No spike in 4xx/5xx on IRISCouch that didn't exist on CouchDB. A
   few 404s for `/_show/` or `/_list/` paths are acceptable (see
   [Deviations § 10](deviations.md)); 5xx spikes are not.

**Failure signal:** client errors above baseline, or IRISCouch 5xx
spike, or replicator job on source stops reporting, or any
smoke-test client (PouchDB browser, replicator parity) reports a
previously-absent error.

**Rollback:** flip DNS / proxy back. Phase 7 (source drain) did NOT
run yet so CouchDB still has fresh data; cutover is reversible:

```bash
# Reverse the DNS / reverse-proxy change
# If DNS: update A record back to the CouchDB host
# If proxy: revert the proxy config, reload
```

Clients reconnect to CouchDB as if nothing had happened. Return to
Phase 4 validation to confirm IRISCouch parity is still good after
the client-side reverted.

---

## Phase 7 — Source drain

Goal: run one last replication pass from CouchDB → IRISCouch to capture
any in-flight writes that arrived at CouchDB during DNS propagation
(the gap between "cutover started" and "all clients resolved to
IRISCouch"). This pass is intentionally short — CouchDB's incremental
replication only pulls changes since the last checkpoint.

After 24–72 hours of stable cutover (adopter's call based on DNS TTL and
client-refresh intervals — longer is safer):

```bash
# One-shot pull on each migrated database
curl -X PUT -u admin:PASS \
  http://couchdb.example.com:5984/_replicator/mydb-drain \
  -H 'Content-Type: application/json' -d '{
    "source": "http://admin:PASS@couchdb.example.com:5984/mydb",
    "target": "http://_system:SYS@target.example.com:52773/iris-couch/mydb",
    "continuous": false,
    "create_target": false
  }'
```

**Success signal:** replication completes with `docs_read: 0` (or a
very small number — the drain was clean because clients had all moved).
`GET /_replicator/mydb-drain` shows `"_replication_state": "completed"`
and `_replication_stats.docs_written: 0`.

**Failure signal:** `docs_read > 0` unexpectedly, indicating clients
are still hitting the old CouchDB endpoint. Investigate DNS
propagation:

```bash
# Check DNS propagation from client networks
dig +short couchdb.example.com @8.8.8.8
dig +short couchdb.example.com @1.1.1.1

# Check last-client-activity on source CouchDB
tail /var/log/couchdb/couchdb.log | grep -E '(PUT|POST)' | head
```

**Rollback:** if drain keeps pulling new docs, extend the drain window
until `docs_read` reaches 0. Do not proceed to Phase 8 until the drain
is clean — decommissioning CouchDB with stragglers still writing to it
means losing those writes.

---

## Phase 8 — Decommission source CouchDB

Goal: stop the source CouchDB process and archive its data for
retention / rollback insurance.

```bash
# Stop the CouchDB process (systemd example)
sudo systemctl stop couchdb

# Archive the data directory to cold storage
# Keep this archive for at least the window specified in your
# data-retention policy — a weeks-long archive is cheap insurance
# against a latent-bug-discovered-two-weeks-later scenario
tar cvf couchdb-preserved.tar /var/lib/couchdb
mv couchdb-preserved.tar s3://backup.example.com/cold/

# Update monitoring — remove CouchDB alerts, confirm IRISCouch
# alerts cover the equivalent surface
```

**Success signal:** three conjoint:

1. CouchDB process stopped; `systemctl status couchdb` reports
   inactive.
2. IRISCouch is serving all production traffic cleanly (no error
   spike).
3. Monitoring dashboards updated to reflect the new endpoint.
   Alerting confirms both (a) "is IRISCouch up?" and (b) "is
   replication healthy?" (for any continuing replication to a peer
   CouchDB cluster if your topology has one).

**Failure signal:** clients still hitting the old CouchDB endpoint
(seen in the audit log or the CouchDB process remaining required for
load). Return to Phase 6 and re-verify DNS propagation; may need a
longer drain window.

**Rollback:** restore the archived data directory, start CouchDB,
flip DNS / proxy back. The symmetric-rollback narrative below is
the full playbook for this scenario.

---

## Symmetric rollback narrative (if you need to roll back **after** Phase 8)

If a post-decommission issue surfaces and IRISCouch must be retired in
favor of a fresh CouchDB:

This is the same playbook in reverse. Each phase here mirrors a phase
above.

1. **Re-install CouchDB.** `apt install couchdb` (or the vendor-
   specific equivalent); configure admin credentials. Mirror of Phase 2.
2. **Replicate-in from IRISCouch.** Create a `_replicator` doc on the
   **IRISCouch** side pointing IRISCouch → CouchDB with `continuous: false`
   per database. Mirror of Phase 3.
3. **Validate.** Run the same three validations from Phase 4 against
   IRISCouch vs newly-populated CouchDB.
4. **(Optional) Dual-write window** in the reverse direction. Mirror
   of Phase 5. Only needed if the rollback spans long enough to
   accumulate writes worth preserving on both sides.
5. **Cutover (reverse).** DNS flip clients from IRISCouch back to
   CouchDB. Mirror of Phase 6.
6. **Source drain (reverse).** One last IRISCouch → CouchDB replication
   to capture any in-flight writes that arrived at IRISCouch during the
   reverse-DNS propagation. Mirror of Phase 7.
7. **Decommission IRISCouch.**
   `Do ##class(IRISCouch.Installer).Uninstall("/iris-couch/")` in the
   target namespace; archive the IRIS `^IRISCouch.*` globals to cold
   storage if your data-retention policy requires it. Mirror of Phase 8.

The CouchDB replicator is bidirectional by design — the same
`_local/<session_id>_checkpoint_*` doc machinery that made forward-
replication idempotent makes reverse-replication idempotent. If you
arrive at this page, run the same playbook in reverse; the phase names
map 1:1.

---

## Post-migration

After Phase 8 (or the symmetric-rollback Phase 7):

- Update monitoring dashboards to reflect the new endpoint.
- Archive the pre-cutover CouchDB data directory until your retention
  window closes.
- Schedule a post-cutover retrospective. One week is typical; revisit
  any issue that surfaced during the cutover window and decide whether
  it is a documentation update, a [`deferred-work.md`](../_bmad-output/implementation-artifacts/deferred-work.md)
  entry, or a full [`deviations.md`](deviations.md) addition per NFR-M4.

---

## References

- CouchDB 3.x replication protocol —
  `sources/couchdb/src/docs/src/replication/protocol.rst`
- CouchDB 3.x `_replicator` database —
  `sources/couchdb/src/docs/src/replication/replicator.rst`
- IRISCouch [Compatibility Matrix](compatibility-matrix.md) — for
  per-endpoint caveats encountered during cutover.
- IRISCouch [Deviations Log](deviations.md) — for pre-cutover
  acceptance (the list of behaviors an adopter knows in advance will
  differ).
- IRISCouch [Troubleshooting Runbook](troubleshooting.md) — for
  incident-class diagnostics during the cutover window.

---

*This playbook is current as of 2026-04-18 (Story 13.2). It is updated
in the same commit as any code change that alters the migration surface
per PRD [NFR-M2](../_bmad-output/planning-artifacts/prd.md) "docs-with-
code" rule.*
