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

sha256_of() {
	sha256sum "$1" | awk '{print $1}'
}

file_size() {
	stat -c '%s' "$1"
}

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
connect="${CONNECT_HELPER:-$repo_root/tools/connect-r36s-wifi.sh}"
bundle_root="${BUNDLE_DIR:-$repo_root/deploy/pcsx2-sdl-r36s-diag}"
target_root="${TARGET_DIR:-/storage/ports/pcsx2-sdl-r36s-diag}"
verify_target_sha256="$(normalize_verify_target_sha256 "${VERIFY_TARGET_SHA256:-0}")"
target_binary="$target_root/bin/armsx2-sdl"
target_lib="$target_root/lib"
bundle_binary="$bundle_root/bin/armsx2-sdl"
bundle_sdl3="$bundle_root/lib/libSDL3.so.0.2.6"
build_resources="$repo_root/build/pcsx2-sdl-r36s/bin/resources"
iso_source="${ISO_SOURCE:-/storage/ports/pcsx2-eerunner-smoke/.config/ARMSX2/discs/Grand Theft Auto - Vice City (Europe) (En,Fr,De,Es,It) (v3.00).iso}"
timeout_seconds="${TIMEOUT_SECONDS:-60}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
artifact_root="$repo_root/artifacts/pcsx2-sdl-r36s-graphical-run"
local_run_dir="$artifact_root/$timestamp"
remote_run_dir="$target_root/logs/run-$timestamp"
target_sha256_status="skipped"
if [[ "$verify_target_sha256" -eq 1 ]]; then
	target_sha256_status="enabled"
fi

require_file "$connect" "connection helper"
require_file "$bundle_binary" "packaged binary"
require_file "$bundle_sdl3" "packaged SDL3"
require_dir "$build_resources" "build resources directory"
mkdir -p "$local_run_dir"
ln -sfn "$local_run_dir" "$artifact_root/latest"

binary_sha="$(sha256_of "$bundle_binary")"
sdl3_sha="$(sha256_of "$bundle_sdl3")"
remote_cmd="TARGET_ROOT=${target_root@Q} RUN_DIR=${remote_run_dir@Q} ISO_SOURCE=${iso_source@Q} TIMEOUT_SECONDS=${timeout_seconds@Q} VERIFY_TARGET_SHA256=${verify_target_sha256@Q} sh -s"

cat >"$local_run_dir/run-info.txt" <<EOF
timestamp_utc=$timestamp
bundle_root=$bundle_root
target_root=$target_root
target_binary=$target_binary
target_lib=$target_lib
iso_source=$iso_source
iso_resolved=target-side
iso_sha256=target-side
iso_size=target-side
timeout_seconds=$timeout_seconds
verify_target_sha256=$verify_target_sha256
target_sha256_verification=$target_sha256_status
binary_sha256=$binary_sha
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
EOF

{
	printf 'bundle_root=%s\n' "$bundle_root"
	printf 'bundle_binary=%s\n' "$bundle_binary"
printf 'bundle_binary_sha256=%s\n' "$binary_sha"
printf 'bundle_sdl3=%s\n' "$bundle_sdl3"
printf 'bundle_sdl3_sha256=%s\n' "$sdl3_sha"
printf 'build_resources=%s\n' "$build_resources"
printf 'verify_target_sha256=%s\n' "$verify_target_sha256"
printf 'target_sha256_verification=%s\n' "$target_sha256_status"
printf 'build_resources_listing=\n'
find "$build_resources" -mindepth 1 -maxdepth 2 -printf '%P\n' | sort
printf 'iso_source=%s\n' "$iso_source"
	printf 'iso_resolved=target-side\n'
	printf 'iso_sha256=target-side\n'
	printf 'iso_size=target-side\n'
} >"$local_run_dir/preflight-host.txt"

