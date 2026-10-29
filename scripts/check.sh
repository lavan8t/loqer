#!/usr/bin/env bash
# LOQer quality guardrails check script.
# Fast deterministic checks: syntax compilation, unit test suite, shell script syntax, and QML linting.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "=== LOQer Quality Guardrails ==="

# Step 1: Python compilation
echo "[Step 1/4] Compiling Python scripts with py_compile..."
PYTHON_FILES=(
    "$REPO_ROOT/bin/loq-ctl"
    "$REPO_ROOT/bin/lenovo-power-daemon"
    "$REPO_ROOT/bin/loq-generate-icon"
    "$REPO_ROOT"/tests/*.py
)
if [ -f "$REPO_ROOT/scripts/package-windows.py" ]; then
    PYTHON_FILES+=("$REPO_ROOT/scripts/package-windows.py")
fi
python3 -m py_compile "${PYTHON_FILES[@]}"
echo "✓ Python syntax compilation successful."

# Step 2: Run unit test suite
echo "[Step 2/4] Running unit test suite..."
python3 "$REPO_ROOT/tests/run_tests.py"
echo "✓ Unit test suite passed."

# Step 3: Shell script syntax checks
echo "[Step 3/4] Validating shell scripts with bash -n..."
SHELL_SCRIPTS=(
    "$REPO_ROOT/bin/loqer"
    "$REPO_ROOT/bin/set-panel-refresh"
    "$REPO_ROOT/bin/prime-run"
    "$REPO_ROOT/bin/loq-hw-write"
    "$REPO_ROOT/install.sh"
    "$REPO_ROOT/uninstall.sh"
    "$REPO_ROOT/build-windows.sh"
    "$REPO_ROOT/scripts/check.sh"
    "$REPO_ROOT/scripts/setup-git-hooks.sh"
)
for script in "${SHELL_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        bash -n "$script"
    fi
done
echo "✓ Shell script syntax validation passed."

# Step 4: QML validation
echo "[Step 4/4] Validating QML files..."
if command -v qmllint >/dev/null 2>&1; then
    qmllint "$REPO_ROOT/ui/loqControl.qml"
    echo "✓ QML linting passed."
else
    echo "qmllint not found in PATH; skipping QML validation."
fi

echo "================================"
echo "All quality guardrails passed successfully!"
