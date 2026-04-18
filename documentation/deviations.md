# IRISCouch Deviation Log

**Last updated:** 2026-04-18 (Story 13.2)
**IRISCouch version:** 0.1.0 (α development, pre-release)
**Scope:** Every observable difference between IRISCouch and Apache
CouchDB 3.x (3.3.3 anchor; 3.5.x planned at γ).

---

## Maintenance rule (NFR-M4)

Every release updates this file. An unlogged deviation is a
release-blocking defect per [PRD NFR-M4](../_bmad-output/planning-artifacts/prd.md).
If a dev agent, reviewer, or adopter discovers behavior that differs
from CouchDB 3.x and is **operator-observable** (see filter below) and
the deviation is not already listed here, that is a defect against
NFR-M4 — fix-forward by either (a) changing IRISCouch to match CouchDB
or (b) adding the entry to this file with a named rationale, in the
same commit as the change. Never the commit after.

The Story 12.2 view query-parameter scope cut was the cited cautionary
failure mode: the cut was documented in the story file, in
`deferred-work.md`, and in the commit message — but not in the README.
Operators only see the README and this file. Story 12.2 is now fixed
(see entry #3 below); the maintenance rule exists so the pattern
doesn't repeat.

## Operator-observable filter

This file catalogs deviations an adopter will see through a supported
CouchDB client (PouchDB, Apache CouchDB replicator, Cloudant SDKs,
Fauxton, `nano`) or a CouchDB-shape automated test suite. The filter:

> A deviation qualifies for this file if an adopter running an
> automated test suite or a supported CouchDB client against IRISCouch
> would see different behavior from the same suite/client against
> Apache CouchDB 3.x.

Items that do **not** qualify (tracked in
[`deferred-work.md`](../_bmad-output/implementation-artifacts/deferred-work.md)
instead):

- Test-coverage gaps (no runtime behavior delta)
- Internal refactor candidates (Pool shim, DRY cleanups, docstring polish)
- CI / infra concerns (self-hosted runner, stylelint installation)
- Tooling bugs upstream (MCP `iris_execute_tests` class-discovery, etc.)
- Frontend polish (favicon, Angular idiom updates, CSS token hygiene)

Applying NFR-M4 in a future release: use the same filter. If unsure
whether a MED qualifies, ask "could an adopter's automated suite see
this?" If yes, it is a deviation.

## Entry format

Each deviation below follows the same shape:

- **Behavior** — the feature or endpoint involved
- **CouchDB 3.x behavior** — what CouchDB does
- **IRISCouch behavior** — what IRISCouch does
- **Rationale** — why the deviation exists
- **Tracking** — story / deferred-work link so the reader can dig further

Entries are ordered by expected operator impact — the items near the
top are the ones most likely to surface in a typical adopter's
evaluation suite. Informational items (cosmetic, cross-origin-specific,
or tiny) are collected under `## Informational` at the bottom.

---

## Primary deviations

### 1. View-key collation

- **Behavior:** ordering of emitted keys in map/reduce view results.
- **CouchDB 3.x behavior:** Erlang `couch_ejson_compare` imposes typed
  collation: `null < false < true < number < string < array < object`.
  Numbers compare numerically (`2 < 10`); strings compare lexically
  within their type bucket.
- **IRISCouch behavior:** `QueryEngine.SortRowsByKey()` encodes each key
  as a type-prefixed JSON string (`n:` for numbers, `s:` for strings,
  `z:` for arrays/objects) and sorts lexically via `$Order`. Homogeneous
  keys sort correctly within a type; **mixed-type keys do not** match
  CouchDB's typed comparator. `emit(10, …)` and `emit(2, …)` compare
  correctly because both are numbers (same `n:` prefix), but `emit(10,…)`
  vs `emit("abc",…)` sort differently from CouchDB because the prefix
  comparison is string-lexical.
- **Rationale:** Story 12.2 scoped to "simple lexicographic JSON-string
  compare" as MVP; a stable typed comparator is non-trivial and was
  deferred so Story 12.2's MVP could ship. Story 14 may revisit as part
  of the byte-equality harness.
- **Tracking:** [`deferred-work.md` → Story 12.2 implementation](../_bmad-output/implementation-artifacts/deferred-work.md#deferred-from-story-12-2-implementation-2026-04-17);
  Epic 12 retrospective § "Dependencies on Epic 12".

### 2. `_approx_count_distinct` reduce

- **Behavior:** the built-in `_approx_count_distinct` reduce operation
  used in map/reduce views.
- **CouchDB 3.x behavior:** Erlang implementation uses a HyperLogLog
  sketch. Cost is O(log N) memory; result is an approximation with a
  bounded variance.
- **IRISCouch behavior:** `IRISCouch.View.BuiltinReduce.ApplyApproxCountDistinct`
  stores every distinct value in a local array and returns the exact
  distinct count. Cost is O(N) memory; result is more accurate than
  CouchDB's but the variance-bound guarantee no longer holds.
- **Rationale:** an exact distinct count is byte-identical to CouchDB
  for small datasets and strictly more accurate for large ones; the
  divergence only matters when adopters rely on HLL's variance-bound
  property or memory profile. True HLL is planned for Epic 14.
- **Tracking:** [`deferred-work.md` → Story 12.2 implementation](../_bmad-output/implementation-artifacts/deferred-work.md#deferred-from-story-12-2-implementation-2026-04-17);
  Epic 12 retrospective § "Dependencies on Epic 12".

### 3. View query parameters (Story 12.2a scope cut)

- **Behavior:** query-string parameters on `GET /{db}/_design/{ddoc}/_view/{view}`.
- **CouchDB 3.x behavior:** supports `reduce`, `include_docs`, `group`,
  `group_level`, `startkey`, `endkey`, `inclusive_end`, `startkey_docid`,
  `endkey_docid`, `key`, `keys`, `limit`, `skip`, `descending`, `stable`,
  `update`, `update_seq` per `api/ddoc/views.rst`.
- **IRISCouch behavior:**
  - **Supported:** `reduce`, `include_docs`.
  - **Silently ignored (deferred to Story 12.2a):** `group`, `group_level`,
    `startkey`, `endkey`, `inclusive_end`, `startkey_docid`, `endkey_docid`,
    `key`, `keys`, `limit`, `skip`, `descending`, `stable`, `update`,
    `update_seq`.

  Clients that submit the ignored parameters receive the full, ungrouped,
  unfiltered, unpaginated result set. No 501; no warning header; no query
  rejection. The full list and per-parameter behavior is in the
  [compatibility matrix](compatibility-matrix.md) under "View query
  parameters". Pagination and range filtering must be done client-side
  until Story 12.2a lands.
- **Rationale:** Story 12.2 MVP shipped the map/reduce pipeline and
  built-in reduces; each additional parameter (key-range scanning,
  grouped reduction, descending sort) has enough surface that bundling
  them all into 12.2 would have exceeded its session budget. Cut was
  taken explicitly with a documented landing place (Story 12.2a).
- **Tracking:** [`deferred-work.md` → Story 12.2 implementation](../_bmad-output/implementation-artifacts/deferred-work.md#deferred-from-story-12-2-implementation-2026-04-17);
  [compatibility matrix § Views — query parameters](compatibility-matrix.md);
  Story 12.2a to be created.

### 4. JSRuntime `Python` backend deferred

- **Behavior:** the `JSRUNTIME=Python` configuration value, intended to
  run user JavaScript via IRIS embedded Python + `quickjs` / `py_mini_racer`.
- **CouchDB 3.x behavior:** n/a — CouchDB runs a SpiderMonkey or Mango
  Erlang VM regardless of Python availability. A pure-Python JS runtime
  is IRISCouch-specific.
- **IRISCouch behavior:** setting `^IRISCouch.Config("JSRUNTIME") =
  "Python"` returns `501 not_implemented` at config-load time. The
  `Subprocess` backend (Node / Bun / Deno) is the sole shipped JS path
  at α/β. Operators needing JS must either configure `Subprocess` with a
  Node-class interpreter or stay on `JSRUNTIME=None` and accept 501 on
  view / validate / custom-filter endpoints.
- **Rationale:** Story 12.4 was deferred on 2026-04-17 because the dev
  host's IRIS image shipped without embedded Python (`PythonRuntimeLibrary`
  CPF field empty; installed Python 3.13 rejected by IRIS for missing
  PE VERSIONINFO; `%SYS.Python.Import("sys")` threw). Rather than gate
  α/β on a Python-enabled IRIS rebuild, `Subprocess` was chosen as the
  sole supported α/β JS path. Story 12.4 has architectural guard-rails
  defined for when it resumes (zero `[Language = python]` in shipped
  classes; `<FileCopy>` bridge; operator-prerequisite `irispip`; CI gate
  on Python-less IRIS image) — see PRD [NFR-M9](../_bmad-output/planning-artifacts/prd.md)
  "Python-Optional Compilation".
- **Tracking:** sprint-status.yaml `12-4-python-jsruntime-backend: deferred`;
  Epic 12 retrospective § "Story 12.4 — Python blocker"; [README § JavaScript
  Runtime Requirements](../README.md#javascript-runtime-requirements).

### 5. Server identity version and `features` array

- **Behavior:** `GET /` welcome envelope.
- **CouchDB 3.x behavior:** a typical CouchDB 3.3.3 install returns
  `{"couchdb":"Welcome","version":"3.3.3","git_sha":"…","uuid":"…","features":["access-ready","partitioned","pluggable-storage-engines","reshard","scheduler"],"vendor":{"name":"The Apache Software Foundation"}}`.
- **IRISCouch behavior:** returns
  `{"couchdb":"Welcome","vendor":{"name":"IRISCouch"},"version":"0.1.0"}`.
  The `version` string is IRISCouch's own semantic-version stamp, not
  `3.3.3`. The `features` array is absent. Automated adopter test suites
  that branch on `features` entries (`partitioned`, `scheduler`, etc.)
  must treat the array as empty.
- **Rationale:** IRISCouch's compatibility anchor is the CouchDB wire
  protocol, not its version-string surface. Pinning `version` to CouchDB's
  would falsely imply release-for-release parity (e.g., reshard / access
  features that IRISCouch does not ship). `features` may land in a later
  release once the set of "yes, IRISCouch has that CouchDB capability"
  claims is stable; today it would be misleading.
- **Tracking:** Story 13.1 Task 0 pre-flight probe (see Story 13.1
  artifact `_bmad-output/implementation-artifacts/13-1-getting-started-guide-and-compatibility-matrix.md`);
  [compatibility matrix § Server metadata](compatibility-matrix.md).

### 6. `_security` object shape for unset databases

- **Behavior:** `GET /{db}/_security` on a database whose security
  configuration has not been written.
- **CouchDB 3.x behavior:** returns `{}` (empty object).
- **IRISCouch behavior:** returns the full default object
  `{"admins":{"names":[],"roles":[]},"members":{"names":[],"roles":[]}}`
  verbatim. This is strictly more useful to clients that consume the
  shape — they get the same structure regardless of whether
  `_security` has been set — but it is a wire deviation.
- **Rationale:** `SecurityService.normalizeSecurity()` in the admin UI
  accepts both shapes, and no known client (PouchDB, replicator, nano)
  depends on the `{}` form; the IRISCouch shape simplifies adopter code.
  Would be tightened if strict CouchDB wire-compat becomes an NFR.
- **Tracking:** [`deferred-work.md` → Story 11.2 Security Configuration View](../_bmad-output/implementation-artifacts/deferred-work.md#deferred-from-story-112----security-configuration-view-2026-04-14).

### 7. `_changes?feed=continuous` and `feed=eventsource`

- **Behavior:** long-lived streaming changes feeds.
- **CouchDB 3.x behavior:** the `continuous` feed streams one JSON
  document per line with no end; `eventsource` streams Server-Sent
  Events formatted as `data: {…}\n\n`. Clients hold the connection open
  indefinitely and receive changes as they happen.
- **IRISCouch behavior:** returns `out of scope with reason` in the
  compatibility matrix; the `/_changes` endpoint rejects `feed=continuous`
  and `feed=eventsource`. `normal` and `longpoll` feeds are fully
  supported. CSP Gateway (the HTTP front-end in front of `%CSP.REST`)
  buffers response bodies before flushing — making streaming impractical
  at the HTTP layer.
- **Rationale:** this is a **CSP-layer deviation**, not a CouchDB-protocol
  deviation. Epic 14 Story 14.1 plans a standalone TCP listener that
  bypasses CSP buffering, restoring full continuous/eventsource support.
  Until then, adopters that need live streaming must poll via `longpoll`
  (repeating `?feed=longpoll&since=<seq>` with the last returned `last_seq`).
- **Tracking:** [compatibility matrix § Changes feeds](compatibility-matrix.md);
  Epic 14 Story 14.1 plan.

### 8. `validate_doc_update` runs against replication writes

- **Behavior:** document writes arriving via `_bulk_docs?new_edits=false`
  or `_replicate` (i.e., the replication protocol's write path).
- **CouchDB 3.x behavior:** `couch_db.erl::validate_doc_update_int` short-
  circuits with `{internal_repl, _} -> ok` when the write is an internal
  replication write. Validate functions do NOT run on replication writes;
  only on direct client writes.
- **IRISCouch behavior:** every `validate_doc_update` function in every
  `_design/*` document runs on every write, regardless of whether the
  write is direct or arriving via replication. There is no
  replication short-circuit.
- **Rationale:** deliberate. Short-circuiting replication means a
  compromised or hostile peer can push writes that would be rejected
  directly. Running validate for every write is a defense-in-depth
  posture; the trade-off is that replicator throughput is limited by
  validate function latency.
- **Tracking:** [compatibility matrix § Design Documents — `validate_doc_update`](compatibility-matrix.md)
  row captures the same guarantee as test-asserted.

### 9. `JSRUNTIMEMAXRSSMB` memory cap softness on Windows

- **Behavior:** the memory-cap enforcement for `JSRUNTIME=Subprocess` Node
  / Deno children.
- **CouchDB 3.x behavior:** n/a (different architecture) — CouchDB runs
  the JS VM inside its own Erlang process and caps JS heap via the VM's
  own `--max-old-space-size` style flag.
- **IRISCouch behavior:** `JSRUNTIMEMAXRSSMB` is honored only as a soft
  target by pool health checks on Windows. Hard OS-level kill-on-
  commit-exceed requires a PowerShell helper with P/Invoke or a signed
  native helper. On Linux the same cap is enforceable via `ulimit -v`
  wrapping; the Story 12.5 shipped code only sets the soft target. A
  runaway allocator on Windows is caught only by `JSRUNTIMETIMEOUT`,
  not by the memory cap.
- **Rationale:** Windows Job Objects for memory capping require native-
  code signing; scope-cut from Story 12.5 and tracked as Story 12.5a.
  Operators on Windows should rely on `JSRUNTIMETIMEOUT` for runaway
  detection until 12.5a ships.
- **Tracking:** [`deferred-work.md` → Story 12.5 → 12.5a](../_bmad-output/implementation-artifacts/deferred-work.md#deferred-from-code-review-of-12-5-incremental-view-indexing-caching-and-sandbox-safety-2026-04-17);
  [`documentation/js-runtime.md` § Pool](js-runtime.md).

### 10. Design-doc render endpoints (`_show` / `_list` / `_update` / `_rewrite`)

- **Behavior:** the design-doc render endpoints.
- **CouchDB 3.x behavior:** execute user-supplied `shows`, `lists`,
  `updates`, or `rewrites` functions. When no function of the named kind
  exists, CouchDB returns `404 not_found`.
- **IRISCouch behavior:** the [compatibility matrix](compatibility-matrix.md)
  classifies these as `501 in default config` on both `None` and
  `Subprocess` backends, because most CouchDB deployments have
  migrated away from them in favor of Mango + client-side rendering. The
  shipped runtime currently returns `404 not_found` (no dispatcher
  registered); a follow-up backend-cleanup story will register the
  routes and return a canonical `501` envelope that names `JSRUNTIME`
  (same shape as `JSRuntimeHttpTest.TestNoneBackendThrowsCanonicalEnvelope`).
- **Rationale:** deferred until a concrete adopter asks. No known PouchDB /
  replicator / Cloudant workload uses these endpoints.
- **Tracking:** [`deferred-work.md` → Story 13.1 review](../_bmad-output/implementation-artifacts/deferred-work.md#deferred-from-code-review-of-13-1-getting-started-guide-and-compatibility-matrix-2026-04-18).

### 11. `_utils/` is the IRISCouch Angular admin UI, not Fauxton

- **Behavior:** the admin UI served at `/_utils/`.
- **CouchDB 3.x behavior:** Fauxton — a React SPA bundled with CouchDB —
  is served. Customizations and plugins target the Fauxton extension
  points.
- **IRISCouch behavior:** `/_utils/` serves the IRISCouch-built Angular
  admin UI (Epic 10 + Epic 11 + Epic 11.5 hosting). Same slot,
  different SPA; no Fauxton extension points are honored. The UI covers
  the same operator actions (database browse, document CRUD, design-
  doc editing, security configuration, revision history) and requires
  the `IRISCouch_Admin` role.
- **Rationale:** intentional. Fauxton is a React SPA with its own build
  pipeline and maintenance model; redistributing it inside IRIS would
  add a JavaScript bundle dependency the project does not want. Angular
  matches IRISCouch's tooling and is first-party maintained.
- **Tracking:** [compatibility matrix § `/_utils/`](compatibility-matrix.md);
  Epic 10 + Epic 11 story files. Not a defect.

---

## Informational

These items either affect a narrow audience, are cosmetic, or are
documented for completeness. They pass the operator-observable filter
in a literal sense but are rarely load-bearing in a real adopter
evaluation.

### `sizes.external` / `sizes.active` report allocated bytes

- **Where:** `GET /{db}` response envelope.
- **CouchDB 3.x:** `sizes.external` is pre-compression JSON size;
  `sizes.active` is live (non-deleted) data size; consumers that
  compute a compression ratio divide `sizes.external / sizes.file` and
  expect a value > 1.0 on typical databases.
- **IRISCouch:** all three values (`file`, `external`, `active`) report
  allocated bytes for the `IRISCouch.*` global subtrees via
  `%Library.GlobalEdit.GetGlobalSizeBySubscript`. A compression-ratio
  consumer would see ~1.0.
- **Audience:** monitoring tools and replicators computing
  compression heuristics. Admin UI and typical adopter flows unaffected.
- **Tracking:** [`deferred-work.md` → Story 11.0 implementation](../_bmad-output/implementation-artifacts/deferred-work.md).

### `HttpClient` replication source TLS config is hardcoded

- **Where:** outbound HTTPS replication from IRISCouch to a CouchDB peer.
- **CouchDB 3.x:** n/a (different SSL stack).
- **IRISCouch:** `IRISCouch.Net.HttpClient.Request` uses SSL config
  `ISC.FeatureTracker.SSL.Config` by default. Operators replicating
  over HTTPS to a remote CouchDB must either create that SSL config
  name on their IRIS instance or accept that HTTPS replication will
  fail until the config is made configurable.
- **Audience:** only operators running `remote` replication endpoints
  over HTTPS. `local` replication and HTTP replication unaffected.
- **Tracking:** [`deferred-work.md` → code review of 8-4](../_bmad-output/implementation-artifacts/deferred-work.md).

### JWT `iat` / `exp` claims on non-UTC servers

- **Where:** JWT issuance and validation.
- **CouchDB 3.x:** standard JWT timestamps (seconds since Unix epoch UTC).
- **IRISCouch:** `IRISCouch.Auth.JWT.UnixTimestamp()` computes the epoch
  from `$Horolog` (local server time). On a UTC-configured server this
  matches CouchDB; on a non-UTC server the `iat` / `exp` claims are
  offset by the server's timezone delta. Valid-within-issuer is fine;
  cross-issuer replication to a UTC-CouchDB peer on a non-UTC IRIS
  server could observe token rejection at token-lifetime edges.
- **Audience:** multi-region operators running IRIS in a non-UTC
  timezone. Default IRIS installs typically run in UTC; this is a
  known, scoped edge case.
- **Tracking:** [`deferred-work.md` → code review of 10-0](../_bmad-output/implementation-artifacts/deferred-work.md).

---

## When you find a deviation not listed here

File it in `deferred-work.md` under a Story-13.2 entry with severity
HIGH if operator-observable (a supported CouchDB client can see the
difference) and severity LOW otherwise. The next release's docs-update
pass will promote the HIGH entry to this file with rationale. Do not
fix IRISCouch's behavior inline just because something diverges — the
divergence may be deliberate (see entries #5, #7, #8, #11 above). Route
through the deviation log first; fix the behavior only if the review
finds the deviation is unintentional.
