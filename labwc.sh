#!/bin/bash

# Labwc Wayland Compositor Setup Script
# This script automates the installation and configuration of Labwc

set -e  # Exit on error

echo "=================================="
echo "Labwc Setup Script"
echo "=================================="

# ==================== 1. Mirror Source Configuration ====================
echo ""
echo "[1/6] Configuring APT mirror source..."

# Backup original sources.list
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
echo "✓ Backup created at /etc/apt/sources.list.bak"

# Configure USTC mirror
sudo tee /etc/apt/sources.list << 'EOF'
deb https://mirrors.ustc.edu.cn/debian/ trixie main
deb https://mirrors.ustc.edu.cn/debian/ trixie-updates main
deb https://mirrors.ustc.edu.cn/debian-security trixie-security main
EOF

# Update package list
sudo apt update
echo "✓ Mirror source configured and updated"

# ==================== 2. Package Installation ====================
echo ""
echo "[2/6] Installing required packages..."

sudo apt install -y labwc waybar foot fuzzel thunar swaybg lxpolkit mako-notifier brightnessctl pavucontrol nm-tray qt6-wayland xdg-desktop-portal-wlr xwayland \
grim slurp wl-clipboard swaylock cliphist \
fonts-noto-cjk fonts-font-awesome fcitx5 fcitx5-chinese-addons \
flatpak adb fastboot

echo "✓ All packages installed successfully"

# ==================== 3. Basic Configuration ====================
echo ""
echo "[3/6] Setting up basic configuration..."

