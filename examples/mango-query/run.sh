#!/usr/bin/env bash
# mango-query example: create a Mango index, then query with $eq/$gt selector.
#
# Demonstrates the native (non-JS) query path: `_index` for declarative index
# management and `_find` for selector-based querying. `_explain` confirms the
# planner chose the index we created rather than a full-scan fallback.

set -eu

IRISCOUCH_URL="${IRISCOUCH_URL:-http://localhost:52773/iris-couch}"
USER="${IRISCOUCH_USER:-_system}"
PASS="${IRISCOUCH_PASS:-SYS}"
DB="mango-query-example"

CURL="curl -s -u ${USER}:${PASS}"

$CURL -o /dev/null -X DELETE "$IRISCOUCH_URL/$DB" || true

echo "Step 1: PUT /$DB"
$CURL -X PUT "$IRISCOUCH_URL/$DB"
echo

echo "Step 2: Seed 10 documents with status + created_at"
# Deterministic IDs so the expected-output diff does not need UUID tolerance
# on the selector hits.
SEED=(
  'doc-001|active|2026-06-01T10:00:00Z'
  'doc-002|active|2026-06-02T10:00:00Z'
  'doc-003|active|2026-06-03T10:00:00Z'
  'doc-004|active|2025-12-30T10:00:00Z'
  'doc-005|inactive|2026-06-04T10:00:00Z'
  'doc-006|inactive|2026-06-05T10:00:00Z'
  'doc-007|pending|2026-06-06T10:00:00Z'
  'doc-008|pending|2025-11-15T10:00:00Z'
  'doc-009|active|2026-06-07T10:00:00Z'
  'doc-010|active|2026-06-08T10:00:00Z'
)
for row in "${SEED[@]}"; do
  id=$(echo "$row" | cut -d'|' -f1)
  status=$(echo "$row" | cut -d'|' -f2)
  ts=$(echo "$row" | cut -d'|' -f3)
  $CURL -o /dev/null -X PUT "$IRISCOUCH_URL/$DB/$id" \
    -H 'Content-Type: application/json' \
    -d "{\"status\":\"$status\",\"created_at\":\"$ts\"}"
done
echo "Seeded ${#SEED[@]} documents"

echo "Step 3: POST /$DB/_index (status, created_at)"
$CURL -X POST "$IRISCOUCH_URL/$DB/_index" \
  -H 'Content-Type: application/json' \
  -d '{"index":{"fields":["status","created_at"]},"name":"status-created","type":"json"}'
echo

echo "Step 4: POST /$DB/_find selector={status:\$eq active, created_at:\$gt 2026-01-01}"
$CURL -X POST "$IRISCOUCH_URL/$DB/_find" \
  -H 'Content-Type: application/json' \
  -d '{"selector":{"$and":[{"status":{"$eq":"active"}},{"created_at":{"$gt":"2026-01-01"}}]},"execution_stats":true}'
echo

echo "Step 5: POST /$DB/_explain (confirm index used, not full-scan)"
$CURL -X POST "$IRISCOUCH_URL/$DB/_explain" \
  -H 'Content-Type: application/json' \
  -d '{"selector":{"$and":[{"status":{"$eq":"active"}},{"created_at":{"$gt":"2026-01-01"}}]}}'
echo

echo "Step 6: DELETE /$DB"
$CURL -X DELETE "$IRISCOUCH_URL/$DB"
echo
