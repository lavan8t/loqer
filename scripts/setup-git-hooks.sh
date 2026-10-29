#!/usr/bin/env bash
# Installs git hooks for the LOQer repository.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GIT_DIR="$REPO_ROOT/.git"

if [ ! -d "$GIT_DIR" ]; then
    echo "Error: .git directory not found in $REPO_ROOT" >&2
    exit 1
fi

HOOKS_DIR="$GIT_DIR/hooks"
mkdir -p "$HOOKS_DIR"

PRE_COMMIT_HOOK="$HOOKS_DIR/pre-commit"

cat << 'EOF' > "$PRE_COMMIT_HOOK"
#!/usr/bin/env bash
# Git pre-commit hook for LOQer
# Runs the quality guardrail check before committing.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "Running pre-commit quality guardrail checks..."
if [ -x "$REPO_ROOT/scripts/check.sh" ]; then
    "$REPO_ROOT/scripts/check.sh"
elif [ -f "$REPO_ROOT/scripts/check.sh" ]; then
    bash "$REPO_ROOT/scripts/check.sh"
else
    echo "Warning: scripts/check.sh not found, skipping pre-commit checks."
fi
EOF

chmod +x "$PRE_COMMIT_HOOK"
echo "Successfully installed pre-commit hook at $PRE_COMMIT_HOOK"
