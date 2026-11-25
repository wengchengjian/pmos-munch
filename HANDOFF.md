# Handoff: munch (K40S) postmarketOS Headless 服务器移植

> 交接时间：2026-11-25 07:35 ｜ 更新：WSL 本机构建路线打通，7.2.0 headless 镜像已交付
> 任务：让 munch 跑起 headless postmarketOS（双槽：slot a 保留 Android，slot b 装 pmOS）

## 一、当前状态

| 里程碑 | 状态 |
|---|---|
| M1 源材料采集 + 差异分析 | ✅ 完成 |
| M2 构建管线（改为 WSL 本机构建，弃用 CI） | ✅ **完成**：镜像产出且通过静态验证闸门 |
| M3 headless dts 重写（7.2.0） | ✅ **完成**：1343 行 alioth 移植 → 660 行 headless 定制 |
| M4 刷机验证 | ⏳ 待执行（镜像已就绪，见第五节） |
| M5 WiFi 联网 + SSH | ⏳ 待 M4 后 |

**当前交付物** `F:\project\pmos-munch\out\`：
- `boot.img` — sha256 `234be9d9eae707c854f343b7a4a8211300e737bce53482f483d70d766ce3d497`
  - Android boot v0-v2 头 (page=4096)，内核 15.3MB（含内嵌 dtb：model="Xiaomi Redmi K40S"，qcom,board-id=<50 0>），initramfs 12.9MB
- `xiaomi-munch-root.img` — sha256 `d4d482ea55afe797f5267c0fcdb59db467731f71ca68b5552d9643b8c667a059`
  - ext4 (block 4096)，内核 7.2.0，postmarketOS (systemd)，hostname=munch，sshd.service，/home/user，密码占位 CHANGE_ME_PASSWORD
- `xiaomi-munch-boot.img` — 512MB ext2 启动分区镜像（fastboot 流程用不到，备查）
- `dtbs/` — 解包的 dtb 备查

## 二、构建环境（WSL）

- **wsl.exe 可用**（早期"Program Blacklist"已解除）。Ubuntu-22.04，用户 `weng`，passwordless sudo
- `.wslconfig` 已调优：`processors=16`、`memory=10GB`（i7-13700K 24 逻辑核 / 16GB 宿主；2026-11-25 从 8/8 提升）
- 网络：**mirrored 模式**；Windows 代理 `127.0.0.1:7897` 在 WSL 内可达（域名被墙时用 `curl -x`）
- 镜像源（`~/.config/pmbootstrap_v3.cfg`）：
  - alpine = `https://mirrors.aliyun.com/alpine/`
  - pmaports = `https://mirrors.aliyun.com/postMarketOS/`
  - **systemd = `https://mirror.nura.eco/postmarketos/extra-repos/systemd/`**（阿里云没有 extra-repos/systemd，会 404；TUNA 挂；BFSU 连上但无响应）
- pmbootstrap 3.12.1（venv `~/pmos-build/.venv`），config 为手写 INI（`pmbootstrap init` 纯交互不可自动化）
- 工作目录：`~/pmos-build/{pmbootstrap, pmaports, kernel-src/}`；`jobs=16`；`ccache_size=20G`

## 三、构建知识与坑（勿重复踩）

1. **快速增量构建**：`pmbootstrap build --lax --src ~/pmos-build/kernel-src/linux-sm8250-7.2.0_git20261010 <pkg>`
   - `--src` 自动加 `abuild -K` 保留对象文件；`--lax` 不 zap chroot
   - **`--src` 的 rsync 用源码树的 `.gitignore` 当排除表**，内核 `.gitignore` 有 git 语法的 `!取反`（如 `*.bc` + `!kernel/time/timeconst.bc`），rsync 不认 `!` → 关键文件被静默排除 → `prepare0` 报 `No rule to make target 'kernel/time/timeconst.bc'`。**对策：构建树里 `mv .gitignore .gitignore.disabled-for-pmb-src`**（脚本已内置）
   - `pmbootstrap install` 的 strict zap 会清掉 chroot `/tmp` 里的增量副本 → 每次 install 后首次内核构建会全量重来（ccache 兜底，实测 ~2-3 分钟）
