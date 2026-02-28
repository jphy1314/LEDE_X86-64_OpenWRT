#!/bin/bash
# Description: OpenWrt DIY script part 2 (After Update feeds)

# 【核心修复】确保脚本在 openwrt 源码目录下运行
[ -d "package" ] || cd openwrt || { echo "❌ 找不到 openwrt 目录"; exit 1; }

# 1. 修改默认 IP 为 192.168.5.1
sed -i 's/192.168.1.1/192.168.5.1/g' package/base-files/files/bin/config_generate

# 2. 修改主机名
sed -i 's/OpenWrt/LEDE/g' package/base-files/files/bin/config_generate

# 确保目标目录存在（防止某些精简版源码缺失目录）
mkdir -p package/base-files/files/etc/config
mkdir -p package/base-files/files/etc/hotplug.d/mount
mkdir -p package/base-files/files/etc/crontabs

# ================================================================
# 👇 [基础优化] 网络硬件加速
# ================================================================

# 修改 rc.local 开机脚本
# 先删除重复的 exit 0，防止多次运行脚本导致 exit 0 出现在中间
sed -i '/exit 0/d' package/base-files/files/etc/rc.local
cat >> package/base-files/files/etc/rc.local <<'EOF'
# 开启网卡硬件加速 (针对常见的 eth0)
ethtool -K eth0 tso on 2>/dev/null
ethtool -K eth0 gso on 2>/dev/null
exit 0
EOF

# ================================================================
# 👇 [磁盘极限动态优化] 自动感知并注入参数
# ================================================================

# 1. 开启系统的全局“自动挂载”
cat > package/base-files/files/etc/config/fstab << 'EOF'
config global
        option anon_swap '0'
        option anon_mount '1'
        option auto_swap '1'
        option auto_mount '1'
        option delay_root '5'
        option check_fs '0'
EOF

# 2. 编写全局 Hotplug 触发脚本
cat > package/base-files/files/etc/hotplug.d/mount/99-optimize-disk << 'EOF'
#!/bin/sh
[ "$ACTION" = "mount" ] || exit 0
[ -z "$MOUNTPOINT" ] && exit 0

# (A) 提升 4MB 预读缓存
if [ -n "$DEVICE" ]; then
    DEV_NAME=$(basename "$DEVICE" | sed 's/[0-9]*$//')
    [ -f "/sys/block/$DEV_NAME/queue/read_ahead_kb" ] && echo 4096 > "/sys/block/$DEV_NAME/queue/read_ahead_kb"
fi

# (B) 重挂载 ext4 极限参数
FSTYPE=$(awk -v mp="$MOUNTPOINT" '$2==mp {print $3}' /proc/mounts)
if [ "$FSTYPE" = "ext4" ]; then
    mount -o remount,rw,noatime,nodiratime,errors=remount-ro,commit=60 "$MOUNTPOINT"
    logger -t "Disk-Optimizer" "已自动为 $MOUNTPOINT ($DEVICE) 开启 ext4 极限模式"
fi
EOF
chmod +x package/base-files/files/etc/hotplug.d/mount/99-optimize-disk

# 3. 动态定时 TRIM (修正了 awk 匹配逻辑)
# 使用 >> 防止覆盖用户已有的计划任务
cat >> package/base-files/files/etc/crontabs/root << 'EOF'
0 4 * * * for mp in $(awk '$3 == "ext4" {print $2}' /proc/mounts); do fstrim "$mp"; logger -t "fstrim" "已完成 $mp 碎片回收"; done
EOF

echo "✅ DIY Part 2 脚本执行完成"
