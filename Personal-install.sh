#!/bin/bash
# Debian 13 (Trixie) gnome
set -e

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo "This script should not be run as root directly. It will use sudo when needed."
    exit 1
fi

# --- Helper Function for Yes/No Prompts ---
confirm() {
    read -p "$1 (y/n): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Temporary directory for downloads
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# 1. APT Sources (USTC Mirror)
if confirm ">> 1. Configure USTC Mirror for APT?"; then
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
    sudo tee /etc/apt/sources.list << 'EOF'
deb http://mirrors.ustc.edu.cn/debian/ trixie main 
deb http://mirrors.ustc.edu.cn/debian/ trixie-updates main 
deb http://mirrors.ustc.edu.cn/debian-security trixie-security main
    sudo apt update
fi

# 2. Desktop Environment & Common Software
if confirm ">> 2. Install Desktop Environment (GDM3/GNOME tools) and common apps?"; then
    sudo apt install -y gdm3 gnome-terminal flatpak fonts-noto-cjk-extra adb fastboot git ibus-libpinyin
    echo ">> Removing unnecessary packages..."
    sudo apt remove -y fortune-* debian-reference-* malcontent-*
    sudo apt autoremove --purge -y
    sudo apt upgrade -y
fi

# 3. Flatpak Setup
if confirm ">> 3. Setup Flatpak (USTC Mirror) and install apps?"; then
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo --user
    flatpak remote-modify flathub --url=https://mirrors.ustc.edu.cn/flathub --user
    flatpak update --user
    flatpak install --user -y flathub \
      com.github.tchx84.Flatseal io.gitlab.librewolf-community \
      org.libreoffice.LibreOffice net.cozic.joplin_desktop \
      io.github.ungoogled_software.ungoogled_chromium net.agalwood.Motrix \
      io.mpv.Mpv org.gimp.GIMP com.dec05eba.gpu_screen_recorder \
      com.mattjakeman.ExtensionManager org.localsend.localsend_app \
      com.cherry_ai.CherryStudio com.usebottles.bottles org.telegram.desktop
fi

# 4. Liquorix Kernel
if confirm ">> 4. Switch to Liquorix Kernel (Better Desktop Responsiveness)?"; then
    echo ">> Downloading Liquorix install script safely..."
    curl -s 'https://liquorix.net/install-liquorix.sh' -o "$TMP_DIR/install-liquorix.sh"
    chmod +x "$TMP_DIR/install-liquorix.sh"
    echo ">> Script downloaded. You can review it: $TMP_DIR/install-liquorix.sh"
    sudo bash "$TMP_DIR/install-liquorix.sh"
fi

# 5. Power Management (auto-cpufreq)
if confirm ">> 5. Install auto-cpufreq for battery/thermal optimization?"; then
    git clone https://github.com/AdnanHodzic/auto-cpufreq.git "$TMP_DIR/auto-cpufreq"
    cd "$TMP_DIR/auto-cpufreq"
    sudo ./auto-cpufreq-installer
    sudo auto-cpufreq --install
    cd -
fi

# 6. Rust Toolchain
if confirm ">> 6. Install Rust Toolchain (with USTC Mirror)?"; then
    echo ">> Downloading rustup script safely..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o "$TMP_DIR/rustup.sh"
    chmod +x "$TMP_DIR/rustup.sh"
    "$TMP_DIR/rustup.sh" -y
    source "$HOME/.cargo/env"
    mkdir -p ~/.cargo
    cat > ~/.cargo/config.toml << 'EOF'
[source.crates-io]
replace-with = 'ustc'
[source.ustc]
registry = "git://mirrors.ustc.edu.cn/crates.io-index.git"
EOF
fi

# 7. Docker Production Environment
if confirm ">> 7. Install Docker Engine and configure mirrors?"; then
    sudo apt update
    sudo apt install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Set up repo
    CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
    sudo tee /etc/apt/sources.list.d/docker.sources << EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $CODENAME
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl enable --now docker
    sudo usermod -aG docker $USER

    # Mirror Config & Data Root (保持你原来的 /home/docker)
    sudo mkdir -p /etc/docker /home/docker
    sudo tee /etc/docker/daemon.json << 'EOF'
{
  "data-root": "/home/docker",
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://registry.aliyuncs.com",
    "https://hub-mirror.c.163.com",
    "https://mirror.azure.cn/docker-hub",
    "https://registry.huawei.com"
  ],
  "log-driver": "json-file",
  "log-opts": { "max-size": "100m", "max-file": "3" }
}
EOF
    sudo systemctl daemon-reload
    sudo systemctl restart docker
fi

# 8. System Optimizations (SSD & Kernel)
if confirm ">> 8. Apply SSD TRIM and Kernel TCP/BBR Optimizations?"; then
    sudo systemctl enable --now fstrim.timer
    sudo tee -a /etc/sysctl.conf << 'EOF'
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
    sudo sysctl -p
fi

echo "-------------------------------------------------------"
echo ">> All tasks completed!"
echo ">> Note: Docker group changes usually require a logout/login."
echo ">> Note: If you installed Rust, run 'source \$HOME/.cargo/env' or add it to ~/.bashrc."
