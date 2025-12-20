#!/bin/bash
# Labwc Installer for Debian 13 (Trixie) - TTY Optimized (English Output)

set -e

# 1. Check Root
if [ "$(id -u)" -eq 0 ]; then
    echo "Error: Please run as a normal user (without sudo)."
    exit 1
fi

# 2. Backup and Update Sources (USTC Mirror)
echo ">> Configuring APT sources (USTC Mirror)..."
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
sudo tee /etc/apt/sources.list << 'EOF'
deb https://mirrors.ustc.edu.cn/debian/ trixie main contrib non-free non-free-firmware
deb https://mirrors.ustc.edu.cn/debian/ trixie-updates main contrib non-free non-free-firmware
deb https://mirrors.ustc.edu.cn/debian-security trixie-security main contrib non-free non-free-firmware
EOF

echo ">> Updating package lists..."
sudo apt update

# 3. Install Packages
echo ">> Installing core packages and dependencies..."
sudo apt install -y labwc waybar swaybg foot fuzzel pcmanfm lxpolkit \
    xwayland grim slurp mako-notifier wireplumber pipewire-pulse \
    fonts-jetbrains-mono otf-font-awesome swaylock swayidle curl

# 4. Create Config Directories
echo ">> Creating configuration directories..."
mkdir -p ~/.config/labwc ~/.config/waybar

# 5. Environment Setup
cat > ~/.config/labwc/environment << EOF
XDG_CURRENT_DESKTOP=labwc
XDG_SESSION_TYPE=wayland
MOZ_ENABLE_WAYLAND=1
QT_QPA_PLATFORM=wayland
GTK_BACKEND=wayland
EOF

# 6. Autostart Script
cat > ~/.config/labwc/autostart << EOF
#!/bin/sh
pipewire &
pipewire-pulse &
wireplumber &
systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
lxpolkit &
waybar &
mako &
swaybg -c "#2e3440" &
EOF
chmod +x ~/.config/labwc/autostart

# 7. Menu Configuration (menu.xml)
cat > ~/.config/labwc/menu.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu>
  <menu id="root-menu">
    <item label="Terminal (Foot)"><action name="Execute" command="foot"/></item>
    <item label="File Manager"><action name="Execute" command="pcmanfm"/></item>
    <item label="App Launcher"><action name="Execute" command="fuzzel"/></item>
    <separator/>
    <item label="Exit Labwc"><action name="Exit"/></item>
  </menu>
</openbox_menu>
EOF

# 8. Keybinds and Core Config (rc.xml)
cat > ~/.config/labwc/rc.xml << EOF
<?xml version="1.0"?>
<labwc_config>
  <keyboard>
    <default/>
    <keybind key="W-Return"><action name="Execute" command="foot"/></keybind>
    <keybind key="W-d"><action name="Execute" command="fuzzel"/></keybind>
    <keybind key="W-e"><action name="Execute" command="pcmanfm"/></keybind>
    <keybind key="W-q"><action name="Close"/></keybind>
    <keybind key="A-Tab"><action name="NextWindow"/></keybind>
    <keybind key="W-Tab"><action name="NextWindow"/></keybind>
    <keybind key="W-S-e"><action name="Exit"/></keybind>
    <keybind key="W-l"><action name="Execute" command="swaylock -f -c 000000"/></keybind>
  </keyboard>

  <theme>
    <name>Adwaita</name>
    <cornerRadius>8</cornerRadius>
  </theme>

  <core>
    <gap>10</gap>
  </core>
</labwc_config>
EOF

# 9. Waybar Configuration
cat > ~/.config/waybar/config << EOF
{
    "layer": "top",
    "height": 30,
    "modules-left": ["wlr/taskbar"],
    "modules-center": ["clock"],
    "modules-right": ["cpu", "memory", "network", "pulseaudio", "tray"],

    "cpu": {"format": "{usage}% CPU"},
    "memory": {"format": "{used:0.1f}GiB RAM"},
    "network": {"format-wifi": "{essid} ({signalStrength}%)", "format-ethernet": "Ethernet"},
    "pulseaudio": {"format": "{volume}% {icon}"}
}
EOF

cat > ~/.config/waybar/style.css << EOF
* { font-family: JetBrains Mono, FontAwesome; font-size: 13px; }
window#waybar { background: #2e3440; color: #fff; }
EOF

echo "-------------------------------------------------------"
echo ">> Installation Complete!"
echo ">> Sources backup created at /etc/apt/sources.list.bak"
echo ">> How to start: Log in to TTY and run: dbus-run-session labwc"
echo ">> Keybinds: Super+Enter (Terminal), Super+D (Launcher), Super+L (Lock)"
