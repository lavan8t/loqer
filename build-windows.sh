#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo "============================================="
echo "  Building Loqer for Windows x64 via MinGW   "
echo "============================================="

# 1. Configure CMake
echo "[1/3] Configuring CMake with mingw64-cmake..."
mingw64-cmake -B build-win -S windows -DCMAKE_BUILD_TYPE=Release

# 2. Build executable
echo "[2/3] Compiling loqer.exe..."
cmake --build build-win --parallel "$(nproc)"

# 3. Package into portable distribution
echo "[3/3] Packaging standalone Windows distribution..."
python3 scripts/package-windows.py

echo "============================================="
echo "  Windows build completed successfully!      "
echo "============================================="
