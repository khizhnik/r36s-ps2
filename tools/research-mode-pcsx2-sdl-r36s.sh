#!/usr/bin/env bash
set -euo pipefail

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
connect="${repo_root}/tools/connect-r36s-wifi.sh"

[[ -x "$connect" ]] || die "connect helper missing or not executable: $connect"

artifact_root="${repo_root}/artifacts/research-mode"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
run_dir="${artifact_root}/${timestamp}"
mkdir -p "$run_dir"

orchestrator_log="${run_dir}/research-mode.log"
exec > >(tee -a "$orchestrator_log") 2>&1

target_root="/storage/ports/pcsx2-sdl-r36s-diag"
target_log_dir="${target_root}/logs/research-mode-${timestamp}"
gdb_log="${run_dir}/gdb-batch.log"
dry_run="${DRY_RUN:-0}"

remote_proc_helpers='
is_real_sway() {
  ps -eo pid=,comm=,args= | awk '"'"'$2 == "sway" || $3 == "/usr/bin/sway" || $3 ~ "^/usr/bin/sway([[:space:]]|$)" { found = 1 } END { exit(found ? 0 : 1) }'"'"'
}
is_start_es() {
  ps -eo pid=,comm=,args= | awk '"'"'$2 == "bash" && $3 == "/usr/bin/start_es.sh" { found = 1 } END { exit(found ? 0 : 1) }'"'"'
}
'

stop_service() {
  printf 'Stopping essway.service on target...\n'
  {
    printf '%s\n' "$remote_proc_helpers"
    cat <<'REMOTE'
set -eu
systemctl mask --runtime essway.service
systemctl stop essway.service
printf 'essway.service state after stop:\n'
systemctl is-enabled essway.service || true
systemctl is-active essway.service || true
readlink /run/systemd/system/essway.service || true
for i in $(seq 1 30); do
  sway_alive="no"
  wayland_socket="no"
  sway_ipc_socket="no"
  emulationstation_alive="no"
  start_es_alive="no"
  if is_real_sway; then
    sway_alive="yes"
  fi
  if test -S /var/run/0-runtime-dir/wayland-1; then
    wayland_socket="yes"
  fi
  if test -S /var/run/0-runtime-dir/sway-ipc.0.sock; then
    sway_ipc_socket="yes"
  fi
  if pgrep -x emulationstation >/dev/null 2>&1; then
    emulationstation_alive="yes"
  fi
  if is_start_es; then
    start_es_alive="yes"
  fi
  if [[ "$i" -eq 1 || "$i" -eq 30 || "$sway_alive" != yes || "$wayland_socket" != yes || "$sway_ipc_socket" != yes || "$emulationstation_alive" != no || "$start_es_alive" != no ]]; then
    printf 'quiescence iteration %s: sway_alive=%s wayland_socket=%s sway_ipc_socket=%s emulationstation_alive=%s start_es_alive=%s\n' \
      "$i" "$sway_alive" "$wayland_socket" "$sway_ipc_socket" "$emulationstation_alive" "$start_es_alive"
  fi
  if [[ "$sway_alive" == yes && "$wayland_socket" == yes && "$sway_ipc_socket" == yes && "$emulationstation_alive" == no && "$start_es_alive" == no ]]; then
    printf 'essway.service stopped; sway and sockets remain alive; emulationstation and start_es.sh are gone.\n'
    free -h
    exit 0
  fi
  sleep 1
done
printf 'error: essway.service stop timed out waiting for sway+sockets+frontend quiescence\n' >&2
ps -eo pid=,comm=,args= | awk '$2 == "sway" || $3 == "/usr/bin/sway" || $3 ~ "^/usr/bin/sway([[:space:]]|$)"' || true
  ls -l /var/run/0-runtime-dir/ || true
  pgrep -x emulationstation || true
  ps -eo pid=,comm=,args= | awk '$2 == "bash" && $3 == "/usr/bin/start_es.sh" { print }' || true
  exit 1
REMOTE
  } | "$connect" sh -s
}

restore_service() {
  cat <<'REMOTE' | "$connect" sh -s
set +e
systemctl unmask --runtime essway.service
rm -f /run/systemd/system/essway.service
systemctl daemon-reload
systemctl reset-failed essway.service
systemctl start essway.service
exit 0
REMOTE
}

