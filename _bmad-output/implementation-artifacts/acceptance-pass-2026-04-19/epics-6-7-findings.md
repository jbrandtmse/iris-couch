# Epics 6-7 Acceptance Test Report — 2026-04-19

## Summary

Live-server `curl` pass against `http://localhost:52773/iris-couch/` using `_system:SYS`. Throwaway DBs `acc19_e6_mango`, `acc19_e7_auth`, `acc19_e7_secdb` plus test users `alice` / `bob` were created and cleaned up successfully.

**Verdict: Epic 6 PASS, Epic 7 PASS with two minor compatibility gaps noted in 7.1.** No security regressions found. Story 7.5 hotfix (real `Security.Users.CheckPassword` validation + `IRISCouch_Admin` role assignment) verified working.

## Story-by-Story Results

### Story 6.1: Mango Index Management — PASS
- AC1 PASS — `POST /{db}/_index` `{index:{fields:["name"]},name:"by-name"}` -> 200 `{"result":"created","id":"_design/5297f08a275eeb017fb8568aac8e023ae6c0794f","name":"by-name"}`. Re-POST returned `{"result":"exists",...}` (idempotent, correct).
- AC2 PASS — `GET /{db}/_index` -> `{"total_rows":2,"indexes":[{"ddoc":null,"name":"_all_docs","type":"special",...},{"ddoc":"_design/...","name":"by-name","type":"json",...}]}`. Implicit `_all_docs` special index present alongside the user index.
- AC3 PASS (with note) — `DELETE /{db}/_index/{ddoc}/json/{name}` works **without** the `_design/` prefix on `{ddoc}` (e.g. `/_index/5297f08a.../json/by-name` -> 200 `{"ok":true}`). Passing the literal `_design/...` string from the GET response returns 404 — the dev must strip the prefix. CouchDB 3.x accepts the bare hash, so wire-compatible, but slightly easier to trip over than necessary.

### Story 6.2: Mango Query Execution — PASS
All operators verified against the 5-doc seed (`u1` Alice/30/NYC/active, `u2` Bob/25/LA/inactive, `u3` Carol/35/NYC/—, `u4` Dave/40/Chicago/active, `u5` Widget/—/—/—):
- `$eq` PASS — `{name:"Alice"}` -> 1 doc.
- `$ne` PASS (critical) — `{status:{$ne:"active"}}` -> u2, u3, u5. Correctly returns docs **missing** the `status` field per CouchDB Mango semantics.
- `$gt`/`$gte`/`$lt`/`$lte` PASS — `{age:{$gt:30}}` -> u3, u4.
- `$in` PASS — `{city:{$in:["NYC","LA"]}}` -> u1, u2, u3.
- `$nin` PASS (critical) — `{status:{$nin:["inactive"]}}` -> u1, u3, u4, u5 (includes missing-field docs).
- `$exists:true/false` PASS — split docs correctly between status-having and status-missing.
- `$and` PASS — `{$and:[{city:"NYC"},{age:{$gte:30}}]}` -> u1, u3.
- `$or` PASS — `{$or:[{name:"Alice"},{name:"Bob"}]}` -> u1, u2.
- `$not` PASS — `{$not:{city:"NYC"}}` -> u2, u4, u5.
- `$regex` PASS — `{name:{$regex:"^A"}}` -> u1.
- AC `fields` projection PASS — only requested keys returned.
- AC `sort + limit + skip` PASS — `sort:[{name:"asc"}], limit:2, skip:1` returned u2, u3 with bookmark `dTN8Q2Fyb2w`.
- AC `bookmark` pagination PASS — passing prior bookmark + limit:2 returned u4, u5 (correct next page).
- AC `execution_stats:true` PASS — response includes `{total_keys_examined:5, total_docs_examined:5, results_returned:1, execution_time_ms:1.7}`.
- AC empty selector PASS — `{}` returned all 5 docs.
- AC6 `_explain` PASS — `POST /{db}/_explain {selector:{name:"Alice"}}` returns `{dbname, index, selector, opts, limit, skip, fields, index_candidates:[{index, analysis:{usable, reasons, ranking, covering}},...]}`. Correctly chose the `by-name` JSON index over `_all_docs` (ranking 1 vs 0; `_all_docs` flagged with `unfavored_type`). Note: spec's mention of a `range` field is not in the response — `index_candidates` is the actual shape per the story's AC6/Task 6.2.
- `warning:"No matching index found, ..."` PASS — included on full-scan queries (e.g. `$ne`, `$nin`, `$exists`), absent on indexed queries (`name:"Alice"`).

