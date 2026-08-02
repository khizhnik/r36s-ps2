SHELL := /bin/bash

REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

.PHONY: build-sdl3-wayland-r36s build-pcsx2-sdl-r36s package-pcsx2-sdl-r36s deploy-pcsx2-sdl-r36s run-pcsx2-sdl-r36s test-pcsx2-sdl-r36s research-mode-pcsx2-sdl-r36s connect-r36s

build-sdl3-wayland-r36s:
	@set -euo pipefail; \
	sdl3_dir='$(REPO_ROOT)/build/sdl3-wayland-rebuild/build'; \
	test -f "$$sdl3_dir/SDL3Config.cmake"; \
	test -f "$$sdl3_dir/libSDL3.so.0.2.6"; \
	test -f "$$sdl3_dir/include-config-release/build_config/SDL_build_config.h"; \
	grep -q '#define SDL_VIDEO_DRIVER_WAYLAND 1' "$$sdl3_dir/include-config-release/build_config/SDL_build_config.h"; \
	printf 'SDL3 Wayland build tree: %s\n' "$$sdl3_dir"

build-pcsx2-sdl-r36s: build-sdl3-wayland-r36s
	@CLEAN="$(CLEAN)" JOBS="$(JOBS)" tools/build-pcsx2-sdl-r36s.sh

package-pcsx2-sdl-r36s: build-pcsx2-sdl-r36s
	@tools/package-pcsx2-sdl-r36s.sh

deploy-pcsx2-sdl-r36s: package-pcsx2-sdl-r36s
	@tools/deploy-pcsx2-sdl-r36s.sh

run-pcsx2-sdl-r36s: deploy-pcsx2-sdl-r36s
	@tools/run-pcsx2-sdl-r36s.sh

test-pcsx2-sdl-r36s:
	@set -euo pipefail; \
	$(MAKE) build-pcsx2-sdl-r36s; \
	$(MAKE) package-pcsx2-sdl-r36s; \
	$(MAKE) deploy-pcsx2-sdl-r36s; \
	set +e; tools/run-pcsx2-sdl-r36s.sh; status=$$?; set -e; \
	[[ "$$status" -eq 134 ]] || { printf 'unexpected run exit status: %s (expected 134)\n' "$$status" >&2; exit 1; }; \
	tools/validate-pcsx2-sdl-r36s-run.sh '$(REPO_ROOT)/artifacts/pcsx2-sdl-r36s-graphical-run/latest' 6

research-mode-pcsx2-sdl-r36s:
	@tools/research-mode-pcsx2-sdl-r36s.sh

connect-r36s:
	@tools/connect-r36s-wifi.sh
