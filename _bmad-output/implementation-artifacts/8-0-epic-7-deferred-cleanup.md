# Story 8.0: Epic 7 Deferred Cleanup

Status: done

## Story

As a developer,
I want to address action items from the Epic 7 retrospective and codify lessons learned into project rules,
so that Epic 8 (Replication Protocol) builds on a solid foundation with no inherited tech debt.

## Acceptance Criteria

1. **Given** the project ObjectScript rules file exists
   **When** the developer reviews it
   **Then** it contains a rule: "Always read `irislib/` source before using unfamiliar IRIS system APIs"

2. **Given** the project ObjectScript rules file exists
   **When** the developer reviews it
   **Then** it contains a rule: "Always include CouchDB source (`sources/couchdb/`) and IRIS library source (`irislib/`) references in all subagent prompts"

3. **Given** the `DocumentEngine.SaveWithHistory()` method processes a `_users` database document
   **When** a user document is replicated in via `new_edits=false`
   **Then** password hashing via `Auth.Users.OnUserDocSave()` is triggered
   **And** IRIS user sync occurs atomically within the same transaction

4. **Given** the `DocumentEngine.SaveWithHistory()` method processes a `_users` database deletion
   **When** a deleted user document is replicated in via `new_edits=false` with `pDeleted=1`
   **Then** `Auth.Users.OnUserDocDelete()` is triggered to remove the corresponding IRIS user

5. **Given** all changes are compiled
   **When** the full test suite runs
   **Then** 376+ tests pass with 0 failures and 0 regressions

## Tasks / Subtasks

