# Implementation Readiness Assessment Report

**Date:** 2026-04-12
**Project:** iris-couch

---
stepsCompleted: [step-01-document-discovery, step-02-prd-analysis, step-03-epic-coverage-validation, step-04-ux-alignment, step-05-epic-quality-review, step-06-final-assessment]
filesIncluded:
  prd: prd.md
  prd-validation: prd-validation-report.md
  architecture: architecture.md
  epics: epics.md
  ux-design: ux-design-specification.md
  supplementary:
    - prd-distillate.md
    - product-brief-iris-couch.md
    - sprint-change-proposal-2026-04-12.md
---

## 1. Document Inventory

| Document Type | File | Size | Modified |
|---|---|---|---|
| PRD | prd.md | 127 KB | 2026-04-12 |
| PRD Validation Report | prd-validation-report.md | 22 KB | 2026-04-11 |
| PRD Distillate | prd-distillate.md | 20 KB | 2026-04-11 |
| Architecture | architecture.md | 62 KB | 2026-04-12 |
| Epics & Stories | epics.md | 141 KB | 2026-04-12 |
| UX Design Specification | ux-design-specification.md | 175 KB | 2026-04-11 |
| Product Brief | product-brief-iris-couch.md | 28 KB | 2026-04-11 |
| Sprint Change Proposal | sprint-change-proposal-2026-04-12.md | 5 KB | 2026-04-12 |

**Discovery Notes:**
- No duplicate conflicts found (no sharded versions)
- All four required document types present
- No missing required documents

## 2. PRD Analysis

### Functional Requirements

**Database Lifecycle (FR1–FR8)**
- FR1: Create database via HTTP PUT
- FR2: Delete database via HTTP DELETE
- FR3: List all databases via `GET /_all_dbs`
- FR4: Retrieve per-database metadata via `GET /{db}`
- FR5: Configure per-database revision retention limit via `PUT /{db}/_revs_limit`
- FR6: Trigger database compaction via `POST /{db}/_compact`
- FR7: Request full commit via `POST /{db}/_ensure_full_commit`
- FR8: Return 201 Created on success, 412 Precondition Failed with `file_exists` if exists

**Document Storage, Revisions & Conflict Model (FR9–FR20)**
- FR9: Create document with server-generated UUID via `POST /{db}`
- FR10: Create/update document with client-specified ID via `PUT /{db}/{docid}`
- FR11: Retrieve document by ID via `GET /{db}/{docid}` with optional query params (`?rev=`, `?revs=`, `?revs_info=`, `?conflicts=`, `?local_seq=`)
- FR12: Delete document via `DELETE /{db}/{docid}?rev=N-hex` or PUT with `_deleted: true`, producing tombstone
- FR13: Enforce optimistic concurrency — stale `_rev` rejected with 409 Conflict
- FR14: Detect and preserve concurrent-update conflicts, expose via `_conflicts` field
- FR15: Compute winning revision deterministically using CouchDB's published algorithm
- FR16: Submit multiple document writes via `POST /{db}/_bulk_docs`
- FR17: Submit replication-format writes via `_bulk_docs` with `new_edits=false`
- FR18: Retrieve multiple documents by ID via `POST /{db}/_bulk_get`
- FR19: Retrieve revision tree and open revisions via `?open_revs=all` or specific revs
- FR20: Reject user-created underscore-prefixed fields with 400 `doc_validation`

**Document Listing & Changes Feed (FR21–FR30)**
- FR21: List all documents via `GET /{db}/_all_docs` with pagination, key-range filtering, included-docs
- FR22: List specific documents via `POST /{db}/_all_docs` with `keys` array
- FR23: Subscribe to changes feed in `feed=normal` mode
- FR24: Subscribe to changes feed in `feed=longpoll` mode
- FR25: Filter changes feed by document IDs via `_doc_ids` filter
- FR26: Filter changes feed by Mango selector via `_selector` filter
- FR27: Filter changes feed to design documents via `_design` filter
- FR28: Subscribe to changes feed in `feed=continuous` mode (TCP listener at gamma)
- FR29: Subscribe to changes feed in `feed=eventsource` mode (TCP listener at gamma)
- FR30: Assign monotonically increasing sequence number to every change, atomically per database

