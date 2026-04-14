# Story 10.0: Epic 9 Deferred Cleanup

Status: done

## Story

As a developer,
I want to address the Epic 9 retrospective action items before starting Angular frontend work,
so that ObjectScript backend rules are complete and no backend debt carries into the UI epic.

## Acceptance Criteria

1. **Given** the Epic 9 retrospective identified "Security.Events pre-registration" as a lesson learned
   **When** the project rules are reviewed
   **Then** a rule exists in `iris-objectscript-basics.md` documenting that `$System.Security.Audit()` requires pre-registered `Security.Events` and fails silently without them

2. **Given** the Epic 9 retrospective flagged `$Horolog` vs UTC timestamp inconsistency
   **When** the two affected locations are examined (`Storage/Database.cls` and `Replication/Manager.cls`)
   **Then** the timestamps use `$ZTimeStamp` (UTC) instead of `$Horolog` (local time) with the "Z" suffix
   **Or** the inconsistency is documented as a known limitation with rationale for deferral

3. **Given** the deferred work log has 44 open items
   **When** the items are triaged for Epic 10 relevance
   **Then** all 44 items are confirmed as ObjectScript-backend-only with no blockers for Angular frontend work

## Triage Table: Epic 9 Retrospective Action Items

| # | Action Item | Decision | Rationale |
|---|-------------|----------|-----------|
| 1 | Add "Security.Events pre-registration" rule to project rules | **Include** | Quick rule addition, prevents silent audit failure in future ObjectScript work |
| 2 | Verify $Horolog vs UTC timestamp consistency | **Include — document** | Investigate the 2 locations, fix if safe or document as known limitation |

## Triage: Deferred Work (44 open items)

All 44 open deferred work items are ObjectScript backend concerns (storage encapsulation, string limits, stream OID leaks, race conditions, missing attachment support, etc.). **All explicitly deferred** — none are relevant to or block Epic 10 Angular frontend work.

## Tasks / Subtasks

- [x] Task 1: Add Security.Events pre-registration rule (AC: #1)
  - [x] Add a section to `.claude/rules/iris-objectscript-basics.md` documenting:
    - `$System.Security.Audit()` silently returns 0 (failure) if the Source/Type/Name triple is not pre-registered via `Security.Events.Create()` in %SYS namespace
    - Always call an `EnsureEvents()` setup method during installation/upgrade
    - Pattern reference: `IRISCouch.Audit.Emit.EnsureEvents()`

- [x] Task 2: Investigate and resolve $Horolog vs UTC timestamp issue (AC: #2)
  - [x] Read `src/IRISCouch/Storage/Database.cls` line ~27 and `src/IRISCouch/Replication/Manager.cls` lines ~70,170
  - [x] Determine if changing `$Horolog` to `$ZTimeStamp` is safe (check all callers and consumers of these timestamps)
  - [x] Either fix the timestamps to use `$ZTimeStamp` or document the limitation in deferred-work.md with clear rationale
  - [x] If fixed, compile affected classes and run existing tests to verify no regressions

- [x] Task 3: Confirm deferred work triage (AC: #3)
  - [x] Review the 44 open items in `_bmad-output/implementation-artifacts/deferred-work.md`
  - [x] Confirm none are relevant to Epic 10 Angular frontend work
  - [x] Add a triage note at the bottom of deferred-work.md confirming the review

### Review Findings

- [x] [Review][Defer] JWT.UnixTimestamp() uses $Horolog (local time) but doc claims UTC [Auth/JWT.cls:158] -- deferred, pre-existing

**Code review complete.** 0 `decision-needed`, 0 `patch`, 1 `defer`, 1 dismissed as noise.

## Dev Notes

- This is a lightweight cleanup story — primarily rule updates and one timestamp investigation
- The Security.Events rule is a codification of a lesson learned, not a code change
- The $Horolog issue affects `$Translate($ZDateTime($Horolog, 3, 1), " ", "T") _ "Z"` pattern which appends UTC indicator to local server time
- `$ZTimeStamp` returns UTC time natively, making it the correct choice for Z-suffix timestamps
- All 44 deferred items are backend concerns; Epic 10 is purely Angular frontend

### Project Structure Notes

- Rules file: `.claude/rules/iris-objectscript-basics.md`
- Deferred work: `_bmad-output/implementation-artifacts/deferred-work.md`
- ObjectScript source: `src/IRISCouch/`
- No Angular/TypeScript files are touched in this story

### References

- [Source: _bmad-output/implementation-artifacts/epic-9-retro-2026-04-14.md#Action Items]
- [Source: _bmad-output/implementation-artifacts/deferred-work.md#Deferred from: code review of 9-0]
- [Source: .claude/rules/iris-objectscript-basics.md]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
None required -- no debugging needed for this cleanup story.

### Completion Notes List
- Task 1: Added "Security.Events Pre-Registration for Audit" rule section to iris-objectscript-basics.md documenting the silent failure behavior of $System.Security.Audit() without pre-registered events, and the EnsureEvents() pattern.
- Task 2: Fixed $Horolog to $ZTimeStamp in 3 locations (Database.cls line 27, Manager.cls lines 70 and 170). All consumers only check timestamp presence/format, not value -- change is safe. Updated "Timestamp and Encoding Standards" rule to document $ZTimeStamp as correct. Both classes compiled successfully. 18 tests pass (14 DatabaseTest + 4 ReplicatorManagerTest). Marked deferred work item as RESOLVED.
- Task 3: Reviewed all 43 remaining open deferred work items (was 44, one resolved in Task 2). All are ObjectScript backend concerns. Zero references to Angular/TypeScript/frontend. Added triage note to deferred-work.md confirming no Epic 10 blockers.

### File List
- `.claude/rules/iris-objectscript-basics.md` (modified -- added Security.Events rule, updated Timestamp rule)
- `src/IRISCouch/Storage/Database.cls` (modified -- $Horolog to $ZTimeStamp)
- `src/IRISCouch/Replication/Manager.cls` (modified -- $Horolog to $ZTimeStamp in 2 locations)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified -- resolved $Horolog item, added Epic 10 triage note)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified -- status update)
- `_bmad-output/implementation-artifacts/10-0-epic-9-deferred-cleanup.md` (modified -- task checkboxes, dev agent record)

## Change Log
- 2026-04-14: Story 10.0 implemented -- Security.Events rule added, $Horolog timestamps fixed to $ZTimeStamp, 43 deferred items triaged for Epic 10
