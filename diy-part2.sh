#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Modify default IP
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate

# ===== 默认主题改为 Argon =====
# luci 元集合只依赖 luci-light，真正声明默认主题（luci-theme-bootstrap）的是 luci-light 集合
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci-light/Makefile

# 兜底：luci-theme-argon 与 luci-theme-bootstrap 各自带 uci-defaults，会在首次启动时
# 互相覆盖 luci.main.mediaurlbase，这里用 99- 前缀脚本最后锁定 Argon 为默认主题
mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-luci-theme-argon <<'EOF'
#!/bin/sh
uci -q get luci.themes.Argon >/dev/null 2>&1 || uci -q set luci.themes.Argon='/luci-static/argon'
uci -q set luci.main.mediaurlbase='/luci-static/argon'
uci -q commit luci
exit 0
EOF
chmod 0755 package/base-files/files/etc/uci-defaults/99-luci-theme-argon

# Modify hostname
#sed -i 's/OpenWrt/P3TERX-Router/g' package/base-files/files/bin/config_generate

# ===== 软件源替换为南京大学镜像 mirror.nju.edu.cn =====
# /etc/opkg/distfeeds.conf 由 include/feeds.mk 按 %U（即 VERSION_REPO）动态生成，
# 改 include/version.mk 里的 VERSION_REPO 就能把全部 opkg 源指向镜像站
sed -i 's#https://downloads.immortalwrt.org#https://mirror.nju.edu.cn/immortalwrt#g' include/version.mk
sed -i 's#https://mirrors.vsean.net/openwrt#https://mirror.nju.edu.cn/immortalwrt#g' include/version.mk
# 幂等：若源码树里残留了上一轮用过的镜像基址（例如浙大），也一并纠正到南大
sed -i 's#https://mirrors.zju.edu.cn/immortalwrt#https://mirror.nju.edu.cn/immortalwrt#g' include/version.mk
# 说明：源码树里另有 package/mtk/applications/luci-app-openfi/root/usr/opkg/distfeeds.conf
# 这类由其它包自带的静态源文件，其地址指向已废弃的 targets/mediatek/mt7981 路径
# （实测南大/浙大/官方三个镜像均 404），与 /etc/opkg/distfeeds.conf 无关，故不做替换。

# 临时解决Rust问题
sed -i 's/ci-llvm=true/ci-llvm=false/g' feeds/packages/lang/rust/Makefile

# add date in output file name
# 幂等：先把 include/image.mk 恢复成源码树原始版本（历史重复注入会把日期叠成一长串），再注入一次。
# 云端 runner 是干净 clone，不需要这步；本地重复编译时必须要有。
if [ -d .git ]; then
	git checkout -- include/image.mk 2>/dev/null || true
fi
if ! grep -q 'BUILD_DATE' include/image.mk; then
	sed -i -e '/^IMG_PREFIX:=/i BUILD_DATE := $(shell date +%Y%m%d)' \
	       -e '/^IMG_PREFIX:=/ s/\($(SUBTARGET)\)/\1-$(BUILD_DATE)/' include/image.mk
fi

# set ubi to 122M
# 该设备树改动已移到 diy-device.sh：diy-part2.sh 在编译流程里只执行一次，
# 而 112M / 122M 的差异必须按设备在编译循环内逐个应用，否则多设备会互相污染。
# 对应行：reg = <0x5c0000 0x7000000>;  →  reg = <0x5c0000 0x7a40000>;
