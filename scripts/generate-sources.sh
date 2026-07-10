#!/bin/bash
set -e

ARCHITECTURES="aarch64"
ADDITIONAL_PACKAGES="xkeyboard-config"
APP_TYPE="f-droid"

while [[ $# -gt 0 ]]; do
    case $1 in
        --architectures) ARCHITECTURES="$2"; shift 2 ;;
        --additional-packages) ADDITIONAL_PACKAGES="$2"; shift 2 ;;
        --app-type) APP_TYPE="$2"; shift 2 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

echo "Generating Termux sources..."
echo "Architectures: $ARCHITECTURES"
echo "App type: $APP_TYPE"

# Clone
git clone --depth 1 https://github.com/termux/termux-app.git termux-app-src
git clone --depth 1 https://github.com/termux/termux-packages.git termux-packages-src

# Apply patches
if [ -d "$APP_TYPE-patches/app-patches" ]; then
    cd termux-app-src
    for p in ../$APP_TYPE-patches/app-patches/*.patch; do
        [ -f "$p" ] && patch -p1 < "$p"
    done
    cd ..
fi

if [ -d "$APP_TYPE-patches/bootstrap-patches" ]; then
    cd termux-packages-src
    for p in ../$APP_TYPE-patches/bootstrap-patches/*.patch; do
        [ -f "$p" ] && patch -p1 < "$p"
    done
    cd ..
fi

# Build bootstrap
cd termux-packages-src
./scripts/run-docker.sh ./scripts/build-bootstraps.sh \
    --architectures "$ARCHITECTURES" \
    --add "$ADDITIONAL_PACKAGES" \
    --disable-bootstrap-second-stage
mkdir -p ../output/bootstrap
cp bootstrap-*.tar.xz ../output/bootstrap/
cp -r xz-* ../output/bootstrap/
cd ..

# Extract terminal-emulator
OUTPUT="output/terminal-emulator"
mkdir -p "$OUTPUT"

cp -r termux-app-src/terminal-emulator "$OUTPUT/"
cp -r termux-app-src/terminal-view "$OUTPUT/"
cp -r termux-app-src/termux-shared "$OUTPUT/"

mkdir -p "$OUTPUT/jni"
cp -r termux-app-src/src/main/jni/*.c "$OUTPUT/jni/" 2>/dev/null || true
cp -r termux-app-src/src/main/jni/Android.mk "$OUTPUT/jni/" 2>/dev/null || true

mkdir -p "$OUTPUT/assets"
cp output/bootstrap/bootstrap-*.tar.xz "$OUTPUT/assets/"

for arch in ${ARCHITECTURES//,/ }; do
    if [ -d "output/bootstrap/xz-$arch" ]; then
        mkdir -p "$OUTPUT/assets/xz-$arch"
        cp output/bootstrap/xz-$arch/* "$OUTPUT/assets/xz-$arch/"
    fi
done

mkdir -p "$OUTPUT/res"
cp -r termux-app-src/src/main/res/* "$OUTPUT/res/" 2>/dev/null || true

echo "Done! Output: $OUTPUT"