**Attachment Handling (FR31–FR40)**
- FR31: Attach binary content inline via base64-encoded `_attachments` in JSON body
- FR32: Attach binary content via `multipart/related` upload
- FR33: Attach binary content via standalone `PUT /{db}/{docid}/{attname}?rev=N-hex`
- FR34: Retrieve attachment raw bytes via `GET /{db}/{docid}/{attname}`
- FR35: Retrieve document with attachments via `multipart/mixed` response
- FR36: Request attachment retrieval only for revisions newer than given rev via `?atts_since=`
- FR37: Request attachments as stubs only via `?attachments=false` (default)
- FR38: Request attachment content inclusion via `?attachments=true`
- FR39: Store attachment content as binary streams without buffering entire bodies in memory
- FR40: Compute and store MD5 digests for every attachment; digests round-trip through replication

**Mango Query & Indexing (FR41–FR50)**
- FR41: Query documents via `POST /{db}/_find` with Mango selector (fields, sort, limit, skip, use_index, r)
- FR42: Create Mango indexes of type `json` via `POST /{db}/_index`
- FR43: List existing Mango indexes via `GET /{db}/_index`
- FR44: Delete a Mango index via `DELETE /{db}/_index/{ddoc}/{type}/{name}`
- FR45: Inspect query plan via `POST /{db}/_explain`
- FR46: Create Mango indexes with `partial_filter_selector`
- FR47: Support Mango selector operators: equality, `$gt`, `$gte`, `$lt`, `$lte`, `$ne`, `$in`, `$nin`, `$exists`, `$type`, `$and`, `$or`, `$nor`, `$not`, `$regex`, `$elemMatch`, `$allMatch`
- FR48: Fall back to full scan when selector cannot be planned against existing index
- FR49: Query design-document views via `GET /{db}/_design/{ddoc}/_view/{view}` when JSRuntime enabled
- FR50: Support built-in reduces `_sum`, `_count`, `_stats`, `_approx_count_distinct`

**Replication Protocol (FR51–FR59)**
- FR51: Retrieve revision difference sets via `POST /{db}/_revs_diff`
- FR52: Retrieve multiple documents with specific revisions via `POST /{db}/_bulk_get` with `revs=true&attachments=true`
- FR53: Persist and retrieve replication checkpoints via `PUT/GET /{db}/_local/{id}`
- FR54: Exclude `_local/` documents from changes feed, `_all_docs`, and replication
- FR55: Configure continuous replication via `_replicator` database documents
- FR56: Write replication state updates back to `_replicator` document
- FR57: Compute deterministic `replication_id` values that survive restart
- FR58: Perform bidirectional replication against a real Apache CouchDB 3.x peer
- FR59: Generate revision hashes deterministically from document content (JSON-canonical MD5)

**Authentication, Authorization & Security (FR60–FR71)**
- FR60: Authenticate via HTTP Basic auth against IRIS user directory
- FR61: Authenticate via `POST /_session` with HMAC-signed `AuthSession` cookie
- FR62: Retrieve current session info via `GET /_session`
- FR63: Log out via `DELETE /_session`
- FR64: Authenticate via JWT bearer tokens
- FR65: Authenticate via proxy auth headers from trusted upstreams
- FR66: Manage users via `_users` database documents synchronized to IRIS user records
- FR67: Hash passwords using PBKDF2 via IRIS primitives, stored in IRIS user record
- FR68: Set per-database admin/member lists via `PUT /{db}/_security`
- FR69: Enforce `_security` access restrictions before document logic
- FR70: Return 401 Unauthorized with `unauthorized` slug when auth missing/invalid
- FR71: Return 403 Forbidden with `forbidden` slug when authorized but not permitted

**User JavaScript Execution — Pluggable JSRuntime (FR72–FR82)**
- FR72: Operators select JSRuntime backend (`None`, `Subprocess`, `Python`) at configuration time
- FR73: Default JSRuntime backend at installation is `None`
- FR74: Accept, store, and replicate design documents regardless of JSRuntime backend
- FR75: With `JSRuntime.None`, JS-requiring requests return 501 with actionable reason string
- FR76: With `JSRuntime.Subprocess`, execute map-reduce view functions via subprocess
- FR77: With `JSRuntime.Subprocess`, execute `validate_doc_update` hooks
- FR78: With `JSRuntime.Subprocess`, execute `_changes` filter functions
- FR79: With `JSRuntime.Python`, execute JS functions via embedded Python + QuickJS
- FR80: Build and maintain incremental view indexes on document write
- FR81: Serve view query results with ETag-based caching (304 Not Modified)
- FR82: Enforce per-invocation timeouts and memory-pressure restarts on JSRuntime subprocesses

