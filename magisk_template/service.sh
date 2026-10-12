#!/system/bin/sh
MODDIR=${0%/*}

# 等待系统桌面启动就绪
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 2
done

# 1. 尝试动态加载 lz4kd.ko 内核驱动
if ! grep -q "lz4kd" /proc/crypto 2>/dev/null; then
    insmod "$MODDIR/lz4kd.ko" || insmod -f "$MODDIR/lz4kd.ko"
fi

# 2. 若算法成功注册，接管并重设 ZRAM
if grep -q "lz4kd" /proc/crypto 2>/dev/null; then
    if [ -e /sys/block/zram0/comp_algorithm ]; then
        swapoff /dev/block/zram0 2>/dev/null
        echo lz4kd > /sys/block/zram0/comp_algorithm
        swapon /dev/block/zram0 2>/dev/null
    fi
fi
