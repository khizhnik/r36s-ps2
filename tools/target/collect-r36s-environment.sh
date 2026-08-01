#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARTIFACT_ROOT="$ROOT_DIR/artifacts/target-environment"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$ARTIFACT_ROOT/$TIMESTAMP"
SSH_TIMEOUT="${SSH_TIMEOUT:-25s}"

mkdir -p "$RUN_DIR"

if command -v timeout >/dev/null 2>&1; then
  remote_shell() {
    timeout "$SSH_TIMEOUT" "$ROOT_DIR/tools/connect-r36s-wifi.sh" sh -s
  }
else
  remote_shell() {
    "$ROOT_DIR/tools/connect-r36s-wifi.sh" sh -s
  }
fi

capture_group() {
  local name="$1"
  local stdout_name="$2"
  local stdout_path="$RUN_DIR/$stdout_name"
  local stderr_path="$RUN_DIR/$name.stderr.txt"
  local rc=0

  set +e
  {
    printf 'set -eu\n'
    cat
  } | remote_shell >"$stdout_path" 2>"$stderr_path"
  rc=$?
  set -e

  if [[ $rc -eq 0 ]]; then
    printf '%s\t%s\t%s\t%s\n' "$name" "$rc" "OK" "$stdout_name" >>"$RUN_DIR/status.tsv"
  else
    printf '%s\t%s\t%s\t%s\n' "$name" "$rc" "FAILED" "$stdout_name" >>"$RUN_DIR/status.tsv"
  fi
}

status_label() {
  local marker="$1"
  if [[ $marker -eq 0 ]]; then
    printf 'COMPLETE\n'
  else
    printf 'PARTIAL\n'
  fi
}

cat >"$RUN_DIR/run-metadata.txt" <<EOF
timestamp_utc=$TIMESTAMP
worktree=$ROOT_DIR
connection_helper=$ROOT_DIR/tools/connect-r36s-wifi.sh
remote_contract=stdin_to_sh_minus_s
ssh_timeout=$SSH_TIMEOUT
notes=read_only_collection_only_no_target_writes
EOF

printf 'group\texit_code\tstatus\tstdout\n' >"$RUN_DIR/status.tsv"

capture_group baseline baseline.stdout.txt <<'REMOTE'
id
whoami
hostname
date
cat /proc/uptime
uname -a
uname -m
getconf LONG_BIT
getconf PAGESIZE
REMOTE

capture_group os-release os-release.stdout.txt <<'REMOTE'
cat /etc/os-release
printf '\n---\n'
cat /etc/arch-release 2>/dev/null || true
printf '\n---\n'
cat /etc/lsb-release 2>/dev/null || true
printf '\n---\n'
getconf GNU_LIBC_VERSION 2>/dev/null || true
printf '\n---\n'
ldd --version 2>&1 | head -n 10
REMOTE

capture_group cpu cpu.stdout.txt <<'REMOTE'
cat /proc/cpuinfo
printf '\n---\n'
lscpu 2>/dev/null || true
printf '\n---\n'
getconf LEVEL1_DCACHE_LINESIZE 2>/dev/null || true
printf '\n---\n'
getconf LEVEL1_ICACHE_LINESIZE 2>/dev/null || true
REMOTE

capture_group memory memory.stdout.txt <<'REMOTE'
getconf PAGESIZE
printf '\n---\n'
cat /proc/meminfo
printf '\n---\n'
ulimit -a
printf '\n---\n'
cat /proc/sys/vm/mmap_min_addr 2>/dev/null || true
printf '\n---\n'
cat /proc/sys/kernel/randomize_va_space 2>/dev/null || true
REMOTE

capture_group filesystem filesystem.stdout.txt <<'REMOTE'
cat /proc/self/mountinfo
printf '\n---\n'
df -hT
printf '\n---\n'
ls -ld /lib /usr/lib /usr/include 2>/dev/null || true
printf '\n---\n'
readlink -f /lib 2>/dev/null || true
printf '\n---\n'
readlink -f /usr/lib 2>/dev/null || true
REMOTE

capture_group packages packages.stdout.txt <<'REMOTE'
command -v pacman || true
printf '\n---\n'
pacman --version 2>/dev/null || true
printf '\n---\n'
pacman -Q 2>/dev/null | sort || true
REMOTE

capture_group dev-pacman-ql dev-pacman-ql.stdout.txt <<'REMOTE'
pacman -Ql gcc
printf '\n---\n'
pacman -Ql glibc
printf '\n---\n'
pacman -Ql binutils
REMOTE

capture_group dev-pacman-qkk dev-pacman-qkk.stdout.txt <<'REMOTE'
pacman -Qkk glibc
printf '\n---\n'
pacman -Qkk gcc
printf '\n---\n'
pacman -Qkk binutils
REMOTE

capture_group dev-pacman-qi dev-pacman-qi.stdout.txt <<'REMOTE'
pacman -Qi glibc
printf '\n---\n'
pacman -Qi gcc
printf '\n---\n'
pacman -Qi binutils
REMOTE

capture_group dev-alt-headers dev-alt-headers.stdout.txt <<'REMOTE'
ls -ld /usr/include /usr/local/include /opt/include /usr/lib/gcc /usr/lib/gcc/* /usr/lib/gcc/*/*/include 2>/dev/null || true
REMOTE

