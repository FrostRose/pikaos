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
echo "updating..."
sudo apt update

echo ""
if ask_run "### 2.1.5 (Optional) Run Pika OS 1 cleanup (remove gnome/flatpak)?" "N"; then
    sudo apt autoremove --purge "gnome*" "pika-gnome*" firefox
fi

echo ""
echo "### 2.2 Desktop Environment and Common Software"
echo "Installing essential packages..."
sudo apt install -y \
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

sudo apt update
echo "Removing unnecessary packages..."
sudo apt remove fortune-* debian-reference-* malcontent-* yelp gnome-user-share

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

echo "1) Enable/Optimize zRAM"
echo "2) Disable/Mask zRAM"
read -p "Choice [1-2]: " c

if [ "$c" == "1" ]; then
    echo -e "ALGO=lz4\nPERCENT=100\nPRIORITY=100" | sudo tee /etc/default/zramswap > /dev/null
    systemctl enable --now zramswap
    echo "Done. zRAM is active."
elif [ "$c" == "2" ]; then
    systemctl stop zramswap
    systemctl disable zramswap
    systemctl mask zramswap
    echo "Done. zRAM is masked."
else
    echo "Invalid."
fi


echo ""
echo "Script execution completed."
