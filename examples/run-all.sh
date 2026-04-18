#!/usr/bin/env bash
# run-all.sh — execute every example in the examples/ tree, report pass/fail.
#
# Exit status: 0 if every non-skipped example passed; 1 if any example failed.
# Skipped examples (conditional prerequisites missing, e.g., no local CouchDB
# for replicate-from-couchdb, no Subprocess JSRuntime for the Node view
# example) count as pass-with-caveat and are included in the summary.
#
# Usage:
#   bash run-all.sh                     # all six examples
#   bash run-all.sh --filter hello      # substring match on example dir name
#   bash run-all.sh --quiet             # hide stdout/stderr per example; keep summary
#
# The per-example stdout is streamed to stdout by default (helps debugging);
# --quiet buffers it to logs under _logs/<example>.log and prints them only
# on failure.

set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$DIR/_logs"
mkdir -p "$LOG_DIR"

FILTER=''
QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --filter) FILTER="$2"; shift 2 ;;
    --quiet)  QUIET=1; shift ;;
    --help)
      sed -n '2,18p' "$0"
      exit 0 ;;
    *) echo "Unknown flag: $1"; exit 64 ;;
  esac
done

EXAMPLES=(
  'hello-document|bash run.sh'
  'pouchdb-sync|node run.mjs'
  'replicate-from-couchdb|bash run.sh'
  'mango-query|bash run.sh'
  'attachment-upload|node run.mjs'
  'jsruntime-subprocess-node|bash run.sh'
)

declare -i PASS=0 FAIL=0 SKIP=0
FAILED_NAMES=()
SKIPPED_NAMES=()

for row in "${EXAMPLES[@]}"; do
  name="${row%%|*}"
  cmd="${row#*|}"

  if [ -n "$FILTER" ] && [[ "$name" != *"$FILTER"* ]]; then
    continue
  fi

  printf '\n==========================================================\n'
  printf 'RUNNING: %s\n' "$name"
  printf '==========================================================\n'

  log="$LOG_DIR/$name.log"
  (
    cd "$DIR/$name" && $cmd
  ) >"$log" 2>&1
  status=$?

  case "$status" in
    0)
      PASS+=1
      printf '[PASS] %s\n' "$name"
      [ "$QUIET" -eq 0 ] && cat "$log"
      ;;
    2)
      SKIP+=1
      SKIPPED_NAMES+=("$name")
      printf '[SKIP] %s (conditional prerequisite missing)\n' "$name"
      [ "$QUIET" -eq 0 ] && cat "$log"
      ;;
    *)
      FAIL+=1
      FAILED_NAMES+=("$name")
      printf '[FAIL] %s (exit %d)\n' "$name" "$status"
      cat "$log"
      ;;
  esac
done

printf '\n==========================================================\n'
printf 'SUMMARY: %d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
if [ "${#SKIPPED_NAMES[@]}" -gt 0 ]; then
  printf 'Skipped: %s\n' "${SKIPPED_NAMES[*]}"
fi
if [ "${#FAILED_NAMES[@]}" -gt 0 ]; then
  printf 'Failed: %s\n' "${FAILED_NAMES[*]}"
fi
printf '==========================================================\n'

[ "$FAIL" -eq 0 ]
