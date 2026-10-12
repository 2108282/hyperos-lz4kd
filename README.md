# Xiaomi 14 (houji) GKI 6.1 with LZ4KD Compression

本项目为 **小米 14 (houji)** 及 **小米 14 Pro (shennong)**（高通骁龙 8 Gen 3 平台）定制的 Android 14 GKI 6.1 通用内核自动化云编译项目。

在标准 Google AOSP GKI 通用内核基础上，集成了华为专有、针对 4KB 内存页特化优化的 **LZ4KD（LZ4K + Delta 跨页差分压缩）** 内存压缩算法，专为移动端 ZRAM 打造。

---

## 核心特性

- **基于 AOSP 官方 GKI 6.1**：保持 KMI-11 接口一致，完全兼容澎湃 OS (HyperOS) 1 / 2 / 3 官方出厂系统的所有闭源驱动（相机、触控、快充、高刷无任何异常）。
- **LZ4KD 专有压缩算法**：
  - 针对移动设备 4KB 单物理内存页剪裁，紧凑 24-bit Tag 结构消除冗余通用头开销；
  - 引入 Delta（差分增量）压缩，大幅提高内存回收保活率，兼顾超高解压速度与低功耗。
- **全自动化 GitHub Actions 云编译**：无需本地庞大编译链，云端全自动出包，每次更新一键重新构建。

---

## 使用与刷入指南

### 1. 编译
点击仓库顶部的 **Actions** 标签页 -> 选择 **Build Xiaomi 14 GKI 6.1 with LZ4KD** -> 点击 **Run workflow** 即可在云端开始编译（约 15 分钟）。

### 2. 刷入步骤 (手机端一键直刷)
1. 编译完成后，在 GitHub Actions 的 **Releases** 或 **Artifacts** 页面下载 `AnyKernel3-Xiaomi14-LZ4KD-GKI.zip`；
2. 手机打开 **Kernel Flasher** App；
3. 点击“Flash AK3 Zip” -> 选择下载好的 Zip 包直刷；
4. 重启手机。

### 3. 生效验证与控制
开机后在终端或 Termux / ADB 中执行：
```bash
cat /sys/block/zram0/comp_algorithm
```
若回显中包含 `[lz4kd]`，说明 LZ4KD 算法已正式在 ZRAM 中生效并被作为默认压缩算法！

手动切换命令（如需测试对比）：
```bash
su
swapoff /dev/block/zram0
echo lz4kd > /sys/block/zram0/comp_algorithm
swapon /dev/block/zram0
```

---

## 安全与还原说明
本项目在刷入前请务必保留官方原厂 `boot.img` 镜像。若需还原，直接在 Kernel Flasher 或电脑 fastboot 刷回原厂 boot 即可秒级还原。
