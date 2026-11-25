# pmos-munch — Redmi K40S 的 headless postmarketOS 服务器

把 Redmi K40S（munch，SM8250-AC）改造成无屏幕、插电常开的 postmarketOS 服务器。
**保留 slot a 的 Android 不动**，pmOS 装在 slot b（UEFI 方案）。

> 详细时间线、失败尝试与逐条踩坑记录见 [HANDOFF.md](HANDOFF.md)。
> 本 README 是成果索引与复现入口。

## 当前状态（2026-11-25）

| 项 | 状态 |
|---|---|
| 启动链 | ✅ UEFI(edk2-msm-munch) → GRUB → 主线 pmOS 7.2.0 + 自建 headless dtb |
| 系统 | ✅ postmarketOS edge / systemd / hostname `munch` |
| 网络 | ✅ WiFi `wlan0`（ath11k/QCA6390），**192.168.0.103**，MAC 已固定 `02:00:7b:15:30:a6` |
| SSH | ✅ `ssh user@192.168.0.103`（局域网）；USB 网络 `ssh user@172.16.42.1` |
| 屏幕 | ✅ 物理黑屏（`panel-blank.service` 拉低面板 reset GPIO12） |
| 电量 | ✅ `/usr/local/bin/battery`（qcom-battery） |
| 包管理 | ✅ apk 数据库已修复；阿里云 Alpine edge 镜像；已装 tmux 等基础包 |
| rootfs 空间 | ⚠️ 约 170MB 空闲（1041MiB ext4），装大包前先扩容 |

**红线（不可违反）**：绝不刷 `dtbo` / `bootloader` / `xbl` / `abl` / `tz` / `modem` / `super`；slot a Android 不可动；唯一允许的数据损失是 `userdata`（已确认接受）。

## 启动架构

```
ABL (slot b)
  └─ boot_b: edk2-msm-munch UEFI
       └─ BDS 扫描 FAT32 userdata 的 \EFI\BOOT\BOOTAA64.EFI
            └─ GRUB 2.06 arm64 standalone
                 ├─ devicetree /boot/dtb.bin     （我们的 headless dtb）
                 ├─ linux       /boot/vmlinuz-pmos（7.2.0 主线，49MB Image）
                 └─ initrd      /boot/initramfs.gz
                      └─ hook 50-loop-root.sh：
                           FAT (PARTLABEL=userdata) → losetup /rootfs.img → ext4
                             └─ pmOS 按 UUID 687be8df-… 找根 → systemd → sshd
```

关键前提：**发布版 UEFI 固件没有 ext2/4 驱动，只认 FAT32/NTFS**；且 UFS 逻辑扇区是 4096，
所以 FAT32 必须用 `mkfs.vfat -S 4096` 创建。BDS 会自动把 `\EFI\Boot\bootaa64.efi` 插到
BootOrder 首位（`PlatformBm.c` 的 AfterConsole 逻辑）。

## 成果目录

```
artifacts/                    小体积关键产物（可进 git）
  dtb.bin                       实际部署的 headless dtb
  kernel.config                 pmOS 7.2.0 内核配置
  grub-fat-BOOTAA64.EFI         FAT 镜像内使用的 GRUB
  grub-black-BOOTAA64.EFI       纯黑屏版 GRUB（build-black-grub.sh）
  grub.cfg                      生产用 grub.cfg
  CHECKSUMS.txt                 大镜像/关键文件的 sha256

out/                          大镜像（不进 git）
  pmos-fat-userdata.img         ★ 当前可刷写交付物（1536MiB FAT32）
  root-debug.img                rootfs 源（ext4 1041MiB，UUID 687be8df）
  pmos-uefi-userdata.img        早期 ext4 UEFI 布局（构建输入）
  dtbs/                         解包 dtb 备查
  dtbo/                         K40S 原厂 dtbo 的 27 个 overlay（已反编译）
  wifi-pkgs/                    离线 WiFi 二进制包（apk 坏掉时的救急方案）
  archive/                      历史镜像、日志、临时目录（可整目录删除）

dts/                          设备树成果与参考
  sm8250-xiaomi-munch-headless.dts   ★ 当前 headless dts（660 行）
  munch-display.dts                  显示/触摸尝试版（不可部署，会挂起）
  refs/                              alioth/munch 参考 dts、原厂 dtbo entry

scripts/
  build/    内核包、dtb、GRUB、initramfs、FAT 镜像构建
  deploy/   fastboot 刷机、GRUB/panel-blank 部署、GPIO 工具
  verify/   QEMU+AAVMF、proot+qemu-user、离线校验
  ops/      WiFi 恢复、apk 修复、MAC 固定等手机侧运维

packages/（本地 `repo/`）       pmaports 包源码（device/firmware/linux-munch，成果）
units/                        手机侧 systemd 单元（panel-blank、battery）
tools/                        手机侧脚本与 gpio_hold 源码/二进制
cmds/                         手机侧一次性操作脚本
edk2/                         UEFI 固件/GRUB arm64 模块（参考，不进 git）
los-ref/  los-src/             LineageOS 参考镜像与 vendor dts（参考，不进 git）
pmaports-alioth/              alioth 上游移植参考（不进 git）
work/                         构建工作目录（不进 git）
archive/                      212 个长尾一次性脚本 + 清单（不进 git，可删）
```

