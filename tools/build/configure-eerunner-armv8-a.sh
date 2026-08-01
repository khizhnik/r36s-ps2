#!/usr/bin/env bash
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
build_dir="$root_dir/build/eerunner-armv8-a"
source_dir="$root_dir/upstream/armsx2"
preset="$root_dir/cmake/presets/eerunner-armv8-a.cmake"

cmake -S "$source_dir" -B "$build_dir" -G Ninja -C "$preset"
