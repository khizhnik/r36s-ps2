#!/usr/bin/env bash
set -euo pipefail

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

require_file() {
	local path="$1"
	local label="${2:-file}"
	[[ -e "$path" ]] || die "missing ${label}: ${path}"
}

require_dir() {
	local path="$1"
	local label="${2:-directory}"
	[[ -d "$path" ]] || die "missing ${label}: ${path}"
}

require_executable() {
	local path="$1"
	local label="${2:-executable}"
	[[ -x "$path" ]] || die "missing ${label}: ${path}"
}

resolve_repo_path() {
	local path="$1"
	local target candidate rel

	if [[ -e "$path" ]]; then
		printf '%s\n' "$path"
		return 0
	fi

	if [[ -L "$path" ]]; then
		target="$(readlink "$path")"
		if [[ "$target" == /work/* ]]; then
			rel="${target#/work/}"
			for candidate in \
				"$repo_root/$rel" \
				"$repo_root/research/upstream/arch-r/$rel" \
				"$repo_root/upstream/armsx2/$rel"
			do
				if [[ -e "$candidate" ]]; then
					printf '%s\n' "$candidate"
					return 0
				fi
			done
		elif [[ "$target" == /* ]] && [[ -e "$target" ]]; then
			printf '%s\n' "$target"
			return 0
		fi
	fi

	if [[ "$path" == /work/* ]]; then
		rel="${path#/work/}"
		for candidate in \
			"$repo_root/$rel" \
			"$repo_root/research/upstream/arch-r/$rel" \
			"$repo_root/upstream/armsx2/$rel"
		do
			if [[ -e "$candidate" ]]; then
				printf '%s\n' "$candidate"
				return 0
			fi
		done
	fi

	die "unable to resolve path: ${path}"
}

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="$repo_root/build/pcsx2-sdl-r36s"
source_root="$repo_root/upstream/armsx2"
toolchain_root="$repo_root/research/upstream/arch-r/build.ArchR-RK3326.aarch64/toolchain"
toolchain_triplet_root="$toolchain_root/aarch64-archr-linux-gnu"
sysroot="$toolchain_triplet_root/sysroot"
sdl3_build_root="$repo_root/build/sdl3-wayland-rebuild/build"
sdl3_pkgconfig_root="$repo_root/build/sdl3-wayland-rebuild/pkgconfig"
sdl3_wayland_headers="$repo_root/build/sdl3-wayland-rebuild/wayland-headers"
sdl3_wayland_libs="$repo_root/build/sdl3-wayland-rebuild/wayland-libs"
wrapper_dir="$build_root/toolchain-wrappers"
gcc_helper_dir="$build_root/gcc-subtools"
build_pkgconfig_dir="$build_root/pkgconfig"
sysroot_overlay_dir="$build_root/sysroot-overlay"
toolchain_file="$build_root/aarch64-wayland-toolchain.cmake"

steamrt_root="${ARCHR_STEAM_RUNTIME_ROOT:-$HOME/.steam/debian-installation/steamapps/common/SteamLinuxRuntime_4}"
steamrt_loader="${ARCHR_STEAM_RUNTIME_LOADER:-$steamrt_root/var/tmp-5LR7R3/usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2}"
steamrt_libpath="${ARCHR_STEAM_RUNTIME_LIBPATH:-$steamrt_root/steamrt4_platform_4.0.20260608.242786/files/share/gdb/auto-load/usr/lib/x86_64-linux-gnu:$steamrt_root/var/tmp-5LR7R3/usr/lib/x86_64-linux-gnu:$steamrt_root/var/tmp-5LR7R3/usr/share/gdb/auto-load/usr/lib/x86_64-linux-gnu:$toolchain_root/lib:$toolchain_triplet_root/lib:$toolchain_triplet_root/lib64:$toolchain_root/x86_64-pc-linux-gnu/aarch64-archr-linux-gnu/lib:$toolchain_root/lib/gcc/aarch64-archr-linux-gnu/14.2.0:$toolchain_root/lib/gcc/aarch64-archr-linux-gnu/14.2.0/plugin:/usr/lib/x86_64-linux-gnu:/lib/x86_64-linux-gnu}"

pkg_config_bin="${PKG_CONFIG:-$(command -v pkg-config || true)}"
ninja_bin="${NINJA:-$(command -v ninja || true)}"
sha256sum_bin="${SHA256SUM:-$(command -v sha256sum || true)}"
file_bin="${FILE:-$(command -v file || true)}"
readelf_bin="${READELF:-$(command -v readelf || true)}"

cmake_real="$toolchain_root/bin/cmake.real"
gcc_real="$toolchain_root/bin/aarch64-archr-linux-gnu-gcc-14.2.0"
gxx_real="$toolchain_root/bin/aarch64-archr-linux-gnu-g++-14.2.0"
cpp_real="$toolchain_root/bin/aarch64-archr-linux-gnu-cpp"
ar_real="$toolchain_root/bin/aarch64-archr-linux-gnu-ar"
ranlib_real="$toolchain_root/bin/aarch64-archr-linux-gnu-ranlib"
nm_real="$toolchain_root/bin/aarch64-archr-linux-gnu-nm"
objcopy_real="$toolchain_root/bin/aarch64-archr-linux-gnu-objcopy"
strip_real="$toolchain_root/bin/aarch64-archr-linux-gnu-strip"
objdump_real="$toolchain_root/bin/aarch64-archr-linux-gnu-objdump"
readelf_real="$toolchain_root/bin/aarch64-archr-linux-gnu-readelf"
addr2line_real="$toolchain_root/bin/aarch64-archr-linux-gnu-addr2line"
ld_real="$toolchain_root/bin/aarch64-archr-linux-gnu-ld"
ld_bfd_real="$toolchain_root/bin/aarch64-archr-linux-gnu-ld.bfd"
ld_gold_real="$toolchain_root/bin/aarch64-archr-linux-gnu-ld.gold"
gcc_ar_real="$toolchain_root/bin/aarch64-archr-linux-gnu-gcc-ar"
gcc_ranlib_real="$toolchain_root/bin/aarch64-archr-linux-gnu-gcc-ranlib"
cxxfilt_real="$toolchain_root/bin/aarch64-archr-linux-gnu-c++filt"
lto_dump_real="$toolchain_root/bin/aarch64-archr-linux-gnu-lto-dump"
cc1_real="$toolchain_root/lib/gcc/aarch64-archr-linux-gnu/14.2.0/cc1"
cc1plus_real="$toolchain_root/lib/gcc/aarch64-archr-linux-gnu/14.2.0/cc1plus"
collect2_real="$toolchain_root/lib/gcc/aarch64-archr-linux-gnu/14.2.0/collect2"
as_real="$toolchain_triplet_root/bin/as"
ld_triplet_real="$toolchain_triplet_root/bin/ld"
ld_bfd_triplet_real="$toolchain_triplet_root/bin/ld.bfd"
ld_gold_triplet_real="$toolchain_triplet_root/bin/ld.gold"
lto1_real="$toolchain_root/lib/gcc/aarch64-archr-linux-gnu/14.2.0/lto1"
lto_wrapper_real="$toolchain_root/lib/gcc/aarch64-archr-linux-gnu/14.2.0/lto-wrapper"

webp_lib="$(resolve_repo_path "$sysroot/usr/lib/libwebp.so")"
webp_demux_lib="$(resolve_repo_path "$sysroot/usr/lib/libwebpdemux.so")"
freetype_lib="$(resolve_repo_path "$sysroot/usr/lib/libfreetype.so")"
fontconfig_lib="$(resolve_repo_path "$sysroot/usr/lib/libfontconfig.so")"
openssl_ssl_lib="$(resolve_repo_path "$sysroot/usr/lib/libssl.so")"
openssl_crypto_lib="$(resolve_repo_path "$sysroot/usr/lib/libcrypto.so")"
wayland_client_lib="$(resolve_repo_path "$sdl3_wayland_libs/libwayland-client.so.0.25.0")"
wayland_egl_lib="$(resolve_repo_path "$sdl3_wayland_libs/libwayland-egl.so.1.25.0")"

join_by_colon() {
	local IFS=':'
	printf '%s\n' "$*"
}

build_sysroot_overlay() {
	local link target resolved rel dest parent repaired=0
	local -a repaired_entries=()

	rm -rf "$sysroot_overlay_dir"
	mkdir -p "$sysroot_overlay_dir"

	while IFS= read -r -d '' link; do
		[[ -L "$link" ]] || continue
		target="$(readlink "$link")"
		[[ "$target" == /work/* ]] || continue
		resolved="$(resolve_repo_path "$target")"
		rel="${link#"$sysroot"/}"
		dest="$sysroot_overlay_dir/$rel"
		parent="$(dirname "$dest")"
		mkdir -p "$parent"
		ln -sfn "$resolved" "$dest"
		repaired_entries+=("${link#"$sysroot"/} -> ${resolved}")
		((++repaired))
	done < <(find "$sysroot" -type l -print0)

	printf 'sysroot overlay repaired links: %d\n' "$repaired"
	for link in "${repaired_entries[@]}"; do
		printf '  %s\n' "$link"
	done
}

if [[ "${CLEAN:-0}" == "1" && -d "$build_root" ]]; then
	rm -rf "$build_root"
fi

mkdir -p "$build_root"

require_file "$source_root/CMakeLists.txt" "upstream source tree"
require_dir "$toolchain_root" "Arch-R toolchain root"
require_dir "$toolchain_triplet_root" "Arch-R triplet toolchain root"
require_dir "$sysroot" "Arch-R sysroot"
require_dir "$toolchain_root/lib" "toolchain library directory"
require_dir "$toolchain_triplet_root/lib" "target lib directory"
require_dir "$toolchain_triplet_root/lib64" "target lib64 directory"
require_dir "$toolchain_root/x86_64-pc-linux-gnu/aarch64-archr-linux-gnu/lib" "toolchain host-side lib directory"
require_dir "$toolchain_root/lib/gcc/aarch64-archr-linux-gnu/14.2.0" "GCC runtime library directory"
require_dir "$toolchain_root/lib/gcc/aarch64-archr-linux-gnu/14.2.0/plugin" "GCC plugin library directory"
require_dir "$sdl3_build_root" "rebuilt SDL3 build tree"
require_dir "$sdl3_pkgconfig_root" "rebuilt SDL3 pkgconfig shims"
require_dir "$sdl3_wayland_headers" "rebuilt SDL3 Wayland headers"
require_dir "$sdl3_wayland_libs" "rebuilt SDL3 Wayland libraries"
require_dir "$sysroot/usr/share/WebP/cmake" "WebP CMake package directory"
require_file "$cmake_real" "toolchain cmake.real"
require_file "$gcc_real" "toolchain gcc"
require_file "$gxx_real" "toolchain g++"
require_file "$cpp_real" "toolchain cpp"
require_file "$ar_real" "toolchain ar"
require_file "$ranlib_real" "toolchain ranlib"
require_file "$nm_real" "toolchain nm"
require_file "$objcopy_real" "toolchain objcopy"
require_file "$strip_real" "toolchain strip"
require_file "$objdump_real" "toolchain objdump"
require_file "$readelf_real" "toolchain readelf"
require_file "$addr2line_real" "toolchain addr2line"
require_file "$ld_real" "toolchain ld"
require_file "$ld_bfd_real" "toolchain ld.bfd"
require_file "$ld_gold_real" "toolchain ld.gold"
require_file "$gcc_ar_real" "toolchain gcc-ar"
require_file "$gcc_ranlib_real" "toolchain gcc-ranlib"
require_file "$cxxfilt_real" "toolchain c++filt"
require_file "$lto_dump_real" "toolchain lto-dump"
require_file "$cc1_real" "toolchain cc1"
require_file "$cc1plus_real" "toolchain cc1plus"
require_file "$collect2_real" "toolchain collect2"
require_file "$as_real" "toolchain as"
require_file "$ld_triplet_real" "toolchain ld"
require_file "$ld_bfd_triplet_real" "toolchain ld.bfd"
require_file "$ld_gold_triplet_real" "toolchain ld.gold"
require_file "$lto1_real" "toolchain lto1"
require_file "$lto_wrapper_real" "toolchain lto-wrapper"
require_dir "${steamrt_root}/var/tmp-5LR7R3/usr/lib/x86_64-linux-gnu" "Steam Linux Runtime compatibility library directory"
require_file "$steamrt_loader" "Steam Linux Runtime loader"
require_file "$sdl3_build_root/SDL3Config.cmake" "rebuilt SDL3 config"
require_file "$sdl3_build_root/libSDL3.so.0.2.6" "rebuilt SDL3 shared library"
require_file "$sdl3_build_root/include-config-release/build_config/SDL_build_config.h" "rebuilt SDL3 build config"
require_file "$sdl3_pkgconfig_root/wayland-client.pc" "Wayland pkg-config shim"
require_file "$sdl3_pkgconfig_root/wayland-egl.pc" "Wayland EGL pkg-config shim"
require_file "$sdl3_pkgconfig_root/wayland-cursor.pc" "Wayland cursor pkg-config shim"
require_file "$sdl3_pkgconfig_root/xkbcommon.pc" "xkbcommon pkg-config shim"
require_file "$sdl3_pkgconfig_root/egl.pc" "EGL pkg-config shim"

require_executable "$pkg_config_bin" "pkg-config"
require_executable "$ninja_bin" "ninja"
require_executable "$sha256sum_bin" "sha256sum"
require_executable "$file_bin" "file"
require_executable "$readelf_bin" "readelf"

if ! grep -q '#define SDL_VIDEO_DRIVER_WAYLAND 1' \
	"$sdl3_build_root/include-config-release/build_config/SDL_build_config.h"; then
	die "rebuilt SDL3 was not configured with SDL_VIDEO_DRIVER_WAYLAND"
fi

mkdir -p "$build_root"
mkdir -p "$wrapper_dir"
mkdir -p "$gcc_helper_dir"
mkdir -p "$build_pkgconfig_dir"
build_sysroot_overlay

sysroot_overlay_libdirs=()
while IFS= read -r -d '' dir; do
	sysroot_overlay_libdirs+=("$dir")
done < <(find "$sysroot_overlay_dir" \( -path '*/lib' -o -path '*/lib64' -o -path '*/usr/lib' -o -path '*/usr/lib64' \) -type d -print0 | sort -z)

if [[ "${#sysroot_overlay_libdirs[@]}" -eq 0 ]]; then
	die "no repaired sysroot library directories were created"
fi

sysroot_overlay_libpath="$(join_by_colon "${sysroot_overlay_libdirs[@]}")"

sysroot_overlay_ldflags=""
for dir in "${sysroot_overlay_libdirs[@]}"; do
	sysroot_overlay_ldflags+=" -Wl,-rpath-link,$dir -L$dir"
done

cat >"$build_pkgconfig_dir/wayland-protocols.pc" <<'EOF'
prefix=/usr
exec_prefix=${prefix}
datadir=${prefix}/share
pkgdatadir=${datadir}/wayland-protocols

Name: wayland-protocols
Description: Wayland protocol XML data
Version: 1.0
EOF

cat >"$wrapper_dir/toolchain-wrap.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail

script_name="\$(basename "\$0")"
toolchain_bin_dir="$toolchain_root/bin"
gcc_helper_dir="$gcc_helper_dir"
runtime_loader="$steamrt_loader"
runtime_libpath="$steamrt_libpath"

	case "\$script_name" in
		aarch64-archr-linux-gnu-gcc|aarch64-archr-linux-gnu-g++|aarch64-archr-linux-gnu-cpp|aarch64-archr-linux-gnu-ar|aarch64-archr-linux-gnu-ranlib|aarch64-archr-linux-gnu-nm|aarch64-archr-linux-gnu-objcopy|aarch64-archr-linux-gnu-strip|aarch64-archr-linux-gnu-objdump|aarch64-archr-linux-gnu-readelf|aarch64-archr-linux-gnu-addr2line|aarch64-archr-linux-gnu-ld|aarch64-archr-linux-gnu-ld.bfd|aarch64-archr-linux-gnu-ld.gold|aarch64-archr-linux-gnu-gcc-ar|aarch64-archr-linux-gnu-gcc-ranlib|aarch64-archr-linux-gnu-c++filt|aarch64-archr-linux-gnu-lto-dump|ld.bfd|ld.gold)
    case "\$script_name" in
      aarch64-archr-linux-gnu-gcc) tool="$gcc_real" ;;
      aarch64-archr-linux-gnu-g++) tool="$gxx_real" ;;
      aarch64-archr-linux-gnu-cpp) tool="$cpp_real" ;;
      aarch64-archr-linux-gnu-ar) tool="$ar_real" ;;
      aarch64-archr-linux-gnu-ranlib) tool="$ranlib_real" ;;
      aarch64-archr-linux-gnu-nm) tool="$nm_real" ;;
      aarch64-archr-linux-gnu-objcopy) tool="$objcopy_real" ;;
      aarch64-archr-linux-gnu-strip) tool="$strip_real" ;;
      aarch64-archr-linux-gnu-objdump) tool="$objdump_real" ;;
      aarch64-archr-linux-gnu-readelf) tool="$readelf_real" ;;
      aarch64-archr-linux-gnu-addr2line) tool="$addr2line_real" ;;
      aarch64-archr-linux-gnu-ld) tool="$ld_real" ;;
      aarch64-archr-linux-gnu-ld.bfd) tool="$ld_bfd_real" ;;
      aarch64-archr-linux-gnu-ld.gold) tool="$ld_gold_real" ;;
      ld.bfd) tool="$ld_bfd_triplet_real" ;;
      ld.gold) tool="$ld_gold_triplet_real" ;;
      aarch64-archr-linux-gnu-gcc-ar) tool="$gcc_ar_real" ;;
      aarch64-archr-linux-gnu-gcc-ranlib) tool="$gcc_ranlib_real" ;;
      aarch64-archr-linux-gnu-c++filt) tool="$cxxfilt_real" ;;
      aarch64-archr-linux-gnu-lto-dump) tool="$lto_dump_real" ;;
    esac
    case "\$script_name" in
      aarch64-archr-linux-gnu-gcc|aarch64-archr-linux-gnu-g++|aarch64-archr-linux-gnu-cpp)
        exec "\$runtime_loader" --library-path "\$runtime_libpath" "\$tool" --sysroot="$sysroot" -B"\$gcc_helper_dir" "\$@"
        ;;
	      *)
	        exec "\$runtime_loader" --library-path "\$runtime_libpath" "\$tool" "\$@"
	        ;;
    esac
    ;;
  cc1)
    exec "\$runtime_loader" --library-path "\$runtime_libpath" "$cc1_real" "\$@"
    ;;
  cc1plus)
    exec "\$runtime_loader" --library-path "\$runtime_libpath" "$cc1plus_real" "\$@"
    ;;
  collect2)
    exec "\$runtime_loader" --library-path "\$runtime_libpath" "$collect2_real" "\$@"
    ;;
  as)
    exec "\$runtime_loader" --library-path "\$runtime_libpath" "$as_real" "\$@"
    ;;
  ld)
    exec "\$runtime_loader" --library-path "\$runtime_libpath" "$ld_triplet_real" "\$@"
    ;;
  ld.bfd)
    exec "\$runtime_loader" --library-path "\$runtime_libpath" "$ld_bfd_triplet_real" "\$@"
    ;;
  ld.gold)
    exec "\$runtime_loader" --library-path "\$runtime_libpath" "$ld_gold_triplet_real" "\$@"
    ;;
  lto1)
    exec "\$runtime_loader" --library-path "\$runtime_libpath" "$lto1_real" "\$@"
    ;;
  lto-wrapper)
    exec "\$runtime_loader" --library-path "\$runtime_libpath" "$lto_wrapper_real" "\$@"
    ;;
  *)
    echo "Unknown tool wrapper name: \$script_name" >&2
    exit 127
    ;;
