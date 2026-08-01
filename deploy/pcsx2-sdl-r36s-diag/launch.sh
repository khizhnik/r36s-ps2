#!/usr/bin/env bash
set -euo pipefail

bundle_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LD_LIBRARY_PATH="${bundle_dir}/lib"
exec "${bundle_dir}/bin/armsx2-sdl" "$@"
