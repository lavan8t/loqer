"""
Hardware Mock Environment for LOQer test suite.
Provides deterministic mocking of sysfs nodes, platform profiles, hwmon telemetry,
power supply, PCI runtime status, and status JSON files.
"""

import os
import sys
import json
import tempfile
import subprocess

DEFAULT_STATUS = {
    "profile": "balanced",
    "is_saver": False,
    "ac_online": True,
    "pl1_w": 55,
    "pl2_w": 115,
    "turbo": True,
    "epp": "balance_performance",
    "gpu_status": "active",
    "gpu_usage": 0,
    "gpu_power_w": 0,
    "display_hz": 144,
    "igpu_mode": 2,
    "fan1_rpm": 2400,
    "fan2_rpm": 2500,
    "cpu_temp": 45,
    "gpu_temp": 40,
    "fan_fullspeed": False,
    "conservation_mode": False,
    "fn_lock": False,
    "touchpad": True,
    "winkey": True,
    "overdrive": False,
    "gpu_ctgp_w": 105,
    "gpu_ppab_w": 25,
    "gpu_total_w": 130,
    "lockfancontroller": False,
    "kbd_backlight": 1,
    "ioport_light": True,
    "battery_capacity": 80,
    "battery_status": "Discharging",
    "battery_health": 100.0,
    "battery_cycles": 15,
    "battery_wh_full": 60.0,
    "battery_wh_design": 60.0,
    "bootlogo_enabled": False
}

BALANCED_FAN_CURVE = [
    {"step": 1, "temp": 45, "pwm1": 20, "pwm2": 25},
    {"step": 2, "temp": 52, "pwm1": 30, "pwm2": 35},
    {"step": 3, "temp": 58, "pwm1": 42, "pwm2": 45},
    {"step": 4, "temp": 65, "pwm1": 55, "pwm2": 55},
    {"step": 5, "temp": 72, "pwm1": 65, "pwm2": 65},
    {"step": 6, "temp": 78, "pwm1": 75, "pwm2": 75},
    {"step": 7, "temp": 84, "pwm1": 85, "pwm2": 85},
    {"step": 8, "temp": 90, "pwm1": 90, "pwm2": 90},
    {"step": 9, "temp": 94, "pwm1": 95, "pwm2": 95},
    {"step": 10, "temp": 98, "pwm1": 100, "pwm2": 100}
]

