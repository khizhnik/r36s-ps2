set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

if(NOT DEFINED ENV{ARCHR_SDK_ROOT})
  message(FATAL_ERROR "ARCHR_SDK_ROOT is not set")
endif()

set(ARCHR_SDK_ROOT "$ENV{ARCHR_SDK_ROOT}")
set(ARCHR_TOOLCHAIN_DIR "${ARCHR_SDK_ROOT}/toolchain")
set(ARCHR_TARGET_TRIPLET "aarch64-archr-linux-gnu")
set(ARCHR_SYSROOT "${ARCHR_TOOLCHAIN_DIR}/${ARCHR_TARGET_TRIPLET}/sysroot")
set(ARCHR_BIN_DIR "${ARCHR_TOOLCHAIN_DIR}/bin")

if(NOT EXISTS "${ARCHR_BIN_DIR}/${ARCHR_TARGET_TRIPLET}-gcc")
  message(FATAL_ERROR "Missing Arch-R cross compiler in ${ARCHR_BIN_DIR}")
endif()

set(CMAKE_C_COMPILER "${ARCHR_BIN_DIR}/${ARCHR_TARGET_TRIPLET}-gcc-14.2.0")
set(CMAKE_CXX_COMPILER "${ARCHR_BIN_DIR}/${ARCHR_TARGET_TRIPLET}-g++-14.2.0")
set(CMAKE_ASM_COMPILER "${ARCHR_BIN_DIR}/${ARCHR_TARGET_TRIPLET}-gcc-14.2.0")
set(CMAKE_AR "${ARCHR_BIN_DIR}/${ARCHR_TARGET_TRIPLET}-ar")
set(CMAKE_RANLIB "${ARCHR_BIN_DIR}/${ARCHR_TARGET_TRIPLET}-ranlib")
set(CMAKE_NM "${ARCHR_BIN_DIR}/${ARCHR_TARGET_TRIPLET}-nm")
set(CMAKE_OBJCOPY "${ARCHR_BIN_DIR}/${ARCHR_TARGET_TRIPLET}-objcopy")
set(CMAKE_OBJDUMP "${ARCHR_BIN_DIR}/${ARCHR_TARGET_TRIPLET}-objdump")
set(CMAKE_READELF "${ARCHR_BIN_DIR}/${ARCHR_TARGET_TRIPLET}-readelf")
set(CMAKE_STRIP "${ARCHR_BIN_DIR}/${ARCHR_TARGET_TRIPLET}-strip")
set(CMAKE_LINKER "${ARCHR_BIN_DIR}/${ARCHR_TARGET_TRIPLET}-ld")

set(CMAKE_SYSROOT "${ARCHR_SYSROOT}")
set(CMAKE_FIND_ROOT_PATH "${ARCHR_SYSROOT};${ARCHR_TOOLCHAIN_DIR}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# CMake's FindX11 module does not search the Arch-R sysroot's standard
# /usr/lib location for the core X11 library during cross-configure.
# Seed the canonical sysroot path so the headless runner can keep using the
# packaged X11 development surface without any source-tree changes.
set(X11_X11_LIB "${ARCHR_SYSROOT}/usr/lib/libX11.so" CACHE FILEPATH "X11 core library" FORCE)
set(X11_Xrandr_LIB "${ARCHR_SYSROOT}/usr/lib/libXrandr.so" CACHE FILEPATH "XRandR extension library" FORCE)
set(X11_API OFF CACHE BOOL "Disable X11 support for the headless eerunner profile" FORCE)
set(WAYLAND_API OFF CACHE BOOL "Disable Wayland support for the headless eerunner profile" FORCE)
set(USE_BACKTRACE OFF CACHE BOOL "Disable libbacktrace support for the headless eerunner profile" FORCE)

# Arch-R on RK3326/R36S is a 4 KiB-page ARM64 target with 64-byte cache lines.
# Seed these values here so the upstream CMake configure can stay fully
# cross-compile friendly without try_run().
set(HOST_PAGE_SIZE "4096" CACHE STRING "Reported host page size")
set(HOST_CACHE_LINE_SIZE "64" CACHE STRING "Reported host cache line size")

set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
