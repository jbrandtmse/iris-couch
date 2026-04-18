# Story 13.0: Epic 12 Deferred Cleanup

Status: review

## Story

As a developer,
I want to close the Epic 12 retrospective action items, codify the three distribution-safety rules that came out of the Story 12.4 Python deferral, and triage the outstanding Epic 12 LOW findings before starting the Epic 13 documentation work,
so that Epic 13 (predominantly markdown + CI-gated working examples) begins with a clean engineering-side ledger, every operator-facing invariant discovered during Epic 12 is written down where the implementing developer will see it, and the compile-on-any-IRIS guarantee is a PRD-level NFR rather than a retro-doc aspiration.

## Acceptance Criteria

1. **Given** the Epic 12 retrospective identified that Story 12.4's Python deferral exposed a pre-flight gap (the `/bmad-create-story` workflow writes 300+ lines of spec before the first environment check runs) and named this as the highest-value preventive measure for any backend-integration story whose Task 0 depends on a runtime capability the dev host may lack
   **When** Story 13.1 or any subsequent backend-integration story is created via `/bmad-create-story`
   **Then** `.claude/rules/research-first.md` contains a new subsection under **Task 0 backend-surface probe** that codifies the pre-flight dev-environment capability check: the dev host must be able to exercise the story's core capability (e.g., `%SYS.Python.Import("sys")` succeeds, `$ZF(-100)` round-trips a no-op, `irispip` is on PATH) **before** any acceptance criteria are authored, and the Task 0 output for such stories must include the verbatim terminal output of that capability probe alongside the existing `curl` probe

2. **Given** the Epic 12 retrospective identified that Story 12.2's view-query-parameter scope cut was silently absent from the README until Josh surfaced it in the retro discussion, even though the cut was documented in the story file, in `deferred-work.md`, and in the commit message
   **When** any future story is deferred, scope-cut, or ships a known operator-observable limitation
   **Then** `.claude/rules/research-first.md` contains a process rule (under the **Task 0 backend-surface probe** subsection or equivalent) stating that `README.md` must be updated **in the same commit** as the sprint-status flip or scope-cut commit, naming the deferred backend / cut feature / new prerequisite so that operator-facing state is never only visible to the dev team

3. **Given** the Epic 12 retrospective identified that if Story 12.4 had *succeeded* on a Python-enabled dev host, the resulting `[Language = python]` methods in IRISCouch classes would have failed to compile at install time on any Python-less IRIS instance — an install-breaking regression for every customer whose IRIS build doesn't include Python — and named this as the single highest-value finding of the retro
   **When** Story 12.4 resumes on a Python-enabled host, or any future story is tempted to reach for `[Language = python]` for any reason
   **Then** `.claude/rules/iris-objectscript-basics.md` contains a new **Python Integration Distribution Rules** subsection (placed after the existing **Python Integration** section) that codifies four invariants as a release-gate rule: (a) zero `[Language = python]` methods may appear in any shipped `.cls` file under `src/IRISCouch/`, (b) Python bridges (e.g., `jsruntime.py`) ship as ZPM `<FileCopy>` resources, never embedded in a class, (c) `irispip install <package>` is documented as an operator prerequisite, never invoked from a ZPM install hook, and (d) `zpm install iris-couch` must succeed on an IRIS instance regardless of embedded Python availability

4. **Given** the Epic 12 retrospective Action Item #10 committed to adding a new NFR to the PRD covering the compile-on-any-IRIS invariant, and the PRD at `_bmad-output/planning-artifacts/prd.md` currently lists no NFR enforcing Python-optional compilation
   **When** Story 13.1's compatibility matrix work references the PRD for authoritative NFR numbering
   **Then** `prd.md` contains a new numbered NFR (next available NFR-x slot after the existing Epic 9 operational NFRs) that reads substantially as: *"IRISCouch ObjectScript classes MUST compile and the IRISCouch ZPM package MUST install on any IRIS 2024.1+ instance regardless of embedded Python availability. Shipped `.cls` files MUST NOT contain `[Language = python]` methods; Python integration (when/if present) MUST ship as ZPM `<FileCopy>` resources with `irispip` documented as an operator-executed prerequisite."* — and the NFR is cross-referenced from AC #3's new rule section in `iris-objectscript-basics.md`

5. **Given** the Epic 12 code-review deferrals contain 21 Story 12.x LOW items (3 from 12.1, 3 from 12.2 review + 3 from 12.2 impl, 5 from 12.3 review, 7 from 12.5 review — all listed in `deferred-work.md`) and the existing Open Items Summary at the top of `deferred-work.md` was seeded by Story 12.0 with the maintenance protocol that every `X.0` cleanup story walks the outstanding items and records a disposition
   **When** each Epic 12 LOW item is reviewed against the current codebase
   **Then** every item gets an explicit decision recorded back into `deferred-work.md` as one of: (a) **resolved in 13.0** (with the commit reference that closes it), (b) **kept deferred** with a one-line rationale that names the specific condition under which we would revisit, or (c) **escalated to MEDIUM** with a follow-up story or sub-task added to sprint-status — and the Story 13.0 triage table below records every decision, and the Open Items Summary at the top of `deferred-work.md` is updated to remove resolved items and add any newly-escalated MEDs

