# IRISCouch

> Wire-compatible Apache CouchDB 3.x server, native to InterSystems IRIS — offline-first replication without a second database.

## 🚧 Pre-Alpha

IRISCouch is under active development toward Milestone Alpha. The core foundation (configuration, HTTP routing, UUID generation, error handling, and installer) is implemented. The repository contains both planning artifacts and working ObjectScript code.

- **[Product Requirements Document](_bmad-output/planning-artifacts/prd.md)** — 115 functional requirements, measurable success criteria, five narrative user journeys, and the complete capability contract for the MVP
- **[Product Brief](_bmad-output/planning-artifacts/product-brief-iris-couch.md)** — vision, positioning, and origin story
- **[Technical Research](_bmad-output/planning-artifacts/research/)** — 2,039-line feasibility study covering architecture, wire-protocol compatibility, and risk analysis

The first public release will be **Milestone Alpha**, which will deliver the core document API, replication protocol, Mango queries, and zero-dependency installation via ZPM/IPM.

## What is IRISCouch?

IRISCouch is an open-source, wire-compatible Apache CouchDB 3.x server implemented natively in InterSystems IRIS ObjectScript. Existing CouchDB clients — PouchDB, the Apache CouchDB replicator, Cloudant SDKs, Fauxton, `nano` — connect to IRISCouch and cannot tell they are not talking to real CouchDB. The HTTP API, replication protocol, Mango query language, MVCC revision model, attachments, and authentication surface all behave exactly as CouchDB 3.x does on the wire. What lives underneath is pure IRIS: raw multi-dimensional globals on the write path, a synchronously-maintained IRIS SQL projection on the Mango read path, `%Stream.GlobalBinary` for attachments, `%CSP.REST` for the HTTP layer. No Erlang, no CouchDB binary, no second database process.

The product exists because teams already running IRIS — and especially HealthShare deployments — currently have no path to CouchDB's offline-first sync model except standing up a second database alongside IRIS. Two engines, two backup strategies, two monitoring dashboards, two credential stores, two upgrade windows. IRISCouch delivers the CouchDB wire protocol from inside IRIS, so existing PouchDB clients and replication jobs keep working unchanged and the standalone CouchDB process can be retired.

## Why This One Won't Stall

Every prior CouchDB reimplementation (BigCouch, rcouch, couch4j, kivik) tried to build a database engine *and* a wire protocol layer from scratch, and each ran out of maintainer bandwidth before reaching production parity. IRISCouch inverts the scope boundary: the wire protocol is the entire deliverable, and the database engine underneath is already shipped as IRIS. Storage, durability, SQL query planning, backup, journaling, HA, clustering, and cache management are IRIS's responsibility, not ours. The project's scope is just the protocol surface — not a database.

IRISCouch is also anchored by a real in-house migration: three production CouchDB databases the author's own team will retire onto IRISCouch. Every release is exercised against that real workload before any public tag. Correctness is a personal problem before it is a public one.

## Project Status

**Quality-gated, not calendar-gated.** There is no fixed ship date. A replication bug that could corrupt a conflict tree is an unshippable defect, full stop.

The PRD commits to three milestone checkpoints within a single MVP:

- **α — Public Alpha.** Full document CRUD, `_bulk_docs`, `_all_docs`, attachments, `normal`/`longpoll` `_changes`, Mango `_find`/`_index`/`_explain`, replication against a real Apache CouchDB peer. Zero mandatory external dependencies. JS-based views and validators return 501 with clear error messages. This is when the project goes public.
- **β — Customer Zero Complete.** `JSRuntime.Subprocess` production-ready; full authentication surface (`_session` cookie auth, `_users`, Basic/JWT/proxy auth); the author's three production CouchDB databases are served by IRISCouch with existing clients unchanged and the standalone Apache CouchDB process is retired.
- **γ — MVP Feature-Complete.** Streaming `_changes` feeds via a standalone TCP listener; ECP distributed-cache clustering; conformance harness green against both CouchDB 3.3.3 and 3.5.x. Every non-deprecated item in the CouchDB 3.x feature inventory is either delivered or explicitly documented as out of scope with a reason.

See the [PRD § Project Scoping & Phased Development Strategy](_bmad-output/planning-artifacts/prd.md) for the full milestone plan and risk register.

