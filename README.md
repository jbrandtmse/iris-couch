# IRISCouch

> Wire-compatible Apache CouchDB 3.x server, native to InterSystems IRIS — offline-first replication without a second database.

## 🚧 Pre-Alpha

IRISCouch is under active development toward Milestone Alpha. The full backend is implemented (Epics 1–9): document CRUD, revision trees, attachments, changes feeds, Mango queries, authentication (cookie/JWT/proxy/basic), bidirectional CouchDB replication, Prometheus metrics, audit trail, and operational resilience. The built-in admin UI is implemented (Epics 10–11): database management, document browsing, design document CRUD, security editing, revision history visualization, and role-based access control — all served directly from IRIS at `/_utils/` with zero external dependencies.

- **[Product Requirements Document](_bmad-output/planning-artifacts/prd.md)** — 115 functional requirements, measurable success criteria, five narrative user journeys, and the complete capability contract for the MVP
- **[Product Brief](_bmad-output/planning-artifacts/product-brief-iris-couch.md)** — vision, positioning, and origin story
- **[Technical Research](_bmad-output/planning-artifacts/research/)** — 2,039-line feasibility study covering architecture, wire-protocol compatibility, and risk analysis

The first public release will be **Milestone Alpha**, which will deliver the core document API, replication protocol, Mango queries, admin UI, and zero-dependency installation via ZPM/IPM.

## What is IRISCouch?

IRISCouch is an open-source, wire-compatible Apache CouchDB 3.x server implemented natively in InterSystems IRIS ObjectScript. Existing CouchDB clients — PouchDB, the Apache CouchDB replicator, Cloudant SDKs, Fauxton, `nano` — connect to IRISCouch and cannot tell they are not talking to real CouchDB. The HTTP API, replication protocol, Mango query language, MVCC revision model, attachments, and authentication surface all behave exactly as CouchDB 3.x does on the wire. What lives underneath is pure IRIS: raw multi-dimensional globals on the write path, a synchronously-maintained IRIS SQL projection on the Mango read path, `%Stream.GlobalBinary` for attachments, `%CSP.REST` for the HTTP layer. No Erlang, no CouchDB binary, no second database process.

The product exists because teams already running IRIS — and especially HealthShare deployments — currently have no path to CouchDB's offline-first sync model except standing up a second database alongside IRIS. Two engines, two backup strategies, two monitoring dashboards, two credential stores, two upgrade windows. IRISCouch delivers the CouchDB wire protocol from inside IRIS, so existing PouchDB clients and replication jobs keep working unchanged and the standalone CouchDB process can be retired.

## Why This One Won't Stall

Every prior CouchDB reimplementation (BigCouch, rcouch, couch4j, kivik) tried to build a database engine *and* a wire protocol layer from scratch, and each ran out of maintainer bandwidth before reaching production parity. IRISCouch inverts the scope boundary: the wire protocol is the entire deliverable, and the database engine underneath is already shipped as IRIS. Storage, durability, SQL query planning, backup, journaling, HA, clustering, and cache management are IRIS's responsibility, not ours. The project's scope is just the protocol surface — not a database.

IRISCouch is also anchored by a real in-house migration: three production CouchDB databases the author's own team will retire onto IRISCouch. Every release is exercised against that real workload before any public tag. Correctness is a personal problem before it is a public one.

## Project Status

**Quality-gated, not calendar-gated.** There is no fixed ship date. A replication bug that could corrupt a conflict tree is an unshippable defect, full stop.

The PRD commits to three milestone checkpoints within a single MVP:

- **α — Public Alpha.** Full document CRUD, `_bulk_docs`, `_all_docs`, attachments, `normal`/`longpoll` `_changes`, Mango `_find`/`_index`/`_explain`, replication against a real Apache CouchDB peer, built-in admin UI at `/_utils/` with role-based access control. Zero mandatory external dependencies. JS-based views and validators return 501 with clear error messages. This is when the project goes public.
- **β — Customer Zero Complete.** `JSRuntime.Subprocess` production-ready; the author's three production CouchDB databases are served by IRISCouch with existing clients unchanged and the standalone Apache CouchDB process is retired.
- **γ — MVP Feature-Complete.** Streaming `_changes` feeds via a standalone TCP listener; ECP distributed-cache clustering; conformance harness green against both CouchDB 3.3.3 and 3.5.x. Every non-deprecated item in the CouchDB 3.x feature inventory is either delivered or explicitly documented as out of scope with a reason.

See the [PRD § Project Scoping & Phased Development Strategy](_bmad-output/planning-artifacts/prd.md) for the full milestone plan and risk register.

## Roadmap