2. **ccache 跨模式命中**：普通构建与 `--src` 构建共享 cache（1.4GB），7.2.0 全量重建实测 15s 内 4700+ 对象命中
3. **首次全量 7.2.0 内核编译**：16 核 9m46s
4. 内核包结构：`device/testing/linux-postmarketos-qcom-sm8250-munch/`（dts 是独立源文件，prepare() 注入 + Makefile 追加，**不用 patch**）
5. 官方 7.2.0 内核包 = `sm8250-7.2.0_git20261010` tag（fork 最新；**无 7.3.x**，分支最高 7.2.0-dev）；tarball sha512 与官方一致
6. 6.19.6 是 fork 的 **branch**（不是 tag），归档可按分支名下载

## 四、headless dts 设计（M3 交付）

`repo/linux-postmarketos-qcom-sm8250-munch/sm8250-xiaomi-munch.dts`（660 行）

**保留**（19 个 okay 节点）：UFS(ufshc@1d84000) / USB2 gadget(dwc3 wrapper a6f8800 + hsphy 88e3000 + PMIC vbus/typec 角色切换) / PCIe0+QCA6390 WiFi(pcie@1c00000 + wifi@0 + qca6390-pmu 完整供电树) / PMIC 充电(charger@1000)+电量计(fuel-gauge@4000) / PON pwrkey+resin / UART12 调试控制台(自带 qup_uart12_default pinctrl, stdout-path 115200n8) / 三组 QUP+DMA / CPU OPP 含 SM8250-AC 3.1872GHz(opp22) / RPMH 稳压器全表（平台共享接线，勿轻改）

**裁剪**：面板/DSI/mdss、触摸、相机(camss/csiphy/cci/i2c)、音频(sound/q6afe/q6dsp/cs35l41)、GPU(gmu/gpu/zap)、venus 视频、NFC、红外、传感器(i2c/spi)、无线充电、remoteproc(adsp/cdsp/slpi 不加载固件)

**板级值来源**：alioth 移植（同 SM8250-AC 平台，UART 验证过的稳压器/UFS/USB 供电）＋ LineageOS munch vendor dts 交叉核对（电池 4500mAh、UFS 轨道 l17/l6/s4 一致、WiFi/BT 使能 GPIO 20/21+sw_ctrl 124 一致、**xbl_aop_mem=0x80600000/0x260000 与 alioth 完全一致** → reserved-memory 采用平台值安全）

**已知遗留**：
- PMIC 充电用主线 pm8150b 驱动（无 bq2597x 外挂快充驱动；PMIC 基础充电够服务器场景）
- bq27z561 外挂电量计未驱动（用 PMIC fg 近似）
- 设备包 depends 里 hexagonrpcd*/tqftpserv/alsa-ucm/mesa-vulkan 未裁剪（**首次启动验证后再做清理**，避免变量过多）
- modules-initfs 保留了 4 个 qcom 模块（现 dts 不启用 remoteproc，可后续清空）

## 五、M4 刷机（下一步，需用户+手机在场）

```powershell
cd F:\project\pmos-munch\out
$fb = "C:\Users\wengchengjian\AppData\Local\Android\Sdk\platform-tools\fastboot.exe"
& $fb getvar current-slot           # 必须确认 = a
& $fb flash boot_b boot.img
& $fb flash userdata xiaomi-munch-root.img
& $fb set_active b
& $fb reboot
# 回滚：& $fb set_active a; & $fb reboot
```

**红线**：绝不刷 `dtbo`/`bootloader`/`xbl`/`abl`/`tz`/`modem`/`super`。唯一数据损失 = userdata 清空（两槽共享，已确认接受）。

**刷后通信**（已验证镜像内可用）：
1. fastboot：音量下+电源，永远可用（回滚锚点）
2. **USB 网卡 + SSH**：数据线插入，Windows 出 USB 以太网适配器 → `ssh user@172.16.42.1`（密码 CHANGE_ME_PASSWORD）。initramfs 已含 `usb_f_rndis/ncm/acm/libcomposite`，init_functions.sh 配 172.16.42.x
3. WiFi SSH：M5 之后
4. UART：拆机接 uart12（115200），dts 已配 stdout-path

**首次启动排查**：无屏幕，看 USB 网卡是否出现 / 路由器是否出现 WiFi 客户端 / UART。若 slot b 不启动：`set_active a` 回 Android 再迭代。

## 六、本地工作目录索引（2026-11-25 已整理）

