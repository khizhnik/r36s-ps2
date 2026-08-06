#!/usr/bin/env bash
set -euo pipefail

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

require_file() {
	local path="$1"
	local label="${2:-file}"
	[[ -e "$path" ]] || die "missing ${label}: ${path}"
}

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
connect="${CONNECT_HELPER:-$repo_root/tools/connect-r36s-wifi.sh}"
bundle_root="${BUNDLE_DIR:-$repo_root/deploy/native-wayland-shm}"
target_root="${TARGET_DIR:-/storage/ports/native-wayland-shm}"
target_bin="$target_root/bin/native-wayland-shm"

require_file "$connect" "connection helper"
require_file "$bundle_root/bin/native-wayland-shm" "packaged binary"

printf 'Deploying bundle %s -> %s\n' "$bundle_root" "$target_root"
tar -C "$bundle_root" -cf - . | "$connect" "mkdir -p '$target_root' && tar -C '$target_root' -xf -"
printf '\nDeployment verified.\n'
