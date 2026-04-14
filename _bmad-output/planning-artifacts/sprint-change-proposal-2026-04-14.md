# Sprint Change Proposal — 2026-04-14

## Issue Summary

`$System.Security.Login()` switches the IRIS process security context to the authenticated user. Non-admin users created via the `_users` database lack `%DB_IRISCOUCH` and other namespace-level roles, causing all subsequent code execution to fail with 500 errors. Additionally, PBKDF2 was manually reimplemented when `$System.Encryption.PBKDF2()` exists natively.

Discovered during manual testing post-Epic 7 completion. Affects all non-_SYSTEM users for both Basic auth and session login.

## Impact Analysis

- **Epic 7 only** — no other epics affected
- **Files:** Auth/Basic.cls, API/AuthHandler.cls, Auth/Users.cls
- **No PRD, architecture, or UX changes needed**
- **Epic 8 (Replication) depends on working auth** — must fix before starting

## Recommended Approach

**Direct Adjustment** — Add Story 7.5 to Epic 7 with 5 targeted changes:
1. Replace `$System.Security.Login()` with `Security.Users.CheckPassword()` in Basic.Authenticate()
2. Replace `$System.Security.Login()` with `Security.Users.CheckPassword()` in AuthHandler.HandleSessionPost()
3. Assign `%DB_IRISCOUCH,%DB_IRISLIB,%DB_IRISTEMP` roles when creating users in Auth.Users
4. Replace manual PBKDF2SHA256 with native `$System.Encryption.PBKDF2()`
5. End-to-end verification with non-admin user

## Implementation Handoff

**Scope:** Minor — Developer agent direct implementation
**Story:** 7.5 (Auth Hotfix — Credential Validation & Role Assignment)
**Success Criteria:** Non-admin user can authenticate via Basic auth and POST /_session without 500 errors. All 375 existing tests pass.
