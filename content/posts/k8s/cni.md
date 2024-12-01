---
title: "CNI 工作原理"
date: 2024-11-17T20:30:06+08:00
draft: true
toc: true
tags: [k8s,cni]
---

## 关于 CNI

CNI 全称 `Container Network Interface`, 容器网络接口, cni 插件是可执行文件, 一般位于 `/opt/cni/bin/` 目录

在 k8s 中, kubelet 调用 cri 创建 sandbox 时(RunPodSandbox)会先去创建 network namespace, 然后创建 pause 和 其他容器并将容器加入到同一个 network namespace 中

cni spec 文档: https://www.cni.dev/docs/spec/

有如下[环境变量参数](https://www.cni.dev/docs/spec/#parameters):

- `CNI_COMMAND`: 对应操作 `ADD`, `DEL`, `CHECK`, or `VERSION`.
- `CNI_CONTAINERID`: 容器 id
- `CNI_NETNS`: 如 `/var/run/netns/[nsname]`
- `CNI_IFNAME`: 要在容器中创建的接口名称, 一般容器中都是 `eth0`
- `CNI_ARGS`: 额外的 kv 参数, 如 `FOO=BAR;ABC=123`
- `CNI_PATH`: 搜索 cni plugin 可执行文件的目录

## 插件分析

### bridge

主要是 `cmdAdd` 和 `cmdDel` 两个函数, 对应 CNI spec 中的 `ADD` 和 `DEL` 两个主要操作

#### cmdAdd

TODO: 分析代码

1. setupBridge 确保机器上存储对应的 bridge
2. setupVeth 在对应的 netns 下创建 veth
3. 执行 ipam.ExecAdd(n.IPAM.Type, args.StdinData) 获取 ip 地址
4. 执行 ipam.ConfigureIface(args.IfName, result) 将 ip 地址设知道对应的 veth 上


## cni 测试工具 `cnitool`

https://www.cni.dev/docs/cnitool/

### 创建 netns testing

```bash
$ ip netns add testing
$ ip netns list
testing
```

### 创建 bridge-static

```bash
cat <<EOF > /etc/cni/net.d/999-bridge-static.conf
{
  "cniVersion": "0.4.0",
  "name": "bridge-static",
  "type": "bridge",
  "bridge": "br0",
  "ipam": {
    "type": "static",
    "routes": [
      {
        "dst": "0.0.0.0/0",
        "gw": "192.168.1.99"
      }
    ],
    "addresses": [
      {
        "address": "192.168.1.67/24"
      }
    ]
  }
}
EOF
```

### 将 bridge-static 添加至 testing netns

```bash
$ CNI_PATH=/opt/cni/bin cnitool add bridge-static /var/run/netns/testing
{
    "cniVersion": "0.4.0",
    "interfaces": [
        {
            "name": "br0",
            "mac": "b2:0c:ce:e1:37:1e"
        },
        {
            "name": "veth56b82c3a",
            "mac": "c6:44:a7:57:57:2d"
        },
        {
            "name": "eth0",
            "mac": "1e:d1:07:6b:a2:6a",
            "sandbox": "/var/run/netns/testing"
        }
    ],
    "ips": [
        {
            "version": "4",
            "interface": 2,
            "address": "192.168.1.67/24"
        }
    ],
    "routes": [
        {
            "dst": "0.0.0.0/0",
            "gw": "192.168.1.99"
        }
    ],
    "dns": {}
}
```

### 检查 netns 里是否成功配置网络

```bash
$ ip -n testing addr
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: eth0@if18: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default
    link/ether 1e:d1:07:6b:a2:6a brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 192.168.1.67/24 brd 192.168.1.255 scope global eth0
       valid_lft forever preferred_lft forever
$ ip -n testing route
default via 192.168.1.99 dev eth0
192.168.1.0/24 dev eth0 proto kernel scope link src 192.168.1.67
$ ip netns exec testing ping -c 1 192.168.1.99
PING 192.168.1.99 (192.168.1.99) 56(84) bytes of data.
64 bytes from 192.168.1.99: icmp_seq=1 ttl=64 time=0.725 ms

--- 192.168.1.99 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.725/0.725/0.725/0.000 ms
```