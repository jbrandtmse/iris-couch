---
title: "Product Brief: IRIS Couch"
status: complete
created: 2026-04-11
updated: 2026-04-11
author: Developer (with Mary, BMad Analyst)
inputs:
  - docs/initial-prompt.md
  - _bmad-output/planning-artifacts/research/technical-couchdb-on-iris-research-2026-04-10.md
  - _bmad-output/planning-artifacts/research/technical-couchdb-on-iris-summary-2026-04-11.md
related:
  - _bmad-output/planning-artifacts/product-brief-iris-couch-distillate.md
---

# Product Brief: IRIS Couch

> *Bring offline-first replication to IRIS — without adding a second database.*

## Executive Summary

**IRIS Couch is the only production-grade, actively-maintained
CouchDB-compatible server in development today that is not Apache CouchDB
itself.** It is an open-source, wire-compatible Apache CouchDB 3.x server
implemented natively in InterSystems IRIS ObjectScript. Existing CouchDB
clients — PouchDB, the Apache CouchDB replicator, Cloudant SDKs, Fauxton —
connect to IRIS Couch and cannot tell the difference. The HTTP API, the
replication protocol, the Mango query language, document MVCC, attachments,
authentication: all of it behaves exactly as CouchDB does on the wire. What
lives underneath is pure IRIS: multi-dimensional globals as the write path,
an IRIS SQL projection as the Mango read path, `%Stream.GlobalBinary` for
attachments, `%CSP.REST` for the HTTP layer. No Erlang. No CouchDB binary.
No second database process.

**It is being built by a team migrating its own three production CouchDB
databases onto it.** Correctness is a personal problem before it is a public
one — IRIS Couch retires a standalone CouchDB that serves real workloads, or
it does not ship. That customer-zero forcing function is the single sharpest
distinction between this project and the graveyard of dormant CouchDB
reimplementations (BigCouch, rcouch, couch4j, kivik) it enters against.

The product exists because shops running InterSystems IRIS alongside Apache
CouchDB are paying an operational tax they shouldn't have to. Two database
engines, two backup strategies, two monitoring setups, two security models,
two sets of upgrade windows — all to serve a single application whose only
real dependency on CouchDB is the wire protocol. **IRIS Couch lets those
shops retire the CouchDB process and serve the same clients from the
database they already run.** No application rewrites. No replication-protocol
compromises. No "close enough" compatibility.

Research has already retired the biggest technical risks: revision-hash
byte-compat is not required (source-proven), replication-protocol byte-compat
is achievable with a simple JSON-canonical MD5 algorithm, and the MVP ships
with zero mandatory external dependencies beyond IRIS itself. What remains is
disciplined execution across a well-scoped phased delivery plan.

## Origin

IRIS Couch starts with a personal itch. After years of using Apache CouchDB —
its offline-first replication, its MVCC conflict model, its delightfully
simple HTTP API, its design-doc conventions — the author came to the same
conclusion every long-time CouchDB user eventually reaches: **there is
nothing else quite like it.** The databases that replaced it for most
workloads (Postgres, Mongo, DynamoDB) are excellent at many things, but none
of them preserve CouchDB's particular magic of "replicate this database to a
phone, work offline for a week, then sync back."

And then there's IRIS. A database engine with blazing-fast multi-dimensional
globals, a mature SQL engine with first-class JSON support, enterprise
operational tooling, embedded Python, and a healthcare ecosystem that
happens to be full of the exact kinds of field-work and offline-first
applications CouchDB has served for a decade.

IRIS Couch is the project that merges the best of both worlds: **CouchDB's
replication model and client ecosystem on top of IRIS's storage engine and
operational story.** Not a port. Not a compatibility shim. A first-class
native implementation where existing CouchDB clients become existing IRIS
clients, silently.

## The Problem

Organizations that already run InterSystems IRIS — especially
HealthShare-backed shops — face a recurring pattern: an application needs
offline-first sync, or a mobile client, or a PouchDB front-end, and the
only way to deliver it today is to stand up a separate Apache CouchDB
instance alongside IRIS. Two database engines for one application. Two
backup strategies. Two monitoring dashboards. Two sets of credentials. Two
upgrade windows. Two places to look when things go wrong. The 2024 Apache
CouchDB user survey captured this exactly: users *"would sooner add a
database to obtain extra features than migrate away from CouchDB."*
CouchDB's value proposition is so specific that teams accept the
operational burden rather than give it up.

