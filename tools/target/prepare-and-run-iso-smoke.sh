#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  prepare-and-run-iso-smoke.sh --disc PATH --bios PATH --state PATH [options]

Options:
  --bundle PATH          Local bundle directory (default: deploy/r36s-pcsx2-eerunner-smoke)
  --target-dir PATH      Target directory on R36S (default: /storage/ports/pcsx2-eerunner-smoke)
  --mkstate-frames N     Frames to run while creating the savestate (default: 300)
  --runtime-mode MODE    Replay mode after mkstate (default: stepdiff)
  --execute              Actually deploy and run. Without this flag the script only prints the plan.
  --help                 Show this help.

Supported runtime modes for the second run:
  stepdiff | localize | repro | contmem | vu0diff | selfcheck | liverun

Notes:
  - The BIOS argument must point to the raw .bin, not the ZIP archive.
  - The disc argument may point to .iso, .img, .bin, or .chd if the format is supported by the current build.
  - The first replay mode defaults to stepdiff because it is the first JIT-bearing mode that also localizes divergences.
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "${script_dir}/../.." && pwd)"
connect="${root_dir}/tools/connect-r36s-wifi.sh"

bundle_dir="${root_dir}/deploy/r36s-pcsx2-eerunner-smoke"
target_dir="/storage/ports/pcsx2-eerunner-smoke"
runtime_mode="stepdiff"
mkstate_frames="300"
disc_path=""
bios_path=""
state_path=""
execute=0

while (($#)); do
  case "$1" in
    --bundle)
      shift || die "--bundle needs a path"
      bundle_dir="${1:-}"
      ;;
    --target-dir)
      shift || die "--target-dir needs a path"
      target_dir="${1:-}"
      ;;
    --disc)
      shift || die "--disc needs a path"
      disc_path="${1:-}"
      ;;
    --bios)
      shift || die "--bios needs a path"
      bios_path="${1:-}"
      ;;
    --state)
      shift || die "--state needs a path"
      state_path="${1:-}"
      ;;
    --mkstate-frames)
      shift || die "--mkstate-frames needs a value"
      mkstate_frames="${1:-}"
      ;;
    --runtime-mode)
      shift || die "--runtime-mode needs a value"
      runtime_mode="${1:-}"
      ;;
    --execute)
      execute=1
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
  shift || true
done

[[ -n "$disc_path" ]] || die "--disc is required"
[[ -n "$bios_path" ]] || die "--bios is required"
[[ -n "$state_path" ]] || die "--state is required"
[[ -d "$bundle_dir" ]] || die "bundle directory missing: $bundle_dir"
[[ -x "$connect" ]] || die "connect helper missing or not executable: $connect"

case "$runtime_mode" in
  selfcheck|stepdiff|localize|repro|contmem|vu0diff|liverun)
    ;;
  *)
    die "unsupported runtime mode: $runtime_mode"
    ;;
esac

bundle_bin="$bundle_dir/bin/pcsx2-eerunner"
bundle_launch="$bundle_dir/launch.sh"
bundle_diag="$bundle_dir/diagnostic.sh"

[[ -x "$bundle_bin" ]] || die "bundle binary missing: $bundle_bin"
[[ -x "$bundle_launch" ]] || die "bundle launcher missing: $bundle_launch"
[[ -x "$bundle_diag" ]] || die "bundle diagnostic missing: $bundle_diag"

plan_dir="${root_dir}/artifacts/pcsx2-iso-smoke/$(date -u +%Y%m%dT%H%M%SZ)"
target_data_root="${target_dir}/.config/ARMSX2"
target_home="${target_dir}/.home"
target_cache="${target_dir}/.cache"
target_data_home="${target_dir}/.local/share"
target_bios_dir="${target_data_root}/bios"
target_disc_dir="${target_data_root}/discs"
target_states_dir="${target_data_root}/sstates"
target_logs_dir="${target_data_root}/logs"

disc_kind_from_path() {
  local path="$1"
  local ext="${path##*.}"
  case "${ext,,}" in
    iso|img|bin|chd) printf '%s\n' "${ext,,}" ;;
    *) printf 'unknown\n' ;;
  esac
}

disc_kind="$(disc_kind_from_path "$disc_path")"
disc_file_output="$(file "$disc_path")"

if [[ "$execute" -eq 1 ]]; then
  case "$disc_kind" in
    iso|img|bin)
      ;;
    chd)
      command -v chdman >/dev/null 2>&1 || die "CHD input requires chdman for fingerprinting/validation"
      ;;
    *)
      die "unsupported disc format: $disc_path"
      ;;
  esac
fi

fingerprint_disc() {
  case "$disc_kind" in
    iso|img|bin)
      isoinfo -d -i "$disc_path"
      printf '\n'
      isoinfo -R -x '/SYSTEM.CNF;1' -i "$disc_path" | tr -d '\r'
      ;;
    chd)
      if command -v chdman >/dev/null 2>&1; then
        chdman info -i "$disc_path"
      else
        printf 'CHD fingerprint requires chdman; only file(1) metadata available locally.\n'
      fi
      ;;
    *)
      printf 'Unknown disc format; only file(1) metadata available locally.\n'
      ;;
  esac
}

