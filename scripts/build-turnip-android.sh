#!/usr/bin/env bash
set -euo pipefail

MESA_REPO="${MESA_REPO:-https://gitlab.freedesktop.org/mesa/mesa.git}"
MESA_REF="${MESA_REF:-main}"
ANDROID_API="${ANDROID_API:-26}"
ANDROID_ABI="${ANDROID_ABI:-arm64-v8a}"
WORK_DIR="${WORK_DIR:-$PWD/work}"
MESA_DIR="${MESA_DIR:-$WORK_DIR/mesa}"
BUILD_DIR="${BUILD_DIR:-$WORK_DIR/build-android}"
INSTALL_DIR="${INSTALL_DIR:-$WORK_DIR/install-android}"
ADRENOTOOLS_NAME="${ADRENOTOOLS_NAME:-Mesa Turnip driver}"
ADRENOTOOLS_DESCRIPTION="${ADRENOTOOLS_DESCRIPTION:-Compiled from Mesa source}"
ADRENOTOOLS_AUTHOR="${ADRENOTOOLS_AUTHOR:-Kap-TRNP}"
ADRENOTOOLS_PACKAGE_VERSION="${ADRENOTOOLS_PACKAGE_VERSION:-1}"
ADRENOTOOLS_DRIVER_VERSION="${ADRENOTOOLS_DRIVER_VERSION:-Mesa $MESA_REF}"
ADRENOTOOLS_LIBRARY_NAME="${ADRENOTOOLS_LIBRARY_NAME:-vulkan.ad07xx.so}"
ADRENOTOOLS_PACKAGE_NAME="${ADRENOTOOLS_PACKAGE_NAME:-turnip-adrenotools-$ANDROID_ABI.zip}"

case "$ANDROID_ABI" in
  arm64-v8a)
    ANDROID_CPU="aarch64"
    ANDROID_CPU_FAMILY="aarch64"
    ANDROID_TARGET="aarch64-linux-android"
    ;;
  *)
    echo "Unsupported ANDROID_ABI: $ANDROID_ABI" >&2
    echo "Supported values: arm64-v8a" >&2
    exit 1
    ;;
esac

NDK_ROOT="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}"
if [[ -z "$NDK_ROOT" ]]; then
  echo "ANDROID_NDK_HOME or ANDROID_NDK_ROOT must be set." >&2
  exit 1
fi

case "$(uname -s)" in
  Linux)
    HOST_TAG="linux-x86_64"
    ;;
  Darwin)
    HOST_TAG="darwin-x86_64"
    ;;
  *)
    echo "Unsupported build host: $(uname -s)" >&2
    exit 1
    ;;
esac

if [[ ! -d "$NDK_ROOT/toolchains/llvm/prebuilt/$HOST_TAG" ]]; then
  echo "Android NDK LLVM toolchain was not found under: $NDK_ROOT" >&2
  exit 1
fi

TOOLCHAIN="$NDK_ROOT/toolchains/llvm/prebuilt/$HOST_TAG"
BIN_DIR="$TOOLCHAIN/bin"
SYSROOT="$TOOLCHAIN/sysroot"
CROSS_FILE="$WORK_DIR/android-$ANDROID_ABI.ini"

mkdir -p "$WORK_DIR"

if [[ ! -d "$MESA_DIR/.git" ]]; then
  git clone --depth 1 --branch "$MESA_REF" "$MESA_REPO" "$MESA_DIR"
else
  git -C "$MESA_DIR" fetch --depth 1 origin "$MESA_REF"
  git -C "$MESA_DIR" checkout FETCH_HEAD
fi

cat > "$CROSS_FILE" <<EOF
[binaries]
c = '$BIN_DIR/${ANDROID_TARGET}${ANDROID_API}-clang'
cpp = '$BIN_DIR/${ANDROID_TARGET}${ANDROID_API}-clang++'
ar = '$BIN_DIR/llvm-ar'
strip = '$BIN_DIR/llvm-strip'
pkg-config = 'pkg-config'

[host_machine]
system = 'android'
cpu_family = '$ANDROID_CPU_FAMILY'
cpu = '$ANDROID_CPU'
endian = 'little'

[properties]
sys_root = '$SYSROOT'
EOF

rm -rf "$BUILD_DIR" "$INSTALL_DIR"

meson setup "$BUILD_DIR" "$MESA_DIR" \
  --cross-file "$CROSS_FILE" \
  --wrap-mode nofallback \
  --prefix "$INSTALL_DIR" \
  --libdir lib \
  --buildtype release \
  -Dandroid-stub=true \
  -Dplatform-sdk-version="$ANDROID_API" \
  -Dplatforms=android \
  -Dvulkan-drivers=freedreno \
  -Dfreedreno-kmds=kgsl \
  -Dgallium-drivers= \
  -Dllvm=disabled \
  -Dshared-llvm=disabled \
  -Degl=disabled \
  -Dgles1=disabled \
  -Dgles2=disabled \
  -Dopengl=false \
  -Dglx=disabled \
  -Dgbm=disabled \
  -Dshared-glapi=disabled \
  -Dvalgrind=disabled \
  -Dlibunwind=disabled \
  -Dzstd=disabled \
  -Dspirv-tools=disabled \
  -Dbuild-tests=false

ninja -C "$BUILD_DIR"
ninja -C "$BUILD_DIR" install

TURNIP_LIB="$(find "$INSTALL_DIR" "$BUILD_DIR" -name 'libvulkan_freedreno.so' -type f | head -n 1 || true)"
if [[ -z "$TURNIP_LIB" ]]; then
  echo "libvulkan_freedreno.so was not produced." >&2
  exit 1
fi

mkdir -p "$WORK_DIR/artifacts"
cp "$TURNIP_LIB" "$WORK_DIR/artifacts/libvulkan_freedreno.so"

PACKAGE_DIR="$WORK_DIR/adrenotools-package"
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"
cp "$TURNIP_LIB" "$PACKAGE_DIR/$ADRENOTOOLS_LIBRARY_NAME"

cat > "$PACKAGE_DIR/meta.json" <<EOF
{
  "schemaVersion": 1,
  "name": "$ADRENOTOOLS_NAME",
  "description": "$ADRENOTOOLS_DESCRIPTION",
  "author": "$ADRENOTOOLS_AUTHOR",
  "packageVersion": "$ADRENOTOOLS_PACKAGE_VERSION",
  "vendor": "Mesa",
  "driverVersion": "$ADRENOTOOLS_DRIVER_VERSION",
  "minApi": $ANDROID_API,
  "libraryName": "$ADRENOTOOLS_LIBRARY_NAME"
}
EOF

(cd "$PACKAGE_DIR" && zip -9 -q "$WORK_DIR/artifacts/$ADRENOTOOLS_PACKAGE_NAME" meta.json "$ADRENOTOOLS_LIBRARY_NAME")

echo "Turnip Android build completed: $WORK_DIR/artifacts/libvulkan_freedreno.so"
echo "AdrenoTools package completed: $WORK_DIR/artifacts/$ADRENOTOOLS_PACKAGE_NAME"