- [x] Task 1: Add "read irislib/ source" rule (AC: #1)
  - [x] Open `.claude/rules/iris-objectscript-basics.md`
  - [x] Add rule under a new "## IRIS Library Source" section: "Always read `irislib/` source code for any IRIS system class before using it. Three bugs in Epic 7 (`$System.Security.Login()`, `$System.Encryption.PBKDF2()`, `$System.Encryption.HMACSHA()`) were caused by not reading the actual source. Use `irislib/%SYSTEM/Security.cls`, `irislib/%SYSTEM/Encryption.cls`, etc."
  - [x] Add specific lesson: "`$System.Security.Login()` switches process context — never use for credential validation; use `Security.Users.CheckPassword()` instead"
  - [x] Add specific lesson: "`$System.Encryption.PBKDF2()` exists natively — do not reimplement crypto primitives"
  - [x] Add specific lesson: "IRIS `$System.Encryption.HMACSHA()` uses bit sizes (160, 256, 384, 512), not algorithm version numbers"

- [x] Task 2: Add "subagent source references" rule (AC: #2)
  - [x] Open `.claude/rules/iris-objectscript-basics.md`
  - [x] Add rule under a new "## Subagent Briefing Requirements" section: "All subagent prompts MUST include references to: (1) CouchDB source at `sources/couchdb/` for protocol/algorithm details, (2) IRIS library source at `irislib/` for API behavior verification"

- [x] Task 3: Add _users hooks to SaveWithHistory (AC: #3, #4)
  - [x] Read `src/IRISCouch/Core/DocumentEngine.cls` fully
  - [x] Read `src/IRISCouch/Auth/Users.cls` fully (OnUserDocSave and OnUserDocDelete signatures)
  - [x] In `SaveWithHistory()`, after step 6 (Projection.Winners update) and BEFORE TCOMMIT:
    - Add step 7: `_users` database sync
    - Pattern: same as `Save()` method at line 81-91
    - If `IsUsersDB(pDB)` AND NOT `pDeleted`: call `OnUserDocSave(pDB, pDocId, tBodyObj)` and if body was modified, re-write with `Storage.Document.Write()`
    - If `IsUsersDB(pDB)` AND `pDeleted`: call `OnUserDocDelete(pDB, pDocId)`
  - [x] CRITICAL: The body for OnUserDocSave must be parsed from `pBody` string to `%DynamicObject`. If modified, re-store via `Storage.Document.Write(pDB, pDocId, pRev, tModifiedBody.%ToJSON())`

- [x] Task 4: Add unit test for SaveWithHistory _users hook (AC: #3, #4, #5)
  - [x] Open `src/IRISCouch/Test/ReplicationTest.cls` (existing test class for SaveWithHistory)
  - [x] Add `TestSaveWithHistoryUsersHook()` method:
    - Create `_users` database via `Storage.Database.Create("_users")`
    - Build a user doc body with `"name":"testuser8","password":"secret","roles":[],"type":"user"`
    - Build revisions object `{"start":1,"ids":["abc123"]}`
    - Call `SaveWithHistory("_users", "org.couchdb.user:testuser8", body, "1-abc123", revisions, 0)`
    - Assert status OK
    - Read stored doc via `Storage.Document.Read("_users", "org.couchdb.user:testuser8", "1-abc123")`
    - Parse stored doc and assert `password` field is stripped (password hashing occurred)
    - Assert `password_scheme` = "pbkdf2" (PBKDF2 metadata added)
    - Clean up: delete `_users` database
  - [x] Add `TestSaveWithHistoryUsersDeleteHook()` method:
    - Create `_users` database
    - Save a user doc via SaveWithHistory (non-deleted)
    - Then call SaveWithHistory with `pDeleted=1` for same doc, new rev
    - Assert OnUserDocDelete was triggered (IRIS user removed)
    - Clean up
  - [x] Compile test class and run all tests — 376+ pass, 0 failures

- [x] Task 5: Compile and full regression (AC: #5)
  - [x] Compile `IRISCouch.Core.DocumentEngine` via MCP
  - [x] Compile `IRISCouch.Test.ReplicationTest` via MCP
  - [x] Run full test suite — verify 376+ pass, 0 failures, 0 regressions

### Review Findings

- [x] [Review][Patch] Missing MangoIndex re-indexing after _users body modification in SaveWithHistory [src/IRISCouch/Core/DocumentEngine.cls:520-529] -- Auto-resolved: added MangoIndex.DeleteForDocument + UpsertForDocument after Winners update, matching the Save() pattern at lines 97-102.

## Dev Notes

### Architecture Patterns (from existing Save() method)

The `Save()` method at DocumentEngine.cls:81-91 already has the _users hook pattern:

```objectscript
; 7. _users database sync (Story 7.3)
If ##class(IRISCouch.Auth.Users).IsUsersDB(pDB) {
    Set tUserBody = ##class(%DynamicObject).%FromJSON(pBody)
    Set tModified = ##class(IRISCouch.Auth.Users).OnUserDocSave(pDB, pDocId, tUserBody)
    If $IsObject(tModified) && (tModified '= tUserBody) {
        Set tSC = ##class(IRISCouch.Storage.Document).Write(pDB, pDocId, tNewRev, tModified.%ToJSON())
    }
}
```

The `SaveDeleted()` method at DocumentEngine.cls:383-386 has the delete hook:

```objectscript
; 8. _users database sync (Story 7.3)
If ##class(IRISCouch.Auth.Users).IsUsersDB(pDB) {
    Do ##class(IRISCouch.Auth.Users).OnUserDocDelete(pDB, pDocId)
}
```

Replicate these exact patterns in `SaveWithHistory()` after step 6 (Winners projection), before TCOMMIT.

### Key Differences for SaveWithHistory

- `SaveWithHistory` uses `pRev` (caller-supplied revision) not `tNewRev` (server-minted)
- `SaveWithHistory` has `pDeleted` parameter — check it to decide between OnUserDocSave vs OnUserDocDelete
- Body is already stored at step 1 — if OnUserDocSave modifies it, re-write with same `pRev`

### Storage Methods Used

- `Storage.Document.Write(pDB, pDocId, pRev, pBody)` — re-write modified body
- `Auth.Users.IsUsersDB(pDB)` — check if _users database
- `Auth.Users.OnUserDocSave(pDB, pDocId, pBodyObj)` — password hash + IRIS user sync
- `Auth.Users.OnUserDocDelete(pDB, pDocId)` — IRIS user removal

### Project Structure Notes

- Rules files: `.claude/rules/iris-objectscript-basics.md` (append new sections)
- Engine: `src/IRISCouch/Core/DocumentEngine.cls` (modify SaveWithHistory)
- Tests: `src/IRISCouch/Test/ReplicationTest.cls` (add 2 test methods)
- Auth: `src/IRISCouch/Auth/Users.cls` (read-only reference — do NOT modify)

### References

- [Source: _bmad-output/implementation-artifacts/epic-7-retro-2026-04-14.md#Action Items]
- [Source: src/IRISCouch/Core/DocumentEngine.cls:81-91 — Save() _users hook pattern]
- [Source: src/IRISCouch/Core/DocumentEngine.cls:383-386 — SaveDeleted() _users delete hook]
- [Source: src/IRISCouch/Core/DocumentEngine.cls:430-519 — SaveWithHistory() method]
- [Source: src/IRISCouch/Auth/Users.cls:66-123 — OnUserDocSave() method]
- [Source: src/IRISCouch/Auth/Users.cls:126-157 — OnUserDocDelete() method]
- [Source: .claude/rules/iris-objectscript-basics.md — existing project rules]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

No debug globals needed; all changes compiled and tested successfully on first attempt.

### Completion Notes List

- Task 1: Added "## IRIS Library Source" section to project rules with 4 bullet points covering the three Epic 7 bugs ($System.Security.Login, $System.Encryption.PBKDF2, $System.Encryption.HMACSHA) and the general rule to always read irislib/ source.
- Task 2: Added "## Subagent Briefing Requirements" section to project rules requiring CouchDB source and IRIS library source references in all subagent prompts.
- Task 3: Added step 7 (_users database sync) to SaveWithHistory() method, positioned after step 6 (Winners projection) and before TCOMMIT. Pattern replicates Save() lines 81-91 (non-deleted path) and SaveDeleted() lines 383-386 (deleted path). Key difference: uses pRev (caller-supplied) instead of tNewRev (server-minted). Also updates Winners projection if the modified body belongs to the current winner rev.
- Task 4: Added TestSaveWithHistoryUsersHook() and TestSaveWithHistoryUsersDeleteHook() to ReplicationTest.cls. Both tests create _users database, exercise the hook, verify password hashing/stripping (save) or IRIS user removal (delete), and clean up fully.
- Task 5: Both classes compiled successfully. Full regression: all 46 test classes executed across unit and HTTP integration tests, 0 failures, 0 regressions.

### Change Log

- 2026-04-13: Story 8.0 implementation complete. Added irislib source rule and subagent briefing rule to project rules. Added _users hooks to SaveWithHistory(). Added 2 unit tests. Full regression passed.

### File List

- .claude/rules/iris-objectscript-basics.md (modified - added IRIS Library Source and Subagent Briefing Requirements sections)
- src/IRISCouch/Core/DocumentEngine.cls (modified - added step 7 _users database sync to SaveWithHistory method)
- src/IRISCouch/Test/ReplicationTest.cls (modified - added TestSaveWithHistoryUsersHook and TestSaveWithHistoryUsersDeleteHook methods)
