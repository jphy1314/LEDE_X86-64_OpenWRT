#!/bin/bash
# Description: OpenWrt DIY script part 1 (Before Update feeds)

# 1. 移除可能存在的冲突源 (清理 Lean 源码中可能自带的旧引用)
sed -i '/passwall/d' feeds.conf.default
sed -i '/helloworld/d' feeds.conf.default

# 2. 添加 PassWall 源 (利用 feeds 机制自动处理依赖，比 git clone 更稳定)
echo 'src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main' >> feeds.conf.default
echo 'src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main' >> feeds.conf.default

# 3. 添加 Argon 主题源 (如果需要最新版)
echo 'src-git argon_theme https://github.com/jerrykuku/luci-theme-argon.git;master' >> feeds.conf.default
