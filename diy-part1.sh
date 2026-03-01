#!/bin/bash
# Description: OpenWrt DIY script part 1 (Before Update feeds)

# 1. 移除可能存在的冲突源 (清理 Lean 源码中可能自带的旧引用)
# 这一步非常重要，能确保系统优先使用你在 YAML 中手动 clone 的最新版本
sed -i '/passwall/d' feeds.conf.default
sed -i '/helloworld/d' feeds.conf.default
sed -i '/smartdns/d' feeds.conf.default
sed -i '/luci-theme-argon/d' feeds.conf.default

# 2. [新增优化] 修改默认编译线程数 (针对 D525 超线程优化)
# 虽然 YAML 有 -j$(nproc)，但在某些特定的工具链构建阶段，手动指定能减少死锁
# 针对 D525 的 2核4线程，设置合理并发
echo "CONFIG_COMPILE_THREADS=4" >> .config

# 3. [新增优化] 预置一些常用依赖，防止 feeds update 时因网络问题漏掉基础库
# 这些库是 Passwall 和 SmartDNS 编译时经常需要调用到的
echo 'src-git packages https://github.com/coolsnowwolf/packages' > feeds.conf.default
echo 'src-git luci https://github.com/coolsnowwolf/luci' >> feeds.conf.default
echo 'src-git routing https://github.com/openwrt/routing.git;master' >> feeds.conf.default
echo 'src-git telephony https://github.com/openwrt/telephony.git;master' >> feeds.conf.default

echo "✅ DIY Part 1 冲突清理及基础源配置完成！"