class MockHardwareEnvironment:
    """
    Context manager that isolates sysfs and runtime state into a temporary directory
    for testing loq-ctl and LOQer daemons.
    """
    def __init__(self, populate_defaults=True):
        self.populate_defaults = populate_defaults
        self._temp_dir_obj = None
        self.root_dir = None
        self.sys_dir = None
        self.legion_dir = None
        self.hwmon_dir = None
        self.power_supply_dir = None
        self.ac_dir = None
        self.pci_dir = None
        self.run_dir = None
        self.status_file = None
        self._orig_env = {}

    def __enter__(self):
        self._temp_dir_obj = tempfile.TemporaryDirectory()
        self.root_dir = self._temp_dir_obj.name

        self.sys_dir = os.path.join(self.root_dir, "sys")
        self.legion_dir = os.path.join(self.sys_dir, "devices", "platform", "legion")
        self.hwmon_dir = os.path.join(self.legion_dir, "hwmon", "hwmon0")
        self.power_supply_dir = os.path.join(self.sys_dir, "class", "power_supply", "BAT1")
        self.ac_dir = os.path.join(self.sys_dir, "class", "power_supply", "AC")
        self.pci_dir = os.path.join(self.sys_dir, "bus", "pci", "devices", "0000:01:00.0")
        self.run_dir = os.path.join(self.root_dir, "run")
        self.status_file = os.path.join(self.run_dir, "lenovo-power-status.json")

        for d in (self.legion_dir, self.hwmon_dir, self.power_supply_dir, self.ac_dir, self.pci_dir, self.run_dir):
            os.makedirs(d, exist_ok=True)

        if self.populate_defaults:
            self._setup_default_nodes()

        # Set environment overrides
        env_vars = {
            "LOQ_SYS_ROOT": self.legion_dir,
            "LOQ_STATUS_FILE": self.status_file,
            "LOQ_RUN_DIR": self.run_dir,
            "LOQER_FORCE_DEVICE": "1",
            "LOQER_NO_SUDO": "1",
        }
        for k, v in env_vars.items():
            self._orig_env[k] = os.environ.get(k)
            os.environ[k] = v

        return self

    def _setup_default_nodes(self):
        # 1. Thermal mode / profile nodes
        self.write_node("thermal_mode", "balanced")
        self.write_node("powermode", "2")
        self.write_node("fan_fullspeed", "0")
        self.write_node("lockfancontroller", "0")

        # 2. iGPU / MUX mode (0: dgpu, 1: igpu, 2: hybrid)
        self.write_node("igpu_mode", "2")
        self.write_node("igpumode", "2")

        # 3. Fan curve node & hwmon auto points
        self.write_node("fancurve", json.dumps(BALANCED_FAN_CURVE, indent=2))
        self.write_node(os.path.join("hwmon", "hwmon0", "name"), "legion_hwmon")
        self.write_node(os.path.join("hwmon", "hwmon0", "fan1_input"), "2400")
        self.write_node(os.path.join("hwmon", "hwmon0", "fan2_input"), "2500")
        self.write_node(os.path.join("hwmon", "hwmon0", "temp1_input"), "45000")
        self.write_node(os.path.join("hwmon", "hwmon0", "temp2_input"), "40000")
        for pt in BALANCED_FAN_CURVE:
            s = pt["step"]
            t = pt["temp"]
            p1_raw = int(round(pt["pwm1"] * 1.27))
            p2_raw = int(round(pt["pwm2"] * 1.27))
            self.write_node(os.path.join("hwmon", "hwmon0", f"pwm1_auto_point{s}_temp"), str(t))
            self.write_node(os.path.join("hwmon", "hwmon0", f"pwm1_auto_point{s}_pwm"), str(p1_raw))
            self.write_node(os.path.join("hwmon", "hwmon0", f"pwm2_auto_point{s}_temp"), str(t))
            self.write_node(os.path.join("hwmon", "hwmon0", f"pwm2_auto_point{s}_pwm"), str(p2_raw))

        # 4. Conservation mode & Fn lock
        self.write_node("conservation_mode", "0")
        self.write_node("fn_lock", "0")

        # 5. Hardware locks
        self.write_node("touchpad", "1")
        self.write_node("winkey", "1")
        self.write_node("overdrive", "0")

        # 6. Power limits
        self.write_node("cpu_longterm_powerlimit", "55")
        self.write_node("cpu_shortterm_powerlimit", "115")
        self.write_node("gpu_ctgp_powerlimit", "105")
        self.write_node("gpu_ppab_powerlimit", "25")
        self.write_node("power_limits", "55 115 105 25")

        # 7. LEDs (kbd backlight & ioport)
        leds_dir = os.path.join(self.legion_dir, "leds", "platform::kbd_backlight_1")
        ioport_dir = os.path.join(self.legion_dir, "leds", "platform::ioport")
        os.makedirs(leds_dir, exist_ok=True)
        os.makedirs(ioport_dir, exist_ok=True)
        self.write_file(os.path.join(leds_dir, "brightness"), "1")
        self.write_file(os.path.join(ioport_dir, "brightness"), "1")

        # 8. Power supply (Battery & AC)
        self.write_file(os.path.join(self.power_supply_dir, "capacity"), "80")
        self.write_file(os.path.join(self.power_supply_dir, "status"), "Discharging")
        self.write_file(os.path.join(self.power_supply_dir, "energy_full"), "60000000")
        self.write_file(os.path.join(self.power_supply_dir, "energy_full_design"), "60000000")
        self.write_file(os.path.join(self.power_supply_dir, "cycle_count"), "15")
        self.write_file(os.path.join(self.ac_dir, "online"), "1")
        self.write_file(os.path.join(self.ac_dir, "type"), "Mains")

        # 9. PCI GPU runtime status
        pci_power_dir = os.path.join(self.pci_dir, "power")
        os.makedirs(pci_power_dir, exist_ok=True)
        self.write_file(os.path.join(pci_power_dir, "runtime_status"), "active")

        # 10. Status JSON file
        self.set_status(DEFAULT_STATUS)

    def write_node(self, rel_path, content):
        """Write content to a node relative to self.legion_dir."""
        target = os.path.join(self.legion_dir, rel_path)
        self.write_file(target, content)

    def read_node(self, rel_path):
        """Read content from a node relative to self.legion_dir."""
        target = os.path.join(self.legion_dir, rel_path)
        return self.read_file(target)

    def write_file(self, abs_path, content):
        """Write content to an arbitrary absolute path in mock root."""
        os.makedirs(os.path.dirname(abs_path), exist_ok=True)
        with open(abs_path, "w") as f:
            f.write(str(content).strip() + "\n")

    def read_file(self, abs_path, default=""):
        """Read content from an arbitrary path in mock root."""
        try:
            with open(abs_path, "r") as f:
                return f.read().strip()
        except Exception:
            return default

    def get_status(self):
        """Read and parse the current status JSON file."""
        try:
            with open(self.status_file, "r") as f:
                return json.load(f)
        except Exception:
            return None

    def set_status(self, data):
        """Write a dictionary to the status JSON file."""
        os.makedirs(os.path.dirname(self.status_file), exist_ok=True)
        with open(self.status_file, "w") as f:
            json.dump(data, f, indent=2)

    def run_loq_ctl(self, *args):
        """
        Execute loq-ctl as a subprocess under this mock environment.
        Returns subprocess.CompletedProcess (stdout, stderr, returncode).
        """
        loq_ctl_bin = os.path.abspath(
            os.path.join(os.path.dirname(__file__), "..", "bin", "loq-ctl")
        )
        env = os.environ.copy()
        env["LOQ_SYS_ROOT"] = self.legion_dir
        env["LOQ_STATUS_FILE"] = self.status_file
        env["LOQ_RUN_DIR"] = self.run_dir
        env["LOQER_FORCE_DEVICE"] = "1"
        env["LOQER_NO_SUDO"] = "1"

        res = subprocess.run(
            [sys.executable, loq_ctl_bin] + list(args),
            env=env,
            capture_output=True,
            text=True
        )
        return res

    def __exit__(self, exc_type, exc_val, exc_tb):
        # Restore environment variables
        for k, v in self._orig_env.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v

        if self._temp_dir_obj:
            self._temp_dir_obj.cleanup()
