#!/bin/bash

set -e

ask_run() {
    local prompt="$1"
    local default="${2:-N}"
    [[ "$default" == "Y" ]] && prompt="$prompt [Y/n] " || prompt="$prompt [y/N] "
    read -p "$prompt" response
    [[ -z "$response" ]] && response="$default"
    [[ "$response" =~ ^[yY][eE][sS]|[yY]$ ]] && return 0 || return 1
}

# 1. 更新与清理
sudo apt update
if ask_run "Deep Cleanup (GNOME/Flatpak/Firefox)?" "N"; then
    sudo apt purge -y "gnome*" "pika-gnome*" "chromium*"
    sudo apt autoremove --purge -y
fi

# 2. 安装核心包
sudo apt install -y \
  gdm3 flatpak fonts-noto-cjk git ibus-libpinyin \
  preload zram-tools adb fastboot thermald nala irqbalance f2fs-tools

# 3. 卸载冗余
sudo apt purge -y fortune-* debian-reference-* malcontent-* yelp \
  gnome-user-share gnome-sushi apx

# 4. Flatpak 配置
flatpak remote-delete flathub || true
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo --user
flatpak remote-modify flathub --url=https://mirrors.ustc.edu.cn/flathub --user
flatpak install --user -y flathub \
  com.github.tchx84.Flatseal org.libreoffice.LibreOffice \
  net.cozic.joplin_desktop io.github.ungoogled_software.ungoogled_chromium \
  net.agalwood.Motrix org.gimp.GIMP com.dec05eba.gpu_screen_recorder \
  com.mattjakeman.ExtensionManager org.localsend.localsend_app \
  com.cherry_ai.CherryStudio com.usebottles.bottles org.telegram.desktop page.tesk.Refine

# 5. 系统优化
sudo journalctl --vacuum-size=100M
sudo systemctl enable --now fstrim.timer thermald irqbalance

echo "1) Enable zRAM | 2) Disable zRAM"
read -p "Choice: " c
if [ "$c" == "1" ]; then
    echo -e "ALGO=lz4\nPERCENT=100\nPRIORITY=100" | sudo tee /etc/default/zramswap > /dev/null
    sudo systemctl enable --now zramswap
elif [ "$c" == "2" ]; then
    sudo systemctl disable --now zramswap
    sudo systemctl mask zramswap
fi

# 6. 自动配置 F2FS 挂载 (fstab)
F2FS_PART=$(lsblk -f -n -l | grep f2fs | awk '{print $1}' | head -n 1 || true)
if [ -n "$F2FS_PART" ]; then
    UUID=$(blkid -s UUID -o value /dev/$F2FS_PART)
    if ! grep -q "$UUID" /etc/fstab; then
        if ask_run "Found F2FS partition $F2FS_PART. Mount to /home?" "Y"; then
            echo "UUID=$UUID  /home  f2fs  defaults,atgc,gc_merge,noatime,nodiscard  0  2" | sudo tee -a /etc/fstab
            echo "F2FS mount added to /etc/fstab."
        fi
    fi
fi

# 7. 最终清理
sudo apt autoremove --purge -y
sudo apt clean

echo "Done."
