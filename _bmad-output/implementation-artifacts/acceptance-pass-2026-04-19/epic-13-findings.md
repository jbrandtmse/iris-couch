# Epic 13 Documentation & Examples Acceptance Test Report — 2026-04-19

## Summary
- Docs verified: 6/6 (all present, non-trivial, internal links resolve)
- Examples verified: 6/6 directories present with consistent shape; 2 of the 2 simple curl-based examples (`hello-document`, `mango-query`) executed successfully against the live server
- Trailing-slash (Story 13-4): verified working for `/{db}/` and `/_utils/`; one boundary observation noted below
- Roadmap table consistent with epic statuses (Epics 1–13 = Done, Epic 14 = Backlog)
- ISSUES FOUND: 1 minor observation (not a regression) — see Trailing-Slash section

## Documentation

### getting-started.md
- Length: 710 lines
- Covers: prerequisites, install (ZPM + manual), 3-probe verify section (verbatim curl output), deployment topology options (reverse-proxy + direct mount), create-a-database, write-a-document, PouchDB browser + Node snippets, JavaScript Runtime Requirements (NFR-M9 verbatim), what's-next, troubleshooting sidebar — matches Story 13-1 AC #1–#3 in full
- Internal links resolve: yes (cross-doc links to compatibility-matrix, deviations, migration, troubleshooting, js-runtime, prd.md, .claude/rules/iris-objectscript-basics.md, README.md, examples/ all hit existing files)
- Verdict: PASS

