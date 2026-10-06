#!/bin/bash

# Xray 安装脚本
# 功能：下载并安装最新版 Xray 到 /opt/xray 目录

echo "=================================="
echo "    Xray 安装脚本启动"
echo "=================================="

# 选择是否使用 GitHub 镜像
MIRROR=""
USE_MIRROR_ANSWER=""
read -r -p "是否使用 GitHub 镜像加速 (https://ghfast.top/)？[y/N]: " USE_MIRROR_ANSWER || true
case "$USE_MIRROR_ANSWER" in
    [yY]|[yY][eE][sS])
        MIRROR="https://ghfast.top/"
        echo "已启用 GitHub 镜像：$MIRROR"
        ;;
    *)
        echo "未启用 GitHub 镜像，将直连 GitHub"
        ;;
esac

# 给 GitHub 链接添加镜像前缀
add_mirror() {
    if [ -n "$MIRROR" ]; then
        printf '%s%s\n' "$MIRROR" "$1"
    else
        printf '%s\n' "$1"
    fi
}

# 获取 Xray 最新版本号：解析 releases/latest，兼容镜像，不直接依赖 api.github.com
get_latest_version() {
    local url final_url version
    url="$(add_mirror "https://github.com/XTLS/Xray-core/releases/latest")"
    version=""

    if command -v curl >/dev/null 2>&1; then
        final_url=$(curl -sIL -A "Mozilla/5.0" -o /dev/null -w '%{url_effective}' "$url" 2>/dev/null)
        version=$(printf '%s\n' "$final_url" | sed -n 's#.*/tag/\(v[^/?#]*\).*#\1#p')
    fi

    if [ -z "$version" ] && command -v wget >/dev/null 2>&1; then
        version=$(wget -qO- "$url" 2>/dev/null | grep -oE '/tag/v[0-9][^"<> ]*' | head -n1 | sed 's#/tag/##')
    fi

    printf '%s\n' "$version"
}

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
    apk add --no-cache wget curl unzip
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
LATEST_VERSION=$(get_latest_version)

if [ -z "$LATEST_VERSION" ]; then
    echo "警告：无法获取最新版本号，使用默认版本 v26.2.6"
    LATEST_VERSION="v26.2.6"
else
    echo "获取到最新版本：$LATEST_VERSION"
fi

# 构建下载链接
XRAY_ZIP_URL="https://github.com/XTLS/Xray-core/releases/download/${LATEST_VERSION}/Xray-linux-64.zip"
DOWNLOAD_URL="$(add_mirror "$XRAY_ZIP_URL")"
echo "下载地址：$DOWNLOAD_URL"

# 下载 Xray 压缩包
echo "开始下载 Xray ${LATEST_VERSION}..."

if command -v wget &> /dev/null; then
    wget -O Xray-linux-64.zip "$DOWNLOAD_URL"
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

# 下载远程配置文件到 /opt/xray
echo "下载配置文件 config.json 到 /opt/xray..."
CONFIG_URL="https://one.808074.xyz/test/config.json"
if command -v wget &> /dev/null; then
    wget -qO /opt/xray/config.json "$CONFIG_URL"
elif command -v curl &> /dev/null; then
    curl -L -o /opt/xray/config.json "$CONFIG_URL"
else
    echo "警告：无法下载 config.json，需要 wget 或 curl"
fi

# 根据包管理器选择启动方式（apk -> OpenRC init.d，否则 systemd）
if command -v apk &> /dev/null; then
    echo "检测到 apk 包管理器，部署 init.d 脚本并启动..."
    INIT_URL="$(add_mirror "https://raw.githubusercontent.com/yodit10124/xray-alpine/refs/heads/main/init.d/xray")"
    if command -v wget &> /dev/null; then
        wget -qO /etc/init.d/xray "$INIT_URL"
    elif command -v curl &> /dev/null; then
        curl -L -o /etc/init.d/xray "$INIT_URL"
    else
        echo "警告：无法下载 init.d 脚本，需要 wget 或 curl"
    fi
    if [ -s /etc/init.d/xray ]; then
        chmod +x /etc/init.d/xray
        if command -v rc-update &> /dev/null; then
            rc-update add xray default || true
        fi
        /etc/init.d/xray start || echo "警告：无法通过 init.d 启动 xray"
    else
        echo "警告：init.d 脚本下载失败或为空"
    fi
else
    echo "非 apk 系统，部署 systemd 单元并启动..."
    SYSTEMD_URL="$(add_mirror "https://raw.githubusercontent.com/yodit10124/xray-alpine/refs/heads/main/systemd/xray.service")"
    if command -v wget &> /dev/null; then
        wget -qO /lib/systemd/system/xray.service "$SYSTEMD_URL"
    elif command -v curl &> /dev/null; then
        curl -L -o /lib/systemd/system/xray.service "$SYSTEMD_URL"
    else
        echo "警告：无法下载 systemd 单元文件，需要 wget 或 curl"
    fi
    if [ -s /lib/systemd/system/xray.service ]; then
        chmod 644 /lib/systemd/system/xray.service
        if command -v systemctl &> /dev/null; then
            systemctl daemon-reload
            systemctl enable --now xray.service || systemctl start xray.service || echo "警告：systemctl 启动 xray 失败"
        else
            echo "警告：未检测到 systemctl，无法启用 systemd 服务"
        fi
    else
        echo "警告：systemd 单元文件下载失败或为空"
    fi
fi

# 显示完成信息
echo "=================================="
echo "    Xray 安装完成！"
echo "=================================="
echo "安装版本：$LATEST_VERSION"
echo "安装位置：/opt/xray"
echo "镜像状态：$([ -n "$MIRROR" ] && echo "已启用 ($MIRROR)" || echo "未启用")"
echo "=================================="
