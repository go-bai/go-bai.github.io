---
title: "无线转有线网络"
date: 2024-04-09T22:16:24+08:00
draft: false
toc: true
tags: [network,linux]
---

> 通过无线网卡连接网络`A(192.168.31.0/24)`, 无线网卡相当于`WAN`口，通过有线网卡接入网络`B(192.168.1.0/24)`, 有线网卡相当于`LAN`口

## 准备一个ubuntu虚拟机`router`

```bash
# 准备qcow2基础镜像
wget https://down.idc.wiki/Image/realServer-Template/current/qcow2/ubuntu22.qcow2 -O /var/lib/libvirt/images/ubuntu.qcow2
# 创建虚拟机以基础镜像为backing file的增量盘
qemu-img create -f qcow2 -F qcow2 -b /var/lib/libvirt/images/ubuntu.qcow2 /var/lib/libvirt/disks/router.qcow2
# 创建并启动虚拟机
virt-install --name router --memory 512 --vcpus 1 --disk /var/lib/libvirt/disks/router.qcow2,bus=sata --import --os-variant ubuntu22.10 --network bridge=br0 --noautoconsole
# 设置自动启动
virsh autostart router
```

## 配置网络

### 将无线网卡透传进虚拟机

打开 `virt-manager` -> 双击 `router domain` -> 点击 `Show virtual hardware details` -> 点击 `Add Hardware` -> 点击 `PCI Host Device` -> 选择 `Intel Corporation Wi-Fi 6 AX200` -> 点击 `Finish`

`virsh console router`进虚拟机里检查发现已存在一个有线网卡`enp1s0`和无线网卡`wlp6s0`

### 使用`netplan`配置网卡

```yaml
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
      addresses: [192.168.1.110/24]
  wifis:
    wlp6s0:
      dhcp4: no
      access-points:
        "wifi名称":
          password: "wifi密码"
      addresses: [192.168.31.88/24]
      nameservers:
        addresses: [223.5.5.5, 114.114.114.114]
      routes:
        - to: default
          via: 192.168.31.1
```

### 配置`NAT`网络

开启`ipv4 forward`

1. `vim /etc/sysctl.conf`

```diff
- #net.ipv4.ip_forward=1
+ net.ipv4.ip_forward=1
```

2. `sysctl -p`

设置`SNAT`和伪装

```bash
iptables -t nat -A POSTROUTING -s '192.168.1.0/24' -o wlp6s0 -j MASQUERADE
# 持久化规则
DEBIAN_FRONTEND=noninteractive apt install iptables-persistent -y
iptables-save -c > /etc/iptables/rules.v4
```

## 参考

- [Problem with my iptables configuration on reboot](https://askubuntu.com/questions/1452706/problem-with-my-iptables-configuration-on-reboot)



