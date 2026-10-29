"""
Unit test suite for LOQer Hardware Controller CLI (loq-ctl).
Tests all subcommands and validation logic stringently against MockHardwareEnvironment.
"""

import os
import json
import unittest
from tests.hardware_mock import MockHardwareEnvironment, BALANCED_FAN_CURVE

class TestLoqCtlProfiles(unittest.TestCase):
    """Test power profiles (quiet, balanced, performance, custom) and input validation."""

    def test_profile_quiet(self):
        with MockHardwareEnvironment() as mock:
            res = mock.run_loq_ctl("profile", "quiet")
            self.assertEqual(res.returncode, 0, f"profile quiet failed: {res.stderr}")
            self.assertEqual(mock.read_node("thermal_mode"), "quiet")
            self.assertEqual(mock.read_node("powermode"), "1")
            self.assertEqual(mock.read_node("fan_fullspeed"), "0")
            self.assertEqual(mock.read_node("gpu_ctgp_powerlimit"), "45")
            self.assertEqual(mock.read_node("gpu_ppab_powerlimit"), "15")

            status = mock.get_status()
            self.assertEqual(status["profile"], "quiet")
            self.assertFalse(status["fan_fullspeed"])

    def test_profile_balanced(self):
        with MockHardwareEnvironment() as mock:
            # Switch to performance first to ensure state changes
            mock.run_loq_ctl("profile", "performance")
            res = mock.run_loq_ctl("profile", "balanced")
            self.assertEqual(res.returncode, 0, f"profile balanced failed: {res.stderr}")
            self.assertEqual(mock.read_node("thermal_mode"), "balanced")
            self.assertEqual(mock.read_node("powermode"), "2")
            self.assertEqual(mock.read_node("fan_fullspeed"), "0")
            self.assertEqual(mock.read_node("gpu_ctgp_powerlimit"), "60")
            self.assertEqual(mock.read_node("gpu_ppab_powerlimit"), "20")

            status = mock.get_status()
            self.assertEqual(status["profile"], "balanced")
            self.assertFalse(status["fan_fullspeed"])

    def test_profile_performance(self):
        with MockHardwareEnvironment() as mock:
            res = mock.run_loq_ctl("profile", "performance")
            self.assertEqual(res.returncode, 0, f"profile performance failed: {res.stderr}")
            self.assertEqual(mock.read_node("thermal_mode"), "performance")
            self.assertEqual(mock.read_node("powermode"), "3")
            self.assertEqual(mock.read_node("fan_fullspeed"), "0")
            self.assertEqual(mock.read_node("gpu_ctgp_powerlimit"), "105")
            self.assertEqual(mock.read_node("gpu_ppab_powerlimit"), "25")

            status = mock.get_status()
            self.assertEqual(status["profile"], "performance")
            self.assertFalse(status["fan_fullspeed"])

    def test_profile_custom(self):
        with MockHardwareEnvironment() as mock:
            res = mock.run_loq_ctl("profile", "custom")
            self.assertEqual(res.returncode, 0, f"profile custom failed: {res.stderr}")
            self.assertEqual(mock.read_node("thermal_mode"), "custom")
            self.assertEqual(mock.read_node("powermode"), "255")
            self.assertEqual(mock.read_node("fan_fullspeed"), "1")
            self.assertEqual(mock.read_node("gpu_ctgp_powerlimit"), "105")
            self.assertEqual(mock.read_node("gpu_ppab_powerlimit"), "25")

            status = mock.get_status()
            self.assertEqual(status["profile"], "custom")
            self.assertTrue(status["fan_fullspeed"])

    def test_profile_aliases(self):
        with MockHardwareEnvironment() as mock:
            # low-power alias for quiet
            res = mock.run_loq_ctl("profile", "low-power")
            self.assertEqual(res.returncode, 0)
            self.assertEqual(mock.read_node("thermal_mode"), "quiet")

            # extreme alias for custom
            res = mock.run_loq_ctl("profile", "extreme")
            self.assertEqual(res.returncode, 0)
            self.assertEqual(mock.read_node("thermal_mode"), "custom")

    def test_profile_invalid_rejection(self):
        with MockHardwareEnvironment() as mock:
            for invalid_prof in ["invalid_mode", "turbo", "silent", "999", ""]:
                res = mock.run_loq_ctl("profile", invalid_prof)
                self.assertNotEqual(res.returncode, 0, f"Expected non-zero returncode for profile '{invalid_prof}'")
                self.assertIn("Invalid profile", res.stderr)


