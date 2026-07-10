#!/bin/bash
# 简化版 - 只生成源码包

set -e

# 1. 下载源码
git clone --depth 1 https://github.com/termux/termux-app.git termux-app-src
git clone --depth 1 https://github.com/termux/termux-packages.git termux-packages-src

# 2. 应用 patches
cd termux-app-src
for patch in ../f-droid-patches/app-patches/*.patch; do
    patch -p1 < "$patch"
done

# 3. 提取 terminal-emulator 模块
mkdir -p ../output/terminal-emulator
cp -r terminal-emulator ../output/terminal-emulator/
cp -r terminal-view ../output/terminal-emulator/
cp -r termux-shared ../output/terminal-emulator/
cp -r src/main/jni ../output/terminal-emulator/jni
cp -r src/main/assets ../output/terminal-emulator/assets
cp -r src/main/res ../output/terminal-emulator/res

# 4. 生成 bootstrap
cd ../termux-packages-src
./scripts/run-docker.sh ./scripts/build-bootstraps.sh \
    --architectures aarch64 \
    --disable-bootstrap-second-stage

cp bootstrap-*.tar.xz ../output/terminal-emulator/assets/

echo "✅ 完成！输出在 output/terminal-emulator/"