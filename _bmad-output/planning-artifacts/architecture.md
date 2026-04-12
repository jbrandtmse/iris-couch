---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
lastStep: 8
status: complete
completedDate: '2026-04-12'
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/product-brief-iris-couch.md
  - _bmad-output/planning-artifacts/prd-validation-report.md
  - _bmad-output/planning-artifacts/ux-design-specification.md
  - _bmad-output/planning-artifacts/research/technical-couchdb-on-iris-research-2026-04-10.md
  - _bmad-output/planning-artifacts/research/technical-couchdb-on-iris-summary-2026-04-11.md
  - docs/initial-prompt.md
workflowType: 'architecture'
project_name: 'iris-couch'
user_name: 'Developer'
date: '2026-04-11'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**
115 FRs across 11 subsystems, covering the full CouchDB 3.x wire-protocol surface. The requirements are organized as a capability contract — every downstream artifact (epics, stories, tests) must trace back to one or more FRs. The subsystems are: Database Lifecycle (FR1–FR8), Document Storage/Revisions/Conflicts (FR9–FR20), Document Listing & Changes Feed (FR21–FR30), Attachments (FR31–FR40), Mango Query & Indexing (FR41–FR50), Replication Protocol (FR51–FR59), Auth/Security (FR60–FR71), JSRuntime (FR72–FR82), Admin UI (FR83–FR95), Observability/Audit/Ops (FR96–FR105), Distribution/Installation/Docs (FR106–FR115).

**Non-Functional Requirements:**
53 NFRs across 8 categories that drive architectural decisions:
- **Performance (P1–P8):** Differential benchmarks against CouchDB 3.3.3 with hard limits (2× write latency, 1.5× read latency, 2× replication throughput). Zero-staleness read-after-write for Mango (P7). Attachment streaming without proportional RSS growth (P8).
- **Reliability (R1–R7):** Rev-tree corruption is the unshippable-defect class (R1). Atomic writes spanning globals + projection + audit (R2). Crash recovery via IRIS journal replay (R3). Checkpoint durability across hard kills (R4) and mirror failover (R5).
- **Security (S1–S9):** No shadow credential store (S1). PBKDF2 hashing (S2). HMAC cookie integrity (S3). Audit completeness (S5). Authorization enforcement at dispatch layer (S6). JSRuntime sandbox isolation (S9).
- **Scalability (SC1–SC5):** Validated envelope of ~10K docs, ~500 MB, low-tens concurrent writers (SC1). Async projection fallback behind feature flag (SC4). ECP clustering at γ (SC5).
- **Observability (O1–O6):** Prometheus/OTEL metrics refreshed ≤10s (O1). Bounded cardinality (O2). Actionable error reasons naming subsystem (O4). Synchronous audit events (O6).
- **Accessibility (A1–A4):** Keyboard navigability (A1). WCAG AA contrast (A2). Screen reader best-effort (A3).
- **Integration (I1–I6):** Three-layer conformance suite gates every release (I1). Zero-byte differential on wire-contract subset (I2).
- **Maintainability (M1–M8):** Customer-zero regression discipline (M1). Quality-gated release cadence (M8).

**Scale & Complexity:**

- Primary domain: API backend + developer tool
- Complexity level: High technical / medium domain
- Estimated architectural components: ~25–30 ObjectScript classes for the server engine, ~15–20 Angular components for the admin UI, plus test infrastructure and conformance harnesses
- Phased delivery: 8 phases (0–7) across 3 milestones (α, β, γ)

### Technical Constraints & Dependencies

1. **ObjectScript-only backend** — all server logic in InterSystems ObjectScript. No mixed-language implementation. External languages only for JSRuntime backends and test harnesses.
2. **Angular-only admin UI** — TypeScript + Angular SPA, pre-compiled to static assets. No runtime npm on target IRIS.
3. **Zero mandatory external dependencies at MVP default** — no Node.js, no Python, no couchjs, no Erlang. JSRuntime backends are operator-opt-in.
4. **IRIS platform features as the operational surface** — mirroring for HA, standard backup, journal replay for crash recovery, `%SYS.Audit` for audit trail, `%Service_WebGateway` for transport auth.
5. **CSP Gateway buffering limitation** — `feed=continuous` and `feed=eventsource` are blocked by the gateway's response buffering. Mitigated by `%Net.TCPServer` standalone listener at γ.
6. **CouchDB 3.3.3 as primary conformance anchor** through β; 3.5.x added at γ.
7. **Wire-protocol byte-compatibility on the conformance subset** — status codes, JSON error envelopes, sequence tokens, checkpoint shapes must match exactly.
8. **`IRISCouch.*` package prefix and `^IRISCouch.*` global prefix** — locked naming convention.
9. **Single-developer + AI coding agents team shape** — architecture must be clean enough for AI agents to implement consistently without committee coordination.
10. **Apache 2.0 license** — CouchDB source used as specification, not copied as code.

### Cross-Cutting Concerns Identified

1. **Wire-protocol conformance enforcement** — affects every HTTP endpoint. The differential harness, CouchDB JS test suite, and PouchDB replication tests gate every release. Architecture must make it easy to verify endpoint-by-endpoint compliance.
2. **Atomic transaction boundaries** — every document write must atomically update: document body global, revision tree global, changes feed sequence, Mango SQL projection, attachment streams (if applicable), and audit event. A single IRIS `TSTART`/`TCOMMIT` must span all of these.
3. **`_security` enforcement at dispatch** — admin/member access checks execute before any document logic. Architecture must cleanly separate the authorization layer from the document storage layer.
4. **Structured error envelopes** — every error path across all subsystems must produce `{"error":"<slug>","reason":"<specific>"}` with the correct HTTP status code. This is a cross-cutting contract that affects every class with an HTTP-facing method.
5. **`%SYS.Audit` integration** — synchronous audit events on every state-changing operation. Architecture must provide a clean audit-emission pattern that every write path calls consistently.
6. **Observability instrumentation** — Prometheus/OTEL metrics for request counts, latencies, replication throughput, changes lag, Mango index hit rates, error counters. Every endpoint class must emit metrics.
7. **Namespace-scoped state** — all IRISCouch globals, projection classes, streams, and configuration live within the webapp's IRIS namespace. Architecture must ensure no cross-namespace leakage. Multiple IRISCouch instances coexist in one IRIS installation via separate namespaces, each with its own web application and reverse proxy port.
8. **Pluggable JSRuntime dispatch** — the `IRISCouch.JSRuntime.Sandbox` interface is called from views, validate_doc_update, and custom _changes filters. Architecture must cleanly abstract this so the 501 default and the enabled backends are interchangeable.
9. **Admin UI as a CouchDB client** — the Angular SPA communicates with iris-couch exclusively through the same CouchDB-compatible HTTP API that external clients use. No private admin API.

## Starter Template Evaluation

### Primary Technology Domain

Dual-domain: InterSystems ObjectScript backend + Angular SPA admin UI. Both technology choices are locked scope non-negotiables from the PRD.

### Starter Options Considered

#### ObjectScript Backend

No starter template ecosystem exists for InterSystems ObjectScript projects. The backend is scaffolded from scratch using:
- The `IRISCouch.*` package prefix (locked)
- Global structure from research report (`^IRISCouch.Docs`, `.Tree`, `.Changes`, `.Seq`, `.Atts`, `.Local`)
- `%CSP.REST` dispatcher extending standard IRIS web application patterns
- ZPM module manifest (`module.xml`) for package distribution
- `%UnitTest.TestCase` for testing

The research report's Phase 0 scaffolding (package skeleton, REST router, utility classes, welcome endpoint) serves as the effective "starter."

#### Angular Admin UI

