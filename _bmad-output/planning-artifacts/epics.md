---
stepsCompleted: ["step-01-validate-prerequisites", "step-02-design-epics", "step-03-create-stories", "step-04-final-validation"]
inputDocuments:
  - "_bmad-output/planning-artifacts/prd.md"
  - "_bmad-output/planning-artifacts/architecture.md"
  - "_bmad-output/planning-artifacts/ux-design-specification.md"
---

# iris-couch - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for iris-couch, decomposing the requirements from the PRD, UX Design, and Architecture requirements into implementable stories.

## Requirements Inventory

### Functional Requirements

FR1: Operators and clients can create a database via HTTP PUT on the database path.
FR2: Operators and clients can delete a database via HTTP DELETE on the database path.
FR3: Clients can list all databases visible to their credentials via `GET /_all_dbs`.
FR4: Clients can retrieve per-database metadata (document count, update sequence, disk size, purge sequence, etc.) via `GET /{db}`.
FR5: Operators can configure a per-database revision retention limit via `PUT /{db}/_revs_limit`.
FR6: Operators can trigger database compaction via `POST /{db}/_compact`.
FR7: Clients can request a full commit via `POST /{db}/_ensure_full_commit`.
FR8: The system returns 201 Created on successful database creation and 412 Precondition Failed with error slug `file_exists` if the database already exists.
FR9: Clients can create a document with a server-generated UUID via `POST /{db}`.
FR10: Clients can create or update a document with a client-specified ID via `PUT /{db}/{docid}`.
FR11: Clients can retrieve a document by ID via `GET /{db}/{docid}`, with optional `?rev=`, `?revs=`, `?revs_info=`, `?conflicts=`, and `?local_seq=` query parameters.
FR12: Clients can delete a document via `DELETE /{db}/{docid}?rev=N-hex` or PUT with `_deleted: true`, producing a tombstone revision.
FR13: The system enforces optimistic concurrency: updates with stale `_rev` values are rejected with 409 Conflict and error slug `conflict`.
FR14: The system detects and preserves concurrent-update conflicts, storing all conflicting revisions and exposing them via the `_conflicts` field when queried with `?conflicts=true`.
FR15: The system computes the winning revision for a document deterministically using CouchDB's published winning-rev algorithm.
FR16: Clients can submit multiple document writes in a single request via `POST /{db}/_bulk_docs`.
FR17: Clients can submit replication-format writes via `POST /{db}/_bulk_docs` with `new_edits=false`, preserving source revision IDs without generating new ones.
FR18: Clients can retrieve multiple documents by ID in a single request via `POST /{db}/_bulk_get`, including specific revisions and revision history.
FR19: Clients can retrieve a document's revision tree and open (leaf) revisions via `?open_revs=all` or `?open_revs=["N-hex",...]`.
FR20: The system rejects user-created top-level fields beginning with underscore (except the documented metadata set) with 400 Bad Request and error slug `doc_validation`.
FR21: Clients can list all documents in a database via `GET /{db}/_all_docs` with pagination (`limit`, `skip`), key-range filtering (`startkey`, `endkey`), and included-docs (`include_docs=true`).
FR22: Clients can list specific documents in a database via `POST /{db}/_all_docs` with a `keys` array.
FR23: Clients can subscribe to a database's changes feed in `feed=normal` mode (single response with the current change snapshot).
FR24: Clients can subscribe to a database's changes feed in `feed=longpoll` mode (request blocks until a new change or timeout).
FR25: Clients can filter a changes feed by specific document IDs via the `_doc_ids` built-in filter.
FR26: Clients can filter a changes feed by Mango selector via the `_selector` built-in filter.
FR27: Clients can filter a changes feed to design documents only via the `_design` built-in filter.
FR28: Clients can subscribe to a changes feed in `feed=continuous` mode (delivered via separate TCP listener at milestone gamma).
FR29: Clients can subscribe to a changes feed in `feed=eventsource` mode (delivered via separate TCP listener at milestone gamma).
FR30: The system assigns a monotonically increasing sequence number to every change, atomically per database.
FR31: Clients can attach binary content to a document inline via base64-encoded `_attachments.<name>.data` in a JSON body.
FR32: Clients can attach binary content via `multipart/related` upload in a single `PUT /{db}/{docid}` request.
FR33: Clients can attach binary content via standalone `PUT /{db}/{docid}/{attname}?rev=N-hex`.
FR34: Clients can retrieve an attachment's raw bytes via `GET /{db}/{docid}/{attname}`.
FR35: Clients can retrieve a document with selected attachments via `multipart/mixed` response when requesting with `Accept: multipart/mixed` and `?open_revs=...`.
FR36: Clients can request attachment retrieval only for revisions newer than a given rev via `?atts_since=["N-hex",...]`.
FR37: Clients can request attachments as stubs only (metadata without content) via `?attachments=false` (default).
FR38: Clients can request attachment content inclusion via `?attachments=true`.
FR39: The system stores attachment content as binary streams without buffering entire attachment bodies in process memory.
FR40: The system computes and stores MD5 digests for every attachment; digests round-trip through replication unchanged.
FR41: Clients can query documents via `POST /{db}/_find` with a Mango selector, including `fields`, `sort`, `limit`, `skip`, `use_index`, and `r` options.
FR42: Clients can create Mango indexes of type `json` on arbitrary document fields via `POST /{db}/_index`.
FR43: Clients can list existing Mango indexes via `GET /{db}/_index`.
FR44: Clients can delete a Mango index via `DELETE /{db}/_index/{ddoc}/{type}/{name}`.
FR45: Clients can inspect the selected query plan for a Mango query via `POST /{db}/_explain`.
FR46: Clients can create Mango indexes that match only a subset of documents via `partial_filter_selector`.
FR47: The system supports Mango selector operators: equality, `$gt`, `$gte`, `$lt`, `$lte`, `$ne`, `$in`, `$nin`, `$exists`, `$type`, `$and`, `$or`, `$nor`, `$not`, `$regex`, `$elemMatch`, `$allMatch`.
FR48: The system falls back to a full scan when a selector cannot be planned against an existing index, returning correct results with reduced performance.
FR49: Clients can query design-document views via `GET /{db}/_design/{ddoc}/_view/{view}` when a JSRuntime backend is enabled.
FR50: The system supports built-in reduces `_sum`, `_count`, `_stats`, and `_approx_count_distinct` on view results.
FR51: Clients can retrieve revision difference sets via `POST /{db}/_revs_diff` to determine which revisions a target already holds.
FR52: Clients can retrieve multiple documents with specific revisions in bulk via `POST /{db}/_bulk_get` with `revs=true&attachments=true`.
FR53: Clients can persist and retrieve replication checkpoints via `PUT /{db}/_local/{id}` and `GET /{db}/_local/{id}`.
FR54: The system excludes `_local/` documents from the changes feed, from `_all_docs`, and from replication to peers.
FR55: Operators can configure continuous replication jobs via documents in the `_replicator` database.
FR56: The system writes replication state updates (`_replication_id`, `_replication_state`, `_replication_state_time`, `_replication_stats`) back to the `_replicator` document as replication progresses.
FR57: The system computes deterministic `replication_id` values that survive process restart and resume replication from the last checkpoint.
FR58: The system performs bidirectional replication against a real Apache CouchDB 3.x peer using the CouchDB replication protocol, including `_revs_diff`, `_bulk_get`, `open_revs`, and `_local/` checkpoints.
FR59: The system generates revision hashes deterministically from document content using a JSON-canonical MD5 algorithm that is replication-protocol sufficient, not byte-identical to CouchDB's Erlang ETF hash.
FR60: Clients can authenticate via HTTP Basic auth with credentials validated against the IRIS user directory.
FR61: Clients can authenticate via `POST /_session` and receive an HMAC-signed `AuthSession` cookie valid for subsequent requests.
FR62: Clients can retrieve their current session information via `GET /_session`.
FR63: Clients can log out by `DELETE /_session`, invalidating the current session cookie.
FR64: Clients can authenticate via JWT bearer tokens against operator-configured issuers and public keys.
FR65: Clients can authenticate via proxy auth headers (`X-Auth-CouchDB-UserName`, `X-Auth-CouchDB-Roles`, `X-Auth-CouchDB-Token`) from trusted upstreams configured with a shared secret.
FR66: Operators can manage users via documents in the `_users` database, which synchronize one-to-one to IRIS user records.
FR67: The system hashes `_users` passwords using PBKDF2 via IRIS primitives and stores hashed credentials in the IRIS user record, not in the `_users` document body.
FR68: Operators can set per-database admin and member lists (names and roles) via `PUT /{db}/_security`.
FR69: The system enforces `_security` admin/member access restrictions on every request before document logic executes.
FR70: The system emits an HTTP 401 Unauthorized with error slug `unauthorized` when authentication is missing or invalid.
FR71: The system emits an HTTP 403 Forbidden with error slug `forbidden` when authentication succeeds but authorization fails.
FR72: Operators can select the JSRuntime backend (`None`, `Subprocess`, or `Python`) at IRISCouch configuration time.
FR73: The default JSRuntime backend at installation is `None`.
FR74: The system accepts, stores, and replicates design documents regardless of the selected JSRuntime backend.
FR75: With `JSRuntime.None`, any request that would require executing user JavaScript returns 501 Not Implemented with error slug `not_implemented` and a reason string that names the subsystem and points at enablement documentation.
FR76: With `JSRuntime.Subprocess` enabled, the system executes user-supplied map-reduce view functions (`map` and `reduce`) against Node, Bun, Deno, or couchjs via `$ZF(-1)` subprocess invocation using the couchjs line protocol.
FR77: With `JSRuntime.Subprocess` enabled, the system executes user-supplied `validate_doc_update` hook functions.
FR78: With `JSRuntime.Subprocess` enabled, the system executes user-supplied `_changes` filter functions.
FR79: With `JSRuntime.Python` enabled, the system executes the same user JavaScript functions via an embedded Python runtime with a QuickJS binding.
FR80: The system builds and maintains incremental view indexes when a JSRuntime backend is enabled, updating indexes on document write rather than on query.
FR81: The system serves view query results with ETag-based response caching so unchanged query results return 304 Not Modified.
FR82: The system enforces per-invocation timeouts and memory-pressure-driven restarts on JSRuntime subprocesses so a misbehaving user function cannot hang the server.
FR83 [alpha]: Operators can access a built-in administration UI at the webapp's `_utils` path without installing Fauxton or any separate tooling.
FR84 [alpha]: The administration UI is a TypeScript + Angular single-page application served as static assets from the IRISCouch webapp.
FR85 [alpha]: Operators can list all databases visible to their credentials via the admin UI.
FR86 [alpha]: Operators can create a database via the admin UI.
FR87 [alpha]: Operators can delete a database via the admin UI.
FR88 [alpha]: Operators can view per-database metadata (document count, update sequence, disk size) via the admin UI.
FR89 [alpha]: Operators can browse documents in a database with pagination via the admin UI.
FR90 [alpha]: Operators can view individual document details (body + metadata + `_rev`) via the admin UI.
FR91 [alpha]: Operators can view design documents stored in a database via the admin UI (read-only).
FR92 [beta]: Operators can create, edit, and delete design documents via the admin UI.
FR93 [alpha]: Operators can view `_security` admin/member configuration for a database via the admin UI (read-only).
FR94 [beta]: Operators can edit `_security` admin/member configuration via the admin UI.
FR95 [gamma]: Operators can view a document's revision history via the admin UI.
FR96: Operators can scrape Prometheus / OpenTelemetry metrics from a dedicated endpoint, exposing at minimum: request counts per endpoint class, request latency histograms, replication throughput (documents/sec and bytes/sec), `_changes` feed lag, Mango index hit rate, and per-status-code error counters.
FR97: The system emits a structured `%SYS.Audit` event for every document write (create, update, delete) including document ID, revision, database, user identity, and timestamp.
FR98: The system emits a structured `%SYS.Audit` event for every authentication attempt (success and failure).
FR99: The system emits a structured `%SYS.Audit` event for every `_security` configuration change.
FR100: The system emits a structured `%SYS.Audit` event for every `_users` database write.
FR101: The system emits a structured `%SYS.Audit` event for replication session start and completion, including source, target, sequence count processed, and byte count transferred.
FR102: All IRISCouch state (document bodies, revision trees, changes feed, attachments, Mango projections, `_local/` checkpoints, `_users` records) lives within the IRIS namespace the webapp is mounted in, so standard IRIS mirroring, backup, and journal replay cover it automatically.
FR103: Replication checkpoints survive a hard process kill and IRIS restart with correct sequence continuity; a resumed replication picks up where the killed replication left off.
FR104: After an IRIS mirror failover, replication resumes from the last checkpoint on the promoted mirror with correct sequence continuity.
FR105: Error responses include a `reason` string that names the subsystem and the specific failure mode, not a generic server-error message.
FR106: Adopters can install IRISCouch into an existing IRIS instance with `zpm "install iris-couch"` as a single command.
FR107: Adopters can install IRISCouch manually via ObjectScript `$System.OBJ.ImportDir` as a documented fallback.
FR108: Operators can mount the IRISCouch webapp at a configurable path, with `/iris-couch/` as the documented default.
FR109: The default installation has no mandatory external dependencies beyond IRIS itself -- no Node.js, no Python, no couchjs binary, no Erlang runtime.
FR110: The repository publishes a Getting Started walkthrough that takes a new adopter from install to first successful PouchDB replication in under one hour.
FR111: The repository publishes a live compatibility matrix listing every CouchDB 3.x HTTP API endpoint with support status (`supported`, `supported with caveat`, `501 in default config`, `out of scope with reason`) and the verification method used.
FR112: The repository publishes a deviation log listing every observable difference between IRISCouch and Apache CouchDB with rationale for each deviation.
FR113: The repository publishes a migration playbook covering pre-migration checklist, install, replicate-in, validation, optional dual-write, cutover, source drain, and symmetric rollback.
FR114: The repository publishes a troubleshooting runbook covering at minimum: replication lag, checkpoint corruption, stuck conflicts, attachment stream failures, and JS sandbox errors.
FR115: The repository ships six working examples in its `examples/` directory: `hello-document`, `pouchdb-sync`, `replicate-from-couchdb`, `mango-query`, `attachment-upload`, and `jsruntime-subprocess-node`. Broken examples block releases.

### Non-Functional Requirements

