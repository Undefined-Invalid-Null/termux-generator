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

echo "=========================================="
echo "Generating Termux sources..."
echo "Architectures: $ARCHITECTURES"
echo "Additional packages: $ADDITIONAL_PACKAGES"
echo "App type: $APP_TYPE"
echo "=========================================="

# Clone
git clone --depth 1 https://github.com/termux/termux-app.git termux-app-src
git clone --depth 1 https://github.com/termux/termux-packages.git termux-packages-src
git clone --depth 1 https://github.com/termux/termux-am-library.git termux-am-library-src

# Move termux-am-library
if [ -d "termux-am-library-src/termux-am-library" ]; then
    mv termux-am-library-src/termux-am-library/ termux-app-src/termux-am-library 2>/dev/null || true
fi
rm -rf termux-am-library-src

# Copy termux_generator_utils.sh to termux-packages scripts
if [ -f "scripts/termux_generator_utils.sh" ]; then
    echo "Copying termux_generator_utils.sh..."
    cp scripts/termux_generator_utils.sh termux-packages-src/scripts/
fi

# Copy to termux-app as well
if [ -f "scripts/termux_generator_utils.sh" ]; then
    cp scripts/termux_generator_utils.sh termux-app-src/scripts/ 2>/dev/null || true
fi

# Apply app patches
if [ -d "$APP_TYPE-patches/app-patches" ]; then
    echo "Applying app patches..."
    cd termux-app-src
    for p in ../$APP_TYPE-patches/app-patches/*.patch; do
        if [ -f "$p" ]; then
            echo "Applying: $(basename $p)"
            patch -p1 < "$p" 2>/dev/null || echo "Warning: patch $(basename $p) skipped"
        fi
    done
    cd ..
fi

# Apply bootstrap patches
if [ -d "$APP_TYPE-patches/bootstrap-patches" ]; then
    echo "Applying bootstrap patches..."
    cd termux-packages-src
    for p in ../$APP_TYPE-patches/bootstrap-patches/*.patch; do
        if [ -f "$p" ]; then
            echo "Applying: $(basename $p)"
            patch -p1 < "$p" 2>/dev/null || echo "Warning: patch $(basename $p) skipped"
        fi
    done
    cd ..
fi

# Build bootstrap
echo "Building bootstrap..."
cd termux-packages-src
./scripts/run-docker.sh ./scripts/build-bootstraps.sh \
    --architectures "$ARCHITECTURES" \
    --add "$ADDITIONAL_PACKAGES" \
    --disable-bootstrap-second-stage

mkdir -p ../output/bootstrap
cp bootstrap-*.tar.xz ../output/bootstrap/ 2>/dev/null || true
cp -r xz-* ../output/bootstrap/ 2>/dev/null || true
cd ..

# Extract terminal-emulator
echo "Extracting terminal-emulator module..."
OUTPUT="output/terminal-emulator"
mkdir -p "$OUTPUT"

cp -r termux-app-src/terminal-emulator "$OUTPUT/"
cp -r termux-app-src/terminal-view "$OUTPUT/"
cp -r termux-app-src/termux-shared "$OUTPUT/"

mkdir -p "$OUTPUT/jni"
cp -r termux-app-src/src/main/jni/*.c "$OUTPUT/jni/" 2>/dev/null || true
cp -r termux-app-src/src/main/jni/Android.mk "$OUTPUT/jni/" 2>/dev/null || true

mkdir -p "$OUTPUT/assets"
cp output/bootstrap/bootstrap-*.tar.xz "$OUTPUT/assets/" 2>/dev/null || true

for arch in ${ARCHITECTURES//,/ }; do
    if [ -d "output/bootstrap/xz-$arch" ]; then
        mkdir -p "$OUTPUT/assets/xz-$arch"
        cp output/bootstrap/xz-$arch/* "$OUTPUT/assets/xz-$arch/" 2>/dev/null || true
    fi
done

mkdir -p "$OUTPUT/res"
cp -r termux-app-src/src/main/res/* "$OUTPUT/res/" 2>/dev/null || true

echo "=========================================="
echo "Done! Output: $OUTPUT"
echo "=========================================="