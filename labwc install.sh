#!/bin/bash
# Labwc Installer for Debian 13 (Trixie) - TTY Optimized version (Improved)

set -e

# 1. Check Root
if [ "$(id -u)" -eq 0 ]; then
    echo "Please run as normal user (not root)."
    exit 1
fi

echo ">> Updating System..."
sudo apt update

echo ">> Installing Packages..."
# Core + extra useful packages
sudo apt install -y labwc waybar swaybg foot fuzzel pcmanfm lxpolkit \
    xwayland grim slurp mako-notifier wireplumber pipewire-pulse \
    fonts-jetbrains-mono otf-font-awesome swaylock swayidle curl

echo ">> Creating Configs..."
mkdir -p ~/.config/labwc ~/.config/waybar

# 2. Environment
cat > ~/.config/labwc/environment << EOF
XDG_CURRENT_DESKTOP=labwc
XDG_SESSION_TYPE=wayland
MOZ_ENABLE_WAYLAND=1
QT_QPA_PLATFORM=wayland
GTK_BACKEND=wayland
EOF

# 3. Autostart
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

# 4. Basic Menu (optional simple menu)
cat > ~/.config/labwc/menu.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu>
  <menu id="root-menu">
    <item label="Terminal"><action name="Execute" command="foot"/></item>
    <item label="File Manager"><action name="Execute" command="pcmanfm"/></item>
    <item label="Menu"><action name="Execute" command="fuzzel"/></item>
    <separator/>
    <item label="Exit"><action name="Exit"/></item>
  </menu>
</openbox_menu>
EOF

# 5. Keybinds and Config
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

# 6. Waybar (more useful modules)
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

echo ">> Installation Complete."
echo ">> To start from TTY: log in, then type 'labwc-session' or 'dbus-run-session labwc'"
echo ">> Lock screen: Super+L"
