---
title: "Creating a bridged network with netplan on Ubuntu 22.04"
date: 2023-10-04T13:01:59+08:00
draft: true
tags: [linux,bridged-network,netplan,ubuntu]
---

### 创建一个`bridged network`

创建一个网桥`br0`给虚机使用，使得虚机和其他设备都在一个LAN下

总配置(`netplan get`)如下:

```yaml
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    enp1s0:
      addresses:
      - "192.168.1.100/24"
      nameservers:
        addresses:
        - 192.168.1.1
      dhcp4: false
      dhcp6: false
      routes:
      - to: "default"
        via: "192.168.1.1"
  bridges:
    br0:
      interfaces:
      - enp1s0
      parameters:
        stp: false
```

由三个文件组成:

1. `/etc/netplan/01-network-manager-all.yaml`

```yaml
# Let NetworkManager manage all devices on this system
network:
  version: 2
  renderer: NetworkManager
```

2. `/etc/netplan/10-ethernet-enp1s0.yaml`

```yaml
network:
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 192.168.1.100/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: 
          - 192.168.1.1
```

3. `/etc/netplan/99-bridged-network-br0.yaml`

```yaml
network:
  bridges:
    br0:
      interfaces:
        - enp1s0
      parameters:
        stp: false
```

### 应用网络配置

容易失联，如果是ssh远程操作请谨慎操作

```bash
netplan apply
```

### 补充

1. 如何没有安装`NetworkManager`需要先安装(通过`systemctl status NetworkManager`查看是否安装)

```bash
apt install network-manager -y
```

2. 生产环境可以`systemd-networkd`和`NetworkManager`共存

[nmstate](https://nmstate.io/) 依赖`NetworkManager`服务, NM可以使用`10-globally-managed-devices.conf`配置不管理哪些接口