esac
EOF
chmod +x "$wrapper_dir/toolchain-wrap.sh"

for tool in \
	aarch64-archr-linux-gnu-gcc \
	aarch64-archr-linux-gnu-g++ \
	aarch64-archr-linux-gnu-cpp \
	aarch64-archr-linux-gnu-ar \
	aarch64-archr-linux-gnu-ranlib \
	aarch64-archr-linux-gnu-nm \
	aarch64-archr-linux-gnu-objcopy \
	aarch64-archr-linux-gnu-strip \
	aarch64-archr-linux-gnu-objdump \
	aarch64-archr-linux-gnu-readelf \
	aarch64-archr-linux-gnu-addr2line \
	aarch64-archr-linux-gnu-ld \
	aarch64-archr-linux-gnu-ld.bfd \
	aarch64-archr-linux-gnu-ld.gold \
	aarch64-archr-linux-gnu-gcc-ar \
	aarch64-archr-linux-gnu-gcc-ranlib \
	aarch64-archr-linux-gnu-c++filt \
	aarch64-archr-linux-gnu-lto-dump \
	cc1 \
	cc1plus \
	collect2 \
	as \
	ld \
	ld.bfd \
	ld.gold \
	lto1 \
	lto-wrapper
do
	ln -sfn toolchain-wrap.sh "$wrapper_dir/$tool"
