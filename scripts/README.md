# scripts 索引

所有脚本里的项目根路径固定为 `/mnt/f/project/pmos-munch`（WSL 视角）。

## build/ — 构建

| 脚本 | 作用 |
|---|---|
| `create-pkg-720.sh` | 首次生成 `linux-postmarketos-qcom-sm8250-munch` 包骨架（7.2.0 config + dts） |
| `update-headless-dts.sh` | 把 `dts/sm8250-xiaomi-munch-headless.dts` 同步进包并刷新 APKBUILD sha512 |
| `sync-dts-and-test.sh` | 显示尝试期用：同步 `dts/refs/munch.dts` 并做 cpp+dtc 编译测试 |
| `fix-720-opp.sh` | 7.2.0 dts 的 CPU OPP 编号修正（3.1872GHz → opp22） |
| `wsl-build-kernel720.sh` | pmbootstrap `--src` 增量构建内核（含 .gitignore 规避、进度日志） |
| `wsl-install.sh` | `pmbootstrap install --split` 生成 rootfs/boot |
| `wsl-export.sh` | 导出镜像到 `out/`（已去掉危险的 `rm -rf out`） |
| `patch-initramfs.sh` | 给 initramfs 加 loop-root hook + HTTP 调试 shell（需 root） |
| `build-black-grub.sh` | 构建纯黑屏版 GRUB standalone（生产 + serial 测试两枚） |
| `build-fat-uefi.sh` | ★ 组装 1536MiB FAT32(-S 4096) userdata 镜像（需 root） |
| `build-uefi-boot.sh` | 早期：复刻 kernelpatcher 流程生成 UEFI boot.img（历史参考） |
| `persist-grub.sh` | 下载 grub arm64 模块并持久化到 `edk2/grub-arm64-efi/` |
| `download-all-patches.sh` / `apply-all-patches.sh` | 下载/应用 alioth SteamOS 的 27 个显示补丁（历史） |
| `extract-dtbo.py` | 解析原厂 dtbo（大端头）并导出 27 个 overlay |
| `fix-sm8250-dup.py` | 修 patch 0027 造成的 `sm8250_snd_hw_params` 重复定义 |
| `check-tdm.sh` | 检查 TDM 补丁冲突（显示尝试期） |

## deploy/ — 刷机与部署

| 脚本 | 作用 |
|---|---|
| `flash-fast.sh` | ★ 分阶段硬超时的 fastboot 整包刷写 + HTTP 可达性验证 |
| `flash-fat-watch.sh` | 刷 FAT 镜像并盯启动（早期诊断版） |
| `wsl-deploy-black-grub.sh` | 通过 SSH 替换手机上的 BOOTAA64.EFI/grub.cfg 并重启 |
| `wsl-install-panel-blank2.sh` | 安装 `gpio_hold` + `panel-blank.service`（黑屏） |
| `wsl-test-gpio12.sh` | 临时拉低 GPIO12 测试（90 秒后自动释放） |
| `wsl-prep-gpio-tool.sh` | 查 gpiochip3 + 安装 aarch64 交叉编译器 |

## verify/ — 离线验证

| 脚本 | 作用 |
|---|---|
| `qemu-uefi-fat-test.sh` | QEMU+AAVMF 验证固件能读 4096 扇区 FAT 并启动 GRUB |
| `qemu-test-black-grub.sh` | QEMU+AAVMF 验证黑屏版 GRUB 的 MARK 标记 |
| `qemu-e2e-test.sh` | 端到端（早期） |
| `offline-verify.sh` | proot+qemu-user 跑 initramfs hook/CGI/losetup 全链路（需 root） |
| `verify-artifacts.py` | 校验 boot.img 头、内嵌 dtb、rootfs 完整性 |
| `verify-headless-dtb.sh` | 从 apk 里取 dtb，核对 model/board-id/保留节点 |

## ops/ — 手机侧运维

| 脚本 | 作用 |
|---|---|
| `wsl-fetch-wifi-binaries.sh` | 从阿里云 Alpine edge 下载 WiFi 依赖 apk 并解包 |
| `wsl-stage-wifi-bin.sh` | 组装 `/usr/local/wifi` 上传包 |
| `wsl-install-wifi-bin.sh` | 离线安装 WiFi 二进制（apk 坏掉时的救急方案） |
| `wsl-run-wifi-reprovision.sh` | 重新下发 wpa_supplicant/udhcpc 配置 |
| `wsl-install-wifi-tools.sh` | 反向 SSH 隧道 + apk 安装 iw/wpa_supplicant（历史） |
| `wsl-apk-repair1.sh` | 配置阿里云镜像源 + 尝试修复 apk 数据库 |
| `wsl-apk-rebuild.sh` | ★ apk 数据库重建（移走损坏 installed，重建 world） |
| `wsl-apk-tools1.sh` | 批量安装常用工具/库（待执行） |
| `wsl-pin-mac-reboot.sh` | 固定 wlan0 MAC 并重启网络 |

## 长尾脚本

早期 7.1/6.19 构建、dtbo/vendor_boot 变体、显示/触摸调查等 212 个一次性脚本已移到
`archive/scripts-longtail/`，并附 `archive/MANIFEST-root-before.txt`（含 sha256）。
确认不再需要后可整目录删除。
