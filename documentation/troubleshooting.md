# IRISCouch Troubleshooting Runbook

**Last updated:** 2026-04-18 (Story 13.2)
**IRISCouch version:** 0.1.0 (α development, pre-release)
**Audience:** operators diagnosing IRISCouch incidents in production.
**Companion docs:** [Getting Started](getting-started.md),
[Compatibility Matrix](compatibility-matrix.md),
[Deviations](deviations.md),
[Migration Playbook](migration.md).

---

## Maintenance rule (NFR-M3)

This runbook is updated **before the next release** whenever a new
incident class surfaces — from customer-zero validation, an external
adopter bug report, or a post-incident retrospective. An unlogged
incident class that recurs is a defect against [PRD NFR-M3](../_bmad-output/planning-artifacts/prd.md).

**How to add a new class:** append a new `## Incident class N — <name>`
section below, using the four-part structure (Symptoms / Diagnostic
steps / Resolution / Prevention). Each new class should be born from a
real incident — either customer-zero or an external report — not from
speculation. File the underlying code fix (if any) in
[`deferred-work.md`](../_bmad-output/implementation-artifacts/deferred-work.md).

The five classes below are the initial set, chosen from what's been
observed during Epic 1–12 development and the operational resilience
work in Epic 9. New adopter-observed classes will be folded in before
each public release.

---

## Structure

Every incident class follows the same shape:

- **Symptoms** — what the operator observes (endpoint behavior, log
  patterns, client errors).
- **Diagnostic steps** — the commands / globals / log greps that
  confirm the class and narrow down the cause.
- **Resolution** — how to recover the system.
- **Prevention** — how to reduce the odds of recurrence.

Cross-references to [`deferred-work.md`](../_bmad-output/implementation-artifacts/deferred-work.md)
and to [`deviations.md`](deviations.md) appear inline where relevant.

---

## Incident class 1 — Replication lag

### Symptoms

- `GET /_active_tasks` shows a continuous replication with `changes_pending`
  growing steadily rather than hovering near 0.
- Client-side sync (e.g., PouchDB) makes progress but at a rate well
  below the expected steady-state — users report "new records take
  minutes to appear on the mobile client".
- Audit events show an unusually high volume of `_changes` feed
  requests arriving from one replicator session.
- IRIS metrics (`GET /_prometheus`) show elevated journal write latency
  (`JOURNALSTATE` tag) or worker-queue saturation.

### Diagnostic steps

```bash
# (1) Observe the replication rate — are changes_pending growing?
curl -s -u _system:SYS http://localhost:52773/iris-couch/_active_tasks | \
  jq '.[] | select(.type == "replication" and .continuous) |
      {source:.source_id, target:.target_id, changes_pending,
       source_seq, checkpointed_source_seq,
       docs_read, docs_written, missing_revisions_found}'

# (2) Read the IRIS journal write-queue state
curl -s -u _system:SYS http://localhost:52773/iris-couch/_prometheus | \
  grep -E 'iriscouch_journal|iriscouch_workqueue'

# (3) Network latency between source and target
ping -c 5 source.example.com
traceroute source.example.com

# (4) If the replicator is doing selector-filter work, check the
# selector itself — pathological filters are the most common
# IRIS-bound replication slowdown
curl -s -u _system:SYS http://localhost:52773/iris-couch/_replicator/<jobid> | \
  jq '{source, target, selector, filter, "continuous", doc_ids}'
```

Look for:

- `changes_pending` growing: confirms lag (not just a slow initial
  sync).
- Elevated `JOURNALSTATE` + growing `workqueue_depth`: IRIS-bound;
  the bottleneck is IRIS's write path, not the network.
- Large `docs_read` / small `docs_written`: selector-filter-bound; the
  replicator is pulling docs that get rejected by the filter, so every
  doc costs a round trip but no work lands.

### Resolution

Based on where the bottleneck lives:

