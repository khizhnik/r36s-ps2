# Arch-R SDL3 package recipe
# Source of truth for the downstream SDL3 package added to the local Arch-R clone.

PKG_NAME="SDL3"
PKG_VERSION="3.2.6"
PKG_SHA256="096a0b843dd1124afda41c24bd05034af75af37e9a1b9d205cc0a70193b27e1a"
PKG_LICENSE="ZLIB"
PKG_SITE="https://github.com/libsdl-org/SDL"
PKG_URL="https://github.com/libsdl-org/SDL/releases/download/release-${PKG_VERSION}/SDL3-${PKG_VERSION}.tar.gz"
PKG_DEPENDS_TARGET="toolchain"
PKG_LONGDESC="Simple DirectMedia Layer 3."
PKG_TOOLCHAIN="cmake"
PKG_BUILD_FLAGS="+pic"

PKG_CMAKE_OPTS_TARGET="-DSDL_SHARED=ON \
                       -DSDL_STATIC=OFF \
                       -DSDL_TESTS=OFF \
                       -DSDL_TEST_LIBRARY=OFF \
                       -DSDL_INSTALL_DOCS=OFF \
                       -DSDL_INSTALL_TESTS=OFF \
                       -DSDL_UNIX_CONSOLE_BUILD=ON"