**Administration UI (FR83–FR95)**
- FR83 [alpha]: Built-in admin UI at `_utils` path, no separate tooling required
- FR84 [alpha]: Admin UI is TypeScript + Angular SPA served as static assets
- FR85 [alpha]: List all databases via admin UI
- FR86 [alpha]: Create database via admin UI
- FR87 [alpha]: Delete database via admin UI
- FR88 [alpha]: View per-database metadata via admin UI
- FR89 [alpha]: Browse documents with pagination via admin UI
- FR90 [alpha]: View individual document details via admin UI
- FR91 [alpha]: View design documents (read-only) via admin UI
- FR92 [beta]: Create, edit, and delete design documents via admin UI
- FR93 [alpha]: View `_security` config (read-only) via admin UI
- FR94 [beta]: Edit `_security` config via admin UI
- FR95 [gamma]: View document revision history via admin UI

**Observability, Audit & Operations (FR96–FR105)**
- FR96: Prometheus/OpenTelemetry metrics scrape endpoint (request counts, latency histograms, replication throughput, changes lag, Mango hit rate, error counters)
- FR97: `%SYS.Audit` event for every document write
- FR98: `%SYS.Audit` event for every authentication attempt
- FR99: `%SYS.Audit` event for every `_security` change
- FR100: `%SYS.Audit` event for every `_users` write
- FR101: `%SYS.Audit` event for replication session start/completion
- FR102: All IRISCouch state lives within IRIS namespace, covered by standard mirroring/backup/journal replay
- FR103: Replication checkpoints survive hard kill + restart with correct seq continuity
- FR104: After mirror failover, replication resumes from last checkpoint with seq continuity
- FR105: Error responses include actionable `reason` string naming subsystem and failure mode

**Distribution, Installation & Documentation (FR106–FR115)**
- FR106: Install via `zpm "install iris-couch"` single command
- FR107: Manual install fallback via `$System.OBJ.ImportDir`
- FR108: Configurable webapp mount path (default `/iris-couch/`); reverse proxy recommended for root-path deployment
- FR109: No mandatory external dependencies beyond IRIS at default install
- FR110: Getting Started walkthrough — install to first PouchDB replication in under one hour
- FR111: Live compatibility matrix for every CouchDB 3.x endpoint
- FR112: Deviation log for every observable difference from Apache CouchDB
- FR113: Migration playbook (pre-migration, install, replicate-in, validate, dual-write, cutover, rollback)
- FR114: Troubleshooting runbook (replication lag, checkpoint corruption, stuck conflicts, attachment failures, JS sandbox errors)
- FR115: Six working examples in `examples/` directory; broken examples block releases

**Total FRs: 115**

### Non-Functional Requirements

**Performance (NFR-P1 through NFR-P8)**
- NFR-P1: Document write latency no worse than 2x Apache CouchDB 3.3.3 median
- NFR-P2: Document read latency no worse than 1.5x Apache CouchDB 3.3.3 median
- NFR-P3: Mango `_find` with index no worse than 2x CouchDB 3.3.3 median
- NFR-P4: Replication throughput no worse than 2x same CouchDB-to-CouchDB replication
- NFR-P5: `_bulk_docs` throughput consistent with per-document write parity
- NFR-P6: `_changes` longpoll freshness within 500ms (zero contention), 2s (representative load)
- NFR-P7: Read-after-write consistency for Mango — zero staleness (synchronous CQRS guarantee)
- NFR-P8: Attachment streaming — no RSS growth proportional to attachment size

**Reliability & Durability (NFR-R1 through NFR-R7)**
- NFR-R1: Replication conflict-tree corruption is unshippable-defect class — halts release
- NFR-R2: Atomic write guarantee — all components in single journaled IRIS transaction
- NFR-R3: Crash recovery parity with IRIS journal replay
- NFR-R4: Replication checkpoint durability — survives hard kill + restart
- NFR-R5: Mirror failover continuity — checkpoints survive with seq continuity on promoted mirror (gamma)
- NFR-R6: Conformance regression guarantee — bug fix requires regression test first
- NFR-R7: Availability parity with hosting IRIS instance

**Security (NFR-S1 through NFR-S9)**
- NFR-S1: Credentials never duplicated — live exclusively in IRIS user directory
- NFR-S2: Password hashing via PBKDF2, >= 10,000 iterations
- NFR-S3: Cookie integrity — HMAC-signed AuthSession cookies
- NFR-S4: Transport encryption via CSP Gateway / reverse proxy; no self-terminated TLS
- NFR-S5: Audit completeness — every state-changing action emits `%SYS.Audit` event
- NFR-S6: Authorization enforcement at HTTP dispatch layer before document logic
- NFR-S7: No telemetry phone-home — only operator-configured outbound traffic
- NFR-S8: Stack trace disclosure — never sent to HTTP client, logged internally only
- NFR-S9: JSRuntime sandbox isolation — subprocess with restricted filesystem/network, timeouts, memory limits

