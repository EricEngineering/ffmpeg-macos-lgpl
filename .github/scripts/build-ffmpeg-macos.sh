#!/usr/bin/env bash
#
# Build a STATIC, universal2 (arm64 + x86_64), LGPL FFmpeg (ffmpeg + ffprobe) with
# libvpx (VP8/VP9) + libwebp — and NO GPL components (no x264/x265). Proprietary
# consumers (e.g. ArcaneAtlas-Vagabond) must ship LGPL ffmpeg; the apps transcode
# to VP9 via libvpx (royalty-free), so nothing GPL is required.
#
# Output: ./out/{ffmpeg,ffprobe} (universal2, +x). Override the dir with $OUT.
# Prereqs (install in CI before running): nasm, cmake, pkg-config.
#
# NOTE: universal2 cross-compilation is fiddly. Bumping any *_VER below is a
# deliberate change — rebuild via the workflow and publish under a new tag.
set -euo pipefail

FFMPEG_VER="7.1"
LIBVPX_VER="1.14.1"
LIBWEBP_VER="1.4.0"
export MACOSX_DEPLOYMENT_TARGET="11.0"

ROOT="$(pwd)"
OUT="${OUT:-$ROOT/out}"
WORK="$(mktemp -d)"
JOBS="$(sysctl -n hw.ncpu)"
mkdir -p "$OUT"

cd "$WORK"
echo "==> fetching sources"
curl -fL "https://github.com/webmproject/libvpx/archive/refs/tags/v${LIBVPX_VER}.tar.gz"   -o libvpx.tgz
curl -fL "https://github.com/webmproject/libwebp/archive/refs/tags/v${LIBWEBP_VER}.tar.gz" -o libwebp.tgz
curl -fL "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VER}.tar.xz"                          -o ffmpeg.txz

build_arch() {
  local ARCH="$1"                       # arm64 | x86_64
  local PREFIX="$WORK/prefix-$ARCH"
  local AF="-arch $ARCH"
  mkdir -p "$PREFIX"
  echo "==> building deps + ffmpeg for $ARCH"

  # ---- libvpx (VP8/VP9) ----
  rm -rf "vpx-$ARCH" && mkdir "vpx-$ARCH" && tar xf libvpx.tgz -C "vpx-$ARCH" --strip-components=1
  ( cd "vpx-$ARCH"
    CC="clang" CFLAGS="$AF" LDFLAGS="$AF" ./configure --prefix="$PREFIX" \
      --target="${ARCH}-darwin20-gcc" --enable-pic --enable-vp8 --enable-vp9 \
      --enable-static --disable-shared --disable-examples --disable-tools \
      --disable-docs --disable-unit-tests
    make -j"$JOBS" && make install )

  # ---- libwebp (+ mux, needed for ffmpeg's animated-webp encoder) ----
  rm -rf "webp-$ARCH" && mkdir "webp-$ARCH" && tar xf libwebp.tgz -C "webp-$ARCH" --strip-components=1
  ( cd "webp-$ARCH"
    cmake -B build -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_OSX_ARCHITECTURES="$ARCH" \
      -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
      -DWEBP_BUILD_ANIM_UTILS=OFF -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF \
      -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF -DWEBP_BUILD_VWEBP=OFF \
      -DWEBP_BUILD_WEBPINFO=OFF -DWEBP_BUILD_WEBPMUX=ON -DWEBP_BUILD_EXTRAS=OFF
    cmake --build build -j"$JOBS" && cmake --install build )

  # ---- ffmpeg (LGPL, static; ffmpeg + ffprobe only) ----
  rm -rf "ff-$ARCH" && mkdir "ff-$ARCH" && tar xf ffmpeg.txz -C "ff-$ARCH" --strip-components=1
  ( cd "ff-$ARCH"
    local cross=()
    if [ "$ARCH" != "$(uname -m)" ]; then
      cross=(--enable-cross-compile --arch="$ARCH" --target-os=darwin --cc="clang $AF")
    fi
    PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" ./configure --prefix="$PREFIX" \
      --disable-gpl --disable-nonfree --enable-static --disable-shared \
      --disable-doc --disable-debug --disable-programs --enable-ffmpeg --enable-ffprobe \
      --enable-libvpx --enable-libwebp \
      --extra-cflags="$AF -I$PREFIX/include" --extra-ldflags="$AF -L$PREFIX/lib" \
      "${cross[@]}"
    make -j"$JOBS" )
  cp "ff-$ARCH/ffmpeg"  "$WORK/ffmpeg-$ARCH"
  cp "ff-$ARCH/ffprobe" "$WORK/ffprobe-$ARCH"
}

build_arch arm64
build_arch x86_64

echo "==> lipo → universal2"
lipo -create "$WORK/ffmpeg-arm64"  "$WORK/ffmpeg-x86_64"  -output "$OUT/ffmpeg"
lipo -create "$WORK/ffprobe-arm64" "$WORK/ffprobe-x86_64" -output "$OUT/ffprobe"
chmod +x "$OUT/ffmpeg" "$OUT/ffprobe"
echo "ffmpeg archs:"; lipo -archs "$OUT/ffmpeg"