IRIS Couch is the answer teams have been waiting for without knowing they
were. Instead of running CouchDB next to IRIS, they run CouchDB *inside*
IRIS. The client applications don't change. The replication contracts don't
change. The PouchDB sync code doesn't change. Only the deployment topology
changes — from two processes to one.

## The Solution

IRIS Couch exposes the CouchDB 3.x HTTP API from an IRIS web application.
Everything a CouchDB client expects is there: the welcome response at `/`,
database lifecycle endpoints (`PUT /{db}`, `DELETE /{db}`, `GET /{db}`),
document CRUD with strict `_rev` optimistic concurrency, `_bulk_docs`,
`_all_docs`, `_bulk_get`, `_changes`, `_revs_diff`, `_find` (Mango),
`_index`, `_explain`, `_local/` checkpoints, attachments in every supported
encoding, the `_users` database, `_session` cookie auth, and `_security`
admin/member enforcement. HTTP status codes and JSON error envelopes match
byte-for-byte. The replication protocol runs to completion against a real
Apache CouchDB peer in either direction.

Underneath, the engine is a CQRS hybrid designed to play to IRIS's
strengths. Writes, revisions, the changes feed, and attachments live in raw
multi-dimensional globals — lock-free, cluster-safe, and as fast as IRIS
can go. Reads for Mango queries flow through a synchronously-maintained SQL
projection built on IRIS SQL's native JSON indexing, so queries benefit
from real query planning instead of ad-hoc global traversal. User-supplied
JavaScript from design documents lives behind a single pluggable interface
with a zero-dependency default (returning clear 501 responses for JS
operations) and optional subprocess (Node/Bun/Deno/couchjs) or embedded
Python backends operators can enable when they need them.

## What Makes This Different

**Category of one.** In 2026, IRIS Couch occupies a vacant slot: the only
actively-developed, production-grade, on-prem CouchDB-compatible server
outside of Apache CouchDB itself. PouchDB Server is community-maintained
and not positioned for enterprise production. Cloudant is cloud-only and
ties users to IBM's infrastructure. Couchbase Server is explicitly *not*
wire-compatible and requires application rewrites. Historical
reimplementations (BigCouch, rcouch, couch4j, kivik) are dormant.

**Why prior reimplementations stalled and IRIS Couch won't.** The graveyard
has a pattern: every dormant reimplementation tried to build a database
engine from scratch — storage, durability, indexing, clustering, the lot —
in addition to implementing the CouchDB wire protocol. Each project ran out
of maintainer bandwidth long before reaching production parity. IRIS Couch
sidesteps that trap entirely: it is a wire-protocol facade over an
already-mature database engine. Storage, durability, SQL query planning,
backup, journaling, HA, clustering, and cache management are IRIS's
responsibility, not ours. The project's scope is just the protocol surface —
not a database. That is the structural reason IRIS Couch can ship where
others stalled.

**Customer-zero forcing function.** The author's team already runs Apache
CouchDB in production and has a standalone instance to retire. The roadmap
is anchored by an actual in-house migration, not speculative market
research. Design decisions are validated against production data before
they ship, not after. Every release is dogfooded by the people who depend
on it most.

**IRIS DocDB is not the same thing.** InterSystems' own document database
feature exposes a proprietary `/api/docdb/v1` REST surface; it does not
speak the CouchDB HTTP API, does not implement Mango, and does not
participate in the CouchDB replication protocol. IRIS Couch does all three.
It complements IRIS DocDB rather than competing with it.

**Timing is right.** CouchDB 3.4 (September 2024) introduced QuickJS
specifically because Red Hat dropped SpiderMonkey from RHEL 9, putting
SpiderMonkey-era CouchDB deployments under active migration pressure.
"Port to IRIS" is a cleaner answer than "upgrade CouchDB *and* migrate to
QuickJS *and* redeploy on a supported OS." The window is open now.

## Who This Serves

**Audience reality check.** IRIS Couch runs inside InterSystems IRIS and
requires an IRIS instance to use. Community Edition works for evaluation;
production use requires a licensed IRIS instance. That means the primary
audience is teams *already committed to IRIS* — existing customers,
HealthShare deployments, evaluation projects weighing IRIS against other
databases. IRIS Couch is not a generic CouchDB alternative for the open
web; it is a way to eliminate a second database *inside* an
already-IRIS-committed stack.