6. **Given** the Epic 12 retrospective deferred Action Items #5 and #9 (Python-less IRIS CI image + `zpm install` release gate) together as "a small story for Python-less IRIS CI image" with no decided owner, and Action Items #7 and #8 (Python bridge ZPM `<FileCopy>` resource, verify ZPM `<FileCopy>` syntax in Task 0) as Story 12.4 resumption prerequisites
   **When** Story 12.4 resumes, or Epic 13 infrastructure work is planned
   **Then** `deferred-work.md` contains explicit entries for each of Action Items #5, #7, #8, #9 with the trigger condition "when Story 12.4 resumes" attached, so the four items cannot be forgotten when 12.4 gets picked back up

## Triage Table: Epic 12 Retrospective Action Items

| # | Action Item | Decision | Rationale | Mapped AC |
|---|-------------|----------|-----------|-----------|
| 1 | Pre-flight dev-environment capability check at story creation | **Include (process rule)** | Retro named this as the highest-value preventive measure for any backend-integration story. Codify in `.claude/rules/research-first.md` as an extension to the Task-0 backend-surface probe subsection. | AC 1 |
| 2 | README update in same commit as any deferral or scope cut | **Include (process rule)** | Operator-facing state must be reflected in README, not only story files / `deferred-work.md` / commit messages. Retro-explicit. | AC 2 |
| 3 | Story 13.1 compatibility matrix must document Epic 12's shipped state | **Drop from 13.0 — belongs in 13.1 spec** | This is a scope requirement for Story 13.1 itself, not Story 13.0 cleanup. The create-story invocation for 13.1 will embed this requirement directly. Log-only here. | — |
| 4 | Story 13.2 troubleshooting runbook must cover JSRuntime failure modes | **Drop from 13.0 — belongs in 13.2 spec** | Same rationale as #3: scope requirement for Story 13.2, not cleanup work. Log-only. | — |
| 5 | Small story for Python-less IRIS CI image + `zpm install` release gate | **Defer with named trigger** | Retro explicitly said "Owner: TBD, lives in Epic 13 or standalone." Not actionable in 13.0 without a CI-image pick (Alpine IRIS Community? InterSystems official Python-free?) — record as deferred and flag against Story 12.4 resumption. | AC 6 |
| 6 | Zero `[Language = python]` methods in any shipped `.cls` file | **Include (distribution rule)** | Release-gate rule; if any future story tempts a `[Language = python]` shortcut, this rule is where the reviewer should catch it. Codify in `.claude/rules/iris-objectscript-basics.md`. | AC 3 |
| 7 | Python bridge (`jsruntime.py`) ships as ZPM `<FileCopy>` resource | **Defer with named trigger (12.4 resumption)** | Same-bucket as rule #6 but implementation-specific; reviewer's release-gate check catches rule #6 first. Defer the ZPM-specific instruction to 12.4 resumption where it's actionable. | AC 6 |
| 8 | Verify ZPM `<FileCopy>` syntax in Task 0 before writing code | **Defer with named trigger (12.4 resumption)** | Task-0 prep instruction for 12.4 specifically; not a generalizable rule. | AC 6 |
| 9 | Compile + install on Python-less IRIS as a release gate | **Defer with named trigger (12.4 resumption)** | Merges with #5; record once under 12.4-resumption block. | AC 6 |
| 10 | Add NFR to PRD covering compile-on-any-IRIS | **Include (PRD edit)** | Retro named this as Epic 13 kickoff task. Updates PRD and cross-references the `iris-objectscript-basics.md` rule from AC #3. | AC 4 |

## Triage Table: Epic 12 LOW Deferrals (AC 5 placeholder — dev to fill in)

The dev agent executing this story **must** review each item in `deferred-work.md` under the headings listed below (all tagged `Story 12.x` or `Epic 12 cleanup`), record its disposition in the triage table, and patch `deferred-work.md` with the decision inline (strike through resolved items, append `-- **KEPT DEFERRED (2026-04-18, Story 13.0): [rationale]**` to kept items, escalate with sprint-status entry if warranted).

