#!/usr/bin/env bash
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
build_dir="$root_dir/build/eerunner-cortex-a35"
source_dir="$root_dir/upstream/armsx2"
preset="$root_dir/cmake/presets/eerunner-cortex-a35.cmake"

cmake -S "$source_dir" -B "$build_dir" -G Ninja -C "$preset"
