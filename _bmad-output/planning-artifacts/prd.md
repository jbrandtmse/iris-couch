---
stepsCompleted:
  - step-01-init
  - step-02-discovery
  - step-02b-vision
  - step-02c-executive-summary
  - step-03-success
  - step-04-journeys
  - step-05-domain (skipped)
  - step-06-innovation
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-polish
  - step-12-complete
inputDocuments:
  - _bmad-output/planning-artifacts/product-brief-iris-couch.md
  - _bmad-output/planning-artifacts/product-brief-iris-couch-distillate.md
  - _bmad-output/planning-artifacts/research/technical-couchdb-on-iris-research-2026-04-10.md
  - _bmad-output/planning-artifacts/research/technical-couchdb-on-iris-summary-2026-04-11.md
  - docs/initial-prompt.md
documentCounts:
  briefCount: 2
  researchCount: 2
  brainstormingCount: 0
  projectDocsCount: 1
classification:
  projectType: api_backend + developer_tool
  domain: general
  complexity: medium domain / high technical
  projectContext: greenfield
workflowType: 'prd'
---

# Product Requirements Document - iris-couch

**Author:** Developer
**Date:** 2026-04-11

## Executive Summary

IRISCouch is an open-source, wire-compatible Apache CouchDB 3.x server
implemented natively in InterSystems IRIS ObjectScript. Existing CouchDB
clients — PouchDB, the Apache CouchDB replicator, Cloudant SDKs, Fauxton,
`nano` — connect to it and cannot tell they are not talking to real
CouchDB. The HTTP API, replication protocol, Mango query language, MVCC
revision model, attachments, and authentication surface all behave exactly
as CouchDB 3.x does on the wire. What lives underneath is pure IRIS: raw
multi-dimensional globals on the write path, a synchronously-maintained
IRIS SQL projection on the Mango read path, `%Stream.GlobalBinary` for
attachments, `%CSP.REST` for the HTTP layer. No Erlang, no CouchDB binary,
no second database process. Apache 2.0 licensed, distributed via GitHub
and ZPM/IPM.

The product exists because teams already running InterSystems IRIS — and
especially HealthShare deployments — currently have no path to CouchDB's
offline-first sync model except standing up a second database next to
IRIS. Two engines, two backup strategies, two monitoring dashboards, two
credential stores, two upgrade windows, all to serve a single application
whose only real dependency on CouchDB is the wire protocol. IRISCouch
delivers that wire protocol from inside IRIS, so existing PouchDB clients
and replication jobs keep working unchanged and the standalone CouchDB
process can be retired. Serving the author's own three production CouchDB
databases is the forcing function: customer zero must be retired onto
IRISCouch or the project does not ship. Every release is exercised
against real production data before any public tag.

### What Makes This Special

**Category of one.** In 2026, IRISCouch occupies a vacant slot: the only
actively-developed, production-grade, non-Apache CouchDB-compatible
server. PouchDB Server is community-maintained and not positioned for
production; Cloudant is cloud-only and ties users to IBM infrastructure;
Couchbase Server is explicitly not wire-compatible and requires
application rewrites; the historical reimplementations (BigCouch, rcouch,
couch4j, kivik) are dormant. That gap exists for a reason — and IRIS
Couch's core insight is why.

**Core insight: CouchDB is a wire protocol, not a database.** Every prior
reimplementation tried to build a storage engine *and* a wire-protocol
layer from scratch and ran out of maintainer bandwidth before reaching
production parity. IRISCouch sidesteps that trap entirely by using IRIS
as the storage engine — durability, journaling, SQL query planning,
backup, HA, clustering, and cache management are already IRIS's
responsibility. The project's scope collapses from "build a database" to
"build a wire-protocol facade over a database IRIS already ships."

**Customer-zero forcing function.** The roadmap is anchored by an actual
in-house migration, not speculative market research. Design decisions are
validated against production data before they ship, not after. This is
the single sharpest distinction between IRISCouch and the graveyard of
dormant reimplementations it enters against.

**Zero mandatory external dependencies at MVP.** No Erlang, no CouchDB
binary, no Node.js, no mandatory Python. Every document CRUD, every
`_bulk_docs` batch, every attachment, every `_find` Mango query, every
`longpoll` `_changes` feed, and every replication round-trip runs on a
vanilla IRIS install. User-supplied JavaScript (design-doc views,
`validate_doc_update`, custom `_changes` filters) lives behind a single
pluggable `JSRuntime.Sandbox` interface with a 501-returning default and
optional Node/Bun/Deno/couchjs subprocess or embedded-Python backends
operators enable only if their application actually needs them.

**Wire-compatibility is measured, not asserted.** Every release is gated
on (a) Apache CouchDB's own JavaScript test suite, (b) PouchDB's
replication conformance tests, and (c) a differential HTTP harness that
issues identical request sequences against IRISCouch and a live CouchDB
peer and diffs responses byte-for-byte. The primary quality bar — "a
replication bug that could corrupt a conflict tree is an unshippable
defect" — defines correctness as verifiable behavior, not marketing copy.

**Enterprise operational story inherited, not rebuilt.** Because IRIS
Couch runs as a `%CSP.REST` web application inside IRIS, it automatically
inherits IRIS's operational surface: mirroring for HA, standard IRIS
backup captures all state (including attachment streams) with no separate
tooling, `%SYS.Audit` emits document and security events for existing
HealthShare audit pipelines, `%Service_WebGateway` handles transport-level
auth, and journal replay provides point-in-time recovery. Operators
learn zero new tools.

## Project Classification

- **Project Type:** `api_backend` + `developer_tool` — a CouchDB 3.x
  HTTP API surface served via `%CSP.REST`, consumed by existing
  CouchDB-ecosystem client libraries and tools (PouchDB, the Apache
  CouchDB replicator, `nano`, `@cloudant/cloudant`, Fauxton). The
  product is simultaneously an HTTP API and the ObjectScript package
  developers install via ZPM/IPM into their IRIS instance.
- **Domain:** `general` — software infrastructure. The product is
  domain-neutral plumbing; no PHI handling, no FDA-regulated decision
  paths, no clinical logic in the product itself. The *target audience*
  overlaps heavily with healthcare (HealthShare, eHealth Africa, Medic
  Mobile, HospitalRun, GRADEpro GDT) but IRISCouch serves those
  workloads as infrastructure rather than as healthcare software.
- **Complexity:** `medium` domain / `high` technical. Low regulatory
  burden and no compliance-certification pathway, but genuinely hard
  technical demands — wire-protocol byte-compatibility, a replication
  state machine that must not corrupt conflict trees, MVCC revision-tree
  merging, a CQRS hybrid with a synchronously-maintained SQL projection,
  a pluggable JavaScript sandbox, and multipart streaming attachment
  handling without buffering large payloads in memory.
- **Project Context:** `greenfield` (code) with locked pre-PRD
  architectural decisions. No implementation exists yet, but a
  2,039-line research report has already retired six of seven spikes,
  locked the CQRS hybrid storage layout, locked a JSON-canonical MD5
  algorithm for rev hashes and `replication_id`, locked the pluggable
  `JSRuntime.Sandbox` interface, and committed the full Phase 0–7
  delivery plan. The PRD inherits those decisions rather than
  re-litigates them.

## Reader's Guide

This PRD is dense and long (~2,500 lines) by design: IRISCouch's
product surface spans 115 functional requirements across 11
subsystems, and the wire-compatibility commitment demands
specificity. Readers should navigate to the section that matches
their role rather than read front-to-back.

**If you are a…**

- **Product sponsor / stakeholder** — read § Executive Summary,
  § Project Classification, § Success Criteria, and § Product
  Scope. Stop there unless you want implementation detail. These
  four sections (~400 lines) cover what the product is, who it
  serves, what "done" means, and what's in and out of scope.
- **UX designer (admin UI)** — read § User Journeys (especially
  Journeys 1 and 5 for the admin UI touch-points), then the
  Administration UI subsection of § Functional Requirements
  (FR83–FR95), then § Non-Functional Requirements §
  Accessibility. Skip the protocol sections.
- **Backend architect / implementer** — read § Innovation & Novel
  Patterns for the architectural decisions, § API Backend +
  Developer Tool — Specific Requirements for the contract rules,
  then all of § Functional Requirements and § Non-Functional
  Requirements. The Endpoint Specification Rules, Data Schema
  Envelopes, and Error Slug Table are load-bearing for
  wire-compatibility work.
- **Test / QA lead** — read § Success Criteria § Measurable
  Outcomes (gating table), § Non-Functional Requirements §
  Integration & Compatibility (three-layer conformance suite),
  and the full FR list as the acceptance checklist.
- **Operations / SRE adopter** — read § User Journeys § Journey 1
  (migration), § Journey 4 (troubleshooting), § Non-Functional
  Requirements § Reliability, Observability, Security, and
  Maintainability, and the Migration Guide and Troubleshooting
  Runbook references in FR113–FR114.
- **Project planner** — read § Product Scope, § Project Scoping
  & Phased Development Strategy, and the Milestone-anchored
  success criteria in § Success Criteria § Business Success.

**Dual audience note.** This PRD is optimized for both human
readers and LLM consumption (BMAD downstream workflow). Every
section has `## Level 2` headers for clean extraction, every
requirement is numbered for traceability, and anti-patterns like
subjective adjectives or implementation leakage in requirements
have been explicitly avoided.

## Success Criteria

### User Success

**Who counts as a "user" here.** IRISCouch has two distinct user
archetypes, and success criteria apply to both:
- **Adopting operators** — teams running IRIS who stand up IRISCouch
  and point existing CouchDB clients at it.
- **Client developers** — engineers whose PouchDB, replicator, `nano`,
  Cloudant SDK, or Fauxton code is supposed to keep working unchanged.

**The aha moment.** An adopting operator points a PouchDB client (or the
Apache CouchDB replicator) at an IRISCouch webapp mount point and watches
their existing database sync bidirectionally with zero client-side code
changes. No shim, no compatibility flag, no "mostly works." It either
does, or the release is not shippable.

**Completion scenarios.**
- *"I retired my CouchDB process."* An operator replicates production
  data from their standalone Apache CouchDB into IRISCouch, dual-writes
  for a validation window, cuts clients over, drains the source, and
  shuts CouchDB down. The clients never knew.
- *"Rollback is symmetric."* If anything misbehaves mid-cutover, the
  operator replicates IRISCouch back out to a fresh CouchDB and cuts
  back. No point of no return.
- *"Backup is one thing, not two."* Operators back up and restore IRIS
  Couch using standard IRIS tooling — external, online, or `IRIS.DAT`
  snapshots — with attachments and revision state captured
  automatically. No separate CouchDB backup strategy.

**Emotional success.** Adopters feel relief rather than delight — the
good kind of boring. The product disappears into the IRIS operational
surface they already know. Client developers feel nothing at all,
because their code did not change.

### Business Success

IRISCouch has no commercial aspirations — no paid tiers, no managed
service, no enterprise support contracts. "Business success" is redefined
accordingly as **project health and adoption signals**, not revenue or
ARR.

**Milestone-anchored success (the primary bar).**
- **Milestone α — Public Alpha.** PouchDB replicates a sample database
  bidirectionally against IRISCouch end-to-end AND the Apache CouchDB
  replicator runs clean in both directions. This is when the project
  goes public.
- **Milestone β — Customer Zero Complete.** The author's three
  production CouchDB databases — including their map-reduce views and
  design-doc filters — are served by IRISCouch with their existing
  clients unchanged, and the standalone Apache CouchDB process is
  retired. This is when the project has delivered on its origin story.
- **Milestone γ — MVP Feature-Complete.** Every non-deprecated item in
  the CouchDB 3.x feature inventory is either delivered, or explicitly
  documented as out of scope with a reason. Conformance harness green
  against both CouchDB 3.3.3 and 3.5.x. This is when IRISCouch
  graduates from alpha to 1.0.

**Ecosystem signals (secondary, softer).**
- At least one adopter beyond customer zero is running IRISCouch
  against real workload data within 12 months of the α public
  announcement.
- The ZPM/IPM package is published and installable; install count is
  tracked but not a gating metric.
- Bug reports and questions originating from non-author adopters appear
  in the GitHub issue tracker — any external engagement is a signal the
  "default answer for offline-first on IRIS" hypothesis is tracking.
- An independent ("not-me") test rig running the differential HTTP
  harness exists by γ.

**Non-goals as explicit business success anti-metrics.**
- IRISCouch does **not** measure itself on CouchDB community mindshare,
  InterSystems Developer Community presence, Open Exchange downloads, or
  external contributor count. The brief explicitly pauses those
  community-building pushes; they are not success metrics.
- Market share against Apache CouchDB is irrelevant. Apache CouchDB is
  healthy; IRISCouch is a backend alternative for teams already on IRIS.

### Technical Success

**Correctness bar (the unshippable-defect class).**
A replication bug that could corrupt a conflict tree — divergent revision
histories, dropped conflicts, or silent loss of a winning-rev calculation
— is never shippable. Not "rare bug." Not "edge case we'll fix in the
next patch." **Unshippable, full stop.** Any suspected corruption of the
rev tree halts the release.

**Conformance gating (per release, not per tag).**
Every release is gated on:
1. **Apache CouchDB's own JavaScript test suite** run against IRISCouch.
2. **PouchDB's replication conformance tests** (the replication subset
   PouchDB publishes for verifying CouchDB-compatible servers).
3. **Differential HTTP harness**: same request sequence issued to IRIS
   Couch and a live Apache CouchDB peer, responses diffed byte-for-byte,
   "must diff zero" on the wire-contract subset (status codes, JSON
   error envelopes, sequence tokens, checkpoint shapes, `_revs_diff` /
   `_bulk_get` outputs).

**Zero-dependency installability at α.**
A vanilla IRIS instance (Community Edition or licensed) with no Node.js,
no Python, no couchjs, no Erlang, installs IRISCouch via ZPM/IPM and
serves every α-scope endpoint on first request. JS-dependent endpoints
return 501 with a clear error message pointing to the JSRuntime backend
configuration.

**Durability and crash safety.**
All writes — document body, revision tree, changes feed, SQL
projection — land atomically inside a single journaled IRIS transaction
or not at all. Crash recovery is whatever IRIS journal replay gives us,
and replication checkpoints (`_local/` docs) survive a hard kill plus
restart with correct seq continuity.

**Attachment streaming proven.**
`%Net.MIMEReader` parses `multipart/related` attachment bodies from the
request stream without buffering the full body in memory. Large
attachments (hundreds of MB) round-trip through PUT/GET without RSS
growth proportional to attachment size.

**HA via IRIS mirroring.**
Document store, rev tree, changes feed, SQL projection, and `_local/`
checkpoints all mirror with the IRIS namespace by construction. A
promoted mirror resumes replication from the last checkpoint with seq
continuity.

**Observability at α.**
Prometheus/OpenTelemetry scrape endpoint exposes request counts,
latencies per endpoint class, replication throughput, `_changes` lag,
and Mango index hit rates.

