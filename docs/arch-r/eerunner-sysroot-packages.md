# Arch-R EE Runner Sysroot Packages

Audit date: 2026-07-28

## Scope

`pcsx2-eerunner` links `PCSX2_FLAGS` and `PCSX2`, so its dependency closure is the common PCSX2 core closure without a GUI frontend.

The target is headless, but it is not a pure zero-dependency runner.

## Source-backed package table

| Dependency | Needed to compile | Needed to link | Needed at runtime | Arch-R package | Already bundled | Optional |
| --- | ---: | ---: | ---: | --- | ---: | ---: |
| `zlib` | yes | yes | yes | `packages/compress/zlib` | no | no |
| `zstd` | yes | yes | yes | `packages/compress/zstd` | no | no |
| `lz4` | yes | yes | yes | `packages/compress/lz4` | no | no |
| `libpng` | yes | yes | yes | `packages/graphics/libpng` | no | no |
| `libjpeg-turbo` | yes | yes | yes | `packages/graphics/libjpeg-turbo` | no | no |
| `libwebp` | yes | yes | yes | `packages/graphics/libwebp` | no | no |
| `freetype` | yes | yes | yes | `packages/graphics/freetype` | no | no |
| `fontconfig` | yes | yes | yes | `packages/graphics/fontconfig` | no | no |
| `SDL3` | yes | yes | yes | `packages/devel/SDL3` | no | no |
| `curl` | yes | yes | yes | `packages/network/curl` | no | no |
| `libpcap` | yes | yes | yes | `projects/ArchR/packages/network/libpcap` | no | no |
| `dbus-1` | yes | yes | yes | `packages/sysutils/dbus` | no | no |
| `libudev` | yes | yes | yes | `packages/sysutils/systemd` | no | no |
| `libbacktrace` | only if `USE_BACKTRACE=ON` | yes | yes | `packages/devel/libbacktrace` | no | yes |
| `wayland` | only if `WAYLAND_API=ON` | yes | yes | `projects/ArchR/packages/wayland/wayland` | no | yes |
| `x11` | only if `X11_API=ON` | yes | yes | `packages/x11/*` | no | yes |
| `shaderc` | only if `USE_VULKAN=ON` | yes | yes | not found in inspected Arch-R package tree | no | yes |
| `vulkan-headers` | only if `USE_VULKAN=ON` | yes | yes | `projects/ArchR/packages/graphics/vulkan/vulkan-headers` | no | yes |

## Bundled dependencies

The following are bundled or vendored in-tree and do not have to come from the target sysroot:

- `fmt`
- `fast_float`
- `rapidyaml`
- `libchdr`
- `soundtouch`
- `simpleini`
- `imgui`
- `cpuinfo`
- `rcheevos`
- `discord-rpc`
- `freesurround`
- `libzip`
- `demanglegnu`
- `ccc`
- `plutovg`
- `plutosvg`
- `libretro` headers
- `vulkan-loader`, `vulkan-headers`, `vulkan-tools`, `volk`, `glslang` are present as Arch-R Vulkan ecosystem packages, but they are not required for the headless `USE_VULKAN=OFF` runner profile

## Headless minimal config

For a minimal `pcsx2-eerunner` probe, the source allows disabling:

- Qt UI
- SDL frontend
- libretro core
- Vulkan renderer
- OpenGL renderer

However, `common/` still wants `SDL3` and the core runtime libraries above.

## Answer to the renderer question

With `USE_OPENGL=OFF` and `USE_VULKAN=OFF`, graphics development headers are not required for the headless runner itself.

That does not eliminate SDL3, audio, input, or the other shared runtime dependencies.
