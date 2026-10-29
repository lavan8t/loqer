"""
Unit test suite for LOQer UI sync guard and candidate resolution.
Tests:
- install.sh --check-sync execution, output diagnostics, and exit codes.
- bin/loqer candidate search priority order and path resolution.
- bin/loqer runtime divergence notice emission and suppression.
"""

import os
import sys
import shutil
import tempfile
import subprocess
import unittest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
INSTALL_SH = os.path.join(REPO_ROOT, "install.sh")
LOQER_BIN = os.path.join(REPO_ROOT, "bin", "loqer")


class TestInstallCheckSync(unittest.TestCase):
    """Tests for install.sh --check-sync and CLI flags."""

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp(prefix="loq_test_sync_")
        self.mock_sys_ui = os.path.join(self.temp_dir, "sys_share", "loqer", "ui")
        self.mock_qs_dir = os.path.join(self.temp_dir, "quickshell", "ii")

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def _setup_synced_environment(self):
        """Populate mock system and quickshell directories with repo files."""
        # System install gets full repo ui/ tree
        shutil.copytree(os.path.join(REPO_ROOT, "ui"), self.mock_sys_ui)

        # Quickshell config gets loqControl.qml and font
        os.makedirs(os.path.join(self.mock_qs_dir, "fonts"), exist_ok=True)
        shutil.copy(
            os.path.join(REPO_ROOT, "ui", "loqControl.qml"),
            os.path.join(self.mock_qs_dir, "loqControl.qml"),
        )
        repo_font = os.path.join(REPO_ROOT, "ui", "fonts", "GoogleSansFlex.ttf")
        if os.path.isfile(repo_font):
            shutil.copy(repo_font, os.path.join(self.mock_qs_dir, "fonts", "GoogleSansFlex.ttf"))

    def _run_install(self, *args, env_overrides=None):
        env = os.environ.copy()
        env["LOQER_SYSTEM_UI_DIR"] = self.mock_sys_ui
        env["LOQER_USER_CONFIG_DIR"] = self.mock_qs_dir
        if env_overrides:
            env.update(env_overrides)
        return subprocess.run(
            [INSTALL_SH, *args],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            env=env,
        )

    def test_check_sync_in_sync(self):
        """When system and user files match repo sources, exit 0 with clean sync message."""
        self._setup_synced_environment()
        res = self._run_install("--check-sync")
        self.assertEqual(res.returncode, 0, f"Expected 0, got {res.returncode}: {res.stderr}\n{res.stdout}")
        self.assertIn("All files are in sync", res.stdout)
        self.assertIn("System install is completely synchronized", res.stdout)
        self.assertIn("User quickshell integration is synchronized", res.stdout)

    def test_check_sync_missing_system_dir(self):
        """When system install directory is missing, exit 1 and report missing."""
        self._setup_synced_environment()
        shutil.rmtree(self.mock_sys_ui)
        res = self._run_install("--check-sync")
        self.assertEqual(res.returncode, 1)
        self.assertIn("[MISSING] System UI directory does not exist", res.stdout)
        self.assertIn("Sync drift detected", res.stdout)

    def test_check_sync_missing_system_file(self):
        """When a file is missing in system install, exit 1 and report file."""
        self._setup_synced_environment()
        os.remove(os.path.join(self.mock_sys_ui, "loqControl.qml"))
        res = self._run_install("--check-sync")
        self.assertEqual(res.returncode, 1)
        self.assertIn("[MISSING] loqControl.qml", res.stdout)
        self.assertIn("Sync drift detected", res.stdout)

    def test_check_sync_divergent_system_file(self):
        """When system install has divergent content, exit 1 and report diff."""
        self._setup_synced_environment()
        with open(os.path.join(self.mock_sys_ui, "loqControl.qml"), "a") as f:
            f.write("\n// modified content\n")
        res = self._run_install("--check-sync")
        self.assertEqual(res.returncode, 1)
        self.assertIn("[DIFF] loqControl.qml differs between repo and system install", res.stdout)
        self.assertIn("Sync drift detected", res.stdout)

    def test_check_sync_extra_system_file(self):
        """When system install has extraneous files not in repo, exit 1 and report extra."""
        self._setup_synced_environment()
        with open(os.path.join(self.mock_sys_ui, "orphan_file.txt"), "w") as f:
            f.write("unexpected")
        res = self._run_install("--check-sync")
        self.assertEqual(res.returncode, 1)
        self.assertIn("[EXTRA] orphan_file.txt", res.stdout)
        self.assertIn("Sync drift detected", res.stdout)

    def test_check_sync_missing_quickshell_dir(self):
        """When quickshell config directory is missing, exit 1 and report missing."""
        self._setup_synced_environment()
        shutil.rmtree(self.mock_qs_dir)
        res = self._run_install("--check-sync")
        self.assertEqual(res.returncode, 1)
        self.assertIn("[MISSING] Quickshell config directory does not exist", res.stdout)
        self.assertIn("Sync drift detected", res.stdout)

    def test_check_sync_missing_quickshell_file(self):
        """When loqControl.qml is missing from quickshell config, exit 1."""
        self._setup_synced_environment()
        os.remove(os.path.join(self.mock_qs_dir, "loqControl.qml"))
        res = self._run_install("--check-sync")
        self.assertEqual(res.returncode, 1)
        self.assertIn("[MISSING] loqControl.qml", res.stdout)
        self.assertIn("Sync drift detected", res.stdout)

    def test_check_sync_divergent_quickshell_file(self):
        """When quickshell loqControl.qml diverges, exit 1 and report diff."""
        self._setup_synced_environment()
        with open(os.path.join(self.mock_qs_dir, "loqControl.qml"), "a") as f:
            f.write("\n// divergent user config\n")
        res = self._run_install("--check-sync")
        self.assertEqual(res.returncode, 1)
        self.assertIn("[DIFF] loqControl.qml differs between repo and user quickshell config", res.stdout)
        self.assertIn("Sync drift detected", res.stdout)

    def test_check_sync_divergent_quickshell_bar_icon(self):
        """When bar module exists in quickshell, verify LoqRingIcon.qml synchronization."""
        self._setup_synced_environment()
        bar_dir = os.path.join(self.mock_qs_dir, "modules", "ii", "bar")
        os.makedirs(bar_dir, exist_ok=True)
        # Create divergent bar icon
        with open(os.path.join(bar_dir, "LoqRingIcon.qml"), "w") as f:
            f.write("// different icon\n")
        res = self._run_install("--check-sync")
        self.assertEqual(res.returncode, 1)
        self.assertIn("[DIFF] modules/ii/bar/LoqRingIcon.qml differs from repo", res.stdout)

    def test_install_usable_without_sudo_for_check_sync(self):
        """Verify that --check-sync can run as non-root user without permission rejection."""
        self._setup_synced_environment()
        res = self._run_install("--check-sync")
        # Ensure it didn't fail due to root permission check
        self.assertNotIn("install.sh must be run with sudo/root permissions", res.stderr)

    def test_install_without_root_fails_for_full_install(self):
        """Verify that running install.sh without --check-sync as non-root fails with error message."""
        res = self._run_install()
        self.assertEqual(res.returncode, 1)
        self.assertIn("Error: install.sh must be run with sudo/root permissions", res.stderr)

    def test_install_help_flag(self):
        """Verify -h and --help display usage without requiring sudo."""
        for flag in ["-h", "--help"]:
            res = self._run_install(flag)
            self.assertEqual(res.returncode, 0)
            self.assertIn("Usage:", res.stdout)
            self.assertIn("--check-sync", res.stdout)