done

for helper in cc1 cc1plus collect2 as ld ld.bfd ld.gold lto1 lto-wrapper; do
	ln -sfn "../toolchain-wrappers/toolchain-wrap.sh" "$gcc_helper_dir/$helper"
done

cat >"$toolchain_file" <<EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_VERSION 1)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_SYSROOT "$sysroot")
set(CMAKE_C_COMPILER   "$wrapper_dir/aarch64-archr-linux-gnu-gcc")
set(CMAKE_CXX_COMPILER "$wrapper_dir/aarch64-archr-linux-gnu-g++")
set(CMAKE_CPP_COMPILER "$wrapper_dir/aarch64-archr-linux-gnu-cpp")
set(CMAKE_ASM_COMPILER "$wrapper_dir/aarch64-archr-linux-gnu-gcc")
set(CMAKE_AR "$wrapper_dir/aarch64-archr-linux-gnu-ar")
set(CMAKE_RANLIB "$wrapper_dir/aarch64-archr-linux-gnu-ranlib")
set(CMAKE_NM "$wrapper_dir/aarch64-archr-linux-gnu-nm")
set(CMAKE_OBJCOPY "$wrapper_dir/aarch64-archr-linux-gnu-objcopy")
set(CMAKE_STRIP "$wrapper_dir/aarch64-archr-linux-gnu-strip")
set(CMAKE_OBJDUMP "$wrapper_dir/aarch64-archr-linux-gnu-objdump")
set(CMAKE_ADDR2LINE "$wrapper_dir/aarch64-archr-linux-gnu-addr2line")
set(CMAKE_LINKER "$wrapper_dir/aarch64-archr-linux-gnu-ld")
set(CMAKE_C_COMPILER_AR "$wrapper_dir/aarch64-archr-linux-gnu-gcc-ar")
set(CMAKE_C_COMPILER_RANLIB "$wrapper_dir/aarch64-archr-linux-gnu-gcc-ranlib")
set(CMAKE_CXX_COMPILER_AR "$wrapper_dir/aarch64-archr-linux-gnu-gcc-ar")
set(CMAKE_CXX_COMPILER_RANLIB "$wrapper_dir/aarch64-archr-linux-gnu-gcc-ranlib")
set(CMAKE_FIND_ROOT_PATH "$sysroot")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
EOF

