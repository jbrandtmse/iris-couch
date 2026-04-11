---
title: CouchPort — Research Summary (Executive One-Pager)
type: research-summary
parent_doc: technical-couchdb-on-iris-research-2026-04-10.md
date: 2026-04-11
author: Mary (BMad Analyst)
---

# CouchPort — Research Summary

A wire-compatible Apache CouchDB 3.x server implemented natively in
InterSystems ObjectScript, using a CQRS hybrid (globals for writes, IRIS SQL
projection for Mango reads). This one-pager condenses the 2,039-line research
report into what you need to decide whether to commit to Phase 0.

---

## Verdict

**Feasible, with zero mandatory external dependencies beyond IRIS itself.**
The biggest risks (rev-hash byte-compat, replication_id byte-compat, ETF
encoder) are all eliminated. Two known limitations are confirmed and
mitigated by scope (continuous-feed `_changes`) or by phasing (JS view
execution). Every MUST-have feature for replication compatibility with
PouchDB, the CouchDB replicator, and Cloudant SDKs is in scope.

---

## Five architectural decisions

1. **CQRS hybrid storage**
   - Writes go to raw IRIS globals: `^CouchPort.Docs`, `.Tree`, `.Changes`,
     `.Seq` (via `$Increment`), `.Atts` (`%Stream.GlobalBinary`), `.Local`.
   - Mango reads go through a `%Persistent` shadow table
     (`CouchPort.Projection.Winners`) + a runtime index table
     (`CouchPort.Projection.MangoIndex`) maintained synchronously on every
     write. No runtime class recompilation for new Mango indexes.

2. **Rev hash and replication_id: our own algorithm, not CouchDB's**
   - CouchDB's algorithms use Erlang ETF (`term_to_binary`), which would take
     days to reproduce in ObjectScript.
   - Source-spike proven: CouchDB **does not verify** either hash on the read
     path. Both are opaque-to-client structural identifiers.
   - CouchPort uses a JSON-canonical MD5 (`CouchPort.Util.Json.Canonicalize` +
     `$System.Encryption.MD5Hash`). Hours of implementation, not days.
   - Interop: fully correct. Mixing replicator clients costs one re-replication
     from seq 0 on algorithm migration; everything else is transparent.

3. **ObjectScript-only engine + pluggable JSRuntime backend**
   - Engine (storage, MVCC, replication, changes, Mango, attachments, auth) is
     pure ObjectScript.
   - User-supplied JS (view map/reduce, `validate_doc_update`, custom filters)
     lives behind a single interface: `CouchPort.JSRuntime.Sandbox`.
   - Three backends, operator-selected via config parameter:
     - `JSRuntime.None` — **MVP default**, returns 501 for JS ops
     - `JSRuntime.Subprocess` — Phase 1b, spawns Node/Bun/Deno/couchjs via
       `$ZF(-1)`, implements CouchDB's couchjs line protocol
     - `JSRuntime.Python` — Phase 1b secondary, PetterS quickjs + `%SYS.Python`
   - **Zero mandatory dependencies in MVP**. Install ObjectScript, go.

4. **REST layer on `%CSP.REST` + Apache mod_csp**
   - `normal` + `longpoll` changes feeds ✅ fully supported
   - `continuous` + `eventsource` ❌ gateway buffers, return 501
   - **This does not hurt replication compat**: PouchDB and the CouchDB
     replicator default to longpoll / normal.
   - Phase 7 option: standalone `%Net.TCPServer` listener on a separate port
     for true streaming, if real demand materializes.

5. **Attachments via `%Stream.GlobalBinary` + `%Net.MIMEReader`**
   - Live-test confirmed: MIMEReader parses `multipart/related` from a stream
     without buffering the full body in memory. Safe for GB-scale attachments.

---

## Feature scope — 120 MVP items across 11 subsystems

| Subsystem | MVP Coverage |
|---|---|
| Server endpoints (`/`, `/_all_dbs`, `/_uuids`, `/_up`, `/_session`, etc.) | full |
| Database endpoints (create, drop, info, `_bulk_docs`, `_all_docs`, `_security`, `_revs_limit`, `_compact`, `_ensure_full_commit`) | full |
| Document CRUD + `_rev` MVCC + tombstones + conflicts | full |
| Replication (`_revs_diff`, `_bulk_get`, `open_revs`, `_local` checkpoints) | full |
| Attachments (inline, stub, multipart/related, multipart/mixed, `atts_since`) | full |
| `_changes` feed: `normal`, `longpoll`, `_doc_ids`/`_selector`/`_design` filters | full |
| `_changes` feed: `continuous`, `eventsource`, JS filters | **501** |
| Mango `_find`, `_index` (json type), `_explain`, `partial_filter_selector` | full |
| Mango `$text` / Nouveau / Clouseau | defer |
| View endpoints `_view/{name}` with built-in reduces (`_sum`/`_count`/`_stats`/`_approx_count_distinct`) | full |
| View endpoints with user JS map/reduce | **501** (JSRuntime.None) |
| `validate_doc_update` | **501** (JSRuntime.None) — coarse `_security` only |
| Auth: `_users`, `_session`, Basic, JWT, proxy | full (Phase 6) |
| Deprecated: shows/lists/updates/rewrites/`_temp_view` | **skip** — off by default in CouchDB 3.x |
| Partitioned databases | defer |