**Scalability (NFR-SC1 through NFR-SC5)**
- NFR-SC1: Validated scale envelope — ~10K docs/db, ~500MB total, low tens concurrent writers
- NFR-SC2: Larger workloads explicitly unvalidated, documented as caveat
- NFR-SC3: Graceful degradation under load — 503 with backpressure reason, not silent failures
- NFR-SC4: Async projection fallback behind feature flag if synchronous projection bottlenecks
- NFR-SC5: ECP clustering supported at gamma; pre-gamma is single-server only

**Observability (NFR-O1 through NFR-O6)**
- NFR-O1: Metric freshness — updated at least every 10 seconds
- NFR-O2: Metric cardinality bounded — database name OK, document ID not
- NFR-O3: Metrics endpoint available whenever HTTP API available
- NFR-O4: Error message actionability — reason field names subsystem and failure mode
- NFR-O5: Structured log format (JSON or key-value)
- NFR-O6: Audit event latency — synchronous within same transaction

**Accessibility (NFR-A1 through NFR-A4)**
- NFR-A1: Keyboard navigability — all actions reachable without pointing device
- NFR-A2: Color contrast meets WCAG AA ratios (4.5:1 normal text, 3:1 large text)
- NFR-A3: Screen reader compatibility — best effort with semantic HTML + ARIA
- NFR-A4: No flash-based content

**Integration & Compatibility (NFR-I1 through NFR-I6)**
- NFR-I1: Three-layer conformance suite gates every release (CouchDB JS tests, PouchDB replication, differential HTTP harness)
- NFR-I2: Differential harness must diff zero bytes on wire-contract subset
- NFR-I3: Compatibility matrix updated on every release, enforced by CI
- NFR-I4: Client smoke test matrix re-run on every release
- NFR-I5: Wire protocol stable within CouchDB 3.x anchor
- NFR-I6: CouchDB 3.x new point releases absorbed within one release cycle

**Maintainability & Operability (NFR-M1 through NFR-M8)**
- NFR-M1: Customer-zero regression discipline — exercised every release
- NFR-M2: Documentation artifact freshness — updated in same commit as code changes
- NFR-M3: Runbook coverage floor — top 5 incident classes at alpha, expanded per findings
- NFR-M4: Deviation log discipline — every difference recorded; unlogged deviation is release-blocking
- NFR-M5: Bus-factor posture — Apache 2.0, forkable, self-documented
- NFR-M6: ObjectScript code quality floor — `///` doc comments on public classes
- NFR-M7: Conformance suite uptime — must run to completion on every RC
- NFR-M8: Release cadence — quality-gated, not calendar-gated

**Total NFRs: 38** (P1-P8, R1-R7, S1-S9, SC1-SC5, O1-O6, A1-A4, I1-I6, M1-M8)

### Additional Requirements

**Constraints & Assumptions:**
- ObjectScript is the only backend implementation language (non-negotiable)
- Angular is the only admin UI implementation language (non-negotiable)
- Wire compatibility measured via three-layer conformance suite, not asserted
- `^IRISCouch.*` globals and `IRISCouch.*` classes naming convention locked
- No commercial productization
- Zero mandatory external dependencies at MVP default
- JSRuntime is pluggable and operator-selected
- Phases 0-7 are all MVP scope (alpha, beta, gamma are checkpoints within MVP)
- Customer zero is the forcing function and continuous regression suite
- Single-developer + AI coding agents team; quality-gated, no deadline
- Apache CouchDB 3.3.3 is primary conformance baseline through beta; 3.5.x added at gamma

**Integration Requirements:**
- Bidirectional replication against live Apache CouchDB 3.x peers
- Smoke-tested clients: PouchDB 9.x, `nano` 10.x, `@cloudant/cloudant` 5.x, Fauxton, CouchDB replicator 3.3.3+3.5.x
- ZPM/IPM distribution as primary install channel
- IRIS mirroring, backup, and `%SYS.Audit` integration inherited by construction

### PRD Completeness Assessment

The PRD is exceptionally thorough and well-structured:
- **115 functional requirements** numbered and organized across 11 subsystems
- **38 non-functional requirements** with measurable/testable criteria across 8 categories
- Clear milestone phasing (alpha/beta/gamma) with specific gating criteria
- 5 detailed user journeys with explicit requirement tracebacks
- Comprehensive risk register with mitigations
- Non-negotiable scope decisions explicitly locked
- Dual audience optimization (human + LLM consumption)
- No observable gaps in requirement coverage for the stated MVP scope