14 epics across three milestones. Quality-gated, not calendar-gated.

### Milestone Alpha — Public Alpha

| Epic | Description | Stories | Backend Tests | UI Specs | Status |
|------|-------------|---------|---------------|----------|--------|
| 1 | Project Foundation & Server Identity | 5/5 | 25 | — | Done |
| 2 | Database Lifecycle Management | 4/4 | 57 | — | Done |
| 3 | Document Storage & Revision Control | 7/7 | 122 | — | Done |
| 4 | Real-Time Change Tracking | 4/4 | 162 | — | Done |
| 5 | Binary Attachment Management | 4/4 | 208 | — | Done |
| 6 | Mango Query Engine | 3/3 | 309 | — | Done |
| 7 | Authentication & Authorization | 6/6 | 376 | — | Done |
| 8 | Replication Protocol | 6/6 | 455 | — | Done |
| 9 | Observability & Audit Trail | 4/4 | 497 | — | Done |
| 10 | Admin UI — Core Experience | 8/8 | 497 | 422 | Done |
| 11 | Admin UI — Design Docs, Security & Hosting | 6/6 | 507 | 678 | Done |
| 12 | Pluggable JavaScript Runtime | 5/5 + 12.4 deferred | ~850 | — | Done |
| 13 | Documentation & Working Examples | 3/3 + 13.0 + 13.4 | — | — | Done |

