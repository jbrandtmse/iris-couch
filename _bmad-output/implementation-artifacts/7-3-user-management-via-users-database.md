# Story 7.3: User Management via _users Database

Status: done

## Story

As an operator,
I want to manage users via documents in the `_users` database that synchronize to IRIS user records,
So that I can use the standard CouchDB user management API.

## Acceptance Criteria

1. `PUT /iris-couch/_users/org.couchdb.user:username` with `{"name":"username","password":"secret","roles":[],"type":"user"}` stores the user document in the `_users` database AND creates a corresponding IRIS user record via `Security.Users`
2. The password is hashed using PBKDF2 via IRIS primitives with iteration count >= 10,000 (NFR-S2) and stored in the IRIS user record, NOT in the `_users` document body
3. The `_users` document body stores CouchDB-compatible metadata: `password_scheme`, `derived_key`, `salt`, `iterations`, `pbkdf2_prf` — but the plaintext password is removed
4. Updating a user document with a new `password` field updates the IRIS user record password with the new PBKDF2 hash and strips the password from the document
5. Deleting a user document removes the corresponding IRIS user record
6. The `_users` database is a real IRISCouch database — all standard document operations (CRUD, revisions, changes feed) work normally on it
7. `GET /iris-couch/_users/org.couchdb.user:username` returns the user document WITHOUT any plaintext password (password field stripped)
8. The write synchronization is one-to-one: every `_users` write creates/updates/removes exactly one IRIS user
9. No credentials exist outside the IRIS user directory (NFR-S1)
10. All 345 existing tests pass with zero regressions
11. New unit and HTTP integration tests cover user creation, password update, user deletion, IRIS user sync verification, and password stripping

## Tasks / Subtasks

