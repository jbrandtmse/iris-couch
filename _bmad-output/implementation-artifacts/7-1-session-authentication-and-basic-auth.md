# Story 7.1: Session Authentication & Basic Auth

Status: done

## Story

As a client,
I want to authenticate via HTTP Basic auth or cookie-based session auth,
So that I can securely access the system using standard CouchDB authentication methods.

## Acceptance Criteria

1. `POST /iris-couch/_session` with `{"name":"user","password":"pass"}` returns 200 OK with `{"ok":true,"name":"user","roles":[...]}` and a `Set-Cookie` header containing an HMAC-signed `AuthSession` cookie, signed with a per-instance secret (NFR-S3)
2. `GET /iris-couch/_session` with a valid `AuthSession` cookie returns 200 OK with `{"ok":true,"userCtx":{"name":"user","roles":[...]},"info":{"authenticated":"cookie"}}`
3. `DELETE /iris-couch/_session` returns 200 OK with `{"ok":true}` and invalidates the `AuthSession` cookie (sets expired cookie)
4. HTTP Basic auth (`Authorization: Basic base64(user:pass)`) authenticates against the IRIS user directory and the request proceeds normally
5. A tampered `AuthSession` cookie fails HMAC verification and the request is treated as unauthenticated (anonymous context)
6. Unauthenticated requests to endpoints that require auth return 401 Unauthorized with `{"error":"unauthorized","reason":"..."}`
7. Authenticated requests where the user lacks authorization return 403 Forbidden with `{"error":"forbidden","reason":"..."}`
8. Credentials are validated exclusively against the IRIS user directory — no shadow credential store (NFR-S1)
9. An authentication middleware (`OnPreDispatch` or equivalent) intercepts ALL requests to establish a user context before any handler logic runs
10. Unauthenticated `GET /iris-couch/_session` returns 200 OK with `{"ok":true,"userCtx":{"name":null,"roles":[]},"info":{}}`
11. All 312 existing tests pass with zero regressions
12. New unit and HTTP integration tests cover session login, session info, session logout, Basic auth, cookie HMAC tampering, and unauthenticated fallback

## Tasks / Subtasks