NFR-P1: Document write latency (median POST/PUT) is no worse than 2x the median latency of Apache CouchDB 3.3.3 running the same workload on the same hardware.
NFR-P2: Document read latency (median GET) is no worse than 1.5x the median latency of Apache CouchDB 3.3.3 on the same workload.
NFR-P3: Mango `_find` latency with a selected index is no worse than 2x the median response time of Apache CouchDB 3.3.3 running the same query against an equivalent index.
NFR-P4: Full bidirectional replication against a real Apache CouchDB 3.3.3 peer over customer zero's databases (~10,000 documents, ~500 MB) completes in no worse than 2x the same replication between two CouchDB peers on the same hardware.
NFR-P5: A bulk write of 1,000 documents via `_bulk_docs` completes in a time consistent with document-write parity (NFR-P1) applied to the batch.
NFR-P6: A document write is visible to a waiting `feed=longpoll` client within 500 ms under zero contention, and within 2 seconds under customer-zero-representative load.
NFR-P7: A Mango `_find` query matching a just-written document sees it with zero staleness (read-after-write consistency via synchronous CQRS projection).
NFR-P8: Uploading or downloading a 500 MB attachment does not cause IRIS process RSS to grow proportionally to attachment size; memory usage is bounded by stream buffer size (kilobytes).
NFR-R1: A replication bug that could corrupt a conflict tree (divergent revision histories, dropped conflicts, silent loss of winning-rev calculation) is never shippable; any suspected corruption halts the release.
NFR-R2: Every document write (body + rev tree + changes feed sequence + Mango projection + attachments) is atomic within a single journaled IRIS transaction; no partial-write observable state exists.
NFR-R3: Crash recovery is whatever IRIS journal replay provides; a hard process kill during a write leaves the database consistent after IRIS restart.
NFR-R4: `_local/` checkpoint documents survive hard process kill plus IRIS restart with correct sequence continuity.
NFR-R5: After IRIS mirror failover, replication checkpoints survive with correct sequence continuity on the promoted mirror; replication resumes without rewinding or duplicating work (gated at gamma).
NFR-R6: Any bug found during customer zero migration or by an external adopter adds a regression test to the differential HTTP harness before the fix ships.
NFR-R7: IRISCouch is available whenever its hosting IRIS instance is available; the product does not add downtime windows beyond IRIS's own operational requirements.
NFR-S1: User credentials live exclusively in IRIS's standard user directory; IRISCouch never maintains a shadow credential store.
NFR-S2: Credentials are hashed using PBKDF2 via IRIS primitives with iteration count matching or exceeding CouchDB 3.x defaults (currently 10,000 iterations).
NFR-S3: `AuthSession` cookies are HMAC-signed with a per-instance secret; cookie forgery requires access to the signing secret; tampering is detected on every request.
NFR-S4: TLS termination is handled by `%Service_WebGateway` / CSP Gateway using operator-configured certificates; IRISCouch does not terminate TLS itself and works correctly behind a reverse proxy.
NFR-S5: Every document mutation, every authentication attempt, every `_security` change, every `_users` write, and every replication session emits a `%SYS.Audit` event; an adopter reading only `%SYS.Audit` sees every state-changing action.
NFR-S6: `_security` admin/member checks execute at the HTTP dispatch layer before document logic runs; a denied request never reaches storage code.
NFR-S7: IRISCouch does not initiate outbound network traffic except operator-configured replication sessions and metrics push to an operator-configured OpenTelemetry collector. No update checks, crash reporting, or usage analytics.
NFR-S8: 500 Internal Server Error responses return a generic error envelope to the client; full stack traces are logged to IRIS logs only, never sent to the HTTP client.
NFR-S9: User-supplied JavaScript executed via `JSRuntime.Subprocess` runs in a subprocess with restricted filesystem and network access; per-invocation timeout and memory limits prevent runaway user code from destabilizing IRISCouch.
NFR-SC1: IRISCouch is validated to serve workloads up to customer zero's envelope: approximately 10,000 documents per database, ~500 MB total state, low tens of concurrent writers, and single-digit map-reduce views or filter functions per database.
NFR-SC2: Workloads substantially larger than NFR-SC1's envelope are explicitly not yet validated; this caveat is published in the compatibility matrix and deviation log.
NFR-SC3: When the synchronous Mango SQL projection becomes a write throughput bottleneck, IRISCouch returns 503 Service Unavailable with reason `projection_backpressure` and emits an audit event rather than silently dropping writes or corrupting state.
NFR-SC4: If post-alpha benchmarking shows synchronous projection cannot serve a specific workload, an async projection mode with a bounded lag window is available behind an opt-in feature flag.
NFR-SC5: ECP distributed-cache clustering is supported at gamma; pre-gamma releases are validated on single-server IRIS deployments only.
NFR-O1: Prometheus / OpenTelemetry metrics are updated at least every 10 seconds; a scrape with a 30-second interval is never stale by more than one interval plus metric update lag.
NFR-O2: Metric labels are bounded cardinality (database name permitted, document ID not); operators cannot accidentally create unbounded label cardinality.
NFR-O3: The metrics scrape endpoint is available whenever the HTTP API is available; metric collection failure does not affect the rest of the system.
NFR-O4: Every error response includes a `reason` field that names the subsystem and specific failure mode, never a generic "server error" string.
NFR-O5: Application-level logs emit as structured entries (JSON or key-value) suitable for log aggregation pipelines; plain-text freeform logs are reserved for debug mode.
NFR-O6: `%SYS.Audit` events are written synchronously within the same transaction as the operation they describe.
NFR-A1: The admin UI is fully usable via keyboard; every action can be reached and executed without a pointing device with sensible tab ordering.
NFR-A2: Text/background color combinations in the admin UI meet WCAG AA contrast ratios (4.5:1 normal text, 3:1 large text).
NFR-A3: Angular components use semantic HTML and ARIA attributes; the UI is expected to work with mainstream screen readers (NVDA, VoiceOver, JAWS) on a best-effort basis.
NFR-A4: The admin UI does not use Flash, Silverlight, or any other deprecated plugin technology.
NFR-I1: Every release is gated on 100% pass rate of the three-layer conformance suite (CouchDB JS test suite, PouchDB replication conformance tests, differential HTTP harness against live CouchDB 3.3.3 peer).
NFR-I2: The differential HTTP harness must diff zero bytes on the wire-contract subset (status codes, JSON error envelope shape, sequence token format, checkpoint document shape, `_bulk_get` response structure, `_revs_diff` response structure).
NFR-I3: The compatibility matrix is updated on every release; endpoint status changes must be committed alongside the code change, enforced by CI.
NFR-I4: The smoke-tested client matrix (PouchDB 9.x, CouchDB replicator 3.3.3 + 3.5.x, nano 10.x, @cloudant/cloudant 5.x, Fauxton) is re-run on every release; a failing client blocks the release.
NFR-I5: The HTTP wire contract is stable for the duration a given CouchDB 3.x version is supported upstream; no wire contract changes within a 3.x anchor.
NFR-I6: When Apache CouchDB publishes a new 3.x point release, the IRISCouch conformance harness is updated within one release cycle to include the new version.
NFR-M1: Customer zero's three production databases are exercised against every release before any public tag; a release that breaks customer zero is not published.
NFR-M2: Published documentation artifacts (compatibility matrix, deviation log, migration playbook, troubleshooting runbook, code examples) are updated in the same commit as any code change that affects them; CI enforces link validity and example compilation.
NFR-M3: The troubleshooting runbook covers the top five incident classes at alpha; new incident classes from customer zero or external adopters become new runbook entries before the next release.
NFR-M4: Every observable difference between IRISCouch and Apache CouchDB is recorded in the deviation log with a rationale; an unlogged deviation is a release-blocking defect.
NFR-M5: IRISCouch is Apache 2.0 licensed and any tagged release remains forkable and self-documented; if the project is shelved, the final release runs, documentation describes its behavior, and code is readable for a new maintainer.
NFR-M6: All public ObjectScript classes carry `///` doc comments on every method; private implementation classes require class-level purpose comments.
NFR-M7: The conformance suite must run to completion on every release candidate; skipping the suite for a release is explicitly forbidden.
NFR-M8: Release cadence is quality-gated, not calendar-gated; a release ships when the conformance suite is green, customer zero is unharmed, and committed milestone scope is complete.

### Additional Requirements

- **No starter template** -- Phase 0 manual scaffold with `IRISCouch.*` package prefix, `^IRISCouch.*` global prefix, `%CSP.REST` dispatcher, ZPM `module.xml`, and `%UnitTest.TestCase`
- Phase 0 exit criterion: `GET /` returns valid CouchDB welcome JSON, `/_uuids?count=3` returns hex UUIDs, ZPM package compiles cleanly on fresh IRIS instance
- Angular Admin UI uses `ng new` minimal scaffold with `--style=css --routing --ssr=false --skip-tests=false`, plus `@angular/cdk`
- ZPM (`module.xml`) is the package distribution mechanism; manifest references all ObjectScript classes and committed `ui/dist/browser/` static assets mapped to `/_utils/`
- Angular SPA is pre-compiled and committed to `ui/dist/browser/` -- adopters never need Node.js at runtime
- CI requires two GitHub Actions workflows: `ci.yml` (ObjectScript compile + unit tests) and `ui-verify.yml` (verify committed `ui/dist/` matches freshly-built `ng build` output)
- IRIS platform features are the operational surface: mirroring for HA, standard backup, journal replay for crash recovery, `%SYS.Audit` for audit, `%Service_WebGateway` for transport auth
- CSP Gateway buffering limitation blocks `feed=continuous` and `feed=eventsource`; mitigation via `%Net.TCPServer` standalone listener deferred to gamma phase
- ObjectScript-only backend: all server logic in InterSystems ObjectScript, no mixed-language implementation
- Angular 19.x + TypeScript 5.x for admin UI (compile-time only)
- Plain CSS with custom-property design tokens (`tokens.css`) -- no SCSS, no CSS-in-JS
- System font stack for proportional text (zero bytes loaded); JetBrains Mono WOFF2 for monospace (~30 KB)
- Angular CDK (not Material) for a11y support; state management via Angular signals or simple RxJS observables -- no NgRx
- Components use `OnPush` change detection strategy
- ~20 Lucide icons as standalone Angular SVG components (hand-picked, not full library)
- Documents stored as raw JSON strings in `^IRISCouch.Docs(db, docId, rev)`, parsed via `%DynamicObject.%FromJSON()` on read
- Process-private cache for parsed `%DynamicObject` during a single request (discarded at end of request)
- Hybrid revision tree structure with three node types in `^IRISCouch.Tree`: "R" (child-to-parent), "L" (leaf index with depth), "W" (cached winning revision)
- Winners projection as `IRISCouch.Projection.Winners` (`%Persistent` class with SQL-queryable table)
- MangoIndex as `IRISCouch.Projection.MangoIndex` (`%Persistent` class with composite index -- no DDL, no class recompilation at runtime)
- Eight named globals: `^IRISCouch.Docs`, `^IRISCouch.Tree`, `^IRISCouch.Changes`, `^IRISCouch.Seq`, `^IRISCouch.Atts`, `^IRISCouch.Local`, `^IRISCouch.DB`, `^IRISCouch.Config`
- All state is namespace-scoped -- no cross-namespace leakage
- Single `%CSP.REST` Router class (`IRISCouch.API.Router`) with full UrlMap as the single HTTP entry point
- 12 per-subsystem Handler classes (ServerHandler, DatabaseHandler, DocumentHandler, ChangesHandler, AttachmentHandler, MangoHandler, ReplicationHandler, AuthHandler, SecurityHandler, DesignHandler, AdminUIHandler, MetricsHandler)
- CouchDB 3.3.3 as primary conformance anchor through beta; 3.5.x added at gamma
- Wire-protocol byte-compatibility on conformance subset
- 13 error slugs from PRD's Error Slug Table used consistently via `IRISCouch.Util.Error.Render()`
- Admin UI communicates exclusively through the same CouchDB-compatible HTTP API -- no private admin API
- No class outside `IRISCouch.API.*` may write to `%response` or read from `%request`
- `DocumentEngine.Save()` is the single write orchestrator wrapping all subsystem calls in one `TSTART`/`TCOMMIT`
- Atomic writes span: document body global, revision tree global, changes feed sequence, Mango SQL projection, attachment streams, and audit event
- `DocumentEngine.SaveWithHistory()` needed for replication `new_edits=false` mode
- No shadow credential store -- auth translates CouchDB auth concepts over IRIS `Security.Users`
- Four auth mechanisms: Session (cookie/HMAC), Basic HTTP, JWT bearer token, X-Auth-CouchDB-* proxy auth
- Authorization enforcement in Router before Handler dispatch via `Auth/Security.cls`
- Prometheus/OTEL metrics refreshed every 10 seconds or less
- Bounded cardinality on metric labels -- coarse endpoint categories only
- Metrics recorded by Router dispatch wrapper, not individual Handlers
- `IRISCouch.Metrics.Record(endpoint, method, status, duration)` signature
- Synchronous audit events via `IRISCouch.Audit.Emit()` with 8 audit event types
- Three-layer conformance test suite gates every release
- External conformance harnesses live in `test/` directory: `differential-harness/`, `pouchdb-conformance/`, `couchdb-js-tests/`
- `IRISCouch.Config` class with class parameter defaults + `^IRISCouch.Config` global overrides; `Config.Get()` as single config access point
- Abstract `IRISCouch.JSRuntime.Sandbox` interface with three concrete implementations: None, Subprocess, Python
- Zero mandatory external dependencies at default -- JSRuntime backends are operator-opt-in
- Uses IRIS `$System.Event` (named events) for longpoll wake signaling
- `IRISCouch.*` package prefix and `^IRISCouch.*` global prefix (locked naming convention)
- All application-generated URLs are root-relative (no webapp mount path in URLs); recommended deployment is reverse proxy presenting IRISCouch at `/` on a dedicated port
- Max ~500 lines per class; one test class per subsystem under `IRISCouch.Test.*`
- ~50 ObjectScript classes specified; ~15-20 Angular components for admin UI
- 5 architectural boundaries enforced: API, Storage, Core, Projection, JSRuntime
- 6 working examples required in `examples/` directory
- 4 documentation artifacts: compatibility-matrix.md, deviations.md, migration.md, troubleshooting.md
- 8 phases (0-7) across 3 milestones (alpha, beta, gamma)
- Implementation sequence is dependency-ordered: Config first, then Router/Handler skeleton, then document storage + rev tree, then DocumentEngine, then changes feed, then projections, then attachments, then audit, then auth/security, then Admin UI (parallel track)

### UX Design Requirements

