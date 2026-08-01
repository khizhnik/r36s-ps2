#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN="${BIN:-$SCRIPT_DIR/bin/recompiler_tests}"
FILTERS_FILE="${FILTERS_FILE:-$SCRIPT_DIR/validation-suite.filters}"
BUNDLE_ROOT="${BUNDLE_ROOT:-$SCRIPT_DIR}"
LOG_ROOT="${LOG_ROOT:-$BUNDLE_ROOT/logs}"
SUITE_TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_ROOT="$LOG_ROOT/validation-$SUITE_TS"

if [[ ! -x "$BIN" ]]; then
  printf 'error: missing executable: %s\n' "$BIN" >&2
  exit 1
fi

if [[ ! -f "$FILTERS_FILE" ]]; then
  printf 'error: missing filter list: %s\n' "$FILTERS_FILE" >&2
  exit 1
fi

mkdir -p "$RUN_ROOT"

HOME_DIR="$BUNDLE_ROOT/.home"
CONFIG_DIR="$BUNDLE_ROOT/.config"
CACHE_DIR="$BUNDLE_ROOT/.cache"
DATA_DIR="$BUNDLE_ROOT/.local/share"
mkdir -p "$HOME_DIR" "$CONFIG_DIR" "$CACHE_DIR" "$DATA_DIR"

summary_tsv="$RUN_ROOT/summary.tsv"
printf 'index\tfilter\tresult\texit_code\telapsed_s\tstdout\tstderr\n' > "$summary_tsv"

readarray -t TEST_FILTERS < <(grep -Ev '^[[:space:]]*(#|$)' "$FILTERS_FILE")

classify_exit_code() {
  case "$1" in
    0) echo PASS ;;
    124) echo TIMEOUT ;;
    132) echo SIGILL ;;
    134) echo SIGABRT ;;
    139) echo SIGSEGV ;;
    *) echo FAIL ;;
  esac
}

overall_status=0

for i in "${!TEST_FILTERS[@]}"; do
  filter="${TEST_FILTERS[$i]}"
  safe_name="$(printf '%s' "$filter" | tr '/: ' '___' | tr -cd 'A-Za-z0-9_.-')"
  test_dir="$RUN_ROOT/$(printf '%02d' "$((i + 1))")-$safe_name"
  mkdir -p "$test_dir"

  printf '%s\n' "$filter" > "$test_dir/filter.txt"
  start_s="$(date +%s)"

  set +e
  timeout 30s \
    env \
      HOME="$HOME_DIR" \
      XDG_CONFIG_HOME="$CONFIG_DIR" \
      XDG_CACHE_HOME="$CACHE_DIR" \
      XDG_DATA_HOME="$DATA_DIR" \
      LD_LIBRARY_PATH="$BUNDLE_ROOT/lib" \
      "$BIN" \
      --gtest_filter="$filter" \
      --gtest_color=no \
      >"$test_dir/stdout.log" \
      2>"$test_dir/stderr.log"
  exit_code=$?
  set -e

  end_s="$(date +%s)"
  elapsed_s="$((end_s - start_s))"
  result="$(classify_exit_code "$exit_code")"

  printf '%s\n' "$exit_code" > "$test_dir/exit-code.txt"
  printf '%s\n' "$elapsed_s" > "$test_dir/elapsed-seconds.txt"
  printf '%s\n' "$result" > "$test_dir/result.txt"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$((i + 1))" \
    "$filter" \
    "$result" \
    "$exit_code" \
    "$elapsed_s" \
    "$test_dir/stdout.log" \
    "$test_dir/stderr.log" \
    >> "$summary_tsv"

  if [[ "$result" != PASS ]]; then
    overall_status=1
  fi
done

printf 'Validation suite logs: %s\n' "$RUN_ROOT"
printf 'Summary TSV: %s\n' "$summary_tsv"

exit "$overall_status"
