#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
log_root="${script_dir}/logs"
mkdir -p "${log_root}"
ts=$(date -u +%Y%m%dT%H%M%SZ)
run_dir="${log_root}/run-${ts}"
mkdir -p "${run_dir}"

bin="${script_dir}/bin/recompiler_tests"
lib_dir="${script_dir}/lib"
loader="/lib/ld-linux-aarch64.so.1"

export HOME="${script_dir}/home"
export XDG_CONFIG_HOME="${script_dir}/config"
export XDG_CACHE_HOME="${script_dir}/cache"
export XDG_DATA_HOME="${script_dir}/data"
mkdir -p "${HOME}" "${XDG_CONFIG_HOME}" "${XDG_CACHE_HOME}" "${XDG_DATA_HOME}"

{
  uname -a
  cat /proc/cpuinfo 2>/dev/null || true
  lscpu 2>/dev/null || true
  file "${bin}"
  readelf -d "${bin}"
  LD_LIBRARY_PATH="${lib_dir}" "${loader}" --list "${bin}" || true
} >"${run_dir}/preflight.log" 2>&1

test_filter="${1:-EeRecHarnessValidation.TestOne_SetsRegisterToKnownPoison}"
if [ "$#" -gt 0 ]; then
  shift
fi

set +e
timeout 30s env \
  LD_LIBRARY_PATH="${lib_dir}" \
  HOME="${HOME}" \
  XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
  XDG_CACHE_HOME="${XDG_CACHE_HOME}" \
  XDG_DATA_HOME="${XDG_DATA_HOME}" \
  "${bin}" \
  --gtest_filter="${test_filter}" \
  --gtest_color=no \
  "$@" \
  >"${run_dir}/stdout.log" 2>"${run_dir}/stderr.log"
status=$?
set -e

printf '%s\n' "${status}" >"${run_dir}/exit-code.txt"

if [ "${status}" -ge 128 ]; then
  sig=$((status - 128))
  {
    printf 'signal=%s\n' "${sig}"
    dmesg 2>/dev/null | tail -n 80 || true
  } >"${run_dir}/crash.log" 2>&1
fi

printf '%s\n' "${run_dir}"
