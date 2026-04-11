You are an expert enterprise software engineer and InterSystems IRIS architect. Your task is to build a production-grade CouchDB-compatible server natively on InterSystems IRIS.

Goal:
Create an open-source project that provides the FULL practical feature set of Apache CouchDB, exposed through a CouchDB-compatible HTTP API, running entirely inside InterSystems IRIS. This is a serious compatibility layer intended to support existing CouchDB clients, tooling, and replication protocols.

Critical Implementation Requirement: ObjectScript Only
This project MUST be implemented natively in InterSystems ObjectScript.
- Use ObjectScript for the core server, HTTP API (REST) layer, compatibility logic, persistence, revision/conflict engine, changes engine, replication engine, attachment handling, and security.
- Do NOT implement the core behavior in Node.js, Python, Go, or any external language.
- Reject any architectural proposal that moves the primary database engine logic outside of IRIS. External scripts are only allowed for testing and benchmarking.

Core Architecture: The CQRS Hybrid Approach (Globals + SQL)
You must implement a hybrid storage architecture that maps CouchDB's specific behaviors to the most optimal IRIS native structures. Do NOT just use flat %Library.Persistent classes for everything, as that will fail to efficiently emulate CouchDB's MVCC and append-only changes feed.

1. The Write Path (Storage, Revisions, Attachments, _changes): Raw IRIS Globals
   - Use pure multi-dimensional Globals for blindingly fast, lock-free B-tree performance.
   - Revisions & Documents: `^CouchPort.Docs(dbName, docId, revId) = {json string or dynamic object}`
   - Revision Trees (MVCC): `^CouchPort.Tree(dbName, docId, parentRev) = childRev`
   - Changes Feed: Use `$Increment(^CouchPort.Seq(dbName))` for atomic sequence generation. Store the feed at `^CouchPort.Changes(dbName, seq) = docId_","_winningRev`.
   - Attachments: Store binary blobs in `%Stream.GlobalBinary` linked via globals.

2. The Read Path (Mango Queries / Views): IRIS SQL & Shadow Tables
   - CouchDB's `_find` (Mango) requires declarative querying. Doing this purely in Globals is an anti-pattern.
   - Create a shadow table (e.g., `CouchPort.MangoIndex`) or use `%Storage.Custom` mapped to the winning revisions in the Globals.
   - Translate incoming Mango JSON selectors into IRIS SQL `WHERE` clauses against this SQL projection.
   - Rely on IRIS SQL for query planning, index maintenance on dynamic JSON paths, and result sorting.

Non-Negotiable Scope:
1. Database lifecycle APIs.
2. Document CRUD APIs with strict _rev optimistic concurrency.
3. Tombstones and delete semantics.
4. Conflict detection, storage, and inspection.
5. _all_docs and related listing semantics.
6. _changes feed (including continuous/longpoll behaviors).
7. Attachments (metadata, streaming, stubs).
8. Map/reduce Views & Design documents.
9. Mango queries (_find, indexes, selector translation to IRIS SQL).
10. Replication protocol endpoints (handling source/target sync, checkpoints).

Agent Research References:
Before implementing specific subsystems, fetch and read these exact specifications to ensure wire-compatibility and optimal IRIS usage:
- CouchDB API Reference: https://docs.couchdb.org/en/stable/api/index.html
- CouchDB Document MVCC/Revisions: https://docs.couchdb.org/en/stable/replication/conflicts.html
- CouchDB Changes Feed: https://docs.couchdb.org/en/stable/api/database/changes.html
- CouchDB Mango Query (_find): https://docs.couchdb.org/en/stable/api/database/find.html
- CouchDB Replication Protocol: https://docs.couchdb.org/en/stable/replication/protocol.html
- IRIS Using Globals: https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GCOS_globals
- IRIS Creating REST APIs: https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GREST
- IRIS JSON in SQL: https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GJSON_sql

Technical Design Requirements:
- Build a REST façade extending `%CSP.REST` that exposes CouchDB-style HTTP endpoints.
- Ensure HTTP status codes and JSON error envelopes exactly match CouchDB (e.g., 409 Conflict, 412 Precondition Failed).
- Support deleted documents as tombstones natively in the Global tree.
- Organize ObjectScript code cleanly (e.g., `CouchPort.API.Router`, `CouchPort.Core.Document`, `CouchPort.Storage.Globals`, `CouchPort.Query.Mango`).

Execution Plan (All Phases are in scope for MVP, but should be adapted to the BMAD method):
Phase 0: Architecture & Scaffolding
- Scaffold the repository (`/src/Couch` for ObjectScript, `/test`,).

- Map out the exact Global node structures and SQL projection classes.

Phase 1: Core Document API & Globals Storage
- Implement DB creation/deletion.
- Implement Document CRUD using Globals.
- Enforce `_rev` generation and optimistic concurrency.
- Implement `_bulk_docs` and `_all_docs`.

Phase 2: Sequences, Changes & Attachments
- Implement the `$Increment` based sequence tracker.
- Implement the `_changes` feed.
- Implement binary attachment storage using `%Stream.GlobalBinary`.

Phase 3: Mango & SQL Projection
- Map the winning revisions to an IRIS SQL table.
- Implement the `_find` endpoint by parsing CouchDB selectors into IRIS SQL queries.

Phase 4: Replication
- Implement the replication endpoints (`_revs_diff`, `_missing_revs`, bulk get).
- Verify sync against an actual Apache CouchDB instance using the official replicator.