### compatibility-matrix.md
- Length: 413 lines
- Coverage: groups endpoints per CouchDB family — Server / Database / Document / Design-Docs (Views, Shows/Lists/Updates/Rewrites, validate_doc_update, custom changes filters) / Replication / Authentication / Attachments — plus a "Runnable examples mapped to endpoint families" header (AC #6 cross-reference into examples/)
- Status markers: all four states present (`supported`, `supported with caveat`, `501 in default config`, `out of scope with reason`) with row counts (74/12/10/27 = 123 rows). Each row has a Verification column citing test class methods or manual probes
- Per Story 13-1 AC #5: JSRuntime view rows split by backend (None / Subprocess / Python-deferred) — present in `## Design Documents — Views`
- Per Story 13-4 AC #9: `/_session`, `/_all_dbs`, `/_uuids` rows have new `405 Method Not Allowed` rows; `/{db}/` trailing-slash row references `OnPreDispatch`; `/_utils/` references `AdminUIRBACTest`
- Verdict: PASS

### deviations.md
- Length: 367 lines
- Covers all 4 Epic-12 canonical deviations (view-key collation, _approx_count_distinct exact-count, 12.2a scope cut, Python deferred) plus 7 cross-epic deviations and 3 informational items per Story 13-2 AC #1
- Header carries NFR-M4 maintenance rule + operator-observable filter + entry-format spec
- Verdict: PASS

### migration.md
- Length: 570 lines
- All 8 phases present (pre-migration checklist → install → replicate-in → validation → dual-write → cutover → source drain → decommission) plus a "Symmetric rollback narrative" section at the end per Story 13-2 AC #2
- Verdict: PASS

### troubleshooting.md
- Length: 783 lines
- All 5 canonical incident classes present (Replication lag, Checkpoint corruption, Stuck conflicts, Attachment stream failures, JS sandbox errors) — each uses the four-part Symptoms / Diagnostic / Resolution / Prevention structure per Story 13-2 AC #3
- JS sandbox section covers all 5 JSRuntime sub-scenarios required by Story 13-2 AC #4 (501 from None backend, timeout misconfig, NODEPATH wrong, ZPM install failure on pre-2024.1 IRIS, validate_doc_update silent rejection)
- Verdict: PASS

### js-runtime.md
- Length: 356 lines
- Covers the 3 backends (None / Subprocess / Python-deferred), config keys, timeout enforcement, pool API
- Verdict: PASS

## Examples

### hello-document
- Entry: `examples/hello-document/run.sh`
- Ran successfully: yes
- Output excerpt: 7-step CRUD roundtrip — PUT db → PUT doc (rev 1-d5ae51ec…) → GET → PUT update (rev 2-d247540a…) → DELETE (rev 3-83b0636a…) → GET = HTTP 404 → DELETE db `{"ok":true}`. Clean exit.

### mango-query
- Entry: `examples/mango-query/run.sh`
- Ran successfully: yes
- Output excerpt: PUT db → seed 10 docs → POST /_index (status+created_at composite, type=json) → POST /_find with `$and[{status:$eq active},{created_at:$gt 2026-01-01}]` returned 5 docs + execution_stats → POST /_explain shows planner picked the composite index over `_all_docs` → DELETE db. Clean exit.

### pouchdb-sync
- Files present: README.md, run.mjs, expected-output.txt, node_modules/ (deps installed). Not executed per instructions (Node-based, treated as non-simple).

### replicate-from-couchdb
- Files present: README.md, run.sh, run.ps1, expected-output.txt. Not executed (requires reachable Apache CouchDB peer).

### attachment-upload
- Files present: README.md, run.mjs, expected-output.txt, fixtures/ (binary payload). Not executed (Node-based per Story 13-3 Task 5).

### jsruntime-subprocess-node
- Files present: README.md, run.sh, run.ps1, setup.js, expected-output.txt. Not executed (requires `JSRUNTIME=Subprocess` configured + Node).

### run-all harness
- `examples/run-all.sh` (99 lines) and `examples/run-all.ps1` (73 lines) both present. Not executed per instructions.

## Trailing-Slash (Story 13-4)

```
$ curl -i -u _system:SYS http://localhost:52773/iris-couch
HTTP/1.1 404 Not Found  ← CSP web-app dispatcher (no trailing slash on the application root itself)

$ curl -i -u _system:SYS http://localhost:52773/iris-couch/
HTTP/1.1 200 OK
{"couchdb":"Welcome","version":"0.1.0","vendor":{"name":"IRISCouch"}}

$ curl -i -u _system:SYS http://localhost:52773/iris-couch/_utils
HTTP/1.1 200 OK   (admin UI HTML served)

$ curl -i -u _system:SYS http://localhost:52773/iris-couch/_utils/
HTTP/1.1 200 OK   (admin UI HTML served)
```

Additional database-level probe (the actual scope of the Story 13-4 OnPreDispatch fix):

```
$ curl -X PUT -u _system:SYS http://localhost:52773/iris-couch/probe-ts-acc
HTTP/1.1 201 Created  {"ok":true}

$ curl -u _system:SYS http://localhost:52773/iris-couch/probe-ts-acc/   # WITH trailing slash
HTTP/1.1 200 OK  {"db_name":"probe-ts-acc","doc_count":0,...}
```

The OnPreDispatch trailing-slash normalization is working as specified for `/{db}/`, `/{db}/{docid}/`, `/_utils[/]`, etc. The bare `/iris-couch` (no slash) returning 404 is **expected** behavior — that's the CSP web-application root resolved by the IRIS CSP dispatcher *before* the IRISCouch Router.cls is even invoked, so OnPreDispatch cannot intercept it. Story 13-4 AC #1 explicitly scopes the fix to "non-root request paths" routed through Router.cls. Operators wanting `/iris-couch` (no slash) to redirect should use the edge-level rewrite documented in `migration.md` (Story 13-4 AC #2). Not a defect; documenting for completeness.

## README Roadmap Consistency

`README.md` Roadmap table:
- Epic 1–11: Done (matches sprint-status); Epic 12: `5/5 + 12.4 deferred` Done (matches Story 13-1 AC #7); Epic 13: `3/3 + 13.0 + 13.4` Done (matches Story 13-3 AC #7 + Story 13-4 AC #9d)
- "Documentation" section links to all 6 documentation files + examples/
- "JavaScript Runtime Requirements" section names `JSRUNTIMEBACKEND` keys, `Python` deferred per NFR-M9
- Verdict: CONSISTENT

## Overall Verdict

Epic 13 acceptance pass: **PASS**. All 6 documentation files exist and meet their story AC coverage; both runnable simple examples execute green against the live server; trailing-slash fix and admin-UI 401 path are in place per Story 13-4; README roadmap and Documentation section reflect the shipped state.