| Option | Verdict | Rationale |
|---|---|---|
| `ng new` with `--style=css --routing --ssr=false` | **Selected** | Minimal Angular CLI scaffold. SSR disabled (static SPA). CSS (not SCSS) matches the plain-CSS-with-custom-properties decision. |
| Angular Material starter (`ng add @angular/material`) | Rejected | Material's visual identity is an explicit anti-pattern per UX spec step 5. |
| PrimeNG starter | Rejected | Bootstrap/consumer aesthetic fights IRIS-native goal. |
| Nx monorepo | Rejected | Overkill for a single SPA with ~15–20 components and a solo-dev team. |
| Custom from scratch (no CLI) | Rejected | Loses Angular CLI tooling (build, test, serve) for no benefit. |

### Selected Foundation

**ObjectScript Backend — Manual Scaffold (Phase 0)**

Project structure:

```
iris-couch/
├── module.xml                          # ZPM package manifest
├── src/
│   └── IRISCouch/                      # ObjectScript class files only
│       ├── API/                        # REST dispatcher and endpoint handlers
│       ├── Core/                       # Document engine, revision tree, MVCC
│       ├── Storage/                    # Global read/write operations
│       ├── Query/                      # Mango selector parsing and SQL translation
│       ├── Projection/                 # Winners and MangoIndex projection classes
│       ├── Changes/                    # Changes feed engine
│       ├── Replication/                # Replication protocol implementation
│       ├── Attachment/                 # Attachment storage and streaming
│       ├── Auth/                       # Authentication and _security enforcement
│       ├── JSRuntime/                  # Pluggable JavaScript sandbox interface
│       ├── Util/                       # Shared utilities (JSON canonical, MD5, error envelopes)
│       ├── Metrics/                    # Prometheus/OTEL metric collection
│       ├── Audit/                      # %SYS.Audit event emission
│       └── Test/                       # %UnitTest.TestCase test classes
├── ui/                                 # Angular admin UI SPA
│   ├── src/
│   │   ├── app/
│   │   │   ├── couch-ui/              # Custom component layer (domain-free, ~15-20 components)
│   │   │   └── features/              # Per-journey feature modules
│   │   │       ├── databases/
│   │   │       ├── documents/
│   │   │       ├── design-docs/
│   │   │       ├── security/
│   │   │       └── revisions/
│   │   ├── assets/
│   │   │   └── fonts/                 # JetBrains Mono WOFF2
│   │   └── styles/
│   │       ├── tokens.css             # Design tokens (CSS custom properties)
│   │       └── global.css             # Reset and base typography
│   ├── angular.json
│   ├── package.json
│   └── tsconfig.json
├── examples/                           # FR115 — 6 working examples
│   ├── hello-document.md
│   ├── pouchdb-sync/
│   ├── replicate-from-couchdb.sh
│   ├── mango-query.md
│   ├── attachment-upload.md
│   └── jsruntime-subprocess-node/
├── docs/                               # Published documentation artifacts
│   ├── compatibility-matrix.md         # FR111
│   ├── deviations.md                   # FR112
│   ├── migration.md                    # FR113
│   └── troubleshooting.md              # FR114
├── test/                               # Conformance harnesses (external to ObjectScript)
│   ├── differential-harness/           # NFR-I2 — byte-diff against live CouchDB
│   ├── pouchdb-conformance/            # NFR-I1 — PouchDB replication tests
│   └── couchdb-js-tests/              # NFR-I1 — CouchDB's own JS test suite
├── README.md
└── LICENSE                             # Apache 2.0
```

**Angular Admin UI — `ng new` Minimal**

Initialization command:
```bash
ng new iris-couch-ui --style=css --routing --ssr=false --skip-tests=false
cd iris-couch-ui
ng add @angular/cdk
```

Post-initialization setup (per UX spec):
- Create `src/app/couch-ui/` — custom component layer (domain-free)
- Create `src/app/features/` — per-journey feature modules
- Add JetBrains Mono WOFF2 to `src/assets/fonts/`
- Hand-pick ~20 Lucide icons as standalone Angular SVG components

### Architectural Decisions Provided by Foundation

**Language & Runtime:**
- ObjectScript for all backend logic (IRIS runtime)
- TypeScript 5.x + Angular 19.x for admin UI (compile-time only)

**Styling Solution:**
- Plain CSS with custom-property design tokens (`tokens.css`)
- System font stack for proportional text (zero bytes loaded)
- JetBrains Mono WOFF2 for monospace (~30 KB)

**Build Tooling:**
- ObjectScript: IRIS compiler via `iris_doc_compile` MCP tool or `$System.OBJ.ImportDir`
- Angular: Angular CLI (`ng build --configuration=production`) — output committed as static assets in the ObjectScript package

**Testing Framework:**
- ObjectScript: `%UnitTest.TestCase` with `$$$Assert*` macros
- Angular: Angular CLI testing utilities (Karma/Jasmine default, replaceable with Jest if preferred)
- Conformance: Three-layer suite (CouchDB JS tests, PouchDB replication, differential HTTP harness) — external to both codebases

**Code Organization:**
- ObjectScript: package-per-subsystem under `IRISCouch.*`
- Angular: feature modules per operator journey under `src/app/features/`

**Development Experience:**
- ObjectScript: MCP tools for compile/execute/debug, `^ClineDebug` global for trace debugging
- Angular: `ng serve` for hot-reload development, compiled output committed for distribution

**Note:** ObjectScript Phase 0 scaffolding and Angular `ng new` initialization should be the first two implementation stories.

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Block Implementation):**
- Document body storage format (raw JSON string + process-private cache)
- Revision tree structure (hybrid: child→parent pointers + leaf index + winner cache)
- Winners projection design (separate key-value MangoIndex table, no runtime recompilation)
- REST router structure (thin Router + per-subsystem Handler classes)
- Transaction orchestration (DocumentEngine owns TSTART/TCOMMIT)

**Important Decisions (Shape Architecture):**
- Configuration management (class parameter defaults + global overrides)
- Admin UI build integration (committed dist/ + CI verification)

**Deferred Decisions (Post-MVP or Benchmark-Driven):**
- Async projection pipeline extraction — deferred until benchmarks demand it (NFR-SC4)
- ECP clustering safety patterns — deferred to γ (NFR-SC5)
- %Net.TCPServer streaming listener design — deferred to γ (FR28/FR29)

### Data Architecture

**Document Body Storage: Raw JSON String + Process-Private Cache**

Documents are stored as raw JSON strings in `^IRISCouch.Docs(db, docId, rev)`. On read, the JSON is parsed via `%DynamicObject.%FromJSON()`. During a single request that accesses the same document multiple times (e.g., `_bulk_get` with `open_revs`), the parsed `%DynamicObject` is cached in a process-private variable to avoid redundant parsing. The cache is discarded at end of request.

Rationale: debuggability is paramount for a wire-compat project. Raw JSON in globals means what you see in `ZWrite` is what the HTTP response will contain. Parse cost is negligible at customer-zero scale (~10K docs, typical doc <10KB). The process-private cache handles the multi-access case without adding persistent complexity.

**Revision Tree Structure: Hybrid Child→Parent + Leaf Index + Winner Cache**

```
^IRISCouch.Tree(db, docId, "R", childRev) = parentRev    // tree structure
^IRISCouch.Tree(db, docId, "L", leafRev)  = depth         // leaf index
^IRISCouch.Tree(db, docId, "W")           = winningRev    // winner cache
```

