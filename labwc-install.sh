#!/bin/bash
# Labwc Installer for Debian 13
set -e

# --- 1. User Check ---
if [ "$(id -u)" -eq 0 ]; then
    echo "Error: Please run as a normal user (without sudo)."
    exit 1
fi

echo "======================================================="
echo "   Labwc Installer for Debian 13 (Trixie)              "
echo "======================================================="
echo "This script will configure USTC mirrors for Debian 13"
echo "and install a complete Wayland desktop environment."
echo ""

echo ">> Preparing system..."

# 2. Install HTTPS support first
#    Ensures 'apt update' works before switching sources
sudo apt update || echo "Warning: Update failed, trying to fix dependencies..."
sudo apt install -y curl wget apt-transport-https ca-certificates lsb-release

# 3. Switch to USTC Mirror (Debian Trixie)
#    Restored original source configuration requested by user.
echo ">> Configuring APT sources to USTC Mirror..."
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
sudo tee /etc/apt/sources.list << 'EOF'
deb https://mirrors.ustc.edu.cn/debian/ trixie main
deb https://mirrors.ustc.edu.cn/debian/ trixie-updates main
deb https://mirrors.ustc.edu.cn/debian-security trixie-security main
EOF

echo ">> Updating package lists..."
sudo apt update

# 3.5 Ensure System is Up-to-Date
#     Standard procedure to ensure base system matches the new sources.
echo ">> upgrading system packages..."
sudo apt upgrade -y

# 4. Install Labwc and full dependencies
#    - Added 'firmware-linux' (drivers)
#    - Added 'openbox' (required for Labwc theme assets)
#    - Added 'libnotify-bin' (for notifications)
echo ">> Installing Labwc and essentials..."
sudo apt install -y \
    labwc waybar swaybg foot fuzzel pcmanfm lxpolkit \
    xwayland grim slurp mako-notifier libnotify-bin \
    pipewire pipewire-pulse wireplumber \
    fonts-jetbrains-mono fonts-font-awesome swaylock swayidle \
    xdg-desktop-portal xdg-desktop-portal-wlr \
    network-manager-gnome firmware-linux \
    gnome-themes-extra adwaita-icon-theme \
    mesa-utils libgl1-mesa-dri \
    dbus dbus-x11 openbox \
    mousepad pavucontrol xarchiver htop

# 4.5 Enable NetworkManager Service
echo ">> Enabling NetworkManager..."
sudo systemctl enable --now NetworkManager

# 5. Configure directory structure
mkdir -p ~/.config/labwc ~/.config/waybar

# 6. Configure Environment Variables
#    Added GTK fallback to prevent crashes on older apps
cat > ~/.config/labwc/environment << 'EOF'
XDG_CURRENT_DESKTOP=labwc
XDG_SESSION_TYPE=wayland
XDG_SESSION_DESKTOP=labwc
MOZ_ENABLE_WAYLAND=1
QT_QPA_PLATFORM=wayland
GTK_BACKEND=wayland,x11
EOF

# 7. Autostart Configuration
#    Removed manual pipewire start (handled by systemd now)
#    Added dbus activation (critical for Wayland)
cat > ~/.config/labwc/autostart << 'EOF'
#!/bin/sh
# Ensure D-Bus environment is updated
dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP &

# Apply GTK Theme settings
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' &
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' &

# Start system services
/usr/lib/lxpolkit/lxpolkit &
nm-applet --indicator &
waybar &
mako &
swaybg -c "#2e3440" &
swayidle -w timeout 300 'swaylock -f -c 000000' &
EOF
chmod +x ~/.config/labwc/autostart

