# sdl3-wayland-smoke

Minimal SDL3 + Wayland + EGL + OpenGL ES smoke test for the R36S / Arch-R stack.

It creates a fullscreen Wayland window, opens an EGL OpenGL ES context, clears
the screen to red, keeps the frame visible for 5 seconds, prints diagnostics,
and exits.

Build is expected to use the existing Arch-R RK3326 cross toolchain preset from
the main repository:

```bash
export ARCHR_SDK_ROOT=/path/to/ArchR/sdk/root
cmake -S sdl3-wayland-smoke -B build/sdl3-wayland-smoke \
  -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE=cmake/toolchains/archr-rk3326-aarch64-clang.cmake
cmake --build build/sdl3-wayland-smoke
```

The resulting binary is intended to be deployed with `libSDL3.so.0*` in a
bundle-local `lib/` directory and launched inside the existing sway session.