UX-DR1: Implement a CSS custom-property design token file (`tokens.css`) with exactly 11 neutral gray palette tokens (`--color-neutral-0` through `--color-neutral-900`, cool-biased from `#FFFFFF` to `#12161F`) and 4 semantic color tokens (`--color-error: #C33F3F`, `--color-warn: #B57B21`, `--color-success: #3C7A5A`, `--color-info: #3C5A9E`), with no gradients, no brand color, and no decorative color use.
UX-DR2: Implement a 7-step spacing scale based on a 4px base unit (`--space-1: 4px`, `--space-2: 8px`, `--space-3: 12px`, `--space-4: 16px`, `--space-6: 24px`, `--space-8: 32px`, `--space-12: 48px`) as CSS custom properties, with all component spacing constrained to these values only.
UX-DR3: Implement a 6-step type scale as CSS custom properties (`--font-size-xs: 12px`, `--font-size-sm: 13px`, `--font-size-md: 14px`, `--font-size-lg: 16px`, `--font-size-xl: 20px`, `--font-size-2xl: 24px`) with corresponding line heights, using only two font weights (400 regular, 500 medium).
UX-DR4: Implement a dual-face typography stack: proportional sans-serif using the system font stack loading zero bytes, and a bundled monospace face (JetBrains Mono preferred) as a single WOFF2 file (~30KB, Latin-1 subset) with `font-display: block`, served from `/iris-couch/_utils/`.
UX-DR5: Implement a border-radius token of 2px and a single border color using `--color-neutral-200` for all borders and dividers.
UX-DR6: Implement JSON syntax coloring using only the existing neutral palette: keys in `--color-neutral-700`, string values in `--color-neutral-900`, numbers in `--color-neutral-800`, `true`/`false`/`null` in `--color-info`. No rainbow coloring, no bold, no italic.
UX-DR7: Implement `font-variant-numeric: tabular-nums` for all numeric columns in tables.
UX-DR8: Implement color usage rules enforcing: semantic color appears in 3 or fewer places per screen; backgrounds use only neutral-50/100/200; text uses only neutral-500 through 900; status badges use semantic color at ~10% alpha background with full-opacity text/border.
UX-DR9: Build `AppShell` component as a CSS grid with three areas: sticky header (full width, 48px high), sidenav (240px fixed width), and main content (flex-1 remaining). Two states: authenticated and unauthenticated. Include landmark roles and skip-to-content link.
UX-DR10: Build `SideNav` component as a 240px fixed-width vertical nav with neutral-0 background and neutral-200 right border. Two variants: `global` and `per-database`. Active item shows neutral-100 background with 2px info-colored left border. Arrow-key navigation via CDK FocusKeyManager. `aria-current="page"` on active item.
UX-DR11: Build `Breadcrumb` component as inline flex row of clickable segments separated by neutral-300 `/` characters. Active segment is non-clickable `<span>` with `aria-current="page"`. Wrapped in `<nav aria-label="Breadcrumb">`.
UX-DR12: Build `PageHeader` component with horizontal flex layout: left side contains title block (breadcrumb + title + metadata), right side contains action cluster. Two variants: `list-view` and `detail-view`.
UX-DR13: Build `DataTable` component on `cdk-table` with `cdk/scrolling` for virtual scroll supporting 10k+ rows. 28px row height. Row states: default, hover, focus-visible, selected. Sortable column headers with `aria-sort`. Arrow-key row navigation. Monospace for identifiers, tabular numerals for quantities.
UX-DR14: Build `Pagination` component using `startkey`-based forward/backward controls matching CouchDB `_all_docs` semantics. Shows range indicator with approximate total. No page numbers. `startkey` reflected in URL query parameter.
UX-DR15: Build `Button` component with three variants: `ghost` (default), `primary` (max one per page), `destructive` (only inside ConfirmDialog). Three sizes: 28px compact, 32px standard, 40px primary-page. States: default, hover, focus-visible, active, disabled, loading.
UX-DR16: Build `IconButton` component as 24x24px minimum hit target. Mandatory `aria-label`. Lucide SVG icons marked `aria-hidden="true"`.
UX-DR17: Build `Badge` component as inline `<span>` with 1px semantic-color border, ~10% alpha semantic-color background. Four variants: `info`, `warn`, `error`, `success`.
UX-DR18: Build `TextInput` component wrapping native `<input>` at 32px height. States: default, focus, disabled, error. Real `<label>` above input. `aria-describedby` for hints. `aria-invalid="true"` for error state.
UX-DR19: Build `TextAreaJson` component (beta phase) as resizable `<textarea>` with monospace font, line numbers gutter, error highlighting for invalid JSON.
UX-DR20: Build `Select` component using CDK overlay and ListKeyManager for full keyboard support. `aria-haspopup="listbox"`, `aria-expanded`, `role="listbox"` with `aria-selected`.
UX-DR21: Build `JsonDisplay` component as read-only pre-formatted monospace container with palette-based syntax coloring via custom tokenizer. Two variants: `full` and `compact`. `role="textbox" aria-readonly="true"`.
UX-DR22: Build `EmptyState` component as vertically centered flex column. Two states: `no-content` (with CTA) and `no-results` (with clear-filter affordance).
UX-DR23: Build `ErrorDisplay` component rendering iris-couch JSON error envelopes verbatim. Anatomy: error-colored border, tinted background, HTTP status Badge, error/reason strings, optional Retry button. Two variants: `full` and `inline`. `role="alert" aria-live="assertive"`.
UX-DR24: Build `CopyButton` component using CDK clipboard. On success, icon changes to check for ~600ms. CDK LiveAnnouncer announces "Copied." to screen readers.
UX-DR25: Build `ConfirmDialog` component using CDK overlay + FocusTrap. ~480px wide. Three variants: `create`, `destructive-type-to-confirm`, `destructive-simple`. `role="dialog" aria-modal="true"`. Esc always closes. Focus returns to trigger on close.
UX-DR26: Build `LoginForm` component as centered card (~360px wide) with iris-couch wordmark, two TextInputs, Sign In button, ErrorDisplay. Real `<form>` with `<label>`. Enter submits. Focus on username on first render.
UX-DR27: Hand-pick ~20 icons from Lucide icon set, inline as standalone Angular SVG components. No icon font, no runtime library, no CDN.
UX-DR28: Implement AppShell layout: 240px fixed sidenav, fluid content area, 24px horizontal page padding. No 12-column grid. No breakpoints above 1280px floor.
UX-DR29: Implement database list view with columns: name (monospace), docs (right-aligned), update seq (truncated), size (human-readable). Sortable. Default sort: name ascending. Whole row clickable.
UX-DR30: Implement per-database document list with columns: `_id` (monospace), `_rev` (truncated to 8 chars). Design documents with `[design]` badge. Tombstoned with `[deleted]` badge. Filter bar with `startkey`/`endkey` prefix matching, 150ms debounce.
UX-DR31: Implement document detail view: header zone (breadcrumb, `_id`, `_rev`, badges), body zone (full JSON via JsonDisplay), attachment zone (conditional list with download links).
UX-DR32: Implement design document list view under dedicated per-database nav item. Read-only at alpha.
UX-DR33: Implement `_security` document view under dedicated per-database nav item. Read-only at alpha, editable at beta.
UX-DR34: Implement deep-linkable URLs for every view: `/_utils/db/`, `/_utils/db/{dbname}/`, `/_utils/db/{dbname}/doc/{docid}`, `/_utils/db/{dbname}/design/{ddocname}`, `/_utils/db/{dbname}/security`. All bookmarkable and survive browser refresh.
UX-DR35: Implement stable browser-back behavior: pagination, sort, filter, and scroll position preserved on back-navigation. Real Angular router state.
UX-DR36: Implement left-nav scope switching: global scope shows Databases/Active tasks/Setup/About; per-database scope shows Documents/Design Documents/Security/Revisions.
UX-DR37: Implement `/` keyboard shortcut to focus filter input, `?` to open keyboard shortcut cheatsheet overlay.
UX-DR38: Implement CouchDB cookie-auth flow: POST to `/_session` for login, session cookie, 401 redirects to login with return-URL memory. "signed in as X / sign out" in header.
UX-DR39: Implement in-place verbatim error rendering: 404 shows error envelope where content would appear; 5xx shows envelope in place; 401 redirects to login; network errors show retry button. No toasts, no modals.
UX-DR40: Implement login error display: verbatim error envelope below login form with 401 badge. Error does not reset username field.
UX-DR41: Implement create-database error handling: 412 shows verbatim error in dialog; invalid name shows client-side validation with CouchDB naming rules visible as hint text.
UX-DR42: Implement fetched-at timestamp display: relative format under 60s, absolute ISO-8601 when older. Manual refresh button. No auto-refresh. Existing data visible during refresh.
UX-DR43: Implement 300ms-delayed loading indicator: 2px info-colored progress bar at top of content area after 300ms. Never obscure existing data.
UX-DR44: Implement universal copy-to-clipboard affordance: every `_id`, `_rev`, database name, design doc name, update sequence, and JSON body has a CopyButton.
UX-DR45: Implement type-to-confirm for destructive actions: exact resource name + document count warning. Delete disabled until typed name matches. No secondary confirmation.
UX-DR46: Implement first-install empty state: empty database list shows EmptyState with CTA. Create-database dialog with CouchDB naming rule hint text.
UX-DR47: Implement conflict handling in document detail: `[has conflicts: N]` badge with click-through to inspect conflicting revisions.
UX-DR48: Implement attachment metadata display: compact list with name, content-type, length, digest. Download button linking to HTTP surface.
UX-DR49: Implement keyboard navigation for all interactive elements: Tab/Shift+Tab, Enter, Esc, Space, arrow keys. Skip-to-content link. CDK FocusKeyManager.
UX-DR50: Implement visible focus indicators: 2px outline in `--color-info` at 3px offset on all interactive elements.
UX-DR51: Implement WCAG AA color contrast: body text ~9:1, semantic colors at 4.5:1 for text, 3:1 for UI components. `axe-core` assertions in component specs.
UX-DR52: Implement screen reader support: CDK LiveAnnouncer for navigation and copy actions; `role="alert"` on ErrorDisplay; ARIA table roles; `role="dialog" aria-modal="true"` on ConfirmDialog; real `<label>` elements; `aria-describedby`.
UX-DR53: Implement `prefers-reduced-motion: reduce` support: disable all transitions when active.
UX-DR54: Implement color-never-sole-signal rule: every status color paired with text and/or icon.
UX-DR55: Implement minimum text size floor of 12px.
UX-DR56: Implement `<html lang="en">` on the document root.
UX-DR57: Implement single viewport breakpoint at 1280px: below shows message requesting larger viewport. No other viewport queries.
UX-DR58: Implement fluid content width above 1280px. No max-width containers. Sidenav stays 240px fixed.
UX-DR59: Support current versions of Chrome, Firefox, Safari, and Edge. No IE11. No mobile browsers. Manual cross-browser test at alpha.
UX-DR60: Limit all animations to 150ms maximum. ConfirmDialog open/close max 100ms. CopyButton success icon ~600ms. No animated page transitions.
UX-DR61: Ensure all UI assets are self-contained: no external CDN, no Google Fonts, no analytics. Every byte from `/iris-couch/_utils/`. Must function on air-gapped network.
UX-DR62: Implement alpha phase components in order: (1) tokens.css, (2) Button + IconButton + Badge, (3) AppShell + SideNav + Breadcrumb + PageHeader, (4) TextInput, (5) LoginForm, (6) DataTable + Pagination, (7) JsonDisplay, (8) ErrorDisplay, (9) CopyButton, (10) EmptyState, (11) ConfirmDialog. Total: 15 components for alpha.
UX-DR63: Implement beta phase additions: TextAreaJson, Button destructive variant polish, ErrorDisplay inline variant, ConfirmDialog dirty-textarea awareness.
UX-DR64: Implement gamma phase additions: RevisionTree component (interactive revision tree graph with CDK overlay), optionally Select component.
UX-DR65: Implement automated accessibility testing: every component spec runs `axe-core` assertions. Component tests verify keyboard activation. Integration tests assert correct click counts on happy path.
UX-DR66: Implement manual testing checklist for alpha: keyboard-only smoke test, screen reader smoke test, color-blind simulation, reduced-motion toggle, cross-browser manual test.
UX-DR67: Implement Direction B visual choices: light left-nav, 28px compact table rows, flush header, inline breadcrumb. Token-level escape hatch to bump to 30px/13px if 12px is uncomfortable.
UX-DR68: Implement iris-couch wordmark as text-only monospace string in neutral-600 in header. No logo, no icon, no graphical symbol.
UX-DR69: Enforce prohibited patterns: no toasts; no welcome tours; no dashboard landing (land on database list); no confirmation for reversible actions; no Material default styling; no CouchDB term relabeling; no auto-refresh without indicator; no client-side data masking; no multi-step wizards; no hover navigation; no charting dashboards.

### FR Coverage Map

FR1: Epic 2 - Database creation via HTTP PUT
FR2: Epic 2 - Database deletion via HTTP DELETE
FR3: Epic 2 - List all databases via GET /_all_dbs
FR4: Epic 2 - Per-database metadata via GET /{db}
FR5: Epic 2 - Revision retention limit via PUT /{db}/_revs_limit
FR6: Epic 2 - Database compaction via POST /{db}/_compact
FR7: Epic 2 - Full commit via POST /{db}/_ensure_full_commit
FR8: Epic 2 - Database creation status codes (201/412)
FR9: Epic 3 - Document creation with server-generated UUID
FR10: Epic 3 - Document creation/update with client-specified ID
FR11: Epic 3 - Document retrieval by ID with query parameters
FR12: Epic 3 - Document deletion producing tombstone revision
FR13: Epic 3 - Optimistic concurrency enforcement (409 Conflict)
FR14: Epic 3 - Concurrent-update conflict detection and preservation
FR15: Epic 3 - Deterministic winning revision computation
FR16: Epic 3 - Bulk document writes via _bulk_docs
FR17: Epic 3 - Replication-format writes with new_edits=false
FR18: Epic 3 - Bulk document retrieval via _bulk_get
FR19: Epic 3 - Revision tree and open revisions via open_revs
FR20: Epic 3 - Underscore field validation (doc_validation)
FR21: Epic 3 - All documents listing via _all_docs with pagination
FR22: Epic 3 - Document listing by keys via POST _all_docs
FR23: Epic 4 - Changes feed in feed=normal mode
FR24: Epic 4 - Changes feed in feed=longpoll mode
FR25: Epic 4 - Changes feed _doc_ids filter
FR26: Epic 4 - Changes feed _selector filter
FR27: Epic 4 - Changes feed _design filter
FR28: Epic 14 - Changes feed in feed=continuous mode (gamma)
FR29: Epic 14 - Changes feed in feed=eventsource mode (gamma)
FR30: Epic 4 - Monotonically increasing sequence numbers
FR31: Epic 5 - Inline base64 attachment upload
FR32: Epic 5 - Multipart/related attachment upload
FR33: Epic 5 - Standalone attachment upload
FR34: Epic 5 - Attachment raw bytes retrieval
FR35: Epic 5 - Multipart/mixed attachment response
FR36: Epic 5 - Conditional attachment retrieval via atts_since
FR37: Epic 5 - Attachment stubs (metadata only)
FR38: Epic 5 - Attachment content inclusion
FR39: Epic 5 - Streaming attachment storage
FR40: Epic 5 - MD5 digest computation and storage
FR41: Epic 6 - Mango query via POST /{db}/_find
FR42: Epic 6 - Mango index creation via POST /{db}/_index
FR43: Epic 6 - Mango index listing via GET /{db}/_index
FR44: Epic 6 - Mango index deletion
FR45: Epic 6 - Mango query plan via POST /{db}/_explain
FR46: Epic 6 - Partial filter selector on indexes
FR47: Epic 6 - Full Mango selector operator support
FR48: Epic 6 - Full scan fallback for unindexed queries
FR49: Epic 12 - Design-document view queries
FR50: Epic 12 - Built-in reduce functions (_sum, _count, _stats, _approx_count_distinct)
FR51: Epic 8 - Revision difference sets via _revs_diff
FR52: Epic 8 - Bulk get with specific revisions
FR53: Epic 8 - Replication checkpoint persistence via _local/
FR54: Epic 8 - Local document exclusion from feeds/replication
FR55: Epic 8 - Continuous replication via _replicator database
FR56: Epic 8 - Replication state updates in _replicator document
FR57: Epic 8 - Deterministic replication_id computation
FR58: Epic 8 - Bidirectional replication with CouchDB peer
FR59: Epic 8 - Deterministic revision hash generation
FR60: Epic 7 - HTTP Basic authentication
FR61: Epic 7 - Session cookie authentication via POST /_session
FR62: Epic 7 - Session info retrieval via GET /_session
FR63: Epic 7 - Session logout via DELETE /_session
FR64: Epic 7 - JWT bearer token authentication
FR65: Epic 7 - Proxy auth via X-Auth-CouchDB-* headers
FR66: Epic 7 - User management via _users database
FR67: Epic 7 - PBKDF2 password hashing via IRIS primitives
FR68: Epic 7 - Per-database _security admin/member lists
FR69: Epic 7 - Security enforcement at dispatch layer
FR70: Epic 7 - HTTP 401 for missing/invalid authentication
FR71: Epic 7 - HTTP 403 for failed authorization
FR72: Epic 12 - JSRuntime backend selection (None/Subprocess/Python)
FR73: Epic 12 - Default JSRuntime backend is None
FR74: Epic 12 - Design document storage regardless of JSRuntime
FR75: Epic 12 - 501 Not Implemented for JSRuntime.None
FR76: Epic 12 - Subprocess JSRuntime map-reduce execution
FR77: Epic 12 - Subprocess JSRuntime validate_doc_update
FR78: Epic 12 - Subprocess JSRuntime changes filter functions
FR79: Epic 12 - Python JSRuntime via QuickJS binding
FR80: Epic 12 - Incremental view index maintenance
FR81: Epic 12 - ETag-based view response caching
FR82: Epic 12 - JSRuntime timeout and memory limits
FR83: Epic 10 - Built-in admin UI at _utils path
FR84: Epic 10 - Angular SPA served as static assets
FR85: Epic 10 - Database listing in admin UI
FR86: Epic 10 - Database creation in admin UI
FR87: Epic 10 - Database deletion in admin UI
FR88: Epic 10 - Per-database metadata in admin UI
FR89: Epic 10 - Document browsing with pagination in admin UI
FR90: Epic 10 - Individual document detail view in admin UI
FR91: Epic 11 - Design document viewing in admin UI (read-only)
FR92: Epic 11 - Design document editing in admin UI (beta)
FR93: Epic 11 - Security config viewing in admin UI (read-only)
FR94: Epic 11 - Security config editing in admin UI (beta)
FR95: Epic 11 - Revision history viewing in admin UI (gamma)
FR96: Epic 9 - Prometheus/OpenTelemetry metrics endpoint
FR97: Epic 9 - Audit event for document writes
FR98: Epic 9 - Audit event for authentication attempts
FR99: Epic 9 - Audit event for _security changes
FR100: Epic 9 - Audit event for _users writes
FR101: Epic 9 - Audit event for replication sessions
FR102: Epic 9 - Namespace-scoped state for IRIS mirroring/backup
FR103: Epic 9 - Replication checkpoint crash recovery
FR104: Epic 9 - Mirror failover checkpoint continuity
FR105: Epic 1 - Actionable error reason strings
FR106: Epic 1 - ZPM single-command installation
FR107: Epic 1 - Manual ObjectScript import fallback
FR108: Epic 1 - Configurable webapp mount path
FR109: Epic 1 - Zero mandatory external dependencies
FR110: Epic 13 - Getting Started walkthrough
FR111: Epic 13 - Live compatibility matrix
FR112: Epic 13 - Deviation log
FR113: Epic 13 - Migration playbook
FR114: Epic 13 - Troubleshooting runbook
FR115: Epic 13 - Six working examples

## Epic List

### Epic 1: Project Foundation & Server Identity
Adopters can install IRISCouch via ZPM and verify a running CouchDB-compatible server that responds to discovery endpoints.
**FRs covered:** FR105, FR106, FR107, FR108, FR109
**Notes:** Phase 0 scaffold. Exit criterion: `GET /` returns CouchDB welcome JSON, `/_uuids` returns UUIDs, ZPM compiles cleanly. Establishes Config system, Router skeleton, error envelope pattern.

### Epic 2: Database Lifecycle Management
Operators and clients can create, delete, list, and inspect databases with full CouchDB-compatible responses.
**FRs covered:** FR1, FR2, FR3, FR4, FR5, FR6, FR7, FR8
**Notes:** First real CouchDB API surface. Standalone -- works with no documents stored yet.

### Epic 3: Document Storage & Revision Control
Clients can store, retrieve, update, and delete documents with full MVCC revision control, conflict detection, and bulk operations.
**FRs covered:** FR9, FR10, FR11, FR12, FR13, FR14, FR15, FR16, FR17, FR18, FR19, FR20, FR21, FR22
**Notes:** Core of the system. Includes DocumentEngine.Save(), rev-tree, _all_docs, _bulk_docs, _bulk_get. Atomic writes per NFR-R2.

### Epic 4: Real-Time Change Tracking
Clients can subscribe to database change feeds to detect new, modified, and deleted documents in real time.
**FRs covered:** FR23, FR24, FR25, FR26, FR27, FR30
**Notes:** Normal + longpoll modes. Built-in filters (_doc_ids, _selector, _design). Uses $System.Event for longpoll signaling. Continuous/eventsource deferred to Epic 14.

