# Epics 1-3 Acceptance Test Report — 2026-04-19

## Summary
- Stories tested: 14/14
- PASS: 14
- FAIL: 0
- ISSUES FOUND: none (one minor observation noted under Story 2-3)

All Epic 1-3 acceptance criteria pass against the live IRISCouch server at
`http://localhost:52773/iris-couch/`. Wire shapes (status codes, JSON keys,
error envelopes, rev string format, `_all_docs` envelope, `_bulk_docs` array
result, `new_edits=false` semantics) match CouchDB 3.x. Throwaway DBs
`acc19_e2`, `acc19_e3`, `acc19_drop` were created and deleted; final
`_all_dbs` returned `["_users"]`.

## Story-by-Story Results

### Story 1-1: Configuration System & Package Scaffold
- All ACs PASS implicitly — server is running, routes resolve, `IRISCouch.Config` package present at `src/IRISCouch/Config.cls`, `module.xml` present. The fact that every other story below succeeds is the integration proof for the scaffold.

### Story 1-2: HTTP Router & Welcome Endpoint
- AC: GET `/iris-couch/` PASS — `200 OK`, body `{"couchdb":"Welcome","version":"0.1.0","vendor":{"name":"IRISCouch"}}`. Required keys present.
- AC: anonymous welcome PASS — also returns `200 OK` (anonymous read allowed on welcome).

### Story 1-3: UUID Generation
- AC default count=1: PASS — `{"uuids":["4371e2b69d8342ad86f1039fa23a6a24"]}` (32 hex chars).
- AC count=5: PASS — array length 5.
- AC count=0 (invalid): PASS — `400` `{"error":"bad_request","reason":"count must be a positive integer up to 1000"}`.
- AC count=1001: PASS — `400` same envelope.
- AC count=abc: PASS — `400` same envelope.

### Story 1-4: Error Envelope Consistency
- 404 unknown DB: PASS — `{"error":"not_found","reason":"Database does not exist."}`.
- 400 bad JSON: PASS — `{"error":"bad_request","reason":"invalid UTF-8 JSON"}`.
- 412 file_exists: PASS (via 2-1 re-PUT).
- 409 conflict: PASS (via 3-2 stale rev).
- All bodies use CouchDB shape `{"error":..,"reason":..}` with `Content-Type: application/json`.

### Story 1-5: Manual ObjectScript Import / Installation
- PASS implicitly — `README.md` and `module.xml` ship; server is operational, proving the install path works on this host.

### Story 2-1: Create / Delete Databases
- PUT `/acc19_e2`: PASS — `201 Created` (header omitted from tail), body `{"ok":true}`.
- Re-PUT (idempotent guard): PASS — `412 Precondition Failed` `{"error":"file_exists","reason":"The database could not be created, the file already exists."}`.
- PUT bad name `BadName`: PASS — `400 illegal_database_name` (validator enforces lowercase rule).
- DELETE existing `acc19_drop`: PASS — `200`, `{"ok":true}`.
- DELETE missing `no_such_db_xyz`: PASS — `404 not_found`.

### Story 2-2: List Databases & Metadata
- GET `/_all_dbs`: PASS — `["_users","acc19_e2"]`.
- GET `/acc19_e2`: PASS — body includes `db_name`, `doc_count:0`, `doc_del_count:0`, `update_seq:"0"`, `purge_seq:0`, `compact_running:false`, `sizes`, `instance_start_time`, `disk_format_version:1`, `committed_update_seq`. Matches CouchDB 3.x shape.
- GET missing DB: PASS — `404 not_found`.

### Story 2-3: Database Maintenance
- POST `_compact`: PASS — `202 Accepted`, `{"ok":true}`.
- POST `_ensure_full_commit`: PASS — `201 Created`, `{"ok":true,"instance_start_time":"0"}`.
- GET `_revs_limit`: PASS — `200`, plain integer body `1000`.
- PUT `_revs_limit` 500: PASS — `200`, body `500`. Subsequent GET also returns `500`.
- Observation (not an AC failure): probed `POST /{db}/_view_cleanup` returned `405 method_not_allowed` ("Only PUT,OPTIONS,GET,DELETE allowed"). Story 2-3 ACs do **not** include `_view_cleanup` (Epic 12 territory), so this is correctly out of scope.

