# Story 4.2: Longpoll Changes Feed

Status: done

## Story

As a client,
I want to subscribe to changes via `feed=longpoll` mode where the request blocks until new changes arrive,
so that I can efficiently detect changes without polling.

## Acceptance Criteria

1. **Given** a database `{db}` with no new changes since the client's `since` value, **When** the client sends `GET /iris-couch/{db}/_changes?feed=longpoll&since=N`, **Then** the request blocks and waits for a new change via `$System.Event` on `"IRISCouch:changes:" _ db`.

2. **Given** a longpoll request is waiting, **When** a document write commits in `DocumentEngine.Save()` and posts the event, **Then** the longpoll response is sent with the new change(s).

3. **Given** a longpoll request is waiting, **When** the configurable timeout expires without new changes, **Then** the response is sent with `{"results":[],"last_seq":N,"pending":0}`.

4. **Given** a longpoll request includes `heartbeat=N` (milliseconds), **When** the timeout has not yet expired and no changes have arrived, **Then** a newline heartbeat is sent at the specified interval to keep the connection alive.

5. **Given** a database already has changes after the client's `since` value, **When** the client sends `GET /{db}/_changes?feed=longpoll&since=N`, **Then** the response is returned immediately with those changes (no blocking).

6. **Given** all existing tests pass with zero regressions, **Then** new tests cover the longpoll scenarios.

## Tasks / Subtasks