| 位置 | 内容 |
|---|---|
| `F:\project\pmos-munch\out\pmos-fat-userdata.img` | **当前可刷写交付物（FAT32 userdata）**；历史镜像在 `out/archive/` |
| `F:\project\pmos-munch\out\root-debug.img` | rootfs 源（ext4，UUID 687be8df…，构建 FAT 镜像时复制为 rootfs.img） |
| `F:\project\pmos-munch\artifacts\` | 小体积关键产物：dtb / kernel.config / GRUB EFI / CHECKSUMS.txt |
| `F:\project\pmos-munch\dts\` | 成果 dts（headless / display）＋ `dts/refs/` 参考源 |
| `F:\project\pmos-munch\scripts\{build,deploy,verify,ops}\` | 精选脚本（索引见 `scripts/README.md`） |
| `F:\project\pmos-munch\repo\` | pmaports 包源码（device/firmware/linux-munch；**未提交上游 git**） |
| `F:\project\pmos-munch\units\`、`tools\`、`cmds\` | 手机侧 systemd 单元、GPIO/WiFi 工具与操作脚本 |
| `F:\project\pmos-munch\archive\` | 212 个长尾一次性脚本 + 根目录清单（可整目录删除） |
| WSL `~/pmos-build/kernel-src/linux-sm8250-7.2.0_git20261010` | 7.2.0 源码树（增量构建源） |
| WSL `~/pmos-build/pmaports/device/testing/` | 三个本地包：device-xiaomi-munch, firmware-xiaomi-alioth, linux-postmarketos-qcom-sm8250-munch |

## 七、后续路线（M4 之后）

1. 首次启动 → USB 网卡/SSH 验证 → `dmesg` 排查缺失驱动
2. 清理：设备包裁依赖（hexagonrpcd 等）、modules-initfs 清空、固件包瘦身
3. M5：ath11k WiFi + NetworkManager/iwd → 无头服务器常态化（systemd 自启 sshd）
4. 充电精调：bq2597x/ln8000/bq27z561 驱动（可选，PMIC 充电已够用）

---

## 2026-11-25 下午：M4 实战记录（重大发现 + 路线转向 UEFI）

### 刷机实验结论（全部已实证）

1. **munch 是 GKI v3 启动链**：ABL 要求 boot 镜像 header v3 + **vendor_boot_b/dtbo_b/vbmeta_b 必须有效**；缺 vendor_boot/dtbo 时连官方 LOS boot.img 都秒回 fastboot。
2. **ABL 的 dtb 校验（闭源）**：vendor_boot 的 dtb 段必须是它认识的 kona base dtb 结构；我们的完整主线 dtb 任何变体（board-id 0/50、compatible 追加 kona、Android 式 /memory 节点）都被拒；dtbo 必须是完整格式（含 __symbols__/__fixups__ 节点、32MB 分区填充），空表/简化 overlay 全被拒。**结论：主线 7.2 + 自有 dtb 走 ABL 路不通。**
3. **LOS 下游内核方案已验证可跑**（但被弃用）：
   - `los-ref/` 下有 LOS 23.2 官方 boot/vendor_boot/dtbo/vbmeta（已实测可启动）
   - LOS 内核 4.19.325-cip131：UFS/UFS-PHY/USB-NCM/EXT4 全部**内置**，无 devtmpfs、无 VT、无 RD_ZSTD
   - pmOS initramfs（gzip 转换后）可在其上运行；deviceinfo 改 `1d6b:0104` 后 Windows 原生 UsbNcm 驱动建卡 + DHCP 172.16.42.2 + ping 通
   - 卡点 = 无 devtmpfs → /dev 空 → 根分区不可见；修复 = initramfs stage1 tmpfs+mdev（`build-d5.sh`，未及上线即转 UEFI）
4. **HTTP CGI 调试 shell**（重大工具）：busybox httpd + `/cgi-bin/put|run`，POST 命令 GET 结果；在无屏幕/无 telnet 情况下完成根因定位。注意 initramfs 的 busybox telnetd 是 one-shot 且有 pty 问题。
5. **UEFI 路线（选定）**：`0xSelenicDove/edk2-msm-munch`（master，2026-11-20 release）
   - 固件已通过复刻 kernelpatcher 流程刷入 boot_b（`out/uefi-munch-boot.img` = BootShim 补丁 LOS 内核 + munch_UEFI.fd + v3 头 62MB）
   - 实测：**UEFI 运行成功**（屏幕黑底白字滚屏 IO error = 扫描文件系统失败，说明 GOP 控制台活着）
   - Ext2Dxe 读不了现代 ext4（64bit/metadata_csum）→ 新 userdata 用兼容特性重新格式化

### UEFI + pmOS 方案（进行中）
- `out/pmos-uefi-userdata.img`（3GB）：ext4（has_journal,extent,... **无 64bit/metadata_csum**）UUID=687be8df 保持
  - `/EFI/BOOT/BOOTAA64.EFI` = GRUB arm64 standalone（linux/fdt/ext2/part_gpt/search_fs_uuid，内嵌 grub.cfg：search fs-uuid → devicetree /boot/dtb.bin → linux → initrd）
  - `/boot/vmlinuz-pmos`（49MB Image）、`/boot/initramfs.gz`、`/boot/dtb.bin`（headless dtb 123KB）
  - rootfs 内容 rsync 自 root-debug.img（含端口 24 telnetd 调试服务）
- 流程：UEFI BDS 找 BOOTAA64.EFI → GRUB → 主线内核 + **我们自己的 dtb** → pmOS 用户空间
- 脚本：`build-uefi-boot.sh`、`build-pmos-uefi.sh`、`persist-grub.sh`（grub arm64 模块已持久化到 edk2/grub-arm64-efi/）、`flash-uefi-pmos.sh`

### 环境备忘
- WSL /tmp 会被频繁清空（VM 重启）→ 重要产物必须放 F: 或 ~（本目录）
- 所有 wsl.exe 调用必须用脚本文件，禁 bash -c 带 $VAR（吞噬）
- 手机当前状态变量：slot b=UEFI；userdata 已换 pmOS-UEFI 布局（刷入中）；slot a Android 保留
- 红区不变：绝不碰 bootloader/xbl/abl/tz/modem/super/slot a 分区

---

## 2026-11-25 晚：根因定位 → FAT32 userdata 方案（已构建，待刷）

### 源码级确认（edk2-msm-munch @ c518900d）

1. **发布固件没有 Ext2/Ext4 驱动**：`sm8250.fdf` 只有 `FatPkg/EnhancedFatDxe`，加 `munch.fdf.inc` 的 `NtfsDxe`（ntfs_aa64.efi）。→ ext4 userdata 上的 GRUB 固件读不到，屏幕滚屏 IO error = BDS 连接/扫描文件系统失败输出。
2. **SimpleInit GUI 在 munch 构建被禁用**：`sm8250.fdf:203` 的 `# INF src/main/SimpleInitMain.inf`（注释 "Disabled for Direct Windows / UEFI BDS Boot"）。配置机制仅存档：`\simpleinit.uefi.cfg` 放任意卷根，`boot.configs.*` 支持 BOOT_LINUX kernel/dtb/initrd/splash。
3. **FdtBlob 是死代码**：`FdtBlob_compat/munch.dtb` 与 `alioth.dtb` **MD5 相同**（复制占位）；发布它的 `KernelFdtDxe` 也被注释。EFI 配置表实际无 dtb → Linux EFI stub 必须靠 GRUB `devicetree`（GRUB `grub_fdt_install()` 装 GRUB_EFI_DEVICE_TREE_GUID 配置表，源码 fdt.c/linux.c 已核实）。
4. **BDS 自动发现**（`Platform/RenegadePkg/Library/PlatformBootManagerLib/PlatformBm.c` AfterConsole）：刷新全部 BootOption 后，**扫描所有 SimpleFileSystem 的 `\EFI\Microsoft\Boot\bootmgfw.efi` / 否则 `\EFI\Boot\bootaa64.efi`，找到即 AddLoadOptionVariable(position 0) 插 BootOrder 首位**（描述 "Windows Boot Manager"）；`PlatformSetup()` 空函数。
   → **FAT32 userdata + `\EFI\BOOT\BOOTAA64.EFI`(GRUB) 必被自动引导。**

