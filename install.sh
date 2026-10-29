#!/usr/bin/env bash
# LOQer Multi-Distro Installation Script
# Installs LOQer binaries, Quickshell UI, bundled fonts, systemd services, shutdown hooks, and desktop integrations.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6 || echo "${HOME:-/home/$TARGET_USER}")"
USER_HOME="${USER_HOME:-${HOME:-/root}}"

REPO_UI="$SCRIPT_DIR/ui"
SYS_UI="${LOQER_SYSTEM_UI_DIR:-/usr/local/share/loqer/ui}"
QS_DIR="${LOQER_USER_CONFIG_DIR:-${XDG_CONFIG_HOME:-$USER_HOME/.config}/quickshell/ii}"

check_sync() {
    local drift=0
    echo "=== LOQer UI Synchronization Check ==="
    echo "Repo UI Source : $REPO_UI"
    echo "System Install : $SYS_UI"
    echo "User Quickshell: $QS_DIR"
    echo ""

    # 1. Check System Install (/usr/local/share/loqer/ui)
    echo "Checking System Install ($SYS_UI)..."
    if [ ! -d "$SYS_UI" ]; then
        echo "  [MISSING] System UI directory does not exist: $SYS_UI"
        drift=1
    else
        local sys_drift=0
        while IFS= read -r -d '' repo_file; do
            local rel="${repo_file#$REPO_UI/}"
            local sys_file="$SYS_UI/$rel"
            if [ ! -e "$sys_file" ]; then
                echo "  [MISSING] $rel (not found in $SYS_UI)"
                sys_drift=1
                drift=1
            elif [ ! -f "$sys_file" ]; then
                echo "  [TYPE MISMATCH] $rel is not a regular file in $SYS_UI"
                sys_drift=1
                drift=1
            elif ! cmp -s "$repo_file" "$sys_file"; then
                echo "  [DIFF] $rel differs between repo and system install"
                sys_drift=1
                drift=1
            fi
        done < <(find "$REPO_UI" -type f -print0)

        while IFS= read -r -d '' sys_file; do
            local rel="${sys_file#$SYS_UI/}"
            local repo_file="$REPO_UI/$rel"
            if [ ! -e "$repo_file" ]; then
                echo "  [EXTRA] $rel exists in system install but not in repo"
                sys_drift=1
                drift=1
            fi
        done < <(find "$SYS_UI" -type f -print0)

        if [ "$sys_drift" -eq 0 ]; then
            echo "  ✓ System install is completely synchronized."
        fi
    fi
    echo ""

    # 2. Check User Quickshell Config (~/.config/quickshell/ii)
    echo "Checking User Quickshell Config ($QS_DIR)..."
    if [ ! -d "$QS_DIR" ]; then
        echo "  [MISSING] Quickshell config directory does not exist: $QS_DIR"
        drift=1
    else
        local qs_drift=0
        local qs_loq="$QS_DIR/loqControl.qml"
        if [ ! -e "$qs_loq" ]; then
            echo "  [MISSING] loqControl.qml (not found in $QS_DIR)"
            qs_drift=1
            drift=1
        elif ! cmp -s "$REPO_UI/loqControl.qml" "$qs_loq"; then
            echo "  [DIFF] loqControl.qml differs between repo and user quickshell config"
            qs_drift=1
            drift=1
        else
            echo "  ✓ loqControl.qml in sync"
        fi

        if [ -f "$REPO_UI/fonts/GoogleSansFlex.ttf" ]; then
            local qs_font="$QS_DIR/fonts/GoogleSansFlex.ttf"
            if [ ! -e "$qs_font" ]; then
                echo "  [MISSING] fonts/GoogleSansFlex.ttf (not found in $QS_DIR)"
                qs_drift=1
                drift=1
            elif ! cmp -s "$REPO_UI/fonts/GoogleSansFlex.ttf" "$qs_font"; then
                echo "  [DIFF] fonts/GoogleSansFlex.ttf differs between repo and user quickshell config"
                qs_drift=1
                drift=1
            else
                echo "  ✓ fonts/GoogleSansFlex.ttf in sync"
            fi
        fi

        if [ -d "$QS_DIR/modules/ii/bar" ] && [ -f "$SCRIPT_DIR/assets/quickshell/LoqRingIcon.qml" ]; then
            local qs_bar_icon="$QS_DIR/modules/ii/bar/LoqRingIcon.qml"
            if [ ! -e "$qs_bar_icon" ]; then
                echo "  [MISSING] modules/ii/bar/LoqRingIcon.qml (not found in $QS_DIR)"
                qs_drift=1
                drift=1
            elif ! cmp -s "$SCRIPT_DIR/assets/quickshell/LoqRingIcon.qml" "$qs_bar_icon"; then
                echo "  [DIFF] modules/ii/bar/LoqRingIcon.qml differs from repo"
                qs_drift=1
                drift=1
            else
                echo "  ✓ modules/ii/bar/LoqRingIcon.qml in sync"
            fi
        fi

        if [ "$qs_drift" -eq 0 ]; then
            echo "  ✓ User quickshell integration is synchronized."
        fi
    fi
    echo ""

    if [ "$drift" -eq 0 ]; then
        echo "Result: All files are in sync. (status 0)"
        return 0
    else
        echo "Result: Sync drift detected! Run './install.sh' to synchronize. (status 1)"
        return 1
    fi
}