**Primary — IRIS/HealthShare shops with existing CouchDB applications.**
Teams already paying the dual-database operational tax. Their success
criterion is simple: the existing PouchDB clients keep working, the
existing replication jobs keep running, and one of the database processes
goes away. IRIS Couch is an ops-burden eliminator before it is anything
else.

**Natural fit — healthcare NGO and field-work applications.** CouchDB and
PouchDB anchor production offline-first stacks at eHealth Africa, Medic
Mobile, the Community Health Toolkit, HospitalRun, and GRADEpro GDT
(deployed in 135+ countries). These are exactly the kinds of workloads
HealthShare already supports on the back end. For any of these
organizations already evaluating or running HealthShare, IRIS Couch
eliminates the second database without touching the PouchDB client code
their field workers rely on.

**Secondary — new IRIS projects that need offline-first sync.** Teams
building field-work applications, mobile clients, or multi-site replicas on
top of an IRIS backend they already trust for other workloads. Today they
either bolt on CouchDB or abandon the offline-first pattern entirely. IRIS
Couch gives them a third option: stay on IRIS and get the full
CouchDB/PouchDB experience from day one.

**Customer zero — the author's own team.** The project exists to retire
one specific standalone CouchDB instance serving three databases on the
order of 10,000 documents and ~500 MB (including attachments), with four
map-reduce views and two filter functions between them. The workload is
small enough to be tractable and large enough to exercise every major
feature path — document CRUD, attachments, map-reduce views, filtered
`_changes`, Mango queries, and replication all hit production traffic
before any public release. The internal migration is both the forcing
function for the roadmap and the highest-confidence quality gate the
project will ever have. Workloads substantially larger or more concurrent
than this envelope are expressly not yet validated; post-α benchmarking
will establish where the scaling ceiling actually sits.

### A note on market sizing

No reliable estimate of the IRIS + CouchDB installed-base overlap exists
in any public data. Customer zero is the only confirmed instance. The
working hypothesis is that teams facing this pattern simply have had
nowhere to advertise it — there was no off-ramp, so there was no reason
to talk about it. Part of IRIS Couch's reason for existing is to create
that advertisement by being the off-ramp.

## Technical Approach

A high-level sketch — the full architecture lives in the research report.

- **Storage layer**: multi-dimensional IRIS globals for documents,
  revision trees, changes feed, `$Increment` sequence counters,
  attachments via `%Stream.GlobalBinary`, and `_local/` checkpoints.
- **Durability and crash safety**: all writes land inside journaled IRIS
  transactions. A single write updates the document body, the rev tree,
  the changes feed, and the SQL projection atomically — or not at all.
  Crash recovery is whatever IRIS's journal replay gives us, which is
  stronger than CouchDB's append-only guarantees and runs on the same
  tooling operators use to protect every other IRIS workload.
- **Read layer**: a `%Persistent` shadow table for Mango queries,
  maintained synchronously on every write, backed by a runtime index table
  that avoids class recompilation when applications create new Mango indexes.
- **HTTP layer**: a `%CSP.REST` dispatcher with a UrlMap covering every
  CouchDB endpoint, JSON error envelopes matching CouchDB exactly.
- **Replication**: native implementation of `_revs_diff`, `_bulk_get`,
  `open_revs` (with nested multipart/mixed), `_local/` checkpoint storage,
  and the full replication state machine. Own JSON-canonical MD5 algorithm
  for rev hashes and replication_id, proven by source-spike to be
  protocol-compatible without matching CouchDB's Erlang-specific hashes
  byte-for-byte.
- **JavaScript runtime**: a single interface, `CouchPort.JSRuntime.Sandbox`,
  with three swappable backends. MVP defaults to a 501-returning stub so
  there are no external dependencies; operators enable the subprocess or
  Python backend only when they need user-supplied design-doc JS.
- **Conformance strategy**: every release is gated on (a) Apache CouchDB's
  own JavaScript test suite run against IRIS Couch, (b) PouchDB's
  replication conformance tests, and (c) a differential HTTP harness that
  issues the same request sequence against IRIS Couch and a live CouchDB
  peer, diffing responses byte-for-byte. "Wire-compatible" is measured, not
  asserted.
- **Deployment**: pure ObjectScript. Compiles into IRIS, mounts as a web
  application. No Erlang, no CouchDB binary, no mandatory Python, no
  Node.js required by default.

### What zero dependencies gets you — and what it doesn't

