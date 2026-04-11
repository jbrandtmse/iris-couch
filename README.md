# IRISCouch

> Wire-compatible Apache CouchDB 3.x server, native to InterSystems IRIS — offline-first replication without a second database.

## 🚧 Under Construction

IRISCouch is actively being planned and will soon be under active development. **No implementation code has been committed yet.** The repository currently contains planning artifacts only.

- **[Product Requirements Document](_bmad-output/planning-artifacts/prd.md)** — 115 functional requirements, measurable success criteria, five narrative user journeys, and the complete capability contract for the MVP
- **[Product Brief](_bmad-output/planning-artifacts/product-brief-iris-couch.md)** — vision, positioning, and origin story
- **[Technical Research](_bmad-output/planning-artifacts/research/)** — 2,039-line feasibility study covering architecture, wire-protocol compatibility, and risk analysis

The first code-bearing release will be **Milestone α (Public Alpha)**, which will deliver the core document API, replication protocol, Mango queries, and zero-dependency installation via ZPM/IPM. Until then, this README is the only thing you can actually run.

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

## Relationship to IRIS DocDB

InterSystems' own IRIS DocDB feature exposes a proprietary `/api/docdb/v1` REST surface; it does not speak the CouchDB HTTP API, does not implement Mango, and does not participate in the CouchDB replication protocol. IRISCouch complements IRIS DocDB rather than competing with it — they occupy different slots in the IRIS ecosystem.

## Distribution

- **License:** [Apache 2.0](LICENSE) — matches Apache CouchDB and InterSystems community convention
- **Target package manager:** ZPM / IPM (`zpm "install iris-couch"`) — planned for α
- **Compatibility anchor:** Apache CouchDB 3.3.3 through β; CouchDB 3.5.x added at γ
- **Smoke-tested clients (planned):** PouchDB 9.x, Apache CouchDB replicator, `nano` 10.x, `@cloudant/cloudant` 5.x, Fauxton

## Contributing

The project is currently built by a single developer working with AI coding agents on a quality-gated cadence, and external contributions are **not actively courted during the pre-α window**. The repository is public and the code is Apache 2.0 — you are free to fork, read, and follow along. Pull requests may sit without merge until α ships.

If you are running a production Apache CouchDB instance alongside InterSystems IRIS and would consider IRISCouch as a potential off-ramp, please open a GitHub issue describing your workload shape (approximate document count, attachment volume, query patterns, JS view usage). Adopter signals are valuable even before code exists.
