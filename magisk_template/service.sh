#!/system/bin/sh
MODDIR=${0%/*}
LOGFILE="/data/local/tmp/lz4kd.log"

exec 1>> "$LOGFILE" 2>&1
echo "=== [$(date)] LZ4KD Service Started ==="

# 等待系统开机完成
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 2
done
echo "[+] System boot completed."

# 1. 动态挂载 lz4kd.ko
if ! grep -q "lz4kd" /proc/crypto 2>/dev/null; then
    echo "[*] Loading lz4kd.ko..."
    insmod "$MODDIR/lz4kd.ko"
    echo "[*] insmod exit code: $?"
fi

# 2. 检查算法注册情况
if grep -q "lz4kd" /proc/crypto 2>/dev/null; then
    echo "[+] lz4kd algorithm registered successfully in /proc/crypto!"
    
    # 3. 切换 ZRAM 压缩算法
    if [ -e /sys/block/zram0/comp_algorithm ]; then
        CUR_ALG=$(cat /sys/block/zram0/comp_algorithm)
        echo "[*] Current ZRAM algorithms: $CUR_ALG"
        
        echo "[*] Turning off swap..."
        swapoff /dev/block/zram0
        
        echo "[*] Setting comp_algorithm to lz4kd..."
        echo lz4kd > /sys/block/zram0/comp_algorithm
        
        echo "[*] Turning on swap..."
        swapon /dev/block/zram0
        
        NEW_ALG=$(cat /sys/block/zram0/comp_algorithm)
        echo "[+] New ZRAM algorithms: $NEW_ALG"
    fi
else
    echo "[-] Error: lz4kd not found in /proc/crypto after insmod."
fi

echo "=== [$(date)] LZ4KD Service Finished ==="
