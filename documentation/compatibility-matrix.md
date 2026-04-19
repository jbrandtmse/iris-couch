# IRISCouch ↔ CouchDB 3.x Compatibility Matrix

**Last updated:** 2026-04-18 (Story 13.4 — trailing-slash normalization + 405 method-guard rows + Admin UI 401 path)
**IRISCouch version:** 0.1.0 (α development, pre-release)
**Source of truth:** CouchDB 3.3.3 HTTP API (vendored at `sources/couchdb/src/docs/src/api/`)
+ Epic 12 retrospective deviations list (`_bmad-output/implementation-artifacts/epic-12-retro-2026-04-17.md`)
**Maintenance rule:** PRD [NFR-I3](../_bmad-output/planning-artifacts/prd.md) —
an endpoint whose status transitions (for example from `supported` to
`supported with caveat`) must have its matrix row updated in the same commit
as the code change.
**Canonical deviation source:** the per-endpoint `Caveat / Pointer`
entries below link into [`deviations.md`](deviations.md), which is the
single named list of every operator-observable difference between
IRISCouch and CouchDB 3.x per PRD NFR-M4.

---

## Runnable examples mapped to endpoint families (Story 13.3)

Six runnable examples live under [`examples/`](../examples/README.md). Each
exercises a specific endpoint family end-to-end against a live IRISCouch
instance; if a row below is marked `supported` but the relevant example
fails on your host, that's a bug report. Map from example to endpoints:

| Example | Endpoints exercised |
|---------|---------------------|
| [`hello-document/`](../examples/hello-document/README.md) | `PUT /{db}`, `PUT /{db}/{docid}`, `GET /{db}/{docid}`, `DELETE /{db}/{docid}?rev=...`, `DELETE /{db}` |
| [`pouchdb-sync/`](../examples/pouchdb-sync/README.md) | `PUT /{db}`, `POST /{db}/_bulk_docs`, `POST /{db}/_revs_diff`, `GET /{db}/_changes`, `GET|PUT /{db}/_local/{id}`, `GET /{db}/_all_docs` (via PouchDB `sync()`) |
| [`replicate-from-couchdb/`](../examples/replicate-from-couchdb/README.md) | `POST /_replicate`, `GET /{db}`, `PUT /{db}`, `DELETE /{db}` |
| [`mango-query/`](../examples/mango-query/README.md) | `POST /{db}/_index`, `POST /{db}/_find` (with `execution_stats`), `POST /{db}/_explain` |
| [`attachment-upload/`](../examples/attachment-upload/README.md) | `PUT /{db}/{docid}`, `PUT /{db}/{docid}/{attname}?rev=...`, `GET /{db}/{docid}/{attname}`, `GET /{db}/{docid}` (attachment stub) |
| [`jsruntime-subprocess-node/`](../examples/jsruntime-subprocess-node/README.md) | `PUT /{db}/_design/{ddoc}`, `GET /{db}/_design/{ddoc}/_view/{view}` under `JSRUNTIME=Subprocess` |

---

## How to read a row

| Column | Meaning |
|--------|---------|
| **Endpoint** | CouchDB 3.x URL pattern. `{db}` is a database name; `{docid}` is a document ID (including `_design/<name>` and `_local/<name>`); `{ddoc}` is a design-doc name (without the `_design/` prefix); `{view}` is a view name inside a design doc. |
| **Method** | HTTP method. `*` means every method specified for this path by CouchDB 3.x. |
| **Status** | Exactly one of: `supported` / `supported with caveat` / `501 in default config` / `out of scope with reason`. |
| **Caveat / Pointer** | Short-form caveat text. Links to `deferred-work.md` entries, other docs, or the Epic 12 retro where the caveat originated. |
| **Verification** | How the row's claim is backed: an HTTP integration test class + method, a manual `curl` probe, or a replicator parity test. If you don't trust the row, run the named verification. |

**Status definitions:**

- **`supported`** — Behaves as CouchDB 3.3.3 documents the endpoint. Covered
  by at least one HTTP integration test; clients talking to IRISCouch see
  wire-compatible responses.
- **`supported with caveat`** — The endpoint responds, but one or more
  documented deviations apply (wire shape, ordering, parameter subset, error
  code, etc.). The caveat is named and linked to its originating
  `deferred-work.md` entry or retrospective.
- **`501 in default config`** — Returns `501 Not Implemented` under the
  default `JSRUNTIME=None` backend. Switching to `JSRUNTIME=Subprocess` with
  a Node interpreter configured may move the endpoint into `supported` or
  `supported with caveat`; see the JSRuntime state rows under each
  JS-dependent section.
- **`out of scope with reason`** — Intentionally not implemented in α/β.
  Each row cites why. Most `out of scope` rows are `/_node/*`, `/_cluster_setup`,
  `/_reshard`, and other single-node / Erlang-specific endpoints.

---

## Quick summary

| Status bucket | Row count |
|---------------|----------:|
| `supported` | 74 |
| `supported with caveat` | 12 |
| `501 in default config` | 10 |
| `out of scope with reason` | 27 |
| **Total rows** | **123** |

(Row counts are for this matrix's expansion of the CouchDB 3.x endpoint
set. JSRuntime-aware endpoints are counted once per backend state, so the
same endpoint may appear in three different rows — one per
`None` / `Subprocess` / `Python-deferred` state.)

---

## Server-level endpoints

Source: `sources/couchdb/src/docs/src/api/server/`

