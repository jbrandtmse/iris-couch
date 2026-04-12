# Story 2.0: Epic 1 Deferred Cleanup

Status: done

## Story

As a developer,
I want to resolve the deferred action items from the Epic 1 retrospective,
so that the codebase is solid before building database lifecycle features in Epic 2.

## Acceptance Criteria

1. **Given** the existing `ServerHandler.HandleWelcome()` catch block, **When** an exception is thrown, **Then** `RenderInternal()` is called with slug `"server_error"`, reason `"server: welcome endpoint error"`, and the exception object — not `Render(500, ...)`.
2. **Given** the existing `ServerHandler.HandleUUIDs()` catch block, **When** an exception is thrown, **Then** `RenderInternal()` is called with slug `"server_error"`, reason `"server: uuid generation error"`, and the exception object.
3. **Given** both ServerHandler catch blocks use `RenderInternal()`, **Then** exception details are logged to the IRIS console and the client receives only a generic error message (NFR-S8).
4. **Given** a new `IRISCouch.Test.HttpIntegrationTest` class exists, **When** the test suite is run, **Then** at least one test verifies an HTTP request to `GET /iris-couch/` returns status 200 and a JSON body with `"couchdb": "Welcome"` via `%Net.HttpRequest`.
5. **Given** the HTTP integration test infrastructure, **Then** a helper method exists that other test classes can reuse for making HTTP requests and checking status codes.
6. **Given** all changes are compiled and tested, **Then** all existing tests (26) continue to pass with zero regressions.

## Retrospective Triage

This story addresses items from the Epic 1 retrospective (`epic-1-retro-2026-04-12.md`) and `deferred-work.md`:

### Included in This Story

| # | Item | Source |
|---|------|--------|
| 1 | Fix ServerHandler catch blocks to use `RenderInternal()` with subsystem-specific reasons | Retro action #1, deferred-work.md |
| 2 | Add HTTP integration test approach using `%Net.HttpRequest` | Retro action #2 |
| 3 | Verify Router dispatch works for parameterized routes (`:db`) — validate as part of integration test setup | Retro section "Preparation for Epic 2" |

### Explicitly Deferred (Not in This Story)

| # | Item | Rationale |
|---|------|-----------|
| 4 | Config.Get() silent failure on invalid keys | Low risk, no Epic 2 impact |
| 5 | Config.Set() accepts arbitrary key names | Low risk, no Epic 2 impact |
| 6 | Config.GetAll() numeric serialization as strings | Cosmetic, fix when API consumes config |
| 7 | Config.GetAll() manual update for new params | Low risk, refactor later |
| 8 | Request.ReadBody() no size limit | NFR concern for Epic 3 (document storage) |
| 9 | Metrics dispatch wrapper in Router | Epic 9 feature |
| 10 | Error.Render() no handling for missing %response | Edge case, non-HTTP usage unlikely |
| 11 | Test Error.Render/RenderInternal with HTTP mock | Partially addressed by integration tests; full mock deferred |

### Dropped

None — all items explicitly triaged above.

## Tasks / Subtasks