# 8. Menu (Right-click)
cat > ~/.config/labwc/menu.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu>
  <menu id="root-menu">
    <item label="Terminal"><action name="Execute" command="foot"/></item>
    <item label="Files"><action name="Execute" command="pcmanfm"/></item>
    <item label="Text Editor"><action name="Execute" command="mousepad"/></item>
    <item label="Volume Control"><action name="Execute" command="pavucontrol"/></item>
    <item label="System Monitor"><action name="Execute" command="foot -e htop"/></item>
    <item label="Launcher"><action name="Execute" command="fuzzel"/></item>
    <separator/>
    <item label="Reconfigure"><action name="Reconfigure"/></item>
    <item label="Lock"><action name="Execute" command="swaylock -f -c 000000"/></item>
    <item label="Exit"><action name="Exit"/></item>
  </menu>
</openbox_menu>
EOF

# 9. RC.xml (Keybinds and Theme)
#    Fixed screenshot command to auto-create directory
cat > ~/.config/labwc/rc.xml << 'EOF'
<?xml version="1.0"?>
<labwc_config>
  <keyboard>
    <default/>
    <keybind key="W-Return"><action name="Execute" command="foot"/></keybind>
    <keybind key="W-d"><action name="Execute" command="fuzzel"/></keybind>
    <keybind key="W-q"><action name="Close"/></keybind>
    <keybind key="A-Tab"><action name="NextWindow"/></keybind>
    <keybind key="W-l"><action name="Execute" command="swaylock -f -c 000000"/></keybind>
    <keybind key="W-S-e"><action name="Exit"/></keybind>
    <keybind key="Print"><action name="Execute" command="sh -c 'mkdir -p ~/Pictures/Screenshots && grim ~/Pictures/Screenshots/$(date +%Y%m%d-%H%M%S).png'"/></keybind>
    <keybind key="W-Print"><action name="Execute" command="sh -c 'mkdir -p ~/Pictures/Screenshots && slurp | grim -g - ~/Pictures/Screenshots/$(date +%Y%m%d-%H%M%S).png'"/></keybind>
  </keyboard>
  <theme>
    <name>Adwaita</name>
    <cornerRadius>8</cornerRadius>
  </theme>
  <core>
    <gap>10</gap>
    <adaptiveSync>yes</adaptiveSync>
  </core>
</labwc_config>
EOF

# 10. Waybar Configuration
cat > ~/.config/waybar/config << 'EOF'
{
    "layer": "top",
    "height": 30,
    "modules-left": ["wlr/taskbar"],
    "modules-center": ["clock"],
    "modules-right": ["cpu", "memory", "network", "pulseaudio", "tray"],
    "wlr/taskbar": {
        "format": "{icon}",
        "on-click": "activate",
        "on-click-right": "close",
        "icon-theme": "Adwaita"
    },
    "clock": {"format-alt": "{:%Y-%m-%d %H:%M}"},
    "cpu": {"format": "{usage}% CPU"},
    "memory": {"format": "{used:0.1f}GiB RAM"},
    "network": {
        "format-wifi": "{essid} ({signalStrength}%)",
        "format-ethernet": "ETH",
        "format-disconnected": "No Net"
    },
    "pulseaudio": {
        "format": "{volume}% {icon}",
        "format-muted": "Muted",
        "on-click": "pavucontrol"
    },
    "tray": {"spacing": 10}
}
EOF

cat > ~/.config/waybar/style.css << 'EOF'
* { font-family: "JetBrains Mono", "FontAwesome 6 Free", "FontAwesome"; font-size: 13px; }
window#waybar { background: #2e3440; color: #ffffff; }
EOF

# 11. Enable User Services
echo ">> Enabling Audio Services (Systemd)..."
systemctl --user daemon-reload
systemctl --user enable --now pipewire pipewire-pulse wireplumber || echo "Note: Audio services will start fully upon next login."

echo "-------------------------------------------------------"
echo ">> Installation Complete!"
echo "-------------------------------------------------------"
echo ">> Please reboot your system to apply changes."
echo ">> After reboot, log in to TTY and run:"
echo "   dbus-run-session labwc"
echo "-------------------------------------------------------"