**Audit trail at day one.**
`%SYS.Audit` emits structured events for document writes and
security-relevant operations. Existing HealthShare audit pipelines pick
up IRISCouch activity with zero additional configuration.

### Measurable Outcomes

| Outcome | Target | Milestone | Gating |
|---|---|---|---|
| PouchDB bidirectional sync against IRISCouch | End-to-end success on sample DB | α | Yes |
| Apache CouchDB replicator clean run (both directions) | No protocol errors, checkpoint resumable | α | Yes |
| Customer-zero workload served | 10,000 docs, ~500 MB total, 3 DBs, 4 map-reduce views, 2 filters, existing clients unchanged | β | Yes |
| Standalone Apache CouchDB process retired for customer zero | Process shut down, IRISCouch serves production | β | Yes |
| CouchDB 3.x non-deprecated feature inventory | Delivered OR explicitly out-of-scope with reason | γ | Yes |
| Differential HTTP harness "must-diff-zero" subset | 100% byte-identical on wire-contract surface | α onward | Yes |
| PouchDB replication conformance tests | 100% pass on replication subset | α onward | Yes |
| CouchDB JS test suite | Pass on covered subsystems; known-skip items documented | α onward | Yes |
| Zero-dependency install on fresh IRIS | ZPM install → `GET /` returns valid welcome response | α | Yes |
| Mirror failover continuity | Replication resumes from `_local/` checkpoint post-promotion with correct seq | γ | Yes |
| Attachment memory profile | RSS growth not proportional to attachment size on multi-hundred-MB PUT | α | Yes |
| External adopter beyond customer zero | ≥1 independent adopter running real workload | α + 12 months | Soft |
| Conformance harness coverage against CouchDB 3.5.x | Green at γ (3.3.3 baseline through β) | γ | Yes |

"Gating" means a release cannot ship if the outcome is not met.
"Soft" means it's a health indicator, not a release gate.

## Product Scope

**Framing note.** The author has locked the following framing and the
PRD respects it: **the entire MVP is Phases 0 through 7**. Milestones
α, β, γ are progress checkpoints *within* the MVP, not a "MVP then
post-MVP" split. The "Growth" section below therefore does NOT contain
items that are simply later MVP phases — it contains items currently
documented as out of scope that could plausibly become future-MVP work
once 1.0 ships. The "Vision" section captures the 3-year state and the
reusable-pattern ambition.

### MVP - Minimum Viable Product

**The full MVP surface — committed scope, delivered across Phases 0–7:**

**Server and database lifecycle**
- `GET /` welcome, `/_uuids`, `/_all_dbs`, `/_up`, `/_session`, `/_active_tasks`
- Database create/drop/info, `_bulk_docs`, `_all_docs`, `_bulk_get`
- `_security`, `_revs_limit`, `_compact`, `_ensure_full_commit`

**Document CRUD, MVCC, conflict model**
- Strict `_rev` optimistic concurrency with 409 / 412 semantics
- Tombstones and delete semantics via rev-tree entries
- Conflict detection, storage, inspection, winning-rev algorithm
- `_bulk_docs` with `new_edits=false` for replication

**Changes feed**
- `feed=normal` and `feed=longpoll` (the two modes PouchDB and the
  Apache CouchDB replicator use by default)
- `_doc_ids`, `_selector`, `_design` filters
- `$Increment`-backed atomic sequence generation

**Attachments**
- Inline, stub, `multipart/related`, `multipart/mixed`, `atts_since`,
  streaming in and out via `%Stream.GlobalBinary` + `%Net.MIMEReader`

**Mango query and indexing**
- `_find`, `_index` (json type), `_explain`, `partial_filter_selector`
- Built-in reduces: `_sum`, `_count`, `_stats`, `_approx_count_distinct`
- Selector-to-IRIS-SQL translation with fallback scan path
- Synchronously-maintained `Winners` projection + runtime `MangoIndex` table

**Replication protocol**
- `_revs_diff`, `_bulk_get`, `open_revs` with `multipart/mixed`
- `_local/` checkpoints with `history[]`
- Own JSON-canonical MD5 algorithm for rev hashes and `replication_id`
- Full bidirectional replication against a live Apache CouchDB 3.x peer

**JavaScript runtime (pluggable)**
- `IRISCouch.JSRuntime.Sandbox` interface with three backends
- `JSRuntime.None` — MVP default, 501 for all JS ops, zero dependencies
- `JSRuntime.Subprocess` — Node/Bun/Deno/couchjs via `$ZF(-1)`, couchjs
  line protocol, operator-enabled
- `JSRuntime.Python` — `%SYS.Python` + PetterS quickjs, operator-enabled
- JS map/reduce views, `validate_doc_update`, and custom `_changes`
  filters work via any enabled backend

**Authentication and security**
- `_users` database with PBKDF2
- `_session` cookie auth with HMAC byte-compat (Phase 6 spike)
- Basic, JWT, and proxy auth modes
- `_security` admin/member enforcement

**Operational surface (inherited from IRIS)**
- IRIS mirroring for HA
- Standard IRIS backup captures all state including attachments
- `%SYS.Audit` events for document writes and security-relevant operations
- Prometheus/OpenTelemetry metrics scrape endpoint
- `%Service_WebGateway` for transport-level auth

**Streaming feeds and clustering (γ-delivered MVP scope)**
- Standalone `%Net.TCPServer` listener on a separate port for
  `feed=continuous` and `feed=eventsource` with proper chunked transfer
  encoding (bypasses CSP Gateway response buffering)
- ECP distributed-cache clustering safety for multi-server IRIS

**Compatibility anchor**
- Apache CouchDB 3.3.3 as primary conformance baseline through β
- CouchDB 3.5.x added to the harness at γ
- Smoke-tested clients: PouchDB 9.x, `nano` 10.x, `@cloudant/cloudant`
  5.x, Fauxton (currently-shipping build)
- Live compatibility matrix published in Getting Started docs, updated
  every release

### Growth Features (Post-MVP)

**This section lists items currently marked out of scope in the product
brief that could plausibly become future-MVP tracks once 1.0 ships.**
None of these are committed. All of them would require a deliberate
decision to expand scope.

- **CouchDB 4.x wire protocol support.** IRISCouch anchors to 3.x
  stable; 4.x is tracked but not targeted.
- **Partitioned databases.** Not required for customer zero or the
  primary audience; future candidate if adopters materialize with the
  need.
- **Nouveau / Clouseau full-text search.** Would require a full-text
  backend decision and significant indexer work.
- **Mango `$text` operator.** Depends on the full-text decision above.
- **CouchDB 4.x-style clustered design (single shard, consensus).**
  A much bigger architectural undertaking than ECP-safe MVP.
- **Additional client smoke-tested versions.** The MVP matrix is
  deliberately small; extending to older PouchDB versions or additional
  language SDKs (Go, Rust) is post-MVP.
- **`JSRuntime.QuickJS`-embedded-native backend.** MVP uses
  subprocess or `%SYS.Python`; an in-process native QuickJS binding
  is an optimization track.

### Vision (Future)

**The 3-year state.**
IRISCouch is the default answer to "how do I get offline-first sync
onto IRIS?" Teams in the HealthShare ecosystem, healthcare NGOs running
field-work apps, retail POS systems, and shops with any
"occasionally-connected" workload stop treating "add CouchDB to the
stack" as the only path. They compile IRISCouch into their existing
IRIS instance, mount it at `/iris-couch/`, point their PouchDB clients
at it, and ship.

**Pattern extraction as a reusable template.**
The architectural core — a CQRS hybrid using IRIS globals for writes,
an IRIS SQL projection for reads, and a pluggable runtime sandbox for
user-supplied scripting — is not CouchDB-specific. It is a reusable
template for building wire-compatible facades over other
document-oriented systems on top of IRIS: **Mongo-on-IRIS,
DynamoDB-on-IRIS, Firebase-on-IRIS**, or any other system whose clients
deserve a migration path into an existing IRIS deployment. IRISCouch
is the first proof-of-existence for this pattern on IRIS; its code is
organized so the pattern is extractable as a reference implementation
for future projects.

**Explicit vision non-goals.**
- IRISCouch does not evolve toward commercial productization, paid
  tiers, or a managed hosting service.
- IRISCouch does not position itself as a CouchDB migration
  destination for teams *not* on IRIS.
- IRISCouch does not compete with MongoDB, Postgres, DynamoDB, or IRIS
  DocDB as a general-purpose document database.

## User Journeys

User archetypes in IRISCouch are unusual in one important way: the
best possible user experience for the **client developer** persona is
"nothing happens." Their code does not change, so the journey is a
non-event — and the PRD treats that non-event as a requirement, not an
afterthought. Human activity concentrates around the **operator**
personas (installing, migrating, observing, troubleshooting) and the
**customer zero** narrative that anchors the whole project.

Five journeys follow. Each one reveals a distinct requirement surface,
summarized in the closing § Journey Requirements Summary.

### Journey 1 — Maya, HealthShare operator retiring a standalone CouchDB

**Persona.** Maya is a senior platform engineer at a mid-sized regional
healthcare network running HealthShare on IRIS. For the past four years,
her team has also operated a separate Apache CouchDB cluster behind one
internal field-data-capture app. Two backup dashboards. Two sets of
credentials in the secrets vault. Two upgrade windows a year. An
oncall playbook with a CouchDB section she has never been comfortable
with because it is the only non-IRIS piece of infrastructure in the
stack. She has quietly wanted the CouchDB process gone for two years
and has not found an off-ramp.

**Opening scene.** Maya is three weeks out from a RHEL 9 migration on
the CouchDB host. Red Hat has dropped SpiderMonkey; the current CouchDB
version won't install cleanly on the new OS. She has two paths: spend
the next sprint upgrading CouchDB, migrating design docs to QuickJS,
and standing up a new RHEL 9 host — or look for a different answer.
She finds a GitHub repo called `iris-couch` through a search for
"CouchDB on IRIS" and reads the README with moderate skepticism.

**Rising action.** The README says three things that catch her
attention: "no second database process," "zero mandatory external
dependencies beyond IRIS," and "every release is dogfooded against
customer zero's production data." She runs the ZPM install against a
dev IRIS instance, mounts the webapp at `/iris-couch/`, and runs
`curl http://localhost:52773/iris-couch/` — she gets a welcome JSON
response that is indistinguishable from a real CouchDB one. She opens
the built-in IRISCouch admin UI at `/iris-couch/_utils/` in her
browser, uses the "Create database" button to stand up an empty target
DB for the replication, and confirms it appears in the database list.
She runs `curl .../_uuids?count=3` and gets three hex UUIDs. She points
the Apache CouchDB replicator from her dev CouchDB at her dev IRIS
Couch and replicates a database full of test documents in. She
refreshes the admin UI, clicks into the replicated database, browses a
handful of documents to visually confirm the data is there, then clicks
into `_design/` and sees the design documents that came across with the
replication. She runs a diff of `_all_docs` between source and
destination via curl. They match.

**Climax.** Maya boots up a disposable PouchDB instance in a browser
tab, points it at IRISCouch, and watches an initial replication run
bidirectionally against her field-data-capture app's schema. Nothing in
the PouchDB code has changed. She opens the IRIS Management Portal's
mirror configuration page and notes that the mirror for the namespace
IRISCouch lives in is already configured — she does not have to set up
a separate HA story for CouchDB anymore. She checks `%SYS.Audit` and
sees document-write events for the replicated documents already flowing
through her existing HealthShare audit pipeline. That was four things
she was expecting to do that she does not have to do.

**Resolution.** Maya's RHEL 9 migration plan changes. Instead of
upgrading CouchDB, she replicates production CouchDB data into a
staging IRISCouch during a validation window, runs a differential
`_all_docs` diff, dual-writes for a week to build confidence, then cuts
her application clients over to IRISCouch and shuts the CouchDB host
down. Her next oncall playbook has one fewer section in it.

**What this journey requires.**
- Zero-dependency installable from ZPM/IPM into a vanilla IRIS
- `GET /` welcome response, `/_uuids`, `/_all_dbs` work on first install
- Apache CouchDB replicator replicates in cleanly from a real CouchDB peer
- PouchDB does end-to-end bidirectional sync without client changes
- IRIS mirroring covers all IRISCouch state without operator work
- `%SYS.Audit` emits document-write events from day one
- **Lightweight built-in admin UI** at `/iris-couch/_utils/` — database
  lifecycle, document browsing, design document viewing. No separate
  install, no second port, no Fauxton dependency. See Summary §9 for
  the full scope boundary.
- Getting Started docs walk Maya from "install" to "replicated in" in
  under an hour
- Published migration playbook with dual-write + cutover + rollback steps

### Journey 2 — Amelia, the client developer who feels nothing

**Persona.** Amelia is a mobile engineer at the same healthcare network.
She owns the field-data-capture Android app — offline-first, PouchDB
under the hood, roughly 4,000 lines of TypeScript. She did not know
Maya was looking at IRISCouch. She does not know what IRISCouch is.

**Opening scene.** Amelia's build pipeline runs integration tests
against a staging CouchDB. On a Tuesday, the staging environment's
CouchDB URL changes to `/iris-couch/` because Maya has rolled out the
new backend to staging. Amelia does not see a ticket about this. It
does not generate a Slack message.

**Rising action.** Amelia's integration tests run. They pass. Her
PouchDB instance replicates against the new URL. Attachments round-trip.
`_find` queries return the same rows. The app's offline-first flow
works.

**Climax.** There is no climax. Amelia's Tuesday is uneventful. She
closes tickets.

**Resolution.** Three weeks later Maya mentions in a team standup
that the CouchDB process has been retired from staging. Amelia says
"oh, I didn't notice." Maya says "that was the entire point." Amelia
goes back to her laptop.

**What this journey requires.**
- Wire-compatibility is not "mostly." Status codes, JSON error
  envelopes, sequence token shapes, checkpoint shapes, `_bulk_get`
  responses must match byte-for-byte on the wire-contract subset
- The differential HTTP harness "must-diff-zero" test is the enforcement
  mechanism for this journey
- When new PouchDB or nano versions ship, the compatibility matrix is
  updated before an adopter upgrades a client and finds out the hard way
- Clear 501 UX for any endpoint the vanilla MVP does not serve, so that
  IF Amelia does hit something (design-doc JS view in MVP default
  config), she sees a clean error pointing at the operator action

### Journey 3 — The author retiring customer zero

**Persona.** The project's author. Has run Apache CouchDB in production
for years. Has a standalone Apache CouchDB instance serving three
production databases totaling roughly 10,000 documents and ~500 MB of
content including attachments. Four map-reduce views and two filter
functions sit between those databases. The author is also the sole
developer of IRISCouch.

**Opening scene.** Phase 0 scaffolding is merged, the Phase 1 rev engine
works in a unit-test harness, and the author has a private IRISCouch
instance running on a dev server alongside the production CouchDB. The
roadmap says α (Public Alpha) must happen before β (Customer Zero
Complete), but the author is allowed to start migrating the smallest of
the three databases to a staging IRISCouch as soon as replication is
stable enough.