- **"R" (revision) nodes**: child→parent pointers. Backward traversal (leaf to root) is O(depth) via `$Get` chain — used for `?revs=true` (`_revisions` object).
- **"L" (leaf) nodes**: all current leaf revisions with their depth. Enumeration is instant via `$Order`. Enables O(1) conflict detection (`_conflicts`) and deterministic winning-rev calculation (longest path, lexicographic tiebreak).
- **"W" (winner) node**: cached winning revision, updated on every write. Every document read, every `_all_docs` row, every `_changes` entry, every Mango result reads this node — must be O(1).

On write: update "R" pointer, recalculate affected "L" leaves, recompute "W" winner — all inside the same `TSTART`/`TCOMMIT`. On `_revs_limit` pruning: walk "R" chain from leaf, kill nodes beyond limit, update "L" set.

**Winners Projection: Separate Key-Value MangoIndex Table**

```objectscript
Class IRISCouch.Projection.Winners Extends %Persistent
{
    Property DbName As %String;
    Property DocId As %String;
    Property WinningRev As %String;
    Property Deleted As %Boolean;
    Property Body As %String(MAXLEN="");
}

Class IRISCouch.Projection.MangoIndex Extends %Persistent
{
    Property DbName As %String;
    Property IndexName As %String;
    Property DocId As %String;
    Property FieldPath As %String;
    Property FieldValue As %String(MAXLEN="");
    
    Index IdxLookup On (DbName, IndexName, FieldPath, FieldValue, DocId);
}
```

- Mango `POST /{db}/_index` → records index definition as metadata, no DDL, no class recompilation
- Document write → for each active Mango index on that database, extract field values from the winning rev and upsert MangoIndex rows (inside the same transaction)
- Mango `POST /{db}/_find` → translates selector to SQL against MangoIndex, joins to Winners for full body
- Mango `POST /{db}/_explain` → reports which MangoIndex is selected and the generated SQL plan

Rationale: the research report specifically designed the two-class approach to avoid runtime class recompilation. MangoIndex rows are maintained synchronously in the write transaction (NFR-P7 zero-staleness guarantee). The write overhead is bounded by the number of active indexes per database.

### REST Router Design

**Thin Router + Per-Subsystem Handler Classes**

```
IRISCouch.API.Router              — UrlMap XData + dispatch only (~200 lines)
IRISCouch.API.ServerHandler       — GET /, /_uuids, /_all_dbs, /_up, /_active_tasks
IRISCouch.API.DatabaseHandler     — PUT/DELETE/GET /{db}, _compact, _ensure_full_commit, _revs_limit
IRISCouch.API.DocumentHandler     — GET/PUT/POST/DELETE /{db}/{docid}, _bulk_docs, _all_docs, _bulk_get
IRISCouch.API.ChangesHandler      — GET/POST /{db}/_changes
IRISCouch.API.AttachmentHandler   — GET/PUT/DELETE /{db}/{docid}/{attname}
IRISCouch.API.MangoHandler        — POST /{db}/_find, _index, _explain
IRISCouch.API.ReplicationHandler  — POST /{db}/_revs_diff, _local/* CRUD
IRISCouch.API.AuthHandler         — POST/GET/DELETE /_session, _users DB operations
IRISCouch.API.SecurityHandler     — GET/PUT /{db}/_security
IRISCouch.API.DesignHandler       — GET/PUT/DELETE /{db}/_design/*, _view/*
IRISCouch.API.AdminUIHandler      — GET /_utils/* (static asset serving)
```

The Router class contains the full `UrlMap` so the complete API surface is visible in one place. Each handler class is focused on one subsystem, stays under ~500 lines, and can be implemented/tested independently. Handler methods receive pre-parsed request context (database name, document ID, query parameters) from the Router's dispatch logic.

### Transaction Orchestration

**DocumentEngine Owns the Transaction (Pipeline Extraction Documented as Refactor Path)**

`IRISCouch.Core.DocumentEngine.Save()` is the single write orchestrator. It wraps all subsystem calls in a single `TSTART`/`TCOMMIT`:

```
DocumentEngine.Save(db, docId, body, rev, attachments)
  TSTART
  1. Storage.WriteBody(db, docId, newRev, body)
  2. Core.RevTree.Update(db, docId, parentRev, newRev) → updates R/L/W nodes
  3. Changes.Record(db, docId, newRev) → $Increment seq, write ^IRISCouch.Changes
  4. Projection.UpdateWinners(db, docId, newRev, body, deleted)
  5. Projection.UpdateMangoIndexes(db, docId, body) → for each active index
  6. Attachment.Store(db, docId, newRev, attachments) → if applicable
  7. Audit.EmitDocWrite(db, docId, newRev, user)
  TCOMMIT
```

Each subsystem method is stateless — receives parameters, performs its work, returns status. No subsystem method manages its own transaction. This makes each method independently testable and the full write sequence explicit in one place.

**Documented refactor path (NFR-SC4):** if post-α benchmarking reveals that synchronous Mango projection (steps 4–5) is a write throughput bottleneck, the orchestrator can be refactored into a pipeline where the projection stage is swappable between synchronous and async-with-bounded-lag. The refactor is mechanical because subsystem methods are already stateless and decoupled.

### Configuration Management

**Class Parameter Defaults + Global Overrides**

```objectscript
Class IRISCouch.Config
{
    Parameter JSRUNTIME = "None";
    Parameter JSRUNTIMESUBPROCESSPATH = "";
    Parameter JSRUNTIMETIMEOUT = 5000;
    Parameter METRICSENABLED = 1;
    Parameter REVSLIMITDEFAULT = 1000;
    
    ClassMethod Get(pKey As %String) As %String
    {
        // Global override takes precedence over class parameter default
        If $Data(^IRISCouch.Config(pKey), tVal) Quit tVal
        Quit ..GetDefault(pKey)
    }
}
```

- Class parameters document the full configuration schema with defaults — self-documenting, IDE-visible
- `^IRISCouch.Config` global overrides allow runtime changes without class recompilation
- `Get()` classmethod is the single config access point across the entire codebase
- Operators override at runtime: `Set ^IRISCouch.Config("JSRuntime") = "Subprocess"`
- Config globals mirror with the namespace automatically (HA)

### Admin UI Build Integration

**Committed dist/ + CI Verification**

The Angular SPA is built with `ng build --configuration=production` and the output is committed to `ui/dist/browser/`. The ZPM `module.xml` references this directory as static web resources mapped to `/_utils/`.

- Adopters never need Node.js, npm, or Angular CLI — pre-compiled assets ship in the ZPM package
- What's tagged in git is exactly what ships — no build-time variability
- CI runs `ng build` and verifies the committed `dist/` matches freshly-built output; divergence fails the build
- Bundle size is small (~200-300 KB gzipped for a ~15-component SPA) — git history cost is negligible

### Deployment Topology: Reverse Proxy as Recommended Model

**Rule:** IRISCouch application code generates all URLs relative to `/`. No handler, utility, or response-building method embeds the IRIS webapp mount path in generated URLs.

**Recommended deployment:** A reverse proxy (nginx or Apache) sits in front of the IRIS Web Gateway and presents IRISCouch at the URL root on a dedicated port. The proxy rewrites incoming requests from `/` to the IRIS webapp path (e.g., `/iris-couch/`).