- [x] Task 1: Fix ServerHandler catch blocks (AC: #1, #2, #3)
  - [x] 1.1: In `HandleWelcome()`, replace `Do ##class(IRISCouch.Util.Error).Render(500, "server_error", "Internal Server Error")` with `Do ##class(IRISCouch.Util.Error).RenderInternal("server_error", "server: welcome endpoint error", ex)`
  - [x] 1.2: In `HandleUUIDs()`, replace `Do ##class(IRISCouch.Util.Error).Render(500, "server_error", "Internal Server Error")` with `Do ##class(IRISCouch.Util.Error).RenderInternal("server_error", "server: uuid generation error", ex)`
  - [x] 1.3: Compile `IRISCouch.API.ServerHandler` and verify no errors

- [x] Task 2: Create HTTP integration test infrastructure (AC: #4, #5)
  - [x] 2.1: Create `IRISCouch.Test.HttpIntegrationTest` extending `%UnitTest.TestCase`
  - [x] 2.2: Implement helper method `MakeRequest(pMethod, pPath, Output pStatus, Output pBody)` that uses `%Net.HttpRequest` to hit the live webapp
  - [x] 2.3: Read server/port from IRIS config or hardcode `localhost:52773` with `/iris-couch/` prefix
  - [x] 2.4: Implement `TestWelcomeEndpoint` — `GET /` returns 200 with `"couchdb":"Welcome"`
  - [x] 2.5: Implement `TestUUIDsEndpoint` — `GET /_uuids` returns 200 with `uuids` array
  - [x] 2.6: Implement `TestNotFoundEndpoint` — `GET /nonexistent` returns 404 with `not_found` error
  - [x] 2.7: Compile and verify all new tests pass

- [x] Task 3: Verify parameterized route readiness (AC: #6)
  - [x] 3.1: Add a temporary smoke test `TestParameterizedRoutePattern` that verifies `GET /testdb123` returns 404 (no database handler yet) — confirms `:db` capture doesn't break routing
  - [x] 3.2: Remove or mark as informational after verification — kept as informational in HttpIntegrationTest

- [x] Task 4: Run full test suite
  - [x] 4.1: Run all existing tests — confirm 26+ tests pass, zero regressions (26/26 passed)
  - [x] 4.2: Verify new integration tests pass (4/4 passed via live webapp)

## Dev Notes

### Files to Modify

| File | Action | Reason |
|------|--------|--------|
| `src/IRISCouch/API/ServerHandler.cls` | Modify | Replace `Render(500,...)` with `RenderInternal(...)` in both catch blocks |
| `src/IRISCouch/Test/HttpIntegrationTest.cls` | Create | New integration test class using `%Net.HttpRequest` |

### Current Catch Block Pattern (WRONG — fix this)

```objectscript
Catch ex {
    Do ##class(IRISCouch.Util.Error).Render(500, "server_error", "Internal Server Error")
}
```

### Correct Catch Block Pattern (from feedback_catch_block_pattern.md + feedback_renderinternal_for_500.md)

```objectscript
Catch ex {
    Do ##class(IRISCouch.Util.Error).RenderInternal("server_error", "server: <subsystem> error", ex)
}
```

After `RenderInternal()` (which calls `Render()` internally), the method should `Quit $$$OK` — NOT `Quit ex.AsStatus()` — to avoid `%CSP.REST` overlaying its own error response.

### HTTP Integration Test Pattern

Use `%Net.HttpRequest` to hit the live webapp:
```objectscript
ClassMethod MakeRequest(pMethod As %String, pPath As %String, Output pStatusCode As %Integer, Output pBody As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set tReq = ##class(%Net.HttpRequest).%New()
    Set tReq.Server = "localhost"
    Set tReq.Port = 52773
    Set tReq.Username = "_SYSTEM"
    Set tReq.Password = "SYS"
    Set tReq.ContentType = "application/json"
    ; Build full path with webapp prefix
    Set tFullPath = "/iris-couch" _ pPath
    If pMethod = "GET" {
        Set tSC = tReq.Get(tFullPath)
    } ElseIf pMethod = "PUT" {
        Set tSC = tReq.Put(tFullPath)
    } ElseIf pMethod = "DELETE" {
        Set tSC = tReq.Delete(tFullPath)
    } ElseIf pMethod = "POST" {
        Set tSC = tReq.Post(tFullPath)
    }
    If $$$ISERR(tSC) Quit tSC
    Set pStatusCode = tReq.HttpResponse.StatusCode
    Set tBodyStr = tReq.HttpResponse.Data.Read()
    Set pBody = ##class(%DynamicObject).%FromJSON(tBodyStr)
    Quit tSC
}
```

**Note:** Credentials (`_SYSTEM`/`SYS`) should match the IRIS instance config. The webapp at `/iris-couch/` requires password auth (configured in Installer).

### Architecture Compliance

- **Package:** `IRISCouch.Test` for test classes, `IRISCouch.API` for handler modifications
- **Naming:** `t` prefix for locals, `p` prefix for parameters
- **Error pattern:** `RenderInternal()` for all 500s per NFR-S8
- **Test framework:** `%UnitTest.TestCase` with `$$$Assert*` macros
- **Compile:** Use MCP compile tools after all edits

### Previous Story Intelligence (Story 1.5)

- 26 tests passing across 5 test classes (ConfigTest, RouterTest, UUIDTest, ErrorEnvelopeTest, InstallerTest)
- Source auto-syncs to IRIS; compile via MCP tools with 'ck' flags
- Router uses local wrapper methods for UrlMap Call dispatch
- Webapp configured at `/iris-couch/` with password auth via Installer

### References

- [Source: _bmad-output/implementation-artifacts/epic-1-retro-2026-04-12.md#Action Items]
- [Source: _bmad-output/implementation-artifacts/deferred-work.md]
- [Source: src/IRISCouch/API/ServerHandler.cls] — lines 23, 50 (catch blocks to fix)
- [Source: src/IRISCouch/Util/Error.cls] — lines 70-79 (RenderInternal method)
- [Memory: feedback_catch_block_pattern.md] — After Error.Render(), return $$$OK not ex.AsStatus()
- [Memory: feedback_renderinternal_for_500.md] — Handler catch blocks must use RenderInternal()

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
None required — all changes compiled and passed on first attempt.

### Completion Notes List
- Task 1: Replaced both ServerHandler catch blocks (`HandleWelcome`, `HandleUUIDs`) to use `RenderInternal()` with subsystem-specific reason strings and the `ex` exception object, per NFR-S8. Also changed `Quit tSC` to `Quit $$$OK` after catch blocks per the established pattern (avoid %CSP.REST overlay).
- Task 2: Created `IRISCouch.Test.HttpIntegrationTest` with reusable `MakeRequest()` ClassMethod helper and 3 endpoint tests (welcome, uuids, not-found). All tests use `%Net.HttpRequest` against live webapp at `localhost:52773/iris-couch/`.
- Task 3: Added `TestParameterizedRoutePattern` to HttpIntegrationTest confirming `/testdb123` returns 404 without routing errors — validates `:db` capture readiness for Epic 2. Kept as informational test.
- Task 4: Full regression suite passed — 26 existing tests + 4 new integration tests = 30 total, 0 failures.

### Change Log
- 2026-04-12: Story 2.0 implementation complete — ServerHandler catch block fixes and HTTP integration test infrastructure (Date: 2026-04-12)

### Review Findings
- [x] [Review][Defer] Hardcoded credentials (_SYSTEM/SYS) in HttpIntegrationTest.MakeRequest [HttpIntegrationTest.cls:35-36] -- deferred, pre-existing pattern from story spec matching IRIS dev defaults
- [x] [Review][Defer] Hardcoded server/port (localhost:52773) in HttpIntegrationTest.MakeRequest [HttpIntegrationTest.cls:33-34] -- deferred, pre-existing pattern documented in story dev notes
- [x] [Review][Defer] No early-return guard after MakeRequest failure in test methods [HttpIntegrationTest.cls:69-117] -- deferred, LOW severity; cascade assertion failures would produce confusing output if server is down, but test framework catches errors and existing test classes follow same pattern

### File List
- `src/IRISCouch/API/ServerHandler.cls` — Modified: replaced Render(500,...) with RenderInternal() in both catch blocks
- `src/IRISCouch/Test/HttpIntegrationTest.cls` — Created: HTTP integration test class with MakeRequest helper and 4 test methods