**Rising action.** The author points the Apache CouchDB replicator at
the smallest production database and replicates into IRISCouch. The
first run reveals a subtle bug in the rev-tree merge path — a conflict
that exists upstream is not preserved on replication in. The release
does not ship. The bug is fixed. The run is repeated. The differential
HTTP harness is extended to catch that class of regression. Replication
is re-run and succeeds. The same process happens for the medium database
and its map-reduce views, which requires enabling `JSRuntime.Subprocess`
with a local Node install and testing the couchjs line protocol
implementation against real design docs from production data.

**Climax.** Milestone β arrives. The author points every client that
reads or writes the three production CouchDB databases at IRISCouch.
The standalone Apache CouchDB process is stopped and its host is
reclaimed. The author watches metrics for a week. Replication throughput
is steady. `_changes` lag is unchanged. The conformance harness is still
green. Nothing breaks.

**Resolution.** The project has delivered on its origin story. IRIS
Couch tags β-complete. The author writes a blog post titled "Retiring a
production CouchDB with IRISCouch" and it becomes the single most
credible artifact in the project's history — not because it is
marketing, but because it describes a migration that actually happened,
the three bugs that had to be fixed before it could happen, and the
regression tests that now gate every subsequent release.

**What this journey requires.**
- Customer zero's workload is treated as the project's continuous
  regression suite, not an acceptance test
- Any bug found in customer zero's workload must produce a new
  conformance test before the bug fix ships
- `JSRuntime.Subprocess` must ship complete enough to serve map-reduce
  views and filter functions by β, not just "work for a toy"
- Metrics (replication throughput, `_changes` lag) must be visible
  without setting up a second observability stack
- Rollback path (replicate IRISCouch → fresh CouchDB) is exercised at
  least once against customer zero before β is declared
- Migration blog post template / playbook that future adopters can
  follow verbatim

### Journey 4 — Tomás, SRE debugging a replication lag incident

**Persona.** Tomás is the oncall SRE at a new post-α adopter site — a
telehealth NGO running a HealthShare deployment with IRISCouch serving
a field-worker mobile app. This is their first adoption; they installed
IRISCouch six weeks ago based on Maya's blog post. Tomás did not
install it himself and is not a CouchDB expert.

**Opening scene.** 02:14 on a Wednesday. Tomás gets paged: "PouchDB
clients at two field sites are reporting replication failures." He has
no idea whether this is an IRIS problem, a network problem, or an IRIS
Couch problem.

**Rising action.** Tomás opens the team's Grafana dashboard. He sees
`_changes` lag climbing on IRISCouch from a normal baseline of <1s to
several minutes. He sees the Prometheus-exposed error counter for
replication endpoints ticking up. He checks the IRIS Management Portal
for the namespace IRISCouch runs in and sees nothing unusual at the
IRIS level — journaling is healthy, locks are clean, no runaway
processes. He opens the IRISCouch runbook he bookmarked when the
system went in and follows the "replication lag" troubleshooting
section. The runbook points him at a specific `^IRISCouch.Changes`
global sequence counter, a specific audit query for recent write
volume, and a specific curl command to check `_local/` checkpoint
state. Within ten minutes he discovers a client bug: one field-site
router is replaying old `_changes` requests after a network reset in a
tight loop because of a stale user-agent string.

**Climax.** Tomás kills the offending client session. `_changes` lag
drops back to normal within thirty seconds. He writes up the incident
in the team's postmortem channel. The incident was not IRISCouch's
fault, but the fact that Tomás could diagnose it from Grafana + runbook
+ one audit query is what made the page closable in thirty minutes
instead of three hours. He goes back to bed.

**Resolution.** The team's internal runbook gets one more entry
appended to it. Tomás now trusts IRISCouch slightly more than he did
the day before. The IRISCouch project learns that "replication lag
with a noisy client" is a case the published runbook should cover — a
GitHub issue is filed to document it upstream.

**What this journey requires.**
- Prometheus/OpenTelemetry metrics for request counts, latencies,
  replication throughput, `_changes` lag, error rates — exposed at α
- A published troubleshooting runbook in the Getting Started docs
  covering at minimum: replication lag, checkpoint corruption, stuck
  conflicts, attachment stream failures, JS sandbox errors
- Audit events queryable for recent write volume to distinguish
  "we're receiving too much" from "we're processing too slowly"
- Error messages on the HTTP surface must be actionable — "reason"
  fields that name the subsystem and the specific failure mode, not
  generic "server error" envelopes
- No part of this journey requires an IRISCouch-specific CLI tool
  beyond curl — everything is reachable via the standard IRIS
  operational surface plus the admin UI plus the runbook

### Journey 5 — Devi, evaluating IRISCouch in a 60-minute spike

**Persona.** Devi is a tech lead at a HealthShare-adjacent shop
evaluating whether their next field-work application can use IRISCouch
or whether they should bolt on a standalone CouchDB. She has not used
IRISCouch before and she has a hard 60-minute block on her calendar
because her team needs an answer before tomorrow morning's architecture
review.

**Opening scene.** 14:00. Devi has a fresh IRIS Community Edition
container running on her laptop. She has the `iris-couch` GitHub repo
open in one tab and the PouchDB quick-start in another. Her stopwatch
is running.

**Rising action.** She runs the ZPM install command from the README.
It completes in under two minutes. She runs the `curl GET /iris-couch/`
smoke test from the README. Welcome response comes back. She runs the
"Hello, document" walkthrough: `PUT /iris-couch/mydb`,
`POST /iris-couch/mydb` with a JSON body, `GET /iris-couch/mydb/$id`,
check the `_rev`, update the doc, check the conflict-on-stale-rev
response. Everything works exactly like CouchDB would. She opens the
built-in admin UI at `/iris-couch/_utils/`, sees her newly-created
`mydb` database in the list, clicks in, and spot-checks the document
she just POSTed — right `_id`, right `_rev`, right body. She points a
local PouchDB instance at `/iris-couch/` and replicates a test dataset
in. It works. She runs `_find` with a Mango selector. It works. She
tries one thing she expects NOT to work — a design-doc JS view — and
sees a 501 response with an error message that says "JSRuntime.None is
the default; enable JSRuntime.Subprocess to execute user JavaScript."
That is exactly the kind of message she needs: honest, specific,
actionable.

**Climax.** Devi has fifteen minutes left on her timer. She writes
three bullets in her notebook: (1) Mango queries work, (2) PouchDB sync
works, (3) JS views are behind an opt-in flag but the opt-in path is
documented. She closes her laptop with time to spare. Her recommendation
for tomorrow's architecture review will be "use IRISCouch, plan for
the JSRuntime.Subprocess enablement if we end up writing design-doc
views."

**Resolution.** Devi becomes the second external adopter after Maya.
The project's ≥1-adopter-by-α+12-months soft metric flips to green.

**What this journey requires.**
- A README that gets to a working `curl GET /` in under five minutes of
  reading
- ZPM install completes on a fresh IRIS Community Edition with no
  manual configuration
- "Hello, document" walkthrough in Getting Started docs that matches
  CouchDB's own quick-start step-for-step
- 501 error responses carry a "reason" string that names the missing
  component and points at the docs section explaining how to enable it
- Mango `_find` works with common selectors (equality, `$gt`, `$lt`,
  `$in`, `$and`, `$or`) from first install
- **Built-in admin UI** reachable in one click from the Getting Started
  walkthrough at `/iris-couch/_utils/`
- The compatibility matrix and "what works today vs what needs an
  opt-in" page is reachable in two clicks from the README

### Journey Requirements Summary

These five journeys, taken together, reveal the following capability
areas as non-negotiable for the MVP — each gets formalized in the
Functional Requirements and Non-Functional Requirements steps that
follow:

1. **Wire-compatible HTTP API surface** covering the full CouchDB 3.x
   inventory listed in Product Scope § MVP, verifiable via the
   differential HTTP harness. Source: Journeys 1, 2, 3, 5.
2. **Zero-dependency installability** via ZPM/IPM on a vanilla IRIS.
   Source: Journeys 1, 5.
3. **Replication protocol completeness** — bidirectional with a real
   Apache CouchDB peer, `_local/` checkpoints survive restart, conflict
   trees preserved without corruption. Source: Journeys 1, 3.
4. **`JSRuntime.Subprocess` production-complete by β** — not a demo,
   but a path customer zero's map-reduce views and filter functions
   can actually run on. Source: Journey 3.
5. **Observability at α** — Prometheus/OpenTelemetry scrape endpoint
   with request counts, latencies per endpoint class, replication
   throughput, `_changes` lag, error counters. Source: Journey 4.
6. **Actionable error responses** — 501 and error envelopes name the
   subsystem and point at the specific config or documentation section
   that resolves them. Source: Journeys 4, 5.
7. **Inherited operational surface** — IRIS mirroring, standard IRIS
   backup, `%SYS.Audit` events. No IRISCouch-specific operational
   tooling required. Source: Journeys 1, 3, 4.
8. **Published documentation artifacts**: Getting Started walkthrough
   (Journey 5), migration playbook with dual-write + rollback (Journey
   1), troubleshooting runbook (Journey 4), compatibility matrix
   (Journeys 1, 2, 5). These are PRD-committed deliverables, not "nice
   to have."
9. **Lightweight built-in admin UI** served from the same webapp mount
   point at `/iris-couch/_utils/` (matching CouchDB's convention for
   operator muscle memory). Implemented as an **Angular** single-page
   application — the standard SPA framework for IRIS-based admin
   surfaces in 2026 — compiled to a static HTML/JS/CSS bundle shipped
   inside the ObjectScript package and served as static assets from
   the IRIS webapp. No Node runtime at install time; Node only at the
   IRISCouch developer's build step. **In scope for the built-in UI**:
   database lifecycle (create, list, drop, per-database info), document
   list with pagination, document detail view with revision history,
   design document management (view, create, edit, delete), and a
   basic `_security` admin/member view. **Explicitly out of scope for
   the built-in UI**: full Mango query builder, map-reduce view
   composer, replication scheduler UI, user administration beyond
   `_security`, profiling/performance tooling, anything that duplicates
   a general-purpose CouchDB admin surface. **Delivered incrementally
   across phases**: a minimum viable subset (database list + create +
   drop + document list + document detail) is α scope so evaluators
   like Devi can rely on it in a 60-minute spike; design document
   management and the `_security` view land at β alongside the
   JSRuntime.Subprocess enablement; revision history view and stats
   panel land at γ. **Fauxton continues to work** for anything more
   advanced — it is a CouchDB client and IRISCouch speaks the wire
   protocol — so adopters who need Fauxton's deeper tooling can point
   Fauxton at IRISCouch with no extra work. The built-in UI is a
   first-15-minutes convenience, not a Fauxton replacement. Source:
   Journeys 1, 5.

The customer-zero story (Journey 3) is the one that collapses all five
journeys into a single correctness bar: *a release that breaks any of
these journeys is a release that cannot ship*, because customer zero's
own migration will catch the regression before a public tag.

## Innovation & Novel Patterns

IRISCouch is primarily a **disciplined execution of wire-compatibility**
rather than a breakthrough invention. Its credibility comes from
finishing where prior attempts stalled, not from inventing new
primitives. This section exists to record the three genuinely novel
elements that make the execution feasible — and to distinguish them
from the parts of the product that are deliberately *not* innovative.

### Detected Innovation Areas

**1. "Wire protocol as spec, not code" as an execution strategy.**
The historical graveyard of CouchDB reimplementations (BigCouch,
rcouch, couch4j, kivik) has a shared failure pattern: each tried to
build a database engine *and* a wire protocol layer from scratch, and
each ran out of maintainer bandwidth before reaching production parity.
IRISCouch inverts the scope boundary. The wire protocol is the entire
deliverable; the database engine underneath is already shipped as IRIS.
Wire compatibility as an integration strategy is not itself novel
(Postgres, MySQL, Redis wire-compatible implementations exist), but
its first application to CouchDB on a non-Erlang runtime with a
production shipping target is. The innovation is less in the technique
than in *where the scope boundary is drawn*.

**2. Decoupling wire-protocol completeness from JS runtime availability
via `IRISCouch.JSRuntime.Sandbox`.** Apache CouchDB is welded to its
JavaScript engine — SpiderMonkey historically, QuickJS from 3.4
onward. You cannot run CouchDB without an installed JS runtime.
IRISCouch introduces a pluggable sandbox interface with three backends
(`None`, `Subprocess`, `Python`) and a 501-returning default, so the
95% of the CouchDB surface that does not require user-supplied JS —
document CRUD, `_bulk_docs`, `_all_docs`, `_bulk_get`, attachments,
`_changes` (normal/longpoll), Mango `_find`/`_index`/`_explain`, and
the full replication protocol — runs with zero external dependencies.
JavaScript becomes an operator-selected capability rather than a
hard install prerequisite. **We are not aware of a prior
CouchDB-compatible server that has made this split**; this appears to
be the first CouchDB-family implementation where "wire-compatible"
and "JS-capable" are independent, operator-selected axes.

**3. CQRS hybrid storage mapped to IRIS globals + synchronous SQL
projection — proof-of-existence.** The general CQRS pattern is
well-known. What is novel here is the specific mapping and the
synchronous-maintenance guarantee:
- Writes flow through journaled IRIS transactions into raw
  multi-dimensional globals: `^IRISCouch.Docs` (document bodies),
  `^IRISCouch.Tree` (revision trees for MVCC), `^IRISCouch.Changes`
  (the changes feed with atomic `$Increment`-based sequences),
  `^IRISCouch.Atts` via `%Stream.GlobalBinary` (attachments), and
  `^IRISCouch.Local` (`_local/` replication checkpoints).
- Reads for Mango queries flow through a `%Persistent` "winners"
  projection class (`IRISCouch.Projection.Winners`) plus a runtime
  `MangoIndex` table (`IRISCouch.Projection.MangoIndex`) that avoids
  runtime class recompilation when adopters create new Mango indexes.
- **The projection is maintained synchronously in the same journaled
  transaction as the underlying write.** There is no eventual
  consistency window. A Mango `_find` issued immediately after a
  `POST` against the same document sees the updated document.
- This is only feasible because IRIS's journaled transaction model
  spans raw globals and `%Persistent` classes atomically — most
  storage engines cannot offer that guarantee, which is why async
  CQRS with a lag window is the more common pattern elsewhere.

IRISCouch is positioned as a **proof-of-existence** of the
"globals-for-writes + synchronous SQL projection for reads" pattern
on IRIS — the first working implementation demonstrating that the
pattern is viable for a production wire-compatible document store.
The PRD does not claim that the pattern is yet a reusable template
for future wire-compat facades on IRIS; whether extractability holds
is an open question the project will answer by actually shipping
IRISCouch first. Pattern extraction for potential Mongo-on-IRIS /
DynamoDB-on-IRIS / Firebase-on-IRIS work is explicitly a
vision-level aspiration discussed in Product Scope § Vision, not a
commitment of this PRD.

### Market Context & Competitive Landscape

**Inside the CouchDB family (2026):**
- **Apache CouchDB** — healthy, well-maintained, not being replaced;
  the reference implementation IRISCouch conforms to.
