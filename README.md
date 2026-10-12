# LZ4KD ZRAM 极速内存压缩模块 (Magisk / KernelSU / APatch 通用版)

本项目为 **Android 14 GKI 6.1 通用内核架构**（如小米 14 系列、红米 K70 系列、一加 12 等高通骁龙 8 Gen 3 平台）提供的免刷机、免改 boot、免关 vbmeta 签名的独立内核模块与通用自启安装包。

---

## 核心优势

- **零风险保护数据**：无需关闭 vbmeta 签名（彻底杜绝触发 FBE 强制格式化清除全盘数据）。
- **零风险保护启动**：完全不修改、不刷写物理 `boot` 分区，永不卡米。
- **动态运行时加载**：利用 Linux 内核公开接口，开机后在用户空间（Root 权限）通过 `insmod` 动态注入 `lz4kd.ko` 驱动，并自动重置切换 ZRAM 为 `lz4kd` 算法。
- **极简安装**：标准的通用 Zip 模块，直接在 Magisk / KernelSU / APatch 管理器内点“从本地安装”即可。

---

## 安装与生效流程

1. 在仓库的 **Releases** 或 **Actions Artifacts** 下载 `LZ4KD-ZRAM-Universal-Module.zip`；
2. 打开手机中的 **Magisk** 或 **KernelSU** 应用；
3. 点击【模块】 -> 【从本地安装】 -> 选择该 Zip 包；
4. 重启手机。

---

## 生效验证

重启开机后，在终端执行：
```bash
cat /proc/crypto | grep -A 2 -B 2 "lz4kd"
```
若出现 `lz4kd` 算法注册项，说明驱动加载成功。接着执行：
```bash
cat /sys/block/zram0/comp_algorithm
```
列表中如果显示 `[lz4kd]`，说明 ZRAM 已正式开启专有 4KB 差分内存压缩！

---

## 一键还原

如需停止使用，直接在 Magisk / KernelSU 模块管理界面点击【移除】该模块并重启即可，系统立即 100% 恢复官方出厂状态，零残留。