| Story | Item (short form) | Decision (resolved / kept / escalated) | Rationale / Commit |
|-------|-------------------|----------------------------------------|---------------------|
| 12.1 | `Util.Error.Render501` `pSubsystem` parameter unused in response body | **KEPT DEFERRED** | Revisit trigger: Story 12.2+ richer-error-metadata work. No Story 13.0 fix — touching Render501 outside an error-envelope story risks scope creep. |
| 12.1 | `Factory.GetSandbox()` logs unrate-limited Warn on garbage config | **KEPT DEFERRED** | Log hygiene; fires only under misconfiguration. Revisit if a customer reports log spam traced here. |
| 12.1 | `iris_execute_tests` class-level discovery only reports 3/11 methods (individual runs pass) | **KEPT DEFERRED** | Story 13.0 Task 0 re-probed MCP: class-level discovery on `JSRuntimeHttpTest` still returns only 1 method; ViewIndexHttpTest returns the expected 7. Upstream `iris-dev-mcp` bug. No IRISCouch fix. |
| 12.2 review | `QueryEngine.Query` double-resolves the winning rev per document | **KEPT DEFERRED** | Tagged for Story 12.2a (View Query Parameters); natural home alongside pagination/iterator refactor. |
| 12.2 review | `SubprocessTestRunner` / `SubprocessTestRunner.ProbeManager` temp helpers still in codebase | **KEPT DEFERRED** | MCP test-discovery bug still reproduces (Task 0 confirms). Probe helpers are the only full-suite runner. Revisit on MCP upstream fix. |
| 12.2 review | `Subprocess.ExecuteReduce` does not validate the `reset` ack before reading reduce response | **KEPT DEFERRED** | Diagnostic-quality only; pair with ExecuteValidateDocUpdate ack-validation fix under a single future "subprocess diagnostics" story. |
| 12.2 impl | Subprocess per-query lifecycle is slow for small views (80–150ms cold start) | **KEPT DEFERRED** | Query hot-path cold-start removed by Story 12.5 incremental indexing; write-time / changes-filter cold-start remains Story 12.5b scope. |
| 12.2 impl | Subprocess `JSRUNTIMETIMEOUT` not enforced at `$ZF(-100)` level (superseded by 12.5 two-layer fix) | **KEPT DEFERRED (historical)** | Already resolved in Story 12.5 (`couchjs-entry.js` self-kill + IRIS `/ASYNC` polling kill). Kept as KEPT DEFERRED for audit continuity rather than stealth-resolve. |
| 12.2 impl | `iris_execute_tests` MCP work-queue instability; required temp inline test runner | **KEPT DEFERRED** | Same tooling bug as Story 12.1 / 12.3 MCP-discovery entries. Still reproduces in Story 13.0 probe. |
| 12.3 review | `Test/SubprocessValidateProbe.cls` retained as evidence-of-work scaffolding; delete at 13.0 or next retro | **KEPT DEFERRED** | MCP class-level discovery still broken (Task 0 re-probed) — probe class's `RunAllValidateHttpTests` / `RunAllFilterHttpTests` helpers remain the workaround. Cannot safely delete. |
| 12.3 review | `Subprocess.ExecuteValidateDocUpdate` does not validate `reset` ack or `ddoc-new` ack before invoke response | **KEPT DEFERRED** | Pairs with ExecuteReduce ack entry; single revisit trigger covers both. |
| 12.3 review | Hardcoded `NODEPATH = "C:\Program Files\nodejs\node.exe"` in JSRuntimeValidateHttpTest / FilterHttpTest / Probe | **KEPT DEFERRED** | Tests skip gracefully on non-Windows via `CanLaunchSubprocess`. Revisit when the Python-less CI image (12.4-resumption block) lands and we need Linux-path Node discovery. |
| 12.3 review | MCP `iris_execute_tests` class-level discovery reports 1/9 for Validate, 1/4 for Filter (individual runs pass) | **KEPT DEFERRED** | Same tooling bug as 12.1 / 12.2. Upstream `iris-dev-mcp` issue, not IRISCouch. |
| 12.3 review | `RunValidateHook` uses `$ZHorolog` (local time, not monotonic) for duration; midnight crossing yields negative | **KEPT DEFERRED** | Project-wide convention (same pattern in Stories 9.3 / 12.2). Fix should be a single sweeping change across all call sites; correcting one in isolation is worse than leaving all three consistent. |
| 12.5 review | `Pool.ShutdownAll` never invoked (no-op in shim; wire when 12.5b lands real pooling) | **KEPT DEFERRED** | Trigger: Story 12.5b resumption. No pooled subprocesses in the shim, so no behaviour gap today. |
| 12.5 review | `Pool.cls` docstring overstates stack-LIFO implementation vs actual shim | **RESOLVED in 13.0** | `Pool.cls` docstring storage block rewritten to mark "Planned for Story 12.5b — shim today" adjacent to the future LIFO-stack layout. Class compiles clean. |
| 12.5 review | `EncodeKeyForSort` bool/integer ambiguity sentinel is dead code | **RESOLVED in 13.0** | Dead `If (pKey = 1) && ($Get(pKey) = 1) && ('$Listvalid(pKey)) {…}` block removed from `Storage/ViewIndex.cls`; replaced with one-line comment. `ViewIndexTest` 8/8 still pass. |
| 12.5 review | Byte-equality claim covers only a single 10-doc fixture; broader coverage belongs in 12.2a | **KEPT DEFERRED** | Trigger: Story 12.2a ships the broader byte-equality harness; home already named. |
| 12.5 review | `TestPooledSubprocessReducesLatency` name misleads — measures warm-index latency, pool is still a shim | **RESOLVED in 13.0** | Method renamed to `TestWarmIndexReducesLatency` with clarifying docstring. `ViewIndexHttpTest` 7/7 pass after rename. |
| 12.5 review | `Pipe.IsProcessDead` tasklist probe leaks temp file on probe-time exception | **KEPT DEFERRED** | IRIS startup scrub reclaims temp files; no correctness impact. Revisit trigger: temp-dir free-space alert in operations. |
| 12.5 review | `Pipe.SandboxFlags` `|`-delimiter fragile if future flag values contain `|` | **KEPT DEFERRED** | Speculative; no current flag contains `|`. Revisit when the first flag with a `|`-containing value is added. |

**Summary:** 3 resolved in 13.0 (Pool docstring tightening, EncodeKeyForSort dead-code removal, test rename), 18 kept deferred with named revisit triggers, 0 escalated to MEDIUM. Matches the Story 12.0 healthy-outcome pattern (2–4 resolved + majority kept with triggers + 0 escalations). No sprint-status follow-up sub-stories required.

