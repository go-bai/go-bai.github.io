---
title: "Libvirt 使用笔记"
date: 2024-07-27T22:57:08+08:00
---

## `virsh` 命令

### `virsh domifaddr` 查看虚拟机网卡ip


```bash
# virsh domifaddr k3s-node01 --source lease
 Name       MAC address          Protocol     Address
-------------------------------------------------------------------------------
```

通过arp获取网卡ip

```bash
# virsh domifaddr k3s-node01 --source arp
 Name       MAC address          Protocol     Address
-------------------------------------------------------------------------------
 vnet18     52:54:00:0e:08:02    ipv4         192.168.1.248/0
```

通过qemu guest agent获取网卡ip

```bash
# virsh domifaddr k3s-node01 --source agent
 Name       MAC address          Protocol     Address
-------------------------------------------------------------------------------
 lo         00:00:00:00:00:00    ipv4         127.0.0.1/8
 enp1s0     52:54:00:0e:08:02    ipv4         192.168.1.248/24
 flannel.1  92:61:59:0c:29:90    ipv4         10.42.0.0/32
 cni0       42:fb:8d:3e:c1:a4    ipv4         10.42.0.1/24
 vethde547696 da:18:a8:b2:ed:f0    N/A          N/A
 vethe1841f6e ce:79:fc:e1:1e:0b    N/A          N/A
 veth464995dc 82:a9:3b:a6:b5:49    N/A          N/A
 veth2370e2ac 4a:c8:32:5c:fb:34    N/A          N/A
```