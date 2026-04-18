# attachment-upload

> **Production warning.** This example uses the default IRIS `_system` / `SYS`
> credentials. **Before running IRISCouch in production**, rotate the IRIS
> admin password, create a dedicated IRISCouch user via `/_users/`, assign a
> non-admin role, and (for attachment-heavy workloads) consider using cookie
> or JWT auth over basic — basic-auth headers are re-sent with every attachment
> GET, which is measurable on large binaries.

Binary attachment round-trip with SHA-256 integrity verification. Uploads a
small PNG fixture to an IRISCouch document, fetches it back, compares the
hash. If the byte content drifts, the script fails with the hash mismatch
visible.

## What it demonstrates

- `PUT /{db}/{docid}` — create a parent document (attachments live on a doc)
- `PUT /{db}/{docid}/{attname}?rev=<prev>` — standalone attachment upload
  (most memory-efficient path; the server streams into `%Stream.GlobalBinary`
  without buffering the whole payload)
- `GET /{db}/{docid}/{attname}` — raw-byte download, correct Content-Type
- `GET /{db}/{docid}` — confirms the `_attachments` stub (length,
  content_type, `stub:true`) attached to the winning revision
- SHA-256 byte-equality assertion against the source fixture

## Prerequisites

- **Node.js 18+** — uses built-in `fetch` and `crypto`; no `npm install`
  step required
- IRIS 2024.1+ with IRISCouch at `http://localhost:52773/iris-couch/`
- Default IRIS credentials (or override via env vars)

## How to run

```bash
cd examples/attachment-upload
node run.mjs
```

Environment overrides:

```bash
IRISCOUCH_URL=... IRISCOUCH_USER=... IRISCOUCH_PASS=... node run.mjs
```

## Expected output

See [`expected-output.txt`](expected-output.txt). Tolerance placeholders:

- `<path>` — absolute path to the fixture, varies per checkout location
- `1-<hash>`, `2-<hash>` — rev hashes on the parent document (pre- and
  post-attachment); unique per run due to the document bodies being hashed
- The **SHA-256 of the downloaded attachment matches the fixture** — this is
  the deterministic, must-match value: `b8534a5c61126b1b077ef7889860820b0b2bf200ffa79aeaaea780ae8076ca88`

## Known deviation: attachment buffering

Per [deviations.md § Attachments](../../documentation/deviations.md), the CSP
Gateway in front of IRIS buffers responses up to its configured threshold
(default ~256 KB), which affects very-large attachment downloads — they
stream correctly from IRIS but buffer at the gateway before being chunked
back to the client. The 987-byte fixture is well under that threshold so
this example isn't affected, but production workflows uploading multi-MB
attachments should read the deviations entry.

## Fixture

[`fixtures/test.png`](fixtures/test.png) is a 48×48 RGB PNG (987 bytes)
generated deterministically from a seeded LCG — not copyrighted artwork, no
licensing concerns. Regenerate with any PNG encoder if you need a different
fixture; update the expected SHA-256 in `expected-output.txt` to match.

## Cross-references

- [Compatibility matrix § Attachments](../../documentation/compatibility-matrix.md#attachments-detail)
  — all attachment rows marked `supported` (standalone, inline, multipart,
  Range requests, `atts_since`, `attachments=true`)
- [Deviations § Attachments](../../documentation/deviations.md) — attachment
  buffering / encoding behaviour specifics
- Epic 5 stories: [5.1 Standalone](../../_bmad-output/implementation-artifacts/5-1-standalone-attachment-upload-and-download.md),
  [5.2 Inline/Multipart](../../_bmad-output/implementation-artifacts/5-2-inline-and-multipart-attachment-upload.md),
  [5.3 Retrieval options](../../_bmad-output/implementation-artifacts/5-3-attachment-retrieval-options-and-multipart-response.md)
- CouchDB source `sources/couchdb/src/docs/src/api/document/attachments.rst`

## Troubleshooting

- **`Content-Type: application/octet-stream` instead of `image/png`** —
  check the `Content-Type` header on the upload request; IRISCouch stores
  whatever the client sent.
- **SHA mismatch** — would indicate attachment corruption; file an issue
  immediately, this is an NFR-R1 correctness class failure. Include the
  IRIS version and the `^IRISCouch.Attachments` global dump for the
  affected doc.
- **`413 Request Entity Too Large`** — CSP Gateway request-body limit.
  Increase via the IRIS Management Portal → CSP Gateway settings →
  Default parameters → `Max Request Body Size`.
