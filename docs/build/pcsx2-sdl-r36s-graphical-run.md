# `pcsx2-sdl` R36S Graphical Run

This documents the current reproducible build, package, deploy, and run
workflow for the instrumented `pcsx2-sdl` graphical experiment on the R36S.

## Proven SDL3 payload

The package step must use the Wayland-enabled SDL3 shared object from the
rebuilt SDL3 tree:

```text
build/sdl3-wayland-rebuild/build/libSDL3.so.0.2.6
```

Required SHA256:

```text
7c8e71e6ccfd2673f1a9e3181d422d623fdb5773e9dece02474ee7c93be1d731
```

The following SDL3 payload must not be repackaged:

```text
05796dab25c8e5d58ed925453b1f698cc08937c197813bda66286f4b26f0805b
```

## One-command flow

The recommended end-to-end command is:

```bash
make test-pcsx2-sdl-r36s
```

That target performs the build, package, deploy, run, and validation steps
and succeeds only when the current known graphical path is reached and the
expected current crash signal is observed.

The individual steps are still available as:

```bash
make build-pcsx2-sdl-r36s
make package-pcsx2-sdl-r36s
make deploy-pcsx2-sdl-r36s
make run-pcsx2-sdl-r36s
```

`make run-pcsx2-sdl-r36s` reports the real emulator exit status.
`make test-pcsx2-sdl-r36s` is the only target that accepts the current
expected `SIGABRT` result, and it verifies the run only after the current
`134` exit status has been observed.

## Build configuration

The build remains the proven ARM64 / Cortex-A35-safe configuration:

- `-march=armv8-a`
- `-mno-outline-atomics`
- SDL frontend enabled
- Wayland enabled
- OpenGL/OpenGL ES enabled
- Vulkan disabled as a renderer
- Qt disabled
- current ARM64 ABI bridge and diagnostics preserved
- CMake + Ninja through the recovered Arch-R cross-build path

## Package layout

The packaged bundle is:

```text
deploy/pcsx2-sdl-r36s-diag/
```

The target directory is:

```text
/storage/ports/pcsx2-sdl-r36s-diag
```

The package step copies:

- `build/pcsx2-sdl-r36s/bin/armsx2-sdl`
- the proven SDL3 shared object from `build/sdl3-wayland-rebuild/build`
- the Wayland / EGL / GLES runtime libraries from `deploy/sdl3-wayland-smoke/lib`
- `libplutosvg.so.0` and `libplutovg.so.1`

The packaged SDL3 symlinks must resolve as:

- `libSDL3.so`
- `libSDL3.so.0`
- `libSDL3.so.0.2.6`

## Deployment

Deployment uses only:

```text
tools/connect-r36s-wifi.sh
```

No separate SSH configuration is duplicated in the new scripts.

## Runtime environment

The run step preserves the proven environment:

- `HOME=/storage/ports/pcsx2-sdl-r36s-diag/home`
- `XDG_CONFIG_HOME=$HOME/.config`
- `XDG_CACHE_HOME=$HOME/.cache`
- `XDG_DATA_HOME=$HOME/.local/share`
- `XDG_RUNTIME_DIR=/var/run/0-runtime-dir`
- `WAYLAND_DISPLAY=wayland-1`
- `SWAYSOCK=/var/run/0-runtime-dir/sway-ipc.0.sock`
- `SDL_VIDEODRIVER=wayland`
- `SDL_AUDIODRIVER=pulseaudio`
- `DISPLAY=:0.0`
- `LD_LIBRARY_PATH=/storage/ports/pcsx2-sdl-r36s-diag/lib`
- `MESA_NO_ERROR=1`
- `MESA_SHADER_CACHE_DIR=/var/cache/mesa`
- `MESA_SHADER_CACHE_MAX_SIZE=128MB`

The ISO is referenced by a stable target-side symlink:

```text
/tmp/vicecity.iso
```

## BIOS and ISO

The current experiment reuses the already-present target assets:

- BIOS: the existing ARMSX2 BIOS in `/storage/ports/pcsx2-sdl-r36s-diag/home/.config/ARMSX2/bios`
- ISO: `Grand Theft Auto - Vice City (Europe) (En,Fr,De,Es,It) (v3.00).iso`

## Proven startup stages

The current binary has already proven these stages:

- `SDL_InitSubSystem(SDL_INIT_VIDEO)` succeeds
- `SDL_CreateWindow()` succeeds
- `BuildWaylandWindowInfo()` returns `Wayland`
- `Host::AcquireRenderWindow()` succeeds
- `GSopen()` succeeds
- the emulator reaches the CPU-thread crash that happens after GS open

The current known failure is **after** successful window creation and GS open,
in the CPU thread.

## Logs

The run script stores logs under:

```text
artifacts/pcsx2-sdl-r36s-graphical-run/<timestamp>/
```

The most recent run is also linked from:

```text
artifacts/pcsx2-sdl-r36s-graphical-run/latest
```

Expected files:

- `run-info.txt`
- `preflight-host.txt`
- `preflight-target.txt`
- `stdout-stderr.txt`
- `emulog.txt`
- `exit-status.txt`
- `signal.txt` when the process exits via signal

The preflight files record:

- executable path and SHA256
- SDL3 path and SHA256
- target-resolved ISO path plus SHA256 and size
- selected BIOS path and SHA256
- `bin/resources` presence and contents
- target-side `ldd` output with the bundle `LD_LIBRARY_PATH`

## Clean and incremental rebuilds

Clean rebuild:

```bash
CLEAN=1 make build-pcsx2-sdl-r36s
```

Incremental rebuild:

```bash
make build-pcsx2-sdl-r36s
```

## Verification

The deployment step verifies:

- executable SHA256
- SDL3 SHA256
- SDL3 symlink chain
- `ldd` with the bundle `LD_LIBRARY_PATH`
- SDL driver registry contains `wayland`

The validation step used by `make test-pcsx2-sdl-r36s` additionally checks
for these ordered markers:

1. `SDL_GetVideoDriver(0)=wayland`
2. `SDL_InitSubSystem(SDL_INIT_VIDEO) success`
3. `SDL_CreateWindow success`
4. `BuildWindowInfo: return Wayland`
5. `Host::AcquireRenderWindow: exit`
6. `GSopen: exit true`

It also requires the run to exit with signal 6.
