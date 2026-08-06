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
source_root="$repo_root/research/sdl3-wayland-blue"
build_root="$repo_root/build/sdl3-wayland-blue"
bundle_root="$repo_root/deploy/sdl3-wayland-blue"
toolchain_wrapper_dir="$repo_root/build/pcsx2-sdl-r36s/toolchain-wrappers"
sdl3_build_root="$repo_root/build/sdl3-wayland-rebuild/build"
smoke_lib_root="$repo_root/deploy/sdl3-wayland-smoke/lib"

source_file="$source_root/main.c"
binary_out="$build_root/bin/sdl3-wayland-blue"
compiler="$toolchain_wrapper_dir/aarch64-archr-linux-gnu-gcc"

require_file "$source_file" "SDL blue diagnostic source"
require_file "$compiler" "AArch64 cross compiler wrapper"
require_file "$sdl3_build_root/libSDL3.so.0.2.6" "rebuilt SDL3 shared library"
require_dir "$smoke_lib_root" "proven SDL3 Wayland runtime directory"

mkdir -p "$build_root/bin"

cflags=(
	-std=c11
	-O2
	-g
	-fno-omit-frame-pointer
	-march=armv8-a
	-mno-outline-atomics
	-I"$repo_root/upstream/armsx2/platforms/android/app/src/main/cpp/3rdparty/sdl3/include"
	-I"$sdl3_build_root/include-config-release"
	-I"$sdl3_build_root/include-revision"
)

ldflags=(
	-L"$sdl3_build_root"
	-lSDL3
	-lm
	-Wl,-rpath,'$ORIGIN/../lib'
)

printf 'Building SDL Wayland blue diagnostic\n'
printf '  source : %s\n' "$source_file"
printf '  output : %s\n' "$binary_out"
printf '  SDL3   : %s\n' "$sdl3_build_root/libSDL3.so.0.2.6"

"$compiler" "${cflags[@]}" "$source_file" -o "$binary_out" "${ldflags[@]}"

printf '\nBuild complete.\n'
printf 'binary_sha256=%s\n' "$(sha256sum "$binary_out" | awk '{print $1}')"
