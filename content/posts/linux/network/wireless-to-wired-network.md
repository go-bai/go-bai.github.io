---
title: "无线转有线网络"
date: 2024-04-09T22:16:24+08:00
---

> 通过无线网卡连接网络`A(192.168.31.0/24)`, 无线网卡相当于`WAN`口，通过有线网卡接入网络`B(192.168.1.0/24)`, 有线网卡相当于`LAN`口

## 准备一个ubuntu虚拟机`router`

```bash
# 准备qcow2基础镜像
wget https://down.idc.wiki/Image/realServer-Template/current/qcow2/ubuntu22.qcow2 -O /var/lib/libvirt/images/ubuntu.qcow2
# 创建虚拟机以基础镜像为backing file的增量盘
qemu-img create -f qcow2 -F qcow2 -b /var/lib/libvirt/images/ubuntu.qcow2 /var/lib/libvirt/disks/router.qcow2 20G
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

### 查看无线网卡信息

#### 安装

```bash
apt install wireless-tools -y
```

#### 查看无线网卡频率

有些wifi配置2.4G和5G网络合并显示, 所以如果信号不好时会连上2.4GHz的频段, 使用`iwlist`命令查看无线网卡的频率

```bash
# iwlist wlp6s0 freq
wlp6s0    32 channels in total; available frequencies :
          Channel 01 : 2.412 GHz
          Channel 02 : 2.417 GHz
          Channel 03 : 2.422 GHz
          Channel 04 : 2.427 GHz
          Channel 05 : 2.432 GHz
          Channel 06 : 2.437 GHz
          Channel 07 : 2.442 GHz
          Channel 08 : 2.447 GHz
          Channel 09 : 2.452 GHz
          Channel 10 : 2.457 GHz
          Channel 11 : 2.462 GHz
          Channel 12 : 2.467 GHz
          Channel 13 : 2.472 GHz
          Channel 36 : 5.18 GHz
          Channel 40 : 5.2 GHz
          Channel 44 : 5.22 GHz
          Channel 48 : 5.24 GHz
          Channel 52 : 5.26 GHz
          Channel 56 : 5.28 GHz
          Channel 60 : 5.3 GHz
          Channel 64 : 5.32 GHz
          Channel 100 : 5.5 GHz
          Channel 104 : 5.52 GHz
          Channel 108 : 5.54 GHz
          Channel 112 : 5.56 GHz
          Channel 116 : 5.58 GHz
          Channel 120 : 5.6 GHz
          Channel 124 : 5.62 GHz
          Channel 128 : 5.64 GHz
          Channel 132 : 5.66 GHz
          Channel 136 : 5.68 GHz
          Channel 140 : 5.7 GHz
          Current Frequency:5.18 GHz (Channel 36)
```

## 参考

- [Problem with my iptables configuration on reboot](https://askubuntu.com/questions/1452706/problem-with-my-iptables-configuration-on-reboot)



