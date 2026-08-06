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

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
connect="${CONNECT_HELPER:-$repo_root/tools/connect-r36s-wifi.sh}"
bundle_root="${BUNDLE_DIR:-$repo_root/deploy/sdl3-wayland-blue}"
target_root="${TARGET_DIR:-/storage/ports/sdl3-wayland-blue}"
verify_target_sha256="$(normalize_verify_target_sha256 "${VERIFY_TARGET_SHA256:-0}")"
target_bin="$target_root/bin/sdl3-wayland-blue"
target_lib="$target_root/lib"
bundle_bin="$bundle_root/bin/sdl3-wayland-blue"
bundle_sdl3="$bundle_root/lib/libSDL3.so.0.2.6"
timeout_seconds="${TIMEOUT_SECONDS:-45}"
blue_backend="${SDL_BLUE_BACKEND:-surface}"
wayland_debug="${WAYLAND_DEBUG:-}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
artifact_root="$repo_root/artifacts/sdl3-wayland-blue-run"
local_run_dir="$artifact_root/$timestamp"
remote_run_dir="$target_root/logs/blue-$timestamp"
target_sha256_status="skipped"
if [[ "$verify_target_sha256" -eq 1 ]]; then
	target_sha256_status="enabled"
fi

require_file() {
	local path="$1"
	local label="${2:-file}"
	[[ -e "$path" ]] || die "missing ${label}: ${path}"
}

require_file "$connect" "connection helper"
require_file "$bundle_bin" "packaged diagnostic binary"
require_file "$bundle_sdl3" "packaged SDL3"

mkdir -p "$local_run_dir"
ln -sfn "$local_run_dir" "$artifact_root/latest"

bundle_sha="$(sha256sum "$bundle_bin" | awk '{print $1}')"
sdl3_sha="$(sha256sum "$bundle_sdl3" | awk '{print $1}')"

cat >"$local_run_dir/run-info.txt" <<EOF
timestamp_utc=$timestamp
bundle_root=$bundle_root
target_root=$target_root
target_binary=$target_bin
target_lib=$target_lib
timeout_seconds=$timeout_seconds
verify_target_sha256=$verify_target_sha256
target_sha256_verification=$target_sha256_status
binary_sha256=$bundle_sha
sdl3_sha256=$sdl3_sha
HOME=$target_root/home
XDG_CONFIG_HOME=$target_root/home/.config
XDG_CACHE_HOME=$target_root/home/.cache
XDG_DATA_HOME=$target_root/home/.local/share
XDG_RUNTIME_DIR=/var/run/0-runtime-dir
WAYLAND_DISPLAY=wayland-1
SWAYSOCK=/var/run/0-runtime-dir/sway-ipc.0.sock
SDL_VIDEODRIVER=wayland
SDL_AUDIODRIVER=pulseaudio
DISPLAY=:0.0
LD_LIBRARY_PATH=$target_lib
MESA_NO_ERROR=1
MESA_SHADER_CACHE_DIR=/var/cache/mesa
MESA_SHADER_CACHE_MAX_SIZE=128MB
SDL_BLUE_BACKEND=$blue_backend
WAYLAND_DEBUG=${wayland_debug:-}
EOF

printf 'bundle_binary=%s\n' "$bundle_bin"
printf 'bundle_binary_sha256=%s\n' "$bundle_sha"
printf 'bundle_sdl3=%s\n' "$bundle_sdl3"
printf 'bundle_sdl3_sha256=%s\n' "$sdl3_sha"
printf 'verify_target_sha256=%s\n' "$verify_target_sha256"
printf 'target_sha256_verification=%s\n' "$target_sha256_status"
printf 'SDL_BLUE_BACKEND=%s\n' "$blue_backend"
printf 'WAYLAND_DEBUG=%s\n' "${wayland_debug:-<unset>}"
printf 'target_binary=%s\n' "$target_bin"
printf 'target_lib=%s\n' "$target_lib"
printf 'timeout_seconds=%s\n' "$timeout_seconds"
printf 'run_dir=%s\n' "$local_run_dir"

cat <<'REMOTE' | "$connect" sh -s -- "$target_root" "$remote_run_dir" "$timeout_seconds" "$verify_target_sha256" "$target_bin" "$target_lib" "$blue_backend" "$wayland_debug"
set -eu

target_root=$1
run_dir=$2
timeout_seconds=$3
verify_target_sha256=$4
target_binary=$5
target_lib=$6
blue_backend=$7
wayland_debug=$8
home_dir="$target_root/home"
target_sha256_status=skipped
if [ "$verify_target_sha256" -eq 1 ]; then
	target_sha256_status=enabled
fi

mkdir -p "$run_dir" "$home_dir/.config" "$home_dir/.cache" "$home_dir/.local/share"