capture_group graphics graphics.stdout.txt <<'REMOTE'
ls -l /dev/dri 2>/dev/null || true
printf '\n---\n'
cat /sys/class/drm/card*/device/uevent 2>/dev/null || true
printf '\n---\n'
lsmod 2>/dev/null | grep -Ei 'panfrost|mali|drm|gpu' || true
printf '\n---\n'
dmesg 2>/dev/null | grep -Ei 'panfrost|mali|drm|gpu' | tail -n 200 || true
printf '\n---\n'
command -v vulkaninfo || true
printf '\n---\n'
command -v glxinfo || true
printf '\n---\n'
command -v eglinfo || true
printf '\n---\n'
command -v es2_info || true
printf '\n---\n'
command -v kmsprint || true
REMOTE

capture_group libgl-runtime libgl-runtime.stdout.txt <<'REMOTE'
ls -l /usr/lib/libGL.so.1 /usr/lib/libGL.so.1.7.0 2>/dev/null || true
printf '\n---\n'
readlink -f /usr/lib/libGL.so.1 2>/dev/null || true
printf '\n---\n'
stat /usr/lib/libGL.so.1.7.0 2>/dev/null || true
printf '\n---\n'
findmnt -T /usr/lib/libGL.so.1.7.0 -o TARGET,SOURCE,FSTYPE,OPTIONS 2>/dev/null || true
printf '\n---\n'
if mountpoint /usr/lib/libGL.so.1.7.0 >/dev/null 2>&1; then
  mountpoint_exit=0
else
  mountpoint_exit=$?
fi
printf 'mountpoint_exit=%s\n' "$mountpoint_exit"
printf '\n---\n'
grep -F '/usr/lib/libGL.so.1.7.0' /proc/self/mountinfo || true
printf '\n---\n'
grep -F '/usr/lib/libGL.so.1' /proc/self/mountinfo || true
printf '\n---\n'
file /usr/lib/libGL.so.1.7.0 2>/dev/null || true
printf '\n---\n'
readelf -h /usr/lib/libGL.so.1.7.0 2>/dev/null || true
printf '\n---\n'
readelf -d /usr/lib/libGL.so.1.7.0 2>/dev/null | sed -n '1,160p' || true
printf '\n---\n'
pacman -Qo /usr/lib/libGL.so.1.7.0 2>&1 || true
printf '\n---\n'
pacman -Qo /usr/lib/libEGL.so.1 2>&1 || true
printf '\n---\n'
pacman -Qo /usr/lib/libGLESv2.so.2 2>&1 || true
printf '\n---\n'
pacman -Qo /usr/lib/libgbm.so.1 2>&1 || true
REMOTE

capture_group vulkan-runtime vulkan-runtime.stdout.txt <<'REMOTE'
ls -l /usr/lib/libvulkan.so* /lib/libvulkan.so* /usr/local/lib/libvulkan.so* 2>/dev/null || true
printf '\n---\n'
ls -ld /usr/share/vulkan /etc/vulkan /usr/share/vulkan/icd.d /etc/vulkan/icd.d 2>/dev/null || true
printf '\n---\n'
find /usr/share/vulkan /etc/vulkan -maxdepth 3 -type f 2>/dev/null | sort || true
printf '\n---\n'
pacman -Q | grep -Ei 'vulkan|mali|mesa' || true
REMOTE

capture_group selected-libraries selected-libraries.tsv <<'REMOTE'
printf 'requested_path\tresolved_path\texists\tpackage\tsoname\telf_machine\tneeded\tnotes\n'
for requested_path in \
  /usr/lib/libc.so.6 \
  /usr/lib/libstdc++.so.6 \
  /usr/lib/libatomic.so.1 \
  /usr/lib/libdrm.so.2 \
  /usr/lib/libgbm.so.1 \
  /usr/lib/libEGL.so.1 \
  /usr/lib/libGLESv2.so.2 \
  /usr/lib/libGL.so.1 \
  /usr/lib/libasound.so.2 \
  /usr/lib/libudev.so.1
do
  if [ -e "$requested_path" ]; then
    resolved_path="$(readlink -f "$requested_path" 2>/dev/null || printf '%s' "$requested_path")"
    package="$( { pacman -Qo "$resolved_path" 2>/dev/null | sed -n 's#.* is owned by \(.*\)$#\1#p' | head -n 1; } || true )"
    soname="$( { readelf -d "$resolved_path" 2>/dev/null | sed -n 's/.*SONAME.*\[\(.*\)\].*/\1/p' | head -n 1; } || true )"
    elf_machine="$( { readelf -h "$resolved_path" 2>/dev/null | sed -n 's/^.*Machine:[[:space:]]*//p' | head -n 1; } || true )"
    needed="$( { readelf -d "$resolved_path" 2>/dev/null | awk '/NEEDED/{gsub(/.*\[/,""); gsub(/\].*/,""); if (out) out = out "," $0; else out = $0} END{print out}'; } || true )"
    printf '%s\t%s\tyes\t%s\t%s\t%s\t%s\t%s\n' \
      "$requested_path" \
      "$resolved_path" \
      "${package:-unknown}" \
      "${soname:-}" \
      "${elf_machine:-}" \
      "${needed:-}" \
      ""
  else
    printf '%s\t\tno\t\t\t\t\tmissing\n' "$requested_path"
  fi
done
REMOTE

overall=0
while IFS=$'\t' read -r group exit_code status stdout_name; do
  [[ "$group" == "group" ]] && continue
  if [[ "$exit_code" != "0" ]]; then
    overall=1
  fi
done <"$RUN_DIR/status.tsv"

marker="$(status_label "$overall")"
printf '%s\n' "$marker" >"$RUN_DIR/$marker"
printf 'Collected target-environment data under %s\n' "$RUN_DIR"
