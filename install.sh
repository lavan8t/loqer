#!/usr/bin/env bash
# LOQer Multi-Distro Installation Script
# Installs LOQer binaries, Quickshell UI, bundled fonts, systemd services, shutdown hooks, and desktop integrations.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: install.sh must be run with sudo/root permissions." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6 || echo "/home/$TARGET_USER")"

echo "=== 1. Installing LOQer Core Binaries ==="
install -m 755 "$SCRIPT_DIR/bin/loqer" /usr/local/bin/loqer
install -m 755 "$SCRIPT_DIR/bin/loq-ctl" /usr/local/bin/loq-ctl
install -m 755 "$SCRIPT_DIR/bin/loq-hw-write" /usr/local/bin/loq-hw-write
install -m 755 "$SCRIPT_DIR/bin/loq-generate-icon" /usr/local/bin/loq-generate-icon
install -m 755 "$SCRIPT_DIR/bin/lenovo-power-daemon" /usr/local/bin/lenovo-power-daemon
install -m 755 "$SCRIPT_DIR/bin/set-panel-refresh" /usr/local/bin/set-panel-refresh

mkdir -p "$USER_HOME/.local/bin"
install -m 755 "$SCRIPT_DIR/bin/loqer" "$USER_HOME/.local/bin/loqer"
install -m 755 "$SCRIPT_DIR/bin/set-panel-refresh" "$USER_HOME/.local/bin/set-panel-refresh"
chown -R "$TARGET_USER:" "$USER_HOME/.local/bin"

echo "=== 2. Installing Quickshell Standalone UI & Bundled Fonts ==="
# System-wide UI files
mkdir -p /usr/local/share/loqer/ui
cp -r "$SCRIPT_DIR/ui/"* /usr/local/share/loqer/ui/

# User-space fallback paths
mkdir -p "$USER_HOME/.local/share/loqer/ui"
cp -r "$SCRIPT_DIR/ui/"* "$USER_HOME/.local/share/loqer/ui/"

# Quickshell legacy integration path
mkdir -p "$USER_HOME/.config/quickshell/ii/fonts"
install -m 644 "$SCRIPT_DIR/ui/loqControl.qml" "$USER_HOME/.config/quickshell/ii/loqControl.qml"
if [ -f "$SCRIPT_DIR/ui/fonts/GoogleSansFlex.ttf" ]; then
    install -m 644 "$SCRIPT_DIR/ui/fonts/GoogleSansFlex.ttf" "$USER_HOME/.config/quickshell/ii/fonts/GoogleSansFlex.ttf"
fi
if [ -d "$USER_HOME/.config/quickshell/ii/modules/ii/bar" ] && [ -f "$SCRIPT_DIR/assets/quickshell/LoqRingIcon.qml" ]; then
    install -m 644 "$SCRIPT_DIR/assets/quickshell/LoqRingIcon.qml" "$USER_HOME/.config/quickshell/ii/modules/ii/bar/LoqRingIcon.qml"
fi

# System font registration
mkdir -p /usr/local/share/fonts/loqer
if [ -f "$SCRIPT_DIR/ui/fonts/GoogleSansFlex.ttf" ]; then
    install -m 644 "$SCRIPT_DIR/ui/fonts/GoogleSansFlex.ttf" /usr/local/share/fonts/loqer/GoogleSansFlex.ttf
fi
if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f /usr/local/share/fonts/loqer >/dev/null 2>&1 || true
fi

chown -R "$TARGET_USER:" "$USER_HOME/.local/share/loqer" "$USER_HOME/.config/quickshell" 2>/dev/null || true

echo "=== 3. Installing Desktop Assets & Dynamic Icons ==="
mkdir -p /usr/local/share/applications "$USER_HOME/.local/share/applications"
install -m 644 "$SCRIPT_DIR/assets/loqer.desktop" /usr/local/share/applications/loqer.desktop
install -m 644 "$SCRIPT_DIR/assets/loqer.desktop" "$USER_HOME/.local/share/applications/loqer.desktop"

# Remove legacy/conflicting desktop files
rm -f "$USER_HOME/.local/share/applications/loq-control.desktop"
rm -f /usr/share/applications/loq-control.desktop

# Generate all hicolor icon resolutions
/usr/local/bin/loq-generate-icon balanced || true

echo "=== 4. Installing Systemd Services and Shutdown Hooks ==="
install -m 644 "$SCRIPT_DIR/systemd/lenovo-power.service" /etc/systemd/system/lenovo-power.service
install -m 644 "$SCRIPT_DIR/systemd/lenovo-fnq-custom.service" /etc/systemd/system/lenovo-fnq-custom.service

mkdir -p /usr/lib/systemd/system-shutdown
install -m 755 "$SCRIPT_DIR/systemd/nvidia-poweroff.shutdown" /usr/lib/systemd/system-shutdown/nvidia-poweroff.shutdown

echo "=== 5. Installing Dynamic Sudoers & Kernel Power Configurations ==="
cat <<EOF > /etc/sudoers.d/loqer
# Loqer Hardware Control Sudo Rules
${TARGET_USER} ALL=(ALL) NOPASSWD: /usr/local/bin/loqer
${TARGET_USER} ALL=(ALL) NOPASSWD: ${USER_HOME}/.local/bin/loqer
${TARGET_USER} ALL=(ALL) NOPASSWD: /usr/local/bin/loq-ctl
${TARGET_USER} ALL=(ALL) NOPASSWD: /usr/local/bin/loq-hw-write
${TARGET_USER} ALL=(ALL) NOPASSWD: /usr/local/bin/loq-generate-icon

Defaults!/usr/local/bin/loqer env_keep += "WAYLAND_DISPLAY XDG_RUNTIME_DIR DISPLAY XAUTHORITY XDG_SESSION_TYPE"
Defaults!${USER_HOME}/.local/bin/loqer env_keep += "WAYLAND_DISPLAY XDG_RUNTIME_DIR DISPLAY XAUTHORITY XDG_SESSION_TYPE"
EOF
chmod 440 /etc/sudoers.d/loqer

mkdir -p /etc/systemd/logind.conf.d
install -m 644 "$SCRIPT_DIR/configs/99-lid-ignore.conf" /etc/systemd/logind.conf.d/99-lid-ignore.conf

mkdir -p /etc/modprobe.d
install -m 644 "$SCRIPT_DIR/configs/nvidia-power-management.conf" /etc/modprobe.d/nvidia-power-management.conf

echo "=== 6. Activating Services ==="
systemctl daemon-reload
systemctl enable --now lenovo-power.service || true
systemctl enable --now lenovo-fnq-custom.service || true

echo "=== Installation complete! ==="
echo "You can now run 'loqer' from terminal, application launcher, or via desktop shortcut."
