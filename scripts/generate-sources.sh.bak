#!/bin/bash
set -e

TERMUX_APP_TYPE="f-droid"
PACKAGE_NAME="com.UIN.Tool"

# ============================================================
# 复制 apply_patches 函数
# ============================================================
apply_patches() {
    local srcdir=$(realpath "$1")
    local targetdir=$(realpath "$2")
    local patches=$(find "$srcdir" -type f | sort)

    if [ -z "$patches" ]; then
        echo "  No patches found in $srcdir"
        return 1
    fi

    pushd "$targetdir" > /dev/null

    for patch in $patches; do
        echo "  Applying: $(basename "$patch")"
        patch -p1 --no-backup-if-mismatch < "$patch" || echo "  ⚠️ Warning: $(basename "$patch") failed"
    done

    popd > /dev/null
}

echo "=========================================="
echo "Generating Termux sources with patches"
echo "App type: $TERMUX_APP_TYPE"
echo "Package name: $PACKAGE_NAME"
echo "=========================================="

# ============================================================
# 1. 下载源码
# ============================================================
echo ""
echo "[1/6] Downloading sources..."

rm -rf termux-apps-main
mkdir -p termux-apps-main

git clone --depth 1 https://github.com/termux/termux-app.git termux-apps-main/termux-app
git clone --depth 1 https://github.com/termux/termux-am-library.git termux-am-library-src

# 移动 termux-am-library
if [ -d "termux-am-library-src/termux-am-library" ]; then
    mkdir -p termux-apps-main/termux-app/termux-am-library
    cp -r termux-am-library-src/termux-am-library/* termux-apps-main/termux-app/termux-am-library/
fi
rm -rf termux-am-library-src

# ============================================================
# 2. 应用 app patches
# ============================================================
echo ""
echo "[2/6] Applying app patches..."

if [ -d "$TERMUX_APP_TYPE-patches/app-patches" ]; then
    apply_patches "$TERMUX_APP_TYPE-patches/app-patches" "termux-apps-main"
else
    echo "  ❌ No patches found in $TERMUX_APP_TYPE-patches/app-patches"
    exit 1
fi

# ============================================================
# 3. 删除 .orig 文件
# ============================================================
echo ""
echo "[3/6] Removing .orig files..."
find termux-apps-main -name "*.orig" -type f -delete 2>/dev/null || true
echo "  ✅ .orig files removed"

# ============================================================
# 4. 替换包名 com.termux -> com.UIN.Tool
# ============================================================
echo ""
echo "[4/6] Replacing package name: com.termux -> $PACKAGE_NAME"

cd termux-apps-main/termux-app

# 替换所有文本文件中的包名
find . -type f -exec file {} + | grep "text" | cut -d: -f1 | while read -r file; do
    sed -i "s/com\.termux/$PACKAGE_NAME/g" "$file" 2>/dev/null || true
    sed -i "s/com_termux/$(echo $PACKAGE_NAME | tr . _)/g" "$file" 2>/dev/null || true
done

# 重命名 Java 包目录
echo "  Renaming Java package directories..."
find . -type d -path "*/com/termux" | while read -r dir; do
    parent=$(dirname "$dir")
    # com/termux -> com/UIN/Tool
    new_dir="$parent/$(echo $PACKAGE_NAME | tr . /)"
    if [ -d "$dir" ] && [ ! -d "$new_dir" ]; then
        mkdir -p "$(dirname "$new_dir")"
        mv "$dir" "$new_dir"
    fi
done

cd ../..

echo "  ✅ Package name replaced"

# ============================================================
# 5. 验证 local-bootstraps patch
# ============================================================
echo ""
echo "[5/6] Verifying local-bootstraps patch..."

INSTALLER_FILE="termux-apps-main/termux-app/app/src/main/java/$(echo $PACKAGE_NAME | tr . /)/app/TermuxInstaller.java"

if grep -q "import android.content.res.AssetManager" "$INSTALLER_FILE" 2>/dev/null; then
    echo "  ✅ local-bootstraps patch applied successfully"
