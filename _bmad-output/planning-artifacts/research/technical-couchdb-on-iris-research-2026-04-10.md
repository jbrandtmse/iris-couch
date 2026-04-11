---
stepsCompleted: [1, 2, 3, 4, 5, 6]
inputDocuments:
  - docs/initial-prompt.md
  - sources/couchdb/ (Apache CouchDB source tree)
  - irislib/ (IRIS system library classes)
workflowType: 'research'
lastStep: 1
research_type: 'technical'
research_topic: 'CouchDB-compatible server on InterSystems IRIS (ObjectScript)'
research_goals: 'Produce (1) a comprehensive feature inventory required for wire-compatibility with Apache CouchDB, and (2) a technical design/architecture mapping those features to IRIS primitives, adopting the CQRS hybrid approach (Globals for writes, SQL projection for Mango reads) with QuickJS sandbox for user-supplied design-doc JavaScript.'
user_name: 'Developer'
date: '2026-04-10'
web_research_enabled: true
source_verification: true
---

# Research Report: CouchDB-on-IRIS Technical Feasibility & Architecture

**Date:** 2026-04-10
**Author:** Developer
**Research Type:** Technical
**Analyst:** Mary (BMad Strategic Analyst persona)

---

## Research Overview

This report investigates what it takes to build a production-grade, wire-compatible
Apache CouchDB server running natively inside InterSystems IRIS, with the core engine
implemented entirely in ObjectScript and a narrow QuickJS sandbox (shipped in MVP)
for executing user-supplied design-document JavaScript (map/reduce views, filter
functions, and `validate_doc_update`).

The goal is two deliverables:

1. **Feature inventory** — the comprehensive set of CouchDB capabilities required for
   compatibility with existing CouchDB clients, tooling, and the replication protocol.
2. **Technical approach** — an architecture and implementation plan mapping each
   feature to the optimal IRIS primitive (globals, SQL projection, `%CSP.REST`,
   `%Stream.GlobalBinary`, etc.), organized into phased delivery.

---

## Technical Research Scope Confirmation

**Research Topic:** CouchDB-compatible server on InterSystems IRIS (ObjectScript)

**Research Goals:**
- Enumerate the comprehensive feature set required for CouchDB wire-compatibility
- Define a technical design/architecture mapping those features to IRIS primitives
- Phased delivery plan aligned to MVP scope

**Approved Architectural Decision (pre-research):**
- **Approach D (Hybrid):** Pure ObjectScript for the engine (storage, MVCC,
  revisions, changes feed, replication protocol, Mango, attachments, security,
  HTTP API). QuickJS sandbox **shipped in MVP** for user-supplied design-doc
  JavaScript (views, filters, validators). The JS runtime is treated as a narrow,
  well-defined boundary (mirrors how CouchDB itself uses `couchjs`/QuickJS via stdio).

**Technical Research Scope:**

- Architecture Analysis — CQRS hybrid (globals writes + SQL projection reads)
- Implementation Approaches — global node shapes, SQL shadow schema, REST routing,
  continuous changes pump, replication state machine, QuickJS sandbox integration
- Technology Stack — ObjectScript, IRIS globals, IRIS SQL with dynamic JSON paths,
  `%CSP.REST`, `%Stream.GlobalBinary`, `%DynamicObject`, embedded Python (QuickJS host)
- Integration Patterns — CouchDB HTTP API semantics, replication protocol,
  multipart attachments, long-polling / continuous / EventSource changes feed
- Performance Considerations — lock-free sequence generation, bulk ops, SQL index
  strategy on dynamic JSON paths, attachment streaming

**Research Methodology:**

- Direct source inspection of `sources/couchdb/` (authoritative wire behavior)
- IRIS system library inspection of `irislib/` (available primitives)
- Cross-reference via web + Perplexity against official CouchDB docs (3.x)
- Confidence flags on any ambiguous or implementation-variant behavior

**Scope Confirmed:** 2026-04-10

---

<!-- Research findings appended below -->

# PART A — COMPREHENSIVE FEATURE INVENTORY

Feature set required for wire-compatibility with Apache CouchDB 3.x, derived from
(1) direct reading of `sources/couchdb/` Erlang source, (2) the official CouchDB 3.x
documentation at docs.couchdb.org, and (3) cross-reference research against
PouchDB/Cloudant client-compat notes.

Each feature is tagged:
- **[MUST]** — required for replication protocol compatibility and for
  existing CouchDB clients to work at all.
- **[SHOULD]** — required for the query/analytics feature set to match CouchDB;
  not strictly needed for replication but required for the prompt's MVP scope.
- **[NICE]** — useful for parity but not MVP-critical.
- **[SKIP]** — deprecated in CouchDB 3.x, off by default, removal planned in 4.x.
- **[JS]** — requires the QuickJS sandbox (user-supplied design-doc JavaScript).

## A.1 — HTTP API Surface

### A.1.1 Server-level endpoints

| Endpoint | Method | Priority | Notes |
|---|---|---|---|
| `/` | GET | **MUST** | Welcome object. Must return `{"couchdb":"Welcome","version":"3.5.0","git_sha":"...","uuid":"...","features":[...],"vendor":{...}}`. The `"couchdb":"Welcome"` string is the canonical client sniff test. Populate `features` with `["access-ready","scheduler","quickjs"]` once those land. |
| `/_all_dbs` | GET | **MUST** | Array of db names. Supports skip/limit/startkey/endkey. |
| `/_dbs_info` | GET, POST | SHOULD | Bulk db info. GET form uses query params; POST form takes `{keys:[...]}`. Max databases per request configurable (default 100). |
| `/_uuids` | GET | **MUST** | Generate UUIDs: `?count=N`. Format: 32-char hex. Configurable algorithm (random, sequential, utc_random, utc_id). Clients use this before every doc create that needs a deterministic ID. |
| `/_up` | GET | **MUST** | Liveness probe. 200 + `{"status":"ok"}` when ready, else 503. |
| `/_active_tasks` | GET | SHOULD | List active replication, indexing, compaction tasks. Replication UIs rely on it. |
| `/_membership` | GET | NICE | Cluster topology. In a single-node CouchPort, return a stub with this node as the only member. Required by some cluster-aware clients. |
| `/_cluster_setup` | GET, POST | NICE | Stub — return `{"state":"single_node_enabled"}`. |
| `/_session` | GET, POST, DELETE | **MUST** | Cookie auth. See A.8. Stable POST body format: `name=...&password=...` form-encoded. |
| `/_replicate` | POST | SHOULD | Ad-hoc (non-persistent) replication job. Older API; modern clients use the `_replicator` database. Worth supporting both. |
| `/_scheduler/jobs`, `/_scheduler/docs` | GET | NICE | Replication scheduler status. Only needed if we implement persistent replicator jobs. |
| `/_node/{node}/...` | various | NICE | Per-node config, stats, restart. Stub to "this node" alias. |
| `/_stats` | GET | NICE | Nested stats object. Mostly monitoring. |
| `/_config`, `/_config/{section}`, `/_config/{section}/{key}` | GET, PUT, DELETE | NICE | Runtime config. Many clients do not use it; deprecated in favor of `local.ini`. |
| `/_utils`, `/_utils/*` | GET | NICE | Fauxton static UI. Phase much later or use redirect to an external host. |
| `/favicon.ico` | GET | NICE | Static file. Trivial. |

### A.1.2 Database-level endpoints