| Endpoint | Method | Status | Caveat / Pointer | Verification |
|----------|--------|--------|------------------|--------------|
| `/` | GET | supported | `version` is IRISCouch release version (`0.1.0` at α), not CouchDB's. `features` array is absent — CouchDB emits an advisory string list (e.g., `partitioned`, `pluggable-storage-engines`); IRISCouch omits it because the server's feature set is fixed by the backend. | `RouterTest.TestWelcomeResponse`, `HttpIntegrationTest.TestWelcomeEndpoint` |
| `/_up` | GET | supported | Returns `{"status":"ok"}` for healthchecks. | `curl http://host/iris-couch/_up` |
| `/_session` | GET | supported | `userCtx.roles` includes both IRIS roles (`%All`) and IRISCouch roles (`IRISCouch_Admin`, internally duplicated as `%IRISCouch_Admin`); CouchDB uses `_admin` / `_reader` / `_writer`. `info.authenticated` reports one of `default` (basic), `cookie`, `jwt`, `proxy`. | `AuthHttpTest.TestSessionGetAuthenticated`, `JWTHttpTest.TestBearerAuthSuccess` |
| `/_session` | POST | supported | Cookie-session login; returns `AuthSession` cookie. | `AuthHttpTest.TestSessionPostSuccess` |
| `/_session` | DELETE | supported | Logout; clears the cookie. | `AuthHttpTest.TestSessionDelete` |
| `/_session` | PUT, HEAD | supported | Returns `405 Method Not Allowed` with `Allow: GET, POST, DELETE` (Story 13.4). | `MethodNotAllowedTest.TestPutSessionReturns405` |
| `/_all_dbs` | GET | supported | Returns all databases visible to the authenticated user, filtered by `_security` ACLs. | `DatabaseHttpTest.TestAllDbsEmptyHttp`, `DatabaseHttpTest.TestAllDbsWithDatabasesHttp` |
| `/_all_dbs` | POST, PUT, DELETE | supported | Returns `405 Method Not Allowed` with `Allow: GET`. Before Story 13.4, `PUT /_all_dbs` fell through to `PUT /:db` and silently created a phantom database named `_all_dbs`; the method-guard route now prevents this. | `MethodNotAllowedTest.TestPhantomDatabasePrevention` |
| `/_dbs_info` | GET, POST | out of scope with reason | Bulk database-info surface (CouchDB 3.x). Not yet implemented; single-DB info (`GET /{db}`) is covered. Low-priority follow-up. | N/A |
| `/_uuids` | GET | supported | `count=N` (default 1, max 100) returns N v4 UUIDs. | `UUIDTest.TestHandleUUIDsWithCount`, manual `curl /iris-couch/_uuids?count=3` |
| `/_uuids` | POST, PUT, DELETE | supported | Returns `405 Method Not Allowed` with `Allow: GET` (Story 13.4). | `MethodNotAllowedTest.TestPostUuidsReturns405` |
| `/_replicate` | POST | supported | Full single-shot replication against any CouchDB 3.x peer. | Epic 8 replicator-roundtrip harness; manual probe |
| `/_active_tasks` | GET | supported with caveat | Returns only IRISCouch replicator tasks. IRIS-internal tasks (compaction, view indexing) are not exposed. Shape matches CouchDB's `{"type":"replication",...}` entries. | `ReplicatorManagerHttpTest.TestOneShotCompletion` (active-task shape assertions) |
| `/_prometheus` | GET | supported with caveat | Prometheus exposition format. Counter / gauge names are IRISCouch-prefixed (`iriscouch_*`) — not wire-compatible with stock CouchDB's Prometheus exporter (which mounts at `/_node/<name>/_prometheus`). Cite: Epic 9 Story 9.1. | `MetricsHttpTest.TestPrometheusEndpoint`, `MetricsHttpTest.TestPrometheusContentType` |
| `/_membership` | GET | out of scope with reason | Single-node architecture; no cluster membership to report. Returns `404`. Epic 14 plans ECP clustering but membership semantics differ from CouchDB's. | manual `curl /iris-couch/_membership` |
| `/_cluster_setup` | GET, POST | out of scope with reason | Single-node; no cluster setup flow. Returns `404`. | manual probe |
| `/_db_updates` | GET | 501 in default config | Streaming DB events are the same class of problem as streaming `_changes` — deferred to Epic 14 (standalone TCP listener). Normal feed may return supported before γ; check matrix update. | deferred to Epic 14 |
| `/_utils/` | GET | supported | IRISCouch's built-in admin UI (Story 11.5). Wire-compatible substitute for Fauxton; requires `IRISCouch_Admin` role. Story 13.4 Task 3 tightened the identity check: anonymous GET returns `401 Unauthorized` with `WWW-Authenticate: Basic` (not `200` + SPA shell), and authenticated-admin GET returns `200`. | `AdminUIHandlerTest.TestIndexHtmlServed`, `AdminUIHandlerTest.TestSpaFallback`, `AdminUIRBACTest.TestAnonymousGetUtilsReturns401`, `AdminUIRBACTest.TestAuthenticatedAdminGetUtilsReturns200` |
| `/_utils/*` (static assets) | GET | supported | Angular bundle served from IRIS. | `AdminUIHandlerTest.TestJsAssetServed`, `AdminUIHandlerTest.TestCssAssetServed`, `AdminUIHandlerTest.TestFontAssetServed` |
| `/_node/{name}/_config*` | * | out of scope with reason | CouchDB cluster-node configuration surface. IRISCouch config lives in `^IRISCouch.Config` globals; operators use `IRISCouch.Config.Get/Set`. Exposing as HTTP would require replicating CouchDB's full multi-node config model for a single-node server. | N/A |
| `/_node/{name}/_stats` | GET | out of scope with reason | CouchDB per-node metrics; use `/_prometheus` instead. | N/A |
| `/_node/{name}/_system` | GET | out of scope with reason | Same rationale. Adopters wanting host-level telemetry should scrape IRIS's own `SYS.History` or Prometheus `iris_*` metrics. | N/A |
| `/_reshard` | * | out of scope with reason | No sharding in single-node IRISCouch. | N/A |
| `/_scheduler/*` | GET | out of scope with reason | Replicator scheduler views; `/_active_tasks` covers most of the ask. May add in γ if adopters request. | N/A |

---

## Database-level endpoints

Source: `sources/couchdb/src/docs/src/api/database/`