# Handle command-line flags before root verification
if [ "${1:-}" = "--check-sync" ]; then
    check_sync
    exit $?
fi

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    echo "Usage: $0 [--check-sync]"
    echo ""
    echo "Options:"
    echo "  --check-sync  Check synchronization between repo, system install, and user quickshell config."
    echo "  -h, --help    Show this help message."
    exit 0
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: install.sh must be run with sudo/root permissions (or use --check-sync to check status)." >&2
    exit 1
fi

echo "=== 1. Installing LOQer Core Binaries ==="
install -m 755 "$SCRIPT_DIR/bin/loqer" /usr/local/bin/loqer
install -m 755 "$SCRIPT_DIR/bin/loq-ctl" /usr/local/bin/loq-ctl
install -m 755 "$SCRIPT_DIR/bin/loq-hw-write" /usr/local/bin/loq-hw-write
install -m 755 "$SCRIPT_DIR/bin/loq-generate-icon" /usr/local/bin/loq-generate-icon
install -m 755 "$SCRIPT_DIR/bin/lenovo-power-daemon" /usr/local/bin/lenovo-power-daemon
install -m 755 "$SCRIPT_DIR/bin/set-panel-refresh" /usr/local/bin/set-panel-refresh
install -m 755 "$SCRIPT_DIR/bin/prime-run" /usr/local/bin/prime-run

mkdir -p "$USER_HOME/.local/bin"
install -m 755 "$SCRIPT_DIR/bin/loqer" "$USER_HOME/.local/bin/loqer"
install -m 755 "$SCRIPT_DIR/bin/set-panel-refresh" "$USER_HOME/.local/bin/set-panel-refresh"
install -m 755 "$SCRIPT_DIR/bin/prime-run" "$USER_HOME/.local/bin/prime-run"
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

echo "=== 7. Setting up Git Hooks ==="
if [ -d "$SCRIPT_DIR/.git" ] && [ -f "$SCRIPT_DIR/scripts/setup-git-hooks.sh" ]; then
    bash "$SCRIPT_DIR/scripts/setup-git-hooks.sh"
    if [ -n "${TARGET_USER:-}" ] && [ "$TARGET_USER" != "root" ]; then
        chown -R "$TARGET_USER:" "$SCRIPT_DIR/.git/hooks" 2>/dev/null || true
    fi
else
    echo "Not a git clone or setup-git-hooks.sh not found; skipping hooks setup."
fi

echo "=== Installation complete! ==="
echo "You can now run 'loqer' from terminal, application launcher, or via desktop shortcut."
