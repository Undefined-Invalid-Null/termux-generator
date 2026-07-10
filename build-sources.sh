#!/bin/bash
set -e -u -o pipefail

cd "$(realpath "$(dirname "$0")")"

TERMUX_GENERATOR_HOME="$(pwd)"
TERMUX_APP__PACKAGE_NAME="com.termux"  # 保持官方名称，因为 UIN Tool 会重命名
TERMUX_APP_TYPE="f-droid"
DO_NOT_CLEAN=""
ADDITIONAL_PACKAGES="xkeyboard-config"

source "$TERMUX_GENERATOR_HOME/scripts/termux_generator_utils.sh"

# ==================== 只下载和准备源码 ====================

echo "=========================================="
echo "下载 Termux 源码..."
echo "=========================================="

# 克隆仓库（不构建 APK）
git clone --depth 1 https://github.com/termux/termux-packages.git termux-packages-main
git clone --depth 1 https://github.com/termux/termux-app.git termux-apps-main/termux-app
git clone --depth 1 https://github.com/termux/termux-x11.git termux-apps-main/termux-x11
git clone --depth 1 https://github.com/termux/termux-am-library.git termux-apps-main/termux-am-library

# 移动 termux-am-library
mv termux-apps-main/termux-am-library/termux-am-library/ termux-apps-main/termux-app/termux-am-library
rm -rf termux-apps-main/termux-am-library/

echo "=========================================="
echo "应用 patches..."
echo "=========================================="

# 应用 bootstrap patches
apply_patches "f-droid-patches/bootstrap-patches" termux-packages-main

# 应用 app patches
apply_patches "f-droid-patches/app-patches" termux-apps-main

# 应用 local-bootstraps patch（最关键）
apply_patches "f-droid-patches/app-patches/local-bootstraps.patch" termux-apps-main

echo "=========================================="
echo "生成 bootstrap 和 terminal-emulator 模块..."
echo "=========================================="

# ==================== 生成 bootstrap ====================

pushd termux-packages-main

# 只构建 bootstrap，不构建 APK
./scripts/run-docker.sh ./scripts/build-bootstraps.sh \
    --add "$ADDITIONAL_PACKAGES" \
    --architectures aarch64 \
    --disable-bootstrap-second-stage

# 复制 bootstrap 文件
mkdir -p "$TERMUX_GENERATOR_HOME/output/bootstrap"
cp bootstrap-*.tar.xz "$TERMUX_GENERATOR_HOME/output/bootstrap/"
cp -r xz-* "$TERMUX_GENERATOR_HOME/output/bootstrap/"

popd

# ==================== 提取 terminal-emulator 模块 ====================

echo "=========================================="
echo "提取 terminal-emulator 模块..."
echo "=========================================="

OUTPUT_DIR="$TERMUX_GENERATOR_HOME/output/terminal-emulator"
mkdir -p "$OUTPUT_DIR"

# 复制 terminal-emulator 源码
cp -r termux-apps-main/termux-app/terminal-emulator "$OUTPUT_DIR/"
cp -r termux-apps-main/termux-app/terminal-view "$OUTPUT_DIR/"
cp -r termux-apps-main/termux-app/termux-shared "$OUTPUT_DIR/"

# 复制 JNI 源码
mkdir -p "$OUTPUT_DIR/jni"
cp termux-apps-main/termux-app/src/main/jni/*.c "$OUTPUT_DIR/jni/" 2>/dev/null || true
cp termux-apps-main/termux-app/src/main/jni/Android.mk "$OUTPUT_DIR/jni/" 2>/dev/null || true

# 复制 resources
mkdir -p "$OUTPUT_DIR/res"
cp -r termux-apps-main/termux-app/src/main/res/* "$OUTPUT_DIR/res/" 2>/dev/null || true

# 复制 assets (bootstrap 已经在里面)
mkdir -p "$OUTPUT_DIR/assets"
cp output/bootstrap/bootstrap-*.tar.xz "$OUTPUT_DIR/assets/"
cp output/bootstrap/xz-*/xz "$OUTPUT_DIR/assets/xz-aarch64/xz" 2>/dev/null || true
cp output/bootstrap/xz-*/liblzma.so.5 "$OUTPUT_DIR/assets/xz-aarch64/liblzma.so.5" 2>/dev/null || true

# ==================== 生成集成脚本 ====================

echo "=========================================="
echo "生成集成脚本..."
echo "=========================================="

cat > "$OUTPUT_DIR/README.md" << 'EOF'
# Terminal Emulator Module for UIN Tool

这是从 termux-generator 提取的终端模拟器模块，包含：

- `terminal-emulator/` - 终端仿真核心 (TerminalEmulator, TerminalBuffer, etc.)
- `terminal-view/` - 终端视图 (TerminalView, TerminalRenderer)
- `termux-shared/` - Termux 共享库
- `jni/` - JNI 代码 (pty_launcher.c)
- `assets/` - Bootstrap 文件

## 集成到 UIN Tool

1. 复制 `terminal-emulator/` 到 `app/src/main/java/com/termux/terminal/`
2. 复制 `terminal-view/` 到 `app/src/main/java/com/termux/view/`
3. 复制 `termux-shared/` 到 `app/src/main/java/com/termux/shared/`
4. 复制 `jni/` 到 `app/src/main/jni/`
5. 复制 `assets/` 到 `app/src/main/assets/`
6. 复制 `res/` 到 `app/src/main/res/`
EOF

cat > "$OUTPUT_DIR/integrate.sh" << 'EOF'
#!/bin/bash
# 自动集成到 UIN Tool 项目

UIN_TOOL_DIR="${1:-../../UIN_Tool}"

if [ ! -d "$UIN_TOOL_DIR/app/src/main/java" ]; then
    echo "错误: 找不到 UIN Tool 项目目录"
    echo "用法: ./integrate.sh /path/to/UIN_Tool"
    exit 1
fi

echo "集成 terminal-emulator 到 UIN Tool..."

# 1. 复制 Java 源码
cp -r terminal-emulator/src/main/java/com/termux/terminal/* "$UIN_TOOL_DIR/app/src/main/java/com/UIN/Tool/terminal/"
cp -r terminal-view/src/main/java/com/termux/view/* "$UIN_TOOL_DIR/app/src/main/java/com/UIN/Tool/view/"
cp -r termux-shared/src/main/java/com/termux/shared/* "$UIN_TOOL_DIR/app/src/main/java/com/termux/shared/"

# 2. 复制 JNI
mkdir -p "$UIN_TOOL_DIR/app/src/main/jni"
cp -r jni/* "$UIN_TOOL_DIR/app/src/main/jni/"

# 3. 复制 assets
mkdir -p "$UIN_TOOL_DIR/app/src/main/assets"
cp -r assets/* "$UIN_TOOL_DIR/app/src/main/assets/"

# 4. 复制 resources
cp -r res/* "$UIN_TOOL_DIR/app/src/main/res/"

echo "集成完成!"
EOF

chmod +x "$OUTPUT_DIR/integrate.sh"

echo "=========================================="
echo "✅ 完成！输出目录: $OUTPUT_DIR"
echo ""
echo "下一步:"
echo "1. cd $OUTPUT_DIR"
echo "2. ./integrate.sh /path/to/UIN_Tool"
echo "=========================================="