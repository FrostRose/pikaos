#!/bin/bash

# ============================================================
# System Configuration & Optimization Script
# Based on provided documentation
# ============================================================

set -e # Exit immediately if a command exits with a non-zero status

# Helper function for optional steps
ask_run() {
    local prompt="$1"
    local default="${2:-N}"
    if [[ "$default" == "Y" ]]; then
        prompt="$prompt [Y/n] "
    else
        prompt="$prompt [y/N] "
    fi
    read -p "$prompt" response
    if [[ -z "$response" ]]; then
        response="$default"
    fi
    if [[ "$response" =~ ^[yY][eE][sS]|[yY]$ ]]; then
        return 0
    else
        return 1
    fi
}

echo "Starting System Configuration..."

# ============================================================
# II. System Configuration
# ============================================================

echo ""
echo "### 2.1 Software Sources"
echo "Installing nala and updating..."
sudo apt update && sudo apt install nala && sudo nala update

echo ""
if ask_run "### 2.1.5 (Optional) Run Pika OS 1 cleanup (remove gnome/flatpak)?" "N"; then
    sudo apt autoremove --purge "gnome*" "pika-gnome*" firefox
fi

echo ""
echo "### 2.2 Desktop Environment and Common Software"
echo "Installing essential packages..."
sudo nala install -y \
  gdm3 \
  gnome-terminal \
  flatpak \
  fonts-noto-cjk \
  git \
  ibus-libpinyin \
  preload \
  zram-tools \
  adb \
  fastboot \
  thermald # Intel cooling

sudo nala update
echo "Removing unnecessary packages..."
sudo nala remove fortune-* debian-reference-* malcontent-* yelp gnome-user-share

echo ""
if ask_run "### 2.2.5 (Optional) Install Pika 2 (Kernel Manager & Wallpapers)?" "N"; then
    sudo nala install pika-kernel-manager pika-wallpapers
fi

echo ""
echo "### 2.3 Flatpak"
echo "Configuring Flatpak sources..."
flatpak remote-delete flathub || true # Ignore error if not exists

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo --user

flatpak remote-modify flathub --url=https://mirrors.ustc.edu.cn/flathub --user

echo "Installing common Flatpak software..."
flatpak install --user -y flathub \
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

echo ""
if ask_run "### 2.4 (Optional) Install Xanmod Kernel?" "N"; then
    wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg
    echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | tee /etc/apt/sources.list.d/xanmod-release.list
    sudo nala update
    sudo nala install -y linux-xanmod-x64v3
fi

# ============================================================
# III. Production Environment
# ============================================================

echo ""
if ask_run "### 3.1 (Optional) Configure Docker Environment?" "N"; then
    
    echo "Configuring Docker Sources..."
    sudo nala update
    sudo nala install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Note: Unquoted EOF to allow variable expansion for VERSION_CODENAME
    sudo tee /etc/apt/sources.list.d/docker.sources << EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
    sudo nala update

    echo "#### 3.1.1 Install Docker"
    sudo nala install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl enable --now docker
    sudo usermod -aG docker $USER
    # Note: newgrp starts a new shell, which might interrupt the script. 
    # executed here but changes apply to current session only if interactive.
    # We will skip 'newgrp' in the script flow to prevent hanging, 
    # usually a reboot or re-login is preferred.

    echo "#### 3.1.2 Mirror Sources"
    sudo mkdir -p /etc/docker
    sudo mkdir -p /home/docker
    sudo tee /etc/docker/daemon.json << 'EOF'
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

    sudo systemctl daemon-reload
    sudo systemctl restart docker
    echo "Docker configuration complete. Please log out and back in for group changes to take effect."
fi

# ============================================================
# IV. System Optimization
# ============================================================

echo ""
echo "### 4.1 General Optimization"

echo "# systemd optimization"
systemctl --user enable --now fstrim.timer
systemctl --user enable --now thermald

echo "# Transparent Huge Pages (THP) optimization"
echo always | sudo tee /sys/kernel/mm/transparent_hugepage/enabled

echo "# zram optimization"
echo -e "ALGO=lz4\nPERCENT=100\nPRIORITY=100" | sudo tee /etc/default/zramswap > /dev/null && sudo systemctl restart zramswap


echo ""
if ask_run "### 4.3 (Optional) Install NVIDIA Graphics Driver?" "N"; then
    sudo nala update

    echo "# Detect NVIDIA GPU"
    lspci | grep -i nvidia

    echo "# install"
    sudo nala install -y \
      linux-headers-$(uname -r) \
      nvidia-driver \
      nvidia-kernel-dkms \
      firmware-misc-nonfree

    echo "# For Docker"
    sudo nala install -y nvidia-container-toolkit
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker

    echo "# For Wayland"
    echo "options nvidia-drm modeset=1 fbdev=1" | sudo tee /etc/modprobe.d/nvidia-options.conf
    sudo update-initramfs -u

    echo "NVIDIA drivers installed. System reboot is recommended."
    if ask_run "Reboot now?" "Y"; then
        sudo reboot
    fi
fi

echo ""
echo "Script execution completed."
