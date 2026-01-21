#!/bin/bash
# DIY Part 2: 禁用 Rust 包，保留 PassWall 依赖

sed -i 's/CONFIG_PACKAGE_shadowsocks-rust=y/# CONFIG_PACKAGE_shadowsocks-rust is not set/' .config
sed -i 's/CONFIG_PACKAGE_v2ray-core=y/# CONFIG_PACKAGE_v2ray-core is not set/' .config
sed -i 's/CONFIG_PACKAGE_xray-core=y/# CONFIG_PACKAGE_xray-core is not set/' .config
sed -i 's/CONFIG_PACKAGE_hysteria=y/# CONFIG_PACKAGE_hysteria is not set/' .config
sed -i 's/CONFIG_PACKAGE_rust=y/# CONFIG_PACKAGE_rust is not set/' .config
