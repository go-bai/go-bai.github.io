---
title: "如何检查网卡和存储设备是否支持 RDMA"
date: 2025-11-02
tags: ["Linux", "RDMA", "网络", "存储", "InfiniBand"]
summary: "全面介绍如何在 Linux 系统中检查网卡和存储设备的 RDMA 支持情况，包括硬件识别、驱动验证和功能测试"
weight: 6
---

## 什么是 RDMA

RDMA (Remote Direct Memory Access，远程直接内存访问) 是一种网络技术，允许网络适配器直接在应用程序内存和远程系统内存之间传输数据，完全绕过操作系统和 CPU。

### RDMA 的三种主要实现

1. **InfiniBand**：专用的高性能互连技术
2. **RoCE (RDMA over Converged Ethernet)**：在以太网上实现 RDMA
   - RoCE v1：基于以太网链路层
   - RoCE v2：基于 IP/UDP，可路由
3. **iWARP**：在 TCP/IP 上实现 RDMA

## 检查网卡是否支持 RDMA

### 1. 查看网卡硬件信息

使用 lspci 查看网卡型号：

```bash
lspci | grep -i ethernet
lspci | grep -i infiniband
lspci | grep -i network
```

查看详细信息：

```bash
lspci -v -s <bus_id>
```

### 2. 检查 RDMA 设备

查看系统是否识别 RDMA 设备：

```bash
ls -l /sys/class/infiniband/
```

查看 RDMA 设备列表：

```bash
ibv_devices
```

输出示例：

```
    device                 node GUID
    ------              ----------------
    mlx5_0              248a0703001a2d88
    mlx5_1              248a0703001a2d89
```

### 3. 查看 RDMA 设备详细信息

查看特定设备的属性：

```bash
ibv_devinfo
```

输出示例：

```
hca_id: mlx5_0
        transport:                      InfiniBand (0)
        fw_ver:                         16.35.1012
        node_guid:                      248a:0703:001a:2d88
        sys_image_guid:                 248a:0703:001a:2d88
        vendor_id:                      0x02c9
        vendor_part_id:                 4123
        hw_ver:                         0x0
        board_id:                       MT_0000000012
        phys_port_cnt:                  1
                port:   1
                        state:                  PORT_ACTIVE (4)
                        max_mtu:                4096 (5)
                        active_mtu:             4096 (5)
                        sm_lid:                 0
                        port_lid:               0
                        port_lmc:               0x00
                        link_layer:             Ethernet
```

### 4. 检查 RDMA 协议支持

查看网卡支持的 RDMA 协议类型：

```bash
# 查看 link_layer
cat /sys/class/infiniband/*/ports/*/link_layer
```

可能的输出：
- `InfiniBand`：支持原生 InfiniBand
- `Ethernet`：支持 RoCE 或 iWARP

查看 GID 类型（判断 RoCE 版本）：

```bash
# 查看 GID 表
ibv_devinfo -v | grep GID

# 或者直接查看
cat /sys/class/infiniband/mlx5_0/ports/1/gid_attrs/types/*
```

GID 类型说明：
- `IB/RoCE v1`：RoCE v1
- `RoCE v2`：RoCE v2
- `IB`：InfiniBand

### 5. 使用 rdma 工具

现代 Linux 系统推荐使用 `rdma` 命令：

```bash
# 查看所有 RDMA 设备
rdma link

# 输出示例
# link mlx5_0/1 state ACTIVE physical_state LINK_UP netdev ens1f0

# 查看 RDMA 系统信息
rdma system
```

### 6. 检查驱动和模块

查看是否加载了 RDMA 相关模块：

```bash
lsmod | grep -E 'rdma|infiniband|mlx|ib_'
```