class TestLoqCtlMux(unittest.TestCase):
    """Test MUX switch modes (hybrid, igpu, dgpu) and input rejection."""

    def test_mux_hybrid(self):
        with MockHardwareEnvironment() as mock:
            res = mock.run_loq_ctl("mux", "hybrid")
            self.assertEqual(res.returncode, 0, f"mux hybrid failed: {res.stderr}")
            self.assertEqual(mock.read_node("igpu_mode"), "2")
            self.assertEqual(mock.read_node("igpumode"), "2")

            status = mock.get_status()
            self.assertEqual(status["igpu_mode"], 2)

    def test_mux_igpu(self):
        with MockHardwareEnvironment() as mock:
            res = mock.run_loq_ctl("mux", "igpu")
            self.assertEqual(res.returncode, 0, f"mux igpu failed: {res.stderr}")
            self.assertEqual(mock.read_node("igpu_mode"), "1")
            self.assertEqual(mock.read_node("igpumode"), "1")

            status = mock.get_status()
            self.assertEqual(status["igpu_mode"], 1)

    def test_mux_dgpu(self):
        with MockHardwareEnvironment() as mock:
            res = mock.run_loq_ctl("mux", "dgpu")
            self.assertEqual(res.returncode, 0, f"mux dgpu failed: {res.stderr}")
            self.assertEqual(mock.read_node("igpu_mode"), "0")
            self.assertEqual(mock.read_node("igpumode"), "0")

            status = mock.get_status()
            self.assertEqual(status["igpu_mode"], 0)

    def test_mux_aliases(self):
        with MockHardwareEnvironment() as mock:
            res = mock.run_loq_ctl("mux", "dedicated")
            self.assertEqual(res.returncode, 0)
            self.assertEqual(mock.read_node("igpu_mode"), "0")

            res = mock.run_loq_ctl("mux", "intel")
            self.assertEqual(res.returncode, 0)
            self.assertEqual(mock.read_node("igpu_mode"), "1")

            res = mock.run_loq_ctl("mux", "auto")
            self.assertEqual(res.returncode, 0)
            self.assertEqual(mock.read_node("igpu_mode"), "2")

    def test_mux_invalid_rejection(self):
        with MockHardwareEnvironment() as mock:
            for invalid_mux in ["invalid", "nvidia", "integrated_only", "3", ""]:
                res = mock.run_loq_ctl("mux", invalid_mux)
                self.assertNotEqual(res.returncode, 0, f"Expected non-zero returncode for mux '{invalid_mux}'")
                self.assertIn("Invalid MUX mode", res.stderr)