- **PouchDB Server** — community-maintained Node.js CouchDB-compatible
  server; has open issues; not positioned as production-grade CouchDB
  3.x replacement; adds Node.js to the stack rather than eliminating
  a database.
- **IBM Cloudant** — commercial managed CouchDB-compatible service;
  cloud-only, vendor lock-in, no on-prem equivalent.
- **Couchbase Server** — originally forked from CouchDB lineage but
  **not wire-compatible**; requires application rewrites to migrate
  from CouchDB; Couchbase publishes its own CouchDB-migration guide
  treating CouchDB users as a migration target.
- **Historical reimplementations**: BigCouch, rcouch, couch4j, kivik —
  all dormant. None are maintained in 2026.
- **Kivik and other Go/Rust adapter libraries** — client-side
  abstraction layers, not servers. No actively-maintained
  Go/Rust/Python *wire-compatible CouchDB server* exists.

**Inside the IRIS ecosystem (2026):**
- **IRIS DocDB** — InterSystems' own document database feature;
  exposes a proprietary `/api/docdb/v1` REST surface. Does **not**
  speak the CouchDB HTTP API, does not implement Mango, and does
  not participate in the CouchDB replication protocol. IRISCouch
  complements IRIS DocDB rather than competing with it; they occupy
  different slots in the IRIS ecosystem.

**Market timing signal.** CouchDB 3.4 (September 2024) adopted QuickJS
specifically because Red Hat dropped SpiderMonkey from RHEL 9, putting
every SpiderMonkey-era CouchDB deployment under active migration
pressure. "Port to IRISCouch" is an alternative to "upgrade CouchDB
*and* migrate to QuickJS *and* redeploy on a supported OS." The
migration window is open now for the specific population of IRIS
shops running older CouchDB instances.

### Validation Approach

Each innovation has a concrete validation path already committed to
in the Success Criteria section and the conformance strategy:

**Wire-protocol-as-spec** is validated by the three-layer conformance
suite that gates every release:
1. Apache CouchDB's own JavaScript test suite run against IRISCouch
2. PouchDB's replication conformance test suite
3. Differential HTTP harness issuing identical request sequences to
   IRISCouch and a live Apache CouchDB peer, diffing responses
   byte-for-byte on the wire-contract subset

**JSRuntime decoupling** is validated by the α milestone acceptance
criterion: PouchDB replicates a sample database bidirectionally
against IRISCouch end-to-end with **no mandatory external
dependencies**. If a replication-path feature turns out to require
JavaScript, α cannot ship, and the decoupling has failed. Research
has already enumerated the JS touch-points in CouchDB and confirmed
that only design-doc view execution, `validate_doc_update`, and
custom `_changes` filters require JS — none of which are in the
replication critical path.

**CQRS hybrid with synchronous projection** is validated by
read-after-write consistency tests: issue a document `POST`, then
immediately issue a Mango `_find` query whose selector matches the
just-posted document, and verify the document appears in the result
set in the same transaction boundary. The pattern is then exercised
at scale against customer zero's real production workload (10,000
documents, 4 map-reduce views, 2 filters) before β can be declared.

### Risk Mitigation

**If wire-protocol-as-spec fails** — some CouchDB behavior turns out
to be undocumented and only observable in Erlang source — the
fallback is disciplined: source-spike the specific behavior, add a
new conformance test, implement, verify. Research already retired
this risk class for rev hashes and `replication_id` via the same
discipline.

**If JSRuntime decoupling fails** — a critical replication-path
feature turns out to require JS execution that cannot be stubbed with
a 501 — the fallback is to promote `JSRuntime.Subprocess` from
operator-opt-in to a mandatory MVP dependency and document the
install step. Research currently assesses this risk as retired
(replication path does not touch user JS), but the fallback exists.

**If the synchronous SQL projection regresses under scale** — write
throughput drops because the synchronous maintenance becomes a
bottleneck on workloads substantially larger than customer zero's
envelope — the fallback is async projection with a bounded lag
window behind a feature flag. This is a *scalability* fallback,
not a correctness fallback; it only applies to workloads beyond the
≈10,000-document, ≈500 MB, few-writer profile of customer zero.
Post-α benchmarking will establish where this ceiling actually sits.
Until then, synchronous-only remains the default and the guarantee.

### What Is Deliberately NOT Innovative

To keep innovation claims honest, IRISCouch deliberately avoids
novelty in several places where prior projects were tempted to
innovate and suffered for it:

- **Not a new wire protocol.** IRISCouch matches CouchDB's HTTP API
  exactly, down to status codes, JSON error envelope shape, sequence
  token format, and checkpoint document shape. Zero invention on the
  public contract.
- **Not a new storage engine.** IRIS is the storage engine. Durability,
  journaling, recovery, backup, replication of the IRIS namespace,
  mirroring, and clustering are IRIS's responsibilities, not
  IRISCouch's.
- **Not a new query language.** Mango is CouchDB's. IRISCouch only
  translates Mango selectors into IRIS SQL; it does not extend Mango
  with new operators or propose a "better" query language.
- **Not a new JavaScript sandbox implementation.** When the operator
  enables `JSRuntime.Subprocess`, it spawns existing runtimes
  (Node, Bun, Deno, couchjs) via `$ZF(-1)` and speaks CouchDB's
  *existing* couchjs line protocol. No new interpreter, no new
  binding layer.
- **Not a new conflict resolution model.** CouchDB's MVCC with
  winning-rev calculation and deterministic conflict preservation
  is implemented as specified, not reinvented.

This discipline is itself load-bearing: every innovation above exists
only because the non-innovations above are held fixed.

## API Backend + Developer Tool — Specific Requirements

Where § Innovation & Novel Patterns locked the *architectural*
decisions that make IRISCouch feasible, this section locks the
*contract* decisions that make IRISCouch verifiable. IRISCouch is
a dual-classification product: an HTTP API backend (a `%CSP.REST`
façade exposing CouchDB 3.x's wire protocol) and a developer tool
(an ObjectScript package installed via ZPM/IPM, consumed by
existing CouchDB-ecosystem client libraries). This section locks
the project-type-specific contract details that the preceding
sections reference but do not enumerate in full.

### Project-Type Overview

**The HTTP API surface** is defined entirely by CouchDB 3.x's published
behavior. IRISCouch does not invent, extend, or reinterpret any public
endpoint; the endpoint list in **Product Scope § MVP** is the complete
committed surface. This section does not re-list endpoints — it locks
the contract rules the endpoints must obey.

**The developer tool surface** is defined by the ObjectScript package
published to ZPM/IPM and the documentation artifacts shipped alongside
it. Client-side SDK support is **inherited, not built**: every
CouchDB client library in the ecosystem is a potential IRISCouch
client unchanged. The smoke-tested matrix is narrow by deliberate
choice; see § Language Support Matrix below.

**Implementation language split (binding rule).** IRISCouch is
implemented in **two languages, each confined to a specific layer**:

- **InterSystems ObjectScript — server backend.** The HTTP API layer,
  storage engine, revision/conflict engine, changes engine, Mango
  selector translation, replication engine, attachment handling,
  authentication, and `_security` enforcement are implemented
  **exclusively** in ObjectScript. Per the project's original kickoff
  brief, proposals that move primary database engine logic outside
  IRIS are rejected. External-language escape hatches exist only
  for (a) operator-enabled JSRuntime backends executing
  user-supplied design-doc JavaScript, and (b) test harness /
  benchmarking scripts.
- **TypeScript + Angular — admin UI only.** The lightweight built-in
  admin UI at `/iris-couch/_utils/` described in § User Journeys is
  a **TypeScript + Angular single-page application**, compiled to a
  static HTML/JS/CSS bundle at IRISCouch build time and shipped
  inside the ObjectScript package as static web assets. The Angular
  toolchain is required at IRISCouch *development* time; it is
  **not** required at adopter install time. Adopters run a vanilla
  IRIS with no Node runtime, no npm, no Angular CLI — they receive
  the compiled bundle as part of the ZPM package.

This split is intentional and non-negotiable: the backend cannot
drift into a mixed-language implementation, and the admin UI cannot
drift into server-rendered ObjectScript CSP pages that would
complicate the SPA model. Any proposal to implement backend logic
in Angular (e.g., "just do the `_find` selector parsing
client-side") or to implement admin UI logic in ObjectScript (e.g.,
"a CSP page for database listing") is a scope violation and should
be rejected at review.

### Endpoint Specification Rules

Every endpoint IRISCouch serves must obey the following rules, which
collectively define "wire-compatible" in operational terms:

**HTTP method allowance.** The set of methods IRISCouch accepts on
each resource is byte-identical to CouchDB's — if CouchDB returns 405
Method Not Allowed for `POST /{db}/{docid}`, IRISCouch returns 405
with the same `Allow` header value. The method allowance table is
derived from CouchDB source as a conformance artifact, not from
documentation (documentation is sometimes stale upstream).

**Status code table.** Status codes IRISCouch emits for each error
class must match CouchDB exactly. The minimum committed subset is:

| Status | Used for |
|---|---|
| 200 OK | Successful GET / PUT / POST returning a body |
| 201 Created | Successful document PUT / POST creating a new document |
| 202 Accepted | Bulk writes where some items failed validation |
| 304 Not Modified | ETag-matched GET |
| 400 Bad Request | Malformed JSON, invalid selector, invalid `_rev` format |
| 401 Unauthorized | Authentication failed or missing |
| 403 Forbidden | Authenticated but not authorized (`_security`, validator reject) |
| 404 Not Found | Database, document, or attachment does not exist |
| 405 Method Not Allowed | HTTP method not valid for resource |
| 406 Not Acceptable | Content negotiation failure (rare) |
| 409 Conflict | `_rev` stale on update, or concurrent update conflict |
| 412 Precondition Failed | Database already exists on PUT, or `If-Match` fails |
| 413 Request Entity Too Large | Document body exceeds configured limit |
| 415 Unsupported Media Type | Non-JSON / non-multipart body on write |
| 416 Requested Range Not Satisfiable | Attachment range request out of bounds |
| 417 Expectation Failed | `Expect: 100-continue` handling failure |
| 500 Internal Server Error | Unhandled internal failure |
| 501 Not Implemented | Endpoint is recognized but backend (JS, `$text`) not enabled |
| 503 Service Unavailable | Backpressure, compaction lock contention |

**JSON error envelope shape.** Every error response body is a JSON
object of the form `{"error": "<slug>", "reason": "<human-readable>"}`
where the `error` slug is drawn from CouchDB's published slug list
(`not_found`, `conflict`, `unauthorized`, `forbidden`,
`bad_request`, `missing_stub`, `invalid_design_doc`, etc.) and the
`reason` string is a specific, actionable human-readable message. The
differential HTTP harness enforces slug parity on the wire-contract
subset.

**Content negotiation.** IRISCouch honors `Accept: application/json`
(default), `Accept: multipart/related`, `Accept: multipart/mixed`, and
`Accept: text/event-stream` (at γ for `feed=eventsource`). Unknown
Accept types fall back to `application/json` with a 200 OK — matching
CouchDB's permissive behavior, not a strict 406.

**Character encoding.** All JSON request and response bodies are
UTF-8 encoded. Non-UTF-8 payloads return 400 Bad Request with error
slug `bad_request` and reason `invalid_utf8`.

**HTTP/1.1 required; HTTP/2 not required.** The CSP Gateway handles
HTTP version negotiation. IRISCouch does not assume HTTP/2 features
(server push, multiplexing) for any of its behavior. HTTP/1.1
keep-alive is sufficient.

### Authentication Model

**Core principle.** The `_users` database and `_session` cookie auth
surface exposed by IRISCouch are **translation layers** over IRIS's
existing authentication stack. Credentials, users, roles, and
permissions live in IRIS's `Security.*` classes; IRISCouch does not
maintain a shadow credential store outside the IRIS security model.

**`_session` cookie auth.** POST `/_session` with form-encoded
`name`/`password` returns an `AuthSession` cookie with an HMAC
signature. The HMAC byte-compat contract with CouchDB is a committed
Phase 6 work item (research flagged it as a deferred spike). Cookie
lifetime, rolling refresh, and the signature algorithm match
CouchDB's published `couch_httpd_auth` behavior.

**Basic auth.** `Authorization: Basic <base64>` is honored on every
request. Credentials are validated against the IRIS user directory
via standard `%SYSTEM.Security` APIs, not against a separate CouchDB
credentials table.

**JWT auth.** JWTs are validated against operator-configured issuers
and public keys. JWT issuer configuration lives in an
IRISCouch-managed configuration store (exact class/table layout is
an architecture decision, not a PRD decision). Claim mapping from
JWT to IRIS user identity is operator-configurable.

**Proxy auth.** `X-Auth-CouchDB-UserName` and
`X-Auth-CouchDB-Roles` headers are honored when the request arrives
from a trusted upstream as configured via a shared secret — matching
CouchDB's `proxy_authentication_handler` behavior.

**`_users` database.** The `_users` database is a real IRISCouch
database like any other, but its document `_id` values (of the form
`org.couchdb.user:<name>`) are mapped one-to-one to IRIS users via a
synchronization layer: creating a document in `_users` creates or
updates the corresponding IRIS user; deleting tombstones the IRIS
user; password fields are hashed via IRIS's PBKDF2 primitives and
stored in the IRIS user record, not in the `_users` document body.
The `_users` document body exposes CouchDB-format metadata
(`roles`, `type`, `derived_key`, `iterations`, `password_scheme`)
for wire compatibility; the actual credentials live in IRIS.

**`_security` enforcement.** Each database has a `_security` document
with `admins` and `members` stanzas (name lists + role lists).
IRISCouch enforces admin/member access on every request that touches
the database: admins can read/write/design, members can read/write
documents but not design, unauthenticated requests are denied if
`members.names` or `members.roles` are non-empty. Enforcement happens
at the HTTP dispatch layer, before any document logic runs.

**Explicitly NOT supported at MVP:** OAuth 1.0a (deprecated in CouchDB
3.x, removed in 4.x), LDAP direct integration (adopters who need LDAP
use IRIS's existing LDAP configuration and rely on the credential
translation layer).

### Data Schema Envelopes

CouchDB is schemaless for document *bodies*, but the wire format has
several fixed envelopes IRISCouch must accept and emit. Each envelope
below is locked as part of the wire contract.

**Document envelope.** Every document on the wire has shape:
```json
{
  "_id": "string",
  "_rev": "N-hex32",
  "_deleted": false,
  "_attachments": { "<filename>": { ... } },
  "_conflicts": [ "N-hex32", ... ],
  "_revs_info": [ { "rev": "N-hex32", "status": "available" | "missing" }, ... ],
  "_revisions": { "start": N, "ids": [ "hex32", ... ] },
  "_local_seq": N,
  "<user fields>": "<user values>"
}
```
All underscore-prefixed fields are reserved CouchDB metadata.
User-level underscore-prefixed fields are rejected with 400
`doc_validation` (matching CouchDB's validation).

**Design document envelope.** Documents with `_id` starting
`_design/` carry additional reserved fields: `language`, `views`,
`validate_doc_update`, `filters`, `updates` (deprecated), `shows`
(deprecated), `lists` (deprecated), `rewrites` (deprecated),
`options`, `autoupdate`. IRISCouch stores the full body regardless of
whether it can execute the functions. JS function execution returns
501 in the `JSRuntime.None` default.

**Replication document envelope.** Documents in the `_replicator`
database carry: `source`, `target`, `create_target`, `continuous`,
`cancel`, `doc_ids`, `selector`, `filter`, `query_params`,
`owner`, `_replication_id`, `_replication_state`,
`_replication_stats`. IRISCouch writes the state fields back to the
document as the replication progresses, matching CouchDB's
self-updating semantics.

**`_security` envelope.** `{ "admins": { "names": [...], "roles": [...] }, "members": { "names": [...], "roles": [...] } }`.

**`_local/` checkpoint envelope.** `_local/<id>` documents store
replication state with shape `{ "_id": "_local/<id>", "_rev": "N-hex", "session_id": "...", "source_last_seq": N, "history": [ ... ] }`.
Unlike regular documents, `_local/` docs do NOT participate in the
changes feed, do NOT appear in `_all_docs`, and are NOT replicated.

**Attachment metadata envelope.** Attachment metadata shape:
`{ "content_type": "string", "revpos": N, "digest": "md5-<base64>", "length": N, "encoding": "gzip" | absent, "encoded_length": N, "stub": true, "data": "<base64>" | absent, "follows": true | absent }`.

### Error Slug Table

The `error` slug values IRISCouch emits are a committed subset of
CouchDB's published slugs. The differential HTTP harness enforces
slug parity on every release:

| Slug | Status | Used when |
|---|---|---|
| `not_found` | 404 | Missing database, document, attachment, or design doc |
| `conflict` | 409 | Stale `_rev` on update, concurrent update conflict |
| `unauthorized` | 401 | Authentication missing or invalid |
| `forbidden` | 403 | Authenticated but not authorized |
| `bad_request` | 400 | Malformed JSON, invalid selector, bad `_rev` format |
| `doc_validation` | 400 | Reserved-field misuse, `validate_doc_update` rejection |
| `missing_stub` | 412 | Attachment stub references a revision that does not exist |
| `invalid_design_doc` | 400 | Design document schema violation |
| `file_exists` | 412 | PUT `/{db}` when database already exists |
| `illegal_database_name` | 400 | Database name contains disallowed characters |
| `internal_server_error` | 500 | Unhandled failure; accompanied by logged stack trace |
| `not_implemented` | 501 | Endpoint recognized but backend not enabled (JSRuntime, `$text`) |
| `partial` | 202 | Some items in a bulk write failed |

New slugs may be added as the conformance harness catches them; no
published slug will be renamed or removed.

### Rate Limits

**No first-party rate limiting at MVP.** IRISCouch delegates rate
limiting to the IRIS web stack: `%Service_WebGateway` connection
limits, CSP Gateway connection pooling, and operator-configured front
proxies (nginx, Apache mod_ratelimit, etc.). This matches CouchDB's
own posture — CouchDB has no built-in per-client rate limiter either.

**What IRISCouch does provide** is observability into request load
via the Prometheus/OpenTelemetry metrics endpoint (request counts
per endpoint class, latencies, error rates). Operators building
rate limits on top of IRISCouch can alert on these metrics rather
than enforce limits in the product.

**Out of scope:** token-bucket per-user limiting, per-database write
quotas, per-attachment bandwidth caps. Adopters needing these deploy
a front proxy.

### API Documentation

**Source of truth.** The CouchDB 3.x HTTP API reference at
`docs.couchdb.org/en/stable/api/` is the canonical specification
IRISCouch conforms to. IRISCouch does not publish a parallel
"IRISCouch API reference" that could drift from the upstream spec.

**What IRISCouch ships instead:**

1. **Compatibility matrix** — live document listing every endpoint
   from CouchDB 3.x's API inventory with columns for: *supported*,
   *supported with caveat*, *returns 501 in default config*, *out of
   scope with reason*. Updated on every release. Location:
   `docs/compatibility-matrix.md`, linked from the repository README.
2. **Deviation log** — list of any observable behaviors where
   IRISCouch intentionally or unavoidably differs from Apache CouchDB
   (e.g., internal rev hash algorithm, sequence counter representation,
   log format). Short, specific, citable. Location:
   `docs/deviations.md`.
3. **ObjectScript class documentation** — generated from `///` doc
   comments on every public class via the IRIS doc tooling. Internal
   development reference only, not part of the external API contract.

**What IRISCouch deliberately does NOT ship:**

- A full OpenAPI/Swagger specification. CouchDB's HTTP API has
  dynamic path components (`/{db}/{docid}`) and polymorphic response
  shapes (Mango `_find` vs. document GET) that resist clean OpenAPI
  modeling. Future work if demand materializes; not committed.
- Auto-generated client SDK wrappers. Every existing CouchDB SDK is
  already an IRISCouch SDK by construction.

### Language Support Matrix

**Server implementation language:** InterSystems ObjectScript,
exclusively. Per the project's original kickoff prompt: the core
server, HTTP API layer, storage, revision/conflict engine, changes
engine, replication engine, attachment handling, and security are
implemented in ObjectScript. External languages are allowed **only**
for (a) operator-enabled JSRuntime backends executing user-supplied
design-doc JavaScript, (b) test harness and benchmarking scripts.

**Admin UI implementation language:** TypeScript / Angular, compiled
to a static HTML/JS/CSS bundle shipped inside the ObjectScript
package and served as static assets from the IRIS webapp. Angular
build toolchain is required only at IRISCouch development time, not
at adopter install time. See § Project-Type Overview →
"Implementation language split" for the binding rule that prevents
drift between the two language layers.

**Supported client libraries (smoke-tested matrix, published as part
of the Getting Started docs):**

| Client | Language | Version | Verification |
|---|---|---|---|
| PouchDB | JavaScript (browser + Node) | 9.x | Replication conformance suite |
| Apache CouchDB replicator | Erlang (peer CouchDB process) | 3.3.3 + 3.5.x | Differential harness |
| `nano` | Node.js | 10.x | Smoke test suite |
| `@cloudant/cloudant` | Node.js | 5.x | Smoke test suite |
| Fauxton | JavaScript (browser SPA) | Currently-shipping build | Manual walkthrough per release |

**Not smoke-tested but expected to work** (because they implement
the CouchDB wire protocol without IRISCouch-specific assumptions):
older PouchDB versions, `python-cloudant`, `cloudant-java`,
`couchdb4j`, `sofa` (Java), `couchdb-go`. These clients are reported
as "community-compatible" in the matrix — they may work, they are
not gated, and bug reports are accepted.

**Explicitly not supported:** Couchbase SDKs (Couchbase is not
wire-compatible with CouchDB; its SDKs do not speak the CouchDB HTTP
API).

### Installation Methods

**Primary:** ZPM / IPM — InterSystems Package Manager.
`zpm "install iris-couch"` is the committed single-command install
path. The ZPM module manifest declares no non-IRIS dependencies.

**Repository:** `github.com/<org>/iris-couch` (repository name
remains `iris-couch` hyphenated for GitHub URL convention; product
name is IRISCouch with no space or hyphen; ObjectScript package
prefix is `IRISCouch.*`).

**License:** Apache 2.0 — matches CouchDB and InterSystems community
convention.

**Manual install fallback:** clone the repository, run
`$System.OBJ.ImportDir(".", "src/**", "ck", .errors, 1)` from an
ObjectScript session, create a webapp at the desired mount point
via the IRIS Management Portal or `Security.Applications`.
Documented as a fallback for development-time workflows and isolated
install environments.

**NOT a committed install channel:** InterSystems Open Exchange.
The brief explicitly pauses community-building pushes, including
Open Exchange submission. An Open Exchange listing may be published
later but is not MVP scope.

**NOT a committed install channel:** Docker Hub image, Helm chart,
operator-managed Kubernetes deployment. IRISCouch runs inside an
existing IRIS instance; containerization is the adopter's deployment
decision, not an IRISCouch deliverable.

### API Surface Stability and Versioning

**Two version anchors operate independently:**

1. **CouchDB 3.x wire version** — IRISCouch anchors to CouchDB 3.3.3
   as the primary conformance baseline through β, adding 3.5.x to
   the conformance harness at γ. CouchDB 4.x wire protocol is
   tracked but not targeted (listed in Product Scope § Growth).
   The wire version is the product's external compatibility
   commitment.
2. **IRISCouch release version** — SemVer (MAJOR.MINOR.PATCH) with
   α-tagged pre-releases (0.x.y-alpha.N), β pre-releases
   (0.x.y-beta.N), and 1.0.0 at γ Milestone completion. SemVer
   applies to the ObjectScript package, not the wire protocol.

**Backward compatibility commitment.**
- IRISCouch's **HTTP wire contract** is stable for the duration a
  given CouchDB 3.x version is supported upstream (Apache). A wire
  contract change would be a breaking change to every adopter's
  client code and will not happen within a 3.x anchor.
- IRISCouch's **ObjectScript public API** (the classes and methods
  exposed to adopters extending IRISCouch, e.g. for custom JSRuntime
  backends or metric exporters) follows SemVer. Breaking changes
  require a major version bump and a deprecation window of at least
  one minor version.
- IRISCouch's **private implementation** (internal helper classes,
  global storage layout, SQL projection class structure) is
  explicitly NOT part of any backward compatibility commitment.
  Storage layout may change between releases; adopters relying on
  direct global access are unsupported.

