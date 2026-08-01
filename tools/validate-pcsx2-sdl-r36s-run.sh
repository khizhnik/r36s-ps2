#!/usr/bin/env bash
set -euo pipefail

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

require_file() {
	local path="$1"
	local label="${2:-file}"
	[[ -f "$path" ]] || die "missing ${label}: ${path}"
}

artifact_dir="${1:-}"
expected_signal="${2:-6}"

[[ -n "$artifact_dir" ]] || die "usage: $0 <artifact-dir> [expected-signal]"
[[ "$expected_signal" =~ ^[0-9]+$ ]] || die "expected signal must be numeric"

expected_status=$((128 + expected_signal))

require_file "$artifact_dir/run-info.txt" "run info"
require_file "$artifact_dir/preflight-host.txt" "host preflight"
require_file "$artifact_dir/preflight-target.txt" "target preflight"
require_file "$artifact_dir/stdout-stderr.txt" "stdout/stderr log"
require_file "$artifact_dir/emulog.txt" "emulog"
require_file "$artifact_dir/exit-status.txt" "exit status"
require_file "$artifact_dir/signal.txt" "signal"

actual_status="$(cat "$artifact_dir/exit-status.txt")"
actual_signal="$(cat "$artifact_dir/signal.txt")"

[[ "$actual_status" == "$expected_status" ]] || die "unexpected exit status: ${actual_status} (expected ${expected_status})"
[[ "$actual_signal" == "$expected_signal" ]] || die "unexpected signal: ${actual_signal} (expected ${expected_signal})"

combined="$artifact_dir/_combined.log"
cat "$artifact_dir/stdout-stderr.txt" "$artifact_dir/emulog.txt" >"$combined"

markers=(
	"DIAG SDLInputSource::InitializeSubsystem post-init SDL_GetVideoDriver(0)=wayland"
	"DIAG BuildWaylandWindowInfo: after SDL_InitSubSystem(SDL_INIT_VIDEO) success"
	"DIAG BuildWaylandWindowInfo: SDL_CreateWindow success"
	"DIAG BuildWindowInfo: return Wayland"
	"DIAG Host::AcquireRenderWindow: exit"
	"DIAG GSopen: exit true"
)

prev_line=0
for marker in "${markers[@]}"; do
	line="$(grep -nF "$marker" "$combined" | head -n1 | cut -d: -f1 || true)"
	[[ -n "$line" ]] || die "missing required marker: $marker"
	[[ "$line" -gt "$prev_line" ]] || die "marker out of order: $marker"
	prev_line="$line"
done

require_file "$artifact_dir/preflight-host.txt" "host preflight"
require_file "$artifact_dir/preflight-target.txt" "target preflight"

grep -q '^iso_resolved=target-side$' "$artifact_dir/preflight-host.txt" || die "missing target-side ISO placeholder in host preflight"
grep -q '^bundle_sdl3_sha256=7c8e71e6ccfd2673f1a9e3181d422d623fdb5773e9dece02474ee7c93be1d731$' "$artifact_dir/preflight-host.txt" || die "unexpected host SDL3 sha256"
grep -q '^selected_bios=' "$artifact_dir/preflight-target.txt" || die "missing selected BIOS in target preflight"
grep -q '^selected_bios_sha256=' "$artifact_dir/preflight-target.txt" || die "missing selected BIOS sha256 in target preflight"
grep -q '^resolved_iso=' "$artifact_dir/preflight-target.txt" || die "missing resolved ISO in target preflight"
grep -q '^resolved_iso_sha256=' "$artifact_dir/preflight-target.txt" || die "missing resolved ISO sha256 in target preflight"
grep -q '^target_sdl3_sha256=7c8e71e6ccfd2673f1a9e3181d422d623fdb5773e9dece02474ee7c93be1d731$' "$artifact_dir/preflight-target.txt" || die "unexpected target SDL3 sha256"
grep -q '^ldd_with_bundle_ld_library_path=' "$artifact_dir/preflight-target.txt" || die "missing ldd header in target preflight"
grep -q 'libSDL3.so.0 => /storage/ports/pcsx2-sdl-r36s-diag/lib/libSDL3.so.0' "$artifact_dir/preflight-target.txt" || die "bundle LD_LIBRARY_PATH did not resolve libSDL3.so.0"
grep -q '^SDL_VIDEODRIVER=wayland$' "$artifact_dir/run-info.txt" || die "missing SDL_VIDEODRIVER in run info"

printf 'validated artifact dir: %s\n' "$artifact_dir"
printf 'expected status: %s\n' "$expected_status"
printf 'expected signal: %s\n' "$expected_signal"
printf 'markers: confirmed in order\n'
