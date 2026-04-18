# Deferred Work Log

## Open Items Summary (as of 2026-04-18, post Story 13.0 triage)

> **Convention.** This summary is maintained by each `X.0` cleanup story.
> Resolving an item requires (a) striking it in the full entry below
> (or annotating with `-- **RESOLVED in Story X.Y (YYYY-MM-DD):** ...`),
> and (b) removing its bullet here. New deferrals are appended to the
> appropriate severity list when the originating story's review lands.
> Initial population: Story 12.0 (2026-04-17) walked the full file and
> enumerated still-open items. HIGH is empty today.

### HIGH

- **[HIGH] Story 13.3** IRISCouch returns 404 for the trailing-slash variant of database URLs (`PUT /{db}/`, `GET /{db}/`, `HEAD /{db}/`). CouchDB 3.x accepts both. PouchDB's default remote-handle construction issues `PUT /{db}/` for auto-create, so any PouchDB-based adopter hits this on the first line of their integration. **Workaround shipped today:** pre-create the DB via `PUT /{db}` (no trailing slash) and pass `{ skip_setup: true }` to PouchDB — see [`examples/pouchdb-sync/`](../../examples/pouchdb-sync/README.md). **Fix path:** add `/:db/` routes (delegating to the same handlers as `/:db`) to `src/IRISCouch/API/Router.cls` UrlMap. Trigger: next backend cleanup story -- [full entry](#deferred-from-story-133-implementation-2026-04-18)

### MEDIUM

