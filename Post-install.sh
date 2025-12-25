#!/bin/bash

# ==========================================
# 系统配置自动化脚本
# ==========================================

set -e # 遇到错误立即停止

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否以 root 运行
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}请使用 sudo 运行此脚本: sudo bash $0${NC}" 
   exit 1
fi

# 获取真实用户 (非 root)
if [ -n "$SUDO_USER" ]; then
    REAL_USER=$SUDO_USER
else
    echo -e "${RED}无法检测到 sudo 用户，请不要直接以 root 登录运行，请使用普通用户 sudo 执行。${NC}"
    exit 1
fi

echo -e "${GREEN}当前运行用户: root${NC}"
echo -e "${GREEN}目标配置用户: $REAL_USER${NC}"

# 询问函数
ask_yes_no() {
    while true; do
        read -p "$1 [y/n]: " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "请输入 y 或 n.";;
        esac
    done
}

# ==========================================
# 2.1 软件源配置 (Nala)
# ==========================================
echo -e "${YELLOW}>>> 2.1 配置 Nala 软件源...${NC}"

# 检查 nala 是否安装
if ! command -v nala &> /dev/null; then
    apt update && apt install -y nala
fi

# ==========================================
# 2.2 桌面环境与常用软件
# ==========================================
echo -e "${YELLOW}>>> 2.2 安装桌面环境与常用软件...${NC}"

nala install -y \
  gdm3 \
  gnome-terminal \
  flatpak \
  fonts-noto-cjk \
  git \
  ibus-libpinyin \
  preload \
  adb \
  fastboot \
  thermald

# 移除无用软件
echo -e "${YELLOW}正在清理无用软件...${NC}"
nala update
nala remove -y fortune-* debian-reference-* malcontent-*

# ==========================================
# 2.3 Flatpak 配置
# ==========================================
echo -e "${YELLOW}>>> 2.3 配置 Flatpak (为用户 $REAL_USER)...${NC}"

# 注意：Flatpak --user 命令必须以普通用户身份运行
sudo -u "$REAL_USER" flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo --user
sudo -u "$REAL_USER" flatpak remote-modify flathub --url=https://mirrors.ustc.edu.cn/flathub --user
sudo -u "$REAL_USER" flatpak update --user

echo -e "${YELLOW}正在安装 Flatpak 常用应用...${NC}"
sudo -u "$REAL_USER" flatpak install --user -y flathub \
  com.github.tchx84.Flatseal \
  io.gitlab.librewolf-community \
  org.libreoffice.LibreOffice \
  net.cozic.joplin_desktop \
  io.github.ungoogled_software.ungoogled_chromium \
  net.agalwood.Motrix \
  org.gimp.GIMP \
  com.dec05eba.gpu_screen_recorder \
  com.mattjakeman.ExtensionManager \
  org.localsend.localsend_app \
  com.cherry_ai.CherryStudio \
  com.usebottles.bottles \
  org.telegram.desktop \
  page.tesk.Refine

# ==========================================
# 2.4 内核更换
# ==========================================
echo -e "${YELLOW}>>> 2.4 更换 Xanmod 内核...${NC}"

wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes

echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | tee /etc/apt/sources.list.d/xanmod-release.list

nala update
nala install -y linux-xanmod-x64v3

# ==========================================
# 2.5 (可选) 电源管理优化
# ==========================================
if ask_yes_no "是否安装 auto-cpufreq 电源管理优化 (2.5)?"; then
    echo -e "${YELLOW}>>> 正在安装 auto-cpufreq...${NC}"
    # 为了避免权限问题，在 /tmp 操作
    cd /tmp
    git clone https://github.com/AdnanHodzic/auto-cpufreq.git
    cd auto-cpufreq
    # 自动安装
    ./auto-cpufreq-installer --install
    # 启用
    auto-cpufreq --install
    cd .. && rm -rf auto-cpufreq
else
    echo "跳过 auto-cpufreq 安装。"
fi

# ==========================================
# 2.6 zram 配置
# ==========================================
echo -e "${YELLOW}>>> 2.6 配置 zram...${NC}"
nala install -y zram-tools

# 自动配置而不是打开 nano
echo -e "${YELLOW}正在写入 zram 默认配置 (lz4, 50% RAM)...${NC}"
tee /etc/default/zramswap << 'EOF'
ALGO=lz4
PERCENT=50
EOF
systemctl restart zramswap.service

# ==========================================
# 3.1 (可选) Docker 配置
# ==========================================
if ask_yes_no "是否安装 Docker 及配置国内镜像 (3.1)?"; then
    echo -e "${YELLOW}>>> 正在安装 Docker...${NC}"
    
    nala update
    nala install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # 修正：在外部获取代号，避免 heredoc 无法解析变量的问题
    VERSION_CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
    
    tee /etc/apt/sources.list.d/docker.sources << EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: ${VERSION_CODENAME}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
    
    nala update
    nala install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
    
    # 将真实用户加入 docker 组
    usermod -aG docker "$REAL_USER"
    echo -e "${GREEN}用户 $REAL_USER 已加入 docker 用户组。${NC}"

    # 配置镜像源
    echo -e "${YELLOW}>>> 配置 Docker 镜像源...${NC}"
    mkdir -p /etc/docker
    # 这里不需要为 docker 用户建 home 目录，data-root 还是放 /var/lib/docker 比较标准
    # 但如果为了遵循您的文档，我们将 data-root 设为 /home/docker，需确保该目录存在且权限正确
    mkdir -p /home/docker
    
    tee /etc/docker/daemon.json << 'EOF'
{
  "data-root": "/home/docker",
  "registry-mirrors": [
    "https://docker.xuanyuan.me",
    "https://docker.m.daocloud.io",
    "https://dockerproxy.com",
    "https://hub.rat.dev"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
EOF
    systemctl daemon-reload
    systemctl restart docker
else
    echo "跳过 Docker 安装。"
fi

# ==========================================
# 四、系统优化
# ==========================================
echo -e "${YELLOW}>>> 4.1 Systemd 优化...${NC}"
systemctl enable --now fstrim.timer
systemctl enable --now thermald

echo -e "${YELLOW}>>> 4.2 内核参数优化...${NC}"
tee -a /etc/sysctl.conf << 'EOF'
# Virtual Memory
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5

# Network Core
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216

# TCP Optimization
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv6.conf.all.accept_ra = 2
EOF

sysctl -p

# ==========================================
# 完成
# ==========================================
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}所有任务已完成！${NC}"
echo -e "${YELLOW}注意：${NC}"
echo -e "1. 已更换内核，建议重启系统。"
echo -e "2. 如果安装了 Docker，用户组更改将在重新登录后生效。"
echo -e "3. Flatpak 应用已安装到用户 $REAL_USER 下。"
echo -e "${GREEN}==========================================${NC}"