- [x] Task 1: Research CouchDB session auth implementation (AC: #1, #2, #3, #5)
  - [x] 1.1 Use Perplexity MCP to research CouchDB `_session` API: request/response formats, cookie format, HMAC algorithm, session timeout, `AuthSession` cookie structure
  - [x] 1.2 Research CouchDB's HMAC signing algorithm for AuthSession cookies: what data is signed, what hash function, what format the cookie value takes
  - [x] 1.3 Research CouchDB's `GET /_session` response format for both authenticated and unauthenticated users
  - [x] 1.4 Document findings in Dev Notes section before proceeding with implementation

- [x] Task 2: Add AUTHSECRET config parameter (AC: #1, #5)
  - [x] 2.1 Edit `src/IRISCouch/Config.cls`
  - [x] 2.2 Add parameter: `Parameter AUTHSECRET = "";` — per-instance secret for HMAC cookie signing (NFR-S3). If empty, auto-generate on first use.
  - [x] 2.3 Add parameter: `Parameter AUTHTIMEOUT = 600;` — session cookie timeout in seconds (CouchDB default is 600)
  - [x] 2.4 Add both to `GetAll()` method
  - [x] 2.5 Compile and verify

- [x] Task 3: Create Auth.Session — Cookie auth engine (AC: #1, #2, #3, #5)
  - [x] 3.1 Create `src/IRISCouch/Auth/Session.cls`
  - [x] 3.2 Implement `ClassMethod CreateCookie(pUsername As %String) As %String`:
    - Get AUTHSECRET from Config (auto-generate and persist if empty)
    - Build cookie value: CouchDB format is `AuthSession=<base64(username:timestamp:hmac)>`
    - HMAC-SHA1 or HMAC-SHA256 (per research) over `username + ":" + timestamp`
    - Return the full cookie value string
  - [x] 3.3 Implement `ClassMethod ValidateCookie(pCookieValue As %String, Output pUsername As %String) As %Boolean`:
    - Decode the cookie value
    - Extract username, timestamp, and HMAC
    - Verify HMAC against the stored secret
    - Check timestamp has not expired (compare against AUTHTIMEOUT config)
    - Set pUsername output if valid
    - Return 1/0
  - [x] 3.4 Implement `ClassMethod GetSecret() As %String`:
    - Read from Config.Get("AUTHSECRET")
    - If empty, generate a random 32-byte hex secret, persist via Config.Set("AUTHSECRET"), return it
    - Subsequent calls return the persisted secret
  - [x] 3.5 Compile and verify

- [x] Task 4: Create Auth.Basic — HTTP Basic auth (AC: #4, #8)
  - [x] 4.1 Create `src/IRISCouch/Auth/Basic.cls`
  - [x] 4.2 Implement `ClassMethod Authenticate(pAuthHeader As %String, Output pUsername As %String, Output pRoles As %DynamicArray) As %Boolean`:
    - Parse `Authorization: Basic <base64>` header
    - Base64-decode to extract `username:password`
    - Validate against IRIS user directory using `$System.Security.Login(pUsername, pPassword)`
    - If valid, set pUsername and query user roles
    - Return 1/0
  - [x] 4.3 Implement `ClassMethod GetUserRoles(pUsername As %String) As %DynamicArray`:
    - Use `Security.Users` or `$Roles` to retrieve the user's roles
    - Return as %DynamicArray of role name strings
  - [x] 4.4 Compile and verify

- [x] Task 5: Create API.AuthHandler — Session endpoints (AC: #1, #2, #3, #10)
  - [x] 5.1 Create `src/IRISCouch/API/AuthHandler.cls`
  - [x] 5.2 Implement `ClassMethod HandleSessionPost() As %Status` (POST /_session):
    - Read request body JSON: `{"name":"...","password":"..."}`
    - Validate credentials via `$System.Security.Login()` against IRIS user directory
    - On success: create AuthSession cookie via Auth.Session.CreateCookie(), set `Set-Cookie` header, return `{"ok":true,"name":"...","roles":[...]}`
    - On failure: return 401 with `{"error":"unauthorized","reason":"Name or password is incorrect."}`
  - [x] 5.3 Implement `ClassMethod HandleSessionGet() As %Status` (GET /_session):
    - Check if request has a valid AuthSession cookie or Basic auth
    - If authenticated: return `{"ok":true,"userCtx":{"name":"user","roles":[...]},"info":{"authenticated":"cookie"}}` (or "default" for Basic)
    - If unauthenticated: return `{"ok":true,"userCtx":{"name":null,"roles":[]},"info":{}}`
    - Use `%Set("name", "", "null")` for JSON null (per project rules)
  - [x] 5.4 Implement `ClassMethod HandleSessionDelete() As %Status` (DELETE /_session):
    - Set `Set-Cookie` header with expired `AuthSession` cookie (Max-Age=0)
    - Return `{"ok":true}`
  - [x] 5.5 Compile and verify

- [x] Task 6: Add auth middleware to Router (AC: #9, #6, #7)
  - [x] 6.1 Edit `src/IRISCouch/API/Router.cls`
  - [x] 6.2 Add `_session` routes to UrlMap (BEFORE all other routes):
    ```xml
    <Route Url="/_session" Method="POST" Call="HandleSessionPost" />
    <Route Url="/_session" Method="GET" Call="HandleSessionGet" />
    <Route Url="/_session" Method="DELETE" Call="HandleSessionDelete" />
    ```
  - [x] 6.3 Add local wrapper methods for session routes (per router wrapper pattern):
    ```objectscript
    ClassMethod HandleSessionPost() As %Status { Quit ##class(IRISCouch.API.AuthHandler).HandleSessionPost() }
    ClassMethod HandleSessionGet() As %Status { Quit ##class(IRISCouch.API.AuthHandler).HandleSessionGet() }
    ClassMethod HandleSessionDelete() As %Status { Quit ##class(IRISCouch.API.AuthHandler).HandleSessionDelete() }
    ```
  - [x] 6.4 Add `OnPreDispatch` class method to establish auth context on every request:
    - Check for AuthSession cookie → validate via Auth.Session.ValidateCookie()
    - Else check for Authorization: Basic header → validate via Auth.Basic.Authenticate()
    - Store authenticated username in a request-scoped variable (e.g., `%IRISCouchUser`, `%IRISCouchRoles`)
    - If no auth present, set anonymous context (empty username, empty roles)
    - Always return `$$$OK` — auth is established but not enforced at this layer (enforcement is Story 7.4)
  - [x] 6.5 **CRITICAL**: Per %CSP.REST docs, `OnPreDispatch` signature must be: `ClassMethod OnPreDispatch(pUrl As %String, pMethod As %String, ByRef pContinue As %Boolean) As %Status`
    - Set `pContinue = 1` to let dispatch proceed
    - Set `pContinue = 0` to block (only if auth is required and missing — defer to Story 7.4)
  - [x] 6.6 Compile Router and verify all existing routes still work

- [x] Task 7: Create unit tests (AC: #11, #12)
  - [x] 7.1 Create `src/IRISCouch/Test/AuthTest.cls` extending %UnitTest.TestCase
  - [x] 7.2 `TestCreateAndValidateCookie`: Create cookie, validate it, verify username extracted correctly
  - [x] 7.3 `TestTamperedCookieRejected`: Create cookie, modify HMAC portion, verify validation fails
  - [x] 7.4 `TestExpiredCookieRejected`: Create cookie with timestamp in the past (or very short timeout), verify rejection
  - [x] 7.5 `TestGetSecretAutoGenerate`: Verify GetSecret() auto-generates and persists on first call, returns same value on second call
  - [x] 7.6 `TestBasicAuthParse`: Test parsing of valid/invalid Authorization headers
  - [x] 7.7 `TestGetUserRoles`: Verify role retrieval for known IRIS user
  - [x] 7.8 Compile and run tests

- [x] Task 8: Create HTTP integration tests (AC: #11, #12)
  - [x] 8.1 Create `src/IRISCouch/Test/AuthHttpTest.cls` extending %UnitTest.TestCase
  - [x] 8.2 `TestSessionPostSuccess`: POST /_session with _SYSTEM/SYS credentials, verify 200, verify Set-Cookie header contains AuthSession
  - [x] 8.3 `TestSessionPostBadPassword`: POST /_session with wrong password, verify 401
  - [x] 8.4 `TestSessionGetAuthenticated`: POST to login, extract cookie, GET /_session with cookie, verify userCtx
  - [x] 8.5 `TestSessionGetUnauthenticated`: GET /_session with no credentials, verify `"name":null` in userCtx
  - [x] 8.6 `TestSessionDelete`: POST to login, DELETE /_session, verify expired cookie in response
  - [x] 8.7 `TestBasicAuthOnExistingEndpoint`: GET / with Basic auth, verify 200 welcome response
  - [x] 8.8 `TestTamperedCookieViaHttp`: POST to login, tamper with cookie value, GET /_session, verify anonymous context
  - [x] 8.9 Compile and run tests
  - [x] 8.10 **IMPORTANT**: Use `%Net.HttpRequest` directly (not MakeRequest helper) for cookie tests — need manual cookie header control

- [x] Task 9: Run full test suite — verify 325+ tests pass, zero regressions (AC: #11)
  - [x] 9.1 Compile all new and modified classes
  - [x] 9.2 Run full test suite
  - [x] 9.3 Verify all 312 existing tests pass (328 total: 312 existing + 16 new all pass)
  - [x] 9.4 Verify all new auth tests pass (9 unit + 7 HTTP = 16 new tests)

## Dev Notes

### Architecture & Patterns

- **Auth package location:** `src/IRISCouch/Auth/` — new package per architecture doc
- **Handler location:** `src/IRISCouch/API/AuthHandler.cls` — per architecture class map
- **Test location:** `src/IRISCouch/Test/AuthTest.cls` + `AuthHttpTest.cls`
- **Router wrapper pattern:** Every UrlMap route needs a local wrapper method in Router.cls delegating to the handler class (see memory `feedback_router_wrapper_pattern.md`)
- **Catch block pattern:** After Error.Render(), return `$$$OK` not `ex.AsStatus()` (see memory `feedback_catch_block_pattern.md`)
- **RenderInternal for 500s:** Handler catch blocks must use `RenderInternal()` to log exceptions per NFR-S8
- **Error slugs:** Use `Error.Render(401, "unauthorized", "...")` and `Error.Render(403, "forbidden", "...")` — slugs already defined in Error.cls
- **Config pattern:** Add new parameters to Config.cls with defaults, add to GetAll() — follow existing pattern
- **JSON null:** Use `%Set("name", "", "null")` for JSON null per project rules

### IRIS Security API

- **Credential validation:** `$System.Security.Login(username, password)` validates against IRIS user directory
- **User roles:** `Security.Users.Get(username, .props)` retrieves user properties including roles
- **HMAC:** Use `$System.Encryption.HMACSHA256(data, secret)` for cookie signing (IRIS built-in)
- **Base64:** `$System.Encryption.Base64Encode()` / `Base64Decode()` for cookie encoding
- **CRITICAL:** Per project rules — never use `New $NAMESPACE` in REST handlers. Use explicit save/restore pattern if namespace switching is needed.

### CouchDB _session API Format

- **POST /_session request:** `{"name":"username","password":"password"}` (JSON body, NOT form-encoded despite CouchDB also supporting form-encoded)
- **POST /_session response (success):** `{"ok":true,"name":"username","roles":["_admin"]}` with `Set-Cookie: AuthSession=<value>; Version=1; Expires=<date>; Max-Age=<seconds>; Path=/; HttpOnly`
- **GET /_session response (authenticated):** `{"ok":true,"userCtx":{"name":"username","roles":["_admin"]},"info":{"authenticated":"cookie","authentication_db":"_users","authentication_handlers":["cookie","default"]}}`
- **GET /_session response (unauthenticated):** `{"ok":true,"userCtx":{"name":null,"roles":[]},"info":{"authentication_handlers":["cookie","default"]}}`
- **DELETE /_session response:** `{"ok":true}` with expired cookie

### Request-Scoped Auth Context
- Store auth state in process-private globals or %-variables accessible to all handler methods
- Pattern: `Set %IRISCouchUser = username`, `Set %IRISCouchRoles = rolesArray`
- Anonymous: `Set %IRISCouchUser = ""`, `Set %IRISCouchRoles = []`
- All handlers can check `%IRISCouchUser` to determine auth state
- Enforcement (checking if auth is required) is deferred to Story 7.4

### OnPreDispatch Contract
- `ClassMethod OnPreDispatch(pUrl As %String, pMethod As %String, ByRef pContinue As %Boolean) As %Status`
- Set `pContinue = 1` to continue dispatch, `pContinue = 0` to block
- For now: always set `pContinue = 1` (auth establishes context but doesn't block)
- This means all existing endpoints continue to work without auth — backward compatible
- Story 7.4 will add authorization enforcement that may set `pContinue = 0`

### Cookie Handling in Tests
- `%Net.HttpRequest` supports cookies via `.SetHeader("Cookie", "AuthSession=value")`
- To extract Set-Cookie from response: `%Net.HttpResponse.GetHeader("SET-COOKIE")`
- Tests need manual cookie management — can't use MakeRequest helper for cookie round-trips

### Previous Story Intelligence (from Story 7.0)
- Story 7.0 was rules/test cleanup only — no new production classes
- All 312 tests pass with zero regressions
- TypeRank empty-string fix ensures null values handled correctly
- This is the first story creating new production code in Epic 7

### References
- [Source: _bmad-output/planning-artifacts/architecture.md — Auth/ package structure, AuthHandler class map]
- [Source: _bmad-output/planning-artifacts/prd.md — NFR-S1 (no shadow credentials), NFR-S3 (HMAC cookie integrity)]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 7.1 — Acceptance criteria]
- [Source: src/IRISCouch/API/Router.cls — Existing UrlMap and wrapper pattern]
- [Source: src/IRISCouch/Config.cls — Configuration parameter pattern]
- [Source: src/IRISCouch/Util/Error.cls — Existing unauthorized/forbidden slugs]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6

### Debug Log References

### Implementation Plan
- CouchDB AuthSession cookie format: base64-encoded value containing `username:hex_timestamp:hmac_hash`
- HMAC algorithm: HMAC-SHA256 (modern CouchDB 3.x uses SHA256)
- Data signed: `username:hex_timestamp` using server secret
- Session timeout: 600 seconds (CouchDB default)
- IRIS credential validation: `$System.Security.Login(username, password)` returns 1/0
- IRIS HMAC: `$System.Encryption.HMACSHA256(data, key)` for cookie signing
- IRIS Base64: `$System.Encryption.Base64Encode()` / `Base64Decode()`
- Cookie format we will implement: `AuthSession=base64(username:hexTimestamp:hmacHex); Path=/iris-couch; HttpOnly; Max-Age=600`

### Completion Notes List
- Task 1: Researched CouchDB _session API via Perplexity MCP. Confirmed HMAC-SHA256, base64-encoded cookie format, 600s default timeout.
- Task 2: Added AUTHSECRET and AUTHTIMEOUT parameters to Config.cls with GetAll() support.
- Task 3: Created Auth.Session with CreateCookie, ValidateCookie, GetSecret (auto-generates 32-byte hex secret). Added hex/bytes utility methods. Fixed Base64 linebreak issue by stripping CR/LF from encoded output.
- Task 4: Created Auth.Basic with Authenticate (parses Basic header, validates via $System.Security.Login) and GetUserRoles (switches to %SYS to query Security.Users). Returns roles as %DynamicArray.
- Task 5: Created API.AuthHandler with HandleSessionPost (login), HandleSessionGet (session info), HandleSessionDelete (logout). Follows catch-block pattern (RenderInternal for 500s, return $$$OK).
- Task 6: Updated Router.cls with _session routes (before all other routes), wrapper methods, OnPreDispatch middleware that establishes %IRISCouchUser/%IRISCouchRoles/%IRISCouchAuthMethod on every request. Cookie auth checked first, then Basic auth, else anonymous. pContinue always set to 1 (enforcement deferred to Story 7.4).
- Task 7: Created AuthTest.cls with 9 unit tests covering cookie round-trip, tampering, expiration, secret auto-gen, Basic auth parsing, role retrieval, hex conversion, invalid formats.
- Task 8: Created AuthHttpTest.cls with 7 HTTP integration tests covering login success/failure, session info authenticated/unauthenticated, logout, Basic auth, and tampered cookie via HTTP.
- Task 9: Full regression suite passes — 328 tests total (312 existing + 16 new), zero failures.

### File List
- src/IRISCouch/Config.cls (modified — added AUTHSECRET, AUTHTIMEOUT parameters)
- src/IRISCouch/Auth/Session.cls (new — cookie auth engine)
- src/IRISCouch/Auth/Basic.cls (new — HTTP Basic auth handler)
- src/IRISCouch/API/AuthHandler.cls (new — session endpoints)
- src/IRISCouch/API/Router.cls (modified — _session routes, wrapper methods, OnPreDispatch)
- src/IRISCouch/Test/AuthTest.cls (new — 9 unit tests)
- src/IRISCouch/Test/AuthHttpTest.cls (new — 7 HTTP integration tests)

### Review Findings

- [x] [Review][Patch] HMAC comparison uses standard string equality vulnerable to timing attacks [Auth/Session.cls:68] -- **FIXED**: Added ConstantTimeEquals() method and replaced direct comparison
- [x] [Review][Patch] AUTHSECRET exposed in plain text via Config.GetAll() [Config.cls:87] -- **FIXED**: GetAll() now returns "[REDACTED]" when AUTHSECRET has a value
- [x] [Review][Patch] AuthHandler uses Set tResponse.ok = 1 producing JSON ok:1 instead of ok:true [AuthHandler.cls:49,75,116] -- **FIXED**: Changed to %Set("ok", 1, "boolean") matching project pattern
- [x] [Review][Patch] Future-dated cookies never expire due to one-sided timestamp check [Auth/Session.cls:73] -- **FIXED**: Added (tAge < 0) check to reject cookies with timestamps in the future
- [x] [Review][Defer] Username containing colons would break cookie parsing format [Auth/Session.cls:59-61] -- deferred, matches CouchDB's own colon-delimited format; IRIS usernames do not conventionally contain colons
- [x] [Review][Defer] GetSecret() race condition: concurrent requests could generate different secrets [Auth/Session.cls:96-101] -- deferred, same single-process architecture constraint documented across project

### Change Log
- 2026-04-13: Story 7.1 implementation — session authentication, Basic auth, auth middleware, 16 new tests (328 total, zero regressions)
- 2026-04-13: Code review fixes — timing-safe HMAC comparison, AUTHSECRET redaction in GetAll(), boolean ok:true in AuthHandler, future-dated cookie rejection
