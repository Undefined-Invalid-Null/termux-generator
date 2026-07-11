#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import json
import sys
import fnmatch

# 配置要排除的目录
EXCLUDE_DIRS = {'.git', '.github', 'build', 'app/build', 'target', 'out', 'bin', 'gen', 'libs'}

def should_exclude_dir(dirpath):
    """
    判断目录是否应该被排除
    """
    # 获取目录名（最后一级）
    dirname = os.path.basename(dirpath)
    
    # 检查是否在排除列表中
    if dirname in EXCLUDE_DIRS:
        return True
    
    # 检查相对路径是否包含排除目录（支持多级路径，如 app/build）
    normalized_path = dirpath.replace('\\', '/')
    for exclude_dir in EXCLUDE_DIRS:
        # 处理像 app/build 这样的多级路径
        if '/' in exclude_dir:
            if exclude_dir in normalized_path:
                return True
        else:
            # 单级目录直接匹配目录名
            if dirname == exclude_dir:
                return True
    
    return False

def collect_files(root_dir):
    """
    收集所有文件：
    - .patch 文件：保存完整路径和内容
    - .sh 文件：保存完整路径和内容
    - 其他文件：只保存路径
    """
    patch_sh_files = []      # 存储 patch/sh 文件（带内容）
    other_files = []         # 存储其他文件（仅路径）
    
    skipped_dirs_count = 0
    
    for dirpath, dirnames, filenames in os.walk(root_dir):
        # 检查当前目录是否应该被排除
        if should_exclude_dir(dirpath):
            # 打印排除信息
            relative_path = os.path.relpath(dirpath, root_dir)
            if relative_path == '.':
                relative_path = dirpath
            print(f"⏭ 跳过排除目录: {relative_path}")
            skipped_dirs_count += 1
            # 清空子目录列表，停止递归进入更深层目录
            dirnames.clear()
            continue
        
        # 动态过滤要遍历的子目录
        dirs_to_remove = []
        for dirname in dirnames:
            full_dir_path = os.path.join(dirpath, dirname)
            if should_exclude_dir(full_dir_path):
                dirs_to_remove.append(dirname)
        
        # 移除要排除的子目录
        for dirname in dirs_to_remove:
            dirnames.remove(dirname)
            print(f"⏭ 跳过排除子目录: {os.path.join(dirpath, dirname)}")
        
        for filename in filenames:
            full_path = os.path.abspath(os.path.join(dirpath, filename))
            
            # 检查是否为 .patch 或 .sh 文件
            if filename.endswith('.patch') or filename.endswith('.sh'):
                try:
                    # 尝试读取文件内容，使用 utf-8 编码
                    with open(full_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    # 确定文件类型
                    if filename.endswith('.patch'):
                        ext = 'patch'
                        file_type = 'Patch'
                    else:  # .sh
                        ext = 'sh'
                        file_type = 'Shell Script'
                    
                    patch_sh_files.append({
                        "path": full_path,
                        "content": content,
                        "type": "source",
                        "extension": ext
                    })
                    print(f"✓ 已读取 {file_type} 文件: {full_path}")
                except UnicodeDecodeError:
                    # 如果不是 utf-8，尝试其他常见编码
                    try:
                        with open(full_path, 'r', encoding='gbk') as f:
                            content = f.read()
                        
                        # 确定文件类型
                        if filename.endswith('.patch'):
                            ext = 'patch'
                            file_type = 'Patch'
                        else:  # .sh
                            ext = 'sh'
                            file_type = 'Shell Script'
                        
                        patch_sh_files.append({
                            "path": full_path,
                            "content": content,
                            "type": "source",
                            "extension": ext
                        })
                        print(f"✓ 已读取 {file_type} 文件(GBK): {full_path}")
                    except Exception as e:
                        print(f"⚠ 编码错误，仅记录路径: {full_path} - {e}")
                        # 确定扩展名
                        if filename.endswith('.patch'):
                            ext = 'patch'
                        else:
                            ext = 'sh'
                        other_files.append({
                            "path": full_path,
                            "type": "other",
                            "skip_reason": "encoding_error",
                            "extension": ext
                        })
                except Exception as e:
                    print(f"✗ 读取失败，仅记录路径: {full_path} - {e}")
                    # 确定扩展名
                    if filename.endswith('.patch'):
                        ext = 'patch'
                    else:
                        ext = 'sh'
                    other_files.append({
                        "path": full_path,
                        "type": "other",
                        "skip_reason": "read_error",
                        "extension": ext
                    })
            else:
                # 其他格式文件，只记录路径
                other_files.append({
                    "path": full_path,
                    "type": "other"
                })
                print(f"📄 记录其他文件: {full_path}")
    
    return patch_sh_files, other_files, skipped_dirs_count

def save_to_json(patch_sh_files, other_files, skipped_dirs_count, output_file):
    """
    将数据保存为 JSON 文件
    """
    # 统计各类型文件数量
    patch_count = sum(1 for f in patch_sh_files if f.get('extension') == 'patch')
    sh_count = sum(1 for f in patch_sh_files if f.get('extension') == 'sh')
    
    result = {
        "summary": {
            "total_patch_sh_files": len(patch_sh_files),
            "total_other_files": len(other_files),
            "total_files": len(patch_sh_files) + len(other_files),
            "patch_files": patch_count,
            "sh_files": sh_count,
            "skipped_directories": skipped_dirs_count,
            "excluded_directories": list(EXCLUDE_DIRS)
        },
        "patch_sh_files": patch_sh_files,
        "other_files": other_files
    }
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
    
    print(f"\n{'='*60}")
    print(f"✅ 成功保存到: {output_file}")
    print(f"📊 统计信息:")
    print(f"   - Patch 文件（含内容）: {patch_count} 个")
    print(f"   - Shell 脚本文件（含内容）: {sh_count} 个")
    print(f"   - 其他文件（仅路径）: {len(other_files)} 个")
    print(f"   - 总计: {len(patch_sh_files) + len(other_files)} 个文件")
    print(f"   - 跳过的排除目录: {skipped_dirs_count} 个")
    print(f"   - 排除的目录: {', '.join(EXCLUDE_DIRS)}")
    print(f"{'='*60}")

def main():
    # 设置输出文件名
    output_file = 'patch_sh_export.json'
    
    # 如果指定了输出参数，使用第一个参数作为输出文件名
    if len(sys.argv) > 1:
        output_file = sys.argv[1]
    
    # 搜索当前目录
    current_dir = os.getcwd()
    print(f"🔍 开始搜索目录: {current_dir}")
    print(f"🚫 排除目录: {', '.join(EXCLUDE_DIRS)}")
    print(f"{'='*60}")
    
    # 收集所有文件
    patch_sh_files, other_files, skipped_dirs_count = collect_files(current_dir)
    
    # 保存到 JSON
    save_to_json(patch_sh_files, other_files, skipped_dirs_count, output_file)

if __name__ == "__main__":
    main()