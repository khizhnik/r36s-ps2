#!/usr/bin/env bash
set -euo pipefail

bundle_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
binary="${bundle_dir}/bin/sdl3-wayland-blue"

printf 'bundle_dir=%s\n' "$bundle_dir"
printf 'binary=%s\n' "$binary"
printf 'sha256(binary)=%s\n' "$(sha256sum "$binary" | awk '{print $1}')"
printf 'sha256(SDL3)=%s\n' "$(sha256sum "${bundle_dir}/lib/libSDL3.so.0.2.6" | awk '{print $1}')"
printf '\n'
LD_LIBRARY_PATH="${bundle_dir}/lib" ldd "$binary" || true