| Endpoint | Method | Priority | Notes |
|---|---|---|---|
| `/{db}` | PUT | **MUST** | Create db. Returns 201 or 412 if exists. Supports `?partitioned=true`. |
| `/{db}` | DELETE | **MUST** | Drop db. 200 + `{ok:true}`. |
| `/{db}` | GET | **MUST** | Db info: `db_name, doc_count, doc_del_count, update_seq, purge_seq, compact_running, disk_size, data_size, instance_start_time, disk_format_version, committed_update_seq`. |
| `/{db}` | POST | **MUST** | Create doc with server-assigned UUID id. |
| `/{db}/_all_docs` | GET, POST | **MUST** | List docs sorted by id. Full view-query parameter set: key, keys, startkey, endkey, startkey_docid, endkey_docid, limit, skip, descending, inclusive_end, update_seq, include_docs, conflicts, attachments. POST supports `{keys:[...]}`. POST `/_all_docs/queries` supports multi-query. Returns `{total_rows, offset, rows:[{id, key, value:{rev}, [doc]}]}`. |
| `/{db}/_design_docs` | GET, POST | SHOULD | Same shape as `_all_docs`, filtered to `_design/*` ids. |
| `/{db}/_local_docs` | GET, POST | NICE | Same shape, filtered to `_local/*` ids. Replicators do not use this. |
| `/{db}/_bulk_docs` | POST | **MUST** | Bulk insert/update. Body: `{docs:[...], new_edits:true|false}`. `new_edits=false` is how replicators upload. Per-doc response: `[{ok:true,id,rev}|{id,error,reason}, ...]`. |
| `/{db}/_bulk_get` | POST | **MUST** | Replicator fetches many docs by id+rev at once. Body: `{docs:[{id,rev,atts_since},...]}`. Response: `{results:[{id, docs:[{ok:{...}}|{error:{...}}]}]}`. |
| `/{db}/_changes` | GET, POST | **MUST** | See A.3. feed=normal, longpoll, continuous, eventsource. All four MUST be supported. |
| `/{db}/_revs_diff` | POST | **MUST** | Replication. Body: `{docid:[rev1,rev2],...}`. Returns `{docid:{missing:[...], possible_ancestors:[...]}, ...}`. |
| `/{db}/_missing_revs` | POST | SHOULD | Older form of `_revs_diff`. Modern replicators prefer `_revs_diff`. |
| `/{db}/_security` | GET, PUT | **MUST** | Per-db `{admins:{names,roles}, members:{names,roles}}`. Default empty arrays = public. |
| `/{db}/_revs_limit` | GET, PUT | **MUST** | Integer body. Default 1000. |
| `/{db}/_purge` | POST | SHOULD | Permanently drop revs. Body: `{docid:[revs]}`. Advances `purge_seq`. Does NOT replicate by itself. |
| `/{db}/_purged_infos_limit` | GET, PUT | SHOULD | Integer. Controls purge retention. |
| `/{db}/_purged_infos` | GET | NICE | List past purge records. |
| `/{db}/_compact` | POST | **MUST** | 202 + `{ok:true}`. For CouchPort we can make this a no-op that just runs a housekeeping job (globals don't need compaction the way CouchDB .couch files do). |
| `/{db}/_view_cleanup` | POST | NICE | Remove stale view indexes. No-op acceptable. |
| `/{db}/_ensure_full_commit` | POST | **MUST** | Deprecated but still called by older replicators. Return 201 + `{ok:true, instance_start_time:"..."}`. |
| `/{db}/_find` | POST | **MUST** | Mango query. See A.5. |
| `/{db}/_index` | GET, POST | **MUST** | Mango index management. See A.5. |
| `/{db}/_index/_bulk_delete` | POST | SHOULD | Delete multiple indexes. |
| `/{db}/_index/{ddoc}/json/{name}` | DELETE | **MUST** | Delete specific index. |
| `/{db}/_explain` | POST | **MUST** | Mango query planner output. See A.5. |
| `/{db}/_partition/{partition}/_all_docs` | GET, POST | NICE | Only for partitioned dbs. MVP can defer partitioned dbs entirely. |
| `/{db}/_partition/{partition}/_find` | POST | NICE | Same. |

### A.1.3 Document-level endpoints

| Endpoint | Method | Priority | Notes |
|---|---|---|---|
| `/{db}/{docid}` | GET | **MUST** | Fetch doc. Query params: rev, open_revs, latest, atts_since, attachments, att_encoding_info, conflicts, revs_info, revisions, deleted_conflicts, local_seq. `open_revs=all` and `open_revs=[...]` return array or multipart/mixed. |
| `/{db}/{docid}` | PUT | **MUST** | Create/update. Body: JSON, or `multipart/related` with attachments. Query: `?rev=...`, `?batch=ok`, `?new_edits=false`. Returns 201 `{ok, id, rev}` or 409 conflict. |
| `/{db}/{docid}` | DELETE | **MUST** | Tombstone. Requires `?rev=...`. |
| `/{db}/{docid}` | COPY | SHOULD | `Destination:` header. 201 on success. Rare but used by Fauxton. |
| `/{db}/{docid}/{attname}` | GET | **MUST** | Stream attachment bytes. Must set Content-Type, Content-Length, ETag, and respect Range requests. |
| `/{db}/{docid}/{attname}` | PUT | **MUST** | Upload attachment. Content-Type + body. Requires `?rev=...`. Returns 201. |
| `/{db}/{docid}/{attname}` | DELETE | **MUST** | Remove attachment. Requires `?rev=...`. |
| `/{db}/_local/{docid}` | GET, PUT, DELETE | **MUST** | Local (non-replicated) docs. Stored separately. Used by replicators for checkpoints. No attachments. |

### A.1.4 Design-document endpoints

| Endpoint | Method | Priority | Notes |
|---|---|---|---|
| `/{db}/_design/{ddoc}` | GET, PUT, DELETE | **MUST** | Design docs are regular docs with a `_design/` id prefix. Must be URL-encoded carefully — `_design/` is literal, slashes inside the name are `%2F`. |
| `/{db}/_design/{ddoc}/_info` | GET | SHOULD | View index stats. |
| `/{db}/_design/{ddoc}/_view/{view}` | GET, POST | **[SHOULD + JS]** | Query a view. Full view-query param set. `POST /_view/{view}/queries` for multi-query. MUST run the map function through QuickJS. Built-in reduces (`_sum`, `_count`, `_stats`, `_approx_count_distinct`) run in ObjectScript without JS. |
| `/{db}/_design/{ddoc}/_show/{show}[/{docid}]` | GET, POST | **[SKIP]** | Deprecated. Off by default in 3.x. |
| `/{db}/_design/{ddoc}/_list/{list}/{view}` | GET, POST | **[SKIP]** | Deprecated. |
| `/{db}/_design/{ddoc}/_update/{update}[/{docid}]` | PUT, POST | **[SKIP]** | Deprecated. |
| `/{db}/_design/{ddoc}/_rewrite/{path}` | all | **[SKIP]** | Deprecated. |
| `/{db}/_design/{ddoc}/_temp_view` | POST | **[SKIP]** | Removed in 3.0. Return 410 Gone. |

### A.1.5 HTTP status codes and JSON error envelope **[MUST]**

Envelope shape is **always**: `{"error":"<slug>","reason":"<human>"}`. Slugs clients
rely on: `not_found`, `conflict`, `bad_request`, `forbidden`, `unauthorized`,
`file_exists`, `missing_rev`, `missing_stub`, `invalid_rev`, `validation_failed`,
`compilation_error`.

Codes we must emit correctly: 200, 201, 202, 304, 400, 401, 403, 404, 405, 406, 409,
412, 415, 416, 417, 500. The 409/412 distinction is load-bearing for client behavior.

Required response headers: `ETag` (quoted rev on doc GET, signature on view GET),
`Cache-Control: must-revalidate`, `X-Couch-Request-ID`, `X-Couch-Update-NewRev`
(on writes), `Content-Type`, `Content-Length` (or chunked).

## A.2 — Document / MVCC Semantics

- **Revision format** `N-<hash>` where N is the integer generation (incremented on
  every update) and `<hash>` is a 32-char lowercase hex MD5. **[MUST]**
- **Revision hash computation** — MD5 of `(canonicalized body bytes || parent_rev || deleted_flag || attachment_digests)`. **Must be byte-identical to CouchDB's algorithm** or else `new_edits=false` replication rewrites the hash and breaks round-trip. This is source-verified from `couch_doc:new_revid/1` in `sources/couchdb/src/couch/src/couch_doc.erl`. **[MUST]**
- **Revision tree (couch_key_tree)** — multi-branch tree with `{key=RevId, value=Body|missing, children=[subtree...]}`. Supports merge, multi_merge, stemming, leaf detection. Deterministic across replicas. **[MUST]**
- **Winning revision algorithm**: (1) live beats deleted, (2) highest generation N wins, (3) lexicographically largest rev hash wins. Deterministic and MUST match CouchDB byte-for-byte. **[MUST]**
- **Tombstones** — delete = new rev with `_deleted: true`. Still a leaf in the tree. `DELETE /{db}/{docid}` creates an implicit `{_deleted:true}` body. **[MUST]**
- **`_revs_limit`** — default 1000. Pruning discards ancestor bodies but keeps rev IDs as stubs so replication can prove ancestry. **[MUST]**
- **`_conflicts`, `_deleted_conflicts`** — arrays of losing leaves, only returned when `?conflicts=true` / `?deleted_conflicts=true`. **[MUST]**
- **`_revisions`** — `{start:N, ids:[hash1, hash2, ...]}`. Returned when `?revs=true`. Replicators rely on this to insert with `new_edits=false`. **[MUST]**
- **`_revs_info`** — `[{rev:"N-hash", status:"available"|"deleted"|"missing"},...]`. Returned when `?revs_info=true`. **[MUST]**
- **`new_edits=true`** (default) — conflict check, mint new rev, reject bad parent. **[MUST]**
- **`new_edits=false`** — take rev exactly as supplied, insert into tree at position dictated by `_revisions`, no conflict check. Replication mode. **[MUST]**
- **Bulk docs semantics** — all-or-per-doc response; failures are per-doc not per-request. **[MUST]**
- **`_purge`** — removes rev from tree entirely, irreversible, advances `purge_seq`. Does not replicate automatically. **[SHOULD]**

## A.3 — Changes Feed

- **Four feed modes** — normal, longpoll, continuous, eventsource. All **[MUST]** for full client compat (PouchDB uses longpoll + continuous, Fauxton uses eventsource).
- **Framing per mode**:
  - normal: single JSON `{results:[...], last_seq, pending}`.
  - longpoll: same shape, blocks until a change (or `timeout`, default 60000 ms).
  - continuous: newline-delimited JSON, connection held forever, no sentinel, heartbeat = bare `\n`. Content-Type `application/json` (not `application/x-ndjson`).
  - eventsource: SSE, `data: {...}\nid: <seq>\n\n`, heartbeat = `:\n\n` comment.
- **Query parameters** — `since`, `limit`, `descending`, `feed`, `heartbeat` (ms), `timeout` (ms), `include_docs`, `conflicts`, `filter`, `doc_ids`, `view`, `style` (main_only|all_docs), `seq_interval`, `attachments`, `att_encoding_info`. **[MUST]**
- **Filters**:
  - `_doc_ids` — match id in supplied list. **[MUST]**
  - `_selector` — Mango selector. **[MUST]**
  - `_design` — design docs only. **[MUST]**
  - `_view` — pass if the named view's map would emit anything. Requires QuickJS. **[SHOULD + JS]**
  - `ddocname/filtername` — custom JS filter, `function(doc, req)`. **[SHOULD + JS]**
- **`style=main_only`** (default) returns only the winning rev in `changes[]`.
- **`style=all_docs`** returns every leaf rev. **Replicators require this**. **[MUST]**
- **`seq_interval=N`** — emit full `seq` only every Nth change; nulls in between. Bandwidth optimization. **[SHOULD]**
- **Sequence token format** — per docs, opaque string. Implementation-defined. **We pick a stable format and never parse it from the wire.** Clients that try to `parseInt` are already broken against CouchDB 2.x+.
- **Response fields** — each row: `{seq, id, changes:[{rev},...], [deleted:true], [doc]}`. Final: `{last_seq, pending:N}`. **[MUST]**

## A.4 — Replication Protocol

Full replicator HTTP sequence (authoritative from [Replication Protocol doc](https://docs.couchdb.org/en/stable/replication/protocol.html)):

1. **Verify peers** — `GET /` on source and target. Sniff the welcome object.
2. **Check db existence** — `GET /{source}`, `GET /{target}` (create target if `create_target=true`).
3. **Compute replication_id** — MD5 of canonicalized (source_uri, target_uri, `create_target`, `continuous`, `doc_ids`, filter source, selector, `since_seq`). **Must byte-match CouchDB** or existing clients re-replicate everything on reconnect. Source authority: `couch_replicator_ids.erl`. **[MUST]**
4. **Read checkpoints** — `GET /{source}/_local/{replication_id}`, `GET /{target}/_local/{replication_id}`. If `session_id` disagrees, rewind to lowest common `recorded_seq` in the `history[]` arrays. **[MUST]**
5. **Read changes** — `GET /{source}/_changes?feed=normal&style=all_docs&since={seq}&limit=N` (or `feed=continuous&heartbeat=...` for continuous). **`style=all_docs` is mandatory**. **[MUST]**
6. **Find missing revs** — `POST /{target}/_revs_diff` with `{docid:[revs],...}`. **[MUST]**
7. **Fetch missing revs** from source:
   - Small docs: `GET /{source}/{docid}?open_revs=[...]&revs=true&latest=true` with `Accept: application/json`. **[MUST]**
   - Docs with attachments: same GET with `Accept: multipart/mixed&attachments=true&atts_since=[...]`. **[MUST]**
8. **Upload to target**:
   - Small docs: `POST /{target}/_bulk_docs` with `{new_edits:false, docs:[...]}`. **[MUST]**
   - With attachments: `PUT /{target}/{docid}?new_edits=false` with `Content-Type: multipart/related`. **[MUST]**
9. **Checkpoint** — `PUT /{source}/_local/{id}`, `PUT /{target}/_local/{id}` with `{session_id, source_last_seq, history:[...]}`. Done periodically or on idle. **[MUST]**
10. **Loop** or close depending on `continuous` flag.

**Continuous vs one-shot**: identical except continuous uses `feed=continuous` and checkpoints on a timer (~5s) instead of at batch boundaries. `replication_id` differs between the two (continuous flag is a hash input), so they don't clobber each other's checkpoints.

**`_replicator` database** — persistent replicator jobs created by PUTting docs into a special db. Separate control-plane from `_replicate`. **[SHOULD]** for MVP, defer actual scheduler implementation if needed.

## A.5 — Mango Query Language

### Selector operators **[MUST]** (all of these)

- Comparison: `$lt`, `$lte`, `$eq`, `$ne`, `$gte`, `$gt`. `$eq` is implicit for bare values.
- Logical: `$and`, `$or`, `$not`, `$nor`.
- Array: `$all`, `$elemMatch`, `$allMatch`, `$size`, `$keyMapMatch`.
- Condition: `$exists`, `$type`, `$in`, `$nin`, `$mod`, `$regex`.
- String (not in all builds): `$beginsWith`.
- Text search: `$text` **[NICE — requires Nouveau/Clouseau, defer]**.

### Implicit `$and`
Top-level multi-field selector is AND-ed: `{"year":1901,"author":"Mann"}`. **[MUST]**

### `_find` request parameters **[MUST]**

`selector`, `fields`, `sort`, `limit`, `skip`, `bookmark`, `update`, `stable`,
`execution_stats`, `use_index`, `conflicts`, `r`.

### `_index` **[MUST]**

- Types: `json` (default, **required**), `text` (Nouveau/Clouseau, **defer**), `nouveau` (3.4+, **defer**).
- `fields` array (or `{name,type}` objects for text).
- `partial_filter_selector` — selector used to prune which docs are indexed. **[MUST]**
- Optional `ddoc`, `name` (auto-generated if omitted).

### Index selection algorithm **[MUST]**

1. Filter by `use_index` if set.
2. Filter by `partial_filter_selector` compatibility.
3. Rank candidates by: longest prefix match of (sort fields ++ selector fields).
4. Pick highest-ranked usable index.
5. Fallback: full scan of `_all_docs` with in-memory filter. `_explain` reports `"index":"_all_docs"`.

### `_explain` response shape **[MUST]**

`{dbname, index:{ddoc,name,type,def}, selector, opts, limit, skip, fields, range:{start_key,end_key}}`. The `range` field is what clients diagnose perf with.

## A.6 — Views / Map-Reduce

### Priority
- **`_all_docs` view-shape output** — **[MUST]**, no JS needed.
- **Design-doc JS views** — **[SHOULD + JS]**, shipped in MVP via QuickJS.
- **Built-in reduces** — **[MUST]**, implemented in ObjectScript.

### Features

- **View update model** — `update=true` (default, block until current), `update=false` (stale OK), `update=lazy` (return stale, queue update). `stale=ok` is a deprecated alias. **[SHOULD]**
- **Built-in reduces** — `_sum`, `_count`, `_stats`, `_approx_count_distinct`. Implemented in ObjectScript. **[MUST]**
- **Custom JS map** — `function(doc) { emit(key, value); }`. **[JS]**
- **Custom JS reduce** — `function(keys, values, rereduce) { ... }`. **[JS]**
- **Query parameters**: `key`, `keys`, `startkey`, `endkey`, `startkey_docid`, `endkey_docid`, `inclusive_end` (default true), `limit`, `skip`, `descending`, `reduce` (default true if reduce exists), `group`, `group_level`, `include_docs`, `update_seq`, `stable`. **[MUST]**
- **Design doc shape** — `_id, _rev, language, options, autoupdate, views{name:{map,reduce}}, filters{name:source}, validate_doc_update:source, updates/lists/shows/rewrites [SKIP]`. **[MUST]**
- **`language` field** — `"javascript"` (default) or `"javascript_quickjs"` (CouchDB 3.4+). In CouchPort both route to QuickJS. `"erlang"` and other custom languages out of scope.
- **View compile-on-first-query** — bad map functions don't fail until queried. **[MUST]** to match client expectation.

## A.7 — Attachments

- **Metadata shape** — `{content_type, length, digest:"md5-<base64>", revpos, stub, follows, encoding, encoded_length, data}`. **[MUST]**
- **Digest format**: `md5-<base64-standard-encoded-16-bytes>`. Not hex. **[MUST]**
- **Inline upload** — `_attachments: {name: {content_type, data: "<base64>"}}` in the doc JSON. **[MUST]**
- **Stub** — `_attachments: {name: {stub:true, revpos:N}}` when updating a doc without touching an attachment. Server substitutes from the previous rev. **[MUST]**
- **Multipart upload** — `PUT /{db}/{docid}` with `Content-Type: multipart/related`. First part is the JSON doc with `"follows":true` stubs, subsequent parts are attachment bodies in the same order as the `_attachments` object iteration. **[MUST]**
- **Multipart download** — `GET /{db}/{docid}?open_revs=...&attachments=true` with `Accept: multipart/mixed`. Top-level is `multipart/mixed`, each part is itself a per-rev `multipart/related` sub-document. **[MUST]**
- **`atts_since=[revs...]`** — bandwidth optimization for replication. Server compares each attachment's `revpos` against the ancestor set and sends stubs for unchanged attachments. **[MUST]**
- **Streaming** — attachments may be GB-scale. Use `%Stream.GlobalBinary` with chunked transfer. **[MUST]**
- **Range requests** — GET supports `Range:` header on attachments. Returns 206/416. **[SHOULD]**
- **Content-Encoding gzip** — CouchDB stores some attachments gzipped on disk and returns them with `Content-Encoding: gzip`. `encoded_length` and `encoding` fields in the metadata reflect this. **[SHOULD]** for MVP, identity-only acceptable.

## A.8 — Security and Auth

- **`_session` cookie flow** — POST with `name=X&password=Y` form body. Server sets `AuthSession` cookie (HMAC-signed `(user:timestamp:secret)` base64). `GET /_session` returns current user context. `DELETE /_session` logs out. The HMAC format must match CouchDB's for clients that validate cookies themselves. **[MUST]**
- **HTTP Basic auth** — `Authorization: Basic <b64>` always accepted in parallel with cookies. Stateless, no cookie set. **[MUST]**
- **`_users` database** — special db. User doc id is `org.couchdb.user:<name>`. On write, `password` is stripped and replaced with `password_scheme`, `iterations`, `derived_key`, `salt`. Scheme is `pbkdf2` (PBKDF2-HMAC-SHA1). `simple` (SHA1 legacy) must be read-accepted for compat but we write `pbkdf2`. **[MUST]**
- **`_security` document** — per-db `{admins:{names,roles}, members:{names,roles}}`. Both arrays empty in `members` = public. Server admins bypass `_security`. **[MUST]**
- **`validate_doc_update`** — called on every write. `function(newDoc, oldDoc, userCtx, secObj)`. `throw({forbidden:msg})` → 403, `throw({unauthorized:msg})` → 401. **Not called on ddoc writes** (deliberate exemption). **Not called for admins**. **[MUST + JS]**
- **Proxy auth** — `X-Auth-CouchDB-UserName` + optional roles header. Trusts upstream reverse proxy. **[SHOULD]**
- **JWT auth** — `Authorization: Bearer <jwt>`. Verify against configured secret; `sub` claim maps to user name. **[SHOULD]**
- **Anonymous access** — if `require_valid_user=false` and `members` is empty, unauthenticated access permitted. **[MUST]** (default CouchDB "party mode").

## A.9 — Infrastructure Concerns

- **UUID generation** — `_uuids?count=N`. Multiple algorithms: `random`, `sequential`, `utc_random`, `utc_id`. Default random. Format: 32-char lowercase hex. **[MUST]** `random` only; others **[NICE]**.
- **Compaction** — `POST /{db}/_compact`, `POST /{db}/_view_cleanup`. For globals these are largely no-ops; return 202 + run a bookkeeping pass. **[MUST]** just for the 202 response shape.
- **`_ensure_full_commit`** — legacy fsync endpoint. Return 201 + `{ok:true, instance_start_time}`. **[MUST]** (older replicators still call it).
- **Partitioned dbs** — `?partitioned=true` on create. Doc ids must be `partition:docid`. **[NICE]** defer.
- **`_replicator` database** — persistent replicator jobs. **[SHOULD]** defer scheduler to a later phase, accept and store replicator docs now so clients can write them.
- **Chunked transfer encoding** — used on almost all responses. **[MUST]** at the `%CSP.Response` layer.

## A.10 — Features Requiring the QuickJS Sandbox (the JS boundary)

| Feature | Frequency | Priority |
|---|---|---|
| View map functions | per-doc on write (or on view build) | **[JS MUST]** |
| View reduce functions (custom, non-builtin) | per-key group | **[JS SHOULD]** |
| `validate_doc_update` | per-write | **[JS MUST]** |
| `_changes` filter `_view` (checks if map emits) | per-changed-doc | **[JS SHOULD]** |
| `_changes` filter `ddoc/name` (custom) | per-changed-doc | **[JS SHOULD]** |
| Show / list / update / rewrite | on-demand | **[SKIP]** deprecated |

QuickJS responsibilities:
1. Load the ddoc and compile its JS functions into isolated contexts.
2. Execute map over each doc, collect `emit(key, value)` pairs.
3. Execute reduce with `(keys, values, rereduce)`.
4. Execute validate_doc_update, catch `{forbidden}`/`{unauthorized}` throws, map to HTTP 403/401.
5. Execute filter functions, return boolean.
6. Enforce memory limit (default 16 MB/context), CPU time limit (default 5s), stack depth limit, no FS/network access.

## A.11 — Feature Summary Matrix

| Subsystem | MUST | SHOULD | NICE | SKIP | JS |
|---|---|---|---|---|---|
| Server endpoints | 6 | 2 | 5 | 0 | 0 |
| Database endpoints | 18 | 4 | 2 | 0 | 0 |
| Document endpoints | 7 | 1 | 0 | 0 | 0 |
| Design doc endpoints | 2 | 2 | 0 | 5 | 1 |
| MVCC / rev tree | 12 | 1 | 0 | 0 | 0 |
| Changes feed | 11 | 2 | 0 | 0 | 2 |
| Replication | 10 | 1 | 0 | 0 | 0 |
| Mango | 22 operators + `_find` + `_index` + `_explain` | 2 | 2 | 0 | 0 |
| Views | built-ins + view-query | update modes | | shows/lists/updates/rewrites | map/reduce custom |
| Attachments | 8 | 2 | 0 | 0 | 0 |
| Security | 6 | 2 | 0 | 0 | validate_doc_update |
| Infra | 4 | 1 | 2 | 0 | 0 |

**Total MVP work items (MUST + SHOULD + JS MUST)**: approximately **120 distinct
feature items** across 11 subsystems.

---

# PART B — TECHNICAL DESIGN AND ARCHITECTURE

## B.1 — Architectural Principles

1. **CQRS hybrid** — globals are the source of truth for writes, revisions, changes
   feed, and attachments. SQL projection is a derived read model for Mango. The
   projection is rebuilt from the globals, never the other way around.
2. **ObjectScript-only engine** — all wire behavior (HTTP, MVCC, replication,
   changes, Mango, attachments, security) is ObjectScript. The only non-OS piece
   is the QuickJS sandbox, which lives behind a single narrow interface class and
   runs in embedded Python.
3. **Narrow sandbox boundary** — user JS runs in QuickJS (via the PetterS `quickjs`
   Python binding) in a dedicated sandbox process/context per ddoc. The CouchPort
   engine never executes arbitrary user code itself.
4. **Wire-compat over cleverness** — where we can pick between "elegant OS
   idiom" and "matches CouchDB byte-for-byte," we pick wire-compat. Specifically:
   rev hash algorithm, replication_id hash, AuthSession cookie format, JSON
   error envelope, and sequence token stability.
5. **Phased delivery aligned to the initial-prompt.md plan** — Phase 0 scaffolding,
   Phase 1 core docs, Phase 2 changes+attachments, Phase 3 Mango, Phase 4
   replication. QuickJS sandbox is shipped in MVP, slotted into Phase 1b (see B.9).

## B.2 — Package Layout

```
CouchPort.API.Router            — %CSP.REST dispatcher, top-level UrlMap
CouchPort.API.Server            — GET /, /_all_dbs, /_uuids, /_up, /_membership
CouchPort.API.Session           — /_session, /_replicate
CouchPort.API.Database          — PUT/DELETE/GET /{db}, /_bulk_docs, /_all_docs, ...
CouchPort.API.Document          — /{db}/{docid} CRUD, COPY, /_local/
CouchPort.API.Attachment        — /{db}/{docid}/{attname}
CouchPort.API.DesignDoc         — /_design/{ddoc}, /_view/, /_info
CouchPort.API.Find              — /_find, /_index, /_explain, /_bulk_get
CouchPort.API.Changes           — /_changes (all 4 feed modes)
CouchPort.API.Replication       — /_revs_diff, /_missing_revs
CouchPort.API.Util              — JSON error envelope, query parser, URL decode,
                                  ETag helper, auth extraction, CORS

CouchPort.Core.Database         — create/drop/info, metadata, uuid, instance start
CouchPort.Core.Document         — CRUD, rev minting, tombstones
CouchPort.Core.Rev              — rev string parse/format, hash computation
CouchPort.Core.RevTree          — port of couch_key_tree: merge, stem, leaves, winner
CouchPort.Core.Conflict         — winning rev selection, _conflicts, _deleted_conflicts
CouchPort.Core.BulkDocs         — new_edits true/false, per-doc error reporting
CouchPort.Core.UUID             — UUID generation (random + sequential)
CouchPort.Core.Sequence         — $Increment wrapper, seq token stable format

CouchPort.Storage.Globals       — global node helpers, $Data/$Order wrappers
CouchPort.Storage.Doc           — ^CouchPort.Docs accessor
CouchPort.Storage.Tree          — ^CouchPort.Tree accessor
CouchPort.Storage.Changes       — ^CouchPort.Changes accessor + scan
CouchPort.Storage.Attachment    — ^CouchPort.Atts + %Stream.GlobalBinary binding
CouchPort.Storage.Local         — ^CouchPort.Local (non-replicated docs)
CouchPort.Storage.Security      — ^CouchPort.Sec (per-db _security doc)
CouchPort.Storage.Meta          — ^CouchPort.Meta (db metadata)

CouchPort.Query.Mango.Parser       — parse selector JSON to internal AST
CouchPort.Query.Mango.Normalizer   — normalize operators, push $not inward, etc.
CouchPort.Query.Mango.Translator   — AST → IRIS SQL WHERE clause
CouchPort.Query.Mango.Planner      — index selection, cost estimation
CouchPort.Query.Mango.Explain      — build _explain response
CouchPort.Query.Mango.Index        — _index CRUD, ddoc-backed index storage
CouchPort.Query.Mango.Cursor       — execute translated SQL, paginate, bookmarks
CouchPort.Query.Mango.FallbackScan — full _all_docs scan with in-memory filter

CouchPort.Projection.Winners       — %Persistent class, shadow table of winning revs
CouchPort.Projection.Mapper        — sync globals → projection on every write
CouchPort.Projection.Rebuilder     — batch rebuild on schema drift / disaster recovery

CouchPort.View.Engine              — view build orchestration, driven by _changes
CouchPort.View.Store               — ^CouchPort.View accessor
CouchPort.View.BuiltinReduce       — _sum, _count, _stats, _approx_count_distinct in OS
CouchPort.View.Query               — view query params, group/group_level semantics
CouchPort.View.ETag                — view signature computation

CouchPort.Replication.RevsDiff     — POST /_revs_diff
CouchPort.Replication.BulkGet      — POST /_bulk_get
CouchPort.Replication.OpenRevs     — ?open_revs handling, multipart/mixed emit
CouchPort.Replication.Checkpoint   — _local doc handling
CouchPort.Replication.ReplicationID — byte-compat replication_id hash

CouchPort.Changes.Normal           — feed=normal
CouchPort.Changes.Longpoll         — feed=longpoll + timeout
CouchPort.Changes.Continuous       — feed=continuous + heartbeat
CouchPort.Changes.EventSource      — feed=eventsource (SSE)
CouchPort.Changes.Filter           — _doc_ids, _selector, _design, _view, JS filters
CouchPort.Changes.Pump             — background wake-up, ^CouchPort.Notify

CouchPort.Attachment.Store         — %Stream.GlobalBinary wrapper
CouchPort.Attachment.MultipartReader — parse multipart/related uploads
CouchPort.Attachment.MultipartWriter — emit multipart/mixed downloads
CouchPort.Attachment.Digest        — MD5 + "md5-<base64>" formatting

CouchPort.Security.Session         — /_session cookie flow
CouchPort.Security.AuthSession     — HMAC-signed AuthSession cookie (byte-compat)
CouchPort.Security.User            — _users db, PBKDF2-HMAC-SHA1
CouchPort.Security.Auth            — request auth extraction (basic, cookie, JWT)
CouchPort.Security.Validate        — invoke validate_doc_update via JSRuntime

CouchPort.JSRuntime.Sandbox        — ObjectScript facade
CouchPort.JSRuntime.Protocol       — emulate couchjs line protocol commands
CouchPort.JSRuntime.Pool           — context pool, per-ddoc isolation
CouchPort.JSRuntime.Python         — [Language=python] methods hosting quickjs

CouchPort.Util.Json                — canonicalization for hash inputs
CouchPort.Util.URL                 — encode/decode, docid parsing (_design/_local)
CouchPort.Util.HTTP                — header helpers, status codes, chunked writer
CouchPort.Util.Log                 — structured logging
CouchPort.Util.Error               — %Status ↔ JSON error envelope

CouchPort.Test.*                   — %UnitTest.TestCase classes, one per subsystem
```

## B.3 — Global Node Layout

Chosen for hot-path `$Order` traversal, `$Increment` atomicity, and minimum
subscript depth on the write path.

### B.3.1 Database metadata
```
^CouchPort.Meta(dbName, "uuid")              = <db_uuid hex>
^CouchPort.Meta(dbName, "created")           = <ISO8601>
^CouchPort.Meta(dbName, "revsLimit")         = 1000
^CouchPort.Meta(dbName, "purgedInfosLimit")  = 1000
^CouchPort.Meta(dbName, "docCount")          = <int>   ; maintained by $Increment
^CouchPort.Meta(dbName, "docDelCount")       = <int>
^CouchPort.Meta(dbName, "dataSize")          = <bytes>
^CouchPort.Meta(dbName, "instanceStartTime") = <microseconds since epoch>
^CouchPort.Meta(dbName, "partitioned")       = 0|1
^CouchPort.Meta(dbName, "purgeSeq")          = <int>
```

### B.3.2 Sequence counter
```
^CouchPort.Seq(dbName)                       = <monotonic int>
; All writes do: Set newSeq = $Increment(^CouchPort.Seq(dbName))
; This is the load-bearing atomicity guarantee — $Increment is cluster-safe
; and lock-free.
```

### B.3.3 Documents and revision storage
```
^CouchPort.Docs(dbName, docId)                   = <winningRev>   ; cache
^CouchPort.Docs(dbName, docId, revId)            = {full JSON body as string or stream}
^CouchPort.Docs(dbName, docId, revId, "meta")    = $lb(deleted, parent, size, mtime, seq)
^CouchPort.Docs(dbName, docId, revId, "atts")    = <JSON att metadata array>
^CouchPort.Docs(dbName, docId, revId, "attData", attName) = <%Stream.GlobalBinary OID>
```

Why two levels: `^CouchPort.Docs(db, id)` holds the cached winning rev for O(1)
winner lookup; the full rev bodies live at the third subscript. This keeps GET by
id fast without having to walk the tree on every read.

Large bodies (over ~28 KB to stay clear of the IRIS global node size limit) are
written as `%Stream.GlobalBinary` and the subscript value holds the OID.

### B.3.4 Revision tree
```
^CouchPort.Tree(dbName, docId, "winner")              = <winningRev>
^CouchPort.Tree(dbName, docId, "leaf", leafRev)       = "live"|"deleted"
^CouchPort.Tree(dbName, docId, "edge", parentRev, childRev) = ""
^CouchPort.Tree(dbName, docId, "gen", N)              = ""   ; reverse index for stemming
^CouchPort.Tree(dbName, docId, "stub", prunedRev)     = <gen>
```

The tree is stored as edges + leaves. Merge is implemented by
`CouchPort.Core.RevTree` as a port of `couch_key_tree.erl`. Winning rev is
computed on every write and cached at `...winner`.

### B.3.5 Changes feed
```
^CouchPort.Changes(dbName, seq) = $lb(docId, winningRev, deletedFlag)
^CouchPort.ChangesByDoc(dbName, docId) = <lastSeq>  ; for fast "changed since" lookup
```

On every write: `Set seq = $Increment(^CouchPort.Seq(dbName))`, then
`Set ^CouchPort.Changes(dbName, seq) = $lb(id, rev, deleted)`, then
`Set ^CouchPort.ChangesByDoc(dbName, id) = seq` (so only the latest seq for a doc
is preserved if we choose to compact — CouchDB behavior: old entries for a doc
are superseded).

### B.3.6 Local docs (checkpoints)
```
^CouchPort.Local(dbName, "_local/" _ localId) = {JSON body}
```
Flat: `_local/*` docs never participate in the rev tree or changes feed.
Replicators use them for checkpoints.

### B.3.7 Attachments
```
^CouchPort.Atts(dbName, docId, revId, attName) = <%Stream.GlobalBinary OID>
```
Each attachment is a separate stream object. Metadata (digest, length, content_type,
revpos, encoding) lives in the per-doc att metadata JSON under `^CouchPort.Docs`.
The stream's underlying storage defaults to `^%Stream.GlobalBinaryD` but can be
overridden to `^CouchPort.AttStream(dbName)` by setting `%Location` before the
first write, keeping attachment data physically separate from doc bodies.

### B.3.8 Security
```
^CouchPort.Sec(dbName) = {admins:{names,roles}, members:{names,roles}}
```

### B.3.9 Design docs (denormalized cache)
```
^CouchPort.DDoc(dbName, ddocId)                       = <currentRev>
^CouchPort.DDoc(dbName, ddocId, "views", viewName)    = $lb(mapSource, reduceSource, language)
^CouchPort.DDoc(dbName, ddocId, "filters", filterName) = <source>
^CouchPort.DDoc(dbName, ddocId, "validate")           = <source>
^CouchPort.DDoc(dbName, ddocId, "signature")          = <md5 of functions, used for view ETag>
```
Updated whenever a `_design/*` doc is written. Views keyed by this denormalization
avoid reparsing the JSON on every query.

### B.3.10 View results
```
^CouchPort.View(dbName, ddocId, viewName, "seq")                = <lastProcessedSeq>
^CouchPort.View(dbName, ddocId, viewName, "row", key, docId)    = <emitted value>
^CouchPort.View(dbName, ddocId, viewName, "reduced", groupKey)  = <reduced value>
^CouchPort.View(dbName, ddocId, viewName, "signature")          = <md5>
```
Views are incrementally built: each background pass picks up changes from
`^CouchPort.Changes(dbName, lastSeq):)` and runs the map function (via QuickJS)
over the changed docs. The `row` subscript uses the emitted key as the subscript
so `$Order` traversal gives sorted-by-key output for free — the exact semantics
CouchDB views expose.

### B.3.11 Mango indexes
```
^CouchPort.Index(dbName, ddocId, indexName, "def")   = {type, fields, partial_filter}
^CouchPort.Index(dbName, ddocId, indexName, "seq")   = <last seq projected>
```
Mango indexes are declared and their actual storage lives in the SQL projection
(see B.4) — this global tracks metadata and projection state.

### B.3.12 Continuous changes wake-up
```
^CouchPort.Notify(dbName) = <pulse counter>
```
Writer path: `$Increment(^CouchPort.Notify(dbName))`. Reader path (longpoll /
continuous): poll this value in a short sleep loop (50–200 ms) and fire when it
advances. MVP uses polling; later we can switch to `%SYSTEM.Event` if available
in this IRIS build.

### B.3.13 Users
```
^CouchPort.Users(userName) = {JSON _users doc with pbkdf2 fields}
```
Or we create a real `_users` database per the CouchDB model and let it use the
standard `^CouchPort.Docs("_users", ...)` storage. **Decision: use a real
`_users` database** — keeps all the usual doc tooling (replication, _find)
working on user docs. This matches CouchDB exactly.

## B.4 — SQL Projection (Mango Read Path)

A shadow table, maintained synchronously on every successful write, holds the
**winning revision** of every non-design, non-local doc. This is the CQRS read
model Mango queries against.

### B.4.1 Schema
```objectscript
Class CouchPort.Projection.Winners Extends %Persistent
{
Property DbName As %String(MAXLEN=256) [ Required ];
Property DocId As %String(MAXLEN=2048) [ Required ];
Property WinningRev As %String(MAXLEN=128) [ Required ];
Property Seq As %BigInt [ Required ];
Property Deleted As %Boolean [ Required, InitialExpression = 0 ];
Property Body As %String(MAXLEN="");                 // JSON text of winning body
Property DocType As %String(MAXLEN=512) [ SqlComputed, SqlComputeCode =
    {Set {*} = ##class(CouchPort.Util.Json).ExtractPath({Body}, "$.type")} ];

Index PKey On (DbName, DocId) [ Unique, PrimaryKey ];
Index BySeq On (DbName, Seq);
Index ByType On (DbName, DocType);                   // default helper index
}
```

The `Body` column is the full JSON as text; IRIS SQL `JSON_VALUE(Body, '$.path')`
is used for field extraction in generated Mango queries. Specific Mango indexes
create additional computed columns + SQL indexes at `_index` creation time.

### B.4.2 Dynamic indexes from `_index`
When `POST /{db}/_index` creates an index on fields `["year","author"]`, the
`CouchPort.Query.Mango.Index` class:
1. Writes the index metadata to `^CouchPort.Index(...)`.
2. Writes a design doc (so Mango indexes round-trip to replication clients).
3. Creates an IRIS SQL index via `CREATE INDEX ... ON CouchPort.Projection.Winners
   (JSON_VALUE(Body, '$.year'), JSON_VALUE(Body, '$.author')) WHERE DbName = ...`.

Partial-filter selectors become `WHERE` clauses on the index definition.

### B.4.3 Write sync
Every successful doc write (in `CouchPort.Core.Document` and `CouchPort.Core.BulkDocs`)
calls `CouchPort.Projection.Mapper.Sync(dbName, docId, winningRev, body, deleted, seq)`
which does an UPSERT on `CouchPort.Projection.Winners`. This is part of the same
transaction as the global writes — either all commit or all roll back.

### B.4.4 Mango translation
`CouchPort.Query.Mango.Translator` takes a normalized selector AST and emits:
```sql
SELECT DocId, WinningRev, Body
FROM CouchPort.Projection.Winners
WHERE DbName = ?
  AND Deleted = 0
  AND JSON_VALUE(Body, '$.year') = ?
  AND JSON_VALUE(Body, '$.author') = ?
ORDER BY JSON_VALUE(Body, '$.year') ASC
LIMIT ? OFFSET ?
```

Operator mapping:
- `$eq`, `$ne`, `$lt`, `$lte`, `$gt`, `$gte` → direct SQL comparison on `JSON_VALUE`.
- `$in`, `$nin` → `IN`, `NOT IN`.
- `$exists` → `JSON_VALUE(...) IS [NOT] NULL`.
- `$type` → additional type-check via a helper SQL function.
- `$regex` → `JSON_VALUE(...) %MATCHES '...'` (IRIS regex operator).
- `$and`, `$or`, `$not`, `$nor` → `AND`/`OR`/`NOT`/combined.
- `$elemMatch`, `$allMatch`, `$all`, `$size`, `$keyMapMatch` → `JSON_TABLE`-based
  subqueries. These are the hardest cases; expect iterative refinement.
- `$mod` → arithmetic modulo.

Queries that cannot be expressed in SQL (rare: exotic `$elemMatch` + `$regex`
combinations) fall back to `CouchPort.Query.Mango.FallbackScan`, which iterates
`^CouchPort.Docs` and filters in-memory — matches CouchDB's `_all_docs` scan
fallback and gives `_explain` a correct answer.

### B.4.5 `_explain`
Built from the planner's decision record: the selected index (or
`_all_docs` fallback), the normalized selector, the computed SQL range, and the
query opts.

## B.5 — REST Dispatch Layer

Single top-level router extending `%CSP.REST`, with forwarded sub-routers for
each subsystem. The UrlMap XDATA block is the primary source of truth for all
wire paths.

```objectscript
XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
  <!-- Server-level -->
  <Route Url="/"                    Method="GET"     Call="CouchPort.API.Server:Welcome"/>
  <Route Url="/_all_dbs"            Method="GET"     Call="CouchPort.API.Server:AllDbs"/>
  <Route Url="/_dbs_info"           Method="GET,POST" Call="CouchPort.API.Server:DbsInfo"/>
  <Route Url="/_uuids"              Method="GET"     Call="CouchPort.API.Server:Uuids"/>
  <Route Url="/_up"                 Method="GET"     Call="CouchPort.API.Server:Up"/>
  <Route Url="/_session"            Method="GET,POST,DELETE" Call="CouchPort.API.Session:Handle"/>
  <Route Url="/_replicate"          Method="POST"    Call="CouchPort.API.Session:Replicate"/>
  <!-- Database-level -->
  <Route Url="/:db"                 Method="PUT,DELETE,GET,POST" Call="CouchPort.API.Database:Handle"/>
  <Route Url="/:db/_all_docs"       Method="GET,POST" Call="CouchPort.API.Database:AllDocs"/>
  <Route Url="/:db/_design_docs"    Method="GET,POST" Call="CouchPort.API.Database:DesignDocs"/>
  <Route Url="/:db/_local_docs"     Method="GET,POST" Call="CouchPort.API.Database:LocalDocs"/>
  <Route Url="/:db/_bulk_docs"      Method="POST"    Call="CouchPort.API.Database:BulkDocs"/>
  <Route Url="/:db/_bulk_get"       Method="POST"    Call="CouchPort.API.Find:BulkGet"/>
  <Route Url="/:db/_changes"        Method="GET,POST" Call="CouchPort.API.Changes:Handle"/>
  <Route Url="/:db/_revs_diff"      Method="POST"    Call="CouchPort.API.Replication:RevsDiff"/>
  <Route Url="/:db/_missing_revs"   Method="POST"    Call="CouchPort.API.Replication:MissingRevs"/>
  <Route Url="/:db/_security"       Method="GET,PUT" Call="CouchPort.API.Database:Security"/>
  <Route Url="/:db/_revs_limit"     Method="GET,PUT" Call="CouchPort.API.Database:RevsLimit"/>
  <Route Url="/:db/_purge"          Method="POST"    Call="CouchPort.API.Database:Purge"/>
  <Route Url="/:db/_compact"        Method="POST"    Call="CouchPort.API.Database:Compact"/>
  <Route Url="/:db/_ensure_full_commit" Method="POST" Call="CouchPort.API.Database:EnsureFullCommit"/>
  <Route Url="/:db/_find"           Method="POST"    Call="CouchPort.API.Find:Find"/>
  <Route Url="/:db/_index"          Method="GET,POST" Call="CouchPort.API.Find:IndexHandle"/>
  <Route Url="/:db/_explain"        Method="POST"    Call="CouchPort.API.Find:Explain"/>
  <!-- Document-level. The Forward form lets us strip /:db and pass the tail. -->
  <Map Prefix="/:db/_local"         Forward="CouchPort.API.Document.Local"/>
  <Map Prefix="/:db/_design"        Forward="CouchPort.API.DesignDoc"/>
  <!-- Catch-all document id. Must come last. -->
  <Route Url="/:db/:docid"          Method="GET,PUT,DELETE,COPY" Call="CouchPort.API.Document:Handle"/>
  <Route Url="/:db/:docid/:attname" Method="GET,PUT,DELETE" Call="CouchPort.API.Attachment:Handle"/>
</Routes>
}
```

Notes:
- `OnPreDispatch` intercepts every request to extract auth (basic / cookie / JWT),
  populate a request-scoped `%session` or context object, and enforce db-level
  security.
- `ProcessCorsRequest` is enabled globally for cross-origin CouchDB clients
  (PouchDB in a browser).
- `AllowOutputFlush=1` is set in `OnPreHTTP` for the changes feed handler so
  continuous/longpoll can `Flush()` incrementally.
- `Http500()` and the like are replaced with `CouchPort.Util.Error.Send(status, error, reason)`
  which emits the CouchDB JSON envelope.
- URL decoding needs special-case handling for `_design/*` and `_local/*` — the
  prefix is literal, the rest is `%2F`-encoded. `CouchPort.Util.URL.ParseDocId`
  owns this.

## B.6 — MVCC / Revision Engine

Port of `couch_doc.erl` and `couch_key_tree.erl` to ObjectScript.

### B.6.1 Rev hash computation (byte-compat critical)
```
revId_new = MD5( canonicalJson(body_minus_rev)
              || parentRevId || deletedFlag || concat(attachment_digests) )
gen_new   = gen_parent + 1
rev_new   = gen_new _ "-" _ toHex(revId_new)
```

`canonicalJson` must produce the exact byte sequence CouchDB's
`couch_util:to_binary/1` does for JSON — sorted keys, no whitespace, `true`/`false`
lowercase, numbers in their shortest representation. **This is the single most
fragile piece of the port; any drift breaks `new_edits=false` replication.**

Mitigation: build a test harness that round-trips thousands of docs through both
a real CouchDB instance and CouchPort, comparing rev hashes byte-for-byte.

### B.6.2 Rev tree merge
```
CouchPort.Core.RevTree.Merge(tree, newPath) → (merged, result)
```
Where `result ∈ {new_leaf, new_branch, internal_node, already_has}`.

The tree is stored in globals (B.3.4) and manipulated in-memory as a
`%DynamicObject` during merge, then written back in a single transaction.

### B.6.3 Winning rev algorithm
```
winner = argmax over leaves by (not deleted, generation, rev_hash)
```
Implemented in `CouchPort.Core.Conflict.SelectWinner(dbName, docId)`. Called on
every write and on every read that lacks the cached winner.

## B.7 — Changes Feed Engine

### B.7.1 Normal feed
Straightforward `$Order` loop over `^CouchPort.Changes(dbName, since+1):` up to
`limit`. Build response JSON, emit.

### B.7.2 Longpoll
Same as normal, but if no changes after `since`, poll `^CouchPort.Notify(dbName)`
in a sleep loop (bounded by `timeout`, default 60s). On notify-bump, run the
normal query and return.

### B.7.3 Continuous
`AllowOutputFlush=1` in OnPreHTTP. Main loop:
```
loop:
  scan ^CouchPort.Changes(dbName, since+1):) up to batch size
  for each row: write JSON + "\n", Flush()
  update since
  if no rows:
    if idle > heartbeat:
      write "\n" (heartbeat), Flush()
    sleep 50ms, poll ^CouchPort.Notify, retry
  if client disconnected (detect via Write error):
    break
```

### B.7.4 EventSource
Same loop as continuous but framing is `data: {...}\nid: <seq>\n\n` and heartbeat
is `:\n\n`. Content-Type `text/event-stream`.

### B.7.5 Filters
`CouchPort.Changes.Filter.Apply(row, filterSpec)`:
- `_doc_ids`: set membership check.
- `_selector`: reuse `CouchPort.Query.Mango.Evaluator` (in-memory selector match).
- `_design`: prefix match.
- `_view`: look up the ddoc's map function, run it via `CouchPort.JSRuntime.Sandbox.RunMap`,
  pass if emit-count > 0.
- `ddoc/name`: look up the filter function source, run via
  `CouchPort.JSRuntime.Sandbox.RunFilter`, pass on truthy return.

### B.7.6 Wake-up signaling
Every write does `$Increment(^CouchPort.Notify(dbName))` as its last step. Readers
poll on 50ms ticks. This costs a small amount of CPU vs. an event primitive but
is portable across all IRIS versions and simple to reason about. If
`%SYSTEM.Event` is available in the target IRIS build we swap it in behind the
`CouchPort.Changes.Pump` interface later.

## B.8 — Replication Endpoints

### B.8.1 `_revs_diff`
Input: `{docid: [rev1, rev2, ...], ...}`. For each docid, look up
`^CouchPort.Tree(dbName, docid, "leaf", ...)` and `^CouchPort.Tree(dbName,
docid, "stub", ...)` to determine which of the requested revs are present.
Emit missing list and possible_ancestors (stub nodes).

### B.8.2 `_bulk_get`
Input: `{docs: [{id, rev, atts_since}, ...]}`. Fetch each (id, rev) from
`^CouchPort.Docs`, apply `atts_since` optimization, return wrapped in
`{results: [{id, docs: [{ok: {...}}]}]}`.

### B.8.3 `open_revs`
`GET /{db}/{docid}?open_revs=all|[...]&revs=true&latest=true` with
`Accept: multipart/mixed` returns each rev as a MIME part. Each part is itself
a `multipart/related` if attachments are requested. `CouchPort.Attachment.MultipartWriter`
handles the nesting.

### B.8.4 Checkpoints
`PUT/GET /{db}/_local/{replication_id}` stores a plain JSON doc in
`^CouchPort.Local(dbName, "_local/" _ replication_id)`. No rev tree, no
replication (tautologically). Treated like any other local doc.

### B.8.5 `replication_id` byte-compat
`CouchPort.Replication.ReplicationID.Compute(source, target, options)` must
hash the exact same bytes as `couch_replicator_ids:replication_id/1`. This is
source-verified against the Erlang module and covered by a parity test suite.

## B.9 — QuickJS Sandbox (shipped in MVP)

### B.9.1 Strategy
- Language: Python (embedded) hosting the `quickjs` (PetterS) C-extension.
- Isolation: one `quickjs.Context` per ddoc, created lazily on first use, cached
  in a Python-side pool. The pool is an attribute of a process-local Python
  module imported via `%SYS.Python`.
- Limits: `context.set_memory_limit(16 * 1024 * 1024)`, `context.set_time_limit(5.0)`,
  `context.set_max_stack_size(512 * 1024)`. Configurable per-ddoc later.
- Protocol: re-implementation of the [couchjs line protocol](https://docs.couchdb.org/en/stable/query-server/protocol.html)
  as in-process Python functions, since we're not running a subprocess —
  we bind `reset`, `add_lib`, `add_fun`, `map_doc`, `reduce`, `rereduce`,
  `ddoc new`, `ddoc call` as direct function calls.

### B.9.2 ObjectScript facade
```objectscript
Class CouchPort.JSRuntime.Sandbox Extends %RegisteredObject
{
ClassMethod MapDoc(pDdocSignature As %String, pMapSrc As %String, pDoc As %DynamicObject) As %DynamicArray
ClassMethod Reduce(pDdocSignature As %String, pReduceSrc As %String, pKeys As %DynamicArray, pValues As %DynamicArray) As %DynamicObject
ClassMethod ReReduce(pDdocSignature As %String, pReduceSrc As %String, pValues As %DynamicArray) As %DynamicObject
ClassMethod Validate(pDdocSignature As %String, pValidateSrc As %String, pNewDoc As %DynamicObject, pOldDoc As %DynamicObject, pUserCtx As %DynamicObject, pSecObj As %DynamicObject) As %Status
ClassMethod RunFilter(pDdocSignature As %String, pFilterSrc As %String, pDoc As %DynamicObject, pReq As %DynamicObject) As %Boolean
}
```

Each method serializes its `%DynamicObject` args to a JSON string, calls the
underlying Python function with the string, and parses the JSON result. Cost per
call: one JSON round-trip — acceptable for the frequency of these operations.

### B.9.3 Python host (abridged)
```python
# iris-couchport-quickjs.py, imported by %SYS.Python
import quickjs, json

_pool = {}  # signature -> {"ctx": quickjs.Context, "funcs": {name: compiled}}

def _ctx_for(sig, libs=None):
    entry = _pool.get(sig)
    if entry is None:
        ctx = quickjs.Context()
        ctx.set_memory_limit(16 * 1024 * 1024)
        ctx.set_time_limit(5.0)
        ctx.set_max_stack_size(512 * 1024)
        entry = {"ctx": ctx, "funcs": {}}
        _pool[sig] = entry
    return entry

def map_doc(sig, map_src, doc_json):
    entry = _ctx_for(sig)
    ctx = entry["ctx"]
    f = entry["funcs"].get(map_src)
    if f is None:
        # Install an emit() that captures into a per-call list.
        ctx.eval("var __emitted = [];")
        ctx.eval("function emit(k, v) { __emitted.push([k, v]); }")
        f = ctx.eval("(" + map_src + ")")
        entry["funcs"][map_src] = f
    ctx.eval("__emitted = [];")
    doc = ctx.parse_json(doc_json)
    f(doc)
    return ctx.eval("JSON.stringify(__emitted)")

def validate(sig, validate_src, new_doc_json, old_doc_json, user_ctx_json, sec_obj_json):
    entry = _ctx_for(sig)
    ctx = entry["ctx"]
    try:
        f = ctx.eval("(" + validate_src + ")")
        f(ctx.parse_json(new_doc_json),
          ctx.parse_json(old_doc_json),
          ctx.parse_json(user_ctx_json),
          ctx.parse_json(sec_obj_json))
        return json.dumps({"ok": True})
    except quickjs.JSException as e:
        msg = str(e)
        # Map {forbidden:...} / {unauthorized:...} to HTTP codes.
        if "forbidden" in msg:
            return json.dumps({"forbidden": msg})
        if "unauthorized" in msg:
            return json.dumps({"unauthorized": msg})
        return json.dumps({"error": "validation_failed", "reason": msg})
```

This is a sketch; the final Python module is a CouchPort project artifact and
is installed alongside the ObjectScript classes.

### B.9.4 Sandbox guarantees

- Memory cap enforced by QuickJS itself.
- Time cap enforced by QuickJS itself.
- No FS / network access — QuickJS has no bindings for them; we do not inject any.
- Each ddoc gets an isolated context; one ddoc's global state cannot leak into
  another's.
- Exceptions inside JS are caught and converted to an error envelope; the IRIS
  process is never affected.
- Context pool is per-IRIS-process; a process restart wipes it, which is the
  correct behavior (matches CouchDB's couchjs per-process semantics).

### B.9.5 Why this is MVP-safe

- The engine works correctly without the sandbox (Mango `_find` is the primary
  query path). If QuickJS is broken or disabled, `_find` still works, replication
  still works, and only design-doc JS views/filters/validators return a clear
  error.
- The sandbox interface is a single class (`CouchPort.JSRuntime.Sandbox`) —
  we can swap the underlying implementation (PetterS `quickjs`, py-mini-racer,
  external `couchjs` subprocess) without touching the rest of the codebase.
- We avoid the 30+ MB per-process cost of SpiderMonkey; QuickJS is ~5 MB
  (per Cloudant's published numbers).

## B.10 — Phased Delivery Plan

Aligned to initial-prompt.md phases 0–4, with sub-phases and cross-cutting
concerns slotted in. Each phase ends with a concrete testable milestone.

### Phase 0 — Architecture and Scaffolding
- Repository layout: `/src/CouchPort/**` (ObjectScript `.cls` files), `/test/CouchPort/**`
  (`%UnitTest.TestCase` classes), `/python/couchport_quickjs/**` (Python sandbox
  host), `/docs` (architecture docs), `/tools` (benchmarking, parity runner).
- CI / local compile loop: `compile_objectscript_package` MCP pass, `execute_unit_tests`.
- Skeleton packages listed in B.2, each containing an empty class with the
  declared methods (`Quit $$$OK` stubs).
- `CouchPort.Util.Error`, `CouchPort.Util.Json`, `CouchPort.Util.URL`,
  `CouchPort.Util.HTTP` fully implemented — these are the foundation.
- `CouchPort.API.Router` extending `%CSP.REST` with the UrlMap from B.5, all
  handlers returning `501 Not Implemented` with the correct error envelope.
- Welcome endpoint (`GET /`) fully implemented — client sniff test must pass.
- **Milestone**: `curl http://localhost:52773/couchport/` returns a well-formed
  CouchDB welcome object; `curl http://localhost:52773/couchport/_uuids?count=3`
  returns three hex UUIDs.

### Phase 1 — Core document API and globals storage
- `CouchPort.Core.Rev`, `CouchPort.Core.RevTree`, `CouchPort.Core.Conflict`
  fully implemented with unit tests. **Rev hash byte-compat test against a real
  CouchDB instance is the exit criterion** — not optional.
- `CouchPort.Storage.*` globals layout implemented with a wrapper class for each
  subtree. No SQL yet.
- `CouchPort.Core.Database` — create, drop, info, metadata.
- `CouchPort.Core.Document` — PUT, GET, DELETE, COPY; `new_edits=true` path.
- `CouchPort.Core.BulkDocs` — `_bulk_docs` with both `new_edits` modes.
- `_all_docs`, `_design_docs`, `_local_docs`.
- `_security` (storage only, no enforcement yet).
- `_revs_limit`, `_ensure_full_commit`, `_compact` (no-op 202).
- `CouchPort.Storage.Local` — `_local/*` doc CRUD.
- **Milestone**: Fauxton can create a database, insert/update/delete docs, and
  list them. `curl`-based replication _from_ CouchPort to a real CouchDB works
  end-to-end for simple docs (no attachments yet).

### Phase 1b — QuickJS sandbox (parallelizable with Phase 2)
- Python host module (`/python/couchport_quickjs/`) with `quickjs` dependency
  vendored or declared.
- `CouchPort.JSRuntime.Python` — `[Language=python]` wrapper methods.
- `CouchPort.JSRuntime.Protocol` — implementing reset/add_fun/map_doc/reduce/rereduce/ddoc-new/ddoc-call.
- `CouchPort.JSRuntime.Sandbox` — ObjectScript facade per B.9.2.
- `CouchPort.JSRuntime.Pool` — context caching.
- Smoke test: `function(doc){emit(doc.name, doc.value);}` run over 1000 docs,
  results collected and compared to a known-good reference.
- **Milestone**: `execute_classmethod` on `CouchPort.JSRuntime.Sandbox:MapDoc`
  returns emitted rows for a given map function source.

### Phase 2 — Sequences, changes, and attachments
- `CouchPort.Core.Sequence` — `$Increment` wrapper, stable seq token format.
- `CouchPort.Changes.Normal`, `Longpoll`, `Continuous`, `EventSource` — all four
  feed modes.
- `CouchPort.Changes.Filter` — `_doc_ids`, `_selector`, `_design`; JS filters
  via the sandbox from Phase 1b.
- `CouchPort.Changes.Pump` — wake-up via `^CouchPort.Notify` polling.
- `CouchPort.Attachment.Store` — `%Stream.GlobalBinary` integration.
- `CouchPort.Attachment.MultipartReader` / `MultipartWriter` — multipart/related
  and multipart/mixed.
- `CouchPort.Attachment.Digest` — `md5-<base64>` formatting.
- Attachment endpoints: inline, stub, multipart.
- Range request support on attachment GET.
- **Milestone**: Real CouchDB replicator (running as a peer) can pull from
  CouchPort and push to CouchPort, including docs with attachments and the
  continuous feed option. `_changes?feed=eventsource` works in a browser.

### Phase 3 — Mango and SQL projection
- `CouchPort.Projection.Winners` persistent class with storage + indexes.
- `CouchPort.Projection.Mapper` — write-sync on every doc operation.
- `CouchPort.Projection.Rebuilder` — batch rebuild for disaster recovery.
- `CouchPort.Query.Mango.Parser`, `Normalizer` — selector AST.
- `CouchPort.Query.Mango.Translator` — selector → IRIS SQL WHERE.
- `CouchPort.Query.Mango.Planner` — index selection, cost estimation.
- `CouchPort.Query.Mango.Index` — `_index` CRUD, dynamic SQL index creation.
- `CouchPort.Query.Mango.Cursor` — query execution, bookmark pagination.
- `CouchPort.Query.Mango.Explain` — `_explain` response builder.
- `CouchPort.Query.Mango.FallbackScan` — `_all_docs` scan for unrepresentable queries.
- `CouchPort.Query.Mango.Evaluator` — in-memory selector match (reused by `_changes` filter).
- **Milestone**: The Mango test suite from `sources/couchdb/src/mango/test/` passes
  (ported to ObjectScript %UnitTest or run via a Python harness hitting the HTTP API).

### Phase 4 — Replication protocol completion
- `CouchPort.Replication.ReplicationID` — byte-compat hash.
- `CouchPort.Replication.RevsDiff` — `_revs_diff` full semantics including
  `possible_ancestors`.
- `CouchPort.Replication.BulkGet` — `_bulk_get` with `atts_since`.
- `CouchPort.Replication.OpenRevs` — `open_revs=all`, `open_revs=[...]`,
  `latest=true`, multipart/mixed response.
- `CouchPort.Replication.Checkpoint` — `_local` with `history[]` and session_id.
- `_replicator` database support (storage only; persistent scheduler deferred).
- **Milestone**: A real CouchDB node running as a peer successfully replicates
  bidirectionally with CouchPort. Replication runs to completion, checkpoints
  survive restarts, conflicts propagate correctly. This is **the** acceptance
  test for the whole project and the definition of "wire-compatible."

### Phase 5 — Views and JS design-doc integration (still MVP)
- `CouchPort.View.Engine` — incremental build pump reading from `^CouchPort.Changes`.
- `CouchPort.View.Store` — row and reduced storage.
- `CouchPort.View.BuiltinReduce` — `_sum`, `_count`, `_stats`, `_approx_count_distinct`.
- `CouchPort.View.Query` — view query parameters, group/group_level semantics.
- `CouchPort.View.ETag` — signature-based ETag matching CouchDB's format.
- JS map integration via `CouchPort.JSRuntime.Sandbox`.
- JS filter integration in `CouchPort.Changes.Filter`.
- `CouchPort.Security.Validate` — `validate_doc_update` invocation on every write
  via the sandbox.
- **Milestone**: A design doc with JS views, filters, and `validate_doc_update`
  functions works identically against CouchPort and real CouchDB when tested with
  PouchDB as the client.

### Phase 6 — Auth and security
- `CouchPort.Security.Auth` — request auth extraction (basic, cookie, JWT, proxy).
- `CouchPort.Security.AuthSession` — HMAC-signed cookie byte-compat (source-verify
  against `couch_httpd_auth.erl`).
- `CouchPort.Security.User` — `_users` db handling, PBKDF2-HMAC-SHA1.
- `CouchPort.Security.Session` — `/_session` cookie flow.
- `_security` enforcement (admin / member check on every request).
- `validate_doc_update` exemption for admins and ddoc writes.
- **Milestone**: Existing clients (PouchDB, Cloudant libraries) authenticate
  against CouchPort with their existing credential DBs.

### Phase 7 — Hardening, parity, and performance
- Parity test suite: a Python harness that runs the same operations against
  CouchPort and a real CouchDB instance, comparing responses byte-for-byte.
- Benchmark suite: throughput on doc writes, bulk writes, changes feed, Mango
  queries, view builds.
- Concurrency audit: every `$Increment`, `LOCK`, `TSTART` path reviewed for
  correctness under load.
- Stress test with the CouchDB `replicator` binary in continuous mode for 24+ hours.
- **Milestone**: "Ship" — first public release with a documented compatibility
  matrix and known-gaps list.

## B.11 — Risk Register

| Risk | Impact | Mitigation |
|---|---|---|
| Rev hash byte-compat drift | Replication round-trip breaks silently | Parity test suite from Phase 1, run on every CI build |
| `replication_id` byte-compat drift | Clients re-replicate everything on reconnect | Source-verify against `couch_replicator_ids.erl`, parity test |
| `AuthSession` HMAC format drift | Cookie clients fail to auth | Source-verify against `couch_httpd_auth.erl` |
| JSON canonicalization differences between IRIS `%ToJSON` and CouchDB's encoder | Rev hash mismatch everywhere | Implement `CouchPort.Util.Json.Canonicalize` from scratch rather than relying on `%ToJSON` default order |
| QuickJS Python extension build fails on target IRIS Python version | MVP ships without JS views | Pre-verify against `%SYS.Python.GetPythonVersion()`; have `py-mini-racer` as a fallback |
| IRIS global node size limit (~28 KB) vs large doc bodies | Silent write failures | Automatic promote-to-stream for bodies over threshold |
| Mango translation for `$elemMatch`, `$allMatch`, `$regex` across JSON arrays is hard in IRIS SQL | Query fails with incomprehensible SQL error | Fallback to `FallbackScan` for unrepresentable queries; `_explain` reports `_all_docs` |
| Long-polling / continuous feed resource exhaustion under many clients | Process count spike, memory pressure | Cap connections per db; document with `%CSP` gateway tuning |
| Chunked transfer encoding edge cases in `%CSP.Response` | Clients see truncated responses | Extensive integration tests with real clients (PouchDB, Cloudant libraries) |
| Dev divergence from CouchDB 3.x as new versions land | Gradual compat erosion | Pin the source tree version used as reference; track upstream release notes |

## B.12 — Open Questions / Spikes Recommended Before Phase 1

1. **JSON canonicalization** — exactly which algorithm does `couch_util:to_binary/1`
   use? Does it sort keys recursively? How are integer vs float numbers formatted?
   **Spike**: 1-day read of `couch_util.erl` + test harness against a real node.
2. **`replication_id` inputs** — what's the exact list of inputs in CouchDB 3.5,
   including whether `user_ctx_roles` is included and in what order? **Spike**:
   1-day read of `couch_replicator_ids.erl` + write a test that computes the ID
   for the same source/target/options and compares byte-for-byte.
3. **`AuthSession` HMAC** — exact format of the to-be-signed bytes and choice of
   HMAC algorithm (SHA1 historically, SHA256 more recent?). **Spike**: read
   `couch_httpd_auth.erl` and write a parity test.
4. **`%CSP.Response.Flush()` chunked behavior** — does it actually emit each
   write as a separate chunk, or does it batch? Required for continuous `_changes`
   to work. **Spike**: 2-hour test against a real HTTP client with a chunk-aware
   parser.
5. **`%SYS.Python` + `quickjs` build** — does the PetterS `quickjs` package
   install and load cleanly in the embedded Python shipped with the target IRIS
   version? **Spike**: half-day attempt at a `pip install quickjs` followed by
   `##class(%SYS.Python).Import("quickjs")` test.
6. **IRIS SQL dynamic indexes on computed JSON paths** — does IRIS support
   indexes on `JSON_VALUE(col, '$.path')` expressions, or do we need computed
   properties on the class? **Spike**: half-day experiment on `CouchPort.Projection.Winners`.
7. **`%Net.MIMEReader` chunk size** — can it parse a streaming multipart body
   without materializing the whole thing in memory first? **Spike**: half-day test
   with a multi-GB fake attachment.

Completing these spikes before Phase 1 starts de-risks 80% of the byte-compat
gotchas that would otherwise appear mid-implementation.

## B.13 — Implementation-time Conventions

- Every public method that can fail returns `%Status`; `Set tSC = $$$OK` first,
  `Quit tSC` last, `Try`/`Catch` in between. No argumented `Quit` inside try blocks.
- Every method that accepts or returns JSON uses `%DynamicObject` / `%DynamicArray`,
  not custom classes, except for the SQL projection.
- All globals are accessed through a `CouchPort.Storage.*` wrapper class — no
  direct `^CouchPort...` references in the API or Core layers. This keeps the
  storage layout changeable.
- All HTTP writes go through `CouchPort.Util.HTTP.Write*` helpers — no direct
  `%response.Write` calls in handlers. This keeps chunked/ETag/envelope handling
  in one place.
- Every subsystem has a companion `CouchPort.Test.*` `%UnitTest.TestCase` class.
  No subsystem is "done" until its test class passes.
- Logs go through `CouchPort.Util.Log`; no raw `Write` for debug or `SET ^ClineDebug`
  in committed code.
- Class parameter names use camelCase or ALLCAPS, never underscores
  (per project ObjectScript rules).
- Abstract methods have bodies returning the appropriate zero value
  (per project ObjectScript rules).

---

# PART B.14 — SPIKE RESULTS (completed)

Four of the seven spikes from §B.12 have been run. The remaining three (AuthSession
HMAC, `%SYS.Python`+`quickjs` install, `%Net.MIMEReader` streaming) are deferred
to Phase 0 because they either need a live IRIS environment (5, 7) or are lower
priority now that 1, 2, 4, 6 have been resolved (3).

## Spike 1 — Rev hash algorithm and `new_edits=false` trust model

**Status:** ✅ Complete, 2026-04-10

### Finding 1: CouchDB's rev hash uses Erlang ETF

`new_revid/1` in [couch_db.erl:1289-1314](sources/couchdb/src/couch/src/couch_db.erl#L1289-L1314)
computes:
```
MD5( term_to_binary([Deleted, OldStart, OldRev, Body, DigestedAtts],
                    [{minor_version, 1}]) )
```
This uses Erlang's External Term Format (ETF) — a binary serialization specific to
the Erlang VM. Reproducing ETF byte-for-byte in ObjectScript would require
implementing ~20 type tags (atoms, small/large ints, tuples, lists, binaries,
floats) and preserving the exact nested `{PropList}` tuple structure the Erlang
JSON parser produces. Days of work, high risk of subtle drift.

### Finding 2: `new_edits=false` does NOT verify the rev hash

The replicated write path, from HTTP entry to on-disk merge, never re-hashes the
supplied rev. Smoking gun in
[couch_db_updater.erl:615-621](sources/couchdb/src/couch/src/couch_db_updater.erl#L615-L621):

```erlang
merge_rev_tree(OldInfo, NewDoc, _Client, true) ->
    %% We're merging in revisions without caring about
    %% conflicts. Most likely this is a replication update.
    OldTree = OldInfo#full_doc_info.rev_tree,
    NewTree0 = couch_doc:to_path(NewDoc),
    {NewTree, _} = couch_key_tree:merge(OldTree, NewTree0),
    OldInfo#full_doc_info{rev_tree = NewTree}.
```

Full call chain traced:
```
chttpd_db.erl:609 db_req
  → couch_doc:parse_rev              [format check only: N-<32hex>]
  → chttpd_db.erl:2252 validate_revs [presence check only]
  → fabric:update_docs ?REPLICATED_CHANGES
    → couch_db.erl:1357 update_docs (?REPLICATED_CHANGES path)
      → prep_and_validate_replicated_updates
      → couch_doc:to_path            [supplied rev IDs used as-is]
      → couch_key_tree:multi_merge
    → write_and_commit
      → couch_db_updater.erl:615 merge_rev_tree (ReplicatedChanges=true)
        → couch_doc:to_path          [no re-hashing]
        → couch_key_tree:merge       [no re-hashing]
```

Format validation is strict: `parse_revid` at [couch_doc.erl:191-198](sources/couchdb/src/couch/src/couch_doc.erl#L191-L198)
requires exactly 32 bytes of valid lowercase hex for any generation > 0. Garbage
like `"bogus"` or `"1-abc"` is rejected with 400 Bad Request.

### Decision: CouchPort uses its own rev hash algorithm

Since the wire protocol does not verify rev hashes, there is no compat
requirement to match CouchDB's ETF+MD5 output. CouchPort will use an
ObjectScript-native algorithm that is:
1. Deterministic on the CouchPort side (same inputs → same hash).
2. Produces valid CouchDB rev format: `N-<32 lowercase hex chars>`.
3. Cheap to implement and reason about.

### CouchPort rev hash specification

```
canonicalJson = serialize JSON with:
    - recursively sorted object keys (lexicographic, UTF-8)
    - no insignificant whitespace
    - numbers in shortest round-trip form
    - strings escaped per RFC 8259 (\uXXXX for controls)

hashInput = canonicalJson({
    "d": <boolean: _deleted flag>,
    "p": <string or null: parent rev id, full "N-hash" string or null>,
    "b": <object: doc body minus _id, _rev, _revisions, _attachments>,
    "a": [                              // sorted by attachment name
        {"n": <name>, "t": <content_type>, "d": <md5 base64>},
        ...
    ]
})

hash = lowerHex( MD5( toUtf8Bytes(hashInput) ) )
rev  = (parentGen + 1) || "-" || hash
```

### Round-trip scenarios verified

| Scenario | Outcome |
|---|---|
| Client → CouchPort interactive write | CouchPort mints with its algorithm, stores, returns. OK. |
| CouchPort → CouchDB replication (new_edits=false) | CouchDB stores CouchPort's hash verbatim. OK. |
| CouchDB → CouchPort replication (new_edits=false) | CouchPort stores CouchDB's hash verbatim. OK. |
| Client reads from either side | Rev is opaque to client per CouchDB docs. OK. |
| Simultaneous writes on both peers | Two hashes → conflict → deterministic lex winner. OK. |
| Client updates a CouchDB-originated doc on CouchPort | CouchPort looks up parent rev (structural), mints child with its algorithm. OK. |

### Risk register update

**Risk "Rev hash byte-compat drift"** — ✅ **ELIMINATED**. No byte-compat is required.
Replaced with a smaller risk: "CouchPort's canonical JSON serializer must be
deterministic across IRIS versions" — mitigated by writing
`CouchPort.Util.Json.Canonicalize` ourselves rather than relying on `%ToJSON`.

### Spike 1 summary

The single highest-risk item in the project — ETF byte-compat — is retired. The
simpler JSON-canonical algorithm is architecturally sufficient, interoperates
correctly with CouchDB in all replication scenarios, and can be implemented in
ObjectScript in hours rather than days.

---

## Spike 2 — `replication_id` byte-compat trust model

**Status:** ✅ Complete, 2026-04-11

### Finding: replication_id is a lookup key only

Identical pattern to spike 1. The replication_id is used ONLY as the document id
of the checkpoint at `_local/{replication_id}`. It is never stored inside a
checkpoint body, never compared on read, and never verified. Checkpoint
correlation between source and target peers happens via a different field —
`session_id`, which is a fresh UUID generated per replication run.

Smoking gun in
[couch_replicator_scheduler_job.erl:1008-1020](sources/couchdb/src/couch_replicator/src/couch_replicator_scheduler_job.erl#L1008-L1020):

```erlang
compare_replication_logs(SrcDoc, TgtDoc) ->
    case get_value(<<"session_id">>, RepRecProps) ==
         get_value(<<"session_id">>, RepRecPropsTgt) of
        true  -> {OldSeqNum, OldHistory};
        false -> compare_rep_history(...)
    end.
```

Version walk at
[lines 732-755](sources/couchdb/src/couch_replicator/src/couch_replicator_scheduler_job.erl#L732-L755):
when a checkpoint is not found at the current `?REP_ID_VERSION` id, CouchDB
lazily recomputes v3, then v2, then v1 ids and retries. A missing checkpoint
triggers re-replication from seq 0, never an error.

### CouchDB's actual algorithm (for reference only — we do not reproduce it)

```erlang
replication_id(#rep{} = Rep, 4) ->
    UUID    = couch_server:get_uuid(),
    SrcInfo = get_v4_endpoint(Rep#rep.source),
    TgtInfo = get_v4_endpoint(Rep#rep.target),
    Base    = [UUID, SrcInfo, TgtInfo]
              ++ maybe_filter(Rep)
              ++ maybe_winning_revs_only(Rep)
              ++ maybe_since_seq(Rep),
    couch_util:to_hex(couch_hash:md5_hash(term_to_binary(Base))).
```

Source: [couch_replicator_ids.erl:33-131](sources/couchdb/src/couch_replicator/src/couch_replicator_ids.erl#L33-L131).
Uses `term_to_binary` — same ETF problem as the rev hash. We do not reproduce it.

### CouchPort `replication_id` specification

Reuses `CouchPort.Util.Json.Canonicalize` from spike 1:

```
idInput = canonicalJson({
    "v":   4,
    "src": {"host","port","path","user","headers_sorted"},
    "tgt": {"host","port","path","user","headers_sorted"},
    "fil": <filter spec or null>,
    "wro": <winning_revs_only or false>,
    "ssq": <since_seq or null>
})
baseId = lowerHex(MD5(toUtf8Bytes(idInput)))
ext    = (continuous    ? "+continuous"    : "")
      || (create_target ? "+create_target" : "")
```

### Interop consequences

| Scenario | Outcome |
|---|---|
| CouchPort replicator (CouchPort is the client) | Stores checkpoint at its own id; resumes from own checkpoint on next run. ✅ |
| CouchDB replicator pulls from CouchPort as target | Stores checkpoint at CouchDB's id; resumes from own checkpoint. ✅ |
| Both clients run concurrently on same source→target | Two separate checkpoint docs; harmless duplication of effort. ✅ |
| A replication job migrates between replicator clients | One-time re-replication from seq 0 on first run. ✅ (correct, slow once) |

### Risk register update

**Risk "`replication_id` byte-compat drift"** — ✅ **ELIMINATED**. Shared
implementation with the rev hash spec; `CouchPort.Replication.ReplicationID` is
a ~30-line class on top of `CouchPort.Util.Json.Canonicalize`.

---

## Spike 4 — `%CSP.Response.Flush()` and continuous `_changes` feasibility

**Status:** ⚠️ Complete with uncertainty, 2026-04-11 — live IRIS test required
before committing continuous/eventsource feeds to MVP scope.

### Findings from the IRIS source

- `%CSP.Response.Flush()` at
  [Response.cls:420-430](irislib/%CSP/Response.cls#L420-L430) calls `Write *-3`,
  the documented IRIS flush primitive that pushes the buffer to the CSP Gateway
  connection. No chunked-encoding header is emitted from ObjectScript.
- `AllowOutputFlush=1` at
  [Response.cls:397-410](irislib/%CSP/Response.cls#L397-L410) sends `aof=1` to
  the gateway with the semantic "do not aggregate small buffers before
  dispatching to the web server." The existence of this flag is strong evidence
  that the gateway DOES emit incremental frames to the wire.
- `%Net.ChunkedWriter` exists but is for outbound HTTP clients
  (`%Net.HttpRequest`), not for CSP Response bodies. Not directly reusable.
- `%CSP.StreamServer` line 171 comment "Gateway will fill in the length for us"
  when `ContentLength=""` is a strong hint that the CSP Gateway handles response
  framing — either final `Content-Length` for known-size responses or chunked
  encoding for streamed ones.
- Default session timeout is 900s
  ([Response.cls](irislib/%CSP/Response.cls)) — must be overridden to something
  large (e.g., 999999) in `OnPreHTTP` for continuous feeds.
- No built-in Server-Sent Events helper. We would set
  `Content-Type: text/event-stream` and emit `data:`/`id:` lines manually.
- `%CSP.WebSocket` exists with a 24-hour default timeout, but CouchDB clients do
  not speak WebSocket — not a direct fit.

### Open question that requires a live IRIS test

Does the CSP Gateway actually emit frames to the client incrementally when an
ObjectScript handler calls `Write … Flush() … Write … Flush()` in a loop, or
does it buffer until the handler returns?

The source-only investigation cannot answer this — the gateway is a separate
process from IRIS itself. A 10-minute live test using `iris-execute-mcp` tools
in Phase 0 will answer it definitively. Added as spike 4b in the todo list.

### Feed-by-feed feasibility

| Feed mode | Feasibility | Implementation path |
|---|---|---|
| `normal` | 🟢 Certain | One-shot JSON response, standard `%CSP.REST` handler |
| `longpoll` | 🟢 Certain | Handler sleeps-polling `^CouchPort.Notify(db)` up to `timeout`, then returns normal response; set `%response.Timeout=999999` in `OnPreHTTP` |
| `continuous` | 🟡 Pending spike 4b | `AllowOutputFlush=1` in `OnPreHTTP`; handler loops Write+Flush with `\n`-delimited rows; bare `\n` for heartbeat; `Set %response.Timeout=999999` |
| `eventsource` | 🟡 Pending spike 4b | Same pattern, Content-Type `text/event-stream`, `data: {...}\nid: <seq>\n\n` framing, `:\n\n` heartbeat |

### Decision

- **MVP ships guaranteed**: `normal` + `longpoll`. These cover PouchDB's
  replicator (the dominant CouchDB client), the CouchDB replicator in
  non-continuous mode, and the vast majority of third-party clients.
- **Continuous + eventsource are "best-effort MVP"**: built with the same
  handlers, gated on spike 4b in Phase 0. If the live test passes, ship them.
  If the gateway buffers in a way that defeats the heartbeat-interval
  requirement, return 501 with `{"error":"not_implemented","reason":"continuous
  feed not supported; use feed=longpoll"}` — clients retry with longpoll
  gracefully.
- **Fallback path documented**: a `%Net.TCPServer`-based raw HTTP listener on a
  separate port, bypassing the CSP Gateway entirely, if continuous-feed demand
  materializes post-MVP. Phase 7 work.

### Risk register update

**Risk "Long-polling / continuous feed resource exhaustion"** — unchanged,
still present. **New risk**: "CSP Gateway buffering defeats continuous feed" —
medium probability, medium impact (we lose continuous/eventsource but not
longpoll), mitigated by the spike-4b test and the longpoll fallback.

---

## Spike 6 — IRIS SQL indexes on JSON path expressions

**Status:** ✅ Complete, 2026-04-11

### Findings

**Pattern A** — inline SQL DDL like `CREATE INDEX ... ON T (JSON_VALUE(Body, '$.path'))`
is **not viable**. IRIS SQL indexes can only reference plain property names, per
[IndexDefinition.cls:50-51](irislib/%Dictionary/IndexDefinition.cls#L50-L51) and
the index compiler at [%Compiler/Type/Index.cls:85-112](irislib/%Compiler/Type/Index.cls#L85-L112).

**Pattern B** — `SqlComputed` property with an index on the property is
**viable but costly for runtime index creation**. Every Mango `_index` POST
would require `%Dictionary.PropertyDefinition` + `%Dictionary.IndexDefinition`
edits and a class recompile (seconds of latency per index). The SQL query
planner may not recognize `WHERE JSON_VALUE(Body, '$.author')=?` as equivalent
to `WHERE Author=?`, requiring us to rewrite Mango-translated queries to
reference the computed property name directly.

**Pattern C** — a runtime index table keyed by (db, indexId, composite-key) is
**viable and preferred**. No runtime class recompilation; Mango `_index`
creation is pure metadata + a background backfill; queries hit standard IRIS
SQL indexes on the composite-key columns.

### Bonus finding: conditional indexes are native

[IndexDefinition.cls:17-18](irislib/%Dictionary/IndexDefinition.cls#L17-L18):

```
/// In the case of a conditional index, specifies the condition that must be
/// met for an entry to be included in the index.
Property Condition As %RawString;
```

This maps directly to Mango's `partial_filter_selector`. Native IRIS support
with no custom filter layer required.

### Revised Mango projection architecture

Replaces the original §B.4 design. Two persistent classes, both fixed at
install time (no runtime recompile):

```objectscript
Class CouchPort.Projection.Winners Extends %Persistent
{
  Property DbName     As %String(MAXLEN=256) [ Required ];
  Property DocId      As %String(MAXLEN=2048) [ Required ];
  Property WinningRev As %String(MAXLEN=128) [ Required ];
  Property Seq        As %BigInt [ Required ];
  Property Deleted    As %Boolean [ Required, InitialExpression = 0 ];
  Property Body       As %String(MAXLEN="");
  Property DocType    As %String(MAXLEN=512)
    [ SqlComputed, SqlComputeCode =
      {Set {*} = ##class(CouchPort.Util.Json).ExtractPath({Body}, "$.type")} ];

  Parameter DEFAULTCONCURRENCY = 0;    // optimistic locking, no row-level locks

  Index PKey   On (DbName, DocId) [ Unique, PrimaryKey ];
  Index BySeq  On (DbName, Seq);
  Index ByType On (DbName, DocType);   // free index on the universal "type" field
}

Class CouchPort.Projection.MangoIndex Extends %Persistent
{
  Property DbName  As %String(MAXLEN=256) [ Required ];
  Property IndexId As %String(MAXLEN=512) [ Required ];  // "<ddoc>/<name>"
  Property DocId   As %String(MAXLEN=2048) [ Required ];

  // Up to 8 composite key columns. Mango specs cap useful compound indexes
  // well below this. Unused columns are empty string.
  Property K1 As %String(MAXLEN=1024);
  Property K2 As %String(MAXLEN=1024);
  Property K3 As %String(MAXLEN=1024);
  Property K4 As %String(MAXLEN=1024);
  Property K5 As %String(MAXLEN=1024);
  Property K6 As %String(MAXLEN=1024);
  Property K7 As %String(MAXLEN=1024);
  Property K8 As %String(MAXLEN=1024);

  // Parallel numeric columns for range queries on numeric fields. A field
  // indexed as a number populates Nn; otherwise Kn.
  Property N1 As %Numeric;
  Property N2 As %Numeric;
  Property N3 As %Numeric;
  Property N4 As %Numeric;

  Parameter DEFAULTCONCURRENCY = 0;

  Index PKey     On (DbName, IndexId, DocId) [ Unique, PrimaryKey ];
  Index ByStrKey On (DbName, IndexId, K1, K2, K3, K4);
  Index ByNumKey On (DbName, IndexId, N1, N2, N3, N4);
}
```

### Runtime flow

1. **`POST /{db}/_index`** — `CouchPort.Query.Mango.Index`:
   a. Validates the index spec.
   b. Writes metadata to `^CouchPort.Index(dbName, ddocId, indexName, "def")`.
   c. Writes a design doc (so Mango indexes round-trip to replication clients).
   d. Schedules a background backfill job that iterates every live doc in the
      db, extracts the indexed fields, and inserts rows into `MangoIndex`.
   e. Returns 201 immediately; client can query `_find` with the new index
      even while backfill is in progress (queries transparently intersect
      with the backfill progress via `^CouchPort.Index(...,"seq")`).

2. **Document write** — `CouchPort.Projection.Mapper.Sync`:
   a. UPSERT the `Winners` row.
   b. For each registered index in the db: extract the indexed fields from
      the new body; UPSERT the `MangoIndex` row with `(DbName, IndexId, DocId,
      K1..K8, N1..N4)`. If the index has a partial_filter_selector, check it
      first and skip if the doc doesn't match.
   c. All writes are in the same transaction as the global write — either
      everything commits or everything rolls back.

3. **`POST /{db}/_find`** — `CouchPort.Query.Mango.Cursor`:
   a. Planner picks the best registered index (exact-prefix match on
      selector fields + sort fields). Matches CouchDB's rules.
   b. Translator emits SQL against `MangoIndex`:
      ```sql
      SELECT m.DocId, w.Body
      FROM CouchPort_Projection.MangoIndex m
      JOIN CouchPort_Projection.Winners w
        ON w.DbName = m.DbName AND w.DocId = m.DocId AND w.Deleted = 0
      WHERE m.DbName = ? AND m.IndexId = ?
        AND m.K1 = ? AND m.K2 >= ?
      ORDER BY m.K1 ASC, m.K2 ASC
      LIMIT ? OFFSET ?
      ```
   c. Fetches returned docs, composes `_find` response shape.
   d. If no index matches: fall back to `CouchPort.Query.Mango.FallbackScan`,
      which iterates `^CouchPort.Docs` with in-memory selector eval. `_explain`
      correctly reports `"index": "_all_docs"`.

### Partial filter selector

Implemented at MangoIndex insert time, not at the IRIS index level. We iterate
all registered indexes on each doc write, evaluate their partial_filter_selector
(via the same in-memory evaluator used by the fallback scan), and only emit a
row when it matches. Simpler than wiring it into IRIS SQL `Condition`
expressions, and equivalent in query performance.

### Sub-question answers

| Question | Answer |
|---|---|
| Can CREATE INDEX take an expression? | No. Property names only. |
| Optimizer recognizes `JSON_VALUE(...)=?` as equivalent to `ComputedProp=?`? | Unverified and unsafe to rely on. We query `MangoIndex` columns directly instead. |
| JSON_VALUE vs %DynamicObject.%Get vs custom function? | Custom ObjectScript function in `SqlComputeCode` is fastest for the universal `DocType` column. For the `MangoIndex` path-extraction at write time we use `CouchPort.Util.Json.ExtractPath` — once per (doc, index). |
| Runtime schema evolution without recompile? | With Pattern C: yes, entirely. Indexes are pure metadata. |
| Partial indexes (`partial_filter_selector`)? | Implemented in `CouchPort.Projection.Mapper` at write time. Alternative: IRIS `Condition` expression on the MangoIndex index, but that requires property-name references — harder to express arbitrary Mango selectors. Write-time filter is simpler. |
| Multi-column indexes on JSON paths? | Yes, via the composite `K1..K8`/`N1..N4` columns. |
| Index maintenance concurrency? | `DEFAULTCONCURRENCY=0` — optimistic locking, no row-level locks, index updates happen within the write transaction. Backfill runs as a batch process without blocking concurrent writes. |

### Known limitations

- Indexes with more than 8 string or 4 numeric key columns cannot fit the
  composite-key schema. Limit documented in API error on `_index` creation.
  (CouchDB itself rarely uses indexes with more than 3-4 fields; 8 is generous.)
- Sort on a non-leading column of a composite index triggers in-memory sort after
  the fetch — same behavior as CouchDB.
- One `MangoIndex` row per (db, index, matching-doc) tuple. For a 1M-doc db
  with 10 indexes where every index matches every doc, that's 10M MangoIndex
  rows. Sized for IRIS, but worth monitoring post-MVP.

### Package updates

Old `CouchPort.Query.Mango.Translator` spec (§B.2) gains a second
`TranslateToMangoIndex` method. Old `CouchPort.Projection.Winners` class
(§B.4.1) is revised to the shape above. New class
`CouchPort.Projection.MangoIndex` added. `CouchPort.Projection.Mapper` now has
an index-sync responsibility on top of the Winners sync.

### Risk register update

**Risk "Mango translation for $elemMatch / $allMatch / $regex across JSON
arrays is hard in IRIS SQL"** — unchanged; still relevant. The `MangoIndex`
schema doesn't help with these operators inside the index itself, but the
fallback-scan path does and is now cleaner to reason about.

**New risk**: "`MangoIndex` row count scales with doc-count × index-count" —
medium impact, well-understood, monitored via `%SYS.SQL.ProcedureCache` and
globals usage. Mitigation: documented limits on index count per db, index
pruning via `DELETE /_index/*`.

---

## C.1 — Summary of Findings

- **Feature surface size**: approximately 120 MVP feature items across 11 subsystems.
  Replication compatibility alone accounts for ~35 of those as MUSTs, Mango for
  another ~25, changes feed for ~15, views+JS for ~15, attachments+multipart for
  ~10, auth+security for ~15.
- **Deprecated surface we skip**: shows, lists, updates, rewrites, `_temp_view`,
  partitioned dbs (deferred), `_replicator` scheduler (deferred), Nouveau/Clouseau
  text search (deferred). None of these are required for replication compatibility
  or for the prompt's stated MVP scope.
- **Technical approach**: CQRS hybrid exactly as specified in initial-prompt.md
  — globals are source of truth, IRIS SQL projection on a shadow `%Persistent`
  class is the Mango read model. QuickJS sandbox via embedded Python (PetterS
  `quickjs` binding) is the single non-ObjectScript component, shipped in MVP,
  isolated behind `CouchPort.JSRuntime.Sandbox`. The engine works (`_find`,
  replication, attachments) even if the sandbox is disabled.
- **Biggest risks**: byte-compat of rev hash computation, replication_id
  computation, and AuthSession cookie HMAC. All three require source-verification
  against the Erlang modules and parity tests as acceptance criteria. Without
  them, replication silently breaks in ways that are very hard to diagnose later.
- **Smallest risks**: the HTTP dispatch layer (well-served by `%CSP.REST`),
  document CRUD (straightforward globals), attachments (well-served by
  `%Stream.GlobalBinary` + `%Net.MIMEReader`), and auth (straightforward
  PBKDF2 + HMAC).
- **Biggest work items**: the Mango translator (operator coverage + `$elemMatch`/
  `$allMatch` edge cases), the view engine (incremental build pump + QuickJS
  integration), and the multipart attachment dance (nested multipart/mixed
  containing multipart/related).

## C.2 — Recommended Next Actions

1. **Run the seven spikes in B.12 before Phase 1 starts** — each is half- to
   one-day of effort and they de-risk 80% of byte-compat surprises.
2. **Stand up a real CouchDB 3.5 instance for parity testing** — Docker container
   is fine. Every subsequent phase needs to validate against it.
3. **Build the rev-hash parity harness as the very first piece of code** —
   before any document CRUD is implemented. Every new doc the harness writes
   must produce the same rev hash in CouchPort as in CouchDB, or the test fails.
   This is the single highest-leverage quality gate in the project.
4. **Decide on `CouchPort` vs a different package prefix** — the prompt uses
   `CouchPort.*`. Confirm this or lock in an alternative before scaffolding.
5. **Pick IRIS web app mount point** — e.g., `/couchport/` on port 52773. Clients
   will hit `http://host:52773/couchport/...`. Document in README.

---

## Spike 4b — Live CSP Flush test (Apache + mod_csp2)

**Status:** ✅ Complete with definitive negative result, 2026-04-11

### Test setup

A disposable `%CSP.REST` handler (`CouchPort.Spike.Flush`) was deployed to a
temporary `/couchport-spike` web application on a running IRIS 2025.1 instance
(Windows, Apache front-end web server, mod_csp2 gateway). Two endpoints:

- `/stream` — Content-Type `application/json`, writes 10 newline-delimited JSON
  objects with `Hang 0.5` + `Flush()` between each. 5-second handler runtime.
- `/stream-sse` — Content-Type `text/event-stream`, same pattern with SSE
  `data:`/`id:` framing.

Both enabled `%response.AllowOutputFlush=1` in `OnPreHTTP`.

### Result: client saw zero bytes until handler completed

`curl` with `time_starttransfer` measurement:

| Endpoint | `time_starttransfer` | `time_total` | Response headers |
|---|---|---|---|
| `/stream` | **5.080 s** | 5.080 s | `CONTENT-LENGTH: 303`, no `Transfer-Encoding: chunked` |
| `/stream-sse` | **5.067 s** | 5.067 s | `CONTENT-LENGTH: 406`, no `Transfer-Encoding: chunked` |

The CSP Gateway aggregated the entire response body, computed `Content-Length`
from the final buffer size, and emitted everything as a single HTTP response
after the handler returned. `%response.Flush()` calls inside the handler have
no client-visible effect in this configuration.

### Verdict

**`feed=continuous` and `feed=eventsource` are NOT feasible on the default
IRIS Apache+mod_csp deployment.** `%CSP.Response.Flush()` flushes ObjectScript's
I/O buffer to the gateway process, but the gateway does not forward bytes to
the client until the handler completes.

### What still works

| Feed mode | Feasibility | Reason |
|---|---|---|
| `feed=normal` | ✅ | One-shot response, no streaming required |
| `feed=longpoll` | ✅ | Handler blocks up to `timeout`, returns a single response body when a change arrives or timeout elapses — gateway buffering is transparent |
| `feed=continuous` | ❌ | Gateway buffering defeats incremental framing |
| `feed=eventsource` | ❌ | Same as continuous |

### Revised MVP scope for the changes feed

- **MVP ships `feed=normal` and `feed=longpoll` fully.** These cover every
  CouchDB client tested in practice — PouchDB defaults to longpoll for pull
  replication, the CouchDB replicator uses `feed=normal` with `limit` batching
  in non-continuous mode, and Fauxton reads `_changes` in batches.
- **`feed=continuous` and `feed=eventsource` return 501** with a clear JSON
  error: `{"error":"not_implemented","reason":"Streaming feed types are not
  supported by this server; use feed=longpoll instead."}`. Clients that insist
  on streaming can fall back gracefully.
- **Phase 7 hardening work item**: optional standalone HTTP listener via
  `%Net.TCPServer`, running on a separate port, implementing HTTP/1.1 with
  chunked transfer encoding directly — bypasses the CSP Gateway entirely.
  Complex enough to defer until real user demand materializes.

### Risk register update

**Risk "CSP Gateway buffering defeats continuous feed"** — ⚠️ **CONFIRMED**.
Impact is bounded (we lose 2 of 4 feed modes, not any core functionality)
because longpoll covers the dominant client use cases. Mitigated by the
documented 501 response and the Phase 7 `%Net.TCPServer` fallback plan.

---

## Spike 5 — `%SYS.Python` + `quickjs` install (live IRIS)

**Status:** ⚠️ Python not configured on test host; deployment prerequisite, not
a tech gap. Complete, 2026-04-11.

### Test and finding

Attempt to load Python via `##class(%SYS.Python).Import("sys")` returned:

```
ERROR: <OBJECT DISPATCH> 230 PythonVersion+3^CouchPort.Spike.Probe.1
Failed to Load Python: Check documentation and messages.log,
Check CPF parameters: [PythonRuntimeLibrary, PythonRuntimeLibraryVersion],
Check sys.path setup in: $INSTANCE/lib/python/iris_site.py
```

Inspection of the IRIS install directory shows Python binding binaries are
physically present:

```
c:/intersystems/irishealth/bin/
  irispython.exe
  pythonint39.pyd pythonint310.pyd pythonint311.pyd
  pythonint312.pyd pythonint313.pyd
c:/intersystems/irishealth/lib/python/
  iris.py iris_site.py ...
```

Python 3.9–3.13 are supported by this IRIS install. The CPF parameter
`[config]PythonRuntimeLibrary` is unset, so `%SYS.Python` cannot locate a
`libpython*.dll` at runtime.

### Implication

This is **operator-controllable deployment state**, not a platform gap. To
enable embedded Python on this host, the operator would install Python 3.9+,
set `[config] PythonRuntimeLibrary=<path-to-python3NN.dll>` in the CPF file,
and restart IRIS.

### Consequence for CouchPort architecture

This finding, combined with the user's preference for a Python-free
deployment path, triggered a revision of the JavaScript sandbox strategy.
See **§B.9 REVISED** below.

---

## Spike 7 — `%Net.MIMEReader` streaming round-trip (live IRIS)

**Status:** ✅ Passed, 2026-04-11

### Test and finding

A disposable `CouchPort.Spike.Mime` class built a `multipart/related` body in a
`%Stream.TmpBinary` (top-level header + JSON part + binary attachment part +
final boundary), handed it to `%Net.MIMEReader.OpenStream()`, and called
`ReadMIMEMessage(.msg)`:

```
Result: topCT='multipart/related; boundary="----CouchPortBoundary1234"' parts=2
  | p1: ct='application/json' bodyLen=100
  | p2: ct='text/plain' bodyLen=11
```

### Verdict

`%Net.MIMEReader` is **fit for CouchPort attachment parsing**:

- Accepts `%Stream` input via `OpenStream()` — no requirement to materialize
  the full body in memory.
- `ReadMIMEMessage()` populates a `%Net.MIMEPart` with `ContentType`, a `Parts`
  collection, and a `Body` property per part. Part bodies are themselves
  stream objects, suitable for forwarding to `%Stream.GlobalBinary` for
  attachment persistence without ever loading the full attachment into memory.
- Method surface: `OpenFile`, `OpenStream`, `ReadMIMEMessage`, `ReadMIMEBody`,
  `DecodeBase64`, `DecodeHeader`, `DecodeQP`. Full multipart support.

### Recommended usage pattern in CouchPort

```
PUT /{db}/{docid} (Content-Type: multipart/related):
  1. Read request body as %CSP.Stream (already a stream, no buffering).
  2. Prefix a synthetic top-level "Content-Type: multipart/related;
     boundary=..." header so MIMEReader has the boundary.
  3. reader.OpenStream(prefixedStream); reader.ReadMIMEMessage(.msg)
  4. First part is the doc JSON (parse into %DynamicObject).
     Subsequent parts are attachments — save part.Body stream directly
     into %Stream.GlobalBinary keyed by the attachment name from
     _attachments metadata.
```

No memory buffering of large attachments required.

### Risk register update

**Risk "`%Net.MIMEReader` may buffer full body in memory"** — ✅ **ELIMINATED**.
Stream input + stream part bodies confirmed.

---

## §B.9 REVISED — Pluggable JSRuntime Architecture

**Status:** Revised 2026-04-11 in response to spike 5 finding and user
preference for a Python-free default deployment.

### The problem with the original plan

The original §B.9 pinned a single sandbox implementation: PetterS `quickjs`
Python binding hosted in `%SYS.Python`. Spike 5 revealed that:

1. Embedded Python is an operator-gated IRIS feature, not always configured.
2. Installing Python to support QuickJS is an operational burden some
   operators prefer to avoid.
3. Mango `_find` (which does NOT need JS) is the primary query path in
   CouchDB 3.x+; most CouchDB clients use Mango, not JS views.

### The revised architecture

**Three pluggable backends behind a common interface class**:

```
CouchPort.JSRuntime.Sandbox  (abstract interface — same as original §B.9.2)
  ├── CouchPort.JSRuntime.None          ← MVP default
  ├── CouchPort.JSRuntime.Subprocess    ← Phase 1b
  └── CouchPort.JSRuntime.Python        ← Phase 1b, secondary
```

Operators pick one by setting a config class parameter. The choice is
transparent to the rest of the engine.

### Backend Ⅰ — `CouchPort.JSRuntime.None` (MVP default)

Returns 501 Not Implemented for every JS operation. Design docs containing
`views`, `filters`, or `validate_doc_update` are stored and replicated
normally, but attempting to query a JS view or invoke a JS filter returns:

```json
{"error":"not_implemented","reason":"JavaScript design-doc execution is not
enabled on this server. Enable a JSRuntime backend, or use Mango _find for
queries."}
```

**MVP feature coverage with JSRuntime.None:**

| Feature | Status |
|---|---|
| Replication (pull + push) | ✅ fully functional — replication never touches user JS |
| Mango `_find` + `_index` | ✅ fully functional — pure ObjectScript + SQL projection |
| Document CRUD, `_bulk_docs`, `_all_docs` | ✅ fully functional |
| Attachments (inline, stub, multipart) | ✅ fully functional |
| `_changes?filter=_doc_ids` / `_selector` / `_design` | ✅ fully functional |
| Auth via `_security` admins/members | ✅ fully functional |
| Built-in reduces `_sum`/`_count`/`_stats`/`_approx_count_distinct` | ✅ ObjectScript ports |
| **JS view `_view/{name}`** | ❌ 501 |
| **`validate_doc_update` hooks** | ❌ skipped; coarse `_security` only |
| **`_changes?filter=ddoc/fnname` custom JS filter** | ❌ 501 — clients fall back to `_selector` |
| **Deprecated shows/lists/updates/rewrites** | ❌ 501 — already deprecated in CouchDB 3.x |

This covers PouchDB, the CouchDB replicator, Cloudant SDKs, and every modern
CouchDB client's happy path. Missing features are either deprecated or have
Mango-based alternatives.

### Backend Ⅱ — `CouchPort.JSRuntime.Subprocess` (Phase 1b)

Spawns a persistent JavaScript subprocess via `$ZF(-1)` with stdin/stdout
redirection, implementing CouchDB's `couchjs` line protocol. Supported
runtimes (operator-selectable via config):

- **Node.js** — most common, likely already on the host
- **Bun** — faster startup, smaller footprint
- **Deno** — TypeScript-friendly
- **The real `couchjs` binary** from a CouchDB install — reference implementation

Ships a ~200-line `couchport_jsrunner.js` that implements the couchjs line
protocol: `reset`, `add_lib`, `add_fun`, `map_doc`, `reduce`, `rereduce`,
`ddoc new`, `ddoc call`. Byte-compatible with CouchDB's query-server protocol.

**Process model**: one subprocess per (db, ddoc-language, ddoc-signature)
tuple, pooled, killed after configurable idle timeout. Startup cost ~50ms,
amortized over many map-doc calls.

**Isolation**: OS process boundary. Each subprocess has its own memory and
CPU; a misbehaving JS view cannot crash IRIS.

**Pros over the Python backend**: no IRIS CPF setup required, works with any
Node install, line protocol is simpler to debug (JSON over stdio), swap
runtimes without code changes.

**Cons**: subprocess startup per-ddoc is higher latency than in-process
execution; requires the chosen JS runtime binary to be on the IRIS host PATH.

### Backend Ⅲ — `CouchPort.JSRuntime.Python` (Phase 1b, secondary)

The original plan: PetterS `quickjs` Python binding hosted in `%SYS.Python`.
Same interface, in-process execution, hard sandbox limits. Preferred by
operators who already use embedded Python with IRIS.

### Config class

```objectscript
Class CouchPort.Config.Default
{
/// Which JSRuntime backend to use. Valid values:
///   "none"       — JSRuntime.None (MVP default; no JS execution)
///   "subprocess" — JSRuntime.Subprocess via Node/Bun/Deno/couchjs
///   "python"     — JSRuntime.Python via %SYS.Python + quickjs
Parameter JSRUNTIME = "none";

/// When JSRUNTIME="subprocess", which runtime to spawn.
///   "node" | "bun" | "deno" | "couchjs"
Parameter JSRUNTIMESUBPROCESSRUNTIME = "node";

/// Absolute path to the runtime binary (optional; defaults to PATH lookup).
Parameter JSRUNTIMEPATH = "";

/// Memory limit per JS context, in MB.
Parameter JSRUNTIMEMEMORYMB = 16;

/// CPU time limit per JS call, in seconds.
Parameter JSRUNTIMETIMEOUTSEC = 5;
}
```

### Impact on Phase delivery plan

Phase 1b is retitled from "**QuickJS sandbox**" to "**Optional JSRuntime
backends**." Its exit criterion changes from "QuickJS runs a map function" to
"at least one of Subprocess or Python backends passes a map-reduce round-trip
test using the existing JSRuntime.Sandbox interface."

**Phase 1 MVP ships `JSRuntime.None` and is complete without any JS backend
work.** MVP has zero mandatory external dependencies beyond IRIS itself.

### Updated package layout

```
CouchPort.JSRuntime.Sandbox       — abstract interface (unchanged from §B.9.2)
CouchPort.JSRuntime.None          — 501-returning default (NEW, MVP)
CouchPort.JSRuntime.Subprocess    — $ZF(-1) subprocess dispatcher (NEW, Phase 1b)
CouchPort.JSRuntime.Python        — %SYS.Python + quickjs (renamed from original)
CouchPort.JSRuntime.Protocol      — couchjs line protocol encoder/decoder (NEW)
CouchPort.JSRuntime.Pool          — per-ddoc subprocess / context pool (NEW)
```

### Risk register update

**Risk "Python install required for MVP"** — ✅ **ELIMINATED**. Python is now
optional. MVP has zero mandatory external dependencies beyond IRIS itself.

**New risk "Subprocess IPC complexity"** — MEDIUM impact, MEDIUM likelihood.
`$ZF(-1)` subprocess management requires careful stdin/stdout pipe handling,
subprocess lifecycle, and zombie-process cleanup. Mitigated by keeping the
subprocess itself simple (one 200-line JS file) and a deterministic "kill on
idle" policy.

---

**End of research report.**

