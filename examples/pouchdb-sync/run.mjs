// pouchdb-sync example: bidirectional sync between an in-memory PouchDB
// and a remote IRISCouch database.
//
// Demonstrates the canonical browser/Node PouchDB integration pattern:
// put docs locally, sync() to push them up, write one doc directly to
// IRISCouch via fetch, sync() again to pull it down. Observable convergence
// is the point.
//
// Prereqs: Node 18+, pouchdb installed (see README.md § Prerequisites).
//
// IRISCouch interop note (Story 13.3 dev-host finding, 2026-04-18):
// IRISCouch's Router UrlMap does not register routes with a trailing slash on
// the database name, so `PUT /{db}/` and `GET /{db}/` both return 404. PouchDB
// by default calls `PUT /{db}/` when constructing a new remote DB handle (the
// auto-create probe). Passing `{ skip_setup: true }` bypasses the auto-create,
// which is what this example does — we create the database explicitly via the
// no-trailing-slash URL first, then construct the PouchDB handle with
// skip_setup. Tracked in deferred-work.md § Story 13.3 with severity HIGH;
// the fix is a one-line Router.cls addition and will be done in a backend
// cleanup story.

import PouchDB from 'pouchdb';

const IRISCOUCH_URL = process.env.IRISCOUCH_URL ?? 'http://localhost:52773/iris-couch';
const USER = process.env.IRISCOUCH_USER ?? '_system';
const PASS = process.env.IRISCOUCH_PASS ?? 'SYS';
const DB = 'pouchdb-sync-example';

const AUTH_HEADER = 'Basic ' + Buffer.from(`${USER}:${PASS}`).toString('base64');
const LOCAL_DB_PATH = `.local-pouchdb-${DB}`;

async function fetchJson(url, init = {}) {
  const res = await fetch(url, {
    ...init,
    headers: { Authorization: AUTH_HEADER, ...(init.headers ?? {}) },
  });
  return { status: res.status, body: await res.json().catch(() => null) };
}

async function ensureCleanSlate() {
  // Drop the remote DB (ignore 404 on first run) and recreate.
  await fetchJson(`${IRISCOUCH_URL}/${DB}`, { method: 'DELETE' });
  const putRes = await fetchJson(`${IRISCOUCH_URL}/${DB}`, { method: 'PUT' });
  if (putRes.status !== 201 && putRes.status !== 412) {
    throw new Error(`remote PUT /${DB} failed with ${putRes.status}: ${JSON.stringify(putRes.body)}`);
  }
  // Drop the local leveldown database from any prior failed run.
  try {
    await new PouchDB(LOCAL_DB_PATH).destroy();
  } catch (_) {
    /* first run: no local state yet */
  }
}

async function main() {
  await ensureCleanSlate();

  // skip_setup: true tells PouchDB not to probe/create the remote on handle
  // construction — we already created it via the no-trailing-slash URL above.
  const remote = new PouchDB(`${IRISCOUCH_URL}/${DB}`, {
    auth: { username: USER, password: PASS },
    skip_setup: true,
  });
  const local = new PouchDB(LOCAL_DB_PATH);

  console.log('Step 1: PUT 5 documents into the local PouchDB');
  const localSeed = [];
  for (let i = 1; i <= 5; i++) {
    const id = `local-${i.toString().padStart(3, '0')}`;
    const res = await local.put({ _id: id, source: 'local', n: i });
    localSeed.push(res.id);
  }
  console.log(JSON.stringify({ seeded: localSeed.length, ids: localSeed }));

  console.log('Step 2: sync() local -> remote');
  const syncResult1 = await local.sync(remote);
  console.log(JSON.stringify({
    push_docs_written: syncResult1.push?.docs_written ?? 0,
    pull_docs_written: syncResult1.pull?.docs_written ?? 0,
  }));

  console.log('Step 3: GET remote /_all_docs (expect 5 from the push)');
  const allDocs1 = await fetchJson(`${IRISCOUCH_URL}/${DB}/_all_docs`);
  console.log(JSON.stringify({ total_rows: allDocs1.body.total_rows, row_ids: allDocs1.body.rows.map((r) => r.id) }));

  console.log('Step 4: Write one doc directly to IRISCouch via fetch (remote-origin)');
  const directRes = await fetchJson(`${IRISCOUCH_URL}/${DB}/remote-001`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ source: 'remote', note: 'written directly via fetch' }),
  });
  console.log(JSON.stringify({ id: directRes.body.id, ok: directRes.body.ok }));

  console.log('Step 5: sync() again (pull the remote-origin doc into local PouchDB)');
  const syncResult2 = await local.sync(remote);
  console.log(JSON.stringify({
    push_docs_written: syncResult2.push?.docs_written ?? 0,
    pull_docs_written: syncResult2.pull?.docs_written ?? 0,
  }));

  console.log('Step 6: Local PouchDB now has 6 docs (5 local + 1 pulled)');
  const localAllDocs = await local.allDocs();
  console.log(JSON.stringify({ total_rows: localAllDocs.total_rows, row_ids: localAllDocs.rows.map((r) => r.id) }));

  console.log('Step 7: Cleanup (drop remote and local)');
  await fetchJson(`${IRISCOUCH_URL}/${DB}`, { method: 'DELETE' });
  await local.destroy();
  console.log('{"cleanup":"ok"}');
}

main().catch((err) => {
  console.error(`FAIL: ${err.message}`);
  process.exit(1);
});