- **IRIS-bound** (journal saturation, work-queue depth): tune IRIS
  journal write-buffer size in the IRIS Management Portal under
  *System Administration → Configuration → System Configuration →
  Journal Settings*. Increase `Journal buffer memory` if memory is
  available. Schedule the tuning during a low-traffic window.

- **Network-bound**: reduce `worker_batch_size` on the replicator doc
  to lower the burst size per round-trip, and raise `worker_processes`
  to parallelize more. Both fields live in the `_replicator/{docid}`
  document.

- **Selector-filter-bound**: simplify the filter. A selector with many
  `$or` branches or deep nested `$and` trees runs the Mango engine
  per-doc. For a replication that pulls most docs anyway, replace the
  selector filter with `_design/` / `_doc_ids` if applicable.

- **Source-CouchDB-bound**: if the source is also reporting slow
  `_active_tasks`, the bottleneck is on the source. Profile the
  source's `_changes` feed rate directly.

### Prevention

- Capture a `_active_tasks` + `_prometheus` baseline under expected load
  **before** cutting a production workload to IRISCouch. See the
  [Migration Playbook Phase 1](migration.md) for the baseline-capture
  recipe.
- Capacity-plan against expected write volume — IRIS-bound replication
  lag is the clearest signal that the target is under-provisioned.
- Avoid ad-hoc `continuous: true` replicators that weren't exercised in
  pre-production with representative workloads.

---

## Incident class 2 — Checkpoint corruption

### Symptoms

- Replication fails mid-stream with an error envelope like
  `{"error": "checkpoint_mismatch", "reason": "..."}` or similar.
- `_local/{replication-id}` checkpoint document on the source or target
  shows an unexpected `source_last_seq` that does not match either
  side's current history. (The `replication-id` is a stable hash of the
  source/target/selector triple per the CouchDB replication protocol,
  not a literal `_replicator_checkpoint_<session_id>` name.)
- Audit log shows abrupt client disconnects followed by the next
  replication attempt not being able to resume cleanly.

### Diagnostic steps

```bash
# (1) Locate the checkpoint docs on both sides. The replication-id is
#     the hash the replicator uses to identify the session; a failing
#     replicator logs it in its error envelope. For an ad-hoc probe,
#     list all _local/* docs via _all_docs on the _local partition:
#       curl /mydb/_local_docs             (if exposed)
#     or walk the _changes feed for _local updates, or inspect the
#     ^IRISCouch.Local(<db>, "_local/<repid>") global in an IRIS
#     terminal (zwrite ^IRISCouch.Local).
curl -s -u admin:PASS http://source.example.com:5984/mydb/_local/<replication-id> | jq
curl -s -u _system:SYS http://localhost:52773/iris-couch/mydb/_local/<replication-id> | jq

# (2) Compare session_id history
#     Each checkpoint stores the chronological history; matching
#     session_id values between the two sides is the replicator's
#     resume signal (per CouchDB replication protocol).
#     If they don't match, the replicator will refuse to resume.

# (3) Check the Epic 9 audit log for client disconnects around the
#     time the replication started failing. IRISCouch audit events go
#     to IRIS's system audit log (%SYS.Audit) via
#     IRISCouch.Audit.Emit -> $System.Security.Audit("IRISCouch", ...).
#     Inspect via the Management Portal:
#       System Operation -> Security Management -> Auditing ->
#       View Audit Database (filter Event Source = "IRISCouch")
# Or query it programmatically in an IRIS terminal:
#   Do $System.Security.Audit("IRISCouch")   ; list registered events
# The Prometheus endpoint surfaces aggregate counters:
curl -s -u _system:SYS http://localhost:52773/iris-couch/_prometheus | \
  grep -E 'iriscouch_audit|iriscouch_replication'
```

Look for:

- Session-ID mismatch between source and target checkpoint docs →
  checkpoint staleness.
- Truncated `history` array in the checkpoint doc → a kill-mid-flush
  scenario; the writer was interrupted before the full history array
  flushed.
