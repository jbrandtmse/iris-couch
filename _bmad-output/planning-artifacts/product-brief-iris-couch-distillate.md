---
title: "Product Brief Distillate: IRIS Couch"
type: llm-distillate
source: "product-brief-iris-couch.md"
created: "2026-04-11"
purpose: "Token-efficient context for downstream PRD creation — dense, thematic, decision-carrying bullets. Every bullet is self-contained; no need to load the full brief."
---

# IRIS Couch — Distillate for PRD Creation

## 1. Core Identity

- **IRIS Couch** is an open-source, wire-compatible Apache CouchDB 3.x server implemented natively in InterSystems IRIS ObjectScript. Existing CouchDB clients (PouchDB, the Apache CouchDB replicator, Cloudant SDKs, Fauxton) connect and cannot tell they are not talking to real CouchDB.
- **Repository/package name**: `iris-couch` (GitHub, published to ZPM/IPM).
- **Human-readable product name**: IRIS Couch.
- **License**: Apache 2.0.
- **Tagline**: *"Bring offline-first replication to IRIS — without adding a second database."*
- **Primary positioning angle locked by user**: (b) capability angle — not consolidation, not blue-ocean, not credibility. The pitch is "get CouchDB's offline-first sync on IRIS without a second DB process."
- **Category of one**: In 2026, IRIS Couch is the only production-grade, actively-developed CouchDB-compatible server outside of Apache CouchDB itself. Backed by research confirming PouchDB Server is community-maintained and not positioned for production, Cloudant is cloud-only, Couchbase is not wire-compatible, BigCouch/rcouch/couch4j/kivik are dormant.

## 2. Personal Motivation (Origin)