```nginx
# Single instance — clients connect to port 5984, see standard CouchDB
server {
    listen 5984;
    location / {
        rewrite ^/(.*) /iris-couch/$1 break;
        proxy_pass http://localhost:52773;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

**Why:** CouchDB clients (PouchDB, Nano, Cradle) expect the server at `/`. CouchDB itself generates absolute URLs internally without prefix awareness — redirects, replication checkpoints, `_design` doc paths all assume root mount. This is a known CouchDB ecosystem limitation (see apache/couchdb#4635). CouchDB's own documentation recommends reverse proxy deployment.

**Multi-instance:** Multiple IRISCouch instances in one IRIS installation use separate namespaces, each with its own IRIS web application and proxy port:

```nginx
server { listen 5984; ... rewrite ^/(.*) /iriscouch-prod/$1 break; ... }
server { listen 5985; ... rewrite ^/(.*) /iriscouch-dev/$1 break; ... }
```

**Direct mount (without proxy):** Works for API clients that accept a base URL with a path prefix. Not recommended for PouchDB replication or clients that follow server-generated redirects. A future enhancement could add `%request.Application`-aware URL generation as an opt-in mode.

**Consistency rule for all subsystems:**
- `Location` headers on redirects: use root-relative paths (e.g., `/mydb`)
- `_changes` feed entries: no absolute URL prefixes
- Replication checkpoint references: root-relative
- Welcome JSON `GET /`: no prefix in any URI field
- Admin UI `CouchApiService`: base URL is `/`

### Decision Impact Analysis

**Implementation Sequence:**
1. Configuration management (`IRISCouch.Config`) — needed by everything else
2. REST Router + Handler skeleton — enables endpoint-by-endpoint development
3. Document body storage + revision tree — the core write path
4. DocumentEngine transaction orchestrator — wires the write path together
5. Changes feed engine — depends on write path
6. Winners projection + MangoIndex — depends on write path
7. Attachment storage — extends write path
8. Audit emission — extends write path
9. Auth + Security enforcement — wraps the dispatch layer
10. Admin UI scaffold — parallel track, independent of backend sequence

**Cross-Component Dependencies:**
- Every Handler class depends on `IRISCouch.Config` for runtime settings
- Every Handler class uses the same error envelope utility (`IRISCouch.Util.Error`)
- `DocumentEngine` depends on all storage/projection/changes/audit subsystems
- `MangoHandler` depends on `Projection.Winners` + `Projection.MangoIndex`
- `ReplicationHandler` depends on `DocumentEngine` (for `new_edits=false` writes), `ChangesHandler`, and `RevTree`
- `DesignHandler` depends on `JSRuntime.Sandbox` interface
- `AdminUIHandler` is independent — serves static files only

## Implementation Patterns & Consistency Rules

### Pattern Categories Defined

**8 critical conflict points identified** where AI agents working on different subsystems could make incompatible choices. Each pattern below is mandatory for all implementation work.

### Pattern 1: Error Envelope Construction

**Rule:** Never construct error JSON directly in Handler methods. Always use the shared utility.

```objectscript
/// Renders a CouchDB-compatible error envelope and sets HTTP status
ClassMethod Render(pStatus As %Integer, pSlug As %String, pReason As %String)
{
    Set %response.Status = pStatus
    Set %response.ContentType = "application/json"
    Set tObj = {"error": (pSlug), "reason": (pReason)}
    Write tObj.%ToJSON()
    Quit
}
```

**Location:** `IRISCouch.Util.Error`

**Usage:** Every Handler method calls `Do ##class(IRISCouch.Util.Error).Render(404, "not_found", "missing")` — never writes error JSON inline.

**Slug values** are constants from the PRD's Error Slug Table (13 slugs): `not_found`, `conflict`, `unauthorized`, `forbidden`, `bad_request`, `doc_validation`, `missing_stub`, `invalid_design_doc`, `file_exists`, `illegal_database_name`, `internal_server_error`, `not_implemented`, `partial`.

**Anti-pattern:** `Write "{""error"":""not_found""}"` anywhere in a Handler class.

### Pattern 2: Handler Method Signature

**Rule:** All Handler endpoint methods follow a consistent signature and request/response pattern.

```objectscript
/// Standard handler method pattern
ClassMethod HandleGetDocument(pDB As %String, pDocId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        // 1. Read query parameters
        Set tRev = %request.Get("rev")
        Set tConflicts = %request.Get("conflicts")
        
        // 2. Business logic (delegate to Core/Storage)
        Set tDoc = ##class(IRISCouch.Storage.Document).Get(pDB, pDocId, tRev)
        
        // 3. Success response
        Do ##class(IRISCouch.Util.Response).JSON(tDoc)
    }
    Catch ex {
        // 4. Error response via standard utility
        Do ##class(IRISCouch.Util.Error).Render(500, "internal_server_error", ex.DisplayString())
    }
    Quit tSC
}
```

**Conventions:**
- First parameter is `pDB As %String` when URL includes `{db}`
- Request body read via `##class(IRISCouch.Util.Request).ReadBody()` returning `%DynamicObject`
- Query parameters via `%request.Get("param")`
- Success responses via `IRISCouch.Util.Response.JSON(pData)` or `.JSONStatus(pStatus, pData)`
- Every method returns `%Status`
- Try/Catch wraps all business logic

### Pattern 3: Global Access Encapsulation

**Rule:** Direct global `Set`/`$Get`/`$Order`/`$Data`/`Kill` on `^IRISCouch.*` globals is allowed ONLY inside `IRISCouch.Storage.*` classes. All other classes call Storage methods.

**Storage classes and their globals:**

| Storage Class | Globals Owned |
|---|---|
| `IRISCouch.Storage.Document` | `^IRISCouch.Docs` |
| `IRISCouch.Storage.RevTree` | `^IRISCouch.Tree` |
| `IRISCouch.Storage.Changes` | `^IRISCouch.Changes`, `^IRISCouch.Seq` |
| `IRISCouch.Storage.Local` | `^IRISCouch.Local` |
| `IRISCouch.Storage.Database` | `^IRISCouch.DB` |
| `IRISCouch.Storage.Attachment` | `^IRISCouch.Atts` (via `%Stream.GlobalBinary`) |

**Anti-pattern:** `Set ^IRISCouch.Docs(db, docId, rev) = body` in a Handler or Core class.

**Exception:** `IRISCouch.Config.Get()` reads `^IRISCouch.Config` directly — this is the only non-Storage global access allowed.

### Pattern 4: ObjectScript Class File Organization

**Rule:** Consistent class structure across all iris-couch ObjectScript classes.

```objectscript
/// <summary>
/// One-line description of what this class does.
/// </summary>
/// <p>Longer description of the class's role in the architecture,
/// which subsystem it belongs to, and what other classes it collaborates with.</p>
Class IRISCouch.Subsystem.ClassName
{

/// Public API methods first (alphabetical within access level)

/// Private helper methods below (prefixed with %% or marked Private)

}
```

**Conventions:**
- One `.cls` file per class
- Max ~500 lines per class — split into focused classes if larger
- Public API methods at top, private helpers below
- Class-level `///` doc comment with HTML/DocBook markup explaining architectural role
- Method-level `///` doc comments on all public methods
- Parameters follow ObjectScript naming: `p` prefix (e.g., `pDocId`)
- Local variables: `t` prefix (e.g., `tResult`)
- Properties: capitalized, no prefix (e.g., `DocId`)

### Pattern 5: Test Organization

**Rule:** One test class per subsystem, co-located under `IRISCouch.Test.*`.

**Naming convention:** `IRISCouch.Test.<Subsystem>Test`

```
IRISCouch.Test.StorageDocumentTest    — tests for Storage.Document
IRISCouch.Test.RevTreeTest            — tests for Core.RevTree / Storage.RevTree
IRISCouch.Test.ChangesTest            — tests for Changes engine
IRISCouch.Test.ProjectionTest         — tests for Winners + MangoIndex
IRISCouch.Test.DocumentEngineTest     — tests for the write orchestrator
IRISCouch.Test.MangoSelectorTest      — tests for Mango selector → SQL translation
IRISCouch.Test.ReplicationTest        — tests for replication protocol
IRISCouch.Test.AuthTest               — tests for authentication and _security
IRISCouch.Test.ErrorEnvelopeTest      — tests for wire-compat error responses
IRISCouch.Test.ConfigTest             — tests for configuration management
```

