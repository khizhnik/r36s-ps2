# Minimal Build Entrypoints

## Observed targets

| Target | Downloads | Builds toolchain | Builds packages | Produces rootfs | Produces sysroot | Requires Docker |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `make RK3326` | yes | yes | yes | yes | yes | no |
| `make docker-RK3326` | yes | yes | yes | yes | yes | yes |
| `PROJECT=ArchR DEVICE=RK3326 ARCH=aarch64 ./scripts/build_distro` | yes | yes | yes | yes | yes | no |
| `PROJECT=ArchR DEVICE=RK3326 ARCH=aarch64 ./scripts/update_packages` | yes | no | package metadata update only | no | no | no |

## Practical answer

The smallest visible entrypoint that can plausibly produce a usable sysroot is the normal package build path driven by `scripts/build` and `scripts/install` through the RK3326 aarch64 flow.

No separate SDK-export-only target was found in the inspected source tree.