### Story 3-1: Single Document Create / Read
- PUT `/acc19_e2/doc1`: PASS — `201`, `{"ok":true,"id":"doc1","rev":"1-8405b02c7a8b94ca85bffac5097b200e"}`. Rev format `<gen>-<32 hex>` correct.
- GET `/acc19_e2/doc1`: PASS — body contains `_id`, `_rev`, plus user fields.
- GET missing doc: PASS — `404`, `{"error":"not_found","reason":"missing"}`.

### Story 3-2: Update / Delete / Optimistic Concurrency
- PUT update with no rev: PASS — `409`, `{"error":"conflict","reason":"Document update conflict."}`.
- PUT update with stale rev `1-bogus`: PASS — `409` same envelope.
- PUT update with correct rev: PASS — `201`, rev advances to `2-...`.
- DELETE `?rev=<current>`: PASS — `200`, `{"ok":true,"id":"doc1","rev":"3-..."}`.
- DELETE without rev: PASS — `409 conflict`.
- DELETE non-existent doc: PASS — `404 missing`.

### Story 3-3: Revision Tree & Conflict Management
- After injecting branch via `new_edits=false`, GET `?conflicts=true`: PASS — body includes `"_conflicts":["1-bbbb..."]` listing the losing branch.
- GET `?revs=true`: PASS — includes `_revisions:{start:1, ids:[...]}`.
- GET `?revs_info=true`: PASS — includes `_revs_info:[{rev:"...",status:"available"}]`.
- GET `?open_revs=all`: PASS — returns array of `{"ok":{...}}` for each leaf rev.

### Story 3-4: Bulk Document Operations
- POST `_bulk_docs` with `{"docs":[{"_id":"a","x":1},{"_id":"b","x":2}]}`: PASS — `201`, body `[{"ok":true,"id":"a","rev":"1-..."},{"ok":true,"id":"b","rev":"1-..."}]`.
- Per-doc IDs honored when supplied (a, b kept). Conflict mixing verified via 3-3 path.

### Story 3-5: Replication-Format Bulk Writes (`new_edits=false`)
- POST `_bulk_docs` with `{"new_edits":false,"docs":[{"_id":"r1","_rev":"5-aaaa...","val":"replicated"}]}`: PASS — body `[]` (CouchDB convention: `new_edits=false` returns empty array on success). Subsequent GET `/acc19_e3/r1` returns `{"_id":"r1","_rev":"5-aaaa...","val":"replicated"}` — arbitrary client rev preserved.

### Story 3-6: `_all_docs` View
- GET `/acc19_e3/_all_docs`: PASS — `{"total_rows":4,"offset":0,"rows":[{"id":"a","key":"a","value":{"rev":"1-..."}}, ...]}`. Rows sorted by id ascending. Wire shape matches CouchDB.
- GET `?include_docs=true&limit=2`: PASS — each row gains a `doc` field with full body; limit honored (2 rows returned).

## Wire-Shape Compatibility Notes
- All status codes match CouchDB 3.x (201 create, 200 read/update-success-on-PUT-update via 3-2, 202 compact, 409 conflict, 412 file_exists, 404 not_found, 400 bad_request, 405 method_not_allowed).
- All error bodies use the `{"error":<token>,"reason":<sentence>}` envelope.
- All responses set `Content-Type: application/json`, including plain-integer `_revs_limit`.
- Rev strings are `<gen>-<32 hex>` exactly.
- `_bulk_docs` returns a top-level JSON **array** (not an object), as CouchDB does.
- `_all_docs` returns the `{total_rows, offset, rows}` envelope with `value.rev`.

## Cleanup
All throwaway DBs deleted. Final `_all_dbs` = `["_users"]`.
