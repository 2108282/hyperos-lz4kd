# Android GKI 通用内核与 LZ4KD 内存压缩算法集成

> **版本**：v2.0
> **适用机型范围**：搭载 Android 13 / 14 / 15 / 16、Linux 5.10 / 5.15 / 6.1 / 6.6+ 的所有 GKI 2.0 架构设备（包括但不限于高通骁龙 8G2 / 8G3 / 8 Gen 4、天玑 9200 / 9300 / 9400 等全系旗舰与主流机型）。  
> **实测验证平台**：小米 14（代号 `houji`，高通骁龙 8 Gen 3 / SM8650 纯 64 位平台，Xiaomi HyperOS / Android 14，基线内核 `6.1.138-android14-11-g0c3d559bcd85`）。

---

## 目录
- [一、 核心认知与 GKI 架构基本盘](#一-核心认知与-gki-架构基本盘)
- [二、 目标设备“核心四要素”精准锁定 SOP](#二-目标设备核心四要素精准锁定-sop)
- [三、 华为 LZ4KD 算法核心原理与源码适配准备](#三-华为-lz4kd-算法核心原理与源码适配准备)
- [四、 正统工业级云端构建流水线 (GitHub Actions + ACK)](#四-正统工业级云端构建流水线-github-actions--ack)
- [五、 全生命周期 12 大血泪踩坑复盘与根本原因剖析](#五-全生命周期-12-大血泪踩坑复盘与根本原因剖析)
- [六、 本地 Boot 镜像继承式缝合全流程 (纯血防翻车指南)](#六-本地-boot-镜像继承式缝合全流程-纯血防翻车指南)
- [七、 开机验收、Scene 界面接管与性能验证](#七-开机验收scene-界面接管与性能验证)

---

## 一、 核心认知与 GKI 架构基本盘

从 Android 12 / 13 起，Google 全面推行 **GKI 2.0（Generic Kernel Image）** 规范：
1. **内核本体解耦**：核心调度、虚拟内存管理、Crypto 算法库统一集成在核心 `Image`（存放在 `boot.img` 分区）中。
2. **厂商驱动外挂**：主板时钟树、SMMU、总线互联、GPU、声卡以及部分平台组件（如 `zram.ko`）作为动态加载驱动，存放在 `vendor_dlkm` 或 `system_dlkm` 分区中。
3. **AVB 签名与 Bootloader**：在 Bootloader 解锁（Orange State）后，AVB 允许引导非原厂签名的内核，**不需要关闭 vbmeta 验证**

---

## 二、 目标设备“核心四要素”精准锁定 SOP

在为任何目标 Android 设备编译/移植内核前，**必须且只能在真机终端**读取并保存以下四大要素：

```bash
# 1. 抓取内核主版本、小版本与精准 Commit 哈希 (最核心基线)
uname -r
# 示例输出：6.1.138-android14-11-g0c3d559bcd85-ab14529422
# -> 内核分支：android14-6.1
# -> 局部版本后缀：-android14-11
# -> 精准提交 Commit：0c3d559bcd85 (后接 c64dae9c9c9687abbe5347fff3ad)

# 2. 确认当前运行的 A/B 槽位
getprop ro.boot.slot_suffix
# 回显：_a 或 _b

# 3. 提取原装 Boot 镜像 (救砖底线资产，严禁使用裁剪包！)
# 可直接通过 Root 提取当前槽位的完整物理镜像（例如 64MB 或 96MB）
dd if=/dev/block/by-name/boot$(getprop ro.boot.slot_suffix) of=/sdcard/stock_boot.img

# 4. 反解内核满血真实运行配置 (IKCONFIG)
# 现代内核均内置了压缩配置流，可在终端使用 Python 直接还原：
python3 -c '
import zlib
with open("/sdcard/stock_boot.img", "rb") as f:
    data = f.read()
pos = data.find(b"\x1f\x8b\x08")
while pos != -1:
    try:
        decomp = zlib.decompress(data[pos:], 16 + zlib.MAX_WBITS)
        if b"CONFIG_" in decomp:
            with open("/sdcard/device_stock_full.config", "wb") as out:
                out.write(decomp)
            print("成功提取出 100% 满血原厂配置！")
            break
    except:
        pass
    pos = data.find(b"\x1f\x8b\x08", pos + 1)
'
```

---

## 三、 华为 LZ4KD 算法核心原理与源码适配准备

### 1. LZ4KD 优势
* **LZ4K（4KB 页剪裁）**：针对移动端 OS 内存按 4KB 页面分配的特点，精简传统 LZ4 的冗余查找窗口与哈希表，压缩时延大幅降低，功耗极小。
* **Delta（跨页差分增量）**：对于连续内存页，计算当前页与上一页的字节异或/差分序列，在后台高密度冷数据压缩场景下，压缩比显著超越原生 LZ4。

### 2. 源码结构规范（必须放置在独立子目录）
必须将算法组织为独立模块，杜绝污染内核原生根目录：
```text
lz4kd_module/
├── Kconfig               # Kconfig 描述文件 (带 default y)
├── Makefile              # 驱动 Makefile (必须使用 obj-$(CONFIG_...) 模式)
├── lz4kd.h               # 核心算法头文件
├── lz4kd_crypto.c        # Crypto API 与 scomp 同步压缩注册接口
├── lz4kd_encode.c        # 编码核心
├── lz4kd_decode.c        # 解码核心
├── lz4kd_encode_delta.c  # 差分增量编码
├── lz4kd_decode_delta.c  # 差分增量解码
└── include/linux/lz4kd.h # 暴露给内核 include 的系统级头文件
```

### 3. `lz4kd_crypto.c` 关键实现规范 (Linux 6.1+ 必须支持 `scomp`)
```c
#include <linux/init.h>
#include <linux/module.h>
#include <linux/crypto.h>
#include <linux/vmalloc.h>
#include <crypto/internal/scompress.h> // 必须是 scompress.h，绝对不能简写为 scomp.h！
#include "lz4kd.h"

// 上下文与压缩/解压实现 ...

static struct scomp_alg scomp = {
	.alloc_ctx		= lz4kd_alloc_ctx,
	.free_ctx		= lz4kd_free_ctx,
	.compress		= lz4kd_scompress,
	.decompress		= lz4kd_sdecompress,
	.base			= {
		.cra_name		= "lz4kd",
		.cra_driver_name	= "lz4kd-scomp",
		.cra_module		= THIS_MODULE,
	}
};

static int __init lz4kd_mod_init(void) {
	int ret = crypto_register_alg(&alg_lz4kd);
	if (ret) return ret;
	ret = crypto_register_scomp(&scomp);
	if (ret) {
		crypto_unregister_alg(&alg_lz4kd);
		return ret;
	}
	return 0;
}
```

---

## 四、 构建流水线 (GitHub Actions + ACK)

本工作流基于官方 AOSP ACK（Android Common Kernel）和 TWRP 核心维护者 YukongA 的标准构建并完善补丁：

```yaml
name: Build Universal GKI LZ4KD Kernel from ACK

on:
  workflow_dispatch:
    inputs:
      TAG:
        description: 'ACK 分支 (例如 android14-6.1 / android15-6.6)'
        required: true
        default: 'android14-6.1'
      KERNEL_COMMIT:
        description: '精准锁定 Commit (与真机 uname -r 严格对齐)'
        required: false
        default: '0c3d559bcd85c64dae9c9c9687abbe5347fff3ad'
  push:
    branches:
      - main

jobs:
  build:
    name: Build LZ4KD Kernel
    runs-on: ubuntu-latest
    env:
      CCACHE_COMPILERCHECK: "%compiler% -dumpmachine; %compiler% -dumpversion"
      CCACHE_NOHASHDIR: "true"
      CCACHE_HARDLINK: "true"
    steps:
      # 1. 扩充磁盘空间 (释放 30GB+，将挂载区分离到大卷)
      - name: Maximize Build Space
        uses: easimon/maximize-build-space@master
        with:
          swap-size-mb: 8192
          root-reserve-mb: 16384
          temp-reserve-mb: 2048
          remove-dotnet: 'true'
          remove-android: 'true'
          remove-haskell: 'true'
          remove-codeql: 'true'

      # 2. 检出仓库代码 (必须在扩容后检出，避免路径漂移)
      - name: Checkout Repository
        uses: actions/checkout@v4

      # 3. 致命坑修复：将所有编译缓存重定向至 90GB+ 工作区大分区
      - name: Redirect Cache to High Capacity Partition
        run: |
          mkdir -p $GITHUB_WORKSPACE/.cache/bazel
          rm -rf /home/runner/.cache 2>/dev/null || true
          ln -sf $GITHUB_WORKSPACE/.cache /home/runner/.cache
          df -h

      # 4. 同步 Google 官方密封编译环境与精准源码基线
      - name: Download Kernel Source via Repo
        run: |
          sudo apt-get remove firefox -y 2>/dev/null || true
          sudo apt-get update
          sudo apt-get install -y repo ccache git zip unzip python3
          cd $GITHUB_WORKSPACE
          git config --global user.name "KernelBuilder"
          git config --global user.email "builder@kernel.local"
          mkdir -p android-kernel && cd android-kernel

          TARGET_TAG="${{ github.event.inputs.TAG || 'android14-6.1' }}"
          repo init --depth=1 -u https://android.googlesource.com/kernel/manifest -b "common-$TARGET_TAG" --repo-rev=v2.16
          repo --trace sync -c -j$(nproc --all) --no-tags

          TARGET_COMMIT="${{ github.event.inputs.KERNEL_COMMIT || '0c3d559bcd85c64dae9c9c9687abbe5347fff3ad' }}"
          if [ -n "$TARGET_COMMIT" ]; then
            cd common
            git fetch --depth=1 https://android.googlesource.com/kernel/common "$TARGET_COMMIT"
            git checkout FETCH_HEAD
            cd ..
          fi

      # 5. 算法注入与内核 Kbuild / 菜单注册
      - name: Inject LZ4KD Algorithm
        run: |
          GKI_ROOT=$GITHUB_WORKSPACE/android-kernel
          LZ4KD_SRC=$GITHUB_WORKSPACE/lz4kd_module

          mkdir -p $GKI_ROOT/common/crypto/lz4kd
          cp -rf $LZ4KD_SRC/* $GKI_ROOT/common/crypto/lz4kd/
          cp -rf $LZ4KD_SRC/include/linux/* $GKI_ROOT/common/include/linux/

          DRIVER_MAKEFILE=$GKI_ROOT/common/crypto/Makefile
          DRIVER_KCONFIG=$GKI_ROOT/common/crypto/Kconfig
          grep -q "lz4kd" "$DRIVER_MAKEFILE" || printf "\nobj-\$(CONFIG_CRYPTO_LZ4KD) += lz4kd/\n" >> "$DRIVER_MAKEFILE"
          grep -q "lz4kd" "$DRIVER_KCONFIG" || sed -i '/endmenu/i\source "crypto/lz4kd/Kconfig"' "$DRIVER_KCONFIG"

          # 注册到 ZRAM 静态菜单 (Scene / 性能调节 App 识别的关键)
          python3 -c '
          zcomp_file = "'$GKI_ROOT'/common/drivers/block/zram/zcomp.c"
          with open(zcomp_file, "r") as f:
              content = f.read()
          target = """#if IS_ENABLED(CONFIG_CRYPTO_ZSTD)\n\t\"zstd\",\n#endif"""
          replacement = target + """\n#if IS_ENABLED(CONFIG_CRYPTO_LZ4KD)\n\t\"lz4kd\",\n#endif"""
          if target in content and "CONFIG_CRYPTO_LZ4KD" not in content:
              content = content.replace(target, replacement, 1)
              with open(zcomp_file, "w") as f:
                  f.write(content)
              print("[+] Successfully registered lz4kd into zcomp.c backends[]")
          '

      # 6. 移除符号保护，全量导出符号支持厂商闭源驱动
      - name: Symbol and ABI Protection Removal
        working-directory: android-kernel
        run: |
          rm -f common/android/abi_gki_protected_exports_* || true
          sed -i '/^[[:space:]]*"protected_exports_list"/d' common/BUILD.bazel 2>/dev/null || true

      # 7. 清理工作树，防止版本号被打上 -dirty 导致驱动拒载
      - name: Clean Working Directory to Avoid -dirty Version
        working-directory: android-kernel
        run: |
          cd common
          git add -A
          git commit -a -m "Add LZ4KD compression algorithm" || true

      # 8. 产物上传 (只交付纯血核心与一键缝合工具，剔除无用 64MB 假 boot 和鸡肋 AnyKernel3)
      - name: Prepare Kernel Image and Repack Tool Artifacts
        run: |
          mkdir -p release_kernel
          cp -f $OUTDIR/Image release_kernel/
          cp -f $OUTDIR/zram.ko release_kernel/ 2>/dev/null || true
          cp -f tools_arm64/magiskboot release_kernel/
          cp -f repack_boot.sh release_kernel/
          chmod +x release_kernel/magiskboot release_kernel/repack_boot.sh

      - name: Upload Kernel Image and Repack Tool
        uses: actions/upload-artifact@v4
        with:
          name: Kernel_Image_and_Repack_Tool
          path: release_kernel/

      - name: Upload LZ4KD Auto Switch Module
        uses: actions/upload-artifact@v4
        with:
          name: LZ4KD_ZRAM_Auto_Switch
          path: LZ4KD_ZRAM_Auto_Switch.zip
```

---

## 五、 复盘与原因剖析

在实际推进过程中，任何一个细节的偏差都会直接导致编译中断、死机断电或无法生效。以下 12 大致命坑是全机型定制的核心教训：

### 1. 通用 AOSP `make gki_defconfig` 裸编卡米断电
* **致命原因**：官方 `gki_defconfig` 仅有 ~660 项基础配置，而实际真机运行时拥有 **2100+ 项配置**。裸编会彻底丢弃高通/联发科平台的硬件时钟树（CLK）、总线互联（Interconnect）、SMMU 保护等驱动，CPU 上电前几毫秒连主板总线都访问不了，触发 Hard Fault 死循环复位。
* **规避原则**：必须使用官方密封 ACK + Kleaf / Bazel 编译，或者基于反解的真机满血 `.config` 编译。

### 2. 源码拉取未锁定 Commit 导致驱动拒绝加载 (CRC Mismatch)
* **致命原因**：若只 clone `android14-6.1` 分支最新 HEAD，代码会滚动到如 `6.1.177`，而手机系统的 400+ 个闭源驱动是严格绑定在出厂 Commit（如 `6.1.138 0c3d559bcd85`）上的。函数符号 CRC 校验错位，驱动被内核集体拒载。
* **规避原则**：通过 `uname -r` 提取精准 Commit，`git fetch` 时精准锁定该 Commit。

### 3. 外挂 `lz4kd.ko` 动态加载瞬间黑屏断电死机 (kCFI 拦截)
* **致命原因**：高通 8 Gen 3 等新平台开启了硬件级 **kCFI（内核控制流完整性保护）**。外部单独编译的模块函数指针前缺失 4 字节类型哈希，函数指针一被内核调用，CPU 直接触发硬件 `BRK` 保护，PMIC 瞬间切断供电。
* **规避原则**：**LZ4KD 必须同源内置编译（Built-in）进内核本体 `Image`**，绝不能作为孤立外挂模块加载。

### 4. 不需要关闭 vbmeta”
* **致命真相**：Bootloader 解锁（Orange State）后，AVB 验证级别已经放开，**允许引导第三方内核**！无论更换内核还是缝合 boot，**不需要关闭 vbmeta**

### 5. 直接覆盖 `crypto/Makefile` 导致构建系统整体崩溃
* **致命原因**：文档若简写为 `cp -rf lz4kd_module/* common/crypto/`，模块自有的简易 Makefile 会直接冲掉 Linux 原生包含几十种加密算法的核心 `Makefile`，导致整个 crypto 目录编译报错停机。
* **规避原则**：建立独立子目录 `common/crypto/lz4kd/`，在原厂 Makefile 尾部通过 `obj-$(CONFIG_CRYPTO_LZ4KD) += lz4kd/` 引入。

### 6. Makefile 写死 `obj-m` 导致无法打入内核镜像
* **致命原因**：Makefile 若固定写为 `obj-m += lz4kd.o`，Kbuild 只会在编译外部模块时生成 `.ko`，根本不会将其符号链接进 `Image`。
* **规避原则**：必须遵循 Kconfig 动态编译语法：`obj-$(CONFIG_CRYPTO_LZ4KD) += lz4kd.o`。

### 7. 未声明 Kconfig 导致配置被 Kbuild 静默剔除
* **致命原因**：仅在 defconfig 写入 `CONFIG_CRYPTO_LZ4KD=y`，但没有在 `Kconfig` 中声明该符号，Kbuild 在执行配置收敛时会作为未知杂质**直接静默丢弃**。
* **规避原则**：规范编写 `Kconfig` 文件，并将其声明为 `default y`。

### 8. Linux 6.1 ZRAM 依赖的 `scompress` 头文件拼写陷阱
* **致命原因**：原代码若 include `<crypto/internal/scomp.h>`，Clang 会直接报 `file not found`。在 Linux 6.1 GKI 中，官方头文件名严格为 **`<crypto/internal/scompress.h>`**（带完整 `ress` 后缀）。

### 9. Bazel / Kleaf 构建设施的 `savedefconfig` 强校验拦截
* **致命原因**：在构建脚本中若手动追加改动了 `gki_defconfig`，Kleaf 在运行中会调用 `savedefconfig` 对比，一旦字段顺序或格式未对齐，直接中断报：`ERROR: savedefconfig does not match`。
* **规避原则**：在 `lz4kd_module/Kconfig` 中直接声明 `default y`，保持原厂 `gki_defconfig` 原汁原味，彻底规避校验拦截。

### 10. CI 虚拟机根分区仅剩 2GB 导致 Bazel 缓存塞满强杀 Runner
* **致命原因**：GitHub 扩容插件将 92GB 挂载在工作区，但根分区 `/dev/root` 仅剩 2GB。Bazel 默认缓存路径 `/home/runner/.cache` 处在根分区，整核编译产生巨量缓存后根分区迅速撑爆，CI 守护进程因无法写磁盘直接崩溃中断。
* **规避原则**：在检出源码后立即执行 `ln -sf $GITHUB_WORKSPACE/.cache /home/runner/.cache`，并将 Bazel cache 参数显式指定为工作区路径。

### 11. 骁龙 8 Gen 3 纯 64 位 CPU 硬件断代导致的 `Busybox setup failed`
* **致命原因**：骁龙 8 Gen 3 硬件级砍掉了 AArch32 架构支持。官方老版 AnyKernel3 默认携带的 `busybox` / `magiskboot` 是 32 位 ARM (ELF32) 二进制文件。在 Recovery 或系统执行时，CPU 硬件因不支持 32 位指令集直接报错退出。
* **规避原则**：必须全量替换为 **ELF64 AArch64 纯 64 位静态编译**工具链。

### 12. 开机状态下直接 `swapoff` / `reset` 触发 `Device or resource busy` (EBUSY)
* **致命原因**：Android 开机进入桌面后，系统内存守护进程（`perfd`/`lmkd`）会常驻打开 `/dev/block/zram0` 句柄。Linux 内核具有死锁保护：`if (disk_openers(disk)) return -EBUSY;`，开机后再尝试 `reset` 必被内核拒绝！
* **规避原则**：必须采用**本地继承式缝合单 Boot 镜像**或在开机早期（`post-fs-data`）由模块自动接管，严禁在开机桌面状态下强行重置。

---

## 六、 本地 Boot 镜像继承式缝合全流程 (纯血防翻车指南)

无论针对什么机型，最优雅、对系统零破坏且 100% 保留原有 TWRP 与开机引导的方案，就是在本地通过 **64 位 `magiskboot`** 进行继承式缝合：

### 1. 使用仓库自带脚本一键缝合（最推荐）

仓库已内置开箱即用的自动缝合脚本 `repack_boot.sh`，内部已集成全部解包、替换、重封包与 100,663,296 字节校验逻辑：

```bash
# 只要将原装救砖底包 boot.img 放在同一目录下，直接运行即可：
sh repack_boot.sh

# 也支持指定任意路径：
sh repack_boot.sh /path/to/stock_boot.img /path/to/Image /path/to/final_boot.img
```
脚本将自动调用 64 位 `magiskboot`，在 1 秒内输出结构严谨对齐的 `final_lz4kd_boot.img`！

### 2. 分步缝合 (SOP)

刷入方式：
* 在 TWRP 中切换为【安装镜像】-> 选择 `final_lz4kd_boot.img` -> 勾选【Boot】滑动刷入；
* 或在电脑 Fastboot 下直敲：`fastboot flash boot_a final_lz4kd_boot.img && fastboot reboot`。

---

## 七、 开机

### 1. 刷入配套的magisk模块，开机自动切换zram压缩方案
开机后在终端执行：
```bash
cat /proc/version
或使用配套sh脚本测试