**Conventions:**
- Every test class extends `%UnitTest.TestCase`
- Test methods named `Test<Scenario>` (e.g., `TestCreateDocument`, `TestConflictDetection`, `TestStaleRevReturns409`)
- `OnBeforeOneTest` creates a fresh test database and cleans all `^IRISCouch.*` globals for it
- `OnAfterOneTest` cleans up the test database
- Max ~500 lines per test class — split into focused test classes if larger
- Use `$$$AssertEquals`, `$$$AssertTrue`, `$$$AssertStatusOK` macros (never method-style assertions)

### Pattern 6: Audit Emission

**Rule:** All audit events flow through a single utility. No direct `%SYS.Audit` calls outside `IRISCouch.Audit`.

```objectscript
ClassMethod Emit(pEventType As %String, pDB As %String, pDocId As %String = "", pRev As %String = "", pUser As %String = "")
```

**Event type constants:**

| Constant | Used by |
|---|---|
| `"DocWrite"` | DocumentEngine.Save() — create/update |
| `"DocDelete"` | DocumentEngine.Save() — delete (tombstone) |
| `"SecurityChange"` | SecurityHandler — PUT /{db}/_security |
| `"AuthSuccess"` | AuthHandler — successful _session / Basic / JWT |
| `"AuthFailure"` | AuthHandler — failed authentication |
| `"UserWrite"` | AuthHandler — _users database document write |
| `"ReplicationStart"` | ReplicationHandler — replication session begins |
| `"ReplicationComplete"` | ReplicationHandler — replication session ends |

**Anti-pattern:** Calling `%SYS.Audit` directly from a Handler or Storage class.

### Pattern 7: Metrics Instrumentation

**Rule:** Metrics are recorded by the Router's dispatch wrapper, not by individual Handlers.

The Router wraps every handler dispatch call:

```
1. Record start timestamp
2. Call handler method
3. Record end timestamp
4. Call IRISCouch.Metrics.Record(endpoint, method, status, duration)
```

**`IRISCouch.Metrics.Record()` signature:**

```objectscript
ClassMethod Record(pEndpoint As %String, pMethod As %String, pStatus As %Integer, pDuration As %Numeric)
```

- `pEndpoint` uses coarse categories (bounded cardinality per NFR-O2): `"server"`, `"database"`, `"document"`, `"changes"`, `"attachment"`, `"mango"`, `"replication"`, `"auth"`, `"security"`, `"design"`, `"admin_ui"`
- Never uses document ID or database name as a metric label (unbounded cardinality)
- Individual Handlers do NOT call `Metrics.Record()` — the Router does it for them

**Exception:** Replication-specific throughput metrics (docs/sec, bytes/sec) are recorded by `ReplicationHandler` because they track cumulative session metrics, not per-request.

### Pattern 8: Angular Component Patterns

**Rule:** Consistent component structure across all admin UI feature modules.

**Feature module structure:**
```
features/databases/
├── databases-list.component.ts      // list view
├── databases-list.component.html
├── databases-list.component.css
├── databases-detail.component.ts    // detail/info view
├── databases-detail.component.html
├── databases-detail.component.css
└── databases-routing.module.ts
```

**Conventions:**
- Components use `OnPush` change detection strategy
- All API calls go through a shared `CouchApiService` that wraps `HttpClient` with the iris-couch base URL and session cookie
- API error responses are passed through unchanged — the `ErrorDisplay` component renders the server's `reason` verbatim
- No client-side transformation of server data (no renaming `_rev` to `revision`, no rounding numbers, no date formatting beyond ISO-8601)
- State is managed via Angular signals or simple RxJS observables — no NgRx, no state management library

### Enforcement Guidelines

**All AI Agents MUST:**

1. Use `IRISCouch.Util.Error.Render()` for every error response — never inline error JSON
2. Use `IRISCouch.Util.Response.JSON()` for every success response — never write JSON directly
3. Access globals only through `IRISCouch.Storage.*` classes — never raw `Set`/`$Get` outside Storage
4. Emit audit events only through `IRISCouch.Audit.Emit()` — never call `%SYS.Audit` directly
5. Follow the Handler method signature pattern — `pDB` first, Try/Catch, return `%Status`
6. Keep classes under ~500 lines — split into focused classes if larger
7. Write test methods as `Test<Scenario>` in the corresponding `IRISCouch.Test.*` class
8. Use coarse endpoint categories for metrics — never document IDs or database names as labels

**Pattern Verification:**
- Code review checks for direct global access outside Storage classes
- Code review checks for inline error JSON construction
- Test classes verify error envelope shape for every error path
- `IRISCouch.Test.ErrorEnvelopeTest` exercises all 13 error slugs against the slug table

## Project Structure & Boundaries

### Complete Project Directory Structure