### 内核/initramfs 能力核对（pmOS 7.2.0，config 存 work/kernel.config）
- `CONFIG_BLK_DEV_LOOP=y`（8 loop）、`VFAT_FS=y`、NLS_CP437/ISO8859_1=y、EXT4=y、DEVTMPFS=y、EFI_STUB=y
- initramfs 有 util-linux blkid + losetup；stage2 `run_hooks /hooks` 用 `sh` 子进程执行；`find_partition` 用 `blkid --uuid`（loop 可识别）

### 新方案（已构建）：FAT32 userdata + GRUB + rootfs.img loop
- `out/pmos-fat-userdata.img`（1536MiB FAT32，label **PMOSBOOT**，serial 5A1B-2C3D，fsck 通过）
  - `/EFI/BOOT/BOOTAA64.EFI`：GRUB 2.06 standalone arm64（模块 fat/fdt/linux/search_label/…）
  - `/EFI/BOOT/grub.cfg`（内嵌同款）：主菜单 + debug shell；`search --label PMOSBOOT` → `devicetree /boot/dtb.bin` → `linux … pmos_root_uuid=687be8df-d76e-40ac-b251-8a4032ad04f3` → `initrd`
  - `/boot/{vmlinuz-pmos, initramfs.gz(补丁版), dtb.bin}`
  - `/rootfs.img` = root-debug.img 拷贝（1041MiB ext4，UUID 687be8df-…，label pmOS_root；fstab /boot 改为 `LABEL=PMOSBOOT /boot vfat`）