常见模块：
- `rdma_cm`：RDMA 连接管理
- `ib_core`：InfiniBand 核心
- `ib_uverbs`：用户空间访问接口
- `mlx5_core`, `mlx5_ib`：Mellanox ConnectX 驱动
- `bnxt_re`：Broadcom 网卡 RDMA
- `i40iw`：Intel XL710 iWARP

查看网卡驱动信息：

```bash
ethtool -i <interface_name>
```

### 7. 检查网络接口的 RDMA 功能

查看网络接口是否关联了 RDMA 设备：

```bash
# 查看网络接口
ip link show

# 查看 RDMA 设备和网络接口的映射
rdma link show

# 或者
ls -l /sys/class/net/*/device/infiniband
```

## 检查存储设备是否支持 RDMA

### 1. NVMe over Fabrics (NVMe-oF)

NVMe-oF 可以使用 RDMA 作为传输层。

查看 NVMe 设备：

```bash
nvme list
```

查看 NVMe 设备的传输类型：

```bash
nvme list-subsys
```

输出示例：

```
nvme-subsys0 - NQN=nqn.2014-08.org.nvmexpress:uuid:...
\
 +- nvme0 rdma traddr=192.168.1.100 trsvcid=4420 live
```

`rdma` 表示使用 RDMA 传输。

查看 NVMe 控制器详细信息：

```bash
nvme id-ctrl /dev/nvme0 | grep -i transport
```

### 2. iSCSI Extensions for RDMA (iSER)

查看 iSCSI 会话是否使用 iSER：

```bash
iscsiadm -m session -P 3 | grep -A5 "iface.transport_name"
```

如果输出包含 `iser`，则使用了 RDMA。

查看 iSER 模块：

```bash
lsmod | grep ib_iser
```

### 3. SMB Direct (SMB over RDMA)

查看 SMB 挂载是否使用 RDMA：

```bash
mount | grep cifs
cat /proc/fs/cifs/DebugData | grep -i rdma
```

## 验证 RDMA 功能

### 1. 安装测试工具

在 Ubuntu/Debian 上：

```bash
apt-get install perftest libibverbs-dev
```

在 RHEL/CentOS 上：

```bash
yum install perftest libibverbs-utils
```

### 2. 基本连通性测试

在服务器端：

```bash
ib_write_bw -d mlx5_0 -i 1
```

在客户端：

```bash
ib_write_bw -d mlx5_0 -i 1 <server_ip>
```

### 3. 性能测试

测试 RDMA Write 带宽：

```bash
# Server
ib_write_bw -a -d mlx5_0

# Client
ib_write_bw -a -d mlx5_0 <server_ip>
```

测试 RDMA Read 带宽：

```bash
# Server
ib_read_bw -a -d mlx5_0

# Client
ib_read_bw -a -d mlx5_0 <server_ip>
```

测试延迟：

```bash
# Server
ib_write_lat -d mlx5_0

# Client
ib_write_lat -d mlx5_0 <server_ip>
```

### 4. 使用 rping 测试 RDMA 连接

测试 RDMA CM (Connection Manager)：

```bash
# Server
rping -s -a 0.0.0.0 -v -C 10

# Client
rping -c -a <server_ip> -v -C 10
```

参数说明：
- `-s`：服务器模式
- `-c`：客户端模式
- `-a`：地址
- `-v`：详细输出
- `-C`：传输次数

## 常见网卡 RDMA 支持情况

### 支持 RDMA 的主要网卡厂商和型号

**Mellanox (NVIDIA)**：
- ConnectX-4/5/6/7 系列
- 支持 InfiniBand 和 RoCE v2

**Intel**：
- X722 系列（iWARP）
- E810 系列（部分型号支持 RoCE）

**Broadcom**：
- NetXtreme-E 系列
- 支持 RoCE v2

**Chelsio**：
- T5/T6 系列
- 支持 iWARP

**Marvell (Cavium)**：
- FastLinQ 41000/45000 系列
- 支持 RoCE v2

### 查看网卡是否在支持列表中

检查内核支持的 RDMA 驱动：

