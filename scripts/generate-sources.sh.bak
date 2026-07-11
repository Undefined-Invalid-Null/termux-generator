#!/bin/bash
set -e

TERMUX_APP_TYPE="f-droid"

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
        # 使用 --no-backup-if-mismatch 防止生成 .orig 文件
        patch -p1 --no-backup-if-mismatch < "$patch" || echo "  ⚠️ Warning: $(basename "$patch") failed"
    done

    popd > /dev/null
}

echo "=========================================="
echo "Generating Termux sources with patches"
echo "App type: $TERMUX_APP_TYPE"
echo "=========================================="

# ============================================================
# 1. 下载源码 (使用与 build-termux.sh 相同的目录结构)
# ============================================================
echo ""
echo "[1/4] Downloading sources..."

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
# 2. 应用 app patches (与 build-termux.sh 完全一致)
# ============================================================
echo ""
echo "[2/4] Applying app patches..."

if [ -d "$TERMUX_APP_TYPE-patches/app-patches" ]; then
    apply_patches "$TERMUX_APP_TYPE-patches/app-patches" "termux-apps-main"
else
    echo "  ❌ No patches found in $TERMUX_APP_TYPE-patches/app-patches"
    exit 1
fi

# ============================================================
# 3. 删除所有 .orig 文件
# ============================================================
echo ""
echo "[3/5] Removing .orig files..."

find termux-apps-main -name "*.orig" -type f -delete 2>/dev/null || true
echo "  ✅ .orig files removed"

# ============================================================
# 4. 验证 local-bootstraps patch
# ============================================================
echo ""
echo "[4/5] Verifying local-bootstraps patch..."

INSTALLER_FILE="termux-apps-main/termux-app/app/src/main/java/com/termux/app/TermuxInstaller.java"

if grep -q "import android.content.res.AssetManager" "$INSTALLER_FILE" 2>/dev/null; then
    echo "  ✅ local-bootstraps patch applied successfully"
else
    echo "  ❌ local-bootstraps patch NOT applied - applying manually..."

    # 手动修改
    sed -i 's/import android.content.Context;/import android.content.Context;\nimport android.content.res.AssetManager;/' "$INSTALLER_FILE"
    sed -i 's/import java.io.FileOutputStream;/import java.io.FileOutputStream;\nimport java.io.InputStream;\nimport java.io.OutputStream;/' "$INSTALLER_FILE"
    sed -i '/public static native byte\[\] getZip();/d' "$INSTALLER_FILE"

    echo "  ✅ Manual patch applied"
fi

# ============================================================
# 5. 提取完整源码
# ============================================================
echo ""
echo "[5/5] Extracting full sources..."

OUTPUT="output/termux-sources"
mkdir -p "$OUTPUT"

# 复制 termux-app (已经 patch)
cp -r termux-apps-main/termux-app "$OUTPUT/"

# 删除 .orig 文件 (再次确保)
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

if grep -q "AssetManager" "$OUTPUT/app/src/main/java/com/termux/app/TermuxInstaller.java" 2>/dev/null; then
    echo "  ✅ AssetManager found"
else
    echo "  ❌ AssetManager NOT found"
fi

if grep -q "loadZipBytes" "$OUTPUT/app/src/main/java/com/termux/app/TermuxInstaller.java" 2>/dev/null; then
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
for file in \
    "app/src/main/java/com/termux/app/TermuxActivity.java" \
    "app/src/main/java/com/termux/app/TermuxInstaller.java" \
    "app/src/main/AndroidManifest.xml" \
    "terminal-emulator/src/main/java/com/termux/terminal/TerminalEmulator.java" \
    "terminal-emulator/src/main/jni/termux.c" \
    "terminal-view/src/main/java/com/termux/view/TerminalView.java" \
    "termux-shared/src/main/java/com/termux/shared/termux/TermuxConstants.java" \
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
echo "=========================================="