The MVP default (`JSRuntime.None`) runs every document CRUD operation,
every `_bulk_docs` batch, every attachment, every `_find` Mango query,
every `longpoll` `_changes` feed, and every replication round-trip. It does
**not** run user-supplied JavaScript. Design documents containing `views`
with JS map/reduce, `validate_doc_update` hooks, or custom JS `_changes`
filters are stored and replicated correctly, but invoking their functions
returns 501 until the operator installs Node.js (or Bun/Deno/couchjs/Python)
and enables a JSRuntime backend. This is a feature, not a bug — it means
the zero-dependency install has a clean, well-defined contract, and the
extra dependency is opt-in based on what the application actually uses.

### Enterprise operational story — inherited from IRIS

IRIS Couch is a web application running inside IRIS, so its operational
surface is IRIS's operational surface. Concretely:

- **High availability**: IRIS mirroring is supported for failover from
  α onward. The document store, revision tree, changes feed, and SQL
  projection all live in journaled globals and mirror with the rest of
  the IRIS namespace. `_local/` replication checkpoints survive failover
  by construction. ECP distributed-cache clustering (multi-server IRIS
  deployments) is sequenced into γ as Phase 7 work; it is committed MVP
  scope, just delivered after the Public Alpha and Customer Zero
  milestones.
- **Backup and restore**: standard IRIS backup — external, online, or
  `IRIS.DAT` snapshots — captures all IRIS Couch state automatically,
  including attachment streams. No separate backup tooling required.
  Point-in-time recovery via IRIS journal replay.
- **Audit trail**: document write and security-relevant events emit
  structured `%SYS.Audit` events from day one, so existing HealthShare
  audit pipelines pick up IRIS Couch activity without additional
  configuration.
- **Observability**: Prometheus / OpenTelemetry metrics for request
  counts, latencies, replication throughput, `_changes` lag, and Mango
  index hit rates are exposed via a standard scrape endpoint. Ships in α.
- **Security**: authentication integrates with IRIS's existing
  `%Service_WebGateway` stack; `_users`, `_session` cookie auth, and
  `_security` admin/member enforcement layer on top. No shadow credential
  store to manage.

## Migration Path

The expected cutover flow for a shop with an existing CouchDB instance:

1. **Stand up IRIS Couch** inside an existing IRIS deployment and mount
   it at a web application path (e.g., `/iris-couch/`).
2. **Replicate in**: point the Apache CouchDB replicator at the source
   CouchDB and the destination IRIS Couch, one database at a time.
   Replication runs as it would between any two CouchDB peers — same
   `new_edits=false` semantics, same checkpoint model.
3. **Validate**: run a differential diff of `_all_docs` and a
   representative `_changes` window against both peers; confirm Mango
   query results match for the application's actual selectors; confirm
   attachment digests round-trip.
4. **Dual-write parallel operation**: (optional) point a subset of
   production clients at IRIS Couch while keeping the source CouchDB
   receiving the full write load, using CouchDB-to-IRIS-Couch replication
   to keep them in sync. Run until confident.
5. **Cut over** the remaining clients, drain the source, and retire the
   standalone CouchDB process.
6. **Rollback** — if anything misbehaves, the migration is symmetric:
   replicate IRIS Couch back out to a fresh CouchDB and cut clients back.
   The wire protocol works the same in both directions, so there is no
   "point of no return."

Migration of design documents requiring JS execution works too, with one
caveat: during the α window (before the subprocess backend is enabled),
design docs replicate in successfully and their JS functions are stored,
but invoking them returns 501. Applications that rely on JS views can
either defer migration until β or enable a JSRuntime backend on the IRIS
Couch side before cutover.

## Milestones & Measures of Done

**The full MVP is Phases 0 through 7 — every phase is committed scope.**
What the milestones below represent are progress checkpoints within that
MVP: visible moments where the project crosses a meaningful line and
earns the label ("public", "customer zero retired", "feature-complete").
Nothing labeled a milestone here sits outside the MVP commitment.

**Milestone α — Public Alpha.** Phase 0 scaffolding through Phase 4
replication complete. Zero mandatory external dependencies. Full document
CRUD, `_bulk_docs`, `_all_docs`, attachments, `normal` and `longpoll`
`_changes` feeds, Mango `_find` + `_index` + `_explain`, replication
against a real Apache CouchDB peer. JS-based views and
`validate_doc_update` return 501 with a clear message pointing to Mango.
Acceptance: **PouchDB replicates a sample database bidirectionally
against IRIS Couch end-to-end, and the CouchDB replicator runs clean in
both directions.** This is when the project goes public.