## 3. Epic Coverage Validation

### Coverage Matrix

| FR Range | PRD Subsystem | Epic | Status |
|---|---|---|---|
| FR1–FR8 | Database Lifecycle | Epic 2: Database Lifecycle Management | Covered |
| FR9–FR22 | Document Storage, Revisions & Conflict Model + Document Listing | Epic 3: Document Storage & Revision Control | Covered |
| FR23–FR27, FR30 | Changes Feed (normal, longpoll, built-in filters) | Epic 4: Real-Time Change Tracking | Covered |
| FR28–FR29 | Changes Feed (continuous, eventsource) | Epic 14: Gamma - Streaming Feeds & ECP Clustering | Covered |
| FR31–FR40 | Attachment Handling | Epic 5: Binary Attachment Management | Covered |
| FR41–FR48 | Mango Query & Indexing (core) | Epic 6: Mango Query Engine | Covered |
| FR49–FR50 | Design-document views & built-in reduces | Epic 12: Pluggable JavaScript Runtime | Covered |
| FR51–FR59 | Replication Protocol | Epic 8: Replication Protocol | Covered |
| FR60���FR71 | Authentication, Authorization & Security | Epic 7: Authentication & Authorization | Covered |
| FR72–FR82 | User JavaScript Execution (JSRuntime) | Epic 12: Pluggable JavaScript Runtime | Covered |
| FR83–FR90 | Administration UI (alpha scope) | Epic 10: Admin UI - Core Experience | Covered |
| FR91–FR95 | Administration UI (beta/gamma scope) | Epic 11: Admin UI - Design Docs & Security Views | Covered |
| FR96–FR104 | Observability, Audit & Operations | Epic 9: Observability & Audit Trail | Covered |
| FR105 | Actionable error responses | Epic 1: Project Foundation & Server Identity | Covered |
| FR106–FR109 | Distribution & Installation | Epic 1: Project Foundation & Server Identity | Covered |
| FR110–FR115 | Documentation & Working Examples | Epic 13: Documentation & Working Examples | Covered |

### Missing Requirements

**No missing FRs identified.** All 115 functional requirements from the PRD are explicitly claimed by at least one epic.

### Coverage Statistics

- Total PRD FRs: 115
- FRs covered in epics: 115
- Coverage percentage: **100%**

### NFR Coverage Notes

The epics document also inventories all 38 NFRs and maps them to relevant epics. Key cross-cutting NFR assignments:
- NFR-R1 (unshippable defect class) — Epic 8 (Replication)
- NFR-R2 (atomic writes) — Epic 3 (Document Storage)
- NFR-P7 (read-after-write consistency) — Epic 6 (Mango)
- NFR-P8 (attachment streaming) — Epic 5 (Attachments)
- NFR-S6 (authorization enforcement point) — Epic 7 (Auth)
- NFR-R5, NFR-SC5 (mirror failover, ECP) — Epic 14 (Gamma)
- NFR-O6 (synchronous audit) — Epic 9 (Observability)
- NFR-A1–A4 (accessibility) — Epics 10, 11 (Admin UI)

## 4. UX Alignment Assessment

### UX Document Status

**Found:** `ux-design-specification.md` (175 KB, completed 2026-04-11, all 14 steps completed)

The UX specification is comprehensive, covering:
- Executive summary with explicit persona mapping to PRD user journeys
- Core user experience principles and emotional design goals
- Design system foundation (tokens, typography, spacing, color)
- 69 UX Design Requirements (UX-DR1 through UX-DR69)
- Component strategy with phased delivery (alpha/beta/gamma)
- Accessibility requirements with automated testing approach
- Responsive design constraints (1280px floor, desktop-only)

### UX <-> PRD Alignment

**Strong alignment observed:**
- UX-DR scope maps directly to PRD FR83–FR95 (Admin UI subsystem)
- All 4 operator personas from PRD user journeys (Maya, Devi, Tomas, author) are explicitly addressed as UX target users
- Phased delivery matches PRD milestone commitments: alpha (read-only design docs/security), beta (editable), gamma (revision history)
- Zero-dependency install constraint honored (UX-DR61: all assets self-contained, no CDN)
- Error envelope rendering matches PRD requirement for actionable `reason` strings (UX-DR23, UX-DR39)
- CouchDB cookie-auth flow aligns with PRD authentication model (UX-DR38)

**No misalignments identified between UX and PRD.**

### UX <-> Architecture Alignment