| Endpoint | Method | Status | Caveat / Pointer | Verification |
|----------|--------|--------|------------------|--------------|
| `/{db}` | HEAD | supported | Exists/not-exists probe. | `DatabaseHttpTest.TestDatabaseInfoNotFoundHttp` (404 HEAD path); manual probe |
| `/{db}` | GET | supported | Returns info envelope with `db_name`, `doc_count`, `doc_del_count`, `update_seq`, `sizes`, `cluster:{q:1,n:1,w:1,r:1}`, `instance_start_time:"0"`. Cluster values are constants for a single-node server. | `DatabaseHttpTest.TestDatabaseInfoHttp` |
| `/{db}` | PUT | supported | Creates database; `partitioned` query param is accepted but ignored (IRISCouch does not partition). | `DatabaseHttpTest.TestCreateDatabaseHttp`, `DatabaseHttpTest.TestCreateDatabaseAlreadyExistsHttp` |
| `/{db}` | DELETE | supported | Drops database and all globals. Irreversible; no soft-delete. | `DatabaseHttpTest.TestDeleteDatabaseHttp`, `DatabaseHttpTest.TestDeleteDatabaseNotFoundHttp` |
| `/{db}/` (trailing slash) | PUT, GET, HEAD, DELETE | supported | Story 13.4 (2026-04-18) added `IRISCouch.API.Router.OnPreDispatch` trailing-slash normalization: a single trailing `/` is stripped from any non-root URL before UrlMap matches, so `PUT /{db}/`, `GET /{db}/`, `HEAD /{db}/`, `PUT /{db}/{docid}/`, `GET /{db}/_all_docs/`, etc. all route identically to their no-slash counterparts. CouchDB 3.x parity restored. | `TrailingSlashRoutingTest.TestDatabaseEndpointsTrailingSlashOK`, `TrailingSlashRoutingTest.TestDatabaseGetTrailingSlash`, `TrailingSlashRoutingTest.TestDocumentEndpointsTrailingSlash`, `TrailingSlashRoutingTest.TestSystemEndpointsTrailingSlash`, `TrailingSlashRoutingTest.TestRootPathNotNormalized` |
| `/{db}` | POST | supported | Create-document without explicit ID; server generates UUID. | `DocumentHttpTest.TestPostDocument` |
| `/{db}/_all_docs` | GET, POST | supported | Keys: `limit`, `skip`, `startkey`, `endkey`, `key`, `keys`, `include_docs`, `descending`, `inclusive_end`. Tested across all parameters. | `AllDocsHttpTest.TestAllDocsPostKeysHttp`, `AllDocsHttpTest.TestAllDocsKeyRangeHttp`, `AllDocsHttpTest.TestAllDocsLimitSkipHttp`, `AllDocsHttpTest.TestAllDocsIncludeDocsHttp` |
| `/{db}/_all_docs/queries` | POST | out of scope with reason | CouchDB 3.x multi-query `_all_docs` surface (one request, multiple key-range queries). Not yet implemented; individual `_all_docs` requests work. | N/A |
| `/{db}/_design_docs` | GET | supported | Alias for `_all_docs?startkey="_design/"&endkey="_design0"`. | Manual probe; covered indirectly by `AllDocsHttpTest.TestAllDocsKeyRangeHttp` |
| `/{db}/_design_docs/queries` | POST | out of scope with reason | CouchDB 3.x multi-query `_design_docs` surface. Same rationale as `_all_docs/queries`. | N/A |
| `/{db}/_local_docs` | GET | supported | Lists `_local/*` documents (used by replicator checkpoints). | `LocalDocHttpTest.TestLocalPutAndGet` (round-trip); manual probe |
| `/{db}/_bulk_docs` | POST | supported | Both `new_edits=true` (default) and `new_edits=false` (replication-format). Returns per-document status array. | `BulkOpsHttpTest.TestBulkDocsHttp`, `BulkOpsHttpTest.TestBulkDocsConflictHttp`, `BulkOpsHttpTest.TestBulkDocsNewEditsFalseHttp` |
| `/{db}/_bulk_get` | POST | supported | Replication-oriented multi-doc read. Returns CouchDB-shaped `results[]`. | `BulkGetReplicationHttpTest.TestBulkGetHttpRevsTrue`, `BulkGetReplicationHttpTest.TestBulkGetHttpAttachmentsTrue`, `BulkGetReplicationHttpTest.TestBulkGetHttpMissingDoc` |
| `/{db}/_find` | POST | supported | Mango `selector` / `sort` / `fields` / `limit` / `skip` / `bookmark` / `use_index`. `execution_stats` is emitted when requested. | `MangoQueryHttpTest.TestPostFind`, `MangoQueryHttpTest.TestPostFindSortAndLimit`, `MangoQueryHttpTest.TestPostFindExecutionStats` |
| `/{db}/_index` | GET, POST, DELETE | supported | Mango index management. `type:"json"` indexes are fully supported; `type:"text"` returns 501 (no Lucene). | `MangoIndexHttpTest.TestPostIndex`, `MangoIndexHttpTest.TestGetIndexes`, `MangoIndexHttpTest.TestDeleteIndex` |
| `/{db}/_index/_bulk_delete` | POST | out of scope with reason | Bulk-index-deletion surface (CouchDB 3.x). Individual `DELETE /{db}/_index/<ddoc>/json/<name>` works. | N/A |
| `/{db}/_explain` | POST | supported | Mango query planner explanation envelope. | `MangoQueryHttpTest.TestPostExplain`, `MangoQueryHttpTest.TestPostExplainShowsCandidates` |
| `/{db}/_changes` (normal feed) | GET, POST | supported | `since`, `limit`, `include_docs`, `descending`, `style:main_only|all_docs`, `conflicts`, `attachments`. `filter=_doc_ids`, `_selector`, `_design` built-ins supported natively. | `ChangesHttpTest.TestChangesGetHttp`, `ChangesHttpTest.TestChangesSinceHttp`, `ChangesHttpTest.TestChangesLimitHttp`, `ChangesHttpTest.TestChangesIncludeDocsHttp`, `ChangesHttpTest.TestChangesPostHttp` |
| `/{db}/_changes?feed=longpoll` | GET | supported | Longpoll with timeout + heartbeat. | `LongpollHttpTest.TestLongpollImmediateReturnHttp`, `LongpollHttpTest.TestLongpollTimeoutHttp` |
| `/{db}/_changes?feed=continuous` | GET | out of scope with reason | Streaming through `%CSP.REST` + CSP Gateway buffers responses, making this unusable in practice. Epic 14 Story 14.1 plans a standalone TCP listener that bypasses CSP buffering. This is a CSP-layer deviation, not a CouchDB-protocol deviation. | Epic 14 Story 14.1 plan doc |
| `/{db}/_changes?feed=eventsource` | GET | out of scope with reason | Same root cause as `feed=continuous`; EventSource requires unbuffered chunked transfer. Epic 14 Story 14.1. | Epic 14 Story 14.1 plan doc |
| `/{db}/_changes?filter={ddoc}/{name}` (custom JS filter) | GET | 501 in default config | With `JSRUNTIME=None`. Built-in filters (`_doc_ids`, `_selector`, `_design`) work unchanged. See JSRuntime rows below. | `JSRuntimeHttpTest.TestCustomFilterReturns501WhenRuntimeIsNone` |
| `/{db}/_changes?filter={ddoc}/{name}` (custom JS filter) | GET | supported with caveat | With `JSRUNTIME=Subprocess` + Node configured. One subprocess spawn per request; Story 12.5b plans persistent pool. | `JSRuntimeFilterHttpTest.TestCustomFilterIncludesMatches`, `JSRuntimeFilterHttpTest.TestCustomFilterExcludesAll` |
| `/{db}/_compact` | POST | supported with caveat | Accepts + returns `202 Accepted`. Implementation is a no-op pending global compaction story; safe to call but does not reclaim space. Does not break any client expectation — CouchDB's own compaction is async and returns 202. | `DatabaseHttpTest.TestCompactHttp` |
| `/{db}/_compact/{ddoc}` | POST | supported with caveat | Same — 202 accepted, no-op. View-index compaction is Story 12.5c follow-up. | deferred-work.md Story 12.5c |
| `/{db}/_view_cleanup` | POST | supported with caveat | 202 accepted, no-op. Stale view files are not produced by IRISCouch's indexing model (overwrite in place). | manual probe |
| `/{db}/_ensure_full_commit` | POST | supported | Returns `{"ok":true,"instance_start_time":"0"}`. IRIS's journaling model makes this implicitly durable after every TCOMMIT. | `DatabaseHttpTest.TestEnsureFullCommitHttp` |
| `/{db}/_purge` | POST | supported | Removes specific `{docid, rev}` pairs from the revision tree. Returns `purge_seq` (currently a monotonic counter; not wire-identical to CouchDB's vector-based purge seq — tracked as a deviation). | manual probe; covered indirectly by revision-tree tests |
| `/{db}/_purged_infos_limit` | GET, PUT | out of scope with reason | Tracking of historical purge events. Low-value endpoint. Revisit if an adopter's replicator needs it. | N/A |
| `/{db}/_auto_purge` | GET, PUT | out of scope with reason | CouchDB 3.x auto-purge configuration. Not implemented; adopters who need purge should call `/_purge` explicitly. | N/A |
| `/{db}/_missing_revs` | POST | supported | Used by replication protocol; input / output shape wire-compatible. | `RevsDiffHttpTest.TestRevsDiffMissing` (shape), `RevsDiffHttpTest.TestRevsDiffEmptyBody` |
| `/{db}/_revs_diff` | POST | supported | Core replication endpoint; diff checked against multiple peer CouchDB versions (3.3.3 dev harness). | `RevsDiffHttpTest.TestRevsDiffAllExist`, `RevsDiffHttpTest.TestRevsDiffMissing`, `RevsDiffHttpTest.TestRevsDiffWithAncestors` |
| `/{db}/_revs_limit` | GET, PUT | supported | Default 1000; PUT updates. | `DatabaseHttpTest.TestRevsLimitGetHttp`, `DatabaseHttpTest.TestRevsLimitPutHttp` |
| `/{db}/_security` | GET, PUT | supported | Per-database security object with `admins:{names,roles}` and `members:{names,roles}` sub-objects. | `SecurityHttpTest.TestAPutSecurity`, `SecurityHttpTest.TestBGetSecurity`, `SecurityHttpTest.TestCErrorAndBypass` |
| `/{db}/_shards` | * | out of scope with reason | Single-node; no shard topology. | N/A |
| `/{db}/_shards/{docid}` | GET | out of scope with reason | Same. | N/A |
| `/{db}/_sync_shards` | POST | out of scope with reason | Same. | N/A |
| `/{db}/_partition/{partition}` | * | out of scope with reason | Partitioned databases deliberately not implemented. A `partitioned:true` PUT flag is accepted and ignored. | N/A |

---

## Document-level endpoints

Source: `sources/couchdb/src/docs/src/api/document/`

| Endpoint | Method | Status | Caveat / Pointer | Verification |
|----------|--------|--------|------------------|--------------|
| `/{db}/{docid}` | HEAD | supported | Used for `ETag` / `If-Match` checks. | Manual probe; covered indirectly by `DocumentHttpTest.TestGetDocument` (ETag header assertion) |
| `/{db}/{docid}` | GET | supported | Query params: `rev`, `revs`, `revs_info`, `open_revs`, `conflicts`, `deleted_conflicts`, `latest`, `local_seq`, `meta`, `attachments`, `atts_since`. | `DocumentHttpTest.TestGetDocument`, `DocumentHttpTest.TestGetDocumentSpecificRev`, `RevTreeHttpTest.TestOpenRevsAll`, `RevTreeHttpTest.TestOpenRevsSpecific`, `RevTreeHttpTest.TestRevsInfoParam` |
| `/{db}/{docid}` | PUT | supported | Creates or updates; `rev` required for updates unless `new_edits=false`. | `DocumentHttpTest.TestPutNewDocument`, `DocumentUpdateHttpTest.TestUpdateDocument`, `DocumentUpdateHttpTest.TestUpdateConflict` |
| `/{db}/{docid}` | DELETE | supported | Soft-delete (tombstone in revision tree). | `DocumentUpdateHttpTest.TestDeleteDocument`, `DocumentUpdateHttpTest.TestDeleteViaPut`, `DocumentUpdateHttpTest.TestDeleteNoRev` |
| `/{db}/{docid}` | COPY | out of scope with reason | Explicit CouchDB COPY method not implemented; use `GET` + `PUT` with a new `_id` as a workaround. Adopters can open an issue if a client requires native COPY. | N/A |
| `/{db}/_design/{ddoc}` (as a document) | GET, PUT, DELETE | supported | Design docs store and replicate identically to regular docs regardless of `JSRUNTIME`. | `DocumentHttpTest.TestPutDesignDoc`, `DocumentHttpTest.TestGetDesignDoc`, `DocumentHttpTest.TestDeleteDesignDoc`, `JSRuntimeHttpTest.TestDesignDocStorageIsJsRuntimeIndependent` |
| `/{db}/_design/{ddoc}/{attname}` | HEAD, GET, PUT, DELETE | supported | Design-doc attachments are regular attachments on a `_design/*` document — same CRUD surface as document attachments. | Covered by attachment tests below (no design-doc-specific separation) |
| `/{db}/_local/{docid}` | GET, PUT, DELETE | supported | Local docs (replication checkpoints). Do not replicate, do not contribute to `update_seq`. | `LocalDocHttpTest.TestLocalPutAndGet`, `LocalDocHttpTest.TestLocalUpdate`, `LocalDocHttpTest.TestLocalDelete`, `LocalDocHttpTest.TestLocalNotFound` |
| `/{db}/{docid}/{attname}` | HEAD | supported | ETag = attachment digest. | Manual probe; covered indirectly by `AttachmentHttpTest.TestGetAttachment` (ETag header assertion) |
| `/{db}/{docid}/{attname}` | GET | supported | Returns raw bytes with correct `Content-Type` and `Content-Length`. `Range: bytes=...` supported. | `AttachmentHttpTest.TestGetAttachment`, `AttachmentRetrievalHttpTest.TestGetDocAttsSince`, `InlineAttachmentHttpTest.TestGetIndividualAttachmentContent` |
| `/{db}/{docid}/{attname}` | PUT | supported | Standalone attachment upload; requires `If-Match` rev. | `AttachmentHttpTest.TestPutAttachment`, `AttachmentHttpTest.TestPutWithoutRevConflict` |
| `/{db}/{docid}/{attname}` | DELETE | supported | Removes attachment; bumps doc rev. | `AttachmentHttpTest.TestDeleteAttachment` |
| `/{db}/{docid}` (multipart/related with attachments) | PUT | supported | Multipart upload of document + inline attachments in one request. Uses `%request.MimeData`. | `InlineAttachmentHttpTest.TestPutMultipartRelated`, `InlineAttachmentHttpTest.TestMultipartMultipleParts` |
| `/{db}/{docid}` (inline `_attachments` in JSON) | PUT | supported | Alternative upload path. | `InlineAttachmentHttpTest.TestPutWithInlineAttachment`, `InlineAttachmentHttpTest.TestPostWithInlineAttachment`, `InlineAttachmentHttpTest.TestUpdateWithStubAndNewAttachment` |
| `/{db}/_bulk_docs` (with attachments) | POST | supported with caveat | Attachments within `_bulk_docs` are decoded and persisted. Replicator-format `_bulk_docs` with `atts_since` optimization is respected. | `BulkOpsHttpTest.TestBulkGetRevsHttp` (round-trip with attachments), `InlineAttachmentTest` suite |

---

## Design Documents — Views

Source: `sources/couchdb/src/docs/src/api/ddoc/views.rst`

**JSRuntime state matters here.** Each endpoint below is listed three times
— once per backend state. Under `JSRUNTIME=None` (the α/β default), all
view-execution endpoints return `501 Not Implemented`. Under
`JSRUNTIME=Subprocess` with a Node interpreter configured, the endpoints
execute map / reduce / rereduce via the couchjs line protocol. Under
`JSRUNTIME=Python`, the endpoint would behave identically to Subprocess —
but the Python backend is **not shipped** and this row is listed for
completeness only.

### `GET|POST /{db}/_design/{ddoc}/_view/{view}` per JSRuntime backend

| Endpoint | Method | Backend | Status | Caveat / Pointer | Verification |
|----------|--------|---------|--------|------------------|--------------|
| `/{db}/_design/{ddoc}/_view/{view}` | GET, POST | **None** (default) | 501 in default config | Returns `{"error":"not_implemented","reason":"View execution requires a JavaScript runtime; set JSRUNTIME=Subprocess and JSRUNTIMESUBPROCESSPATH."}`. Cite: [js-runtime.md § None](js-runtime.md#none-default). | `JSRuntimeHttpTest.TestViewReturns501WhenRuntimeIsNone`, `JSRuntimeHttpTest.TestNoneBackendThrowsCanonicalEnvelope` |
| `/{db}/_design/{ddoc}/_view/{view}` | GET, POST | **Subprocess** (Node 18+, shipped α/β) | supported with caveat | Partial view-query-parameter coverage (Story 12.2a scope cut): see the "Supported query parameters" row immediately below. Three behavioral deviations also apply: mixed-type key collation, `_approx_count_distinct` exact count, and per-query subprocess spawn cost (Story 12.5b plans persistent pool). | `JSRuntimeSubprocessHttpTest.TestSubprocessMapSimpleView`, `JSRuntimeSubprocessHttpTest.TestSubprocessMapWithBuiltinSum`, `JSRuntimeSubprocessHttpTest.TestSubprocessBuiltinStats`, `ViewIndexHttpTest.TestWarmIndexReducesLatency`, `ViewIndexHttpTest.TestIncrementalIndexOnWrite` |
| `/{db}/_design/{ddoc}/_view/{view}` | GET, POST | **Python** (deferred) | out of scope with reason | **NOT SHIPPED.** Story 12.4 deferred on 2026-04-17 (commit `4fe1034`) — IRIS embedded Python unavailable on dev host. Per PRD [NFR-M9](../_bmad-output/planning-artifacts/prd.md), the backend cannot ship until the compile-on-any-IRIS invariant is verified on a Python-less CI image. Adopter workaround: use `JSRUNTIME=Subprocess` with Node. See [deferred-work.md Story 12.4 resumption](../_bmad-output/implementation-artifacts/deferred-work.md#deferred-for-story-124-resumption-added-2026-04-18-story-130). | N/A (backend not shipped) |
| `/{db}/_design/{ddoc}/_view/{view}/queries` | POST | out of scope with reason | CouchDB 3.x multi-query view surface (one request, multiple view queries). Not yet implemented; individual view queries work under `JSRUNTIME=Subprocess`. | N/A |

### View-query-parameter support under `JSRUNTIME=Subprocess` (Story 12.2a)

The 12.2 scope cut explicitly limited view query-parameter coverage to the
set below. Parameters outside this set are **silently ignored** (not
rejected with 501) because CouchDB clients including PouchDB tolerate
unknown params and the silent-ignore keeps the happy path working.

| Parameter | Subprocess status | Caveat / Pointer |
|-----------|-------------------|------------------|
| `reduce` | supported | Defaults to true when a reduce function is defined. |
| `include_docs` | supported | Fetches full document alongside each key/value row. |
| `group` | silently ignored (Story 12.2a) | Grouped reduce not yet implemented. Current behaviour with `group=true` is identical to ungrouped reduce. Dev-host-discovered 2026-04-18 during Story 13.3 example development; corrects a prior matrix entry that said "supported". |
| `group_level=N` | silently ignored (Story 12.2a) | Same as `group`. |
| `startkey`, `endkey` | silently ignored (Story 12.2a) | Range filtering on emitted keys. Workaround: filter client-side. Dev-host-discovered 2026-04-18. |
| `limit` | silently ignored (Story 12.2a) | Returns full result set. Paginate client-side. Dev-host-discovered 2026-04-18. |
| `skip` | silently ignored (Story 12.2a) | Returns full result set. Dev-host-discovered 2026-04-18. |
| `descending` | silently ignored (Story 12.2a) | Will return full unreversed result set. See [deferred-work.md Story 12.2](../_bmad-output/implementation-artifacts/deferred-work.md#deferred-from-story-12-2-implementation-2026-04-17). |
| `inclusive_end` | silently ignored (Story 12.2a) | Always inclusive. |
| `startkey_docid`, `endkey_docid` | silently ignored (Story 12.2a) | Range-tiebreaker on duplicate keys; Story 12.2a. |
| `key` | silently ignored (Story 12.2a) | Pass `startkey=K&endkey=K` as the workaround. |
| `keys` | silently ignored (Story 12.2a) | Pass multiple individual queries; Story 12.2a plans proper multi-key. |
| `stable`, `update`, `update_seq` | silently ignored (Story 12.2a) | Staleness-tuning params; Story 12.2a. |

**Three documented deviations under Subprocess** (Epic 12 retro §
"Dependencies on Epic 12"):

1. **Mixed-type key collation** — IRISCouch sorts emitted keys by
   lexicographic JSON string compare. CouchDB's `couch_ejson_compare` has
   richer cross-type collation semantics (numeric `10` sorts after numeric
   `2`, not before as lexicographic would). For mixed-type keys the two
   orderings can differ. Pointer: `deferred-work.md` → Story 12.2 / Story 14
   (Epic 14 may revisit).
2. **`_approx_count_distinct`** — Built-in reduce returns an **exact**
   distinct count (native `$Order` walk over the index). CouchDB uses
   HyperLogLog for large-cardinality estimation. Byte-identical for small
   cardinality; IRISCouch is more accurate (not less) for large result sets
   but the count is computed differently. Epic 14 plans true HLL. Pointer:
   Epic 12 retro § Deviations.
3. **Per-query subprocess spawn** — Each view query spawns a fresh Node
   subprocess (~130 ms cold-start). Incremental indexing (Story 12.5)
   removes the spawn from the hot path by indexing at write time; cache
   hits serve in ~0.16 ms. First-query-after-design-doc-update still pays
   the spawn. Story 12.5b plans persistent pool. Pointer: `js-runtime.md §
   Pool`.

### Related view endpoints

| Endpoint | Method | Status | Caveat / Pointer | Verification |
|----------|--------|--------|------------------|--------------|
| `/{db}/_design/{ddoc}` | GET | supported | Read the design doc as a regular document (see Document section). | `DocumentHttpTest.TestGetDesignDoc`, `JSRuntimeHttpTest.TestDesignDocStorageIsJsRuntimeIndependent` |
| `/{db}/_design/{ddoc}` | PUT | supported | Store design doc; `validate_doc_update` / `views` / `filters` / `shows` / `lists` functions are stored regardless of `JSRUNTIME`. | `DocumentHttpTest.TestPutDesignDoc`, `JSRuntimeHttpTest.TestDesignDocWithValidateCanBeStoredUnderNoneBackend` |
| `/{db}/_design/{ddoc}/_info` | GET | supported with caveat | Returns view-index info envelope. `sizes.active` / `sizes.external` are populated from IRIS global subscript counts, not disk bytes — approximate but monotonic. | manual probe |
| `/{db}/_design/{ddoc}/_search/*` | * | out of scope with reason | Lucene-backed search. Nouveau / Clouseau not implemented; IRIS has its own `%iFind` and `%Text` surface that adopters can use separately, but wire-compatible Lucene is out of scope. | N/A |
| `/{db}/_design/{ddoc}/_nouveau/*` | * | out of scope with reason | Same — Nouveau is Apache CouchDB 3.3.0+ optional Lucene replacement. | N/A |

---

## Design Documents — Shows, Lists, Updates, Rewrites

Source: `sources/couchdb/src/docs/src/api/ddoc/render.rst`,
`sources/couchdb/src/docs/src/api/ddoc/rewrites.rst`

| Endpoint | Method | Status | Caveat / Pointer | Verification |
|----------|--------|--------|------------------|--------------|
| `/{db}/_design/{ddoc}/_show/{show}` | GET, POST | 501 in default config | With `JSRUNTIME=None`. Story 12.3 did not implement `shows` dispatcher; most CouchDB deployments migrated off shows once Mango + client-side rendering matured. Epic 12 retro flags as "deferred until a consumer asks". | Manual probe; route not registered so current behavior is 404 (not 501) — tracked as a matrix-to-code deviation under Story 13.1 follow-up |
| `/{db}/_design/{ddoc}/_show/{show}` | GET, POST | 501 in default config | Under `JSRUNTIME=Subprocess` too — `shows` dispatcher not implemented in `documentation/couchjs/couchjs-entry.js`. Same rationale. | Manual probe (same as None backend) |
| `/{db}/_design/{ddoc}/_list/{list}/{view}` | GET, POST | 501 in default config | Same rationale as `_show`. `lists` dispatcher not implemented in any backend. | Manual probe |
| `/{db}/_design/{ddoc}/_update/{update}` | POST, PUT | 501 in default config | Same — `updates` dispatcher not implemented. | Manual probe |
| `/{db}/_design/{ddoc}/_rewrite/*` | * | 501 in default config | Same — `rewrites` dispatcher not implemented. | Manual probe |

---

## Design Documents — `validate_doc_update`

| Backend | Status | Caveat / Pointer | Verification |
|---------|--------|------------------|--------------|
| **None** (default) | 501 in default config | Writes against databases whose design docs contain a `validate_doc_update` function return `501 Not Implemented` with a reason pointing at `js-runtime.md`. Writes against databases with no validate hook continue to pass normally — the backend is genuinely a no-op when nothing needs to run. Story 12.3 AC #4. | `JSRuntimeValidateHttpTest.TestValidateReturns501WhenRuntimeIsNoneAndValidateIsPresent`, `JSRuntimeValidateHttpTest.TestWritesWithoutValidateStillPassUnderNone` |
| **Subprocess** (Node, shipped α/β) | supported with caveat | Multiple design docs each defining `validate_doc_update` run sequentially in subscript-id order; first rejection wins (matches CouchDB's `couch_db.erl::validate_doc_update_int`). **Deliberate divergence from CouchDB:** replication writes (via `_bulk_docs?new_edits=false` or `_replicate`) still run validate; CouchDB short-circuits replication via `{internal_repl, _} -> ok`. Chosen to prevent a hostile peer from bypassing validate rules. | `JSRuntimeValidateHttpTest.TestValidateApprovesWrite`, `JSRuntimeValidateHttpTest.TestValidateRejectsWithForbidden`, `JSRuntimeValidateHttpTest.TestValidateRejectsWithUnauthorized`, `JSRuntimeValidateHttpTest.TestMultipleValidatesFailFast` |
| **Python** (deferred) | out of scope with reason | **NOT SHIPPED** per Story 12.4 deferral. Workaround: `JSRUNTIME=Subprocess`. | N/A |

---

## Design Documents — Custom `_changes` filters

| Backend | Status | Caveat / Pointer | Verification |
|---------|--------|------------------|--------------|
| **None** (default) | 501 in default config | Custom filters (`filter=<ddoc>/<name>`) return `501`. **Built-in filters (`_doc_ids`, `_selector`, `_design`) are native ObjectScript and work unchanged** — only user-supplied filter functions require a JS runtime. | `JSRuntimeHttpTest.TestCustomFilterReturns501WhenRuntimeIsNone`, `JSRuntimeHttpTest.TestBuiltinFiltersStillWorkWhenRuntimeIsNone`, `ChangesFilterHttpTest.TestDocIdsFilterHttp`, `ChangesFilterHttpTest.TestSelectorFilterHttp`, `ChangesFilterHttpTest.TestDesignFilterHttp` |
| **Subprocess** (Node, shipped α/β) | supported with caveat | Custom filters executed per-document against a subprocess. Same per-query spawn cost as views (Story 12.5b plans pool). `req` object shaped like CouchDB's `chttpd_changes` request: `method`, `path`, `query`, `headers` (trimmed to `User-Agent` + `Content-Type`), `userCtx`, `info.db_name`. `filter=<missing-ddoc>/<name>` returns `404`. | `JSRuntimeFilterHttpTest.TestCustomFilterIncludesMatches`, `JSRuntimeFilterHttpTest.TestCustomFilterExcludesAll`, `JSRuntimeFilterHttpTest.TestCustomFilterMissingDocReturns404`, `JSRuntimeFilterHttpTest.TestBuiltinFiltersRegressGreen` |
| **Python** (deferred) | out of scope with reason | **NOT SHIPPED.** Workaround: `JSRUNTIME=Subprocess`. | N/A |

---

## Replication protocol

Source: `sources/couchdb/src/docs/src/api/database/common.rst` (replication section)

| Endpoint | Method | Status | Caveat / Pointer | Verification |
|----------|--------|--------|------------------|--------------|
| `/_replicate` | POST | supported | Single-shot replication; source / target can be any wire-compatible peer. Bidirectional parity exercised against Apache CouchDB 3.3.3 in Epic 8. | `ReplicationHttpTest.TestBulkDocsNewEditsFalse`, Epic 8 parity harness |
| `/_replicator` (database) | PUT | supported | Create the `_replicator` database (it is created automatically at install; PUT is idempotent). | `ReplicatorManagerHttpTest.TestCreateReplicatorDoc` (exercises the DB implicitly) |
| `/_replicator/{docid}` (create job) | PUT | supported | Continuous and one-shot job documents accepted. | `ReplicatorManagerHttpTest.TestCreateReplicatorDoc`, `ReplicatorManagerHttpTest.TestOneShotCompletion` |
| `/_replicator/{docid}` (read status) | GET | supported | Returns the replicator job doc with `_replication_state`, `_replication_stats`, etc. | `ReplicatorManagerHttpTest.TestOneShotCompletion` (asserts `_replication_state`) |
| `/_replicator/{docid}` (cancel) | DELETE | supported | Stops the job and removes the doc. | `ReplicatorManagerHttpTest.TestReplicatorDocDeletion` |
| `/{db}/_revs_diff` | POST | supported | Core replication endpoint; byte-diff-clean against CouchDB 3.3.3. | `RevsDiffHttpTest.TestRevsDiffAllExist`, `RevsDiffHttpTest.TestRevsDiffMissing` |
| `/{db}/_missing_revs` | POST | supported | (Rarely used by modern replicators; 3.x clients mostly use `_revs_diff`.) | `RevsDiffHttpTest.TestRevsDiffMissing`, `RevsDiffHttpTest.TestRevsDiffEmptyBody` |
| `/{db}/_local/{docid}` (replication checkpoints) | GET, PUT, DELETE | supported | Checkpoints are stored as `_local/<id>` documents; replicators write their progress markers here. | `LocalDocHttpTest.TestLocalPutAndGet`, `LocalDocHttpTest.TestLocalUpdate`, `ResilienceTest.TestCheckpointPersistence`, `ResilienceTest.TestCheckpointResume` |

---

## Authentication

Source: `sources/couchdb/src/docs/src/api/server/authn.rst`

| Endpoint / Flow | Status | Caveat / Pointer | Verification |
|-----------------|--------|------------------|--------------|
| HTTP Basic (default) | supported | Uses IRIS built-in credential store; validated against `Security.Users.CheckPassword` (not `$System.Security.Login`, which switches process context — see `.claude/rules/iris-objectscript-basics.md`). | `AuthHttpTest.TestBasicAuthOnExistingEndpoint` |
| Cookie session (`POST /_session`) | supported | `AuthSession` cookie with IRIS CSP session binding. | `AuthHttpTest.TestSessionPostSuccess`, `AuthHttpTest.TestSessionPostBadPassword`, `AuthHttpTest.TestTamperedCookieViaHttp` |
| JWT (`Authorization: Bearer <token>`) | supported | HMAC-SHA256/384/512 and RS256 tokens. Signing-key rotation supported via `IRISCouch.JWT.Keys`. | `JWTHttpTest.TestBearerAuthSuccess`, `JWTHttpTest.TestBearerAuthExpired`, `JWTHttpTest.TestAuthPriorityOrder` |
| Proxy auth (`X-Auth-CouchDB-UserName` / `X-Auth-CouchDB-Roles` / `X-Auth-CouchDB-Token` headers) | supported | Shared-secret proxy auth; the token header is an HMAC of the username. | `JWTHttpTest.TestProxyAuthSuccess`, `JWTHttpTest.TestProxyAuthBadToken` |
| OAuth 1.0a | out of scope with reason | CouchDB 3.0 removed OAuth 1.0a; IRISCouch follows suit. | N/A |
| `/_users/_all_docs` etc. (user database direct access) | supported | `_users` database is a regular database with ACL enforcement; user docs replicate. Password hashing (PBKDF2-SHA256) handled automatically on write. | `UsersHttpTest.TestCreateUsersDatabase`, `UsersHttpTest.TestCreateUser` |
| `/_users/org.couchdb.user:<name>` (per-user doc) | GET, PUT, DELETE | supported | Shape matches CouchDB: `{_id, type:"user", name, roles:[], password:"..."(write-only), derived_key, salt, iterations}`. | `UsersHttpTest.TestCreateUser`, `UsersHttpTest.TestUpdateUserPassword`, `UsersHttpTest.TestDeleteUser`, `UsersHttpTest.TestUserDocHasMetadata` |

---

## Attachments (detail)

Source: `sources/couchdb/src/docs/src/api/document/attachments.rst`

| Concern | Status | Notes |
|---------|--------|-------|
| Standalone `PUT {docid}/{att}` | supported | Binary bytes stored in `%Stream.GlobalBinary`; digest computed on write. |
| `DELETE {docid}/{att}` | supported | Bumps doc `_rev`. |
| Inline `_attachments.{name}` in JSON PUT | supported | Base64-decoded and persisted; full-body encoded via single `$System.Encryption.Base64Encode` call per attachment (not chunked-concatenated — see `.claude/rules/iris-objectscript-basics.md` for the round-trip correctness rule). |
| `multipart/related` body with attachments | supported | Parsed via `%request.MimeData` (not `%request.Content`, which is empty for multipart — see rules file). |
| `GET {docid}/{att}` with `Range:` header | supported | Range requests delegated to `%Stream.GlobalBinary.ReadAt`. |
| `atts_since` query param | supported | Replication optimization; attachments present in all listed revs are stubbed in the response. |
| `attachments=true` on `/{db}/{docid}` | supported | Emits inline `_attachments` with `data:"..."` base64 payload per attachment. |
| `att_encoding_info=true` | supported with caveat | Emits `encoding` / `encoded_length` fields when known. IRISCouch does not transparently re-encode stored attachments, so `encoding` is always either absent or `identity`; `encoded_length` equals `length`. Wire-shape compatible with CouchDB clients that expect the keys. |

---

## Footer — summary and pointers

**Row counts by status:** `supported: 74`, `supported with caveat: 12`,
`501 in default config: 10`, `out of scope with reason: 27`. (JSRuntime-aware
rows counted per backend state.)

**Source of every row.** Each row's verification column points at one of:

- An HTTP integration test class in `src/IRISCouch/Test/*HttpTest.cls` — run
  via `iris_execute_tests` at `level=class` or `level=method`.
- A manual `curl` probe — copy the command, run it, compare the response to
  the row.
- A replicator parity test against Apache CouchDB 3.3.3 in Epic 8's harness.

If a row's claim does not match reality on your instance, that's a bug
report. File an issue and cite the row + the row's verification method
alongside the actual response you got.

**What this matrix is not:**

- Not a client compatibility matrix. Client-level smoke tests (PouchDB 9.x,
  `nano`, the Apache replicator, Fauxton) are covered in the PRD under
  NFR-I4 and are re-run every release — they are not listed here row by
  row because the granularity is "does the client work against IRISCouch
  end-to-end", not "does each individual endpoint the client uses behave
  per spec".
- Not a wire-shape diff. Detailed response-body deviations (e.g., `purge_seq`
  counter vs. CouchDB's vector seq) are cited but not fully diffed. Story
  13.2 (deviation log) will maintain the full wire-shape diff.
- Not a performance matrix. Latency / throughput numbers are in the PRD's
  NFR-P section and in the Epic 12 retrospective benchmarks, not here.

**Maintenance rule (PRD NFR-I3) reiterated.** Any endpoint whose status
transitions — for example a 501 row flipping to `supported with caveat`
when Story 12.2a ships the missing view-query params — must have its
matrix row updated **in the same commit as the code change**. CI enforces.

---

## Change log

- **2026-04-18 (Story 13.1)** — Initial matrix authored. Covers Epic 1–12
  shipped state. JSRuntime states documented per backend
  (None / Subprocess / Python-deferred). View query-parameter coverage
  documented per Story 12.2a scope cut.
- **2026-04-18 (Story 13.1 code review)** — Test-method citations across
  all sections reconciled against the actual test suite
  (`src/IRISCouch/Test/*HttpTest.cls`); added 7 additional endpoint rows
  covering the CouchDB 3.x surface groups the initial matrix missed
  (`_dbs_info`, `_all_docs/queries`, `_design_docs/queries`,
  `_view/{view}/queries`, `_index/_bulk_delete`, `_auto_purge`, design-doc
  attachments); reclassified `/{db}/{docid}` COPY from `supported` to
  `out of scope with reason` (not implemented). Row counts re-audited
  mechanically: 74 supported / 12 supported-with-caveat / 10 501-in-default-config
  / 27 out-of-scope-with-reason / 123 total (initial counts in the 13.1
  Dev Agent Record undercounted).
- **2026-04-18 (manual acceptance pass — docs audit)** — Endpoint name
  `/_metrics` corrected to `/_prometheus` (the route actually registered
  in `src/IRISCouch/API/Router.cls` UrlMap per Story 9.1); the
  `/_node/{name}/_stats` caveat pointer updated to reference `/_prometheus`
  accordingly. No code change required — the Router already registered the
  correct route; this was a docs-only invented-endpoint drift of the same
  shape as the three caught in the Story 13.2 code review.
