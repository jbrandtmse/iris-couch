# Getting Started with IRISCouch

> From a fresh IRIS instance to a round-trip PouchDB replication in under one
> hour. No Python required. Node.js only if you want JavaScript-backed views.

This guide walks a new adopter from `zpm "install iris-couch"` through a bidirectional
PouchDB sync against a running IRISCouch server. Nine short sections, roughly
forty minutes of copy-paste. Every shell prompt in the guide is runnable against
the live IRISCouch dev instance as of 2026-04-18; if something does not match
what you see on your host, jump to the [Troubleshooting](#troubleshooting)
sidebar at the end.

## Table of contents

1. [Prerequisites](#prerequisites)
2. [Install](#install)
3. [Verify the server is running](#verify-the-server-is-running)
4. [Deployment topology options](#deployment-topology-options)
5. [Create a database](#create-a-database)
6. [Write a document](#write-a-document)
7. [Set up PouchDB sync](#set-up-pouchdb-sync)
8. [JavaScript Runtime Requirements](#javascript-runtime-requirements)
9. [What's next](#whats-next)
10. [Troubleshooting](#troubleshooting)

---

## Prerequisites

| Item | Requirement | Notes |
|------|-------------|-------|
| IRIS | 2024.1+ (Community or full) | Community Edition is sufficient for α/β evaluation. |
| Namespace | An IRIS namespace you can install into (e.g., `USER`) | The installer creates the web application, the `IRISCouch_Admin` role, and audit events against this namespace. |
| Operator privileges | `_SYSTEM` or equivalent admin on the target IRIS | Needed to create the CSP web application and register audit events in `%SYS`. |
| Network | Outbound access to the ZPM registry (`pm.community.intersystems.com`) | Only required for `zpm "install"`. Manual-import fallback is documented in the main [README](../README.md#option-2-manual-import). |
| Node.js | **Optional**, 18+ | Only required if you want JavaScript-backed views, `validate_doc_update` hooks, or custom `_changes` filters. Install via `winget install OpenJS.NodeJS.LTS` (Windows), `apt install nodejs` (Debian/Ubuntu), or `brew install node` (macOS). |
| Python | **Not required**, ever | IRISCouch compiles and runs on Python-less IRIS images by explicit invariant (PRD [NFR-M9](../_bmad-output/planning-artifacts/prd.md)). See [JavaScript Runtime Requirements](#javascript-runtime-requirements). |

**Note on Node.js.** IRISCouch never installs, bundles, or auto-installs Node.
The `Subprocess` JSRuntime backend calls a Node interpreter that the operator
has installed separately and pointed at via configuration. If you skip Node
(the common case), the `None` default backend ships and every JS-required
endpoint returns `501 not_implemented` with a pointer envelope. Document
CRUD, attachments, `_changes`, Mango, replication, and the admin UI all work
unchanged without Node.

---

## Install

### Option A — ZPM (recommended)

```objectscript
; In the IRIS terminal, from the target namespace (e.g., USER):
zpm "install iris-couch"
```

Expected console output (truncated to the key lines):

```
[USER|iris-couch]     Reload START (/opt/.../iris-couch/)
[USER|iris-couch]     Module object refreshed.
[USER|iris-couch]     Validate START
[USER|iris-couch]     Validate SUCCESS
[USER|iris-couch]     Compile START
[USER|iris-couch]     Compile SUCCESS
[USER|iris-couch]     Activate START
[USER|iris-couch]     Configure START
[USER|iris-couch]     Configure SUCCESS
[USER|iris-couch]     Activate SUCCESS
[USER|iris-couch] iris-couch MODULE INSTALLED
```

The installer (see `IRISCouch.Installer.Install`) does four things in one
transaction:

1. Creates the CSP web application (default mount path `/iris-couch/`)
2. Registers audit event types in `%SYS` via `Security.Events.Create`
3. Creates the `IRISCouch_Admin` role and grants it to the installing user + `_SYSTEM`
4. Sets default config values for `JSRUNTIME`, `JSRUNTIMESUBPROCESSPATH`, etc.

One-line verification that the module registered correctly:

```bash
curl -s http://localhost:52773/iris-couch/ | head -1
```

You should see a JSON payload beginning `{"couchdb":"Welcome",...`. Full
verification is the next section.

### Option B — Manual ObjectScript import

If ZPM is not available on your IRIS instance, see
[README → Option 2: Manual Import](../README.md#option-2-manual-import).
The procedure is: clone the repo, `$System.OBJ.ImportDir("/path/to/src/IRISCouch/", , "ck", , 1)`,
then `Do ##class(IRISCouch.Installer).Install($Namespace, "/iris-couch/")`.

---

## Verify the server is running

Three short probes confirm the install is live and the auth layer is
functioning. Output below is verbatim from the dev-host IRIS 2024.1
instance running this repository on 2026-04-18, mounted at
`/iris-couch/` on IRIS's default CSP port `52773`.

```
$ curl -u _system:SYS -i http://localhost:52773/iris-couch/
HTTP/1.1 200 OK
Date: Sat, 18 Apr 2026 09:04:49 GMT
Server: Apache
CACHE-CONTROL: no-cache
EXPIRES: Thu, 29 Oct 1998 17:04:19 GMT
PRAGMA: no-cache
CONTENT-LENGTH: 69
Content-Type: application/json

{"couchdb":"Welcome","version":"0.1.0","vendor":{"name":"IRISCouch"}}

$ curl -u _system:SYS -i http://localhost:52773/iris-couch/_session
HTTP/1.1 200 OK
Date: Sat, 18 Apr 2026 09:04:50 GMT
Server: Apache
CACHE-CONTROL: no-cache
EXPIRES: Thu, 29 Oct 1998 17:04:19 GMT
PRAGMA: no-cache
CONTENT-LENGTH: 129
Content-Type: application/json

{"ok":true,"userCtx":{"name":"_system","roles":["%All","%IRISCouch_Admin","IRISCouch_Admin"]},"info":{"authenticated":"default"}}

$ curl -u _system:SYS -i http://localhost:52773/iris-couch/_all_dbs
HTTP/1.1 200 OK
Date: Sat, 18 Apr 2026 09:04:50 GMT
Server: Apache
CACHE-CONTROL: no-cache
EXPIRES: Thu, 29 Oct 1998 17:04:19 GMT
PRAGMA: no-cache
CONTENT-LENGTH: 15
Content-Type: application/json

["_replicator"]
```

### What each response tells you

- **`/`** — The `couchdb:"Welcome"` field is the CouchDB identity handshake;
  PouchDB, `nano`, and the Apache CouchDB replicator all dispatch on this
  field before they send any other request. The `vendor.name` distinguishes
  IRISCouch from stock CouchDB for clients that log it (most do not). The
  `version` is the IRISCouch release version, currently `0.1.0` during α
  development (will track CouchDB 3.x compatibility anchors at β).
- **`/_session`** — `userCtx.name` is the authenticated IRIS user; `roles`
  includes both IRIS system roles (`%All`) and IRISCouch roles
  (`IRISCouch_Admin`, internally prefixed to `%IRISCouch_Admin`). The
  `authenticated:"default"` field reports which auth mechanism the request
  used — `default` here means HTTP Basic with the IRIS built-in credential
  store, other possibilities being `cookie` (session auth), `jwt`, and
  `proxy`. Cookie / JWT / proxy auth is documented under
  [Epic 7](../_bmad-output/planning-artifacts/prd.md).
- **`/_all_dbs`** — Lists the databases visible to the authenticated user.
  On a fresh install this contains only `_replicator` (the built-in replication
  job database, always present). `_users` appears the first time any user
  authenticates via cookie session; databases you create via `PUT` appear here.

If any of these three probes returns a non-200 status, see
[Troubleshooting](#troubleshooting) — do not skip ahead to PouchDB sync until
the identity handshake and the session endpoint both return 200.

---

## Deployment topology options

IRISCouch mounts at a configurable path on the IRIS CSP gateway — default
`/iris-couch/` — not at `/` the way stock Apache CouchDB does. This matters
for clients: some CouchDB CLI tools hard-code paths like `/_session` and
`/_uuids` without a configurable prefix, and those tools cannot speak to
IRISCouch unless a reverse proxy rewrites `/` → `/iris-couch/` on the wire.

You have two choices. Option A is recommended; Option B is fine for
PouchDB-only integrations.

### Option A — Reverse proxy (recommended)

A tiny nginx or Apache config in front of IRIS rewrites the root path so
clients see bare CouchDB paths (`/_session`, `/_uuids`, `/{db}/...`). This
unlocks Fauxton-equivalent tooling, older CouchDB admin scripts, and any
client that can't be configured with a URL prefix.

#### nginx

Minimum viable config (nginx 1.18+). Save as `/etc/nginx/sites-available/iris-couch.conf`
and enable with `ln -s` into `sites-enabled`:

```nginx
server {
    listen 5984;
    server_name _;

    # Forward the CouchDB root mount onto the IRISCouch mount path.
    # Clients see bare /_session, /_uuids, /mydb/... etc.
    location / {
        proxy_pass http://127.0.0.1:52773/iris-couch/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Long-poll changes feeds need an extended read timeout.
        proxy_read_timeout 120s;
        proxy_buffering off;
    }
}
```

Reload nginx (`nginx -s reload`) and probe:

```bash
curl -u _system:SYS http://localhost:5984/
# {"couchdb":"Welcome","version":"0.1.0","vendor":{"name":"IRISCouch"}}
```

The CouchDB default port is 5984; binding IRISCouch to that port through
the proxy lets existing client configs work unchanged. Bind to any other
port if 5984 is already in use.

#### Apache (mod_proxy_http)

Enable the required modules once:

```bash
a2enmod proxy proxy_http rewrite
```

Virtual host config (`/etc/apache2/sites-available/iris-couch.conf`):

```apache
<VirtualHost *:5984>
    ServerName iriscouch.local

    # Strip nothing from the path; just forward everything under / to /iris-couch/.
    ProxyPreserveHost On
    ProxyPass        / http://127.0.0.1:52773/iris-couch/
    ProxyPassReverse / http://127.0.0.1:52773/iris-couch/

    # Long-poll changes feeds.
    ProxyTimeout 120

    <Proxy *>
        Require all granted
    </Proxy>
</VirtualHost>
```

Reload Apache (`systemctl reload apache2`). Same verification curl as above.

### Option B — Direct mount (prefix every URL)

If the reverse proxy is impractical (e.g., behind an InterSystems API Manager
gateway that already does other routing), speak to IRISCouch directly at its
native mount path:

```bash
# All client URLs include /iris-couch/ as a prefix.
curl -u _system:SYS http://localhost:52773/iris-couch/_session
curl -u _system:SYS http://localhost:52773/iris-couch/mydb/_all_docs
```

**Client compatibility caveats under Option B:**

| Client | Prefix support | Notes |
|--------|---------------|-------|
| PouchDB | ✅ Accepts any URL | `new PouchDB('http://host/iris-couch/mydb')` just works. |
| Apache CouchDB replicator | ✅ Accepts any URL | Source / target URLs in `_replicator` docs are literal; prefix is transparent. |
| `nano` (Node.js client) | ✅ Accepts any URL | `require('nano')('http://host/iris-couch')` works. |
| Fauxton (built-in) | ✅ Works at `/iris-couch/_utils/` | IRISCouch serves its own admin UI at this path (Story 11.5); no separate Fauxton install needed. |
| Older CouchDB CLI scripts with hard-coded paths | ⚠️ Need modification | Scripts that curl `/_uuids` or `/_session` without a base-URL variable must be rewritten. Reverse proxy (Option A) is easier than patching every script. |
| `curl` + ad-hoc bash | ✅ Works | Just write the full URL including `/iris-couch/`. |

Admin UI is accessible both ways: with the reverse proxy, browse to
`http://localhost:5984/_utils/`; under direct mount, browse to
`http://localhost:52773/iris-couch/_utils/`. Sign in with your IRIS
credentials; the UI requires the `IRISCouch_Admin` role, which the
installer grants automatically to the installing user.

---

## Create a database

With the server running, create a database named `mydb`:

```bash
curl -X PUT -u _system:SYS http://localhost:52773/iris-couch/mydb
```

Expected response (`201 Created`):

```json
{"ok":true}
```

Double-check it exists:

```bash
curl -u _system:SYS http://localhost:52773/iris-couch/_all_dbs
# ["_replicator","mydb"]

curl -u _system:SYS http://localhost:52773/iris-couch/mydb
# {"db_name":"mydb","doc_count":0,"doc_del_count":0,"update_seq":0,"purge_seq":0,
#  "compact_running":false,"sizes":{"active":0,"external":0,"file":0},
#  "props":{},"cluster":{"q":1,"n":1,"w":1,"r":1},"instance_start_time":"0"}
```

**GUI equivalent.** Open `http://localhost:52773/iris-couch/_utils/` (or
`http://localhost:5984/_utils/` under the reverse proxy). Sign in, click
the **Create Database** button in the database list view, enter `mydb`,
confirm. Either approach produces the same database.

---

## Write a document

Create a single document with a POST:

```bash
curl -X POST -u _system:SYS \
     -H "Content-Type: application/json" \
     -d '{"name":"hello","ts":"2026-04-18T09:30:00Z"}' \
     http://localhost:52773/iris-couch/mydb
```

Expected response (`201 Created`):

```json
{"ok":true,"id":"8f3c0a1b4d6e5f7a9c2d1e3b4f5a6c7d","rev":"1-a5d0f1..."}
```

The `id` is a server-generated UUID (you may supply your own by using
`PUT /mydb/<id>` instead of `POST /mydb`). The `rev` is a CouchDB MVCC
revision token of the form `<N>-<hash>` — the `N` prefix is the depth in
the revision tree, the `<hash>` is a deterministic digest of the document
body. You will need the `rev` for any subsequent update or delete of this
document.

Read it back:

```bash
curl -u _system:SYS http://localhost:52773/iris-couch/mydb/<id-from-previous-response>
```

Or read all documents in the database:

```bash
curl -u _system:SYS 'http://localhost:52773/iris-couch/mydb/_all_docs?include_docs=true'
```

Expected `_all_docs` response shape (truncated):

```json
{
  "offset": 0,
  "total_rows": 1,
  "rows": [{
    "id": "8f3c0a1b...", "key": "8f3c0a1b...",
    "value": {"rev": "1-a5d0f1..."},
    "doc": {"_id": "8f3c0a1b...", "_rev": "1-a5d0f1...", "name": "hello", "ts": "..."}
  }]
}
```

That's the backbone of the CouchDB document API. Everything else — updates,
deletes, conflicts, attachments, bulk operations — follows the same pattern
and is documented in the [compatibility matrix](compatibility-matrix.md).

---

## Set up PouchDB sync

This is where the guide earns its name. One `db.sync()` call sets up a
live bidirectional replication between a local browser or Node.js
PouchDB database and the IRISCouch `mydb` you just created. Any write
to either side appears on the other within a few seconds.

### Browser snippet

Save as `sync.html`:

```html
<!DOCTYPE html>
<html>
<head>
  <title>IRISCouch + PouchDB demo</title>
  <script src="https://cdn.jsdelivr.net/npm/pouchdb@9.0.0/dist/pouchdb.min.js"></script>
</head>
<body>
  <h1>IRISCouch sync demo</h1>
  <pre id="log"></pre>
  <script>
    const log = (msg) => {
      document.getElementById('log').textContent += msg + '\n';
    };

    const local = new PouchDB('mydb-local');
    const remote = new PouchDB('http://localhost:52773/iris-couch/mydb', {
      auth: { username: '_system', password: 'SYS' }
    });

    local.sync(remote, { live: true, retry: true })
      .on('change',   (info) => log('change: '   + JSON.stringify(info)))
      .on('paused',   (err)  => log('paused'))
      .on('active',   ()     => log('active'))
      .on('denied',   (err)  => log('denied: '   + err))
      .on('complete', (info) => log('complete'))
      .on('error',    (err)  => log('error: '    + err));

    // Write a test document every few seconds to demonstrate push.
    setInterval(async () => {
      await local.post({ source: 'browser', at: new Date().toISOString() });
    }, 5000);
  </script>
</body>
</html>
```

Open the file in a browser. You should see `active` → `paused` flipping in
the log as PouchDB catches up on the initial sync, then new `change` entries
as each 5-second timer tick posts a document. `curl` `/_all_docs` server-side
to confirm the documents arrive.

**Note on CORS.** Browsers enforce CORS on cross-origin AJAX. If you serve
`sync.html` from a different origin than IRIS (for example, from `file://`
or a different port), the browser will block the request. Run `sync.html`
from the same origin as IRISCouch (e.g., drop it into the IRISCouch admin
UI's static asset directory), or enable CORS on the CSP gateway — CORS
configuration on IRIS is operator-configured and out of scope for this
guide.

### Node.js snippet

Save as `sync.js` and `npm install pouchdb`:

```js
const PouchDB = require('pouchdb');

const local = new PouchDB('mydb-local');
const remote = new PouchDB('http://localhost:52773/iris-couch/mydb', {
  auth: { username: '_system', password: 'SYS' }
});

local.sync(remote, { live: true, retry: true })
  .on('change',   (info) => console.log('change:', info))
  .on('paused',   ()     => console.log('paused'))
  .on('active',   ()     => console.log('active'))
  .on('denied',   (err)  => console.error('denied:', err))
  .on('complete', (info) => console.log('complete:', info))
  .on('error',    (err)  => console.error('error:', err));

// Push a document every 5 seconds.
setInterval(async () => {
  const result = await local.post({ source: 'node', at: new Date().toISOString() });
  console.log('posted:', result.id);
}, 5000);
```

Run `node sync.js`. Same semantics as the browser snippet; no CORS concerns
because Node is not a browser.

**Authentication note.** The `auth: { username, password }` option sends
HTTP Basic auth on every request. For production, switch to cookie session
auth (`POST /_session` with form-encoded credentials, save the `AuthSession`
cookie, send on subsequent requests) or JWT (signed token in the
`Authorization: Bearer ...` header). Both are documented in the
compatibility matrix under `/_session` and the PRD Authentication section.
Never embed `_system`/`SYS` in shipped client code.

### Confirming the round-trip

In a third terminal, curl `_all_docs` on IRISCouch every few seconds:

```bash
watch -n 2 'curl -s -u _system:SYS http://localhost:52773/iris-couch/mydb/_all_docs | head -c 200'
```

`total_rows` should increment as the PouchDB browser/Node timer ticks push
documents in.

---

## JavaScript Runtime Requirements

IRISCouch executes JavaScript-dependent CouchDB features (map/reduce views,
`validate_doc_update` hooks, custom `_changes` filters, eventually show/list/update)
through a pluggable runtime abstraction. Three backends exist; two ship at α/β.

**PRD [NFR-M9](../_bmad-output/planning-artifacts/prd.md) (verbatim):**

> **NFR-M9 — Python-Optional Compilation.** IRISCouch ObjectScript classes
> MUST compile and the IRISCouch ZPM package MUST install on any IRIS 2024.1+
> instance regardless of embedded Python availability. Shipped `.cls` files
> MUST NOT contain `[Language = python]` methods; Python integration (when /
> if present) MUST ship as ZPM `<FileCopy>` resources with `irispip`
> documented as an operator-executed prerequisite, never invoked from a ZPM
> install hook.

### Configuration keys

Two config keys control the runtime:

| Key | Default | Purpose |
|-----|---------|---------|
| `JSRUNTIME` | `None` | Active backend: `None`, `Subprocess`, or `Python` (deferred). |
| `JSRUNTIMESUBPROCESSPATH` | `""` | Full path to the JS interpreter (Node / Bun / Deno) when `JSRUNTIME=Subprocess`. |

Read and write from the IRIS terminal:

```objectscript
Write ##class(IRISCouch.Config).Get("JSRUNTIME")
Do ##class(IRISCouch.Config).Set("JSRUNTIME", "Subprocess")
Do ##class(IRISCouch.Config).Set("JSRUNTIMESUBPROCESSPATH", "C:\Program Files\nodejs\node.exe")
```

(Linux/macOS:
`Do ##class(IRISCouch.Config).Set("JSRUNTIMESUBPROCESSPATH", "/usr/bin/node")`.)

### Backend states at α/β

- **`None` (default, shipped).** Every JS-required endpoint returns
  `501 not_implemented` with a pointer envelope naming `JSRUNTIME`. Document
  CRUD, attachments, `_changes` with built-in filters, Mango queries,
  replication, and the admin UI all work unchanged. Design documents can
  still be stored, read, replicated, and deleted — the write path simply
  never evaluates their JS.
- **`Subprocess` (shipped α/β).** Spawns a Node / Bun / Deno subprocess
  per-query (persistent pool tracked as Story 12.5b) to execute map/reduce,
  validate, and filter functions. Incremental indexing (Story 12.5) makes
  the hot path ~O(1) per key on read. Requires Node 18+ (or Bun 1+, Deno 1.40+)
  installed separately by the operator; the path is configured via
  `JSRUNTIMESUBPROCESSPATH`. **IRISCouch never auto-installs Node.**
- **`Python` — NOT SHIPPED.** Story 12.4 was deferred on 2026-04-17 (commit
  `4fe1034`) when the dev host's IRIS build was found to have no embedded
  Python available. The deferral is **total** — the Python backend is not
  "supported with caveat", it is not running, and it does not ship in α or
  β. See the [compatibility matrix JSRuntime rows](compatibility-matrix.md#design-documents--views)
  and the [deferred-work.md Story 12.4 resumption block](../_bmad-output/implementation-artifacts/deferred-work.md#deferred-for-story-124-resumption-added-2026-04-18-story-130)
  for resumption prerequisites.

### "What breaks without Node"

When `JSRUNTIME=None` (default), the following endpoints return `501`:

- `GET|POST /{db}/_design/{ddoc}/_view/{view}` — user-supplied map/reduce
- Writes to databases whose design docs define `validate_doc_update`
- `GET|POST /{db}/_changes?filter={ddoc}/{filtername}` (custom filters only)

Everything else — including the built-in filters `_doc_ids`, `_selector`,
and `_design`, and the built-in reduce functions `_sum`, `_count`, `_stats`,
`_approx_count_distinct` (native ObjectScript, bypasses the subprocess) —
works without any JS runtime.

### "What is permanently out of scope without Python"

Nothing. The `Subprocess` backend supports every JS-required capability
the Python backend would. Python is a **delivery vehicle for JS execution
on hosts where Node is impractical** (e.g., restricted-firewall enterprises
that can `irispip install quickjs` but cannot `apt install nodejs`). It is
not a feature gate.

### Reference reads

- [`documentation/js-runtime.md`](js-runtime.md) — detailed backend semantics,
  entry script, sandbox flags, timeout enforcement, known limitations
- [`.claude/rules/iris-objectscript-basics.md` — Python Integration Distribution Rules](../.claude/rules/iris-objectscript-basics.md)
- [Compatibility matrix JSRuntime rows](compatibility-matrix.md#design-documents--views)
- [PRD NFR-M9 (line 2563)](../_bmad-output/planning-artifacts/prd.md)
- [Epic 12 retrospective](../_bmad-output/implementation-artifacts/epic-12-retro-2026-04-17.md)
- [`deferred-work.md` → Deferred for Story 12.4 resumption](../_bmad-output/implementation-artifacts/deferred-work.md)

---

## What's next

- **[Compatibility matrix](compatibility-matrix.md)** — every CouchDB 3.x
  HTTP endpoint, status (supported / with caveat / 501 / out of scope),
  verification method. If you're evaluating IRISCouch against a specific
  workload, read this next.
- **Admin UI** — `http://localhost:52773/iris-couch/_utils/` (direct mount)
  or `http://localhost:5984/_utils/` (reverse proxy). Database browsing,
  document CRUD, design-doc editing, security configuration, revision
  history.
- **[Migration Playbook](migration.md)** — eight-phase playbook for
  moving a production Apache CouchDB workload onto IRISCouch, with
  per-step success/failure criteria and a symmetric rollback narrative.
  Read this next if you are adopting IRISCouch to retire a standing
  CouchDB deployment.
- **[Deviations Log](deviations.md)** — every operator-observable
  difference between IRISCouch and CouchDB 3.x with named rationale.
  Read this if you are evaluating IRISCouch against a workload and
  want to know in advance which CouchDB behaviors you cannot rely on.
- **[Troubleshooting Runbook](troubleshooting.md)** — five canonical
  incident classes (replication lag, checkpoint corruption, stuck
  conflicts, attachment stream failures, JS sandbox errors) with
  Symptoms / Diagnostic / Resolution / Prevention for each.
- **[Working code examples](../examples/README.md).** Six ready-to-run
  integrations: `hello-document` (curl CRUD roundtrip), `pouchdb-sync`
  (bidirectional sync with observable convergence), `replicate-from-couchdb`
  (the runnable template for [Migration Playbook Phase 3](migration.md)),
  `mango-query` (declarative `_index` / `_find` / `_explain`),
  `attachment-upload` (binary SHA-256 round-trip), `jsruntime-subprocess-node`
  (JavaScript views via Subprocess backend). Run any one individually or use
  `examples/run-all.sh` to run them all.

---

## Troubleshooting

**`Connection refused` on `localhost:52773`.** IRIS is not running, or the
default CSP port has been changed. Start IRIS (`iris start <instance>`) and
re-probe. If port 52773 is correct but still refused, check the IRIS
instance's CSP configuration in the Management Portal under *System
Administration → Security → Applications → Web Applications*.

**`401 Unauthorized` on a probe you expected to work.** The IRIS credentials
(`_system:SYS`) may have been changed at install time. Use your actual IRIS
admin credentials. The `/_session` endpoint will tell you which user IRIS
authenticated the request as.

**`404 Not Found` on `/iris-couch/`.** The installer did not run, or the web
application was not created. Re-run `Do ##class(IRISCouch.Installer).Install($Namespace, "/iris-couch/")`
from the terminal. If that fails, inspect the `%SYS.CSP.WebApps` table (via
SQL) and confirm `/iris-couch/` is present and points at the correct
namespace.

**`501 Not Implemented` response to a view query.** Expected behaviour when
`JSRUNTIME=None` (the default). Either:
- Switch to `Subprocess` and configure `JSRUNTIMESUBPROCESSPATH` (see
  [JavaScript Runtime Requirements](#javascript-runtime-requirements)), or
- Stay on `None` and understand that `_view/<name>` rows in the compatibility
  matrix are `501 in default config` — [matrix](compatibility-matrix.md).

**PouchDB `sync()` stalls.** Two common causes:
1. CORS blocking in browsers (see the PouchDB browser snippet note above).
   Node.js PouchDB does not hit this.
2. IRISCouch returning a 501 for a view the replicator tried to use as a
   filter function. Replicators that use `filter: 'myddoc/myfilter'` in
   their options require a JS runtime; use `doc_ids` or `selector` filters
   instead under `JSRUNTIME=None`.

**Admin UI says "access denied" after login.** The `IRISCouch_Admin` role
was not granted to the logging-in user. The installer grants it
automatically to the installing user and `_SYSTEM`; to grant additional
users, from the `%SYS` namespace:

```objectscript
Do ##class(Security.Users).AddRoles("username", "IRISCouch_Admin")
```

**ZPM install fails with a compile error referencing `[Language = python]`.**
This would indicate a regression of PRD NFR-M9. Shipped IRISCouch .cls files
must contain zero `[Language = python]` methods; if you encounter this,
open an issue and include the failing class name + line. Per the Epic 12
retro, a Python-less IRIS CI image is planned to catch this regression
automatically.

**Any other "this shouldn't have happened" outcome.** File an issue; the
project is pre-α and adopter signals are genuinely valuable.

---

*This guide is current as of 2026-04-18 (Story 13.1). The compatibility
matrix in [compatibility-matrix.md](compatibility-matrix.md) is updated on
every release per PRD NFR-I3; this guide is updated whenever the install
procedure, required prereqs, or topology recommendations change.*