```
iris-couch/
├── module.xml                                    # ZPM package manifest
├── LICENSE                                       # Apache 2.0
├── README.md
├── .gitignore
├── .github/
│   └── workflows/
│       ├── ci.yml                                # ObjectScript compile + unit tests
│       └── ui-verify.yml                         # Verify committed ui/dist/ matches ng build
│
├── src/
│   └── IRISCouch/
│       ├── API/
│       │   ├── Router.cls                        # %CSP.REST UrlMap + dispatch wrapper
│       │   ├── ServerHandler.cls                 # GET /, /_uuids, /_all_dbs, /_up
│       │   ├── DatabaseHandler.cls               # PUT/DELETE/GET /{db}, _compact, _revs_limit
│       │   ├── DocumentHandler.cls               # CRUD /{db}/{docid}, _bulk_docs, _all_docs, _bulk_get
│       │   ├── ChangesHandler.cls                # GET/POST /{db}/_changes
│       │   ├── AttachmentHandler.cls             # GET/PUT/DELETE /{db}/{docid}/{attname}
│       │   ├── MangoHandler.cls                  # POST /{db}/_find, _index, _explain
│       │   ├── ReplicationHandler.cls            # POST /{db}/_revs_diff, _local/* CRUD
│       │   ├── AuthHandler.cls                   # POST/GET/DELETE /_session
│       │   ├── SecurityHandler.cls               # GET/PUT /{db}/_security
│       │   ├── DesignHandler.cls                 # /{db}/_design/*, _view/*
│       │   └── AdminUIHandler.cls                # GET /_utils/* static asset serving
│       │
│       ├── Core/
│       │   ├── DocumentEngine.cls                # Write orchestrator (TSTART/TCOMMIT)
│       │   ├── RevTree.cls                       # Revision tree logic (merge, winner calc, pruning)
│       │   └── WinningRev.cls                    # Deterministic winning-rev algorithm
│       │
│       ├── Storage/
│       │   ├── Document.cls                      # ^IRISCouch.Docs read/write
│       │   ├── RevTree.cls                       # ^IRISCouch.Tree read/write (R/L/W nodes)
│       │   ├── Changes.cls                       # ^IRISCouch.Changes, ^IRISCouch.Seq
│       │   ├── Local.cls                         # ^IRISCouch.Local (_local/ checkpoints)
│       │   ├── Database.cls                      # ^IRISCouch.DB (database metadata)
│       │   └── Attachment.cls                    # ^IRISCouch.Atts (%Stream.GlobalBinary)
│       │
│       ├── Query/
│       │   ├── MangoSelector.cls                 # Mango selector parser
│       │   ├── MangoNormalizer.cls                # Selector canonicalization
│       │   ├── MangoToSQL.cls                    # Selector → IRIS SQL translation
│       │   └── MangoPlanner.cls                  # Index selection and query planning
│       │
│       ├── Projection/
│       │   ├── Winners.cls                       # %Persistent — winning rev SQL projection
│       │   ├── MangoIndex.cls                    # %Persistent — key-value index table
│       │   └── MangoIndexDef.cls                 # Index definition metadata storage
│       │
│       ├── Changes/
│       │   ├── Feed.cls                          # Changes feed engine (normal + longpoll)
│       │   ├── Filter.cls                        # Built-in filters (_doc_ids, _selector, _design)
│       │   └── Longpoll.cls                      # Longpoll wait/notify mechanism
│       │
│       ├── Replication/
│       │   ├── RevsDiff.cls                      # _revs_diff implementation
│       │   ├── BulkGet.cls                       # _bulk_get with open_revs + multipart/mixed
│       │   ├── Checkpoint.cls                    # _local/ checkpoint management
│       │   ├── ReplicationId.cls                 # JSON-canonical MD5 replication_id generation
│       │   └── Replicator.cls                    # _replicator database state machine
│       │
│       ├── Attachment/
│       │   ├── Store.cls                         # Attachment storage via %Stream.GlobalBinary
│       │   ├── MIMEReader.cls                    # Multipart/related request parsing
│       │   ├── MIMEWriter.cls                    # Multipart/mixed response generation
│       │   └── Digest.cls                        # MD5 digest computation
│       │
│       ├── Auth/
│       │   ├── Session.cls                       # _session cookie auth (HMAC)
│       │   ├── Basic.cls                         # HTTP Basic auth
│       │   ├── JWT.cls                           # JWT bearer token validation
│       │   ├── Proxy.cls                         # X-Auth-CouchDB-* proxy auth
│       │   ├── Users.cls                         # _users database ↔ IRIS Security.Users sync
│       │   └── Security.cls                      # _security admin/member enforcement
│       │
│       ├── JSRuntime/
│       │   ├── Sandbox.cls                       # Abstract interface for JS execution
│       │   ├── None.cls                          # Default — returns 501 for all JS ops
│       │   ├── Subprocess.cls                    # Node/Bun/Deno/couchjs via $ZF(-1)
│       │   └── Python.cls                        # %SYS.Python + QuickJS (secondary)
│       │
│       ├── Util/
│       │   ├── Error.cls                         # Error envelope rendering (slug + reason)
│       │   ├── Response.cls                      # Success response helpers
│       │   ├── Request.cls                       # Request body/param parsing
│       │   ├── JSON.cls                          # JSON canonicalization for rev hashes
│       │   ├── UUID.cls                          # Hex UUID generation (/_uuids)
│       │   └── Hash.cls                          # MD5 hashing ($System.Encryption.MD5Hash)
│       │
│       ├── Metrics/
│       │   ├── Collector.cls                     # In-process metric accumulation
│       │   ├── Endpoint.cls                      # Prometheus/OTEL scrape endpoint handler
│       │   └── Record.cls                        # Per-request metric recording
│       │
│       ├── Audit/
│       │   └── Emit.cls                          # %SYS.Audit event emission
│       │
│       ├── Config.cls                            # Class parameter defaults + global overrides
│       │
│       └── Test/
│           ├── StorageDocumentTest.cls
│           ├── RevTreeTest.cls
│           ├── ChangesTest.cls
│           ├── ProjectionTest.cls
│           ├── DocumentEngineTest.cls
│           ├── MangoSelectorTest.cls
│           ├── ReplicationTest.cls
│           ├── AuthTest.cls
│           ├── ErrorEnvelopeTest.cls
│           ├── ConfigTest.cls
│           └── AttachmentTest.cls
│
├── ui/                                           # Angular admin UI SPA
│   ├── angular.json
│   ├── package.json
│   ├── package-lock.json
│   ├── tsconfig.json
│   ├── tsconfig.app.json
│   ├── tsconfig.spec.json
│   ├── src/
│   │   ├── index.html
│   │   ├── main.ts
│   │   ├── app/
│   │   │   ├── app.component.ts
│   │   │   ├── app.routes.ts
│   │   │   ├── couch-ui/                        # Custom component layer (~15-20 components)
│   │   │   │   ├── app-shell/
│   │   │   │   ├── side-nav/
│   │   │   │   ├── breadcrumb/
│   │   │   │   ├── page-header/
│   │   │   │   ├── data-table/
│   │   │   │   ├── pagination/
│   │   │   │   ├── button/
│   │   │   │   ├── text-input/
│   │   │   │   ├── badge/
│   │   │   │   ├── empty-state/
│   │   │   │   ├── error-display/
│   │   │   │   ├── copy-button/
│   │   │   │   ├── confirm-dialog/
│   │   │   │   ├── login-form/
│   │   │   │   └── json-display/
│   │   │   ├── features/
│   │   │   │   ├── databases/
│   │   │   │   │   ├── databases-list.component.ts
│   │   │   │   │   ├── databases-list.component.html
│   │   │   │   │   ├── databases-list.component.css
│   │   │   │   │   ├── databases-detail.component.ts
│   │   │   │   │   ├── databases-detail.component.html
│   │   │   │   │   ├── databases-detail.component.css
│   │   │   │   │   └── databases-routing.module.ts
│   │   │   │   ├── documents/
│   │   │   │   │   ├── documents-list.component.*
│   │   │   │   │   ├── documents-detail.component.*
│   │   │   │   │   └── documents-routing.module.ts
│   │   │   │   ├── design-docs/
│   │   │   │   │   ├── design-docs-list.component.*
│   │   │   │   │   ├── design-docs-detail.component.*
│   │   │   │   │   └── design-docs-routing.module.ts
│   │   │   │   ├── security/
│   │   │   │   │   ├── security-view.component.*
│   │   │   │   │   └── security-routing.module.ts
│   │   │   │   └── revisions/                   # γ scope
│   │   │   │       ├── revisions-view.component.*
│   │   │   │       └── revisions-routing.module.ts
│   │   │   └── services/
│   │   │       ├── couch-api.service.ts          # HttpClient wrapper for iris-couch API
│   │   │       └── auth.service.ts               # _session cookie management
│   │   ├── assets/
│   │   │   └── fonts/
│   │   │       └── jetbrains-mono.woff2
│   │   └── styles/
│   │       ├── tokens.css                        # Design tokens (≤50 CSS custom properties)
│   │       └── global.css                        # Reset + base typography
│   └── dist/                                     # Committed ng build output
│       └── browser/
│           ├── index.html
│           ├── main-[hash].js
│           ├── styles-[hash].css
│           └── assets/
│
├── examples/
│   ├── hello-document.md                         # FR115
│   ├── pouchdb-sync/
│   ├── replicate-from-couchdb.sh
│   ├── mango-query.md
│   ├── attachment-upload.md
│   └── jsruntime-subprocess-node/
│
├── docs/
│   ├── compatibility-matrix.md                   # FR111
│   ├── deviations.md                             # FR112
│   ├── migration.md                              # FR113
│   └── troubleshooting.md                        # FR114
│
└── test/                                         # External conformance harnesses
    ├── differential-harness/                     # NFR-I2
    ├── pouchdb-conformance/                      # NFR-I1
    └── couchdb-js-tests/                         # NFR-I1
```

### Architectural Boundaries

**API Boundary (HTTP Surface):**
The `IRISCouch.API.Router` class is the single entry point for all HTTP traffic. No class outside `IRISCouch.API.*` writes to `%response` or reads from `%request`. Handler classes translate between HTTP and internal method calls — they never contain business logic.

