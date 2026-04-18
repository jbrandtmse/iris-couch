#!/usr/bin/env bash
# replicate-from-couchdb example: pull a database from Apache CouchDB into
# IRISCouch via the `/_replicate` endpoint. This is the concrete realisation
# of Phase 3 ("Replicate-in") of documentation/migration.md.
#
# Prereq: a reachable Apache CouchDB at $COUCHDB_URL (default
# http://localhost:5984). If unreachable, the script prints a clear guidance
# message naming the COUCHDB_URL env var and exits with status 2 (skipped),
# which the run-all harness treats as a conditional-skip rather than a
# failure.

set -eu

IRISCOUCH_URL="${IRISCOUCH_URL:-http://localhost:52773/iris-couch}"
IRIS_USER="${IRISCOUCH_USER:-_system}"
IRIS_PASS="${IRISCOUCH_PASS:-SYS}"

COUCHDB_URL="${COUCHDB_URL:-http://localhost:5984}"
COUCH_USER="${COUCHDB_USER:-admin}"
COUCH_PASS="${COUCHDB_PASS:-couchdb}"

SRC_DB='replicate-source'
TGT_DB='replicate-target'

IRIS="curl -s -u ${IRIS_USER}:${IRIS_PASS}"
COUCH="curl -s -u ${COUCH_USER}:${COUCH_PASS}"

# Preflight: is Apache CouchDB reachable?
if ! $COUCH -f -m 3 "$COUCHDB_URL/" >/dev/null 2>&1; then
  cat <<EOF
[SKIPPED] No reachable Apache CouchDB at $COUCHDB_URL.

This example requires a running CouchDB 3.x instance to replicate from.
Options to supply one:

  # Run a throwaway CouchDB in docker:
  docker run --rm -d -p 5984:5984 \\
    -e COUCHDB_USER=admin -e COUCHDB_PASSWORD=couchdb \\
    --name couchdb-for-examples couchdb:3.3

  # Or point at an existing instance:
  COUCHDB_URL=http://your-couch-host:5984 \\
  COUCHDB_USER=youruser COUCHDB_PASS=yourpass \\
    bash run.sh

Exiting with status 2 (conditional skip). The run-all harness treats this
as an environmental-skip, not a failure, and records it in the summary.
EOF
  exit 2
fi

# Build source URL with auth embedded (the _replicate payload requires this
# shape — CouchDB does not support arbitrary header forwarding to replication
# workers).
SRC_URL="http://${COUCH_USER}:${COUCH_PASS}@${COUCHDB_URL#http://}/$SRC_DB"

# Reset both sides
$COUCH -o /dev/null -X DELETE "$COUCHDB_URL/$SRC_DB" || true
$IRIS  -o /dev/null -X DELETE "$IRISCOUCH_URL/$TGT_DB" || true

echo "Step 1: Seed source CouchDB at $COUCHDB_URL/$SRC_DB with 5 sample docs"
$COUCH -o /dev/null -X PUT "$COUCHDB_URL/$SRC_DB"
for i in 1 2 3 4 5; do
  id="src-doc-$(printf %03d $i)"
  $COUCH -o /dev/null -X PUT "$COUCHDB_URL/$SRC_DB/$id" \
    -H 'Content-Type: application/json' \
    -d "{\"origin\":\"apache-couchdb\",\"n\":$i}"
done
# Capture the source doc_count for end-to-end parity check
SRC_COUNT=$($COUCH "$COUCHDB_URL/$SRC_DB" | sed -n 's/.*"doc_count":\([0-9]*\).*/\1/p')
echo "Source /$SRC_DB doc_count=$SRC_COUNT"

echo "Step 2: Create target database on IRISCouch"
$IRIS -X PUT "$IRISCOUCH_URL/$TGT_DB"
echo

echo "Step 3: POST /_replicate on IRISCouch (source=apache-couchdb, target=iris-couch)"
REPLICATE_BODY=$(cat <<JSON
{"source":"$SRC_URL","target":"$TGT_DB","continuous":false}
JSON
)
$IRIS -X POST "$IRISCOUCH_URL/_replicate" \
  -H 'Content-Type: application/json' \
  -d "$REPLICATE_BODY"
echo

echo "Step 4: Confirm doc_count parity"
# /_replicate (non-continuous) is synchronous in IRISCouch — it returns once
# replication is complete. So we can check parity immediately; no polling
# loop required.
TGT_COUNT=$($IRIS "$IRISCOUCH_URL/$TGT_DB" | sed -n 's/.*"doc_count":\([0-9]*\).*/\1/p')
echo "Target /$TGT_DB doc_count=$TGT_COUNT"
if [ "$SRC_COUNT" != "$TGT_COUNT" ]; then
  echo "FAIL: doc_count mismatch (source=$SRC_COUNT target=$TGT_COUNT)"
  exit 1
fi
echo "PARITY OK"

echo "Step 5: Spot-check one replicated document"
$IRIS "$IRISCOUCH_URL/$TGT_DB/src-doc-003"
echo

echo "Step 6: Cleanup (drop both source and target)"
$COUCH -X DELETE "$COUCHDB_URL/$SRC_DB"
echo
$IRIS  -X DELETE "$IRISCOUCH_URL/$TGT_DB"
echo