**Coverage test**: every feature exercised by PouchDB, the CouchDB replicator,
and Cloudant Python/Java SDKs is in full-MVP scope. The 501 surface is limited
to features that either have Mango alternatives or are deprecated in
upstream CouchDB.

---

## Phased delivery plan

| Phase | Scope | Exit criterion |
|---|---|---|
| **0** — Scaffolding | Package skeleton, `%CSP.REST` router, `CouchPort.Util.*`, welcome endpoint, CI via `iris_doc_compile` | `GET /` returns valid welcome object; `/_uuids?count=3` returns hex UUIDs |
| **1** — Core docs | Rev engine, rev tree merge, CRUD, `_bulk_docs`, `_all_docs`, `_security`, `_local`, `_revs_limit`, `_compact`, rev-hash parity harness | Fauxton can CRUD docs; curl-based simple replication from CouchPort to CouchDB works |
| **1b** *(parallel)* | `JSRuntime.None` stub (MVP); optionally `JSRuntime.Subprocess` and/or `JSRuntime.Python` | 501 responses for JS ops; at least one backend passes map-reduce round-trip if built |
| **2** — Changes + attachments | Sequence counter, `_changes` (normal + longpoll), `_changes.Filter` with `_doc_ids`/`_selector`/`_design`, attachment store, multipart reader/writer | Real CouchDB replicator does full bidirectional sync with attachments and longpoll feed |
| **3** — Mango | `Winners` + `MangoIndex` projection classes, selector parser, normalizer, SQL translator, planner, `_find`, `_index`, `_explain`, fallback scan | Mango test suite (ported) passes |
| **4** — Replication completion | `replication_id` (our algorithm), `_revs_diff`, `_bulk_get`, `open_revs` with multipart/mixed, `_local` checkpoint `history[]`, `_replicator` db storage | Real CouchDB node replicates bidirectionally with CouchPort; checkpoints survive restart; conflicts propagate correctly |
| **5** — Views + JS integration | View engine incremental build, `View.Store`, `View.BuiltinReduce`, `View.ETag`, JS map/reduce + filter + validate dispatch via `JSRuntime.Sandbox` | Design doc with JS view + filter + `validate_doc_update` works identically to real CouchDB |
| **6** — Auth + security | `_session` cookie flow, `_users` db with PBKDF2, `_security` enforcement, Basic + JWT + proxy auth modes | PouchDB and Cloudant clients authenticate with existing credential DBs |
| **7** — Hardening + optional streaming | Parity test harness, stress test, `%Net.TCPServer` raw HTTP listener for continuous/eventsource | Documented compatibility matrix, first public release |

---

## Risk register — final state

| Risk | Status |
|---|---|
| Rev hash byte-compat | ✅ Eliminated |
| `replication_id` byte-compat | ✅ Eliminated |
| ETF encoder implementation burden | ✅ Not needed |
| Mango runtime schema evolution | ✅ Resolved (two-class projection) |
| `%Net.MIMEReader` memory buffering | ✅ Eliminated (live-test confirmed) |
| Python install required for MVP | ✅ Eliminated (pluggable JSRuntime) |
| CSP Gateway buffers continuous feed | ⚠️ Confirmed; mitigated by longpoll MVP + Phase 7 raw-TCP fallback |
| AuthSession HMAC byte-compat | ⏳ Deferred to Phase 6 |
| `$ZF(-1)` subprocess IPC complexity | 🟡 New, bounded (simple JS file + kill-on-idle) |
| Mango `$elemMatch`/`$allMatch`/`$regex` on JSON arrays in IRIS SQL | 🟡 Known-hard, fallback-scan path is the mitigation |
| Large doc bodies vs IRIS global node size | 🟡 Auto-promote to `%Stream.GlobalBinary` over threshold |

---

## What Phase 0 needs before code starts

All four items are complete:

- [x] **Feature inventory locked** — A.1–A.11 enumerates the full surface
- [x] **Architectural decisions locked** — B.1–B.13 defines globals, projection, REST, JSRuntime
- [x] **Six of seven spikes resolved** — only spike 3 (AuthSession HMAC) deferred to Phase 6
- [x] **Dev loop verified on live IRIS 2025.1** — `iris_doc_put` → `iris_doc_compile` → `iris_execute_classmethod` works; webapp create/delete works; MD5 + MIMEReader probes succeeded

**Still open** (none are blockers):

- Pick a package prefix — `CouchPort.*` proposed, confirm or lock alternative
- Pick a webapp mount point — e.g., `/couchport/` on port 52773
- Decide whether to stand up a Docker CouchDB 3.5 instance for parity testing (recommended)
- Decide whether to also spike 5 (Python+quickjs) on a Python-enabled IRIS host, or defer that until a JSRuntime.Python implementer actually wants to build it

---

## Deliverable index

- **Full report**: `technical-couchdb-on-iris-research-2026-04-10.md` (2,039 lines)
- **This summary**: `technical-couchdb-on-iris-summary-2026-04-11.md` (you are here)
- **Initial prompt**: `docs/initial-prompt.md`
- **Reference sources**:
  - `sources/couchdb/` — Apache CouchDB 3.x Erlang source
  - `irislib/` — IRIS system library classes