class TestLoqCtlFanCurve(unittest.TestCase):
    """Test fancurve subcommands, validation, monotonicity, and bounds checking."""

    def test_fancurve_get(self):
        with MockHardwareEnvironment() as mock:
            res = mock.run_loq_ctl("fancurve", "get")
            self.assertEqual(res.returncode, 0, f"fancurve get failed: {res.stderr}")
            points = json.loads(res.stdout)
            self.assertEqual(len(points), 10)
            self.assertEqual(points[0]["step"], 1)
            self.assertEqual(points[9]["step"], 10)
            for pt in points:
                self.assertIn("temp", pt)
                self.assertIn("pwm1", pt)
                self.assertIn("pwm2", pt)
                self.assertTrue(0 <= pt["pwm1"] <= 100)
                self.assertTrue(0 <= pt["pwm2"] <= 100)

    def test_fancurve_preset_quiet_and_balanced(self):
        with MockHardwareEnvironment() as mock:
            res = mock.run_loq_ctl("fancurve", "preset", "quiet")
            self.assertEqual(res.returncode, 0, f"fancurve preset quiet failed: {res.stderr}")
            self.assertIn("Applied fan preset: quiet", res.stdout)
            self.assertEqual(mock.read_node("lockfancontroller"), "1")

            res_bal = mock.run_loq_ctl("fancurve", "preset", "balanced")
            self.assertEqual(res_bal.returncode, 0, f"fancurve preset balanced failed: {res_bal.stderr}")
            self.assertIn("Applied fan preset: balanced", res_bal.stdout)

    def test_fancurve_preset_invalid(self):
        with MockHardwareEnvironment() as mock:
            res = mock.run_loq_ctl("fancurve", "preset", "super_extreme_fake")
            self.assertNotEqual(res.returncode, 0)
            self.assertIn("Unknown fan curve preset", res.stderr)

    def test_fancurve_auto_reset(self):
        with MockHardwareEnvironment() as mock:
            mock.write_node("lockfancontroller", "1")
            res = mock.run_loq_ctl("fancurve", "auto")
            self.assertEqual(res.returncode, 0)
            self.assertEqual(mock.read_node("lockfancontroller"), "0")

            mock.write_node("lockfancontroller", "1")
            res_reset = mock.run_loq_ctl("fancurve", "reset")
            self.assertEqual(res_reset.returncode, 0)
            self.assertEqual(mock.read_node("lockfancontroller"), "0")

    def test_fancurve_set_single_point(self):
        with MockHardwareEnvironment() as mock:
            res = mock.run_loq_ctl("fancurve", "set", "5", "70", "80", "85")
            self.assertEqual(res.returncode, 0, f"fancurve set failed: {res.stderr}")

            t_val = mock.read_node(os.path.join("hwmon", "hwmon0", "pwm1_auto_point5_temp"))
            p1_val = mock.read_node(os.path.join("hwmon", "hwmon0", "pwm1_auto_point5_pwm"))
            p2_val = mock.read_node(os.path.join("hwmon", "hwmon0", "pwm2_auto_point5_pwm"))

            self.assertEqual(t_val, "70")
            self.assertEqual(p1_val, str(int(round(80 * 1.27))))
            self.assertEqual(p2_val, str(int(round(85 * 1.27))))

    def test_fancurve_set_out_of_bounds(self):
        with MockHardwareEnvironment() as mock:
            # Step out of bounds (must be 1-10)
            res = mock.run_loq_ctl("fancurve", "set", "0", "50", "50", "50")
            self.assertNotEqual(res.returncode, 0)
            res = mock.run_loq_ctl("fancurve", "set", "11", "50", "50", "50")
            self.assertNotEqual(res.returncode, 0)

            # Temp out of bounds (must be 0-120)
            res = mock.run_loq_ctl("fancurve", "set", "5", "-5", "50", "50")
            self.assertNotEqual(res.returncode, 0)
            res = mock.run_loq_ctl("fancurve", "set", "5", "130", "50", "50")
            self.assertNotEqual(res.returncode, 0)

            # PWM out of bounds (must be 0-100)
            res = mock.run_loq_ctl("fancurve", "set", "5", "50", "-1", "50")
            self.assertNotEqual(res.returncode, 0)
            res = mock.run_loq_ctl("fancurve", "set", "5", "50", "101", "50")
            self.assertNotEqual(res.returncode, 0)
            res = mock.run_loq_ctl("fancurve", "set", "5", "50", "50", "150")
            self.assertNotEqual(res.returncode, 0)

    def test_fancurve_apply_valid_curve(self):
        with MockHardwareEnvironment() as mock:
            curve = [
                {"step": s, "temp": 30 + s * 6, "pwm1": s * 9, "pwm2": s * 9}
                for s in range(1, 11)
            ]
            res = mock.run_loq_ctl("fancurve", "apply", json.dumps(curve))
            self.assertEqual(res.returncode, 0, f"Valid curve apply failed: {res.stderr}")
            self.assertIn("Fan curve applied successfully", res.stdout)

            # Verify node in hwmon matches
            t_val = mock.read_node(os.path.join("hwmon", "hwmon0", "pwm1_auto_point10_temp"))
            self.assertEqual(t_val, "90")

    def test_fancurve_temperature_monotonicity_rejection(self):
        with MockHardwareEnvironment() as mock:
            # Violate monotonicity at step 5 (temp drops from 65 to 60)
            curve = [
                {"step": 1, "temp": 40, "pwm1": 20, "pwm2": 20},
                {"step": 2, "temp": 48, "pwm1": 30, "pwm2": 30},
                {"step": 3, "temp": 55, "pwm1": 40, "pwm2": 40},
                {"step": 4, "temp": 65, "pwm1": 50, "pwm2": 50},
                {"step": 5, "temp": 60, "pwm1": 60, "pwm2": 60},  # Violation: 60 < 65
                {"step": 6, "temp": 75, "pwm1": 70, "pwm2": 70},
                {"step": 7, "temp": 80, "pwm1": 80, "pwm2": 80},
                {"step": 8, "temp": 85, "pwm1": 85, "pwm2": 85},
                {"step": 9, "temp": 90, "pwm1": 90, "pwm2": 90},
                {"step": 10, "temp": 95, "pwm1": 95, "pwm2": 95},
            ]
            res = mock.run_loq_ctl("fancurve", "apply", json.dumps(curve))
            self.assertNotEqual(res.returncode, 0)
            self.assertIn("monotonicity", res.stderr.lower())

    def test_fancurve_pwm_bounds_rejection(self):
        with MockHardwareEnvironment() as mock:
            curve = [
                {"step": s, "temp": 40 + s * 5, "pwm1": 50, "pwm2": 50}
                for s in range(1, 11)
            ]
            # Set point 5 PWM1 to 105% (out of bounds)
            curve[4]["pwm1"] = 105
            res = mock.run_loq_ctl("fancurve", "apply", json.dumps(curve))
            self.assertNotEqual(res.returncode, 0)
            self.assertIn("out of bounds", res.stderr.lower())

    def test_fancurve_corrupt_syntax_rejection(self):
        with MockHardwareEnvironment() as mock:
            # Corrupt JSON syntax
            res = mock.run_loq_ctl("fancurve", "apply", "{this is: not valid json}")
            self.assertNotEqual(res.returncode, 0)
            self.assertIn("Malformed", res.stderr)

            # Only 9 points instead of 10
            short_curve = [
                {"step": s, "temp": 40 + s * 5, "pwm1": 50, "pwm2": 50}
                for s in range(1, 10)
            ]
            res = mock.run_loq_ctl("fancurve", "apply", json.dumps(short_curve))
            self.assertNotEqual(res.returncode, 0)
            self.assertIn("10 points", res.stderr)

            # Missing required field
            bad_field_curve = [
                {"step": s, "temp": 40 + s * 5, "pwm1": 50}  # missing pwm2
                for s in range(1, 11)
            ]
            res = mock.run_loq_ctl("fancurve", "apply", json.dumps(bad_field_curve))
            self.assertNotEqual(res.returncode, 0)
            self.assertIn("missing", res.stderr.lower())