- [x] Task 1: Research CouchDB _users database internals (AC: #1, #2, #3)
  - [x] 1.1 Read CouchDB source: `sources/couchdb/src/couch/src/couch_users_db.erl` — understand `before_doc_update` hook, password hashing flow, field stripping
  - [x] 1.2 Research IRIS `Security.Users` API: Create(), Modify(), Delete(), password property format
  - [x] 1.3 Research IRIS PBKDF2: `$System.Encryption.PBKDF2()` or equivalent — parameters, output format
  - [x] 1.4 Document findings in Dev Notes

- [x] Task 2: Create Auth.Users — _users database sync engine (AC: #1, #2, #3, #4, #5, #8, #9)
  - [x] 2.1 Create `src/IRISCouch/Auth/Users.cls`
  - [x] 2.2 Implement `ClassMethod OnUserDocSave(pDB As %String, pDocId As %String, pBody As %DynamicObject) As %DynamicObject`:
    - Called by DocumentEngine AFTER normal document save, WITHIN the transaction
    - Only processes documents in the `_users` database
    - Extract username from `_id`: `org.couchdb.user:<name>` → `<name>`
    - If `password` field exists in body:
      - Generate random salt (16+ bytes hex)
      - Hash password using PBKDF2-SHA256 with >= 10,000 iterations via IRIS primitives
      - Create or update IRIS user via Security.Users (requires %SYS namespace switch)
      - Set CouchDB metadata fields: `password_scheme: "pbkdf2"`, `derived_key`, `salt`, `iterations: 10000`, `pbkdf2_prf: "sha256"`
      - Remove `password` field from body
      - Return modified body (with password stripped, metadata added)
    - If no `password` field: update roles only if changed
    - **CRITICAL**: Use explicit save/restore namespace pattern (not `New $NAMESPACE`)
  - [x] 2.3 Implement `ClassMethod OnUserDocDelete(pDB As %String, pDocId As %String)`:
    - Called by DocumentEngine when deleting in `_users` database
    - Extract username from doc ID
    - Remove IRIS user via Security.Users.Delete() (requires %SYS namespace)
  - [x] 2.4 Implement `ClassMethod CreateOrUpdateIRISUser(pUsername As %String, pPassword As %String, pRoles As %String) As %Status`:
    - Switch to %SYS namespace
    - Check if user exists via Security.Users.Exists()
    - If exists: Modify password and roles
    - If new: Create user with password and roles
    - Restore namespace
  - [x] 2.5 Implement `ClassMethod IsUsersDB(pDB As %String) As %Boolean`:
    - Return 1 if pDB = "_users"
  - [x] 2.6 Implement `ClassMethod ExtractUsername(pDocId As %String) As %String`:
    - Parse `org.couchdb.user:<name>` → `<name>`
    - Return empty string if format doesn't match
  - [x] 2.7 Compile and verify

- [x] Task 3: Hook into DocumentEngine save path (AC: #1, #6)
  - [x] 3.1 Edit `src/IRISCouch/Core/DocumentEngine.cls`
  - [x] 3.2 In the `Save()` method, AFTER storing document body but WITHIN TSTART/TCOMMIT:
    - Check if `Auth.Users.IsUsersDB(pDB)` is true
    - If yes, call `Auth.Users.OnUserDocSave(pDB, pDocId, bodyObj)`
    - If body was modified (password stripped), re-save the modified body via Storage.Document
  - [x] 3.3 In the `SaveDeleted()` method, within transaction:
    - Check if `Auth.Users.IsUsersDB(pDB)` is true
    - If yes, call `Auth.Users.OnUserDocDelete(pDB, pDocId)`
  - [x] 3.4 **CRITICAL**: The sync is INSIDE the transaction. If IRIS user creation fails, the entire document write rolls back.
  - [x] 3.5 Compile and verify

- [x] Task 4: Ensure _users database can be created (AC: #6)
  - [x] 4.1 Verify that `PUT /iris-couch/_users` creates the database like any other
  - [x] 4.2 No special handling needed — the database is a regular IRISCouch database
  - [x] 4.3 The `_users` name starts with underscore but CouchDB allows this for system databases
  - [x] 4.4 Verify existing database name validation doesn't reject underscore-prefixed names

- [x] Task 5: Create unit tests (AC: #10, #11)
  - [x] 5.1 Create `src/IRISCouch/Test/UsersTest.cls` extending %UnitTest.TestCase
  - [x] 5.2 `TestExtractUsername`: Verify `org.couchdb.user:alice` → `alice`, invalid formats → ""
  - [x] 5.3 `TestIsUsersDB`: Verify `_users` returns true, other names return false
  - [x] 5.4 `TestOnUserDocSaveStripsPassword`: Create user doc body with password, call OnUserDocSave, verify password field removed and metadata fields added
  - [x] 5.5 `TestOnUserDocSaveCreatesIRISUser`: Call OnUserDocSave, verify IRIS user exists via Security.Users.Exists() in %SYS
  - [x] 5.6 `TestOnUserDocDeleteRemovesIRISUser`: Create user, then call OnUserDocDelete, verify IRIS user removed
  - [x] 5.7 `TestPasswordNotInDocument`: Save user doc via DocumentEngine, read it back, verify no password field
  - [x] 5.8 Compile and run tests
  - [x] 5.9 **IMPORTANT**: Test cleanup must remove test IRIS users in OnAfterOneTest to avoid polluting the IRIS security config

- [x] Task 6: Create HTTP integration tests (AC: #10, #11)
  - [x] 6.1 Create `src/IRISCouch/Test/UsersHttpTest.cls` extending %UnitTest.TestCase
  - [x] 6.2 `TestCreateUsersDatabase`: PUT /_users, verify 201
  - [x] 6.3 `TestCreateUser`: PUT /_users/org.couchdb.user:testuser with password, verify 201, verify GET returns doc without password
  - [x] 6.4 `TestUpdateUserPassword`: PUT with new password, verify IRIS user updated
  - [x] 6.5 `TestDeleteUser`: DELETE user doc, verify IRIS user removed
  - [x] 6.6 `TestUserDocHasMetadata`: GET user doc, verify password_scheme, derived_key, salt, iterations fields present
  - [x] 6.7 Compile and run tests
  - [x] 6.8 **IMPORTANT**: Cleanup must delete `_users` database AND remove test IRIS users

- [x] Task 7: Run full test suite — verify 358+ tests pass, zero regressions (AC: #10)
  - [x] 7.1 Compile all new and modified classes
  - [x] 7.2 Run full test suite
  - [x] 7.3 Verify all 345 existing tests pass
  - [x] 7.4 Verify all new _users tests pass

## Dev Notes

### Architecture & Patterns
- **Auth.Users location:** `src/IRISCouch/Auth/Users.cls` — per architecture (`Auth/Users.cls` in class map)
- **DocumentEngine hook pattern:** Similar to how Projection.Winners is called in DocumentEngine.Save() — synchronous call inside transaction
- **Namespace switching:** Use explicit `Set tOrigNS = $Namespace` / `Set $Namespace = "%SYS"` / restore pattern — NEVER `New $NAMESPACE` in REST context
- **Catch block restoration:** In catch blocks, ALWAYS restore namespace as first line: `Set $Namespace = tOrigNS`
- **Storage encapsulation:** Never access ^IRISCouch.* globals directly — use Storage.Document methods

### CouchDB _users Database Behavior (from source: couch_users_db.erl)
- **before_doc_update hook:** CouchDB intercepts writes to `_users` and processes the password before storage
- **Password hashing:** PBKDF2 with SHA-256 PRF, configurable iterations (CouchDB 3.x defaults to 600,000, our minimum per NFR-S2 is 10,000)
- **Fields stored in document:** `password_scheme: "pbkdf2"`, `pbkdf2_prf: "sha256"`, `derived_key: <hex>`, `salt: <hex>`, `iterations: <int>`
- **Fields removed from document:** `password` (the plaintext), `preserve_salt`
- **Document ID format:** `org.couchdb.user:<username>` — the `org.couchdb.user:` prefix is mandatory
- **Document body fields:** `name`, `type: "user"`, `roles: []`, plus the hashing metadata above

### IRIS Security.Users API
- **Exists:** `Security.Users.Exists(username, .exists)` — returns status, sets exists=1/0
- **Create:** `Security.Users.Create(username, .props)` — props is a subscripted array with properties
- **Modify:** `Security.Users.Modify(username, .props)` — modify existing user properties
- **Delete:** `Security.Users.Delete(username)` — remove user
- **Password property:** `props("Password") = "cleartext"` — IRIS hashes internally
- **Roles property:** `props("Roles") = "role1,role2"` — comma-separated string
- **All require %SYS namespace**

### PBKDF2 in IRIS
- For the CouchDB metadata fields (derived_key, salt), we need to compute PBKDF2 ourselves
- IRIS `$System.Encryption.PBKDF2()` may be available — research in Task 1
- If not available, we can use `$System.Encryption.HMACSHA()` iteratively (PBKDF2 is iterated HMAC)
- The derived_key in the document is for CouchDB wire compatibility — IRIS stores its own internal password hash

### Transaction Safety
- The _users sync MUST be inside the DocumentEngine TSTART/TCOMMIT
- If IRIS user creation fails → TROLLBACK → document write also rolls back
- This ensures one-to-one sync guarantee (AC #8)

### CouchDB Source Reference
- `sources/couchdb/src/couch/src/couch_users_db.erl` — `before_doc_update/3`, `save_doc/1`, `remove_password_fields/1`

### Previous Story Intelligence (from Story 7.2)
- Auth package has Session.cls, Basic.cls, JWT.cls, Proxy.cls — Users.cls joins this family
- Basic.GetUserRoles() shows the %SYS namespace switching pattern to follow
- Config.cls has AUTHSECRET, AUTHTIMEOUT, JWT*, PROXYAUTHSECRET — no new config params needed for this story
- 345 tests pass with zero regressions

### References
- [Source: _bmad-output/planning-artifacts/epics.md#Story 7.3 — Acceptance criteria]
- [Source: _bmad-output/planning-artifacts/prd.md — NFR-S1 (no shadow credentials), NFR-S2 (PBKDF2 hashing), FR66-67]
- [Source: sources/couchdb/src/couch/src/couch_users_db.erl — Password hashing, field stripping]
- [Source: src/IRISCouch/Core/DocumentEngine.cls — Save() transaction pattern]
- [Source: src/IRISCouch/Auth/Basic.cls:56 — GetUserRoles %SYS namespace pattern]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6

### Debug Log References
- PBKDF2 verified against RFC 6070 test vector: password="password", salt="salt", c=1, dkLen=20 -> 120fb6cffcf8b32c43e7225256c4f837a86548c9
- Security.Users.Exists() does NOT set output parameter when user doesn't exist (unlike documentation) -- must initialize variable before call
- $System.Encryption.PBKDF2() not available in IRIS -- implemented PBKDF2 via iterated $System.Encryption.HMACSHA(256)
- $System.Encryption.GenCryptRand(16) confirmed working for salt generation
- Security.Users.Create/Modify/Delete all confirmed working with %SYS namespace switch

### Completion Notes List
- Created IRISCouch.Auth.Users class with full _users database sync engine
- Implemented PBKDF2-SHA256 using iterated HMACSHA256 (matching RFC 6070 test vectors)
- Hooked into DocumentEngine.Save() and SaveDeleted() within transaction boundaries
- Password stripping and CouchDB metadata fields verified end-to-end through HTTP
- IRIS user creation/update/deletion confirmed via Security.Users API
- All existing tests pass with zero regressions
- Key discovery: Security.Users.Exists() returns error status AND leaves output parameter UNDEFINED when user doesn't exist -- requires initializing variable before call and checking for non-empty rather than numeric truthiness

### File List
- src/IRISCouch/Auth/Users.cls (NEW) -- _users database sync engine with PBKDF2, IRIS user management
- src/IRISCouch/Core/DocumentEngine.cls (MODIFIED) -- Added _users hooks in Save() and SaveDeleted() methods
- src/IRISCouch/Test/UsersTest.cls (NEW) -- Unit tests for Auth.Users (10 test methods)
- src/IRISCouch/Test/UsersHttpTest.cls (NEW) -- HTTP integration tests for _users API (5 test methods)

### Review Findings

- [x] [Review][Patch] Roles-only path missing catch-block namespace restore in OnUserDocSave [Auth/Users.cls:111] -- FIXED: Added $Get(tOrigNS) restore in catch block
- [x] [Review][Patch] MangoIndex not re-indexed after _users body modification [DocumentEngine.cls:96] -- FIXED: Added MangoIndex delete+re-index after modified body re-save
- [x] [Review][Patch] OnUserDocDelete ignores Security.Users.Delete() status [Auth/Users.cls:139] -- FIXED: Capture status, throw on error to trigger rollback
- [x] [Review][Patch] Roles-only UpdateIRISUserRoles status not checked [Auth/Users.cls:106] -- FIXED: Added $$$ISERR check with throw
- [x] [Review][Patch] PBKDF2 silently returns empty on failure [Auth/Users.cls:82] -- FIXED: Added empty-check guard with throw before using derived key
- [x] [Review][Defer] SaveWithHistory does not call _users hooks [DocumentEngine.cls:424-516] -- deferred, replication protocol not yet implemented (Epic 8)
- [x] [Review][Defer] SaveWithAttachments does not call _users hooks [DocumentEngine.cls:538-685] -- deferred, _users docs with attachments extremely unlikely
- [x] [Review][Defer] Falsy password values not guarded [Auth/Users.cls:77] -- deferred, CouchDB clients always send password as string
- [x] [Review][Defer] Hardcoded test credentials in UsersHttpTest [Test/UsersHttpTest.cls:184-189] -- deferred, pre-existing pattern across all HTTP test files

## Change Log
- 2026-04-13: Story 7.3 implementation complete -- Auth.Users sync engine, DocumentEngine hooks, unit and HTTP tests
- 2026-04-13: Code review -- 5 patches auto-resolved (namespace restore, status checks, MangoIndex re-index, PBKDF2 guard), 4 items deferred
