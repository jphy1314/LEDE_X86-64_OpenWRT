#!/bin/bash
# Description: OpenWrt DIY script part 2 (After Update feeds)

# 确保在当前目录下操作，不需要 cd openwrt
if [ ! -d "package" ]; then
    echo "❌ 错误: 找不到 package 目录，请检查脚本运行位置!"
    exit 1
fi

# 确保必要的目录存在 (使用 -p 参数是安全的)
mkdir -p package/base-files/files/bin
mkdir -p package/base-files/files/etc/config
mkdir -p package/base-files/files/etc/hotplug.d/mount
mkdir -p package/base-files/files/etc/crontabs

# 1. 修改默认 IP 为 192.168.5.1
sed -i 's/192.168.1.1/192.168.5.1/g' package/base-files/files/bin/config_generate

# 2. 修改主机名
sed -i 's/OpenWrt/LEDE/g' package/base-files/files/bin/config_generate

# 3. 网络硬件加速
sed -i '/exit 0/d' package/base-files/files/etc/rc.local
cat >> package/base-files/files/etc/rc.local <<'EOF'
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

# 5. 磁盘性能优化脚本
cat > package/base-files/files/etc/hotplug.d/mount/99-optimize-disk << 'EOF'
#!/bin/sh
[ "$ACTION" = "mount" ] || exit 0
[ -z "$MOUNTPOINT" ] && exit 0
if [ -n "$DEVICE" ]; then
    DEV_NAME=$(basename "$DEVICE" | sed 's/[0-9]*$//')
    [ -f "/sys/block/$DEV_NAME/queue/read_ahead_kb" ] && echo 4096 > "/sys/block/$DEV_NAME/queue/read_ahead_kb"
fi
FSTYPE=$(awk -v mp="$MOUNTPOINT" '$2==mp {print $3}' /proc/mounts)
if [ "$FSTYPE" = "ext4" ]; then
    mount -o remount,rw,noatime,nodiratime,errors=remount-ro,commit=60 "$MOUNTPOINT"
fi
EOF
chmod +x package/base-files/files/etc/hotplug.d/mount/99-optimize-disk

# 6. 定时 TRIM
cat >> package/base-files/files/etc/crontabs/root << 'EOF'
0 4 * * * for mp in $(awk '$3 == "ext4" {print $2}' /proc/mounts); do fstrim "$mp"; done
EOF

echo "✅ DIY Part 2 脚本优化完成！"