## 复现 / 重建

前置：WSL Ubuntu-22.04，`pmbootstrap` 3.12.x，GRUB arm64 模块已由
`scripts/build/persist-grub.sh` 落到 `edk2/grub-arm64-efi/`。

```bash
# 1) 内核包（7.2.0 + headless dts）
bash scripts/build/create-pkg-720.sh          # 首次生成包骨架
bash scripts/build/update-headless-dts.sh     # 同步 dts + 刷新 sha512
bash scripts/build/wsl-build-kernel720.sh     # pmbootstrap 增量构建

# 2) initramfs 补 loop-root hook（需要 root）
sudo bash scripts/build/patch-initramfs.sh

# 3) GRUB（纯黑屏版）
bash scripts/build/build-black-grub.sh

# 4) 组装 FAT32 userdata 镜像（需要 root，产物 out/pmos-fat-userdata.img）
sudo bash scripts/build/build-fat-uefi.sh

# 5) 离线验证（安全，不改 binfmt）
sudo bash scripts/verify/offline-verify.sh
bash scripts/verify/qemu-uefi-fat-test.sh
```

刷机（手机进 fastboot，**先确认 current-slot=a**）：

```bash
bash scripts/deploy/flash-fast.sh
# 等价手工步骤：
#   fastboot flash userdata out/pmos-fat-userdata.img
#   fastboot set_active b && fastboot reboot
# 回滚：fastboot set_active a && fastboot reboot
```

## 关键经验（别再踩）

1. **ABL 会校验 dtb**：vendor_boot 的 dtb 必须是它认识的 kona base 结构；主线 dtb 直接塞
   boot/vendor_boot 会被拒（`fastboot boot` 返回 OKAY 但设备停在 fastboot）。UEFI 路线绕开了它。
2. **UEFI 固件无 ext4 驱动**：userdata 必须 FAT32；且 FAT 扇区必须是 4096（UFS 逻辑块）。
3. **屏幕花屏不是 Linux 写的**：`/dev/fb0` dump 全 0，但物理面板仍在自刷新 — 面板被 bootloader
   锁存。可靠办法是 `gpio_hold 3 12 0` 把 reset 拉低（`panel-blank.service` 持久化）。
4. **带显示/面板的内核不可部署**：会黑屏挂起且 WiFi/USB 都不出现，只能 fastboot 整包回刷。
5. **apk v2 database format error**：`/lib/apk/db/installed` 被污染成 ELF。修复：移走该文件、
   清空 `/etc/apk/world`、`apk add --force-overwrite tmux` 重建数据库（详见 `scripts/ops/`）。
6. **WiFi 工具可离线部署**：apk 坏掉时用 `out/wifi-pkgs/wifi-bin.tar.gz` 解到 `/usr/local/wifi`，
   `LD_LIBRARY_PATH=/usr/local/wifi/lib` 运行。
7. **WSL 脚本**：`wsl.exe bash -c` 会吞 `$VAR`，一律用脚本文件；WSL `/tmp` 会丢，产物放 F:。

## 参考

- UEFI 固件：`0xSelenicDove/edk2-msm-munch`
- alioth pmOS 移植：`github.com/nasaarmas/pmaports-alioth`
- munch vendor dts：LineageOS `android_kernel_xiaomi_sm8250` (lineage-22.2)
- 救砖复盘：`github.com/wengchengjian/xiaomi-edl-revival`
