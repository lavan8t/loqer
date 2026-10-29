"""
Unit test suite for LOQer Background Power Daemon (lenovo-power-daemon).
Stringently tests atomic JSON persistence, defensive GPU telemetry,
hwmon/sysfs error hardening, and battery/power resilience using MockHardwareEnvironment.
"""

import os
import sys
import glob
import json
import time
import shutil
import tempfile
import unittest
import importlib.machinery
import importlib.util
from unittest.mock import patch

from tests.hardware_mock import MockHardwareEnvironment

DAEMON_BIN_PATH = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "bin", "lenovo-power-daemon")
)

def load_daemon_module():
    """Dynamically load bin/lenovo-power-daemon as a module."""
    loader = importlib.machinery.SourceFileLoader("lenovo_power_daemon", DAEMON_BIN_PATH)
    spec = importlib.util.spec_from_loader(loader.name, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


class TestDaemonAtomicWrite(unittest.TestCase):
    """Test atomic status file writing and filesystem guarantees."""

    def setUp(self):
        self.mod = load_daemon_module()
        self.temp_dir = tempfile.mkdtemp(prefix="loq_atomic_test_")

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_write_atomic_json(self):
        """
        Verify atomic write, valid JSON formatting, directory auto-creation,
        and replacement without partial or torn file states.
        """
        target_file = os.path.join(self.temp_dir, "nested", "status.json")
        sample_data = {
            "profile": "balanced",
            "pl1_w": 55,
            "pl2_w": 115,
            "turbo": True,
            "features": ["fn_lock", "overdrive", "rgb"],
            "nested": {"key": "value", "ratio": 0.85}
        }

        # 1. Write initial payload and verify auto-creation of missing directories
        res = self.mod.write_atomic_json(target_file, sample_data)
        self.assertTrue(res, "write_atomic_json returned False for initial write")
        self.assertTrue(os.path.exists(target_file), "Target file was not created")

        # 2. Verify file permissions (0644)
        file_stat = os.stat(target_file)
        self.assertEqual(file_stat.st_mode & 0o777, 0o644)

        # 3. Read back and verify exact JSON fidelity
        with open(target_file, "r", encoding="utf-8") as f:
            read_back = json.load(f)
        self.assertEqual(read_back, sample_data)

        # 4. Verify no dangling temporary files (.tmp.*) remain
        temp_dir = os.path.dirname(target_file)
        tmp_files = glob.glob(os.path.join(temp_dir, "*.tmp.*"))
        self.assertEqual(tmp_files, [], f"Leftover temporary files found: {tmp_files}")

        # 5. Verify atomic replacement: overwrite with updated content
        updated_data = {
            "profile": "performance",
            "pl1_w": 95,
            "pl2_w": 135,
            "turbo": True,
            "status": "updated"
        }
        res2 = self.mod.write_atomic_json(target_file, updated_data)
        self.assertTrue(res2, "write_atomic_json returned False for update write")

        with open(target_file, "r", encoding="utf-8") as f:
            read_back2 = json.load(f)
        self.assertEqual(read_back2, updated_data)

        # Confirm again no .tmp files linger
        tmp_files2 = glob.glob(os.path.join(temp_dir, "*.tmp.*"))
        self.assertEqual(tmp_files2, [], f"Leftover temporary files after update: {tmp_files2}")

    def test_write_atomic_json_failure_cleanup(self):
        """Verify write_atomic_json handles invalid targets cleanly and cleans temp files."""
        # Target a path where the parent is a non-directory file
        blocking_file = os.path.join(self.temp_dir, "blocker")
        with open(blocking_file, "w") as f:
            f.write("I am a file, not a directory")

        impossible_path = os.path.join(blocking_file, "status.json")
        with patch("sys.stderr"):
            res = self.mod.write_atomic_json(impossible_path, {"test": True})
        self.assertFalse(res, "write_atomic_json should return False on filesystem error")


class TestDaemonGpuTelemetry(unittest.TestCase):
    """Test defensive guards in GPU telemetry calculations."""

    def setUp(self):
        self.mod = load_daemon_module()
        self.mod.reset_gpu_telemetry_state()

    def test_get_gpu_telemetry_active_and_suspended(self):
        """
        Verify suspended/unknown returns (0, 0.0), and active calculates duty cycle
        defensively without zero division even on rapid calls (dt_ms == 0),
        negative delta time, or negative active time deltas.
        """
        # 1. Suspended state returns (0, 0.0)
        usage, power = self.mod.get_gpu_telemetry("suspended")
        self.assertEqual(usage, 0)
        self.assertEqual(power, 0.0)

        # 2. Unknown state returns (0, 0.0)
        usage, power = self.mod.get_gpu_telemetry("unknown")
        self.assertEqual(usage, 0)
        self.assertEqual(power, 0.0)

        with MockHardwareEnvironment() as mock:
            pci_active_time_node = os.path.join(mock.pci_dir, "power", "runtime_active_time")

            # 3. Active state: first call anchors the timestamp and active counter
            mock.write_file(pci_active_time_node, "1000")
            self.mod.reset_gpu_telemetry_state()

            with patch("time.monotonic", return_value=100.0):
                u1, p1 = self.mod.get_gpu_telemetry("active")
                self.assertEqual(u1, 0)
                self.assertEqual(p1, 0.0)

            # 4. Immediate rapid call (dt_ms == 0): must not raise ZeroDivisionError
            with patch("time.monotonic", return_value=100.0):
                u2, p2 = self.mod.get_gpu_telemetry("active")
                self.assertEqual(u2, 0)
                self.assertEqual(p2, 0.0)

            # 5. Rapid call under 100ms threshold (e.g. dt_ms = 50ms): returns 0 usage
            with patch("time.monotonic", return_value=100.05):
                u3, p3 = self.mod.get_gpu_telemetry("active")
                self.assertEqual(u3, 0)
                self.assertEqual(p3, 0.0)

            # 6. Active calculation with 50% duty cycle:
            # dt = 1.0s (1000ms), da = 500ms -> ratio = 0.5 -> 50% usage
            # Power = 8.0 + (50 / 100.0) * 85.0 = 50.5W
            mock.write_file(pci_active_time_node, "1500")
            with patch("time.monotonic", return_value=101.05):
                u4, p4 = self.mod.get_gpu_telemetry("active")
                self.assertEqual(u4, 50)
                self.assertEqual(p4, 50.5)

            # 7. Negative delta time (clock anomaly / time jump backwards)
            mock.write_file(pci_active_time_node, "1600")
            with patch("time.monotonic", return_value=99.0):
                u5, p5 = self.mod.get_gpu_telemetry("active")
                self.assertEqual(u5, 0)
                self.assertEqual(p5, 0.0)

            # 8. Negative active time delta (counter wrapped or driver reset)
            # Anchor first
            self.mod.reset_gpu_telemetry_state()
            mock.write_file(pci_active_time_node, "5000")
            with patch("time.monotonic", return_value=200.0):
                self.mod.get_gpu_telemetry("active")

            # Subsequent call has lower active counter
            mock.write_file(pci_active_time_node, "2000")
            with patch("time.monotonic", return_value=201.0):
                u6, p6 = self.mod.get_gpu_telemetry("active")
                self.assertEqual(u6, 0)
                self.assertEqual(p6, 0.0)

            # 9. Missing / unreadable runtime_active_time node
            os.remove(pci_active_time_node)
            self.mod.reset_gpu_telemetry_state()
            with patch("time.monotonic", return_value=300.0):
                u7, p7 = self.mod.get_gpu_telemetry("active")
                self.assertEqual(u7, 0)
                self.assertEqual(p7, 0.0)


class TestDaemonStatusJson(unittest.TestCase):
    """Test status JSON schema and dual target path persistence."""

    def setUp(self):
        self.mod = load_daemon_module()

    def test_update_status_json(self):
        """
        Verify status JSON is written to both target locations with valid schema
        matching all expected keys (profile, pl1_w, pl2_w, fan1_rpm, gpu_usage, etc.).
        """
        with MockHardwareEnvironment() as mock:
            uid = os.environ.get("SUDO_UID") or str(os.getuid() if os.getuid() != 0 else 1000)

            data = self.mod.update_status_json("balanced", "standard", ac_on=True)

            # Verify both target locations are written
            system_target = os.path.join(mock.run_dir, "lenovo-power-status.json")
            user_target = os.path.join(mock.run_dir, "user", str(uid), "lenovo-power-status.json")

            self.assertTrue(os.path.isfile(system_target), f"Missing system status file: {system_target}")
            self.assertTrue(os.path.isfile(user_target), f"Missing user status file: {user_target}")

            # Read both files and verify validity
            with open(system_target, "r") as f:
                sys_status = json.load(f)

            with open(user_target, "r") as f:
                usr_status = json.load(f)

            self.assertEqual(sys_status, usr_status)

            expected_keys = [
                "profile", "is_saver", "ac_online", "pl1_w", "pl2_w", "turbo", "epp",
                "gpu_status", "gpu_usage", "gpu_power_w", "display_hz", "igpu_mode",
                "fan1_rpm", "fan2_rpm", "cpu_temp", "gpu_temp", "fan_fullspeed",
                "conservation_mode", "fn_lock", "touchpad", "winkey", "overdrive",
                "gpu_ctgp_w", "gpu_ppab_w", "gpu_total_w", "lockfancontroller",
                "kbd_backlight", "ioport_light", "battery_capacity", "battery_status",
                "battery_health", "battery_cycles", "battery_wh_full", "battery_wh_design",
                "bootlogo_enabled"
            ]

            for key in expected_keys:
                self.assertIn(key, sys_status, f"Missing required schema key '{key}' in status JSON")

            # Check specific balanced profile values
            self.assertEqual(sys_status["profile"], "balanced")
            self.assertFalse(sys_status["is_saver"])
            self.assertTrue(sys_status["ac_online"])
            self.assertEqual(sys_status["pl1_w"], 55)
            self.assertEqual(sys_status["pl2_w"], 115)
            self.assertEqual(sys_status["fan1_rpm"], 2400)
            self.assertEqual(sys_status["fan2_rpm"], 2500)
            self.assertEqual(sys_status["cpu_temp"], 45)
            self.assertEqual(sys_status["gpu_temp"], 40)
            self.assertEqual(sys_status["battery_capacity"], 80)
            self.assertEqual(sys_status["battery_status"], "Discharging")
            self.assertEqual(sys_status["battery_health"], 100.0)

    def test_update_status_json_profiles(self):
        """Verify update_status_json assigns correct limits across all profiles."""
        with MockHardwareEnvironment() as mock:
            # Performance on AC
            data_perf = self.mod.update_status_json("performance", "standard", ac_on=True)
            self.assertEqual(data_perf["profile"], "performance")
            self.assertEqual(data_perf["pl1_w"], 95)
            self.assertEqual(data_perf["pl2_w"], 135)
            self.assertEqual(data_perf["display_hz"], 144)

            # Quiet on AC
            data_quiet = self.mod.update_status_json("quiet", "standard", ac_on=True)
            self.assertEqual(data_quiet["profile"], "quiet")
            self.assertEqual(data_quiet["pl1_w"], 35)
            self.assertEqual(data_quiet["pl2_w"], 65)
            self.assertEqual(data_quiet["display_hz"], 144)

            # Quiet on Battery (saver mode)
            data_saver = self.mod.update_status_json("quiet", "quiet_battery", ac_on=False)
            self.assertEqual(data_saver["profile"], "quiet")
            self.assertEqual(data_saver["pl1_w"], 15)
            self.assertEqual(data_saver["pl2_w"], 25)
            self.assertTrue(data_saver["is_saver"])
            self.assertEqual(data_saver["display_hz"], 60)


class TestDaemonResilience(unittest.TestCase):
    """Test daemon resilience against missing hwmon, battery, or sysfs nodes."""

    def setUp(self):
        self.mod = load_daemon_module()

    def test_missing_hwmon_resilience(self):
        """
        Verify daemon handles missing hwmon/temp/fan nodes without raising
        unhandled exceptions, falling back to 0.
        """
        with MockHardwareEnvironment() as mock:
            # 1. Complete absence of hwmon directory
            shutil.rmtree(mock.hwmon_dir)

            hwmon_path = self.mod.find_legion_hwmon()
            # Must not crash and can return None or fallback
            self.assertTrue(hwmon_path is None or not os.path.exists(hwmon_path))

            # update_status_json must not raise
            data = self.mod.update_status_json("balanced", "standard", ac_on=True)
            self.assertEqual(data["fan1_rpm"], 0)
            self.assertEqual(data["fan2_rpm"], 0)
            self.assertEqual(data["cpu_temp"], 0)
            self.assertEqual(data["gpu_temp"], 0)

            # 2. Corrupted / non-numeric contents in hwmon nodes
            os.makedirs(mock.hwmon_dir, exist_ok=True)
            mock.write_file(os.path.join(mock.hwmon_dir, "name"), "legion_hwmon")
            mock.write_file(os.path.join(mock.hwmon_dir, "fan1_input"), "corrupted_rpm")
            mock.write_file(os.path.join(mock.hwmon_dir, "fan2_input"), "")
            mock.write_file(os.path.join(mock.hwmon_dir, "temp1_input"), "N/A")
            mock.write_file(os.path.join(mock.hwmon_dir, "temp2_input"), "-500")

            data2 = self.mod.update_status_json("balanced", "standard", ac_on=True)
            self.assertEqual(data2["fan1_rpm"], 0)
            self.assertEqual(data2["fan2_rpm"], 0)
            self.assertEqual(data2["cpu_temp"], 0)
            self.assertEqual(data2["gpu_temp"], 0)

    def test_battery_disconnected_or_ac_offline(self):
        """
        Verify handling of missing BAT0/BAT1 or AC offline states without crashing.
        """
        with MockHardwareEnvironment() as mock:
            # 1. Battery disconnected (BAT1 removed, no BAT0)
            shutil.rmtree(mock.power_supply_dir)

            bat_path = self.mod.find_battery_path()
            self.assertIsNone(bat_path, "find_battery_path should return None when no battery exists")

            data = self.mod.update_status_json("balanced", "standard", ac_on=True)
            self.assertEqual(data["battery_capacity"], 0)
            self.assertEqual(data["battery_status"], "Unknown")
            self.assertEqual(data["battery_health"], 100.0)
            self.assertEqual(data["battery_cycles"], 0)
            self.assertEqual(data["battery_wh_full"], 0.0)
            self.assertEqual(data["battery_wh_design"], 0.0)

            # 2. AC offline
            mock.write_file(os.path.join(mock.ac_dir, "online"), "0")
            self.assertFalse(self.mod.is_ac_online(), "is_ac_online should return False when AC is offline")

            data_ac_off = self.mod.update_status_json("quiet", "quiet_battery", ac_on=False)
            self.assertFalse(data_ac_off["ac_online"])
            self.assertTrue(data_ac_off["is_saver"])

            # 3. Alternate battery name: BAT0
            bat0_dir = os.path.join(mock.sys_dir, "class", "power_supply", "BAT0")
            os.makedirs(bat0_dir, exist_ok=True)
            mock.write_file(os.path.join(bat0_dir, "capacity"), "65")
            mock.write_file(os.path.join(bat0_dir, "status"), "Charging")
            mock.write_file(os.path.join(bat0_dir, "energy_full"), "50000000")
            mock.write_file(os.path.join(bat0_dir, "energy_full_design"), "60000000")
            mock.write_file(os.path.join(bat0_dir, "cycle_count"), "22")

            bat_path0 = self.mod.find_battery_path()
            self.assertEqual(bat_path0, bat0_dir)

            data_bat0 = self.mod.update_status_json("balanced", "standard", ac_on=True)
            self.assertEqual(data_bat0["battery_capacity"], 65)
            self.assertEqual(data_bat0["battery_status"], "Charging")
            self.assertEqual(data_bat0["battery_cycles"], 22)
            self.assertEqual(data_bat0["battery_wh_full"], 50.0)
            self.assertEqual(data_bat0["battery_wh_design"], 60.0)
            self.assertAlmostEqual(data_bat0["battery_health"], 83.3, places=1)


class TestDaemonHardwareControl(unittest.TestCase):
    """Test daemon profile switching and limits application."""

    def setUp(self):
        self.mod = load_daemon_module()

    def test_set_hardware_profile(self):
        """Verify set_hardware_profile updates sysfs nodes under mock environment."""
        with MockHardwareEnvironment() as mock:
            # Performance
            self.assertTrue(self.mod.set_hardware_profile("performance"))
            self.assertEqual(mock.read_node("powermode"), "3")
            self.assertEqual(mock.read_node("fan_fullspeed"), "0")

            # Custom
            self.assertTrue(self.mod.set_hardware_profile("custom"))
            self.assertEqual(mock.read_node("powermode"), "255")
            self.assertEqual(mock.read_node("fan_fullspeed"), "1")

            # Quiet
            self.assertTrue(self.mod.set_hardware_profile("quiet"))
            self.assertEqual(mock.read_node("powermode"), "1")
            self.assertEqual(mock.read_node("fan_fullspeed"), "0")

            # Balanced
            self.assertTrue(self.mod.set_hardware_profile("balanced"))
            self.assertEqual(mock.read_node("powermode"), "2")
            self.assertEqual(mock.read_node("fan_fullspeed"), "0")

    def test_set_rapl_and_gpu_tgp(self):
        """Verify set_rapl_limit and set_gpu_tgp write EC limits cleanly."""
        with MockHardwareEnvironment() as mock:
            self.mod.set_rapl_limit(95, 135)
            self.assertEqual(mock.read_node("cpu_longterm_powerlimit"), "95")
            self.assertEqual(mock.read_node("cpu_shortterm_powerlimit"), "135")
            self.assertEqual(mock.read_node("cpu_cross_loading_powerlimit"), "95")

            self.mod.set_gpu_tgp(105, 25)
            self.assertEqual(mock.read_node("gpu_ctgp_powerlimit"), "105")
            self.assertEqual(mock.read_node("gpu_ppab_powerlimit"), "25")

    def test_find_legion_hwmon_override(self):
        """Verify LOQ_HWMON_DIR environment variable takes precedence."""
        with MockHardwareEnvironment() as mock:
            custom_hwmon = os.path.join(mock.root_dir, "custom_hwmon")
            os.makedirs(custom_hwmon, exist_ok=True)
            mock.write_file(os.path.join(custom_hwmon, "name"), "legion_hwmon")

            try:
                os.environ["LOQ_HWMON_DIR"] = custom_hwmon
                found = self.mod.find_legion_hwmon()
                self.assertEqual(found, custom_hwmon)
            finally:
                os.environ.pop("LOQ_HWMON_DIR", None)


if __name__ == "__main__":
    unittest.main()
