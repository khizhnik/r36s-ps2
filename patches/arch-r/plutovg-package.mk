# Arch-R plutovg package recipe
PKG_NAME="plutovg"
PKG_VERSION="1.3.3"
PKG_SHA256="2b0d17a6e016f47b86f9c00e2cb82600041b1ea1f7d2a00c2d46ae542cbfed3c"
PKG_LICENSE="MIT"
PKG_SITE="https://github.com/sammycage/plutovg"
PKG_URL="https://github.com/sammycage/plutovg/archive/refs/tags/v${PKG_VERSION}.tar.gz"
PKG_DEPENDS_TARGET="toolchain"
PKG_LONGDESC="Tiny 2D vector graphics library in C."
PKG_TOOLCHAIN="cmake"
PKG_BUILD_FLAGS="+pic"

PKG_CMAKE_OPTS_TARGET="-DBUILD_SHARED_LIBS=ON \
                       -DPLUTOVG_BUILD_EXAMPLES=OFF"