**Strong alignment observed:**
- Architecture specifies Angular 19 SPA with `ng new` minimal scaffold — matches UX component strategy
- Architecture explicitly rejects Angular Material (matches UX spec step 5 anti-pattern)
- Architecture specifies `@angular/cdk` for accessibility primitives — UX-DRs reference CDK throughout (FocusKeyManager, overlay, clipboard, LiveAnnouncer)
- Architecture specifies `AdminUIHandler.cls` for static asset serving at `/_utils/*` — matches UX mounting point
- Architecture specifies committed `ui/dist/browser/` with CI verification — matches UX zero-dependency constraint
- Architecture specifies "Admin UI as a CouchDB client" — UI communicates via same HTTP API, no private admin API — matches UX service layer design
- Architecture Pattern 8 (Angular Component Patterns) aligns with UX component structure

**No architectural gaps that would block UX delivery.**

### UX Requirements in Epics

The epics document inventories all 69 UX-DRs and maps them to stories:
- **Epic 10 (Admin UI - Core Experience):** UX-DR1–DR18, UX-DR21–DR31, UX-DR34–DR46, UX-DR49–DR62, UX-DR65–DR69
- **Epic 11 (Admin UI - Design Docs & Security Views):** UX-DR19, UX-DR20, UX-DR32, UX-DR33, UX-DR47, UX-DR48, UX-DR63, UX-DR64

All 69 UX-DRs are accounted for across Epics 10 and 11.

### Warnings

**None.** UX documentation is thorough, well-aligned with both PRD and Architecture, and fully mapped to epics.

## 5. Epic Quality Review

### Epic Structure Validation

#### User Value Focus

| Epic | Title | User Value? | Assessment |
|---|---|---|---|
| 1 | Project Foundation & Server Identity | Yes — "Adopters can install and verify a running CouchDB-compatible server" | GREEN |
| 2 | Database Lifecycle Management | Yes — "Operators and clients can create, delete, list, and inspect databases" | GREEN |
| 3 | Document Storage & Revision Control | Yes — "Clients can store, retrieve, update, and delete documents with MVCC" | GREEN |
| 4 | Real-Time Change Tracking | Yes — "Clients can subscribe to database change feeds" | GREEN |
| 5 | Binary Attachment Management | Yes — "Clients can upload, download, and manage binary attachments" | GREEN |
| 6 | Mango Query Engine | Yes — "Clients can create indexes and query documents using Mango selectors" | GREEN |
| 7 | Authentication & Authorization | Yes — "Operators can secure the system; clients can authenticate" | GREEN |
| 8 | Replication Protocol | Yes — "Clients can replicate data bidirectionally with Apache CouchDB peers" | GREEN |
| 9 | Observability & Audit Trail | Yes — "Operators can monitor system health and audit every operation" | GREEN |
| 10 | Admin UI - Core Experience | Yes — "Operators can log in, view/manage databases, browse documents" | GREEN |
| 11 | Admin UI - Design Documents & Security | Yes — "Operators can view and manage design documents and security" | GREEN |
| 12 | Pluggable JavaScript Runtime | Yes — "Operators can enable JavaScript execution for design-doc views/validation/filters" | GREEN |
| 13 | Documentation & Working Examples | Yes — "Adopters have comprehensive documentation and working examples" | GREEN |
| 14 | Gamma - Streaming Feeds & ECP Clustering | Yes — "Clients can subscribe to continuous/eventsource feeds; operators can deploy across ECP" | GREEN |

All 14 epics are framed around user/operator outcomes. No purely technical milestone epics detected.

#### Epic Independence Validation

- **Epic 1** — stands alone completely (ZPM install, welcome endpoint, UUIDs, error envelope)
- **Epic 2** — depends only on Epic 1 output (router, config system). Can function standalone.
- **Epic 3** — depends on Epic 1 + 2 (database must exist to store documents). Valid dependency.
- **Epic 4** — depends on Epic 3 (changes track document writes). Valid sequential dependency.
- **Epic 5** — depends on Epic 3 (attachments are on documents). Valid.
- **Epic 6** — depends on Epic 3 (Mango queries documents). Valid.
- **Epic 7** — depends on Epic 1 (auth wraps HTTP layer). Can be developed in parallel with 3-6.
- **Epic 8** — depends on Epics 3, 4, 5 (replication uses docs, changes, attachments). Valid.
- **Epic 9** — depends on Epic 1+ (observability wraps existing endpoints). Cross-cutting, valid.
- **Epics 10-11** — depend on backend epics (UI consumes the HTTP API). Valid for parallel track.
- **Epic 12** — depends on Epic 3 (JSRuntime executes against documents). Valid.
- **Epic 13** — depends on all prior epics (documentation covers the product). Valid as final epic.
- **Epic 14** — depends on Epic 4 (extends changes feed). Valid gamma-scope extension.

