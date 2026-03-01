#!/bin/bash
# Description: OpenWrt DIY script part 2 (After Update feeds)

# 【核心修复】检查是否在 openwrt 目录
if [ ! -f "scripts/feeds" ]; then
    echo "❌ 错误: 必须在 openwrt 根目录运行此脚本!"
    exit 1
fi

# ----------------------------------------------------------------
# 1. 架构级优化：针对 Intel Atom D525 (Bonnell)
# ----------------------------------------------------------------
# 将默认的通用 x86-64 优化为专为 Atom D525 设计的指令集
if [ -f "include/target.mk" ]; then
    sed -i 's/march=x86-64/march=bonnell/g' include/target.mk
    echo "✅ 已开启 Atom Bonnell (D525) 硬件指令集优化"
fi

# ----------------------------------------------------------------
# 2. 目录准备 (使用编译系统的 files 机制，而不是直接改源码包)
# ----------------------------------------------------------------
# 编译时，根目录下的 files 文件夹会自动覆盖到系统的 / 目录
ROOT_FILES="files"
mkdir -p $ROOT_FILES/etc/config
mkdir -p $ROOT_FILES/etc/hotplug.d/mount
mkdir -p $ROOT_FILES/etc/crontabs
mkdir -p $ROOT_FILES/bin

# ----------------------------------------------------------------
# 3. 基础系统配置
# ----------------------------------------------------------------

# 修改默认 IP 为 192.168.5.1
# 注意：config_generate 在源码包内，这里保留你原本的修改逻辑
[ -f package/base-files/files/bin/config_generate ] && \
sed -i 's/192.168.1.1/192.168.5.1/g' package/base-files/files/bin/config_generate

# 修改主机名
[ -f package/base-files/files/bin/config_generate ] && \
sed -i 's/OpenWrt/LEDE/g' package/base-files/files/bin/config_generate

# ----------------------------------------------------------------
# 4. 网络硬件加速 (修改 rc.local)
# ----------------------------------------------------------------
# 确保目标文件存在于 files 目录
cat > $ROOT_FILES/etc/rc.local <<'EOF'
# 开启网卡硬件加速 (需要固件包含 ethtool)
for dev in $(ls /sys/class/net | grep -E 'eth|enp|eno'); do
    ethtool -K $dev tso on 2>/dev/null
    ethtool -K $dev gso on 2>/dev/null
    ethtool -K $dev gro on 2>/dev/null
done
exit 0
EOF

# ----------------------------------------------------------------
# 5. 磁盘与性能优化
# ----------------------------------------------------------------

# 磁盘自动挂载配置 (fstab)
cat > $ROOT_FILES/etc/config/fstab << 'EOF'
config global
        option anon_swap '0'
        option anon_mount '1'
        option auto_swap '1'
        option auto_mount '1'
        option delay_root '5'
        option check_fs '0'
EOF

# 全局 Hotplug 挂载优化脚本 (极限读写性能)
cat > $ROOT_FILES/etc/hotplug.d/mount/99-optimize-disk << 'EOF'
#!/bin/sh
[ "$ACTION" = "mount" ] || exit 0
[ -z "$MOUNTPOINT" ] && exit 0

# 提升 4MB 预读缓存
DEV_NAME=$(basename "$DEVICE" | sed 's/[0-9]*$//')
if [ -f "/sys/block/$DEV_NAME/queue/read_ahead_kb" ]; then
    echo 4096 > "/sys/block/$DEV_NAME/queue/read_ahead_kb"
fi

# 甄别 ext4 并重挂载极限参数 (针对 D525 弱 CPU 优化，减少 I/O 等待)
FSTYPE=$(awk -v mp="$MOUNTPOINT" '$2==mp {print $3}' /proc/mounts)
if [ "$FSTYPE" = "ext4" ]; then
    mount -o remount,rw,noatime,nodiratime,errors=remount-ro,commit=60 "$MOUNTPOINT"
    logger -t "Disk-Optimizer" "已为 $MOUNTPOINT 开启 ext4 优化参数"
fi
EOF
chmod +x $ROOT_FILES/etc/hotplug.d/mount/99-optimize-disk

# 定时 TRIM (凌晨 4 点)
cat >> $ROOT_FILES/etc/crontabs/root << 'EOF'
0 4 * * * for mp in $(awk '$3 == "ext4" {print $2}' /proc/mounts); do fstrim "$mp" 2>/dev/null; done
EOF

echo "✅ DIY Part 2 脚本优化完成！"