### Epic 5: Binary Attachment Management
Clients can upload, download, and manage binary attachments on documents with streaming I/O and integrity verification.
**FRs covered:** FR31, FR32, FR33, FR34, FR35, FR36, FR37, FR38, FR39, FR40
**Notes:** Inline, multipart, and standalone upload. Streaming without proportional memory growth (NFR-P8). MD5 digest computation for replication integrity.

### Epic 6: Mango Query Engine
Clients can create indexes and query documents using CouchDB Mango selectors with full operator support.
**FRs covered:** FR41, FR42, FR43, FR44, FR45, FR46, FR47, FR48
**Notes:** Synchronous SQL projection for zero-staleness reads (NFR-P7). Includes _find, _index, _explain, partial filter selectors. Backpressure handling (NFR-SC3).

### Epic 7: Authentication & Authorization
Operators can secure the system with multiple auth mechanisms and per-database access control; clients can authenticate and manage sessions.
**FRs covered:** FR60, FR61, FR62, FR63, FR64, FR65, FR66, FR67, FR68, FR69, FR70, FR71
**Notes:** Four auth mechanisms (Basic, Session/Cookie, JWT, Proxy). _users database syncs to IRIS Security.Users. _security enforced at dispatch layer (NFR-S6). PBKDF2 hashing (NFR-S2).

### Epic 8: Replication Protocol
Clients and operators can replicate data bidirectionally with Apache CouchDB peers using the full CouchDB replication protocol.
**FRs covered:** FR51, FR52, FR53, FR54, FR55, FR56, FR57, FR58, FR59
**Notes:** _revs_diff, _bulk_get with revisions, _local/ checkpoints, _replicator database, deterministic replication IDs. Checkpoint durability (NFR-R4). Highest-risk epic per NFR-R1.

### Epic 9: Observability & Audit Trail
Operators can monitor system health via metrics and audit every state-changing operation for compliance.
**FRs covered:** FR96, FR97, FR98, FR99, FR100, FR101, FR102, FR103, FR104
**Notes:** Prometheus/OTEL metrics endpoint, 8 audit event types via %SYS.Audit, structured logging. Crash recovery and mirror failover verification. Synchronous audit within transactions (NFR-O6).

### Epic 10: Admin UI - Core Experience
Operators can log into a built-in web UI, view and manage databases, and browse documents without any external tooling.
**FRs covered:** FR83, FR84, FR85, FR86, FR87, FR88, FR89, FR90
**UX-DRs covered:** UX-DR1-DR18, UX-DR21-DR31, UX-DR34-DR46, UX-DR49-DR62, UX-DR65-DR69
**Notes:** Angular 19 SPA at /_utils. Includes design tokens, all alpha components (15 total per UX-DR62), login flow, database list, document list + detail, deep-linkable URLs, accessibility, Direction B visual style.

### Epic 11: Admin UI - Design Documents & Security Views
Operators can view and manage design documents and database security configuration through the admin UI.
**FRs covered:** FR91, FR92, FR93, FR94, FR95
**UX-DRs covered:** UX-DR19, UX-DR20, UX-DR32, UX-DR33, UX-DR47, UX-DR48, UX-DR63, UX-DR64
**Notes:** Read-only at alpha (FR91, FR93), editable at beta (FR92, FR94), revision history at gamma (FR95). Beta adds TextAreaJson, inline ErrorDisplay.

### Epic 12: Pluggable JavaScript Runtime
Operators can enable JavaScript execution for design-document views, validation hooks, and custom change filters.
**FRs covered:** FR49, FR50, FR72, FR73, FR74, FR75, FR76, FR77, FR78, FR79, FR80, FR81, FR82
**Notes:** Abstract Sandbox interface with None (501 default), Subprocess (Node/Bun/Deno/couchjs), Python (QuickJS) backends. Incremental view indexing on write. ETag caching. Timeout + memory-pressure restarts (NFR-S9).

### Epic 13: Documentation & Working Examples
Adopters have comprehensive documentation, a migration playbook, and working code examples that enable successful evaluation and adoption.
**FRs covered:** FR110, FR111, FR112, FR113, FR114, FR115
**Notes:** Getting Started walkthrough (<1 hour to PouchDB replication), live compatibility matrix, deviation log, migration playbook, troubleshooting runbook, 6 working examples. Documentation artifacts update with code changes (NFR-M2). Broken examples block releases.

### Epic 14: Gamma - Streaming Feeds & ECP Clustering
Clients can subscribe to continuous and eventsource change feeds; operators can deploy IRISCouch across ECP distributed-cache clusters for high availability.
**FRs covered:** FR28, FR29
**NFRs covered:** NFR-R5, NFR-SC5
**Notes:** Continuous/eventsource feeds via %Net.TCPServer standalone listener (bypasses CSP Gateway buffering limitation). ECP clustering safety patterns. Mirror failover checkpoint continuity verification. CouchDB 3.5.x conformance anchor added.

## Epic 1: Project Foundation & Server Identity

Adopters can install IRISCouch via ZPM and verify a running CouchDB-compatible server that responds to discovery endpoints.

### Story 1.1: Configuration System & Package Scaffold

As an adopter,
I want to install the IRISCouch package into my IRIS instance via `zpm "install iris-couch"`,
So that I have a working foundation with proper configuration management.

**Acceptance Criteria:**

**Given** a fresh IRIS instance with ZPM installed
**When** the adopter runs `zpm "install iris-couch"`
**Then** the package compiles cleanly with zero errors
**And** the `IRISCouch.Config` class is available with default parameter values
**And** `Config.Get("JSRUNTIME")` returns `"None"` as the default
**And** `^IRISCouch.Config` global overrides take precedence over class parameter defaults
**And** the webapp is mounted at `/iris-couch/` by default
**And** the mount path is configurable via `^IRISCouch.Config("WEBAPPPATH")`
**And** all generated URLs (redirects, response bodies, Location headers) are root-relative — no webapp mount path is embedded in application-generated URLs (reverse proxy deployment model per architecture decision)
**And** no external dependencies (Node.js, Python, couchjs, Erlang) are required

### Story 1.2: HTTP Router & CouchDB Welcome Endpoint

As a client,
I want to send `GET /` to the IRISCouch endpoint and receive a CouchDB-compatible welcome JSON response,
So that I can verify the server is running and discover its version.

**Acceptance Criteria:**

**Given** IRISCouch is installed and the webapp is mounted
**When** a client sends `GET /iris-couch/`
**Then** the response status is 200 OK
**And** the response Content-Type is `application/json`
**And** the response body contains `{"couchdb":"Welcome","version":"...","vendor":{"name":"IRISCouch"}}`
**And** the `IRISCouch.API.Router` class extends `%CSP.REST` with a UrlMap dispatching to handler classes
**And** the `ServerHandler` processes the welcome request

**Given** a client sends a request to an undefined route
**When** the Router cannot match the URL
**Then** the response is 404 with a JSON error envelope `{"error":"not_found","reason":"..."}`

### Story 1.3: UUID Generation Endpoint

As a client,
I want to request UUIDs via `GET /_uuids?count=N`,
So that I can generate document IDs client-side before creating documents.

**Acceptance Criteria:**

**Given** IRISCouch is running
**When** a client sends `GET /iris-couch/_uuids`
**Then** the response status is 200 OK
**And** the response body contains `{"uuids":["<hex-uuid>"]}` with exactly 1 UUID

**Given** IRISCouch is running
**When** a client sends `GET /iris-couch/_uuids?count=3`
**Then** the response body contains `{"uuids":["<hex1>","<hex2>","<hex3>"]}` with exactly 3 unique hex UUIDs

**Given** IRISCouch is running
**When** a client sends `GET /iris-couch/_uuids?count=0` or a negative count
**Then** the response is 400 Bad Request with a JSON error envelope

### Story 1.4: Error Envelope & Consistent Error Responses

As a client,
I want all error responses to include a JSON envelope with `error` and `reason` fields naming the subsystem and failure mode,
So that I can programmatically handle errors and diagnose issues.

**Acceptance Criteria:**

**Given** any error condition occurs in IRISCouch
**When** the error response is rendered
**Then** the response body is a JSON object with at minimum `{"error":"<slug>","reason":"<subsystem: specific failure>"}`
**And** the `IRISCouch.Util.Error.Render()` classmethod is the single entry point for all error responses
**And** the 13 error slugs from the PRD (`not_found`, `conflict`, `forbidden`, `unauthorized`, `file_exists`, `doc_validation`, `bad_request`, `not_implemented`, `method_not_allowed`, `bad_content_type`, `precondition_failed`, `projection_backpressure`, `server_error`) are supported
**And** 500 Internal Server Error responses return a generic envelope to the client with full traces logged to IRIS logs only (NFR-S8)
**And** the `reason` field always names the subsystem and specific failure mode, never a generic message (NFR-O4)

### Story 1.5: Manual ObjectScript Import Installation

As an adopter without ZPM available,
I want to install IRISCouch manually via `$System.OBJ.ImportDir` with documented steps,
So that I can deploy IRISCouch in environments where ZPM is not installed.

**Acceptance Criteria:**

**Given** an IRIS instance without ZPM
**When** the adopter follows the documented manual import procedure using `$System.OBJ.ImportDir`
**Then** all IRISCouch ObjectScript classes compile cleanly
**And** the webapp can be configured manually via the IRIS Management Portal or programmatic setup
**And** `GET /iris-couch/` returns the CouchDB welcome JSON after manual setup
**And** the installation documentation lists the exact commands and configuration steps required
**And** the directory structure supports both ZPM and manual import without modification

## Epic 2: Database Lifecycle Management

Operators and clients can create, delete, list, and inspect databases with full CouchDB-compatible responses.

### Story 2.1: Create and Delete Databases

As an operator,
I want to create databases via `PUT /{db}` and delete them via `DELETE /{db}`,
So that I can provision and decommission data stores for my applications.

**Acceptance Criteria:**

**Given** an authenticated client
**When** the client sends `PUT /iris-couch/{db}` with a valid database name
**Then** the response status is 201 Created
**And** the response body is `{"ok":true}`
**And** the `^IRISCouch.DB(db)` global is initialized with database metadata
**And** empty globals are prepared for the new database's documents, rev-tree, changes, and sequences

**Given** a database with name `{db}` already exists
**When** the client sends `PUT /iris-couch/{db}`
**Then** the response status is 412 Precondition Failed
**And** the response body contains `{"error":"file_exists","reason":"The database could not be created, the file already exists."}`

**Given** an existing database `{db}`
**When** the client sends `DELETE /iris-couch/{db}`
**Then** the response status is 200 OK
**And** the response body is `{"ok":true}`
**And** all globals associated with the database are removed

**Given** no database named `{db}` exists
**When** the client sends `DELETE /iris-couch/{db}`
**Then** the response status is 404 Not Found
**And** the response body contains `{"error":"not_found","reason":"Database does not exist."}`

### Story 2.2: List Databases and Retrieve Metadata

As a client,
I want to list all databases via `GET /_all_dbs` and retrieve per-database metadata via `GET /{db}`,
So that I can discover available databases and inspect their state.

**Acceptance Criteria:**

**Given** one or more databases exist
**When** the client sends `GET /iris-couch/_all_dbs`
**Then** the response status is 200 OK
**And** the response body is a JSON array of database name strings sorted alphabetically

**Given** no databases exist
**When** the client sends `GET /iris-couch/_all_dbs`
**Then** the response status is 200 OK
**And** the response body is an empty JSON array `[]`

**Given** a database `{db}` exists
**When** the client sends `GET /iris-couch/{db}`
**Then** the response status is 200 OK
**And** the response body includes `db_name`, `doc_count`, `update_seq`, `disk_size`, `purge_seq`, and other CouchDB-compatible metadata fields

**Given** no database named `{db}` exists
**When** the client sends `GET /iris-couch/{db}`
**Then** the response status is 404 Not Found with a `not_found` error envelope

### Story 2.3: Database Maintenance Operations

As an operator,
I want to configure revision retention limits, trigger compaction, and request full commits,
So that I can manage database storage and durability.

**Acceptance Criteria:**

**Given** an existing database `{db}`
**When** the operator sends `PUT /iris-couch/{db}/_revs_limit` with a numeric body (e.g., `1000`)
**Then** the response status is 200 OK
**And** the revision retention limit is stored in the database metadata
**And** subsequent `GET /iris-couch/{db}/_revs_limit` returns the configured value

**Given** an existing database `{db}`
**When** the operator sends `POST /iris-couch/{db}/_compact`
**Then** the response status is 202 Accepted
**And** the response body is `{"ok":true}`
**And** compaction of the database's revision tree and tombstones is initiated

**Given** an existing database `{db}`
**When** the client sends `POST /iris-couch/{db}/_ensure_full_commit`
**Then** the response status is 201 Created
**And** the response body contains `{"ok":true,"instance_start_time":"..."}`
**And** all pending writes for the database are confirmed durable

## Epic 3: Document Storage & Revision Control

Clients can store, retrieve, update, and delete documents with full MVCC revision control, conflict detection, and bulk operations.

### Story 3.1: Single Document Create & Read

As a client,
I want to create documents via `POST /{db}` and `PUT /{db}/{docid}` and retrieve them via `GET /{db}/{docid}`,
So that I can store and access JSON data in the database.

**Acceptance Criteria:**

**Given** an existing database `{db}`
**When** the client sends `POST /iris-couch/{db}` with a JSON body
**Then** the response status is 201 Created
**And** the response body contains `{"ok":true,"id":"<server-generated-uuid>","rev":"1-<hash>"}`
**And** the document body is stored in `^IRISCouch.Docs(db, docId, rev)` as raw JSON
**And** the revision tree is initialized in `^IRISCouch.Tree` with a single leaf node

**Given** an existing database `{db}`
**When** the client sends `PUT /iris-couch/{db}/{docid}` with a JSON body and no `_rev` field
**Then** the response status is 201 Created
**And** the document is stored with the client-specified `{docid}`
**And** the initial revision is `1-<deterministic-hash>`

**Given** a document `{docid}` exists in database `{db}`
**When** the client sends `GET /iris-couch/{db}/{docid}`
**Then** the response status is 200 OK
**And** the response body contains the document JSON with `_id` and `_rev` fields

**Given** a document `{docid}` exists with multiple revisions
**When** the client sends `GET /iris-couch/{db}/{docid}?rev=N-hex`
**Then** the response returns the specific revision requested
**And** if the revision does not exist, the response is 404 Not Found

**Given** the `DocumentEngine.Save()` classmethod is the single write orchestrator
**When** a document is written
**Then** the write is wrapped in a `TSTART`/`TCOMMIT` transaction ensuring atomicity (NFR-R2)

### Story 3.2: Document Update, Delete & Optimistic Concurrency

As a client,
I want to update documents with revision checks and delete documents producing tombstones,
So that I have safe concurrent access with no silent data loss.

**Acceptance Criteria:**

**Given** a document `{docid}` exists with revision `1-abc`
**When** the client sends `PUT /iris-couch/{db}/{docid}` with `"_rev":"1-abc"` and updated body
**Then** the response status is 201 Created
**And** the response contains the new revision `2-<hash>`
**And** the previous revision remains in the tree

**Given** a document `{docid}` exists with revision `2-def`
**When** the client sends `PUT /iris-couch/{db}/{docid}` with a stale `"_rev":"1-abc"`
**Then** the response status is 409 Conflict
**And** the response body contains `{"error":"conflict","reason":"Document update conflict."}`

**Given** a document `{docid}` exists with revision `N-hex`
**When** the client sends `DELETE /iris-couch/{db}/{docid}?rev=N-hex`
**Then** the response status is 200 OK
**And** a tombstone revision `(N+1)-<hash>` is created with `"_deleted":true`

**Given** a document `{docid}` exists
**When** the client sends `PUT /iris-couch/{db}/{docid}` with `"_deleted":true` and valid `_rev`
**Then** the document is deleted producing the same tombstone revision as DELETE

**Given** a client sends a document with a top-level field starting with underscore (other than documented metadata)
**When** the document is validated
**Then** the response status is 400 Bad Request
**And** the response body contains `{"error":"doc_validation","reason":"..."}`

### Story 3.3: Revision Tree & Conflict Management

As a client,
I want the system to detect, store, and expose concurrent-update conflicts and compute the deterministic winning revision,
So that I can resolve conflicts without data loss.

**Acceptance Criteria:**

**Given** two clients concurrently update the same document from the same parent revision
**When** the second write arrives (via `new_edits=false` or replication)
**Then** both revisions are stored as leaf nodes in `^IRISCouch.Tree`
**And** the winning revision is computed deterministically using CouchDB's published algorithm (highest depth, then lexicographic rev hash)
**And** the winning revision is cached in the "W" node of the tree

