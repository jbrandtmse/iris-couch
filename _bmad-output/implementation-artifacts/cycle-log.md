# Epic Development Cycle Log

## Epic 13: Documentation & Working Examples

### 2026-04-18T00:00:00Z — Cycle started
- **Scope:** Epic 13, Stories 13.0 (deferred cleanup, to be created) + 13.1, 13.2, 13.3 (backlog)
- **Invocation:** `/epic-dev-cycle Epic 13`
- **Sprint status at kickoff:** Epic 12 `in-progress` (retrospective done), 13.1/13.2/13.3 `backlog`, 13.0 not yet in sprint-status
- **Preconditions verified:** `sprint-status.yaml` current, `deferred-work.md` present, `epic-12-retro-2026-04-17.md` present with 10 action items

### 2026-04-18T00:10:00Z — Phase 0: Sprint Planning
- Sprint-status.yaml verified current — all Epic 13 stories (13.1/13.2/13.3) tracked as backlog; no story files yet
- `last_updated` bumped to 2026-04-18 with note "Epic 13 cycle begins, Story 13.0 pending creation"
- No issues surfaced — all 14 epics, 60+ stories tracked

### 2026-04-18T00:15:00Z — Phase 0.5: Retrospective Review & Story 13.0 prep
- Read Epic 12 retrospective (`epic-12-retro-2026-04-17.md`, 194 lines): 10 action items identified
- Read `deferred-work.md` open items: HIGH=0, MED=8 open (4 Epic-12 carry-forwards scoped to 12.5a/b/c + 12.2, 3 Epic-10 UI gaps, 1 infra), LOW~60+ across epics 1-12
- **Triage decision (codified in Story 13.0):**
  - INCLUDE: Action Item #1 (pre-flight env check rule), #2 (README-same-commit rule), #6 (zero `[Language = python]` compile-rule), #10 (PRD NFR addition)
  - INCLUDE as new Story 13.x creation: Action Item #5 / #9 (Python-less IRIS CI image + release gate)
  - DEFER with named trigger: Action Items #7, #8 (Story 12.4 resumption prerequisites)
  - OUT-OF-SCOPE: Action Items #3 (goes into Story 13.1 spec directly), #4 (goes into Story 13.2 spec directly)
  - LOW triage: walk `deferred-work.md` LOW list, resolve quick wins, keep-deferred with revisit triggers for rest (pattern from Story 12.0)

### 2026-04-18T00:30:00Z — Story 13.0 created
- **Story file:** `_bmad-output/implementation-artifacts/13-0-epic-12-deferred-cleanup.md` (6 ACs, 7 tasks + Task 0 pre-flight)
- **Sprint status:** `13-0-epic-12-deferred-cleanup: ready-for-dev`; `epic-13: in-progress`
- **Scope:** markdown + rules edits (research-first.md x2, iris-objectscript-basics.md x1, prd.md x1) + 21 LOW triage + deferred-work.md maintenance. No ObjectScript/Angular feature work; Task 5 may produce small code deletes/rename on dev judgment.
- **Next:** spawn `dev-13-0` agent via Agent tool with bypassPermissions mode

### 2026-04-18T01:00:00Z — Story 13.0 dev complete
- **Agent:** `dev-13-0` (general-purpose, bypassPermissions); total 1084925ms; 87 tool uses
- **Dev output — Task 0 probe (a) Python:** `ERROR: <OBJECT DISPATCH> 230 ... Failed to Load Python: Check CPF PythonRuntimeLibrary` (expected — self-application of new rule succeeded)
- **Dev output — Task 0 probe (b) `$ZF(-100)`:** `tSC=0` (success)
- **Dev output — Task 0 probe (c) `/_session`:** 200 OK with auth envelope
- **Triage outcome:** 3 resolved (`Pool.cls` docstring, `EncodeKeyForSort` dead-code in `Storage/ViewIndex.cls`, `TestPooledSubprocessReducesLatency` rename), 18 kept-deferred with named triggers, 0 escalated — matches Story 12.0 healthy envelope
- **Files modified:** 6 rule/docs/status files + 3 ObjectScript classes (Pool.cls, Storage/ViewIndex.cls, Test/ViewIndexHttpTest.cls) — all compiled clean (102ms)
- **Tests:** `ViewIndexTest` 8/8 and `ViewIndexHttpTest` 7/7 green post-change (including renamed test)
- **Status:** Story 13.0 review → spawn `cr-13-0` code review

### 2026-04-18T01:15:00Z — Story 13.0 code review complete
- **Agent:** `cr-13-0` (general-purpose, bypassPermissions); 332741ms; 33 tool uses
- **Findings:** 0 CRITICAL, 0 HIGH, 1 MEDIUM auto-resolved, 2 LOW dismissed as below-noise-floor
- **MED auto-resolved:** `research-first.md` numbered list was broken by an interposed paragraph between items 3 and 4 — fixed by relocating the "This rule supersedes..." concluding paragraph to after item 5, restoring unbroken 1→2→3→4→5 rendering
- **All 6 ACs verified satisfied:** research-first.md items 4+5 present, iris-objectscript-basics.md Python Distribution Rules subsection present, PRD NFR-M9 cross-referenced, triage 3/18/0 matches Story 12.0 envelope, 12.4-resumption section added
- **Code change validation:** Pool.cls docstring preserved class shape; ViewIndex.cls dead-code removal preserves semantics (remaining numeric/string branches cover all scalar cases); ViewIndexHttpTest rename clean (no executable code references old name)

### 2026-04-18T01:20:00Z — Story 13.0 committed
- **Commit:** `d745f94` — `feat(epic-13): Story 13.0 - Epic 12 Deferred Cleanup`
- **10 files, 569 insertions, 40 deletions**
- **Pushed:** `origin/main` (25241f1..d745f94)
- **Sprint status:** `13-0-epic-12-deferred-cleanup: review → done`

### 2026-04-18T01:30:00Z — Story 13.1 created
- **Story file:** `_bmad-output/implementation-artifacts/13-1-getting-started-guide-and-compatibility-matrix.md` (7 ACs, 5 tasks + Task 0 pre-flight probe)
- **Sprint status:** `13-1-getting-started-guide-and-compatibility-matrix: ready-for-dev`
- **Scope:** `documentation/getting-started.md` + `documentation/compatibility-matrix.md` + `README.md` updates (Documentation section, Roadmap bumps, JSRuntime Requirements subsection). Zero new code. Epic 12 retro AI #3 (compatibility-matrix JSRuntime state embed) + AI #2 (README-same-commit self-application) built into ACs.
- **Next:** spawn `dev-13-1` agent

### 2026-04-18T02:15:00Z — Story 13.1 dev complete
- **Agent:** `dev-13-1` (general-purpose, bypassPermissions); 749327ms; 55 tool uses
- **Files created:** `documentation/getting-started.md` (657 lines), `documentation/compatibility-matrix.md` (363 lines, 98 endpoint rows)
- **Compatibility matrix status counts:** 56 supported / 18 supported-with-caveat / 11 501-in-default-config / 13 out-of-scope — dev chose three-rows-per-endpoint format for JSRuntime-aware rows (None / Subprocess / Python-deferred) to make the Python non-ship visually distinct from "caveat"
- **Config-key correction:** story spec used hypothetical `JSRUNTIMEBACKEND` / `NODEPATH`; actual shipping code uses `JSRUNTIME` / `JSRUNTIMESUBPROCESSPATH` (verified against `src/IRISCouch/Config.cls` and existing `documentation/js-runtime.md`) — dev substituted actual keys into all new docs
- **Task 0 probe substitutions:** actual welcome envelope returns `version:"0.1.0"` with no `features` field (not the speculative `3.3.3`/`features:[...]` lead pre-authored); dev substituted verbatim dev-host output and logged the version deviation in the matrix `GET /` row as supported-with-caveat
- **Matrix-verification bugs discovered:** none — no new deferred-work entries
- **README edits:** Epic 12 row → `5/5 + 12.4 deferred | ~850 | — | Done`; Epic 13 row → `2/3 | — | — | In Progress`; new `## Documentation` section between Distribution and JS Runtime Requirements
- **Status:** Story 13.1 review → spawn `cr-13-1` code review

