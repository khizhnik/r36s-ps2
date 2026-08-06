#!/usr/bin/env bash
set -euo pipefail

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

normalize_verify_target_sha256() {
	local raw_value="${1:-0}"
	case "${raw_value,,}" in
		0|false|no)
			printf '0\n'
			;;
		1|true|yes)
			printf '1\n'
			;;
		*)
			die "invalid VERIFY_TARGET_SHA256 value: ${raw_value} (expected 0/false/no or 1/true/yes)"
			;;
	esac
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
verify_target_sha256="$(normalize_verify_target_sha256 "${VERIFY_TARGET_SHA256:-0}")"

require_dir "$bundle_root" "packaged bundle"
require_file "$bundle_root/bin/armsx2-sdl" "packaged binary"
require_file "$bundle_root/lib/libSDL3.so.0.2.6" "packaged SDL3"
require_file "$connect" "connection helper"

printf 'Deploying bundle %s -> %s\n' "$bundle_root" "$target_root"
tar -C "$bundle_root" -cf - . | "$connect" "mkdir -p '$target_root' && tar -C '$target_root' -xf -"

printf '\n== target verification ==\n'
printf 'verify_target_sha256=%s\n' "$verify_target_sha256"
if [[ "$verify_target_sha256" -eq 1 ]]; then
	printf 'target_sha256_verification=enabled\n'
	"$connect" "sha256sum '$target_bin' '$target_lib/libSDL3.so.0.2.6'"
	printf 'target_sha256_verification=completed\n'
else
	printf 'target_sha256_verification=skipped\n'
	"$connect" "set -e; test -x '$target_bin'; test -r '$target_lib/libSDL3.so.0.2.6'; test -L '$target_lib/libSDL3.so'; test -L '$target_lib/libSDL3.so.0'; stat -c '%n size=%s mtime=%Y mode=%a' '$target_bin' '$target_lib/libSDL3.so.0.2.6'; readlink '$target_lib/libSDL3.so'; readlink '$target_lib/libSDL3.so.0'"
fi
printf '\n'
"$connect" "cd '$target_lib' && for link in libSDL3.so libSDL3.so.0 libSDL3.so.0.2.6; do printf '%s -> %s\n' \"\$link\" \"\$(readlink -f \"\$link\")\"; done"
printf '\n'
"$connect" "LD_LIBRARY_PATH='$target_lib' ldd '$target_bin' | sed -n '/libSDL3\\.so\\.0/p;/libwayland-client\\.so\\.0/p;/libwayland-egl\\.so\\.1/p;/libxkbcommon\\.so\\.0/p;/libEGL\\.so\\.1/p;/libGLESv2\\.so\\.2/p;/libmali\\.so\\.1/p'"
printf '\n'
"$connect" "set -e; sdl='$target_lib/libSDL3.so.0.2.6'; if command -v readelf >/dev/null 2>&1; then readelf -Ws \"\$sdl\"; else strings -a \"\$sdl\"; fi | grep -Eq 'Wayland_(VideoInit|CreateDevice)|SDL_WAYLAND|wl_display'"

printf '\nDeployment verified.\n'