**Storage Boundary (Global Access):**
Only `IRISCouch.Storage.*` classes touch `^IRISCouch.*` globals directly. All other subsystems call Storage methods. This boundary enables future storage-layer changes (e.g., ECP safety at γ) without touching business logic.

**Core Boundary (Business Logic):**
`IRISCouch.Core.*` classes contain business logic (revision tree algorithms, winning-rev calculation, write orchestration). They depend on Storage for persistence and are called by API Handlers. They never touch `%request`/`%response`.

**Projection Boundary (SQL Read Path):**
`IRISCouch.Projection.*` classes are `%Persistent` and are the only classes accessed via IRIS SQL. `IRISCouch.Query.*` classes translate Mango selectors into SQL queries against these projections. No other subsystem issues SQL.

**JSRuntime Boundary (Pluggable Interface):**
`IRISCouch.JSRuntime.Sandbox` is the abstract interface. `None`, `Subprocess`, and `Python` are concrete implementations. Only `IRISCouch.API.DesignHandler` and `IRISCouch.Changes.Filter` call the Sandbox interface. No other class is aware of the JS runtime.

**Admin UI Boundary (Static SPA):**
The Angular SPA communicates exclusively through the CouchDB-compatible HTTP API. There is no private admin API, no server-side rendering, no ObjectScript-to-Angular coupling. `AdminUIHandler` serves static files only.

### Requirements to Structure Mapping

**FR Category → Directory:**

| FR Category | FRs | Primary Directory |
|---|---|---|
| Database Lifecycle | FR1–FR8 | `API/DatabaseHandler`, `Storage/Database` |
| Document Storage/Revisions | FR9–FR20 | `API/DocumentHandler`, `Core/DocumentEngine`, `Core/RevTree`, `Storage/Document`, `Storage/RevTree` |
| Document Listing & Changes | FR21–FR30 | `API/ChangesHandler`, `Changes/Feed`, `Changes/Filter`, `Changes/Longpoll` |
| Attachments | FR31–FR40 | `API/AttachmentHandler`, `Attachment/Store`, `Attachment/MIMEReader`, `Attachment/MIMEWriter` |
| Mango Query & Indexing | FR41–FR50 | `API/MangoHandler`, `Query/*`, `Projection/*` |
| Replication Protocol | FR51–FR59 | `API/ReplicationHandler`, `Replication/*` |
| Auth & Security | FR60–FR71 | `API/AuthHandler`, `API/SecurityHandler`, `Auth/*` |
| JSRuntime | FR72–FR82 | `API/DesignHandler`, `JSRuntime/*` |
| Admin UI | FR83–FR95 | `ui/src/app/features/*`, `API/AdminUIHandler` |
| Observability & Ops | FR96–FR105 | `Metrics/*`, `Audit/Emit` |
| Distribution & Docs | FR106–FR115 | `module.xml`, `docs/*`, `examples/*` |

**Cross-Cutting Concerns → Location:**

| Concern | Classes |
|---|---|
| Error envelopes | `Util/Error.cls` — called by every Handler |
| Response formatting | `Util/Response.cls` — called by every Handler |
| Request parsing | `Util/Request.cls` — called by every Handler |
| Configuration | `Config.cls` — called by every subsystem |
| Audit events | `Audit/Emit.cls` — called by DocumentEngine, AuthHandler, SecurityHandler, ReplicationHandler |
| Metrics recording | `Metrics/Record.cls` — called by Router dispatch wrapper |
| _security enforcement | `Auth/Security.cls` — called by Router before Handler dispatch |

### Data Flow

**Document Write Path:**
```
HTTP PUT /{db}/{docid}
  → Router (auth check via Auth/Security, start metrics timer)
    → DocumentHandler.HandlePutDocument()
      → DocumentEngine.Save()
        TSTART
        → Storage.Document.Write()         → ^IRISCouch.Docs
        → Storage.RevTree.Update()         → ^IRISCouch.Tree (R/L/W)
        → Storage.Changes.Record()         → ^IRISCouch.Changes + ^IRISCouch.Seq
        → Projection.Winners.Update()      → SQL table
        → Projection.MangoIndex.Update()   → SQL table (per active index)
        → Storage.Attachment.Store()       → ^IRISCouch.Atts (if applicable)
        → Audit.Emit("DocWrite")           → %SYS.Audit
        TCOMMIT
      ← return new rev
    ← Util.Response.JSONStatus(201, {"ok":true, "id":..., "rev":...})
  ← Router records metrics
```

**Mango Query Read Path:**
```
HTTP POST /{db}/_find
  → Router (auth check, metrics)
    → MangoHandler.HandleFind()
      → Query.MangoSelector.Parse(selector)
      → Query.MangoNormalizer.Normalize(parsed)
      → Query.MangoPlanner.SelectIndex(normalized, db)
      → Query.MangoToSQL.Translate(normalized, selectedIndex)
      → Execute SQL against Projection.MangoIndex + Projection.Winners
      ← return matching documents
    ← Util.Response.JSON({"docs": [...]})
```

**Replication Pull Path (remote CouchDB → IRISCouch):**
```
Remote CouchDB replicator:
  1. GET /{db}/_changes?since=N       → ChangesHandler → Changes.Feed
  2. POST /{db}/_revs_diff            → ReplicationHandler → Replication.RevsDiff
  3. POST /{db}/_bulk_get             → ReplicationHandler → Replication.BulkGet
  4. POST /{db}/_bulk_docs (new_edits=false) → DocumentHandler → DocumentEngine.Save()
  5. PUT /{db}/_local/{checkpoint}    → ReplicationHandler → Storage.Local
```

## Architecture Validation Results

### Coherence Validation ✅

**Decision Compatibility:**
All architectural decisions are mutually compatible. Raw JSON storage + process-private cache integrates cleanly with the DocumentEngine orchestrator. The hybrid revision tree (R/L/W nodes) stays in sync with the Winners projection inside the same `TSTART`/`TCOMMIT`. The thin Router + Handler pattern aligns with the Storage encapsulation boundary — Handlers call Core/Storage methods, never globals directly. Config class with global overrides is compatible with all subsystems calling `Config.Get()`.

**Pattern Consistency:**
All 8 implementation patterns support the architectural decisions. The error envelope pattern covers all 13 slugs from the PRD's Error Slug Table. The Handler method signature pattern is consistent with the Router dispatch wrapper for metrics instrumentation. The Storage encapsulation boundary (Pattern 3) enforces the architectural boundary between API/Core and Storage layers.

**Structure Alignment:**
The directory structure supports every architectural decision. Each FR category maps to specific directories. Cross-cutting concerns (error, response, request, config, audit, metrics) each have a single-class home. Test classes map 1:1 to subsystems.

### Requirements Coverage Validation ✅

**Functional Requirements Coverage (115 FRs, 11 subsystems):**

