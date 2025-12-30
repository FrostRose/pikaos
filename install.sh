#!/bin/bash

# --- Configuration & Colors ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Detect the real user (if running via sudo) to install Flatpaks for the correct user
if [ $SUDO_USER ]; then
    REAL_USER=$SUDO_USER
else
    REAL_USER=$(whoami)
fi

echo -e "${GREEN}Starting System Setup Script...${NC}"
echo -e "${YELLOW}Running setup for user: ${REAL_USER}${NC}"

# --- Helper Function for Yes/No Prompts ---
ask_yes_no() {
    while true; do
        read -p "$1 [y/n]: " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# --- Step 1: Base System & Nala ---
echo -e "${GREEN}[1/7] Installing Nala and updating system...${NC}"
sudo apt install -y nala
sudo nala update

echo -e "${GREEN}[2/7] Installing core packages...${NC}"
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
  thermald

echo -e "${GREEN}[3/7] Cleaning up bloatware...${NC}"
sudo nala remove -y fortune-* debian-reference-* malcontent-* yelp

# --- Step 2: Flatpak Configuration ---
echo -e "${GREEN}[4/7] Configuring Flatpak...${NC}"

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo --user

flatpak remote-modify flathub --url=https://mirrors.ustc.edu.cn/flathub --user

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

# --- Step 3: XanMod Kernel ---
echo -e "${GREEN}[5/7] Installing XanMod Kernel...${NC}"
wget -qO - https://dl.xanmod.org/archive.key | sudo gpg --dearmor --yes -o /usr/share/keyrings/xanmod-archive-keyring.gpg
echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | sudo tee /etc/apt/sources.list.d/xanmod-release.list
sudo nala update
sudo nala install -y linux-xanmod-x64v3

# --- Step 4: Optional - Auto-cpufreq ---
if ask_yes_no "${YELLOW}Do you want to install auto-cpufreq (Battery optimization)?${NC}"; then
    echo -e "${GREEN}Installing auto-cpufreq...${NC}"
    git clone https://github.com/AdnanHodzic/auto-cpufreq.git
    cd auto-cpufreq
    sudo ./auto-cpufreq-installer
    sudo auto-cpufreq --install
    cd .. && rm -rf auto-cpufreq
else
    echo "Skipping auto-cpufreq."
fi

# --- Step 5: Optional - Docker ---
if ask_yes_no "${YELLOW}Do you want to install Docker (with CN mirrors)?${NC}"; then
    echo -e "${GREEN}Installing Docker...${NC}"
    sudo nala update
    sudo nala install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null

    sudo nala update
    sudo nala install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    sudo systemctl enable --now docker
    sudo usermod -aG docker "$REAL_USER"
    
    # Configure Docker Daemon (Mirrors & Logging)
    echo -e "${GREEN}Configuring Docker Daemon...${NC}"
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
else
    echo "Skipping Docker installation."
fi

# --- Step 6: System Optimizations ---
echo -e "${GREEN}[6/7] Applying system optimizations...${NC}"

sudo systemctl enable --now fstrim.timer
sudo systemctl enable --now thermald

echo -e "${GREEN}Writing sysctl configurations...${NC}"
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

# --- Step 7: Finish ---
echo -e "${GREEN}[7/7] Installation Complete!${NC}"
echo -e "${YELLOW}Note: If you installed Docker, you may need to log out and log back in for group permissions to take effect.${NC}"
echo -e "${YELLOW}Please reboot your system to load the XanMod kernel and apply all settings.${NC}"