**Milestone β — Customer Zero Complete.** Phase 5 views-and-JS integration
with `JSRuntime.Subprocess` (or `.Python`) enabled, plus Phase 6
authentication. Acceptance: **the author's three production CouchDB
databases, including their map-reduce views and design-doc filters, are
served by IRIS Couch with their existing clients unchanged, and the
standalone Apache CouchDB process is retired.** This is when the project
has delivered on its origin story.

**Milestone γ — MVP Feature-Complete.** Phase 7 hardening complete. A
standalone `%Net.TCPServer` HTTP listener on a separate port provides
full `feed=continuous` and `feed=eventsource` support for the clients
that need them; ECP distributed-cache clustering is supported; the
conformance harness runs against both CouchDB 3.3.3 and 3.5.x; a
published compatibility matrix documents every smoke-tested client and
version. Acceptance: **every non-deprecated item from the CouchDB 3.x
feature inventory is either delivered, or explicitly documented as out
of scope with a reason.** This is when IRIS Couch graduates from "alpha"
to "1.0."

The three milestones are sequenced but not strictly gated — α unblocks
the public announcement and the early-adopter conversation, β unblocks
the author's own migration, γ closes the MVP commitment. β can run in
parallel with γ work where appropriate.

## Scope

All items below are committed MVP scope. What changes across α/β/γ is
**when** they land, not **whether** they land.

**Delivered by α (Phase 0–4):**

- Full CouchDB 3.x HTTP API surface for replication compatibility
- Document CRUD with strict `_rev` MVCC, conflicts, tombstones
- `_all_docs`, `_bulk_docs`, `_bulk_get`, `_revs_diff`
- `_changes` endpoint with `feed=normal` and `feed=longpoll` (the two
  modes PouchDB and the CouchDB replicator use by default)
- Attachments: inline, stub, multipart/related, multipart/mixed,
  `atts_since`, streaming
- Mango `_find`, `_index` (json type), `_explain`, `partial_filter_selector`
- Built-in reduces: `_sum`, `_count`, `_stats`, `_approx_count_distinct`
- `_users` database, `_session` cookie auth, Basic auth, `_security`
  admin/member enforcement
- Full replication against an Apache CouchDB 3.x peer
- IRIS mirroring for HA, standard IRIS backup, `%SYS.Audit` integration,
  Prometheus / OpenTelemetry metrics endpoint

**Delivered by β (Phase 5–6):**

- JS-based views (`map` + `reduce`) via JSRuntime.Subprocess
- JS-based `validate_doc_update` hooks
- JS-based custom filter functions for `_changes`
- Incremental view engine with ETag-based cache matching
- Full authentication surface: proxy auth, JWT auth, cookie HMAC byte-compat

**Delivered by γ (Phase 7):**

- `feed=continuous` and `feed=eventsource` streaming `_changes` modes
  via a standalone `%Net.TCPServer` HTTP listener on a separate port —
  this bypasses the CSP Gateway's response-buffering behavior and emits
  proper chunked transfer encoding directly
- ECP distributed-cache clustering safety (multi-server IRIS deployments)
- Conformance harness green against both CouchDB 3.3.3 and 3.5.x
- Published compatibility matrix for every smoke-tested client version

**Compatibility targets:**

- **Anchor**: Apache CouchDB **3.3.3** as the primary conformance
  baseline through β; CouchDB 3.5.x added to the harness at γ.
- **Smoke-tested client versions**: PouchDB 9.x, `nano` 10.x, `@cloudant/cloudant`
  5.x, Fauxton (currently-shipping build). A live compatibility matrix is
  part of the Getting Started docs and updated on every release.

**Out of scope — explicitly not planned.**

- CouchDB 4.x wire protocol (anchor to 3.x stable; 4.x is a later track
  beyond this MVP)
- Cloudant-specific query / index extensions
- Deprecated surfaces: `_show`, `_list`, `_update`, `_rewrite`, `_temp_view`
- Partitioned databases
- Nouveau / Clouseau full-text search
- Native Erlang ETF encoding (deliberate architectural choice — our
  JSON-canonical MD5 is wire-protocol sufficient)
- Commercial productization, paid tiers, managed hosting

## Vision

