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

# Copy custom local packages into OpenWrt tree so they are available during build
if [ -d "$GITHUB_WORKSPACE/package/luci-compat-keep" ]; then
  mkdir -p package
  cp -r "$GITHUB_WORKSPACE/package/luci-compat-keep" package/
fi

# 主题改用 feeds/luci 自带的 luci-theme-argon + luci-app-argon-config，
# 不再克隆第三方 Aurora 主题（以下两行已弃用，保留备查）
# git clone https://github.com/eamonxg/luci-theme-aurora package/luci-theme-aurora
# git clone https://github.com/eamonxg/luci-app-aurora-config package/luci-app-aurora-config

git clone https://github.com/timsaya/luci-app-bandix package/luci-app-bandix
git clone https://github.com/timsaya/openwrt-bandix package/openwrt-bandix

# luci-app-run：在 LuCI 页面上传并运行 .run / .sh / .ipk / .apk 安装包
# 注意仓库根目录下的 luci-app-run/ 子目录才是包本体，因此先克隆到临时目录再拷贝
rm -rf /tmp/luci-app-run
git clone --depth=1 https://github.com/wukongdaily/luci-app-run /tmp/luci-app-run
mkdir -p package/luci-app-run
cp -a /tmp/luci-app-run/luci-app-run/. package/luci-app-run/
