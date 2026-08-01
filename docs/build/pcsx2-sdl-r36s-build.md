# `pcsx2-sdl` R36S Build Command

This repository exposes a dedicated downstream build entrypoint for the
instrumented SDL frontend.

## Make command

```bash
make build-sdl3-wayland-r36s
make build-pcsx2-sdl-r36s
```

Optional clean reconfigure:

```bash
CLEAN=1 make build-pcsx2-sdl-r36s
```

The command delegates to `tools/build-pcsx2-sdl-r36s.sh`.
The `build-sdl3-wayland-r36s` prerequisite target validates the rebuilt SDL3
Wayland tree before the PCSX2 build starts.

## Output location

The dedicated build tree is:

```text
build/pcsx2-sdl-r36s/
```

The main binary is expected at:

```text
build/pcsx2-sdl-r36s/bin/armsx2-sdl
```

The build script prints the exact binary path after a successful build.

## How to clean

```bash
CLEAN=1 make build-pcsx2-sdl-r36s
```

This removes the dedicated build directory and regenerates the project-local
toolchain wrappers before reconfiguring.

## How to verify the binary

After a successful build, verify:

```bash
file build/pcsx2-sdl-r36s/bin/armsx2-sdl
readelf -d build/pcsx2-sdl-r36s/bin/armsx2-sdl
sha256sum build/pcsx2-sdl-r36s/bin/armsx2-sdl
```

The build script already prints the file type, dynamic dependencies, and
SHA256.

## Connection helper

The existing remote helper remains available through Make:

```bash
make connect-r36s
```

This delegates to `tools/connect-r36s-wifi.sh` and does not duplicate SSH
logic.