In three years, **IRIS Couch is the default answer to "how do I get
offline-first sync onto IRIS?"** Teams in the HealthShare ecosystem,
healthcare NGOs running field-work apps, retail POS systems, and any shop
with an "occasionally connected" workload stop treating "add CouchDB to
the stack" as the only path. They compile IRIS Couch into their existing
IRIS instance, mount it at `/iris-couch/`, point their PouchDB clients at
it, and ship.

### Beyond IRIS Couch — the CQRS + pluggable runtime pattern

The architectural core of the project — **a CQRS hybrid using IRIS
globals for writes, an IRIS SQL projection for reads, and a pluggable
runtime sandbox for user-supplied scripting** — is not CouchDB-specific.
It is a reusable template for building wire-compatible facades over any
other document-oriented system on top of IRIS: Mongo-on-IRIS,
DynamoDB-on-IRIS, Firebase-on-IRIS, or any other system whose clients
deserve a migration path into an existing IRIS deployment. IRIS Couch is
the first proof-of-existence for this pattern on IRIS, and its code is
organized so the pattern is extractable as a reference implementation for
future projects.

The project becomes the canonical reference for implementing
CouchDB-compatible servers on non-Erlang storage engines, and its
pluggable JSRuntime architecture becomes a pattern other
compatibility-layer projects can borrow. None of this requires
commercialization. It requires a stable, correct, maintained code base —
which is exactly what customer-zero delivery discipline guarantees.

## Posture: Quality-Gated, Not Calendar-Gated

IRIS Couch is released on a correctness-first cadence. There is no fixed
ship date; a replication bug that could corrupt a conflict tree is an
unshippable defect, full stop. Urgency belongs to adopters facing their own
migration deadlines — the project's job is to be correct and ready when
they arrive.

Practically, this means:

- **Apache 2.0 licensed.** Matches CouchDB and InterSystems community
  convention. CouchDB source is used as a specification, not copied as
  code.
- **Distribution**: GitHub repository (`iris-couch`), published to the
  InterSystems Package Manager (ZPM / IPM).
- **Small-team footprint, high leverage.** IRIS Couch is built primarily
  by a single developer working with AI coding agents — a deliberate
  choice to keep decision velocity high and avoid committee architecture,
  made feasible by 2026-era tooling that turns a single engineer into a
  larger effective team. Honest about the bus factor, deliberate about
  the cadence.
- **Customer-zero keeps it alive.** The author's team runs IRIS Couch
  against real production data between every release. That workload is the
  project's continuous regression suite — the code is exercised against
  three real CouchDB databases before any user sees a tag.
- **CouchDB 3.x point-release tracking.** Wire-protocol changes upstream
  are absorbed into the conformance suite within a release cycle. IRIS
  Couch anchors explicitly to CouchDB 3.x stable; 4.x is tracked but not
  targeted.
- **No commercial aspirations.** IRIS Couch does not compete with
  Cloudant, does not offer a managed service, does not pursue enterprise
  support contracts. It is a tool, released to the world.
- **No community-building push right now — but not a dead end.** External
  contributors are not actively courted and PRs may sit without merge. The
  repository is public, the code is Apache 2.0, and any user is free to
  fork and take it further. If the project is ever shelved, the final
  release remains forkable and documented.
- **Not a CouchDB replacement.** Apache CouchDB is healthy and
  well-maintained. IRIS Couch is an alternative backend for teams with a
  specific operational reason to consolidate — not a migration target for
  the CouchDB community at large.

## Credits and Inspirations

- **Apache CouchDB** — for being the only database whose replication
  model is worth the years of loyalty it engenders. IRIS Couch exists
  because Apache CouchDB is worth copying.
- **PouchDB** — for making offline-first a real product category and
  defining the client-side half of the wire contract this project
  implements.
- **InterSystems IRIS** — for globals, `%Persistent` classes,
  `%Stream.GlobalBinary`, `%CSP.REST`, `%SYS.Python`, and the rest of the
  building blocks that make this project feasible in the first place.
- **The CouchDB 3.4 QuickJS work** — for proving that a sandboxed,
  pluggable JS runtime is the right architectural direction for
  CouchDB-family systems and for clearing the path IRIS Couch now walks.

---

*This brief is the product-level framing for IRIS Couch. The full technical
feasibility study, feature inventory, phased delivery plan, and risk
register live in `_bmad-output/planning-artifacts/research/`.*
