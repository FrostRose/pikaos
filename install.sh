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
if ask_run "Deep Cleanup Desktop ?" "N"; then
    sudo apt purge -y "gnome*" "showtime" "otter*" "pika-gnome-*" "pikman-*" "pika-device-manager" "chromium*"
    sudo apt install gdm3 -y
    sudo apt autoremove -y
fi

# 2. 安装核心包
sudo apt install -y \
  flatpak fonts-noto-cjk git ibus-libpinyin \
  preload thermald irqbalance

# 3. 卸载冗余
sudo apt remove -y fortune-* debian-reference-* malcontent-* yelp \
  gnome-user-share gnome-sushi apx

# 4. Flatpak 配置
flatpak remote-delete flathub || true
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo --user
flatpak remote-modify flathub --url=https://mirrors.ustc.edu.cn/flathub --user
flatpak install --user -y flathub \
  io.gitlab.librewolf-community \
  com.github.tchx84.Flatseal \
  org.libreoffice.LibreOffice \
  net.cozic.joplin_desktop \
  net.agalwood.Motrix \
  org.gimp.GIMP \
  com.dec05eba.gpu_screen_recorder \
  com.mattjakeman.ExtensionManager \
  org.localsend.localsend_app \
  com.usebottles.bottles \
  page.tesk.Refine
flatpak list --app --columns=application | while read app; do
    flatpak override --user --nosocket=x11 --nosocket=fallback-x11 "$app"
done

# 6. 最终清理
sudo apt autoremove --purge -y
sudo apt full-upgrade
sudo apt clean

echo "Done."