**Progress:** 13/13 Alpha+Beta epics complete (Epic 13 shipped 13.0 Epic-12-deferred cleanup + 13.1 Getting Started guide & Compatibility Matrix + 13.2 Deviations / Migration / Troubleshooting + 13.3 Working code examples + 13.4 Deferred backlog cleanup & trailing-slash fix) — ~850 backend ObjectScript assertions + 688 Angular UI specs passing, 0 failures, 0 regressions across 13 consecutive epics; only Epic 14 Gamma (streaming feeds + ECP clustering) remains in the backlog. The 2026-04-18 acceptance-pass backlog closed in Story 13.4 — HIGH section of deferred-work.md back to 0 open items, MED section down by 5 (RBAC bypass, timeout classification, 405 vs 404, remaining double-envelope sites, UI spec URL-prefix sweep). Story 12.4 (Python JSRuntime backend) is deferred to a future milestone pending a Python-enabled IRIS image; see [JavaScript Runtime Requirements](#javascript-runtime-requirements) for the operator-facing implication. Release-gate enforcement for the `examples/` tree: the `examples/run-all.sh` harness runs dev-host-local before each tag; GitHub Actions CI wiring is deferred to an α/β infra story (see [deferred-work.md § Story 13.3](_bmad-output/implementation-artifacts/deferred-work.md)). Adopters: start at the [Getting Started guide](documentation/getting-started.md), the [Compatibility Matrix](documentation/compatibility-matrix.md), and the [Working Examples](examples/README.md); for production migration see the [Migration Playbook](documentation/migration.md) and [Troubleshooting Runbook](documentation/troubleshooting.md).

### Milestone Beta — Customer Zero Complete

Adds on top of Alpha: Pluggable JavaScript runtime for views and validators (Epic 12), documentation and working examples (Epic 13). Validation against the author's three production CouchDB databases.

### Milestone Gamma — MVP Feature-Complete (1.0)

| Epic | Description | Status |
|------|-------------|--------|
| 14 | Streaming Feeds & ECP Clustering | Backlog |

Adds continuous/eventsource `_changes` feeds via standalone TCP listener, ECP distributed-cache clustering, and CouchDB 3.5.x conformance.

## Relationship to IRIS DocDB

InterSystems' own IRIS DocDB feature exposes a proprietary `/api/docdb/v1` REST surface; it does not speak the CouchDB HTTP API, does not implement Mango, and does not participate in the CouchDB replication protocol. IRISCouch complements IRIS DocDB rather than competing with it — they occupy different slots in the IRIS ecosystem.

## Distribution

- **License:** [Apache 2.0](LICENSE) — matches Apache CouchDB and InterSystems community convention
- **Target package manager:** ZPM / IPM (`zpm "install iris-couch"`) — planned for α
- **Compatibility anchor:** Apache CouchDB 3.3.3 through β; CouchDB 3.5.x added at γ
- **Smoke-tested clients (planned):** PouchDB 9.x, Apache CouchDB replicator, `nano` 10.x, `@cloudant/cloudant` 5.x, Fauxton

## Documentation

Operator- and adopter-facing documentation lives under `documentation/`:

- **[Getting Started Guide](documentation/getting-started.md)** — fresh IRIS to a working PouchDB replication in under one hour. Install, topology options (reverse-proxy or direct mount), create-a-database, write-a-document, browser + Node PouchDB snippets, JSRuntime configuration, troubleshooting.
- **[Compatibility Matrix](documentation/compatibility-matrix.md)** — every CouchDB 3.x HTTP endpoint grouped by family, each marked `supported` / `supported with caveat` / `501 in default config` / `out of scope with reason` with a named verification method (HTTP integration test, manual `curl` probe, replicator parity test). JSRuntime-aware endpoints (views, validate, filters) document all three backend states (`None` / `Subprocess` / `Python-deferred`).
- **[Deviations Log](documentation/deviations.md)** — every operator-observable difference between IRISCouch and CouchDB 3.x with a named rationale. NFR-M4: an unlogged deviation is a release-blocking defect.
- **[Migration Playbook](documentation/migration.md)** — eight-phase playbook for retiring a production Apache CouchDB instance onto IRISCouch, with per-step success/failure criteria and a symmetric rollback narrative.
- **[Troubleshooting Runbook](documentation/troubleshooting.md)** — five canonical incident classes (replication lag, checkpoint corruption, stuck conflicts, attachment stream failures, JS sandbox errors) each with Symptoms / Diagnostic steps / Resolution / Prevention.
- **[JSRuntime Backends](documentation/js-runtime.md)** — detailed semantics for the pluggable JavaScript runtime: Subprocess entry script, sandbox flags, timeout enforcement, pool API, known limitations.
- **[Working Examples](examples/README.md)** — six runnable integrations (`hello-document`, `pouchdb-sync`, `replicate-from-couchdb`, `mango-query`, `attachment-upload`, `jsruntime-subprocess-node`) with a `run-all` harness that is the release-gate enforcement mechanism (per Story 13.3 AC #4; GitHub Actions CI wiring deferred to α/β infra).

The planning-artifact links at the top of this README (PRD, Product Brief, Technical Research) remain the canonical product documentation; the `documentation/` tree adds adopter- and operator-facing guides on top.

## JavaScript Runtime Requirements

**For Alpha and Beta milestones, Node is the only supported JavaScript runtime for design-document execution.**

IRISCouch ships with three pluggable `JSRuntime` backends — `None`, `Subprocess`, and `Python` — but only `None` and `Subprocess` are production-ready at α/β:

| Backend | α/β Status | What it runs | Install requirement |
|---------|-----------|--------------|---------------------|
| `None` (default) | ✅ Ships | Nothing — returns `501 not_implemented` for every JS-dependent path | None |
| `Subprocess` | ✅ Ships | Node, Bun, Deno, or any JS interpreter that can execute the vendored `documentation/couchjs/couchjs-entry.js` | **Node 18+ (or Bun 1+, Deno 1.40+) installed on the IRIS host**; path configured via `^IRISCouch.Config("JSRUNTIMESUBPROCESSPATH")` |
| `Python` | ⏳ Deferred | JS via IRIS embedded Python + `quickjs` / `py_mini_racer` | Requires a Python-enabled IRIS build with `irispip install quickjs`. **Not shipping at α/β** — see Story 12.4 |

**Operators who cannot install a Node-compatible JS runtime must use `JSRUNTIME=None` and will lose these CouchDB features until γ or later:**

- 🚫 **Map/reduce view queries** — `GET /{db}/_design/{ddoc}/_view/{view}` returns `501 not_implemented`. Built-in reduces (`_sum`, `_count`, `_stats`, `_approx_count_distinct`) are native ObjectScript and still work once a runtime is present, but user-supplied map functions require JS execution.
- 🚫 **`validate_doc_update` enforcement** — Document writes against a database whose design docs define `validate_doc_update` return `501 not_implemented`. Databases without validate functions still accept writes normally; this restriction is per-database, not server-wide.
- 🚫 **Custom changes-feed filters** — `GET /{db}/_changes?filter={ddoc}/{filtername}` returns `501 not_implemented`. **Built-in filters (`_doc_ids`, `_selector`, `_design`) are native and work unchanged** — the restriction only affects user-supplied filter functions referenced by `{ddoc}/{name}`.

**What still works under `JSRUNTIME=None`:**

- All document CRUD (`PUT`/`GET`/`DELETE` including `_bulk_docs`, `_bulk_get`, `_all_docs`)
- Attachments (`PUT`/`GET`/`DELETE` including inline, multipart, and standalone)
- `_changes` feed (normal + longpoll) with built-in filters
- Mango `_find`, `_index`, `_explain` (native ObjectScript, does not use JS)
- Authentication (session, basic, JWT, proxy)
- Bidirectional replication against Apache CouchDB peers
- Admin UI at `/_utils/`
- Prometheus/OTEL metrics and audit events
- Design documents themselves — they **store and replicate** regardless of the JSRuntime setting, so migration staging (importing design docs into a runtime-less target before enabling execution) is supported

**Why Python is deferred:** the Python backend requires IRIS to be built against a Python runtime library (`PythonRuntimeLibrary` CPF field) with a compatible Python version (3.11 or 3.12 recommended; 3.13 is known problematic). Many IRIS images — including several InterSystems-packaged ones — ship without Python enabled by default. Rather than gate the α/β public release on a runtime re-build, we ship Subprocess as the single supported JS path and track Python re-enablement as a follow-up story. When it resumes, Story 12.4 must ship zero `[Language = python]` methods in any IRISCouch `.cls` file (compile-time Python dependency would break installation on Python-less IRIS) — all Python interaction goes through `%SYS.Python.Import()` at runtime against a file-copy Python bridge.

**View query parameters not yet supported (Story 12.2a follow-up):** view execution via `Subprocess` currently supports `reduce` and `include_docs` query parameters. The following CouchDB 3.x view-query parameters are **not yet implemented** and are deferred to Story 12.2a:

- `group=true` / `group_level=N` — grouped reduce results (single-group reduce works; per-key grouping does not)
- `startkey=<json>` / `endkey=<json>` / `inclusive_end=false` — range filtering on emitted keys
- `limit=N` / `skip=N` — pagination

Clients that submit these parameters today will receive the full, ungrouped, unfiltered result set. Pagination and range filtering must be done client-side until 12.2a lands. The compatibility matrix in Epic 13 will mark these rows `supported with caveat — 12.2a pending`.

**Other known deviations from CouchDB 3.x (Story 12.2):**

- **View-key collation:** emitted keys are sorted via lexicographic JSON string compare. CouchDB's `couch_ejson_compare` has richer cross-type collation semantics (e.g., numeric `10` sorts after numeric `2`, not before like lexicographic would). For mixed-type keys the two orderings can differ.
- **`_approx_count_distinct`:** native implementation returns an exact distinct count (simple `$Order`-based). CouchDB uses HyperLogLog for large-cardinality estimation. Results are byte-identical for small cardinality; for very large result sets the IRISCouch value is more accurate but computed differently.

## Installation

### Option 1: ZPM / IPM (Recommended)

If ZPM is available on your IRIS instance:

```
zpm "install iris-couch"
```

### Option 2: Manual Import

For environments where ZPM is not installed:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/jbrandtmse/iris-couch.git
   ```

2. **Import classes into your target namespace** (e.g., `IRISCOUCH`):
   ```objectscript
   Do $System.OBJ.ImportDir("C:\path\to\iris-couch\src\IRISCouch\", , "ck", , 1)
   ```
   - Replace the path with the actual location of your cloned repository.
   - On Linux/macOS: `Do $System.OBJ.ImportDir("/path/to/iris-couch/src/IRISCouch/", , "ck", , 1)`
   - The `"ck"` flags mean compile + keep source. The final `1` enables recursive import of subdirectories.

3. **Create the web application** (programmatic method):
   ```objectscript
   Do ##class(IRISCouch.Installer).Install($Namespace, "/iris-couch/")
   ```
   This creates the web application, registers audit events, and creates the `IRISCouch_Admin` role (granting it to the installing user and `_SYSTEM`).

4. **Verify the installation:**
   ```bash
   curl http://localhost:52773/iris-couch/
   ```
   Expected response:
   ```json
   {"couchdb":"Welcome","vendor":{"name":"IRISCouch"},"version":"0.1.0"}
   ```

5. **Access the Admin UI:**
   Open `http://localhost:52773/iris-couch/_utils/` in a browser. Sign in with your IRIS credentials. The admin UI requires the `IRISCouch_Admin` role — the installer grants this to the installing user automatically. To grant access to additional users:
   ```objectscript
   ; In the %SYS namespace:
   Do ##class(Security.Users).AddRoles("username", "IRISCouch_Admin")
   ```

### Uninstall

To remove the web application programmatically:
```objectscript
Do ##class(IRISCouch.Installer).Uninstall("/iris-couch/")
```

## Contributing

The project is currently built by a single developer working with AI coding agents on a quality-gated cadence, and external contributions are **not actively courted during the pre-α window**. The repository is public and the code is Apache 2.0 — you are free to fork, read, and follow along. Pull requests may sit without merge until α ships.

If you are running a production Apache CouchDB instance alongside InterSystems IRIS and would consider IRISCouch as a potential off-ramp, please open a GitHub issue describing your workload shape (approximate document count, attachment volume, query patterns, JS view usage). Adopter signals are valuable even before code exists.