```bash
ls /lib/modules/$(uname -r)/kernel/drivers/infiniband/hw/
```

## 故障排查

### 问题 1：找不到 RDMA 设备

检查步骤：

```bash
# 1. 确认硬件
lspci | grep -i network

# 2. 检查驱动是否加载
lsmod | grep -E 'mlx|ib_'

# 3. 查看内核日志
dmesg | grep -i rdma
dmesg | grep -i infiniband

# 4. 手动加载驱动
modprobe rdma_cm
modprobe ib_core
modprobe mlx5_ib  # 根据你的网卡选择驱动
```

### 问题 2：RDMA 设备存在但无法使用

检查端口状态：

```bash
# 查看端口是否 ACTIVE
ibv_devinfo | grep state

# 查看网络接口是否 UP
ip link show

# 检查 RDMA 子系统状态
rdma link show
```

### 问题 3：性能不达预期

检查配置：

```bash
# 1. 检查 MTU 设置
ip link show <interface>
ibv_devinfo | grep mtu

# 2. 检查网卡硬件卸载功能
ethtool -k <interface> | grep offload

# 3. 检查 IRQ 亲和性
cat /proc/interrupts | grep mlx

# 4. 检查 NUMA 配置
numactl --hardware
```

### 问题 4：RoCE 无法工作

RoCE 特殊要求：

```bash
# 1. 启用无损以太网（PFC - Priority Flow Control）
# 对于 RoCE v1，必须配置
dcbtool sc <interface> pfc e:1 a:1,1,1,1,1,1,1,1

# 2. 检查交换机是否支持 PFC/ECN
# RoCE 对网络质量要求高，需要无丢包环境

# 3. 验证 RoCE 配置
cma_roce_mode  # 查看 RoCE 模式
```

## 实用脚本

完整的 RDMA 检测脚本：

```bash
#!/bin/bash

echo "=== RDMA Hardware Detection ==="
echo

echo "1. Network Adapters:"
lspci | grep -E 'Ethernet|InfiniBand|Network'
echo

echo "2. RDMA Devices:"
if command -v ibv_devices &> /dev/null; then
    ibv_devices
else
    echo "ibv_devices not found. Install libibverbs-utils"
fi
echo

echo "3. RDMA Device Details:"
if command -v ibv_devinfo &> /dev/null; then
    ibv_devinfo | grep -E 'hca_id|transport|link_layer|state'
fi
echo

echo "4. RDMA Modules:"
lsmod | grep -E 'rdma|ib_|mlx|bnxt'
echo

echo "5. RDMA Links:"
if command -v rdma &> /dev/null; then
    rdma link show
fi
echo

echo "6. Network Interfaces with RDMA:"
for iface in $(ls /sys/class/net/); do
    if [ -L "/sys/class/net/$iface/device/infiniband" ]; then
        rdma_dev=$(ls /sys/class/net/$iface/device/infiniband/)
        echo "$iface -> $rdma_dev"
    fi
done
```

保存为 `check_rdma.sh` 并执行：

```bash
chmod +x check_rdma.sh
./check_rdma.sh
```

## 参考资料

- **Linux RDMA 文档**：
  - https://www.kernel.org/doc/html/latest/infiniband/
  - Documentation/infiniband/ in kernel source

- **厂商文档**：
  - NVIDIA Mellanox OFED：https://network.nvidia.com/products/infiniband-drivers/linux/mlnx_ofed/
  - Intel Ethernet RDMA：https://www.intel.com/content/www/us/en/products/docs/network-io/

- **工具和库**：
  - rdma-core：https://github.com/linux-rdma/rdma-core
  - perftest：https://github.com/linux-rdma/perftest

- **标准规范**：
  - InfiniBand Architecture Specification
  - RoCE v2 Specification (Annex A17 in InfiniBand spec)
  - RFC 5040-5043 (iWARP specifications)
