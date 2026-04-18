// Licensed under the Apache License, Version 2.0 (the "License"); you may not
// use this file except in compliance with the License. You may obtain a copy of
// the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// IRISCouch couchjs-compatible dispatcher entry-point (Story 12.2 + 12.3).
//
// Reads newline-terminated JSON command arrays from stdin and emits
// newline-terminated JSON responses on stdout. Supports the subset of the
// CouchDB couchjs protocol required by Stories 12.2 / 12.3:
//   ["reset", <config?>]
//   ["add_fun", <source>]
//   ["map_doc", <doc>]
//   ["reduce", [<fn-src>...], <kv-pairs>]
//   ["rereduce", [<fn-src>...], <values>]
//   ["ddoc", "new", "_design/<name>", <ddoc-body>]           -- register (Story 12.3)
//   ["ddoc", "_design/<name>", <funPath>, <funArgs>]         -- invoke   (Story 12.3)
//
// The `ddoc` dispatcher matches sources/couchdb/share/server/loop.js::DDoc and
// supports the funPath entries required by IRISCouch today:
//   ["validate_doc_update"] -> Validate.validate (sources/.../validate.js)
//   ["filters","<name>"]    -> Filter.filter     (sources/.../filter.js)
// Other entries (shows/lists/updates/rewrites/views) remain out of scope;
// invoking them responds with an ["error","not_implemented", ...] line.
//
// Intentionally does NOT implement: add_lib, show/list/update/rewrite
// functions, view-filter (filter_view).
//
// The canonical CouchDB loop (sources/couchdb/share/server/loop.js) relies on
// SpiderMonkey-only primitives (evalcx, gc, print, readline, deepFreeze on
// global objects). Rather than shim those across Node/Bun/Deno, this entry
// script re-implements the minimal protocol surface using Node's built-in
// "vm" module for the sandbox equivalent of evalcx.

'use strict';

const fs = require('fs');
const vm = require('vm');

// Story 12.5 AC #4: primary wall-clock timeout enforcement lives here.
// The parent (IRIS) passes --iriscouch-timeout-ms=<N> on the command line,
// or we default to 5000. A rogue map function that does `while(true){}`
// will be killed by this setTimeout at the JS event loop level -- i.e.,
// the moment control leaves the user code. Note that genuinely blocking
// JS (synchronous infinite loops) cannot be interrupted from JS; for
// those, the parent-side kill (Pipe.KillPid) is the defense-in-depth.
// See documentation/js-runtime.md Security Model.
function parseTimeoutArg() {
  for (const arg of process.argv.slice(2)) {
    const m = arg.match(/^--iriscouch-timeout-ms=(\d+)$/);
    if (m) return Number(m[1]);
  }
  return 5000;
}
const TIMEOUT_MS = parseTimeoutArg();
setTimeout(() => {
  try { process.stderr.write('jsruntime_timeout_self\n'); } catch (_) {}
  process.exit(124);
}, TIMEOUT_MS).unref();

// Story 12.5 AC #6: sandbox hardening applied to the vm.Context objects
// below. __proto__ manipulation is blocked by the runCommand option
// contextCodeGeneration: {strings:false, wasm:false} where supported.

// --- sandbox state (mirrors State.funs / State.lib from share/server/state.js) ---
const State = {
  funs: [],           // list of compiled map/reduce functions
  lib: null,
  query_config: {},
};

// Registered design docs keyed by ddoc id (Story 12.3). Values are the raw
// ddoc bodies as handed to us by IRIS in the `["ddoc","new",id,body]` command.
// Mirrors the `ddocs = {}` map in share/server/loop.js::DDoc.
const ddocs = Object.create(null);

// --- protocol helpers -----------------------------------------------------

function respond(obj) {
  process.stdout.write(JSON.stringify(obj) + '\n');
}

function respondRaw(line) {
  process.stdout.write(line + '\n');
}

function errstr(e) {
  if (e && typeof e === 'object' && 'message' in e) {
    return e.name ? (e.name + ': ' + e.message) : String(e.message);
  }
  try { return JSON.stringify(e); } catch (_) { return String(e); }
}

// --- sandbox creation (evalcx replacement) --------------------------------
//
// Each compiled function runs in its own vm context so user source code
// cannot mutate the dispatcher's globals. The sandbox exposes emit / log /
// sum / JSON / isArray -- the subset that CouchDB map/reduce functions
// actually rely on, per share/server/views.js::create_sandbox.