### 2026-04-18T02:30:00Z — Story 13.1 code review complete
- **Agent:** `cr-13-1` (general-purpose, bypassPermissions); 757632ms; 116 tool uses
- **Findings:** 0 CRITICAL, 0 HIGH, 2 MEDIUM auto-resolved, 2 LOW deferred
- **MEDs auto-resolved:** (1) ~45 test-method citations in the compat matrix were stale — reconciled against actual `*HttpTest.cls` classes; (2) matrix missed 7 CouchDB 3.x endpoint families (`_dbs_info`, `_all_docs/queries`, `_design_docs/queries`, `_view/{view}/queries`, `_index/_bulk_delete`, `_auto_purge`, design-doc attachments) + COPY reclassified `supported` → `out of scope with reason` (no handler exists)
- **Final matrix counts:** 74 supported / 12 supported-with-caveat / 10 501-default / 27 OOS — 123 rows total (up from dev's initial 98)
- **LOW deferred:** (1) render endpoints (`_show`/`_list`/`_update`/`_rewrite`) matrix-listed as 501 but actually return 404 (no dispatcher); (2) `_scheduler/*` and `_node/*` families collapsed into single rows
- **All 7 ACs verified.** Config-key correction (JSRUNTIME vs JSRUNTIMEBACKEND) confirmed against `Config.cls`. Probe output matches Dev Agent Record verbatim.

### 2026-04-18T02:40:00Z — Story 13.1 committed
- **Commit:** `0a849f8` — `feat(epic-13): Story 13.1 - Getting Started Guide & Compatibility Matrix`
- **7 files, 1427 insertions, 8 deletions**
- **Pushed:** `origin/main` (d745f94..0a849f8)
- **Sprint status:** `13-1-getting-started-guide-and-compatibility-matrix: review → done`

### 2026-04-18T02:45:00Z — Story 13.2 created
- **Story file:** `_bmad-output/implementation-artifacts/13-2-deviation-log-migration-playbook-and-troubleshooting-runbook.md` (4 ACs, 5 tasks + Task 0 deviation-audit)
- **Sprint status:** `13-2-deviation-log-migration-playbook-and-troubleshooting-runbook: ready-for-dev`
- **Scope:** `documentation/deviations.md` + `documentation/migration.md` + `documentation/troubleshooting.md` + cross-reference updates to compatibility-matrix.md / getting-started.md / README.md. Epic 12 retro AI #4 (JSRuntime failure modes) operationalized as AC #4 with 5 sub-scenarios. Zero new code.
- **Next:** spawn `dev-13-2` agent

### 2026-04-18T04:00:00Z — Story 13.2 dev complete
- **Agent:** `dev-13-2` (general-purpose, bypassPermissions); 972685ms; 60 tool uses
- **Files created:** `documentation/deviations.md` (367 lines), `documentation/migration.md` (567 lines), `documentation/troubleshooting.md` (735 lines)
- **Deviations logged:** 14 total (11 primary + 3 informational) — Epic 12 canonical 4 all present, 7 cross-epic deviations surfaced via Task 0 audit (server identity version, _security default object, continuous/eventsource OOS, validate_doc_update on replication writes, Windows Job Object memory-cap softness, render endpoints 404-not-501, /_utils Angular vs Fauxton)
- **Task 0 audit:** ~70 bulleted entries with per-item source citations (Epic 12 retro, deferred-work.md, cross-epic retros, compatibility-matrix.md, CouchDB replication protocol.rst); inclusion/exclusion rationale per item pasted verbatim into Dev Agent Record
- **No new deferred-work entries** — every candidate was already logged; no HIGH defects discovered during audit
- **Size overruns intentional:** all three docs exceeded soft ceilings (367 vs 150-250, 567 vs 300-450, 735 vs 200-350); dev prioritized operator utility over line budget per story intent
- **README edits:** Epic 13 Roadmap row → `3/3 | — | — | In Progress` (13.3 still pending); Documentation section expanded with 3 new entries
- **Status:** Story 13.2 review → spawn `cr-13-2` code review

### 2026-04-18T04:15:00Z — Story 13.2 code review complete
- **Agent:** `cr-13-2` (general-purpose, bypassPermissions); 608260ms; 98 tool uses
- **Findings:** 0 CRITICAL, **3 HIGH auto-resolved**, 1 MEDIUM auto-resolved, 1 LOW dismissed (size overrun), 1 INFO flagged (pre-existing gap, OOS)
- **HIGH auto-resolved:** (1) `GET /_metrics` → actual route is `/_prometheus` per Router.cls (3 uses corrected); (2) `GET /_node/_local/_config/jsruntime` endpoint doesn't exist — compat-matrix lists it OOS — replaced with `##class(IRISCouch.Config).Get(...)` terminal commands (4 uses); (3) `zwrite ^IRISCouch.Audit(<seq>)` — global doesn't exist, audit events go to IRIS `%SYS.Audit` via `$System.Security.Audit("IRISCouch", ...)` — replaced with Management Portal navigation (3 uses)
- **MED auto-resolved:** Checkpoint doc pattern `_local/_replicator_checkpoint_<session_id>` was invented; CouchDB spec uses `_local/{replication-id}` (hash of source/target/selector) — corrected in Symptoms/Diagnostic/Resolution; also fixed `subprocess_spawn_failed` → actual envelope `subprocess_error`
- **NFR-M4 assessment: SATISFIED** — 14 deviations cover all operator-observable differences; filter spot-check on 3 EXCLUDED items (Pool shim 12.5b, UI delete trigger, CI infra) all pass correctly
- **All 4 ACs verified after auto-resolution.** 5 JSRuntime sub-scenarios (AC #4) all present and diagnostically runnable

### 2026-04-18T04:25:00Z — Story 13.2 committed
- **Commit:** `d8267bc` — `feat(epic-13): Story 13.2 - Deviation Log, Migration Playbook & Troubleshooting Runbook`
- **9 files, 2230 insertions, 10 deletions**
- **Pushed:** `origin/main` (0a849f8..d8267bc)
- **Sprint status:** `13-2-deviation-log-migration-playbook-and-troubleshooting-runbook: review → done`

### 2026-04-18T04:30:00Z — Story 13.3 created
- **Story file:** `_bmad-output/implementation-artifacts/13-3-working-code-examples.md` (7 ACs, 10 tasks + Task 0 probe/audit)
- **Sprint status:** `13-3-working-code-examples: ready-for-dev`
- **Scope:** 6 examples under `examples/` (hello-document, pouchdb-sync, replicate-from-couchdb, mango-query, attachment-upload, jsruntime-subprocess-node) + `run-all.sh/ps1` harness + CI wiring decision (Option A extend workflows vs Option B defer with trigger) + cross-references to 3 docs + README Roadmap bump to Epic 13 Done. Language policy: curl-based (hello-doc, replicate, mango) + Node-based (pouchdb-sync, attachment, jsruntime-subprocess).
- **Dependencies verified:** `documentation/couchjs/couchjs-entry.js` present (7 files); `.github/workflows/ui-smoke.yml` exists but no examples CI yet
- **Next:** spawn `dev-13-3` agent — Epic 13 final story

### 2026-04-18T05:15:00Z — Story 13.3 dev complete
- **Agent:** `dev-13-3` (general-purpose, bypassPermissions); 1488003ms; 157 tool uses
- **Files created:** 27 under `examples/` tree — 6 example subdirectories + shared harness (`run-all.sh/ps1`) + root README + PNG fixture (987 bytes)
- **Dev-host smoke:** 5 pass + 1 skip (`replicate-from-couchdb` skipped because no CouchDB reachable on dev host; skip-path verified). 0 failures.
- **CI wiring decision: Option B (deferred).** `.github/workflows/ui-smoke.yml` already sits unrun pending self-hosted runner (Story 11.0 precedent); adding a second unrun workflow would not improve enforcement. New deferred-work entry names trigger "before α/β tagging gate"
- **In-the-wild bugs surfaced (2 — both escalated):**
  - **HIGH — trailing-slash routing:** `PUT /{db}/` returns 404 instead of creating DB (CouchDB 3.x accepts both). Broke PouchDB default construction. Worked around in example via `{ skip_setup: true }`; escalated to deferred-work for 2-line Router.cls fix
  - **MED — matrix lie on view query params:** `group`/`group_level`/`startkey`/`endkey`/`limit`/`skip` listed as "supported (12.2)" but silently ignored in `QueryEngine.Query`/`ViewHandler.ExtractQueryParams`. **Corrected matrix in same commit per NFR-I3**; example restructured to avoid unsupported params
- **Matrix cross-ref strategy:** Option B (new header section mapping examples→endpoint families) rather than per-row Example column (cheaper for 123 rows)
- **Sprint status:** `13-3-working-code-examples: ready-for-dev → review`; new field `last_story_submitted_for_review`
- **Status:** Story 13.3 review → spawn `cr-13-3` code review

## Epic 11: Admin UI - Design Documents & Security Views

### 2026-04-17T00:00:00Z — Story 11.5: Admin UI Static Hosting & Access Control
- **Create Story:** Story file pre-created via sprint change proposal at `11-5-admin-ui-handler-and-security.md`. Status: ready-for-dev.
- **Sprint status:** 11-5 added via correct-course, epic-11 reopened (in-progress)
- **Development:** Built Angular production bundle (main-I7CDCDFR.js 540KB, styles-KO5L73LS.css 3KB, ~135KB gzipped). New AdminUIHandler.cls (~200 lines): static file serving via %Stream.FileBinary.LinkToFile with 32KB chunked output, SPA fallback to index.html for deep links, 14-type MIME mapping, hashed-asset immutable caching, path traversal security. OnPreDispatch intercept in Router.cls for wildcard /_utils/* URL handling. IRISCouch_Admin role (without % prefix — IRIS reserves it) created idempotently in Installer.Install(). 10 ObjectScript HTTP integration tests. 2 Chrome DevTools screenshots. Manual curl verification of all endpoints.
- **Code Review:** 1 HIGH auto-resolved (argumented Quit in For loop — IsHashedAsset), 1 MEDIUM auto-resolved (unchecked StreamFile error status), 1 LOW deferred (AC text says %IRISCouch_Admin but role is IRISCouch_Admin). All ObjectScript classes compile clean.
- **Status:** review → done

### 2026-04-16T00:00:00Z — Epic 11 Retrospective
- **Retrospective saved:** `epic-11-retro-2026-04-16.md` (document-form, not party-mode dialogue since cycle was automated end-to-end)
- **Key findings:** All 6 Epic-10 action items completed or carried forward. Subscription-leak rule paid for itself twice. Task 0 pattern caught real backend gaps in both beta/gamma stories. `RevisionTree` pure-layout-helper + CDK-overlay pattern reusable. Chrome DevTools MCP caught one bug (deleted-leaf 404) invisible to specs.
- **5 new action items** (process, technical, infrastructure). Epic 11 retrospective complete. Sprint status: `epic-11-retrospective: optional → done`.

### 2026-04-15T00:00:00Z — Cycle resumed
- **Scope:** Epic 11, Stories 11.3 (in-progress) and 11.4 (backlog)
- **Sprint status (resume):** 11.0/11.1/11.2 done, 11.3 in-progress, 11.4 backlog
- **Phase 0 sprint planning:** Skipped — sprint-status.yaml current as of 2026-04-14, all Epic 11 stories tracked
- **Phase 0.5 retro review:** Skipped — Epic 10 retro already triaged into Story 11.0 (done)
- **Story 11.3 state at resume:** Story file present; backend Task 0 already RESOLVED in deferred-work; all expected UI files modified (TextAreaJson, unsaved-changes guard, design-doc-create-dialog, design-doc-detail/list, security-view, services); 4 screenshots present; story checkboxes still unchecked and Dev Agent Record empty — needs dev to verify/close out

### 2026-04-16T00:00:00Z — Story 11.4: Revision History View
- **Create Story:** Story file created at `11-4-revision-history-view.md` with 7 ACs and 6 tasks (backend regression test, RevisionTree primitive with CDK overlay popover, RevisionsService for client-side tree stitching, RevisionsViewComponent feature page, routing/sidenav, testing).
- **Development:** Dev discovered story-spec assumption was wrong — `?deleted_conflicts=true` was NOT yet implemented in the backend handler. Added `Storage.RevTree.GetDeletedConflicts()` + handler clause (4+4 lines) and 2 new ObjectScript HTTP tests (`TestRevisionTreeCombinedQuery`, `TestDeletedConflictsEmpty`). New UI: the `RevisionTree` couch-ui primitive (SVG-based, pure layout helper `computeRevisionTreeLayout`, CDK overlay popover), `IconHistoryComponent`, `RevisionsService` (N+1 forkJoin with 404-tolerance for deleted leaves), `RevisionsViewComponent` (two-slot subscription discipline), `revisionsMatcher` registered before `docDetailMatcher`, extended SideNav with optional `[docId]` input + disabled state. 599 → 669 specs (+70). 5 Chrome DevTools screenshots captured. All 7 ACs satisfied.
- **Code Review:** 2 MED auto-resolved: (1) routing regression upgraded from index-comparison to real `provideRouter` integration test with navigateByUrl + component assertion + negative-control reversed-order test; (2) Esc handler now defers to open CDK overlay popover (first Esc dismisses popover, second navigates back). 6 LOW deferred. 676/676 specs pass after fixes. ObjectScript classes compile clean.
- **Sprint status:** 11-4 moved backlog → ready-for-dev → review
- **Commit:** `cc5b14b` pushed to origin/main
- **Status:** done

### 2026-04-15T00:00:00Z — Story 11.3: Design Document & Security Editing
- **Create Story:** Story file pre-existing from prior partial run
- **Development:** Dev confirmed Task 0 backend (6 explicit `/:db/_design/...` UrlMap routes + composite-ID reassembly + 5 new ObjectScript tests) and the full UI editing UX (TextAreaJson primitive with line-numbers gutter and 4 visual states; design-doc detail edit/save/delete; design-doc create dialog; security view edit/save; ConfirmDialog `warning` variant; shared `unsavedChangesGuard`; service additions). All 8 ACs satisfied. 591 Angular specs pass; ObjectScript Task 0 tests pass individually; regression suites green. 4 Chrome DevTools screenshots captured. TESTING-CHECKLIST.md updated. Two Story 11.1 deferrals marked RESOLVED.
- **Code Review:** 1 MED auto-resolved (Esc key handler in edit mode for design-doc-detail and security-view, +8 specs). 5 LOW deferred (gutter scroll via `getElementById`, 405/404 tolerance in `TestPostDesignDocNotAllowed`, `Date.now()` titleId, delete-dialog `[innerHTML]`, idempotent invalid-event emit). 599 specs pass after fixes.
- **Commit:** `8b993ce` pushed to origin/main
- **Status:** done

## Epic 10: Admin UI - Core Experience

### 2026-04-14T10:00:00Z — Cycle started
- **Scope:** Epic 10, Stories 10.0 (deferred cleanup) through 10.7
- **Sprint status:** All Epic 10 stories at `backlog`, epic at `backlog`

### 2026-04-14T10:00:00Z — Phase 0: Sprint Planning
- Sprint-status.yaml confirmed current (14 epics, 55+ stories tracked)
- Epic 10 stories confirmed: 10.1-10.7 (plus 10.0 cleanup from retro)
- No issues surfaced

### 2026-04-14T17:00:00Z — Story 10.7: Error Handling, Accessibility & Cross-Browser Verification
- **Create Story:** Story file created at `10-7-error-handling-accessibility-and-cross-browser-verification.md`
- **Development:** All 8 tasks completed. Network error handling, LiveAnnouncer navigation announcements, keyboard audit, WCAG contrast fix (warn #B57B21→#8B6914), reduced-motion audit, prohibited patterns audit (clean), TESTING-CHECKLIST.md created. 26 new tests (422 total). 125.12KB gzip.
- **Code Review:** 2 patches auto-resolved (DataTable Enter key test, SideNav arrow-key assertion). 2 deferred (duplicate error string/handler). 423 tests after fixes.
- **Commit:** `ddaad2c` pushed to origin/main
- **Status:** done

### 2026-04-14T16:00:00Z — Story 10.6: Document Detail View
- **Create Story:** Story file created at `10-6-document-detail-view.md`
- **Development:** All 4 tasks completed. JsonDisplay (custom tokenizer, syntax coloring), document detail with header/badges/attachments/conflicts/404. 46 new tests (395 total). 124.91KB gzip.
- **Code Review:** 4 patches auto-resolved (copy raw JSON fidelity, conflict subscription leak, attachment URL, conflict fetch test). 1 deferred (design doc double-encoding). 396 tests after fixes.
- **Commit:** `43a9be8` pushed to origin/main
- **Status:** done

### 2026-04-14T15:00:00Z — Story 10.5: Document List View with Filtering & Pagination
- **Create Story:** Story file created at `10-5-document-list-view-with-filtering-and-pagination.md`
- **Development:** All 5 tasks completed. DocumentService, Pagination component, document list with filter (150ms debounce, prefix matching), startkey-based pagination, [design]/[deleted] badges, URL deep-linking. 62 new tests (345 total). 122.37KB gzip.
- **Code Review:** 4 patches auto-resolved (dead import, stale request cancel, error display, Esc key handler). 2 LOW deferred. 349 tests after fixes.
- **Commit:** `e4375c3` pushed to origin/main
- **Status:** done

### 2026-04-14T14:00:00Z — Story 10.4: Database List View with Create & Delete
- **Create Story:** Story file created at `10-4-database-list-view-with-create-and-delete.md`
- **Development:** All 7 tasks completed. DatabaseService, DataTable (cdk-table), EmptyState, ConfirmDialog (CDK FocusTrap, 3 variants), PageHeader (fetched-at, loading bar), database list feature. 95 new tests (283 total). 116.10KB gzip.
- **Code Review:** 1 MED auto-resolved (PageHeader OnChanges interface). 1 MED deferred (missing delete UI trigger in template). 
- **Commit:** `d593ad3` pushed to origin/main
- **Status:** done

### 2026-04-14T13:00:00Z — Story 10.3: AppShell, Navigation & Login
- **Create Story:** Story file created at `10-3-appshell-navigation-and-login.md`
- **Development:** All 9 tasks completed. Auth service, API client, 401 interceptor, auth guard, AppShell, SideNav (CDK FocusKeyManager), Breadcrumb, ErrorDisplay, LoginForm, ShortcutOverlay, routing. 85 new tests (188 total). 100.75KB gzip.
- **Code Review:** 1 HIGH + 4 MED auto-resolved (nested subscribe, overlay leak, SideNav route matching, a11y attrs). 3 LOW deferred.
- **Commit:** `622f1ec` pushed to origin/main
- **Status:** done

### 2026-04-14T12:00:00Z — Story 10.2: Core UI Components
- **Create Story:** Story file created at `10-2-core-ui-components.md`
- **Development:** All 7 tasks completed. 5 components (Button, IconButton, Badge, TextInput, CopyButton) + axe-core test utils + barrel export. 58 new tests, 103 total. 60.52KB gzip build.
- **Code Review:** 2 HIGH + 2 MED auto-resolved (TextInput id timing, barrel export leak, hardcoded hex, CopyButton OnDestroy). 3 LOW deferred.
- **Commit:** `26bba59` pushed to origin/main
- **Status:** done

### 2026-04-14T11:00:00Z — Story 10.1: Angular Scaffold, Design Tokens & Icon System
- **Create Story:** Story file created at `10-1-angular-scaffold-design-tokens-and-icon-system.md`
- **Development:** All 8 tasks completed. Angular 18 scaffold with CDK, tokens.css (33 tokens), global.css, JetBrains Mono WOFF2 (21KB), 20 Lucide icon components, HTML config. 45/45 tests pass, 60KB gzip build.
- **Code Review:** CLEAN — 0 HIGH/MED. 3 LOW deferred (OnPush, signal inputs, font weight 500).
- **Commit:** `e09eec4` pushed to origin/main
- **Status:** done

### 2026-04-14T10:30:00Z — Story 10.0: Epic 9 Deferred Cleanup
- **Create Story:** Story file created at `10-0-epic-9-deferred-cleanup.md`
- **Development:** All 3 tasks completed. Security.Events rule added, $Horolog→$ZTimeStamp fixed in 3 locations, 43 deferred items triaged. 20/20 tests pass.
- **Code Review:** CLEAN — 0 issues. 1 LOW deferred (pre-existing JWT $Horolog).
- **Commit:** `e6949b3` pushed to origin/main
- **Status:** done

### 2026-04-14T10:05:00Z — Phase 0.5: Retrospective Review & Story 10.0
- Epic 9 retrospective reviewed: 2 "Must Do" action items triaged
- Item 1 (Security.Events rule): Include in 10.0
- Item 2 ($Horolog vs UTC): Include in 10.0 (investigate + document/fix)
- 44 deferred work items: All ObjectScript backend, none blocking Epic 10
- Story 10.0 created: `10-0-epic-9-deferred-cleanup.md`
- Epic 10 status: `in-progress`

## Epic 8: Replication Protocol

### 2026-04-13T00:00:00Z — Cycle started
- **Scope:** Epic 8, Stories 8.0 (deferred cleanup) through 8.5
- **Sprint status:** All Epic 8 stories at `backlog`

### 2026-04-13T00:00:00Z — Phase 0: Sprint Planning
- Sprint-status.yaml confirmed current (14 epics, 55+ stories tracked)
- Epic 8 stories confirmed: 8.1-8.5 (plus 8.0 cleanup from retro)
- No issues surfaced

## Epic 9: Observability & Audit Trail

### 2026-04-14T00:00:00Z — Cycle started
- **Scope:** Epic 9, Stories 9.0 (deferred cleanup) through 9.3
- **Sprint status:** All Epic 9 stories at `backlog`

### 2026-04-14T00:00:00Z — Phase 0: Sprint Planning
- Sprint-status.yaml confirmed current (14 epics tracked)
- Epic 9 stories confirmed: 9.1-9.3 (plus 9.0 cleanup from retro)
- No issues surfaced

### 2026-04-14T01:30:00Z — Story 9.3: Operational Resilience & Data Durability
- **Create Story:** Story file created at `9-3-operational-resilience-and-data-durability.md`
- **Development:** All 7 tasks completed. 2 new files (Util/Log.cls, ResilienceTest.cls), 5 modified (DocumentEngine logging, Manager logging, Error logging, Config docs, Installer docs). 7 new tests, 0 regressions.
- **Code Review:** 1 MEDIUM auto-resolved (missing changes feed rollback assertion). 1 LOW deferred.
- **Commit:** `185af5a` pushed to origin/main
- **Status:** done

### 2026-04-14T02:00:00Z — Epic 9 Complete
- All 4 stories done (9.0-9.3). Epic 9 status set to `done`.

### 2026-04-14T01:00:00Z — Story 9.2: Audit Event Emission
- **Create Story:** Story file created at `9-2-audit-event-emission.md`
- **Development:** All 8 tasks completed. 1 new Audit class (Emit.cls with EnsureEvents), 2 test classes (17+3 tests), 5 production files modified (DocumentEngine 6 methods, AuthHandler, Router, SecurityHandler, Manager). 0 regressions.
- **Code Review:** 2 MEDIUM auto-resolved (missing UserWrite on _users delete paths). 2 LOW deferred.
- **Commit:** `2126bfb` pushed to origin/main
- **Status:** done

### 2026-04-14T00:30:00Z — Story 9.1: Prometheus / OpenTelemetry Metrics Endpoint
- **Create Story:** Story file created at `9-1-prometheus-opentelemetry-metrics-endpoint.md`
- **Development:** All 7 tasks completed. 3 new Metrics classes (Collector, Record, Endpoint), 2 test classes (11+3 tests), Router modified (32 wrappers + OnPreDispatch + route). 0 regressions.
- **Code Review:** 1 HIGH + 2 MEDIUM auto-resolved (histogram double-counting, security-denied metrics, test assertions). 1 LOW deferred.
- **Commit:** `48d82a4` pushed to origin/main
- **Status:** done

### 2026-04-14T00:10:00Z — Story 9.0: Epic 8 Deferred Cleanup
- **Create Story:** Story file created at `9-0-epic-8-deferred-cleanup.md`
- **Development:** All 5 tasks completed. 3 files modified (DocumentEngine hook reorder, Database timestamp+cleanup, DatabaseTest +1 test). 0 regressions.
- **Code Review:** CLEAN. 0 critical/high/medium. 1 pre-existing LOW deferred (timezone).
- **Commit:** `96dad9b` pushed to origin/main
- **Status:** done

### 2026-04-14T00:05:00Z — Phase 0.5: Retrospective Review & Story 9.0
- Epic 8 retrospective found: `epic-8-retro-2026-04-13.md`
- Triaged all action items:
  - **Included in 9.0:** Fix SaveDeleted _users hook ordering (#1), fix ISO-8601 timestamp (#2), add status checking to Database.Delete() (#3)
  - **Deferred:** Response.Binary() utility (#4) — LOW, not blocking
  - **Dropped:** None
- Story 9.0 created: `9-0-epic-8-deferred-cleanup.md`
- Epic 9 status updated to `in-progress`

---

### 2026-04-13T04:00:00Z — Epic 8 Complete & Retrospective
- Manual HTTP verification: 25/25 curl tests pass (local docs, _revs_diff, _bulk_get, replication, _replicator)
- Interactive retrospective conducted with full party mode
- Codebase audit: 4 pre-existing violations found, documented for Story 9.0
- 9 new project rules codified from code review patterns
- IRIS audit system researched: $System.Security.Audit() + %SYS.Audit:List pattern documented
- Retro document: `epic-8-retro-2026-04-13.md`
- Epic 8 status: done, retrospective: done

### 2026-04-13T03:30:00Z — Story 8.5: _replicator Database & Continuous Replication Jobs
- **Create Story:** Story file created at `8-5-replicator-database-and-continuous-replication-jobs.md`
- **Development:** All 7 tasks completed. 1 new Replication class (Manager), 2 test classes, 2 modified production classes (DocumentEngine hooks, Replicator stats). 20 new tests pass, 0 regressions.
- **Code Review:** 1 HIGH + 2 MEDIUM auto-resolved (delete hook ordering, ISO timestamp format, JOB post-commit). 3 LOW deferred.
- **Commit:** `a824308` pushed to origin/main
- **Status:** done

### 2026-04-13T02:30:00Z — Story 8.4: Bidirectional Replication Protocol
- **Create Story:** Story file created at `8-4-bidirectional-replication-protocol.md`
- **Development:** All 7 tasks completed. 4 new Replication classes (ReplicationId, Checkpoint, HttpClient, Replicator), 4 test classes. 28 new tests pass, 0 regressions.
- **Code Review:** 1 HIGH + 3 MEDIUM auto-resolved (storage encapsulation, checkpoint error handling, corruption detection, attachment fetch). 5 LOW deferred.
- **Commit:** `2a4b453` pushed to origin/main
- **Status:** done

### 2026-04-13T01:30:00Z — Story 8.3: Replication-Ready Bulk Get
- **Create Story:** Story file created at `8-3-replication-ready-bulk-get.md`
- **Development:** All 5 tasks completed. 1 file modified (BulkHandler.cls +attachments=true), 2 created (BulkGetReplicationTest.cls 8 tests, BulkGetReplicationHttpTest.cls 5 tests). 0 regressions.
- **Code Review:** 1 HIGH + 2 MEDIUM auto-resolved (chunked Base64 encoding fix, iterator mutation fix, string limit fix). 2 LOW deferred.
- **Commit:** `1459eff` pushed to origin/main
- **Status:** done

### 2026-04-13T01:00:00Z — Story 8.2: Revision Difference Calculation
- **Create Story:** Story file created at `8-2-revision-difference-calculation.md`
- **Development:** All 5 tasks completed. 2 files modified (ReplicationHandler.cls +HandleRevsDiff, Router.cls +route+wrapper), 2 created (RevsDiffTest.cls 6 tests, RevsDiffHttpTest.cls 5 tests). 0 regressions.
- **Code Review:** CLEAN. 0 critical/high/medium. 1 LOW deferred (possible_ancestors generation filtering).
- **Commit:** `98db6c8` pushed to origin/main
- **Status:** done

### 2026-04-13T00:30:00Z — Story 8.1: Local Documents & Replication Checkpoints
- **Create Story:** Story file created at `8-1-local-documents-and-replication-checkpoints.md`
- **Development:** All 8 tasks completed. 4 files created (Storage/Local.cls, API/ReplicationHandler.cls, Test/LocalDocTest.cls, Test/LocalDocHttpTest.cls), 2 modified (Router.cls routes+wrappers, Database.cls deletion cleanup). 15 new tests pass, 0 regressions.
- **Code Review:** PASSED. 0 critical/high. 2 MEDIUM auto-resolved (response utility consistency). 3 LOW deferred.
- **Commit:** `ff65e60` pushed to origin/main
- **Status:** done

### 2026-04-13T00:10:00Z — Story 8.0: Epic 7 Deferred Cleanup
- **Create Story:** Story file created at `8-0-epic-7-deferred-cleanup.md`
- **Development:** All 5 tasks completed. 3 files modified (iris-objectscript-basics.md rules, DocumentEngine.cls _users hooks, ReplicationTest.cls +2 tests). All classes compile. 0 regressions.
- **Code Review:** PASSED. 0 critical/high. 1 MEDIUM auto-resolved (missing MangoIndex re-index after _users body mod). 4 LOW dismissed.
- **Commit:** `3e71d94` pushed to origin/main
- **Status:** done

### 2026-04-13T00:05:00Z — Phase 0.5: Retrospective Review & Story 8.0
- Epic 7 retrospective found: `epic-7-retro-2026-04-14.md`
- Triaged all action items:
  - **Included in 8.0:** Add irislib/ source rule (#1), add subagent source refs rule (#2), verify SaveWithHistory _users hooks (#3)
  - **Deferred:** JWT clock skew (#4), username colons (#5), GetSecret race (#6), proxy auth test gap (#7), CleanupTestUser swallows exceptions (#8), hardcoded infra roles (#9)
  - **Dropped:** None
- Also reviewed deferred-work.md — all existing items low/medium, none blocking Epic 8
- Story 8.0 created: `8-0-epic-7-deferred-cleanup.md`
- Epic 8 status updated to `in-progress`

---

## Epic 1: Project Foundation & Server Identity

### 2026-04-12T11:48:40Z — Cycle started
- **Scope:** Epic 1, Stories 1.1 through 1.5
- **Sprint status:** All stories at `backlog`

### 2026-04-12T11:48:40Z — Phase 0: Sprint Planning
- Sprint-status.yaml already current (generated earlier this session)
- 14 epics, 55 stories tracked
- All Epic 1 stories confirmed in sprint-status.yaml

### 2026-04-12T11:48:40Z — Phase 0.5: Retrospective Review
- No previous epic (Epic 1 is first). Skipping Story 1.0 creation.

### 2026-04-12T12:00:00Z — Story 1.1: Configuration System & Package Scaffold
- **Create Story:** Story file created at `1-1-configuration-system-and-package-scaffold.md`
- **Development:** All 8 tasks completed. 7 files created (module.xml, Config.cls, Error.cls, Response.cls, Request.cls, ConfigTest.cls, API/.gitkeep). All classes compile cleanly. 6 test scenarios pass.
- **Code Review:** PASSED. 0 critical/high. 5 low/medium items deferred to `deferred-work.md`.
- **Commit:** `aeb49ef` pushed to origin/main
- **Status:** done

### 2026-04-12T13:00:00Z — Story 1.2: HTTP Router & CouchDB Welcome Endpoint
- **Create Story:** Story file created at `1-2-http-router-and-couchdb-welcome-endpoint.md`
- **Development:** All 4 tasks completed. 3 files created (Router.cls, ServerHandler.cls, RouterTest.cls). .gitkeep deleted. All classes compile cleanly. 5 tests pass, 0 regressions.
- **Code Review:** PASSED. 0 critical/high. 2 medium auto-resolved (dedup HandleWelcome logic, fix catch block %Status). 1 deferred (metrics wrapper stub).
- **Commit:** `a9bd50e` pushed to origin/main
- **Status:** done

### 2026-04-12T14:00:00Z — Story 1.3: UUID Generation Endpoint
- **Create Story:** Story file created at `1-3-uuid-generation-endpoint.md`
- **Development:** All 5 tasks completed. 2 files created (UUID.cls, UUIDTest.cls), 2 modified (Router.cls, ServerHandler.cls). 14 tests pass, 0 regressions.
- **Code Review:** PASSED. 0 critical/high. 1 medium auto-resolved (max count cap at 1000 + integer validation). 0 deferred.
- **Commit:** `edd675b` pushed to origin/main
- **Status:** done

### 2026-04-12T15:00:00Z — Story 1.4: Error Envelope & Consistent Error Responses
- **Create Story:** Story file created at `1-4-error-envelope-and-consistent-error-responses.md`
- **Development:** All 5 tasks completed. 1 file created (ErrorEnvelopeTest.cls), 2 modified (Error.cls, Router.cls). 20 tests pass, 0 regressions.
- **Code Review:** PASSED. 0 critical/high. 1 medium auto-resolved (Router catch block uses RenderInternal). 5 deferred.
- **Commit:** `81acb41` pushed to origin/main
- **Status:** done

### 2026-04-12T16:00:00Z — Story 1.5: Manual ObjectScript Import Installation
- **Create Story:** Story file created at `1-5-manual-objectscript-import-installation.md`
- **Development:** All 5 tasks completed. 2 files created (Installer.cls, InstallerTest.cls), 1 modified (README.md). 25 tests pass, 0 regressions.
- **Code Review:** PASSED. 0 critical/high. 2 medium auto-resolved (README clone URL, stale status section). 0 deferred.
- **Commit:** `3f474a2` pushed to origin/main
- **Status:** done

### 2026-04-12T16:30:00Z — Epic 1 Complete
- All 5 stories done. Epic status set to `done`.
- **Total files created:** 13 ObjectScript classes + module.xml + README updates
- **Total tests:** 25 passing, 0 failures across 5 test classes
- **Deferred items:** ~10 items in deferred-work.md (all low/medium severity)

### 2026-04-12T17:00:00Z — Hotfix: Router Dispatch Fix
- **Issue:** Manual HTTP testing revealed all routes returned 404. Two root causes:
  1. `Page()` override replaced `%CSP.REST` dispatch mechanism entirely
  2. UrlMap `Call="ClassName:Method"` cross-class syntax doesn't work
- **Fix:** Local wrapper methods for Call dispatch, `ReportHttpStatusCode` override for custom 404/error JSON
- **Commit:** `b177076` pushed to origin/main
- **Verified:** All 4 endpoint scenarios working via curl (welcome, uuids, 404, 405)

### 2026-04-12T17:30:00Z — Retrospective Complete
- Interactive retrospective conducted with user
- Retro document: `epic-1-retro-2026-04-12.md`
- 3 action items for Story 2.0, 3 deferred items, 3 lessons codified in memory
- Webapp installed and verified live at `/iris-couch/`
- Epic 1 retrospective status: done

---

## Epic 2: Database Lifecycle Management

### 2026-04-12T18:00:00Z — Cycle started
- **Scope:** Epic 2, Stories 2.0 (deferred cleanup) through 2.3
- **Sprint status:** All Epic 2 stories at `backlog`

### 2026-04-12T18:00:00Z — Phase 0: Sprint Planning
- Sprint-status.yaml confirmed current (14 epics, 55 stories tracked)
- Epic 2 stories confirmed: 2.1, 2.2, 2.3 (plus 2.0 cleanup from retro)
- No issues surfaced

### 2026-04-12T18:05:00Z — Phase 0.5: Retrospective Review & Story 2.0
- Epic 1 retrospective found: `epic-1-retro-2026-04-12.md`
- Triaged all action items:
  - **Included in 2.0:** Fix ServerHandler catch blocks (RenderInternal), HTTP integration test infrastructure, parameterized route verification
  - **Deferred:** Config.Get/Set/GetAll issues (4 items), Request.ReadBody size limit, metrics wrapper, Error.Render missing %response
  - **Dropped:** None
- Story 2.0 created: `2-0-epic-1-deferred-cleanup.md`
- Epic 2 status updated to `in-progress`

### 2026-04-12T18:30:00Z — Story 2.0: Epic 1 Deferred Cleanup
- **Create Story:** Story file created at `2-0-epic-1-deferred-cleanup.md`
- **Development:** All 4 tasks completed. 1 file modified (ServerHandler.cls), 1 created (HttpIntegrationTest.cls). 30 tests pass (26 existing + 4 new), 0 regressions.
- **Code Review:** PASSED. 0 critical/high/medium. 3 low items deferred (hardcoded creds, hardcoded server/port, no early-return guard in tests).
- **Commit:** `af024d2` pushed to origin/main
- **Status:** done

### 2026-04-12T19:00:00Z — Story 2.1: Create and Delete Databases
- **Create Story:** Story file created at `2-1-create-and-delete-databases.md`
- **Development:** All 6 tasks completed. 4 files created (Storage/Database.cls, API/DatabaseHandler.cls, Test/DatabaseTest.cls, Test/DatabaseHttpTest.cls), 3 modified (Router.cls, Error.cls, HttpIntegrationTest.cls). 41 tests pass (30 existing + 11 new), 0 regressions.
- **Code Review:** PASSED. 2 medium auto-resolved (hardcoded slugs replaced with constants, duplicate reason string fixed). 2 low deferred (race condition, name length limit).
- **Commit:** `d19bc66` pushed to origin/main
- **Status:** done

### 2026-04-12T20:00:00Z — Story 2.2: List Databases and Retrieve Metadata
- **Create Story:** Story file created at `2-2-list-databases-and-retrieve-metadata.md`
- **Development:** All 7 tasks completed. 6 files modified (Storage/Database.cls, DatabaseHandler.cls, Router.cls, DatabaseTest.cls, DatabaseHttpTest.cls, HttpIntegrationTest.cls). 49 tests pass (41 existing + 8 new), 0 regressions.
- **Code Review:** PASSED. 0 critical/high/medium. 4 low dismissed as noise. No auto-resolves or deferrals.
- **Commit:** `7d07cd0` pushed to origin/main
- **Status:** done

### 2026-04-12T21:00:00Z — Story 2.3: Database Maintenance Operations
- **Create Story:** Story file created at `2-3-database-maintenance-operations.md`
- **Development:** All 6 tasks completed. 6 files modified (Storage/Database.cls, DatabaseHandler.cls, Router.cls, DatabaseTest.cls, DatabaseHttpTest.cls, HttpIntegrationTest.cls). 57 tests pass (49 existing + 8 new), 0 regressions.
- **Code Review:** PASSED. 2 medium auto-resolved (direct Write replaced with Response.JSON, integer validation added). 2 low dismissed. 0 deferred.
- **Commit:** `2de7eb3` pushed to origin/main
- **Status:** done

### 2026-04-12T21:30:00Z — Epic 2 Complete
- All 4 stories done (2.0, 2.1, 2.2, 2.3)
- **Total files created:** 4 new classes (Storage/Database, API/DatabaseHandler, Test/DatabaseTest, Test/DatabaseHttpTest)
- **Total files modified:** 5 existing classes (Router, ServerHandler, Error, HttpIntegrationTest, Response)
- **Total tests:** 57 passing, 0 failures across 8 test classes
- **Deferred items:** 5 items in deferred-work.md (all low severity)

### 2026-04-12T22:00:00Z — Retrospective Complete
- Retro document: `epic-2-retro-2026-04-12.md`
- Epic 1 retro action items: 3/3 completed (all fulfilled in Story 2.0)
- 3 action items for Epic 3, 4 deferred items, 5 lessons codified
- Epic 2 retrospective status: done

---

## Epic 3: Document Storage & Revision Control

### 2026-04-12T23:00:00Z — Cycle started
- **Scope:** Epic 3, Stories 3.0 (deferred cleanup) through 3.6
- **Sprint status:** All Epic 3 stories at `backlog`

### 2026-04-12T23:00:00Z — Phase 0: Sprint Planning
- Sprint-status.yaml confirmed current (14 epics, 55+ stories tracked)
- Epic 3 stories confirmed: 3.1-3.6 (plus 3.0 cleanup from retro)
- No issues surfaced

### 2026-04-12T23:05:00Z — Phase 0.5: Retrospective Review & Story 3.0
- Epic 2 retrospective found: `epic-2-retro-2026-04-12.md`
- Triaged all action items:
  - **Included in 3.0:** Database lifecycle integration test, doc_del_count tracking, disk_size verification
  - **Deferred:** Config-driven test infra, early-return guard, name length validation, race condition, all 15 deferred-work.md items
  - **Dropped:** None
- Story 3.0 created: `3-0-epic-2-deferred-cleanup.md`
- Epic 3 status updated to `in-progress`

### 2026-04-12T23:30:00Z — Story 3.0: Epic 2 Deferred Cleanup
- **Create Story:** Story file created at `3-0-epic-2-deferred-cleanup.md`
- **Development:** All 4 tasks completed. 2 files modified (Storage/Database.cls, DatabaseHttpTest.cls). 49 tests pass (48 existing + 1 new), 0 regressions.
- **Code Review:** PASSED. 0 critical/high/medium. 3 items dismissed as noise. 0 deferred.
- **Commit:** `417817f` pushed to origin/main
- **Status:** done

### 2026-04-12T24:00:00Z — Story 3.1: Single Document Create & Read
- **Create Story:** Story file created at `3-1-single-document-create-and-read.md`
- **Development:** All 9 tasks completed. 7 files created (Storage/Document.cls, Storage/RevTree.cls, Core/RevHash.cls, Core/DocumentEngine.cls, API/DocumentHandler.cls, Test/DocumentTest.cls, Test/DocumentHttpTest.cls), 1 modified (Router.cls). 66 tests pass (49 existing + 17 new), 0 regressions.
- **Code Review:** PASSED. 1 high auto-resolved (TROLLBACK guard in DocumentEngine), 1 medium auto-resolved (JSON parse validation in HandlePost/HandlePut). 2 low deferred (parent rev validation, doc ID underscore prefix).
- **Commit:** `ec4a679` pushed to origin/main
- **Status:** done

### 2026-04-13T01:00:00Z — Story 3.2: Document Update, Delete & Optimistic Concurrency
- **Create Story:** Story file created at `3-2-document-update-delete-and-optimistic-concurrency.md`
- **Development:** All 8 tasks completed. 4 files modified (DocumentHandler.cls, DocumentEngine.cls, RevTree.cls, Router.cls), 2 files created (DocumentUpdateTest.cls, DocumentUpdateHttpTest.cls). 86 tests pass (75 existing + 11 new), 0 regressions.
- **Code Review:** PASSED. 1 high auto-resolved (_deleted:true on non-existent doc guard), 1 medium auto-resolved (D marker before AddChild to fix RecomputeWinner ordering). 1 low deferred (double-delete doc_count negative).
- **Commit:** `dd3068f` pushed to origin/main
- **Status:** done

### 2026-04-13T02:00:00Z — Story 3.3: Revision Tree & Conflict Management
- **Create Story:** Story file created at `3-3-revision-tree-and-conflict-management.md`
- **Development:** All 9 tasks completed. 2 files modified (RevTree.cls, DocumentHandler.cls), 2 files created (RevTreeTest.cls, RevTreeHttpTest.cls). 97 tests pass (86 existing + 11 new), 0 regressions. Fixed latent RecomputeWinner tiebreak bug (> to ] operator).
- **Code Review:** PASSED. 1 medium auto-resolved (open_revs 404 for non-existent docs), 1 medium deferred (missing test coverage for deleted/missing revs_info statuses). 3 low dismissed.
- **Commit:** `4ffcb09` pushed to origin/main
- **Status:** done

### 2026-04-13T03:00:00Z — Story 3.4: Bulk Document Operations
- **Create Story:** Story file created at `3-4-bulk-document-operations.md`
- **Development:** All 6 tasks completed. 2 files modified (DocumentHandler.cls, Router.cls), 2 files created (BulkOpsTest.cls, BulkOpsHttpTest.cls). 106 tests pass (97 existing + 9 new), 0 regressions.
- **Code Review:** PASSED. 1 medium auto-resolved (added missing new_edits=false HTTP test). 2 deferred (empty id handling, repetitive error construction). 2 dismissed.
- **Commit:** `7903979` pushed to origin/main
- **Status:** done

### 2026-04-13T04:00:00Z — Story 3.5: Replication-Format Bulk Writes
- **Create Story:** Story file created at `3-5-replication-format-bulk-writes.md`
- **Development:** All 6 tasks completed. 3 files modified (RevTree.cls, DocumentEngine.cls, DocumentHandler.cls), 2 files created (ReplicationTest.cls, ReplicationHttpTest.cls), 1 test updated. 112+ tests pass (7 new + 1 updated), 0 regressions.
- **Code Review:** PASSED. 1 high auto-resolved (Quit/While dual HTTP response bug in HandleBulkDocs). 1 low deferred (race condition on doc_count). 2 dismissed.
- **Commit:** `840555e` pushed to origin/main
- **Status:** done

### 2026-04-13T05:00:00Z — Story 3.6: All Documents View
- **Create Story:** Story file created at `3-6-all-documents-view.md`
- **Development:** All 8 tasks completed. 3 files modified (DocumentHandler.cls, Router.cls, Document.cls), 2 files created (AllDocsTest.cls, AllDocsHttpTest.cls). 122 tests pass (112+ existing + 10 new), 0 regressions.
- **Code Review:** PASSED. 1 medium auto-resolved (storage encapsulation — direct global access replaced with CountNonDeleted). 1 low deferred (local_seq missing field). 2 dismissed.
- **Commit:** `4e97c02` pushed to origin/main
- **Status:** done

### 2026-04-13T05:30:00Z — Epic 3 Complete
- All 7 stories done (3.0, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6)
- **Total files created:** 14 new classes (Storage/Document, Storage/RevTree, Core/RevHash, Core/DocumentEngine, API/DocumentHandler, plus 9 test classes)
- **Total files modified:** Router.cls, Error.cls, Storage/Database.cls, HttpIntegrationTest, deferred-work.md
- **Total tests:** 122 passing, 0 failures across 20 test classes
- **Deferred items:** ~9 new items added to deferred-work.md (all low/medium severity)

### 2026-04-13T06:00:00Z — Retrospective Complete
- Retro document: `epic-3-retro-2026-04-13.md`
- Epic 2 retro action items: 3/3 completed (all fulfilled in Story 3.0)
- 3 action items for Epic 4, 6 deferred items, 6 lessons codified
- Storage encapsulation feedback saved to memory
- Epic 3 retrospective status: done

---

## Epic 4: Real-Time Change Tracking

### 2026-04-12T07:00:00Z — Cycle started
- **Scope:** Epic 4, Stories 4.0 (deferred cleanup) through 4.3
- **Sprint status:** All Epic 4 stories at `backlog`

### 2026-04-12T07:00:00Z — Phase 0: Sprint Planning
- Sprint-status.yaml confirmed current (14 epics, 56+ stories tracked)
- Epic 4 stories confirmed: 4.1, 4.2, 4.3 (plus 4.0 cleanup from retro)
- No issues surfaced

### 2026-04-12T07:05:00Z — Phase 0.5: Retrospective Review & Story 4.0
- Epic 3 retrospective found: `epic-3-retro-2026-04-13.md`
- Triaged all action items:
  - **Included in 4.0:** Split DocumentHandler, Quit-in-loop guideline, GetRevsInfo test coverage, 5 storage encapsulation violations
  - **Deferred:** 6 items (doc_count negative, race condition, local_seq omitted, empty id, repetitive construction, underscore prefix)
  - **Dropped:** None
- Story 4.0 created: `4-0-epic-3-deferred-cleanup.md`
- Epic 4 status updated to `in-progress`

### 2026-04-12T07:30:00Z — Story 4.0: Epic 3 Deferred Cleanup
- **Create Story:** Story file created at `4-0-epic-3-deferred-cleanup.md`
- **Development:** All 10 tasks completed. 3 files created (Storage/Changes.cls, API/BulkHandler.cls, API/AllDocsHandler.cls), 5 modified (RevTree.cls, DocumentEngine.cls, DocumentHandler.cls, Router.cls, RevTreeTest.cls). DocumentHandler reduced 1009→396 lines. 124 tests pass (122 existing + 2 new), 0 regressions.
- **Code Review:** PASSED. 0 critical/high/medium. 3 pre-existing low items deferred. 0 auto-resolved.
- **Commit:** `7c58b1b` pushed to origin/main
- **Status:** done

### 2026-04-12T08:30:00Z — Story 4.1: Normal Changes Feed
- **Create Story:** Story file created at `4-1-normal-changes-feed.md`
- **Development:** All 6 tasks completed. 3 files created (API/ChangesHandler.cls, Test/ChangesTest.cls, Test/ChangesHttpTest.cls), 2 modified (Storage/Changes.cls, Router.cls). 140 tests pass (124 existing + 16 new), 0 regressions.
- **Code Review:** PASSED. 1 high auto-resolved (inner catch Quit → Return for POST parse error), 1 medium auto-resolved (descending pending count fix). 1 low deferred (missing unsupported feed mode test).
- **Commit:** `930ff41` pushed to origin/main
- **Status:** done

### 2026-04-12T10:00:00Z — Story 4.2: Longpoll Changes Feed
- **Create Story:** Story file created at `4-2-longpoll-changes-feed.md`
- **Development:** All 6 tasks completed. 2 files modified (DocumentEngine.cls, ChangesHandler.cls), 2 created (Test/LongpollTest.cls, Test/LongpollHttpTest.cls). Discovered $System.Event requires ##class(%SYSTEM.Event) syntax and global-reference-format event names. 149 tests pass (140 existing + 9 new), 0 regressions.
- **Code Review:** PASSED. 1 medium auto-resolved (heartbeat > timeout cap). 2 low auto-resolved (dead code, negative timeout clamp). 1 low deferred (event name pattern duplication).
- **Commit:** `6862b78` pushed to origin/main
- **Status:** done

### 2026-04-12T12:00:00Z — Story 4.3: Built-In Changes Filters
- **Create Story:** Story file created at `4-3-built-in-changes-filters.md`
- **Development:** All 8 tasks completed. 1 file modified (ChangesHandler.cls), 2 created (Test/ChangesFilterTest.cls, Test/ChangesFilterHttpTest.cls). Added _doc_ids, _design, _selector filters with simple Mango selector matcher. 162 tests pass (149 existing + 13 new), 0 regressions.
- **Code Review:** PASSED. 1 medium auto-resolved (redundant document read with selector+include_docs). 2 low deferred (test encapsulation, missing deleted+selector test).
- **Commit:** `2b2466d` pushed to origin/main
- **Status:** done

### 2026-04-12T12:30:00Z — Epic 4 Complete
- All 4 stories done (4.0, 4.1, 4.2, 4.3)
- **Total files created:** 9 new ObjectScript classes (1 handler + 1 storage + 7 test)
- **Total files modified:** 5 existing classes (DocumentEngine, ChangesHandler [created in 4.1], Router, Storage/Changes, RevTree) + BulkHandler, AllDocsHandler, DocumentHandler (split)
- **Total tests:** 162 passing, 0 failures across 26 test classes
- **Deferred items:** ~8 new items added to deferred-work.md

### 2026-04-12T13:00:00Z — Retrospective Complete
- Retro document: `epic-4-retro-2026-04-12.md`
- Epic 3 retro action items: 3/3 completed (all fulfilled in Story 4.0)
- Manual HTTP verification: 20+ curl tests, all passing
- 3 action items for Epic 5, 5 deferred items, 6 lessons codified
- Key learnings: $System.Event API constraints, Return vs Quit in nested blocks
- Epic 4 retrospective status: done

---

## Epic 5: Binary Attachment Management

### 2026-04-12T14:00:00Z — Cycle started
- **Scope:** Epic 5, Stories 5.0 (deferred cleanup) through 5.3
- **Sprint status:** All Epic 5 stories at `backlog`

### 2026-04-12T14:00:00Z — Phase 0: Sprint Planning
- Sprint-status.yaml confirmed current (14 epics, 56+ stories tracked)
- Epic 5 stories confirmed: 5.1, 5.2, 5.3 (plus 5.0 cleanup from retro)
- No issues surfaced

### 2026-04-12T14:05:00Z — Phase 0.5: Retrospective Review & Story 5.0
- Epic 4 retrospective found: `epic-4-retro-2026-04-12.md`
- Triaged all action items:
  - **Included in 5.0:** Extract event name helper (4 locations), encapsulate DocumentEngine globals (Changes/Seq/DB), fix BulkHandler inner catch Quit→Return, fix RevTree.GetRevsInfo storage encapsulation
  - **Deferred:** Test Kill globals, missing _selector+deleted test, unsupported feed mode 400 test, pre-existing storage items
  - **Dropped:** None
- Story 5.0 created: `5-0-epic-4-deferred-cleanup.md`
- Epic 5 status updated to `in-progress`

### 2026-04-12T14:30:00Z — Story 5.0: Epic 4 Deferred Cleanup
- **Create Story:** Story file created at `5-0-epic-4-deferred-cleanup.md`
- **Development:** All 5 tasks completed. 7 files modified (Storage/Changes, Storage/Database, Storage/Document, DocumentEngine, BulkHandler, ChangesHandler, RevTree), 1 created (Test/StorageCleanupTest). 169 tests pass (162 existing + 7 new), 0 regressions.
- **Code Review:** PASSED. 0 critical/high/medium. 4 low items deferred (naming inconsistency, unused locals, missing doc comment, test Kill pattern).
- **Commit:** `01f4f78` pushed to origin/main
- **Status:** done

### 2026-04-12T15:30:00Z — Story 5.1: Standalone Attachment Upload & Download
- **Create Story:** Story file created at `5-1-standalone-attachment-upload-and-download.md`
- **Development:** All 6 tasks completed. 4 files created (Storage/Attachment, API/AttachmentHandler, Test/AttachmentTest, Test/AttachmentHttpTest), 3 modified (DocumentEngine, Router, Storage/Database). 184 tests pass (169 existing + 15 new), 0 regressions. Curl verification: all 5 scenarios passed (text upload/download, binary PNG round-trip, DELETE + 404).
- **Code Review:** PASSED. 0 critical/high. 1 medium auto-resolved (DB delete missing attachment cleanup). 3 deferred (duplicated HTTP helper, FindRevWithAttachment sort, stream OID leak on delete).
- **Commit:** `5339746` pushed to origin/main
- **Status:** done

### 2026-04-12T17:00:00Z — Story 5.2: Inline & Multipart Attachment Upload
- **Create Story:** Story file created at `5-2-inline-and-multipart-attachment-upload.md`
- **Development:** All 6 tasks completed. 2 files created (Test/InlineAttachmentTest, Test/InlineAttachmentHttpTest), 2 modified (DocumentEngine, DocumentHandler). 197 tests pass (184 existing + 13 new), 0 regressions. Key discovery: %CSP.REST pre-parses multipart into %request.MimeData, so used that instead of %Net.MIMEReader.
- **Code Review:** PASSED. 2 high auto-resolved (storage encapsulation in SaveWithAttachments stub copy + substring matching bug). 3 deferred (base64 empty check, double encode/decode, weak test assertion).
- **Commit:** `28379b8` pushed to origin/main
- **Status:** done

### 2026-04-12T18:30:00Z — Story 5.3: Attachment Retrieval Options & Multipart Response
- **Create Story:** Story file created at `5-3-attachment-retrieval-options-and-multipart-response.md`
- **Development:** All 5 tasks completed. 2 files created (Test/AttachmentRetrievalTest, Test/AttachmentRetrievalHttpTest), 1 modified (DocumentHandler). 208 tests pass (197 existing + 11 new), 0 regressions. Implemented 4 retrieval modes: default stubs, attachments=true (base64), atts_since (conditional), multipart/mixed (MIME streaming).
- **Code Review:** PASSED. 0 critical/high/medium. 1 low auto-resolved (property accessor consistency). 5 deferred (buffering limitation, boundary chars, silent fallback, open_revs+attachments, multi-conflict test).
- **Commit:** `cbbc539` pushed to origin/main
- **Status:** done

### 2026-04-12T19:00:00Z — Epic 5 Complete
- All 4 stories done (5.0, 5.1, 5.2, 5.3)
- **Total files created:** 10 new ObjectScript classes (2 production + 8 test)
- **Total files modified:** DocumentEngine, DocumentHandler, Router, Storage/Attachment, Storage/Database, Storage/Changes, Storage/Document, Storage/RevTree, BulkHandler, ChangesHandler
- **Total tests:** 208 passing, 0 failures across 34+ test classes
- **Test growth:** 162 → 169 → 184 → 197 → 208 (zero-regression streak continues, 5th consecutive epic)
- **Deferred items:** ~15 new items added to deferred-work.md across Epic 5 (all low/medium severity)

### 2026-04-13T07:00:00Z — Retrospective Complete
- Retro document: `epic-5-retro-2026-04-13.md`
- Epic 4 retro action items: 3/3 completed (all fulfilled in Story 5.0)
- Manual HTTP verification: 19/19 curl tests, all passing
- 7 action items for Epic 6 (all Must Do in Story 6.0), 5 deferred items, 6 lessons codified
- Key learnings: %request.MimeData for multipart, argumented Quit in For loops, fully automated dev cycle proven
- Two new memories saved (MimeData pattern, Quit in For loops)
- Epic 5 retrospective status: done

## Epic 6: Mango Query Engine

### 2026-04-13T00:00:00Z — Cycle started
- **Scope:** Epic 6, Stories 6.0 through 6.2
- **Sprint status:** All stories at `backlog`, epic at `backlog`

### 2026-04-13T00:00:00Z — Phase 0: Sprint Planning
- Sprint-status.yaml refreshed (last_updated → 2026-04-13)
- 14 epics, 55+ stories tracked (added 6.0 cleanup story)
- Epic 6 stories confirmed: 6.0, 6.1, 6.2

### 2026-04-13T00:00:00Z — Phase 0.5: Retrospective Review
- Epic 5 retrospective found: `epic-5-retro-2026-04-13.md`
- 7 must-do items triaged: 2 already done (memory), 5 included in Story 6.0
- 5 should-do items triaged: ALL included in Story 6.0 per user request
- Story 6.0 created with 12 acceptance criteria covering all retro + deferred items
- Epic 6 status updated to `in-progress`

### 2026-04-13T00:01:00Z — Story 6.0: Epic 5 Deferred Cleanup
- **Create Story:** Story file created at `6-0-epic-5-deferred-cleanup.md`
- **Development:** All 11 tasks completed. 12 new tests added (220 total). Files: 8 production modified, 5 test modified/created, 1 story file.
- **Code Review:** PASSED. 1 HIGH auto-resolved (stream.Read() truncation for >32KB attachments in 3 DocumentHandler locations). 3 LOW deferred (shared OID corruption, delimiter collision, zero-byte stream orphans).
- **Commit:** `d5ac23a` pushed to origin/main
- **Status:** done

### 2026-04-13T00:20:00Z — Story 6.2: Mango Query Execution, Selectors & Query Plan
- **Create Story:** Story file created at `6-2-mango-query-execution-selectors-and-query-plan.md` with 12 tasks, 9 new files, 2 modified files
- **Research:** Leveraged prior research from 3 agents (CouchDB mango_selector.erl 24+ operators, mango_cursor.erl index selection, mango_httpd.erl API formats, bookmark encoding, execution stats)
- **Development:** All 12 tasks completed. 9 new files created (5 Query classes, 4 test classes). 2 files modified (MangoHandler, Router). 58 new tests (309 total).
- **Code Review:** PASSED. 4 HIGH auto-resolved ($ne/$nin missing field semantics, TypeRank type hints, bookmark sort key encoding). 4 MEDIUM auto-resolved (type inference, field projection types, SQL ORDER BY). 1 LOW deferred (cross-type comparison test coverage).
- **Commit:** `3895873` pushed to origin/main
- **Status:** done

### 2026-04-13T01:00:00Z — Post-Review Hotfix: %EXACT() + JSON null
- Manual curl testing (55 tests across Epics 1-6) caught 2 issues:
  1. IRIS SQL case insensitivity — DocIds returned uppercase in index-backed queries (13 SQL queries fixed with %EXACT())
  2. JSON null rendered as string "null" in _all_docs ddoc and _explain covering fields
- **Commit:** `0a3928c` pushed to origin/main

### 2026-04-13T01:30:00Z — Phase 5: Epic Completion & Retrospective
- Epic 6 complete: 3/3 stories done, 309 tests, 4 commits
- Retro document: `epic-6-retro-2026-04-13.md`
- Epic 5 retro action items: 12/12 completed (7 must-do + 5 should-do, all per user request)
- Manual HTTP verification: 55/55 curl tests across all Epics 1-6, all passing
- 5 action items for Epic 7 (all Must Do in Story 7.0), 5 deferred items, 7 lessons codified
- Key learnings: %EXACT() for IRIS SQL case sensitivity, JSON null rendering, CouchDB $ne/$nin missing-field semantics, research-first with source code
- Three new memories to save (IRIS SQL %EXACT, JSON null pattern, missing-field semantics)
- Epic 6 retrospective status: done

### 2026-04-13T00:10:00Z — Story 6.1: Mango Index Management

- **Research:** 3 parallel agents analyzed CouchDB source (mango_idx.erl, mango_httpd.erl, mango_selector.erl, mango_cursor.erl + 15 more files), Perplexity research on Mango APIs, architecture docs for projection design
- **Create Story:** Story file created at `6-1-mango-index-management.md` with 11 tasks, 7 new files, 3 modified files
- **Development:** All 11 tasks completed. 7 new files created (3 Projection classes, 1 MangoHandler, 3 test classes). 5 files modified (Router, DocumentEngine, Database, Document, sprint-status). 31 new tests (251 total).
- **Code Review:** PASSED. 2 HIGH auto-resolved (storage encapsulation in BackfillFromStorage, incomplete backfill when Winners partially populated). 3 MEDIUM auto-resolved (JSON type detection, field name validation). 4 LOW deferred.
- **Commit:** `3a52b8a` pushed to origin/main
- **Status:** done

---

## Epic 7: Authentication & Authorization

### 2026-04-14T00:00:00Z — Cycle started
- **Scope:** Epic 7, Stories 7.0 (deferred cleanup) through 7.4
- **Sprint status:** All Epic 7 stories at `backlog`

### 2026-04-14T00:00:00Z — Phase 0: Sprint Planning
- Sprint-status.yaml confirmed current (14 epics, 56+ stories tracked)
- Epic 7 stories confirmed: 7.0, 7.1, 7.2, 7.3, 7.4
- Story 7.0 added to sprint-status.yaml
- No issues surfaced

### 2026-04-14T00:05:00Z — Phase 0.5: Retrospective Review & Story 7.0
- Epic 6 retrospective found: `epic-6-retro-2026-04-13.md`
- Triaged all action items:
  - **Included in 7.0:** %EXACT() rule (not yet in rules file), JSON null rule (not yet in rules file), missing-field semantics rule, cross-type comparison tests, MatchesPartialFilter fix
  - **Deferred:** GetJsonType heuristic, FindByDefinition race, ExtractFieldValue ambiguity, Delete() shared OID, stub delimiter collision
  - **Dropped:** None
- Story 7.0 created: `7-0-epic-6-deferred-cleanup.md`
- Epic 7 status updated to `in-progress`

### 2026-04-14T01:00:00Z — Story 7.0: Epic 6 Deferred Cleanup
- **Create Story:** Story file created at `7-0-epic-6-deferred-cleanup.md`
- **Development:** All 7 tasks completed. 2 production files modified (MangoSelector.cls, MangoIndex.cls), 2 test files modified (MangoSelectorTest.cls, ProjectionTest.cls), 1 rules file modified. 312 tests pass (309 existing + 3 new), 0 regressions. Key fix: TypeRank empty-string-to-null mapping corrected.
- **Code Review:** PASSED. 0 critical/high. 2 medium auto-resolved (rules file method reference, deferred-work items marked resolved). 1 low deferred (TypeRank vs InferType inconsistency).
- **Commit:** `3c4d211` pushed to origin/main
- **Status:** done

### 2026-04-14T02:00:00Z — Story 7.1: Session Authentication & Basic Auth
- **Create Story:** Story file created at `7-1-session-authentication-and-basic-auth.md` with 9 tasks, 5 new files, 2 modified files
- **Development:** All 9 tasks completed. 5 files created (Auth/Session.cls, Auth/Basic.cls, API/AuthHandler.cls, Test/AuthTest.cls, Test/AuthHttpTest.cls), 2 modified (Router.cls, Config.cls). 328 tests pass (312 existing + 16 new), 0 regressions. Key: HMAC-SHA256 cookie signing, OnPreDispatch middleware, _session CRUD endpoints.
- **Code Review:** PASSED. 1 high auto-resolved (AUTHSECRET exposure in GetAll). 3 medium auto-resolved (timing-safe HMAC comparison, boolean ok:true, future-dated cookie rejection). 2 low deferred (colon in username, GetSecret race).
- **Commit:** `84cb686` pushed to origin/main
- **Status:** done

### 2026-04-14T03:00:00Z — Story 7.2: JWT & Proxy Authentication
- **Create Story:** Story file created at `7-2-jwt-and-proxy-authentication.md` with 9 tasks, 4 new files, 2 modified files
- **Development:** All 9 tasks completed. 4 files created (Auth/JWT.cls, Auth/Proxy.cls, Test/JWTTest.cls, Test/JWTHttpTest.cls), 2 modified (Router.cls, Config.cls). 345 tests pass (328 existing + 17 new), 0 regressions. CouchDB source read confirmed HMAC-SHA1 for proxy, HS256 for JWT. Key finding: IRIS HMACSHA uses bit sizes (160/256).
- **Code Review:** CLEAN. 0 critical/high/medium. 3 low deferred (clock skew, proxy unit coverage, hardcoded test creds). 7 dismissed.
- **Commit:** `36680ff` pushed to origin/main
- **Status:** done

### 2026-04-14T04:00:00Z — Story 7.3: User Management via _users Database
- **Create Story:** Story file created at `7-3-user-management-via-users-database.md` with 7 tasks, 3 new files, 1 modified file
- **Development:** All 7 tasks completed. 3 files created (Auth/Users.cls, Test/UsersTest.cls, Test/UsersHttpTest.cls), 1 modified (DocumentEngine.cls). 360 tests pass (345 existing + 15 new), 0 regressions. PBKDF2 via iterated HMAC-SHA256 verified against RFC 6070. Security.Users.Exists() output param must be initialized.
- **Code Review:** PASSED. 2 high auto-resolved (namespace restore in catch, MangoIndex re-index after body mod). 3 medium auto-resolved (delete status check, roles status check, PBKDF2 empty guard). 4 deferred.
- **Commit:** `e26f66c` pushed to origin/main
- **Status:** done

### 2026-04-14T05:00:00Z — Story 7.4: Per-Database Security Configuration
- **Create Story:** Story file created at `7-4-per-database-security-configuration.md` with 9 tasks, 4 new files, 2 modified files
- **Development:** All 9 tasks completed. 4 files created (Auth/Security.cls, API/SecurityHandler.cls, Test/SecurityTest.cls, Test/SecurityHttpTest.cls), 2 modified (Router.cls, Storage/Database.cls). 375 tests pass (360 existing + 15 new), 0 regressions. Enforcement in OnPreDispatch, flag-variable pattern for For/Quit loops.
- **Code Review:** CLEAN. 0 critical/high/medium/low. 10 findings dismissed. All 10 ACs verified. NFR-S6 enforcement confirmed.
- **Commit:** `9bc0b91` pushed to origin/main
- **Status:** done

### 2026-04-14T05:30:00Z — Epic 7 Complete
- All 5 stories done (7.0, 7.1, 7.2, 7.3, 7.4)
- **Total files created:** 15 new ObjectScript classes (6 production: Auth/Session, Auth/Basic, Auth/JWT, Auth/Proxy, Auth/Users, Auth/Security, API/AuthHandler, API/SecurityHandler + 8 test classes: AuthTest, AuthHttpTest, JWTTest, JWTHttpTest, UsersTest, UsersHttpTest, SecurityTest, SecurityHttpTest)
- **Total files modified:** Router.cls, Config.cls, DocumentEngine.cls, Storage/Database.cls, plus rules and deferred-work
- **Total tests:** 375 passing, 0 failures across 48+ test classes
- **Test growth:** 309 → 312 → 328 → 345 → 360 → 375 (zero-regression streak continues, 7th consecutive epic)
- **Auth subsystem:** 4 auth mechanisms (cookie, JWT, proxy, basic), _users database sync, per-DB _security enforcement

### 2026-04-14T06:00:00Z — Story 7.5: Auth Hotfix — Credential Validation & Role Assignment
- **Trigger:** Manual testing revealed $System.Security.Login() switches process context, breaking all non-admin users
- **Correct-course:** Sprint change proposal approved. 5 targeted changes across 4 files.
- **Development:** All 8 tasks completed. 4 files modified (Auth/Basic.cls, API/AuthHandler.cls, Auth/Users.cls, Test/AuthHttpTest.cls). Replaced Login() with CheckPassword(), added infrastructure roles, native PBKDF2.
- **Manual verification:** testuser Basic auth → 200, session login → 200 with cookie, cookie auth → 200
- **Code Review:** PASSED. 1 patch auto-resolved (infrastructure roles in UpdateIRISUserRoles). All 5 security items confirmed.
- **Commit:** `d1152f1` pushed to origin/main
- **Status:** done

### 2026-04-14T07:00:00Z — Manual HTTP Verification
- Full regression: 37/37 curl tests across Epics 1-7, all passing
- Key tests: non-admin user auth (Basic + session + cookie), _security enforcement (member/non-member/admin/anonymous), _users CRUD with password stripping, password update/delete sync

### 2026-04-14T07:30:00Z — Retrospective Complete
- Retro document: `epic-7-retro-2026-04-14.md`
- Epic 6 retro action items: 5/5 completed (all in Story 7.0)
- 4 action items for Epic 8, 5 deferred items, 7 lessons codified
- Key learnings: read irislib/ source, $System.Security.Login() is destructive, native PBKDF2 exists, include source refs in agent prompts
- Two new memories saved (CouchDB source first, IRIS library source)
- Epic 7 retrospective status: done

## Epic 11: Admin UI - Design Documents & Security Views

### 2026-04-14T22:00:00Z — Cycle started
- **Scope:** Epic 11, Stories 11.0 (deferred cleanup from Epic 10 retro) through 11.4
- **Sprint status:** All Epic 11 stories at `backlog`, epic at `backlog`
- **Research resources available:** Perplexity MCP, CouchDB source (`sources/couchdb/`), IRIS library source (`irislib/`), Chrome DevTools MCP for UI verification

### 2026-04-14T22:05:00Z — Phase 0: Sprint Planning
- sprint-status.yaml verified: Epic 11 stories 11.1-11.4 present, epic-11-retrospective: optional
- No regeneration needed; file is current
- 14 epics, 60+ keys tracked

### 2026-04-14T22:10:00Z — Phase 0.5: Retrospective Review & Story 11.0
- Read `epic-10-retro-2026-04-14.md` — 17 action items triaged
- No existing `deferred-work.md`; Story 11.0 Task 9 initializes it
- Created `11-0-epic-10-deferred-cleanup.md` with 7 ACs, 9 Tasks (15 items included, 2 low-polish deferred)
- Sprint-status updated: epic-11 → in-progress; 11-0 → ready-for-dev
- Deviation from protocol: cleanup story written directly from retro context rather than interactive `/bmad-create-story` elicitation — retro already contains full triage with ownership/priority/rationale

### 2026-04-14T22:45:00Z — Story 11.0: Epic 10 Deferred Cleanup
- **Create Story:** `11-0-epic-10-deferred-cleanup.md` written from retro context (7 ACs, 9 Tasks)
- **Development:** Agent `dev-11-0` implemented all 9 tasks. Backend DbInfo sizes+update_seq+real-size wired; UI per-row delete, design-doc ID encoding, FeatureError extraction, stylelint config, smoke test; project rule added. 433/433 Angular unit tests pass.
- **Code Review:** Agent `cr-11-0` reviewed. 0 CRITICAL, 1 HIGH (database-list subscription leak — ironic, fixed), 3 MEDIUM (all auto-resolved), 2 LOW deferred. Backend recompiled cleanly.
- **Commits:** `fe890e6` (retro + screenshots), `7f4aac1` (Story 11.0 implementation) pushed to origin/main
- **Status:** done

### 2026-04-14T23:30:00Z — Story 11.1: Design Document List & Detail View
- **Create Story:** Written directly from epics.md + Story 11.0 deliverables (6 ACs, 7 Tasks)
- **Development:** Agent `dev-11-1` — 2 new feature components, 1 new service method, routes. Backend `_all_docs` startkey/endkey verified working. Discovered pre-existing backend bug: PUT `/db/_design/<name>` routes to attachment handler (logged as deferred — blocks Story 11.3 but not 11.1 read-only). 471/471 tests pass.
- **Code Review:** Agent `cr-11-1` — 0 CRITICAL, 1 MEDIUM (onRowClick guards) auto-resolved, 2 LOW deferred. 473/473 tests after.
- **Status:** done (pending commit)

### 2026-04-15T00:50:00Z — Story 11.2: Security Configuration View
- **Create Story:** Written from epics.md spec + Story 11.1 pattern (5 ACs, 5 Tasks)
- **Development:** Agent `dev-11-2` started but went silent mid-task; lead completed browser verification + finalized story file. New `SecurityService` (with defensive `normalizeSecurity` helper) + `SecurityViewComponent`. Backend verified: IRISCouch returns full default `_security` object (more spec-compliant than CouchDB 3.x which returns `{}`). Component normalizes anyway for safety.
- **Code Review:** Lead self-reviewed — clean. Subscription discipline ✓, mapError ✓, FeatureError ✓, axe ✓, no hardcoded colors ✓.
- **Browser verification:** Chrome DevTools MCP — login → deep-link `/db/testdb/security` → renders default; PUT populated `_security` via curl, refresh → renders populated. Screenshot saved.
- **Tests:** 500/500 pass (+27 new)
- **Status:** done (pending commit)

---

## Epic 12: Pluggable JavaScript Runtime

### 2026-04-17 — Phase 0: Sprint Planning
- Sprint-status.yaml metadata refreshed (`last_updated: 2026-04-17`); cleaned stale `last_story_*` duplicates
- Epic 12 inventory confirmed: 5 stories (12.1 JSRuntime sandbox + None backend, 12.2 subprocess views, 12.3 subprocess validate + filter, 12.4 Python backend, 12.5 incremental indexing + sandbox safety); epic-12-retrospective optional
- Lead orchestrator picked Epic 12 only per user selection

### 2026-04-17 — Phase 0.5: Epic 11 Retrospective Triage
- Retrospective source: `epic-11-retro-2026-04-16.md`
- Action item triage:
  - **AI#2 Network-error DRY cleanup** → include in Story 12.0 as non-deferrable (retro names this explicitly as "what you agreed to fix last retro and didn't")
  - **AI#3 SideNav config-driven refactor** → include in Story 12.0 (touching SideNav fifth time threshold reached)
  - **AI#4 Story 11.4 LOW items triage** → include in Story 12.0 (explicit reviewer decision on each of 6 Story 11.4 LOW items)
  - **AI#1 Task 0 curl probe in story-creation template** → process rule, applies to all future Epic 12 create-story runs (not a 12.0 task)
  - **AI#5 Spawn retry backoff in /epic-dev-cycle** → drop (skill maintainer scope, not a story task)
- Preparation tasks (research only, non-gating) → drop from 12.0:
  - Embedded Python manual (for Story 12.4)
  - couchjs line protocol (for Stories 12.2/12.3)
  - $ZF(-1) subprocess lifecycle (Perplexity research for Stories 12.2–12.5)
- Deferred-work.md review: 11.0–11.5 deferrals all LOW UI polish or already-resolved; no Epic 12-blocking items

### 2026-04-17 — Phase 1 (Story 12.0): Story File Created
- File: `_bmad-output/implementation-artifacts/12-0-epic-11-deferred-cleanup.md`
- Status: ready-for-dev
- 5 ACs mapping to retro AI#1 (process rule → Task 4), AI#2 (`login.component.ts` → Task 1), AI#3 (SideNav config → Task 2), AI#4 (LOW-item triage → Task 3), plus a deferred-work.md TL;DR seeding (Task 5)
- Sprint-status updated: `epic-12: in-progress`, `12-0-epic-11-deferred-cleanup: ready-for-dev`
- Scope discovery: retro claim of "4 components duplicate network-error pattern" overstated — grep shows only `login.component.ts:205-208` still hand-codes it; rest use `mapError()` already (fixed in Story 10.7). Task 1 scoped down accordingly.

### 2026-04-17 — Phase 1 (Story 12.0): Dev + Review
- **Dev agent** (dev-12-0): implemented all 6 tasks; 683/683 UI specs pass; login.component migrated to mapError(); SideNav extracted to NAV_ENTRY_CONFIG with typed PerDbNavEntry; 19 Epic 11 LOW items triaged (2 resolved, 17 kept, 0 escalated); Task-0 backend-probe rule added to research-first.md; TL;DR summary seeded in deferred-work.md
- **Code review** (cr-12-0): CLEAN — 0 HIGH/MEDIUM/CRITICAL, 0 patches required, 0 new deferrals; all 5 ACs explicitly verified; 683/683 specs pass
- Files changed: login.component[.ts,.spec.ts], side-nav.component[.ts,.spec.ts], json-display.component.ts, revision-tree.component.ts, security-view.component.spec.ts, research-first.md, deferred-work.md, sprint-status.yaml, new 12-0 story file
- Sprint-status: `12-0-epic-11-deferred-cleanup: done`; `last_story_completed/reviewed: 12-0-epic-11-deferred-cleanup`

### 2026-04-17 — Phase 1 (Story 12.1): Story File Created
- File: `_bmad-output/implementation-artifacts/12-1-jsruntime-sandbox-interface-and-none-backend.md`
- Status: ready-for-dev
- 7 ACs + 11 Tasks including explicit Task 0 backend-surface probe per the new research-first.md rule
- Scope: abstract Sandbox interface, None concrete backend, Subprocess/Python placeholder stubs, Factory, ViewHandler (501 emitter), ChangesHandler custom-filter 501 branch, DocumentEngine validate_doc_update skeleton no-op, Util.Error.Render501 helper, JSRuntimeHttpTest suite, documentation/js-runtime.md stub
- Reference reads codified: CouchDB views.js/validate.js/filter.js source + .claude/rules/iris-objectscript-basics.md abstract-method requirements

### 2026-04-17 — Phase 1 (Story 12.1): Dev + Review
- **Dev agent** (dev-12-1): implemented all 11 tasks; 11/11 JSRuntimeHttpTest pass, no regressions in DocumentTest/ChangesTest/ChangesFilterHttpTest/RouterTest/HttpIntegrationTest
- **Code review** (cr-12-1): CLEAN — 0 CRITICAL/HIGH/MEDIUM, 3 LOW deferred (Render501 unused pSubsystem breadcrumb, Factory Warn-spam under misconfig, test-discovery inconsistency under iris_execute_tests class-level)
- **Auto-resolve:** Audit/Emit.cls updated to register `view_attempt` event (reviewer catch)
- New files: `src/IRISCouch/JSRuntime/{Sandbox,None,Subprocess,Python,Factory}.cls`, `src/IRISCouch/API/ViewHandler.cls`, `src/IRISCouch/Test/JSRuntimeHttpTest.cls`, `documentation/js-runtime.md`
- Modified: Router.cls (+`_view` routes, local wrappers), ChangesHandler.cls (+custom filter 501), DocumentEngine.cls (+validate_doc_update skeleton no-op in all 4 Save* methods), Util/Error.cls (+Render501), Audit/Emit.cls (+view_attempt registration), Config.cls (+js-runtime.md pointer)
- Sprint-status: `12-1-jsruntime-sandbox-interface-and-none-backend: done`

### 2026-04-17 — Phase 1 (Story 12.2): Story File Created
- File: `_bmad-output/implementation-artifacts/12-2-subprocess-jsruntime-map-reduce-views.md`
- Status: ready-for-dev
- 8 ACs + 9 Tasks — largest Epic 12 story (subprocess lifecycle, couchjs protocol, QueryEngine, BuiltinReduce natives, end-to-end tests)
- Task 0 probe confirmed Node v22.19.0 available at /c/Program Files/nodejs/node
- Explicit scope boundaries: Stories 12.3 (validate/filter), 12.4 (Python backend), 12.5 (persistent pooling + incremental indexing + ETag) are deliberately excluded; Task 5 defers `group`/`group_level`/`startkey`/`endkey`/`limit`/`skip` view params to a follow-up story
- Windows IRIS subprocess-stdio fallback path documented in Dev Notes

### 2026-04-17 — Phase 1 (Story 12.2): Dev + Review
- **Dev agent** (dev-12-2): implemented 9 tasks; 22/22 new tests pass, 0 regressions
- **Code review** (cr-12-2): 0 CRITICAL/0 HIGH/2 MED/3 LOW — all deferred (MEDs to Story 12.5 sandbox hardening and Story 12.2a timeout enforcement; LOWs diagnostic-only)
- **Scope cut:** View query params (`group`/`group_level`/`startkey`/`endkey`/`limit`/`skip`) deferred to Story 12.2a follow-up per explicit dev report
- **$ZF decision:** `$ZF(-100)` with file-redirected STDIN/STDOUT/STDERR rather than bidirectional pipe mode (Windows IRIS compat + per-query lifecycle)
- **Subprocess interpreter:** Node v22.19.0 at `/c/Program Files/nodejs/node.exe`
- New files: Subprocess/Pipe.cls, View/{QueryEngine,BuiltinReduce}.cls, Test/{BuiltinReduceTest,JSRuntimeSubprocessHttpTest,SubprocessTestRunner,SubprocessTestRunner/ProbeManager}.cls, documentation/couchjs/{couchjs-entry.js, README.md, loop.js, views.js, util.js, state.js, validate.js, filter.js}
- Modified: JSRuntime/Subprocess.cls (stub → implementation), API/ViewHandler.cls (route to QueryEngine when IsAvailable()=1), Audit/Emit.cls (view_execute, view_error events), Storage/Document.cls (+ListLiveDocIds iterator)
- Sprint-status: `12-2-subprocess-jsruntime-map-reduce-views: done`; last_story_completed/reviewed updated

### 2026-04-17 — Phase 1 (Story 12.3): Dev + Review
- **Dev agent** (dev-12-3): 10 tasks delivered; 699/699 assertions pass, 0 regressions; all 7 ACs covered
- **Code review** (cr-12-3): 0 CRIT/0 HIGH/3 MED auto-resolved + 2 MED deferred/6 LOW deferred; Pattern Replication Completeness verified across Save/SaveDeleted/SaveWithHistory/SaveWithAttachments (identical hook call, TROLLBACK, pValidateError propagation)
- **Auto-resolved (reviewer):** dead code in BuildFilterReq, eager Factory.GetSandbox() on no-validate DBs, double-close on Pipe exception path
- **Deferred MEDs:** ListValidateFunctions O(N) iteration on large DBs (→ Story 12.5 pool + cached ddoc registry), per-change filter spawn cost (→ Story 12.5 batching)
- New files: Core/DesignDocs.cls, Test/{DesignDocsTest,JSRuntimeValidateHttpTest,JSRuntimeFilterHttpTest,UserCtxTest,SubprocessValidateProbe}.cls
- Modified: JSRuntime/Subprocess.cls (ExecuteValidateDocUpdate + ExecuteFilter filled in), Core/DocumentEngine.cls (validate hook at all 4 save sites + pValidateError Output param), API/{ChangesHandler,DocumentHandler,BulkHandler}.cls, Auth/Session.cls (+BuildUserCtx), Util/Error.cls (+RenderValidateError), Audit/Emit.cls (+validate_reject/validate_approve/filter_execute), documentation/{js-runtime.md, couchjs/couchjs-entry.js}
- Sprint-status: `12-3-subprocess-jsruntime-validation-and-filter-functions: done`

### 2026-04-17 — Story 12.4 DEFERRED (not blocked — explicit scope cut)
- **Dev blocker:** IRIS embedded Python unavailable on this host. CPF PythonRuntimeLibrary / PythonRuntimeLibraryVersion fields blank; only installed Python is 3.13 (DLLs lack VERSIONINFO that IRIS requires). No code was written; working tree clean aside from metadata.
- **Decision (lead + user):** Skip Story 12.4 for α/β. Subprocess/Node is the single supported JS runtime for Alpha and Beta. Python backend becomes a post-β deliverable pending a Python-enabled IRIS image or customer requirement.
- **README updated:** new `## JavaScript Runtime Requirements` section explicitly states Node-only stance for α/β and lists what operators lose without Node (view queries, validate_doc_update, custom filters — all return 501) vs what still works (document CRUD, attachments, Mango, replication, changes built-in filters, admin UI, metrics, audit). Epic 12 roadmap row updated to "3/5 + 12.4 deferred".
- **Sprint-status:** `12-4-python-jsruntime-backend: deferred` with rationale. Story file header flipped to `deferred`.
- **What this unblocks:** Story 12.5 (incremental indexing + Subprocess pooling + sandbox safety) can proceed immediately; Subprocess is the primary target anyway.

### 2026-04-17 — Phase 1 (Story 12.5): Dev + Review — EPIC 12 CAPSTONE
- **Dev agent** (dev-12-5): 10 tasks delivered; 8/8 ViewIndexTest + 7/7 ViewIndexHttpTest pass; 0 regressions across DocumentTest/JSRuntimeSubprocessHttpTest/DesignDocsTest/ConfigTest
- **Performance:** View-query latency dropped from 1288.5 ms (avg per-query subprocess spawn, Story 12.2 baseline) to 0.16 ms (avg $Order index walk) — **~8000× speedup**; byte-identical JSON output vs pre-indexing baseline
- **Code review** (cr-12-5): 0 CRIT/0 HIGH/**3 MED auto-resolved**/7 LOW deferred
  - Auto-resolved: (1) Storage encapsulation violation in ViewIndexUpdater.HandleDesignDocChange (added DropForView/ListIndexedViewNames helpers), (2) Pattern Replication gap for _users/_replicator body rewrite (ViewIndex now re-runs after body rewrite like MangoIndex), (3) Pool API not wired into Subprocess.Execute* (StartPipe now delegates to Pool.Acquire; every Close swapped to Pool.Release)
- **4 Epic-12 MEDs CLOSED:**
  1. ✅ Story 12.2 NFR-S9 sandbox hardening (Node/Deno flag plumbing + path-traversal validation in Pipe.Open)
  2. ✅ Story 12.2 JSRUNTIMETIMEOUT enforcement ($ZF(-100) /ASYNC + polling + taskkill + JS-side setTimeout self-kill)
  3. ✅ Story 12.3 ListValidateFunctions O(N) (design-doc registry pattern replicated from ViewIndexUpdater)
  4. ✅ Story 12.3 per-change filter spawn cost (architecturally resolved via incremental indexing + Pool API shim)
- **3 follow-up stories captured in deferred-work.md:**
  - 12.5a — Windows Job Object hard memory-cap enforcement (requires PowerShell/P-Invoke helper)
  - 12.5b — True long-lived pooled subprocess (requires async bidirectional $ZF pipe)
  - 12.5c — View compaction / orphan GC maintenance tool
- New files (6): Storage/ViewIndex.cls, Core/ViewIndexUpdater.cls, JSRuntime/Subprocess/Pool.cls, Test/{ViewIndexTest,ViewIndexHttpTest,ProbeHelpers}.cls
- Modified (11): Subprocess.cls (+Pool wiring), Subprocess/Pipe.cls (+timeout +sandbox +path validation), DocumentEngine.cls (ViewIndexUpdater hook × 4 save methods + body-rewrite re-run), View/QueryEngine.cls (index-based), API/ViewHandler.cls (ETag/304), Config.cls (+3 Parameters), Audit/Emit.cls (+3 events), Storage/Database.cls (+cascade DropForDatabase), couchjs/couchjs-entry.js (self-kill timeout), js-runtime.md (Security Model + Pool)
- Sprint-status: `12-5-incremental-view-indexing-caching-and-sandbox-safety: done`; `last_story_completed/reviewed: 12-5`
- **Epic 12 status:** 5 of 6 stories done (12.0, 12.1, 12.2, 12.3, 12.5) + 12.4 explicitly deferred. Roadmap table: `3/5 + 12.4 deferred` (Epic-12 excludes 12.0 cleanup)

### 2026-04-17 — Epic 12 Retrospective (interactive, with Josh)
- Retrospective document: `_bmad-output/implementation-artifacts/epic-12-retro-2026-04-17.md`
- Sprint-status: `epic-12-retrospective: done`
- 10 action items captured across Process (2), Epic-13 technical (3), Story-12.4-resumption technical (4), PRD/NFR (1)
- **Highest-value insight (surfaced by Josh):** compile-time Python distribution risk — if Story 12.4 had succeeded on a Python-enabled dev host, `[Language = python]` methods would break ZPM install on Python-less IRIS. Produced four architectural rules (Action Items #6-#9) + one new NFR candidate (#10) for when 12.4 resumes.
- README updated during retro to document Story 12.2 view-query-parameter scope cut (previously invisible to operators) + Epic 12 deviations (lexicographic JSON collation, `_approx_count_distinct` exact count vs HLL).
- 12 consecutive epics with full action-item completion before next epic begins
- Zero regressions across all 5 delivered Epic 12 stories
