#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Package LZ4KD ZRAM Driver Module for Xiaomi 14 (HyperOS / Android 14 GKI 6.1)
"""

import os
import sys
import glob
import shutil
import zipfile

def main():
    dist_dirs = glob.glob("android-kernel/out/*/dist")
    outdir = dist_dirs[0] if dist_dirs else "android-kernel/dist"
    print(f"[+] Searching zram.ko in {outdir}...")

    zram_kos = glob.glob(f"{outdir}/**/zram.ko", recursive=True)
    if not zram_kos:
        print(f"[-] ERROR: zram.ko not found in {outdir}")
        if os.path.exists(outdir):
            print(os.listdir(outdir))
        sys.exit(1)

    zram_ko = zram_kos[0]
    print(f"[+] Found zram.ko at: {zram_ko} (size: {os.path.getsize(zram_ko)} bytes)")

    mod_dir = "lz4kd_driver_module"
    if os.path.exists(mod_dir):
        shutil.rmtree(mod_dir)

    p_meta = os.path.join(mod_dir, "META-INF", "com", "google", "android")
    p_flat = os.path.join(mod_dir, "system_dlkm", "flatten", "lib", "modules")
    p_full = os.path.join(mod_dir, "system_dlkm", "lib", "modules", "6.1.138-android14-11-g0c3d559bcd85-ab14529422", "kernel", "drivers", "block", "zram")

    os.makedirs(p_meta, exist_ok=True)
    os.makedirs(p_flat, exist_ok=True)
    os.makedirs(p_full, exist_ok=True)

    prop_content = """id=xiaomi14_lz4kd_zram
name=小米14 LZ4KD ZRAM 驱动模块
version=v1.0
versionCode=100
author=YukongA & PairDev
description=为小米 14 (HyperOS / Android 14 GKI 6.1) 提供包含 LZ4KD 原生菜单支持的 ZRAM 核心驱动，Scene 可直接识别并接管。
"""
    with open(os.path.join(mod_dir, "module.prop"), "w", encoding="utf-8") as f:
        f.write(prop_content)

    with open(os.path.join(p_meta, "updater-script"), "w", encoding="utf-8") as f:
        f.write("#MAGISK\n")

    update_bin = """#!/sbin/sh
OUTFD=$2
ZIPFILE=$3

ui_print() {
  echo -e "ui_print $1\\nui_print" > /proc/self/fd/$OUTFD
}

ui_print "************************************"
ui_print "*   小米 14 LZ4KD ZRAM 驱动模块    *"
ui_print "*   适配 Android 14 GKI 6.1 内核   *"
ui_print "************************************"

if [ -z "$MODPATH" ]; then
  MODPATH="/data/adb/modules/xiaomi14_lz4kd_zram"
fi

rm -rf "$MODPATH"
mkdir -p "$MODPATH"
unzip -o "$ZIPFILE" -d "$MODPATH" "system_dlkm/*" "module.prop" >&2

chmod -R 755 "$MODPATH"
find "$MODPATH" -type f -exec chmod 644 {} +

ui_print "- 正在部署同源编译的 LZ4KD ZRAM 核心驱动..."
ui_print "- 驱动原生包含 lz4kd 菜单项"
ui_print "- 安装完成！请重启手机，开机后 Scene 下拉菜单即可直接选择 lz4kd。"
exit 0
"""
    p_bin = os.path.join(p_meta, "update-binary")
    with open(p_bin, "w", encoding="utf-8") as f:
        f.write(update_bin)
    os.chmod(p_bin, 0o755)

    shutil.copy2(zram_ko, os.path.join(p_flat, "zram.ko"))
    shutil.copy2(zram_ko, os.path.join(p_full, "zram.ko"))

    zip_name = "LZ4KD_ZRAM_Driver_Module.zip"
    with zipfile.ZipFile(zip_name, "w", zipfile.ZIP_DEFLATED) as zf:
        for root, dirs, files in os.walk(mod_dir):
            for file in files:
                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, mod_dir)
                zf.write(full_path, rel_path)

    print(f"[+] {zip_name} packaged successfully! Size: {os.path.getsize(zip_name)} bytes")

if __name__ == "__main__":
    main()