- initramfs 补丁 `/hooks/50-loop-root.sh`：等 PARTLABEL=userdata（blkid+sysfs 双路）→ vfat 挂 /run/rootimg-fat → losetup rootfs.img；ext4 UUID 由 pmOS 原流程 blkid 发现当根。
- 脚本：`build-fat-uefi.sh`、`patch-initramfs.sh`、`flash-fat-watch.sh`

### 待做
- 刷入观察：GRUB 菜单 10s 自动第一项 → 内核 → Windows 出 UsbNcm 网卡（stage2 setup_usb_network 不依赖 root）→ `ssh user@172.16.42.1`
- 若无 USB 网卡 = 内核早崩（无 console），需换带显示 dtb / UART 再侦查
- 之后：M5 WiFi；屏幕终端+logo

---

## 2026-11-25 夜：M4 完成 ✅（主线 pmOS + UEFI 全链路打通）

**结果**：USB 网络 172.16.42.1，`ssh user@172.16.42.1`（密码 CHANGE_ME_PASSWORD）登录成功。
- kernel 7.2.0-postmarketos-qcom-sm8250-munch，hostname `munch`，systemd 运行
- wlan0 已由 ath11k 驱动创建（WCN6855 固件齐全），待装用户态 WiFi 工具（M5）
- 22/24 端口监听正常；getty@tty1、serial-getty@ttyMSM0 已 mask（无 VT/串口，预期）

### 最终启动架构
UEFI(edk2-msm-munch, slot b) → BDS 扫描 FAT32 `\EFI\Boot\bootaa64.efi` → GRUB(arm64 standalone) →
`devicetree /boot/dtb.bin` + 主线 7.2 内核 + 补丁 initramfs（/boot 均在 FAT 上）→
initramfs hook 挂 `/dev/sda34`(userdata, FAT32) → `losetup /rootfs.img` → ext4 → pmOS 原流程按 UUID 找根 → systemd → sshd

### 本轮踩坑与修复（全部实证）
1. **固件无 ext2/4 驱动**（sm8250.fdf 仅 FatPkg+NtfsDxe；SimpleInit 被禁）→ userdata 必须 FAT32/NTFS；BDS 会自动扫描 `\EFI\Boot\bootaa64.efi`（PlatformBm.c）
2. **FdtBlob_compat/munch.dtb 是 alioth 复制品**，且 KernelFdtDxe 被注释 → dtb 由 GRUB 传
3. **UFS 逻辑块 4096**：FAT32 必须 `mkfs.vfat -S 4096`（否则内核报 "logical sector size too small"，`blocksize=` 选项在新内核已废）；EDK2 FatPkg 与 GRUB 均可读 4096 扇区 FAT（QEMU+AAVMF 已实证）
4. initramfs busybox **没有 httpd**；httpd/tcpsvd 在 busybox-extras
5. rootfs systemd 版：sshd unit `ExecStart=/usr/sbin/sshd.pam`（该文件本就存在）；/sbin、/bin 为 usrmerge 符号链接
6. init_2nd 的 `setup_dynamic_partitions`（deviceinfo super=/dev/sda30）在无 make-dynpart-mappings 服务时可跳过；已用 deviceinfo 覆盖置空
7. **调试通道**：HTTP shell（/run/www + cgi put/run，busybox-extras httpd，stage1 即启动）+ tcpsvd:4444 裸 shell；switch_root 后 /run 被 systemd 重挂 tmpfs 会失效，但足以完成根因定位
8. WSL 离线验证栈：qemu-user 直跑 arm64 二进制；proot（`-r` 需尾斜杠；先 `busybox --install -s`）；QEMU+AAVMF 验证固件 FAT 兼容性；**切勿在 WSL 手动注册 binfmt**（会搞挂 WSL，恢复=wsl --shutdown）

### 产物
- `out/pmos-fat-userdata.img`：1536MiB FAT32(-S 4096) label PMOSBOOT/UUID 5A1B-2C3D
  - /EFI/BOOT/BOOTAA64.EFI(GRUB) + grub.cfg；/boot/{vmlinuz-pmos,initramfs.gz(补丁),dtb.bin}；/rootfs.img(ext4 UUID 687be8df, label pmOS_root)
