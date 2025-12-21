#!/bin/bash

# Labwc Wayland Compositor Setup Script
# This script automates the installation and configuration of Labwc

set -e

echo "=================================="
echo "Labwc Setup Script"
echo "=================================="

# Part 1: Installation
echo ""
echo "[1/6] Configuring mirror sources..."

# Backup sources.list
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak

# Configure mirror sources
sudo tee /etc/apt/sources.list << 'EOF'
deb https://mirrors.ustc.edu.cn/debian/ trixie main
deb https://mirrors.ustc.edu.cn/debian/ trixie-updates main
deb https://mirrors.ustc.edu.cn/debian-security trixie-security main
EOF

# Update package list
echo ""
echo "[2/6] Updating package list..."
sudo apt update

# Install packages
echo ""
echo "[3/6] Installing packages..."
sudo apt install -y labwc waybar foot fuzzel thunar swaybg lxpolkit mako-notifier brightnessctl pavucontrol nm-tray qt6-wayland xdg-desktop-portal-wlr xwayland \
grim slurp wl-clipboard swaylock cliphist \
fonts-noto-cjk fonts-font-awesome fcitx5 fcitx5-chinese-addons \
libnotify-bin network-manager-gnome curl wget git \
flatpak adb fastboot

# Part 2: Configuration
echo ""
echo "[4/6] Setting up configuration directories..."