else
    echo "  ❌ local-bootstraps patch NOT applied - applying manually..."

    sed -i 's/import android.content.Context;/import android.content.Context;\nimport android.content.res.AssetManager;/' "$INSTALLER_FILE"
    sed -i 's/import java.io.FileOutputStream;/import java.io.FileOutputStream;\nimport java.io.InputStream;\nimport java.io.OutputStream;/' "$INSTALLER_FILE"
    sed -i '/public static native byte\[\] getZip();/d' "$INSTALLER_FILE"

    echo "  ✅ Manual patch applied"
fi

# ============================================================
# 6. 提取完整源码
# ============================================================
echo ""
echo "[6/6] Extracting full sources..."

OUTPUT="output/termux-sources"
mkdir -p "$OUTPUT"

# 复制 termux-app
cp -r termux-apps-main/termux-app "$OUTPUT/"

# 删除 .orig 文件
find "$OUTPUT" -name "*.orig" -type f -delete 2>/dev/null || true

# 删除 bootstrap 文件
find "$OUTPUT" -name "bootstrap-*.zip" -delete 2>/dev/null || true
find "$OUTPUT" -name "bootstrap-*.tar.xz" -delete 2>/dev/null || true
find "$OUTPUT" -name "bootstrap-*" -delete 2>/dev/null || true

# 删除构建产物
rm -rf "$OUTPUT/.git"
rm -rf "$OUTPUT/.gradle"
rm -rf "$OUTPUT/build"
rm -rf "$OUTPUT/app/build"
rm -rf "$OUTPUT/app/.cxx"
rm -rf "$OUTPUT/terminal-emulator/build"
rm -rf "$OUTPUT/terminal-view/build"
rm -rf "$OUTPUT/termux-shared/build"

# ============================================================
# 验证
# ============================================================
echo ""
echo "=========================================="
echo "Verification:"

# 验证包名
if grep -r "com.termux" "$OUTPUT/app/src/main/java" --include="*.java" 2>/dev/null | grep -v "com.termux" | head -5; then
    echo "  ⚠️ Some com.termux references may remain"
else
    echo "  ✅ Package name replaced"
fi

# 验证 patch
if grep -q "AssetManager" "$OUTPUT/app/src/main/java/$(echo $PACKAGE_NAME | tr . /)/app/TermuxInstaller.java" 2>/dev/null; then
    echo "  ✅ AssetManager found"
else
    echo "  ❌ AssetManager NOT found"
fi

if grep -q "loadZipBytes" "$OUTPUT/app/src/main/java/$(echo $PACKAGE_NAME | tr . /)/app/TermuxInstaller.java" 2>/dev/null; then
    echo "  ❌ loadZipBytes still exists"
else
    echo "  ✅ loadZipBytes removed"
fi

# 检查 .orig 文件
ORIG_COUNT=$(find "$OUTPUT" -name "*.orig" -type f 2>/dev/null | wc -l)
if [ "$ORIG_COUNT" -eq 0 ]; then
    echo "  ✅ No .orig files found"
else
    echo "  ⚠️ $ORIG_COUNT .orig files found"
fi

# 检查关键文件
echo ""
echo "Key files:"
NEW_PACKAGE_PATH=$(echo $PACKAGE_NAME | tr . /)
for file in \
    "app/src/main/java/$NEW_PACKAGE_PATH/app/TermuxActivity.java" \
    "app/src/main/java/$NEW_PACKAGE_PATH/app/TermuxInstaller.java" \
    "app/src/main/AndroidManifest.xml" \
    "terminal-emulator/src/main/java/$NEW_PACKAGE_PATH/terminal/TerminalEmulator.java" \
    "terminal-emulator/src/main/jni/termux.c" \
    "terminal-view/src/main/java/$NEW_PACKAGE_PATH/view/TerminalView.java" \
    "termux-shared/src/main/java/$NEW_PACKAGE_PATH/shared/termux/TermuxConstants.java" \
    "build.gradle" \
    "settings.gradle"
do
    if [ -f "$OUTPUT/$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file MISSING"
    fi
done

echo ""
echo "=========================================="
echo "Done! Output: $OUTPUT"
echo "Package name: $PACKAGE_NAME"
echo "=========================================="