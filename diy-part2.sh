#!/bin/bash
# Description: OpenWrt DIY script part 2 (After Update feeds)

# 【核心修复】自动识别目录，防止在 GitHub Actions 中路径报错
if [ -d "openwrt/package" ]; then
    cd openwrt
elif [ ! -d "package" ]; then
    echo "❌ 错误: 找不到 OpenWrt 源码目录!"
    exit 1
fi

# 确保必要的目录存在
mkdir -p package/base-files/files/bin
mkdir -p package/base-files/files/etc/config
mkdir -p package/base-files/files/etc/hotplug.d/mount
mkdir -p package/base-files/files/etc/crontabs

# 1. 修改默认 IP 为 192.168.5.1
[ -f package/base-files/files/bin/config_generate ] && \
sed -i 's/192.168.1.1/192.168.5.1/g' package/base-files/files/bin/config_generate

# 2. 修改主机名
[ -f package/base-files/files/bin/config_generate ] && \
sed -i 's/OpenWrt/LEDE/g' package/base-files/files/bin/config_generate

# 3. 网络硬件加速 (修改 rc.local)
sed -i '/exit 0/d' package/base-files/files/etc/rc.local
cat >> package/base-files/files/etc/rc.local <<'EOF'
# 开启网卡 TX 硬件加速 (需要 ethtool 支持)
ethtool -K eth0 tso on 2>/dev/null
ethtool -K eth0 gso on 2>/dev/null
exit 0
EOF

# 4. 磁盘自动挂载配置 (fstab)
cat > package/base-files/files/etc/config/fstab << 'EOF'
config global
        option anon_swap '0'
        option anon_mount '1'
        option auto_swap '1'
        option auto_mount '1'
        option delay_root '5'
        option check_fs '0'
EOF

# 5. 编写全局 Hotplug 触发脚本 (极限读写性能优化)
cat > package/base-files/files/etc/hotplug.d/mount/99-optimize-disk << 'EOF'
#!/bin/sh
[ "$ACTION" = "mount" ] || exit 0
[ -z "$MOUNTPOINT" ] && exit 0

# 提升 4MB 预读缓存
if [ -n "$DEVICE" ]; then
    DEV_NAME=$(basename "$DEVICE" | sed 's/[0-9]*$//')
    if [ -f "/sys/block/$DEV_NAME/queue/read_ahead_kb" ]; then
        echo 4096 > "/sys/block/$DEV_NAME/queue/read_ahead_kb"
    fi
fi

# 甄别 ext4 并重挂载极限参数
FSTYPE=$(awk -v mp="$MOUNTPOINT" '$2==mp {print $3}' /proc/mounts)
if [ "$FSTYPE" = "ext4" ]; then
    mount -o remount,rw,noatime,nodiratime,errors=remount-ro,commit=60 "$MOUNTPOINT"
    logger -t "Disk-Optimizer" "已自动为 $MOUNTPOINT ($DEVICE) 开启 ext4 极限性能模式"
fi
EOF
chmod +x package/base-files/files/etc/hotplug.d/mount/99-optimize-disk

# 6. 定时 TRIM (凌晨 4 点自动回收固态硬盘碎片)
cat >> package/base-files/files/etc/crontabs/root << 'EOF'
0 4 * * * for mp in $(awk '$3 == "ext4" {print $2}' /proc/mounts); do fstrim "$mp"; logger -t "fstrim" "已完成 $mp 的碎片回收"; done
EOF

echo "✅ DIY Part 2 脚本优化完成！"
