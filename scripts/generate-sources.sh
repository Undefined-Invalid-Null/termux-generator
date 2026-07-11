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
git clone --depth 1 https://github.com/termux/termux-am-library.git termux-am-library-src

# Move termux-am-library
if [ -d "termux-am-library-src/termux-am-library" ]; then
    mkdir -p termux-app-src/termux-am-library
    cp -r termux-am-library-src/termux-am-library/* termux-app-src/termux-am-library/
fi
rm -rf termux-am-library-src

# ============================================================
# 应用 app patches (使用 apply_patches 函数)
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
            patch -p1 < "$patch_file" 2>&1 || echo "  ⚠️ Warning: $(basename "$patch_file") failed"
        fi
    done
    
    cd - > /dev/null
}

echo "Applying app patches..."
if [ -d "$APP_TYPE-patches/app-patches" ]; then
    apply_patches "$APP_TYPE-patches/app-patches" "termux-app-src"
else
    echo "  ❌ No patches found in $APP_TYPE-patches/app-patches"
fi

# ============================================================
# 验证 local-bootstraps patch 是否应用
# ============================================================
echo ""
echo "Verifying local-bootstraps patch..."

if grep -q "import android.content.res.AssetManager" termux-app-src/app/src/main/java/com/termux/app/TermuxInstaller.java 2>/dev/null; then
    echo "  ✅ local-bootstraps patch applied successfully"
else
    echo "  ❌ local-bootstraps patch NOT applied - applying manually..."

    cd termux-app-src
    
    # 1. 添加 import
    sed -i 's/import android.content.Context;/import android.content.Context;\nimport android.content.res.AssetManager;/' app/src/main/java/com/termux/app/TermuxInstaller.java
    sed -i 's/import java.io.FileOutputStream;/import java.io.FileOutputStream;\nimport java.io.InputStream;\nimport java.io.OutputStream;/' app/src/main/java/com/termux/app/TermuxInstaller.java
    
    # 2. 删除 native 方法声明
    sed -i '/public static native byte\[\] getZip();/d' app/src/main/java/com/termux/app/TermuxInstaller.java
    
    cd ..
    
    echo "  ✅ Manual patch applied"
fi

# ============================================================
# 提取完整源码
# ============================================================
echo ""
echo "Extracting full sources..."
OUTPUT="output/termux-sources"
mkdir -p "$OUTPUT"

# 复制所有模块
cp -r termux-app-src/* "$OUTPUT/"

# 删除 bootstrap 文件
find "$OUTPUT" -name "bootstrap-*.zip" -delete 2>/dev/null || true
find "$OUTPUT" -name "bootstrap-*.tar.xz" -delete 2>/dev/null || true

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

echo ""
echo "=========================================="
echo "Done! Output: $OUTPUT"
echo "=========================================="