write_disc_system_cnf() {
  local out="$1"
  case "$disc_kind" in
    iso|img|bin)
      isoinfo -R -x '/SYSTEM.CNF;1' -i "$disc_path" | tr -d '\r' >"$out"
      ;;
    chd)
      : >"$out"
      printf 'SYSTEM.CNF extraction for CHD is not available without chdman.\n' >&2
      ;;
    *)
      : >"$out"
      ;;
  esac
}

validate_target_bios_dir() {
  local bios_dir="$1"
  local -a valid=()
  local bios_file size

  shopt -s nullglob
  for bios_file in "$bios_dir"/*; do
    [[ -f "$bios_file" ]] || continue
    size="$(stat -c '%s' "$bios_file")"
    if (( size < 4 * 1024 * 1024 || size > 8 * 1024 * 1024 )); then
      continue
    fi
    if grep -a -m1 -q 'RESET' "$bios_file" && grep -a -m1 -q 'ROMVER' "$bios_file"; then
      valid+=("$bios_file")
    fi
  done
  shopt -u nullglob

  if (( ${#valid[@]} != 1 )); then
    printf 'error: expected exactly one valid BIOS in %s, found %d\n' "$bios_dir" "${#valid[@]}" >&2
    if (( ${#valid[@]} == 0 )); then
      printf '  no BIOS matched size + signature checks\n' >&2
    else
      printf '  valid BIOS candidates:\n' >&2
      printf '    %s\n' "${valid[@]}" >&2
    fi
    return 1
  fi

  printf '%s\n' "${valid[0]}"
}

printf 'Plan only (no execution)\n'
printf '  bundle : %s\n' "$bundle_dir"
printf '  target : %s\n' "$target_dir"
printf '  data root : %s\n' "$target_data_root"
printf '  disc   : %s\n' "$disc_path"
printf '  bios   : %s\n' "$bios_path"
printf '  state  : %s\n' "$state_path"
printf '  mode   : %s\n' "$runtime_mode"
printf '  frames : %s\n' "$mkstate_frames"
printf '  disckind: %s\n' "$disc_kind"
printf '  file    : %s\n' "$disc_file_output"
printf '  system.cnf artifact: %s\n' "$plan_dir/disc-system.cnf"
printf '\nRun A (savestate creation)\n'
printf '  %s --set EmuCore/EnableFastBoot=false --mkstate %q --frames %q --iso %q\n' \
  "$bundle_bin" "$state_path" "$mkstate_frames" "$disc_path"
printf '\nRun B (first runtime replay)\n'
printf '  %s --%s --savestate %q --frames %q --iso %q\n' \
  "$bundle_bin" "$runtime_mode" "$state_path" "$mkstate_frames" "$disc_path"
printf '\nWill store logs under:\n  %s\n' "$plan_dir"

if [[ "$execute" -eq 0 ]]; then
  exit 0
fi

mkdir -p "$plan_dir"
write_disc_system_cnf "$plan_dir/disc-system.cnf"

for p in "$disc_path" "$bios_path"; do
  [[ -f "$p" ]] || die "missing input file: $p"
done

disc_sha="$(sha256sum "$disc_path" | awk '{print $1}')"
bios_sha="$(sha256sum "$bios_path" | awk '{print $1}')"
{
  printf 'DISC PATH    = %s\n' "$disc_path"
  printf 'DISC FORMAT  = %s\n' "$disc_kind"
  printf 'DISC FILE    = %s\n' "$disc_file_output"
  printf 'DISC SHA256  = %s\n' "$disc_sha"
  printf '\nDISC FINGERPRINT\n'
  fingerprint_disc
} | tee "$plan_dir/disc-fingerprint.txt"
{
  printf 'BIOS PATH    = %s\n' "$bios_path"
  printf 'BIOS FILE    = %s\n' "$(file "$bios_path")"
  printf 'BIOS SHA256  = %s\n' "$bios_sha"
} | tee "$plan_dir/bios-fingerprint.txt"
printf 'DISC SHA256 = %s\n' "$disc_sha" | tee "$plan_dir/input-sha256.txt"
printf 'BIOS SHA256 = %s\n' "$bios_sha" | tee -a "$plan_dir/input-sha256.txt"

q_target="$(printf '%q' "$target_dir")"
q_data_root="$(printf '%q' "$target_data_root")"
q_bundle="$(printf '%q' "$bundle_dir")"
q_disc_src="$(printf '%q' "$disc_path")"
q_bios_src="$(printf '%q' "$bios_path")"
q_disc_base="$(printf '%q' "$(basename "$disc_path")")"
q_bios_base="$(printf '%q' "$(basename "$bios_path")")"

backup_stamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_dir="${target_dir}.backup-${backup_stamp}"
q_backup="$(printf '%q' "$backup_dir")"

echo "Backing up target directory if it exists..."
"$connect" bash -lc "set -euo pipefail; if [ -e $q_target ]; then mv $q_target $q_backup; fi; mkdir -p $q_target"

echo "Copying bundle..."
tar -C "$bundle_dir" -cf - . | "$connect" bash -lc "set -euo pipefail; tar -C $q_target -xf -"

echo "Staging BIOS and ISO into the target directory..."
"$connect" bash -lc "set -euo pipefail; mkdir -p $q_target $q_target/.home $q_target/.config $q_target/.cache $q_target/.local/share $q_data_root/bios $q_data_root/discs $q_data_root/sstates $q_data_root/logs"
tar -C "$(dirname "$bios_path")" -cf - "$(basename "$bios_path")" | "$connect" bash -lc "set -euo pipefail; tar -C $q_data_root/bios -xf -"
tar -C "$(dirname "$disc_path")" -cf - "$(basename "$disc_path")" | "$connect" bash -lc "set -euo pipefail; tar -C $q_data_root/discs -xf -"

echo "Validating target BIOS directory..."
validated_bios="$("$connect" bash -lc "set -euo pipefail; validate_target_bios_dir() { local bios_dir=\$1; local -a valid=(); local bios_file size; shopt -s nullglob; for bios_file in \"\$bios_dir\"/*; do [[ -f \"\$bios_file\" ]] || continue; size=\$(stat -c '%s' \"\$bios_file\"); if (( size < 4 * 1024 * 1024 || size > 8 * 1024 * 1024 )); then continue; fi; if grep -a -m1 -q 'RESET' \"\$bios_file\" && grep -a -m1 -q 'ROMVER' \"\$bios_file\"; then valid+=(\"\$bios_file\"); fi; done; shopt -u nullglob; if (( \${#valid[@]} != 1 )); then printf 'expected exactly one valid BIOS in %s, found %d\\n' \"\$bios_dir\" \"\${#valid[@]}\" >&2; exit 1; fi; printf '%s\\n' \"\${valid[0]}\"; }; validate_target_bios_dir $q_data_root/bios")" || die "target BIOS directory validation failed"
printf 'Validated BIOS: %s\n' "$validated_bios" | tee "$plan_dir/validated-bios.txt"

echo "Target-side preflight..."
"$connect" bash -lc "set -euo pipefail
export HOME=$q_target/.home
export XDG_CONFIG_HOME=$q_target/.config
export XDG_CACHE_HOME=$q_target/.cache
export XDG_DATA_HOME=$q_target/.local/share
cd $q_target
id
uname -a
cat /etc/os-release
free -h
df -h
mount
printf 'BIOS directory contents:\n'
find $q_data_root/bios -maxdepth 1 -type f -printf '%f %s bytes\n'
command -v bash || true
command -v timeout || true
command -v readelf || true
command -v file || true
command -v ldd || true
command -v sha256sum || true
test -x /lib/ld-linux-aarch64.so.1
test -d /storage/ports
file bin/pcsx2-eerunner
readelf -h bin/pcsx2-eerunner
readelf -d bin/pcsx2-eerunner
LD_LIBRARY_PATH=\"\$PWD/lib\" ldd bin/pcsx2-eerunner
LD_LIBRARY_PATH=\"\$PWD/lib\" /lib/ld-linux-aarch64.so.1 --list bin/pcsx2-eerunner
" | tee "$plan_dir/target-preflight.log"

echo "Running bundle diagnostic..."
"$connect" bash -lc "set -euo pipefail
export HOME=$q_target/.home
export XDG_CONFIG_HOME=$q_target/.config
export XDG_CACHE_HOME=$q_target/.cache
export XDG_DATA_HOME=$q_target/.local/share
cd $q_target
./diagnostic.sh
" | tee "$plan_dir/diagnostic-launch.log"

echo "Running mkstate..."
"$connect" bash -lc "set -euo pipefail
export HOME=$q_target/.home
export XDG_CONFIG_HOME=$q_target/.config
export XDG_CACHE_HOME=$q_target/.cache
export XDG_DATA_HOME=$q_target/.local/share
export LD_LIBRARY_PATH="$q_target/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cd $q_target
timeout 30s ./bin/pcsx2-eerunner --set EmuCore/EnableFastBoot=false --mkstate $q_data_root/sstates/first-boot.p2s --frames $mkstate_frames --iso $q_data_root/discs/$q_disc_base
" | tee "$plan_dir/mkstate-launch.log"

echo "Running replay mode..."
"$connect" bash -lc "set -euo pipefail
export HOME=$q_target/.home
export XDG_CONFIG_HOME=$q_target/.config
export XDG_CACHE_HOME=$q_target/.cache
export XDG_DATA_HOME=$q_target/.local/share
export LD_LIBRARY_PATH="$q_target/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cd $q_target
timeout 30s ./bin/pcsx2-eerunner --$runtime_mode --savestate $q_data_root/sstates/first-boot.p2s --frames $mkstate_frames --iso $q_data_root/discs/$q_disc_base
" | tee "$plan_dir/runtime-launch.log"

echo "Collecting logs..."
"$connect" bash -lc "set -euo pipefail
cd $q_target
find logs -maxdepth 2 -type f -print
"

echo "Done. Local artifacts directory: $plan_dir"
