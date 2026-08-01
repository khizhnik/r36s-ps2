# Build Host Baseline

Audit date: 2026-07-27

This document captures the current local build host before any configure or build attempt.

## Environment

```text
pwd
/home/khizhnik/Games/R36S/r36s-ps2

uname -a
Linux 13DEV 6.1.0-49-amd64 #1 SMP PREEMPT_DYNAMIC Debian 6.1.174-1 (2026-05-26) x86_64 GNU/Linux

uname -m
x86_64

getconf LONG_BIT
64

getconf PAGESIZE
4096

nproc
20

free -h
Mem:            46Gi        17Gi       1.1Gi       1.7Gi        29Gi        28Gi
Swap:          8.2Gi       2.1Gi       6.1Gi

df -h .
/dev/nvme0n1p3  461G  392G   46G  90% /home/khizhnik/Games/R36S/r36s-ps2
```

## Tooling

```text
cmake --version
not installed in PATH

ninja --version
1.11.1

make --version
GNU Make 4.3

gcc --version
gcc (Debian 12.2.0-14+deb12u1) 12.2.0

g++ --version
g++ (Debian 12.2.0-14+deb12u1) 12.2.0

clang --version
not installed in PATH

clang++ --version
not installed in PATH

ld --version
GNU ld (GNU Binutils for Debian) 2.40

ld.lld --version
not installed in PATH

pkg-config --version
1.8.1
```

## Available pkg-config packages relevant to ARMSX2

- `egl`
- `gl`
- `libdrm`
- `libudev`
- `wayland-client`
- `wayland-egl`
- `x11`
- `vulkan`
- `freetype2`
- `fontconfig`
- `libpng`
- `zlib`
- `liblzma`
- `libwebp`
- `libjpeg`
- `alsa`
- `libpulse`
- `libpulse-simple`
- `libpulse-mainloop-glib`
- `dbus-1`
- `gbm`

## Host interpretation

- Host architecture is `x86_64`, not ARM64.
- Native ARM64 build is not possible on this host.
- Cross build is also not currently ready because no `aarch64-linux-gnu-*` compiler/toolchain was found in PATH.
- The first hard blocker for configure is the missing `cmake` executable.
- The second blocker for the intended Cortex-A35 experiment is that this host is not the target ISA family.
