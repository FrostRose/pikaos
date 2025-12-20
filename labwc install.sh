#!/bin/bash
# Labwc Installer for Debian 13

set -e

# Check Root
if [ "$(id -u)" -eq 0 ]; then
    echo "Error: Please run as a normal user (without sudo)."
    exit 1
fi

# Switch to USTC Mirror
echo ">> Configuring APT sources to USTC Mirror..."
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
sudo tee /etc/apt/sources.list << 'EOF'
deb https://mirrors.ustc.edu.cn/debian/ trixie main contrib non-free non-free-firmware
deb https://mirrors.ustc.edu.cn/debian/ trixie-updates main contrib non-free non-free-firmware
deb https://mirrors.ustc.edu.cn/debian-security trixie-security main contrib non-free non-free-firmware
EOF

echo ">> Updating package lists..."
sudo apt update

# Install minimal packages
echo ">> Installing Labwc and essentials..."
sudo apt install -y labwc waybar swaybg foot fuzzel pcmanfm lxpolkit \
    xwayland grim slurp mako-notifier pipewire pipewire-pulse wireplumber \
    fonts-jetbrains-mono font-awesome swaylock swayidle

# Config directories
mkdir -p ~/.config/labwc ~/.config/waybar

# Environment
cat > ~/.config/labwc/environment << EOF
XDG_CURRENT_DESKTOP=labwc
XDG_SESSION_TYPE=wayland
MOZ_ENABLE_WAYLAND=1
QT_QPA_PLATFORM=wayland
GTK_BACKEND=wayland
EOF

# Autostart (minimal)
cat > ~/.config/labwc/autostart << EOF
#!/bin/sh
lxpolkit &
waybar &
mako &
swaybg -c "#2e3440" &
swayidle -w timeout 300 'swaylock -f -c 000000' &
EOF
chmod +x ~/.config/labwc/autostart

# Menu (minimal)
cat > ~/.config/labwc/menu.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu>
  <menu id="root-menu">
    <item label="Terminal"><action name="Execute" command="foot"/></item>
    <item label="Files"><action name="Execute" command="pcmanfm"/></item>
    <item label="Launcher"><action name="Execute" command="fuzzel"/></item>
    <separator/>
    <item label="Lock"><action name="Execute" command="swaylock -f -c 000000"/></item>
    <item label="Exit"><action name="Exit"/></item>
  </menu>
</openbox_menu>
EOF

# RC.xml (core keybinds)
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

# Waybar (simple with taskbar)
cat > ~/.config/waybar/config << EOF
{
    "layer": "top",
    "height": 30,
    "modules-left": ["wlr/taskbar"],
    "modules-center": ["clock"],
    "modules-right": ["cpu", "memory", "network", "pulseaudio", "tray"],
    "wlr/taskbar": {"format": "{icon}"},
    "clock": {"format-alt": "{:%Y-%m-%d %H:%M}"},
    "cpu": {"format": "{usage}% CPU"},
    "memory": {"format": "{used:0.1f}GiB RAM"},
    "network": {"format-wifi": "{essid} ({signalStrength}%)"},
    "pulseaudio": {"format": "{volume}% vol"}
}
EOF

cat > ~/.config/waybar/style.css << EOF
* { font-family: JetBrains Mono, FontAwesome; font-size: 13px; }
window#waybar { background: #2e3440; color: #ffffff; }
EOF

echo "-------------------------------------------------------"
echo ">> Installation Complete!"
echo ">> Backup: /etc/apt/sources.list.bak"
echo ">> Enable audio: systemctl --user enable --now pipewire pipewire-pulse wireplumber"
echo ">> Start: dbus-run-session labwc"
echo ">> Keybinds: Super+Enter (Term), Super+D (Launcher), Super+L (Lock)"