verify_restored() {
  printf 'Verifying restored essway.service on target...\n'
  local remote_script
  local restore_status_file="${target_log_dir}/restore-status.txt"
  remote_script="$(mktemp "${run_dir}/verify-restored.XXXXXX")"
  {
    printf 'target_log_dir=%q\n' "$target_log_dir"
    printf 'restore_status_file=%q\n' "$restore_status_file"
    printf '%s\n' "$remote_proc_helpers"
    cat <<'REMOTE'
set +e
restore_status=1
restored_ok=0
mkdir -p "$(dirname "$restore_status_file")"
for i in $(seq 1 30); do
  active_status=0
  enabled_status=0
  mask_status=0
  sway_status=1
  start_es_status=1
  emu_status=1
  socket_status=1
  if [ "$i" -eq 1 ] || [ "$i" -eq 30 ]; then
    printf 'restore iteration %s:\n' "$i"
  fi
  printf 'systemctl is-active essway.service: '
  systemctl is-active essway.service
  active_status=$?
  printf 'systemctl is-enabled essway.service: '
  systemctl is-enabled essway.service
  enabled_status=$?
  printf 'readlink /run/systemd/system/essway.service: '
  if [ -L /run/systemd/system/essway.service ]; then
    readlink /run/systemd/system/essway.service
    mask_status=0
  else
    printf '(absent)\n'
    mask_status=1
  fi
  if is_real_sway; then
    sway_status=0
  fi
  printf 'real sway process: '
  ps -eo pid=,comm=,args= | awk '$2 == "sway" || $3 == "/usr/bin/sway" || $3 ~ "^/usr/bin/sway([[:space:]]|$)" { print; found = 1 } END { exit(found ? 0 : 1) }'
  sway_status=$?
  printf 'start_es.sh process: '
  if is_start_es; then
    ps -eo pid=,comm=,args= | awk '$2 == "bash" && $3 == "/usr/bin/start_es.sh" { print; found = 1 } END { exit(found ? 0 : 1) }'
    start_es_status=$?
  else
    printf '(absent)\n'
    start_es_status=1
  fi
  printf 'emulationstation process: '
  pgrep -x emulationstation
  emu_status=$?
  printf 'both Wayland sockets:\n'
  ls -l /var/run/0-runtime-dir/wayland-1 /var/run/0-runtime-dir/sway-ipc.0.sock
  socket_status=$?
  printf 'verification summary: active=%s enabled=%s mask=%s sway=%s start_es=%s emulationstation=%s sockets=%s\n' \
    "$active_status" "$enabled_status" "$mask_status" "$sway_status" "$start_es_status" "$emu_status" "$socket_status"
  if [ "$active_status" -eq 0 ] \
    && [ "$mask_status" -ne 0 ] \
    && [ "$sway_status" -eq 0 ] \
    && [ "$emu_status" -eq 0 ] \
    && [ "$socket_status" -eq 0 ]; then
    restored_ok=1
  fi
  sleep 1
done
if [ "$restored_ok" -eq 1 ]; then
  printf 'restore verification succeeded\n'
  restore_status=0
else
  restore_status=1
fi
printf '%s\n' "$restore_status" >"$restore_status_file"
if [ "$restore_status" -eq 0 ]; then
  exit 0
fi
exit 1
REMOTE
  } >"$remote_script"
  local rc=0
  set +e
  "$connect" sh -s <"$remote_script"
  rc=$?
  set -e
  rm -f "$remote_script"
  local target_restore_status
  target_restore_status="$("$connect" "cat '$restore_status_file'")"
  printf 'verify_restored ssh rc: %s\n' "$rc"
  printf 'verify_restored target_restore_status: %s\n' "${target_restore_status:-empty}"
  if [[ "$target_restore_status" == 0 ]]; then
    return 0
  fi
  return "$rc"
}

