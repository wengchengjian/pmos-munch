# pmos-munch

Redmi K40S (munch) 的 postmarketOS **headless 服务器**移植——基于 alioth（POCO F3，同 SM8250-AC）的成熟 pmOS 移植改造。

## 战略背景

munch 无官方 pmOS 移植，但兄弟机型 alioth 的移植质量足以覆盖"手机当服务器"的全部需求：

```
服务器需要的：CPU ✅ RAM ✅ UFS ✅ WiFi(QCA6390) ✅ 电源管理 ✅
服务器不需要的：屏幕 触摸 相机 GPS 指纹 modem 通话  ← 驱动死区，正好全部可裁
```

所以本项目目标是 **headless 服务器设备包**（`UI=none`），不是日常手机系统。

## 与 alioth 的硬件差异（决定适配点）

| 组件 | alioth (POCO F3) | munch (K40S) | 处理策略 |
|---|---|---|---|
| SoC | SM8250-AC | SM8250-AC | 相同 |
| WiFi | QCA6390 | QCA6390 | **相同，firmware 可直接复用** |
| 存储 | UFS 3.1 | UFS 3.1 | 相同 |
| 充电器 | bq2597x-standalone | **bq2597x master/slave + ln8000** | 需适配（服务器长期插电，必须） |
| 电量计 | PMIC (pm8150b-fg) | **外挂 bq27z561** | 需适配 |
| 音频功放 | cs35l41 | nxp tfa98xx | 裁掉（不需要） |
| 无线充电 | p9415 + rx1619 | 无 | 裁掉 |
| 面板/触摸 | ams667xx01 / ft8756 | 不同 IC | 裁掉（headless） |

## 目录结构

```
device-xiaomi-munch/      设备包（deviceinfo / initramfs 模块 / 配置）
firmware-xiaomi-munch/    固件包（复用 alioth 的 SM8250 blob 集，含签名 firmware）
.github/workflows/build.yml  GitHub Actions 构建管线
scripts/flash-windows.md    Windows 侧 fastboot 刷机步骤（slot b 双系统）
```

## 构建

推送到 main 或手动 `workflow_dispatch` → Actions 构建 → 下载 artifact：

- `boot.img` → `fastboot flash boot_b boot.img`
- `rootfs.img` → `fastboot flash userdata rootfs.img`
- `fastboot set_active b` → 从 slot b 启动 pmOS；`fastboot set_active a` 随时回 Android

> 构建环境说明：开发者本机 WSL 被安全策略禁用、无 Docker，故构建全部在 GitHub Actions（Ubuntu）完成，Windows 仅负责 fastboot 刷入。

## 里程碑

- [x] M0: 环境探明（构建管线架构）
- [x] M1: alioth 源材料 + munch Android dts 采集，差异清单产出
- [ ] M2: 首轮 CI 构建通过（alioth dts 原样，验证管线）
- [ ] M3: munch 定制 headless dts（充电/电量计适配）
- [ ] M4: 刷入 slot b 启动验证（UART 日志迭代）
- [ ] M5: WiFi 联网 + SSH 可达 → 服务器可用

## 参考

- alioth pmOS 移植：github.com/nasaarmas/pmaports-alioth
- munch Android dts：LineageOS/android_kernel_xiaomi_sm8250 (lineage-22.2)
- 救砖与安全机制复盘：github.com/wengchengjian/xiaomi-edl-revival
