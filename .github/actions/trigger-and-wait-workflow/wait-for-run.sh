#!/usr/bin/env bash
# Waits for a workflow run to finish.
#
# Usage: wait-for-run.sh <run id> <timeout in minutes> [seconds between checks]
#
# Exit code 0: the run finished with the result "success". Nothing else gives 0.
# Exit code 1: the run failed or was cancelled, it took longer than the timeout,
#              or its state could not be read several times in a row.
#
# Needs the gh command and GH_TOKEN. Writes "conclusion=<result>" to $GITHUB_OUTPUT when set.
set -u

RUN_ID="${1:?usage: wait-for-run.sh <run id> <timeout in minutes> [seconds between checks]}"
TIMEOUT_MINUTES="${2:?usage: wait-for-run.sh <run id> <timeout in minutes> [seconds between checks]}"
POLL_SECONDS="${3:-30}"

# how many times in a row the state may be unreadable (a short GitHub API problem) before giving up
MAX_UNREADABLE=5

if ! [[ "$RUN_ID" =~ ^[0-9]+$ ]] || ! [[ "$TIMEOUT_MINUTES" =~ ^[0-9]+$ ]] || ! [[ "$POLL_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "::error::wait-for-run.sh: the run id, the timeout and the wait must be whole numbers"
  exit 1
fi

report() {
  [ -n "${GITHUB_OUTPUT:-}" ] && echo "conclusion=$1" >> "$GITHUB_OUTPUT"
  return 0
}

MAX_WAIT_SECONDS=$((TIMEOUT_MINUTES * 60))
START_TIME=$(date +%s)
UNREADABLE=0

while true; do
  ELAPSED=$(($(date +%s) - START_TIME))

  if [ "$ELAPSED" -gt "$MAX_WAIT_SECONDS" ]; then
    echo "::error::Run ${RUN_ID} did not finish within ${TIMEOUT_MINUTES} minutes"
    report "timed_out"
    exit 1
  fi

  STATE="$(gh run view "$RUN_ID" --json status,conclusion 2>/dev/null)" || STATE=""
  STATUS="$(jq -r '.status // empty' <<< "$STATE" 2>/dev/null)" || STATUS=""

  case "$STATUS" in
    completed)
      CONCLUSION="$(jq -r '.conclusion // empty' <<< "$STATE")"
      report "${CONCLUSION:-unknown}"
      if [ "$CONCLUSION" = "success" ]; then
        echo "::notice::Run ${RUN_ID} finished with success"
        exit 0
      fi
      echo "::error::Run ${RUN_ID} finished with: ${CONCLUSION:-unknown}"
      exit 1
      ;;
    in_progress | queued | requested | waiting | pending)
      UNREADABLE=0
      echo "Run ${RUN_ID} is ${STATUS} (waited ${ELAPSED}s)"
      ;;
    *)
      UNREADABLE=$((UNREADABLE + 1))
      if [ "$UNREADABLE" -ge "$MAX_UNREADABLE" ]; then
        echo "::error::The state of run ${RUN_ID} could not be read ${UNREADABLE} times in a row (last answer: '${STATUS}')"
        report "unknown"
        exit 1
      fi
      echo "::warning::The state of run ${RUN_ID} could not be read (try ${UNREADABLE} of ${MAX_UNREADABLE}), trying again"
      ;;
  esac

  sleep "$POLL_SECONDS"
done