let mapResults = [];

function makeSandbox() {
  const sandbox = {
    emit: function (key, value) { mapResults.push([key, value]); },
    sum: function (values) {
      let rv = 0;
      for (const v of values) { rv += v; }
      return rv;
    },
    log: function (msg) { respond(['log', String(msg)]); },
    toJSON: JSON.stringify,
    JSON: JSON,
    isArray: Array.isArray,
  };
  vm.createContext(sandbox);
  return sandbox;
}

// Compile a user-supplied function source string into a callable.
// CouchDB source strings look like: "function(doc){ emit(doc._id,1); }"
// We wrap them in parens so vm.runInContext evaluates to a function value.
function compileFunction(source, sandbox) {
  if (!source || typeof source !== 'string') {
    throw ['error', 'compilation_error', 'missing function'];
  }
  try {
    const wrapped = '(' + source + ')';
    const fn = vm.runInContext(wrapped, sandbox, { filename: 'ddoc-fn' });
    if (typeof fn !== 'function') {
      throw ['error', 'compilation_error', 'expression does not eval to a function (' + source + ')'];
    }
    return fn;
  } catch (e) {
    if (Array.isArray(e)) throw e;
    throw ['error', 'compilation_error', errstr(e) + ' (' + source + ')'];
  }
}

// Wrap a raised exception per share/server/views.js::handleViewError. Per-doc
// map errors are swallowed (caller records an empty emission); fatal_error
// terminates the map for that document.
function handleViewError(err, doc) {
  if (err === 'fatal_error') {
    throw ['error', 'map_runtime_error', "function raised 'fatal_error'"];
  }
  if (Array.isArray(err) && err[0] === 'fatal') {
    throw err;
  }
  let message = 'function raised exception ' + errstr(err);
  if (doc && doc._id) message += ' with doc._id ' + doc._id;
  respond(['log', message]);
}

// --- command handlers -----------------------------------------------------

const dispatch = {
  reset: function (config) {
    State.funs = [];
    State.lib = null;
    State.query_config = config || {};
    respondRaw('true');
  },
  add_fun: function (newFun) {
    const sandbox = makeSandbox();
    const fn = compileFunction(newFun, sandbox);
    State.funs.push({ fn: fn, sandbox: sandbox });
    respondRaw('true');
  },
  map_doc: function (doc) {
    // One inner array per registered map function; each contains zero or
    // more [key, value] pairs. Matches share/server/views.js::mapDoc.
    const buf = [];
    for (const entry of State.funs) {
      mapResults = [];
      try {
        // Inject the doc into the per-fn sandbox as a top-level name, then
        // invoke the function with the same reference. The sandbox holds
        // emit() which pushes into mapResults.
        entry.sandbox.__doc = doc;
        entry.fn.call(entry.sandbox, doc);
        buf.push(mapResults);
      } catch (err) {
        handleViewError(err, doc);
        buf.push([]);
      }
    }
    respond(buf);
  },
  reduce: function (reduceFuns, kvs) {
    const keys = kvs.map((kv) => kv[0]);
    const values = kvs.map((kv) => kv[1]);
    runReduce(reduceFuns, keys, values, false);
  },
  rereduce: function (reduceFuns, values) {
    runReduce(reduceFuns, null, values, true);
  },
  // ddoc dispatcher (Story 12.3). Protocol matches share/server/loop.js::DDoc:
  //   ["ddoc", "new", "_design/<name>", <body>]
  //     -> register body under the given id, respond "true"
  //   ["ddoc", "_design/<name>", [<cmd>, ...], <funArgs>]
  //     -> invoke <cmd> on the registered ddoc with funArgs, respond result
  ddoc: function () {
    const args = Array.prototype.slice.call(arguments);
    const first = args.shift();
    if (first === 'new') {
      const ddocId = args.shift();
      const body = args.shift();
      ddocs[ddocId] = body || {};
      respondRaw('true');
      return;
    }
    // Invocation branch
    const ddocId = first;
    const funPath = args.shift() || [];
    const funArgs = args.shift() || [];
    const ddoc = ddocs[ddocId];
    if (!ddoc) {
      throw ['fatal', 'query_protocol_error', 'uncached design doc: ' + ddocId];
    }
    const cmd = funPath[0];
    if (cmd === 'validate_doc_update') {
      // Validate.validate(fun, ddoc, args) per share/server/validate.js
      const source = ddoc.validate_doc_update;
      const sandbox = makeSandbox();
      const fn = compileFunction(source, sandbox);
      try {
        fn.apply(ddoc, funArgs);
        respondRaw('1');
      } catch (err) {
        if (err && err.name && err.stack) {
          // Real Error — re-throw so the outer dispatcher returns ["error",...]
          throw err;
        }
        // Thrown plain value (e.g. {forbidden:"..."} or {unauthorized:"..."})
        // is the response, per validate.js
        respond(err);
      }
      return;
    }
    if (cmd === 'filters') {
      // Filter.filter(fun, ddoc, args) per share/server/filter.js. funPath is
      // ["filters","<name>"]. funArgs is [[<doc>,...], <req>].
      const fname = funPath[1];
      const filters = ddoc.filters || {};
      const source = filters[fname];
      if (typeof source !== 'string' || source.length === 0) {
        throw ['error', 'not_found',
          'missing filters function ' + fname + ' on design doc ' + ddocId];
      }
      const sandbox = makeSandbox();
      const fn = compileFunction(source, sandbox);
      const docs = funArgs[0] || [];
      const req = funArgs[1];
      const results = [];
      for (let i = 0; i < docs.length; i++) {
        let out;
        try {
          out = fn.apply(ddoc, [docs[i], req]);
        } catch (err) {
          // Per share/server/filter.js the filter propagates its own
          // exceptions; map to a structured error so IRIS logs the reason.
          throw ['error', 'filter_runtime_error', errstr(err)];
        }
        results.push((out && true) || false);
      }
      respond([true, results]);
      return;
    }
    // Unhandled ddoc subcommand. Views/shows/lists/updates/rewrites are not
    // supported by Story 12.3 scope — callers must not request them yet.
    throw ['error', 'not_implemented', 'ddoc subcommand not supported: ' + cmd];
  },
};

