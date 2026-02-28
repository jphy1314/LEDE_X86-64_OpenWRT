#!/bin/bash
# Description: OpenWrt DIY script part 1 (Before Update feeds)

# 1. 移除可能存在的冲突源 (清理 Lean 源码中可能自带的旧引用)
sed -i '/passwall/d' feeds.conf.default
sed -i '/helloworld/d' feeds.conf.default
sed -i '/smartdns/d' feeds.conf.default

# 2. 添加 PassWall 源 (利用 feeds 机制自动处理依赖)
echo 'src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main' >> feeds.conf.default
echo 'src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main' >> feeds.conf.default

# 3. 添加 SmartDNS 源 (补回之前在 yml 中删除的部分)
echo 'src-git smartdns https://github.com/pymumu/openwrt-smartdns.git' >> feeds.conf.default
echo 'src-git luci_smartdns https://github.com/pymumu/luci-app-smartdns.git' >> feeds.conf.default

# 4. 添加 Argon 主题源
echo 'src-git argon_theme https://github.com/jerrykuku/luci-theme-argon.git;master' >> feeds.conf.default