### Story 7.1: Session & Basic Auth — PASS with two compat gaps
- AC `POST /_session` JSON PASS — `{name:"_system",password:"SYS"}` -> 200 `{"ok":true,"name":"_system","roles":["%All","%IRISCouch_Admin","IRISCouch_Admin"]}` + `Set-Cookie: AuthSession=...; Max-Age=600; Path=/iris-couch; HttpOnly`.
- **GAP 1**: `POST /_session` form-encoded (`Content-Type: application/x-www-form-urlencoded`, body `name=_system&password=SYS`) -> 400 `{"error":"bad_request","reason":"Request body is required."}`. CouchDB 3.x accepts both form and JSON; only JSON works here. Most clients (PouchDB, Fauxton) send JSON, so impact is limited, but it is a wire-compat deviation.
- AC `GET /_session` with cookie PASS — `{"ok":true,"userCtx":{"name":"_system","roles":[...]},"info":{"authenticated":"cookie"}}`.
- **GAP 2**: `GET /_session` anonymous returns `info:{}` — CouchDB spec includes `info.authentication_handlers:["cookie","default"]` so clients can discover supported handlers. Empty `info` may break clients that probe handlers.
- AC `DELETE /_session` PASS — 200 + `Set-Cookie: AuthSession=; Max-Age=0; ...` (proper expiration).
- AC wrong-password PASS — `{name:"_system",password:"WRONG"}` -> 401 `{"error":"unauthorized","reason":"Name or password is incorrect."}`.
- AC Basic Auth PASS — `-u _system:SYS` honored on `GET /{db}` -> 200 with DB info.
- AC anonymous read of DB without `_security` PASS (by design) — returns 200. Per Story 7.1 spec, "auth is established but not enforced at this layer (enforcement is Story 7.4)" — confirmed by 7.4 below.

### Story 7.2: JWT & Proxy Auth — PASS (config-gated, disabled by default)
- Bearer token: `Authorization: Bearer <bogus>` -> `GET /_session` returns anonymous context (`{userCtx:{name:null,roles:[]}}`), not 401. Per AC1 + Config `JWTSECRET=""` default, JWT is disabled and ignored — bogus tokens fall through to anonymous, which is correct gate behavior.
- Proxy headers: `X-Auth-CouchDB-UserName: alice` + roles header without token -> anonymous (proxy auth disabled by default per `PROXYAUTHSECRET=""`). Correct.
- Did not exercise enabled JWT/proxy paths (AC1-4) — no shared secret configured on the running instance, and the spec marks these config-gated. Negative paths (disabled = ignore) verified.

### Story 7.3: User Management via _users — PASS
- AC PUT user PASS — `PUT /_users/org.couchdb.user:alice {name,password:"secret123",roles:[],type:"user"}` -> 201 `{"ok":true,"id":"org.couchdb.user:alice","rev":"1-..."}`.
- AC password hashing PASS — `GET` shows `password_scheme:"pbkdf2", pbkdf2_prf:"sha256", derived_key:"...", salt:"...", iterations:10000`. Plain password is not stored.
- AC login as new user PASS — `POST /_session {name:"alice",password:"secret123"}` -> 200 + cookie. Verifies Story 7.5 hotfix: `Security.Users.CheckPassword` is the actual validator (wrong password -> 401).
- DELETE alice & bob PASS — both removed cleanly with rev.
- Note: alice's `roles` in the session response are IRIS internal (`%DB_IRISCOUCH`, `%DB_IRISLIB`, `%DB_IRISTEMP`), not the empty `[]` from the user doc. This is the IRIS-side role list, not the CouchDB user-doc roles. Wire-compat deviation worth flagging — clients comparing `roles` on the session against the user doc will see a mismatch.

### Story 7.4: Per-Database _security — PASS
- AC PUT/GET `_security` PASS — round-trips `{admins:{names:["_system"],roles:[]},members:{names:["alice"],roles:[]}}` exactly.
- AC member access PASS — alice (in members) can `GET /acc19_e7_secdb` -> 200.
- AC anonymous denied PASS — no auth -> 401 `{"error":"unauthorized","reason":"Authentication required for this database"}`.
- AC non-member denied PASS — bob (not in members) -> 403 `{"error":"forbidden","reason":"You are not allowed to access this db."}` on both read and write.
- AC admin-vs-member separation PASS — alice (member) can read `_security` but cannot write it (-> 403). Only admins (`_system`) can mutate `_security`.

### Story 7.5: Auth Hotfix — PASS
- `Security.Users.CheckPassword` actually validates: alice with right pw -> 200, alice with wrong pw -> 401 (not previously-broken always-success path).
- `IRISCouch_Admin` role grants admin: `_system`'s session response includes `IRISCouch_Admin` and `%IRISCouch_Admin` in roles, and `_system` can perform admin ops (write `_security`, read `_users`, etc.).
- Negative case: alice (no `IRISCouch_Admin`) cannot write `_security` — confirms role gate, not just username gate.

## Cleanup
All test artifacts removed: alice + bob users (DELETE 200), 3 test DBs (DELETE 200 each).

## Recommended Follow-ups (non-blocking)
1. Story 7.1 form-encoded `POST /_session` — accept `application/x-www-form-urlencoded` for full CouchDB wire compat.
2. Story 7.1 `GET /_session` — populate `info.authentication_handlers` so clients can discover handler set.
3. Story 7.3 — consider returning the user-doc `roles` array in `POST /_session` response (instead of, or alongside, IRIS internal `%DB_*` roles) to match CouchDB shape.
