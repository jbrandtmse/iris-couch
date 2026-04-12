---
type: bmad-distillate
sources:
  - "prd.md"
downstream_consumer: "architecture design"
created: "2026-04-11"
token_estimate: 4200
parts: 1
---

## Core Identity & Strategy

- IRISCouch: open-source, wire-compatible Apache CouchDB 3.x server implemented natively in InterSystems IRIS ObjectScript; Apache 2.0 licensed; distributed via GitHub + ZPM/IPM
- Core insight: CouchDB is a wire protocol, not a database; scope collapses from "build a database" to "build a wire-protocol facade over IRIS"
- Classification: api_backend + developer_tool; general domain (not healthcare software, but healthcare-adjacent audience); medium domain / high technical complexity; greenfield code with locked pre-PRD architectural decisions from 2,039-line research report
- Entire MVP = Phases 0-7; milestones alpha/beta/gamma are progress checkpoints within one MVP, not staged splits
- alpha = Public Alpha (prove wire-compat credibility); beta = Customer Zero Complete (prove origin story); gamma = MVP Feature-Complete / 1.0 tag
- Sequencing: alpha must ship before beta; beta and gamma can run in parallel
- MVP philosophy: problem-solving MVP (retire customer zero's 3 production CouchDB DBs) + platform secondary dimension (prove globals-for-writes + sync SQL projection pattern); not revenue/market-validation/user-acquisition MVP
- Resource profile: one developer + AI coding agents; no hiring; no deadline (quality-gated, not calendar-gated); bus factor = 1 (acknowledged risk)
- Customer zero forcing function: author's 3 production CouchDB databases (~10K docs, ~500 MB, 4 map-reduce views, 2 filters); every release exercised against this before public tag
- No commercial productization; no paid tiers; no managed service; no enterprise support; community-building pushes explicitly paused during MVP
- Category of one in 2026: only actively-developed, production-grade, non-Apache CouchDB-compatible server
- Market timing: CouchDB 3.4 (Sep 2024) adopted QuickJS because Red Hat dropped SpiderMonkey from RHEL 9; migration window open for IRIS shops on older CouchDB
- Scope non-negotiables: (1) ObjectScript only backend language; (2) Angular only admin UI language; (3) wire-compat measured via 3-layer conformance suite; (4) ^IRISCouch.* globals + IRISCouch.* classes naming; (5) no commercialization; (6) zero mandatory external deps at MVP default; (7) JS runtime pluggable/operator-selected; (8) Phases 0-7 = MVP; (9) customer zero = forcing function + continuous regression

## Users & Success

- Two archetypes: adopting operators (IRIS teams standing up IRISCouch) and client developers (PouchDB/replicator/nano/Cloudant SDK/Fauxton users whose code should not change)
- Aha moment: PouchDB or CouchDB replicator syncs bidirectionally with zero client-side changes
- Completion: operator retires CouchDB process; rollback is symmetric (replicate back out); backup is one thing (standard IRIS tooling)
- User success: client developers feel nothing; operators feel relief
- Business success = project health + adoption signals (not revenue); milestones alpha/beta/gamma are primary bar
- Gating outcomes table: PouchDB bidir sync (alpha); CouchDB replicator clean (alpha); customer-zero 10K docs/500MB/3DBs/4views/2filters served (beta); standalone CouchDB retired (beta); CouchDB 3.x feature inventory delivered-or-scoped (gamma); differential harness must-diff-zero (alpha+); PouchDB conformance 100% (alpha+); CouchDB JS tests pass (alpha+); zero-dep install (alpha); mirror failover continuity (gamma); attachment RSS non-proportional (alpha); conformance vs 3.5.x green (gamma)
- Soft metric: >=1 external adopter running real workload within alpha+12 months
- Technical success: replication corruption = unshippable defect class (full stop); 3-layer conformance suite gates every release; zero-dep install at alpha; atomic writes in single journaled IRIS transaction; attachment streaming without RSS growth; HA via IRIS mirroring; Prometheus/OTel at alpha; %SYS.Audit at day one
- Anti-metrics: not measuring CouchDB community mindshare, Open Exchange downloads, external contributor count, market share vs Apache CouchDB
- Journey requirements summary (9 areas, all non-negotiable for MVP): (1) wire-compatible HTTP surface verifiable via diff harness; (2) zero-dep ZPM install; (3) replication protocol completeness (bidir, checkpoints survive restart, conflict trees preserved); (4) JSRuntime.Subprocess production-complete by beta; (5) observability at alpha (Prometheus/OTel); (6) actionable error responses (501s name subsystem + point at docs); (7) inherited ops surface (mirroring, backup, audit); (8) published docs: Getting Started, migration playbook, troubleshooting runbook, compat matrix; (9) lightweight built-in Angular admin UI at /_utils/

## Locked Architectural Decisions

- CQRS hybrid storage: writes to raw multi-dimensional globals (^IRISCouch.Docs, ^IRISCouch.Tree, ^IRISCouch.Changes, ^IRISCouch.Atts via %Stream.GlobalBinary, ^IRISCouch.Local); reads for Mango through %Persistent Winners projection (IRISCouch.Projection.Winners) + runtime MangoIndex table (IRISCouch.Projection.MangoIndex, avoids runtime class recompilation)
- Synchronous SQL projection maintained in same journaled transaction as write; zero eventual-consistency window; feasible because IRIS journals span raw globals + %Persistent atomically
- Fallback: async projection with bounded lag window behind feature flag if sync projection regresses at scale (post-alpha benchmarking determines ceiling)
- JSRuntime.Sandbox pluggable interface with 3 backends: None (501 default, zero deps), Subprocess (Node/Bun/Deno/couchjs via $ZF(-1), couchjs line protocol), Python (%SYS.Python + PetterS quickjs); JS is operator-selected capability, not hard prerequisite
- Innovation: first CouchDB-family impl where wire-compat and JS-capable are independent operator-selected axes
- Rev-hash algorithm: JSON-canonical MD5 of revision tuple; replication-protocol-sufficient, not byte-identical to CouchDB's Erlang ETF hash (documented deviation)
- replication_id: own JSON-canonical MD5; deterministic, survives restart, resumes from last checkpoint
- HTTP dispatch: %CSP.REST web application; HTTP/1.1 required, HTTP/2 not required; CSP Gateway handles version negotiation
- Streaming feeds (continuous/eventsource): 501 at alpha/beta; standalone %Net.TCPServer listener on separate port at gamma (bypasses CSP Gateway response buffering)
- Attachments: %Stream.GlobalBinary + %Net.MIMEReader for multipart/related parsing without full-body buffering
- Changes feed: $Increment-backed atomic sequence generation per database
- Auth: _users DB with PBKDF2 via IRIS primitives; _session cookie auth with HMAC (Phase 6 spike for byte-compat); Basic/JWT/proxy auth; credentials in IRIS Security.* classes, not shadow store; _security enforcement at HTTP dispatch layer
- Deliberately NOT innovative: not new wire protocol, not new storage engine, not new query language, not new JS sandbox impl, not new conflict resolution model
- Implementation language split (binding rule): ObjectScript exclusively for server backend; TypeScript/Angular exclusively for admin UI (compiled to static bundle, no Node at install time); no drift between layers

## Wire Protocol Contract

- Endpoint spec rules: method allowance byte-identical to CouchDB (derived from source, not docs); status codes match exactly (200/201/202/304/400/401/403/404/405/406/409/412/413/415/416/417/500/501/503)
- JSON error envelope: {"error": "<slug>", "reason": "<human-readable>"}; slug parity enforced by diff harness
- Error slugs committed: not_found (404); conflict (409); unauthorized (401); forbidden (403); bad_request (400); doc_validation (400); missing_stub (412); invalid_design_doc (400); file_exists (412); illegal_database_name (400); internal_server_error (500); not_implemented (501); partial (202)
- Content negotiation: application/json (default), multipart/related, multipart/mixed, text/event-stream (gamma); unknown Accept types fall back to application/json with 200 (permissive, matching CouchDB)
- UTF-8 required; non-UTF-8 returns 400 bad_request invalid_utf8
- Data schema envelopes (locked wire contract): document (_id, _rev N-hex32, _deleted, _attachments, _conflicts, _revs_info, _revisions, _local_seq, user fields); design doc (language, views, validate_doc_update, filters, etc.); replication doc (source, target, _replication_id/state/stats); _security (admins/members with names/roles); _local/ checkpoint (session_id, source_last_seq, history[]); attachment metadata (content_type, revpos, digest md5-base64, length, encoding, stub/data/follows)
- Auth model: Basic (IRIS user directory), cookie (_session HMAC-signed AuthSession), JWT (operator-configured issuers/keys), proxy (X-Auth-CouchDB-* headers + shared secret); _users DB maps to IRIS users 1:1; passwords hashed PBKDF2 in IRIS user record not doc body; not supported at MVP: OAuth 1.0a, LDAP direct
- Rate limits: none first-party at MVP; delegated to IRIS web stack + operator front proxies (matches CouchDB posture)
- API docs: CouchDB 3.x docs at docs.couchdb.org is canonical spec; IRISCouch ships compatibility matrix (docs/compatibility-matrix.md), deviation log (docs/deviations.md), ObjectScript class docs; no OpenAPI spec, no auto-generated SDKs
- Versioning: two independent anchors: (1) CouchDB 3.3.3 wire conformance baseline through beta, 3.5.x added at gamma, 4.x tracked not targeted; (2) IRISCouch SemVer (0.x.y-alpha.N, 0.x.y-beta.N, 1.0.0 at gamma); wire contract stable for CouchDB 3.x lifetime; ObjectScript public API follows SemVer; private impl (globals layout, SQL projection) explicitly not backward-compatible
- Language support matrix (smoke-tested): PouchDB 9.x (JS), CouchDB replicator 3.3.3+3.5.x (Erlang), nano 10.x (Node), @cloudant/cloudant 5.x (Node), Fauxton (browser SPA); community-compatible (not gated): older PouchDB, python-cloudant, cloudant-java, couchdb4j, sofa, couchdb-go; explicitly not supported: Couchbase SDKs
- Install: primary = ZPM/IPM (zpm "install iris-couch"); manual fallback = $System.OBJ.ImportDir + webapp creation; NOT committed: Open Exchange, Docker Hub, Helm chart
- 6 shipped examples verified by CI (release-blocking): hello-document, pouchdb-sync, replicate-from-couchdb, mango-query, attachment-upload, jsruntime-subprocess-node
- Migration playbook (docs/migration.md): pre-migration checklist, install, replicate-in, validate, dual-write, cutover, drain, symmetric rollback, post-migration

## Functional Requirements

- Database Lifecycle (FR1-FR8): PUT create DB (201/412 file_exists); DELETE drop DB; GET /_all_dbs; GET /{db} metadata; PUT _revs_limit; POST _compact; POST _ensure_full_commit
- Document Storage/Revisions/Conflicts (FR9-FR20): POST with server UUID; PUT with client ID; GET with ?rev/?revs/?revs_info/?conflicts/?local_seq; DELETE produces tombstone; 409 on stale _rev; conflict detection/storage/inspection; deterministic winning-rev algorithm; _bulk_docs; _bulk_docs new_edits=false; _bulk_get with revisions; open_revs=all/specific; reject user underscore fields with 400 doc_validation
- Document Listing & Changes Feed (FR21-FR30): _all_docs with pagination/key-range/include_docs; POST _all_docs with keys; feed=normal; feed=longpoll; _doc_ids filter; _selector filter; _design filter; feed=continuous (gamma, TCP listener); feed=eventsource (gamma, TCP listener); monotonic atomic sequence per DB
- Attachments (FR31-FR40): inline base64; multipart/related upload; standalone PUT; raw GET; multipart/mixed response; atts_since; stubs-only default; content inclusion; streaming without memory buffering; MD5 digest computation, round-trip through replication
- Mango Query & Indexing (FR41-FR50): _find with selector/fields/sort/limit/skip/use_index/r; _index create json type; _index list; _index delete; _explain; partial_filter_selector; full selector operator set ($gt/$gte/$lt/$lte/$ne/$in/$nin/$exists/$type/$and/$or/$nor/$not/$regex/$elemMatch/$allMatch); fallback full scan; design-doc views via JSRuntime; built-in reduces _sum/_count/_stats/_approx_count_distinct
- Replication (FR51-FR59): _revs_diff; _bulk_get revs=true&attachments=true; _local/ checkpoint PUT/GET; _local/ excluded from changes/all_docs/replication; _replicator DB continuous jobs; replication state written back to _replicator doc; deterministic replication_id survives restart; bidirectional replication vs real CouchDB 3.x; JSON-canonical MD5 rev hashes
- Auth/Security (FR60-FR71): Basic auth vs IRIS user directory; POST _session cookie auth; GET _session; DELETE _session logout; JWT bearer; proxy auth (X-Auth-CouchDB-*); _users DB synced to IRIS users; PBKDF2 via IRIS; _security PUT; _security enforcement before doc logic; 401 unauthorized; 403 forbidden
- JSRuntime (FR72-FR82): operator selects None/Subprocess/Python; default=None; design docs stored/replicated regardless of backend; 501 with actionable reason on None; Subprocess: map-reduce via couchjs line protocol, validate_doc_update, _changes filters; Python: same via embedded QuickJS; incremental view index maintenance on write; ETag/304 view caching; per-invocation timeout + memory-restart
- Admin UI (FR83-FR95): alpha: _utils path, Angular SPA static assets, list/create/delete DBs, per-DB metadata, document list+detail (paginated), read-only design docs, read-only _security; beta: design doc CRUD, _security edit; gamma: revision history view
- Observability/Audit/Ops (FR96-FR105): Prometheus/OTel scrape (request counts, latency histograms, replication throughput, _changes lag, Mango hit rate, error counters); %SYS.Audit for every doc write, auth attempt, _security change, _users write, replication session start/complete; all state in IRIS namespace (mirroring/backup/journal automatic); checkpoint durability through hard kill; mirror failover continuity; actionable reason strings in errors
- Distribution/Install/Docs (FR106-FR115): ZPM single-command install; manual ImportDir fallback; configurable webapp mount (default /iris-couch/); zero mandatory external deps; Getting Started walkthrough (<1hr to PouchDB sync); live compatibility matrix; deviation log; migration playbook; troubleshooting runbook (top 5 incident classes); 6 working examples (CI-verified, release-blocking)

## Non-Functional Requirements

- Performance: NFR-P1 write latency <=2x CouchDB 3.3.3 median on 10K-doc workload; NFR-P2 read latency <=1.5x; NFR-P3 Mango _find with index <=2x; NFR-P4 replication throughput <=2x (bidir, 10K docs, 500MB); NFR-P5 _bulk_docs 1K docs consistent with P1; NFR-P6 _changes longpoll freshness <500ms zero contention, <2s under load; NFR-P7 read-after-write zero staleness for Mango (sync CQRS guarantee); NFR-P8 attachment streaming RSS not proportional to size (KB buffer, not MB); post-alpha benchmarking publishes empirical results
- Reliability: NFR-R1 replication corruption = unshippable (halt release); NFR-R2 atomic write (body+rev tree+changes+projection+attachments in single IRIS txn); NFR-R3 crash recovery = IRIS journal replay; NFR-R4 _local/ checkpoints survive hard kill + restart with correct seq; NFR-R5 mirror failover continuity (gamma validation); NFR-R6 every bug produces regression test before fix ships; NFR-R7 availability = IRIS availability, no added downtime
- Security: NFR-S1 credentials never duplicated (IRIS user directory only); NFR-S2 PBKDF2 >=10K iterations; NFR-S3 HMAC-signed cookies, tampering detected; NFR-S4 TLS via %Service_WebGateway/CSP Gateway (IRISCouch does not terminate TLS); NFR-S5 audit completeness (every mutation, auth attempt, _security change, _users write, replication session in %SYS.Audit); NFR-S6 _security checks at HTTP dispatch before storage; NFR-S7 no telemetry phone-home (only operator-configured replication + OTel push); NFR-S8 stack traces logged not sent to client; NFR-S9 JSRuntime subprocess sandbox isolation (Node --permission/Bun/Deno sandbox/couchjs) + per-invocation timeout+memory limits
- Scalability: NFR-SC1 validated envelope = 10K docs/DB, ~500MB, low-tens concurrent writers, single-digit views/filters; NFR-SC2 larger workloads explicitly unvalidated (documented caveat); NFR-SC3 graceful degradation under projection backpressure (503, not silent drop); NFR-SC4 async projection fallback behind opt-in flag; NFR-SC5 ECP clustering supported at gamma only
- Observability: NFR-O1 metric freshness <=10s; NFR-O2 bounded label cardinality (DB name OK, doc ID not); NFR-O3 metrics endpoint available whenever API is; NFR-O4 actionable error reason fields (name subsystem + failure mode); NFR-O5 structured logs (JSON/KV, plain-text for debug only); NFR-O6 audit events synchronous within same transaction
- Accessibility (admin UI only): NFR-A1 full keyboard navigability; NFR-A2 WCAG AA contrast ratios; NFR-A3 screen reader best-effort (semantic HTML + ARIA); NFR-A4 no Flash/Silverlight; not committed: full WCAG 2.1 AA cert, Section 508, i18n (English only at MVP)
- Integration: NFR-I1 3-layer conformance suite gates every release (CouchDB JS tests, PouchDB replication, diff harness); NFR-I2 diff harness must-diff-zero on wire-contract subset; NFR-I3 compat matrix updated every release (CI-enforced); NFR-I4 client smoke tests re-run every release; NFR-I5 wire protocol stable within 3.x anchor; NFR-I6 new CouchDB 3.x point releases absorbed within one IRISCouch release cycle
- Maintainability: NFR-M1 customer-zero regression on every release; NFR-M2 doc artifacts updated same commit as code (CI-enforced); NFR-M3 runbook covers top 5 incident classes at alpha, expands per findings; NFR-M4 deviation log covers every observable difference (undocumented deviation = release-blocking); NFR-M5 bus-factor posture (Apache 2.0, forkable, self-documented); NFR-M6 /// doc comments on all public ObjectScript classes; NFR-M7 conformance suite must run every RC (no "skipped it" pattern); NFR-M8 release cadence quality-gated not calendar-gated

## Risks & Scope Boundaries

- R1 (high): replication protocol edge cases not in research; mitigation: 3-layer conformance + customer-zero regression + new test before fix
- R2 (medium): CSP Gateway buffers streaming feeds; mitigation: 501 at alpha/beta, %Net.TCPServer at gamma; PouchDB/replicator default to longpoll so replication unaffected
- R3 (medium): Mango selector edge cases ($elemMatch, $allMatch, $regex on arrays) hard in IRIS SQL; mitigation: fallback scan path, documented performance caveat
- R4 (medium-low): sync SQL projection regression at scale beyond 10K/500MB; mitigation: post-alpha benchmarking, async fallback behind feature flag
- R5 (medium): JSRuntime.Subprocess IPC complexity for couchjs line protocol; mitigation: narrow beta target to customer zero's function classes, expand during stabilization
- R6 (low): AuthSession cookie HMAC byte-compat (Phase 6 spike); fallback: re-login-once acceptable if documented
- R7 (medium credibility / low viability): N=1 adopter thin signal; mitigation: Devi's journey defines evaluation surface; soft metric tracked not gating
- R8 (medium vision / low MVP): "default answer for offline-first on IRIS" requires adoption; mitigation: MVP does not depend on vision realization
- R9 (medium, delayed): CouchDB 4.x wire changes; mitigation: anchor to 3.x, track 4.x, separate follow-on if needed
- R10 (high long-term / low short-term): single-developer bus factor; mitigation: Apache 2.0, documented, forkable, AI agents extend capacity
- R11 (low): "no deadline" risk of never shipping; mitigation: customer zero's migration pressure is implicit deadline
- R12 (N/A): "fewer resources" scenario not applicable; already at floor
- Growth features (post-MVP, not committed): CouchDB 4.x wire protocol; partitioned databases; Nouveau/Clouseau full-text search; Mango $text operator; CouchDB 4.x clustered design; additional smoke-tested client versions; JSRuntime.QuickJS embedded-native backend
- Vision (3-year): default answer for offline-first on IRIS; pattern extraction as reusable template (Mongo-on-IRIS, DynamoDB-on-IRIS, Firebase-on-IRIS); whether extractability holds is open question answered by shipping IRISCouch first
- Vision non-goals: no commercial productization; not for teams not on IRIS; not competing as general-purpose document DB
- Rejected/dormant alternatives in ecosystem: PouchDB Server (community, not production-grade); Cloudant (cloud-only, vendor lock-in); Couchbase (not wire-compatible); BigCouch, rcouch, couch4j, kivik (all dormant 2026); IRIS DocDB (proprietary API, no CouchDB compat, complementary not competing)
- Explicit non-goals: Open Exchange submission at MVP; Docker/Helm distribution; OpenAPI spec; auto-generated client SDKs; OAuth 1.0a; LDAP direct integration; full WCAG 2.1 AA; Section 508; i18n; token-bucket rate limiting; per-DB write quotas; commercial anything
