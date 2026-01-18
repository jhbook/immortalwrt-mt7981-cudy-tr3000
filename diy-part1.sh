#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Uncomment a feed source
#sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# Add a feed source
#echo 'src-git helloworld https://github.com/fw876/helloworld' >>feeds.conf.default
#echo 'src-git passwall https://github.com/xiaorouji/openwrt-passwall' >>feeds.conf.default

git clone https://github.com/eamonxg/luci-theme-aurora package/luci-theme-aurora
git clone https://github.com/eamonxg/luci-app-aurora-config package/luci-app-aurora-config
git clone https://github.com/timsaya/luci-app-bandix package/luci-app-bandix
git clone https://github.com/timsaya/openwrt-bandix package/openwrt-bandix
git clone https://github.com/EasyTier/luci-app-easytier.git package/luci-app-easytier-tmp

# 拆分官方目录（必须将luci-app-easytier/easytier分别放到package根目录）
cp -rf package/luci-app-easytier-tmp/luci-app-easytier package/
cp -rf package/luci-app-easytier-tmp/easytier package/

# 删除临时目录，减少编译冗余
rm -rf package/luci-app-easytier-tmp

# 修复 luci.util.pcdata 兼容报错（官方指定方案）
sed -i 's/util.pcdata/xml.pcdata/g' package/luci-app-easytier/luasrc/model/cbi/easytier*.lua

#【关键修复】删除 luci-app-easytier 中冲突的 uci-defaults 文件
# 防止它与 luci-i18n-easytier-zh-cn 包冲突
rm -f package/luci-app-easytier/root/etc/uci-defaults/luci-i18n-easytier-zh-cn
