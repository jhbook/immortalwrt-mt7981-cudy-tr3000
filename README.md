[定制教程](https://xiabee.eu.org/customize.html) | [刷写教程](https://xiabee.eu.org/install.html) | [本地编译教程](./本地编译教程.md)

<div align=center>
<img src="tr3000.png" height=200px align="center">
</div>

---

## immortalwrt 源码

编译自 https://github.com/padavanonly/immortalwrt-mt798x-6.6 ，兼容 Cudy Tr3000 128M 新 flash

---

## ubi 分区档位（64M / 112M / 122M / 256M）

仓库内置四种编译目标，运行 Actions 时在 `device` 里选择（或选 `all` 一次编完全部）：

| 编译目标 | config | ubi 分区 | 设备树 ubi 行 | 适用设备 |
| --- | --- | --- | --- | --- |
| `128M` | `config/128m.config` | 64M | `...-v1.dts`：`<0x5c0000 0x4000000>` | 原厂布局 / 未扩容 |
| `128M-Ubootmod` | `config/128muboot.config` | 112M | `...-v1-ubootmod.dts`：`<0x5c0000 0x7000000>` | 已刷 ubootmod BL2+FIP |
| `122M-Ubootmod` | `config/122m.config` | 122M（到 flash 末尾） | 同上，改写为 `<0x5c0000 0x7a40000>` | 已刷 ubootmod，U-Boot 里选 122M 档 |
| `256M` | `config/256m.config` | 单分区 | `...-v1-256mb.dts` | 256M flash 机型 |

112M 与 122M 的唯一差异是设备树里的 ubi 大小，由 `diy-device.sh` 在编译循环内按设备名切换；`diy-part2.sh` 一个 job 只执行一次，放那里会让多设备互相污染。两者共用同一个 profile，因此产物按 `-ubootmod-112m-` / `-ubootmod-122m-` 重命名区分。

⚠️ **设备树里的 ubi 大小必须和 U-Boot 建立的 ubi 布局一致**，否则内核挂载根文件系统失败 → boot loop（无限重启）。刷 122M 固件前请确认 U-Boot Web 界面里有 122M 档并选中它。

---

## DHCP uboot

编译自 https://github.com/weekdaycare/bl-mt798x-dhcpd 感谢大佬开源，兼容新 flash

![](/uboot.png)

128M uboot 为三分区 uboot 支持原厂 ubi 大小 64MB，扩容 ubi 分区 112MB，最大 ubi 分区 122MB

256M uboot 为单分区 uboot

---

## USB 供电控制

上游的最新源码已经打开了默认供电，具体可以见这条 [commit](https://github.com/padavanonly/immortalwrt-mt798x-6.6/commit/86356f8a2f796e5808fda25ce3e3bf6b3cc3278e)

若你想关闭 USB 供电执行命令

```bash
echo 0 > /sys/class/gpio/modem_power/value
```

恢复供电执行命令

```bash
echo 1 > /sys/class/gpio/modem_power/value
```

---

## 默认主题与软件源

- 默认主题为 **Argon**（`luci-theme-argon` + `luci-app-argon-config`，直接取自 luci feed）。`diy-part2.sh` 已把 `luci-light` 集合的主题依赖由 bootstrap 换成 argon，并写入 `99-luci-theme-argon` 脚本，在首次启动时锁定 `luci.main.mediaurlbase`，避免与各主题自带的 uci-defaults 互相覆盖。
- 固件内置的 opkg 软件源指向南京大学镜像 `https://mirror.nju.edu.cn/immortalwrt/releases/24.10-SNAPSHOT`：由 `diy-part2.sh` 改写源码树 `include/version.mk` 里的 `VERSION_REPO` 生效（`/etc/opkg/distfeeds.conf` 由 `include/feeds.mk` 按 `%U` 动态生成，不是静态文件）。`config/*.config` 里的 `CONFIG_VERSION_REPO` 只是留档：它不是 Kconfig 符号，`make defconfig` 会把它丢掉，真正起作用的是 `version.mk`。

---

## 第三方软件包

- [OpenClash](https://github.com/vernesong/OpenClash)
- [Bandix](https://github.com/timsaya/luci-app-bandix)
- [luci-app-run](https://github.com/wukongdaily/luci-app-run)
- luci-app-ttyd
- luci-app-upnp
- kmod-usb-net-cdc-ether
- kmod-usb-net-rndis
- kmod-mtd-rw

---

## SSH 连接 Action

可以通过 ssh 连接到 Action 工作流来配置 `menuconfig` 。

手动运行 `ImmortalWrt Builder`，选择单个设备（不能选 `all`），并勾选 SSH 选项。
工作流使用 Upterm 公共中继提供 SSH 会话，仅允许使用触发者 GitHub 账号上的 SSH 公钥连接。
在 `SSH connection to Menuconfig` 步骤的日志中找到 SSH 连接命令；连接后执行：

```sh
cd /workdir/openwrt
make menuconfig
# 保存并退出 menuconfig 后，通知工作流继续推送配置和编译：
touch "$GITHUB_WORKSPACE/continue"
```

SSH 步骤最多运行 15 分钟，请在超时前保存配置并创建 `continue` 文件；直接取消运行或超时会跳过配置推送。
如果不显示连接命令，可在 GitHub 的 Re-run jobs 中勾选 Enable debug logging，
检查 Upterm 启动日志及到 `uptermd.upterm.dev` 的连接情况。

---

## 编译注意事项

GitHub Actions 存储有限，大型软件包（如 sing-box 或 alist）建议使用预编译方式，而不是源码编译，即在编译过程中加入已经编译好现成软件包。否则你应该会碰到超长编译时间 + 超出 Action 储存。示例：

```sh
# 创建存储二进制文件的目录
BIN_DIR="$GITHUB_WORKSPACE/openwrt/files/usr/bin"
mkdir -p "$BIN_DIR"

# -------- 下载并解压 xray-core ARM64 -------
echo "Downloading xray-core..."
curl -L -o xray.zip https://github.com/XTLS/Xray-core/releases/download/v25.10.15/Xray-linux-arm64-v8a.zip
unzip -o xray.zip -d "$BIN_DIR"
chmod +x "$BIN_DIR/xray"
rm xray.zip

# -------- 下载并解压 sing-box ARM64 -------
echo "Downloading sing-box..."
curl -L -o sing-box.tar.gz https://github.com/SagerNet/sing-box/releases/download/v1.12.12/sing-box-1.12.12-linux-arm64.tar.gz
TMP_DIR=$(mktemp -d)
tar -xzf sing-box.tar.gz -C "$TMP_DIR"
mv "$TMP_DIR"/sing-box-1.12.12-linux-arm64/sing-box "$BIN_DIR"/sing-box
chmod +x "$BIN_DIR/sing-box"
rm -rf "$TMP_DIR"
rm sing-box.tar.gz
```

---

## Credits

- [bl-mt798x-dhcpd](https://github.com/weekdaycare/bl-mt798x-dhcpd)
- [bl-mt798x](https://github.com/hanwckf/bl-mt798x)
- [immortalwrtwrt](https://github.com/padavanonly/immortalwrt-mt798x-6.6)
- [P3TERX](https://github.com/P3TERX)
- [Microsoft Azure](https://azure.microsoft.com)
- [GitHub Actions](https://github.com/features/actions)
- [OpenWrt](https://github.com/openwrt/openwrt)
- [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede)
- [Mikubill/transfer](https://github.com/Mikubill/transfer)
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release)
- [Mattraks/delete-workflow-runs](https://github.com/Mattraks/delete-workflow-runs)
- [dev-drprasad/delete-older-releases](https://github.com/dev-drprasad/delete-older-releases)
- [peter-evans/repository-dispatch](https://github.com/peter-evans/repository-dispatch)

---

## License

[MIT](https://github.com/P3TERX/Actions-OpenWrt/blob/main/LICENSE) © [**P3TERX**](https://p3terx.com)
