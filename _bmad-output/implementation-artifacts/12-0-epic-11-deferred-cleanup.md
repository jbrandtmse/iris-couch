# Story 12.0: Epic 11 Deferred Cleanup

Status: done

## Story

As a developer,
I want to close the Epic 11 retrospective action items and triage the outstanding Epic 11 LOW findings before starting the JSRuntime work,
so that Epic 12 (predominantly ObjectScript backend) begins with a clean Angular-side ledger and the "what you agreed to fix last retro and didn't" accountability thread is cut before it compounds.

## Acceptance Criteria

1. **Given** the Epic 11 retrospective identified that `login.component.ts` still hand-codes the `status === 0` / "Cannot reach" branch even though `mapError()` has been the canonical classifier since Story 10.7
   **When** `login.component.ts` issues its login request and handles the error
   **Then** the component consumes `mapError()` from `services/error-mapping.ts` (no inline `if (err.status === 0)` branch remains), and the resulting feature-error display is byte-identical to the prior message for the network-unreachable case (regression-tested via an HTTP 0 stub)

2. **Given** Stories 10.3, 11.1, 11.2, and 11.4 each bolted a new entry onto the hardcoded per-database `items` array in `side-nav.component.ts`, with Story 11.4's disabled-when-no-docId branch foreshadowing worse bolt-ons in Epic 14
   **When** the SideNav renders its per-database scope
   **Then** the four entries (Documents, Design Documents, Security, Revision History) are produced from a single typed config array of records shaped like `{ id, label, route: (ctx) => string, enabled: (ctx) => boolean, tooltip?: (ctx) => string }`; adding a fifth entry is a one-line append to the config array, and the existing keyboard-focus, aria-current, and disabled-with-tooltip behaviours all survive unchanged (verified by the existing side-nav spec suite plus one new spec that asserts "adding a config entry renders a corresponding `<li>` with the correct attributes")

3. **Given** the Epic 11 code-review deferrals contain six Story 11.4 LOW items, five Story 11.3 LOW items, two Story 11.2 LOW items, two Story 11.0 code-review LOW items, three Story 11.0 implementation LOW items, and one Story 11.5 LOW item (all listed in `deferred-work.md`)
   **When** each item is reviewed against the current codebase
   **Then** every item gets an explicit decision recorded back into `deferred-work.md` as one of: (a) **resolved in 12.0** (linked to the commit that closes it), (b) **kept deferred** with a one-line rationale that names the specific condition under which we would revisit, or (c) **escalated to MEDIUM** with a follow-up story or sub-task added to sprint-status — and the Story 12.0 triage table at the bottom of this story records every decision

4. **Given** Epic 12's first three stories (12.1–12.3) will consume IRIS embedded Python and `$ZF(-1)` subprocess APIs, and the `/epic-dev-cycle` protocol requires backend-consuming stories to capture a Task 0 curl / smoke probe
   **When** Story 12.1 and later are created via `/bmad-create-story`
   **Then** a short reminder note is appended to `.claude/rules/research-first.md` codifying that every Epic 12 story with a new backend surface includes (a) a `curl` probe against the proposed endpoint, (b) verbatim expected output pasted into the story Tasks, and (c) a concrete reference read (couchjs protocol / Python manual / $ZF(-1) docs) cited in the story Dev Notes — this is a process rule, not a code change

5. **Given** the existing `deferred-work.md` has grown unwieldy across 11 epics
   **When** a developer opens it to find open items
   **Then** a "TL;DR / open-item summary" table is maintained at the top of the file listing only the **still-open** items grouped by severity (HIGH / MEDIUM / LOW) with a one-line pointer to the full entry below, and Story 12.0 seeds this summary from the current state of the file so future stories can maintain it incrementally

## Triage Table: Epic 11 Retrospective Action Items

