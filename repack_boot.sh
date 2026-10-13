#!/bin/bash
# ==============================================================================
# 小米 14 (houji) GKI 内核继承式缝合脚本
# 用途：将云编译出的新内核二进制（Image）安全替换进原装 96MB boot.img 底包
# 特性：严格保留原厂 Boot Header v4、TWRP、Ramdisk、AVB 签名链与 100663296 字节对齐
# 支持无参自动探测，也支持自定义参数: ./repack_boot.sh [stock_boot] [new_image] [output]
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="/tmp/kernel_repack_$(date +%s)"

# 1. 自动探测或接收原版底包 boot.img
STOCK_BOOT="${1:-${SCRIPT_DIR}/boot.img}"
if [ ! -f "$STOCK_BOOT" ]; then
    STOCK_BOOT="/sdcard/Download/DSHA/工作区/boot.img"
fi
if [ ! -f "$STOCK_BOOT" ]; then
    STOCK_BOOT="/sdcard/Download/boot.img"
fi
if [ ! -f "$STOCK_BOOT" ]; then
    echo "[-] 错误：找不到原装救砖底包 boot.img！请将其放置在脚本同级目录或作为参数传入。"
    echo "    用法: $0 [stock_boot.img] [Image] [output.img]"
    exit 1
fi

# 2. 自动探测或接收新编译的 Image
NEW_IMAGE="${2:-${SCRIPT_DIR}/Image}"
if [ ! -f "$NEW_IMAGE" ] && [ -f "${SCRIPT_DIR}/Raw_Kernel_and_Boot.zip" ]; then
    echo "[*] 从同级 Raw_Kernel_and_Boot.zip 中解压提取 Image..."
    unzip -p "${SCRIPT_DIR}/Raw_Kernel_and_Boot.zip" Image > "/tmp/temp_Image"
    NEW_IMAGE="/tmp/temp_Image"
elif [ ! -f "$NEW_IMAGE" ] && [ -f "/sdcard/Download/DSHA/工作区/Raw_Kernel_and_Boot.zip" ]; then
    echo "[*] 从工作区 Raw_Kernel_and_Boot.zip 中解压提取 Image..."
    unzip -p "/sdcard/Download/DSHA/工作区/Raw_Kernel_and_Boot.zip" Image > "/tmp/temp_Image"
    NEW_IMAGE="/tmp/temp_Image"
fi

if [ ! -f "$NEW_IMAGE" ]; then
    echo "[-] 错误：找不到新编译的 Image 二进制文件！"
    exit 1
fi

# 3. 自动探测 64 位 magiskboot 工具
MAGISKBOOT="${SCRIPT_DIR}/magiskboot"
if [ ! -f "$MAGISKBOOT" ]; then
    MAGISKBOOT="${SCRIPT_DIR}/tools_arm64/magiskboot"
fi
if [ ! -f "$MAGISKBOOT" ]; then
    MAGISKBOOT="${SCRIPT_DIR}/magiskboot_64"
fi
if [ ! -f "$MAGISKBOOT" ]; then
    MAGISKBOOT="/sdcard/Download/DSHA/工作区/magiskboot_64"
fi
if [ ! -f "$MAGISKBOOT" ]; then
    MAGISKBOOT=$(which magiskboot 2>/dev/null || true)
fi

if [ ! -f "$MAGISKBOOT" ]; then
    echo "[-] 错误：找不到 64 位 magiskboot 工具！"
    exit 1
fi

OUTPUT_BOOT="${3:-${SCRIPT_DIR}/final_lz4kd_boot.img}"

echo "========================================================"
echo "[+] 小米 14 GKI 内核继承式缝合流程开始"
echo "    - 原装底包: $STOCK_BOOT"
echo "    - 内核本体: $NEW_IMAGE"
echo "    - 封包工具: $MAGISKBOOT"
echo "========================================================"

# 4. 创建独立临时工作区
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

cp -f "$STOCK_BOOT" ./stock_boot.img
cp -f "$NEW_IMAGE" ./new_Image
cp -f "$MAGISKBOOT" ./magiskboot
chmod 755 ./magiskboot

# 5. 解包原版底包
echo "[+] Step 1: 解包原装 boot.img (解析 Header v4 与签名结构)..."
./magiskboot unpack stock_boot.img

# 6. 原位替换内核本体
echo "[+] Step 2: 替换内核本体 (将原版 kernel 替换为含 LZ4KD 的新 Image)..."
cp -f ./new_Image ./kernel

# 7. 继承重封包
echo "[+] Step 3: 重封包生成全新的 final_lz4kd_boot.img..."
./magiskboot repack stock_boot.img final_lz4kd_boot.img

# 8. 严格校验文件大小
STOCK_SZ=$(stat -c "%s" stock_boot.img)
FINAL_SZ=$(stat -c "%s" final_lz4kd_boot.img)

echo "[+] Step 4: 校验镜像字节尺寸..."
echo "    - 原装镜像尺寸: $STOCK_SZ 字节"
echo "    - 缝合镜像尺寸: $FINAL_SZ 字节"

if [ "$STOCK_SZ" -ne "$FINAL_SZ" ]; then
    echo "[-] 警告：字节尺寸与原厂不一致！缝合可能存在结构异常！"
    exit 1
fi

echo "[+] 尺寸 100% 精确吻合 (均为 $FINAL_SZ 字节 / 96MB)！"

# 9. 输出并交付
cp -f final_lz4kd_boot.img "$OUTPUT_BOOT"
if [ -d "/sdcard/Download" ] && [ "$OUTPUT_BOOT" != "/sdcard/Download/final_lz4kd_boot.img" ]; then
    cp -f final_lz4kd_boot.img "/sdcard/Download/final_lz4kd_boot.img" 2>/dev/null || true
fi

echo "========================================================"
echo "[+] 缝合圆满完成！输出文件："
echo "    $OUTPUT_BOOT"
echo "========================================================"

# 清理临时目录
rm -rf "$WORK_DIR" "/tmp/temp_Image" 2>/dev/null || true