class TestLoqCtlConservation(unittest.TestCase):
    """Test battery conservation mode (80% toggle and status read)."""

    def test_conservation_enable_and_disable(self):
        with MockHardwareEnvironment() as mock:
            # Enable conservation mode
            res_on = mock.run_loq_ctl("conservation", "1")
            self.assertEqual(res_on.returncode, 0, f"conservation 1 failed: {res_on.stderr}")
            self.assertEqual(mock.read_node("conservation_mode"), "1")
            status = mock.get_status()
            self.assertTrue(status["conservation_mode"])

            # Disable conservation mode
            res_off = mock.run_loq_ctl("conservation", "0")
            self.assertEqual(res_off.returncode, 0, f"conservation 0 failed: {res_off.stderr}")
            self.assertEqual(mock.read_node("conservation_mode"), "0")
            status = mock.get_status()
            self.assertFalse(status["conservation_mode"])

    def test_conservation_read_status(self):
        with MockHardwareEnvironment() as mock:
            mock.write_node("conservation_mode", "1")
            res = mock.run_loq_ctl("conservation", "status")
            self.assertEqual(res.returncode, 0)
            self.assertEqual(res.stdout.strip(), "1")

            mock.write_node("conservation_mode", "0")
            res2 = mock.run_loq_ctl("conservation", "get")
            self.assertEqual(res2.returncode, 0)
            self.assertEqual(res2.stdout.strip(), "0")

    def test_conservation_toggle(self):
        with MockHardwareEnvironment() as mock:
            mock.write_node("conservation_mode", "0")
            res = mock.run_loq_ctl("conservation", "toggle")
            self.assertEqual(res.returncode, 0)
            self.assertEqual(mock.read_node("conservation_mode"), "1")

            res2 = mock.run_loq_ctl("conservation")
            self.assertEqual(res2.returncode, 0)
            self.assertEqual(mock.read_node("conservation_mode"), "0")

    def test_conservation_invalid_rejection(self):
        with MockHardwareEnvironment() as mock:
            res = mock.run_loq_ctl("conservation", "invalid_value")
            self.assertNotEqual(res.returncode, 0)
            self.assertIn("Invalid value", res.stderr)