**No circular dependencies detected. No forward dependencies (Epic N requiring Epic N+1).**

### Story Quality Assessment

#### Story Sizing

All stories reviewed appear appropriately sized — focused on a single capability with clear boundaries. No "mega-stories" that bundle unrelated concerns.

#### Acceptance Criteria Quality

**Strengths:**
- All stories use proper "As a [role], I want [capability], So that [value]" format
- Acceptance criteria consistently use Given/When/Then BDD structure
- Error conditions are included alongside happy paths
- Criteria are specific and testable (exact HTTP status codes, JSON response shapes, global paths)

### Quality Findings

#### Critical Violations (RED)

**None identified.** After calibration for ObjectScript/IRIS conventions (globals created on first write, `%SYS.Audit` is a built-in IRIS class, CDK is a dependency declared in the architecture), no genuine critical violations remain.

#### Major Issues (ORANGE)

**ORANGE-1: Story 8.4 (Bidirectional Replication) is large and underspecified for orchestration logic.**
The story describes end-to-end bidirectional replication but does not explicitly break out the replication state machine / coordinator logic as a distinct concern. The story implicitly assumes a replication orchestrator exists but no prior story defines one.
- **Impact:** Implementer may struggle to scope this story; it could become a multi-week effort.
- **Recommendation:** Consider splitting Story 8.4 into (a) outbound replication pull/push orchestration and (b) end-to-end bidirectional verification. Or ensure the story's implementation notes make the orchestrator scope explicit.

**ORANGE-2: Story 8.5 (_replicator Database & Continuous Jobs) references system database conventions not defined elsewhere.**
The `_replicator` database is a special system database with self-updating document semantics. No prior story defines the system database concept or the document schema for replication state fields.
- **Impact:** Implementer needs to understand CouchDB `_replicator` semantics deeply; no explicit schema definition is provided.
- **Recommendation:** Add a brief schema definition for `_replicator` document fields within the story's AC or implementation notes.

**ORANGE-3: Some acceptance criteria leak implementation details rather than describing observable behavior.**
Several ACs reference specific internal class/method names (e.g., `DocumentEngine.SaveWithHistory()`, `IRISCouch.Util.Error.Render()`) and global structures (`^IRISCouch.Seq`, `^IRISCouch.Changes`). While these align with the architecture document, they constrain the implementer to specific internal designs within what should be a behavior contract.
- **Impact:** Low — architecture already locks these decisions. But it conflates AC (what) with implementation (how).
- **Recommendation:** Acceptable given that architecture decisions are pre-locked. Note for implementers that internal class names in ACs are architectural guidance, not rigid contract.

#### Minor Concerns (YELLOW)

**YELLOW-1: NFR references in acceptance criteria (e.g., "per NFR-R2", "per NFR-O4").**
Several stories reference NFR identifiers without inlining the requirement text. Implementers must cross-reference the PRD to understand the constraint.
- **Recommendation:** Acceptable — the epics document already inventories all NFRs at the top. Cross-references are sufficient for a single-developer + AI agent workflow.

**YELLOW-2: Story 5.3 (Attachment Retrieval Options) — `atts_since` parameter semantics could be clearer.**
The `atts_since` parameter requires knowing which revision added/changed an attachment. The mechanism for tracking this is implied by the revision tree but not explicitly spelled out.
- **Recommendation:** Minor — the CouchDB specification defines `atts_since` semantics, and the architecture's revision tree design supports it. No action needed unless an implementer flags confusion.

**YELLOW-3: Epic 10 stories include highly prescriptive UX details (e.g., "exactly 11 neutral gray palette tokens").**
These are implementation-level specifications from the UX-DRs, not user-value outcomes. However, this is intentional — the UX spec was designed to be this prescriptive for AI agent consumption.
- **Recommendation:** Acceptable for this project's AI-assisted workflow. No change needed.

**YELLOW-4: Story 12.5 (Incremental View Indexing & ETag Caching) references HTTP caching without prior caching infrastructure story.**
ETag caching is introduced here for view results but no prior epic establishes an HTTP caching layer.
- **Recommendation:** Acceptable — ETag caching is a standard HTTP pattern implementable at the handler level. No separate infrastructure story needed.

**YELLOW-5: Milestone labels in ACs (e.g., "[alpha]", "[beta]", "[gamma]") are not formally defined as gates.**
Some stories reference milestone phases without explicit gate criteria within the story itself.
- **Recommendation:** Gate criteria are defined in the PRD's Success Criteria section. Cross-reference is sufficient.

