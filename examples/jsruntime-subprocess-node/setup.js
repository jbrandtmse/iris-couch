// jsruntime-subprocess-node setup helper (Node 18+).
//
// Shared helpers for the run.sh / run.ps1 wrappers:
// - fetchJson with basic-auth
// - config probe (confirms JSRUNTIME=Subprocess)
// - design-doc writer
//
// Runs directly: `node setup.js <command>` where command is one of:
//   probe        — exit 0 if JSRUNTIME=Subprocess, 1 otherwise
//   seed         — create DB, seed 5 docs, PUT design doc
//   query-map    — GET /_view/by-type?reduce=false, print rows
//   query-reduce — GET /_view/by-type (default: apply reduce), print rows
//   cleanup      — DELETE the test database

'use strict';

const IRISCOUCH_URL = process.env.IRISCOUCH_URL || 'http://localhost:52773/iris-couch';
const USER = process.env.IRISCOUCH_USER || '_system';
const PASS = process.env.IRISCOUCH_PASS || 'SYS';
const DB = 'jsruntime-subprocess-example';
const AUTH_HEADER = 'Basic ' + Buffer.from(`${USER}:${PASS}`).toString('base64');

// Story 13.3 dev-host note on couchjs-entry.js: this example MUST use the
// shipped Story 12.2 entry script at ../../documentation/couchjs/couchjs-entry.js
// — do NOT fork or re-implement. The subprocess plumbing is Epic 12's
// contribution; the example's contribution is orchestration around it.
const path = require('node:path');
const COUCHJS_ENTRY = path.resolve(__dirname, '..', '..', 'documentation', 'couchjs', 'couchjs-entry.js');

async function fetchJson(url, init = {}) {
  const res = await fetch(url, {
    ...init,
    headers: { Authorization: AUTH_HEADER, ...(init.headers || {}) },
  });
  let body = null;
  try { body = await res.json(); } catch (_) { /* non-json response */ }
  return { status: res.status, body };
}

async function probe() {
  // The Config endpoint is not exposed over HTTP; the best proxy we have is
  // to issue a view query and see whether we get a 501-None envelope. If
  // Subprocess is active, we'll get a real response; if None, we'll get the
  // canonical not_implemented envelope. Both cases are observable.
  await fetchJson(`${IRISCOUCH_URL}/${DB}`, { method: 'DELETE' });
  await fetchJson(`${IRISCOUCH_URL}/${DB}`, { method: 'PUT' });
  await fetchJson(`${IRISCOUCH_URL}/${DB}/_design/probe`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ views: { probe: { map: 'function(doc){emit(doc._id,1);}' } } }),
  });
  const res = await fetchJson(`${IRISCOUCH_URL}/${DB}/_design/probe/_view/probe`);
  await fetchJson(`${IRISCOUCH_URL}/${DB}`, { method: 'DELETE' });

  if (res.status === 501 || (res.body && res.body.error === 'not_implemented')) {
    console.error('FAIL: JSRUNTIME is set to None (or JSRUNTIMESUBPROCESSPATH not configured).');
    console.error('  Configure the Subprocess backend before running this example:');
    console.error('    Do ##class(IRISCouch.Config).Set("JSRUNTIME", "Subprocess")');
    console.error('    Do ##class(IRISCouch.Config).Set("JSRUNTIMESUBPROCESSPATH", "<path-to-node>")');
    console.error('  See documentation/getting-started.md § JavaScript Runtime Requirements.');
    console.error('  Entry script path (should exist): ' + COUCHJS_ENTRY);
    return false;
  }
  if (res.status === 200) {
    console.log('PROBE OK: JSRUNTIME=Subprocess and views execute successfully.');
    console.log('  couchjs entry script path: ' + COUCHJS_ENTRY);
    return true;
  }
  console.error(`FAIL: unexpected probe response ${res.status}: ${JSON.stringify(res.body)}`);
  return false;
}

async function seed() {
  await fetchJson(`${IRISCOUCH_URL}/${DB}`, { method: 'DELETE' });
  console.log('Step 1: PUT /' + DB);
  const createRes = await fetchJson(`${IRISCOUCH_URL}/${DB}`, { method: 'PUT' });
  console.log(JSON.stringify(createRes.body));

  console.log('Step 2: Seed 5 documents with a `type` field');
  for (let i = 1; i <= 5; i++) {
    const tp = (i % 2 === 0) ? 'even' : 'odd';
    await fetchJson(`${IRISCOUCH_URL}/${DB}/doc-${i}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ n: i, type: tp }),
    });
  }
  console.log('{"seeded":5}');

  console.log('Step 3: PUT _design/examples with map + built-in _count reduce');
  const designRes = await fetchJson(`${IRISCOUCH_URL}/${DB}/_design/examples`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      views: {
        'by-type': {
          map: 'function(doc){if(doc.type){emit(doc.type,1);}}',
          reduce: '_count',
        },
      },
    }),
  });
  console.log(JSON.stringify({ id: designRes.body.id, ok: designRes.body.ok }));
}

async function queryMap() {
  console.log('Step 4: GET /_view/by-type?reduce=false (map emissions from JS subprocess)');
  const res = await fetchJson(`${IRISCOUCH_URL}/${DB}/_design/examples/_view/by-type?reduce=false`);
  console.log(JSON.stringify(res.body));
}

async function queryReduce() {
  console.log('Step 5: GET /_view/by-type (default: _count reduce, ungrouped)');
  const res = await fetchJson(`${IRISCOUCH_URL}/${DB}/_design/examples/_view/by-type`);
  console.log(JSON.stringify(res.body));
}

async function cleanup() {
  console.log('Step 6: DELETE /' + DB);
  const res = await fetchJson(`${IRISCOUCH_URL}/${DB}`, { method: 'DELETE' });
  console.log(JSON.stringify(res.body));
}

async function main() {
  const cmd = process.argv[2];
  switch (cmd) {
    case 'probe':        process.exit((await probe()) ? 0 : 1);
    case 'seed':         return seed();
    case 'query-map':    return queryMap();
    case 'query-reduce': return queryReduce();
    case 'cleanup':      return cleanup();
    default:
      console.error(`Usage: node setup.js <probe|seed|query-map|query-reduce|cleanup>`);
      process.exit(2);
  }
}

main().catch((err) => { console.error('FAIL: ' + err.message); process.exit(1); });
