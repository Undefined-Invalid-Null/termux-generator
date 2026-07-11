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
# 应用所有 app patches
# ============================================================
echo "Applying app patches..."
cd termux-app-src

PATCH_DIR="../$APP_TYPE-patches/app-patches"
if [ -d "$PATCH_DIR" ]; then
    for p in $PATCH_DIR/*.patch; do
        if [ -f "$p" ]; then
            echo "  Applying: $(basename $p)"
            patch -p1 < "$p" || echo "  Warning: $(basename $p) failed"
        fi
    done
else
    echo "  No patches found in $PATCH_DIR"
fi

cd ..

# ============================================================
# 验证 local-bootstraps patch 是否应用成功
# ============================================================
echo "Verifying local-bootstraps patch..."

cd termux-app-src

if grep -q "import android.content.res.AssetManager" app/src/main/java/com/termux/app/TermuxInstaller.java 2>/dev/null; then
    echo "  ✅ local-bootstraps patch already applied"
else
    echo "  ⚠️ local-bootstraps patch NOT applied - applying manually..."
    
    # 手动添加 AssetManager import
    sed -i 's/import android.content.Context;/import android.content.Context;\nimport android.content.res.AssetManager;/' app/src/main/java/com/termux/app/TermuxInstaller.java
    
    # 手动添加 InputStream/OutputStream import
    sed -i 's/import java.io.FileOutputStream;/import java.io.FileOutputStream;\nimport java.io.InputStream;\nimport java.io.OutputStream;/' app/src/main/java/com/termux/app/TermuxInstaller.java
    
    echo "  ✅ Manual patch applied"
fi

cd ..

# ============================================================
# 提取完整源码 (不包含 bootstrap)
# ============================================================
echo "Extracting full sources..."
OUTPUT="output/termux-sources"
mkdir -p "$OUTPUT"

# 复制所有模块
cp -r termux-app-src/* "$OUTPUT/"

# 删除 bootstrap zip/tar.xz 文件
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
# 验证源码完整性
# ============================================================
echo ""
echo "=========================================="
echo "Verifying source integrity:"

# 关键文件列表
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
    "terminal-emulator/src/main/java/com/termux/terminal/TerminalEmulator.java"
    "terminal-emulator/src/main/java/com/termux/terminal/TerminalSession.java"
    "terminal-emulator/src/main/java/com/termux/terminal/JNI.java"
    "terminal-emulator/src/main/jni/termux.c"
    "terminal-emulator/src/main/jni/Android.mk"
    "terminal-view/src/main/java/com/termux/view/TerminalView.java"
    "termux-shared/src/main/java/com/termux/shared/termux/TermuxConstants.java"
    "termux-am-library/src/main/java/com/termux/am/Am.java"
    "build.gradle"
    "settings.gradle"
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
    echo "  ✅ AssetManager found - bootstrap will use assets"
else
    echo "  ❌ AssetManager NOT found"
fi

if grep -q "loadZipBytes" "$OUTPUT/app/src/main/java/com/termux/app/TermuxInstaller.java" 2>/dev/null; then
    echo "  ❌ loadZipBytes still exists"
else
    echo "  ✅ loadZipBytes removed"
fi

# 检查是否有 bootstrap 文件残留
BOOTSTRAP_FILES=$(find "$OUTPUT" -name "bootstrap-*" 2>/dev/null | wc -l)
if [ $BOOTSTRAP_FILES -eq 0 ]; then
    echo "  ✅ No bootstrap files found"
else
    echo "  ⚠️ $BOOTSTRAP_FILES bootstrap files found (should be 0)"
fi

echo "=========================================="
echo "Done! Output: $OUTPUT"
echo "=========================================="