- 脚本：`build-fat-uefi.sh`、`patch-initramfs.sh`、`flash-fast.sh`（分阶段硬超时）、`qemu-uefi-fat-test.sh`、`offline-verify.sh`
- rootfs 占用 81%（170MB 空闲），后续 apk 安装需注意空间

### M5 待办
- 反向 SSH 隧道复用 PC 代理（WSL: ssh -R 7897:127.0.0.1:7897）→ 手机 apk add iw wpa_supplicant → 配置 WiFi → 路由器内 SSH
- 屏幕终端/logo（用户要求）：需 DT 显示（DRM/fbcon）或 simple-framebuffer
- 清理：mask 的 getty、rootfs 扩容（rootfs.img 置于 FAT 内可在 PC 端离线扩）

---

## 2026-11-25 深夜：M5 达成 ✅（WiFi + 无头 SSH 服务器完成）

**结果**：手机接入家庭 WiFi `CHANGE_ME_SSID`，`ssh user@192.168.0.100` 从局域网访问成功（密码 CHANGE_ME_PASSWORD）。
- wlan0: 192.168.0.100/24，网关 192.168.0.1，公网/DNS 正常（ping 223.5.5.5 ~25ms）
- hostname `munch`，时间已 NTP 同步（Asia/Shanghai），systemd-timesyncd active
- 持久化服务（全部 enabled）：`wpa_supplicant@wlan0`、`wlan0-dhcp`(自建)、`sshd`
- USB 网络仍并存（172.16.42.1/usb0），数据线可拔

### WiFi 配置细节（复现用）
1. 工具安装：`apk add iw wpa_supplicant dhcpcd`（借 SSH 反向隧道用 PC 代理联网：WSL `ssh -R 7897:127.0.0.1:7897`；注意 sshd 默认 `AllowTcpForwarding no`，已改 yes）
2. `/etc/wpa_supplicant/wpa_supplicant-wlan0.conf`：`country=CN`, ssid/psk, `key_mgmt=WPA-PSK`
3. **dhcpcd 在本机不可用**（拿不到地址即退出）；改用 busybox **udhcpc**：
   - 自建脚本 `/usr/local/bin/udhcpc-wlan0.script`（关键：busybox udhcpc 传给脚本的接口变量是 `$interface`，不是 `$IFACE`）
   - 自建 systemd 单元 `wlan0-dhcp.service`（`busybox udhcpc -i wlan0 -s ... -f`，Restart=always）
   - `systemctl disable --now wpa_supplicant.service`（dbus 模式），启用 `wpa_supplicant@wlan0.service`
4. 注意 busybox `ip` 不支持 `addr replace`，脚本里用 flush+add

### 常用操作
- WiFi SSH：`ssh user@192.168.0.100`（密码 CHANGE_ME_PASSWORD；sudo 同一密码）
- USB SSH：`ssh user@172.16.42.1`
- 改 WiFi：编辑 `/etc/wpa_supplicant/wpa_supplicant-wlan0.conf` 后 `systemctl restart wpa_supplicant@wlan0`
- 屏幕终端+logo：仍未做（需要带显示的 dtb/DRM 或 simple-framebuffer；内核当前 headless dtb）
- rootfs 空间 82%（~158MB 空闲），apk 安装前注意

---

## 2026-11-25 下午：显示/触摸移植尝试 ❌ → 已回滚到 headless ✅

### 尝试内容（供以后参考，勿直接部署）
- 应用全部 27 个 alioth(SteamOSforAlioth) 内核补丁：23 个干净；0007/0008 是 Retroid/Mangmi 专用（无对应 dts，跳过）；0017 面板驱动只差 Makefile 一行（已手补）；0027 TDM 与内核树自带实现重复（已删掉补丁注入的重复函数与 ops 行）
- 配置：`CONFIG_DRM_PANEL_SAMSUNG_AMS667XX01=y`、`CONFIG_TOUCHSCREEN_FT8756=m`
- munch dts 加入：DSI0 面板（compatible `xiaomi,alioth-ams667xx01`、vci=pm8150a LDO11 3.0V、vddio=l14a、reset=gpio12）、SPI4 FT8756（reset 33/irq 39，vio=L10C、lab/ibb=L1C）、tlmm 引脚状态；dtc 编译通过
- 从 K40S 原厂 dtbo（只读导出 `out/dtbo_a.img`，27 个 overlay，含 `xiaomi munch`）核对：触摸确为 focaltech@qupv3_se4_spi（33/39，L10C/L1C）；面板由 bootloader 按 panel ID 从 j3s/k81/l81a 等型号中选择，静态 dts 无法确定实际型号（AMS667 init 是 F0/FB 风格，原厂 j3s 是 FF/FB 风格，存在不匹配风险）

