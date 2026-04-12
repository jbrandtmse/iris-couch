# Story 1.3: UUID Generation Endpoint

Status: done

## Story

As a client,
I want to request UUIDs via `GET /_uuids?count=N`,
so that I can generate document IDs client-side before creating documents.

## Acceptance Criteria

1. **Given** IRISCouch is running, **When** a client sends `GET /iris-couch/_uuids`, **Then** the response status is 200 OK and the body contains `{"uuids":["<hex-uuid>"]}` with exactly 1 UUID.
2. **Given** IRISCouch is running, **When** a client sends `GET /iris-couch/_uuids?count=3`, **Then** the response body contains `{"uuids":["<hex1>","<hex2>","<hex3>"]}` with exactly 3 unique hex UUIDs.
3. **Given** IRISCouch is running, **When** a client sends `GET /iris-couch/_uuids?count=0` or a negative count, **Then** the response is 400 Bad Request with a JSON error envelope.
4. **Given** any UUID returned, **Then** it is a lowercase 32-character hex string (matching CouchDB's UUID format).

## Tasks / Subtasks

- [x] Task 1: Create `IRISCouch.Util.UUID` class (AC: #1, #2, #4)
  - [x] 1.1: Implement `Generate()` classmethod returning a single hex UUID string
  - [x] 1.2: Implement `GenerateN(pCount)` classmethod returning a `%DynamicArray` of N hex UUIDs
  - [x] 1.3: UUIDs must be 32-character lowercase hex strings (no dashes)
  - [x] 1.4: Use `$System.Util.CreateGUID()` or `##class(%PopulateUtils).StringMin()` for generation, then strip dashes and lowercase
- [x] Task 2: Add `/_uuids` route to Router (AC: #1, #2, #3)
  - [x] 2.1: Add `<Route Url="/_uuids" Method="GET" Call="IRISCouch.API.ServerHandler:HandleUUIDs" />` to Router UrlMap
- [x] Task 3: Implement `HandleUUIDs()` on `ServerHandler` (AC: #1, #2, #3)
  - [x] 3.1: Read `count` query parameter from `%request.Get("count")`, default to 1
  - [x] 3.2: Validate count is a positive integer; return 400 with `bad_request` slug if invalid
  - [x] 3.3: Call `UUID.GenerateN(count)` and return `{"uuids": [...]}` via `Response.JSON()`
- [x] Task 4: Create/update `IRISCouch.Test.UUIDTest` class (AC: #1, #2, #3, #4)
  - [x] 4.1: `TestGenerateSingleUUID` — verify 32-char lowercase hex format
  - [x] 4.2: `TestGenerateMultipleUUIDs` — verify count and uniqueness
  - [x] 4.3: `TestHandleUUIDsDefault` — verify default count=1 response structure
  - [x] 4.4: `TestHandleUUIDsWithCount` — verify count=3 returns 3 UUIDs
  - [x] 4.5: `TestHandleUUIDsInvalidCount` — verify count=0 returns 400
- [x] Task 5: Compile and validate
  - [x] 5.1: Compile all new and modified classes
  - [x] 5.2: Run all tests (UUIDTest, RouterTest, ConfigTest) — verify no regressions

### Review Findings

- [x] [Review][Patch] No upper bound on count parameter allows resource exhaustion [ServerHandler.cls:40] — FIXED: added max 1000 cap and integer check
- [x] [Review][Defer] Fractional count values (e.g., 1.5) pass original validation [ServerHandler.cls:40] — FIXED as part of integer validation patch above
- [x] [Review][Dismiss] Test uniqueness check uses string contains pattern — dismissed, works correctly for fixed-width hex UUIDs with delimiters

## Dev Notes

### Previous Story Intelligence (Story 1.2)

**Existing files this story depends on or modifies:**
- `src/IRISCouch/API/Router.cls` — ADD a new route for `/_uuids` to the UrlMap XData block
- `src/IRISCouch/API/ServerHandler.cls` — ADD `HandleUUIDs()` classmethod (server-level endpoint)
- `src/IRISCouch/Util/Error.cls` — USE `Error.Render(400, "bad_request", ...)` for invalid count
- `src/IRISCouch/Util/Response.cls` — USE `Response.JSON()` for success responses

**Patterns established in Story 1.2:**
- Router uses class-qualified `Call` syntax: `IRISCouch.API.ServerHandler:HandleUUIDs`
- Handler methods return `%Status`, use Try/Catch, call `Error.Render()` in catch
- Code review fixed: catch blocks should NOT set tSC = ex.AsStatus() when Error.Render() already wrote the response — just return $$$OK
- Testable helper pattern: extract business logic into separate methods (e.g., `BuildWelcomeResponse()`) for unit testing without HTTP context

### Architecture Compliance

- **UUID utility goes in `IRISCouch.Util.UUID`** — matches the architecture's Util package for shared utilities
- **Route goes in Router UrlMap** — ServerHandler handles server-level endpoints (not database-scoped)
- **Handler method pattern:** `ClassMethod HandleUUIDs() As %Status` with Try/Catch
- **Error responses via `Error.Render()`** — never inline JSON
- **Success responses via `Response.JSON()`** — never Write directly

### CouchDB UUID Format

CouchDB's `/_uuids` endpoint returns UUIDs as 32-character lowercase hex strings (no dashes):

```json
{"uuids":["6e1295ed6c29495e54cc05947f18c8af"]}
```

With `?count=3`:
```json
{"uuids":["6e1295ed6c29495e54cc05947f18c8af","75bd12baf38a22a066c9c5ebc4210274","b1fa6d6a2bba6b9ac93b0c0fceff3daa"]}
```

CouchDB returns 400 for count < 1 or non-numeric:
```json
{"error":"bad_request","reason":"count must be a positive integer"}
```

### UUID Generation in ObjectScript

Use `$System.Util.CreateGUID()` which returns a GUID like `{6E1295ED-6C29-495E-54CC-05947F18C8AF}`. Strip braces and dashes, then lowercase:

```objectscript
ClassMethod Generate() As %String
{
    Set tGUID = $System.Util.CreateGUID()
    Set tHex = $Translate(tGUID, "{}-", "")
    Quit $ZConvert(tHex, "L")
}
```

### Router UrlMap Addition

Add this route to the existing UrlMap in Router.cls, BEFORE the `GET /` route (more specific routes first):

```xml
<Route Url="/_uuids" Method="GET" Call="IRISCouch.API.ServerHandler:HandleUUIDs" />
<Route Url="/" Method="GET" Call="IRISCouch.API.ServerHandler:HandleWelcome" />
```

### HandleUUIDs Implementation Pattern

```objectscript
ClassMethod HandleUUIDs() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tCount = %request.Get("count", 1)
        ; Validate count
        If (tCount '= +tCount) || (tCount < 1) {
            Do ##class(IRISCouch.Util.Error).Render(400, "bad_request", "count must be a positive integer")
            Quit
        }
        Set tUUIDs = ##class(IRISCouch.Util.UUID).GenerateN(tCount)
        Set tResponse = {}
        Set tResponse.uuids = tUUIDs
        Do ##class(IRISCouch.Util.Response).JSON(tResponse)
    }
    Catch ex {
        Do ##class(IRISCouch.Util.Error).Render(500, "server_error", "Internal Server Error")
    }
    Quit tSC
}
```

### Testing Approach

Follow Story 1.2's testable helper pattern:
- Test `UUID.Generate()` directly — verify format (32 chars, lowercase hex, no dashes)
- Test `UUID.GenerateN(N)` directly — verify count and uniqueness
- Test `HandleUUIDs` business logic by building the response object and verifying structure
- For count validation, test the validation logic directly

### What This Story Does NOT Include

- No `/_all_dbs` endpoint (Epic 2)
- No `/_up` endpoint (can be added later)
- No `/_active_tasks` endpoint (can be added later)
- No rate limiting on UUID generation
- No configurable UUID algorithm

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.3] — Story requirements and acceptance criteria
- [Source: _bmad-output/planning-artifacts/architecture.md#REST Router Design] — ServerHandler handles /_uuids
- [Source: _bmad-output/planning-artifacts/architecture.md#Project Structure] — IRISCouch.Util.UUID location
- [Source: _bmad-output/implementation-artifacts/1-2-http-router-and-couchdb-welcome-endpoint.md] — Previous story context

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6 (1M context)

### Debug Log References
No debug issues encountered. All classes compiled and tests passed on first attempt.

### Completion Notes List
- Created IRISCouch.Util.UUID class with Generate() and GenerateN() classmethods using $System.Util.CreateGUID()
- Added /_uuids GET route to Router UrlMap (placed before / route for correct specificity ordering)
- Implemented HandleUUIDs() classmethod on ServerHandler with count query parameter validation (default=1, rejects non-positive integers with 400 bad_request)
- Created IRISCouch.Test.UUIDTest with 5 test methods covering format validation, count/uniqueness, response structure, and input validation
- All 14 tests pass (9 existing + 5 new), zero regressions

### File List
- src/IRISCouch/Util/UUID.cls (new)
- src/IRISCouch/API/Router.cls (modified - added /_uuids route)
- src/IRISCouch/API/ServerHandler.cls (modified - added HandleUUIDs classmethod)
- src/IRISCouch/Test/UUIDTest.cls (new)

### Change Log
- 2026-04-12: Implemented Story 1.3 - UUID Generation Endpoint. Created UUID utility class, added route, handler, and 5 unit tests. All 14 tests pass.