## Roadmap

14 epics across three milestones. Quality-gated, not calendar-gated.

### Milestone Alpha — Public Alpha

| Epic | Description | Stories | Tests | Status |
|------|-------------|---------|-------|--------|
| 1 | Project Foundation & Server Identity | 5/5 | 25 | Done |
| 2 | Database Lifecycle Management | 4/4 | 57 | Done |
| 3 | Document Storage & Revision Control | 7/7 | 122 | Done |
| 4 | Real-Time Change Tracking | 4/4 | 162 | Done |
| 5 | Binary Attachment Management | 4/4 | 208 | Done |
| 6 | Mango Query Engine | 3/3 | 309 | Done |
| 7 | Authentication & Authorization | 6/6 | 376 | Done |
| 8 | Replication Protocol | 0/5 | — | Backlog |
| 9 | Observability & Audit Trail | 0/3 | — | Backlog |
| 10 | Admin UI — Core Experience | 0/7 | — | Backlog |
| 11 | Admin UI — Design Docs & Security | 0/4 | — | Backlog |
| 12 | Pluggable JavaScript Runtime | 0/5 | — | Backlog |
| 13 | Documentation & Working Examples | 0/3 | — | Backlog |

**Progress:** 7/13 epics complete — 376 tests passing, 0 failures, 0 regressions across 7 consecutive epics.

### Milestone Beta — Customer Zero Complete

Adds on top of Alpha: design document and security editing in the Admin UI (Epic 11 stories), HMAC cookie auth byte-compat, and validation against the author's three production CouchDB databases.

### Milestone Gamma — MVP Feature-Complete (1.0)

| Epic | Description | Status |
|------|-------------|--------|
| 14 | Streaming Feeds & ECP Clustering | Backlog |

Adds continuous/eventsource `_changes` feeds via standalone TCP listener, ECP distributed-cache clustering, revision history UI, and CouchDB 3.5.x conformance.

## Relationship to IRIS DocDB

InterSystems' own IRIS DocDB feature exposes a proprietary `/api/docdb/v1` REST surface; it does not speak the CouchDB HTTP API, does not implement Mango, and does not participate in the CouchDB replication protocol. IRISCouch complements IRIS DocDB rather than competing with it — they occupy different slots in the IRIS ecosystem.

## Distribution

- **License:** [Apache 2.0](LICENSE) — matches Apache CouchDB and InterSystems community convention
- **Target package manager:** ZPM / IPM (`zpm "install iris-couch"`) — planned for α
- **Compatibility anchor:** Apache CouchDB 3.3.3 through β; CouchDB 3.5.x added at γ
- **Smoke-tested clients (planned):** PouchDB 9.x, Apache CouchDB replicator, `nano` 10.x, `@cloudant/cloudant` 5.x, Fauxton

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

   **Alternative: Management Portal manual setup**
   - Navigate to **System Administration > Security > Applications > Web Applications**
   - Click **Create New Web Application**
   - Set **Name** to `/iris-couch/`
   - Set **Namespace** to your target namespace (e.g., `IRISCOUCH`)
   - Set **Dispatch Class** to `IRISCouch.API.Router`
   - Enable **Password** authentication
   - Check **Enabled**
   - Click **Save**

4. **Verify the installation:**
   ```bash
   curl http://localhost:52773/iris-couch/
   ```
   Expected response:
   ```json
   {"couchdb":"Welcome","vendor":{"name":"IRISCouch"},"version":"0.1.0"}
   ```

### Uninstall

To remove the web application programmatically:
```objectscript
Do ##class(IRISCouch.Installer).Uninstall("/iris-couch/")
```

## Contributing

The project is currently built by a single developer working with AI coding agents on a quality-gated cadence, and external contributions are **not actively courted during the pre-α window**. The repository is public and the code is Apache 2.0 — you are free to fork, read, and follow along. Pull requests may sit without merge until α ships.

If you are running a production Apache CouchDB instance alongside InterSystems IRIS and would consider IRISCouch as a potential off-ramp, please open a GitHub issue describing your workload shape (approximate document count, attachment volume, query patterns, JS view usage). Adopter signals are valuable even before code exists.