printf '%s\n' "bundle_root=$bundle_root"
printf '%s\n' "target_root=$target_root"
printf '%s\n' "binary=$target_binary"
printf '%s\n' "binary_sha256=$binary_sha"
printf '%s\n' "sdl3_sha256=$sdl3_sha"
printf '%s\n' "iso_source=$iso_source"
printf '%s\n' "timeout_seconds=$timeout_seconds"
printf '%s\n' "run_dir=$local_run_dir"

cat <<'REMOTE' | "$connect" "$remote_cmd"
set -eu

target_root=$TARGET_ROOT
run_dir=$RUN_DIR
iso_source=$ISO_SOURCE
timeout_seconds=$TIMEOUT_SECONDS
verify_target_sha256=$VERIFY_TARGET_SHA256
target_binary="$target_root/bin/armsx2-sdl"
target_lib="$target_root/lib"
home_dir="$target_root/home"
bios_dir_link="$home_dir/.config/ARMSX2/bios"
bios_dir="$(readlink -f "$bios_dir_link")"
resources_dir="$target_root/bin/resources"
target_sha256_status=skipped
if [ "$verify_target_sha256" -eq 1 ]; then
	target_sha256_status=enabled
fi

mkdir -p "$run_dir" "$home_dir/.config" "$home_dir/.cache" "$home_dir/.local/share"
ln -sfn "$iso_source" /tmp/vicecity.iso

resolved_iso="$(readlink -f "$iso_source")"
if [ ! -f "$resolved_iso" ]; then
	printf 'error=missing ISO image on target: %s\n' "$iso_source"
	exit 1
fi
resolved_iso_sha256="skipped"
resolved_iso_size="$(stat -c '%s' "$resolved_iso")"
if [ "$verify_target_sha256" -eq 1 ]; then
	resolved_iso_sha256="$(sha256sum "$resolved_iso" | awk '{print $1}')"
fi
target_binary_sha256="skipped"
target_sdl3_sha256="skipped"
selected_bios_sha256="skipped"
if [ "$verify_target_sha256" -eq 1 ]; then
	target_binary_sha256="$(sha256sum "$target_binary" | awk '{print $1}')"
	target_sdl3_sha256="$(sha256sum "$target_lib/libSDL3.so.0.2.6" | awk '{print $1}')"
fi

{
	printf 'target_root=%s\n' "$target_root"
	printf 'run_dir=%s\n' "$run_dir"
	printf 'target_binary=%s\n' "$target_binary"
	printf 'target_lib=%s\n' "$target_lib"
	printf 'iso_source=%s\n' "$iso_source"
	printf 'timeout_seconds=%s\n' "$timeout_seconds"
	printf 'verify_target_sha256=%s\n' "$verify_target_sha256"
	printf 'target_sha256_verification=%s\n' "$target_sha256_status"
	printf 'HOME=%s\n' "$home_dir"
	printf 'XDG_CONFIG_HOME=%s\n' "$home_dir/.config"
	printf 'XDG_CACHE_HOME=%s\n' "$home_dir/.cache"
	printf 'XDG_DATA_HOME=%s\n' "$home_dir/.local/share"
	printf 'XDG_RUNTIME_DIR=%s\n' "/var/run/0-runtime-dir"
	printf 'WAYLAND_DISPLAY=%s\n' "wayland-1"
	printf 'SWAYSOCK=%s\n' "/var/run/0-runtime-dir/sway-ipc.0.sock"
	printf 'SDL_VIDEODRIVER=%s\n' "wayland"
	printf 'SDL_AUDIODRIVER=%s\n' "pulseaudio"
	printf 'DISPLAY=%s\n' ":0.0"
	printf 'LD_LIBRARY_PATH=%s\n' "$target_lib"
	printf 'MESA_NO_ERROR=%s\n' "1"
	printf 'MESA_SHADER_CACHE_DIR=%s\n' "/var/cache/mesa"
	printf 'MESA_SHADER_CACHE_MAX_SIZE=%s\n' "128MB"
} >"$run_dir/run-info.txt"

