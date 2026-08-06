#!/usr/bin/env bash
set -euo pipefail

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
connect="${CONNECT_HELPER:-$repo_root/tools/connect-r36s-wifi.sh}"
bundle_root="${BUNDLE_DIR:-$repo_root/deploy/native-wayland-shm}"
target_root="${TARGET_DIR:-/storage/ports/native-wayland-shm}"
target_bin="$target_root/bin/native-wayland-shm"
target_lib="$target_root/lib"
timeout_seconds="${TIMEOUT_SECONDS:-10}"
wayland_debug="${WAYLAND_DEBUG:-}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
artifact_root="$repo_root/artifacts/native-wayland-shm-run"
local_run_dir="$artifact_root/$timestamp"
remote_run_dir="$target_root/logs/native-$timestamp"

[[ -x "$bundle_root/bin/native-wayland-shm" ]] || die "missing packaged binary"
[[ -e "$connect" ]] || die "missing connection helper"

mkdir -p "$local_run_dir"
ln -sfn "$local_run_dir" "$artifact_root/latest"

cat >"$local_run_dir/run-info.txt" <<EOF
timestamp_utc=$timestamp
bundle_root=$bundle_root
target_root=$target_root
target_binary=$target_bin
timeout_seconds=$timeout_seconds
WAYLAND_DEBUG=${wayland_debug:-<unset>}
XDG_RUNTIME_DIR=/var/run/0-runtime-dir
WAYLAND_DISPLAY=wayland-1
SWAYSOCK=/var/run/0-runtime-dir/sway-ipc.0.sock
EOF

cat <<'REMOTE' | "$connect" sh -s -- "$target_root" "$remote_run_dir" "$timeout_seconds" "$wayland_debug" "$target_bin" "$target_lib"
set -eu

target_root=$1
run_dir=$2
timeout_seconds=$3
wayland_debug=$4
target_bin=$5
target_lib=$6

mkdir -p "$run_dir"

set +e
HOME=/storage \
XDG_RUNTIME_DIR=/var/run/0-runtime-dir \
WAYLAND_DISPLAY=wayland-1 \
SWAYSOCK=/var/run/0-runtime-dir/sway-ipc.0.sock \
LD_LIBRARY_PATH="$target_lib" \
WAYLAND_DEBUG="$wayland_debug" \
timeout --kill-after=5s "${timeout_seconds}s" "$target_bin" \
	>"$run_dir/stdout-stderr.txt" 2>&1
status=$?
set -e

printf '%s\n' "$status" >"$run_dir/exit-status.txt"
if [ -s "$run_dir/stdout-stderr.txt" ]; then
	cp "$run_dir/stdout-stderr.txt" "$run_dir/emulog.txt"
else
	: >"$run_dir/emulog.txt"
fi
REMOTE

printf '\n== retrieving target logs ==\n'
"$connect" "tar -C '$remote_run_dir' -cf - ." | tar -C "$local_run_dir" -xf -

printf '\n== run summary ==\n'
printf 'logs=%s\n' "$local_run_dir"
if [[ -f "$local_run_dir/exit-status.txt" ]]; then
	printf 'exit-status=%s\n' "$(cat "$local_run_dir/exit-status.txt")"
fi
if [[ -f "$local_run_dir/emulog.txt" ]]; then
	printf '\n== emulog tail ==\n'
	tail -n 80 "$local_run_dir/emulog.txt"
fi

if [[ -f "$local_run_dir/exit-status.txt" ]]; then
	exit "$(cat "$local_run_dir/exit-status.txt")"
fi
exit 1
