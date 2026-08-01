#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SYSROOT="${TARGET_SYSROOT:-$ROOT_DIR/sysroots/r36s-archr}"

usage() {
  cat <<'EOF'
Usage: plan-r36s-sysroot.sh [--execute]

Prints a dry-run sysroot acquisition plan. This stage never performs a copy.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "${1:-}" == "--execute" ]]; then
  echo "Execution mode is disabled for this stage." >&2
  exit 1
fi

cat <<EOF
Target sysroot destination: $TARGET_SYSROOT

Live ABI snapshot plan:
  - /lib/ -> /usr/lib/ (merged-usr)
  - /usr/lib/
  - /usr/share/cmake/
  - /usr/lib/pkgconfig/ if present
  - /usr/share/pkgconfig/ if present
  - selected runtime vendor libraries such as:
      /usr/lib/libEGL.so.1
      /usr/lib/libGLESv2.so.2
      /usr/lib/libgbm.so.1
      /usr/lib/libdrm.so.2

Package-based sysroot plan:
  - headers from matching package archives
  - build metadata from matching package archives
  - runtime libs from matching package archives
  - target-specific vendor libraries only when archives match the live ABI

Known target facts:
  - /usr/include is absent on the live console
  - pkg-config is absent from PATH on the live console
  - libvulkan.so.1 was not found on the live console

Explicit exclusions:
  - /boot
  - /flash
  - /dev
  - /proc
  - /sys
  - /run
  - /tmp
  - /var/cache
  - /var/log
  - /home
  - /root
  - /storage
  - ROMs, BIOS, saves, firmware dumps

Not permitted in this stage:
  - rsync
  - --delete
  - --remove-source-files
  - any execution path that writes to the target
EOF