{
	printf 'target_root=%s\n' "$target_root"
	printf 'target_binary=%s\n' "$target_binary"
	printf 'target_binary_file=%s\n' "$(file -b "$target_binary")"
	printf 'target_binary_stat=%s\n' "$(stat -c '%n size=%s mtime=%Y mode=%a' "$target_binary")"
	printf 'target_binary_sha256=%s\n' "$target_binary_sha256"
	printf 'target_lib=%s\n' "$target_lib"
	printf 'target_sdl3=%s\n' "$target_lib/libSDL3.so.0.2.6"
		printf 'target_sdl3_stat=%s\n' "$(stat -c '%n size=%s mtime=%Y mode=%a' "$target_lib/libSDL3.so.0.2.6")"
		printf 'target_sdl3_sha256=%s\n' "$target_sdl3_sha256"
		printf 'target_sdl3_link_libSDL3.so=%s\n' "$(readlink "$target_lib/libSDL3.so")"
		printf 'target_sdl3_link_libSDL3.so.0=%s\n' "$(readlink "$target_lib/libSDL3.so.0")"
		printf 'target_resources=%s\n' "$resources_dir"
	printf 'target_resources_listing=\n'
	find "$resources_dir" -mindepth 1 -maxdepth 2 -printf '%P\n' | sort
	printf 'resolved_iso=%s\n' "$resolved_iso"
	printf 'resolved_iso_sha256=%s\n' "$resolved_iso_sha256"
	printf 'resolved_iso_size=%s\n' "$resolved_iso_size"
	printf 'bios_dir_link=%s\n' "$bios_dir_link"
	printf 'bios_dir=%s\n' "$bios_dir"
	selected_bios="$(find "$bios_dir" -maxdepth 1 -type f | sort | head -n 1 || true)"
	[ -n "$selected_bios" ] || { printf 'error=missing BIOS file\n'; exit 1; }
	if [ "$verify_target_sha256" -eq 1 ]; then
		selected_bios_sha256="$(sha256sum "$selected_bios" | awk '{print $1}')"
	fi
	printf 'selected_bios=%s\n' "$selected_bios"
	printf 'selected_bios_sha256=%s\n' "$selected_bios_sha256"
	printf 'selected_bios_size=%s\n' "$(stat -c '%s' "$selected_bios")"
	printf 'ldd_with_bundle_ld_library_path=\n'
	LD_LIBRARY_PATH="$target_lib" ldd "$target_binary"
} >"$run_dir/preflight-target.txt"