- `source_last_seq` on the target newer than the source's current
  `update_seq` → suggests the source was restored from a pre-replication
  backup and the checkpoint points at a sequence the source no longer
  has.

### Resolution

Delete the `_local/{replication-id}` doc on the side that has the
stale checkpoint; restart the replication:

```bash
curl -X DELETE -u _system:SYS \
  "http://localhost:52773/iris-couch/mydb/_local/<replication-id>?rev=<rev>"

# Restart by re-creating the _replicator doc
```

Expect a short replay of already-replicated documents — the
`_bulk_docs?new_edits=false` path is idempotent, so replaying does not
create duplicate revisions. The replay duration is bounded by the size
of the `_changes` feed since the last valid checkpoint.

If both sides' checkpoints are corrupt, delete both and restart the
replication from scratch; the target becomes an incremental target
again and the full changes feed replays.

### Prevention

- Ensure replicator client processes have stable session identity —
  restarting the replicator process while it holds a partial checkpoint
  is the most common cause of corruption. CouchDB's replicator
  auto-resumes by session_id; an ad-hoc `curl` loop does not.
- Avoid killing replication processes mid-flight. If you must stop a
  running replication, use `DELETE /_replicator/{docid}` (which
  flushes a final checkpoint) rather than `kill -9` on a shell-loop
  script.
- CouchDB replication protocol reference:
  `sources/couchdb/src/docs/src/replication/protocol.rst` documents the
  checkpoint handshake in full; an operator rebuilding a replicator
  pipeline should read that file first.

---

## Incident class 3 — Stuck conflicts

### Symptoms

- `GET /{db}/{docid}?conflicts=true` shows a `_conflicts` array that
  doesn't clear across multiple writes — the same conflict revisions
  persist indefinitely.
- Application reports wrong-data scenarios (user sees the wrong
  revision's body; two clients believe they committed the same write
  successfully but the API returns one or the other's rev depending
  on resolution order).
- Replication continues normally but the data is stale from the
  application's perspective.

### Diagnostic steps

```bash
# (1) Read the full conflict set for one affected document
curl -s -u _system:SYS \
  "http://localhost:52773/iris-couch/mydb/mydocid?conflicts=true" | jq

# (2) Inspect the revision tree
curl -s -u _system:SYS \
  "http://localhost:52773/iris-couch/mydb/mydocid?revs_info=true" | jq

# (3) Check if a design doc's validate_doc_update is blocking the
#     merge (conflict-resolution writes go through validate just like
#     regular writes; a misconfigured validate can reject the merge)
curl -s -u _system:SYS \
  'http://localhost:52773/iris-couch/mydb/_all_docs?startkey="_design/"&endkey="_design0"&include_docs=true' | \
  jq '.rows[].doc | select(.validate_doc_update != null) | {_id, validate_doc_update}'
```

Look for:

- Multiple leaf revisions with different bodies → stuck conflict.
- One leaf revision marked `deleted: true` and another live → winner
  is the live one, but the application may be reading the wrong one
  by revision ID.