- [x] Task 1: Add `$System.Event` notification to DocumentEngine write methods (AC: #2)
  - [x] 1.1: In `DocumentEngine.Save()`, after `TCOMMIT`, add event signal via `##class(%SYSTEM.Event).Signal()`
  - [x] 1.2: In `DocumentEngine.SaveDeleted()`, after `TCOMMIT`, add the same event signal
  - [x] 1.3: In `DocumentEngine.SaveWithHistory()`, after `TCOMMIT`, add the same event signal
  - [x] 1.4: Compile via MCP
  - [x] 1.5: Event signal is AFTER TCOMMIT, guarded by `##class(%SYSTEM.Event).Defined()` check to avoid ERUNDEF errors when no longpoll listener exists

- [x] Task 2: Update `ChangesHandler.HandleChanges` to support `feed=longpoll` (AC: #1, #2, #3, #5)
  - [x] 2.1: Updated feed validation to accept `"longpoll"` as a valid feed mode
  - [x] 2.2: Added longpoll logic: check GetLastSeq, if no new changes enter wait loop via `##class(%SYSTEM.Event).WaitMsg()`, support heartbeat intervals, return empty results on timeout
  - [x] 2.3: Normal feed path unchanged
  - [x] 2.4: Still rejects `feed=continuous` and `feed=eventsource` with 400
  - [x] 2.5: Compile via MCP

- [x] Task 3: Add `timeout` and `heartbeat` parameter parsing to ChangesHandler (AC: #3, #4)
  - [x] 3.1: Parse `timeout` from query string or POST body (integer, milliseconds, default 60000)
  - [x] 3.2: Parse `heartbeat` from query string or POST body (integer, milliseconds, default 0 = disabled)
  - [x] 3.3: Parameters only used when `feed=longpoll` — ignored for normal mode
  - [x] 3.4: Compile via MCP

- [x] Task 4: Create unit tests `Test/LongpollTest.cls` (AC: #1-#5)
  - [x] 4.1: Created `src/IRISCouch/Test/LongpollTest.cls` extending `%UnitTest.TestCase`
  - [x] 4.2: `OnBeforeOneTest` / `OnAfterOneTest` — kill globals for "testlongpolldb", create fresh db, clean up event resources
  - [x] 4.3: `TestEventSignalOnSave` — verifies event signal fired after Save() (PASSED)
  - [x] 4.4: `TestEventSignalOnDelete` — verifies event signal fired after SaveDeleted() (PASSED)
  - [x] 4.5: `TestLongpollImmediateReturn` — verifies GetLastSeq > since returns immediately (PASSED)
  - [x] 4.6: `TestLongpollTimeout` — verifies WaitMsg timeout behavior (PASSED)
  - [x] 4.7: `TestEventCreate` — verifies idempotent event creation (PASSED)

- [x] Task 5: Create HTTP integration tests `Test/LongpollHttpTest.cls` (AC: #2, #5)
  - [x] 5.1: Created `src/IRISCouch/Test/LongpollHttpTest.cls` extending `%UnitTest.TestCase`
  - [x] 5.2: `OnBeforeOneTest` / `OnAfterOneTest` — kill globals for "testlongpollhttpdb", create fresh db
  - [x] 5.3: `TestLongpollImmediateReturnHttp` — 200, results returned immediately (PASSED)
  - [x] 5.4: `TestLongpollTimeoutHttp` — 200, empty results after timeout (PASSED)
  - [x] 5.5: `TestFeedNormalStillWorks` — 200, regression check (PASSED)
  - [x] 5.6: `TestUnsupportedFeedMode` — 400 for continuous and eventsource (PASSED)

- [x] Task 6: Run full test suite (AC: #6)
  - [x] 6.1: All existing 140 tests pass (zero regressions)
  - [x] 6.2: All new tests pass (9 tests: 5 unit + 4 HTTP)

## Dev Notes

### $System.Event API

IRIS provides `$System.Event` for inter-process communication:

```objectscript
; Create a named event (idempotent)
Do $System.Event.Create("IRISCouch:changes:mydb")

; Signal an event (wakes one waiting process)
Do $System.Event.Signal("IRISCouch:changes:mydb")

; Wait for an event with timeout (seconds, not milliseconds!)
; Returns: "" on timeout, or the message string if signaled
Set tResult = $System.Event.WaitMsg("IRISCouch:changes:mydb", timeoutInSeconds)

; Delete an event resource
Do $System.Event.Delete("IRISCouch:changes:mydb")
```

**CRITICAL**: `$System.Event.WaitMsg` timeout parameter is in SECONDS (floating point), not milliseconds. CouchDB's `timeout` parameter is in milliseconds, so divide by 1000 when passing to WaitMsg.

**CRITICAL**: `$System.Event.Signal()` wakes ONE waiting process. If multiple longpoll clients are waiting on the same database, only one wakes. For alpha this is acceptable — each woken client re-queries the changes feed. For production, consider using `$System.Event.Broadcast()` or multiple event names.

### Event Placement — After TCOMMIT

The `$System.Event.Signal()` call MUST be after `TCOMMIT`, not inside the transaction:

```objectscript
; Inside DocumentEngine.Save():
TCOMMIT
Set tInTrans = 0
; Signal AFTER commit so readers see committed data
Do $System.Event.Signal("IRISCouch:changes:" _ pDB)
Quit
```

If placed inside the transaction, the longpoll reader might wake up before the data is committed and see stale state.

### Longpoll Flow

```
Client: GET /{db}/_changes?feed=longpoll&since=5
  1. Handler checks: any changes after seq 5?
  2. If yes → return immediately (same as normal feed)
  3. If no → Create event, enter wait loop:
     a. Wait for event or heartbeat interval
     b. If event received → query changes since 5, return results
     c. If heartbeat timeout → write "\n", flush, continue waiting
     d. If total timeout → return {"results":[],"last_seq":5,"pending":0}
```

### Heartbeat Mechanism

Heartbeats keep the HTTP connection alive by sending a newline character (`\n`) at regular intervals. This prevents proxy timeouts and client connection drops.

```objectscript
; Heartbeat loop (simplified)
Set tElapsed = 0
Set tHeartbeatSec = tHeartbeat / 1000
Set tTimeoutSec = tTimeout / 1000
For {
    Set tResult = $System.Event.WaitMsg("IRISCouch:changes:" _ pDB, tHeartbeatSec)
    If tResult '= "" {
        ; Event received — changes happened
        Quit
    }
    ; Timeout on wait — send heartbeat
    Do %response.Write($Char(10))
    Do %response.Flush()
    Set tElapsed = tElapsed + tHeartbeat
    If tElapsed >= tTimeout {
        ; Total timeout expired — return empty
        Quit
    }
}
```

**NOTE**: In %CSP.REST, `%response.Write()` and `%response.Flush()` work for sending partial responses. The Content-Type should still be `application/json` — the heartbeat newlines precede the JSON body.

### Timeout Parameter

- CouchDB default: 60000ms (60 seconds)
- Minimum: no enforced minimum, but values < 1000 may not be useful
- `timeout=0` means "return immediately" — equivalent to normal feed

### Longpoll with Existing Changes (AC #5)

If the database already has changes after the client's `since` value, longpoll returns immediately — no blocking. This is checked before entering the wait loop:

```objectscript
Set tLastSeq = ##class(IRISCouch.Storage.Changes).GetLastSeq(pDB)
If tLastSeq > tSince {
    ; Changes already exist — return immediately (same as normal)
}
```

### Testing Longpoll

Testing actual longpoll blocking requires concurrent processes — one to wait, one to write. For unit tests, we test the components:
1. Event signaling works (signal + immediate WaitMsg)
2. Immediate return when changes exist
3. Timeout behavior (short timeout, verify empty response)

For HTTP integration tests, we primarily test the "immediate return" case (changes exist) and the timeout case (short timeout). True concurrent longpoll testing requires a more complex test harness.

### Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `src/IRISCouch/Core/DocumentEngine.cls` | **Modify** | Add $System.Event.Signal after TCOMMIT in Save/SaveDeleted/SaveWithHistory |
| `src/IRISCouch/API/ChangesHandler.cls` | **Modify** | Add feed=longpoll support with wait loop, heartbeat, timeout |
| `src/IRISCouch/Test/LongpollTest.cls` | **Create** | Unit tests for longpoll event signaling |
| `src/IRISCouch/Test/LongpollHttpTest.cls` | **Create** | HTTP integration tests for longpoll endpoint |

### Established Patterns

- Handler catch: `RenderInternal()` then `Quit $$$OK`
- Storage encapsulation: all `^IRISCouch.*` access through Storage.* classes only
- Response: `Response.JSON(tResult)` for 200
- Router wrappers: already exist for _changes (from Story 4.1)
- Test cleanup: `OnBeforeOneTest` kills globals, creates fresh db
- Constructor: `%OnNew(initvalue As %String = "")` with `##super(initvalue)` call
- Inner catch pattern: use `Return $$$OK` not `Quit` to exit method entirely

### Previous Story Intelligence (Story 4.1)

- 140 tests passing across 22 test classes
- ChangesHandler.HandleChanges accepts both GET and POST
- Storage.Changes has GetLastSeq, ListChanges, CountSince, ReadEntry, GetDocSeq
- POST body parse error uses `Return $$$OK` (fixed in code review)
- Descending pending count uses `total - count` formula (fixed in code review)
- Feed mode validation currently returns 400 for anything except "normal" — update to accept "longpoll"

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.2] — Acceptance criteria
- [Source: _bmad-output/planning-artifacts/architecture.md:1025-1026] — $System.Event resolution for longpoll
- [Source: src/IRISCouch/API/ChangesHandler.cls] — Current handler (normal mode only)
- [Source: src/IRISCouch/Core/DocumentEngine.cls:64-75] — TCOMMIT location for event signal placement
- [Source: src/IRISCouch/Storage/Changes.cls] — GetLastSeq, ListChanges methods

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
- Used ^ClineDebug and IRISCouch.Test.DebugEvent temporary class to diagnose $System.Event API issues
- Discovered $System.Event must use ##class(%SYSTEM.Event) syntax in compiled classes (not $System.Event shorthand)
- Discovered event resource names must be in $name format (global reference syntax) — colons cause FUNCTION errors
- Discovered Signal() on non-existent event resource throws ERUNDEF — added Defined() guard

### Completion Notes List
- All 6 acceptance criteria satisfied
- $System.Event.Signal placed AFTER TCOMMIT in all three DocumentEngine write methods (Save, SaveDeleted, SaveWithHistory)
- Event resource name format: `^IRISCouch.LPChanges("dbname")` (global reference syntax required by $name format)
- Signal guarded by Defined() check to prevent ERUNDEF when no longpoll listener exists
- ChangesHandler supports feed=longpoll with timeout (default 60s) and heartbeat parameters
- Longpoll with existing changes returns immediately (AC #5)
- Longpoll timeout returns empty results with last_seq and pending=0 (AC #3)
- Heartbeat sends newline characters at specified intervals (AC #4)
- feed=continuous and feed=eventsource still rejected with 400
- 9 new tests added (5 unit + 4 HTTP), all passing
- 140 existing tests pass with zero regressions

### File List
- `src/IRISCouch/Core/DocumentEngine.cls` — Modified: added $System.Event.Signal after TCOMMIT in Save, SaveDeleted, SaveWithHistory
- `src/IRISCouch/API/ChangesHandler.cls` — Modified: added feed=longpoll support, timeout/heartbeat parsing, wait loop
- `src/IRISCouch/Test/LongpollTest.cls` — Created: 5 unit tests for event signaling and longpoll behavior
- `src/IRISCouch/Test/LongpollHttpTest.cls` — Created: 4 HTTP integration tests for longpoll endpoint

### Review Findings

- [x] [Review][Patch] Heartbeat > timeout causes wait longer than timeout — WaitMsg interval not capped at remaining time [ChangesHandler.cls:120-134] — FIXED: added min(heartbeat, remaining) cap and operator precedence fix
- [x] [Review][Patch] tGotEvent variable set but never used — dead code in heartbeat loop [ChangesHandler.cls:118] — FIXED: removed unused variable
- [x] [Review][Patch] Negative timeout not clamped — negative values cause undefined WaitMsg behavior [ChangesHandler.cls:35] — FIXED: added clamp to 0
- [x] [Review][Defer] Event resource name pattern duplicated in 4 locations [DocumentEngine.cls:78,162,259 + ChangesHandler.cls:114] — deferred, code quality improvement not blocking

### Change Log
- 2026-04-12: Story 4.2 implemented — longpoll changes feed with $System.Event-based blocking, timeout, heartbeat support
- 2026-04-12: Code review — fixed heartbeat > timeout edge case, removed dead code, added negative timeout clamp
