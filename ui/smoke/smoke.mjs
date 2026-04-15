#!/usr/bin/env node
/**
 * Dev-server smoke test — Story 11.0 AC #4 / Task 4.
 *
 * Closes the verification gap that allowed 5 bugs into "done" during Epic 10
 * (dev proxy broken and undetected because no automated check exercised it).
 *
 * What this script does:
 *   1. Starts `ng serve` (or reuses an existing server on :4200).
 *   2. Polls `http://localhost:4200/` until the dev server is ready.
 *   3. Verifies the dev proxy rewrites `/iris-couch/*` by:
 *        a. Calling `/iris-couch/_session` (POST) with test credentials.
 *        b. Calling `/iris-couch/_all_dbs` (GET) with the returned cookie.
 *   4. Fails with exit code 1 if any step fails.
 *
 * No external test runner (Playwright/Cypress) is used — plain Node + fetch
 * keeps the smoke test fast, dependency-light, and easy to wire into CI.
 * For a richer flow (per-row delete, routing), pair this with the Chrome
 * DevTools MCP smoke script documented in ui/TESTING-CHECKLIST.md §6.
 *
 * Usage:
 *   node ui/smoke/smoke.mjs
 *
 * Environment variables:
 *   SMOKE_BASE_URL  default "http://localhost:4200"
 *   SMOKE_USERNAME  default "_system"
 *   SMOKE_PASSWORD  default "SYS"
 *   SMOKE_START_SERVER  "1" (default) to start ng serve; "0" to reuse existing
 *   SMOKE_READY_TIMEOUT_MS  default 90000 (90s) for ng serve boot
 *
 * Backend requirement:
 *   An IRIS instance running on localhost:52773 with the `iris-couch`
 *   web application configured and at least one valid credential pair.
 *   In CI this should be provisioned via a container or service job.
 */

import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { setTimeout as sleep } from 'node:timers/promises';

const BASE_URL = process.env.SMOKE_BASE_URL || 'http://localhost:4200';
const USERNAME = process.env.SMOKE_USERNAME || '_system';
const PASSWORD = process.env.SMOKE_PASSWORD || 'SYS';
const START_SERVER = (process.env.SMOKE_START_SERVER ?? '1') === '1';
const READY_TIMEOUT_MS = Number(process.env.SMOKE_READY_TIMEOUT_MS || 90000);

/** Log a step. */
function log(msg) {
  // eslint-disable-next-line no-console
  console.log(`[smoke] ${msg}`);
}

/** Fail with a non-zero exit. */
function fail(msg, extra) {
  // eslint-disable-next-line no-console
  console.error(`[smoke] FAIL: ${msg}`);
  if (extra !== undefined) console.error(extra);
  process.exit(1);
}

/** Poll the dev server until it responds 200 or we time out. */
async function waitForServer(url, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  let lastErr;
  while (Date.now() < deadline) {
    try {
      const res = await fetch(url, { redirect: 'manual' });
      if (res.status >= 200 && res.status < 500) return;
    } catch (err) {
      lastErr = err;
    }
    await sleep(500);
  }
  fail(`dev server at ${url} did not become ready within ${timeoutMs}ms`, lastErr);
}

/** Main flow. */
async function main() {
  let serverProc;
  if (START_SERVER) {
    log('starting `ng serve`...');
    serverProc = spawn(
      process.platform === 'win32' ? 'npm.cmd' : 'npm',
      ['run', 'start', '--', '--port', '4200'],
      { cwd: new URL('..', import.meta.url).pathname.replace(/^\//, ''), stdio: ['ignore', 'pipe', 'pipe'] },
    );
    serverProc.stdout?.on('data', (d) => process.stdout.write(`[ng] ${d}`));
    serverProc.stderr?.on('data', (d) => process.stderr.write(`[ng] ${d}`));
    serverProc.on('exit', (code) => {
      if (code !== null && code !== 0) {
        // eslint-disable-next-line no-console
        console.error(`[smoke] ng serve exited with code ${code}`);
      }
    });
  }

  try {
    log(`waiting for ${BASE_URL}/ ...`);
    await waitForServer(`${BASE_URL}/`, READY_TIMEOUT_MS);
    log('dev server is up');

    // 1. Login via proxy.
    log('POST /iris-couch/_session');
    const loginRes = await fetch(`${BASE_URL}/iris-couch/_session`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: `name=${encodeURIComponent(USERNAME)}&password=${encodeURIComponent(PASSWORD)}`,
      redirect: 'manual',
    });
    if (loginRes.status !== 200) {
      const body = await loginRes.text().catch(() => '');
      fail(`login returned HTTP ${loginRes.status}`, body.slice(0, 500));
    }
    const cookie = loginRes.headers.get('set-cookie') || '';
    if (!cookie) {
      fail('login succeeded but no Set-Cookie header was returned — proxy is likely stripping cookies');
    }
    log('login OK, got session cookie');

    // 2. List databases via proxy with the session cookie.
    log('GET /iris-couch/_all_dbs');
    const listRes = await fetch(`${BASE_URL}/iris-couch/_all_dbs`, {
      headers: { cookie: cookie.split(';')[0] },
    });
    if (listRes.status !== 200) {
      const body = await listRes.text().catch(() => '');
      fail(`/_all_dbs returned HTTP ${listRes.status}`, body.slice(0, 500));
    }
    const body = await listRes.json().catch(() => null);
    if (!Array.isArray(body)) {
      fail('/_all_dbs did not return a JSON array', body);
    }
    log(`OK — ${body.length} databases visible`);

    log('SMOKE PASSED');
    process.exit(0);
  } finally {
    if (serverProc && !serverProc.killed) {
      log('stopping ng serve...');
      serverProc.kill('SIGTERM');
      await Promise.race([once(serverProc, 'exit'), sleep(3000)]);
      if (!serverProc.killed) serverProc.kill('SIGKILL');
    }
  }
}

main().catch((err) => fail('uncaught error', err));