- **[MED] Story 13.3** Compatibility matrix view-query-parameter rows corrected: `group`, `group_level`, `startkey`, `endkey`, `limit`, `skip` were listed as "supported (Story 12.2 shipped)" but the code in `IRISCouch.View.QueryEngine` and `IRISCouch.API.ViewHandler.ExtractQueryParams` silently ignores them (confirmed by dev-host test: `group=true` on a grouped reduce returns `{"rows":[{"key":null,"value":N}]}` — ungrouped output). Matrix updated in same commit to reclassify these rows as `silently ignored (Story 12.2a)`, consistent with the existing Story 12.2 deferred-work entry. -- [full entry](#deferred-from-story-133-implementation-2026-04-18)
- **[MED] Story 13.3** Examples CI harness unwired. Trigger: before α/β tagging gate. Owner: TBD. Description: `examples/run-all.sh` and `examples/run-all.ps1` exist and pass locally on the dev host (5/6 pass, 1 environmental-skip for replicate-from-couchdb pending a dockerized CouchDB or reachable peer). Requires a dockerized IRIS CI image + GitHub Actions workflow (`examples-smoke.yml`) to satisfy epics.md AC #4 "broken example blocks the release" at release-tag time. -- [full entry](#deferred-from-story-133-implementation-2026-04-18)

- **[MED] Story 12.2** View query params beyond `reduce`/`include_docs` not implemented; suggest Story 12.2a for `group`, `group_level`, `startkey`, `endkey`, `limit`, `skip` -- [full entry](#deferred-from-story-12-2-implementation-2026-04-17)
- **[MED] Story 12.2** `_approx_count_distinct` uses exact distinct count (HLL deferred to Epic 14) -- [full entry](#deferred-from-story-12-2-implementation-2026-04-17)
- **[MED] Story 12.2** Row sort uses JSON string collation, not CouchDB typed collation; mixed-type keys mis-ordered -- [full entry](#deferred-from-story-12-2-implementation-2026-04-17)
- ~~**[MED] Story 12.2 review** NFR-S9 subprocess sandbox hardening~~ -- **RESOLVED in Story 12.5 (2026-04-17, patched during code review)**: `Pipe.BuildSandboxFlags` emits per-interpreter flags (Node: `--disable-proto=delete --no-experimental-global-webcrypto --no-warnings`; Deno: `run --allow-read --deny-net/write/run/env/ffi/sys`); `Pipe.ValidateExecutablePath` rejects `..` traversal and missing-file paths and is applied to BOTH the interpreter and the entry script. Memory-cap Windows Job Object enforcement deferred to Story 12.5a (PowerShell helper required).
- ~~**[MED] Story 12.2 review** `JSRUNTIMETIMEOUT` documented as enforced but `Pipe.cls` does not pass a timeout to `$ZF(-100)`~~ -- **RESOLVED in Story 12.5 (2026-04-17)**: two-layer enforcement via (a) couchjs-entry.js `setTimeout(exit(124)).unref()` self-kill and (b) IRIS-side `/ASYNC` + `tasklist`/`kill -0` polling with `taskkill`/`kill -9` on expiry. `Pipe.Flush` returns `jsruntime_timeout: subprocess exceeded Nms`; `ViewIndexUpdater` propagates the timeout so write transactions TROLLBACK. Verified by `ViewIndexHttpTest.TestRunawayMapFunctionTimesOut`.
- **[MED] Story 12.5 → 12.5a** Windows Job Object memory cap enforcement. `JSRUNTIMEMAXRSSMB` is honoured only as a soft target by pool health checks; hard OS-level kill-on-commit-exceed requires a PowerShell helper with P/Invoke or a signed native helper. Deferred to Story 12.5a -- operators on Windows should assume a runaway allocator is caught only by `JSRUNTIMETIMEOUT`, not memory cap.
- **[MED] Story 12.5 → 12.5b** True long-lived pooled subprocess. The 12.5 Pool API is a pragmatic shim (fresh Pipe per Acquire) because `$ZF(-100)` is synchronous. A bidirectional `$ZF(-100,"/ASYNC")` long-lived stdio pattern would let a single Node process amortise cold-start across hundreds of calls. Scope cut for 12.5; track as 12.5b when an async-pipe pattern is hardened.
- **[MED] Story 12.5** View compaction (garbage-collecting orphaned `^IRISCouch.ViewIndex*` entries after mass deletes) not shipped. Incremental update removes per-doc entries as docs change, so in normal operation nothing orphans; but a `Storage.ViewIndex.Compact(pDB)` maintenance entry point is a useful operator tool. Tracked as Story 12.5c.
- **[MED] Story 10.3** ErrorDisplay test suite has only 3 examples (401/404/500); UX spec requires 5 -- add 409 and network-error -- [full entry](#deferred-from-code-review-of-10-3-appshell-navigation-and-login-2026-04-14)
- **[MED] Story 10.4** No UI trigger for database delete action (AC #5) -- backing method exists but DataTable lacks action-column support -- [full entry](#deferred-from-code-review-of-10-4-database-list-view-with-create-and-delete-2026-04-14)
- **[MED] Story 11.0** UI smoke workflow requires self-hosted runner; workflow queues indefinitely without infra -- [full entry](#deferred-from-story-110-implementation-2026-04-14)
- ~~**[MED] Story 12.3 review** `ListValidateFunctions` iterates ALL live docs then filters on `_design/` prefix~~ -- **RESOLVED in Story 12.5 (2026-04-17)**: `ViewIndexUpdater.ListDesignDocIds` uses direct `$Order` over `^IRISCouch.Tree(pDB, "_design/")` so cost is O(k) in the number of design docs. The pattern is reusable; `DesignDocs.ListValidateFunctions` can adopt it in a cleanup story when design-doc counts get large in practice.
- ~~**[MED] Story 12.3 review** One subprocess spawn per changes-feed doc for custom filters~~ -- **RESOLVED in Story 12.5 (2026-04-17)**: the new `IRISCouch.JSRuntime.Subprocess.Pool` API (Acquire/Release) is in place. In 12.5 the pool is a pragmatic shim (fresh Pipe per call) because `$ZF(-100)` is sync-per-command. The incremental indexing work (Task 2) also removes the subprocess cost from the view-query hot path entirely. True long-lived subprocess pooling is tracked as Story 12.5b.

### LOW

**ObjectScript backend (Epics 1-9):**

- **[LOW] Story 1.1** `Config.Get()` silently returns "" for misspelled keys -- [full entry](#deferred-from-code-review-of-1-1-configuration-system-and-package-scaffold-2026-04-12)
- **[LOW] Story 1.1** `Config.GetAll()` numeric parameters serialize as strings -- [full entry](#deferred-from-code-review-of-1-1-configuration-system-and-package-scaffold-2026-04-12)
- **[LOW] Story 1.1** `Config.Set()` accepts arbitrary keys without validation -- [full entry](#deferred-from-code-review-of-1-1-configuration-system-and-package-scaffold-2026-04-12)
- **[LOW] Story 1.1** `Request.ReadBody()` has no size limit -- [full entry](#deferred-from-code-review-of-1-1-configuration-system-and-package-scaffold-2026-04-12)
- **[LOW] Story 1.4** `Error.Render()` crashes if `%response` missing (non-HTTP context) -- [full entry](#deferred-from-code-review-of-1-4-error-envelope-and-consistent-error-responses-2026-04-12)
- **[LOW] Story 1.2** Missing metrics dispatch wrapper structure in `Router.cls` -- [full entry](#deferred-from-code-review-of-1-2-http-router-and-couchdb-welcome-endpoint-2026-04-12)
- **[LOW] Story 2.1** No maximum database name length validation -- [full entry](#deferred-from-code-review-of-2-1-create-and-delete-databases-2026-04-12)
- **[LOW] Story 3.1** `RevTree.AddChild` does not verify parent revision exists in leaf index -- [full entry](#deferred-from-code-review-of-3-1-single-document-create-and-read-2026-04-12)
- **[LOW] Story 3.1** No underscore-prefix validation on document IDs in `HandlePut` -- [full entry](#deferred-from-code-review-of-3-1-single-document-create-and-read-2026-04-12)
- **[LOW] Story 3.4** `HandleBulkGet` silently skips docs with empty id -- [full entry](#deferred-from-code-review-of-3-4-bulk-document-operations-2026-04-12)
- **[LOW] Story 3.6** `_local_seq` omitted when no changes entry found -- [full entry](#deferred-from-code-review-of-3-6-all-documents-view-2026-04-12)
- **[LOW] Epic 3 retro** `HandleAllDocs` iterates `^IRISCouch.Docs` directly (9 lines) -- [full entry](#deferred-from-epic-3-retrospective--storage-encapsulation-violations-2026-04-13)
- **[LOW] Story 5.1** `FindRevWithAttachment` lexicographic sort fails at generation 10+ -- [full entry](#deferred-from-code-review-of-5-1-standalone-attachment-upload-and-download-2026-04-12)
- **[LOW] Story 5.1** Stream OID leak on attachment Delete -- [full entry](#deferred-from-code-review-of-5-1-standalone-attachment-upload-and-download-2026-04-12)
- **[LOW] Story 5.2** Double base64 encode/decode in multipart/related path -- [full entry](#deferred-from-code-review-of-5-2-inline-and-multipart-attachment-upload-2026-04-12)
- **[LOW] Story 5.3** Attachment buffering in base64 paths reads entire stream into memory -- [full entry](#deferred-from-code-review-of-5-3-attachment-retrieval-options-and-multipart-response-2026-04-12)
- **[LOW] Story 5.3** No `attachments=true` support for open_revs JSON response path -- [full entry](#deferred-from-code-review-of-5-3-attachment-retrieval-options-and-multipart-response-2026-04-12)
- **[LOW] Epic 5 cleanup** Delete() clears shared stream OID data affecting other revisions -- [full entry](#deferred-from-code-review-of-6-0-epic-5-deferred-cleanup-2026-04-13)
- **[LOW] Epic 5 cleanup** Stub delimiter "||" in SaveWithAttachments may collide with attachment names -- [full entry](#deferred-from-code-review-of-6-0-epic-5-deferred-cleanup-2026-04-13)
- **[LOW] Epic 5 cleanup** Delete Clear+Save leaves zero-byte stream entry -- [full entry](#deferred-from-code-review-of-6-0-epic-5-deferred-cleanup-2026-04-13)
- **[LOW] Story 6.1** `GetJsonType` treats string "true"/"false" as boolean without type hint -- [full entry](#deferred-from-code-review-of-6-1-mango-index-management-2026-04-13)
- **[LOW] Story 6.1** `ExtractFieldValue` cannot distinguish missing vs empty-string field -- [full entry](#deferred-from-code-review-of-6-1-mango-index-management-2026-04-13)
- **[LOW] Epic 6 cleanup** `TypeRank` vs `InferType` inconsistency on empty string -- [full entry](#deferred-from-code-review-of-7-0-epic-6-deferred-cleanup-2026-04-13)
- **[LOW] Story 7.1** Username containing colons breaks cookie parsing -- [full entry](#deferred-from-code-review-of-7-1-session-authentication-and-basic-auth-2026-04-13)
- **[LOW] Story 7.2** JWT exp check has no clock skew tolerance -- [full entry](#deferred-from-code-review-of-7-2-jwt-and-proxy-authentication-2026-04-13)
- **[LOW] Story 7.3** `SaveWithHistory` does not call `_users` hooks -- [full entry](#deferred-from-code-review-of-7-3-user-management-via-users-database-2026-04-13)
- **[LOW] Story 7.3** `SaveWithAttachments` does not call `_users` hooks -- [full entry](#deferred-from-code-review-of-7-3-user-management-via-users-database-2026-04-13)
- **[LOW] Story 7.3** Falsy password values not guarded in `Auth/Users.cls` -- [full entry](#deferred-from-code-review-of-7-3-user-management-via-users-database-2026-04-13)
- **[LOW] Story 8.1** `RenderInternal` called without exception arg for Storage write failures -- [full entry](#deferred-from-code-review-of-8-1-local-documents-and-replication-checkpoints-2026-04-13)
- **[LOW] Story 8.1** No error handling in `Storage.Local.Read()/GetRev()` for corrupted `$ListBuild` data -- [full entry](#deferred-from-code-review-of-8-1-local-documents-and-replication-checkpoints-2026-04-13)
- **[LOW] Story 8.2** `possible_ancestors` returns all leaf revisions without generation filtering -- [full entry](#deferred-from-code-review-of-8-2-revision-difference-calculation-2026-04-13)
- **[LOW] Story 8.3** Partial attachment `Get()` failure produces mixed stubs+inline response -- [full entry](#deferred-from-code-review-of-8-3-replication-ready-bulk-get-2026-04-13)
- **[LOW] Story 8.4** `ReplicateLocal` (push) path lacks NFR-R1 corruption detection -- [full entry](#deferred-from-code-review-of-8-4-bidirectional-replication-protocol-2026-04-13)
- **[LOW] Story 8.4** `ReplicateLocal` (push) path does not include inline attachment data in `_bulk_docs` -- [full entry](#deferred-from-code-review-of-8-4-bidirectional-replication-protocol-2026-04-13)
- **[LOW] Story 8.4** `HttpClient` SSLConfiguration hardcoded to `"ISC.FeatureTracker.SSL.Config"` -- [full entry](#deferred-from-code-review-of-8-4-bidirectional-replication-protocol-2026-04-13)
- **[LOW] Story 8.4** `HttpClient.Request` reads entire response body into string -- [full entry](#deferred-from-code-review-of-8-4-bidirectional-replication-protocol-2026-04-13)
- **[LOW] Story 8.4** `Checkpoint.BuildCheckpointDoc` types `source_last_seq` as "number" (CouchDB 2.x uses strings) -- [full entry](#deferred-from-code-review-of-8-4-bidirectional-replication-protocol-2026-04-13)
- **[LOW] Story 8.4** No checkpoint written when source has zero changes and no prior checkpoint -- [full entry](#deferred-from-code-review-of-8-4-bidirectional-replication-protocol-2026-04-13)
- **[LOW] Story 8.5** Missing MangoIndex re-indexing in `_replicator` Save hook -- [full entry](#deferred-from-code-review-of-8-5-replicator-database-and-continuous-replication-jobs-2026-04-13)
- **[LOW] Story 8.5** `ReplicateLocal` / `ReplicateRemote` do not populate `pStats` Output -- [full entry](#deferred-from-code-review-of-8-5-replicator-database-and-continuous-replication-jobs-2026-04-13)
- **[LOW] Story 8.5** One-shot replication error does not retry -- [full entry](#deferred-from-code-review-of-8-5-replicator-database-and-continuous-replication-jobs-2026-04-13)
- **[LOW] Story 9.1** `BuildOutput` string concatenation may exceed ObjectScript ~3.6MB string limit -- [full entry](#deferred-from-code-review-of-9-1-prometheus-opentelemetry-metrics-endpoint-2026-04-13)
- **[LOW] Story 9.3** `Log.Debug()` has no gating for debug-level logging -- [full entry](#deferred-from-code-review-of-9-3-operational-resilience-and-data-durability-2026-04-13)
- **[LOW] Epic 9 cleanup** `JWT.UnixTimestamp()` uses `$Horolog` (local time) but doc claims UTC -- [full entry](#deferred-from-code-review-of-10-0-epic-9-deferred-cleanup-2026-04-14)
- **[LOW] Story 10.6** Design doc ID double-encoding in `getDocument` / `getAttachmentUrl` (pending Epic 11 routing) -- [full entry](#deferred-from-code-review-of-10-6-document-detail-view-2026-04-14)
- **[LOW] Story 11.2** IRISCouch `_security` backend divergence from CouchDB 3.x spec (informational) -- [full entry](#deferred-from-story-112----security-configuration-view-2026-04-14)
- **[LOW] Story 11.3** `TestPostDesignDocNotAllowed` accepts 404 OR 405 -- [full entry](#deferred-from-code-review-of-11-3-design-document-and-security-editing-2026-04-15)
- **[LOW] Story 11.0 impl** `sizes.external` / `sizes.active` report allocated bytes, not pre-compression JSON -- [full entry](#deferred-from-story-110-implementation-2026-04-14)

**Angular UI (Epics 10-11):**

- **[LOW] Story 10.1** No `ChangeDetectionStrategy.OnPush` on icon components -- [full entry](#deferred-from-code-review-of-10-1-angular-scaffold-design-tokens-and-icon-system-2026-04-14)
- **[LOW] Story 10.1** `@Input()` decorator vs modern `input()` signal (see also "Angular UI — ongoing") -- [full entry](#deferred-from-code-review-of-10-1-angular-scaffold-design-tokens-and-icon-system-2026-04-14)
- **[LOW] Story 10.1** No JetBrains Mono weight 500 bundled -- [full entry](#deferred-from-code-review-of-10-1-angular-scaffold-design-tokens-and-icon-system-2026-04-14)
- **[LOW] Story 10.2** Badge 10px font-size vs AC #6 "no text below 12px" -- [full entry](#deferred-from-code-review-of-10-2-core-ui-components-2026-04-14)
- **[LOW] Story 10.2** Hardcoded RGBA values in badge backgrounds -- [full entry](#deferred-from-code-review-of-10-2-core-ui-components-2026-04-14)
- **[LOW] Story 10.2** CopyButton no error feedback on failed clipboard copy -- [full entry](#deferred-from-code-review-of-10-2-core-ui-components-2026-04-14)
- **[LOW] Story 10.3** Password field not cleared after successful login -- [full entry](#deferred-from-code-review-of-10-3-appshell-navigation-and-login-2026-04-14)
- **[LOW] Story 10.3** Button component CSS budget warning -- [full entry](#deferred-from-code-review-of-10-3-appshell-navigation-and-login-2026-04-14)
- **[LOW] Story 10.5** `paginationStart` assumes linear page history -- [full entry](#deferred-from-code-review-of-10-5-document-list-view-with-filtering-and-pagination-2026-04-14)
- **[LOW] Story 10.5** `totalRows` reflects total DB doc count, not filtered count -- [full entry](#deferred-from-code-review-of-10-5-document-list-view-with-filtering-and-pagination-2026-04-14)
- **[LOW] Story 10.7** Network error message hardcoded in 3 components (DRY) -- [full entry](#deferred-from-code-review-of-10-7-error-handling-accessibility-and-cross-browser-verification-2026-04-14)
- **[LOW] Story 10.7** Error handler pattern (status=0 branch) duplicated 3x -- [full entry](#deferred-from-code-review-of-10-7-error-handling-accessibility-and-cross-browser-verification-2026-04-14)
- **[LOW] Angular UI ongoing** Real favicon -- [full entry](#angular-ui--ongoing-deferrals-initialized-by-story-110)
- **[LOW] Angular UI ongoing** Angular 19+ idiom polish -- [full entry](#angular-ui--ongoing-deferrals-initialized-by-story-110)
- **[LOW] Story 11.0 impl** stylelint configured but not installed -- [full entry](#deferred-from-story-110-implementation-2026-04-14)
- **[LOW] Story 11.0 review** Smoke.mjs path resolution on Windows -- [full entry](#deferred-from-story-110-code-review-2026-04-14)
- **[LOW] Story 11.0 review** FeatureError rawError setter clears statusCode -- [full entry](#deferred-from-story-110-code-review-2026-04-14)
- **[LOW] Story 11.3** TextAreaJson uses `getElementById` for gutter scroll sync -- [full entry](#deferred-from-code-review-of-11-3-design-document-and-security-editing-2026-04-15)
- **[LOW] Story 11.3** `design-doc-create-dialog` `titleId` uses `Date.now()` without randomness -- [full entry](#deferred-from-code-review-of-11-3-design-document-and-security-editing-2026-04-15)
- **[LOW] Story 11.3** Delete-dialog body uses `[innerHTML]` -- [full entry](#deferred-from-code-review-of-11-3-design-document-and-security-editing-2026-04-15)
- **[LOW] Story 11.3** TextAreaJson `emitValidity` re-emits on every invalid tick -- [full entry](#deferred-from-code-review-of-11-3-design-document-and-security-editing-2026-04-15)
- **[LOW] Story 11.4** Rapid mouseenter popover churn -- [full entry](#deferred-from-code-review-of-11-4-revision-history-view-2026-04-15)
- **[LOW] Story 11.4** `selectedRev` not preserved across Refresh click -- [full entry](#deferred-from-code-review-of-11-4-revision-history-view-2026-04-15)
- **[LOW] Story 11.4** `showPopover` anchors SVG cast as `HTMLElement` -- [full entry](#deferred-from-code-review-of-11-4-revision-history-view-2026-04-15)
- **[LOW] Story 11.4** AC #5 wording says "move the selected node"; impl moves focus -- [full entry](#deferred-from-code-review-of-11-4-revision-history-view-2026-04-15)
- **[LOW] Story 11.4** No explicit "≥ 5 conflict branches" layout test -- [full entry](#deferred-from-code-review-of-11-4-revision-history-view-2026-04-15)
- **[LOW] Story 11.5** AC #4 error message says `%IRISCouch_Admin` vs `IRISCouch_Admin` -- [full entry](#deferred-from-code-review-of-11-5-admin-ui-handler-and-security-2026-04-15)
- **[LOW] Story 12.1** `Util.Error.Render501` `pSubsystem` parameter unused in response body -- [full entry](#deferred-from-code-review-of-12-1-jsruntime-sandbox-interface-and-none-backend-2026-04-17) -- **KEPT DEFERRED (2026-04-18, Story 13.0): revisit if/when Story 12.2+ introduces richer error metadata that needs a structured `subsystem` field in the 501 body.**
- **[LOW] Story 12.1** `Factory.GetSandbox()` logs unrate-limited Warn on garbage config -- [full entry](#deferred-from-code-review-of-12-1-jsruntime-sandbox-interface-and-none-backend-2026-04-17) -- **KEPT DEFERRED (2026-04-18, Story 13.0): log-hygiene only; fires only under misconfiguration. Revisit if a customer reports log spam traced to this call site.**
- **[LOW] Story 12.1** `iris_execute_tests` class-level discovery only reports 3/11 methods (individual runs all pass) -- [full entry](#deferred-from-code-review-of-12-1-jsruntime-sandbox-interface-and-none-backend-2026-04-17) -- **KEPT DEFERRED (2026-04-18, Story 13.0): tooling bug in `iris-dev-mcp`, not in IRISCouch; Story 13.0 re-probed and confirmed class-level discovery is still broken (ViewIndexHttpTest correctly lists 7 methods; JSRuntimeHttpTest returns only 1). Revisit when the MCP async work-queue issue is fixed upstream.**
- **[LOW] Story 12.2 review** `QueryEngine.Query` double-resolves the winning rev per document (ListLiveDocIds already filters by rev/tombstone) -- [full entry](#deferred-from-code-review-of-12-2-subprocess-jsruntime-map-reduce-views-2026-04-17) -- **KEPT DEFERRED (2026-04-18, Story 13.0): correctness-neutral perf waste; already tagged for Story 12.2a (View Query Parameters) where pagination / index-iterator refactor is the natural home. Do not resolve here — touching QueryEngine outside a pagination story risks scope creep.**
- **[LOW] Story 12.2 review** `SubprocessTestRunner` + `SubprocessTestRunner.ProbeManager` temp helpers still in codebase (keep until MCP `iris_execute_tests` stabilises) -- [full entry](#deferred-from-code-review-of-12-2-subprocess-jsruntime-map-reduce-views-2026-04-17) -- **KEPT DEFERRED (2026-04-18, Story 13.0): Story 13.0 re-probed MCP `iris_execute_tests` — class-level discovery still returns 1/N methods on JSRuntimeHttpTest (same symptom as Story 12.1 logged). The probe helpers remain the workaround. Revisit when MCP work-queue instability is resolved upstream.**
- **[LOW] Story 12.2 review** `Subprocess.ExecuteReduce` does not validate the `reset` ack before reading the reduce response -- [full entry](#deferred-from-code-review-of-12-2-subprocess-jsruntime-map-reduce-views-2026-04-17) -- **KEPT DEFERRED (2026-04-18, Story 13.0): diagnostic-quality only. Revisit bundled with the same assert-ack fix for ExecuteValidateDocUpdate when an operator reports a vague "empty response" subprocess error in the wild.**
- **[LOW] Story 12.3 review** `Test/SubprocessValidateProbe.cls` retained as evidence-of-work scaffolding per story spec; delete at story close or next Epic 12 retrospective -- [full entry](#deferred-from-code-review-of-12-3-subprocess-jsruntime-validation-and-filter-functions-2026-04-17) -- **KEPT DEFERRED (2026-04-18, Story 13.0): Story 13.0 re-probed MCP `iris_execute_tests` — still broken for JSRuntimeValidateHttpTest / JSRuntimeFilterHttpTest class-level discovery. The probe class's `RunAllValidateHttpTests` / `RunAllFilterHttpTests` helpers remain the only reliable full-suite runner. Revisit when MCP work-queue stabilises — same trigger as the SubprocessTestRunner entry above.**
- **[LOW] Story 12.3 review** `Subprocess.ExecuteValidateDocUpdate` does not validate the `reset` ack or `ddoc-new` ack before reading the invoke response (same diagnostic-quality gap as ExecuteReduce) -- [full entry](#deferred-from-code-review-of-12-3-subprocess-jsruntime-validation-and-filter-functions-2026-04-17) -- **KEPT DEFERRED (2026-04-18, Story 13.0): pair with the ExecuteReduce ack-validation entry above; single revisit trigger (operator-reported vague subprocess error) handles both.**
- **[LOW] Story 12.3 review** Hardcoded `NODEPATH = "C:\Program Files\nodejs\node.exe"` in `JSRuntimeValidateHttpTest`, `JSRuntimeFilterHttpTest`, and `SubprocessValidateProbe`; tests skip via `CanLaunchSubprocess` on non-Windows but still non-portable -- [full entry](#deferred-from-code-review-of-12-3-subprocess-jsruntime-validation-and-filter-functions-2026-04-17) -- **KEPT DEFERRED (2026-04-18, Story 13.0): tests already skip gracefully via `CanLaunchSubprocess`. Revisit when the Python-less IRIS CI image (see Story 12.4-resumption block below) lands and we need Linux-path Node discovery for cross-platform CI.**
- **[LOW] Story 12.3 review** MCP `iris_execute_tests` class-level discovery reports only 1/9 methods for `JSRuntimeValidateHttpTest` and 1/4 for `JSRuntimeFilterHttpTest`; individual runs all pass (same symptom previously logged for Story 12.1 and 12.2). Dev used a probe-helper `RunAllValidateHttpTests` to aggregate -- [full entry](#deferred-from-code-review-of-12-3-subprocess-jsruntime-validation-and-filter-functions-2026-04-17) -- **KEPT DEFERRED (2026-04-18, Story 13.0): tooling bug confirmed still present at Story 13.0 time (see 12.1 entry above); not an IRISCouch issue. File against `iris-dev-mcp` upstream when reproducible outside this project.**
- **[LOW] Story 12.3 review** `RunValidateHook` uses `$ZHorolog` (local time, not monotonic) for duration measurement; crossing midnight yields negative durations in the audit `durationMs` field -- [full entry](#deferred-from-code-review-of-12-3-subprocess-jsruntime-validation-and-filter-functions-2026-04-17) -- **KEPT DEFERRED (2026-04-18, Story 13.0): project-wide convention (same pattern in Story 9.3 logging + Story 12.2 view audit). Revisit as a single sweeping fix when a customer reports the midnight-negative duration in a real audit log — changing one call site here while leaving the others is worse than leaving all three.**
- **[LOW] Story 12.5 review** `Pool.ShutdownAll` never invoked (no-op in shim; must be wired when 12.5b lands real pooling) -- [full entry](#deferred-from-code-review-of-12-5-incremental-view-indexing-caching-and-sandbox-safety-2026-04-17) -- **KEPT DEFERRED (2026-04-18, Story 13.0): trigger is Story 12.5b resumption (real long-lived pool). Wiring ShutdownAll to a namespace shutdown hook is only needed when there are actually pooled subprocesses to shut down.**
- ~~**[LOW] Story 12.5 review** `Pool.cls` docstring overstates stack-LIFO implementation vs actual shim~~ -- **RESOLVED in Story 13.0 (2026-04-18)**: docstring rewritten to mark the storage block as "Planned for Story 12.5b — shim today"; current Acquire behaviour and future LIFO-stack layout are now clearly separated.
- ~~**[LOW] Story 12.5 review** `EncodeKeyForSort` bool/integer ambiguity sentinel is dead code~~ -- **RESOLVED in Story 13.0 (2026-04-18)**: dead `If (pKey = 1) && ($Get(pKey) = 1) && ('$Listvalid(pKey)) {…}` block removed from `Storage/ViewIndex.cls`; rationale retained in the comment above the fall-through. `Storage.ViewIndex` and `ViewIndexHttpTest` suites remain green (8/8 + 7/7).
- **[LOW] Story 12.5 review** Byte-equality claim covers only a single 10-doc fixture; broader coverage belongs in 12.2a -- [full entry](#deferred-from-code-review-of-12-5-incremental-view-indexing-caching-and-sandbox-safety-2026-04-17) -- **KEPT DEFERRED (2026-04-18, Story 13.0): trigger already named — Story 12.2a (View Query Parameters) will ship the mixed-type-key / reduce-output / `include_docs=true` byte-equality harness. No Story 13.0 fix.**
- ~~**[LOW] Story 12.5 review** `TestPooledSubprocessReducesLatency` name misleads — measures warm-index latency, pool is still a shim~~ -- **RESOLVED in Story 13.0 (2026-04-18)**: renamed to `TestWarmIndexReducesLatency` with a docstring clarifying the pool is a shim and the test measures warm-index latency via the incremental index. `ViewIndexHttpTest` 7/7 green after rename.
- **[LOW] Story 12.5 review** `Pipe.IsProcessDead` tasklist probe leaks temp file on probe-time exception -- [full entry](#deferred-from-code-review-of-12-5-incremental-view-indexing-caching-and-sandbox-safety-2026-04-17) -- **KEPT DEFERRED (2026-04-18, Story 13.0): IRIS startup scrub reclaims the temp files; no correctness impact. Revisit if a long-running IRIS instance reports `pprobe*` file accumulation in the temp dir (trigger: temp-dir free-space alert in operations).**
- **[LOW] Story 12.5 review** `Pipe.SandboxFlags` `|`-delimiter fragile if future flag values contain `|` -- [full entry](#deferred-from-code-review-of-12-5-incremental-view-indexing-caching-and-sandbox-safety-2026-04-17) -- **KEPT DEFERRED (2026-04-18, Story 13.0): speculative; no current flag contains `|`. Revisit the moment any sandbox flag is added whose value plausibly includes `|` (e.g. a regex allowlist) — swap to `$ListBuild` encoding at that point.**
- **[LOW] Story 13.1 review** `_show` / `_list` / `_update` / `_rewrite` render endpoints matrix-listed as `501 in default config` but actually return `404` (no dispatcher registered) -- [full entry](#deferred-from-code-review-of-13-1-getting-started-guide-and-compatibility-matrix-2026-04-18) -- **NEW DEFERRAL (2026-04-18, Story 13.1 review):** fix-forward via route registration + canonical 501 envelope in the next backend-cleanup story. No known client depends on 404-vs-501 distinction for these endpoints today.
- **[LOW] Story 13.1 review** `/_scheduler/*` and `/_node/{name}/*` families collapsed to one matrix row each rather than one row per individual endpoint from vendored CouchDB docs -- [full entry](#deferred-from-code-review-of-13-1-getting-started-guide-and-compatibility-matrix-2026-04-18) -- **NEW DEFERRAL (2026-04-18, Story 13.1 review):** deliberate readability choice; all endpoints in each family carry the same `out of scope with reason` rationale. Expand only if an adopter-filed issue cites one of the collapsed endpoints by name.

---

## Deferred for Story 12.4 resumption (added 2026-04-18, Story 13.0)

> **Purpose.** Story 12.4 (Python JSRuntime backend) was deferred on
> 2026-04-17 because the dev host lacked embedded Python (see the
> top-of-list MED entry "Story 12.4 Python JSRuntime backend deferred").
> The Epic 12 retrospective named four action items (#5, #7, #8, #9) as
> prerequisites for any 12.4 resumption; they are consolidated here under
> a single trigger so none can be forgotten when 12.4 is picked back up.
> Cross-references: Epic 12 retrospective
> `_bmad-output/implementation-artifacts/epic-12-retro-2026-04-17.md`,
> Story 13.0 triage table.

- **[12.4-RESUME] AI #5 + #9 — Python-less IRIS CI image + `zpm install iris-couch` release-gate job.** When Story 12.4 resumes (or when Epic 14 DevOps infra is planned, whichever is first), stand up a CI job that runs `zpm install iris-couch` on a Python-less IRIS image (candidates: Alpine IRIS Community 2024.1+, or an InterSystems official image with Python disabled via CPF). The job must pass on every release candidate. Verified by PRD NFR-M9 (Python-Optional Compilation). Owner: TBD — Story 12.4 re-creation should name the CI image pick as a Task 0 pre-flight. Merges the two separate retro action items because they share the same CI infra and cannot be delivered independently.

- **[12.4-RESUME] AI #7 — Python bridge (`jsruntime.py`) ships as a ZPM `<FileCopy>` resource, never embedded in a `.cls`.** When Story 12.4 lands `jsruntime.py` (or any similar Python bridge), the file must be a standalone `.py` under the ZPM module tree, declared in `module.xml` as a `<FileCopy>` resource copied to a known install location at package install time. The ObjectScript side must call the bridge via `$ZF(-100)` against the installed path or via `%SYS.Python.Import` against the module, **not** via `[Language = python]` in a shipped class. Enforced by PRD NFR-M9 + `.claude/rules/iris-objectscript-basics.md::Python Integration Distribution Rules`. Pre-first-commit check on Story 12.4.

- **[12.4-RESUME] AI #8 — Verify ZPM `<FileCopy>` syntax (`Target=` vs `Dir=`) against current ZPM docs.** Charlie's caveat (Epic 12 retrospective): ZPM resource attribute names (`Target`, `Dir`, path semantics) have drifted across ZPM versions. Story 12.4's Task 0 must include a live `<FileCopy>` probe on the current ZPM version installed on the dev host before any code is written — pasting the working `module.xml` snippet into the story Dev Notes as the ground-truth attribute form. Do not trust older stories or Perplexity summaries; run the probe.

---

## Deferred from: code review of 1-1-configuration-system-and-package-scaffold (2026-04-12)

- **Config.Get() silently returns "" for invalid/misspelled keys** [Config.cls:36] -- $Parameter() returns empty string for non-existent parameter names. No error signaling for typos like Get("JSRUNTIM"). Consider adding key validation when the API layer is built.
- **Config.GetAll() numeric parameters serialize as strings in JSON** [Config.cls:73-78] -- $Parameter() always returns strings. Values like JSRUNTIMETIMEOUT=5000 and METRICSENABLED=1 will serialize as "5000" and "1" in JSON rather than numeric 5000 and 1. Will matter when config is returned via HTTP API. Address during Story 1.2 or when API endpoints consume config values.
- **Config.Set() accepts arbitrary key names without validation** [Config.cls:57] -- No check that pKey matches a known class parameter. Allows setting phantom keys in the global. Low risk currently but could cause confusion. Consider validating against known parameter list.
- **Request.ReadBody() has no size limit on body read** [Request.cls:17] -- %request.Content.Read() has no explicit size limit. Very large request bodies could consume excessive memory. Address as part of NFR/security hardening work.
- ~~**Config.GetAll() requires manual update when parameters are added** [Config.cls:72-79] -- Each new parameter must be manually added to GetAll(). Consider using ObjectScript introspection to dynamically enumerate class parameters if the parameter count grows significantly.~~ -- **CLOSED: cosmetic, no functional impact**

## Deferred from: code review of 1-4-error-envelope-and-consistent-error-responses (2026-04-12)

- ~~**ServerHandler catch blocks use Render() instead of RenderInternal()** [ServerHandler.cls:23,50]~~ -- **RESOLVED prior to Story 9.0**: Both catch blocks now use `RenderInternal()` with subsystem-specific reasons. Verified in cleanup pass.
- ~~**ServerHandler catch block reasons do not name the subsystem** [ServerHandler.cls:23,50]~~ -- **RESOLVED prior to Story 9.0**: HandleWelcome uses "server: welcome endpoint error", HandleUUIDs uses "server: uuid generation error". Verified in cleanup pass.
- ~~**TestRenderEnvelopeFormat does not test Error.Render() method** [ErrorEnvelopeTest.cls:40-54] -- Test constructs %DynamicObject manually to verify JSON structure but never calls Error.Render(). Requires HTTP response mock or integration test harness to properly test.~~ -- **CLOSED: test-only, no production impact**
- ~~**TestRenderInternalHidesTrace does not test RenderInternal() method** [ErrorEnvelopeTest.cls:57-81] -- Test verifies hardcoded string "Internal Server Error" doesn't contain stack trace info but never calls RenderInternal(). Requires HTTP response mock to properly test.~~ -- **CLOSED: test-only, no production impact**
- **Error.Render() has no error handling for missing %response** [Error.cls:56-61] -- If %response is not available (e.g. non-HTTP context), Render() will throw an UNDEFINED error. Pre-existing from Story 1.1.

## Deferred from: code review of 2-0-epic-1-deferred-cleanup (2026-04-12)

- ~~**Hardcoded credentials (_SYSTEM/SYS) in HttpIntegrationTest.MakeRequest** [HttpIntegrationTest.cls:35-36]~~ -- **RESOLVED in cleanup pass**: Added configurable TESTSERVER/TESTPORT/TESTUSERNAME/TESTPASSWORD parameters with `GetTest*()` accessor methods reading from `^IRISCouchTest` global overrides. MakeRequest and all test files updated to use shared accessors.
- ~~**Hardcoded server/port (localhost:52773) in HttpIntegrationTest.MakeRequest** [HttpIntegrationTest.cls:33-34]~~ -- **RESOLVED in cleanup pass**: Same fix as above; server/port now configurable via `^IRISCouchTest("Server")` and `^IRISCouchTest("Port")` globals.
- ~~**No early-return guard after MakeRequest failure in test methods** [HttpIntegrationTest.cls:69-117] -- If MakeRequest returns error status, subsequent assertions on tBody properties would cause INVALID OREF. Test framework catches this as test error, but diagnostic info is lost. Consider adding guard pattern when test count grows.~~ -- **CLOSED: test-only, no production impact**

## Deferred from: code review of 1-2-http-router-and-couchdb-welcome-endpoint (2026-04-12)

- **Missing metrics dispatch wrapper structure in Router** [Router.cls] -- Story 1.2 dev notes specify adding metrics wrapping structure (OnPreDispatch or dispatch wrapper) with a no-op stub. This was not implemented because IRISCouch.Metrics classes do not exist yet. Add the metrics dispatch wrapper when Story 9.1 (Prometheus/OTEL Metrics Endpoint) is implemented.

## Deferred from: code review of 2-1-create-and-delete-databases (2026-04-12)

- ~~**Race condition between Exists() and Create() in HandleCreate** [DatabaseHandler.cls:25-28] -- Between the Exists() check in HandleCreate and the Create() call, another concurrent request could create the same database. Create() does its own internal Exists() check, but if that second check fails, it returns an error status which triggers a 500 RenderInternal instead of the expected 412. Extremely unlikely in practice; address if concurrency requirements increase.~~ -- **CLOSED: by design -- single-process architecture constraint, documented**
- **No maximum database name length validation** [Storage/Database.cls:88-136] -- CouchDB enforces a maximum database name length. Not specified in story AC but could cause issues with very long names hitting global subscript limits. Address when hardening database lifecycle operations.

## Deferred from: code review of 3-1-single-document-create-and-read (2026-04-12)

- **RevTree.AddChild does not verify parent revision exists in leaf index** [RevTree.cls:55] -- If pParentRev is not in the leaf index, $Get returns "" coercing to 0, resulting in incorrect depth calculation. Not reachable in Story 3.1 (create-only uses Init), but should be validated when update path (Story 3.2) is implemented.
- **No underscore-prefix validation on document IDs in HandlePut** [DocumentHandler.cls:74] -- CouchDB reserves document IDs starting with underscore for system documents (_design/, _local/). No validation prevents clients from creating documents with reserved ID prefixes. Address when system document handling is implemented (Epic 5+).

## Deferred from: code review of 3-2-document-update-delete-and-optimistic-concurrency (2026-04-12)

- ~~**doc_count can go negative on double-delete via engine API** [DocumentEngine.cls:SaveDeleted] -- If SaveDeleted is called on a document that has already been deleted (e.g., via direct engine call bypassing handler), doc_count is decremented again, potentially going negative. The handler layer prevents this via exists + rev match checks, but the engine has no internal guard. Low risk since the API layer blocks this path. Address if engine methods are exposed to other callers.~~ -- **CLOSED: by design -- single-process architecture constraint, documented**

## Deferred from: code review of 3-3-revision-tree-and-conflict-management (2026-04-12)

- ~~**No unit test for `deleted` or `missing` status in GetRevsInfo** [RevTreeTest.cls] -- TestGetRevsInfo only covers the `available` status path. The `deleted` and `missing` status branches in GetRevsInfo are not exercised by unit tests. Add test cases that create a deleted revision and a pruned/missing revision to verify all three status paths. Not a code bug, but incomplete test coverage.~~ -- **CLOSED: test-only, no production impact**

## Deferred from: code review of 3-4-bulk-document-operations (2026-04-12)

- **HandleBulkGet silently skips docs with empty id** [DocumentHandler.cls:596] -- When a `_bulk_get` request contains a doc entry with no `id` field or an empty `id`, the code silently skips it with `Continue`. The response array will have fewer entries than the request array. Not in AC and CouchDB behavior for this edge case is unspecified. Consider returning an error entry for malformed doc requests.
- ~~**Repetitive error-entry construction in HandleBulkDocs** [DocumentHandler.cls:433-530]~~ -- **RESOLVED in cleanup pass**: Extracted `BuildErrorEntry(pDocId, pError, pReason)` helper method in BulkHandler.cls. All error-entry construction now delegates to it.

## Deferred from: code review of 3-5-replication-format-bulk-writes (2026-04-12)

- ~~**Race condition on doc_count for concurrent SaveWithHistory calls** [DocumentEngine.cls:212] -- `$Data(^IRISCouch.Tree(pDB, pDocId))` check for genuinely new documents is performed before TSTART. If two concurrent SaveWithHistory calls arrive for the same new docId, both could see tIsNewDoc=1 and both increment doc_count. Low risk in current single-process architecture but should be addressed if concurrent replication support is added.~~ -- **CLOSED: by design -- single-process architecture constraint, documented**

## Deferred from: code review of 3-6-all-documents-view (2026-04-12)

- **_local_seq field omitted when no changes entry found for document** [DocumentHandler.cls:370] -- When `local_seq=true` is requested on GET /{db}/{docid}, if no matching entry is found in ^IRISCouch.Changes, the _local_seq field is simply not included in the response. CouchDB always returns _local_seq when the parameter is specified. Acceptable for alpha; address when changes feed coverage is hardened.

## Deferred from: Epic 3 retrospective — Storage Encapsulation Violations (2026-04-13)

- ~~**HandleGet local_seq scans ^IRISCouch.Changes directly** [DocumentHandler.cls:362-364]~~ -- **RESOLVED prior to Story 9.0**: HandleGet uses `Storage.Changes.GetDocSeq(pDB, pDocId)` (line 664). Verified in cleanup pass.
- **HandleAllDocs iterates ^IRISCouch.Docs directly (9 lines)** [DocumentHandler.cls:798-876] -- HandleAllDocs and its key-range/pagination logic directly iterates `^IRISCouch.Docs(pDB)` via `$Order` and `$Data`. Should be encapsulated in a `Storage.Document.ListDocIds(pDB, pStartKey, pEndKey, pDirection)` iterator method or similar. Fix in Story 4.0 when DocumentHandler is split.
- ~~**DocumentEngine.SaveDeleted sets ^IRISCouch.Tree D-marker directly** [DocumentEngine.cls:129]~~ -- **RESOLVED prior to Story 9.0**: SaveDeleted uses `RevTree.MarkDeleted(pDB, pDocId, tNewRev)` (line 397). Verified in cleanup pass.
- ~~**DocumentEngine.SaveWithHistory checks ^IRISCouch.Tree for idempotency** [DocumentEngine.cls:192]~~ -- **RESOLVED prior to Story 9.0**: SaveWithHistory uses `RevTree.RevExists(pDB, pDocId, pRev)` (line 495). Verified in cleanup pass.
- ~~**DocumentEngine.SaveWithHistory checks ^IRISCouch.Tree for new-doc detection** [DocumentEngine.cls:212]~~ -- **RESOLVED prior to Story 9.0**: SaveWithHistory uses `RevTree.TreeExists(pDB, pDocId)` (line 515). Verified in cleanup pass.

## Deferred from: code review of 4-0-epic-3-deferred-cleanup (2026-04-12)

- ~~**RevTree.GetRevsInfo accesses ^IRISCouch.Docs directly** [RevTree.cls:227]~~ -- **RESOLVED prior to Story 9.0**: GetRevsInfo uses `Storage.Document.RevisionExists(pDB, pDocId, tRev)` (line 227). Verified in cleanup pass.
- ~~**DocumentEngine direct global access to ^IRISCouch.Changes/Seq/DB** [DocumentEngine.cls:65-72,143-150,234-241]~~ -- **RESOLVED prior to Story 9.0**: All three methods use `Storage.Changes.RecordChange()`, `Storage.Database.IncrementDocCount()`, `Storage.Database.SetUpdateSeq()`, etc. Verified in cleanup pass.
- ~~**Inner try/catch Quit in HandleBulkDocs new_edits path** [BulkHandler.cls:36]~~ -- **RESOLVED prior to Story 9.0**: HandleBulkDocs inner catch already uses `Return $$$OK` (line 37). Verified in cleanup pass.

## Deferred from: code review of 4-1-normal-changes-feed (2026-04-12)

- ~~**No test for unsupported feed mode 400 response** [ChangesHandler.cls:87-90] -- The handler returns 400 for feed modes other than "normal" (e.g., longpoll, continuous), but no unit or HTTP test exercises this path. Minor coverage gap; add when Story 4.2 (longpoll) is implemented.~~ -- **CLOSED: test-only, no production impact**

## Deferred from: code review of 4-2-longpoll-changes-feed (2026-04-12)

- ~~**Event resource name pattern duplicated in 4 locations** [DocumentEngine.cls:78,162,259 + ChangesHandler.cls:114] -- The event name string `"^IRISCouch.LPChanges(""" _ pDB _ """)"` is constructed identically in DocumentEngine.Save, SaveDeleted, SaveWithHistory, and ChangesHandler.HandleChanges. Should be extracted to a shared helper method or constant for maintainability. Code quality improvement, not a bug.~~ -- **CLOSED: cosmetic, no functional impact**

## Deferred from: code review of 4-3-built-in-changes-filters (2026-04-12)

- ~~**Storage encapsulation: test files directly Kill ^IRISCouch.* globals** [ChangesFilterTest.cls:19-24, ChangesFilterHttpTest.cls:19-24] -- OnBeforeOneTest/OnAfterOneTest directly Kill ^IRISCouch.DB, ^IRISCouch.Docs, etc. instead of going through Storage.* classes. Pre-existing pattern used across all 24+ test files. Should be addressed project-wide when test infrastructure is refactored.~~ -- **CLOSED: test-only, no production impact**
- ~~**Missing test: _selector filter with deleted documents** [ChangesFilterTest.cls] -- No unit test exercises the _selector filter's behavior with deleted documents (which should be skipped per the implementation). The handler code correctly skips them, but no test validates this edge case. Add when delete+filter interaction is explicitly specified or during test coverage expansion.~~ -- **CLOSED: test-only, no production impact**

## Deferred from: code review of 5-0-epic-4-deferred-cleanup (2026-04-12)

- ~~**DocumentExists naming inconsistent with sibling Exists method** [Storage/Document.cls:69]~~ -- **RESOLVED prior to Story 9.0**: Method renamed to `RevisionExists(pDB, pDocId, pRev)`. All callers updated. Verified in cleanup pass.
- ~~**Unused local variables in IncrementDocCount/IncrementDelCount** [Storage/Database.cls:175,183] -- `$Increment` results are assigned to `tCount`/`tDelCount` but never returned or used. Harmless (ObjectScript requires assignment for `$Increment` side effect) but cosmetic noise.~~ -- **CLOSED: cosmetic, no functional impact**
- ~~**RecordChange lacks documentation about transaction requirement** [Storage/Changes.cls:150]~~ -- **RESOLVED in cleanup pass**: Added doc comment noting TSTART/TCOMMIT requirement for callers.
- ~~**Test file directly kills ^IRISCouch.* globals** [StorageCleanupTest.cls:22-26,34-38] -- Continues pre-existing pattern across 24+ test files. Should be addressed project-wide when test infrastructure is refactored (same as existing deferred item from 4-3 review).~~ -- **CLOSED: test-only, no production impact**

## Deferred from: code review of 5-1-standalone-attachment-upload-and-download (2026-04-12)

- ~~**Duplicated HTTP helper in AttachmentHttpTest.MakeBinaryRequest** [AttachmentHttpTest.cls:70-107]~~ -- **RESOLVED in cleanup pass**: All hardcoded credentials and connection params replaced with `HttpIntegrationTest.GetTest*()` shared accessors. MakeRequest already supports custom content type via pContentType parameter.
- **FindRevWithAttachment lexicographic sort at generation 10+** [Storage/Attachment.cls:204-216] -- $Order sorts revision strings lexicographically ("10-x" before "2-x"), so at gen 10+ the "latest" found may not be the highest generation. Not reachable through HTTP handler (which resolves winning rev first), but could produce incorrect results when Storage.Attachment.Get() is called directly without a rev parameter. Address when multi-generation attachment scenarios are tested.
- **Stream OID leak on attachment Delete** [Storage/Attachment.cls:127-140] -- Storage.Attachment.Delete kills the metadata and stream OID reference but does not delete the underlying %Stream.GlobalBinary object. The stream data persists orphaned in the global. Low impact since it only affects explicitly deleted attachments, and database deletion cleans up the entire global. Address during storage compaction/garbage collection implementation.

## Deferred from: code review of 5-2-inline-and-multipart-attachment-upload (2026-04-12)

- ~~**Base64 decode empty-string check is unreliable for validation** [DocumentEngine.cls:520-526]~~ -- **RESOLVED in cleanup pass**: Fixed validation to check `(tBinary = "") && (tBase64 '= "")`, allowing zero-byte attachments (empty base64 input) while rejecting non-empty base64 that decodes to empty.
- **Double base64 encode/decode in multipart/related path** [DocumentHandler.cls:143-148] -- The multipart handler reads binary data from MIME streams, base64-encodes it into a DynamicObject, then SaveWithAttachments base64-decodes it again. This is wasteful and risks issues with binary data exceeding ObjectScript string limits (~3.6MB). Consider adding a stream-based path to SaveWithAttachments that accepts pre-decoded streams for multipart use. Address when large attachment support is needed.
- ~~**TestInvalidBase64 always passes regardless of outcome** [InlineAttachmentTest.cls:156] -- Uses `$$$AssertTrue(1, ...)` which is unconditionally true. Does not verify whether SaveWithAttachments actually rejected or accepted the invalid base64 data. Strengthen assertion when base64 validation logic is improved.~~ -- **CLOSED: test-only, no production impact**

## Deferred from: code review of 5-3-attachment-retrieval-options-and-multipart-response (2026-04-12)

- **Attachment buffering in base64 paths reads entire stream into memory** [DocumentHandler.cls:591,623] -- `?attachments=true` and `?atts_since` paths use `tStream.Read()` which loads the full attachment into an ObjectScript string variable (~3.6MB limit). This is a known CouchDB design limitation: base64-in-JSON inherently requires full content in memory. The multipart path correctly streams in 32KB chunks. Document as a size limitation; CouchDB recommends standalone GET for large attachments.
- ~~**Multipart boundary may contain MIME-special characters** [DocumentHandler.cls:442-444]~~ -- **RESOLVED in cleanup pass**: Changed from `Base64Encode` to hex encoding via `%xsd.hexBinary.LogicalToXSD()`, producing only safe alphanumeric characters in the boundary string.
- ~~**Invalid atts_since JSON silently falls back to stubs** [DocumentHandler.cls:601-606]~~ -- **RESOLVED prior to Story 9.0**: The catch block now returns HTTP 400 with "invalid JSON in atts_since parameter" (line 616-617). Verified in cleanup pass.
- **No attachments=true support for open_revs JSON response path** [DocumentHandler.cls:516-545] -- The open_revs JSON array path always returns attachment stubs. CouchDB supports combining `?attachments=true` with `?open_revs` to include base64 data in the array response. Not in story AC. Address if client compatibility requires it.
- ~~**No multipart test with multiple conflicting revisions** [AttachmentRetrievalHttpTest.cls] -- All multipart tests use a single-revision document. No test validates correct MIME structure when multiple leaf revisions exist with different attachments. Add during test coverage expansion or conflict-related stories.~~ -- **CLOSED: test-only, no production impact**

## Deferred from: code review of 6-0-epic-5-deferred-cleanup (2026-04-13)

- **Delete() clears shared stream OID data affecting other revisions** [Storage/Attachment.cls:131-139] -- CopyAttachments and CopyOneAttachment share stream OIDs between revisions. Delete() uses Clear()+Save() which destroys the underlying stream data for ALL revisions referencing the same OID. Not triggered by current production code paths (DeleteAttachment uses CopyAttachments with exclusion, not Delete()), but would corrupt data if Delete() is called on a revision whose stream OID is shared. Pre-existing architectural tension. Address when storage compaction or direct attachment deletion by revision is implemented.
- **Stub delimiter "||" in SaveWithAttachments may collide with attachment names** [DocumentEngine.cls:552] -- Attachment names are concatenated with "||" as delimiter, then split with $Piece. If an attachment name contains "||", parsing fails. Extremely unlikely in practice. Consider using $ListBuild for the stub name collection.
- **Delete Clear+Save leaves zero-byte stream entry** [Storage/Attachment.cls:134-138] -- After Clear()+Save(), the stream OID still exists as a zero-byte entry in stream storage. Not a data leak but leaves orphaned zero-byte entries. Address during storage compaction implementation.

## Deferred from: code review of 6-1-mango-index-management (2026-04-13)

- **GetJsonType treats string values "true"/"false" as boolean type without type hint** [Projection/MangoIndex.cls:219] -- The heuristic fallback path (no type hint) still cannot distinguish ObjectScript string "true" from a JSON boolean true. The primary extraction path now uses %GetTypeOf() hints which handles this correctly. The fallback path is only used by direct callers of GetJsonType without hints. Address if external callers require accurate boolean detection.
- ~~**MatchesPartialFilter only handles top-level equality selectors** [Projection/MangoIndex.cls:244-265]~~ -- **RESOLVED in Story 7.0**: Refactored to delegate to MangoSelector.Normalize()+Match() for full operator support.
- ~~**FindByDefinition-to-Create race condition under concurrency** [API/MangoHandler.cls:131-140] -- Between FindByDefinition returning false and MangoIndexDef.Create(), a concurrent request could create the same index, causing a unique constraint violation surfaced as 500 instead of "exists". Extremely unlikely in current single-process architecture. Address if concurrent index creation support is required.~~ -- **CLOSED: by design -- single-process architecture constraint, documented**
- **ExtractFieldValue cannot distinguish missing field from field with empty string value** [Projection/MangoIndex.cls:172-202] -- Both cases return "". The new pJsonType output parameter returns "null" for both. Not a practical issue for index population since empty string and missing field both result in "null" type index rows. Address if Mango query semantics require distinguishing $exists from empty value.

## Deferred from: code review of 6-2-mango-query-execution-selectors-and-query-plan (2026-04-13)

- ~~**Missing cross-type comparison unit tests** [MangoSelectorTest.cls]~~ -- **RESOLVED in Story 7.0**: Added TestCompareNullLtNumber and TestCompareBoolLtString tests. Also fixed TypeRank empty-string fallback to return null rank (0) instead of string rank (4).

## Deferred from: code review of 7-0-epic-6-deferred-cleanup (2026-04-13)

- **TypeRank vs InferType inconsistency on empty string** [MangoSelector.cls:820,914] -- `TypeRank("")` returns 0 (null) after the Story 7.0 fix, but `InferType("")` still returns "string" (line 914). When both are used on the same empty-string value, they disagree on the type. Currently safe because InferType is only called when field is found (tFound=true), while the empty-string-as-null path in TypeRank is for CompareValues direct calls. Pre-existing architectural inconsistency, not triggered by current code paths. Address if type detection is unified across the two methods.

## Deferred from: code review of 7-1-session-authentication-and-basic-auth (2026-04-13)

- **Username containing colons breaks cookie parsing** [Auth/Session.cls:59-61] -- Cookie format `username:hexTimestamp:hmacHex` uses `$Piece(tDecoded, ":", 1)` for username extraction. If a username contains a colon, parsing fails. Matches CouchDB's own colon-delimited format and IRIS usernames do not conventionally contain colons. Address if custom IRIS usernames with colons are supported.
- ~~**GetSecret() race condition under concurrent requests** [Auth/Session.cls:96-101] -- Two concurrent requests seeing empty AUTHSECRET could both generate different secrets; the second Config.Set overwrites the first. Cookies signed with the first secret immediately become invalid. Same single-process architecture constraint documented in multiple previous deferred items (e.g., doc_count race, FindByDefinition race). Address if concurrent process support is required.~~ -- **CLOSED: by design -- single-process architecture constraint, documented**

## Deferred from: code review of 7-2-jwt-and-proxy-authentication (2026-04-13)

- **JWT exp check has no clock skew tolerance** [Auth/JWT.cls:61] -- The expiration check `If tExp '> tNow Quit` is exact with zero tolerance for clock drift between the JWT issuer and the IRISCouch server. Industry standard is 30-60 seconds of leeway. CouchDB itself does not implement clock skew tolerance for JWT exp, so current behavior is CouchDB-compatible. Address if integration with external IdPs experiences clock-drift rejections.
- ~~**Proxy auth unit tests test HMAC computation but not Authenticate() directly** [Test/JWTTest.cls:183-196] -- TestProxyAuthValid verifies HMAC-SHA1 computation and IsEnabled() but cannot call Proxy.Authenticate() because it requires a live %request object. The HTTP integration test (JWTHttpTest.TestProxyAuthSuccess) covers the full Authenticate() flow. Consider adding a mock %request pattern if unit-level coverage of Authenticate() is needed.~~ -- **CLOSED: test-only, no production impact**
- ~~**Hardcoded test credentials and connection params in JWTHttpTest** [Test/JWTHttpTest.cls:138-140,149-153]~~ -- **RESOLVED in cleanup pass**: All hardcoded values replaced with `HttpIntegrationTest.GetTest*()` shared accessors.

## Deferred from: code review of 7-5-auth-hotfix-credential-validation-and-role-assignment (2026-04-13)

- ~~**CleanupTestUser swallows all exceptions silently** [Test/AuthHttpTest.cls:260] -- The catch block in CleanupTestUser discards all errors without logging. If cleanup fails (e.g., namespace switch error, user deletion failure), the test suite proceeds with stale state that could cause cascading test failures. Pre-existing test helper pattern used across multiple test files. Address when test infrastructure error handling is standardized.~~ -- **CLOSED: test-only, no production impact**

## Deferred from: code review of 7-3-user-management-via-users-database (2026-04-13)

- **SaveWithHistory does not call _users hooks** [DocumentEngine.cls:424-516] -- If a _users document is replicated in via SaveWithHistory (new_edits=false), no password hashing or IRIS user sync occurs. This could allow importing user docs without creating corresponding IRIS users. Not triggered in current architecture since replication protocol (Epic 8) is not yet implemented. Address when Story 8.4 (bidirectional replication) is implemented.
- **SaveWithAttachments does not call _users hooks** [DocumentEngine.cls:538-685] -- If a _users document is saved via SaveWithAttachments, no user sync occurs. Extremely unlikely since _users documents do not normally have attachments. Address if attachment support on _users documents is required.
- **Falsy password values not guarded** [Auth/Users.cls:77] -- `pBody.%Get("password")` returns "" for null, but numeric 0 or boolean false would pass the `'= ""` check and be used as a password string. CouchDB clients always send password as a string, so this is not practically triggered. Address if input validation hardening is required.
- ~~**Hardcoded test credentials and connection params in UsersHttpTest** [Test/UsersHttpTest.cls:184-189]~~ -- **RESOLVED in cleanup pass**: All hardcoded values replaced with `HttpIntegrationTest.GetTest*()` shared accessors.

## Deferred from: code review of 8-1-local-documents-and-replication-checkpoints (2026-04-13)

- **RenderInternal called without exception arg for Storage write failures** [ReplicationHandler.cls:119,190] -- When Storage.Local.Write() or Delete() returns an error status inside the Try block, RenderInternal is called without an exception object, so no detailed error info is logged to IRIS console. The status error details are lost. Address when a utility method for logging %Status errors (not just exceptions) is added.
- **No error handling in Storage.Local.Read()/GetRev() for corrupted $ListBuild data** [Local.cls:43-45,56-58] -- If the global value is corrupted and not a valid $ListBuild structure, $ListGet would throw an exception that propagates to the handler's Catch block. Not practically triggered unless global data is manually modified. Address during storage hardening or data integrity work.
- ~~**TOCTOU race between Exists() and Read()/GetRev() in HandleLocalGet** [ReplicationHandler.cls:29-35] -- If another process deletes the local document between the Exists() check and the Read()/GetRev() calls, Read() returns "" and %FromJSON("") throws an exception caught by the outer Catch block (returns 500 instead of 404). Low probability in single-process IRIS configurations. Address when concurrent access patterns are implemented.~~ -- **CLOSED: by design -- single-process architecture constraint, documented**

## Deferred from: code review of 8-2-revision-difference-calculation (2026-04-13)

- **possible_ancestors returns all leaf revisions without generation filtering** [ReplicationHandler.cls:190-193] -- CouchDB filters possible_ancestors to only include leaf revisions whose generation number is strictly less than the maximum missing revision's generation (couch_db.erl:2159-2170). IRISCouch returns all leaf revisions from GetLeafRevs without this filtering. This provides more data than strictly necessary to replication clients but does not break correctness since clients treat possible_ancestors as hints. The story spec explicitly defines the algorithm without generation filtering. Address when replication performance optimization is prioritized or if a client is observed to malfunction with the broader set.

## Deferred from: code review of 8-3-replication-ready-bulk-get (2026-04-13)

- ~~**Inner parse catch Quit falls through to UNDEFINED in HandleBulkGet** [BulkHandler.cls:268-273]~~ -- **RESOLVED in cleanup pass**: Changed inner catch `Quit` to `Return $$$OK` to correctly exit the method after rendering the 400 error response.
- **Partial attachment Get() failure produces mixed stubs+inline response** [BulkHandler.cls:344-360] -- If `Storage.Attachment.Get()` fails for one attachment while others succeed, the failed attachment remains as its original stub entry while others are replaced with inline data. The response contains a mix of stubs and inline data for the same document. CouchDB does not define behavior for this edge case. Address if attachment retrieval reliability issues surface.

## Deferred from: code review of 8-4-bidirectional-replication-protocol (2026-04-13)

- **ReplicateLocal (push) path lacks NFR-R1 corruption detection** [Replicator.cls:404-439] -- The push path builds _bulk_docs payload for the remote CouchDB target but does not perform local corruption detection after the remote write. Remote CouchDB handles its own integrity checks. Address if bidirectional push integrity verification is needed.
- **ReplicateLocal (push) path does not include inline attachment data in _bulk_docs** [Replicator.cls:404-439] -- Push replication does not encode local attachment data as base64 inline entries in the _bulk_docs payload. Requires base64 inline attachment encoding not yet implemented. Address when push replication with attachments is a priority.
- **HttpClient SSLConfiguration hardcoded to "ISC.FeatureTracker.SSL.Config"** [HttpClient.cls:131] -- HTTPS requests use a hardcoded SSL config name. If this config does not exist on the IRIS instance, HTTPS connections will fail. Make configurable via an SSLConfiguration property when production SSL requirements are defined.
- **HttpClient.Request reads entire response body into string** [HttpClient.cls:171] -- `tReq.HttpResponse.Data.Read()` reads the full response into a string variable. For very large bulk_get responses this could exceed IRIS string limits. Implement streaming response handling for large replications.
- **Checkpoint BuildCheckpointDoc types source_last_seq as "number"** [Checkpoint.cls:183] -- Always forces source_last_seq to number type. CouchDB 2.x+ uses opaque string sequences (e.g., "57-g1AAAA..."). IRISCouch uses integer sequences locally so this is correct for local-to-local. Address when testing remote CouchDB 2.x+ interoperability.
- **No checkpoint written when source has zero changes and no prior checkpoint** [Replicator.cls:131-134] -- When source has no changes and no prior checkpoint exists, the method returns without writing a checkpoint. This is benign since the next replication will also start from 0. CouchDB protocol technically writes a checkpoint even with zero changes. Address if checkpoint consistency verification is implemented.

## Deferred from: code review of 8-5-replicator-database-and-continuous-replication-jobs (2026-04-13)

- **Missing MangoIndex re-indexing in _replicator Save hook** [DocumentEngine.cls:105-126] -- The _replicator hook in Save() updates Winners projection after body modification but does not re-index MangoIndex, unlike the _users hook pattern (lines 96-102). Inconsistent but low impact since Mango indexes on _replicator are unlikely. Address if Mango query support on _replicator documents is needed.
- **ReplicateLocal and ReplicateRemote do not populate pStats Output** [Replicator.cls:380,503] -- Push and pull replication paths do not pass through the Output pStats parameter. Callers receive zeros (initialized by Replicate() at lines 52-57) rather than actual stats. Address when push/pull replication stats are needed for _replicator document updates.
- **One-shot replication error does not retry** [Manager.cls:264-267] -- One-shot errors immediately set state to "error" and exit without retry. Story AC#5 mentions "the job retries with exponential backoff" but CouchDB behavior is that only continuous mode retries. Current behavior matches CouchDB semantics. Address if one-shot retry is explicitly required.

## Deferred from: code review of 9-0-epic-8-deferred-cleanup (2026-04-13)

- ~~**$Horolog returns local time but timestamps append "Z" (UTC) suffix** [Storage/Database.cls:27, Replication/Manager.cls:70,170]~~ -- **RESOLVED in Story 10.0**: All three locations changed from `$Horolog` to `$ZTimeStamp` (UTC). Updated "Timestamp and Encoding Standards" rule to document `$ZTimeStamp` as the correct choice. All tests pass.

## Deferred from: code review of 9-1-prometheus-opentelemetry-metrics-endpoint (2026-04-13)

- **BuildOutput string concatenation may exceed ObjectScript ~3.6MB string limit** [Endpoint.cls:40-49] -- All Prometheus metric output is concatenated into a single ObjectScript string variable `tOut` via `BuildOutput()`. If many endpoint/method/status combinations accumulate over time, this could approach the ~3.6MB ObjectScript string limit. Pre-existing architectural pattern (string concatenation for HTTP responses). Address when metrics cardinality grows or when a streaming response pattern is adopted for large outputs.

## Deferred from: code review of 9-2-audit-event-emission (2026-04-13)

- ~~**TestEnsureEvents namespace switch has no Try/Catch** [AuditTest.cls:119-129] -- The test switches to %SYS to verify Security.Events registration but does not wrap assertions in Try/Catch. If any assertion fails, the namespace stays as %SYS for remaining tests, potentially corrupting test isolation. Pre-existing test pattern across multiple test files. Address when test infrastructure error handling is standardized.~~ -- **CLOSED: test-only, no production impact**
- ~~**Hardcoded credentials (_SYSTEM/SYS) in AuditHttpTest** [AuditHttpTest.cls:93-94]~~ -- **RESOLVED in cleanup pass**: All hardcoded values replaced with `HttpIntegrationTest.GetTest*()` shared accessors.

## Deferred from: code review of 9-3-operational-resilience-and-data-durability (2026-04-13)

- **Log.Debug() has no gating for debug-level logging** [Util/Log.cls:54-57] -- The doc comment says "Only emitted when IRIS debug logging is enabled" but the implementation always calls Emit unconditionally. IRIS does not have a built-in debug flag that can be checked via ObjectScript. Consider adding a Config parameter (e.g., LOGLEVEL) to control minimum log level, or checking a global flag before emitting debug messages. Low impact since Debug() is not currently called from any production code path.

## Deferred from: code review of 10-0-epic-9-deferred-cleanup (2026-04-14)

- **JWT.UnixTimestamp() uses $Horolog (local time) but doc claims UTC** [Auth/JWT.cls:158] -- `UnixTimestamp()` computes Unix epoch from `$Horolog` which returns local server time, but the doc comment says "seconds since 1970-01-01 00:00:00 UTC". On non-UTC servers, JWT `iat`/`exp` claims will be offset by the server's timezone delta. Pre-existing issue not introduced by Story 10.0 (which fixed the ISO-8601 `$Horolog`+Z pattern in different files). Should use `$ZTimeStamp` for the day and seconds components, or document the local-time assumption. Low impact when server runs in UTC.

---

## Epic 10 Triage (2026-04-14)

**Reviewed by:** Story 10.0 (Epic 9 Deferred Cleanup)

All 43 remaining open deferred work items were reviewed for Epic 10 (Admin UI - Angular frontend) relevance. Every item is an ObjectScript backend concern (storage encapsulation, string limits, stream OID leaks, race conditions, attachment edge cases, replication stats, cookie parsing, JWT clock skew, etc.). **None reference Angular, TypeScript, or frontend code. None block Epic 10 work.** The Angular frontend consumes the IRISCouch REST API and does not depend on any of these backend internals being resolved first.

## Deferred from: code review of 10-1-angular-scaffold-design-tokens-and-icon-system (2026-04-14)

- **No ChangeDetectionStrategy.OnPush on icon components** [ui/src/app/couch-ui/icons/*.ts] -- All 20 icon components and AppComponent use the default change detection strategy. For components with no dynamic content beyond a single `size` input, OnPush would be a minor performance optimization. LOW -- address project-wide when more components exist.
- **@Input() decorator vs modern input() signal** [ui/src/app/couch-ui/icons/*.ts] -- Angular 18 introduced the `input()` signal function. The current code uses the traditional `@Input()` decorator which is fully supported and not deprecated. LOW -- stylistic preference, can be adopted project-wide when the team decides on signal adoption.
- **No JetBrains Mono weight 500 bundled** [ui/src/assets/fonts/] -- UX spec mentions weights 400 and 500, but only 400 is bundled per story decision. Browser will synthesize faux-bold for 500. LOW -- bundle 500 weight WOFF2 (~20KB more) in a later story if synthetic bold looks poor on Windows ClearType.

## Deferred from: code review of 10-2-core-ui-components (2026-04-14)

- **Badge 10px font-size vs AC #6 "no text below 12px"** [ui/src/app/couch-ui/badge/badge.component.ts:29] -- UX spec explicitly requires "10 px uppercase small-caps" for badges; AC #6 says no text below 12px. These contradict. UX spec is the design authority and takes precedence. If the minimum changes, update badge font-size accordingly.
- **Hardcoded RGBA values in badge backgrounds** [ui/src/app/couch-ui/badge/badge.component.ts:44-59] -- Background colors use raw rgba() values (e.g., rgba(60, 90, 158, 0.1)) corresponding to semantic colors at 10% alpha. No CSS token exists for alpha-modified semantic colors. LOW -- consider adding alpha-variant tokens to tokens.css if more components need this pattern.
- **CopyButton no error feedback on failed clipboard copy** [ui/src/app/couch-ui/copy-button/copy-button.component.ts:93] -- When clipboard.copy() returns false (e.g., due to browser security restrictions), no error feedback is shown. User gets no indication the copy failed. LOW -- add visual/auditory error feedback in a future pass.

## Deferred from: code review of 10-3-appshell-navigation-and-login (2026-04-14)

- **ErrorDisplay test suite has only 3 examples (401, 404, 500)** [ui/src/app/couch-ui/error-display/error-display.component.spec.ts] -- UX spec requires at least 5 examples (401, 404, 409, 500, network error). Missing 409 conflict error and network error test cases. MEDIUM -- add missing test cases in a future story or test expansion pass.
- **Password field not cleared after successful login** [ui/src/app/features/auth/login.component.ts:186-189] -- After successful login, this.password remains in component memory until Angular garbage-collects the component on navigation. Security hygiene improvement. LOW -- component is destroyed on navigation, so exposure window is minimal.
- **Button component CSS budget warning** [ui/src/app/couch-ui/button/button.component.ts] -- Production build warns button component CSS (2.28 KB) exceeds the 2.05 KB budget by 229 bytes. Pre-existing from Story 10.2. LOW -- either increase budget or reduce CSS.

## Deferred from: code review of 10-4-database-list-view-with-create-and-delete (2026-04-14)

- **No UI trigger for database delete action (AC #5)** [ui/src/app/features/databases/database-list.component.ts] -- `openDeleteDialog(db: DatabaseEntry)` method exists and works correctly, but no template element invokes it. The DataTable component is domain-free and does not support action columns with buttons. AC #5 requires "the operator clicks delete on a database" which needs either: (a) extending DataTable to support template-projected cell content for an actions column, (b) adding a separate row-action overlay/menu, or (c) adding inline delete buttons outside the DataTable. MEDIUM -- functional code exists and is tested; only the UI trigger is missing.

## Deferred from: code review of 10-5-document-list-view-with-filtering-and-pagination (2026-04-14)

- **paginationStart assumes linear page history** [ui/src/app/features/database/database-detail.component.ts] -- Range indicator math uses `pageHistory.length * PAGE_SIZE`, which is inaccurate if any page had fewer than PAGE_SIZE rows (e.g., the last page of filtered results). Cosmetic only -- affects the approximate range indicator display. LOW.
- **totalRows reflects total DB doc count, not filtered count** [ui/src/app/features/database/database-detail.component.ts] -- CouchDB `_all_docs` `total_rows` returns the total number of documents in the database regardless of filter. Range indicator shows "rows 1-3 of ~42,187" even when only 3 docs match the filter prefix. By design per CouchDB API -- no way to get filtered count without a separate query. LOW.

## Deferred from: code review of 10-6-document-detail-view (2026-04-14)

- **Design doc ID double-encoding in getDocument and getAttachmentUrl** [ui/src/app/services/document.service.ts, ui/src/app/features/document/document-detail.component.ts] -- `encodeURIComponent('_design/myview')` produces `_design%2Fmyview`, but CouchDB expects `/{db}/_design/myview` with the slash unencoded. This will cause 404s when navigating to design doc detail views. Address in Epic 11 Story 11-1 (Design Document List and Detail View) which introduces design doc-specific routing and API methods.

## Deferred from: code review of 10-7-error-handling-accessibility-and-cross-browser-verification (2026-04-14)

- **Network error message hardcoded in 3 components** [database-list.component.ts, database-detail.component.ts, document-detail.component.ts] -- The string "Cannot reach `/iris-couch/`. Check that the server is running." is duplicated across all three feature components. Extract to a shared constant or utility function for DRY compliance. LOW.
- **Error handler pattern (status=0 branch) duplicated 3x** [database-list.component.ts, database-detail.component.ts, document-detail.component.ts] -- The `if (err.status === 0) { ... } else { ... }` error classification logic is copy-pasted identically across all three components. Extract to a shared error handler utility function (e.g., `classifyHttpError(err): { error, reason, statusCode }`) for maintainability. LOW.

## Angular UI — ongoing deferrals (initialized by Story 11.0)

Story 11.0 establishes a running Angular-UI-scoped section for deferrals
that do not fit any single epic's code review (forward-looking, polish,
tooling-adjacent). Two items from the Epic 10 retrospective triage are
the initial entries.

- **Real favicon** [ui/public/favicon.ico] -- Current `data:,` stub ships
  a 1x1 transparent placeholder. Cosmetic only; no functional impact.
  Revisit near launch when brand assets are finalised. Source: Epic 10
  retrospective triage #16.
- **Angular 19+ idiom polish** [ui/src/app/couch-ui/icons/*, input()
  signal mode, weight-500 font inclusion] -- Several components still use
  classic `@Input()` decorators instead of the Angular 19 `input()` signal
  form; the icon components use default font weight where the design spec
  suggests `weight-500`. Non-functional; revisit when upgrading to
  Angular 19+. Source: Epic 10 retrospective triage #17.

## Deferred from: Story 11.0 implementation (2026-04-14)

- **stylelint is configured but not installed** [ui/.stylelintrc.json,
  ui/package.json] -- The `color-no-hex` and rgba-disallowed rules are
  defined in `.stylelintrc.json` and wired to `npm run stylelint`, but
  the `stylelint` and `stylelint-config-standard` packages are not yet
  added to `devDependencies` (this requires an `npm install` in a
  sandboxed environment). Next developer should install them and run
  the initial pass; all existing violations have already been refactored
  during Story 11.0. LOW. -- **KEPT DEFERRED (2026-04-17, Story 12.0):**
  requires an environment with network access to install npm packages;
  not a code concern. Revisit bundled with the next `npm install`-capable
  infra task.
- **UI smoke workflow requires self-hosted runner** [.github/workflows/ui-smoke.yml]
  -- The CI job is configured to run on a `[self-hosted, iris-smoke]`
  runner because the smoke script needs a live IRIS backend. Provisioning
  the runner is an infra task outside this story's scope. MEDIUM -- without
  a runner the workflow queues indefinitely. Either provision the runner,
  change to GitHub-hosted + service container, or gate the workflow behind
  a `workflow_dispatch` trigger. -- **KEPT DEFERRED (2026-04-17, Story 12.0):**
  already tagged MEDIUM; infra work that belongs with Epic 14 DevOps
  story, not Epic 12 JSRuntime work. No code change required.
- **sizes.external and sizes.active use allocated bytes (not uncompressed
  JSON)** [src/IRISCouch/Storage/Database.cls ComputeDiskSize] -- CouchDB
  spec defines `sizes.external` as the pre-compression JSON size and
  `sizes.active` as the live (non-deleted) size. IRIS does not expose a
  clean equivalent via `%Library.GlobalEdit.GetGlobalSizeBySubscript()`
  -- all three values report allocated bytes for the IRISCouch.* global
  subtrees. Sufficient for the UI's informational display and for
  spec-compliance at the JSON-shape level, but consumers that compute
  compression ratios from these fields will see a ratio of 1.0. LOW --
  revisit if a replicator or monitoring consumer surfaces the gap. --
  **KEPT DEFERRED (2026-04-17, Story 12.0):** ObjectScript backend
  concern, not UI. Story 12.0 is UI-only; revisit trigger (replicator
  or monitoring consumer surfacing the gap) still applies.

## Deferred from: Story 11.0 code review (2026-04-14)

- **Smoke.mjs path resolution on Windows (LOW).** `new URL('..', import.meta.url).pathname.replace(/^\//, '')` does not URL-decode,
  so paths with spaces become `%20` literals in the `cwd` passed to
  `spawn()`. Prefer `fileURLToPath(new URL('..', import.meta.url))` from
  `node:url`. Does not affect the CI runner path. Revisit next time the
  smoke script is touched. -- **KEPT DEFERRED (2026-04-17, Story 12.0):**
  revisit trigger already named (next time smoke.mjs is touched). No
  current consumer hit by this; CI runner path has no spaces.
- **FeatureError rawError setter clears statusCode (LOW).** When a consumer
  binds both `[statusCode]` and `[rawError]`, the `rawError` setter resets
  `statusCode` to the mapped value — binding-order dependent. Pre-existing
  in the new code but no current consumer binds both. If a future caller
  needs to override status, split into `setFromRaw(err, overrideStatus?)`.
  -- **KEPT DEFERRED (2026-04-17, Story 12.0):** no consumer binds both
  inputs today; the revisit trigger (first caller that needs explicit
  status override) is already documented. Splitting the API speculatively
  would add surface without a concrete use case.

## Deferred from: Story 11.1 development (2026-04-14)

- **RESOLVED in Story 11.3 Task 0 (2026-04-15).** Backend:
  `PUT /{db}/_design/{name}` routes to attachment handler, not DocumentPut
  (HIGH -- blocks design-doc write UX). The `Router.cls` UrlMap had
  `/:db/:docid/:attname` registered before `/:db/:docid`, so a request to
  `PUT /testdb/_design/myapp` matched the attachment route with
  `docid = "_design"` and `attname = "myapp"`.
  Fix: Story 11.3 added explicit `_design/:ddocid` PUT/GET/DELETE routes
  (Option B) ahead of the attachment route, dispatching to the existing
  `DocumentHandler.HandlePut/HandleGet/HandleDelete` with the composite ID
  reassembled. Also added `_design/:ddocid/:attname` routes so design-doc
  attachments still work. Verified via curl: `PUT /testdb11x3/_design/myapp`
  now returns `{"ok":true,"id":"_design/myapp","rev":"1-..."}` and
  `GET /testdb11x3/_design/myapp` returns the full envelope with
  `_id = "_design/myapp"`. New ObjectScript tests in
  `src/IRISCouch/Test/DocumentHttpTest.cls` cover PUT/GET/DELETE on
  composite IDs plus a `TestLocalDocStillRoutes` regression for `_local/`.
  Existing `AttachmentHttpTest`, `AttachmentRetrievalHttpTest`, and
  `InlineAttachmentHttpTest` all remain green. See `Story 11.3` for details.
- **RESOLVED in Story 11.3 Task 0 (2026-04-15).** Backend design-doc GET
  returns bare body, not a full document envelope (MED -- cosmetic for
  read-only, blocking for editing). With the routing fix above, GET
  `/db/_design/name` now returns the full `{_id, _rev, ...}` envelope
  (verified via the `TestGetDesignDoc` integration test).

## Deferred from: code review of 11-3-design-document-and-security-editing (2026-04-15)

- **TextAreaJson uses `document.getElementById` for gutter scroll sync** [ui/src/app/couch-ui/text-area-json/text-area-json.component.ts:332] -- Gutter scroll sync looks up the textarea element via `document.getElementById(this.textareaId)` instead of the already-declared `@ViewChild('textareaEl')` / `@ViewChild('gutterEl')` refs. Works reliably today but relies on the id being unique across the page and on DOM availability at event-dispatch time. LOW -- refactor to use the ViewChild references when next editing the file. -- **KEPT DEFERRED (2026-04-17, Story 12.0):** revisit when TextAreaJson grows a second consumer or the file is next touched. Single consumer today (DesignDocDetail); getElementById works reliably.
- **`TestPostDesignDocNotAllowed` accepts both 404 and 405** [src/IRISCouch/Test/DocumentHttpTest.cls:219] -- Story 11.3 Task 0 test asserts `(tStatus = 405) || (tStatus = 404)` for `POST /{db}/_design/{name}`. Backend currently returns 405 per %CSP.REST's `Http405` handler; the 404 tolerance was added defensively because the exact dispatcher behaviour for POST on a GET/PUT/DELETE-only route was not formally specced. LOW -- tighten to strict 405 once the behaviour is nailed down in a regression test for `Http405()`. -- **KEPT DEFERRED (2026-04-17, Story 12.0):** ObjectScript backend concern, not UI. Story 12.0 is UI-only; revisit as part of a future Http405 regression story.
- **`design-doc-create-dialog` `titleId` uses `Date.now()` without randomness** [ui/src/app/features/design-docs/design-doc-create-dialog.component.ts:183] -- If two instances of the dialog were ever mounted in the same millisecond the `aria-labelledby` IDs would collide. Only one create dialog can ever be open at a time, so this is functionally harmless; mentioned for consistency with other dialogs that use a monotonic counter. LOW. -- **KEPT DEFERRED (2026-04-17, Story 12.0):** guarded by "only one dialog instance ever mounted" invariant. Revisit if multiple simultaneous dialog mounts become possible.
- **Delete-dialog body uses `[innerHTML]` with `ddocShortName` interpolated into raw HTML** [ui/src/app/features/design-docs/design-doc-detail.component.ts:141] -- The delete-confirm dialog body concatenates the user-visible ddoc short name (sourced from the route param) into an HTML string rendered via `[innerHTML]="body"` inside ConfirmDialog. Angular's DomSanitizer strips dangerous HTML so script injection is not practically reachable, and the same pattern is used in `database-list.component.ts`. LOW -- consider migrating both call sites to a template-projected body variant if ConfirmDialog grows a structured API. -- **KEPT DEFERRED (2026-04-17, Story 12.0):** revisit bundled with the next ConfirmDialog API extension (e.g., when a structured-body overload is added). DomSanitizer keeps the current form safe.
- **TextAreaJson `emitValidity` re-emits on every invalid event** [ui/src/app/couch-ui/text-area-json/text-area-json.component.ts:374] -- The guard `if (this.lastEmittedValid === valid && !errorMessage) return;` only suppresses re-emission for the valid case. When the JSON remains invalid across keystrokes, `validityChange` fires on every debounce tick. Current subscribers treat this idempotently, but it is unnecessary event-bus chatter. LOW -- tighten by tracking `lastEmittedErrorMessage` and suppressing duplicate-invalid emissions too. -- **KEPT DEFERRED (2026-04-17, Story 12.0):** subscribers are idempotent; revisit only if a profiler shows emission overhead or a future subscriber is sensitive to duplicate-invalid events.

## Deferred from: code review of 11-4-revision-history-view (2026-04-15)

- ~~**Hardcoded `font-size: 12px` on `.revision-tree__node-badge`** [ui/src/app/couch-ui/revision-tree/revision-tree.component.ts:~230] -- The winner-star badge inside the SVG uses a literal `12px` instead of a design token. The pattern everywhere else in this file is `var(--font-size-xs)` etc. LOW -- replace with a token (or add a dedicated `--revtree-badge-size` token) the next time this component is touched. Not covered by stylelint today because stylelint only flags color literals, not font-size literals.~~ -- **RESOLVED in Story 12.0 (2026-04-17):** swapped `12px` -> `var(--font-size-xs)` (token resolves to same 12px) in `revision-tree.component.ts`.
- **Rapid mouseenter popover churn** [ui/src/app/couch-ui/revision-tree/revision-tree.component.ts:showPopover] -- Every `mouseenter` creates a fresh CDK overlay (after disposing the previous one). Rapid hover across adjacent nodes results in dispose/create ping-pong. No correctness bug (the overlay is always cleaned up on destroy and on mouseleave), but cheaper to reuse a single `OverlayRef` and just call `overlayRef.updatePosition()` + swap the portal component inputs. LOW -- optimize if perf profiling shows overlay creation dominating. -- **KEPT DEFERRED (2026-04-17, Story 12.0):** revisit trigger (profiler showing overlay dominance) still applies; no correctness bug.
- **`selectedRev` not preserved across a Refresh click** [ui/src/app/features/revisions/revisions-view.component.ts:loadTree] -- `loadTree()` clears `this.tree = null` but leaves `selectedRev` alone, and then its next-callback initialises `candidate` from `route.snapshot.queryParamMap.get('rev')` -- so a refresh that resets the URL would lose the selection. In practice `?rev=` is kept in sync via `onNodeSelect`'s `router.navigate({ replaceUrl: true })`, so the snapshot does contain the last-selected rev and the selection round-trips correctly. LOW -- documented for completeness; revisit if the refresh path stops updating the URL. -- **KEPT DEFERRED (2026-04-17, Story 12.0):** URL round-trips correctly today; documented for completeness only.
- **`showPopover` anchors via an SVG element cast as `HTMLElement`** [ui/src/app/couch-ui/revision-tree/revision-tree.component.ts:~421] -- CDK's `flexibleConnectedTo` types its origin as `HTMLElement`, but we pass an `<g>` (SVGGraphicsElement). CDK only uses `getBoundingClientRect()` which SVG elements support, so this works at runtime; the cast is a type-system lie. LOW -- clean up by narrowing the type or by anchoring to a wrapping `<div>` if the component grows a more elaborate popover API. -- **KEPT DEFERRED (2026-04-17, Story 12.0):** revisit trigger (richer popover API growing) still applies; runtime-correct.
- **AC #5 wording says arrow keys "move the selected node"; implementation moves focus** [ui/src/app/couch-ui/revision-tree/revision-tree.component.ts:onKeydown] -- The story Task 2 spec and every existing Angular keyboard-nav pattern in this codebase use "move focus; activate with Enter/Space" semantics, which is what was implemented (and what axe-core + keyboard-nav specs assert). AC #5's "move the selected node" is a minor wording mismatch between the user-facing AC and the Task 2 design note. LOW -- tighten the AC wording in the next epic retro or leave as-is since the keyboard model is deliberate and axe-clean. -- **KEPT DEFERRED (2026-04-17, Story 12.0):** spec-text divergence only; implementation is axe-clean and matches the app-wide keyboard-nav idiom. Revisit during the next epics.md edit pass if that file becomes the source of truth for AC wording.
- **No explicit unit test for a "≥ 5 conflict branches" legibility scenario** [ui/src/app/couch-ui/revision-tree/revision-tree-layout.spec.ts] -- Layout helper has specs for the 3-leaf tree and the 50-rev linear chain, but not the 5-leaf width test referenced in AC #5. Given that the layout is fixed-grid (one column per leaf), five leaves always fit trivially; a test would mostly assert deterministic column assignment. LOW -- add a fixture-driven "5-leaf wide" test if the layout algorithm ever grows heuristics that could mis-pack wide trees. -- **KEPT DEFERRED (2026-04-17, Story 12.0):** fixed-grid layout cannot mis-pack by construction; revisit if layout grows packing heuristics.

## Deferred from: Story 11.2 -- Security Configuration View (2026-04-14)

- ~~**JsonDisplay line-number gutter fails axe color-contrast on 10+ line bodies
  (LOW -- shared component styling issue).** `.json-display__line-number` uses
  `color: var(--color-neutral-400)` but renders (per axe) at `#9096a1` on
  `#f7f8fa`, contrast ratio 2.79 (WCAG AA needs 4.5). Tripped by the default
  `_security` body which is exactly 10 lines after JsonDisplay's internal
  2-space pretty-print. Design-doc bodies in Story 11.1 stay under 10 lines
  so the issue did not surface there. SecurityViewComponent's axe success-state
  spec disables the `color-contrast` rule as a scoped workaround. Fix in
  `ui/src/app/couch-ui/json-display/json-display.component.ts` by bumping the
  line-number color to a token with >= 4.5:1 contrast against
  `--color-neutral-50` (e.g., `--color-neutral-600` which renders ~4.7:1 on
  the same background). Single-line change. Affects every view that renders
  JsonDisplay with a >= 10-line body.~~ -- **RESOLVED in Story 12.0 (2026-04-17):**
  swapped `--color-neutral-400` -> `--color-neutral-600` in
  `json-display.component.ts`. Removed the scoped `color-contrast` disable
  in `security-view.component.spec.ts`; full axe-core pass restored for the
  10-line default `_security` body.
- **IRISCouch `_security` backend divergence from CouchDB 3.x spec (INFORMATIONAL
  -- client-side tolerated).** CouchDB 3.x returns `{}` for an unset
  `_security`; IRISCouch returns the full default object
  `{"admins":{"names":[],"roles":[]},"members":{"names":[],"roles":[]}}`
  verbatim. Verified via `curl -u _system:SYS /iris-couch/testsec112/_security`
  on 2026-04-14. SecurityService.normalizeSecurity() accepts both shapes so
  no client action is needed. Revisit if strict CouchDB wire compatibility
  becomes an NFR; otherwise leave as-is since the IRISCouch shape is strictly
  more useful to clients. -- **KEPT DEFERRED (2026-04-17, Story 12.0):** ObjectScript backend concern; revisit trigger (strict CouchDB wire compat becoming an NFR) still applies.

## Deferred from: code review of 11-5-admin-ui-handler-and-security (2026-04-15)

- **AC #4 error message says `%IRISCouch_Admin` but role is `IRISCouch_Admin`** [Story 11.5 AC #4] -- The role was renamed from `%IRISCouch_Admin` to `IRISCouch_Admin` during implementation because IRIS rejects `%`-prefixed custom roles (Error #887). The 403 error body and all code correctly reference `IRISCouch_Admin`, but the AC text still says `%IRISCouch_Admin`. Cosmetic documentation mismatch only. LOW -- update the AC wording in the next story or epic retro. -- **KEPT DEFERRED (2026-04-17, Story 12.0):** documentation-only mismatch; code is already correct. Revisit during the next epics.md / PRD-level edit when AC text is being touched for other reasons.

## Deferred from: Story 12-2 implementation (2026-04-17)

- **[MED] View query params beyond `reduce` and `include_docs` not implemented** [Story 12.2 MVP cut] -- The `QueryEngine.Query()` method supports only `reduce` and `include_docs` today. CouchDB 3.x views also honour `group`, `group_level`, `startkey`, `endkey`, `limit`, `skip`, `descending`, `inclusive_end`, `stale`, `update_seq`. These were deferred to a follow-up story because each adds enough surface (key-range scanning, grouped reduction, etc.) that Story 12.2 would have exceeded its session budget. The deferred surface is large enough to warrant its own story; suggest **Story 12.2a: View Query Parameters**. Rationale captured in the story artifact's Task 5 notes. MED -- common client pattern (`?limit=10&skip=20`) returns all rows today; clients that depend on these params will need to paginate in application code until 12.2a lands.

- **[MED] `_approx_count_distinct` is an exact distinct count, not HLL** [Story 12.2 AC #3 deviation] -- `IRISCouch.View.BuiltinReduce.ApplyApproxCountDistinct` stores every distinct value in a local array and counts it. CouchDB uses a HyperLogLog sketch (log-space probabilistic estimate). The IRISCouch result is strictly more accurate but has O(N) memory vs CouchDB's O(log N), which matters for million-row reduces. Deferred to **Epic 14** per the story spec. MED -- noticeable only at very high cardinality; documented as a KNOWN DEVIATION in the BuiltinReduce class doc comment.

- **[MED] Row sort by key uses JSON string collation, not CouchDB typed collation** [Story 12.2 AC #1 deviation] -- `QueryEngine.SortRowsByKey()` encodes each key into a string with a type-tag prefix ("n:" for numbers, "s:" for strings, "z:" for objects/arrays) and sorts via `$Order`. This is correct for homogeneous-type keys but mis-orders mixed-type keys where CouchDB's native Erlang comparator (`couch_ejson_compare.erl`) would place `null < false < true < number < string < array < object`. Fix requires a stable typed comparator. Deferred because Story 12.2's MVP scope explicitly allowed "simple lexicographic JSON-string compare". LOW-MED depending on how often applications emit mixed-type keys.

- **[LOW] Subprocess `JSRUNTIMETIMEOUT` not enforced today** [Story 12.2 Task 2] -- The `Pipe.Flush()` method spawns the subprocess via `$ZF(-100)` with no timeout argument; a runaway map function will hang until Windows kills the process or the OS pipe buffers fill. `JSRUNTIMETIMEOUT` is read by the class but not passed through to the `$ZF` call. Fix: wrap in `%SYSTEM.Process.Timeout()` or post-spawn watchdog. Deferred because Story 12.5 persistent-pool work will rework this anyway. LOW -- real concern is denial-of-service via a ddoc with an infinite loop; for 12.2's trusted-admin model this is acceptable. -- **KEPT DEFERRED (2026-04-18, Story 13.0): superseded by Story 12.5 two-layer timeout fix; left as KEPT for audit continuity — see summary entry above.**

- **[LOW] Subprocess per-query lifecycle is slow for small views** [Story 12.2 AC #6] -- Each view query spawns a fresh Node process, which takes ~80-150ms cold-start on Windows before any JS executes. Fine for occasional queries; expensive if an app issues hundreds of view queries per request. Explicitly in-scope for **Story 12.5** (persistent pool + incremental indexing). No action needed before 12.5. -- **KEPT DEFERRED (2026-04-18, Story 13.0): cold-start removed from query hot path by Story 12.5 incremental indexing; remaining write-time + changes-filter cold-start is Story 12.5b scope.**

- **[LOW] `iris_execute_tests` MCP work-queue instability** [Story 12.2 Task 7] -- Extends the Story 12.1 deferred observation. During Story 12.2 the MCP's async work-queue began returning 500 errors after a handful of consecutive test runs, requiring ~15-20s recovery between invocations. Story 12.2 worked around this by running tests via a temp `IRISCouch.Test.SubprocessTestRunner` helper that exercises tests inline with a probe `%UnitTest.Manager`. The helper should be deleted once `iris_execute_tests` is reliable. File against `iris-dev-mcp` when reproducible. LOW -- tooling issue, no product impact. -- **KEPT DEFERRED (2026-04-18, Story 13.0): Story 13.0 re-probed MCP; class-level discovery still returns 1/N methods. Probe helpers remain in tree as workaround. Revisit when upstream MCP fix lands.**

## Deferred from: code review of 12-1-jsruntime-sandbox-interface-and-none-backend (2026-04-17)

- **[LOW] `Util.Error.Render501` `pSubsystem` parameter is unused in the response body** [Story 12.1 Task 8] -- The method takes `(pSubsystem, pReason)` but only logs `pSubsystem` via `Util.Log.Info`; the HTTP body uses `pReason` only. Callers already embed the subsystem label in `pReason` via `BuildJSRuntimeNotImplementedReason(pSubsystem)`, so the separate `pSubsystem` argument is a redundant breadcrumb for structured-log consumers. Consider either (a) dropping `pSubsystem` and parsing it out of the log data, or (b) adding a dedicated `subsystem` field to the response body once Story 12.2 introduces richer error metadata. LOW — stylistic / informational only; no behavioural impact in 12.1.

- **[LOW] `Factory.GetSandbox()` logs a Warn on every call when `JSRUNTIME` holds garbage** [Story 12.1 Task 4] -- A misconfigured server receiving 1000 req/sec will emit 1000 "Unrecognised JSRUNTIME value" warnings/sec with no deduplication. Consider gating via a process-private "already-warned this session" flag keyed on the current garbage value, or lifting the log to a once-per-config-change admin event. LOW — operational log hygiene; does not impact correctness and only fires under misconfiguration.

- **[LOW] Story 12.2** Subprocess per-query lifecycle is slow for small views (80-150ms cold start); pool work is Story 12.5 scope -- [full entry](#deferred-from-story-12-2-implementation-2026-04-17) -- **KEPT DEFERRED (2026-04-18, Story 13.0): incremental indexing (Story 12.5) removed cold-start cost from the query hot path; remaining cold-start concern (write-time index + changes-filter) is the target of Story 12.5b long-lived pool. Do not resolve here.**
- **[LOW] Story 12.2** Subprocess `JSRUNTIMETIMEOUT` not enforced at `$ZF(-100)` level; runaway JS hangs until OS pipe backpressure -- [full entry](#deferred-from-story-12-2-implementation-2026-04-17) -- **KEPT DEFERRED (2026-04-18, Story 13.0): superseded by Story 12.5's two-layer timeout fix (`couchjs-entry.js` self-kill + IRIS-side `/ASYNC` + polling kill). This specific LOW entry is historical; the underlying concern is resolved. Leave as KEPT DEFERRED for audit-trail continuity rather than stealth-resolve.**
- **[LOW] Story 12.2** `iris_execute_tests` MCP work-queue instability; required a temp inline test runner -- [full entry](#deferred-from-story-12-2-implementation-2026-04-17) -- **KEPT DEFERRED (2026-04-18, Story 13.0): tooling bug in `iris-dev-mcp`, still reproduces as of Story 13.0 probe (class-level discovery returns 1/N methods for JSRuntimeHttpTest). Revisit when upstream fix lands. Same trigger as 12.1 / 12.3 MCP-discovery entries above.**
- **[LOW] Test discovery inconsistency under `iris_execute_tests` class-level runs** [Story 12.1 Task 9] -- When `IRISCouch.Test.JSRuntimeHttpTest` is run at `level=class`, the MCP runner reports only 3 of the 11 test methods (`AbstractSandboxContract`, `BuiltinFiltersStillWorkWhenRuntimeIsNone`, `CustomFilterReturns501WhenRuntimeIsNone`); all 11 pass when invoked individually at `level=method`. Likely an `%UnitTest.Manager` caching / work-queue interaction in the MCP tool rather than a class-level issue (the class compiles clean and standalone `do ##class(%UnitTest.Manager).RunTest(...)` runs all 11). Revisit when Story 12.2 or the next ObjectScript story needs bulk test runs; if reproducible, file against the `iris-dev-mcp` server. LOW — does not affect correctness; individual runs confirm 11/11 pass.

## Deferred from: code review of 12-2-subprocess-jsruntime-map-reduce-views (2026-04-17)

- **[MED] NFR-S9 subprocess sandbox hardening (filesystem/network restrictions, memory limits, path-traversal validation) not implemented** [Story 12.2 review] -- The epic spec and NFR-S9 require "restricted filesystem and network access" plus "per-invocation timeout and memory limits" for user-supplied JavaScript. Story 12.2's `Pipe.cls` launches the interpreter with no sandbox flags (no `--allow-read`/`--allow-net` for Deno, no ulimit-style wrapping, no validation of the configured `JSRUNTIMESUBPROCESSPATH` against path traversal or symlink attacks). Per the epic plan these restrictions are explicitly scheduled for **Story 12.5** (persistent pool, memory-pressure restarts, sandboxing). Logging here so reviewers of 12.5 do not overlook the Deno `--allow-*` flags, the Windows job-object memory cap, and path-traversal validation before launch. MED -- default trusted-admin deployment assumes the operator owns both IRIS and the interpreter binary, so the gap is acceptable until 12.5.

- **[MED] Subprocess `JSRUNTIMETIMEOUT` documented as enforced (5000 ms default) but `Pipe.cls` never passes a timeout to `$ZF(-100)`** [Story 12.2 review] -- Both `documentation/js-runtime.md` and `documentation/couchjs/README.md` state "`JSRUNTIMETIMEOUT` (default 5000 ms) caps the per-query interpreter wall-clock". The code path at `Pipe.Flush()` does not read the config value and does not pass `/TIMEOUT=` (or a watchdog) to `$ZF(-100)`. A runaway `while(true){}` in a user map function will hang until Windows kills the process or OS pipe buffers fill. Previously logged as LOW in the dev notes; upgrading to MED because the docs make a concrete promise that the code does not keep. Fix is either: (a) read `JSRUNTIMETIMEOUT` and pass `/TIMEOUT=<ms>` to `$ZF(-100)`, or (b) remove the docs sentence until Story 12.5 lands pool-level timeout enforcement. Either is safe for 12.2a.

- **[LOW] `QueryEngine.Query` double-resolves winning rev per document** [Story 12.2 review] -- `ListLiveDocIds(pDB)` already filters out tombstoned and missing-rev documents by calling `Storage.RevTree.GetWinner` + `IsDeleted` internally. `QueryEngine.Query` then loops over the returned IDs and calls `GetWinner`/`IsDeleted` a second time (`QueryEngine.cls:96-97`). Each extra call is a constant-time global lookup so the perf hit is bounded, but for a 10k-doc view this still burns ~10k unnecessary `$Data` calls. Fix: change `ListLiveDocIds` to also return the winning rev (or return an iterator yielding `(docId, winningRev)` tuples) so `QueryEngine` does not re-resolve. LOW -- correctness-neutral; defer until pagination/index work in Story 12.2a or 12.5.

- **[LOW] `SubprocessTestRunner` + `SubprocessTestRunner.ProbeManager` are marked "delete after review" but still in the codebase** [Story 12.2 review] -- The story's File List calls these out as temp helpers to remove after review sign-off. They are workarounds for the `iris_execute_tests` MCP instability tracked elsewhere in this file. Keep until the MCP issue is fixed (otherwise review-time regression runs stop working); revisit the delete at Story 12.2a close or the next Epic-12 retrospective.

- **[LOW] `ExecuteReduce` does not validate the `reset` ack** [Story 12.2 review] -- `Subprocess.ExecuteReduce` reads `tResetAck` via `ReadLine` but never checks that it equals `true`. If the entry script exited early during `reset` (disk full, OOM during vm-context creation), `tResetAck` would be an `["error", ...]` array and the subsequent `tReduceLine` read would be EOF / empty. Current behaviour is an eventual empty-response error, so the failure mode is merely less diagnostic rather than unsafe. Fix: assert `tResetAck = "true"` before proceeding, wrap the mismatch in a `ThrowSubprocessError` with the raw ack for debuggability. LOW -- diagnostic quality only; no correctness impact.

## Deferred from: code review of 12-3-subprocess-jsruntime-validation-and-filter-functions (2026-04-17)

**Review scope.** Full-coverage adversarial review across Blind Hunter / Edge Case Hunter / Acceptance Auditor on all six new classes and eight modified classes. Story delivered 699/699 assertions, all 7 ACs verified, Pattern Replication Completeness confirmed across Save / SaveDeleted / SaveWithHistory / SaveWithAttachments (identical hook call signature, identical TROLLBACK semantics, identical `pValidateError` Output propagation). Auto-resolved 3 MEDIUM items in-line during review; remainder deferred below.

### Auto-resolved during review (2026-04-17)

- **[MED->FIXED] Dead code in `ChangesHandler.BuildFilterReq`** -- `Set tFullPath = [].%Push(pDB).%Push("_changes")` (line 429) constructed an array that was never read. Removed the assignment; `%Set("path", ["_changes"])` / `%Set("info", {"db_name":(pDB)})` remain unchanged. No behavioural impact. **Fixed in code during review.**

- **[MED->FIXED] `RunValidateHook` allocated a sandbox even when no validate-defining ddoc was present** -- `Factory.GetSandbox()` was called immediately after `ListValidateFunctions`, before the `If tValidates = 0 Quit` early-exit. On the hot path (databases with no validate hook, which is the vast majority) this wasted a `%New()` per write. Reordered so `GetSandbox()` runs only when a validate is actually present. **Fixed in code during review.** Measurable on high-write-rate benchmarks; correctness-neutral.

- **[MED->FIXED] Double-close on `Pipe` in `ExecuteValidateDocUpdate` exception path** -- The Catch block closed the pipe and then `Quit`-ed, which exits the Try/Catch without returning from the method; the common-exit `If $IsObject(tPipe) Do tPipe.Close()` line then ran a second `Close()`. Safe because `Pipe.Close` is explicitly idempotent, but wasteful and inconsistent with `ExecuteFilter` (which uses `Throw ex` to bypass the common-exit close). Removed the redundant Catch-block close so the method has a single well-defined close-once-on-exit flow. **Fixed in code during review.**

### Still-open items

- **[MED] `ListValidateFunctions` iterates all live docs when it only needs `_design/*`** [Story 12.3 Task 3] -- `DesignDocs.ListValidateFunctions` calls `Storage.Document.ListLiveDocIds(pDB, 1)` and then filters each id with `If $Extract(tDocId, 1, 8) '= "_design/" Continue`. On a 1M-doc database this walks the entire `^IRISCouch.Docs(pDB,*)` subscript tree per write. A direct `$Order` over `^IRISCouch.Docs(pDB, "_design/...")` (guarded by `$Extract "_design/"`) would reduce the per-write cost from O(N) to O(number of design docs), which is typically 1-5. Fix belongs alongside Story 12.5 pool work which will also want a cached design-doc registry. MED -- noticeable on large DBs under write-heavy workloads; measured impact is load-dependent.

- **[MED] One subprocess spawn per candidate change for custom filters** [Story 12.3 Task 2 follow-up] -- `ChangesHandler.HandleChanges` invokes `tCustomSandbox.ExecuteFilter(...)` per doc inside the `While tI < tRawResults.%Size()` loop. Each call spawns a fresh Node process (~80-150ms cold-start on Windows). A changes feed with 1000 changes pays ~100 seconds of spawn latency. The `ddoc filters` protocol already supports batched `[[doc1,doc2,...], req]` invocation -- the entry script iterates `docs` and emits `[true, results[]]`. Fix: group changes into N-doc batches (or single-call-all-docs) and walk the returned result array in order. Deferred per story spec (Task 2: "log a follow-up LOW to defer batching to Story 12.5 pooling"). MED (was LOW per story spec; upgraded to MED because the performance gap is 10x+ on real workloads once Story 12.5 pool removes spawn cost).

- **[LOW] `Test/SubprocessValidateProbe.cls` retained as evidence-of-work scaffolding** [Story 12.3 File List note] -- The class docstring explicitly calls it out as a probe helper "intentionally retained as part of Dev Notes evidence -- safe to delete after story close". Keep until Story 12.3 is signed off / next Epic 12 retrospective; delete as part of a cleanup story. The probe helpers (`ProbeApprove` / `ProbeForbid` / `ProbeUnauth` / `ProbeFilterTrue` / `ProbeFilterFalse` / `ProbePeel` / `ProbeStatusText`) also shadow production paths and could be replaced by a single unit-test class once the MCP test runner is reliable.

- **[LOW] `Subprocess.ExecuteValidateDocUpdate` does not validate intermediate acks before reading the invoke response** [Story 12.3 Task 1] -- Same diagnostic-quality gap as `ExecuteReduce` (logged for Story 12.2). The method reads `tResetAck`, `tNewDDocAck`, then `tResult` without asserting the first two are the expected `"true"`. If the entry script crashed during `reset` or `ddoc new` (disk full / OOM / malformed ddoc body), the eventual failure mode is an empty-response error (vague) rather than a named "reset failed" / "ddoc registration failed" error. Fix parallels the Story 12.2 review entry for `ExecuteReduce`: assert the ack equals `"true"` and raise `ThrowSubprocessError(tPipe, ...)` on mismatch. LOW -- diagnostic quality only; no correctness impact.

- **[LOW] Hardcoded `NODEPATH = "C:\Program Files\nodejs\node.exe"` in three test classes** [Story 12.3 Tasks 8, 0] -- `Test/JSRuntimeValidateHttpTest`, `Test/JSRuntimeFilterHttpTest`, and `Test/SubprocessValidateProbe` all declare `Parameter NODEPATH = "C:\Program Files\nodejs\node.exe"`. Each HTTP test class guards execution with a `CanLaunchSubprocess()` helper that returns 0 when the path is invalid, so on non-Windows or non-Node environments the tests skip (via `$$$AssertTrue(1, "SKIP: no launchable Node interpreter on this runner")`) rather than fail. Same pattern is used by Story 12.2 tests. Fix: either (a) read `JSRUNTIMESUBPROCESSPATH` from the environment / a test-config helper, or (b) probe common Unix paths (`/usr/bin/node`, `/usr/local/bin/node`, `/opt/homebrew/bin/node`) in `OnBeforeOneTest`. LOW -- CI portability; tests skip gracefully today.

- **[LOW] MCP `iris_execute_tests` class-level discovery reports only 1/9 methods for `JSRuntimeValidateHttpTest` and 1/4 for `JSRuntimeFilterHttpTest`** [Story 12.3 review] -- Extends the Story 12.1 and 12.2 observations. At `level=class` the runner reports only `MultipleValidatesFailFast` (9 test methods defined, 1 discovered) and only `BuiltinFiltersRegressGreen` (4 defined, 1 discovered). Running at `level=method` with the full `IRISCouch.Test.JSRuntimeValidateHttpTest:TestValidateApprovesWrite` target returns `{"total":0,"passed":0}` -- the runner does not recognise the namespaced method form. Dev worked around by adding `SubprocessValidateProbe.RunAllValidateHttpTests` / `RunAllFilterHttpTests` that instantiate the test class directly and invoke each method via `$METHOD`, then inspect `^UnitTest.Result` with a custom `LastUnitTestSummary` walker. This reproduces the 699/699 number reported in the story file. LOW -- tooling issue, no product impact; file against `iris-dev-mcp` when reproducible outside IRISCouch.

- **[LOW] `RunValidateHook` uses `$ZHorolog` for duration measurement** [Story 12.3 Task 10] -- `DocumentEngine.RunValidateHook` and `ChangesHandler.HandleChanges` both use `Set tStart = $ZHorolog` + `Set tDuration = ($ZHorolog - tStart) * 1000` for the audit `durationMs` payload. `$ZHorolog` is local wall-clock and is not monotonic; a request spanning midnight yields a negative duration. Other callers in the codebase (Story 9.3 logging, Story 12.2 view audit) already use the same pattern, so this is a pre-existing project-wide convention. Fix: switch to `$zh` with wrap-around handling, or use `$ZUTIL(193)` / `$ZUTIL(194)` which return monotonic ticks. LOW -- real-world trigger is a validate or filter call spanning 00:00 local; effect is a cosmetic negative number in the audit event. Correctness of the validate result is unaffected.

- **[LOW] `ExecuteValidateDocUpdate` / `ExecuteFilter` do not carry `JSRUNTIMETIMEOUT` through to `$ZF(-100)`** [Story 12.3 Tasks 1, 2] -- Extends the Story 12.2 `Pipe.cls` timeout gap already logged above. Story 12.3 two new methods inherit the same `Pipe.Flush()` limitation: a runaway `validate_doc_update` or filter function with an infinite loop will hang the IRIS process for that write / changes request until Windows kills the Node child. Same fix applies (propagate `JSRUNTIMETIMEOUT` into the `$ZF` call); tracked under Story 12.2 MED entry.

- **[LOW] `BuildFilterReq` exposes only `User-Agent` and `Content-Type` headers** [Story 12.3 Task 5 Key decisions] -- Per dev notes this is an intentional trim ("minimal but CouchDB-compatible"). Some CouchDB filters in the wild reference `X-Forwarded-For`, `Authorization`, and `Accept-Language` headers. Adding more headers is trivially backward-compatible but may leak sensitive data (Authorization tokens) to user-supplied JS. Revisit if a real user reports a filter that needs specific headers; default is to keep the trimmed surface. LOW -- API compat risk is low; the CouchDB documentation explicitly warns against relying on `req.headers` for security decisions.

- **[LOW] `ExecuteFilter` treats `["error", ...]` entry-script responses as "exclude doc" silently** [Story 12.3 Task 2] -- Lines 342-345 of `Subprocess.cls`: when the entry script returns `["error","filter_runtime_error", ...]` for a doc (e.g. the filter fn threw a `TypeError`), `ExecuteFilter` returns 0 (exclude) without logging. The entry script `throw ['error','filter_runtime_error', errstr(err)]` is meant to surface as a structured error, but the caller behaviour is to silently drop the doc. This matches CouchDB "falsy excludes" but loses the diagnostic. Fix: emit a `Util.Log.Warn("jsruntime", "filter runtime error", {docId, reason})` when `tArr.%Get(0) = "error"`. LOW -- operators debugging "why is my filter not matching doc X" today have to attach the subprocess and reproduce.

- **[LOW] Custom filter path `Audit.Emit.FilterExecute` is emitted once per `_changes` request regardless of error** [Story 12.3 Task 10] -- If `ExecuteFilter` throws mid-iteration (subprocess failed), the outer Catch renders a 500 and the `FilterExecute` audit event is never emitted. Operators grepping audit for filter activity will not see the attempt. Fix: emit `FilterExecute` (or a new `FilterError`) before re-throwing so the audit trail reflects the attempt. LOW -- affects observability only; parallel to the existing `ViewError` vs `ViewExecute` split.

- **[LOW] Multi-key `: ` peel in `DocumentHandler.RenderValidate` and `BulkHandler.BuildValidateErrorEntry` is duplicated** [Story 12.3 Task 6] -- Both helpers do the same `$Find(tMsg, ": ") ... $Extract(tMsg, tColon, *)` peel. Extract into a shared `Util.Error.PeelIRISErrorPrefix(pMsg) As %String` helper so locale-prefix handling lives in one place. LOW -- refactor; no behavioural difference.

## Deferred from: code review of 12-5-incremental-view-indexing-caching-and-sandbox-safety (2026-04-17)

- **[LOW] `Pool.ShutdownAll` is never invoked** [Story 12.5 Task 3] -- The docstring for `IRISCouch.JSRuntime.Subprocess.Pool.ShutdownAll` claims the method is "called on IRIS shutdown or namespace stop via `%SYSTEM.Event.Signal`" but no such registration exists. In the Story 12.5 shim the method is a no-op (the pool stack is always empty), so the missing invocation is cosmetic today. When Story 12.5b lands and the pool holds real subprocess OREFs, `ShutdownAll` must actually fire — wire it via a namespace-shutdown hook at that time. LOW -- no behaviour gap in the current shim.

- ~~**[LOW] `Pool.cls` docstring overstates the implementation as LIFO/MRU** [Story 12.5 Task 3]~~ -- **RESOLVED in Story 13.0 (2026-04-18)**: Storage block in `Pool.cls` rewritten to mark "Planned for Story 12.5b — shim today" next to the LIFO-stack layout description, so current reader cannot mistake the spec for the current behaviour.

- ~~**[LOW] `EncodeKeyForSort` bool/integer ambiguity sentinel is dead code** [Story 12.5 Task 1]~~ -- **RESOLVED in Story 13.0 (2026-04-18)**: dead `If (pKey = 1) && ($Get(pKey) = 1) && ('$Listvalid(pKey)) {…}` block removed from `Storage/ViewIndex.cls:82-85`; replaced with a one-line comment explaining why the block was dead.

- **[LOW] Byte-equality claim covers a single narrow fixture** [Story 12.5 Completion Notes] -- Dev's pre/post byte-identical demonstration uses a 10-doc `emit(doc._id, 1)` fixture. Mixed-type keys, reduce outputs, and `include_docs=true` responses are not byte-compared. Story 12.2a already carries range-param work and is the natural home for a broader byte-equality harness. LOW -- coverage gap; no known defect.

- ~~**[LOW] `ViewIndexHttpTest.TestPooledSubprocessReducesLatency` method name misleads** [Story 12.5 Task 9]~~ -- **RESOLVED in Story 13.0 (2026-04-18)**: method renamed to `TestWarmIndexReducesLatency`; docstring updated to clarify the test measures warm-index latency (not a pooled subprocess, which is a shim until Story 12.5b). `ViewIndexHttpTest` 7/7 green after rename.

- **[LOW] `Pipe.IsProcessDead` leaks its tasklist probe stdout temp file on probe-time exception** [Story 12.5 Task 4] -- If the probe spawn itself throws, the outer catch swallows the exception without deleting `tProbeStdout`. IRIS's startup scrub reclaims the file eventually, but long-lived sessions that repeatedly hit the error path could accumulate tens to hundreds of stale `pprobe*` files in the temp dir. Fix: wrap the `%File.TempFilename` -> delete in a small finally-style helper. LOW -- temp-file pressure only, no correctness impact.

- **[LOW] `Pipe.SandboxFlags` pipe-delimiter is fragile for future flag values containing `|`** [Story 12.5 Task 5] -- `BuildSandboxFlags` returns a `|`-separated string that `Flush` splits via `$Piece`. If a future interpreter requires a flag value containing `|` (unusual but possible for regex-allowlists), the tokenisation breaks. Switch to a `$ListBuild` encoding when the flag surface grows. LOW -- speculative; no current flag collides.

### Resolved during code review of 12.5 (2026-04-17)

- **[MED→RESOLVED] Storage encapsulation violation in `Core.ViewIndexUpdater.HandleDesignDocChange`** -- Original code killed `^IRISCouch.ViewIndex*` globals directly at 4 sites, violating the "Storage.ViewIndex is the sole owner" rule. Fixed by adding `Storage.ViewIndex.DropForView(pDB, pDDocId, pViewName)` and `Storage.ViewIndex.ListIndexedViewNames(pDB, pDDocId)` helpers and routing `HandleDesignDocChange` through them.
- **[MED→RESOLVED] Pattern Replication gap: `_users`/`_replicator` body rewrite did not re-run ViewIndex** -- When `DocumentEngine.Save` rewrote the body post-step-6b (e.g., password stripping on `_users`, system-field injection on `_replicator`), the view index retained emissions from the pre-rewrite body. Matched the existing MangoIndex re-index pattern: ViewIndexUpdater now fires again after the body rewrite. TROLLBACKs cleanly on timeout in the re-run path.
- **[MED→RESOLVED] Pool API not wired into `Subprocess.ExecuteMap/Reduce/Validate/Filter`** -- Per AC #7, these methods must route through the Pool. Original code called `Pipe.%New()` directly from `StartPipe`. Fixed: `StartPipe` now delegates to `Pool.Acquire()` and every `tPipe.Close()` site swapped to `Pool.Release(tPipe)`. Observable behaviour unchanged under the 12.5 shim (Pool.Acquire still returns a fresh Pipe), but future 12.5b upgrade becomes drop-in.
- **[MED→RESOLVED] Node sandbox flag list missing `--no-experimental-global-webcrypto`** -- Spec AC #6 names this flag explicitly. Dev's `BuildSandboxFlags` used `--disable-proto=delete|--no-warnings` instead. Added the crypto-disable flag per spec.
- **[MED→RESOLVED] `Pipe.Flush` positional-arg call shape dropped timeout arg on Deno** -- Deno's 8-flag prefix (`run` + 7 allow/deny) plus executable + entry + timeout = 11 args, but the fixed positional `$ZF(-100)` call only passed slots 0-9, silently dropping the trailing timeout argument on Deno. Rewrote to use the by-reference `$ZF(-100, flags, program, .args)` pattern per `irislib/%Net/Remote/Utility.cls` so arg count is unbounded.
- **[LOW→RESOLVED] Entry script path not validated for traversal** -- `Pipe.Open` now runs `ValidateExecutablePath` on both `pExecutable` and `pEntryScript`, closing the consistency gap.
- **[LOW→RESOLVED] `IsProcessDead` docstring described an unimplemented file-size heuristic** -- Stale paragraph removed; the docstring now accurately describes the `tasklist` / `kill -0` probe.

## Deferred from: code review of 13-1-getting-started-guide-and-compatibility-matrix (2026-04-18)

- **[LOW] Story 13.1** `_show` / `_list` / `_update` / `_rewrite` design-doc render endpoints listed in the compatibility matrix as `501 in default config` but actually return `404` in current runtime (no dispatcher registered). [Matrix §"Design Documents — Shows, Lists, Updates, Rewrites"] -- The intended semantics once the dispatcher ships is 501 under `JSRUNTIME=None` (matching views/validate/custom filters). The matrix preserves the `501` classification to stay forward-compatible and to communicate that "these endpoints are known-to-CouchDB, not unknown". Fix-forward: in the next backend-cleanup story, register the four render routes and have them return a uniform `501` envelope naming `JSRUNTIME` (same shape as `JSRuntimeHttpTest.TestNoneBackendThrowsCanonicalEnvelope`). LOW -- operator impact is only that `curl /{db}/_design/.../_show/...` returns 404 instead of 501 today; no known client depends on the distinction.

- **[LOW] Story 13.1** `/_scheduler/*` and `/_node/{name}/*` endpoint families collapsed into one matrix row each, rather than one row per individual endpoint in the vendored CouchDB docs (`/_scheduler/jobs`, `/_scheduler/docs`, `/_scheduler/docs/{replicator_db}`, `/_scheduler/docs/{replicator_db}/{docid}`, `/_node/{name}`, `/_node/{name}/_stats`, `/_node/{name}/_system`, `/_node/{name}/_prometheus`, `/_node/{name}/_smoosh/status`, `/_node/{name}/_restart`, `/_node/{name}/_versions`). [Matrix §"Server-level endpoints"] -- All endpoints in each family are `out of scope with reason` for the same reason (single-node / per-node-metrics architecture mismatch). Collapsing is a deliberate readability choice; expanding the matrix would add ~10 rows of identical `out of scope with reason` entries with no adopter benefit. LOW -- revisit only if an adopter asks "is `/_node/X/_restart` supported?" and needs a distinct row to cite. Trigger: any adopter-filed issue that cites one of these collapsed endpoints by name.

## Deferred from: Story 13.3 implementation (2026-04-18)

- **[HIGH] Story 13.3** IRISCouch returns 404 for trailing-slash variants of the database URL (`PUT /{db}/`, `GET /{db}/`, `HEAD /{db}/`). CouchDB 3.x accepts both the trailing-slash and no-trailing-slash forms on every `/{db}` endpoint. **Discovered during Story 13.3 dev** while building the `examples/pouchdb-sync/` example: PouchDB's default remote-handle construction calls `PUT /{db}/` (with trailing slash) as its auto-create probe, which IRISCouch's UrlMap does not match, so PouchDB treats the DB as nonexistent and aborts replication with `"missing" 404`. **Root cause:** `src/IRISCouch/API/Router.cls` UrlMap declares `<Route Url="/:db" ...>` four times (PUT, GET, DELETE, POST) but no `/:db/` companion routes; CSP's URL matcher treats trailing-slash as a distinct path. **Workaround shipped in the example:** pre-create the DB with an explicit `PUT /{db}` (no trailing slash) and pass `{ skip_setup: true }` to the PouchDB constructor so the auto-create probe is skipped. This is the standard production PouchDB pattern anyway — it saves a round-trip per handle construction — so the workaround is not distasteful. **Fix path:** add four `<Route Url="/:db/" ...>` entries alongside the existing `/:db` routes (delegating to the same handlers: `HandleDatabaseCreate`, `HandleDatabaseInfo`, `HandleDatabaseDelete`, `HandleDocumentPost`). Two-line Router.cls change, ~10 minutes including compile. Trigger: the next backend cleanup story ideally `14-0-epic-13-deferred-cleanup.md` when Epic 14 kicks off. HIGH -- silent PouchDB integration failure without the workaround; affects every adopter who tries to sync a fresh browser PouchDB against IRISCouch without reading the example README first.

- **[MED] Story 13.3** Compatibility matrix view-query-parameter rows (§ "View-query-parameter support under `JSRUNTIME=Subprocess` (Story 12.2a)") listed `group`, `group_level`, `startkey`, `endkey`, `limit`, `skip` as "supported (Story 12.2 shipped)" — **this was incorrect**. The code in `IRISCouch.View.QueryEngine.Query` (line 26 class comment: "Only reduce and include_docs query params are honoured") and `IRISCouch.API.ViewHandler.ExtractQueryParams` (reads only `reduce` and `include_docs`, ignores everything else) actually silently ignores these six params, consistent with the existing Story 12.2 deferred-work entry ("View query params beyond `reduce` and `include_docs` not implemented — Story 12.2a"). The matrix entry was aspirational — the matrix author (Story 13.1) appears to have conflated "logged as deferred" with "shipped and deferred is now-resolved". **Fix shipped in same commit as this entry:** matrix rows reclassified to `silently ignored (Story 12.2a)` with a "Dev-host-discovered 2026-04-18" pointer. No behavioural change needed — the code already silently ignores these params per CouchDB client-tolerance convention. Confirmed by dev-host probe: `group=true` on a map/reduce view with 5 docs returns `{"rows":[{"key":null,"value":5}]}` — ungrouped — not per-key grouped. MED -- matrix was misrepresenting the product's capability; corrected.

- **[MED] Story 13.3** Examples CI harness unwired. The `examples/run-all.sh` and `examples/run-all.ps1` harnesses ship today and pass locally against the dev-host IRIS (5/6 examples pass; 1 environmental-skip for `replicate-from-couchdb` — requires a reachable Apache CouchDB which the dev host does not have; `jsruntime-subprocess-node` passes after configuring `JSRUNTIME=Subprocess` + `JSRUNTIMESUBPROCESSPATH`). The story's AC #4 requires that a broken example block the release. Today that enforcement is **dev-host-manual**: the author runs `run-all.sh` before tagging. **Automated enforcement** requires a dockerized IRIS CI image + a GitHub Actions workflow (`.github/workflows/examples-smoke.yml`) that provisions IRIS, installs IRISCouch, configures `JSRUNTIME=Subprocess`, spins up an Apache CouchDB sidecar, then runs `bash examples/run-all.sh`. Estimated scope: one dockerfile (IRIS + IRISCouch), one GitHub Actions workflow, one docker-compose for the CouchDB sidecar — ~1 day of infra work. Precedent: the single existing workflow `ui-smoke.yml` hit the same infra wall (self-hosted-runner-required, queued indefinitely without infra — see Story 11.0 deferred entry above). Same infra story can land both. **Trigger:** before α/β tagging gate. Owner: TBD. MED -- today's manual dev-host enforcement is functional but is a single-point-of-failure in the release process.

- **[LOW] Story 13.3** `examples/jsruntime-subprocess-node/setup.js` probe for `JSRUNTIME=Subprocess` is observable-only (issues a view query, detects 501 envelope) rather than reading `^IRISCouch.Config("JSRUNTIME")` directly. Reading the global requires a `/Config` HTTP endpoint which IRISCouch does not expose (and should not — configuration lives in globals, not HTTP). The observable probe is correct but has a one-query overhead per example run. Acceptable as-is. LOW -- cosmetic; the probe works and documents itself.

- **[LOW] Story 13.3** `examples/attachment-upload/fixtures/test.png` is a 987-byte deterministic noise PNG (48×48 RGB, seeded LCG) rather than a 1-2 KB file as the story task suggested. Noise PNGs don't compress, so hitting exactly 1-2 KB requires a specific canvas size; 48×48 was the closest round-number that stays within the range without going over. Round-trip SHA-256 assertion works identically regardless of size. If a future story needs a 1-2 KB fixture specifically, regenerate the noise PNG at 56×56 (~1.4 KB). LOW -- cosmetic.
