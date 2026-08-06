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

require_dir() {
	local path="$1"
	local label="${2:-directory}"
	[[ -d "$path" ]] || die "missing ${label}: ${path}"
}

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
bundle_root="${BUNDLE_DIR:-$repo_root/deploy/native-wayland-shm}"
build_root="${BUILD_DIR:-$repo_root/build/native-wayland-shm}"
wayland_lib_root="$repo_root/build/sdl3-wayland-rebuild/wayland-libs"
bundle_bin="$bundle_root/bin/native-wayland-shm"
binary_src="$build_root/bin/native-wayland-shm"

require_dir "$build_root" "native Wayland SHM build tree"
require_file "$binary_src" "native Wayland SHM binary"
require_file "$wayland_lib_root/libwayland-client.so.0.25.0" "proven wayland-client library"

mkdir -p "$bundle_root/bin"
mkdir -p "$bundle_root/lib"
install -m 0755 "$binary_src" "$bundle_bin"
install -m 0644 "$wayland_lib_root/libwayland-client.so.0.25.0" "$bundle_root/lib/libwayland-client.so.0.25.0"
ln -sfn libwayland-client.so.0.25.0 "$bundle_root/lib/libwayland-client.so.0"
ln -sfn libwayland-client.so.0 "$bundle_root/lib/libwayland-client.so"

cat >"$bundle_root/MANIFEST.txt" <<EOF
Package: native-wayland-shm
Binary SHA256: $(sha256sum "$bundle_bin" | awk '{print $1}')
EOF

printf 'Packaged bundle: %s\n' "$bundle_root"
printf 'Binary SHA256: %s\n' "$(sha256sum "$bundle_bin" | awk '{print $1}')"
