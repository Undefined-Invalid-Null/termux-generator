#!/bin/bash
set -e

# 配置
TERMUX_APP__PACKAGE_NAME="com.termux"
TERMUX_APP_TYPE="f-droid"

# 加载工具函数
source "$(dirname "$0")/termux_generator_utils.sh"

# ============================================================
# 应用 patches (复用 build-termux.sh 的逻辑)
# ============================================================
apply_patches() {
    local patch_dir="$1"
    local target_dir="$2"
    
    if [ ! -d "$patch_dir" ]; then
        echo "  Patch directory not found: $patch_dir"
        return 1
    fi
    
    cd "$target_dir"
    
    for patch_file in "$patch_dir"/*.patch; do
        if [ -f "$patch_file" ]; then
            echo "  Applying: $(basename "$patch_file")"
            # 使用 -p1 去除 a/ 和 b/ 前缀
            patch -p1 < "$patch_file" 2>&1 || echo "  ⚠️ Warning: $(basename "$patch_file") failed"
        fi
    done
    
    cd - > /dev/null
}

echo "=========================================="
echo "Generating Termux sources with patches"
echo "App type: $TERMUX_APP_TYPE"
echo "=========================================="

# ============================================================
# 1. 下载源码
# ============================================================
echo ""
echo "[1/4] Downloading sources..."

rm -rf termux-app-src
git clone --depth 1 https://github.com/termux/termux-app.git termux-app-src
git clone --depth 1 https://github.com/termux/termux-am-library.git termux-am-library-src

# 移动 termux-am-library
if [ -d "termux-am-library-src/termux-am-library" ]; then
    mkdir -p termux-app-src/termux-am-library
    cp -r termux-am-library-src/termux-am-library/* termux-app-src/termux-am-library/
fi
rm -rf termux-am-library-src

# ============================================================
# 2. 应用 app patches
# ============================================================
echo ""
echo "[2/4] Applying app patches..."

if [ -d "$TERMUX_APP_TYPE-patches/app-patches" ]; then
    apply_patches "$TERMUX_APP_TYPE-patches/app-patches" "termux-app-src"
else
    echo "  ❌ No patches found in $TERMUX_APP_TYPE-patches/app-patches"
    exit 1
fi

# ============================================================
# 3. 验证 local-bootstraps patch
# ============================================================
echo ""
echo "[3/4] Verifying local-bootstraps patch..."

INSTALLER_FILE="termux-app-src/app/src/main/java/com/termux/app/TermuxInstaller.java"

if grep -q "import android.content.res.AssetManager" "$INSTALLER_FILE" 2>/dev/null; then
    echo "  ✅ local-bootstraps patch applied successfully"
else
    echo "  ❌ local-bootstraps patch NOT applied - applying manually..."

    # 手动修改 TermuxInstaller.java
    sed -i 's/import android.content.Context;/import android.content.Context;\nimport android.content.res.AssetManager;/' "$INSTALLER_FILE"
    sed -i 's/import java.io.FileOutputStream;/import java.io.FileOutputStream;\nimport java.io.InputStream;\nimport java.io.OutputStream;/' "$INSTALLER_FILE"
    
    # 删除 native 方法声明
    sed -i '/public static native byte\[\] getZip();/d' "$INSTALLER_FILE"
    
    echo "  ✅ Manual patch applied"
fi

# ============================================================
# 4. 提取完整源码
# ============================================================
echo ""
echo "[4/4] Extracting full sources..."

OUTPUT="output/termux-sources"
mkdir -p "$OUTPUT"

# 复制所有模块
cp -r termux-app-src/* "$OUTPUT/"

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

# 删除 xz-* 目录
find "$OUTPUT" -type d -name "xz-*" -exec rm -rf {} + 2>/dev/null || true

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

# 检查关键文件
FILES=(
    "app/src/main/java/com/termux/app/TermuxActivity.java"
    "app/src/main/java/com/termux/app/TermuxService.java"
    "app/src/main/java/com/termux/app/TermuxInstaller.java"
    "app/src/main/AndroidManifest.xml"
    "terminal-emulator/src/main/java/com/termux/terminal/TerminalEmulator.java"
    "terminal-emulator/src/main/jni/termux.c"
    "terminal-view/src/main/java/com/termux/view/TerminalView.java"
    "termux-shared/src/main/java/com/termux/shared/termux/TermuxConstants.java"
    "build.gradle"
    "settings.gradle"
)

echo ""
echo "Key files:"
for file in "${FILES[@]}"; do
    if [ -f "$OUTPUT/$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file MISSING"
    fi
done

# 检查是否有 bootstrap 残留
BOOTSTRAP_COUNT=$(find "$OUTPUT" -name "bootstrap-*" 2>/dev/null | wc -l)
if [ "$BOOTSTRAP_COUNT" -eq 0 ]; then
    echo "  ✅ No bootstrap files found"
else
    echo "  ⚠️ $BOOTSTRAP_COUNT bootstrap files found"
fi

echo ""
echo "=========================================="
echo "Done! Output: $OUTPUT"
echo "=========================================="