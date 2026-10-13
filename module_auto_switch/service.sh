#!/system/bin/sh
# Wait until system is booted
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 2
done

# Ensure lz4kd is supported
if grep -q "lz4kd" /proc/crypto 2>/dev/null; then
    DEV_NUM=$(cat /sys/block/zram0/dev 2>/dev/null)
    MAJOR=${DEV_NUM%:*}
    MINOR=${DEV_NUM#*:}
    
    ZNODE="/dev/zram0_fix"
    rm -f "$ZNODE" 2>/dev/null
    mknod "$ZNODE" b "$MAJOR" "$MINOR" 2>/dev/null || mknod "$ZNODE" b 253 0
    chmod 660 "$ZNODE"

    swapoff "$ZNODE" 2>/dev/null || swapoff /dev/block/zram0 2>/dev/null || true
    echo 1 > /sys/block/zram0/reset 2>/dev/null
    echo lz4kd > /sys/block/zram0/comp_algorithm 2>/dev/null
    echo 17179869184 > /sys/block/zram0/disksize 2>/dev/null
    mkswap "$ZNODE" 2>/dev/null
    swapon "$ZNODE" 2>/dev/null
fi