class TestLoqerCandidateResolution(unittest.TestCase):
    """Tests for bin/loqer candidate search order and path resolution."""

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp(prefix="loq_candidate_test_")
        # Create an isolated clone of bin/loqer with NO sibling ../ui
        self.isolated_bin_dir = os.path.join(self.temp_dir, "isolated", "bin")
        os.makedirs(self.isolated_bin_dir, exist_ok=True)
        self.isolated_loqer = os.path.join(self.isolated_bin_dir, "loqer")
        shutil.copy(LOQER_BIN, self.isolated_loqer)
        os.chmod(self.isolated_loqer, 0o755)

        # Mock directories for lower priority candidates
        self.mock_sys = os.path.join(self.temp_dir, "sys_ui")
        self.mock_pkg = os.path.join(self.temp_dir, "pkg_ui")
        self.mock_user_share = os.path.join(self.temp_dir, "user_share_ui")
        self.mock_user_config = os.path.join(self.temp_dir, "user_config_ui")

        for d in [self.mock_sys, self.mock_pkg, self.mock_user_share, self.mock_user_config]:
            os.makedirs(d, exist_ok=True)

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def _create_qml_file(self, directory, content="// loqControl"):
        os.makedirs(directory, exist_ok=True)
        path = os.path.join(directory, "loqControl.qml")
        with open(path, "w") as f:
            f.write(content)
        return path

    def _run_loqer(self, binary_path=None, args=None, env=None, cwd=None):
        cmd = [binary_path or LOQER_BIN]
        if args is not None:
            cmd.extend(args)
        else:
            cmd.append("--print-path")

        run_env = os.environ.copy()
        run_env["LOQER_FORCE_DEVICE"] = "1"
        run_env["LOQER_SYSTEM_UI_DIR"] = self.mock_sys
        run_env["LOQER_PKG_UI_DIR"] = self.mock_pkg
        run_env["LOQER_USER_SHARE_DIR"] = self.mock_user_share
        run_env["LOQER_USER_CONFIG_DIR"] = self.mock_user_config
        if env:
            run_env.update(env)

        return subprocess.run(
            cmd,
            cwd=cwd or self.temp_dir,
            capture_output=True,
            text=True,
            env=run_env,
        )

    def test_candidate_1_explicit_loqer_ui_path_override(self):
        """Candidate 1: LOQER_UI_PATH environment variable takes highest priority."""
        custom_file = self._create_qml_file(os.path.join(self.temp_dir, "custom"))
        # Also populate system and user config candidates to prove override wins
        self._create_qml_file(self.mock_sys)
        self._create_qml_file(self.mock_user_config)

        res = self._run_loqer(env={"LOQER_UI_PATH": custom_file})
        self.assertEqual(res.returncode, 0)
        lines = [line.strip() for line in res.stdout.strip().splitlines() if line.strip()]
        self.assertEqual(lines[-1], custom_file)

    def test_candidate_2_repo_source(self):
        """Candidate 2: When running from repo checkout, SCRIPT_DIR/../ui is resolved."""
        # Lower candidates also exist, but repo source should win
        self._create_qml_file(self.mock_sys)
        self._create_qml_file(self.mock_user_config)

        res = self._run_loqer(binary_path=LOQER_BIN)
        self.assertEqual(res.returncode, 0)
        expected = os.path.abspath(os.path.join(REPO_ROOT, "bin", "..", "ui", "loqControl.qml"))
        lines = [line.strip() for line in res.stdout.strip().splitlines() if line.strip()]
        self.assertEqual(os.path.abspath(lines[-1]), expected)

    def test_candidate_3_cwd_ui(self):
        """Candidate 3: In isolated binary with no sibling ../ui, pwd/ui/loqControl.qml is resolved."""
        cwd_dir = os.path.join(self.temp_dir, "cwd_test")
        cwd_ui_file = self._create_qml_file(os.path.join(cwd_dir, "ui"))
        self._create_qml_file(self.mock_sys)

        res = self._run_loqer(binary_path=self.isolated_loqer, cwd=cwd_dir)
        self.assertEqual(res.returncode, 0)
        lines = [line.strip() for line in res.stdout.strip().splitlines() if line.strip()]
        self.assertEqual(os.path.abspath(lines[-1]), os.path.abspath(cwd_ui_file))

    def test_candidate_4_system_ui(self):
        """Candidate 4: System install directory (/usr/local/share/loqer/ui)."""
        sys_file = self._create_qml_file(self.mock_sys)
        self._create_qml_file(self.mock_pkg)
        self._create_qml_file(self.mock_user_config)

        res = self._run_loqer(binary_path=self.isolated_loqer)
        self.assertEqual(res.returncode, 0)
        lines = [line.strip() for line in res.stdout.strip().splitlines() if line.strip()]
        self.assertEqual(os.path.abspath(lines[-1]), os.path.abspath(sys_file))

    def test_candidate_5_pkg_ui(self):
        """Candidate 5: Distro package directory (/usr/share/loqer/ui)."""
        pkg_file = self._create_qml_file(self.mock_pkg)
        self._create_qml_file(self.mock_user_share)
        self._create_qml_file(self.mock_user_config)

        res = self._run_loqer(binary_path=self.isolated_loqer)
        self.assertEqual(res.returncode, 0)
        lines = [line.strip() for line in res.stdout.strip().splitlines() if line.strip()]
        self.assertEqual(os.path.abspath(lines[-1]), os.path.abspath(pkg_file))

    def test_candidate_6_user_share_ui(self):
        """Candidate 6: User local share (~/.local/share/loqer/ui)."""
        user_share_file = self._create_qml_file(self.mock_user_share)
        self._create_qml_file(self.mock_user_config)

        res = self._run_loqer(binary_path=self.isolated_loqer)
        self.assertEqual(res.returncode, 0)
        lines = [line.strip() for line in res.stdout.strip().splitlines() if line.strip()]
        self.assertEqual(os.path.abspath(lines[-1]), os.path.abspath(user_share_file))

    def test_candidate_7_user_config_ui(self):
        """Candidate 7: Quickshell user config (~/.config/quickshell/ii)."""
        user_config_file = self._create_qml_file(self.mock_user_config)

        res = self._run_loqer(binary_path=self.isolated_loqer)
        self.assertEqual(res.returncode, 0)
        lines = [line.strip() for line in res.stdout.strip().splitlines() if line.strip()]
        self.assertEqual(os.path.abspath(lines[-1]), os.path.abspath(user_config_file))

    def test_candidates_none_found(self):
        """When no candidate exists anywhere, loqer exits with code 1 and error message."""
        res = self._run_loqer(binary_path=self.isolated_loqer)
        self.assertEqual(res.returncode, 1)
        self.assertIn("Error: Could not locate loqControl.qml in standard paths.", res.stderr)


