#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
bundle_dir="$script_dir"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_root="$bundle_dir/logs/$timestamp"
run_log="$log_root/run.log"
stdout_log="$log_root/stdout.log"
stderr_log="$log_root/stderr.log"
exit_code_file="$log_root/exit-code.txt"

mkdir -p "$log_root"

{
  printf 'bundle_dir=%s\n' "$bundle_dir"
  printf 'timestamp=%s\n' "$timestamp"
  uname -a || true
  cat /proc/cpuinfo || true
  command -v lscpu >/dev/null 2>&1 && lscpu || true
  readelf -d "$bundle_dir/bin/recompiler_tests" || true
  LD_LIBRARY_PATH="$bundle_dir/lib" /lib/ld-linux-aarch64.so.1 --list "$bundle_dir/bin/recompiler_tests" || true
} >"$run_log" 2>&1

set +e
timeout 30s \
  env \
    HOME="$bundle_dir/.home" \
    XDG_CONFIG_HOME="$bundle_dir/.config" \
    XDG_CACHE_HOME="$bundle_dir/.cache" \
    XDG_DATA_HOME="$bundle_dir/.local/share" \
    LD_LIBRARY_PATH="$bundle_dir/lib" \
    "$bundle_dir/bin/recompiler_tests" \
    --gtest_filter=EeRecHarnessValidation.TestOne_SetsRegisterToKnownPoison \
    --gtest_color=no \
    >"$stdout_log" \
    2>"$stderr_log"
exit_code=$?
set -e

printf '%s\n' "$exit_code" >"$exit_code_file"

if (( exit_code != 0 )); then
  {
    printf '\n--- dmesg tail ---\n'
    dmesg 2>/dev/null | tail -n 80 || true
  } >>"$stderr_log"
fi

printf 'exit_code=%s\n' "$exit_code"
exit "$exit_code"
