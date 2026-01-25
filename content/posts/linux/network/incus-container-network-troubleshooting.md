---
title: "Incus 容器无法联网？两种常见原因及排查指南"
date: 2026-01-25T19:37:55+08:00
---

最近在使用 Incus 创建容器时遇到了网络问题：容器死活无法访问外网。经过排查，发现有两种常见原因会导致这个问题。本文记录完整的排查过程和解决方案，希望能帮助遇到类似问题的朋友。

## 问题现象

创建容器后，容器正常启动并获取到了 IP 地址，但无法访问外网：

```bash
$ incus list
+-------+---------+--------------------+------+-----------+
| NAME  |  STATE  |        IPV4        | IPV6 |   TYPE    |
+-------+---------+--------------------+------+-----------+
| first | RUNNING | 10.81.40.80 (eth0) |      | CONTAINER |
+-------+---------+--------------------+------+-----------+

# 到网关通
$ incus exec first -- ping -c 2 10.81.40.1
64 bytes from 10.81.40.1: icmp_seq=1 ttl=64 time=0.149 ms  ✓

# 到外网不通
$ incus exec first -- ping -c 2 8.8.8.8
0 received, 100% packet loss  ✗
```

## 通用排查步骤

在定位具体原因之前，先做基础检查：

### 1. 检查网络配置

```bash
# 查看 Incus 网络配置
$ incus network show br-lxc
config:
  ipv4.address: 10.81.40.1/24
  ipv4.nat: "true"
name: br-lxc
type: bridge
managed: true
```

确认网桥配置正常，NAT 已启用。

### 2. 检查 IP 转发

```bash
$ cat /proc/sys/net/ipv4/ip_forward
1
```

### 3. 检查主机网络

```bash
$ ping -c 1 8.8.8.8
64 bytes from 8.8.8.8: icmp_seq=1 ttl=108 time=256 ms  ✓
```

### 4. 逐跳测试连通性

```bash
# 容器 -> Incus 网关
$ incus exec first -- ping -c 2 10.81.40.1     ✓

# 容器 -> 上游路由器
$ incus exec first -- ping -c 2 192.168.1.99   ✓ 或 ✗

# 容器 -> 外网
$ incus exec first -- ping -c 2 8.8.8.8        ✗
```

根据逐跳测试结果，可以初步判断问题类型。

---

## 原因一：Docker 的 FORWARD chain 阻断流量

### 症状特点

- 容器只能 ping 通网关
- 无法 ping 通上游路由器
- 系统同时安装了 Docker

### 原因分析

Docker 的 nftables `FORWARD` chain 使用 `policy drop`，但没有规则放行 Incus 桥接流量：

```bash
$ nft list chain ip filter FORWARD
table ip filter {
    chain FORWARD {
        type filter hook forward priority filter; policy drop;
        jump DOCKER-USER      # 空的，不处理
        jump DOCKER-FORWARD   # 只处理 docker0 接口
        jump ts-forward       # 只处理 tailscale0 接口
        # incusbr0 流量没有匹配任何规则 -> 被 policy drop 丢弃
    }
}
```

虽然 Incus 有自己的 `table inet incus` -> `fwd.incusbr0` chain 会 accept 流量，但数据包在到达 Incus chain 之前已被 Docker 的 chain drop。

**关键点**：Docker 的 `ip filter FORWARD` 链优先级与 Incus 的 `inet incus fwd.*` 链相同（都是 filter priority），但 `ip` 表在 `inet` 表之前处理，所以 Docker 的 drop 先生效。

### 解决方案

**方案 A：直接插入规则到 FORWARD chain**

```bash
nft insert rule ip filter FORWARD iifname "incusbr0" accept
nft insert rule ip filter FORWARD oifname "incusbr0" accept
```

**方案 B：使用 DOCKER-USER chain（推荐）**

Docker 设计了 DOCKER-USER chain 供用户添加自定义规则，重启 Docker 不会覆盖：

```bash
nft add rule ip filter DOCKER-USER iifname "incusbr0" accept
nft add rule ip filter DOCKER-USER oifname "incusbr0" accept
```

**持久化配置**

创建 systemd service：

```bash
cat > /etc/systemd/system/incus-nft-fix.service << 'EOF'
[Unit]
Description=Fix nftables for Incus
After=docker.service incus.service

[Service]
Type=oneshot
ExecStart=/usr/sbin/nft add rule ip filter DOCKER-USER iifname "incusbr0" accept
ExecStart=/usr/sbin/nft add rule ip filter DOCKER-USER oifname "incusbr0" accept
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now incus-nft-fix.service
```

---

## 原因二：Tailscale + bridge-nf-call-iptables 冲突

### 症状特点

- 容器可以 ping 通网关
- 容器可以 ping 通上游路由器（说明 NAT 工作正常）
- 但无法 ping 通外网
- 系统安装了 Tailscale
- 抓包发现异常：每个 ping 产生两个请求包

### 深入分析

用 tcpdump 抓包观察：

