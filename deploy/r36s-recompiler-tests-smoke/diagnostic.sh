#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
log_root="${script_dir}/logs"
mkdir -p "${log_root}"
ts=$(date -u +%Y%m%dT%H%M%SZ)
run_dir="${log_root}/diagnostic-${ts}"
mkdir -p "${run_dir}"

bin="${script_dir}/bin/recompiler_tests"
lib_dir="${script_dir}/lib"
loader="/lib/ld-linux-aarch64.so.1"

{
  printf 'cwd=%s\n' "$PWD"
  uname -a
  cat /etc/os-release 2>/dev/null || true
  free -h 2>/dev/null || true
  df -h 2>/dev/null || true
  mount 2>/dev/null || true
  file "${bin}"
  readelf -h "${bin}"
  readelf -d "${bin}"
  LD_LIBRARY_PATH="${lib_dir}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" ldd "${bin}" || true
  LD_LIBRARY_PATH="${lib_dir}" "${loader}" --list "${bin}" || true
} >"${run_dir}/diagnostic.log" 2>&1

printf '%s\n' "${run_dir}"
