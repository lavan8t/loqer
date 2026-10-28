#!/usr/bin/env bash
# Loqer Installation Script
# Installs Loqer binaries, Quickshell UI, systemd daemons, shutdown hooks, and desktop integrations.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: install.sh must be run with sudo/root permissions." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${SUDO_USER:-lavan}"
USER_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

echo "=== 1. Installing Loqer Core Binaries ==="
install -m 755 "$SCRIPT_DIR/bin/loqer" /usr/local/bin/loqer
install -m 755 "$SCRIPT_DIR/bin/loq-ctl" /usr/local/bin/loq-ctl
install -m 755 "$SCRIPT_DIR/bin/loq-hw-write" /usr/local/bin/loq-hw-write
install -m 755 "$SCRIPT_DIR/bin/loq-generate-icon" /usr/local/bin/loq-generate-icon
install -m 755 "$SCRIPT_DIR/bin/lenovo-power-daemon" /usr/local/bin/lenovo-power-daemon

mkdir -p "$USER_HOME/.local/bin"
install -m 755 "$SCRIPT_DIR/bin/loqer" "$USER_HOME/.local/bin/loqer"
install -m 755 "$SCRIPT_DIR/bin/set-panel-refresh" "$USER_HOME/.local/bin/set-panel-refresh"

echo "=== 2. Installing Quickshell Material 3 UI ==="
mkdir -p "$USER_HOME/.config/quickshell/ii"
install -m 644 "$SCRIPT_DIR/ui/loqControl.qml" "$USER_HOME/.config/quickshell/ii/loqControl.qml"

echo "=== 3. Installing Desktop Assets & Dynamic Icons ==="
mkdir -p "$USER_HOME/.local/share/applications"
install -m 644 "$SCRIPT_DIR/assets/loqer.desktop" "$USER_HOME/.local/share/applications/loqer.desktop"

# Remove legacy/conflicting desktop files
rm -f "$USER_HOME/.local/share/applications/loq-control.desktop"
rm -f /usr/share/applications/loq-control.desktop

# Generate all hicolor icon resolutions
/usr/local/bin/loq-generate-icon balanced

echo "=== 4. Installing Systemd Services and Shutdown Hooks ==="
install -m 644 "$SCRIPT_DIR/systemd/lenovo-power.service" /etc/systemd/system/lenovo-power.service
install -m 644 "$SCRIPT_DIR/systemd/lenovo-fnq-custom.service" /etc/systemd/system/lenovo-fnq-custom.service

mkdir -p /usr/lib/systemd/system-shutdown
install -m 755 "$SCRIPT_DIR/systemd/nvidia-poweroff.shutdown" /usr/lib/systemd/system-shutdown/nvidia-poweroff.shutdown

echo "=== 5. Installing Sudoers & Kernel Power Configurations ==="
install -m 440 "$SCRIPT_DIR/configs/loqer-sudoers" /etc/sudoers.d/loqer

mkdir -p /etc/systemd/logind.conf.d
install -m 644 "$SCRIPT_DIR/configs/99-lid-ignore.conf" /etc/systemd/logind.conf.d/99-lid-ignore.conf

mkdir -p /etc/modprobe.d
install -m 644 "$SCRIPT_DIR/configs/nvidia-power-management.conf" /etc/modprobe.d/nvidia-power-management.conf

echo "=== 6. Activating Services ==="
systemctl daemon-reload
systemctl enable --now lenovo-power.service
systemctl enable --now lenovo-fnq-custom.service
systemctl kill -s HUP systemd-logind.service || true

# Update desktop and icon databases
su - "$TARGET_USER" -c "update-desktop-database $USER_HOME/.local/share/applications/ 2>/dev/null || true"
su - "$TARGET_USER" -c "gtk-update-icon-cache -f -t $USER_HOME/.local/share/icons/hicolor/ 2>/dev/null || true"

echo "=== Loqer installed successfully! ==="
