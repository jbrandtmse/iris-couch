// attachment-upload example: PUT a binary attachment, GET it back,
// assert the bytes round-trip unchanged via SHA-256.
//
// Demonstrates the standalone-attachment endpoint — the workhorse path for
// CouchDB binary payloads (image uploads, PDF storage, etc.). Uses Node 18+
// built-in fetch so there are no external dependencies beyond Node itself.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const IRISCOUCH_URL = process.env.IRISCOUCH_URL ?? 'http://localhost:52773/iris-couch';
const USER = process.env.IRISCOUCH_USER ?? '_system';
const PASS = process.env.IRISCOUCH_PASS ?? 'SYS';
const DB = 'attachment-upload-example';
const FIXTURE = path.join(__dirname, 'fixtures', 'test.png');
const AUTH_HEADER = 'Basic ' + Buffer.from(`${USER}:${PASS}`).toString('base64');

function sha256(buf) {
  return createHash('sha256').update(buf).digest('hex');
}

async function fetchJson(url, init = {}) {
  const res = await fetch(url, {
    ...init,
    headers: { Authorization: AUTH_HEADER, ...(init.headers ?? {}) },
  });
  return { status: res.status, body: await res.json().catch(() => null), headers: res.headers };
}

async function main() {
  // Load fixture + source hash up-front so the comparison is against a known
  // value, not something the script also produced on the fly.
  const fixtureBytes = fs.readFileSync(FIXTURE);
  const sourceHash = sha256(fixtureBytes);
  console.log(`Fixture: ${FIXTURE} (${fixtureBytes.length} bytes, SHA-256 ${sourceHash})`);

  // Clean slate
  await fetchJson(`${IRISCOUCH_URL}/${DB}`, { method: 'DELETE' });

  console.log(`Step 1: PUT /${DB}`);
  const createRes = await fetchJson(`${IRISCOUCH_URL}/${DB}`, { method: 'PUT' });
  console.log(JSON.stringify(createRes.body));

  console.log(`Step 2: PUT /${DB}/image-doc (parent document)`);
  const docRes = await fetchJson(`${IRISCOUCH_URL}/${DB}/image-doc`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ title: 'noise PNG', format: 'image/png' }),
  });
  console.log(JSON.stringify({ id: docRes.body.id, ok: docRes.body.ok }));
  const rev1 = docRes.body.rev;

  console.log(`Step 3: PUT /${DB}/image-doc/test.png?rev=${rev1} (attach the PNG)`);
  const attachRes = await fetch(
    `${IRISCOUCH_URL}/${DB}/image-doc/test.png?rev=${rev1}`,
    {
      method: 'PUT',
      headers: { Authorization: AUTH_HEADER, 'Content-Type': 'image/png' },
      body: fixtureBytes,
    },
  );
  const attachBody = await attachRes.json();
  console.log(JSON.stringify({ id: attachBody.id, ok: attachBody.ok }));
  const rev2 = attachBody.rev;

  console.log(`Step 4: GET /${DB}/image-doc/test.png (download the attachment)`);
  const getRes = await fetch(`${IRISCOUCH_URL}/${DB}/image-doc/test.png`, {
    headers: { Authorization: AUTH_HEADER },
  });
  const downloadedBytes = Buffer.from(await getRes.arrayBuffer());
  const downloadedHash = sha256(downloadedBytes);
  console.log(JSON.stringify({
    status: getRes.status,
    content_type: getRes.headers.get('content-type'),
    content_length: downloadedBytes.length,
    sha256: downloadedHash,
  }));

  console.log(`Step 5: Assert SHA-256 round-trip`);
  if (downloadedHash !== sourceHash) {
    console.log(JSON.stringify({ round_trip: 'FAIL', source_sha256: sourceHash, downloaded_sha256: downloadedHash }));
    process.exit(1);
  }
  console.log(JSON.stringify({ round_trip: 'OK', bytes: downloadedBytes.length }));

  console.log(`Step 6: GET /${DB}/image-doc (confirm rev bumped + attachment stub)`);
  const docGet = await fetchJson(`${IRISCOUCH_URL}/${DB}/image-doc`);
  const attachStub = docGet.body._attachments?.['test.png'];
  console.log(JSON.stringify({
    _rev: docGet.body._rev,
    has_attachment: Boolean(attachStub),
    content_type: attachStub?.content_type,
    length: attachStub?.length,
    stub: attachStub?.stub,
  }));

  console.log(`Step 7: DELETE /${DB}`);
  const delRes = await fetchJson(`${IRISCOUCH_URL}/${DB}`, { method: 'DELETE' });
  console.log(JSON.stringify(delRes.body));
}

main().catch((err) => {
  console.error(`FAIL: ${err.message}`);
  process.exit(1);
});