### Best Practices Compliance Summary

| Check | Result |
|---|---|
| Epics deliver user value | PASS (14/14) |
| Epics function independently (no forward deps) | PASS |
| Stories appropriately sized | PASS (with ORANGE-1 caveat on Story 8.4) |
| No forward dependencies within epics | PASS |
| Data structures created when needed | PASS (IRIS globals are created on first write) |
| Clear acceptance criteria (Given/When/Then) | PASS |
| Traceability to FRs maintained | PASS (100% FR coverage) |
| Traceability to UX-DRs maintained | PASS (69/69 UX-DRs mapped) |

## 6. Summary and Recommendations

### Overall Readiness Status

**READY** — with minor recommendations below.

The iris-couch project's planning artifacts are exceptionally well-prepared for implementation. The PRD, Architecture, UX Design Specification, and Epics & Stories documents are comprehensive, internally consistent, and tightly aligned with each other. This is among the most thorough planning artifact sets for a project of this complexity.

### Scorecard

| Dimension | Score | Notes |
|---|---|---|
| PRD Completeness | 10/10 | 115 FRs, 38 NFRs, 5 user journeys, full risk register |
| FR Coverage in Epics | 10/10 | 100% (115/115 FRs mapped to epics) |
| UX-DR Coverage in Epics | 10/10 | 100% (69/69 UX-DRs mapped to epics) |
| UX <-> PRD Alignment | 10/10 | Zero misalignments |
| UX <-> Architecture Alignment | 10/10 | Zero architectural gaps |
| Epic User-Value Focus | 10/10 | All 14 epics framed as user outcomes |
| Epic Independence | 9/10 | Valid sequential dependencies; no circular deps |
| Story Quality (format/ACs) | 9/10 | Consistent Given/When/Then; minor implementation leakage |
| Dependency Management | 9/10 | No forward deps; Story 8.4/8.5 could be clearer |
| NFR Traceability | 9/10 | All 38 NFRs inventoried and mapped; cross-references used |

### Critical Issues Requiring Immediate Action

**None.** No blocking issues were identified that would prevent implementation from starting.

### Recommended Improvements (Non-Blocking)

1. **Consider splitting Story 8.4 (Bidirectional Replication).** This is the largest and most complex story in the entire backlog. Consider splitting into (a) outbound replication orchestration (pull source changes → apply locally) and (b) inbound replication serving (respond to peer's replication requests) to make implementation progress more measurable and reduce risk of scope creep within the story.

2. **Add explicit `_replicator` document schema to Story 8.5.** The `_replicator` database has self-updating document semantics and a specific field set (`_replication_id`, `_replication_state`, `_replication_state_time`, `_replication_stats`). Adding a brief schema definition within the story's acceptance criteria or implementation notes would help the implementer scope the work.

3. **Consider extracting internal class/method names from acceptance criteria into implementation notes.** Several ACs reference specific ObjectScript class names (e.g., `DocumentEngine.SaveWithHistory()`, `IRISCouch.Util.Error.Render()`). While these align with the architecture document, separating "what" (observable behavior) from "how" (implementation approach) would make the ACs cleaner. This is a stylistic preference, not a defect — the architecture already locks these decisions.

### Strengths Worth Preserving

- **Exceptional traceability.** Every FR traces to an epic, every UX-DR traces to a story, every NFR is inventoried and cross-referenced. This is rare and valuable.
- **Honest risk accounting.** The PRD's risk register is specific, paired with concrete mitigations, and integrated into scope decisions rather than existing as a separate "risks" appendix.
- **Wire-compatibility as a measurable bar.** The three-layer conformance suite (CouchDB JS tests, PouchDB replication conformance, differential HTTP harness) turns "compatible" from a marketing claim into a testable gate. This is the project's strongest architectural decision.
- **Phased delivery with clear milestone gates.** Alpha/beta/gamma milestones have specific gating criteria, not vague "feature complete" definitions.
- **UX design discipline.** The deliberately narrow scope (FR83-FR95 only), the "resist the urge to become Fauxton" principle, and the prescriptive UX-DRs prevent feature creep in the admin UI.

### Final Note

This assessment identified **3 non-blocking recommendations** across **5 evaluation dimensions**. All planning artifacts are internally consistent and well-aligned. The project is ready to proceed to implementation.

**Assessment performed:** 2026-04-12
**Assessor:** Implementation Readiness Workflow (BMad)
**Report location:** `_bmad-output/planning-artifacts/implementation-readiness-report-2026-04-12.md`