**Given** a document with conflicts exists
**When** the client sends `GET /iris-couch/{db}/{docid}?conflicts=true`
**Then** the response includes a `_conflicts` array listing all non-winning leaf revisions

**Given** a document exists with a multi-revision history
**When** the client sends `GET /iris-couch/{db}/{docid}?revs=true`
**Then** the response includes a `_revisions` object with `start` and `ids` array tracing the revision path

**Given** a document exists
**When** the client sends `GET /iris-couch/{db}/{docid}?revs_info=true`
**Then** the response includes `_revs_info` array with each revision's status (`available`, `missing`, `deleted`)

**Given** a document exists
**When** the client sends `GET /iris-couch/{db}/{docid}?open_revs=all`
**Then** the response returns all leaf revisions as a multipart or JSON array

**Given** a document exists
**When** the client sends `GET /iris-couch/{db}/{docid}?open_revs=["1-abc","2-def"]`
**Then** the response returns the specified revisions, or `{"missing":"N-hex"}` for revisions not found

### Story 3.4: Bulk Document Operations

As a client,
I want to submit multiple document writes in a single request and retrieve multiple documents by ID in bulk,
So that I can efficiently perform batch operations.

**Acceptance Criteria:**

**Given** an existing database `{db}`
**When** the client sends `POST /iris-couch/{db}/_bulk_docs` with `{"docs":[{...},{...}]}`
**Then** the response status is 201 Created
**And** the response body is a JSON array with per-document results (`{"ok":true,"id":"...","rev":"..."}` or `{"error":"conflict","id":"...","reason":"..."}`)
**And** each document write is processed through `DocumentEngine.Save()`

**Given** documents exist in database `{db}`
**When** the client sends `POST /iris-couch/{db}/_bulk_get` with `{"docs":[{"id":"doc1"},{"id":"doc2","rev":"1-abc"}]}`
**Then** the response status is 200 OK
**And** the response body contains results for each requested document
**And** specific revisions can be requested per document
**And** missing documents return `{"error":"not_found"}` in their result entry

**Given** a bulk_get request includes `revs=true`
**When** the response is generated
**Then** each document includes its revision history in the `_revisions` field

### Story 3.5: Replication-Format Bulk Writes

As a replication client,
I want to submit writes with `new_edits=false` that preserve source revision IDs,
So that replication can graft external revision histories into the local database.

**Acceptance Criteria:**

**Given** an existing database `{db}`
**When** the client sends `POST /iris-couch/{db}/_bulk_docs` with `{"new_edits":false,"docs":[...]}`
**Then** documents are stored with their provided `_rev` values unchanged
**And** no new revision IDs are generated by the server
**And** `DocumentEngine.SaveWithHistory()` grafts the external revision history into `^IRISCouch.Tree`

**Given** a document with revision history is submitted via `new_edits=false`
**When** the revision tree is updated
**Then** existing local revisions are preserved
**And** new branches from the source are grafted correctly
**And** the winning revision is recomputed after grafting