**Trivial fixes executed under Task 5 (bundled with Story 13.0 commit):**
- `src/IRISCouch/JSRuntime/Subprocess/Pool.cls` — storage-layout docstring block rewritten to mark "Planned for Story 12.5b — shim today".
- `src/IRISCouch/Storage/ViewIndex.cls` — removed dead bool/integer sentinel block at lines 82-85; one-line comment left in place.
- `src/IRISCouch/Test/ViewIndexHttpTest.cls` — `TestPooledSubprocessReducesLatency` renamed to `TestWarmIndexReducesLatency` with updated docstring.

All three files compiled clean via `iris_doc_compile ck` flags. `IRISCouch.Test.ViewIndexTest` (8/8 pass) and `IRISCouch.Test.ViewIndexHttpTest` (7/7 pass) verified green post-change.

**Reminder to dev agent:** The Story 12.0 pattern is to aim for **2–4 resolved + majority kept-deferred with named triggers + 0 escalations** as the healthy outcome. If the LOW list would expand `deferred-work.md` past usability, bias toward resolving cheap fixes. Do not escalate to MEDIUM unless the original disposition was genuinely wrong (new evidence since code review).

## Triage Table: Epic 12 Deferred 12.4-Resumption Entries (AC 6)

When Story 12.4 (Python JSRuntime backend) resumes on a Python-enabled dev host, the following deferred items must be revisited. Each is already listed elsewhere in `deferred-work.md` under its originating story; this table consolidates them under a single trigger so they cannot be forgotten.

| Source Action Item | Item | Trigger |
|--------------------|------|---------|
| AI #5 / #9 | Python-less IRIS CI image + `zpm install iris-couch` release-gate job | When Story 12.4 resumes OR when Epic 14 DevOps infra is planned — whichever comes first |
| AI #7 | Python bridge (`jsruntime.py`) ships as ZPM `<FileCopy>` resource, NEVER embedded in `.cls` | When Story 12.4 resumes (pre-first-commit) |
| AI #8 | Verify ZPM `<FileCopy>` `Target=` vs `Dir=` attribute syntax against current ZPM docs (Charlie's caveat) | When Story 12.4 resumes (pre-first-commit, Task 0) |

**Dev task:** append a single new `## Deferred for Story 12.4 resumption (added 2026-04-18, Story 13.0)` section to `deferred-work.md` with these three items, linked back to the Epic 12 retrospective AI numbers. Already-named Story 12.4 deferral stays where it is in the MED section; this new section consolidates the *resumption prerequisites*.

## Tasks / Subtasks