- **The soul of the project**: the author has used Apache CouchDB for years and believes nothing else exists like it. Offline-first replication, MVCC conflict model, simple HTTP API, design-doc conventions — a singular combination the author wants to preserve on IRIS.
- **The project intent in one line** (author's own words): *"I want to merge the best of both worlds of CouchDB and IRIS."*
- **Not a rescue mission**: the brief explicitly avoids anti-CouchDB framing. CouchDB is healthy and well-maintained. IRIS Couch is an alternative backend for teams with a specific reason to consolidate, not a CouchDB migration target.

## 3. Customer Zero (Forcing Function)

- **Three production CouchDB databases** to migrate off standalone CouchDB onto IRIS Couch.
- **Scale**: approximately 10,000 documents, ~500 MB total (including attachments), across all three.
- **Query patterns**: mix of Mango `_find` AND map-reduce views — four views, two filters across the three databases.
- **Implication**: JSRuntime.None is insufficient for the author's own migration. JSRuntime.Subprocess (or .Python) is on the critical path for customer-zero acceptance at Milestone β.
- **No pre-committed first app as acceptance test** — the user is open to how the internal migration is staged as phases land. Migration can be incremental (small DBs first, then medium).
- **Dogfooding credibility**: the brief's strongest differentiator from the graveyard of dormant reimplementations. Every release is exercised against real production data before any public tag.

## 4. Audience and Market

- **Audience reality**: IRIS Couch runs inside IRIS and requires an IRIS instance (Community Edition for evaluation, licensed IRIS for production). Named upfront in the brief.
- **Primary audience**: IRIS/HealthShare shops with existing CouchDB applications paying a dual-database operational tax. Success = existing PouchDB clients keep working, one DB process goes away.
- **Natural fit — healthcare NGO / field-work**: eHealth Africa, Medic Mobile / Community Health Toolkit, HospitalRun, GRADEpro GDT (deployed in 135+ countries) run CouchDB+PouchDB in production. These organizations overlap suspiciously well with HealthShare's existing buyer profile.
- **Secondary audience**: new IRIS projects that need offline-first sync without bolting on CouchDB.
- **Tertiary but critical**: customer zero — the author's own team.
- **Market sizing**: no reliable public data on IRIS+CouchDB overlap. Customer zero is the only confirmed instance. Working hypothesis: teams facing this had nowhere to advertise the pain because there was no off-ramp. Brief states this honestly rather than faking a number.
- **Deliberately NOT targeted**: the general CouchDB open-web community. IRIS Couch cannot be adopted by anyone not already on IRIS.

## 5. What Is NOT In Scope (Rejected or Explicitly Excluded)

**Rejected during research — do not re-propose**:

- **Reproducing CouchDB's Erlang ETF-based rev hash byte-for-byte**. Source-spike proved CouchDB does not verify the hash on the replicated-write path (`new_edits=false` is used as-is). Would take days to reimplement vs hours for a JSON-canonical MD5 that works just as well. Rejected.
- **Reproducing CouchDB's Erlang ETF-based `replication_id` byte-for-byte**. Same pattern: source-spike proved it is a lookup key into `_local/*` checkpoints and never verified. Rejected.
- **Mandatory `%SYS.Python` + QuickJS as the only JS sandbox**. Spike 5 showed Python requires operator CPF setup (not wired on the test host). Rejected as a hard MVP dependency.
- **`feed=continuous` / `feed=eventsource` on the default Apache + mod_csp gateway**. Spike 4b proved live that the gateway buffers the full response before forwarding — `time_starttransfer=5.08s` for a handler that ran for 5 seconds emitting 10 flushed lines. Rejected as a Phase-1-through-5 implementation path.
- **Supporting CouchDB 4.x wire protocol**. Out of scope; anchor to CouchDB 3.x stable.
- **Cloudant-specific query/index extensions**. Out of scope.
- **Deprecated CouchDB surfaces**: `_show`, `_list`, `_update`, `_rewrite`, `_temp_view`. Already deprecated in CouchDB 3.x, off by default upstream, slated for removal in 4.x. Never in scope.
- **Partitioned databases**. Out of scope; not required for the author's workload or the primary audience.
- **Nouveau / Clouseau full-text search**. Out of scope.
- **Native Erlang ETF encoding (in any form)**. Deliberate architectural choice; JSON-canonical MD5 is wire-protocol sufficient.
- **Commercial productization**: no managed service, no paid tiers, no enterprise support contracts.
- **Community-building push in phase one**: no active courting of external contributors, no CouchDB community outreach, no InterSystems Developer Community campaign, no Open Exchange partnership drive — all paused by explicit user decision.

## 6. Accepted Architectural Decisions

- **CQRS hybrid storage**: raw IRIS multi-dimensional globals for writes (documents, revision trees, changes feed via `$Increment`, attachments via `%Stream.GlobalBinary`, `_local/` checkpoints). IRIS SQL projection (a `%Persistent` shadow table plus a runtime index table) for Mango reads. Maintained synchronously on every write inside the same journaled transaction.
- **Pluggable JSRuntime sandbox**: single abstract interface (`CouchPort.JSRuntime.Sandbox`) with three swappable backends:
  - `CouchPort.JSRuntime.None` — MVP default, returns 501 for all JS ops. Zero dependencies.
  - `CouchPort.JSRuntime.Subprocess` — spawns Node/Bun/Deno/couchjs via `$ZF(-1)`, implements CouchDB's couchjs line protocol. Ships at β for customer zero.
  - `CouchPort.JSRuntime.Python` — %SYS.Python + PetterS quickjs, in-process execution. Secondary option at β.
- **Own rev-hash algorithm**: JSON-canonical MD5 of `{d,p,b,a}` where `d`=deleted flag, `p`=parent rev id, `b`=body minus `_id`/`_rev`/`_revisions`/`_attachments`, `a`=sorted attachment digests. Format: `N-<32 lowercase hex>`. Deterministic, replication-protocol sufficient.
- **Own replication_id algorithm**: JSON-canonical MD5 of source/target/filter/options bag. Same canonicalizer as rev hash. Produces valid `_local/` checkpoint IDs.
- **HTTP dispatch**: `%CSP.REST` subclass with UrlMap covering every CouchDB endpoint. JSON error envelope shape `{"error":"<slug>","reason":"<human>"}` matches CouchDB exactly.
- **Attachments**: `%Stream.GlobalBinary` underlying storage; `%Net.MIMEReader` with `OpenStream()` for multipart/related parsing — stream-in/stream-out confirmed by live spike, no memory buffering of large attachments.
- **Changes feed**: two of four feed modes (normal, longpoll) work through the CSP Gateway; the other two (continuous, eventsource) require a standalone `%Net.TCPServer` listener on a separate TCP port, scheduled in γ (Phase 7).

## 7. Phased Delivery — All Phases Are MVP Scope

- **The entire MVP = Phases 0 through 7**, reframed explicitly at user request. α, β, γ are progress checkpoints WITHIN the MVP, not a "MVP then post-MVP" split.
- **Milestone α — Public Alpha** (Phases 0–4): scaffolding, core document API + rev engine + globals storage, sequences + changes feed (normal/longpoll) + attachments, Mango + SQL projection, replication protocol. Acceptance: **PouchDB replicates a sample database bidirectionally end-to-end; CouchDB replicator runs clean in both directions.** This is when the project goes public.
- **Milestone β — Customer Zero Complete** (Phases 5–6): views + JS integration via JSRuntime.Subprocess, authentication surface (`_session` cookie HMAC, `_users` PBKDF2, Basic/JWT/proxy auth, `_security` enforcement). Acceptance: **the author's three production CouchDB databases are served by IRIS Couch with their existing clients unchanged; the standalone Apache CouchDB process is retired.**
- **Milestone γ — MVP Feature-Complete** (Phase 7 hardening): standalone `%Net.TCPServer` HTTP listener on a separate port provides `feed=continuous` + `feed=eventsource` with proper chunked transfer encoding, bypassing mod_csp; ECP distributed-cache clustering support; conformance harness green against both CouchDB 3.3.3 and 3.5.x; published compatibility matrix. Acceptance: **every non-deprecated CouchDB 3.x feature is either delivered or explicitly documented as out of scope with a reason.** This is when IRIS Couch graduates from alpha to 1.0.
- α/β/γ are sequenced but not strictly gated — β can run in parallel with γ work.

## 8. Delivery Capacity

- **Single developer with AI coding agents.** Honest about bus factor, deliberate about cadence. The brief frames this as a feature (no committee architecture, high velocity, 2026-era tooling leverage) rather than a liability.
- **No deadline.** Quality-gated, not calendar-gated. Urgency belongs to adopters facing their own migration deadlines.
- **Customer-zero as continuous regression suite.** The author's own workload exercises the code against real production data between every release.
- **If ever shelved**: the final release remains forkable and documented. Adopters are not stranded.

## 9. Operational Maturity Commitments

- **High availability**: IRIS mirroring supported from α onward. Document store, rev tree, changes feed, and SQL projection all mirror with the IRIS namespace; `_local/` checkpoints survive failover by construction. Single-instance deployment at α; ECP distributed-cache clustering at γ.
- **Backup and restore**: standard IRIS backup (external, online, IRIS.DAT snapshots) captures all state automatically including attachment streams. Point-in-time recovery via journal replay. No separate backup tooling.
- **Audit**: `%SYS.Audit` events emitted for document writes and security-relevant operations from day one. Existing HealthShare audit pipelines pick up IRIS Couch activity without configuration.
- **Observability**: Prometheus/OpenTelemetry metrics for request counts, latencies, replication throughput, `_changes` lag, Mango index hit rates. Scrape endpoint ships at α.
- **Security integration**: `%Service_WebGateway` stack for transport-level auth; `_users`, `_session` cookie auth, `_security` admin/member enforcement layered on top.

## 10. Conformance and Correctness Strategy

- **Apache CouchDB's own JavaScript test suite** run against IRIS Couch.
- **PouchDB's replication conformance tests.**
- **Differential HTTP harness** that issues the same request sequence against IRIS Couch and a live CouchDB peer and diffs responses byte-for-byte.
- **Rev-tree property tests** for the conflict model and winning-rev algorithm.
- **Every release is gated on this suite**, not asserted to be wire-compatible.

## 11. Compatibility Targets

- **Anchor version**: Apache CouchDB **3.3.3** as the primary conformance baseline through β; CouchDB 3.5.x added at γ.
- **Smoke-tested client versions**: PouchDB 9.x, `nano` 10.x (Node CouchDB client), `@cloudant/cloudant` 5.x, Fauxton (currently-shipping build).
- **Live compatibility matrix** published as part of Getting Started docs, updated every release.

## 12. Migration Path (What Adopters Do)

1. Stand up IRIS Couch inside an existing IRIS deployment; mount at e.g. `/iris-couch/`.
2. Replicate in: point Apache CouchDB replicator at source CouchDB → destination IRIS Couch, one database at a time. Uses standard `new_edits=false` and checkpoint model.
3. Validate: differential `_all_docs` diff, `_changes` window comparison, Mango result parity for production selectors, attachment digest round-trip.
4. (Optional) Dual-write parallel operation via bidirectional replication to build confidence.
5. Cut over clients, drain source, retire standalone CouchDB.
6. Rollback path is symmetric — replicate IRIS Couch back out to a fresh CouchDB if anything misbehaves. No point of no return.

## 13. Adoption-Critical Caveats

- **During α, design docs with JS views/filters/validators replicate in correctly** and the functions are stored, but invoking them returns 501 until an operator enables JSRuntime.Subprocess. Apps that depend on JS either defer migration to β or enable the subprocess backend before cutover.
- **`feed=continuous` / `feed=eventsource` clients** must either use `feed=longpoll` (which the CouchDB replicator and PouchDB default to anyway) or wait for γ's `%Net.TCPServer` streaming listener on a separate port.
- **Large-scale workloads** (orders of magnitude beyond customer zero's ~10k docs / ~500 MB) are not yet benchmarked; post-α work will establish where the scaling ceiling sits.

## 14. Competitive Intelligence Worth Preserving

- **PouchDB Server**: community-maintained Node.js CouchDB-compatible server; has open issues; not positioned as production CouchDB-3.x replacement. Adds Node.js to the stack rather than eliminating a database.
- **IBM Cloudant**: commercial managed CouchDB-compatible service. Cloud-only, vendor lock-in, no on-prem equivalent.
- **Couchbase Server**: originally forked from CouchDB lineage. **Not wire-compatible.** Has a CouchDB migration guide that requires application rewrites. Brand confusion risk with CouchDB.
- **Kivik / Go/Rust reimplementations**: adapter libraries, not servers. No actively-maintained Go/Rust/Python wire-compatible CouchDB server in 2025–2026.
- **Historical reimplementations**: BigCouch, rcouch, couch4j — all dormant. Pattern: each tried to build a database engine from scratch alongside the wire protocol and ran out of maintainer bandwidth. IRIS Couch sidesteps this by using IRIS as the storage engine.
- **IRIS DocDB**: proprietary `/api/docdb/v1` REST surface. Does NOT speak CouchDB HTTP API, Mango, or the replication protocol. Complementary to IRIS Couch, not overlapping.

## 15. Market/Timing Intelligence

- **2024 Apache CouchDB user survey finding** (sourced from Neighbourhoodie 2025): users *"would sooner add a database to obtain extra features than migrate away from CouchDB."* Directly validates the consolidation thesis — teams keep CouchDB + $OTHER rather than replacing CouchDB.
- **CouchDB 3.4 (Sept 2024) QuickJS adoption** was driven by Red Hat 9 dropping SpiderMonkey. SpiderMonkey-era CouchDB deployments are under active migration pressure — "port to IRIS Couch" is an alternative to "upgrade CouchDB AND migrate to QuickJS AND redeploy on supported OS."
- **QuickJS vs SpiderMonkey**: 4–6x faster, ~6x lower memory per process (~5 MB vs ~30 MB). Published by Cloudant blog.
- **Healthcare field-work CouchDB deployments**: eHealth Africa, Medic Mobile/CHT, HospitalRun, GRADEpro GDT, active in 135+ countries per PouchDB user list.
- **HN sentiment (2025)**: CouchDB attachment sync is "not a pleasant experience" — real pain acknowledged even by loyal users.
- **Couchbase migration guide**: Couchbase publishes documentation treating CouchDB users as a migration target, confirming the two are not interchangeable.

## 16. Key Open Questions Flagged for PRD Phase

- **Exact API signature for `CouchPort.JSRuntime.Sandbox`**: sync vs async? Per-request sandbox or process-pooled? Timeout/memory contract? Needs PRD-level specification before Phase 1b starts.
- **Spike 3 — AuthSession cookie HMAC byte-compat**: still deferred. Needs a source-spike against `couch_httpd_auth.erl` before Phase 6 Authentication work starts. Low risk but not yet retired.
- **Python CPF setup documentation**: if `JSRuntime.Python` backend is to be offered, the deployment guide must walk operators through setting `PythonRuntimeLibrary` in the IRIS CPF file.
- **Default webapp mount point**: `/iris-couch/` proposed in this brief and research. Lock in the PRD.
- **Package prefix**: `CouchPort.*` used throughout the research doc as ObjectScript package prefix. This is NOT the same as the product name "IRIS Couch" — they diverged during research before the name was finalized. **Resolve in PRD**: either rename all package references to `IRISCouch.*` (matches product name but diverges from repo name `iris-couch`) or keep `CouchPort.*` (matches the research doc's 80+ class references but confuses readers). My recommendation: **`IRISCouch.*`** as the ObjectScript package prefix — aligns with product name and IRIS community naming conventions.
- **Benchmarking target for post-α scaling**: at what document count / attachment volume / concurrent client count does the CQRS projection's synchronous write path start regressing? Needs performance characterization for documentation.
- **Mirror semantics for `_local/` checkpoints during failover**: technically survive by construction, but the specific guarantee (monotonic seq continuity after promotion, replication resume correctness) needs empirical validation.

## 17. Posture Signals (for PRD and README Voice)

- **Quality-gated, not calendar-gated.** Correctness before shippability.
- **Replication-protocol-bug-that-corrupts-conflict-tree** = unshippable defect. The project's highest-severity failure mode is silent data divergence, and that defines the quality bar.
- **Wire-compat over cleverness**: HTTP status codes, JSON error envelopes, sequence tokens, and checkpoint shapes match CouchDB exactly. Internal hashing diverges where the wire protocol allows.
- **CouchDB source is specification, not code**: Apache 2.0 license chosen; CouchDB source is read for wire-behavior specification only. No CouchDB code is copied. Borrowed test vectors are cited.
- **Honest scoping**: the brief explicitly says market sizing is unknown, customer zero is N=1 so far, and workloads larger than ~10k docs are not yet validated. This is a credibility feature, not a vulnerability.
- **Ambition calibrated to capacity**: single-developer + AI-agents is realistic. The project scope is deliberately smaller than "build a database" — it is "build a wire-protocol facade over a database IRIS already ships."

## 18. Vision (3-Year View)

- **IRIS Couch becomes the default answer to "how do I get offline-first sync onto IRIS?"**
- Expands beyond customer zero into HealthShare ecosystem, healthcare field-work apps, retail POS, any "occasionally connected" workload.
- Canonical reference for implementing CouchDB-compatible servers on non-Erlang storage engines.
- **Pattern extraction opportunity**: the CQRS hybrid + pluggable JSRuntime sandbox pattern is reusable for other compatibility layers on IRIS — Mongo-on-IRIS, DynamoDB-on-IRIS, Firebase-on-IRIS. Code is organized so the pattern is extractable as a reference implementation. This ambition is now explicit in the brief's Vision section.
- No commercialization. No managed hosting. Stable, correct, maintained code base, customer-zero dogfooded.