### Code Examples

The following examples ship in the repository and are covered by
the compatibility matrix verification:

1. **`examples/hello-document.md`** — the "Hello, document"
   quick-start from Devi's Journey 5: ZPM install, create database,
   create document, update with optimistic concurrency, handle 409
   conflict. ≤20 minutes to complete.
2. **`examples/pouchdb-sync/`** — a minimal HTML page running
   PouchDB in the browser that replicates bidirectionally against
   a local IRISCouch instance. Tested against PouchDB 9.x.
3. **`examples/replicate-from-couchdb.sh`** — a shell script using
   the Apache CouchDB replicator to replicate a database from a
   running Apache CouchDB into IRISCouch. Tested against CouchDB
   3.3.3 and 3.5.x.
4. **`examples/mango-query.md`** — worked example creating a Mango
   index, running a `_find` query, reading the `_explain` output,
   and interpreting the plan.
5. **`examples/attachment-upload.md`** — worked example of
   multipart/related document+attachment PUT and streaming GET.
6. **`examples/jsruntime-subprocess-node/`** — operator-level
   walkthrough for enabling `JSRuntime.Subprocess` with a local
   Node.js install, including the couchjs line protocol handshake.
   Covers the β enablement path.

Examples are verified by CI on every release. A broken example is
a release blocker.

### Migration Guide

