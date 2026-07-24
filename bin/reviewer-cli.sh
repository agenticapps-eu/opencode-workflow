#!/usr/bin/env bash
# reviewer-cli.sh — defensive wrapper for an external-vendor reviewer CLI (§18).
#
# The §18 change-gate requires a change to carry independent multi-AI review
# (>=2 external-vendor reviewers) in REVIEWS.md before code. The review
# *producer* (the opencode `openspec-change-review` skill) calls this wrapper
# once per vendor to run the actual CLI. This wrapper exists because the cParX
# pilot found `codex exec "<prompt>"` reads stdin and HANGS without `</dev/null`
# (a 4-minute timeout on first attempt). A hanging reviewer must never be able
# to stall an edit indefinitely, so every reviewer invocation is:
#   - fed `</dev/null` on stdin, and
#   - bounded by a hard `timeout`.
#
# Usage:
#   reviewer-cli.sh <vendor> <prompt-file>
#     <vendor>       gemini | codex   (>=2 DISTINCT vendors required by §18)
#     <prompt-file>  path to a file holding the full review prompt
#
# Env:
#   REVIEWER_TIMEOUT   hard wall-clock cap, seconds (default 180)
#
# Output: the reviewer's raw verdict text on stdout. Exit 0 on a completed
# review; non-zero if the CLI is missing, timed out, or errored (the producer
# treats a non-zero vendor as "reviewer unavailable" and reports it — it does
# NOT silently count as a passing reviewer).

set -u

vendor="${1:-}"
prompt_file="${2:-}"
TIMEOUT="${REVIEWER_TIMEOUT:-180}"

die() { printf 'reviewer-cli: %s\n' "$*" >&2; exit 3; }

[ -n "$vendor" ] || die "usage: reviewer-cli.sh <vendor> <prompt-file>"
[ -f "$prompt_file" ] || die "prompt file not found: $prompt_file"

# Resolve a `timeout` binary (GNU coreutils `timeout` or macOS `gtimeout`).
TIMEOUT_BIN=""
if command -v timeout >/dev/null 2>&1; then TIMEOUT_BIN="timeout"
elif command -v gtimeout >/dev/null 2>&1; then TIMEOUT_BIN="gtimeout"
fi
run_bounded() {
  # run_bounded <cmd...> — enforce the timeout if we have one, else best-effort.
  if [ -n "$TIMEOUT_BIN" ]; then
    "$TIMEOUT_BIN" "$TIMEOUT" "$@"
  else
    "$@"
  fi
}

prompt="$(cat "$prompt_file")"

case "$vendor" in
  gemini)
    command -v gemini >/dev/null 2>&1 || die "gemini CLI not found on PATH"
    # gemini -p "<prompt>" worked first-try in the pilot; still bound + </dev/null.
    run_bounded gemini -p "$prompt" </dev/null
    ;;
  codex)
    command -v codex >/dev/null 2>&1 || die "codex CLI not found on PATH"
    # codex exec reads stdin and hangs without </dev/null (pilot friction #3).
    run_bounded codex exec "$prompt" </dev/null
    ;;
  *)
    die "unknown vendor '$vendor' (expected: gemini | codex)"
    ;;
esac

rc=$?
[ "$rc" -eq 124 ] && die "$vendor timed out after ${TIMEOUT}s"
exit "$rc"
