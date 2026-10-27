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

# ===== 软件源替换为浙江大学镜像 mirrors.zju.edu.cn =====
# /etc/opkg/distfeeds.conf 由 include/feeds.mk 按 %U（即 VERSION_REPO）动态生成，
# 改 include/version.mk 里的 VERSION_REPO 就能把全部 opkg 源指向镜像站
sed -i 's#https://downloads.immortalwrt.org#https://mirrors.zju.edu.cn/immortalwrt#g' include/version.mk
sed -i 's#https://mirrors.vsean.net/openwrt#https://mirrors.zju.edu.cn/immortalwrt#g' include/version.mk
# 兜底：源码树里若存在静态 distfeeds 模板也一并替换
grep -rl 'downloads.immortalwrt.org' --include='distfeeds*' . 2>/dev/null | xargs -r sed -i 's#https://downloads.immortalwrt.org#https://mirrors.zju.edu.cn/immortalwrt#g'

# 临时解决Rust问题
sed -i 's/ci-llvm=true/ci-llvm=false/g' feeds/packages/lang/rust/Makefile

# add date in output file name
sed -i -e '/^IMG_PREFIX:=/i BUILD_DATE := $(shell date +%Y%m%d)' \
       -e '/^IMG_PREFIX:=/ s/\($(SUBTARGET)\)/\1-$(BUILD_DATE)/' include/image.mk

# set ubi to 122M
# sed -i 's/reg = <0x5c0000 0x7000000>;/reg = <0x5c0000 0x7a40000>;/' target/linux/mediatek/dts/mt7981b-cudy-tr3000-v1-ubootmod.dts