**A single published migration playbook** is a committed PRD
deliverable (wired to Journey 1 — Maya — and Journey 3 — the
author's customer zero migration). Location: `docs/migration.md`.
The playbook covers:

1. **Pre-migration checklist** — IRIS version, namespace, mirroring,
   auth stack, what to snapshot before starting.
2. **Installing IRISCouch** into an existing IRIS deployment.
3. **Replicating in** one database at a time from the source
   Apache CouchDB using the CouchDB replicator.
4. **Validating** — `_all_docs` diff, `_changes` window comparison,
   Mango result parity, attachment digest round-trip, `_security`
   document parity.
5. **Dual-write parallel operation** (optional validation period).
6. **Cutting over** application clients.
7. **Draining and retiring** the source CouchDB process.
8. **Rollback** — symmetric: replicate IRISCouch → fresh CouchDB,
   cut clients back. No point of no return.
9. **Post-migration** — metric comparison, audit trail verification,
   operational runbook handover.

The playbook is validated against customer zero's three-database
migration before β. Any discovery during customer zero that makes a
step harder than the playbook implies is a playbook update and a
code update, not just a documentation correction.

## Project Scoping & Phased Development Strategy

§ Product Scope and § API Backend + Developer Tool — Specific
Requirements together enumerate *what* is in MVP. This section
provides **strategic framing** for *why* those scope decisions
are the right ones, what each milestone proves, and what risks
are being deliberately accepted or mitigated. It does not restate
the feature list.

### MVP Strategy & Philosophy

IRISCouch's MVP is a **hybrid problem-solving + platform MVP**, not a
revenue MVP, not a market-validation MVP, not a user-acquisition MVP.

- **Problem-solving dimension**: the MVP is the minimum scope required
  to retire customer zero's three production CouchDB databases onto
  IRIS and keep their existing clients running unchanged. If that
  works, the original problem has been solved.
- **Platform dimension**: the MVP is simultaneously the minimum scope
  required to demonstrate that *any* wire-compatible document store
  can be built on IRIS using the globals-for-writes + synchronous SQL
  projection pattern. "Platform" here means the architectural pattern
  is proven out, not that IRISCouch itself becomes a platform for
  external plugins or third-party builds.
- **Not a revenue MVP**: IRISCouch has no paid tiers, no managed
  service, no enterprise support pipeline, no ARR target. The
  existence of "business success metrics" in § Success Criteria has
  been redefined as project-health and adoption signals, not
  commercial traction. MVP completion does not unlock a commercial
  milestone.
- **Not a market-validation MVP**: the consolidation thesis (teams
  pay a dual-database tax they'd rather eliminate) was pre-validated
  by the 2024 Apache CouchDB user survey and by customer zero's own
  pain. The MVP does not exist to test whether people want this; it
  exists to deliver it.
- **Not a user-acquisition MVP**: community-building pushes (Open
  Exchange, InterSystems Developer Community, CouchDB mailing list
  announcements) are explicitly paused during the MVP window. The
  primary adoption metric is correctness against customer zero's
  workload, not installed base.

**Philosophy in one sentence.** *The MVP is done when customer zero
is served and the wire-compatibility claim is verifiable — not when
a user count is reached, not when a revenue target is hit, and not
when a calendar date arrives.*

**MVP approach label:** `problem-solving MVP` with a `platform`
secondary dimension.

### Resource Profile and Cadence

- **Team size**: one developer working with AI coding agents. No
  hiring plan. No contractor budget. The single developer is also
  customer zero.
- **Deadline**: none. The project is quality-gated, not
  calendar-gated. Adopters who face migration deadlines (e.g.,
  RHEL 9 / SpiderMonkey pressure) carry those deadlines on their own
  calendars; IRISCouch's job is to be correct and ready when they
  arrive, not to rush.
- **Continuous regression mechanism**: customer zero's own workload.
  Every release is exercised against the three production CouchDB
  databases before any public tag.
- **Bus factor honesty**: 1. If the single developer steps away, the
  final tagged release remains forkable, documented, and Apache 2.0
  licensed. This is acknowledged as a risk (see § Risk-Based Scoping
  below), not hidden.

### Strategic Role of Each Milestone Within MVP

The milestones α, β, and γ are **progress checkpoints within a
single committed MVP**, not a staged MVP / growth / vision split.
Their strategic roles are distinct:

**Milestone α — Public Alpha: prove wire-compat credibility.**
- Unlocks: the public conversation. IRISCouch stops being a
  private project and becomes something adopters can evaluate.
- De-risks: the replication protocol (the project's highest-risk
  correctness surface), the CQRS hybrid at write path, the
  zero-dependency install story.
- Proves: "this thing is wire-compatible enough that PouchDB and
  the CouchDB replicator cannot tell the difference."
- Delivers the first *public* version of every PRD-committed
  documentation artifact: README, Getting Started walkthrough,
  initial compatibility matrix, deviation log.
- What α does NOT yet prove: customer zero migration (β), feature
  completeness (γ), or streaming feeds (γ).

**Milestone β — Customer Zero Complete: prove the origin story.**
- Unlocks: the strongest credibility signal the project will ever
  have. The author's blog post "Retiring a production CouchDB with
  IRISCouch" replaces generic claims with a specific, audited,
  real-world migration.
- De-risks: `JSRuntime.Subprocess` (production-complete enough to
  serve real map-reduce views and filter functions), the auth
  surface (HMAC cookie parity with real CouchDB `_session` clients),
  and the migration playbook (validated by actual execution).
- Proves: "the dogfooding claim is not marketing." Customer zero is
  served. The standalone Apache CouchDB process is retired.
- β is the moment the project graduates from "it might work" to
  "it works in production for at least one real workload."

**Milestone γ — MVP Feature-Complete: prove the inventory.**
- Unlocks: the 1.0 tag. IRISCouch leaves alpha.
- De-risks: ECP distributed-cache clustering safety for multi-server
  IRIS, streaming feed support via `%Net.TCPServer` (bypassing the
  CSP Gateway buffering limitation), and conformance against both
  CouchDB 3.3.3 and 3.5.x.
- Proves: every non-deprecated item in the CouchDB 3.x feature
  inventory is either delivered or explicitly documented as out of
  scope with a reason. No silent gaps.
- γ is the moment the published compatibility matrix stops needing
  "coming in a future release" rows and the project can be
  recommended to non-customer-zero adopters without asterisks.

**Sequencing rule**: α must ship before β (customer zero cannot
migrate onto pre-α code), but β and γ can run in parallel. γ work is
not gated on β completion — e.g., the `%Net.TCPServer` streaming
listener can be built while customer zero is migrating.

### Must-Haves vs. Could-Be-Deferred-Within-MVP

The three milestones commit to every feature in § Product Scope, but
within that commitment there are lines where "minimum viable"
diverges from "polished." This section captures those deferral
decisions explicitly so later PR reviews do not re-litigate them.

| Capability | Minimum viable at α | Polished by |
|---|---|---|
| Admin UI database lifecycle | Create, list, drop, per-DB info | γ (stats panel) |
| Admin UI document browsing | List (paginated), detail view | β (revision history view) |
| Admin UI design docs | Read-only view | β (create/edit/delete) |
| Admin UI `_security` | Read-only display | β (admin/member edit) |
| Getting Started docs | Install + first document + first PouchDB sync | β (+ JSRuntime enablement walkthrough) |
| Migration playbook | Rough draft based on internal dry run | β (validated against customer zero) |
| Troubleshooting runbook | Top 5 incident classes covered | γ (expanded per customer zero + external adopter findings) |
| Compatibility matrix | Every MVP endpoint row filled in | γ (+ community-compatible clients reported) |
| Observability scrape endpoint | Core counters and histograms | γ (+ alerting rule examples) |
| JSRuntime.Subprocess | Not required; 501 default is shipped | β (production-complete for customer zero) |
| JSRuntime.Python | Not required; deferred | Not committed within MVP; secondary option only |

**Items that CANNOT be deferred or manualized even at α**
(non-negotiable even in "minimum viable" form):

- Wire-protocol byte-compat on the conformance subset — no "we'll
  tighten it later" on status codes, JSON error envelopes, sequence
  tokens, checkpoint shapes, or `_bulk_get` responses.
- Replication correctness — no rev-tree corruption class of bug
  ships, ever. This is the unshippable-defect bar defined in
  § Success Criteria.
- The three-layer conformance suite — CouchDB JS tests, PouchDB
  replication conformance, differential HTTP harness — must be
  running and green on day one of α, not "coming in a point release."
- Zero-dependency install — the ZPM `install iris-couch` path on a
  fresh IRIS must work at α. A manual-only install at α would break
  Devi's Journey 5 (60-minute evaluation) and invalidate the
  "category of one" positioning.
- `%SYS.Audit` events for document writes and security events — a
  gap here would break adopters' existing HealthShare audit
  pipelines and violate the healthcare-adjacency commitment.
- `_users`/`_session`/`_security` at β — these are not optional;
  they are required for customer zero to serve authenticated clients
  after cutover.

### Risk-Based Scoping

Scope decisions are driven by explicit risk accounting. Each risk
below is paired with the mitigation that shapes what's in or out of
MVP.

#### Technical Risks

**R1. Replication protocol edge cases not covered by research.**
*Severity*: high. A missed edge case that causes silent conflict
corruption is the project's defining unshippable-defect class.
*Mitigation*: three-layer conformance suite on every release;
customer zero's real workload as continuous regression; any bug
found produces a new regression test before the fix ships. Accepting
this risk means α cannot be date-driven — the conformance suite
must be green.

**R2. CSP Gateway buffering behavior for streaming feeds.**
*Severity*: medium. Known and confirmed by live spike: the gateway
buffers the full response before forwarding, making
`feed=continuous` and `feed=eventsource` unusable via the standard
deployment path.
*Mitigation*: explicit scope decision — these feed modes return 501
in α and β; a standalone `%Net.TCPServer` listener on a separate
port delivers them at γ. The PouchDB and CouchDB replicator default
to longpoll, so replication correctness is unaffected.

**R3. Mango selector edge cases in IRIS SQL translation.**
*Severity*: medium. `$elemMatch`, `$allMatch`, and `$regex` on JSON
arrays are known-hard in IRIS SQL's JSON index support.
*Mitigation*: fallback scan path for selectors the translator
cannot efficiently plan; documented in the deviation log as a
performance caveat rather than a correctness gap. Customer zero's
queries exercise the common selectors; rare operators get the
fallback.

**R4. Synchronous SQL projection regression at scale.**
*Severity*: medium to low. The synchronous-maintenance guarantee is
novel and has not yet been benchmarked beyond customer zero's
envelope (~10K documents, ~500 MB).
*Mitigation*: post-α benchmarking establishes the scaling ceiling
empirically; async projection with a bounded lag window is a
documented fallback behind a feature flag. Until benchmarking says
otherwise, synchronous-only is the default and the guarantee.

**R5. `JSRuntime.Subprocess` IPC complexity for customer zero's
views.** *Severity*: medium. The couchjs line protocol is
documented but not trivial; subprocess lifetime management
(kill-on-idle, restart-on-crash, timeout enforcement) is new
surface.
*Mitigation*: narrow the `JSRuntime.Subprocess` MVP target to
exactly the function classes customer zero uses (map-reduce views
and filter functions, no `validate_doc_update` at β if customer
zero does not use it); expand to full JS coverage as part of β
stabilization.

**R6. `AuthSession` cookie HMAC byte-compat with existing CouchDB
clients.** *Severity*: low. Source-spike deferred to Phase 6.
*Mitigation*: if the HMAC algorithm turns out to be harder than a
day's work, ship β with the cookie clients have to re-login once
(acceptable for customer zero; acceptable for adopters if
documented in the migration playbook).

#### Market Risks

**R7. N=1 adopter (customer zero) is a very thin success signal.**
*Severity*: medium for *credibility*, low for *project viability*
(customer zero is the forcing function, not a growth metric).
*Mitigation*: Devi's Journey 5 defines the evaluation surface for
a second adopter; the soft metric of ≥1 external adopter by α+12
months is tracked but not gating. If no external adopter
materializes, IRISCouch still serves its original purpose.

**R8. "Default answer for offline-first on IRIS" framing requires
some adoption to be true.**
*Severity*: medium for the vision statement, not for the MVP.
*Mitigation*: the MVP commitment does not depend on the vision
being realized. If IRISCouch only ever serves customer zero and
one or two other adopters, the product still works, the code is
still maintained, and the brief's "quality-gated, not
calendar-gated" posture is preserved. Vision-level aspirations are
not milestone gates.

**R9. Apache CouchDB 4.x changes the wire contract in a way that
forces IRISCouch to track or fall behind.**
*Severity*: medium, delayed.
*Mitigation*: anchor explicitly to CouchDB 3.x stable for the MVP;
4.x is tracked but not targeted (listed in § Product Scope →
Growth). If 4.x ships with breaking wire changes, a separate
follow-on project can track it after IRISCouch 1.0.

#### Resource Risks

**R10. Single-developer bus factor.**
*Severity*: high for long-term maintenance, low for short-term
shipping (the single developer is the project's origin).
*Mitigation*: Apache 2.0 license means any tagged release is
forkable; customer zero's migration creates a real operational
constraint that forces disciplined documentation; AI coding agents
extend effective capacity at each step. If the project is ever
shelved, the final release remains forkable and documented.

**R11. "No deadline" creates a risk of never shipping.**
*Severity*: low (customer zero's RHEL 9 / migration pressure
imposes an implicit deadline on the author), but real.
*Mitigation*: customer zero is the forcing function — if the
author's own CouchDB host needs to retire, β must happen.
Quality-gated does not mean indefinitely deferred; it means
"correctness before calendar, but customer zero's calendar is real."

**R12. "Fewer resources than planned" scenario.**
*Severity*: not applicable. The planned resources are already the
floor: one developer, AI coding agents, no deadline. There is no
"scale down" scenario because there is no "scale up" baseline to
scale down from.

### Scope Non-Negotiables

Some scope decisions are not up for revision and are listed here so
future PRs and discussions do not re-litigate them. Every item
below has been locked by explicit decision in prior PRD steps or in
the product brief:

1. **ObjectScript is the only backend implementation language**
   (Step 7 — Implementation language split).
2. **Angular is the only admin UI implementation language**
   (Step 4 — Admin UI, Step 7 — Implementation language split).
3. **Wire-compatibility is measured, not asserted** — three-layer
   conformance suite gates every release (Step 3 — Success
   Criteria).
4. **`^IRISCouch.*` globals and `IRISCouch.*` classes** are the
   committed naming convention.
5. **No commercial productization** — no paid tiers, no managed
   service, no enterprise support contracts (Product Brief,
   Step 2c — Executive Summary).
6. **Zero mandatory external dependencies at MVP default**
   (Step 2c — Executive Summary, Step 6 — Innovation).
7. **JavaScript runtime is pluggable and operator-selected**
   (Step 6 — Innovation § 2, Product Scope § MVP).
8. **All of Phases 0–7 are MVP scope** — α, β, γ are checkpoints
   within MVP, not a staged split (Step 3 — Product Scope framing
   note).
9. **Customer zero is the forcing function and the continuous
   regression suite** (Product Brief, Step 3 — Success Criteria,
   Step 4 — Journey 3).

## Functional Requirements

The preceding sections have defined *what kind* of product
IRISCouch is, *what quality bars* it must clear, and *what
strategic scope* it commits to. This section crystallizes all of
that into a **capability contract** for IRISCouch. Every
downstream artifact — architecture, epic breakdown, UX for the
admin UI, acceptance tests — must trace back to one or more
requirements below. A capability not listed here will not exist
in the final product unless it is explicitly added to this
section in a subsequent PRD revision.

Requirements are stated as testable capabilities (WHAT) rather than
implementation approaches (HOW). Quality attributes (performance,
reliability, security posture) live in § Non-Functional Requirements.
Actors are: **client** (any HTTP client speaking the CouchDB wire
protocol), **operator** (the IRIS administrator installing or
configuring IRISCouch), and **system** (IRISCouch itself).

### Database Lifecycle

- **FR1**: Operators and clients can create a database via HTTP
  PUT on the database path.
- **FR2**: Operators and clients can delete a database via HTTP
  DELETE on the database path.
- **FR3**: Clients can list all databases visible to their
  credentials via `GET /_all_dbs`.
- **FR4**: Clients can retrieve per-database metadata (document
  count, update sequence, disk size, purge sequence, etc.) via
  `GET /{db}`.
- **FR5**: Operators can configure a per-database revision
  retention limit via `PUT /{db}/_revs_limit`.
- **FR6**: Operators can trigger database compaction via
  `POST /{db}/_compact`.
- **FR7**: Clients can request a full commit via
  `POST /{db}/_ensure_full_commit`.
- **FR8**: The system returns `201 Created` on successful database
  creation and `412 Precondition Failed` with error slug
  `file_exists` if the database already exists.

### Document Storage, Revisions & Conflict Model

- **FR9**: Clients can create a document with a server-generated
  UUID via `POST /{db}`.
- **FR10**: Clients can create or update a document with a
  client-specified ID via `PUT /{db}/{docid}`.
- **FR11**: Clients can retrieve a document by ID via
  `GET /{db}/{docid}`, with optional `?rev=`, `?revs=`,
  `?revs_info=`, `?conflicts=`, and `?local_seq=` query parameters.
- **FR12**: Clients can delete a document via
  `DELETE /{db}/{docid}?rev=N-hex` or `PUT` with `_deleted: true`,
  producing a tombstone revision.
- **FR13**: The system enforces optimistic concurrency: updates
  with stale `_rev` values are rejected with `409 Conflict` and
  error slug `conflict`.
- **FR14**: The system detects and preserves concurrent-update
  conflicts, storing all conflicting revisions and exposing them
  via the `_conflicts` field when queried with `?conflicts=true`.
- **FR15**: The system computes the winning revision for a document
  deterministically using CouchDB's published winning-rev algorithm.
- **FR16**: Clients can submit multiple document writes in a single
  request via `POST /{db}/_bulk_docs`.
- **FR17**: Clients can submit replication-format writes via
  `POST /{db}/_bulk_docs` with `new_edits=false`, preserving source
  revision IDs without generating new ones.
- **FR18**: Clients can retrieve multiple documents by ID in a
  single request via `POST /{db}/_bulk_get`, including specific
  revisions and revision history.
- **FR19**: Clients can retrieve a document's revision tree and
  open (leaf) revisions via `?open_revs=all` or
  `?open_revs=["N-hex",...]`.
- **FR20**: The system rejects user-created top-level fields
  beginning with underscore (except the documented metadata set)
  with `400 Bad Request` and error slug `doc_validation`.

### Document Listing & Changes Feed

- **FR21**: Clients can list all documents in a database via
  `GET /{db}/_all_docs` with pagination (`limit`, `skip`), key-range
  filtering (`startkey`, `endkey`), and included-docs
  (`include_docs=true`).
- **FR22**: Clients can list specific documents in a database via
  `POST /{db}/_all_docs` with a `keys` array.
- **FR23**: Clients can subscribe to a database's changes feed in
  `feed=normal` mode (single response with the current change
  snapshot).
- **FR24**: Clients can subscribe to a database's changes feed in
  `feed=longpoll` mode (request blocks until a new change or
  timeout).
- **FR25**: Clients can filter a changes feed by specific document
  IDs via the `_doc_ids` built-in filter.
- **FR26**: Clients can filter a changes feed by Mango selector
  via the `_selector` built-in filter.
- **FR27**: Clients can filter a changes feed to design documents
  only via the `_design` built-in filter.
- **FR28**: Clients can subscribe to a changes feed in
  `feed=continuous` mode (delivered via separate TCP listener at γ).
- **FR29**: Clients can subscribe to a changes feed in
  `feed=eventsource` mode (delivered via separate TCP listener at γ).
- **FR30**: The system assigns a monotonically increasing sequence
  number to every change, atomically per database.

### Attachment Handling

- **FR31**: Clients can attach binary content to a document inline
  via base64-encoded `_attachments.<name>.data` in a JSON body.
- **FR32**: Clients can attach binary content via `multipart/related`
  upload in a single `PUT /{db}/{docid}` request.
- **FR33**: Clients can attach binary content via standalone
  `PUT /{db}/{docid}/{attname}?rev=N-hex`.
- **FR34**: Clients can retrieve an attachment's raw bytes via
  `GET /{db}/{docid}/{attname}`.
- **FR35**: Clients can retrieve a document with selected
  attachments via `multipart/mixed` response when requesting with
  `Accept: multipart/mixed` and `?open_revs=...`.
- **FR36**: Clients can request attachment retrieval only for
  revisions newer than a given rev via `?atts_since=["N-hex",...]`.
- **FR37**: Clients can request attachments as stubs only (metadata
  without content) via `?attachments=false` (default).
- **FR38**: Clients can request attachment content inclusion via
  `?attachments=true`.
- **FR39**: The system stores attachment content as binary streams
  without buffering entire attachment bodies in process memory.
- **FR40**: The system computes and stores MD5 digests for every
  attachment; digests round-trip through replication unchanged.

### Mango Query & Indexing

- **FR41**: Clients can query documents via `POST /{db}/_find` with
  a Mango selector, including `fields`, `sort`, `limit`, `skip`,
  `use_index`, and `r` options.
- **FR42**: Clients can create Mango indexes of type `json` on
  arbitrary document fields via `POST /{db}/_index`.
- **FR43**: Clients can list existing Mango indexes via
  `GET /{db}/_index`.
- **FR44**: Clients can delete a Mango index via
  `DELETE /{db}/_index/{ddoc}/{type}/{name}`.
- **FR45**: Clients can inspect the selected query plan for a Mango
  query via `POST /{db}/_explain`.
- **FR46**: Clients can create Mango indexes that match only a
  subset of documents via `partial_filter_selector`.
- **FR47**: The system supports Mango selector operators:
  equality, `$gt`, `$gte`, `$lt`, `$lte`, `$ne`, `$in`, `$nin`,
  `$exists`, `$type`, `$and`, `$or`, `$nor`, `$not`, `$regex`,
  `$elemMatch`, `$allMatch`.
- **FR48**: The system falls back to a full scan when a selector
  cannot be planned against an existing index, returning correct
  results with reduced performance.
- **FR49**: Clients can query design-document views via
  `GET /{db}/_design/{ddoc}/_view/{view}` when a JSRuntime backend
  is enabled.
- **FR50**: The system supports built-in reduces `_sum`, `_count`,
  `_stats`, and `_approx_count_distinct` on view results.

### Replication Protocol

- **FR51**: Clients can retrieve revision difference sets via
  `POST /{db}/_revs_diff` to determine which revisions a target
  already holds.
- **FR52**: Clients can retrieve multiple documents with specific
  revisions in bulk via `POST /{db}/_bulk_get` with
  `revs=true&attachments=true`.
- **FR53**: Clients can persist and retrieve replication
  checkpoints via `PUT /{db}/_local/{id}` and
  `GET /{db}/_local/{id}`.
- **FR54**: The system excludes `_local/` documents from the
  changes feed, from `_all_docs`, and from replication to peers.
- **FR55**: Operators can configure continuous replication jobs via
  documents in the `_replicator` database.
- **FR56**: The system writes replication state updates
  (`_replication_id`, `_replication_state`, `_replication_state_time`,
  `_replication_stats`) back to the `_replicator` document as
  replication progresses.
- **FR57**: The system computes deterministic `replication_id`
  values that survive process restart and resume replication from
  the last checkpoint.
- **FR58**: The system performs bidirectional replication against a
  real Apache CouchDB 3.x peer using the CouchDB replication
  protocol, including `_revs_diff`, `_bulk_get`, `open_revs`, and
  `_local/` checkpoints.
- **FR59**: The system generates revision hashes deterministically
  from document content using an algorithm that is
  replication-protocol sufficient (JSON-canonical MD5 of the
  revision tuple), not byte-identical to CouchDB's Erlang ETF hash.

### Authentication, Authorization & Security

- **FR60**: Clients can authenticate via HTTP Basic auth with
  credentials validated against the IRIS user directory.
- **FR61**: Clients can authenticate via `POST /_session` and
  receive an HMAC-signed `AuthSession` cookie valid for subsequent
  requests.
- **FR62**: Clients can retrieve their current session information
  via `GET /_session`.
- **FR63**: Clients can log out by `DELETE /_session`, invalidating
  the current session cookie.
- **FR64**: Clients can authenticate via JWT bearer tokens against
  operator-configured issuers and public keys.
- **FR65**: Clients can authenticate via proxy auth headers
  (`X-Auth-CouchDB-UserName`, `X-Auth-CouchDB-Roles`,
  `X-Auth-CouchDB-Token`) from trusted upstreams configured with a
  shared secret.
- **FR66**: Operators can manage users via documents in the
  `_users` database, which synchronize one-to-one to IRIS user
  records.
- **FR67**: The system hashes `_users` passwords using PBKDF2 via
  IRIS primitives and stores hashed credentials in the IRIS user
  record, not in the `_users` document body.
- **FR68**: Operators can set per-database admin and member lists
  (names and roles) via `PUT /{db}/_security`.
- **FR69**: The system enforces `_security` admin/member access
  restrictions on every request before document logic executes.
- **FR70**: The system emits an HTTP `401 Unauthorized` with error
  slug `unauthorized` when authentication is missing or invalid.
- **FR71**: The system emits an HTTP `403 Forbidden` with error
  slug `forbidden` when authentication succeeds but authorization
  fails.

### User JavaScript Execution (Pluggable JSRuntime)

- **FR72**: Operators can select the JSRuntime backend (`None`,
  `Subprocess`, or `Python`) at IRISCouch configuration time.
- **FR73**: The default JSRuntime backend at installation is `None`.
- **FR74**: The system accepts, stores, and replicates design
  documents regardless of the selected JSRuntime backend.
- **FR75**: With `JSRuntime.None`, any request that would require
  executing user JavaScript returns `501 Not Implemented` with
  error slug `not_implemented` and a reason string that names the
  subsystem and points at enablement documentation.
- **FR76**: With `JSRuntime.Subprocess` enabled, the system executes
  user-supplied map-reduce view functions (`map` and `reduce`)
  against Node, Bun, Deno, or couchjs via `$ZF(-1)` subprocess
  invocation using the couchjs line protocol.
- **FR77**: With `JSRuntime.Subprocess` enabled, the system executes
  user-supplied `validate_doc_update` hook functions.
- **FR78**: With `JSRuntime.Subprocess` enabled, the system executes
  user-supplied `_changes` filter functions.
- **FR79**: With `JSRuntime.Python` enabled, the system executes the
  same user JavaScript functions via an embedded Python runtime
  with a QuickJS binding.
- **FR80**: The system builds and maintains incremental view
  indexes when a JSRuntime backend is enabled, updating indexes
  on document write rather than on query.
- **FR81**: The system serves view query results with ETag-based
  response caching so unchanged query results return `304 Not
  Modified`.
- **FR82**: The system enforces per-invocation timeouts and
  memory-pressure-driven restarts on JSRuntime subprocesses so a
  misbehaving user function cannot hang the server.

### Administration UI

- **FR83** `[α]`: Operators can access a built-in administration UI at
  the webapp's `_utils` path (default `/iris-couch/_utils/`)
  without installing Fauxton or any separate tooling.
- **FR84** `[α]`: The administration UI is a TypeScript + Angular
  single-page application served as static assets from the
  IRISCouch webapp.
- **FR85** `[α]`: Operators can list all databases visible to their
  credentials via the admin UI.
- **FR86** `[α]`: Operators can create a database via the admin UI.
- **FR87** `[α]`: Operators can delete a database via the admin UI.
- **FR88** `[α]`: Operators can view per-database metadata (document
  count, update sequence, disk size) via the admin UI.
- **FR89** `[α]`: Operators can browse documents in a database with
  pagination via the admin UI.
- **FR90** `[α]`: Operators can view individual document details
  (body + metadata + `_rev`) via the admin UI.
- **FR91** `[α]`: Operators can view design documents stored in a
  database via the admin UI (read-only).
- **FR92** `[β]`: Operators can create, edit, and delete design
  documents via the admin UI.
- **FR93** `[α]`: Operators can view `_security` admin/member
  configuration for a database via the admin UI (read-only).
- **FR94** `[β]`: Operators can edit `_security` admin/member
  configuration via the admin UI.
- **FR95** `[γ]`: Operators can view a document's revision history via
  the admin UI.

### Observability, Audit & Operations

- **FR96**: Operators can scrape Prometheus / OpenTelemetry metrics
  from a dedicated endpoint, exposing at minimum: request counts
  per endpoint class, request latency histograms, replication
  throughput (documents/sec and bytes/sec), `_changes` feed lag,
  Mango index hit rate, and per-status-code error counters.
- **FR97**: The system emits a structured `%SYS.Audit` event for
  every document write (create, update, delete) including document
  ID, revision, database, user identity, and timestamp.
- **FR98**: The system emits a structured `%SYS.Audit` event for
  every authentication attempt (success and failure).
- **FR99**: The system emits a structured `%SYS.Audit` event for
  every `_security` configuration change.
- **FR100**: The system emits a structured `%SYS.Audit` event for
  every `_users` database write.
- **FR101**: The system emits a structured `%SYS.Audit` event for
  replication session start and completion, including source,
  target, sequence count processed, and byte count transferred.
- **FR102**: All IRISCouch state (document bodies, revision trees,
  changes feed, attachments, Mango projections, `_local/`
  checkpoints, `_users` records) lives within the IRIS namespace
  the webapp is mounted in, so standard IRIS mirroring, backup,
  and journal replay cover it automatically.
- **FR103**: Replication checkpoints survive a hard process kill
  and IRIS restart with correct sequence continuity; a resumed
  replication picks up where the killed replication left off.
- **FR104**: After an IRIS mirror failover, replication resumes
  from the last checkpoint on the promoted mirror with correct
  sequence continuity.
- **FR105**: Error responses include a `reason` string that names
  the subsystem and the specific failure mode, not a generic
  server-error message.

### Distribution, Installation & Documentation

- **FR106**: Adopters can install IRISCouch into an existing IRIS
  instance with `zpm "install iris-couch"` as a single command.
- **FR107**: Adopters can install IRISCouch manually via
  ObjectScript `$System.OBJ.ImportDir` as a documented fallback.
- **FR108**: Operators can mount the IRISCouch webapp at a
  configurable path, with `/iris-couch/` as the documented default.
  For maximum CouchDB client compatibility (especially PouchDB
  replication), the recommended deployment uses a reverse proxy
  (nginx or Apache) that presents IRISCouch at the URL root on a
  dedicated port; example configurations are provided in the
  deployment documentation (see FR110, FR114).
- **FR109**: The default installation has no mandatory external
  dependencies beyond IRIS itself — no Node.js, no Python, no
  couchjs binary, no Erlang runtime.
- **FR110**: The repository publishes a Getting Started walkthrough
  that takes a new adopter from install to first successful PouchDB
  replication in under one hour.
- **FR111**: The repository publishes a live compatibility matrix
  listing every CouchDB 3.x HTTP API endpoint with support status
  (`supported`, `supported with caveat`, `501 in default config`,
  `out of scope with reason`) and the verification method used.
- **FR112**: The repository publishes a deviation log listing every
  observable difference between IRISCouch and Apache CouchDB with
  rationale for each deviation.
- **FR113**: The repository publishes a migration playbook covering
  pre-migration checklist, install, replicate-in, validation,
  optional dual-write, cutover, source drain, and symmetric
  rollback.
- **FR114**: The repository publishes a troubleshooting runbook
  covering at minimum: replication lag, checkpoint corruption,
  stuck conflicts, attachment stream failures, and JS sandbox
  errors.
- **FR115**: The repository ships six working examples in its
  `examples/` directory: `hello-document`, `pouchdb-sync`,
  `replicate-from-couchdb`, `mango-query`, `attachment-upload`,
  and `jsruntime-subprocess-node`. Broken examples block releases.

## Non-Functional Requirements

If § Functional Requirements is the *what*, this section is the
*how well*. Every FR above has an implicit quality bar — how
fast, how reliably, how securely, how maintainably it must
operate — and this section makes those quality bars explicit and
testable. NFRs are selective: only categories that genuinely
apply to this product are documented, to prevent requirement
bloat. Each NFR is stated in a form that can be tested or
measured, even when the measurement path involves differential
comparison against a real Apache CouchDB peer rather than
absolute numbers.

### NFR Categorization Note

Where a quality attribute does not yet have an empirical baseline
(because IRISCouch has not shipped and cannot yet be benchmarked
at the scale adopters will use), the NFR is expressed as a
**differential commitment** against Apache CouchDB 3.3.3 running
the same workload on comparable hardware. Differential NFRs
become absolute NFRs as benchmarking data accumulates post-α.

### Performance

**NFR-P1 — Document write latency parity.** Median `POST /{db}`
or `PUT /{db}/{docid}` latency, measured over a 10,000-document
customer-zero-representative workload, is no worse than **2× the
median latency of Apache CouchDB 3.3.3** running the same workload
on the same hardware. Target: significantly better; hard limit:
2×.

**NFR-P2 — Document read latency parity.** Median
`GET /{db}/{docid}` latency is no worse than **1.5× the median
latency of Apache CouchDB 3.3.3** on the same workload. IRIS's
raw-global read path is expected to be competitive or better.

**NFR-P3 — Mango `_find` latency with a selected index.** For
a Mango query whose selector can be planned against an existing
`json` index, median response time is no worse than **2× the
median response time of Apache CouchDB 3.3.3** running the same
query against an equivalent index.

**NFR-P4 — Replication throughput parity.** A full bidirectional
replication against a real Apache CouchDB 3.3.3 peer, over
customer zero's three databases (~10,000 documents, ~500 MB
including attachments), completes in a time **no worse than 2×**
the same replication between two Apache CouchDB 3.3.3 peers on
the same hardware.

**NFR-P5 — `_bulk_docs` throughput.** A bulk write of 1,000
documents via `_bulk_docs` completes in a time consistent with
document-write parity (NFR-P1) applied to the batch.

**NFR-P6 — `_changes` feed freshness in `feed=longpoll` mode.**
A document write is visible to a waiting `feed=longpoll` client
within **500 ms** under zero contention, and within **2 seconds**
under customer-zero-representative load.

**NFR-P7 — Read-after-write consistency for Mango on the same
write path.** A Mango `_find` query whose selector matches a
document just written via `POST`/`PUT` in the same transaction
boundary sees the written document **with zero staleness**. This
is a functional guarantee stated as an NFR because it defines
the quality the synchronous CQRS projection must deliver.

**NFR-P8 — Attachment streaming efficiency.** Uploading or
downloading a 500 MB attachment does **not** cause IRIS process
RSS to grow proportionally to attachment size. Memory usage
during the transfer is bounded by stream buffer size (kilobytes,
not megabytes).

**Benchmarking commitment.** NFR-P1 through NFR-P5 are
empirically validated in a post-α benchmarking effort and the
results are published in the deviation log and the compatibility
matrix. If any NFR is missed by more than its stated hard limit,
the deviation log records the gap and the mitigation.

### Reliability & Durability

**NFR-R1 — Unshippable-defect class.** A replication bug that
could corrupt a conflict tree — divergent revision histories,
dropped conflicts, or silent loss of a winning-rev calculation —
is never shippable. A release is halted if such a class of bug
is suspected, regardless of schedule or adopter pressure. This
is the highest-severity reliability commitment the project
makes.

**NFR-R2 — Atomic write guarantee.** Every document write (body
+ rev tree + changes feed sequence + Mango projection +
attachments, as applicable) is atomic: all components commit
inside a single journaled IRIS transaction, or none of them do.
There is no partial-write observable state.

**NFR-R3 — Crash recovery parity with IRIS.** Crash recovery of
IRISCouch state is whatever IRIS journal replay gives us; no
additional recovery mechanisms are required. A hard process kill
during a write leaves the database in a consistent state after
IRIS restart.

**NFR-R4 — Replication checkpoint durability.** `_local/`
checkpoint documents survive hard process kill plus IRIS restart
with correct sequence continuity. A resumed replication picks up
from the last recorded checkpoint, never from earlier.

**NFR-R5 — Mirror failover continuity.** After an IRIS mirror
failover, replication checkpoints survive with correct sequence
continuity on the promoted mirror. Replication resumes from the
last checkpoint on the new primary without rewinding or
duplicating work. *(Gated at γ by empirical validation — the
brief's Spike 3 risk register flags this as "technically survives
by construction, needs empirical validation.")*

**NFR-R6 — Conformance regression guarantee.** Any bug found
during customer zero migration or by an external adopter adds a
regression test to the differential HTTP harness before the fix
ships. A fix without a regression test is not accepted.

**NFR-R7 — Availability.** IRISCouch is available whenever its
hosting IRIS instance is available. The product does not add
downtime windows beyond IRIS's own operational requirements
(backup windows, upgrade windows, journaling checkpoints).

### Security

**NFR-S1 — Credentials never duplicated.** User credentials live
exclusively in IRIS's standard user directory. IRISCouch never
maintains a shadow credential store. A password set via the
`_users` database is hashed and stored in the IRIS user record,
not in the document body.

**NFR-S2 — Password hashing.** Credentials are hashed using
PBKDF2 via IRIS primitives, with iteration count matching or
exceeding CouchDB 3.x defaults (currently 10,000 iterations).

**NFR-S3 — Cookie integrity.** `AuthSession` cookies are
HMAC-signed with a per-instance secret. Cookie forgery requires
access to the signing secret; tampering is detected on every
request.

**NFR-S4 — Transport encryption and reverse proxy.** TLS
termination is handled by `%Service_WebGateway` / the CSP Gateway
using operator-configured certificates. IRISCouch does not
terminate TLS itself. The product works correctly behind a reverse
proxy terminating TLS upstream. Reverse proxy deployment is the
recommended topology for CouchDB client compatibility — IRISCouch
generates all URLs relative to `/` (no path-prefix awareness in
application code), and the proxy maps the external root to the
IRIS webapp mount path.

**NFR-S5 — Audit completeness.** Every document mutation, every
authentication attempt, every `_security` change, every `_users`
write, and every replication session emits a `%SYS.Audit` event.
An adopter reading only `%SYS.Audit` sees every state-changing
action IRISCouch performed.

**NFR-S6 — Authorization enforcement point.** `_security`
admin/member checks execute at the HTTP dispatch layer before
document logic runs. A request that should be denied never
reaches storage code.

**NFR-S7 — No telemetry phone-home.** IRISCouch does not
initiate outbound network traffic except (a) replication sessions
the operator has configured and (b) metrics push to an
operator-configured OpenTelemetry collector endpoint. No update
checks, no crash reporting, no usage analytics.

**NFR-S8 — Stack trace disclosure.** `500 Internal Server Error`
responses return a generic error envelope to the client
(`{"error": "internal_server_error", "reason": "..."}`) and log
the full stack trace to IRIS logs. Stack traces are never sent
to the HTTP client.

**NFR-S9 — JSRuntime sandbox isolation.** User-supplied
JavaScript executed via `JSRuntime.Subprocess` runs in a
subprocess with restricted filesystem and network access,
enforced by the operator's chosen runtime (Node `--permission`,
Bun sandbox, Deno default sandbox, couchjs historical behavior).
Per-invocation timeout and memory limits prevent runaway user
code from destabilizing IRISCouch (cf. FR82).

### Scalability

**NFR-SC1 — Validated scale envelope.** IRISCouch is validated
to serve workloads up to and including customer zero's envelope:
approximately **10,000 documents per database**, **~500 MB total
state** (bodies + attachments + metadata), **low tens of
concurrent writers**, and **single-digit map-reduce views or
filter functions per database**. Workloads within this envelope
have a correctness commitment and a performance commitment
(NFR-P1 through NFR-P6).

**NFR-SC2 — Unvalidated scale zones.** Workloads substantially
larger or more concurrent than NFR-SC1's envelope — hundreds of
thousands of documents per database, multi-gigabyte attachment
volume, high-concurrency write fan-out, dozens of map-reduce
views per database — are **explicitly not yet validated**. The
published compatibility matrix and the deviation log carry this
caveat. Post-α benchmarking work establishes the scaling ceiling
empirically and the boundary between NFR-SC1 and NFR-SC2
contracts.

**NFR-SC3 — Graceful degradation under load.** When the
synchronous Mango SQL projection becomes a write throughput
bottleneck (detected via the observability metrics in § NFR-O1),
IRISCouch does not silently drop writes or corrupt state. It
returns `503 Service Unavailable` with error slug
`internal_server_error` and `reason: "projection_backpressure"`,
and emits an audit event. Operators can alert on this and
respond.

**NFR-SC4 — Async projection fallback.** If a post-α benchmark
establishes that the synchronous projection pattern cannot
serve a specific production workload at acceptable latency, an
async projection mode with a bounded lag window is available
behind an opt-in feature flag. This is a documented fallback,
not a default.

**NFR-SC5 — ECP clustering scope.** ECP distributed-cache
clustering is supported at γ (multi-server IRIS deployments
sharing a namespace via ECP). Before γ, IRISCouch is validated
on single-server IRIS deployments only. Multi-server ECP
deployments on pre-γ releases are unsupported.

### Observability

**NFR-O1 — Metric freshness.** Prometheus / OpenTelemetry metrics
exposed by the scrape endpoint are updated at least every **10
seconds**. A scrape with a 30-second interval is never stale by
more than one interval plus metric update lag.

**NFR-O2 — Metric cardinality bounded.** Metric labels are
bounded cardinality — database name is permitted, document ID is
not. An operator cannot accidentally create unbounded label
cardinality by writing many unique documents.

**NFR-O3 — Metric endpoint availability.** The metrics scrape
endpoint is available whenever the rest of the HTTP API is
available. Metric collection failure does not affect the rest of
the system.

**NFR-O4 — Error message actionability.** Every error response
includes a `reason` field that names the subsystem and the
specific failure mode (e.g., `"jsruntime.none: views require
JSRuntime.Subprocess, see docs/jsruntime-enablement.md"`), never
a generic `"server error"` string.

**NFR-O5 — Log structured format.** Application-level logs emit
as structured entries (JSON-formatted or key-value) suitable for
consumption by log aggregation pipelines. Plain-text freeform
logs are reserved for debug mode.

**NFR-O6 — Audit event latency.** `%SYS.Audit` events are
written synchronously within the same transaction as the
operation they describe. An operation that appears to an
HTTP client as successful has a corresponding audit entry at
that moment, not eventually.

### Accessibility

**Scope note.** IRISCouch's human UI surface is the built-in
Angular admin UI. It is used by technical operators, not by
a broad public audience, and is not a regulated healthcare
UI (no PHI presentation layer). Accessibility commitments are
scoped to **reasonable baseline usability** rather than full
WCAG AA conformance.

**NFR-A1 — Keyboard navigability.** The admin UI is fully usable
via keyboard — every action the UI exposes can be reached and
executed without a pointing device. Tab ordering is sensible.

**NFR-A2 — Color contrast.** Text color / background color
combinations in the admin UI meet **WCAG AA contrast ratios
(4.5:1 for normal text, 3:1 for large text)** as a minimum. Not
a full WCAG AA audit, but the contrast bar is met.

**NFR-A3 — Screen reader compatibility (best-effort).** Angular
components use semantic HTML and ARIA attributes where
applicable. The UI is expected to work with mainstream screen
readers (NVDA, VoiceOver, JAWS), though not formally tested
against each. Bug reports are accepted; screen-reader-only bugs
are not release-blocking unless they break a core operator
workflow.

**NFR-A4 — No flash-based content.** The admin UI does not use
Flash, Silverlight, or any other deprecated plugin technology.
(Stated for completeness; current Angular practice makes this
trivially true.)

**Explicitly NOT committed.**
- Full WCAG 2.1 AA certification
- Section 508 certification
- Internationalization / localization of the admin UI (English
  only at MVP; i18n is a post-MVP consideration)
- High-contrast theme beyond the default contrast ratio compliance

### Integration & Compatibility

**NFR-I1 — Conformance suite gating.** Every release is gated on
100% pass rate of the three-layer conformance suite:
1. Apache CouchDB's own JavaScript test suite (on the covered
   subsystems, with skipped items documented)
2. PouchDB's replication conformance tests (full replication
   subset, zero failures)
