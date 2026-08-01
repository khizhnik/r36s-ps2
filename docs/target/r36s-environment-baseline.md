# R36S Environment Baseline

This document records the read-only ABI and runtime baseline of the target
R36S console.

## Confirmed Facts

- Architecture: `aarch64`
- CPU model: `Cortex-A35`
- CPU count: `4`
- CPU part: `0xd04`
- CPU features reported by the kernel: `fp`, `asimd`, `evtstrm`, `aes`,
  `pmull`, `sha1`, `sha2`, `crc32`, `cpuid`
- Page size: `4096`
- RAM: about `1,006,764 kB` total
- libc: `glibc 2.40`
- Kernel: `6.12.94`
- Hostname: `ark-b276`
- User for the approved connection path: `root`
- `uid=0(root)` on the approved SSH path
- `/lib` is a symlink to `/usr/lib`
- `/usr/lib` exists as a normal directory
- `/usr/include` is absent on the live console
- `pkg-config` is not available in `PATH`
- `pacman` is present and the package database is readable in read-only mode

## Filesystem and Runtime Shape

- Root filesystem: ext4 on `/dev/mmcblk1p2`
- `/flash`: vfat boot/config partition on `/dev/mmcblk1p1`
- `/storage`: ext4 data partition on `/dev/mmcblk1p3`
- `/storage/games-external`: exFAT on `/dev/mmcblk0p1`
- `/tmp/assets`, `/tmp/cores`, `/tmp/joypads`, `/tmp/overlays`,
  `/tmp/database`, `/tmp/shaders` are overlay-backed runtime directories
- `/var` is tmpfs, with `/var/log` backed by the data partition

## Collection Artifacts

- `artifacts/target-environment/20260727T180305Z/baseline.stdout.txt`
- `artifacts/target-environment/20260727T180305Z/os-release.stdout.txt`
- `artifacts/target-environment/20260727T180305Z/cpu.stdout.txt`
- `artifacts/target-environment/20260727T180305Z/memory.stdout.txt`
- `artifacts/target-environment/20260727T180305Z/filesystem.stdout.txt`
- `artifacts/target-environment/20260727T180305Z/status.tsv`

## Trusted Run

- `artifacts/target-environment/20260727T180305Z/`

## Notes

- The target is treated as a source of ABI truth, not as a build host.
- No system settings were modified during collection.
- The console is runtime-oriented; it does not expose a development header tree
  in the live filesystem.