- [x] **Task 0: Pre-flight verification (process rule compliance)** (AC: #1)
  - [x] Confirmed the dev host can exercise the three primitives referenced by AC #1's capability-check language: (a) `%SYS.Python.Import("sys")` errors on this Python-less host, (b) `$ZF(-100)` round-trips a no-op command, (c) `curl -u _system:SYS http://localhost:52773/iris-couch/_session` returns the auth envelope.
  - [x] Pasted verbatim terminal output for each of (a), (b), (c) into the **Dev Agent Record → Debug Log References** section below.
  - [x] Self-application of the new rule succeeded: probe (a) failed with the exact "Failed to Load Python" error predicted by the rule wording; that refusal output is preserved in the Debug Log for future reference. The rule is usable in practice — no wording revision required.

- [x] **Task 1: Append pre-flight capability-check rule to research-first.md** (AC: #1)
  - [x] Located the existing **Task 0 backend-surface probe (Epic 12+ story creation)** subsection in `.claude/rules/research-first.md`.
  - [x] Added new numbered item 4: **"Pre-flight dev-environment capability check (added 2026-04-18, Story 13.0 from Epic 12 retro AI #1)"**.
  - [x] Item 4 states when to probe (story capability depends on a runtime primitive — embedded Python, `irispip` package, subprocess toolchain, filesystem path, external CLI) and what to do on failure (escalate to user for defer/drop decision before writing 300+ lines of spec). Story 12.4 cited as the failure mode. Lists probe forms for Embedded Python / `$ZF(-100)` / External CLI / HTTP endpoint.
  - [x] Kept the existing three numbered items (live `curl` probe, verbatim expected output, concrete reference citation) unchanged.
  - [x] Markdown renders clean — no broken lists, no heading level regressions.

- [x] **Task 2: Append README-in-same-commit rule to research-first.md** (AC: #2)
  - [x] Added numbered item 5 in the same **Task 0 backend-surface probe** subsection: **"Operator-facing state must ride the commit (added 2026-04-18, Story 13.0 from Epic 12 retro AI #2)"**.
  - [x] Item 5 states: when a story is deferred, scope-cut, or ships a known operator-observable limitation, `README.md` MUST be updated in the same commit as the sprint-status flip or scope-cut commit. Story 12.2 view-query-parameter scope cut cited as the failure mode.
  - [x] Noted that internal refactors / test renames / implementation-detail changes do not require README updates — rule applies to operator-observable state only.

- [x] **Task 3: Codify Python distribution rules in iris-objectscript-basics.md** (AC: #3)
  - [x] Located the existing **Python Integration** section in `.claude/rules/iris-objectscript-basics.md`.
  - [x] Appended new subsection **"Python Integration Distribution Rules (added 2026-04-18, Story 13.0 from Epic 12 retro AI #6)"** immediately after the existing Python Integration block.
  - [x] Subsection codifies the four invariants as a release-gate rule (no `[Language = python]` in shipped classes, Python bridges ship as ZPM `<FileCopy>` resources, `irispip` documented as operator prerequisite never invoked from install hooks, `zpm install iris-couch` must succeed on Python-less IRIS).
  - [x] Cross-referenced PRD NFR-M9 (Python-Optional Compilation, added under Task 4).
  - [x] Included the cited reason: "Epic 12 retrospective Action Items #6–#9 + NFR-M9 (2026-04-17). Story 12.4 deferral exposed the distribution risk; this rule prevents ship-breaking `[Language = python]` from re-entering the codebase when 12.4 resumes."

- [x] **Task 4: Add compile-on-any-IRIS NFR to the PRD** (AC: #4)
  - [x] Opened `_bmad-output/planning-artifacts/prd.md` and located the NFR block.
  - [x] Found the next available Maintainability & Operability slot — NFR-M9 (last existing was NFR-M8 "Release cadence").
  - [x] Inserted **NFR-M9 — Python-Optional Compilation** immediately after NFR-M8.
  - [x] Body text adapted to the PRD's existing voice: compile-on-any-IRIS invariant, no `[Language = python]` in shipped classes, ZPM `<FileCopy>` distribution model, `irispip` as operator prerequisite, release-gate CI verification on a Python-less IRIS Community image when that CI image lands (else manual verification).
  - [x] Cross-referenced back to `.claude/rules/iris-objectscript-basics.md::Python Integration Distribution Rules` for the code-review enforcement rule; cited origin is Epic 12 retrospective Action Items #6–#10.

- [x] **Task 5: Triage Epic 12 LOW deferrals** (AC: #5)
  - [x] Reviewed each of the 21 items in the **Triage Table: Epic 12 LOW Deferrals** above against the current codebase; decided resolve/keep/escalate per the triage table's Decision column.
  - [x] Outcome: 3 resolved in 13.0 (Pool docstring tightening, EncodeKeyForSort dead-code removal, `TestPooledSubprocessReducesLatency` rename), 18 kept deferred with named revisit triggers, 0 escalated to MEDIUM. Matches the Story 12.0 healthy-outcome pattern.
  - [x] Three trivial fixes executed and bundled with Story 13.0 (no separate commit per fix):
    - `src/IRISCouch/JSRuntime/Subprocess/Pool.cls`: rewrote the storage-layout docstring block to mark "Planned for Story 12.5b — shim today" adjacent to the future LIFO-stack layout.
    - `src/IRISCouch/Storage/ViewIndex.cls`: removed dead bool/integer sentinel block at lines 82-85; replaced with a one-line comment explaining why the block was dead.
    - `src/IRISCouch/Test/ViewIndexHttpTest.cls`: renamed `TestPooledSubprocessReducesLatency` → `TestWarmIndexReducesLatency` with clarifying docstring.
  - [x] Annotated all 18 kept-deferred items in `deferred-work.md` (both in the top Open Items Summary and in the per-story-deferred full entries where appropriate) with `-- **KEPT DEFERRED (2026-04-18, Story 13.0): [rationale]**` suffixes naming the specific revisit condition.
  - [x] Strike-through (`~~...~~`) applied to the three resolved items in the Open Items Summary and in the per-review-section full entries, with `-- **RESOLVED in Story 13.0 (2026-04-18)**: …` summary suffix.
  - [x] Confirmed 0 items required escalation to MEDIUM (no new evidence since code review for any LOW; all had correct original dispositions).
  - [x] Open Items Summary at the top of `deferred-work.md` date-stamp updated ("as of 2026-04-18, post Story 13.0 triage"); three resolved items retained in the summary with strike-through + resolution marker per the convention Story 12.0 established.
  - [x] MCP `iris_execute_tests` class-level discovery re-probed during triage: still broken (returns 1 method for `JSRuntimeHttpTest` where 11 exist). This confirmed all MCP-discovery-related LOW items must stay KEPT DEFERRED — probe-helper classes (`SubprocessValidateProbe`, `SubprocessTestRunner`, `ProbeManager`) cannot be safely deleted.
  - [x] Post-change validation: `IRISCouch.Test.ViewIndexTest` 8/8 pass, `IRISCouch.Test.ViewIndexHttpTest` 7/7 pass (including renamed `TestWarmIndexReducesLatency`). All three modified classes compile clean under `iris_doc_compile ck`.

- [x] **Task 6: Append 12.4-resumption deferred block to deferred-work.md** (AC: #6)
  - [x] Added a new top-level section `## Deferred for Story 12.4 resumption (added 2026-04-18, Story 13.0)` immediately after the Open Items Summary and its `---` separator, before the per-story-deferred sections.
  - [x] Populated with three entries from the triage table: (1) AI #5 + #9 merged — Python-less IRIS CI image + `zpm install` release gate; (2) AI #7 — `jsruntime.py` ships as ZPM `<FileCopy>`; (3) AI #8 — verify ZPM `<FileCopy>` `Target=`/`Dir=` attribute syntax in Task 0.
  - [x] Each entry names the Epic 12 retro AI number, states the trigger condition ("When Story 12.4 resumes", or "When Epic 14 DevOps infra is planned, whichever is first"), and cross-references the Epic 12 retrospective file.
  - [x] Confirmed Epic 12 retro AI #4 (the Story 12.4 Python backend deferral itself) stays where it already is in the MED list — this new section consolidates *resumption prerequisites* only, not the deferral decision.

- [x] **Task 7: Add Story 13.0 to sprint-status.yaml** (structural)
  - [x] Confirmed presence: `13-0-epic-12-deferred-cleanup: ready-for-dev` and `epic-13: in-progress` were pre-seeded at story creation on 2026-04-18.
  - [x] Flipped `13-0-epic-12-deferred-cleanup` to `in-progress` at story start (Task 0 completion).
  - [x] Will flip to `review` at Step 9 completion gate (story-file Status transition triggers this).
  - [x] Updated `last_updated` timestamp to `2026-04-18 (Story 13.0 in-progress; epic-13 in-progress)`.

## Dev Notes

### Why this cleanup is documentation + rules

All four INCLUDED Epic 12 action items (#1 process rule, #2 process rule, #6 distribution rule, #10 PRD NFR) are markdown edits to rules files or the PRD. There is no ObjectScript to write, no Angular to modify, no test to author — only the LOW triage in Task 5 may produce code changes, and the story spec scopes those to "cheap fixes only, bundled with the cleanup commit." This is intentional: Story 13.0's job is to unblock Epic 13 (documentation + working examples), not to sneak backend work in under the cleanup banner.

### Previous Story Intelligence

- **Story 12.0** established the `X.0` cleanup pattern for this codebase — Retrospective Action Items + LOW triage + rule-file edits, all triaged into a single triage-table at the top of the story and checkbox-annotated in the deferred-work.md file. Story 13.0 follows that pattern exactly. The table structure (#, Action Item, Decision, Rationale, Mapped AC) is identical; only the content changes.
- **Story 12.0 also seeded the Open Items Summary** at the top of `deferred-work.md`. That summary must be updated by every subsequent `X.0` cleanup story — add newly-escalated MEDs, remove newly-resolved items. Do not rewrite the summary structure; edit in place.
- **Story 12.5** landed the incremental indexing + pool API + sandbox hardening that closed 4 MEDs from 12.2/12.3. Those MEDs are no longer in the LOW triage list because they were already resolved; the items in the Epic 12 LOW Deferrals table above are all the *post-12.5* residue. Do not revisit the MED closures — they're done and strike-through in `deferred-work.md` already.

### Capability probes for Task 0 verification (use these exact commands)

For AC #1 self-application:

```bash
# Probe (a): embedded Python availability on this dev host
iris session IRIS -U IRISCOUCH "##class(%SYS.Python).Import(\"sys\")"
# Expected output on THIS dev host (Python-less): ERROR #5002: ... or <PYTHON> error
# Expected output on a Python-enabled host: <PYTHON REFERENCE>

# Probe (b): $ZF(-100) subprocess round-trip
iris session IRIS -U IRISCOUCH "set tSC = $ZF(-100, \"/SHELL\", \"cmd\", \"/c\", \"echo hello\") zw tSC"
# Expected: 0 (success) plus "hello" in the IRIS log stream

# Probe (c): HTTP smoke for curl verification discipline
curl -u _system:SYS -i http://localhost:52773/iris-couch/_session
# Expected: 200 OK with CouchDB /_session auth envelope
```

If (a) fails on the current dev host (likely — Story 12.4 deferral's root cause), paste the actual error verbatim into the Dev Agent Record. That refusal output IS the self-application of the new rule — future readers of 13.0 can see what "Python unavailable" looks like on this host and understand why 12.4 was deferred.

### Subscription discipline

**Not applicable.** Story 13.0 is markdown + rule-file edits. No Angular code, no HTTP subscriptions, no RxJS. The `.claude/rules/angular-patterns.md` subscription-leak rule is not invoked.

### Backend scope

**Minimal.** The LOW triage in Task 5 may produce small code changes:

- Deletion of `src/IRISCouch/Test/SubprocessValidateProbe.cls` (if MCP `iris_execute_tests` stabilized) or `src/IRISCouch/Test/SubprocessTestRunner.cls` + `ProbeManager.cls` (likewise)
- Docstring edit to `src/IRISCouch/JSRuntime/Subprocess/Pool.cls`
- Dead-code removal in `src/IRISCouch/JSRuntime/Subprocess/QueryEngine.cls` (`EncodeKeyForSort` sentinel)
- Test method rename in `src/IRISCouch/Test/ViewIndexHttpTest.cls` (`TestPooledSubprocessReducesLatency` → descriptive name)

If any of these are taken, run `compile_objectscript_package` via MCP after the edit to verify clean compile. No new ObjectScript classes, no new tests. Bundle all edits in the Story 13.0 commit.

### File List (expected)

Rules / docs (modified):

- `.claude/rules/research-first.md` — append items 4 and 5 to **Task 0 backend-surface probe** subsection
- `.claude/rules/iris-objectscript-basics.md` — append **Python Integration Distribution Rules** subsection
- `_bmad-output/planning-artifacts/prd.md` — add new NFR (Python-Optional Compilation)
- `_bmad-output/implementation-artifacts/deferred-work.md` — triage annotations for 21 LOW items + new 12.4-resumption section + Open Items Summary update
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — flip `13-0-epic-12-deferred-cleanup` ready-for-dev → in-progress → review; flip `epic-13: in-progress`; bump `last_updated`

Code (possibly modified under Task 5, dev's call):

- `src/IRISCouch/Test/SubprocessValidateProbe.cls` — possibly deleted
- `src/IRISCouch/Test/SubprocessTestRunner.cls` + `src/IRISCouch/Test/SubprocessTestRunner/ProbeManager.cls` — possibly deleted
- `src/IRISCouch/JSRuntime/Subprocess/Pool.cls` — possibly edited (docstring)
- `src/IRISCouch/JSRuntime/Subprocess/QueryEngine.cls` — possibly edited (dead code)
- `src/IRISCouch/Test/ViewIndexHttpTest.cls` — possibly edited (test rename)

### Project Structure Notes

- No new files, no new components — only edits to existing files plus optional deletions under Task 5.
- The two new rules (AC #1 process rule, AC #3 distribution rule) live in the *existing* rules tree under `.claude/rules/` — no new rule file is created. This matches the Story 12.0 precedent for Task 0 rule additions.
- PRD edit (AC #4) is a single-NFR addition; do not restructure the PRD's NFR numbering or regroup existing NFRs.

### References

- Epic 12 retrospective: `_bmad-output/implementation-artifacts/epic-12-retro-2026-04-17.md` (10 action items, retrospective action item follow-through table, readiness assessment)
- Existing research-first rule: `.claude/rules/research-first.md` (**Task 0 backend-surface probe** subsection added by Story 12.0)
- Existing ObjectScript basics rule: `.claude/rules/iris-objectscript-basics.md` (**Python Integration** section)
- PRD: `_bmad-output/planning-artifacts/prd.md` (NFR list)
- Deferred-work inventory: `_bmad-output/implementation-artifacts/deferred-work.md` (Open Items Summary at top; per-story-deferred sections below)
- Story 12.0 template for pattern replication: `_bmad-output/implementation-artifacts/12-0-epic-11-deferred-cleanup.md`
- Story 12.4 deferral decision: `_bmad-output/implementation-artifacts/12-4-python-jsruntime-backend.md` + `sprint-change-proposal-2026-04-17.md`

## Dev Agent Record

### Agent Model Used

Claude Opus 4.7 (1M context) via Claude Code bmad-dev-story skill.

### Debug Log References

**Task 0 self-application of AC #1 — dev-host capability probe (2026-04-18).** This is the Story 13.0 self-application of the new pre-flight rule. All three probes executed via IRIS-Dev MCP tools on the current dev host, Windows 11 Pro, IRIS instance `IRIS` namespace `IRISCOUCH`.

**Probe (a) — Embedded Python availability** (`##class(%SYS.Python).Import("sys")`):

```
ERROR: <OBJECT DISPATCH> 230 Execute+36^ExecuteMCPv2.REST.Command.1 Failed to Load Python: Check documentation and messages.log, Check CPF parameters:[PythonRuntimeLibrary,PythonRuntimeLibraryVersion], Check sys.path setup in: $INSTANCE/lib/python/iris_site.py
```

This is the exact failure mode that caused Story 12.4 to be deferred. The refusal output IS the self-application of the rule — it proves the rule is operational (a Python-dependent story cannot be authored on this dev host without the user consenting to defer or switch hosts). Future readers of Story 13.0 can see what "Python unavailable" looks like in practice and understand why 12.4 was deferred.

**Probe (b) — `$ZF(-100)` subprocess round-trip** (`$ZF(-100, "/SHELL", "cmd", "/c", "echo hello")`):

```
tSC=0
```

Return code 0 = success. Subprocess round-trip is available on this dev host, which is consistent with the Story 12.2 / 12.3 / 12.5 subprocess JSRuntime functionality still working. The `$ZF(-100)` primitive is usable for any future subprocess-consuming story on this host.

**Probe (c) — HTTP smoke for curl discipline** (`curl -u _system:SYS -i http://localhost:52773/iris-couch/_session`):

```
HTTP/1.1 200 OK
Date: Sat, 18 Apr 2026 08:35:47 GMT
Server: Apache
CACHE-CONTROL: no-cache
EXPIRES: Thu, 29 Oct 1998 17:04:19 GMT
PRAGMA: no-cache
CONTENT-LENGTH: 129
Content-Type: application/json

{"ok":true,"userCtx":{"name":"_system","roles":["%All","%IRISCouch_Admin","IRISCouch_Admin"]},"info":{"authenticated":"default"}}
```

IRISCouch service is up, authentication envelope is returning the expected shape, and the original Story 12.0 `curl` probe discipline still works. This is the baseline the README-in-same-commit rule (item 5) builds on.

**Self-application verdict:** The pre-flight capability-check rule (Task 1) is usable in practice. Probe (a) failed exactly as the rule's prose predicts; no wording revision needed before writing the rule file edit. This story (Story 13.0) did not depend on embedded Python, so the probe (a) failure did not block — but it demonstrates the rule catches the class of defects that made Story 12.4 fail.

**MCP test-discovery re-probe (during Task 5 triage).** Ran `iris_execute_tests` at `level=class` against `IRISCouch.Test.JSRuntimeHttpTest`. Result: `{"total":1,"passed":1,"failed":0,"skipped":0}` — only 1 of the 11 test methods discovered. Same bug reported in Story 12.1 LOW entry. Also verified `IRISCouch.Test.ViewIndexHttpTest` correctly reports all 7 methods, so the bug is per-class, not a blanket MCP failure. This confirmed all MCP-discovery-related LOW items (Story 12.1 entry 3, Story 12.2 review entries, Story 12.2 impl entry, Story 12.3 review entries, Story 12.3 probe classes) must remain KEPT DEFERRED — the probe-helper classes are still the only reliable full-suite runner.

### Completion Notes List

**What was accomplished.** All four INCLUDED Epic 12 retrospective action items (AI #1, #2, #6, #10) were delivered as markdown edits to rules files / PRD; the 21-item Epic 12 LOW triage ran with the Story 12.0 pattern (3 resolved + 18 kept-deferred with named triggers + 0 escalations); 3 cheap fixes executed under Task 5 and bundled with the Story 13.0 commit; the Story 12.4-resumption deferred block was added to `deferred-work.md` to prevent AI #5/#7/#8/#9 being forgotten when 12.4 resumes.

**Key deliverables and their files (absolute paths).**
- `C:\git\iris-couch\.claude\rules\research-first.md` — items 4 (pre-flight capability check) and 5 (README-same-commit) appended to the **Task 0 backend-surface probe** subsection.
- `C:\git\iris-couch\.claude\rules\iris-objectscript-basics.md` — new **Python Integration Distribution Rules** subsection appended after the existing Python Integration block; four release-gate invariants codified.
- `C:\git\iris-couch\_bmad-output\planning-artifacts\prd.md` — new **NFR-M9 — Python-Optional Compilation** added to the Maintainability & Operability NFR block.
- `C:\git\iris-couch\_bmad-output\implementation-artifacts\deferred-work.md` — 21 Epic 12 LOW items triaged and annotated; 3 resolved (strike-through); 18 kept-deferred with revisit-trigger suffixes; new Deferred-for-Story-12.4-resumption section consolidating AI #5/#7/#8/#9.
- `C:\git\iris-couch\src\IRISCouch\JSRuntime\Subprocess\Pool.cls` — storage-layout docstring rewritten to mark the LIFO-stack block "Planned for Story 12.5b — shim today".
- `C:\git\iris-couch\src\IRISCouch\Storage\ViewIndex.cls` — dead bool/integer sentinel block removed from `EncodeKeyForSort`; replaced with a single-line comment.
- `C:\git\iris-couch\src\IRISCouch\Test\ViewIndexHttpTest.cls` — `TestPooledSubprocessReducesLatency` renamed to `TestWarmIndexReducesLatency` with clarifying docstring.
- `C:\git\iris-couch\_bmad-output\implementation-artifacts\sprint-status.yaml` — `13-0-epic-12-deferred-cleanup` flipped ready-for-dev → in-progress → review; `last_updated` timestamp bumped.
- `C:\git\iris-couch\_bmad-output\implementation-artifacts\13-0-epic-12-deferred-cleanup.md` — this story file; triage table filled in, all 8 tasks marked complete, Dev Agent Record populated.

**Triage methodology applied (Story 12.0 pattern).** (i) Resolve items only when the cost is trivially cheap and the fix doesn't require new test coverage; (ii) keep-defer items whose revisit trigger is genuinely future-state (CI image, subsequent story, upstream MCP fix, operator-reported bug); (iii) escalate only on new evidence since code review. Outcome 3/18/0 matches the Story 12.0 healthy envelope (2-4 resolved + majority kept + 0 escalations).

**Compile and test verification.** All three modified ObjectScript classes compiled clean via `iris_doc_compile` with `ck` flags (102ms total). `IRISCouch.Test.ViewIndexTest` (8/8 pass) and `IRISCouch.Test.ViewIndexHttpTest` (7/7 pass — including the renamed `TestWarmIndexReducesLatency`) verified green post-change. No regressions.

**Not in scope.** No new ObjectScript classes created; no Angular changes; no new tests authored. The story file's "Why this cleanup is documentation + rules" note in Dev Notes holds — Story 13.0's job was to unblock Epic 13, not to sneak backend work under the cleanup banner.

### File List

**Modified:**
- `.claude/rules/research-first.md`
- `.claude/rules/iris-objectscript-basics.md`
- `_bmad-output/planning-artifacts/prd.md`
- `_bmad-output/implementation-artifacts/deferred-work.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/13-0-epic-12-deferred-cleanup.md`
- `src/IRISCouch/JSRuntime/Subprocess/Pool.cls`
- `src/IRISCouch/Storage/ViewIndex.cls`
- `src/IRISCouch/Test/ViewIndexHttpTest.cls`

**Created:** (none)

**Deleted:** (none — MCP class-level discovery bug still reproduces, so probe-helper classes must stay in tree as the full-suite workaround)

### Change Log

- 2026-04-18: Story 13.0 file created by `/bmad-create-story` during `/epic-dev-cycle Epic 13` orchestration. Triage tables seeded from Epic 12 retrospective (10 action items) and deferred-work.md (21 Epic 12 LOW items). Status: ready-for-dev.
- 2026-04-18: Story 13.0 implementation complete. Task 0 pre-flight probes captured (all three verbatim in Debug Log References). Tasks 1-4 markdown edits delivered (research-first.md items 4-5; iris-objectscript-basics.md Python Integration Distribution Rules; PRD NFR-M9). Task 5 triage executed: 3 resolved (Pool docstring, EncodeKeyForSort dead code, test rename), 18 kept-deferred with named triggers, 0 escalations. Task 6 added 12.4-resumption deferred block consolidating Epic 12 retro AI #5/#7/#8/#9. Task 7 flipped sprint-status to in-progress → review. All 9 modified files listed in File List. Tests green: ViewIndexTest 8/8, ViewIndexHttpTest 7/7. Status: review.

### Review Findings

_To be filled in by code-review agent_