| Subsystem | FRs | Architectural Support | Status |
|---|---|---|---|
| Database Lifecycle | FR1–FR8 | DatabaseHandler + Storage.Database | ✅ |
| Document Storage/Revisions | FR9–FR20 | DocumentHandler + DocumentEngine + RevTree + Storage.Document + Storage.RevTree | ✅ |
| Listing & Changes | FR21–FR30 | ChangesHandler + Changes.Feed + Changes.Filter + Changes.Longpoll | ✅ |
| Attachments | FR31–FR40 | AttachmentHandler + Attachment.Store + MIMEReader + MIMEWriter | ✅ |
| Mango Query | FR41–FR50 | MangoHandler + Query.* + Projection.* | ✅ |
| Replication | FR51–FR59 | ReplicationHandler + Replication.* + Storage.Local | ✅ |
| Auth & Security | FR60–FR71 | AuthHandler + SecurityHandler + Auth.* | ✅ |
| JSRuntime | FR72–FR82 | DesignHandler + JSRuntime.Sandbox/None/Subprocess/Python | ✅ |
| Admin UI | FR83–FR95 | AdminUIHandler + ui/ Angular SPA | ✅ |
| Observability & Ops | FR96–FR105 | Metrics.* + Audit.Emit + Config (mirroring/backup inherited from IRIS) | ✅ |
| Distribution & Docs | FR106–FR115 | module.xml + docs/* + examples/* | ✅ |

**Non-Functional Requirements Coverage (53 NFRs, 8 categories):**

| NFR Category | Key NFRs | Architectural Support | Status |
|---|---|---|---|
| Performance | P1–P8 | CQRS hybrid, process-private cache, streaming attachments via %Stream.GlobalBinary | ✅ |
| Reliability | R1–R7 | DocumentEngine atomic TSTART/TCOMMIT, IRIS journal replay, checkpoint durability | ✅ |
| Security | S1–S9 | Auth.* translation layer over IRIS Security.*, no shadow credentials, JSRuntime sandbox isolation | ✅ |
| Scalability | SC1–SC5 | Documented async-projection refactor path (SC4), ECP deferred to γ (SC5) | ✅ |
| Observability | O1–O6 | Metrics.* with Router wrapper, bounded cardinality labels, Audit.Emit synchronous in transaction | ✅ |
| Accessibility | A1–A4 | Angular CDK a11y module, WCAG AA palette locked in UX spec | ✅ |
| Integration | I1–I6 | Three conformance harnesses in test/, error envelope pattern enforces wire-compat | ✅ |
| Maintainability | M1–M8 | ~500-line class limit, ///  doc comments, customer-zero regression discipline | ✅ |

### Implementation Readiness Validation ✅

**Decision Completeness:**
All critical decisions are documented with rationale. Technology versions are locked (ObjectScript on IRIS, Angular 19.x + TypeScript 5.x for UI). The 5 data/infrastructure decisions and 8 implementation patterns cover every area where AI agents could diverge.

**Structure Completeness:**
The project tree specifies every directory and ~50 ObjectScript classes by name and purpose. The Angular UI structure specifies feature modules, component layer, services, and asset organization. FR-to-directory mapping is explicit for all 11 subsystems.

**Pattern Completeness:**
All 8 patterns include concrete code examples, anti-patterns, and enforcement rules. The patterns cover the critical divergence points: error construction, handler signatures, global access, class organization, test structure, audit emission, metrics recording, and Angular components.

### Gap Analysis Results

**Critical Gaps: 0**

**Important Gaps (2 — resolved):**

1. **`_bulk_docs` with `new_edits=false` replication writes.** The DocumentEngine.Save() orchestrator is designed for normal writes. Replication's `new_edits=false` mode grafts external revision histories without generating new revs.
   **Resolution:** `DocumentEngine.SaveWithHistory()` as a parallel method to `Save()` — same TSTART/TCOMMIT transaction pattern, same subsystem calls, but the RevTree logic grafts incoming revisions instead of appending a new child. This is an implementation-level method variant, not an architectural change.

2. **Longpoll notification mechanism.** `Changes.Longpoll` needs to wake waiting clients when a new write commits. The architecture didn't specify the signaling mechanism.
   **Resolution:** Use IRIS `$System.Event` (named events). After TCOMMIT in DocumentEngine, post an event keyed by database name. Longpoll waits on that event with a configurable timeout. Simple, in-process, no polling, no external dependencies. Event name format: `"IRISCouch:changes:" _ pDB`.

**Nice-to-Have Gaps (1 — deferred by design):**

1. **View engine architecture for JSRuntime.** FR49/FR50 (view queries, built-in reduces) and FR80 (incremental view indexes) need a view index storage and build mechanism. This is Phase 5 (β) scope. The JSRuntime.Sandbox interface is in place as the extension point; the view engine will be designed when Phase 5 begins. No architectural change needed — the boundary is clean.

### Architecture Completeness Checklist

**✅ Requirements Analysis**

- [x] Project context thoroughly analyzed (115 FRs, 53 NFRs, 5 user journeys)
- [x] Scale and complexity assessed (high technical / medium domain)
- [x] Technical constraints identified (10 constraints documented)
- [x] Cross-cutting concerns mapped (9 concerns documented)

**✅ Architectural Decisions**

- [x] Data architecture: raw JSON + process-private cache, hybrid rev tree, separate MangoIndex
- [x] REST design: thin Router + 12 per-subsystem Handlers
- [x] Transaction orchestration: DocumentEngine owns TSTART/TCOMMIT
- [x] Configuration: class parameter defaults + global overrides
- [x] Admin UI build: committed dist/ + CI verification
- [x] Deferred decisions documented with triggers (async projection, ECP, streaming listener)

**✅ Implementation Patterns**

- [x] 8 patterns covering all critical divergence points
- [x] Concrete code examples for each pattern
- [x] Anti-patterns documented
- [x] Enforcement guidelines specified

**✅ Project Structure**

- [x] Complete directory structure with ~50 named ObjectScript classes
- [x] Angular UI structure with feature modules and component layer
- [x] 5 architectural boundaries defined and enforced
- [x] FR-to-directory mapping for all 11 subsystems
- [x] 3 data flow diagrams (write path, Mango read path, replication pull)

### Architecture Readiness Assessment

**Overall Status:** READY FOR IMPLEMENTATION

**Confidence Level:** High — all 168 requirements (115 FRs + 53 NFRs) have explicit architectural support, all critical decisions are made, and 0 critical gaps remain.

**Key Strengths:**
- CQRS hybrid is a well-validated pattern backed by the research report's spike results
- Storage encapsulation boundary (Pattern 3) protects against global-access sprawl as the codebase grows
- DocumentEngine atomic transaction ensures NFR-R2 (no partial writes) by construction
- Thin Router + focused Handlers enables parallel subsystem development by independent AI agents
- 8 implementation patterns prevent the most likely agent-divergence scenarios

**Areas for Future Enhancement:**
- View engine architecture (Phase 5/β scope — JSRuntime.Sandbox interface is the extension point)
- ECP clustering safety patterns (Phase 7/γ scope — Storage boundary isolates the change)
- %Net.TCPServer streaming listener design (Phase 7/γ scope — separate port, separate handler)
- Async projection fallback (benchmark-driven — DocumentEngine refactor path documented)

### Implementation Handoff

**AI Agent Guidelines:**

1. Follow all architectural decisions exactly as documented in this architecture
2. Use all 8 implementation patterns consistently — especially Pattern 1 (error envelopes), Pattern 3 (storage encapsulation), and Pattern 5 (test organization)
3. Respect the 5 architectural boundaries — API, Storage, Core, Projection, JSRuntime
4. Refer to this document for all architectural questions before making independent choices
5. When in doubt about a pattern, check the anti-pattern examples — they document the most common mistakes

**First Implementation Priority (Phase 0 scaffolding):**
1. `IRISCouch.Config` — needed by everything else
2. `IRISCouch.Util.Error`, `IRISCouch.Util.Response`, `IRISCouch.Util.Request` — cross-cutting utilities
3. `IRISCouch.API.Router` with `UrlMap` + `IRISCouch.API.ServerHandler` — `GET /` welcome endpoint
4. `module.xml` ZPM manifest
5. `IRISCouch.Test.ConfigTest` + `IRISCouch.Test.ErrorEnvelopeTest` — first tests

**Exit criterion for Phase 0:** `GET /` returns a valid CouchDB welcome JSON response; `/_uuids?count=3` returns hex UUIDs; the ZPM package compiles cleanly on a fresh IRIS instance.

