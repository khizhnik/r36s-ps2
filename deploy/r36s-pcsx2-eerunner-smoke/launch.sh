#!/usr/bin/env bash
set -euo pipefail

bundle_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
binary="${bundle_dir}/bin/pcsx2-eerunner"
log_root="${bundle_dir}/logs"
ts="$(date -u +%Y%m%dT%H%M%SZ)"
run_dir="${log_root}/${ts}"

mkdir -p "${run_dir}"

{
  echo "bundle_dir=${bundle_dir}"
  echo "binary=${binary}"
  echo "timestamp_utc=${ts}"
  echo "argv=$*"
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
    readelf -d "${binary}" || true
  fi
  echo
  if command -v ldd >/dev/null 2>&1; then
    ldd "${binary}" || true
  fi
} >"${run_dir}/diagnostic.log" 2>&1

export LD_LIBRARY_PATH="${bundle_dir}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
export PCSX2_NOCONSOLE=1

if [ "$#" -eq 0 ]; then
  set -- --help
fi

set +e
timeout 30s "${binary}" "$@" >"${run_dir}/stdout.log" 2>"${run_dir}/stderr.log"
status=$?
set -e

printf '%s\n' "${status}" >"${run_dir}/exit-code.txt"
exit "${status}"