service_restarted=0
gdb_status_file="${run_dir}/gdb-status.txt"
timeout_status_file="${run_dir}/timeout-status.txt"
ssh_status_file="${run_dir}/ssh-status.txt"
target_log_path_file="${run_dir}/target-log-path.txt"
cleanup() {
  local rc=$?
  set +e
  if [[ -x "$connect" ]]; then
    cat <<'REMOTE' | "$connect" sh -s || true
set +e
pkill -x gdb || true
pkill -x timeout || true
pkill -f '/storage/ports/pcsx2-sdl-r36s-diag/bin/armsx2-sdl' || true
systemctl unmask --runtime essway.service || true
rm -f /run/systemd/system/essway.service || true
systemctl daemon-reload || true
systemctl reset-failed essway.service || true
systemctl start essway.service || true
printf 'cleanup verification:\n'
systemctl is-active essway.service || true
systemctl is-enabled essway.service || true
readlink /run/systemd/system/essway.service || true
ps -eo pid=,comm=,args= | awk '$2 == "sway" || $3 == "/usr/bin/sway" || $3 ~ "^/usr/bin/sway([[:space:]]|$)" { print }' || true
ps -eo pid=,comm=,args= | awk '$2 == "bash" && $3 == "/usr/bin/start_es.sh" { print }' || true
pgrep -x emulationstation || true
ls -l /var/run/0-runtime-dir/wayland-1 /var/run/0-runtime-dir/sway-ipc.0.sock || true
exit 0
REMOTE
  fi
  if [[ "$service_restarted" -eq 0 ]]; then
    restore_service
    verify_restored || true
    service_restarted=1
  fi
  set -e
  exit "$rc"
}
trap cleanup EXIT

printf 'Research mode artifact dir: %s\n' "$run_dir"
printf 'Target root: %s\n' "$target_root"
printf 'Target log dir: %s\n' "$target_log_dir"
printf '%s\n' "$target_log_dir" >"$target_log_path_file"

set +e
stop_service
stop_service_status=$?

printf 'Preflight on target...\n'
{
  printf '%s\n' "$remote_proc_helpers"
  cat <<'REMOTE'
set -eu
printf '=== preflight ===\n'
printf 'sway: '
if is_real_sway; then
  echo yes
else
  echo no
  exit 1
fi
printf 'wayland-1 socket: '
test -S /var/run/0-runtime-dir/wayland-1 && echo yes || { echo no; exit 1; }
printf 'sway-ipc socket: '
test -S /var/run/0-runtime-dir/sway-ipc.0.sock && echo yes || { echo no; exit 1; }
printf 'emulationstation: '
! pgrep -x emulationstation >/dev/null 2>&1 && echo absent || { echo present; exit 1; }
printf 'start_es.sh: '
if is_start_es; then
  echo present
  exit 1
else
  echo absent
fi
printf 'gdb: '
! pgrep -x gdb >/dev/null 2>&1 && echo absent || { echo present; exit 1; }
printf 'armsx2-sdl: '
! pgrep -f '/storage/ports/pcsx2-sdl-r36s-diag/bin/armsx2-sdl' >/dev/null 2>&1 && echo absent || { echo present; exit 1; }
printf 'essway.service enabled: '
if enabled_state="$(systemctl is-enabled essway.service 2>&1)"; then
  printf '%s\n' "$enabled_state"
else
  printf '%s\n' "$enabled_state"
fi
printf 'essway.service active: '
if active_state="$(systemctl is-active essway.service 2>&1)"; then
  printf '%s\n' "$active_state"
else
  printf '%s\n' "$active_state"
fi
printf 'essway.service mask link: '
readlink /run/systemd/system/essway.service || true
printf 'free -h:\n'
free -h
available_mib="$(free -m | awk '/^Mem:/ {print $7; exit}')"
if [ -z "$available_mib" ] || [ "$available_mib" -lt 256 ]; then
  printf 'error: insufficient available memory: %s MiB\n' "${available_mib:-unknown}" >&2
  exit 1
fi
printf 'MemAvailable MiB: %s\n' "$available_mib"
REMOTE
} | "$connect" sh -s
preflight_status=$?
set -e

printf 'local status chain before launch: stop_service=%s preflight=%s\n' "$stop_service_status" "$preflight_status"
if [[ "$stop_service_status" -ne 0 || "$preflight_status" -ne 0 ]]; then
  printf 'error: stop/preflight failed before launch\n' >&2
  exit 1
fi

if [[ "$dry_run" == 1 ]]; then
  printf 'Dry run requested; skipping gdb capture.\n'
  set +e
  restore_service
  restore_status=$?
  verify_restored
  verify_status=$?
  target_restore_status="$("$connect" "cat '$target_log_dir/restore-status.txt'")"
  set -e
  printf 'dry-run status chain: stop_service=%s preflight=%s restore_service=%s verify_restored=%s target_restore_status=%s\n' \
    "$stop_service_status" "$preflight_status" "$restore_status" "$verify_status" "${target_restore_status:-empty}"
  if [[ "${stop_service_status:-1}" -eq 0 && "${preflight_status:-1}" -eq 0 && "$restore_status" -eq 0 && "${target_restore_status:-1}" -eq 0 ]]; then
    service_restarted=1
    trap - EXIT
    printf 'Research mode dry run complete.\n'
    printf '  logs: %s\n' "$run_dir"
    exit 0
  fi
  printf 'error: dry-run restoration did not complete cleanly\n' >&2
  exit 1
