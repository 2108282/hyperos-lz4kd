### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers & GKI 2.0
properties() { '
kernel.string=Xiaomi 14 (houji) GKI 6.1 with LZ4KD
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=houji
'; }

block=boot;
is_slot_device=auto;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;
no_magisk_check=1;

. tools/ak3-core.sh;

split_boot;

if [ -f "$SPLITIMG/ramdisk.cpio" ]; then
    unpack_ramdisk;
    write_boot;
else
    flash_boot;
fi;