capture_sway_state() {
	local sway_outputs_json="$run_dir/sway-outputs.json"
	local sway_tree_json="$run_dir/sway-tree.json"
	local sway_summary_txt="$run_dir/sway-summary.txt"
	local sway_window_title="ARMSX2"

	if ! command -v swaymsg >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
		printf 'swaymsg_or_jq=unavailable\n' >"$sway_summary_txt"
		return 0
	fi

	sleep 6
	env \
		XDG_RUNTIME_DIR=/var/run/0-runtime-dir \
		WAYLAND_DISPLAY=wayland-1 \
		SWAYSOCK=/var/run/0-runtime-dir/sway-ipc.0.sock \
		swaymsg -t get_outputs -r >"$sway_outputs_json" 2>/dev/null || true
	env \
		XDG_RUNTIME_DIR=/var/run/0-runtime-dir \
		WAYLAND_DISPLAY=wayland-1 \
		SWAYSOCK=/var/run/0-runtime-dir/sway-ipc.0.sock \
		swaymsg -t get_tree -r >"$sway_tree_json" 2>/dev/null || true
	if [ -s "$sway_tree_json" ]; then
		printf 'sway_window_title=%s\n' "$sway_window_title" >"$sway_summary_txt"
		jq -r --arg title "$sway_window_title" '
			recurse(.nodes[]?, .floating_nodes[]?) |
			select(((.name? // "") | ascii_downcase | contains("armsx2")) or
			       ((.name? // "") | ascii_downcase | contains("pcsx2")) or
			       ((.name? // "") | ascii_downcase | contains("sdl")) or
			       ((.app_id? // "") | ascii_downcase | contains("armsx2")) or
			       ((.app_id? // "") | ascii_downcase | contains("pcsx2")) or
			       ((.app_id? // "") | ascii_downcase | contains("sdl"))) |
			"window_found=true\n" +
			"name=\(.name // "<null>")\n" +
			"app_id=\(.app_id // "<null>")\n" +
			"visible=\(.visible // false)\n" +
			"focused=\(.focused // false)\n" +
			"fullscreen_mode=\(.fullscreen_mode // 0)\n" +
			"rect=\(.rect.width)x\(.rect.height)+\(.rect.x)+\(.rect.y)\n" +
			"window_rect=\(.window_rect.width)x\(.window_rect.height)+\(.window_rect.x)+\(.window_rect.y)\n" +
			"output=\(.output // "<null>")\n" +
			"app_id_or_name=\(.app_id // .name // "<null>")\n"
		' "$sway_tree_json" >>"$sway_summary_txt" 2>/dev/null || printf 'window_found=false\n' >>"$sway_summary_txt"
		jq -r '
			.[] |
			select(.focused == true) |
			"focused_output=\(.name)\n" +
			"mode=\(.current_mode.width // 0)x\(.current_mode.height // 0)\n" +
			"rect=\(.rect.width)x\(.rect.height)+\(.rect.x)+\(.rect.y)\n" +
			"scale=\(.scale // 1)\n" +
			"transform=\(.transform // 0)\n"
		' "$sway_outputs_json" >>"$sway_summary_txt" 2>/dev/null || true
	else
		printf 'window_found=false\n' >"$sway_summary_txt"
	fi
	return 0
}

capture_sway_state &
sway_snapshot_pid=$!

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
timeout --kill-after=5s "${timeout_seconds}s" "$target_binary" /tmp/vicecity.iso \
  >"$run_dir/stdout-stderr.txt" 2>&1
status=$?
set -e

wait "$sway_snapshot_pid" || true

printf '%s\n' "$status" >"$run_dir/exit-status.txt"
if [ "$status" -ge 128 ]; then
	printf '%s\n' "$((status - 128))" >"$run_dir/signal.txt"
fi

emulog_source="$(find "$home_dir/.config/ARMSX2/logs" -maxdepth 1 -type f 2>/dev/null | sort | tail -n 1 || true)"
if [ -n "$emulog_source" ]; then
	cp "$emulog_source" "$run_dir/emulog.txt"
else
	cp "$run_dir/stdout-stderr.txt" "$run_dir/emulog.txt"
fi
REMOTE

require_file "$local_run_dir/run-info.txt" "local run info"
require_file "$local_run_dir/preflight-host.txt" "local preflight host info"

printf '\n== retrieving target logs ==\n'
"$connect" "tar -C '$remote_run_dir' -cf - ." | tar -C "$local_run_dir" -xf -

if [[ ! -f "$local_run_dir/emulog.txt" ]]; then
	cp "$local_run_dir/stdout-stderr.txt" "$local_run_dir/emulog.txt"
fi

printf '\n== process check ==\n'
"$connect" "pgrep -af 'armsx2-sdl|timeout --kill-after=5s' || true"

printf '\n== run summary ==\n'
if [[ -f "$local_run_dir/exit-status.txt" ]]; then
	printf 'exit-status=%s\n' "$(cat "$local_run_dir/exit-status.txt")"
fi
if [[ -f "$local_run_dir/signal.txt" ]]; then
	printf 'signal=%s\n' "$(cat "$local_run_dir/signal.txt")"
fi
printf 'logs=%s\n' "$local_run_dir"
if [[ -f "$local_run_dir/exit-status.txt" ]]; then
	exit "$(cat "$local_run_dir/exit-status.txt")"
fi
exit 1
