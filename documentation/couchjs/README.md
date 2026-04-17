# IRISCouch Subprocess JSRuntime — couchjs entry-point

This directory holds the JavaScript entry-point script that IRISCouch's
`IRISCouch.JSRuntime.Subprocess` backend spawns to execute design-document
map, reduce, and (in Story 12.3) filter / validate_doc_update functions.

## Using it

1. Install a JavaScript interpreter (any of Node 18+, Bun 1+, Deno 1.40+).
2. Configure IRISCouch to use the subprocess backend:

   ```objectscript
   Do ##class(IRISCouch.Config).Set("JSRUNTIME", "Subprocess")
   Do ##class(IRISCouch.Config).Set("JSRUNTIMESUBPROCESSPATH", "C:\Program Files\nodejs\node.exe")
   ```

3. The Subprocess backend automatically locates `couchjs-entry.js` in this
   directory (or on the configured `JSRUNTIMESUBPROCESSENTRY` override
   path) and passes it as the script argument to the interpreter.

## Protocol

`couchjs-entry.js` implements the CouchDB query-server line protocol
defined in `sources/couchdb/share/server/loop.js`. IRISCouch writes
newline-terminated JSON command arrays to stdin; the interpreter writes
one JSON response line per command to stdout. Story 12.2 supports the
`reset`, `add_fun`, `map_doc`, `reduce`, and `rereduce` commands. The
`ddoc`, `add_lib`, and protocol-extension commands are Story 12.3 /
Epic 13 scope and produce `unknown_command` errors today.

## Vendored reference sources

The `loop.js`, `views.js`, `util.js`, `state.js`, `validate.js`, and
`filter.js` files in this directory are verbatim copies of the CouchDB
3.x query-server code (Apache 2.0). They are preserved as a reference
for the protocol semantics IRISCouch targets and are NOT loaded at
runtime. Note that the CouchDB originals rely on SpiderMonkey-only
primitives (`evalcx`, `gc`, `print`, `readline`); our entry script uses
Node's `vm` module as the `evalcx` replacement.

## Troubleshooting

- **`IsAvailable()` returns 0.** The interpreter path is missing or does
  not execute. Run the interpreter manually with `--version` from the
  same shell IRIS spawns from (Windows: the service account, *not* your
  interactive login) to verify PATH and permissions.
- **`subprocess_error` in the view response.** Inspect
  `cconsole.log` for the full subprocess stderr capture and the
  `jsruntime` structured log lines. The reason string names the
  interpreter + path + last error line for diagnosability.
- **Timeout after Nms.** `JSRUNTIMETIMEOUT` (default 5000 ms) caps the
  per-query interpreter run. Long-running reduces should use a builtin
  (`_sum`, `_count`, `_stats`) which bypasses the subprocess.

## License

Vendored reference files are Apache 2.0 per their headers. The
`couchjs-entry.js` driver is under the same license as the rest of
IRISCouch.
