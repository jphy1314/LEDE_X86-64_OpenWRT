#!/usr/bin/env bash
# ==============================================================================
# Script: OpenWrt DIY Part 2 (Enterprise CI/CD Edition)
# Description: Post-update custom configuration script for GitHub Actions
# Target: Intel Atom D525 (Bonnell), High-Performance Disk & Network IO
# ==============================================================================

# 1. 严格模式：遇到错误立刻退出，未定义变量报错，管道失败报错
set -euo pipefail

# 2. 全局变量统一定义（拒绝硬编码，便于后期维护）
readonly TARGET_IP="192.168.5.1"
readonly TARGET_HOSTNAME="LEDE"
readonly TARGET_ARCH_OLD="march=x86-64"
readonly TARGET_ARCH_NEW="march=bonnell"
readonly FILES_DIR="files"
readonly CONFIG_GEN_FILE="package/base-files/files/bin/config_generate"

# 3. GitHub Actions 专属日志与异常捕获系统
trap 'catch_error $? $LINENO' ERR
catch_error() {
    local exit_code="$1"
    local line_no="$2"
    echo "::error file=${BASH_SOURCE[0]},line=${line_no}::❌ 脚本在第 ${line_no} 行发生致命错误! 退出码: ${exit_code}"
    [[ -n "${GITHUB_STEP_SUMMARY:-}" ]] && echo "❌ **构建失败**: 脚本执行中断于第 ${line_no} 行。" >> "$GITHUB_STEP_SUMMARY"
    exit "$exit_code"
}

log_info()    { echo -e "\033[36m[INFO]\033[0m $1"; }
log_success() { 
    echo -e "\033[32m[SUCCESS]\033[0m $1"
    [[ -n "${GITHUB_STEP_SUMMARY:-}" ]] && echo "✅ $1" >> "$GITHUB_STEP_SUMMARY"
}
log_warn()    { echo -e "\033[33m[WARN]\033[0m $1"; }

# ----------------------------------------------------------------
# 阶段 0: 运行环境安全预检
# ----------------------------------------------------------------
if [[ ! -f "scripts/feeds" ]]; then
    echo "::error::当前路径错误！必须在 OpenWrt 源码根目录运行此脚本。"
    exit 1
fi
[[ -n "${GITHUB_STEP_SUMMARY:-}" ]] && echo "### 🛠️ OpenWrt 固件定制报告 (DIY Part 2)" > "$GITHUB_STEP_SUMMARY"

# ----------------------------------------------------------------
echo "::group::阶段 1: 硬件架构与基础网络配置"
# ----------------------------------------------------------------
# 1.1 架构级优化 (Atom D525)
if [[ -f "include/target.mk" ]] && grep -q "$TARGET_ARCH_OLD" "include/target.mk"; then
    sed -i "s/${TARGET_ARCH_OLD}/${TARGET_ARCH_NEW}/g" include/target.mk
    log_success "硬件指令集优化: 强制开启 ${TARGET_ARCH_NEW}"
else
    log_warn "跳过架构优化：未找到目标标识或文件不存在"
fi

# 1.2 默认 IP 与主机名注入
if [[ -f "$CONFIG_GEN_FILE" ]]; then
    sed -i "s/192.168.1.1/${TARGET_IP}/g" "$CONFIG_GEN_FILE"
    sed -i "s/OpenWrt/${TARGET_HOSTNAME}/g" "$CONFIG_GEN_FILE"
    log_success "基础网络配置: IP 设为 ${TARGET_IP}, 主机名设为 ${TARGET_HOSTNAME}"
else
    log_warn "跳过基础配置: 找不到 ${CONFIG_GEN_FILE}"
fi
echo "::endgroup::"

# ----------------------------------------------------------------
echo "::group::阶段 2: 初始化 files 目录骨架"
# ----------------------------------------------------------------
mkdir -p "${FILES_DIR}/"{etc/config,etc/hotplug.d/mount,etc/crontabs,bin}
log_info "已建立 ${FILES_DIR} 注入目录骨架"
echo "::endgroup::"

# ----------------------------------------------------------------
echo "::group::阶段 3: 注入性能调优策略 (网络/磁盘)"
# ----------------------------------------------------------------

# 3.1 网络硬件加速 (rc.local 优雅注入)
# 注意：加入了 command -v 检测，防止因缺少 ethtool 导致不断报错
cat << 'EOF' > "${FILES_DIR}/etc/rc.local"
#!/bin/sh
# Put your custom commands here that should be executed once
# the system init finished. By default this file does nothing.

