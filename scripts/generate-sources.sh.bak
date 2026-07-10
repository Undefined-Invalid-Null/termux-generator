#!/bin/bash
set -e

APP_TYPE="f-droid"

while [[ $# -gt 0 ]]; do
    case $1 in
        --app-type) APP_TYPE="$2"; shift 2 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

echo "=========================================="
echo "Generating Termux sources with patches"
echo "App type: $APP_TYPE"
echo "=========================================="

# Clone
git clone --depth 1 https://github.com/termux/termux-app.git termux-app-src
git clone --depth 1 https://github.com/termux/termux-packages.git termux-packages-src
git clone --depth 1 https://github.com/termux/termux-am-library.git termux-am-library-src

# Move termux-am-library
if [ -d "termux-am-library-src/termux-am-library" ]; then
    mkdir -p termux-app-src/termux-am-library
    cp -r termux-am-library-src/termux-am-library/* termux-app-src/termux-am-library/
fi
rm -rf termux-am-library-src

# ============================================================
# 应用 app patches
# ============================================================
echo "Applying app patches..."
cd termux-app-src

for p in ../$APP_TYPE-patches/app-patches/*.patch; do
    if [ -f "$p" ]; then
        echo "  Applying: $(basename $p)"
        patch -p1 < "$p" 2>/dev/null || echo "  Warning: $(basename $p) failed"
    fi
done

cd ..

# ============================================================
# 应用 bootstrap patches
# ============================================================
echo "Applying bootstrap patches..."
cd termux-packages-src

for p in ../$APP_TYPE-patches/bootstrap-patches/*.patch; do
    if [ -f "$p" ]; then
        echo "  Applying: $(basename $p)"
        patch -p1 < "$p" 2>/dev/null || echo "  Warning: $(basename $p) failed"
    fi
done

cd ..

# ============================================================
# 验证并强制修复 local-bootstraps patch
# ============================================================
echo "Verifying local-bootstraps patch..."

cd termux-app-src

if ! grep -q "import android.content.res.AssetManager" app/src/main/java/com/termux/app/TermuxInstaller.java 2>/dev/null; then
    echo "  Applying local-bootstraps patch manually..."
    
    sed -i 's/import android.content.Context;/import android.content.Context;\nimport android.content.res.AssetManager;/' app/src/main/java/com/termux/app/TermuxInstaller.java
    sed -i 's/import java.io.FileOutputStream;/import java.io.FileOutputStream;\nimport java.io.InputStream;\nimport java.io.OutputStream;/' app/src/main/java/com/termux/app/TermuxInstaller.java
    
    echo "  ✅ Manual fix applied"
else
    echo "  ✅ local-bootstraps patch already applied"
fi

cd ..

# ============================================================
# 构建 bootstrap (用于获取 xz 工具)
# ============================================================
echo "Building bootstrap to get xz tools..."
cd termux-packages-src

./scripts/run-docker.sh ./scripts/build-bootstraps.sh \
    --architectures aarch64 \
    --add xkeyboard-config \
    --disable-bootstrap-second-stage

mkdir -p ../output/bootstrap
cp bootstrap-*.tar.xz ../output/bootstrap/ 2>/dev/null || true
cp -r xz-* ../output/bootstrap/ 2>/dev/null || true

cd ..

# ============================================================
# 提取完整源码
# ============================================================
echo "Extracting full sources..."
OUTPUT="output/termux-sources"
mkdir -p "$OUTPUT"

# 复制所有模块 (完整)
cp -r termux-app-src/* "$OUTPUT/"

# 复制 bootstrap 到 assets
mkdir -p "$OUTPUT/app/src/main/assets"
cp output/bootstrap/bootstrap-*.tar.xz "$OUTPUT/app/src/main/assets/" 2>/dev/null || true

for arch in aarch64 arm i686 x86_64; do
    if [ -d "output/bootstrap/xz-$arch" ]; then
        mkdir -p "$OUTPUT/app/src/main/assets/xz-$arch"
        cp output/bootstrap/xz-$arch/* "$OUTPUT/app/src/main/assets/xz-$arch/" 2>/dev/null || true
    fi
done

# 确保所有必需的目录存在
mkdir -p "$OUTPUT/app/src/main/java/com/termux/app"
mkdir -p "$OUTPUT/app/src/main/java/com/termux/app/activities"
mkdir -p "$OUTPUT/app/src/main/java/com/termux/app/api/file"
mkdir -p "$OUTPUT/app/src/main/java/com/termux/app/event"
mkdir -p "$OUTPUT/app/src/main/java/com/termux/app/fragments/settings"
mkdir -p "$OUTPUT/app/src/main/java/com/termux/app/models"
mkdir -p "$OUTPUT/app/src/main/java/com/termux/app/terminal"
mkdir -p "$OUTPUT/app/src/main/java/com/termux/app/terminal/io"
mkdir -p "$OUTPUT/app/src/main/java/com/termux/filepicker"
mkdir -p "$OUTPUT/app/src/main/res"

# ============================================================
# 验证源码完整性
# ============================================================
echo ""
echo "=========================================="
echo "Verifying source integrity:"

FILES=(
    "app/src/main/java/com/termux/app/TermuxActivity.java"
    "app/src/main/java/com/termux/app/TermuxService.java"
    "app/src/main/java/com/termux/app/TermuxInstaller.java"
    "app/src/main/java/com/termux/app/TermuxApplication.java"
    "app/src/main/java/com/termux/app/RunCommandService.java"
    "app/src/main/java/com/termux/app/TermuxOpenReceiver.java"
    "app/src/main/java/com/termux/app/activities/HelpActivity.java"
    "app/src/main/java/com/termux/app/activities/SettingsActivity.java"
    "app/src/main/java/com/termux/app/api/file/FileReceiverActivity.java"
    "app/src/main/java/com/termux/app/event/SystemEventReceiver.java"
    "app/src/main/java/com/termux/app/terminal/TermuxTerminalViewClient.java"
    "app/src/main/java/com/termux/app/terminal/TermuxActivityRootView.java"
    "app/src/main/java/com/termux/app/terminal/TermuxSessionsListViewController.java"
    "app/src/main/java/com/termux/app/terminal/TermuxTerminalSessionActivityClient.java"
    "app/src/main/java/com/termux/app/terminal/io/TermuxTerminalExtraKeys.java"
    "app/src/main/java/com/termux/app/fragments/settings/TermuxPreferencesFragment.java"
    "app/src/main/java/com/termux/app/models/UserAction.java"
    "app/src/main/java/com/termux/filepicker/TermuxDocumentsProvider.java"
    "app/src/main/AndroidManifest.xml"
)

MISSING=0
for file in "${FILES[@]}"; do
    if [ -f "$OUTPUT/$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file MISSING"
        MISSING=1
    fi
done

if [ $MISSING -eq 0 ]; then
    echo "  ✅ All files present"
else
    echo "  ⚠️ Some files missing"
fi

# 验证 bootstrap patch
if grep -q "AssetManager" "$OUTPUT/app/src/main/java/com/termux/app/TermuxInstaller.java" 2>/dev/null; then
    echo "  ✅ AssetManager found - bootstrap uses assets"
else
    echo "  ❌ AssetManager NOT found"
fi

if grep -q "bootstrap.*xz" "$OUTPUT/app/src/main/java/com/termux/app/TermuxInstaller.java" 2>/dev/null; then
    echo "  ✅ bootstrap uses .xz"
else
    echo "  ❌ bootstrap does NOT use .xz"
fi

if [ -f "$OUTPUT/app/src/main/assets/bootstrap-aarch64.tar.xz" ]; then
    echo "  ✅ bootstrap-aarch64.tar.xz present"
else
    echo "  ❌ bootstrap-aarch64.tar.xz MISSING"
fi

echo "=========================================="
echo "Done! Output: $OUTPUT"
echo "=========================================="