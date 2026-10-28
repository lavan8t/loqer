<p align="center">
  <img src="assets/loqer.svg" width="128" height="128" alt="LOQer logo">
</p>

# LOQer

[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Windows%20x64-blue.svg)](https://github.com/lavan8t/loqer)
[![UI](https://img.shields.io/badge/ui-Material%203%20QML-6750A4.svg)](https://github.com/lavan8t/loqer)
[![CI/CD](https://github.com/lavan8t/loqer/actions/workflows/ci.yml/badge.svg)](https://github.com/lavan8t/loqer/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

LOQer manages power profiles, fan curves, GPU display routing, and battery thresholds on Lenovo LOQ 15IAX9 and Legion laptops running Linux and Windows.

On Linux, the project pairs a background daemon with a standalone Quickshell desktop window and a command-line tool named `loq-ctl`. On Windows, a minified native C++ Qt host embeds the exact 1:1 Material 3 frontend and Google Sans Flex variable font with zero rewrite, interfacing directly with Lenovo ACPI WMI and Win32 firmware APIs under the hood.

## Features

### Power profiles and Fn+Q

The daemon synchronizes system power targets with the physical Fn+Q hotkey using EC CMOS register `0x7A`. It switches across four states:

- Quiet: 45W cTGP, 15W PPAB, low fan speeds.
- Balanced: 60W cTGP, 20W PPAB, dynamic fan curve.
- Performance: 105W cTGP, 25W PPAB (130W total GPU limit), aggressive fan curve.
- Custom: 105W cTGP, 25W PPAB, unlocked fan controller, full fan speed support.

### GPU MUX switch

The `igpumode` sysfs interface switches display wiring:

- Dedicated (0): routes the internal display directly to the NVIDIA RTX GPU.
- iGPU (1): forces the integrated Intel graphics.
- Hybrid (2): enables runtime power management (D3cold) for the NVIDIA card.

### Fan curves

The daemon writes directly to the `legion_hwmon` sysfs attributes `pwm1_auto_point1_temp` through `pwm2_auto_point10_pwm`.

- Supports 10 temperature and PWM steps for the CPU and GPU fans.
- Ships presets for quiet, balanced, performance, and maximum cooling.
- Reverts control to the embedded controller with the auto preset.

### UEFI Boot Logo Changer

LOQer supports Lenovo's native InsydeH2O UEFI DIY Boot Logo mechanism (as supported on LOQ 15IAX9 and Legion models):
- Auto-fits, centers, and pads images onto the display canvas (up to 1920x1080).
- Validates formats (PNG, JPG, BMP) and firmware buffer limits (under 1.5MB).
- Updates UEFI variables `LBLDESP` and `LBLDVC` (SHA256 / CRC32 integrity checksums) via kernel efivars.
- Reverts cleanly to the factory OEM Lenovo boot splash with one click or command.

### Hardware controls

- Battery conservation: caps charge at 80% via `/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode`.
- Fn lock: toggles function key behavior in hardware.
- Input locks: enables or disables the touchpad and Windows key.
- Display: toggles panel overdrive and switches internal panel refresh rate (60Hz / 144Hz) across Hyprland, KDE Plasma, Sway/wlroots, and X11.
- Power limits: sets Intel RAPL PL1 and PL2 limits alongside GPU cTGP and PPAB targets.
- Typography: bundled Google Sans Flex variable font with tuned width (`wdth: 98-104`) and weight axes for Material 3 metrics and headers.

## Repository structure

```
loqer/
├── bin/
│   ├── lenovo-power-daemon    # Background ACPI and sysfs sync daemon
│   ├── loq-ctl                # Hardware control CLI
│   ├── loq-generate-icon      # LOQ ring SVG and PNG generator
│   ├── loq-hw-write           # Sudo helper for sysfs writes
│   ├── loqer                  # Launcher for the Quickshell GUI
│   └── set-panel-refresh      # Multi-DE internal panel refresh rate script
├── ui/
│   ├── loqControl.qml         # Standalone Material 3 desktop window
│   ├── modules/               # Bundled Quickshell Material 3 component library
│   ├── services/              # Bundled MaterialThemeLoader service
│   └── fonts/                 # Bundled Google Sans Flex variable font
├── assets/
│   ├── loqer.desktop          # Application launcher entry
│   └── loqer.svg              # Ring emblem vector graphic
├── systemd/
│   ├── lenovo-fnq-custom.service # Restores CMOS 0x7A across reboots
│   ├── lenovo-power.service   # Runs lenovo-power-daemon as a system service
│   └── nvidia-poweroff.shutdown # Wakes GPU to D0 during shutdown to prevent lockups
├── configs/
│   ├── 99-lid-ignore.conf     # Ignores laptop lid close events
│   ├── hyprland-loqer.lua     # Window floating and sizing rules
│   ├── loqer-sudoers          # Passwordless sudo rules for hardware writes
│   └── nvidia-power-management.conf # Dynamic power management options
├── install.sh                 # Deployment script
├── uninstall.sh               # Removal script
└── LICENSE
```

## Installation

### Requirements

- A Lenovo LOQ or Legion laptop.
- Linux kernel with `legion_laptop` and `ideapad_acpi` drivers.
- `quickshell` and `imagemagick` packages.
- Root / sudo access.

### One-liner (Release Archive)

Download the release archive and run the installer:

```bash
curl -fsSL https://github.com/lavan8t/loqer/releases/latest/download/loqer-v1.0.0.tar.gz | tar -xz && cd loqer && sudo ./install.sh
```

### Git Clone

```bash
git clone https://github.com/lavan8t/loqer.git
cd loqer
sudo ./install.sh
```

The installer configures `/usr/local/bin`, installs the standalone UI and bundled Google Sans Flex font, configures sudo permissions for hardware writes, registers systemd units, and generates desktop application icons.

## CLI usage

`loq-ctl` handles hardware operations from the shell:

```bash
# Power profiles
loq-ctl profile quiet
loq-ctl profile balanced
loq-ctl profile performance
loq-ctl profile custom

# Display routing (MUX)
loq-ctl mux hybrid
loq-ctl mux dedicated
loq-ctl mux igpu

# Hardware toggles
loq-ctl conservation 1
loq-ctl fn_lock toggle
loq-ctl touchpad 1
loq-ctl refresh 144

# Fan curve presets and manual steps
loq-ctl fancurve preset balanced
loq-ctl fancurve get
loq-ctl fancurve set 5 70 80 85

# Power envelopes (PL1, PL2, cTGP, PPAB in watts)
loq-ctl powerlimits 65 125 105 25

# UEFI Boot Logo management
loq-ctl bootlogo status
loq-ctl bootlogo set /path/to/custom_logo.png
loq-ctl bootlogo reset

# Read telemetry JSON
loq-ctl status
```

## Windows Native Host & Cross-Compilation

LOQer provides a native C++ Windows host (`windows/`) that embeds the exact 1:1 Material 3 QML frontend and variable font into a minified, standalone Windows executable (`loqer.exe`).

### Building on Fedora (MinGW Cross-Compilation)

You can compile the Windows binary and package a portable release zip directly on Fedora:

```bash
# 1. Install toolchain dependencies
sudo dnf install -y mingw64-gcc-c++ mingw64-filesystem mingw64-qt6-qtbase \
                    mingw64-qt6-qtdeclarative mingw64-qt6-qt5compat \
                    mingw64-qt6-qtshadertools mingw64-qt6-qtsvg upx cmake make

# 2. Build and package
./build-windows.sh
```

The script compiles the native binary with aggressive dead-code elimination, strips symbols, and packages all runtime DLLs and platform plugins into:
- `dist/loqer-windows-x64.zip` (standalone portable distribution)
- `loqer.exe` (~2.5 MB compressed native executable)

### Under the Hood on Windows

- **Power Modes & Conservation**: Dispatched natively to Lenovo ACPI WMI classes (`root\wmi` -> `Lenovo_BiosSetting`, `Lenovo_GameZone`).
- **Telemetry**: Live AC power and battery telemetry queried via Win32 `GetSystemPowerStatus`.
- **UEFI Boot Logo**: Uses Win32 `GetFirmwareEnvironmentVariableExW` and `SetFirmwareEnvironmentVariableExW` with Lenovo GUID `{782163fe-78e8-466d-978a-0a7b427b03b3}` and automatically mounts the ESP to stage the splash image.

## CI/CD Automation

The repository includes a GitHub Actions workflow (`.github/workflows/ci.yml`) that runs on every push and pull request:
- **Linux Distribution**: Packages `loqer-linux-x64.tar.gz` with complete daemon, CLI, and systemd units.
- **Windows Distribution**: Cross-compiles `loqer.exe` inside a Fedora container and produces `loqer-windows-x64.zip`.
- **Automated Releases**: On tagged commits (`v*`), both Linux and Windows release archives are automatically attached to the GitHub release.

## License

MIT