3. Differential HTTP harness against a live Apache CouchDB
   3.3.3 peer (byte-identical on the wire-contract subset)

**NFR-I2 — Differential diff target.** The differential HTTP
harness must diff **zero bytes** on the wire-contract subset:
status codes, JSON error envelope shape (key ordering, slug
values, `reason` field presence), sequence token format,
checkpoint document shape, `_bulk_get` response structure,
`_revs_diff` response structure. A non-zero diff on this subset
halts the release.

**NFR-I3 — Compatibility matrix freshness.** The published
compatibility matrix is updated on every release. An endpoint
whose status changes from "supported" to "supported with caveat"
(or any other transition) must have the matrix updated in the
same commit as the code change, enforced by CI.

**NFR-I4 — Client smoke test cadence.** The smoke-tested client
matrix (PouchDB 9.x, Apache CouchDB replicator 3.3.3 + 3.5.x,
`nano` 10.x, `@cloudant/cloudant` 5.x, Fauxton) is re-run on
every release. A client that fails its smoke test blocks the
release until the failure is understood — either a fix, or an
explicit matrix downgrade with rationale.

**NFR-I5 — Wire protocol stability.** The HTTP wire contract is
stable for the duration a given CouchDB 3.x version is supported
upstream (Apache). A wire contract change would be a breaking
change to every adopter's client code and will not happen within
a 3.x anchor.

