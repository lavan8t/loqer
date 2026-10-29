# Agent Instructions

- **Package Manager**: Always use `bun` and `bunx`. Never use `npm`, `npx`, `yarn`, or `pnpm`.
- **Git Commits**: Always commit with `--no-gpg-sign`.

## Agent skills

### Issue tracker

GitHub issues tracked via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Canonical five-role triage labels (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context repository layout (`GLOSSARY.md` + `docs/adr/`). See `docs/agents/domain.md`.

## File Hierarchy & Single Source of Truth

- **Source files (Repository)**:
  - `ui/`: Canonical Quickshell QML interface sources (`loqControl.qml`, fonts, modules, services).
  - `bin/`: CLI tools, daemons, and core executables (`loqer`, `loq-ctl`, `lenovo-power-daemon`, `loq-hw-write`, `loq-generate-icon`, `set-panel-refresh`, `prime-run`).
- **Quickshell Integration**:
  - `~/.config/quickshell/ii/`: User-level desktop shell configuration. `install.sh` synchronizes `loqControl.qml`, bundled fonts, and panel bar modules (`modules/ii/bar/LoqRingIcon.qml`) here.
- **System Installation**:
  - `/usr/local/share/loqer/ui/`: System-wide shared UI files and assets.
  - `/usr/local/bin/`: System-wide installed core binaries.
- **Synchronization**:
  - To install or sync source changes across the system and user configurations, run:
    `./install.sh`
    or via passwordless sudo helper:
    `sudo -n /usr/local/bin/loq-hw-write "./install.sh"`
- **Sync Verification**:
  - Run `./install.sh --check-sync` (usable without sudo).
  - Compares files between repo `ui/`, system install `/usr/local/share/loqer/ui/`, and user quickshell config `~/.config/quickshell/ii/`.
  - Exits with `0` when all locations are synchronized, or `1` if drift is detected.
- **Runtime Candidate Resolution**:
  - `bin/loqer` searches for `loqControl.qml` in the following priority order:
    1. `$LOQER_UI_PATH` (explicit environment override)
    2. `${SCRIPT_DIR}/../ui/loqControl.qml` (repository checkout source)
    3. `$(pwd)/ui/loqControl.qml` (current working directory source)
    4. `/usr/local/share/loqer/ui/loqControl.qml` (system install)
    5. `/usr/share/loqer/ui/loqControl.qml` (distribution package install)
    6. `~/.local/share/loqer/ui/loqControl.qml` (user local share install)
    7. `~/.config/quickshell/ii/loqControl.qml` (quickshell desktop configuration)
  - If `$LOQER_UI_PATH` is not explicitly set and divergence between repository source and installed targets is detected, `bin/loqer` issues a diagnostic notice: `[LOQer] Notice: UI file loaded from <path>`.

## Testing & Quality Guardrails

- **Full Check Suite**:
  - Run `./scripts/check.sh` before committing or pushing changes. Validates:
    1. Python script compilation (`py_compile`).
    2. Unit test suite execution (`python3 tests/run_tests.py`).
    3. Shell script syntax validation (`bash -n`).
    4. QML syntax linting via `qmllint` (if present in PATH).
- **Unit Test Runner**:
  - Run `python3 tests/run_tests.py` to discover and execute all unit tests in `tests/test_*.py`.
  - Tests utilize `tests/hardware_mock.py` to safely mock `/sys` and `/proc` hardware interfaces without requiring root privileges.
- **Pre-commit Hook**:
  - Automatically installed by `./scripts/setup-git-hooks.sh` during `./install.sh`.
  - Enforces running `./scripts/check.sh` prior to every git commit.

## Hardware & Privileged Execution

- **Sudoers Permissions**:
  - Sudoers configuration in `/etc/sudoers.d/loqer` allows passwordless execution (`NOPASSWD`) for:
    - `/usr/local/bin/loq-ctl`
    - `/usr/local/bin/loq-hw-write`
    - `/usr/local/bin/loqer`
    - `${USER_HOME}/.local/bin/loqer`
    - `/usr/local/bin/loq-generate-icon`
- **Privileged Commands & Hardware Writes**:
  - To execute arbitrary privileged scripts, perform hardware node writes, or run installation routines without interactive password prompts, use:
    `sudo -n /usr/local/bin/loq-hw-write "<command>"`
