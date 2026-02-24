#!/bin/bash

# Xray 安装脚本
# 功能：下载并安装最新版 Xray 到 /opt/xray 目录

echo "=================================="
echo "    Xray 安装脚本启动"
echo "=================================="

# 检查并安装所需软件包
echo "检查并安装必要软件包"

# 检测包管理器并安装
if command -v apt &> /dev/null; then
    # Debian/Ubuntu 系列
    echo "检测到 apt 包管理器"
    apt update
    apt install -y wget curl unzip
elif command -v yum &> /dev/null; then
    # CentOS/RHEL 7/8 系列
    echo "检测到 yum 包管理器"
    yum install -y wget curl unzip
elif command -v dnf &> /dev/null; then
    # Fedora/RHEL 8+ 系列
    echo "检测到 dnf 包管理器"
    dnf install -y wget curl unzip
elif command -v pacman &> /dev/null; then
    # Arch Linux 系列
    echo "检测到 pacman 包管理器"
    pacman -Sy --noconfirm wget curl unzip
elif command -v apk &> /dev/null; then
    # Alpine Linux 系列
    echo "检测到 apk 包管理器"
    apk add
    apk add wget curl unzip
else
    echo "警告：无法自动安装软件包，请确保系统已安装 wget、curl 和 unzip"
    echo "支持的包管理器：apt, yum, dnf, pacman, apk"
fi

echo "软件包检查完成"

# 创建 /opt/xray 目录
echo "创建 /opt/xray 目录..."
mkdir -p /opt/xray
if [ $? -eq 0 ]; then
    echo "目录创建成功：/opt/xray"
else
    echo "错误：无法创建目录 /opt/xray"
    exit 1
fi

# 切换到 /opt/xray 目录
cd /opt/xray || exit 1

# 获取最新版本号
echo "获取 Xray 最新版本信息..."

# 使用 GitHub API 获取最新版本号
if command -v curl &> /dev/null; then
    LATEST_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep "tag_name" | cut -d '"' -f 4)
elif command -v wget &> /dev/null; then
    LATEST_VERSION=$(wget -qO- https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep "tag_name" | cut -d '"' -f 4)
else
    echo "错误：无法获取最新版本信息，需要 curl 或 wget"
    exit 1
fi

if [ -z "$LATEST_VERSION" ]; then
    echo "警告：无法获取最新版本号，使用默认版本 v26.2.6"
    LATEST_VERSION="v26.2.6"
else
    echo "获取到最新版本：$LATEST_VERSION"
fi

# 构建下载链接
DOWNLOAD_URL="https://github.com/XTLS/Xray-core/releases/download/${LATEST_VERSION}/Xray-linux-64.zip"
echo "下载地址：$DOWNLOAD_URL"

# 下载 Xray 压缩包
echo "开始下载 Xray ${LATEST_VERSION}..."

# 尝试使用 wget 下载，如果没有 wget 则尝试使用 curl
if command -v wget &> /dev/null; then
   wget --show-progress -q "$DOWNLOAD_URL"
elif command -v curl &> /dev/null; then
    curl -L -o Xray-linux-64.zip --progress-bar "$DOWNLOAD_URL"
else
    echo "错误：系统中没有 wget 或 curl，无法下载"
    exit 1
fi

if [ $? -eq 0 ] && [ -f "Xray-linux-64.zip" ]; then
    echo "下载完成"
else
    echo "错误：下载失败"
    exit 1
fi

# 解压文件
echo "正在解压文件到当前目录..."
if command -v unzip &> /dev/null; then
    unzip -q Xray-linux-64.zip
else
    echo "错误：系统中没有 unzip，无法解压"
    exit 1
fi

if [ $? -eq 0 ]; then
    echo "解压完成"
    echo "解压文件列表："
    ls -la /opt/xray
else
    echo "错误：解压失败"
    exit 1
fi

# 删除压缩包
echo "清理临时文件..."
rm -f Xray-linux-64.zip

if [ $? -eq 0 ]; then
    echo "压缩包已删除"
else
    echo "警告：压缩包删除失败"
fi

# 设置执行权限
chmod +x /opt/xray/xray

# 显示完成信息
echo "=================================="
echo "    Xray 安装完成！"
echo "=================================="
echo "安装版本：$LATEST_VERSION"
echo "安装位置：/opt/xray"
echo "=================================="