**NFR-I6 — Apache CouchDB version tracking.** When Apache
CouchDB publishes a new 3.x point release, the IRISCouch
conformance harness is updated within **one release cycle** to
include the new version. Upstream behavior changes are absorbed
into the harness before the corresponding IRISCouch release
ships.

### Maintainability & Operability

**NFR-M1 — Customer-zero regression discipline.** Customer zero's
three production databases are exercised against every release
before any public tag. A release that breaks customer zero is
not published.

**NFR-M2 — Documentation artifact freshness.** The published
compatibility matrix, deviation log, migration playbook,
troubleshooting runbook, and code examples (FR111–FR115) are
updated in the same commit as any code change that affects
them. CI enforces link validity and example compilation.

**NFR-M3 — Runbook coverage floor.** The troubleshooting runbook
covers the top five incident classes at α (replication lag,
checkpoint corruption, stuck conflicts, attachment stream
failures, JS sandbox errors). Any new incident class observed
during customer zero or by an external adopter becomes a new
runbook entry before the next release.

**NFR-M4 — Deviation log discipline.** Every observable
difference between IRISCouch and Apache CouchDB — intentional
or unavoidable — is recorded in the deviation log with a
rationale. A deviation that exists in code but not in the log
is a release-blocking defect.

**NFR-M5 — Bus-factor posture.** IRISCouch is Apache 2.0 licensed
and any tagged release remains forkable and self-documented. If
the project is ever shelved, adopters are not stranded: the
final release runs, the documentation describes its behavior,
and the code is readable and well-commented enough for a new
maintainer to pick up.

**NFR-M6 — ObjectScript code quality floor.** All public
ObjectScript classes (those adopters extend for custom JSRuntime
backends, metric exporters, or integration hooks) carry `///`
doc comments on every method. Private implementation classes
do not require full documentation but do require class-level
purpose comments.

**NFR-M7 — Conformance suite uptime.** The conformance suite
must run to completion on every release candidate. A "the
conformance suite is broken so we skipped it this release"
pattern is explicitly forbidden.

**NFR-M8 — Release cadence.** Release cadence is
**quality-gated, not calendar-gated**. There is no minimum
release frequency; a release ships when the conformance suite
is green, customer zero is unharmed, and the committed scope
for that milestone is complete. A release does not ship just
because time has passed.

**NFR-M9 — Python-Optional Compilation.** IRISCouch ObjectScript
classes MUST compile and the IRISCouch ZPM package MUST install
on any IRIS 2024.1+ instance regardless of embedded Python
availability. Shipped `.cls` files MUST NOT contain
`[Language = python]` methods; Python integration (when / if
present) MUST ship as ZPM `<FileCopy>` resources with `irispip`
documented as an operator-executed prerequisite, never invoked
from a ZPM install hook. Verified by a release-gate CI job that
runs `zpm install iris-couch` on a Python-less IRIS Community
image (when that CI image becomes available — tracked in
`deferred-work.md` under Story 12.4-resumption prerequisites;
until the CI image lands, manual verification on a Python-less
IRIS instance is the release gate). The corresponding code-review
rules live in `.claude/rules/iris-objectscript-basics.md` under
**Python Integration Distribution Rules**. Cited origin: Epic 12
retrospective (2026-04-17), Action Items #6–#10 — Story 12.4's
Python JSRuntime deferral exposed that a `[Language = python]`
method in any shipped class is a latent install-break for every
IRIS customer without embedded Python, and named this NFR as the
single highest-value finding of the retro.