mkdir -p ~/.config/labwc && cp -r /usr/share/doc/labwc/examples/* ~/.config/labwc/ || echo "示例文件未找到,请检查安装"
echo "✓ Configuration directory created"

# ==================== 4. Autostart Configuration ====================
echo ""
echo "[4/6] Creating autostart script..."

cat > ~/.config/labwc/autostart << 'EOF'
#!/bin/sh

# Update environment variables
dbus-update-activation-environment --systemd --all || echo "D-Bus 更新失败" >> ~/autostart.log

# Start services
lxpolkit &
swaybg -c "#080200" &
fcitx5 -d --replace &  
mako &
nm-tray &
waybar &

# Clipboard manager
wl-paste --watch cliphist store & 

# Portal (optional, comment out if working automatically)
# /usr/libexec/xdg-desktop-portal-wlr &
# sleep 1
# /usr/libexec/xdg-desktop-portal &
EOF

# Set execute permission and add user to video group
chmod +x ~/.config/labwc/autostart
sudo usermod -aG video $USER
echo "✓ Autostart script created and configured"

# ==================== 5. Right-click Menu Configuration ====================
echo ""
echo "[5/6] Creating right-click menu..."

cat > ~/.config/labwc/menu.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu>

  <menu id="system" label="系统">
    <item label="重启 WM">
      <action name="Execute">
        <command>/bin/sh -c 'labwc-msg exit || killall labwc'</command>
      </action>
    </item>
    <item label="注销">
      <action name="Execute">
        <command>/bin/sh -c 'loginctl terminate-session "$XDG_SESSION_ID"'</command>
      </action>
    </item>
    <item label="关机">
      <action name="Execute">
        <command>/bin/sh -c 'systemctl poweroff'</command>
      </action>
    </item>
    <item label="重启">
      <action name="Execute">
        <command>/bin/sh -c 'systemctl reboot'</command>
      </action>
    </item>
  </menu>

  <menu id="apps" label="应用">
    <item label="终端 (Foot)">
      <action name="Execute"><command>/usr/bin/foot</command></action>
    </item>
    <item label="文件管理器（Thunar）">
      <action name="Execute"><command>/usr/bin/thunar</command></action>
    </item>
    <item label="网络设置 (nm-tray)">
      <action name="Execute"><command>/usr/bin/nm-tray</command></action>
    </item>
    <item label="音量控制 (pavucontrol)">
      <action name="Execute"><command>/usr/bin/pavucontrol</command></action>
    </item>
  </menu>

  <menu id="tools" label="工具">
    <item label="Launcher (Fuzzel)">
      <action name="Execute"><command>/usr/bin/fuzzel</command></action>
    </item>
    <item label="截图 (slurp + grim)">
      <action name="Execute">
        <command>/bin/sh -c 'mkdir -p ~/Pictures && slurp | grim ~/Pictures/screenshot-$(date -u +%Y%m%dT%H%M%SZ).png && notify-send "Screenshot saved"'</command>
      </action>
    </item>
  </menu>

  <item label="退出 Labwc">
    <action name="Execute">
      <command>/bin/sh -c 'labwc-msg exit || killall labwc'</command>
    </action>
  </item>

</openbox_menu>
EOF

echo "✓ Right-click menu configured"

# ==================== 6. Environment Variables ====================
echo ""
echo "[6/6] Setting up environment variables..."

cat > ~/.config/labwc/environment << 'EOF'
# Input method
export GTK_IM_MODULE=fcitx5
export QT_IM_MODULE=fcitx5
export XMODIFIERS="@im=fcitx5"
export SDL_IM_MODULE=fcitx5
#某些应用可能需要这个 export GLFW_IM_MODULE=ibus


# Desktop identification
export XDG_CURRENT_DESKTOP=labwc
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=labwc

# Force applications to use Wayland
export GDK_BACKEND=wayland,x11
export QT_QPA_PLATFORM="wayland;xcb"
export MOZ_ENABLE_WAYLAND=1  # Firefox 原生 Wayland
export _JAVA_AWT_WM_NONREPARENTING=1 # 修复 Java 应用显示问题
EOF

echo "✓ Environment variables configured"

# ==================== 7. Keyboard Shortcuts Configuration ====================
echo ""
echo "[7/7] Creating keyboard shortcuts configuration..."

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
      <action name="Execute" command="foot"/>
    </keybind>

    <!-- Launch Launcher -->
    <keybind key="W-d">
      <action name="Execute" command="fuzzel"/>
    </keybind>

    <!-- Lock screen (requires swaylock or swaylock-effects) -->
    <keybind key="W-l">
      <action name="Execute" command="swaylock -c 000000"/>
    </keybind>

    <!-- Close current window -->
    <keybind key="A-F4">
      <action name="Close"/>
    </keybind>

    <!-- Maximize/Unmaximize -->
    <keybind key="W-a">
      <action name="ToggleMaximize"/>
    </keybind>

    <!-- Fullscreen -->
    <keybind key="W-f">
      <action name="ToggleFullscreen"/>
    </keybind>

    <!-- Workspace switching -->
    <keybind key="W-1"><action name="GoToDesktop" to="1"/></keybind>
    <keybind key="W-2"><action name="GoToDesktop" to="2"/></keybind>
    <keybind key="W-3"><action name="GoToDesktop" to="3"/></keybind>
    <keybind key="W-4"><action name="GoToDesktop" to="4"/></keybind>

    <!-- Volume control -->
    <keybind key="XF86_AudioLowerVolume">
      <action name="Execute" command="pactl set-sink-volume @DEFAULT_SINK@ -5%"/>
    </keybind>
    <keybind key="XF86_AudioRaiseVolume">
      <action name="Execute" command="pactl set-sink-volume @DEFAULT_SINK@ +5%"/>
    </keybind>
    <keybind key="XF86_AudioMute">
      <action name="Execute" command="pactl set-sink-mute @DEFAULT_SINK@ toggle"/>
    </keybind>

    <!-- Brightness control -->
    <keybind key="XF86_MonBrightnessDown">
      <action name="Execute" command="brightnessctl set 10%-"/>
    </keybind>
    <keybind key="XF86_MonBrightnessUp">
      <action name="Execute" command="brightnessctl set +10%"/>
    </keybind>

    <!-- Screenshot: select area -->
    <keybind key="Print">
      <action name="Execute" command="sh -c 'mkdir -p ~/Pictures &amp;&amp; slurp | grim ~/Pictures/screenshot-$(date +%s).png'"/>
    </keybind>

    <!-- Fullscreen screenshot -->
    <keybind key="W-Print">
      <action name="Execute" command="sh -c 'mkdir -p ~/Pictures &amp;&amp; grim ~/Pictures/screenshot-$(date +%s).png'"/>
    </keybind>
  </keyboard>

  <mousebind button="Left" action="Drag">
    <action name="Move"/>
  </mousebind>

  <mousebind button="Right" action="Drag">
    <action name="Resize"/>
  </mousebind>

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

echo "✓ Keyboard shortcuts configured"

# ==================== Completion ====================
echo ""
echo "=================================="
echo "✓ Setup completed successfully!"
echo "=================================="
echo ""
echo "Next steps:"
echo "1. Log out and select 'Labwc' from your display manager"
echo "2. Or reboot your system"
echo ""
echo "Note: You've been added to the 'video' group."
echo "You may need to log out and back in for this to take effect."
echo ""
echo "Useful keyboard shortcuts:"
echo "  Win+Return    - Open terminal"
echo "  Win+D         - Open launcher"
echo "  Win+L         - Lock screen"
echo "  Win+A         - Toggle maximize"
echo "  Win+F         - Toggle fullscreen"
echo "  Win+1/2/3/4   - Switch workspaces"
echo "  Print         - Screenshot (select area)"
echo "  Win+Print     - Screenshot (fullscreen)"
echo ""