class TestLoqCtlHardwareLocks(unittest.TestCase):
    """Test hardware locks: Fn lock, touchpad, Win key, and Overdrive."""

    def test_fn_lock(self):
        with MockHardwareEnvironment() as mock:
            res_on = mock.run_loq_ctl("fn_lock", "1")
            self.assertEqual(res_on.returncode, 0)
            self.assertEqual(mock.read_node("fn_lock"), "1")
            self.assertTrue(mock.get_status()["fn_lock"])

            res_off = mock.run_loq_ctl("fn_lock", "0")
            self.assertEqual(res_off.returncode, 0)
            self.assertEqual(mock.read_node("fn_lock"), "0")
            self.assertFalse(mock.get_status()["fn_lock"])

            res_status = mock.run_loq_ctl("fn_lock", "status")
            self.assertEqual(res_status.returncode, 0)
            self.assertEqual(res_status.stdout.strip(), "0")

            res_inv = mock.run_loq_ctl("fn_lock", "invalid")
            self.assertNotEqual(res_inv.returncode, 0)

    def test_touchpad(self):
        with MockHardwareEnvironment() as mock:
            res_off = mock.run_loq_ctl("touchpad", "0")
            self.assertEqual(res_off.returncode, 0)
            self.assertEqual(mock.read_node("touchpad"), "0")
            self.assertFalse(mock.get_status()["touchpad"])

            res_on = mock.run_loq_ctl("touchpad", "1")
            self.assertEqual(res_on.returncode, 0)
            self.assertEqual(mock.read_node("touchpad"), "1")
            self.assertTrue(mock.get_status()["touchpad"])

            res_status = mock.run_loq_ctl("touchpad", "status")
            self.assertEqual(res_status.returncode, 0)
            self.assertEqual(res_status.stdout.strip(), "1")

            res_inv = mock.run_loq_ctl("touchpad", "bad_state")
            self.assertNotEqual(res_inv.returncode, 0)

    def test_winkey(self):
        with MockHardwareEnvironment() as mock:
            res_off = mock.run_loq_ctl("winkey", "0")
            self.assertEqual(res_off.returncode, 0)
            self.assertEqual(mock.read_node("winkey"), "0")
            self.assertFalse(mock.get_status()["winkey"])

            res_on = mock.run_loq_ctl("winkey", "1")
            self.assertEqual(res_on.returncode, 0)
            self.assertEqual(mock.read_node("winkey"), "1")
            self.assertTrue(mock.get_status()["winkey"])

            res_inv = mock.run_loq_ctl("winkey", "invalid")
            self.assertNotEqual(res_inv.returncode, 0)

    def test_overdrive(self):
        with MockHardwareEnvironment() as mock:
            res_on = mock.run_loq_ctl("overdrive", "1")
            self.assertEqual(res_on.returncode, 0)
            self.assertEqual(mock.read_node("overdrive"), "1")
            self.assertTrue(mock.get_status()["overdrive"])

            res_off = mock.run_loq_ctl("overdrive", "0")
            self.assertEqual(res_off.returncode, 0)
            self.assertEqual(mock.read_node("overdrive"), "0")
            self.assertFalse(mock.get_status()["overdrive"])

            res_inv = mock.run_loq_ctl("overdrive", "invalid")
            self.assertNotEqual(res_inv.returncode, 0)