### 结果与事故
- 新内核（Image 49,020,928B + 新 dtb + ft8756.ko.zst）写入 FAT 后重启：**黑屏、WiFi/USB 均不出现 → 内核在启动早期挂住**（不是单纯屏不亮）
- `fastboot boot out/boot.img` 返回 OKAY 但设备仍停在 fastboot（ABL 不接受该旧 boot.img），非破坏恢复失败
- 恢复：`flash-fast.sh` 整包回刷 `out/pmos-fat-userdata.img`（10:44 快照，旧内核可用）；**fastboot reboot 常不生效，需要手动长按电源或再发一次**

### 恢复后的 WiFi 重配（重要经验）
- 快照 rootfs 是 06:51 基线，**没有 WiFi 配置，也没有 tmux/kmscon/agetty**
- **apk 不可用**：镜像内 apk-tools 3.0.11 与 /lib/apk/db 的 v2 格式不匹配（`v2 database format error`）
- 绕过 apk：从 Alpine edge aarch64 直接下载并解包二进制到 `/usr/local/wifi`（`LD_LIBRARY_PATH=/usr/local/wifi/lib`）：
  - `wpa_supplicant 2.11-r7`、`iw 6.17-r0`、`libnl3 3.12.0`、`dbus-libs 1.16.4`、`pcsc-lite-libs 2.5.2`
  - 依赖检查：wpa_supplicant 需 libnl/dbus/pcsc + 手机已有 libssl/libcrypto/musl；iw 只需 libnl
- 自建 systemd 单元（已 enabled）：
  - `wpa_supplicant-wlan0.service`：ExecStartPre 固定 MAC `02:00:7b:15:30:a6`（ath11k 默认随机 MAC），主进程 `/usr/local/wifi/bin/wpa_supplicant -Dnl80211`
  - `wlan0-dhcp.service`：`/usr/sbin/udhcpc -i wlan0 -r 192.168.0.100 -s /usr/local/bin/udhcpc-wlan0.script`
- 路由器最终给 **192.168.0.103**（请求 .100 未获批；MAC 固定后 .103 稳定）
- DNS：DHCP 下发的 `192.168.1.1` 无效，已把 `/etc/resolv.conf` 固定为 `192.168.0.1 / 223.5.5.5 / 8.8.8.8`；NTP 已同步

### 当前可用状态（headless）
- `ssh user@192.168.0.103`（密码 CHANGE_ME_PASSWORD）；USB 仍为 172.16.42.1
- WiFi 自启、MAC 固定、DNS/NTP 正常；rootfs 170MB 空闲
- **警告：带显示/面板的内核不可部署**（会黑屏挂起）；FAT 上是可用的旧内核，如需重试显示，务必先在 GRUB 加“一次性测试入口 + 安全默认入口”，避免再次只能 fastboot 救砖

---

## 2026-11-25 整理记录

- 根目录 250+ 个一次性脚本 → 精选 42 个到 `scripts/{build,deploy,verify,ops}`，其余 212 个移入
  `archive/scripts-longtail/`，并保留 `archive/MANIFEST-root-before.txt`（整理前全量 sha256）
- dts 统一到 `dts/`（headless 成果、display 尝试版、`dts/refs/` 参考源）
- `out/` 历史镜像 2.8GB → `out/archive/`；当前交付物与构建输入仍在 `out/` 根
- 新增 `README.md`（成果索引/架构/复现）、`scripts/README.md`（脚本索引）、`artifacts/CHECKSUMS.txt`
- `wsl-export.sh` 去掉 `rm -rf out`（避免误删交付物）
- 以后新增脚本请放进 `scripts/` 对应子目录，不要再堆在根目录

---

## 2026-11-25 下午：userdata 扩容到 223 GiB ✅

**目标**：把 sda34（224.8 GiB）里未使用的 ~223 GiB 用起来，作为 rootfs。

### 方案（不改 GPT、不碰其它分区）

sda34 内部切两段，FAT32 启动区保持原样：

