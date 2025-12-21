#!/bin/bash

# Backup apt sources
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak

# Modify apt sources to use USTC mirrors (Debian Trixie)
sudo tee /etc/apt/sources.list << 'EOF'
deb https://mirrors.ustc.edu.cn/debian/ trixie main
deb https://mirrors.ustc.edu.cn/debian/ trixie-updates main
deb https://mirrors.ustc.edu.cn/debian-security trixie-security main
EOF

# Update package lists
sudo apt update

# Install desktop environment and essential tools
sudo apt install -y \
  gdm3 \
  gnome-terminal \
  flatpak \
  fonts-noto-cjk \
  adb \
  fastboot \
  git \
  ibus-libpinyin

# Remove unused packages and upgrade system
sudo apt remove fortune-* debian-reference-* malcontent-* && sudo apt autoremove --purge && sudo apt upgrade

# Add Flatpak remote (User scope)
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo --user

# Modify Flatpak remote to use USTC mirror
flatpak remote-modify flathub --url=https://mirrors.ustc.edu.cn/flathub --user

# Update Flatpak
flatpak update --user

# Install common Flatpak applications
flatpak install --user -y flathub \
  com.github.tchx84.Flatseal \
  io.gitlab.librewolf-community \
  org.libreoffice.LibreOffice \
  net.cozic.joplin_desktop \
  io.github.ungoogled_software.ungoogled_chromium \
  net.agalwood.Motrix \
  io.mpv.Mpv \
  org.gimp.GIMP \
  com.dec05eba.gpu_screen_recorder \
  com.mattjakeman.ExtensionManager \
  org.localsend.localsend_app \
  com.cherry_ai.CherryStudio \
  com.usebottles.bottles \
  org.telegram.desktop

# Install Liquorix Kernel
curl -s 'https://liquorix.net/install-liquorix.sh' | sudo bash

# Power Management Optimization (Optional)
while true; do
    read -p "Do you want to install auto-cpufreq for power management optimization? (y/n): " yn
    case $yn in
        [Yy]* ) 
            echo "Installing auto-cpufreq..."
            git clone https://github.com/AdnanHodzic/auto-cpufreq.git
            cd auto-cpufreq
            sudo ./auto-cpufreq-installer
            sudo auto-cpufreq --install
            cd .. && rm -rf auto-cpufreq
            break;;
        [Nn]* ) 
            echo "Skipping auto-cpufreq installation."
            break;;
        * ) echo "Please answer yes or no.";;
    esac
done

# Enable SSD TRIM
sudo systemctl enable --now fstrim.timer

# Optimize kernel parameters
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