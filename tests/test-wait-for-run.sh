#!/usr/bin/env bash
# shellcheck disable=SC2016  # single quotes are meant: that text must reach the script under test as it is
# The step that waits for the image build must only pass when the build passed.
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

SCRIPT="$REPO/.github/actions/trigger-and-wait-workflow/wait-for-run.sh"

# A fake gh: each call prints the next line of $W/answers (the last line repeats).
# A line that is the word FAIL makes that call fail with no output.
cat > "$W/bin/gh" <<FAKE
#!/bin/sh
echo "gh \$*" >> "$W/calls.log"
n=\$(cat "$W/count" 2>/dev/null || echo 0); n=\$((n + 1)); echo "\$n" > "$W/count"
total=\$(wc -l < "$W/answers")
[ "\$n" -gt "\$total" ] && n=\$total
line=\$(sed -n "\${n}p" "$W/answers")
[ "\$line" = "FAIL" ] && exit 1
printf '%s\n' "\$line"
FAKE
chmod +x "$W/bin/gh"

# wait_with <answers...>: runs the script with those answers; sets $code and $W/output
wait_with() {
  printf '%s\n' "$@" > "$W/answers"
  rm -f "${W:?}/count" "${W:?}/output" "${W:?}/calls.log"
  PATH="$W/bin:$PATH" GITHUB_OUTPUT="$W/output" "$SCRIPT" 123 "${TIMEOUT:-5}" 0 > "$W/log" 2>&1
  code=$?
}

RUNNING='{"status":"in_progress","conclusion":""}'

wait_with "$RUNNING" '{"status":"queued","conclusion":null}' "$RUNNING" '{"status":"completed","conclusion":"success"}'
same "passes when the run ends with success" "$code" "0"
has "reports the result success" "$W/output" "conclusion=success"
same "asked for the state until the run ended" "$(grep -c 'run view 123' "$W/calls.log")" "4"

wait_with "$RUNNING" '{"status":"completed","conclusion":"failure"}'
same "fails when the run failed" "$code" "1"
has "reports the result failure" "$W/output" "conclusion=failure"

wait_with '{"status":"completed","conclusion":"cancelled"}'
same "fails when the run was cancelled" "$code" "1"

wait_with '{"status":"completed","conclusion":"timed_out"}'
same "fails when the run hit GitHub's own time limit" "$code" "1"

wait_with '{"status":"completed","conclusion":null}'
same "fails when the run ended with no result" "$code" "1"

wait_with "$RUNNING" FAIL '' "$RUNNING" 'not json' '{"status":"completed","conclusion":"success"}'
same "carries on after a few unreadable answers" "$code" "0"

wait_with "$RUNNING" FAIL
same "fails when the state can not be read many times in a row" "$code" "1"
has "says that the state could not be read" "$W/log" "could not be read"

wait_with '{"status":"something_new","conclusion":null}'
same "fails on a state it does not know" "$code" "1"

# time passes 10 minutes per look at the clock, so a 5 minute limit is over at the second look
cat > "$W/bin/date" <<FAKE
#!/bin/sh
n=\$(cat "$W/clock" 2>/dev/null || echo 0); n=\$((n + 600)); echo "\$n" > "$W/clock"
echo "\$n"
FAKE
chmod +x "$W/bin/date"
wait_with "$RUNNING"
same "fails when the run takes longer than the limit" "$code" "1"
has "reports the result timed_out" "$W/output" "conclusion=timed_out"
rm -f "${W:?}/bin/date"

isnt "stops on a run id that is not a number" env PATH="$W/bin:$PATH" "$SCRIPT" "12; echo x" 5 0

ACTION="$REPO/.github/actions/trigger-and-wait-workflow/action.yml"
has "the action uses the script to wait" "$ACTION" 'wait-for-run.sh" "$RUN_ID" "$TIMEOUT_MINUTES"'
hasnt "the action never ends a wait with success by itself" "$ACTION" "exit 0"

finish
