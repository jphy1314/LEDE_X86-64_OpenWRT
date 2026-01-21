#!/bin/bash
# DIY Part 1: 基础设置
# 不拉任何 helloworld / Rust feed

# 修改默认 IP
sed -i 's/192.168.1.1/192.168.5.1/g' package/base-files/files/bin/config_generate