| # | Action Item | Decision | Rationale | Mapped AC |
|---|-------------|----------|-----------|-----------|
| 1 | Story-creation Task 0 curl probe (process rule) | **Include (as process rule)** | Retro named this as a preventive measure for Epic 12 backend-consuming stories. Codify in `.claude/rules/research-first.md` rather than as executable story work. | AC 4 |
| 2 | Network-error DRY cleanup (non-deferrable) | **Include (scoped down)** | `mapError()` already consumes the status=0 branch in 7 feature components. Only `login.component.ts:205-208` still hand-codes it. Migrate this one call site; retro's "4 components" claim overstated actual state. | AC 1 |
| 3 | SideNav config-driven refactor | **Include** | Four hardcoded entries, one with conditional rendering; Epic 14 will make this worse. Retro-explicit "do when touching SideNav for the fifth time". | AC 2 |
| 4 | Story 11.4 LOW items triage | **Include** | Six LOW findings, all with ambiguous "revisit later" dispositions. Triage now before they rot. | AC 3 |
| 5 | Spawn retry with backoff in `/epic-dev-cycle` | **Drop** | Skill-maintainer scope, not a story task. Log only. | — |

## Triage Table: Epic 11 Preparation Tasks

| # | Prep Task | Decision | Rationale |
|---|-----------|----------|-----------|
| P1 | Read `documentation/IRIS_Embedded_Python_Complete_Manual.md` | **Drop (non-gating)** | Research read; applies to Story 12.4, not 12.0. Dev of 12.4 owns. |
| P2 | Read couchjs line protocol in `sources/couchdb/share/server/` | **Drop (non-gating)** | Research read; applies to Stories 12.2/12.3 dev. |
| P3 | Research `$ZF(-1)` subprocess lifecycle (Perplexity) | **Drop (non-gating)** | Research read; applies to Stories 12.2–12.5. Owned by consuming-story dev. |

## Triage Table: Epic 11 LOW Deferrals (AC 3 placeholder — dev to fill in)

The dev agent executing this story **must** review each item in `deferred-work.md` under the headings listed below, record its disposition in the triage table, and patch `deferred-work.md` with the decision inline (e.g., strike through resolved items, append "— **KEPT DEFERRED (2026-04-17): [rationale]**" to kept items).

