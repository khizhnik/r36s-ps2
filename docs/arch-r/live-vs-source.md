# Live vs Source

| Live fact | Source mechanism | Confidence |
| --- | --- | --- |
| `/usr/include` absent | `scripts/install` excludes it; `libmali` also prunes it from sysroot | CONFIRMED_BY_BOTH |
| `gcc` package present, driver absent | `gcc` target install ships only runtime libraries | CONFIRMED_BY_BOTH |
| `/lib -> /usr/lib` | `scripts/image` creates the legacy symlink | CONFIRMED_BY_SOURCE |
| `libGL.so.1.7.0` backed by null placeholder behavior | `libglvnd` + `gpudriver` runtime bind mount | CONFIRMED_BY_BOTH |
| `libEGL` / `libGLESv2` available | `libglvnd` and/or vendor GLES packaging | CONFIRMED_BY_BOTH |
| `libgbm` from Mesa | Mesa target package with GBM enabled | CONFIRMED_BY_BOTH |
| Vulkan absent | Vulkan support is optional and not enabled by RK3326 defaults | INFERENCE |
| `/var` tmpfs | BusyBox/systemd mount units | CONFIRMED_BY_BOTH |
| runtime overlay directories exist | RetroArch and ArchR tmpfiles/mount units | CONFIRMED_BY_BOTH |
| package DB retains removed files | package metadata is separate from runtime mount view | INFERENCE |

