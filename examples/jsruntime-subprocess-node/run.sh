#!/usr/bin/env bash
# jsruntime-subprocess-node example: end-to-end view query exercising the
# Subprocess JSRuntime backend (Story 12.2 / 12.5).
#
# Demonstrates that IRISCouch will spawn the configured Node interpreter,
# pass it documentation/couchjs/couchjs-entry.js, stream the design-doc
# map function over the couchjs line protocol, and return wire-compatible
# view output.

set -eu

DIR="$(cd "$(dirname "$0")" && pwd)"

echo 'Probe: verify JSRUNTIME=Subprocess is active'
if ! node "$DIR/setup.js" probe; then
  echo ''
  echo '[SKIPPED] Subprocess JSRuntime not available; see instructions above.'
  exit 2
fi
echo ''

node "$DIR/setup.js" seed
echo ''
node "$DIR/setup.js" query-map
echo ''
node "$DIR/setup.js" query-reduce
echo ''
node "$DIR/setup.js" cleanup
