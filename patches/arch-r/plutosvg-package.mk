# Arch-R plutosvg package recipe
PKG_NAME="plutosvg"
PKG_VERSION="0.0.8"
PKG_SHA256="49d5cfe772d3aa10cd4879f2f6e189f5083c08e4c8ea01bf3d5b87c97dfca7d2"
PKG_LICENSE="MIT"
PKG_SITE="https://github.com/sammycage/plutosvg"
PKG_URL="https://github.com/sammycage/plutosvg/archive/refs/tags/v${PKG_VERSION}.tar.gz"
PKG_DEPENDS_TARGET="toolchain plutovg"
PKG_LONGDESC="Tiny SVG rendering library in C."
PKG_TOOLCHAIN="cmake"
PKG_BUILD_FLAGS="+pic"

PKG_CMAKE_OPTS_TARGET="-DBUILD_SHARED_LIBS=ON \
                       -DPLUTOSVG_BUILD_EXAMPLES=OFF \
                       -DPLUTOSVG_ENABLE_FREETYPE=OFF"