- `validate_doc_update` that rejects the merging write with `forbidden`
  → the stuck conflict is blocked by the validate hook (see
  [Incident class 5e](#5e-validate_doc_update-rejection-without-config-awareness)
  below).

### Resolution

Pick the winning revision per CouchDB MVCC rules: highest generation
wins, ties broken lexically by revision hash. Delete the non-winning
conflict revisions to clear the conflict:

```bash
# For each non-winning conflict rev, delete explicitly
for r in $(curl -s -u _system:SYS \
           "http://localhost:52773/iris-couch/mydb/mydocid?conflicts=true" | \
           jq -r '._conflicts[]?'); do
  curl -X DELETE -u _system:SYS \
    "http://localhost:52773/iris-couch/mydb/mydocid?rev=$r"
done

# Verify
curl -s -u _system:SYS \
  "http://localhost:52773/iris-couch/mydb/mydocid?conflicts=true" | jq
```

### Prevention

- Build an application-level conflict-resolution strategy **before**
  shipping replication to production. "Last-writer-wins on every
  conflict" is a strategy; "pick the winner based on a business rule"
  is a better strategy; "ignore conflicts and hope" is not a strategy.
- PouchDB's `db.resolveConflicts` / `db.get(id, {conflicts: true})`
  are the client-side hooks; use them explicitly.
- Audit `_conflicts` array length per doc as part of health metrics.
  A sudden spike is a signal that a deployment or client-version
  mismatch is creating conflicts faster than resolution can clear
  them.

---

## Incident class 4 — Attachment stream failures

### Symptoms

- Large attachment downloads (`GET /{db}/{docid}/{attname}`) stall
  mid-stream or return partial bytes (fewer bytes than the `Content-
  Length` header claimed).
- Attachment uploads return `413 Payload Too Large` or `500 Internal
  Server Error` for files above some threshold.
- Replication of databases with large attachments (> 100 MB per
  attachment) fails with vague stream errors.

### Diagnostic steps

```bash
# (1) Reproduce with a known-size attachment
curl -s -u _system:SYS -o /tmp/att \
  "http://localhost:52773/iris-couch/mydb/mydocid/myatt"
ls -la /tmp/att
# Compare size to the Content-Length header the server returned
curl -sI -u _system:SYS "http://localhost:52773/iris-couch/mydb/mydocid/myatt"

# (2) Check CSP Gateway buffer size (this is the CSP-layer deviation
#     from CouchDB; see deviations.md § 7 for the _changes-feed
#     analog)
#     In the Management Portal: System Administration → Security →
#     Applications → Web Applications → (your IRISCouch app) →
#     Max Upload / Max Response settings

# (3) Verify %Stream.GlobalBinary integrity via bulk_get
curl -s -u _system:SYS -X POST \
  http://localhost:52773/iris-couch/mydb/_bulk_get?attachments=true \
  -H 'Content-Type: application/json' \
  -d '{"docs":[{"id":"mydocid"}]}' | jq '.results[].docs[].ok._attachments'

# (4) For multipart upload failures, check the attachment handler
#     (Story 5.2 multipart boundary handling)
curl -v -u _system:SYS -X PUT \
  "http://localhost:52773/iris-couch/mydb/mydocid/myatt?rev=<rev>" \
  -H 'Content-Type: multipart/related; boundary=abcd' \
  -d @/path/to/big-file
# The -v output shows where the request stalls
```

Look for:

- `Content-Length` correct but `/tmp/att` smaller: CSP Gateway
  truncated the response mid-stream (buffer overflow).
- `413` on upload: CSP Gateway `MaxUploadSize` reached.
- `500` on `bulk_get` with `attachments=true` but single-attachment
  `GET` succeeds: the base64 inline path is hitting memory limits
  (known `[LOW]` in deferred-work.md § Story 5.3).

### Resolution

- Raise the CSP Gateway `MaxUploadSize` for the IRISCouch web
  application (Management Portal → Web Applications). The default
  CSP Gateway upload limit is frequently lower than CouchDB's
  effective limit.
- For very-large attachments (> 100 MB), route through a reverse
  proxy with direct streaming rather than CSP buffering. The reverse
  proxy holds the stream open to the client while the CSP back-end
  writes/reads the `%Stream.GlobalBinary` content; the buffering
  layer only handles the headers.
- For `bulk_get?attachments=true` failures, split the `docs` array
  into smaller batches so each batch's total inline base64 stays
  under the IRIS string-size ceiling (~3.6 MB per string).

### Prevention

- Cap application-level attachment sizes at the infrastructure's
  documented limit. An application that accepts arbitrarily-sized
  uploads and stores them in CouchDB / IRISCouch attachments is an
  application that will eventually hit the limit in production.
- Route very-large blobs to separate object storage (S3, Azure Blob,
  IRIS's own BLOB support) rather than relying on CouchDB attachments.
  Attachments are designed for small assets (icons, PDFs, profile
  images) — not for gigabyte media.

---

## Incident class 5 — JS sandbox errors

The JSRuntime subsystem has five distinct failure modes, all of which
have been observed or foreseen during Epic 12 development. Each has a
distinct diagnostic path. Additional JSRuntime failure modes should be
appended as they are observed in the wild.

### 5a. `501 not_implemented` from a view query

#### Symptoms

- `GET` or `POST` to `/{db}/_design/{ddoc}/_view/{view}` returns
  `501 Not Implemented` with a body like
  `{"error":"not_implemented","reason":"JSRuntime 'None' does not support view execution; configure JSRUNTIME=Subprocess"}`.
- Every view query fails identically across databases; no database-
  specific bias.
- This is the default state on a fresh IRISCouch install.

#### Diagnostic steps

IRISCouch does not expose `/_node/{name}/_config*` (per [Compatibility
Matrix § /_node](compatibility-matrix.md) — the full cluster-node
config HTTP surface is out of scope for the single-node IRISCouch
server). Read the JSRuntime config from an IRIS terminal session in
the IRISCouch namespace:

```objectscript
; (1) Read the current JSRuntime config
Do ##class(IRISCouch.Config).GetAll().%ToJSON()
; Or a single key:
Write ##class(IRISCouch.Config).Get("JSRUNTIME")
```

Expected output when the backend is None:
`{"JSRUNTIME":"None","JSRUNTIMESUBPROCESSPATH":"",...}`.

If `JSRUNTIME` is `None`, the 501 is expected. If `JSRUNTIME` is
already `Subprocess` but views still 501, see
[incident 5c](#5c-node-path-misconfig) below.

#### Resolution

Install Node 18+ (or Bun 1+, Deno 1.40+) on the IRIS host and switch
the config:

```objectscript
; In an IRIS terminal session:
Set ^IRISCouch.Config("JSRUNTIME") = "Subprocess"
Set ^IRISCouch.Config("JSRUNTIMESUBPROCESSPATH") = "C:\Program Files\nodejs\node.exe"
; Or on Linux / macOS:
Set ^IRISCouch.Config("JSRUNTIMESUBPROCESSPATH") = "/usr/bin/node"
```

Then restart IRIS or force config reload, and re-test the view query.

#### Prevention

- Include JS requirements in your deployment capacity plan at install
  time. [Getting Started § JSRuntime](getting-started.md) and
  [js-runtime.md](js-runtime.md) cover the install choices.
- Before operator-visible features depend on views, confirm the
  runtime is set to `Subprocess` with a valid Node path.

### 5b. Timeout misconfig

#### Symptoms

- View queries return
  `{"error":"jsruntime_timeout","reason":"subprocess exceeded 5000ms"}`
  (or the configured `JSRUNTIMETIMEOUT`).
- View queries hang for far longer than `JSRUNTIMETIMEOUT` claims,
  eventually producing a vague CSP Gateway error rather than a
  timeout envelope.
- Audit log shows `timeout` events from `ViewIndexUpdater` or
  `Subprocess.ExecuteMap`.

#### Diagnostic steps

```objectscript
; (1) Read the current timeout config (in an IRIS terminal)
Write ##class(IRISCouch.Config).Get("JSRUNTIMETIMEOUT")
; Expect a positive integer like 5000
```

```text
(2) Inspect recent timeout audit events. IRISCouch emits
    JsRuntimeTimeout audit events via IRISCouch.Audit.Emit ->
    $System.Security.Audit() into IRIS's %SYS.Audit log (NOT a
    ^IRISCouch.Audit global). Open the Management Portal:
      System Operation -> Security Management -> Auditing ->
      View Audit Database
    Filter Event Source = "IRISCouch" and Event Type =
    "JsRuntimeTimeout" for the rows that name subsystem
    ("map" / "reduce" / "validate_doc_update" / "filter"),
    timeoutMs, ddoc, and database.
```

```bash
# (3) Watch the aggregate counter via /_prometheus
curl -s -u _system:SYS http://localhost:52773/iris-couch/_prometheus | \
  grep -E 'iriscouch_jsruntime_timeout'

# (4) If timeouts are firing at the wrong layer, check that both
# enforcement layers are active — couchjs self-kill + IRIS-side poll
```

#### Resolution

Story 12.5 ships **two-layer** timeout enforcement. Both layers should
fire during a genuine timeout:

- **couchjs self-kill:** the entry script
  `documentation/couchjs/couchjs-entry.js` sets
  `setTimeout(() => { process.exit(124); }, timeout_ms + 1000).unref()`
  so a runaway Node process exits itself 1 second after the deadline.
- **IRIS-side poll:** `Pipe.Flush` passes `/ASYNC` to `$ZF(-100)` and
  polls `tasklist` (Windows) or `kill -0` (POSIX) to detect that the
  child is still running. On expiry, `taskkill /F` (Windows) or
  `kill -9` (POSIX) forces termination.

If only one layer fires, the subprocess spawn is not using the
`/ASYNC` flag. Inspect `IRISCouch.JSRuntime.Subprocess.Pipe.cls` to
confirm `$ZF(-100, "/ASYNC", …)`. See
[`js-runtime.md` § Timeout enforcement](js-runtime.md) for the full
architecture.

If the timeout is legitimate (a pathological map function that truly
takes longer than `JSRUNTIMETIMEOUT`), either:

```objectscript
; Raise the ceiling
Set ^IRISCouch.Config("JSRUNTIMETIMEOUT") = 30000  ; 30 seconds
```

…or rewrite the map function to do less work per doc.

#### Prevention

- Profile view map functions on representative data before exposing
  them to production load. A map that emits many rows or does heavy
  JSON parsing will push timeouts.
- Monitor the `jsruntime` audit category for timeout events and
  alarm on a baseline deviation.
- Do not raise `JSRUNTIMETIMEOUT` beyond 30 seconds lightly — a long
  timeout means a runaway ties up a subprocess for that long before
  the pool can recover it.

### 5c. Node path misconfig

#### Symptoms

- View queries return `500 Internal Server Error` with a body whose
  error name comes from the subprocess path
  (`Pool.Acquire: Pipe.Open failed: ...`, raised as a
  `subprocess_error` envelope from `IRISCouch.JSRuntime.Subprocess.Pool`).
- IRIS application error log shows `$ZF(-100)` errors referencing the
  interpreter path.
- The error is consistent across view queries — not flaky — which
  distinguishes it from a transient spawn failure.

#### Diagnostic steps

```objectscript
; (1) Read the configured subprocess path from an IRIS terminal
Write ##class(IRISCouch.Config).Get("JSRUNTIMESUBPROCESSPATH")
; Note the returned path
```

```bash
# (2) Verify the path is a valid, executable file
ls -la "<subprocess_path>"
"<subprocess_path>" --version
# e.g. on Windows:
# dir "C:\Program Files\nodejs\node.exe"
# "C:\Program Files\nodejs\node.exe" --version
```

The expected output is a version string (e.g., `v20.11.1`). Any
error — file not found, permission denied, `ENOENT` — confirms the
path is bad.

An operator hitting this in production will see a 500 envelope of
roughly this shape (the exact wording comes from the
`$System.Status.GetErrorText(tSC)` wrapped by
`IRISCouch.JSRuntime.Subprocess.Pool.Acquire`):

```json
{
  "error": "subprocess_error",
  "reason": "Pool.Acquire: Pipe.Open failed: <$ZF(-100) error text naming '/usr/bin/nodejs'>"
}
```

The `reason` field names the failing path; use it to correct the
config.

#### Resolution

Set the correct path and restart:

```objectscript
Set ^IRISCouch.Config("JSRUNTIMESUBPROCESSPATH") = "/usr/bin/node"
```

Verify:

```objectscript
Write ##class(IRISCouch.Config).Get("JSRUNTIMESUBPROCESSPATH")
```

Re-run the failing view query.

#### Prevention

- Deployment automation should validate the Node path before enabling
  `JSRUNTIME=Subprocess`. A simple shell check:
  `test -x "$NODE_PATH" && "$NODE_PATH" --version || exit 1`.
- The install documentation ([getting-started.md § JSRuntime](getting-started.md))
  names the common paths for Windows, macOS, and Linux.

### 5d. ZPM install failure on pre-2024.1 IRIS

#### Symptoms

- `zpm "install iris-couch"` aborts mid-install.
- Error output references `[Language = python]` method compile errors
  on pre-2024.1 IRIS **(regression case — should not happen on shipped
  IRISCouch — see Prevention below)**.
- Or general compile errors on the IRISCouch classes because IRIS is
  older than 2024.1.

#### Diagnostic steps

```bash
# (1) Check the IRIS version
# In an IRIS terminal:
write $ZVERSION
# Expect: "IRIS for Windows (x86-64) 2024.1.0 (Build 267U) ..." or newer
```

If `$ZVERSION` reports a version earlier than 2024.1, that is the
blocker — IRISCouch supports IRIS 2024.1+ only (PRD [NFR-M9](../_bmad-output/planning-artifacts/prd.md)
"Compile-on-any-IRIS" guarantees compile within that range).

If `$ZVERSION` is 2024.1+ **and** the error references
`[Language = python]`, that is a genuine defect — IRISCouch's NFR-M9
promises zero `[Language = python]` methods in shipped classes
regardless of Python availability. File an issue with the failing
class name and line number.

#### Resolution

- **IRIS version < 2024.1:** upgrade IRIS to 2024.1+ on the target
  host, or pin to an older IRISCouch release that supported your IRIS
  line (if one exists).
- **IRIS 2024.1+ but `[Language = python]` compile failure:** this is
  NFR-M9 regression — file an issue immediately (zero tolerance per
  the Epic 12 retrospective). The fix is to remove the Python method
  declaration; no operator workaround is sufficient.

#### Prevention

- Include `$ZVERSION` check in pre-deployment automation:
  ```bash
  iris session <INSTANCE> -U %SYS "write $ZVERSION" | grep -q "2024.1\|2024.[2-9]\|202[5-9]"
  ```
- The IRISCouch CI pipeline includes a Python-less IRIS image release-
  gate job (Story 12.4 resumption action item #5 + #9) to catch the
  `[Language = python]` regression automatically.

### 5e. `validate_doc_update` rejection without config awareness

#### Symptoms

- Document writes fail with `403 Forbidden` and a message like
  `{"error":"forbidden","reason":"you can't touch this"}` or similar
  — words the operator doesn't recognize.
- Only some writes fail — those that trigger the validate function's
  reject path. Other writes pass.
- The operator may not realize a design doc exists that is rejecting
  writes. Default CouchDB-style workflows often install
  `validate_doc_update` under `_design/app` without operator
  visibility.

#### Diagnostic steps

```bash
# (1) List all design docs in the affected database
curl -s -u _system:SYS \
  'http://localhost:52773/iris-couch/mydb/_all_docs?startkey="_design/"&endkey="_design0"&include_docs=true' | \
  jq '.rows[].doc | {_id, has_validate: (.validate_doc_update != null), validate_snippet: (.validate_doc_update | tostring | .[0:120])}'

# (2) Inspect the full validate function body
curl -s -u _system:SYS \
  "http://localhost:52773/iris-couch/mydb/_design/app" | jq '.validate_doc_update'

# (3) Audit (Epic 9 / Story 12.3) the validate_doc_update invocations.
# IRISCouch audit events go to IRIS's %SYS.Audit log via
# IRISCouch.Audit.Emit -> $System.Security.Audit("IRISCouch", ...).
# Inspect via Management Portal:
#   System Operation -> Security Management -> Auditing ->
#   View Audit Database
# Filter Event Source = "IRISCouch" and Event Type = "ValidateReject"
# (or "ValidateApprove" for the accept path). The EventData JSON names
# db, docId, ddoc, status code, and reason string.
```

Look for:

- `validate_doc_update` present on any `_design/*` doc: that is the
  source of the rejections.
- `throw({forbidden: "..."})` or `throw({unauthorized: "..."})` inside
  the function: these are the CouchDB-standard rejection shapes; the
  operator-visible error message comes from this string.
- `userCtx` checks inside the function: the function may be
  conditionally rejecting based on the user's roles. `curl /_session`
  to confirm the requesting user's role set.

#### Resolution

Three options, in order of preference:

1. **Fix the validate function** if it has a bug. Update the design
   doc; the fix is effective on the next write.
2. **Delete the design doc** if it is unused (legacy from a prior
   deployment, imported by accident, etc.).
3. **Bypass validation globally** by setting `JSRUNTIME=None`
   **(not recommended for production)**. This makes every write pass
   validate (because the runtime returns 501 at validate-invocation
   time, which the backend treats as "validate unavailable" and admits
   the write with `new_edits=true`). Useful only for emergency
   write-admission during a production incident.

#### Prevention

- Audit design docs at deployment time. The admin UI at `/_utils/`
  lists design docs per database; inspect `validate_doc_update` fields
  before enabling write traffic.
- Include design-doc migration in your deployment runbook — don't
  replicate design docs from a dev database into production without
  reviewing what rules they enforce.
- Reference: [Compatibility Matrix § Design Documents — `validate_doc_update`](compatibility-matrix.md)
  for the per-backend status; [Deviations § 8](deviations.md) for
  IRISCouch's validate-on-replication-writes divergence from CouchDB.

---

## Cross-reference: where to file a new incident class

If you encounter a class that doesn't fit any of the above:

1. Add a `## Incident class N — <name>` section below, following the
   four-part structure.
2. If the incident reveals a **code defect**, file it in
   [`deferred-work.md`](../_bmad-output/implementation-artifacts/deferred-work.md)
   under a severity-appropriate section (HIGH if operator-observable).
3. If the incident reveals a **deviation from CouchDB that is
   deliberate**, add an entry to [`deviations.md`](deviations.md)
   per the NFR-M4 maintenance rule.
4. If the incident is **purely operational** (tuning knob, capacity
   plan), this runbook is the right home.

The runbook's maintenance rule (NFR-M3) commits to keeping this list
current across releases. An adopter reading this file should find
their incident class — not just a generic "contact support" pointer.

---

## References

- [PRD NFR-M3 (Troubleshooting Runbook Coverage)](../_bmad-output/planning-artifacts/prd.md)
- [Epic 12 retrospective § Action Item #4](../_bmad-output/implementation-artifacts/epic-12-retro-2026-04-17.md)
- [Story 12.5 two-layer timeout implementation](../_bmad-output/implementation-artifacts/12-5-incremental-view-indexing-caching-and-sandbox-safety.md)
- [Epic 9 operational resilience tests](../_bmad-output/implementation-artifacts/9-3-operational-resilience-and-data-durability.md)
- [CouchDB 3.x troubleshooting conventions (vendored)](../sources/couchdb/src/docs/src/)
- [IRISCouch JSRuntime Backends](js-runtime.md)

---

*This runbook is current as of 2026-04-18 (Story 13.2). It is updated
in the same commit as any code change that alters an incident class's
diagnostic path, per PRD [NFR-M2](../_bmad-output/planning-artifacts/prd.md)
"docs-with-code" rule. New incident classes are added before the
next release under NFR-M3.*
