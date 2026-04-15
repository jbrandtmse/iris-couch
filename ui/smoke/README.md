# Dev-Server Smoke Test

Tooling pick: **plain Node 20+ with built-in fetch** (no Playwright / Cypress dependency).

**Why this exists.** During Epic 10, the dev proxy (`proxy.conf.js`) was broken
for multiple commits without anyone noticing because no automated check
exercised `ng serve` end-to-end. The Epic 10 retrospective escalated this to
a systemic verification gap that allowed five bugs into a "done" state.
Story 11.0 Task 4 closes that gap.

## What it checks

1. `ng serve` boots (or an existing server is reachable on `:4200`).
2. The proxy rewrites `/iris-couch/*` to the IRIS backend.
3. `POST /iris-couch/_session` with test credentials returns 200 + a
   `Set-Cookie` header (catches the exact regression Story 10.3 shipped with).
4. `GET /iris-couch/_all_dbs` with the session cookie returns a JSON array.

Exits 0 on success, non-zero on any failure. Stderr contains the first 500
bytes of the failing response for diagnosis.

## Running locally

```
cd ui
node smoke/smoke.mjs
```

Tunable via environment variables:

| Variable | Default | Purpose |
|---|---|---|
| `SMOKE_BASE_URL` | `http://localhost:4200` | Dev-server URL |
| `SMOKE_USERNAME` | `_system` | IRIS user to authenticate as |
| `SMOKE_PASSWORD` | `SYS` | Password |
| `SMOKE_START_SERVER` | `1` | `0` to reuse an existing `ng serve` |
| `SMOKE_READY_TIMEOUT_MS` | `90000` | How long to wait for `ng serve` |

## Backend fixture

This smoke test requires a running IRIS instance with the `iris-couch`
web application configured and at least one valid credential pair. In CI
this must be provisioned via a container, service job, or pre-existing
shared instance.

Required state on the backend:

- IRIS listening on `localhost:52773` (or override via the `proxy.conf.js`
  target).
- Web application `iris-couch` enabled and mapped to the IRISCouch package.
- A known credential pair available as `SMOKE_USERNAME` / `SMOKE_PASSWORD`.
- At least one namespace with the `iris-couch-test` prefix for isolation
  (recommended but not required by this script).

## CI wiring

`.github/workflows/ui-smoke.yml` runs this script on PRs that touch `ui/`.
Because the workflow depends on a live IRIS backend (which is not available
in the default GitHub-hosted runners), the job is currently scoped to a
self-hosted runner labelled `iris-smoke`. If your fork does not have a
matching runner, the workflow will queue indefinitely and you can skip it
via the repo's "required checks" settings, or comment out the `runs-on`
line for a one-off run.

## Deepening the smoke

For a richer end-to-end flow (per-row delete, routing, visual regression)
use the Chrome DevTools MCP smoke script documented in
`ui/TESTING-CHECKLIST.md` §6.
