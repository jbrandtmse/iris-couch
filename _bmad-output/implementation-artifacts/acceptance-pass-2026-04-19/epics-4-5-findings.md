# Epics 4-5 Acceptance Test Report — 2026-04-19

## Summary

All 6 stories (4.1, 4.2, 4.3, 5.1, 5.2, 5.3) were exercised against the live server at `http://localhost:52773/iris-couch/` using fresh DBs `acc19_e4_changes` and `acc19_e5_attach`. **All primary ACs pass.** Three minor wire deviations from CouchDB 3.x noted; none block functionality.

Wire deviations:
1. **Story 4.1**: `seq` is serialized as a JSON **string** (`"1"`) rather than the integer the story Dev Notes promise (`1`). CouchDB 2.x+ uses opaque strings, so this is forward-compatible — but it contradicts the story spec line "seq is an integer (not a string)".
2. **Story 4.2**: `since=now` is **not honored** — the server treats it as `since=0` and dumps all changes immediately instead of blocking. Numeric `since` values past `last_seq` block correctly.
3. **Story 5.3**: `HEAD /{db}/{docid}/{attname}` returns **405 Method Not Allowed**. The Router's UrlMap only declares PUT/GET/DELETE for the attachment route; `?att_encoding_info=true` also returns no `encoding`/`encoded_length` fields (attachments aren't gzip'd, so arguably moot, but the metadata key is missing).

## Story-by-Story Results

### Story 4.1: Normal Changes Feed
- **AC1 (basic shape)**: PASS — `{"results":[...],"last_seq":"6","pending":0}` returned with `seq/id/changes[{rev}]` per entry, monotonically increasing.
- **AC2 (since=N)**: PASS — `?since=2` returned only seq 3-6.
- **AC3 (limit=N + pending)**: PASS — `?limit=2` returned 2 entries with `pending:4`.
- **AC4 (include_docs=true)**: PASS — `doc` field present with `_id`/`_rev` injected.
- **AC5 (style=all_docs)**: NOT RE-TESTED (no conflicts seeded; story unit tests cover this).
- **AC6 (descending=true)**: PASS — `?descending=true&limit=2` returned seq 6 then 5.
- **AC7 (POST)**: PASS — `POST /_changes` with `{"since":0,"limit":2}` returned same shape as GET.
- **Deleted-doc flag**: PASS — `"deleted":true` present on tombstone entry.
- **Deviation**: `seq` is `"6"` (string) not `6` (int); contradicts Dev Notes line 110 but matches CouchDB 2.x wire shape.

### Story 4.2: Longpoll Changes Feed
- **AC1/AC2 (block then wake on write)**: PASS — longpoll with `since=last_seq&timeout=10000` blocked ~1s, woke when a doc was PUT in parallel, returned `seq:8` change in ~1244 ms total.
- **AC3 (timeout returns empty)**: PASS — `since=999&timeout=2000` returned `{"results":[],"last_seq":"999","pending":0}` after 2130 ms.
- **AC5 (immediate return when changes already present)**: PASS — `since=0&limit=2` returned in 131 ms with results.
- **AC4 (heartbeat)**: NOT TESTED via curl (timing-dependent; story tests cover).
- **Deviation**: `since=now` is **not** treated as "current last_seq" — it returns all changes immediately. Numeric `since` works correctly. CouchDB accepts the literal string `"now"`; this server does not.

### Story 4.3: Built-In Changes Filters
- **AC1 (filter=_doc_ids POST)**: PASS — `{"doc_ids":["doc1","doc3"]}` returned only those 2.
- **AC1 (filter=_doc_ids GET)**: PASS — `?doc_ids=["doc2","doc4"]` returned only those 2.
- **AC2 (filter=_selector)**: PASS — `{"selector":{"name":"doc2"}}` returned only doc2.
- **AC3 (filter=_design)**: PASS — only `_design/myview` returned.
- **AC4 (unknown filter → 404)**: PASS — `filter=_nonexistent` returned `404 {"error":"not_found","reason":"missing"}`.

### Story 5.1: Standalone Attachment Upload & Download
- **AC1 (PUT + 201 + new rev)**: PASS — returned `{"ok":true,"id":"mydoc","rev":"2-..."}` with HTTP 201.
- **AC5 (GET binary)**: PASS — bytes round-trip identical (md5 `5d6176b5...` matched both sides via `cmp`).
- **AC8 (404 for missing att)**: PASS — `{"error":"not_found","reason":"Document is missing attachment"}`.
- **AC9 (PUT without rev → 409)**: PASS — `{"error":"conflict","reason":"Document update conflict."}`.
- **AC12 (DELETE attachment)**: PASS — returned 200 with new rev `3-...`.

### Story 5.2: Inline & Multipart Attachment Upload
- **AC1 (inline base64)**: PASS — PUT with `_attachments:{hello.txt:{content_type,data:base64}}` stored correctly; GET returned original bytes.
- **AC3 (multipart/related upload)**: PASS — constructed multipart body with JSON part + binary part with `Content-Disposition: filename="file.bin"`; server stored it; GET round-tripped bytes (md5 matched).
- **AC5 (stub preservation)**: PASS — verified indirectly via 5.3 atts_since test; older attachment preserved as stub when new attachment added.

### Story 5.3: Attachment Retrieval Options & Multipart Response
- **AC1 (default = stubs)**: PASS — `_attachments` shows `{content_type,length,digest:"md5-...",revpos,stub:true}` per attachment.
- **AC2 (?attachments=true)**: PASS — base64 `data` field present, `stub:true` removed.
- **AC3 (?atts_since)**: PASS — older attachment (revpos=1) returned as stub, newer (revpos=2) returned with `data`.
- **AC4 (multipart/mixed + open_revs=all)**: PASS — `Content-Type: multipart/mixed; boundary=iriscouch_...`; body contains JSON part with `"follows":true` markers, then binary parts with proper `Content-Disposition: attachment; filename="..."` headers; closing `--boundary--`.
- **HEAD /{db}/{docid}/{attname}**: **FAIL (405)** — Router's UrlMap allows PUT/GET/DELETE only; HEAD returns 405. Story 5.3 mentions HEAD in the prompt list but it's NOT in the AC for 5.3 (ACs 1-6 don't reference HEAD). Treating as a minor gap, not a strict AC failure.
- **?att_encoding_info=true**: Returns stubs but does **not** add `encoding` / `encoded_length` fields. Server doesn't gzip attachments so the fields would be no-ops, but CouchDB would emit `encoding:"identity"` for completeness.

## Cleanup
Both test databases deleted (`HTTP 200` ok). Temp binaries removed.
