#!/bin/bash
# Labwc Installer for Debian 13
set -e

# 1. Check Root (Must run as normal user)
if [ "$(id -u)" -eq 0 ]; then
    echo "Error: Please run as a normal user (without sudo)."
    exit 1
fi

echo ">> Preparing system..."

# 2. [Critical Fix] Install HTTPS support first
#    This prevents 'apt update' failure after changing sources to https.
#    Assumes original sources (cdrom/http) are valid.
sudo apt update || echo "Warning: Initial update failed, attempting to install ca-certificates anyway..."
sudo apt install -y curl wget apt-transport-https ca-certificates lsb-release

# 3. Switch to USTC Mirror (Debian Trixie)
echo ">> Configuring APT sources to USTC Mirror..."
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
sudo tee /etc/apt/sources.list << 'EOF'
deb https://mirrors.ustc.edu.cn/debian/ trixie main
deb https://mirrors.ustc.edu.cn/debian/ trixie-updates main
deb https://mirrors.ustc.edu.cn/debian-security trixie-security main

echo ">> Updating package lists..."
sudo apt update

# 4. Install Labwc and full dependencies
#    - xdg-desktop-portal-wlr: Required for screen sharing/interactions
#    - network-manager-gnome: Required for WiFi management (nm-applet)
#    - gnome-themes-extra: Provides the 'Adwaita' window theme
#    - mesa-utils: Basic graphics drivers
#    - dbus/dbus-x11: Essential for inter-process communication
#    - mousepad: Lightweight text editor
#    - pavucontrol: GUI audio mixer
#    - xarchiver: Archive manager
#    - htop: System monitor
echo ">> Installing Labwc and essentials..."
sudo apt install -y \
    labwc waybar swaybg foot fuzzel pcmanfm lxpolkit \
    xwayland grim slurp mako-notifier \
    pipewire pipewire-pulse wireplumber \
    fonts-jetbrains-mono font-awesome swaylock swayidle \
    xdg-desktop-portal xdg-desktop-portal-wlr \
    network-manager-gnome \
    gnome-themes-extra adwaita-icon-theme \
    mesa-utils libgl1-mesa-dri \
    dbus dbus-x11 \
    mousepad pavucontrol xarchiver htop

# 5. Configure directory structure
mkdir -p ~/.config/labwc ~/.config/waybar

# 6. Configure Environment Variables
cat > ~/.config/labwc/environment << EOF
XDG_CURRENT_DESKTOP=labwc
XDG_SESSION_TYPE=wayland
XDG_SESSION_DESKTOP=labwc
MOZ_ENABLE_WAYLAND=1
QT_QPA_PLATFORM=wayland
GTK_BACKEND=wayland
EOF

# 7. Autostart
#    - dbus-update-activation-environment: Ensure D-Bus environment is set
#    - pipewire services: Manual start for TTY-based sessions
#    - nm-applet: Network tray icon
cat > ~/.config/labwc/autostart << EOF
#!/bin/sh
# Ensure D-Bus environment is updated
dbus-update-activation-environment --all &

# Start audio services (fallback for non-systemd sessions)
pipewire &
pipewire-pulse &
wireplumber &

# Start system services
lxpolkit &
nm-applet --indicator &
waybar &
mako &
swaybg -c "#2e3440" &
swayidle -w timeout 300 'swaylock -f -c 000000' &
EOF
chmod +x ~/.config/labwc/autostart

# 8. Menu (Right-click)
cat > ~/.config/labwc/menu.xml << EOF
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
#    Note: Adwaita theme depends on gnome-themes-extra package
#    Added screenshot keybinds using grim and slurp
cat > ~/.config/labwc/rc.xml << EOF
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
    <keybind key="Print"><action name="Execute" command="grim ~/screenshot-\$(date +%Y%m%d-%H%M%S).png"/></keybind>
    <keybind key="W-Print"><action name="Execute" command="grim -g '\$(slurp)' ~/screenshot-\$(date +%Y%m%d-%H%M%S).png"/></keybind>
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

# 10. Waybar Configuration
cat > ~/.config/waybar/config << EOF
{
    "layer": "top",
    "height": 30,
    "modules-left": ["wlr/workspaces", "wlr/taskbar"],
    "modules-center": ["clock"],
    "modules-right": ["cpu", "memory", "network", "pulseaudio", "tray"],
    "wlr/workspaces": {
        "format": "{name}",
        "on-click": "activate"
    },
    "wlr/taskbar": {
        "format": "{icon}",
        "on-click": "activate"
    },
    "clock": {"format-alt": "{:%Y-%m-%d %H:%M}"},
    "cpu": {"format": "{usage}% CPU"},
    "memory": {"format": "{used:0.1f}GiB RAM"},
    "network": {
        "format-wifi": "{essid} ({signalStrength}%)",
        "format-ethernet": "{ipaddr}/{cidr}",
        "format-disconnected": "Disconnected"
    },
    "pulseaudio": {"format": "{volume}% vol"},
    "tray": {"spacing": 10}
}
EOF

cat > ~/.config/waybar/style.css << EOF
* { font-family: "JetBrains Mono", "FontAwesome 6 Free", "FontAwesome"; font-size: 13px; }
window#waybar { background: #2e3440; color: #ffffff; }
EOF

# 11. [Critical Fix] Auto-enable Audio Services
echo ">> Enabling Audio Services..."
systemctl --user enable --now pipewire pipewire-pulse wireplumber || echo "Note: systemd user services may not start until graphical session"

echo "-------------------------------------------------------"
echo ">> Installation Complete!"
echo ">> Backup: /etc/apt/sources.list.bak"
echo "-------------------------------------------------------"
echo ">> How to start Labwc:"
echo "   From TTY, run:"
echo "   dbus-run-session labwc"
echo ""
echo ">> Keyboard Shortcuts:"
echo "   Win+Enter       : Terminal"
echo "   Win+D           : Application Launcher"
echo "   Win+Q           : Close Window"
echo "   Win+L           : Lock Screen"
echo "   Win+Shift+E     : Exit Labwc"
echo "   Print           : Screenshot (full screen)"
echo "   Win+Print       : Screenshot (selection)"
echo ""
echo ">> Right-click on desktop to access menu"
echo "-------------------------------------------------------"