fi

printf 'Running target-side gdb batch capture...\n'
set +e
cat <<'REMOTE' | "$connect" sh -s -- "$target_log_dir" "$gdb_log"
set -eu
target_log_dir="$1"
gdb_log="$2"
gdb_status_file="${target_log_dir}/gdb-status.txt"
timeout_status_file="${target_log_dir}/timeout-status.txt"
cd /storage/ports/pcsx2-sdl-r36s-diag
mkdir -p "$target_log_dir"
export HOME=/storage/ports/pcsx2-sdl-r36s-diag/home
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_RUNTIME_DIR=/var/run/0-runtime-dir
export WAYLAND_DISPLAY=wayland-1
export SWAYSOCK=/var/run/0-runtime-dir/sway-ipc.0.sock
export SDL_VIDEODRIVER=wayland
export SDL_AUDIODRIVER=pulseaudio
export DISPLAY=:0.0
export LD_LIBRARY_PATH=/storage/ports/pcsx2-sdl-r36s-diag/lib
export MESA_NO_ERROR=1
export MESA_SHADER_CACHE_DIR=/var/cache/mesa
export MESA_SHADER_CACHE_MAX_SIZE=128MB
command -v gdb >/dev/null 2>&1
test -x ./bin/armsx2-sdl
test -r /tmp/vicecity.iso
set +e
timeout 180s sh -c '
  set -eu
  gdb_log="$1"
  gdb_status_file="$2"
  gdb -q -batch \
    -ex "set pagination off" \
    -ex "set confirm off" \
    -ex "set breakpoint pending on" \
    -ex "handle SIGSEGV nostop noprint pass" \
    -ex "handle SIGBUS nostop noprint pass" \
    -ex "handle SIGABRT stop print pass" \
    -ex "break CrashHandler::CrashSignalHandler" \
    -ex "run /tmp/vicecity.iso" \
    -ex "bt 10" \
    -ex "info args" \
    -ex "set \$uc = (ucontext_t*)ctx" \
    -ex "printf \"signal=%d\\n\", signal" \
    -ex "printf \"siginfo->si_code=%d\\n\", siginfo->si_code" \
    -ex "printf \"siginfo->si_addr=%p\\n\", siginfo->si_addr" \
    -ex "printf \"ucontext_pc=%p\\n\", (void*)\$uc->uc_mcontext.pc" \
    -ex "printf \"ucontext_lr=%p\\n\", (void*)\$uc->uc_mcontext.regs[30]" \
    -ex "printf \"ucontext_sp=%p\\n\", (void*)\$uc->uc_mcontext.sp" \
    -ex "x/12i \$uc->uc_mcontext.pc-24" \
    -ex "info symbol \$uc->uc_mcontext.pc" \
    ./bin/armsx2-sdl >"$gdb_log" 2>&1
  gdb_status=$?
  printf "%s\n" "$gdb_status" >"$gdb_status_file"
' sh "$gdb_log" "$gdb_status_file"
timeout_status=$?
set -e
if [[ -s "$gdb_status_file" ]]; then
  gdb_status="$(cat "$gdb_status_file")"
else
  gdb_status="$timeout_status"
  printf '%s\n' "$gdb_status" >"$gdb_status_file"
fi
printf '%s\n' "$timeout_status" >"$timeout_status_file"
printf 'gdb exit status: %s\n' "$gdb_status"
printf 'timeout exit status: %s\n' "$timeout_status"
printf 'gdb log: %s\n' "$gdb_log"
if [[ -s "$gdb_log" ]]; then
  tail -n 80 "$gdb_log"
else
  printf 'gdb log missing or empty on target\n'
fi
REMOTE
ssh_pipeline_status=("${PIPESTATUS[@]}")
ssh_status="${ssh_pipeline_status[1]:-${ssh_pipeline_status[0]}}"
set -e
printf '%s\n' "$ssh_status" >"$ssh_status_file"
printf 'ssh exit status: %s\n' "$ssh_status"
printf 'Target log path: %s\n' "$target_log_dir"
restore_service
verify_restored
service_restarted=1

printf 'Research mode complete.\n'
printf '  logs: %s\n' "$run_dir"