class TestLoqerDivergenceNotice(unittest.TestCase):
    """Tests for loqControl.qml version divergence diagnostic notices."""

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp(prefix="loq_diverge_test_")
        self.mock_sys = os.path.join(self.temp_dir, "sys_ui")
        self.mock_user_config = os.path.join(self.temp_dir, "user_config_ui")
        os.makedirs(self.mock_sys, exist_ok=True)
        os.makedirs(self.mock_user_config, exist_ok=True)

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def _run_loqer(self, env_overrides=None, args=None):
        cmd = [LOQER_BIN]
        if args is not None:
            cmd.extend(args)
        else:
            cmd.append("--print-path")

        env = os.environ.copy()
        env["LOQER_FORCE_DEVICE"] = "1"
        env["LOQER_SYSTEM_UI_DIR"] = self.mock_sys
        env["LOQER_USER_CONFIG_DIR"] = self.mock_user_config
        # Neutralize other search paths
        env["LOQER_PKG_UI_DIR"] = os.path.join(self.temp_dir, "empty_pkg")
        env["LOQER_USER_SHARE_DIR"] = os.path.join(self.temp_dir, "empty_share")
        if env_overrides:
            env.update(env_overrides)

        return subprocess.run(
            cmd,
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            env=env,
        )

    def test_divergence_notice_displayed_when_divergent(self):
        """When installed copy diverges from repo source, display diagnostic notice."""
        # Create divergent system file
        with open(os.path.join(self.mock_sys, "loqControl.qml"), "w") as f:
            f.write("// different version\n")

        res = self._run_loqer()
        self.assertEqual(res.returncode, 0)
        combined = res.stdout + res.stderr
        self.assertIn("[LOQer] Notice: UI file loaded from", combined)

    def test_divergence_notice_suppressed_when_in_sync(self):
        """When installed copy has identical content to repo source, do not display notice."""
        repo_qml = os.path.join(REPO_ROOT, "ui", "loqControl.qml")
        shutil.copy(repo_qml, os.path.join(self.mock_sys, "loqControl.qml"))
        shutil.copy(repo_qml, os.path.join(self.mock_user_config, "loqControl.qml"))

        res = self._run_loqer()
        self.assertEqual(res.returncode, 0)
        combined = res.stdout + res.stderr
        self.assertNotIn("[LOQer] Notice: UI file loaded from", combined)

    def test_divergence_notice_suppressed_when_explicit_override(self):
        """When LOQER_UI_PATH is explicitly set, diagnostic notice is suppressed even if divergent."""
        with open(os.path.join(self.mock_sys, "loqControl.qml"), "w") as f:
            f.write("// different version\n")
        custom_file = os.path.join(self.temp_dir, "custom.qml")
        with open(custom_file, "w") as f:
            f.write("// custom qml\n")

        res = self._run_loqer(env_overrides={"LOQER_UI_PATH": custom_file})
        self.assertEqual(res.returncode, 0)
        combined = res.stdout + res.stderr
        self.assertNotIn("[LOQer] Notice: UI file loaded from", combined)

    def test_mock_qs_invocation(self):
        """Verify loqer invokes quickshell 'qs -p <TARGET_CONFIG>' when launching normally."""
        # Put mock qs script in PATH
        mock_bin_dir = os.path.join(self.temp_dir, "bin")
        os.makedirs(mock_bin_dir, exist_ok=True)
        mock_qs = os.path.join(mock_bin_dir, "qs")
        with open(mock_qs, "w") as f:
            f.write("#!/usr/bin/env bash\necho \"MOCK_QS_CALLED: $@\"\nexit 0\n")
        os.chmod(mock_qs, 0o755)

        # Run loqer without --print-path and without LOQER_DRY_RUN
        env = {
            "PATH": f"{mock_bin_dir}:{os.environ['PATH']}",
            "LOQER_DRY_RUN": "0",
        }
        res = self._run_loqer(args=[], env_overrides=env)
        self.assertEqual(res.returncode, 0, f"Failed: {res.stderr}\n{res.stdout}")
        self.assertIn("MOCK_QS_CALLED: -p", res.stdout)
        self.assertIn("loqControl.qml", res.stdout)


if __name__ == "__main__":
    unittest.main()