class TestLoqCtlPowerLimits(unittest.TestCase):
    """
    Test GodMode power limits:
    PL1 (15-115W), PL2 (25-135W), cTGP (45-105W), PPAB (5-25W).
    """

    def test_powerlimits_valid(self):
        with MockHardwareEnvironment() as mock:
            res = mock.run_loq_ctl("powerlimits", "55", "115", "105", "25")
            self.assertEqual(res.returncode, 0, f"powerlimits failed: {res.stderr}")
            self.assertEqual(mock.read_node("cpu_longterm_powerlimit"), "55")
            self.assertEqual(mock.read_node("cpu_shortterm_powerlimit"), "115")
            self.assertEqual(mock.read_node("gpu_ctgp_powerlimit"), "105")
            self.assertEqual(mock.read_node("gpu_ppab_powerlimit"), "25")

            status = mock.get_status()
            self.assertEqual(status["pl1_w"], 55)
            self.assertEqual(status["pl2_w"], 115)
            self.assertEqual(status["gpu_ctgp_w"], 105)
            self.assertEqual(status["gpu_ppab_w"], 25)
            self.assertEqual(status["gpu_total_w"], 130)

    def test_powerlimits_boundaries_min(self):
        with MockHardwareEnvironment() as mock:
            # Minimum allowed values: PL1=15, PL2=25, cTGP=45, PPAB=5
            res = mock.run_loq_ctl("powerlimits", "15", "25", "45", "5")
            self.assertEqual(res.returncode, 0, f"Min boundary powerlimits failed: {res.stderr}")
            self.assertEqual(mock.read_node("cpu_longterm_powerlimit"), "15")
            self.assertEqual(mock.read_node("cpu_shortterm_powerlimit"), "25")
            self.assertEqual(mock.read_node("gpu_ctgp_powerlimit"), "45")
            self.assertEqual(mock.read_node("gpu_ppab_powerlimit"), "5")

    def test_powerlimits_boundaries_max(self):
        with MockHardwareEnvironment() as mock:
            # Maximum allowed values: PL1=115, PL2=135, cTGP=105, PPAB=25
            res = mock.run_loq_ctl("powerlimits", "115", "135", "105", "25")
            self.assertEqual(res.returncode, 0, f"Max boundary powerlimits failed: {res.stderr}")
            self.assertEqual(mock.read_node("cpu_longterm_powerlimit"), "115")
            self.assertEqual(mock.read_node("cpu_shortterm_powerlimit"), "135")
            self.assertEqual(mock.read_node("gpu_ctgp_powerlimit"), "105")
            self.assertEqual(mock.read_node("gpu_ppab_powerlimit"), "25")

    def test_powerlimits_pl1_out_of_range(self):
        with MockHardwareEnvironment() as mock:
            # PL1 < 15
            res = mock.run_loq_ctl("powerlimits", "14", "115", "105", "25")
            self.assertNotEqual(res.returncode, 0)
            self.assertIn("out of range", res.stderr)

            # PL1 > 115
            res2 = mock.run_loq_ctl("powerlimits", "116", "116", "105", "25")
            self.assertNotEqual(res2.returncode, 0)
            self.assertIn("out of range", res2.stderr)

    def test_powerlimits_pl2_out_of_range(self):
        with MockHardwareEnvironment() as mock:
            # PL2 < 25
            res = mock.run_loq_ctl("powerlimits", "20", "24", "105", "25")
            self.assertNotEqual(res.returncode, 0)
            self.assertIn("out of range", res.stderr)

            # PL2 > 135
            res2 = mock.run_loq_ctl("powerlimits", "55", "136", "105", "25")
            self.assertNotEqual(res2.returncode, 0)
            self.assertIn("out of range", res2.stderr)

            # PL2 < PL1 (illogical inversion)
            res3 = mock.run_loq_ctl("powerlimits", "80", "70", "105", "25")
            self.assertNotEqual(res3.returncode, 0)
            self.assertIn("cannot be less than PL1", res3.stderr)

    def test_powerlimits_ctgp_out_of_range(self):
        with MockHardwareEnvironment() as mock:
            # cTGP < 45
            res = mock.run_loq_ctl("powerlimits", "55", "115", "44", "25")
            self.assertNotEqual(res.returncode, 0)
            self.assertIn("out of range", res.stderr)

            # cTGP > 105
            res2 = mock.run_loq_ctl("powerlimits", "55", "115", "106", "25")
            self.assertNotEqual(res2.returncode, 0)
            self.assertIn("out of range", res2.stderr)

    def test_powerlimits_ppab_out_of_range(self):
        with MockHardwareEnvironment() as mock:
            # PPAB < 5
            res = mock.run_loq_ctl("powerlimits", "55", "115", "105", "4")
            self.assertNotEqual(res.returncode, 0)
            self.assertIn("out of range", res.stderr)

            # PPAB > 25
            res2 = mock.run_loq_ctl("powerlimits", "55", "115", "105", "26")
            self.assertNotEqual(res2.returncode, 0)
            self.assertIn("out of range", res2.stderr)

    def test_powerlimits_invalid_syntax(self):
        with MockHardwareEnvironment() as mock:
            # Missing arguments
            res = mock.run_loq_ctl("powerlimits")
            self.assertNotEqual(res.returncode, 0)

            # Non-integer inputs
            res2 = mock.run_loq_ctl("powerlimits", "abc", "115")
            self.assertNotEqual(res2.returncode, 0)

            res3 = mock.run_loq_ctl("powerlimits", "55", "def")
            self.assertNotEqual(res3.returncode, 0)


