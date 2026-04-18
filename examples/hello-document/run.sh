#!/usr/bin/env bash
# hello-document example: single-doc CRUD roundtrip against IRISCouch.
#
# Demonstrates: PUT database -> PUT doc -> GET doc -> PUT update -> DELETE doc
# -> confirm 404 on subsequent GET -> DELETE database.
#
# Rev hashes in the output are deterministic only across identical bodies;
# run-to-run the placeholders 1-<hash>, 2-<hash>, 3-<hash> will change. The
# example-runner harness diffs modulo these placeholders.

set -eu

IRISCOUCH_URL="${IRISCOUCH_URL:-http://localhost:52773/iris-couch}"
USER="${IRISCOUCH_USER:-_system}"
PASS="${IRISCOUCH_PASS:-SYS}"
DB="hello-document-example"

CURL="curl -s -u ${USER}:${PASS}"

# Ensure a clean slate: if a stale database lingers from a previous failed run,
# drop it. 404 on the probe is the expected happy path.
$CURL -o /dev/null -X DELETE "$IRISCOUCH_URL/$DB" || true

echo "Step 1: PUT /$DB"
$CURL -X PUT "$IRISCOUCH_URL/$DB"
echo

echo "Step 2: PUT /$DB/greeting (initial body)"
REV1_RAW=$($CURL -X PUT "$IRISCOUCH_URL/$DB/greeting" \
    -H 'Content-Type: application/json' \
    -d '{"message":"hello, iris-couch","lang":"en"}')
echo "$REV1_RAW"
# Extract rev for the next update
REV1=$(echo "$REV1_RAW" | sed -n 's/.*"rev":"\([^"]*\)".*/\1/p')

echo "Step 3: GET /$DB/greeting"
$CURL "$IRISCOUCH_URL/$DB/greeting"
echo

echo "Step 4: PUT /$DB/greeting?rev=$REV1 (update)"
REV2_RAW=$($CURL -X PUT "$IRISCOUCH_URL/$DB/greeting?rev=$REV1" \
    -H 'Content-Type: application/json' \
    -d '{"message":"hello again, iris-couch","lang":"en"}')
echo "$REV2_RAW"
REV2=$(echo "$REV2_RAW" | sed -n 's/.*"rev":"\([^"]*\)".*/\1/p')

echo "Step 5: DELETE /$DB/greeting?rev=$REV2"
$CURL -X DELETE "$IRISCOUCH_URL/$DB/greeting?rev=$REV2"
echo

echo "Step 6: GET /$DB/greeting (expect 404)"
$CURL -o /dev/null -w "HTTP %{http_code}\n" "$IRISCOUCH_URL/$DB/greeting"

echo "Step 7: DELETE /$DB"
$CURL -X DELETE "$IRISCOUCH_URL/$DB"
echo
