#!/usr/bin/env bash
# LOQer Uninstallation Script
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: uninstall.sh must be run with sudo/root permissions." >&2
    exit 1
fi

TARGET_USER="${SUDO_USER:-lavan}"
USER_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

echo "=== Stopping and disabling services ==="
systemctl disable --now lenovo-power.service 2>/dev/null || true
systemctl disable --now lenovo-fnq-custom.service 2>/dev/null || true

rm -f /etc/systemd/system/lenovo-power.service
rm -f /etc/systemd/system/lenovo-fnq-custom.service
rm -f /usr/lib/systemd/system-shutdown/nvidia-poweroff.shutdown
rm -f /etc/sudoers.d/loqer

systemctl daemon-reload

echo "=== Removing installed binaries ==="
rm -f /usr/local/bin/loqer
rm -f /usr/local/bin/loq-ctl
rm -f /usr/local/bin/loq-hw-write
rm -f /usr/local/bin/loq-generate-icon
rm -f /usr/local/bin/lenovo-power-daemon
rm -f "$USER_HOME/.local/bin/loqer"

echo "=== Removing desktop entries and icons ==="
rm -f "$USER_HOME/.local/share/applications/loqer.desktop"
find "$USER_HOME/.local/share/icons/hicolor" -name "loqer.*" -delete 2>/dev/null || true

su - "$TARGET_USER" -c "update-desktop-database $USER_HOME/.local/share/applications/ 2>/dev/null || true"

echo "=== LOQer uninstalled successfully ==="
