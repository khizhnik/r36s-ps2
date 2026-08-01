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
bundle_root="${BUNDLE_DIR:-$repo_root/deploy/pcsx2-sdl-r36s-diag}"
target_root="${TARGET_DIR:-/storage/ports/pcsx2-sdl-r36s-diag}"
connect="${CONNECT_HELPER:-$repo_root/tools/connect-r36s-wifi.sh}"
target_lib="$target_root/lib"
target_bin="$target_root/bin/armsx2-sdl"

require_dir "$bundle_root" "packaged bundle"
require_file "$bundle_root/bin/armsx2-sdl" "packaged binary"
require_file "$bundle_root/lib/libSDL3.so.0.2.6" "packaged SDL3"
require_file "$connect" "connection helper"

printf 'Deploying bundle %s -> %s\n' "$bundle_root" "$target_root"
tar -C "$bundle_root" -cf - . | "$connect" "mkdir -p '$target_root' && tar -C '$target_root' -xf -"

printf '\n== target verification ==\n'
"$connect" "sha256sum '$target_bin' '$target_lib/libSDL3.so.0.2.6'"
printf '\n'
"$connect" "cd '$target_lib' && for link in libSDL3.so libSDL3.so.0 libSDL3.so.0.2.6; do printf '%s -> %s\n' \"\$link\" \"\$(readlink -f \"\$link\")\"; done"
printf '\n'
"$connect" "LD_LIBRARY_PATH='$target_lib' ldd '$target_bin' | sed -n '/libSDL3\\.so\\.0/p;/libwayland-client\\.so\\.0/p;/libwayland-egl\\.so\\.1/p;/libxkbcommon\\.so\\.0/p;/libEGL\\.so\\.1/p;/libGLESv2\\.so\\.2/p;/libmali\\.so\\.1/p'"
printf '\n'
"$connect" "set -e; sdl='$target_lib/libSDL3.so.0.2.6'; if command -v readelf >/dev/null 2>&1; then readelf -Ws \"\$sdl\"; else strings -a \"\$sdl\"; fi | grep -Eq 'Wayland_(VideoInit|CreateDevice)|SDL_WAYLAND|wl_display'"

printf '\nDeployment verified.\n'