cat >"$wrapper_dir/cmake" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "$steamrt_loader" --library-path "$steamrt_libpath" "$cmake_real" "\$@"
EOF
chmod +x "$wrapper_dir/cmake"

export PKG_CONFIG_SYSROOT_DIR="$sysroot"
export PKG_CONFIG_PATH=""
export PKG_CONFIG_LIBDIR="$build_pkgconfig_dir:$sdl3_pkgconfig_root:$sysroot/usr/lib/pkgconfig:$sysroot/usr/share/pkgconfig"
export LIBRARY_PATH="$sysroot_overlay_libpath:$sysroot/usr/lib:$sysroot/lib${LIBRARY_PATH:+:$LIBRARY_PATH}"
export SDL3_DIR="$sdl3_build_root"
export CMAKE_PREFIX_PATH="$sdl3_build_root${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"
export PATH="/usr/bin:/bin:${PATH:-}"

cmake_args=(
	-S "$source_root"
	-B "$build_root"
	-G Ninja
	-DCMAKE_TOOLCHAIN_FILE="$toolchain_file"
		-DCMAKE_BUILD_TYPE=RelWithDebInfo
		-DCMAKE_EXPORT_COMPILE_COMMANDS=ON
		-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
		-DCMAKE_C_FLAGS="-march=armv8-a -mno-outline-atomics"
		-DCMAKE_CXX_FLAGS="-march=armv8-a -mno-outline-atomics"
	-DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=bfd$sysroot_overlay_ldflags -L$sysroot/usr/lib -L$sysroot/lib"
	-DCMAKE_MODULE_LINKER_FLAGS="-fuse-ld=bfd$sysroot_overlay_ldflags -L$sysroot/usr/lib -L$sysroot/lib"
	-DCMAKE_SHARED_LINKER_FLAGS="-fuse-ld=bfd$sysroot_overlay_ldflags -L$sysroot/usr/lib -L$sysroot/lib"
	-DHOST_PAGE_SIZE=4096
	-DHOST_CACHE_LINE_SIZE=64
	-DWebP_DIR="$sysroot/usr/share/WebP/cmake"
	-DWebP_INCLUDE_DIR="$sysroot/usr/include"
	-DWebP_LIBRARY="$webp_lib"
	-DWebP_DEMUX_LIBRARY="$webp_demux_lib"
	-D_WebP_REQUIRED_LIBS_FOUND=ON
	-DFREETYPE_INCLUDE_DIRS="$sysroot/usr/include/freetype2"
	-DFREETYPE_LIBRARY="$freetype_lib"
	-DFontconfig_INCLUDE_DIR="$sysroot/usr/include"
	-DFontconfig_LIBRARY="$fontconfig_lib"
	-DOPENSSL_ROOT_DIR="$sysroot/usr"
	-DOPENSSL_USE_STATIC_LIBS=OFF
	-DOPENSSL_SSL_LIBRARY="$openssl_ssl_lib"
	-DOPENSSL_CRYPTO_LIBRARY="$openssl_crypto_lib"
	-DWayland_Client_INCLUDE_DIR="$sdl3_wayland_headers"
	-DWayland_Client_LIBRARY="$wayland_client_lib"
	-DWayland_Egl_INCLUDE_DIR="$sdl3_wayland_headers"
	-DWayland_Egl_LIBRARY="$wayland_egl_lib"
	-DENABLE_TESTS=OFF
	-DENABLE_QT_UI=OFF
	-DENABLE_GSRUNNER=OFF
	-DENABLE_VURUNNER=OFF
	-DENABLE_EERUNNER=OFF
	-DENABLE_LIBRETRO=OFF
	-DENABLE_SDL_FRONTEND=ON
	-DENABLE_RECOMPILER_TEST_HOOKS=OFF
	-DUSE_OPENGL=ON
	-DUSE_VULKAN=OFF
	-DUSE_BACKTRACE=OFF
	-DX11_API=OFF
	-DWAYLAND_API=ON
	-DSDL3_DIR="$sdl3_build_root"
)