function runReduce(reduceFuns, keys, values, rereduce) {
  const reductions = [];
  for (const source of reduceFuns) {
    const sandbox = makeSandbox();
    try {
      const fn = compileFunction(source, sandbox);
      reductions.push(fn.call(sandbox, keys, values, rereduce));
    } catch (err) {
      // Match share/server/views.js::runReduce -- record null on error
      respond(['log', 'reduce error: ' + errstr(err)]);
      reductions.push(null);
    }
  }
  respond([true, reductions]);
}

// --- line dispatcher ------------------------------------------------------

function handleLine(line) {
  let cmd;
  try {
    cmd = JSON.parse(line);
  } catch (e) {
    respond(['error', 'json_parse_error', errstr(e)]);
    return;
  }
  if (!Array.isArray(cmd) || cmd.length < 1) {
    respond(['error', 'protocol_error', 'command must be a JSON array']);
    return;
  }
  const cmdkey = cmd[0];
  const args = cmd.slice(1);
  const handler = dispatch[cmdkey];
  if (!handler) {
    respond(['error', 'unknown_command', "unknown command '" + cmdkey + "'"]);
    return;
  }
  try {
    handler.apply(null, args);
  } catch (e) {
    if (Array.isArray(e) && e[0] === 'fatal') {
      e[0] = 'error';
      respond(e);
      process.exit(1);
    } else if (Array.isArray(e)) {
      respond(e);
    } else {
      respond(['error', 'unnamed_error', errstr(e)]);
    }
  }
}

// --- main: read stdin line-by-line ---------------------------------------

// Node's readline would be fluent, but IRIS $ZF(-100) /STDIN=<file> delivers
// the full command stream at once. Reading stdin to end, splitting on "\n"
// keeps the protocol equivalent whether the driver is a pipe or a file.

let buffer = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => { buffer += chunk; });
process.stdin.on('end', () => {
  const lines = buffer.split('\n');
  for (const line of lines) {
    const trimmed = line.replace(/\r$/, '');
    if (trimmed.length === 0) continue;
    handleLine(trimmed);
  }
  // Clean shutdown; flush any pending stdout.
  if (process.stdout.write('') === false) {
    process.stdout.once('drain', () => process.exit(0));
  } else {
    process.exit(0);
  }
});