**Given** the system generates revision hashes
**When** a document is created or updated
**Then** the hash is computed deterministically from document content using a JSON-canonical MD5 algorithm
**And** the hash is replication-protocol sufficient (not byte-identical to CouchDB's Erlang ETF hash)

### Story 3.6: All Documents View

As a client,
I want to list all documents via `GET /{db}/_all_docs` with pagination and key-range filtering, and query by specific keys via `POST /{db}/_all_docs`,
So that I can browse and look up documents in a database.

**Acceptance Criteria:**

**Given** a database `{db}` contains documents
**When** the client sends `GET /iris-couch/{db}/_all_docs`
**Then** the response status is 200 OK
**And** the response body contains `{"total_rows":N,"offset":0,"rows":[{"id":"...","key":"...","value":{"rev":"..."}}]}`
**And** rows are sorted by document ID ascending

**Given** a database contains many documents
**When** the client sends `GET /iris-couch/{db}/_all_docs?limit=10&skip=20`
**Then** the response returns at most 10 rows starting from offset 20

**Given** a database contains documents
**When** the client sends `GET /iris-couch/{db}/_all_docs?startkey="doc-a"&endkey="doc-m"`
**Then** the response returns only documents with IDs in the specified range

**Given** a database contains documents
**When** the client sends `GET /iris-couch/{db}/_all_docs?include_docs=true`
**Then** each row includes a `doc` field containing the full document body

**Given** a database contains documents
**When** the client sends `POST /iris-couch/{db}/_all_docs` with `{"keys":["doc1","doc2","doc3"]}`
**Then** the response returns rows for the specified document IDs
**And** missing documents return a row with `{"error":"not_found"}` in the value

**Given** a document exists
**When** the client sends `GET /iris-couch/{db}/{docid}?local_seq=true`
**Then** the response includes the `_local_seq` field with the document's sequence number

## Epic 4: Real-Time Change Tracking

Clients can subscribe to database change feeds to detect new, modified, and deleted documents in real time.

### Story 4.1: Normal Changes Feed

As a client,
I want to retrieve a snapshot of database changes via `GET /{db}/_changes` in `feed=normal` mode,
So that I can see all document changes up to the current sequence.

**Acceptance Criteria:**

**Given** a database `{db}` with documents that have been created, updated, or deleted
**When** the client sends `GET /iris-couch/{db}/_changes`
**Then** the response status is 200 OK
**And** the response body contains `{"results":[{"seq":N,"id":"...","changes":[{"rev":"..."}]}],"last_seq":N,"pending":0}`
**And** each change has a monotonically increasing sequence number assigned atomically via `^IRISCouch.Seq(db)`

**Given** a database with changes
**When** the client sends `GET /iris-couch/{db}/_changes?since=5`
**Then** only changes with sequence numbers greater than 5 are returned

**Given** a database with many changes
**When** the client sends `GET /iris-couch/{db}/_changes?limit=10`
**Then** at most 10 change entries are returned
**And** `pending` reflects the count of remaining changes

**Given** a database with changes
**When** the client sends `GET /iris-couch/{db}/_changes?include_docs=true`
**Then** each change entry includes a `doc` field with the full document body

**Given** a database with documents that have conflicts
**When** the client sends `GET /iris-couch/{db}/_changes?style=all_docs`
**Then** each change entry lists all leaf revisions in the `changes` array

**Given** `DocumentEngine.Save()` commits a write
**When** the transaction completes
**Then** the change is recorded in `^IRISCouch.Changes(db, seq)` within the same transaction

### Story 4.2: Longpoll Changes Feed

As a client,
I want to subscribe to changes via `feed=longpoll` mode where the request blocks until new changes arrive,
So that I can efficiently detect changes without polling.

**Acceptance Criteria:**

**Given** a database `{db}` with no new changes since the client's `since` value
**When** the client sends `GET /iris-couch/{db}/_changes?feed=longpoll&since=N`
**Then** the request blocks and waits for a new change via `$System.Event` on `"IRISCouch:changes:" _ db`

**Given** a longpoll request is waiting
**When** a document write commits in `DocumentEngine.Save()` and posts the event
**Then** the longpoll response is sent with the new change(s)
**And** the response is visible within 500ms under zero contention (NFR-P6)

**Given** a longpoll request is waiting
**When** the configurable timeout expires without new changes
**Then** the response is sent with `{"results":[],"last_seq":N,"pending":0}`

**Given** a longpoll request includes `heartbeat=N` (milliseconds)
**When** the timeout has not yet expired and no changes have arrived
**Then** a newline heartbeat is sent at the specified interval to keep the connection alive

### Story 4.3: Built-In Changes Filters

As a client,
I want to filter the changes feed by document IDs, Mango selector, or design-document-only,
So that I receive only the changes relevant to my application.

**Acceptance Criteria:**

**Given** a database with various documents
**When** the client sends `GET /iris-couch/{db}/_changes?filter=_doc_ids` with `{"doc_ids":["doc1","doc2"]}` in the request body
**Then** only changes for the specified document IDs are returned

**Given** a database with various documents
**When** the client sends `POST /iris-couch/{db}/_changes?filter=_selector` with a Mango selector body (e.g., `{"selector":{"type":"order"}}`)
**Then** only changes for documents matching the selector are returned

**Given** a database with both regular and design documents
**When** the client sends `GET /iris-couch/{db}/_changes?filter=_design`
**Then** only changes for design documents (IDs starting with `_design/`) are returned

**Given** a client specifies an unsupported or non-existent filter
**When** the changes request is processed
**Then** the response is 404 Not Found with an appropriate error envelope

**Given** filters are applied
**When** the changes feed is in `feed=longpoll` mode
**Then** the filter is applied to the longpoll response as well, returning only matching changes

## Epic 5: Binary Attachment Management

Clients can upload, download, and manage binary attachments on documents with streaming I/O and integrity verification.

### Story 5.1: Standalone Attachment Upload & Download

As a client,
I want to upload attachments via `PUT /{db}/{docid}/{attname}` and download them via `GET /{db}/{docid}/{attname}`,
So that I can associate binary files with documents and retrieve them.

**Acceptance Criteria:**

**Given** a document `{docid}` exists in database `{db}` with revision `N-hex`
**When** the client sends `PUT /iris-couch/{db}/{docid}/photo.jpg?rev=N-hex` with binary content and `Content-Type: image/jpeg`
**Then** the response status is 201 Created
**And** the response body contains `{"ok":true,"id":"...","rev":"(N+1)-<hash>"}`
**And** the attachment content is stored via `%Stream.GlobalBinary` in `^IRISCouch.Atts`
**And** the attachment metadata (content_type, length, digest) is recorded
**And** an MD5 digest is computed and stored for replication integrity

**Given** a document has an attachment `photo.jpg`
**When** the client sends `GET /iris-couch/{db}/{docid}/photo.jpg`
**Then** the response status is 200 OK
**And** the `Content-Type` header matches the stored content type
**And** the response body is the raw binary attachment content
**And** the content is streamed without buffering the entire body in process memory (NFR-P8)

**Given** a 500 MB attachment is uploaded or downloaded
**When** the transfer completes
**Then** IRIS process RSS has not grown proportionally to the attachment size
**And** memory usage is bounded by stream buffer size (kilobytes)

**Given** a document does not have the requested attachment
**When** the client sends `GET /iris-couch/{db}/{docid}/{attname}`
**Then** the response status is 404 Not Found with error envelope

### Story 5.2: Inline & Multipart Attachment Upload

As a client,
I want to upload attachments inline via base64 in the document JSON body or via `multipart/related` request,
So that I can create documents with attachments in a single request.

**Acceptance Criteria:**

**Given** a client creates or updates a document
**When** the JSON body includes `"_attachments":{"file.txt":{"content_type":"text/plain","data":"<base64-encoded>"}}`
**Then** the attachment is decoded from base64 and stored as a binary stream
**And** the attachment metadata (content_type, length, digest) is computed and stored
**And** the document revision reflects the attachment addition

**Given** a client sends `PUT /iris-couch/{db}/{docid}` with `Content-Type: multipart/related`
**When** the request body contains a JSON part followed by binary attachment parts
**Then** the document JSON is parsed from the first part
**And** each subsequent part is stored as an attachment matched by Content-Disposition filename
**And** the write is atomic within the same `DocumentEngine.Save()` transaction

**Given** a document has existing attachments
**When** the client updates the document with `_attachments` containing stubs (`"stub":true`) for unchanged attachments and new data for added attachments
**Then** existing stub attachments are preserved without re-uploading
**And** new attachments are added alongside existing ones

### Story 5.3: Attachment Retrieval Options & Multipart Response

As a client,
I want to control how attachments are included in document responses -- as stubs, full content, conditionally by revision, or via multipart/mixed,
So that I can optimize bandwidth and retrieve only the attachment data I need.

**Acceptance Criteria:**

**Given** a document with attachments
**When** the client sends `GET /iris-couch/{db}/{docid}` (default `?attachments=false`)
**Then** the `_attachments` field contains stubs with metadata only (content_type, length, digest, stub:true) -- no content data

**Given** a document with attachments
**When** the client sends `GET /iris-couch/{db}/{docid}?attachments=true`
**Then** the `_attachments` field includes base64-encoded `data` for each attachment

**Given** a document with attachments across multiple revisions
**When** the client sends `GET /iris-couch/{db}/{docid}?atts_since=["2-abc"]`
**Then** only attachments added or modified since revision `2-abc` include content
**And** attachments unchanged since that revision are returned as stubs

**Given** a client requests a document with `Accept: multipart/mixed` and `?open_revs=all`
**When** the document has attachments
**Then** the response is a multipart/mixed MIME response
**And** each part contains a revision with its attachments as nested MIME parts
**And** the MIME boundaries and Content-Type headers are correctly formatted

## Epic 6: Mango Query Engine

Clients can create indexes and query documents using CouchDB Mango selectors with full operator support.

### Story 6.1: Mango Index Management

As a client,
I want to create, list, and delete Mango indexes on document fields,
So that I can optimize query performance for my access patterns.

**Acceptance Criteria:**

**Given** an existing database `{db}`
**When** the client sends `POST /iris-couch/{db}/_index` with `{"index":{"fields":["type","date"]},"name":"idx-type-date","ddoc":"my-indexes"}`
**Then** the response status is 200 OK
**And** the response body contains `{"result":"created","id":"_design/my-indexes","name":"idx-type-date"}`
**And** a `MangoIndex` persistent record is created with the composite index definition
**And** no DDL or class recompilation occurs at runtime

**Given** an index already exists with the same definition
**When** the client sends the same `POST /{db}/_index` request
**Then** the response contains `{"result":"exists"}` and no duplicate is created

**Given** a database with indexes
**When** the client sends `GET /iris-couch/{db}/_index`
**Then** the response status is 200 OK
**And** the response body lists all indexes including the special `_all_docs` index and all user-created indexes with their fields, ddoc, name, and type

**Given** an existing index
**When** the client sends `DELETE /iris-couch/{db}/_index/{ddoc}/json/{name}`
**Then** the response status is 200 OK
**And** the index record is removed

**Given** a client creates an index with `partial_filter_selector`
**When** the index is created with `{"index":{"fields":["status"],"partial_filter_selector":{"type":"order"}}}`
**Then** the index only covers documents matching the partial filter
**And** queries that don't match the partial filter do not use this index

### Story 6.2: Mango Query Execution, Selectors & Query Plan

As a client,
I want to query documents via `POST /{db}/_find` with Mango selectors and inspect query plans via `POST /{db}/_explain`,
So that I can find documents matching complex criteria and optimize my queries.

**Acceptance Criteria:**

**Given** a database with documents and a Mango index on `["type"]`
**When** the client sends `POST /iris-couch/{db}/_find` with `{"selector":{"type":"order"},"fields":["_id","type","total"],"sort":[{"type":"asc"}],"limit":25}`
**Then** the response status is 200 OK
**And** the response body contains `{"docs":[...],"bookmark":"..."}`
**And** only the specified fields are returned
**And** results are sorted as requested
**And** at most 25 documents are returned

**Given** a database with documents
**When** the client sends a query using operators `$gt`, `$gte`, `$lt`, `$lte`, `$ne`, `$in`, `$nin`, `$exists`, `$type`, `$and`, `$or`, `$nor`, `$not`, `$regex`, `$elemMatch`, `$allMatch`, and equality
**Then** each operator is correctly translated to SQL and applied
**And** results match the expected CouchDB Mango semantics

**Given** a query with `skip` and `limit` parameters
**When** the query is executed
**Then** the first `skip` matching documents are skipped and the next `limit` documents are returned

**Given** a query with `use_index` specifying a particular index
**When** the query is executed
**Then** the specified index is used if compatible with the selector
**And** if the index is incompatible, an error is returned

**Given** a query selector that cannot be planned against any existing index
**When** the query is executed
**Then** the system falls back to a full scan
**And** correct results are returned with reduced performance
**And** a warning is included in the response indicating no index was used

**Given** the synchronous Mango SQL projection becomes a write throughput bottleneck
**When** writes exceed the projection capacity
**Then** the system returns 503 Service Unavailable with reason `projection_backpressure`
**And** an audit event is emitted (NFR-SC3)

**Given** a document was just written
**When** a Mango query matches that document
**Then** the document appears in results with zero staleness (NFR-P7)

**Given** a database with documents and indexes
**When** the client sends `POST /iris-couch/{db}/_explain` with a selector
**Then** the response status is 200 OK
**And** the response body shows the selected index (or `"all_docs"` for full scan), the selector analysis, range details, and fields examined

## Epic 7: Authentication & Authorization

Operators can secure the system with multiple auth mechanisms and per-database access control; clients can authenticate and manage sessions.

### Story 7.1: Session Authentication & Basic Auth

As a client,
I want to authenticate via HTTP Basic auth or cookie-based session auth,
So that I can securely access the system using standard CouchDB authentication methods.

**Acceptance Criteria:**

**Given** a valid IRIS user exists
**When** the client sends `POST /iris-couch/_session` with `{"name":"user","password":"pass"}`
**Then** the response status is 200 OK
**And** the response body contains `{"ok":true,"name":"user","roles":[...]}`
**And** the response includes a `Set-Cookie` header with an HMAC-signed `AuthSession` cookie
**And** the cookie is signed with a per-instance secret (NFR-S3)

**Given** a valid `AuthSession` cookie
**When** the client sends `GET /iris-couch/_session` with the cookie
**Then** the response status is 200 OK
**And** the response body contains the current user's name, roles, and authentication method (`{"ok":true,"userCtx":{"name":"user","roles":[...]},"info":{"authenticated":"cookie"}}`)

**Given** a valid session exists
**When** the client sends `DELETE /iris-couch/_session`
**Then** the response status is 200 OK
**And** the `AuthSession` cookie is invalidated

**Given** a client provides HTTP Basic auth credentials
**When** the credentials match a valid IRIS user
**Then** the request is authenticated and proceeds normally

**Given** a tampered `AuthSession` cookie
**When** the client sends a request with the tampered cookie
**Then** the HMAC verification fails and the request is treated as unauthenticated

**Given** a request requires authentication but none is provided
**When** the request reaches the auth layer
**Then** the response is 401 Unauthorized with `{"error":"unauthorized","reason":"..."}`

**Given** a request is authenticated but the user lacks authorization
**When** the request reaches the authorization check
**Then** the response is 403 Forbidden with `{"error":"forbidden","reason":"..."}`

**Given** user credentials are validated
**When** authentication is processed
**Then** credentials are checked against the IRIS user directory exclusively -- no shadow credential store exists (NFR-S1)

### Story 7.2: JWT & Proxy Authentication

As a client,
I want to authenticate via JWT bearer tokens or proxy auth headers from trusted upstreams,
So that I can integrate IRISCouch with external identity providers and reverse proxies.

**Acceptance Criteria:**

**Given** an operator has configured JWT issuers and public keys
**When** a client sends a request with `Authorization: Bearer <jwt-token>`
**Then** the token is validated against the configured issuer and public key
**And** the user identity and roles are extracted from the token claims
**And** the request proceeds as authenticated

**Given** a JWT token is expired or has an invalid signature
**When** the client sends a request with the invalid token
**Then** the response is 401 Unauthorized with an appropriate reason

**Given** an operator has configured a shared secret for proxy auth
**When** a trusted upstream sends a request with `X-Auth-CouchDB-UserName`, `X-Auth-CouchDB-Roles`, and `X-Auth-CouchDB-Token` headers
**Then** the token is validated against the shared secret
**And** the user identity and roles from the headers are trusted
**And** the request proceeds as authenticated

**Given** proxy auth headers are present but the token does not match the shared secret
**When** the request is processed
**Then** the response is 401 Unauthorized

**Given** multiple auth mechanisms are available
**When** a request includes credentials for more than one mechanism
**Then** the Router selects the auth mechanism in a deterministic priority order (cookie > bearer > proxy > basic)

### Story 7.3: User Management via _users Database

As an operator,
I want to manage users via documents in the `_users` database that synchronize to IRIS user records,
So that I can use the standard CouchDB user management API.

**Acceptance Criteria:**

**Given** the `_users` database exists
**When** an operator creates a user document with `PUT /iris-couch/_users/org.couchdb.user:username` containing `{"name":"username","password":"secret","roles":[],"type":"user"}`
**Then** the user document is stored in the `_users` database
**And** a corresponding IRIS user record is created via `Security.Users`
**And** the password is hashed using PBKDF2 via IRIS primitives with iteration count >= 10,000 (NFR-S2)
**And** the hashed credential is stored in the IRIS user record, not in the `_users` document body

**Given** an existing user document is updated with a new password
**When** the document write completes
**Then** the IRIS user record password is updated with the new PBKDF2 hash
**And** the `_users` document does not contain the plaintext or hashed password

**Given** a user document is deleted
**When** the deletion completes
**Then** the corresponding IRIS user record is also removed

**Given** the `_users` database
**When** any write occurs
**Then** the write synchronizes one-to-one to the IRIS user directory
**And** no credentials exist outside the IRIS user directory

### Story 7.4: Per-Database Security Configuration

As an operator,
I want to set per-database admin and member lists via `PUT /{db}/_security`,
So that I can control who can read and write each database.

**Acceptance Criteria:**

**Given** an existing database `{db}`
**When** the operator sends `PUT /iris-couch/{db}/_security` with `{"admins":{"names":["admin1"],"roles":["db-admin"]},"members":{"names":["user1"],"roles":["reader"]}}`
**Then** the response status is 200 OK
**And** the security configuration is stored for the database

**Given** a database with security configuration
**When** the client sends `GET /iris-couch/{db}/_security`
**Then** the response contains the current admin and member lists

**Given** a database with member restrictions
**When** a non-member, non-admin client sends any request to the database
**Then** the request is rejected with 403 Forbidden before any document logic executes (NFR-S6)

**Given** a database with admin restrictions
**When** a member (non-admin) attempts a restricted operation (e.g., creating a design document)
**Then** the request is rejected with 403 Forbidden

**Given** a database with no `_security` configuration
**When** any authenticated user sends a request
**Then** the request proceeds (open access for authenticated users)

**Given** the `_security` enforcement layer
**When** any request arrives for a database
**Then** admin/member checks execute at the HTTP dispatch layer before document logic runs
**And** a denied request never reaches storage code

## Epic 8: Replication Protocol

Clients and operators can replicate data bidirectionally with Apache CouchDB peers using the full CouchDB replication protocol.

### Story 8.1: Local Documents & Replication Checkpoints

As a replication client,
I want to persist and retrieve replication checkpoints via `_local/` documents,
So that replication can resume from where it left off after interruption.

**Acceptance Criteria:**

**Given** an existing database `{db}`
**When** the client sends `PUT /iris-couch/{db}/_local/{id}` with a JSON body
**Then** the response status is 201 Created
**And** the document is stored in `^IRISCouch.Local(db, id)`

**Given** a local document exists
**When** the client sends `GET /iris-couch/{db}/_local/{id}`
**Then** the response status is 200 OK
**And** the response body contains the local document with `_id` and `_rev`

**Given** a local document exists
**When** the client sends `DELETE /iris-couch/{db}/_local/{id}?rev=N-hex`
**Then** the response status is 200 OK
**And** the local document is removed

**Given** local documents exist in a database
**When** the changes feed is queried via `GET /{db}/_changes`
**Then** local documents are excluded from the results

**Given** local documents exist in a database
**When** `GET /{db}/_all_docs` is queried
**Then** local documents are excluded from the results

**Given** replication is active between two peers
**When** local documents are processed
**Then** local documents are excluded from replication to peers

**Given** a hard process kill occurs during replication
**When** IRIS restarts and journal replay completes
**Then** the last-written checkpoint document in `^IRISCouch.Local` is intact (NFR-R4)
**And** resumed replication picks up from the last checkpoint with correct sequence continuity

### Story 8.2: Revision Difference Calculation

As a replication client,
I want to retrieve which revisions the target already holds via `POST /{db}/_revs_diff`,
So that replication transfers only the missing data.

**Acceptance Criteria:**

**Given** a database with documents at various revisions
**When** the client sends `POST /iris-couch/{db}/_revs_diff` with `{"doc1":["1-abc","2-def"],"doc2":["1-xyz"]}`
**Then** the response status is 200 OK
**And** the response body lists only the revisions not present locally: `{"doc1":{"missing":["2-def"]},"doc2":{"missing":["1-xyz"]}}`

**Given** all submitted revisions already exist locally
**When** the `_revs_diff` request is processed
**Then** the response body is an empty object `{}`

**Given** a document with a known revision tree
**When** `_revs_diff` identifies missing revisions
**Then** the response optionally includes `possible_ancestors` listing known ancestor revisions that could serve as a merge base

### Story 8.3: Replication-Ready Bulk Get

As a replication client,
I want to retrieve multiple documents with specific revisions, revision history, and attachments in a single request,
So that the replication protocol can efficiently pull missing data.

**Acceptance Criteria:**

**Given** a database with documents
**When** the client sends `POST /iris-couch/{db}/_bulk_get` with `{"docs":[{"id":"doc1","rev":"2-def"},{"id":"doc2","rev":"1-xyz"}]}` and query parameters `revs=true&attachments=true`
**Then** the response status is 200 OK
**And** each document includes its full revision history in `_revisions`
**And** each document includes attachment content (not just stubs)

**Given** a requested document or revision does not exist
**When** the `_bulk_get` response is generated
**Then** the missing document/revision entry contains `{"error":"not_found","reason":"missing"}`

**Given** documents with attachments are requested with `attachments=true`
**When** the response is generated
**Then** attachments are included inline as base64 or via multipart/mixed response
**And** attachment digests are preserved for replication integrity

### Story 8.4: Bidirectional Replication Protocol

As a replication client,
I want to perform bidirectional replication against Apache CouchDB 3.x peers using the full CouchDB replication protocol,
So that data is synchronized between IRISCouch and CouchDB instances.

**Acceptance Criteria:**

**Given** IRISCouch and a CouchDB 3.x peer both have databases
**When** a pull replication is initiated from CouchDB to IRISCouch
**Then** the replication protocol executes: read source `_changes`, post `_revs_diff` to target, `_bulk_get` missing docs from source, `_bulk_docs` with `new_edits=false` to target, update `_local/` checkpoint
**And** all source documents and revisions are present in IRISCouch after completion

**Given** IRISCouch has documents not present on a CouchDB peer
**When** a push replication is initiated from IRISCouch to CouchDB
**Then** the same protocol executes in reverse
**And** all IRISCouch documents and revisions are present on the CouchDB peer after completion

**Given** a replication completes successfully
**When** the `replication_id` is computed
**Then** the ID is deterministic based on source, target, and filter configuration
**And** the same `replication_id` is computed after process restart (FR57)

**Given** replication is interrupted by a process kill
**When** replication resumes after IRIS restart
**Then** it picks up from the last checkpoint without rewinding or duplicating work

**Given** the system generates revision hashes during replication
**When** documents are replicated
**Then** hashes are computed deterministically from document content using a JSON-canonical MD5 algorithm
**And** hashes are replication-protocol sufficient for correct conflict resolution (FR59)

**Given** any suspected revision-tree corruption during replication
**When** the condition is detected
**Then** the issue is flagged as an unshippable defect (NFR-R1)

### Story 8.5: _replicator Database & Continuous Replication Jobs

As an operator,
I want to configure continuous replication jobs via documents in the `_replicator` database,
So that replication runs automatically and I can monitor its progress.

**`_replicator` Document Schema:**

The `_replicator` database is a system database with self-updating document semantics. Each document represents a replication job and has the following field contract:

| Field | Set by | Required | Description |
|---|---|---|---|
| `source` | Operator | Yes | Source database URL (remote) or name (local) |
| `target` | Operator | Yes | Target database URL (remote) or name (local) |
| `create_target` | Operator | No | If `true`, create the target database if it does not exist |
| `continuous` | Operator | No | If `true`, replication runs continuously; if `false`/absent, one-shot |
| `cancel` | Operator | No | If `true`, cancel the running replication job |
| `doc_ids` | Operator | No | Array of document IDs to replicate (subset replication) |
| `selector` | Operator | No | Mango selector to filter which documents are replicated |
| `filter` | Operator | No | Name of a design-doc filter function (e.g., `"mydesign/myfilter"`) |
| `query_params` | Operator | No | Key-value object passed to the filter function |
| `owner` | System | — | Set to the authenticated user who created the document |
| `_replication_id` | System | — | Deterministic job ID computed from source+target+options; survives restart |
| `_replication_state` | System | — | One of `"triggered"`, `"completed"`, `"error"` |
| `_replication_state_time` | System | — | ISO-8601 timestamp of the last state transition |
| `_replication_stats` | System | — | Object: `{"docs_read": N, "docs_written": N, "doc_write_failures": N, "missing_checked": N, "missing_found": N}` |

The system-set fields (`owner`, `_replication_id`, `_replication_state`, `_replication_state_time`, `_replication_stats`) are written back to the document by IRISCouch as the replication progresses. Operators must not set system fields manually; they are overwritten on each state transition.

**Acceptance Criteria:**

**Given** the `_replicator` database exists
**When** an operator creates a document with `{"source":"http://couchdb:5984/mydb","target":"localdb","continuous":true}`
**Then** a replication job is started automatically
**And** the document is updated with `_replication_id` containing the deterministic job ID
**And** the `owner` field is set to the authenticated user identity

**Given** a running replication job
**When** progress is made
**Then** the `_replicator` document is updated with `_replication_state` (`triggered`, `completed`, `error`), `_replication_state_time`, and `_replication_stats` (docs read, docs written, doc write failures)

**Given** a continuous replication job is configured
**When** new changes appear in the source database
**Then** the replication job detects and transfers them automatically

**Given** a replication job document is deleted
**When** the deletion is processed
**Then** the associated replication job is stopped

**Given** a replication job encounters an error
**When** the error is recorded
**Then** `_replication_state` is set to `"error"` with details in `_replication_stats`
**And** the job retries with exponential backoff

## Epic 9: Observability & Audit Trail

Operators can monitor system health via metrics and audit every state-changing operation for compliance.

### Story 9.1: Prometheus / OpenTelemetry Metrics Endpoint

As an operator,
I want to scrape Prometheus / OpenTelemetry metrics from a dedicated endpoint,
So that I can monitor system health, request latency, and throughput.

**Acceptance Criteria:**

**Given** IRISCouch is running
**When** the operator scrapes the metrics endpoint
**Then** the response contains Prometheus-compatible metrics including:
**And** request counts per endpoint class (`server`, `database`, `document`, `changes`, `attachment`, `mango`, `replication`, `auth`, `security`, `design`)
**And** request latency histograms per endpoint class
**And** replication throughput (documents/sec and bytes/sec)
**And** `_changes` feed lag
**And** Mango index hit rate
**And** per-status-code error counters

**Given** the metrics endpoint is active
**When** the operator scrapes at a 30-second interval
**Then** metrics are never stale by more than one interval plus 10-second update lag (NFR-O1)

**Given** any metric label
**When** the label cardinality is examined
**Then** labels use coarse endpoint categories only -- never document IDs, never database names beyond bounded sets (NFR-O2)

**Given** `IRISCouch.Metrics.Record(endpoint, method, status, duration)` is the recording interface
**When** any HTTP request completes
**Then** the Router dispatch wrapper calls `Metrics.Record()` -- individual Handlers do not record metrics directly (except replication-specific throughput)

**Given** the metrics scrape endpoint
**When** the rest of the system experiences errors
**Then** metric collection failure does not affect other system operations (NFR-O3)

### Story 9.2: Audit Event Emission

As an operator,
I want every state-changing operation to emit a `%SYS.Audit` event,
So that I have a complete compliance trail of all mutations, authentication, and configuration changes.

**Acceptance Criteria:**

**Given** a document is created, updated, or deleted
**When** the write commits in `DocumentEngine.Save()`
**Then** a `%SYS.Audit` event of type `DocWrite` or `DocDelete` is emitted within the same transaction
**And** the event includes document ID, revision, database, user identity, and timestamp

**Given** a client attempts authentication (success or failure)
**When** the auth handler processes the attempt
**Then** a `%SYS.Audit` event of type `AuthSuccess` or `AuthFailure` is emitted
**And** the event includes user identity (if known), auth mechanism, and timestamp

**Given** a `_security` configuration is changed
**When** the write completes
**Then** a `%SYS.Audit` event of type `SecurityChange` is emitted with the database name and user who made the change

**Given** a `_users` database write occurs
**When** the user document is created, updated, or deleted
**Then** a `%SYS.Audit` event of type `UserWrite` is emitted

**Given** a replication session starts or completes
**When** the session state changes
**Then** a `%SYS.Audit` event of type `ReplicationStart` or `ReplicationComplete` is emitted
**And** the event includes source, target, sequence count processed, and byte count transferred

**Given** `IRISCouch.Audit.Emit()` is the single audit interface
**When** any audit event is emitted
**Then** the event is written synchronously within the same IRIS transaction as the operation it describes (NFR-O6)

**Given** an adopter reads only `%SYS.Audit`
**When** they review the audit log
**Then** they see every state-changing action that occurred in IRISCouch (NFR-S5)

### Story 9.3: Operational Resilience & Data Durability

As an operator,
I want all IRISCouch state to be covered by standard IRIS mirroring, backup, and journal replay, with replication checkpoints surviving crashes and failovers,
So that I can rely on existing IRIS operational procedures for disaster recovery.

**Acceptance Criteria:**

**Given** IRISCouch is installed in an IRIS namespace
**When** the state storage is examined
**Then** all state (document bodies, revision trees, changes feed, attachments, Mango projections, `_local/` checkpoints, `_users` records) resides within the namespace
**And** no state is stored outside the namespace or in cross-namespace globals
**And** standard IRIS mirroring, backup, and journal replay cover all IRISCouch state automatically

**Given** a hard process kill occurs during a document write
**When** IRIS restarts and journal replay completes
**Then** the database is in a consistent state -- either the write completed fully or was rolled back entirely (NFR-R3)

**Given** a replication was in progress when a hard kill occurred
**When** IRIS restarts
**Then** the last-written `_local/` checkpoint is intact
**And** resumed replication picks up from that checkpoint with correct sequence continuity (NFR-R4)

**Given** an IRIS mirror failover occurs
**When** the promoted mirror takes over
**Then** replication checkpoints survive with correct sequence continuity
**And** replication resumes without rewinding or duplicating work (NFR-R5, gated at gamma)

**Given** application-level logs are emitted
**When** log entries are generated
**Then** they are structured entries (JSON or key-value) suitable for log aggregation pipelines (NFR-O5)
**And** plain-text freeform logs are reserved for debug mode only

## Epic 10: Admin UI - Core Experience

Operators can log into a built-in web UI, view and manage databases, and browse documents without any external tooling.

### Story 10.1: Angular Scaffold, Design Tokens & Icon System

As an operator,
I want the admin UI foundation to be established with consistent visual design tokens,
So that all subsequent UI components share a unified look and feel.

**Acceptance Criteria:**

**Given** the admin UI project is initialized
**When** the scaffold is created
**Then** it uses `ng new` with `--style=css --routing --ssr=false --skip-tests=false`
**And** `@angular/cdk` is added as a dependency (no Angular Material)
**And** no other UI framework or state management library (NgRx, PrimeNG, etc.) is installed

**Given** the `tokens.css` file is created
**When** the design tokens are defined
**Then** it includes exactly 11 neutral gray palette tokens (`--color-neutral-0` through `--color-neutral-900`)
**And** 4 semantic color tokens (`--color-error`, `--color-warn`, `--color-success`, `--color-info`)
**And** 7-step spacing scale (`--space-1` through `--space-12`)
**And** 6-step type scale (`--font-size-xs` through `--font-size-2xl`) with corresponding line heights
**And** border-radius of 2px and border color of `--color-neutral-200`

**Given** the typography stack is configured
**When** fonts are loaded
**Then** proportional text uses the system font stack (zero bytes loaded)
**And** JetBrains Mono WOFF2 (~30KB, Latin-1 subset) is bundled and served from `/iris-couch/_utils/` with `font-display: block`

**Given** the icon system is set up
**When** icons are used in the UI
**Then** approximately 20 hand-picked Lucide icons are available as standalone Angular SVG components
**And** no icon font, runtime icon library, or CDN is used

**Given** the HTML document
**When** it is rendered
**Then** `<html lang="en">` is set on the document root
**And** `<meta name="viewport" content="width=1280">` is present
**And** the iris-couch wordmark is rendered as text-only monospace string in neutral-600 in the header

**Given** the built SPA
**When** assets are examined
**Then** all UI assets are self-contained with no external CDN loads, no Google Fonts, no analytics beacons
**And** every byte the browser loads comes from `/iris-couch/_utils/`

### Story 10.2: Core UI Components (Button, Badge, TextInput, CopyButton)

As an operator,
I want polished, accessible core UI primitives,
So that all views have consistent interactive elements with proper keyboard and screen reader support.

**Acceptance Criteria:**

**Given** the Button component is implemented
**When** it is rendered
**Then** it wraps a native `<button>` with three variants: `ghost` (default), `primary` (max one per page), `destructive` (only inside ConfirmDialog)
**And** three sizes: 28px compact, 32px standard, 40px primary-page
**And** states: default, hover, focus-visible, active, disabled, loading (spinner replaces icon, label stays)
**And** `aria-label` is required if icon-only

**Given** the IconButton component
**When** it is rendered
**Then** it has a 24x24px minimum hit target with mandatory `aria-label`
**And** Lucide SVG icons are marked `aria-hidden="true"`
**And** neutral-50 fill appears on hover

**Given** the Badge component
**When** it is rendered
**Then** it displays as an inline `<span>` with 1px semantic-color border and ~10% alpha background
**And** four variants are available: `info`, `warn`, `error`, `success`

**Given** the TextInput component
**When** it is rendered
**Then** it wraps a native `<input>` at 32px height with a real `<label>` above (never placeholder-as-label)
**And** states: default, focus (info-colored border + box-shadow), disabled, error (`aria-invalid="true"`)
**And** hint text linked via `aria-describedby`

**Given** the CopyButton component
**When** the user clicks it
**Then** content is copied to clipboard via CDK clipboard
**And** the icon changes to a check icon for ~600ms
**And** CDK LiveAnnouncer announces "Copied." to screen readers

**Given** any interactive component
**When** it receives keyboard focus
**Then** a visible 2px outline in `--color-info` at 3px offset is displayed
**And** all transitions respect `prefers-reduced-motion: reduce`
**And** no text renders below 12px
**And** each component `.spec.ts` includes at least one `axe-core` assertion

### Story 10.3: AppShell, Navigation & Login

As an operator,
I want to log in and navigate the admin UI with a persistent sidebar and breadcrumbs,
So that I can access all sections of the application.

**Acceptance Criteria:**

**Given** the AppShell component
**When** it is rendered for an authenticated user
**Then** it displays a CSS grid with: sticky header (full width, 48px), sidenav (240px fixed), and main content (flex-1)
**And** landmark roles are present (`<header role="banner">`, `<nav role="navigation">`, `<main role="main">`)
**And** a skip-to-content link is visible only on focus, landing on `<main>`

**Given** the AppShell for an unauthenticated user
**When** it is rendered
**Then** only the centered LoginForm is shown

**Given** the SideNav component at global scope
**When** it is rendered
**Then** it shows navigation items: Databases, Active tasks, Setup, About
**And** the active item shows neutral-100 background with 2px info-colored left border and `aria-current="page"`
**And** arrow-key navigation works via CDK FocusKeyManager

**Given** the SideNav when a database is in scope
**When** it is rendered
**Then** it switches to per-database sub-sections: Documents, Design Documents, Security

**Given** the Breadcrumb component
**When** it is rendered
**Then** it shows inline flex row of clickable segments separated by neutral-300 `/`
**And** the last segment is a non-clickable `<span>` with `aria-current="page"`
**And** it is wrapped in `<nav aria-label="Breadcrumb">`

**Given** the LoginForm component
**When** it is rendered
**Then** it displays a centered card (~360px) with iris-couch wordmark, username and password TextInputs, and Sign In primary button
**And** it is a real `<form>` with `<label>` for both inputs
**And** Enter in either input submits the form
**And** focus is on the username input on first render

**Given** valid credentials are submitted
**When** login succeeds via `POST /_session`
**Then** the session cookie is stored and the operator is redirected to the database list

**Given** invalid credentials are submitted
**When** login fails
**Then** the verbatim error envelope is shown below the form with 401 badge
**And** the username field is not reset

**Given** a 401 response is received on any authenticated request
**When** the session has expired
**Then** the operator is redirected to login with return-URL memory

**Given** the `?` key is pressed on any page
**When** the keyboard shortcut cheatsheet overlay opens
**Then** it lists available keyboard shortcuts

**Given** the viewport is below 1280px wide
**When** the page loads
**Then** the AppShell is hidden and a full-viewport message reads "iris-couch requires a viewport of at least 1280 pixels wide."

### Story 10.4: Database List View with Create & Delete

As an operator,
I want to see all my databases in a sortable table and create or delete databases,
So that I can manage my data stores through the UI.

**Acceptance Criteria:**

**Given** the database list view
**When** databases exist
**Then** a DataTable built on `cdk-table` displays columns: name (monospace), docs (integer, right-aligned), update seq (monospace, truncated with hover-for-full), size (human-readable, right-aligned)
**And** columns are sortable with `aria-sort` attributes
**And** default sort is name ascending
**And** whole rows are clickable with pointer cursor navigating to the database's document list
**And** rows use 28px height with 12px row text
**And** numeric columns use `font-variant-numeric: tabular-nums`

**Given** no databases exist
**When** the database list is displayed
**Then** an EmptyState shows "No databases yet. / Create one to get started." with a primary CTA button

**Given** the operator clicks "Create database"
**When** the ConfirmDialog (create variant) opens
**Then** it contains a single TextInput for database name
**And** CouchDB naming rules (lowercase, digits, `_$()-/`, cannot start with digit) are shown as hint text
**And** invalid names show client-side validation inline

**Given** the operator creates a database with a name that already exists
**When** the API returns 412
**Then** the verbatim error envelope is shown inside the dialog

**Given** the operator clicks delete on a database
**When** the ConfirmDialog (destructive-type-to-confirm) opens
**Then** it shows the exact database name in monospace with document count warning
**And** the delete button remains disabled until the typed name matches exactly

**Given** the database list is displayed
**When** data is loaded
**Then** a fetched-at timestamp is shown with relative format under 60s, absolute ISO-8601 when older
**And** a manual refresh button is available
**And** no auto-refresh occurs
**And** a 300ms-delayed 2px info-colored progress bar shows at the top during loading

### Story 10.5: Document List View with Filtering & Pagination

As an operator,
I want to browse documents in a database with filtering and pagination,
So that I can find and navigate to specific documents.

**Acceptance Criteria:**

**Given** a database with documents
**When** the document list is displayed
**Then** a DataTable shows `_id` (monospace) and `_rev` (monospace, truncated to 8 chars with hover-for-full or click-to-copy) columns
**And** default sort is `_id` ascending
**And** design documents appear inline with a subtle `[design]` Badge
**And** tombstoned documents show `[deleted]` Badge with greyed row

**Given** a filter bar above the document list
**When** the operator types in the filter input labeled "filter by `_id` prefix"
**Then** filtering uses `startkey`/`endkey` prefix matching with 150ms debounce
**And** the filter state is reflected in the URL
**And** a clear-filter IconButton appears inside the input's right edge

**Given** the `/` key is pressed on the document list
**When** the key event fires
**Then** focus moves to the filter input

**Given** the document list has more documents than the page size
**When** pagination controls are displayed
**Then** Pagination uses `startkey`-based forward/backward controls
**And** shows range indicator ("rows 1-25 of ~42,187") with approximate total
**And** no page numbers are shown
**And** `startkey` is reflected in the URL query parameter for stable browser back

**Given** the operator navigates to a document detail and presses browser back
**When** the document list is restored
**Then** pagination, sort, filter, and scroll position are preserved via Angular router state

**Given** all URLs in the document list view
**When** they are examined
**Then** `/_utils/db/{dbname}/` is deep-linkable, bookmarkable, and survives browser refresh

### Story 10.6: Document Detail View

As an operator,
I want to view a document's full JSON body, metadata, and attachments,
So that I can inspect document content and state.

**Acceptance Criteria:**

**Given** a document exists
**When** the document detail view is displayed
**Then** the header zone shows breadcrumb, `_id` in large monospace with CopyButton, full `_rev` in monospace with CopyButton, and fetched-at timestamp with refresh button

**Given** a document with special states
**When** the header is rendered
**Then** appropriate badges are shown: `[deleted]` (warn), `[has conflicts: N]` (warn), `[has attachments: N]` (info)

**Given** a document's JSON body
**When** the body zone is rendered
**Then** JsonDisplay shows the document in read-only pre-formatted monospace with palette-based syntax coloring (keys in neutral-700, strings in neutral-900, numbers in neutral-800, booleans/null in info)
**And** non-selectable line numbers appear on the left
**And** the content is the exact bytes of the HTTP response, pretty-printed with 2-space indent, no key reordering, no type coercion
**And** `role="textbox" aria-readonly="true" aria-label="Document JSON"` is set
**And** a "Copy raw JSON" button strip appears above the JSON display

**Given** a document with attachments
**When** the attachment zone is rendered
**Then** a compact list shows each attachment's name (monospace), content-type, length (human-readable), and digest (monospace, truncated)
**And** a download button links directly to `GET /{db}/{docid}/{attname}`

**Given** a document with conflicts and `[has conflicts: N]` badge
**When** the badge is clicked
**Then** all conflicting revisions are listed with the ability to click through and inspect each one

**Given** every `_id`, `_rev`, database name, and JSON body on the page
**When** the user wants to copy
**Then** a CopyButton is available next to each value
**And** "Copy raw JSON" produces byte-identical output to `curl /db/id`

**Given** a document that does not exist (404)
**When** the detail view is loaded
**Then** an ErrorDisplay shows the verbatim JSON error envelope in-place where the document would appear with a 404 Badge

**Given** the URL `/_utils/db/{dbname}/doc/{docid}`
**When** it is loaded directly
**Then** the view renders correctly as a standalone entry point

### Story 10.7: Error Handling, Accessibility & Cross-Browser Verification

As an operator,
I want consistent error handling, full keyboard accessibility, and cross-browser compatibility,
So that the admin UI is reliable and usable for all operators.

**Acceptance Criteria:**

**Given** the ErrorDisplay component
**When** an error is rendered
**Then** it shows error-colored 1px border, error-10% tinted background, HTTP status code Badge, `error` string in bold monospace, `reason` string in regular monospace
**And** optionally includes a single Retry button
**And** two variants are available: `full` (full-width) and `inline` (compact)
**And** `role="alert" aria-live="assertive"` is set
**And** content is always verbatim from server -- no "Oops", no rephrasing

**Given** a 5xx error response
**When** it occurs on any view
**Then** the error envelope is shown in-place where success content would appear

**Given** a network connectivity error
**When** the server is unreachable
**Then** the message "Cannot reach `/iris-couch/`. Check that the server is running." is shown with a manual Retry button

**Given** any interactive element in the UI
**When** keyboard navigation is tested
**Then** Tab/Shift+Tab follows visual order, Enter activates focused element, Esc closes dialogs, Space activates buttons, arrow keys navigate within SideNav and DataTable rows

**Given** CDK LiveAnnouncer integration
**When** navigation state changes or copy actions occur
**Then** announcements like "Loaded database list", "Loaded document `{id}`", "Copied." are made to screen readers

**Given** all text/background color combinations
**When** contrast ratios are measured
**Then** body text meets ~9:1 ratio, all semantic colors meet 4.5:1 for text and 3:1 for UI components (WCAG AA)

**Given** every status indicator in the UI
**When** color is used
**Then** it is always paired with text and/or an icon -- color is never the sole signal

**Given** the OS preference `prefers-reduced-motion: reduce`
**When** it is active
**Then** all transitions and animations are disabled

**Given** all animations in the UI
**When** their durations are measured
**Then** none exceeds 150ms except CopyButton success icon (~600ms) and ConfirmDialog open/close (max 100ms)

**Given** the admin UI
**When** tested across browsers
**Then** the defining flow (login -> database list -> document detail) works on current Chrome, Firefox, Safari, and Edge

**Given** every Angular component `.spec.ts` file (UX-DR65)
**When** automated tests are run
**Then** each spec includes at least one `axe-core` assertion covering color contrast, missing labels, invalid ARIA, and focus order
**And** component unit tests verify keyboard activation paths (Enter/Space on buttons, Esc on dialogs)
**And** integration tests for all 5 user flows assert correct click counts on the happy path

**Given** the alpha release manual testing checklist (UX-DR66)
**When** QA is performed
**Then** the checklist includes: keyboard-only smoke test of all flows, screen reader smoke test with NVDA or VoiceOver (verify ErrorDisplay `role="alert"` and CopyButton LiveAnnouncer), color-blind simulation via Chrome DevTools, reduced-motion toggle test, and cross-browser manual test on Chrome/Firefox/Safari/Edge

**Given** the prohibited patterns list
**When** the UI is reviewed
**Then** no toasts, no welcome tours, no dashboard landing page, no confirmation for reversible actions, no Material default styling, no CouchDB term relabeling, no auto-refresh without indicator, no client-side data masking, no multi-step wizards, no hover navigation, no charting dashboards are present

## Epic 11: Admin UI - Design Documents & Security Views

Operators can view and manage design documents and database security configuration through the admin UI.

### Story 11.1: Design Document List & Detail View (Alpha - Read-Only)

As an operator,
I want to view design documents stored in a database through the admin UI,
So that I can inspect map/reduce functions, validation hooks, and other design document content.

**Acceptance Criteria:**

**Given** a database contains design documents
**When** the operator navigates to the Design Documents section via the per-database SideNav
**Then** a DataTable lists all `_design/` prefixed document names in monospace

**Given** the design document list
**When** the operator clicks on a design document
**Then** the full JSON content is displayed via the JsonDisplay component
**And** the view is read-only (no edit controls at alpha)

**Given** the URL `/_utils/db/{dbname}/design/{ddocname}`
**When** it is loaded directly
**Then** the design document detail view renders correctly as a standalone entry point

**Given** any design document detail view
**When** CopyButton affordances are examined
**Then** the design document name and full JSON body have CopyButton available

### Story 11.2: Security Configuration View (Alpha - Read-Only)

As an operator,
I want to view the `_security` admin/member configuration for a database through the admin UI,
So that I can verify who has access to each database.

**Acceptance Criteria:**

**Given** a database with `_security` configuration
**When** the operator navigates to the Security section via the per-database SideNav
**Then** the full JSON security object is displayed via JsonDisplay
**And** the view is read-only (no edit controls at alpha)

**Given** a database with no `_security` configuration
**When** the Security section is displayed
**Then** the empty security object `{"admins":{"names":[],"roles":[]},"members":{"names":[],"roles":[]}}` is shown

**Given** the URL `/_utils/db/{dbname}/security`
**When** it is loaded directly
**Then** the security view renders correctly as a standalone entry point

### Story 11.3: Design Document & Security Editing (Beta)

As an operator,
I want to create, edit, and delete design documents and edit `_security` configuration through the admin UI,
So that I can manage database logic and access control without external tools.

**Acceptance Criteria:**

**Given** the TextAreaJson component (beta)
**When** it is rendered
**Then** it displays a resizable `<textarea>` with monospace font, line numbers gutter, and `spellcheck="false"`
**And** invalid JSON is highlighted with error message ("Invalid JSON at line 7")
**And** states: default, focus, disabled, invalid
**And** real `<label>` and `aria-describedby` are present

**Given** the design document detail view at beta
**When** the operator clicks Edit
**Then** the JsonDisplay switches to TextAreaJson for editing
**And** the operator can modify the JSON content and save via PUT to the API

**Given** the operator wants to create a new design document
**When** the create action is invoked
**Then** a ConfirmDialog (create variant) collects the design document name
**And** a TextAreaJson is presented for the document body

**Given** the operator wants to delete a design document
**When** the delete action is invoked
**Then** a ConfirmDialog (destructive-type-to-confirm) requires typing the exact design doc name
**And** on confirmation, the design doc is deleted via DELETE to the API

**Given** the security view at beta
**When** the operator clicks Edit
**Then** the JsonDisplay switches to TextAreaJson for editing the `_security` object
**And** the operator can save changes via PUT `/{db}/_security`

**Given** a JSON validation error during editing
**When** the operator attempts to save invalid JSON
**Then** an inline ErrorDisplay variant shows the validation error without closing the editor

**Given** the operator presses Esc while editing with unsaved changes
**When** the dialog or editor is closing
**Then** the ConfirmDialog has dirty-textarea awareness and warns about unsaved changes

### Story 11.4: Revision History View (Gamma)

As an operator,
I want to view a document's revision history through the admin UI,
So that I can understand how a document evolved and inspect specific revisions.

**Acceptance Criteria:**

**Given** a document with multiple revisions
**When** the operator navigates to the revision history view
**Then** an interactive RevisionTree component renders the revision tree as a graph
**And** CDK overlay popovers show node details on interaction

**Given** the revision tree graph
**When** the operator clicks on a revision node
**Then** the specific revision's content is displayed

**Given** a document with conflict branches
**When** the revision tree is displayed
**Then** all branches (including conflicts) are visible in the graph

**Given** the revision tree has many revisions
**When** filtering is needed
**Then** optionally a Select component allows filtering by revision type or branch

## Epic 12: Pluggable JavaScript Runtime

Operators can enable JavaScript execution for design-document views, validation hooks, and custom change filters.

### Story 12.1: JSRuntime Sandbox Interface & None Backend

As an operator,
I want IRISCouch to accept and store design documents regardless of JSRuntime configuration, with clear 501 responses when JS execution is unavailable,
So that I can migrate design documents before enabling a runtime.

**Acceptance Criteria:**

**Given** the `IRISCouch.JSRuntime.Sandbox` abstract class
**When** it is defined
**Then** it specifies abstract methods for: executing map functions, executing reduce functions, executing validate_doc_update, and executing filter functions

**Given** `Config.Get("JSRUNTIME")` returns `"None"` (the default)
**When** a client requests `GET /{db}/_design/{ddoc}/_view/{view}`
**Then** the response is 501 Not Implemented
**And** the error body contains `{"error":"not_implemented","reason":"JSRuntime backend is set to None. See [documentation link] to enable view execution."}`

**Given** any JSRuntime backend (including None)
**When** a client creates or updates a design document via `PUT /{db}/_design/{ddoc}`
**Then** the design document is stored and replicated normally
**And** no JavaScript execution is attempted during storage

**Given** `JSRuntime.None` is active
**When** any request would require JS execution (views, validate_doc_update, custom filters)
**Then** the response is 501 with a reason string that names the specific subsystem and points at enablement documentation

**Given** the configuration system
**When** `^IRISCouch.Config("JSRUNTIME")` is set to `"Subprocess"` or `"Python"`
**Then** the corresponding Sandbox implementation is used for JS execution

### Story 12.2: Subprocess JSRuntime - Map/Reduce Views

As an operator,
I want to execute user-supplied map-reduce view functions via a subprocess runtime,
So that I can query design-document views using Node, Bun, Deno, or couchjs.

**Acceptance Criteria:**

**Given** `Config.Get("JSRUNTIME")` is set to `"Subprocess"` and a valid runtime path is configured
**When** a client sends `GET /iris-couch/{db}/_design/{ddoc}/_view/{view}`
**Then** the map function from the design document is executed via `$ZF(-1)` subprocess using the couchjs line protocol
**And** the view results are returned as `{"total_rows":N,"offset":0,"rows":[{"id":"...","key":...,"value":...}]}`

**Given** a view with a reduce function
**When** the view is queried with `?reduce=true` (default)
**Then** the reduce function is executed on the map results

**Given** a view with a built-in reduce
**When** the reduce is `_sum`, `_count`, `_stats`, or `_approx_count_distinct`
**Then** the built-in reduce is executed natively without invoking the subprocess

**Given** the subprocess runtime
**When** it communicates with the couchjs process
**Then** the couchjs line protocol is followed (JSON lines over stdin/stdout)

**Given** the configured subprocess path
**When** it points to Node, Bun, Deno, or couchjs binary
**Then** any of these runtimes work interchangeably via the same line protocol

### Story 12.3: Subprocess JSRuntime - Validation & Filter Functions

As an operator,
I want `validate_doc_update` hooks and custom changes filter functions to execute via the subprocess runtime,
So that I can enforce document validation rules and filter changes using user JavaScript.

**Acceptance Criteria:**

**Given** a design document with a `validate_doc_update` function and `JSRuntime.Subprocess` is active
**When** any document write is processed by `DocumentEngine.Save()`
**Then** the validation function is executed via subprocess before the write commits
**And** if the validation throws, the write is rejected with 403 Forbidden and the thrown reason

**Given** a design document with a `validate_doc_update` function
**When** the validation function approves the write
**Then** the document write proceeds normally

**Given** a changes feed request with `filter={ddoc}/{filtername}` and `JSRuntime.Subprocess` is active
**When** changes are processed
**Then** the custom filter function from the design document is executed for each change
**And** only changes where the filter returns `true` are included in the response

**Given** `JSRuntime.None` is active
**When** a request would invoke `validate_doc_update` or a custom filter
**Then** the response is 501 Not Implemented with an appropriate reason

### Story 12.4: Python JSRuntime Backend

As an operator,
I want an alternative JSRuntime backend using embedded Python with QuickJS,
So that I can run design-document JavaScript without installing Node.js or other external runtimes.

**Acceptance Criteria:**

**Given** `Config.Get("JSRUNTIME")` is set to `"Python"` and IRIS embedded Python is available
**When** a client requests a view, validate_doc_update, or custom filter execution
**Then** the JavaScript function is executed via `%SYS.Python` with a QuickJS binding
**And** the results are identical to those produced by the Subprocess backend

**Given** the Python JSRuntime
**When** map/reduce, validate_doc_update, and filter functions are executed
**Then** the same Sandbox interface methods are used as the Subprocess backend
**And** the caller (DesignHandler, DocumentEngine, ChangesHandler) does not need to know which backend is active

**Given** embedded Python is not available on the IRIS instance
**When** `Config.Get("JSRUNTIME")` is set to `"Python"`
**Then** the system falls back gracefully with a clear error message indicating Python is not available

### Story 12.5: Incremental View Indexing, Caching & Sandbox Safety

As an operator,
I want view indexes maintained incrementally on writes with ETag caching, and sandbox safety limits,
So that view queries are fast and misbehaving user code cannot destabilize the server.

**Acceptance Criteria:**

**Given** a JSRuntime backend is enabled and a database has design documents with views
**When** a document is written via `DocumentEngine.Save()`
**Then** the view indexes are updated incrementally during the write (not deferred to query time)
**And** the index update is part of the write transaction

**Given** a view has been queried and the index has not changed since
**When** the client re-queries with the same ETag via `If-None-Match`
**Then** the response is 304 Not Modified with no body

**Given** a view index has changed since the last query
**When** the client re-queries
**Then** a new ETag is returned with the updated results

**Given** a user-supplied JavaScript function
**When** it is executed via any JSRuntime backend
**Then** a per-invocation timeout is enforced (default 5000ms from `Config.Get("JSRUNTIMETIMEOUT")`)
**And** if the timeout is exceeded, the subprocess is killed and an error is returned

**Given** a subprocess runtime under memory pressure
**When** memory limits are approached
**Then** the subprocess is restarted to prevent destabilizing IRISCouch
**And** the next invocation uses a fresh subprocess

**Given** any JSRuntime subprocess
**When** it is running
**Then** it has restricted filesystem and network access (NFR-S9)

## Epic 13: Documentation & Working Examples

Adopters have comprehensive documentation, a migration playbook, and working code examples that enable successful evaluation and adoption.

### Story 13.1: Getting Started Guide & Compatibility Matrix

As an adopter,
I want a Getting Started walkthrough and a live compatibility matrix,
So that I can evaluate IRISCouch quickly and understand which CouchDB APIs are supported.

**Acceptance Criteria:**

**Given** a new adopter with a fresh IRIS instance
**When** they follow the Getting Started guide
**Then** they can go from installation to first successful PouchDB replication in under one hour
**And** the guide covers: install via ZPM, configure reverse proxy (nginx/Apache example configs for root-mount on dedicated port), verify server is running, create a database, write a document, set up PouchDB sync
**And** the guide includes deployment topology options: recommended reverse proxy (with nginx and Apache examples) and direct mount path (with client compatibility caveats)

**Given** the compatibility matrix document (`compatibility-matrix.md`)
**When** an adopter reviews it
**Then** every CouchDB 3.x HTTP API endpoint is listed with one of: `supported`, `supported with caveat`, `501 in default config`, `out of scope with reason`
**And** the verification method used for each endpoint status is documented
**And** the matrix is updated on every release alongside code changes (NFR-I3)

### Story 13.2: Deviation Log, Migration Playbook & Troubleshooting Runbook

As an adopter,
I want to understand all differences from CouchDB, have a migration plan, and troubleshoot common issues,
So that I can confidently migrate from CouchDB to IRISCouch.

**Acceptance Criteria:**

**Given** the deviation log document (`deviations.md`)
**When** an adopter reviews it
**Then** every observable difference between IRISCouch and Apache CouchDB is listed with a rationale
**And** an unlogged deviation is treated as a release-blocking defect (NFR-M4)

**Given** the migration playbook document (`migration.md`)
**When** an adopter follows it
**Then** it covers: pre-migration checklist, install, replicate-in, validation, optional dual-write, cutover, source drain, and symmetric rollback
**And** each step has clear success/failure criteria

**Given** the troubleshooting runbook document (`troubleshooting.md`)
**When** an operator encounters a common issue
**Then** the runbook covers at minimum the top 5 incident classes: replication lag, checkpoint corruption, stuck conflicts, attachment stream failures, and JS sandbox errors
**And** each entry includes: symptoms, diagnostic steps, resolution, and prevention
**And** new incident classes from customer zero or external adopters become new entries before the next release (NFR-M3)

**Given** any documentation artifact
**When** a code change affects its content
**Then** the documentation is updated in the same commit (NFR-M2)

### Story 13.3: Working Code Examples

As an adopter,
I want six working code examples in the repository,
So that I can learn IRISCouch patterns by running real code.

**Acceptance Criteria:**

**Given** the `examples/` directory
**When** an adopter lists its contents
**Then** six examples are present: `hello-document`, `pouchdb-sync`, `replicate-from-couchdb`, `mango-query`, `attachment-upload`, `jsruntime-subprocess-node`

**Given** the `hello-document` example
**When** it is run against a fresh IRISCouch instance
**Then** it demonstrates creating, reading, updating, and deleting a document

**Given** the `pouchdb-sync` example
**When** it is run
**Then** it demonstrates bidirectional sync between PouchDB and IRISCouch

**Given** the `replicate-from-couchdb` example
**When** it is run with a CouchDB instance available
**Then** it demonstrates pulling data from CouchDB into IRISCouch

**Given** the `mango-query` example
**When** it is run
**Then** it demonstrates creating a Mango index and querying with selectors

**Given** the `attachment-upload` example
**When** it is run
**Then** it demonstrates uploading and downloading binary attachments

**Given** the `jsruntime-subprocess-node` example
**When** it is run with Node.js available
**Then** it demonstrates enabling the Subprocess JSRuntime and querying a design-document view

**Given** any tagged release
**When** CI runs
**Then** all six examples compile and execute successfully -- a broken example blocks the release

## Epic 14: Gamma - Streaming Feeds & ECP Clustering

Clients can subscribe to continuous and eventsource change feeds; operators can deploy IRISCouch across ECP distributed-cache clusters for high availability.

### Story 14.1: Continuous & EventSource Changes Feeds

As a client,
I want to subscribe to changes via `feed=continuous` and `feed=eventsource` modes for real-time streaming,
So that I can receive changes as a continuous stream without repeated HTTP requests.

**Acceptance Criteria:**

**Given** a database with changes and a `%Net.TCPServer` standalone listener running
**When** a client connects via `feed=continuous`
**Then** changes are streamed as newline-delimited JSON lines
**And** each line contains a single change entry `{"seq":N,"id":"...","changes":[{"rev":"..."}]}`
**And** the stream remains open, delivering new changes as they occur

**Given** a client connected to a continuous feed
**When** a new document write commits
**Then** the change is delivered to the stream via `$System.Event` signaling

**Given** a database with changes
**When** a client connects via `feed=eventsource`
**Then** changes are streamed in Server-Sent Events format (`data: {...}\n\n`)
**And** the stream uses `Content-Type: text/event-stream`

**Given** a continuous or eventsource feed
**When** no changes occur for a period
**Then** heartbeat messages are sent at the configured interval to keep the connection alive

**Given** the CSP Gateway buffering limitation
**When** continuous or eventsource feeds are served
**Then** they are delivered via the `%Net.TCPServer` standalone listener, bypassing CSP Gateway entirely

**Given** filters are specified on a continuous or eventsource feed
**When** changes are streamed
**Then** the same built-in filters (`_doc_ids`, `_selector`, `_design`) work as they do for normal and longpoll feeds

### Story 14.2: ECP Clustering & Mirror Failover Verification

As an operator,
I want to deploy IRISCouch across ECP distributed-cache clusters with verified mirror failover behavior,
So that I can achieve high availability for my CouchDB-compatible workloads.

**Acceptance Criteria:**

**Given** IRISCouch deployed on an ECP distributed-cache cluster
**When** document operations are performed
**Then** all globals (`^IRISCouch.Docs`, `^IRISCouch.Tree`, `^IRISCouch.Changes`, `^IRISCouch.Seq`, `^IRISCouch.Atts`, `^IRISCouch.Local`, `^IRISCouch.DB`, `^IRISCouch.Config`) work correctly across ECP
**And** SQL projections (`Winners`, `MangoIndex`) are accessible across cluster nodes

**Given** an IRIS mirror failover occurs during normal operation
**When** the promoted mirror takes over
**Then** all replication checkpoints in `^IRISCouch.Local` survive with correct sequence continuity (NFR-R5)
**And** resumed replication picks up from the last checkpoint without rewinding or duplicating work

**Given** an IRIS mirror failover occurs during an active replication
**When** the promoted mirror resumes
**Then** the replication detects the existing checkpoint and continues from the correct sequence

**Given** the conformance test suite
**When** run against an ECP-clustered IRISCouch deployment
**Then** all tests pass identically to single-server deployment

**Given** the gamma milestone
**When** the conformance harness is updated
**Then** CouchDB 3.5.x is added as a conformance anchor alongside 3.3.3