printf '== build context ==\n'
printf 'repo root: %s\n' "$repo_root"
printf 'build root: %s\n' "$build_root"
printf 'source root: %s\n' "$source_root"
printf 'toolchain root: %s\n' "$toolchain_root"
printf 'toolchain file: %s\n' "$toolchain_file"
printf 'sysroot: %s\n' "$sysroot"
printf 'SDL3 dir: %s\n' "$sdl3_build_root"
printf 'Steam runtime loader: %s\n' "$steamrt_loader"
printf 'Steam runtime libpath: %s\n' "$steamrt_libpath"
printf 'CLEAN: %s\n' "${CLEAN:-0}"
printf 'JOBS: %s\n' "${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf 4)}"

"$wrapper_dir/cmake" "${cmake_args[@]}"

jobs="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf 4)}"
"$ninja_bin" -C "$build_root" -j "$jobs" pcsx2-sdl

binary=""
while IFS= read -r candidate; do
	if [[ -z "$candidate" ]]; then
		continue
	fi
	binary="$candidate"
	break
done < <(find "$build_root" -type f \( -name 'armsx2-sdl' -o -name 'pcsx2-sdl' \) | sort)

[[ -n "$binary" ]] || die "pcsx2-sdl binary not found after build"

printf '\n== build output ==\n'
printf 'binary: %s\n' "$binary"
"$file_bin" "$binary"
printf '\nneeded libraries:\n'
"$readelf_bin" -d "$binary" | sed -n '/NEEDED/p'
printf '\nsha256:\n'
"$sha256sum_bin" "$binary"
