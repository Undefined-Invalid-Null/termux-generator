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

# 检查是否已应用
if ! grep -q "import android.content.res.AssetManager" app/src/main/java/com/termux/app/TermuxInstaller.java 2>/dev/null; then
    echo "  ❌ local-bootstraps patch NOT applied - applying manually..."

    # 手动修改 TermuxInstaller.java
    cat > app/src/main/java/com/termux/app/TermuxInstaller.java.patch << 'EOF'
--- a/app/src/main/java/com/termux/app/TermuxInstaller.java
+++ b/app/src/main/java/com/termux/app/TermuxInstaller.java
@@ -4,6 +4,7 @@
 import android.app.AlertDialog;
 import android.app.ProgressDialog;
 import android.content.Context;
+import android.content.res.AssetManager;
 import android.os.Build;
 import android.os.Environment;
 import android.system.Os;
@@ -22,6 +23,8 @@
 import java.io.ByteArrayInputStream;
 import java.io.File;
 import java.io.FileOutputStream;
+import java.io.InputStream;
+import java.io.OutputStream;
 import java.io.InputStreamReader;
 import java.util.ArrayList;
 import java.util.List;
EOF

    # 直接用 sed 修改
    sed -i 's/import android.content.Context;/import android.content.Context;\nimport android.content.res.AssetManager;/' app/src/main/java/com/termux/app/TermuxInstaller.java
    sed -i 's/import java.io.FileOutputStream;/import java.io.FileOutputStream;\nimport java.io.InputStream;\nimport java.io.OutputStream;/' app/src/main/java/com/termux/app/TermuxInstaller.java

    echo "  ✅ Manual fix applied"
else
    echo "  ✅ local-bootstraps patch already applied"
fi

cd ..

# ============================================================
# 提取源码
# ============================================================
echo "Extracting sources..."
OUTPUT="output/termux-sources"
mkdir -p "$OUTPUT"

# 复制所有模块
cp -r termux-app-src/app "$OUTPUT/"
cp -r termux-app-src/terminal-emulator "$OUTPUT/"
cp -r termux-app-src/terminal-view "$OUTPUT/"
cp -r termux-app-src/termux-shared "$OUTPUT/"
cp -r termux-app-src/termux-am-library "$OUTPUT/" 2>/dev/null || true
cp termux-app-src/build.gradle "$OUTPUT/" 2>/dev/null || true
cp termux-app-src/settings.gradle "$OUTPUT/" 2>/dev/null || true

# ============================================================
# 验证最终结果
# ============================================================
echo ""
echo "=========================================="
echo "Verification:"

if grep -q "AssetManager" "$OUTPUT/app/src/main/java/com/termux/app/TermuxInstaller.java" 2>/dev/null; then
    echo "  ✅ AssetManager found - bootstrap will use assets"
else
    echo "  ❌ AssetManager NOT found - bootstrap still uses SO"
fi

if grep -q "runEarlyCommand" "$OUTPUT/app/src/main/java/com/termux/app/TermuxInstaller.java" 2>/dev/null; then
    echo "  ✅ runEarlyCommand found"
else
    echo "  ❌ runEarlyCommand NOT found"
fi

if grep -q "determineTermuxArchName" "$OUTPUT/app/src/main/java/com/termux/app/TermuxInstaller.java" 2>/dev/null; then
    echo "  ✅ determineTermuxArchName found"
else
    echo "  ❌ determineTermuxArchName NOT found"
fi

if grep -q "loadZipBytes" "$OUTPUT/app/src/main/java/com/termux/app/TermuxInstaller.java" 2>/dev/null; then
    echo "  ❌ loadZipBytes still exists - patch may be incomplete"
else
    echo "  ✅ loadZipBytes removed - bootstrap will use xz"
fi

echo "=========================================="
echo "Done! Output: $OUTPUT"
echo "=========================================="