| Story | Item (short form) | Decision (resolved / kept / escalated) | Rationale / Commit |
|-------|-------------------|----------------------------------------|---------------------|
| 11.0 review | Smoke.mjs path resolution on Windows | **KEPT DEFERRED** | Revisit trigger already named (next time smoke.mjs is touched); CI runner path has no spaces. |
| 11.0 review | FeatureError rawError setter clears statusCode | **KEPT DEFERRED** | No consumer binds both inputs today; revisit trigger (first caller needing status override) already documented. |
| 11.0 impl | stylelint configured but not installed | **KEPT DEFERRED** | Requires network-capable `npm install`; bundle with next infra task. |
| 11.0 impl | UI smoke workflow requires self-hosted runner | **KEPT DEFERRED (MED, already tagged)** | Infra task; belongs with Epic 14 DevOps story. |
| 11.0 impl | `sizes.external` / `sizes.active` report allocated bytes | **KEPT DEFERRED** | ObjectScript backend concern; Story 12.0 is UI-only. Revisit trigger (replicator/monitoring consumer) still applies. |
| 11.2 | JsonDisplay gutter color contrast at 10+ lines | **RESOLVED in 12.0** | Swapped `--color-neutral-400` → `--color-neutral-600` in `json-display.component.ts`. Removed scoped `color-contrast` axe disable in `security-view.component.spec.ts`. |
| 11.2 | IRISCouch `_security` backend divergence (informational) | **KEPT DEFERRED** | ObjectScript backend concern; informational only. Revisit if CouchDB wire-compat becomes an NFR. |
| 11.3 | TextAreaJson uses `getElementById` for gutter scroll sync | **KEPT DEFERRED** | Single consumer today (DesignDocDetail); revisit when file is next touched or gains a second consumer. |
| 11.3 | `TestPostDesignDocNotAllowed` accepts 404 OR 405 | **KEPT DEFERRED** | ObjectScript backend test; Story 12.0 is UI-only. Revisit bundled with a future Http405 regression story. |
| 11.3 | `design-doc-create-dialog` `titleId` uses `Date.now()` | **KEPT DEFERRED** | Guarded by "only one dialog mounted at a time" invariant. |
| 11.3 | Delete-dialog body uses `[innerHTML]` | **KEPT DEFERRED** | DomSanitizer strips XSS; revisit when ConfirmDialog grows a structured body API. |
| 11.3 | TextAreaJson `emitValidity` re-emits on every invalid tick | **KEPT DEFERRED** | Subscribers idempotent; revisit only if a profile or new subscriber surfaces the cost. |
| 11.4 | Hardcoded `font-size: 12px` on `.revision-tree__node-badge` | **RESOLVED in 12.0** | Swapped literal `12px` → `var(--font-size-xs)` (token resolves to same 12px) in `revision-tree.component.ts`. |
| 11.4 | Rapid mouseenter popover churn | **KEPT DEFERRED** | No correctness bug; revisit trigger (profiler showing overlay dominance) already named. |
| 11.4 | `selectedRev` not preserved across Refresh click | **KEPT DEFERRED** | URL round-trips correctly today; documented-for-completeness only. |
| 11.4 | `showPopover` anchors SVG cast as `HTMLElement` | **KEPT DEFERRED** | CDK only calls `getBoundingClientRect()` which SVG supports. Runtime-correct; cast is a type-only lie. |
| 11.4 | AC #5 wording says "move the selected node"; impl moves focus | **KEPT DEFERRED (spec-text)** | Implementation is axe-clean and matches app-wide keyboard-nav idiom. Revisit at next epics.md edit pass. Not a code change. |
| 11.4 | No explicit "≥ 5 conflict branches" layout test | **KEPT DEFERRED** | Fixed-grid layout cannot mis-pack by construction; test would only assert deterministic column assignment. Revisit if layout grows packing heuristics. |
| 11.5 | AC #4 error message says `%IRISCouch_Admin` vs `IRISCouch_Admin` | **KEPT DEFERRED (doc-only)** | Documentation-only mismatch; code is already correct. Revisit at next epics.md / PRD edit. |

**Summary:** 2 resolved in 12.0 (JsonDisplay gutter contrast, revision-tree badge font token), 17 kept deferred with named revisit triggers, 0 escalated to MEDIUM. No new sprint-status follow-ups required.

**Trivial fixes executed under Task 3 (no separate commit — bundled with this story):**
- `ui/src/app/couch-ui/json-display/json-display.component.ts` — line-number gutter color token swap
- `ui/src/app/features/security/security-view.component.spec.ts` — removed scoped `color-contrast` axe disable (fix now in place)
- `ui/src/app/couch-ui/revision-tree/revision-tree.component.ts` — badge font-size → token

## Tasks / Subtasks

