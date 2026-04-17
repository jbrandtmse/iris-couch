// Licensed under the Apache License, Version 2.0 (the "License"); you may not
// use this file except in compliance with the License. You may obtain a copy of
// the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// IRISCouch couchjs-compatible dispatcher entry-point (Story 12.2).
//
// Reads newline-terminated JSON command arrays from stdin and emits
// newline-terminated JSON responses on stdout. Supports the subset of the
// CouchDB couchjs protocol required by Story 12.2:
//   ["reset", <config?>]
//   ["add_fun", <source>]
//   ["map_doc", <doc>]
//   ["reduce", [<fn-src>...], <kv-pairs>]
//   ["rereduce", [<fn-src>...], <values>]
//
// Intentionally does NOT implement: add_lib, ddoc, shows, lists, filters,
// updates, rewrites, validate_doc_update (Story 12.3 / Epic 13 scope).
//
// The canonical CouchDB loop (sources/couchdb/share/server/loop.js) relies on
// SpiderMonkey-only primitives (evalcx, gc, print, readline, deepFreeze on
// global objects). Rather than shim those across Node/Bun/Deno, this entry
// script re-implements the minimal protocol surface using Node's built-in
// "vm" module for the sandbox equivalent of evalcx.

'use strict';

const fs = require('fs');
const vm = require('vm');

// --- sandbox state (mirrors State.funs / State.lib from share/server/state.js) ---
const State = {
  funs: [],           // list of compiled map/reduce functions
  lib: null,
  query_config: {},
};

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