# Create config directory and copy examples
mkdir -p ~/.config/labwc && cp -r /usr/share/doc/labwc/examples/* ~/.config/labwc/ || echo "No example files found, please check installation"

# Configure autostart
echo ""
echo "[5/6] Configuring autostart..."
cat > ~/.config/labwc/autostart <<'EOF'
#!/bin/sh

LOG="$HOME/.local/state/labwc-autostart.log"
mkdir -p "$(dirname "$LOG")"
exec >>"$LOG" 2>&1

# import environment vars into systemd user environment
dbus-update-activation-environment --systemd --all || echo "Failed to update env for systemd"

# ---- PolicyKit Agent ----
# If you have policykit-1-gnome installed, this session can display authentication dialogs
if [ -x /usr/lib/polkit-1-gnome/polkit-gnome-authentication-agent-1 ]; then
  /usr/lib/polkit-1-gnome/polkit-gnome-authentication-agent-1 &
fi


swaybg -c "#2E3440" &
fcitx5 -d --replace &
mako &
nm-tray &
waybar &
wl-paste --watch cliphist store &

# ---- xdg-desktop-portal ----
# /usr/lib/xdg-desktop-portal &
echo "autostart finished at $(date)"
EOF

chmod +x ~/.config/labwc/autostart

# Fix video group issue
echo ""
echo "Adding user to video group..."
sudo usermod -aG video $USER

# Configure right-click menu
echo ""
echo "Configuring right-click menu..."
cat > ~/.config/labwc/menu.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu>
  <menu id="apps" label="Applications">
    <item label="Terminal (Foot)">
      <action name="Execute"><command>foot</command></action>
    </item>
    <item label="Files (Thunar)">
      <action name="Execute"><command>thunar</command></action>
    </item>
  </menu>

  <menu id="system" label="System">
    <item label="Network (nm-tray)">
      <action name="Execute"><command>nm-tray</command></action>
    </item>
    <item label="Volume (pavucontrol)">
      <action name="Execute"><command>pavucontrol</command></action>
    </item>
    <separator />
    <item label="Screenshot (area)">
      <action name="Execute">
        <command>sh -c 'mkdir -p ~/Pictures && grim -g "$(slurp)" ~/Pictures/$(date +%s).png && notify-send "Screenshot saved" || notify-send "Screenshot failed"'</command>
      </action>
    </item>
    
    <separator />
    
    <menu id="power" label="Power">
      <item label="Lock Screen">
        <action name="Execute"><command>swaylock -c 000000</command></action>
      </item>
      <item label="Exit Labwc">
        <action name="Exit" />
      </item>
      <item label="Reboot">
        <action name="Execute"><command>systemctl reboot</command></action>
      </item>
      <item label="Shutdown">
        <action name="Execute"><command>systemctl poweroff</command></action>
      </item>
    </menu>
  </menu>

</openbox_menu>
EOF

# Configure environment variables
echo ""
echo "Configuring environment variables..."
cat > ~/.config/labwc/environment << 'EOF'
# ---- Input Method: Fcitx5 ----
export GTK_IM_MODULE=fcitx5
export QT_IM_MODULE=fcitx5
export XMODIFIERS="@im=fcitx"

# other IM modules (optional)
export SDL_IM_MODULE=fcitx5

# ---- Desktop / Wayland session ----
export XDG_CURRENT_DESKTOP=labwc
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=labwc

# toolkit backends (Wayland first, fallback to X11)
export GDK_BACKEND=wayland,x11
export QT_QPA_PLATFORM=wayland

# Firefox Wayland support
export MOZ_ENABLE_WAYLAND=1

# Java AWT nonreparenting workaround
export _JAVA_AWT_WM_NONREPARENTING=1
EOF

# Configure keybindings
echo ""
echo "[6/6] Configuring keybindings..."
cat > ~/.config/labwc/rc.xml << 'EOF'
<?xml version="1.0"?>
<labwc_config>

  <!-- Workspace count -->
  <desktops number="4"/>

  <!-- Theme (optional) -->
  <theme>
    <cornerRadius>6</cornerRadius>
    <titlebar>
      <layout>icon:iconify,max,close</layout>
      <showTitle>yes</showTitle>
    </titlebar>
  </theme>

  <placement>
    <policy>Cascade</policy>
    <cascadeOffset x="30" y="20"/>
  </placement>

  <keyboard>
    <!-- Keep default shortcuts -->
    <default/>

    <!-- Launch terminal -->
    <keybind key="W-Return">
      <action name="Execute">
        <command>foot</command>
      </action>
    </keybind>

    <!-- Launch Launcher -->
    <keybind key="W-d">
      <action name="Execute">
        <command>fuzzel</command>
      </action>
    </keybind>

    <!-- Lock screen (requires swaylock or swaylock-effects) -->
    <keybind key="W-l">
      <action name="Execute">
        <command>swaylock -c 000000</command>
      </action>
    </keybind>

    <!-- Close current window -->
    <keybind key="A-F4">
      <action name="Close"/>
    </keybind>

    <!-- Maximize/Unmaximize -->
    <keybind key="W-a">
      <action name="ToggleMaximize"/>
    </action>
    </keybind>

    <!-- Fullscreen -->
    <keybind key="W-f">
      <action name="ToggleFullscreen"/>
    </keybind>

    <!-- Workspace switching -->
    <keybind key="W-1"><action name="GoToDesktop"><to>1</to></action></keybind>
    <keybind key="W-2"><action name="GoToDesktop"><to>2</to></action></keybind>
    <keybind key="W-3"><action name="GoToDesktop"><to>3</to></action></keybind>
    <keybind key="W-4"><action name="GoToDesktop"><to>4</to></action></keybind>

    <!-- Volume control -->
    <keybind key="XF86_AudioLowerVolume">
      <action name="Execute">
        <command>pactl set-sink-volume @DEFAULT_SINK@ -5%</command>
      </action>
    </keybind>
    <keybind key="XF86_AudioRaiseVolume">
      <action name="Execute">
        <command>pactl set-sink-volume @DEFAULT_SINK@ +5%</command>
      </action>
    </keybind>
    <keybind key="XF86_AudioMute">
      <action name="Execute">
        <command>pactl set-sink-mute @DEFAULT_SINK@ toggle</command>
      </action>
    </keybind>

    <!-- Brightness control -->
    <keybind key="XF86_MonBrightnessDown">
      <action name="Execute">
        <command>brightnessctl set 10%-</command>
      </action>
    </keybind>
    <keybind key="XF86_MonBrightnessUp">
      <action name="Execute">
        <command>brightnessctl set +10%</command>
      </action>
    </keybind>

    <!-- Screenshot: select area -->
    <keybind key="Print">
      <action name="Execute">
        <command>sh -c 'mkdir -p ~/Pictures &amp;&amp; slurp | grim ~/Pictures/screenshot-$(date +%s).png'</command>
      </action>
    </keybind>

    <!-- Fullscreen screenshot -->
    <keybind key="W-Print">
      <action name="Execute">
        <command>sh -c 'mkdir -p ~/Pictures &amp;&amp; grim ~/Pictures/screenshot-$(date +%s).png'</command>
      </action>
    </keybind>
  </keyboard>

  <mouse>
    <context name="Frame">
      <mousebind button="Left" action="Drag">
        <action name="Move"/>
      </mousebind>
      <mousebind button="Right" action="Drag">
        <action name="Resize"/>
      </mousebind>
    </context>

    <context name="Root">
      <mousebind button="Right" action="Press">
        <action name="ShowMenu"/>
      </mousebind>
    </context>
  </mouse>

  <windowRules>
    <!-- Notifications don't appear in taskbar -->
    <windowRule matchClass="Mako-Notifier">
      <skipTaskbar>yes</skipTaskbar>
      <skipWindowSwitcher>yes</skipWindowSwitcher>
    </windowRule>

    <!-- Dialogs are floating -->
    <windowRule matchRole="dialog">
      <floating>yes</floating>
    </windowRule>

    <!-- Specific programs floating -->
    <windowRule matchClass="Gnome-calculator">
      <floating>yes</floating>
    </windowRule>
  </windowRules>

</labwc_config>
EOF

echo ""
echo "=================================="
echo "Setup completed successfully!"
echo "=================================="
echo ""
echo "IMPORTANT: Please log out and log back in for group changes to take effect."
echo "You can start Labwc by selecting it from your display manager."
echo ""