- [x] **Task 1: Migrate `login.component.ts` to `mapError()`** (AC: #1)
  - [x] Remove the inline `if (err.status === 0) { ... }` branch at `login.component.ts:205-212` (or equivalent line range — dev should re-locate the branch by grep on `err.status === 0` inside the login component)
  - [x] Import `mapError` from `services/error-mapping.ts` and replace the branch with `const mapped = mapError(err); this.error = mapped.display;` — mirror the pattern used in `database-list.component.ts:254` and friends
  - [x] Update the `login.component.spec.ts` "shows network error when /_session unreachable" test to stub an `HttpErrorResponse` with `status: 0` and assert the displayed `reason` matches the shared `mapError` output
  - [x] Run `ng test --watch=false --include='**/login.component.spec.ts'` and confirm the spec passes (15/15 pass)
  - [x] Grep the entire `ui/src/` tree for `err.status === 0` after the change; the only remaining hit should be `services/error-mapping.ts` itself (confirmed — single hit)

- [x] **Task 2: SideNav config-driven refactor** (AC: #2)
  - [x] Introduce a typed `NAV_ENTRY_CONFIG` constant in `side-nav.component.ts` (or extract to `side-nav.config.ts` if it grows >20 lines) shaped like:
    ```ts
    type NavContext = { dbName: string; docId: string | null };
    interface PerDbNavEntry {
      id: string;
      label: string;
      route: (ctx: NavContext) => string;
      enabled: (ctx: NavContext) => boolean;
      tooltip?: (ctx: NavContext) => string | null;
    }
    ```
  - [x] Replace the inline array inside `updateNavScope()` with a `.map()` over the config, passing the current `{dbName, docId}` context in
  - [x] Verify Revision History's disabled-when-no-docId branch still produces the same `{ disabled: true, tooltip: "Select a document first to view its revisions" }` output for the `NavItem` (preserved via `toNavItem` helper; spec asserts identical output)
  - [x] Keep the existing `NavItem` output contract — the template and `FocusKeyManager` wiring must not change
  - [x] Add one new spec to `side-nav.component.spec.ts` that asserts appending an entry to the config renders an additional `<li>` with the correct `aria-disabled` / `href` attributes (test overrides `component.navEntryConfig` directly and spies on `router.url` to trigger scope update; three new specs added)
  - [x] Confirm all existing side-nav specs still pass (keyboard nav, aria-current, Revision History disabled/enabled transitions) — 16/16 pass

- [x] **Task 3: Triage Epic 11 LOW deferrals** (AC: #3, #5)
  - [x] For each of the 19 items in the triage table above: reviewed, decided, and annotated back into `deferred-work.md`
  - [x] 2 trivial fixes executed (JsonDisplay gutter color + RevisionTree badge font-size) — see "Trivial fixes executed under Task 3" note in the triage table
  - [x] AC #5 wording mismatch on 11.4 kept deferred as a spec-text-only item (no code change)
  - [x] JsonDisplay gutter contrast bug resolved via single token swap; `security-view.component.spec.ts` axe scope-disable removed; full axe-core pass restored

- [x] **Task 4: Append Task 0 curl-probe rule to research-first.md** (AC: #4)
  - [x] Added "Task 0 backend-surface probe (Epic 12+ story creation)" subsection under "IRIS/ObjectScript emphasis"
  - [x] Captures (a) live `curl -u _system:SYS` probe, (b) verbatim status + body in the story, (c) concrete reference read (embedded-Python manual for `%SYS.Python`, couchjs line protocol for `$ZF(-1)`, CouchDB source or InterSystems doc otherwise)
  - [x] No existing rules reordered; markdown renders clean

- [x] **Task 5: Seed TL;DR summary in deferred-work.md** (AC: #5)
  - [x] `## Open Items Summary (as of 2026-04-17)` section inserted at the top above all per-story-deferred sections
  - [x] Three subsections (HIGH, MEDIUM, LOW); HIGH is empty. LOW is further split by ObjectScript-backend vs Angular-UI for scannability.
  - [x] Convention statement at the top of the summary names the maintenance protocol for future `X.0` cleanup stories
  - [x] Walked the full file; skipped strike-through / RESOLVED / CLOSED items

- [x] **Task 6: Add Story 12.0 to sprint-status.yaml** (structural)
  - [x] Entry `12-0-epic-11-deferred-cleanup: ready-for-dev` was pre-seeded by the lead; dev confirmed presence on 2026-04-17 and flipped to `in-progress` at story start, then `review` at completion

## Dev Notes

### Why this cleanup is lean

Three of the five Epic 11 retro action items map here (AI#2, #3, #4's triage). AI#1 is a process rule (Task 4 codifies it), AI#5 is skill-maintainer scope (dropped). Research prep tasks (P1–P3) are owned by the stories that consume those subsystems, not by 12.0. This is intentional: Story 12.0's job is to unblock Epic 12, not to front-load every Epic 12 background read.

### Previous Story Intelligence

- **Story 10.7** extracted `mapError()` to `services/error-mapping.ts` as the canonical HTTP error classifier. It already covers the `status === 0` branch with the exact "Cannot reach `/iris-couch/`" message. Every feature component *except* `login.component.ts` migrated to it during Stories 10.7–11.5. The gap is a single file.
- **Story 11.4** introduced the disabled-with-tooltip state for the Revision History SideNav entry. The new config shape in Task 2 must preserve this state mechanism exactly — the disabled branch was spec'd in Story 11.4 and tested in `side-nav.component.spec.ts`.
- **Story 11.0** established the subscription-leak prevention rule in `.claude/rules/angular-patterns.md`. Tasks 1 and 2 above do not introduce new HTTP subscriptions, so the rule is not directly invoked, but the dev must confirm no new `.subscribe()` calls are introduced without `takeUntilDestroyed(this.destroyRef)` or equivalent.

### Subscription discipline

Task 1 touches `login.component.ts`, which does subscribe directly to `authService.login()`. Do not change that subscription structure; `mapError` is a pure function and does not affect subscription lifecycle.

### Backend scope

**None.** This story is UI-only plus a markdown rule addition. No ObjectScript classes are touched. No IRIS compile step is required.

### File List (expected)

- `ui/src/app/features/auth/login.component.ts` — migrate to `mapError()`
- `ui/src/app/features/auth/login.component.spec.ts` — update network-error test stub
- `ui/src/app/couch-ui/side-nav/side-nav.component.ts` — extract `NAV_ENTRY_CONFIG`
- `ui/src/app/couch-ui/side-nav/side-nav.component.spec.ts` — add config-driven render spec
- `ui/src/app/couch-ui/json-display/json-display.component.ts` — (possibly) swap `--color-neutral-400` → `--color-neutral-600` for gutter (Task 3 trivial fix)
- `.claude/rules/research-first.md` — append Task-0 backend-surface probe subsection
- `_bmad-output/implementation-artifacts/deferred-work.md` — add TL;DR summary + triage annotations
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — add `12-0-...` entry (lead pre-seeds; dev confirms)

### Project Structure Notes

- No new files, no new components — only edits to existing files. The one exception is if Task 2's config is large enough to warrant extracting to `side-nav.config.ts` (dev's call based on final line count).

### References

- Epic 11 retrospective: `_bmad-output/implementation-artifacts/epic-11-retro-2026-04-16.md` (action items, preparation tasks)
- Existing `mapError()`: `ui/src/app/services/error-mapping.ts:19-54`
- SideNav inline items array: `ui/src/app/couch-ui/side-nav/side-nav.component.ts:188-225`
- Deferred-work inventory: `_bmad-output/implementation-artifacts/deferred-work.md`
- Angular patterns rule: `.claude/rules/angular-patterns.md` (subscription-leak + no-hardcoded-colors)
- Research-first rule: `.claude/rules/research-first.md` (add Task-0 backend-probe subsection)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.7 (1M context) — `claude-opus-4-7[1m]`. Single-task dev agent.

### Debug Log References

- Login spec (post-migration): `ng test --include='**/login.component.spec.ts'` → 15 pass, 0 fail (was 14 pass before the migration's new network-error spec).
- SideNav spec: `ng test --include='**/side-nav.component.spec.ts'` → 16 pass, 0 fail (was 13 pass before the three new config-driven specs).
- Full suite: `ng test` → **683 pass, 0 fail**. No regressions from the JsonDisplay gutter color swap or the RevisionTree badge token swap.

### Completion Notes List

- **Task 1 (login.component migration).** `login.component.ts` now consumes the canonical `mapError()` for every error branch. The login-specific 401 fallback (friendly "Name or password is incorrect." when `/_session` returns a bare 401 without a JSON envelope) is preserved via a post-mapError refinement check — a new spec covers it. The existing 401-with-body test kept the same assertion surface but now stubs an `HttpErrorResponse` so `mapError()` recognizes it as HTTP vs a plain error object. Final `err.status === 0` grep confirms the only remaining hit in `ui/src/` is `services/error-mapping.ts` itself.
- **Task 2 (SideNav config-driven).** `NAV_ENTRY_CONFIG` is a module-level `readonly` array of `PerDbNavEntry` records with `{id, label, route(ctx), enabled(ctx), tooltip(ctx)}`. Kept the file contained (no separate `side-nav.config.ts`) because total additions landed well under the 20-line threshold in the story guidance. `updateNavScope()` now `.map`s the config through a private `toNavItem()` helper that preserves the Story 11.4 disabled-with-tooltip contract exactly (empty `route`, `disabled: true`, tooltip from the config function). The existing template and `FocusKeyManager` wiring are unchanged. Added three new specs: canonical-ids invariant, config-append adds an extra `<li>` with correct href, and disabled-with-tooltip branch survives the refactor.
- **Task 3 (19 LOW triage).** 2 resolved in 12.0 (JsonDisplay gutter contrast, RevisionTree badge font-size), 17 kept deferred with named revisit triggers, 0 escalated. No sprint-status follow-ups added. The `security-view.component.spec.ts` axe-rule scope-disable for `color-contrast` was removed since the fix is in place; full axe-core pass runs green for the 10-line default `_security` body. All annotations applied inline in `deferred-work.md` (strike-through for resolved items, `-- **KEPT DEFERRED (2026-04-17, Story 12.0):** ...` suffix for kept ones).
- **Task 4 (research-first rule).** Added "Task 0 backend-surface probe (Epic 12+ story creation)" subsection under "IRIS/ObjectScript emphasis". Process rule, not code. Specifies `curl -u _system:SYS` probe, verbatim expected output pasted into Tasks, and a concrete reference read cited in Dev Notes. Epic 12-specific guidance: cite `documentation/IRIS_Embedded_Python_Complete_Manual.md` for `%SYS.Python` consumers; cite couchjs line protocol in `sources/couchdb/share/server/` for `$ZF(-1)` consumers. No existing rules reordered.
- **Task 5 (TL;DR seed).** Inserted `## Open Items Summary (as of 2026-04-17)` at the top of `deferred-work.md`. HIGH is empty; 3 MEDIUM items (10.3 ErrorDisplay coverage, 10.4 delete trigger, 11.0 smoke runner); LOW split into ObjectScript-backend vs Angular-UI for scannability. Convention statement at the top names the maintenance protocol: future `X.0` cleanup stories strike the full entry AND remove the bullet here to close a line. Anchors use GitHub-style slug derivation from the `## Deferred from: ...` headings — slugifies predictably and no special handling was required.
- **Task 6 (sprint-status).** Entry was pre-seeded by the lead. Confirmed present at story start; flipped to `in-progress` on 2026-04-17, now `review`.
- **No new subscriptions.** Task 1 touches `login.component.ts` which already subscribes directly to `authService.login()`. The subscription shape was preserved; `mapError()` is a pure synchronous function. No need to invoke the subscription-leak prevention pattern from `.claude/rules/angular-patterns.md`.
- **No hardcoded colors.** All color changes went through design tokens. The `--color-neutral-600` swap in `json-display.component.ts` and the `--font-size-xs` swap in `revision-tree.component.ts` are both token-only.

### File List

Angular (created/modified):

- `ui/src/app/features/auth/login.component.ts` — migrated to `mapError()`; preserved 401-no-body friendly fallback.
- `ui/src/app/features/auth/login.component.spec.ts` — added network-error spec; promoted plain-object error stubs to `HttpErrorResponse`; added 401-no-body fallback spec.
- `ui/src/app/couch-ui/side-nav/side-nav.component.ts` — added `NavContext`, `PerDbNavEntry`, `NAV_ENTRY_CONFIG`; introduced `navEntryConfig` component field; extracted `toNavItem()` helper; replaced inline per-db items array with `.map()` over the config.
- `ui/src/app/couch-ui/side-nav/side-nav.component.spec.ts` — three new specs under "config-driven rendering (Story 12.0)".
- `ui/src/app/couch-ui/json-display/json-display.component.ts` — gutter `color` bumped from `--color-neutral-400` to `--color-neutral-600` (WCAG AA fix for 10+ line bodies).
- `ui/src/app/couch-ui/revision-tree/revision-tree.component.ts` — badge `font-size: 12px` swapped to `var(--font-size-xs)`.
- `ui/src/app/features/security/security-view.component.spec.ts` — removed the scoped `color-contrast` axe rule disable now that the gutter is fixed.

Docs / rules (modified):

- `.claude/rules/research-first.md` — appended "Task 0 backend-surface probe (Epic 12+ story creation)" subsection.
- `_bmad-output/implementation-artifacts/deferred-work.md` — added `Open Items Summary (as of 2026-04-17)` TL;DR at top; annotated 19 Epic 11 LOW items inline with resolve/kept decisions.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — flipped `12-0-epic-11-deferred-cleanup` ready-for-dev → in-progress → review; bumped `last_updated`.
- `_bmad-output/implementation-artifacts/12-0-epic-11-deferred-cleanup.md` — this story file.

### Change Log

- 2026-04-17: Story 12.0 implementation complete — login.component migrated to `mapError()`; SideNav refactored to `NAV_ENTRY_CONFIG`; 19 Epic 11 LOW deferrals triaged (2 resolved, 17 kept, 0 escalated); Task-0 backend-probe rule added to `.claude/rules/research-first.md`; TL;DR summary seeded in `deferred-work.md`. All 683 UI specs pass.
- 2026-04-17: Code review complete — clean review, all 5 ACs satisfied, 683/683 specs pass, zero HIGH/MEDIUM findings, no auto-resolve patches needed. Status → done.

### Review Findings

Adversarial review run 2026-04-17 across three layers (Blind Hunter, Edge Case Hunter, Acceptance Auditor).

**Result: clean — 0 HIGH/MEDIUM/CRITICAL findings, 0 patches required, 0 new deferrals.**

- [x] AC #1 satisfied — `err.status === 0` grep in `ui/src/` returns only `services/error-mapping.ts:21`; login-spec stubs `HttpErrorResponse` with `status: 0` and asserts byte-identical reason text via `mapError()`.
- [x] AC #2 satisfied — `PerDbNavEntry` interface and `NAV_ENTRY_CONFIG` present; `updateNavScope()` produces items from a single `.map()`; disabled-with-tooltip + aria-disabled + keyboard-focus all covered by new + existing specs (16/16 pass).
- [x] AC #3 satisfied — 19 Epic 11 LOW items annotated (2 RESOLVED + 17 KEPT DEFERRED, 0 escalated); RESOLVED items map to concrete code changes (`json-display` gutter color token swap, `revision-tree` badge font-size token swap, `security-view.component.spec.ts` axe scope-disable removed).
- [x] AC #4 satisfied — "Task 0 backend-surface probe (Epic 12+ story creation)" subsection placed under "IRIS/ObjectScript emphasis" in `research-first.md`; no other rule sections reordered.
- [x] AC #5 satisfied — "Open Items Summary (as of 2026-04-17)" section seeded at top of `deferred-work.md`, HIGH empty, 3 MEDIUM + 47 LOW bulleted with per-item anchors; spot-checked anchor slugs resolve.
- [x] Test suite: 683/683 pass (matches dev's reported count exactly).
- [x] No hardcoded hex/rgba in touched component CSS (per `.claude/rules/angular-patterns.md`) — only comment references to tokens in `json-display.component.ts`.
- [x] No new `.subscribe()` calls added. `login.component.ts` subscription was preserved deliberately per Dev Notes; `submitting` guard prevents re-entry.

Dismissed noise:

- Login 401 friendly-fallback uses case-sensitive compare (`mapped.display.error !== 'unauthorized'`). Works today because `mapError()` returns the `err.statusText` verbatim for a no-body 401 (typically `"Unauthorized"`, capital U). A new spec (`uses friendly "Name or password is incorrect." fallback when 401 has no error body`) pins this contract. Not a bug.
- SideNav `setTimeout` in the new config-driven specs could fire after fixture teardown. Same pattern pre-exists from Story 11.4; full suite runs green. Not a regression.
