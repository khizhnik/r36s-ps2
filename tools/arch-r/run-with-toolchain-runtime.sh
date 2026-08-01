#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  printf 'Usage: %s <command> [args...]\n' "${0##*/}" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
sdk_root="${ARCHR_SDK_ROOT:-${repo_root}/research/upstream/arch-r/build.ArchR-RK3326.aarch64}"
toolchain_dir="${sdk_root}/toolchain"
triplet="aarch64-archr-linux-gnu"

runtime_libdirs=(
  "${toolchain_dir}/x86_64-pc-linux-gnu/${triplet}/lib"
  "${toolchain_dir}/x86_64-pc-linux-gnu/${triplet}/lib64"
  "${toolchain_dir}/lib"
  "${toolchain_dir}/lib64"
)
pkgconfig_libdirs=(
  "${toolchain_dir}/${triplet}/sysroot/usr/lib/pkgconfig"
  "${toolchain_dir}/${triplet}/sysroot/usr/share/pkgconfig"
  "${toolchain_dir}/share/pkgconfig"
)

ld_library_path=""
for dir in "${runtime_libdirs[@]}"; do
  if [ -d "${dir}" ]; then
    if [ -n "${ld_library_path}" ]; then
      ld_library_path="${ld_library_path}:${dir}"
    else
      ld_library_path="${dir}"
    fi
  fi
done

export PATH="${toolchain_dir}/bin:${toolchain_dir}/sbin:${PATH:-}"
if [ -n "${ld_library_path}" ]; then
  if [ -n "${LD_LIBRARY_PATH:-}" ]; then
    export LD_LIBRARY_PATH="${ld_library_path}:${LD_LIBRARY_PATH}"
  else
    export LD_LIBRARY_PATH="${ld_library_path}"
  fi
fi

export PKG_CONFIG_SYSROOT_DIR="${toolchain_dir}/${triplet}/sysroot"
pkgconfig_path=""
for dir in "${pkgconfig_libdirs[@]}"; do
  if [ -d "${dir}" ]; then
    if [ -n "${pkgconfig_path}" ]; then
      pkgconfig_path="${pkgconfig_path}:${dir}"
    else
      pkgconfig_path="${dir}"
    fi
  fi
done
if [ -n "${pkgconfig_path}" ]; then
  export PKG_CONFIG_LIBDIR="${pkgconfig_path}"
fi

exec "$@"