```
sda34 224.8 GiB
  0        .. 1536 MiB   FAT32 "PMOSBOOT"（UEFI/GRUB/内核/initramfs/旧 rootfs.img）
  1536 MiB .. end        ext4 "pmOS_root" 223 GiB（UUID 复用 687be8df-…，不新增分区项）
```

- 手机端用 `losetup -o 1610612736 /dev/loopX /dev/sda34` 映射大段（已挂载的 sda34 也可以，
  实测可行）。注意参数顺序是 **loopdev 在前、file 在后**，写反会 `Invalid argument`。
- `mkfs.ext4 -m 0 -U 687be8df-… -E lazy_itable_init=1,lazy_journal_init=1`
- `rsync -aHAX --numeric-ids --one-file-system` 把当前 rootfs 复制进新 fs（约 768MB）
- 新 initramfs 的 `hooks/50-loop-root.sh`：
  1. 找 PARTLABEL=userdata；
  2. `losetup -o 1536MiB` 映射大 ext4；
  3. `blkid` 校验 UUID + 只读挂载测试；
  4. 成功则保留 loop 给 pmOS 按 UUID 找根；
  5. 任何一步失败 → 回退到挂 FAT + `losetup /rootfs.img`（旧 1GB 根，UUID 相同）。
- 旧 initramfs 保留在 FAT：`/boot/boot/initramfs-old-rootfsimg.gz`。

### 验证结果

```
/dev/loop0  218.7G  已用 784M  可用 218.0G  /
/dev/sda34  1.5G    /boot (FAT)
e2fsck -fn: clean, 8255 files
dmesg: loop-root: offset loop /dev/loop0 uuid=687be8df… big rootfs OK
services: panel-blank / wpa_supplicant-wlan0 / wlan0-dhcp / sshd 全部 active
WiFi: 192.168.0.100（DHCP 请求 .100 成功；此前是 .103）
外网/网关 ping 正常；battery 95% Charging
```

### 备份（PC）

- `out/backup-20261125-133425/`：扩容前 1.5GiB 启动区 + initramfs/grub/vmlinuz/dtb + /etc
- `out/pmos-fat-userdata-grow.img`：扩容后启动 FAT（1.5GiB）
- `out/rootfs-grow-20261125-135002.tar.gz`：扩容后 rootfs（约 437MB）
- 校验和见 `artifacts/CHECKSUMS.txt`

### 警告

- **不要再用 `flash-fast.sh` 刷旧的 `out/pmos-fat-userdata.img`**：那会把 userdata 截回
  1.5GiB 旧布局，大 ext4 虽然物理还在但启动 hook 会找不到/被覆盖。
  （`flash-fast.sh` 已改为刷 `out/pmos-fat-userdata-grow.img`，只覆盖前 1.5GiB。）
- 恢复顺序：优先 `out/pmos-fat-userdata-grow.img`；若必须整包重刷，刷完后要重做扩容
  （`scripts/ops/wsl-grow-rootfs.sh` + `scripts/build/wsl-build-grow-initramfs.sh`）。
- 大 ext4 不是分区，GPT 里仍是 sda34；换系统/重刷 userdata 会丢，需要重新迁移。

---

## 2026-11-25 下午：常用工具安装完成 ✅

扩容后 rootfs 有 218GB，执行两批 apk 安装（无 `--force-overwrite`，标准事务）：

- 第一批 110 个包：bash、coreutils、findutils、grep/sed/gawk/diffutils、file/less、
  procps-ng、psmisc、util-linux、tar/xz/zstd、tree/jq、curl/wget/rsync、openssh-client、
  ca-certificates、bind-tools、iproute2/net-tools/netcat-openbsd/socat、sqlite-libs、
  libffi/libstdc++/zlib/readline/libxml2
- 第二批：git 2.56.1、python3 3.14.10 + pip 26.2.1、gcc 15.2.0、make 4.4.1、musl-dev、
  pkgconf、vim 9.2、nano、htop 3.5.3、strace、lsof、ncdu、unzip/zip、tcpdump 4.99.7、
  sqlite3、openssl 3.5.9、bash-completion

结果：`df -h /` = 219G 总 / 1.2G 已用 / 218G 可用；新 SSH 登录正常（PAM 未被破坏）；
panel-blank / wpa_supplicant-wlan0 / wlan0-dhcp / sshd 全部 active；仅 getty@tty1 和
serial-getty 失败（无 VT/串口，预期）。脚本：`scripts/ops/wsl-apk-tools1.sh`、
`wsl-apk-tools2.sh`、`wsl-verify-tools.sh`。