if command -v ethtool >/dev/null 2>&1; then
    for dev in $(ls /sys/class/net 2>/dev/null | grep -E 'eth|enp|eno'); do
        ethtool -K "$dev" tso on 2>/dev/null
        ethtool -K "$dev" gso on 2>/dev/null
        ethtool -K "$dev" gro on 2>/dev/null
    done
    logger -t "Network-Opt" "硬件加速 (TSO/GSO/GRO) 已启用"
fi
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/rc.local"
log_success "网卡调优: 注入硬件加速自启脚本"

# 3.2 磁盘自动挂载参数
cat << 'EOF' > "${FILES_DIR}/etc/config/fstab"
config global
        option anon_swap '0'
        option anon_mount '1'
        option auto_swap '1'
        option auto_mount '1'
        option delay_root '5'
        option check_fs '0'
EOF
log_success "磁盘调优: 注入 fstab 自动挂载策略"

# 3.3 全局 Hotplug 挂载优化脚本 (修复 ACTION 错误，完美兼容 NVMe)
cat << 'EOF' > "${FILES_DIR}/etc/hotplug.d/mount/99-optimize-disk"
#!/bin/sh
# 【关键修复】OpenWrt 挂载触发的 ACTION 是 add，不是 mount！
[ "$ACTION" = "add" ] || exit 0
[ -z "$MOUNTPOINT" ] && exit 0

# 【智能兼容】兼容 NVMe(nvme0n1p1) / eMMC(mmcblk0p1) / 普通SATA(sda1)
DEV_NAME=""
if [ -n "$DEVICE" ]; then
    case "$DEVICE" in
        *nvme[0-9]*n[0-9]*p[0-9]* | *mmcblk[0-9]*p[0-9]*)
            DEV_NAME=$(echo "$DEVICE" | sed 's/p[0-9]*$//') ;;
        *)
            DEV_NAME=$(basename "$DEVICE" | sed 's/[0-9]*$//') ;;
    esac
    
    # 提升块设备预读到 4MB
    if [ -n "$DEV_NAME" ] && [ -f "/sys/block/$DEV_NAME/queue/read_ahead_kb" ]; then
        echo 4096 > "/sys/block/$DEV_NAME/queue/read_ahead_kb" 2>/dev/null
    fi
fi

# ext4 极限参数重挂载
FSTYPE=$(awk -v mp="$MOUNTPOINT" '$2==mp {print $3}' /proc/mounts 2>/dev/null)
if [ "$FSTYPE" = "ext4" ]; then
    mount -o remount,rw,noatime,nodiratime,errors=remount-ro,commit=60 "$MOUNTPOINT" 2>/dev/null
    logger -t "Disk-Opt" "为 $MOUNTPOINT 开启 ext4 极限性能参数"
fi
EOF
chmod 0755 "${FILES_DIR}/etc/hotplug.d/mount/99-optimize-disk"
log_success "磁盘调优: 注入 Hotplug IO 极限优化脚本"

# 3.4 定时 TRIM 任务 (保证幂等性，防止重复添加)
CRON_FILE="${FILES_DIR}/etc/crontabs/root"
if [[ ! -f "$CRON_FILE" ]] || ! grep -q 'fstrim' "$CRON_FILE"; then
    echo "0 4 * * * for mp in \$(awk '\$3 == \"ext4\" {print \$2}' /proc/mounts 2>/dev/null); do fstrim \"\$mp\" 2>/dev/null; done" >> "$CRON_FILE"
    log_success "存储维护: 注入固态硬盘定时 TRIM 任务"
fi
echo "::endgroup::"

# ----------------------------------------------------------------
echo "::group::阶段 4: 固件依赖包强制补齐 (CI 专属)"
# ----------------------------------------------------------------
# 在 CI 环境下没有人手动点 menuconfig，脚本依赖的组件必须强制注入
cat << 'EOF' >> .config
CONFIG_PACKAGE_ethtool=y
CONFIG_PACKAGE_fstrim=y
CONFIG_PACKAGE_kmod-nvme=y
EOF
log_success "依赖补齐: 强制编译 ethtool, fstrim, nvme"
echo "::endgroup::"

log_info "🎉 DIY Part 2 任务以 0 错误率执行完毕！"
