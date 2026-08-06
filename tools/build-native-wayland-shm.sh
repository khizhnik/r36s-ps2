#!/usr/bin/env bash
set -euo pipefail

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

require_file() {
	local path="$1"
	local label="${2:-file}"
	[[ -f "$path" ]] || die "missing ${label}: ${path}"
}

require_dir() {
	local path="$1"
	local label="${2:-directory}"
	[[ -d "$path" ]] || die "missing ${label}: ${path}"
}

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source_root="$repo_root/research/native-wayland-shm"
build_root="$repo_root/build/native-wayland-shm"
bundle_root="$repo_root/deploy/native-wayland-shm"
toolchain_wrapper_dir="$repo_root/build/pcsx2-sdl-r36s/toolchain-wrappers"
compiler="$toolchain_wrapper_dir/aarch64-archr-linux-gnu-gcc"
wayland_scanner="${WAYLAND_SCANNER_EXECUTABLE:-$(command -v wayland-scanner)}"
wayland_lib_root="$repo_root/build/sdl3-wayland-rebuild/wayland-libs"
protocol_xml="${WAYLAND_PROTOCOL_XML:-/usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml}"
if [[ ! -f "$protocol_xml" ]]; then
	protocol_xml="$repo_root/research/upstream/arch-r/build.ArchR-RK3326.aarch64/toolchain/aarch64-archr-linux-gnu/sysroot/usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml"
fi

source_file="$source_root/main.c"
generated_dir="$build_root/generated"
binary_out="$build_root/bin/native-wayland-shm"

require_file "$source_file" "native Wayland SHM source"
require_file "$compiler" "AArch64 cross compiler wrapper"
require_file "$wayland_scanner" "wayland-scanner"
require_file "$wayland_lib_root/libwayland-client.so.0.25.0" "proven wayland-client library"
require_file "$protocol_xml" "xdg-shell protocol XML"
require_dir "$repo_root/build/pcsx2-sdl-r36s" "existing build tree for Wayland headers"

mkdir -p "$build_root/bin" "$generated_dir"

"$wayland_scanner" client-header "$protocol_xml" "$generated_dir/xdg-shell-client-protocol.h"
"$wayland_scanner" private-code "$protocol_xml" "$generated_dir/xdg-shell-protocol.c"

cflags=(
	-std=c11
	-O2
	-g
	-fno-omit-frame-pointer
	-march=armv8-a
	-mno-outline-atomics
	-I"$generated_dir"
	-I"$repo_root/build/sdl3-wayland-rebuild/wayland-headers"
)

ldflags=(
	-L"$wayland_lib_root"
	-lwayland-client
	-Wl,--allow-shlib-undefined
	-Wl,-rpath,'$ORIGIN/../lib'
)

printf 'Building native Wayland SHM diagnostic\n'
printf '  source : %s\n' "$source_file"
printf '  output : %s\n' "$binary_out"
printf '  xml    : %s\n' "$protocol_xml"

"$compiler" "${cflags[@]}" "$source_file" "$generated_dir/xdg-shell-protocol.c" -o "$binary_out" "${ldflags[@]}"

printf '\nBuild complete.\n'
printf 'binary_sha256=%s\n' "$(sha256sum "$binary_out" | awk '{print $1}')"
