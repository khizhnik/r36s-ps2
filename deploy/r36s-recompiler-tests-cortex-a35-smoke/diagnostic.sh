#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
bundle_dir="$script_dir"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_root="$bundle_dir/logs/diagnostic-$timestamp"
log_file="$log_root/diagnostic.log"

mkdir -p "$log_root"

{
  printf 'bundle_dir=%s\n' "$bundle_dir"
  printf 'timestamp=%s\n' "$timestamp"
  uname -a
  cat /etc/os-release
  free -h
  df -h
  mount
  readelf -h "$bundle_dir/bin/recompiler_tests"
  readelf -d "$bundle_dir/bin/recompiler_tests"
  LD_LIBRARY_PATH="$bundle_dir/lib" ldd "$bundle_dir/bin/recompiler_tests" || true
  LD_LIBRARY_PATH="$bundle_dir/lib" /lib/ld-linux-aarch64.so.1 --list "$bundle_dir/bin/recompiler_tests" || true
} >"$log_file" 2>&1

printf '%s\n' "$log_file"