```bash
# 在 Incus 网桥上抓包
$ tcpdump -i br-lxc -n icmp
10.81.40.80 > 8.8.8.8: ICMP echo request, id 236, seq 1
10.81.40.80 > 8.8.8.8: ICMP echo request, id 236, seq 2
# 只有出站请求，没有回复

# 在出口网卡上抓包
$ tcpdump -i br0 -n "icmp and host 8.8.8.8"
192.168.1.100 > 8.8.8.8: ICMP echo request, id 237, seq 1
192.168.1.100 > 8.8.8.8: ICMP echo request, id 0, seq 1    # 诡异的重复包
8.8.8.8 > 192.168.1.100: ICMP echo reply, id 0, seq 1      # 只有 id=0 的收到回复
```

每个 ping 产生了两个请求包（原始 id=237 和异常 id=0），只有 id=0 的包收到回复，但容器报告 100% 丢包。

### 原因分析

检查 bridge-nf-call-iptables：

```bash
$ sysctl net.bridge.bridge-nf-call-iptables
net.bridge.bridge-nf-call-iptables = 1
```

当 `bridge-nf-call-iptables = 1` 时，通过网桥的二层流量会被送入 netfilter 处理。这意味着容器的流量不仅会经过 Incus 的规则，还会经过 Tailscale 的规则：

```bash
$ nft list chain ip filter ts-forward
table ip filter {
    chain ts-forward {
        iifname "tailscale0" meta mark set mark and 0xff00ffff xor 0x40000
        mark and 0xff0000 == 0x40000 accept
        oifname "tailscale0" ip saddr 100.64.0.0/10 drop
        oifname "tailscale0" accept
    }
}
```

Tailscale 的规则对流量做了标记处理，干扰了容器流量的正常转发路径，导致返回流量无法正确路由回容器。

### 解决方案

禁用 bridge-nf-call-iptables：

```bash
# 临时生效
echo 0 > /proc/sys/net/bridge/bridge-nf-call-iptables
echo 0 > /proc/sys/net/bridge/bridge-nf-call-ip6tables

# 永久生效
cat > /etc/sysctl.d/99-incus-bridge.conf << 'EOF'
net.bridge.bridge-nf-call-iptables = 0
net.bridge.bridge-nf-call-ip6tables = 0
EOF

sysctl -p /etc/sysctl.d/99-incus-bridge.conf
```

---

## 快速诊断流程图

```
容器无法访问外网
        │
        ▼
   能 ping 通网关？ ──No──> 检查容器网络配置
        │
       Yes
        │
        ▼
  能 ping 通上游路由器？
        │
       No                          Yes
        │                           │
        ▼                           ▼
  检查 FORWARD chain            抓包检查
  (可能是 Docker 问题)         (可能是 Tailscale 问题)
        │                           │
        ▼                           ▼
  nft list chain              tcpdump -i <出口网卡>
  ip filter FORWARD           观察是否有重复包
        │                           │
        ▼                           ▼
  policy drop?                bridge-nf-call-iptables=1?
  没有放行 incus 接口?               │
        │                           ▼
        ▼                     禁用 bridge-nf-call-iptables
  添加 DOCKER-USER 规则
```

## 排查命令速查

```bash
# 基础检查
incus network show <bridge-name>
cat /proc/sys/net/ipv4/ip_forward
ping -c 1 8.8.8.8

# 逐跳测试
incus exec <container> -- ping <gateway>
incus exec <container> -- ping <upstream-router>
incus exec <container> -- ping 8.8.8.8

# nftables 规则检查
nft list ruleset
nft list chain ip filter FORWARD
nft list chain inet incus fwd.<bridge-name>

# 抓包分析
tcpdump -i <incus-bridge> -n icmp
tcpdump -i <wan-interface> -n "icmp and host 8.8.8.8"

# bridge-nf 检查
sysctl net.bridge.bridge-nf-call-iptables
lsmod | grep br_netfilter
```

## 总结对比

| 问题类型 | 特征 | 检查方法 | 解决方案 |
|---------|------|---------|---------|
| Docker FORWARD drop | 只能到网关，无法到上游路由器 | `nft list chain ip filter FORWARD` 看 policy | 添加 DOCKER-USER 规则 |
| Tailscale + bridge-nf | 能到上游路由器，抓包有重复包 | 抓包 + 检查 `bridge-nf-call-iptables` | 禁用 bridge-nf-call-iptables |

## 相关环境示例

```
# 网络拓扑
Container (10.81.40.80)
    │
    ▼ veth
Incus Bridge: br-lxc / incusbr0 (10.81.40.1/24 或 10.228.103.1/24)
    │
    ▼ NAT (masquerade)
Host Bridge: br0 (192.168.1.100)
    │
    ▼
Upstream Router (192.168.1.99)
    │
    ▼
Internet

# 可能存在的其他组件
- Docker Bridge: docker0 (172.17.0.0/16)
- Tailscale: tailscale0 (100.x.x.x)
```

## 参考资料

- [Linux Bridge and Netfilter](https://wiki.linuxfoundation.org/networking/bridge)
- [Incus Documentation - Network](https://linuxcontainers.org/incus/docs/main/reference/network_bridge/)
- [Docker and iptables](https://docs.docker.com/network/iptables/)
- [Tailscale Knowledge Base](https://tailscale.com/kb/)