# 小米 14 (houji) GKI 6.1 LZ4KD 极速内存压缩内核工程

本项目基于 Google 官方 Android Common Kernel (ACK) `android14-6.1` 分支（基线锁定：`0c3d559bcd85`），为高通骁龙 8 Gen 3 平台（小米 14 / houji）提供集成华为专有 **LZ4KD（LZ4K 4KB页剪裁 + Delta 跨页差分增量）** 压缩算法的工业级定制内核流水线。

---

## 核心技术特性与设计原则

1. **同源内置算法，硬件级安全**：
   - 华为 `lz4kd`（`lz4kd-scomp`）算法直接内置于内核主二进制（`CONFIG_CRYPTO_LZ4KD=y`）；
   - 完美通过高通骁龙 8 Gen 3 硬件级 **kCFI（内核控制流完整性保护）** 校验，零黑屏、零断电复位。
2. **顺应出厂时序，彻底根除无限重启（Bootloop Prevention）**：
   - 驱动配置严格遵循出厂标准 `CONFIG_ZRAM=m`；
   - 规避了因早于 Android First-Stage Init 抢占注册驱动导致的 `LOG(FATAL)` 符号重入死锁冲突，100% 稳定开机。
3. **mknod 动态设备直通**：
   - 自启模块利用内核主次设备号（`253:0`）动态创建直通节点，彻底免疫 Android 14 命名空间隔离与路径混淆。
4. **全套自动化云端交付**：
   - 每次 GitHub Actions 构建均自动输出 AnyKernel3 卡刷包、裸内核镜像（`Image` / `boot.img` / `zram.ko`）以及一键自启切换模块。

---

## 云端构建交付资产清单 (Artifacts)

| 资产名称 | 交付物说明 | 适用场景 |
| :--- | :--- | :--- |
| **`AnyKernel3_Xiaomi14_LZ4KD`** | 适配 64 位纯血环境的标准 AnyKernel3 卡刷包 | TWRP Recovery 界面直接卡刷安装内核 |
| **`Raw_Kernel_and_Boot`** | 包含编译原件 `Image`、`boot.img` 以及同源 `zram.ko` | Fastboot 救砖备用、本地 `magiskboot` 缝合 |
| **`LZ4KD_ZRAM_Auto_Switch`** | 针对 KernelSU / Magisk 的开机自启接管模块 | 开机自动穿透沙箱，重置并切换 ZRAM 为 `lz4kd` |

---

## 安装与开机见证

### 第一步：刷入内核镜像（双通道任选其一）
- **方式 A（系统桌面下，最快）**：
  在手机上打开【**刷写中心**】App -> 选择【刷入 Boot 镜像】 -> 选择缝合后的 `final_lz4kd_boot.img` -> 刷入当前 Boot 分区并重启。
- **方式 B（TWRP Recovery）**：
  进入 TWRP -> 点击【安装】切换为【安装镜像】 -> 选中镜像并勾选【Boot】分区滑动刷入 -> 重启系统。

### 第二步：安装开机自动接管模块
1. 打开手机中的 **KernelSU** 或 **Magisk** 应用；
2. 点击【模块】 -> 【从本地安装】 -> 选择 `LZ4KD_ZRAM_Auto_Switch.zip` 刷入；
3. 重启手机。

---

## 生效验证

手机开机后，在终端（Root 权限）执行：
```bash
cat /proc/crypto | grep -A 4 "lz4kd"
```
回显包含 `lz4kd-scomp` 且 `selftest: passed`，证明底层算法硬件自检通过。

继续执行：
```bash
cat /sys/block/zram0/comp_algorithm
```
回显将原生显示：
```text
lzo lzo-rle lz4 zstd [lz4kd]
```
`[lz4kd]` 高亮中括号即代表专有 4KB 差分增量算法已全面接管系统的 16GB ZRAM 虚拟内存！

在 **Scene** App 中打开【功能】->【Swap / ZRAM 调节】，压缩算法亦同步显示为 `lz4kd`！

---

## 一键还原与防翻车保障

工作区安全备份原厂官方救砖底包 `boot.img`（96MB）。若需要恢复官方出厂状态，在电脑 Fastboot 敲一行命令即可秒级还原：
```bash
fastboot flash boot boot.img
fastboot reboot
```
