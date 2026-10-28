#!/usr/bin/env python3
import os
import sys
import shutil
import subprocess
import zipfile

MINGW_ROOT = "/usr/x86_64-w64-mingw32/sys-root/mingw"
MINGW_BIN = os.path.join(MINGW_ROOT, "bin")
MINGW_PLUGINS = os.path.join(MINGW_ROOT, "lib/qt6/plugins")
MINGW_QML = os.path.join(MINGW_ROOT, "lib/qt6/qml")

SYSTEM_DLLS = {
    "kernel32.dll", "user32.dll", "gdi32.dll", "advapi32.dll", "msvcrt.dll",
    "shell32.dll", "ole32.dll", "oleaut32.dll", "ws2_32.dll", "comctl32.dll",
    "comdlg32.dll", "shlwapi.dll", "version.dll", "imm32.dll", "winmm.dll",
    "uxtheme.dll", "dwmapi.dll", "crypt32.dll", "netapi32.dll", "secur32.dll",
    "userenv.dll", "iphlpapi.dll", "wtsapi32.dll", "wbemuuid.dll", "setupapi.dll",
    "mpr.dll", "dnsapi.dll", "d3d11.dll", "dxgi.dll", "d3d9.dll", "d3d12.dll",
    "opengl32.dll", "ncrypt.dll", "authz.dll", "dwrite.dll", "winhttp.dll",
    "ntdll.dll", "shcore.dll"
}

def get_imported_dlls(filepath):
    res = subprocess.run(["x86_64-w64-mingw32-objdump", "-p", filepath],
                         capture_output=True, text=True)
    dlls = []
    for line in res.stdout.splitlines():
        if "DLL Name:" in line:
            dlls.append(line.split("DLL Name:")[1].strip())
    return dlls

def strip_binary(filepath):
    subprocess.run(["x86_64-w64-mingw32-strip", "--strip-unneeded", filepath],
                   capture_output=True)

def main():
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    build_dir = os.path.join(root_dir, "build-win")
    dist_dir = os.path.join(root_dir, "dist")
    package_dir = os.path.join(dist_dir, "loqer-windows-x64")
    exe_src = os.path.join(build_dir, "loqer.exe")

    if not os.path.exists(exe_src):
        print(f"Error: {exe_src} not found. Please build first.")
        sys.exit(1)

    print(f"[*] Packaging Loqer Windows x64 into {package_dir}...")
    if os.path.exists(package_dir):
        shutil.rmtree(package_dir)
    os.makedirs(package_dir, exist_ok=True)

    # 1. Copy main executable
    exe_dst = os.path.join(package_dir, "loqer.exe")
    shutil.copy2(exe_src, exe_dst)
    strip_binary(exe_dst)

    # 2. Copy platforms/qwindows.dll
    platforms_dst = os.path.join(package_dir, "platforms")
    os.makedirs(platforms_dst, exist_ok=True)
    qwindows_src = os.path.join(MINGW_PLUGINS, "platforms", "qwindows.dll")
    if os.path.exists(qwindows_src):
        qwindows_dst = os.path.join(platforms_dst, "qwindows.dll")
        shutil.copy2(qwindows_src, qwindows_dst)
        strip_binary(qwindows_dst)

    # 3. Copy imageformats plugins (qjpeg, qsvg)
    imageformats_dst = os.path.join(package_dir, "imageformats")
    os.makedirs(imageformats_dst, exist_ok=True)
    for img_plugin in ["qjpeg.dll", "qsvg.dll"]:
        img_src = os.path.join(MINGW_PLUGINS, "imageformats", img_plugin)
        if os.path.exists(img_src):
            img_dst = os.path.join(imageformats_dst, img_plugin)
            shutil.copy2(img_src, img_dst)
            strip_binary(img_dst)

    # 4. Copy required QML modules
    qml_dst = os.path.join(package_dir, "qml")
    os.makedirs(qml_dst, exist_ok=True)

    qml_modules_to_copy = [
        "QtQuick/Controls/Basic",
        "QtQuick/Controls/impl",
        "QtQuick/Controls",
        "QtQuick/Layouts",
        "QtQuick/Shapes",
        "QtQuick/Templates",
        "QtQuick/Window"
    ]

    for mod in qml_modules_to_copy:
        src_mod = os.path.join(MINGW_QML, mod)
        dst_mod = os.path.join(qml_dst, mod)
        if os.path.exists(src_mod):
            shutil.copytree(src_mod, dst_mod, dirs_exist_ok=True)

    # Strip all dlls inside qml_dst
    for root, _, files in os.walk(qml_dst):
        for f in files:
            if f.endswith(".dll"):
                strip_binary(os.path.join(root, f))

    # 5. Resolve and copy all recursive DLL dependencies
    needed_dlls = set()
    to_scan = [exe_dst, os.path.join(platforms_dst, "qwindows.dll")]

    for root, _, files in os.walk(package_dir):
        for f in files:
            if f.endswith(".dll"):
                to_scan.append(os.path.join(root, f))

    scanned = set()
    while to_scan:
        cur = to_scan.pop(0)
        scanned.add(cur)
        for dll in get_imported_dlls(cur):
            dll_lower = dll.lower()
            if dll_lower in SYSTEM_DLLS or dll_lower.startswith("api-ms-win-"):
                continue
            needed_dlls.add(dll)
            src_candidate = os.path.join(MINGW_BIN, dll)
            if os.path.exists(src_candidate) and src_candidate not in scanned and src_candidate not in to_scan:
                to_scan.append(src_candidate)

    print(f"[*] Found {len(needed_dlls)} runtime DLL dependencies.")
    for dll in sorted(needed_dlls):
        src_dll = os.path.join(MINGW_BIN, dll)
        if os.path.exists(src_dll):
            dst_dll = os.path.join(package_dir, dll)
            shutil.copy2(src_dll, dst_dll)
            strip_binary(dst_dll)
            print(f"    + {dll} ({os.path.getsize(dst_dll) / 1024:.1f} KB)")
        else:
            print(f"    ! Warning: {dll} not found in {MINGW_BIN}")

    # 6. Create portable ZIP package
    zip_path = os.path.join(dist_dir, "loqer-windows-x64.zip")
    print(f"[*] Creating {zip_path}...")
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zipf:
        for root, _, files in os.walk(package_dir):
            for file in files:
                abs_path = os.path.join(root, file)
                rel_path = os.path.relpath(abs_path, dist_dir)
                zipf.write(abs_path, rel_path)

    zip_size_mb = os.path.getsize(zip_path) / (1024 * 1024)
    print(f"[✓] Successfully packaged {zip_path}")
    print(f"[✓] Package size: {zip_size_mb:.2f} MB")

if __name__ == "__main__":
    main()