class TestLoqCtlStatus(unittest.TestCase):
    """Test status subcommand parsing and output."""

    def test_status_output(self):
        with MockHardwareEnvironment() as mock:
            res = mock.run_loq_ctl("status")
            self.assertEqual(res.returncode, 0, f"status failed: {res.stderr}")
            data = json.loads(res.stdout)
            self.assertIn("profile", data)
            self.assertIn("pl1_w", data)
            self.assertIn("pl2_w", data)
            self.assertIn("igpu_mode", data)
            self.assertIn("battery_capacity", data)

    def test_status_missing_file(self):
        with MockHardwareEnvironment() as mock:
            if os.path.exists(mock.status_file):
                os.remove(mock.status_file)
            res = mock.run_loq_ctl("status")
            self.assertNotEqual(res.returncode, 0)
            self.assertIn("not found", res.stderr.lower())


class TestLoqCtlErrorHandling(unittest.TestCase):
    """Test graceful handling of missing sysfs nodes, unknown commands, and GPU tests."""

    def test_missing_sysfs_node_failure(self):
        with MockHardwareEnvironment() as mock:
            # Delete touchpad node
            touchpad_path = os.path.join(mock.legion_dir, "touchpad")
            if os.path.exists(touchpad_path):
                os.remove(touchpad_path)

            res = mock.run_loq_ctl("touchpad", "1")
            self.assertNotEqual(res.returncode, 0)
            self.assertIn("not found", res.stderr.lower())

    def test_unknown_subcommand(self):
        with MockHardwareEnvironment() as mock:
            res = mock.run_loq_ctl("nonexistent_command_12345")
            self.assertNotEqual(res.returncode, 0)
            self.assertIn("Unknown command", res.stderr)

    def test_gpu_spike_invocation(self):
        with MockHardwareEnvironment() as mock:
            # Verify test-gpu handles invocation without uncaught python crashes
            res = mock.run_loq_ctl("test-gpu", "1")
            # If libOpenCL is missing, it catches Exception and writes to stderr
            # The important assertion is that loq-ctl doesn't crash with a Python traceback
            self.assertNotIn("Traceback (most recent call last)", res.stderr)


if __name__ == "__main__":
    unittest.main()