capture_sway_state() {
	if ! command -v swaymsg >/dev/null 2>&1; then
		printf 'swaymsg=unavailable\n' >"$run_dir/sway-summary.txt"
		return 0
	fi

	sleep 5
	env \
		XDG_RUNTIME_DIR=/var/run/0-runtime-dir \
		WAYLAND_DISPLAY=wayland-1 \
		SWAYSOCK=/var/run/0-runtime-dir/sway-ipc.0.sock \
		swaymsg -t get_outputs -r >"$run_dir/sway-outputs.json" 2>/dev/null || true
	env \
		XDG_RUNTIME_DIR=/var/run/0-runtime-dir \
		WAYLAND_DISPLAY=wayland-1 \
		SWAYSOCK=/var/run/0-runtime-dir/sway-ipc.0.sock \
		swaymsg -t get_tree -r >"$run_dir/sway-tree.json" 2>/dev/null || true

	if command -v jq >/dev/null 2>&1 && [ -s "$run_dir/sway-outputs.json" ]; then
		{
			printf 'sway_window_title=%s\n' "sdl3-wayland-blue"
			jq -r '
				.[] |
				select(.focused == true) |
				"focused_output=\(.name)\n" +
				"display_id=\(.id)\n" +
				"mode=\(.current_mode.width // 0)x\(.current_mode.height // 0)@\(.current_mode.refresh // 0)\n" +
				"rect=\(.rect.width)x\(.rect.height)+\(.rect.x)+\(.rect.y)\n" +
				"scale=\(.scale // 1)\n" +
				"transform=\(.transform // 0)\n"
			' "$run_dir/sway-outputs.json"
			jq -r '
				recurse(.nodes[]?, .floating_nodes[]?) |
				select(((.name? // "") | ascii_downcase | contains("sdl3-wayland-blue")) or
				       ((.name? // "") | ascii_downcase | contains("blue")) or
				       ((.app_id? // "") | ascii_downcase | contains("sdl3-wayland-blue")) or
				       ((.app_id? // "") | ascii_downcase | contains("blue"))) |
				"window_found=true\n" +
				"name=\(.name // "<null>")\n" +
				"app_id=\(.app_id // "<null>")\n" +
				"visible=\(.visible // false)\n" +
				"focused=\(.focused // false)\n" +
				"fullscreen_mode=\(.fullscreen_mode // 0)\n" +
				"rect=\(.rect.width)x\(.rect.height)+\(.rect.x)+\(.rect.y)\n" +
				"window_rect=\(.window_rect.width)x\(.window_rect.height)+\(.window_rect.x)+\(.window_rect.y)\n" +
				"output=\(.output // "<null>")\n"
			' "$run_dir/sway-tree.json"
		} >"$run_dir/sway-summary.txt" 2>/dev/null || printf 'window_found=false\n' >"$run_dir/sway-summary.txt"
	else
		printf 'window_found=false\n' >"$run_dir/sway-summary.txt"
	fi
}

capture_sway_state &
snapshot_pid=$!

printf 'DIAG SDL_PRESENT enter\n'
printf 'DIAG SDL_PRESENT video_driver=wayland\n'
printf 'DIAG SDL_PRESENT display_count=target-side\n'

set +e
HOME="$home_dir" \
XDG_CONFIG_HOME="$home_dir/.config" \
XDG_CACHE_HOME="$home_dir/.cache" \
XDG_DATA_HOME="$home_dir/.local/share" \
XDG_RUNTIME_DIR=/var/run/0-runtime-dir \
WAYLAND_DISPLAY=wayland-1 \
SWAYSOCK=/var/run/0-runtime-dir/sway-ipc.0.sock \
SDL_VIDEODRIVER=wayland \
SDL_AUDIODRIVER=pulseaudio \
DISPLAY=:0.0 \
LD_LIBRARY_PATH="$target_lib" \
MESA_NO_ERROR=1 \
MESA_SHADER_CACHE_DIR=/var/cache/mesa \
MESA_SHADER_CACHE_MAX_SIZE=128MB \
SDL_BLUE_BACKEND="$blue_backend" \
WAYLAND_DEBUG="$wayland_debug" \
timeout --kill-after=5s "${timeout_seconds}s" "$target_binary" \
	>"$run_dir/stdout-stderr.txt" 2>&1
status=$?
set -e

printf '%s\n' "$status" >"$run_dir/exit-status.txt"
if [ "$status" -ge 128 ]; then
	printf '%s\n' "$((status - 128))" >"$run_dir/signal.txt"
fi

wait "$snapshot_pid" || true

if [ -s "$run_dir/stdout-stderr.txt" ]; then
	cp "$run_dir/stdout-stderr.txt" "$run_dir/emulog.txt"
else
	: >"$run_dir/emulog.txt"
fi

printf 'DIAG SDL_PRESENT exit\n'
REMOTE

printf '\n== retrieving target logs ==\n'
"$connect" "tar -C '$remote_run_dir' -cf - ." | tar -C "$local_run_dir" -xf -

printf '\n== run summary ==\n'
printf 'logs=%s\n' "$local_run_dir"
if [[ -f "$local_run_dir/exit-status.txt" ]]; then
	printf 'exit-status=%s\n' "$(cat "$local_run_dir/exit-status.txt")"
fi
if [[ -f "$local_run_dir/signal.txt" ]]; then
	printf 'signal=%s\n' "$(cat "$local_run_dir/signal.txt")"
fi

if [[ -f "$local_run_dir/run-info.txt" ]]; then
	sed -n '1,30p' "$local_run_dir/run-info.txt"
fi

if [[ -f "$local_run_dir/emulog.txt" ]]; then
	printf '\n== emulog tail ==\n'
	tail -n 80 "$local_run_dir/emulog.txt"
fi

if [[ -f "$local_run_dir/exit-status.txt" ]]; then
	exit "$(cat "$local_run_dir/exit-status.txt")"
fi
exit 1
