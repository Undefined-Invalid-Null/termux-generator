#!/bin/bash
set -e

# ============================================================
# 加载工具函数
# ============================================================
portable_sed_i() {
    if sed v </dev/null 2> /dev/null; then
        sed -i "$@"
    else
        sed -i '' "$@"
    fi
}

apply_patches() {
    local srcdir=$(realpath "$1")
    local targetdir=$(realpath "$2")
    local patches=$(find "$srcdir" -type f | sort)

    pushd "$targetdir" > /dev/null

    for patch in $patches; do
        echo "  Applying: $(basename "$patch")"
        patch -p1 --no-backup-if-mismatch < "$patch" || echo "  ⚠️ Warning: $(basename "$patch") failed"
    done

    popd > /dev/null
}

replace_termux_name() {
    if [[ "$TERMUX_APP__PACKAGE_NAME" == "com.termux" ]]; then
        return
    fi
    local targetdir="$1"
    local replacement_name="$2"
    local replacement_name_underscore="$(echo "$replacement_name" | tr . _)"
    local replacement_name_slash="$(echo "$replacement_name" | tr . /)"

    pushd "$targetdir" > /dev/null
    
    local file
    find . -type f -exec file {} + | grep "text" | cut -d: -f1 | while read -r file; do
        portable_sed_i -e "s|>Termux<|>$replacement_name<|g" \
                       -e "s|\"Termux\"|\"$replacement_name\"|g" \
                       -e "s|Termux:|$replacement_name:|g" \
                       -e "s|com\\.termux|$replacement_name|g" \
                       -e "s|com_termux|$replacement_name_underscore|g" \
                       -e '/http/!s|com/termux|'$replacement_name_slash'|g' "$file"
    done

    popd > /dev/null
}

migrate_termux_folder() {
    if [[ "$TERMUX_APP__PACKAGE_NAME" == "com.termux" ]]; then
        return
    fi
    local parentdir="$(dirname "$(dirname "$1")")"
    local replacement_name="$2"
    local destination="${parentdir}/$(echo "$replacement_name" | tr . /)/"

    echo "  Migrating: ${parentdir}/com/termux/ -> ${destination}"
    mkdir -p "${destination}"
    if [ -d "${parentdir}/com/termux/" ]; then
        mv "${parentdir}/com/termux/"* "${destination}" 2>/dev/null || true
        rm -rf "${parentdir}/com/termux/" 2>/dev/null || true
    fi
}

migrate_termux_folder_tree() {
    if [[ "$TERMUX_APP__PACKAGE_NAME" == "com.termux" ]]; then
        return
    fi
    local targetdir="$1"
    local replacement_name="$2"

    pushd "$targetdir" > /dev/null

    local dir
    find "$(pwd)" -type d -name termux | grep -v -e 'shared/termux' -e 'settings/termux' | while read -r dir; do
        migrate_termux_folder "$dir" "$replacement_name"
    done

    popd > /dev/null
}

# ============================================================
# 配置
# ============================================================
TERMUX_APP_TYPE="f-droid"
TERMUX_APP__PACKAGE_NAME="com.UIN.Tool"

echo "=========================================="
echo "Generating Termux sources with patches"
echo "App type: $TERMUX_APP_TYPE"
echo "Package name: $TERMUX_APP__PACKAGE_NAME"
echo "=========================================="

# ============================================================
# 1. 下载源码
# ============================================================
echo ""
echo "[1/5] Downloading sources..."

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
echo "[2/5] Applying app patches..."

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
echo "[3/5] Removing .orig files..."
find termux-apps-main -name "*.orig" -type f -delete 2>/dev/null || true
echo "  ✅ .orig files removed"

# ============================================================
# 4. 替换包名
# ============================================================
echo ""
echo "[4/5] Replacing package name: com.termux -> $TERMUX_APP__PACKAGE_NAME"

if [ "$TERMUX_APP__PACKAGE_NAME" != "com.termux" ]; then
    replace_termux_name "termux-apps-main/termux-app" "$TERMUX_APP__PACKAGE_NAME"
    migrate_termux_folder_tree "termux-apps-main/termux-app" "$TERMUX_APP__PACKAGE_NAME"
    echo "  ✅ Package name replaced"
else
    echo "  ℹ️ Package name unchanged (com.termux)"
fi

# ============================================================
# 5. 提取完整源码
# ============================================================
echo ""
echo "[5/5] Extracting full sources..."

OUTPUT="output/termux-sources"
mkdir -p "$OUTPUT"

# 复制 termux-app
cp -r termux-apps-main/termux-app "$OUTPUT/"

# 删除 .orig 文件
find