#!/usr/bin/env bash
set -euo pipefail

bundle_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
binary="${bundle_dir}/bin/pcsx2-eerunner"
log_root="${bundle_dir}/logs"
ts="$(date -u +%Y%m%dT%H%M%SZ)"
run_dir="${log_root}/diagnostic-${ts}"

mkdir -p "${run_dir}"

{
  echo "bundle_dir=${bundle_dir}"
  echo "binary=${binary}"
  echo "timestamp_utc=${ts}"
  echo
  uname -a
  echo
  cat /etc/os-release
  echo
  free -h
  echo
  mount
  echo
  if command -v readelf >/dev/null 2>&1; then
    readelf -h "${binary}" || true
    readelf -d "${binary}" || true
  fi
  echo
  if command -v ldd >/dev/null 2>&1; then
    ldd "${binary}" || true
  fi
} >"${run_dir}/diagnostic.log" 2>&1

printf '%s\n' "${run_dir}"
