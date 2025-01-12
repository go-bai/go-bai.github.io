---
title: "深入了解 Kubernetes CNI 网络插件 Flannel"
date: 2025-01-01T13:11:35+08:00
draft: false
toc: true
tags: [flannel]
---

## 关于

[flannel](https://github.com/flannel-io/flannel) 是由 CoreOS 开发的一个简单易用的容器网络插件

网络是 k8s 中至关重要的一部分, 这里以简单的 flannel 为例做深入分析

### 工作原理

> 以下介绍在 chart 方式部署的 flannel

flanneld 进程以 daemonset/kube-flannel-ds 方式运行在所有 node 上, 负责从提前配置好的网络池中分配子网租约 (subnet lease) 给 node.

flanneld 使用 k8s api 或者 etcd 存储网络配置、分配的子网和任何补充数据(如 node 的 public ip), 在 k8s 中使用一般不会单独提供 etcd 去存储这些数据.
- 网络配置存储在 configmap 中, kube-flannel ns 下的 cm/kube-flannel-cfg 中
- 分配的子网存储在 PodCIDR 中

flannel 通过 informer 去 list/watch node 资源来动态设置网络, 主要是设置 route, arp 和 fdb 网络配置.

flannel 支持多种 pod 之间数据的转发后端(`backend`), 一旦设置 `backend` 就不应该在运行中更改, 推荐使用 `VXLAN`

#### 推荐的 backend

##### VXLAN (Virtual eXtensible LAN) 虚拟可扩展局域网

关于 [VXLAN](https://www.kernel.org/doc/Documentation/networking/vxlan.txt) 简单介绍:

VXLAN 协议是一个隧道协议, 用来解决 VLAN ID 在 IEEE 802.1q 中限制只能有 4096(12bit) 个的问题. 在 VXLAN 中, VXLAN 标识符(VNI)的大小扩展至 16777216(24bit).

VXLAN 由 [IETF RFC7348](https://datatracker.ietf.org/doc/html/rfc7348) 描述, 并且被很多厂商实现(如linux kernel vxlan module)了, 该协议使用单个目的端口(一般是`4789`)运行在 UDP 之上.

##### host-gw

使用host-gw创建通过远程机器IP到子网的IP路由, 需要在运行 flannel 的主机之间建立直接的 layer2 连接

Host-gw提供了良好的性能, 很少依赖, 并且易于设置

##### WireGuard

使用内核内的WireGuard封装和加密报文.

##### UDP

如果你的网络和内核不支持使用VXLAN或host-gw, 则仅在调试时使用UDP.

---

### 支持 Network Policy 的安装方式

从 `v0.25.5` 开始, 可以和 flannel 在同一个 pod 中一起部署 [kube-network-policies](https://github.com/kubernetes-sigs/kube-network-policies) 来提供 network policy controller.

#### 通过 `chart` 安装 `flannel`

当前 chart 已经支持部署 kube-network-policies, 设置 `netpol.enabled=true` 即可

```bash
mkdir -p ~/charts/flannel/flannel
cd ~/charts/flannel/flannel
helm repo add flannel https://flannel-io.github.io/flannel/
# values.yaml 用来查看默认值
helm show values flannel/flannel > values.yaml
cat <<EOF > custom-values.yaml
podCidr: "10.42.0.0/16"

flannel:
  image:
    repository: docker.io/flannel/flannel
    tag: v0.26.2
  image_cni:
    repository: docker.io/flannel/flannel-cni-plugin
    tag: v1.6.0-flannel1
  args:
  - "--ip-masq"
  - "--kube-subnet-mgr"
  backend: "vxlan"
  backendPort: 4789
  mtu: 1450
  vni: 4096

netpol:
  enabled: true
  args:
  - "--hostname-override=\$(MY_NODE_NAME)"
  - "--v=2"
  image:
    repository: registry.k8s.io/networking/kube-network-policies
    tag: v0.4.0
EOF
kubectl create ns kube-flannel
kubectl label --overwrite ns kube-flannel pod-security.kubernetes.io/enforce=privileged
helm upgrade --install --namespace kube-flannel flannel flannel/flannel -f custom-values.yaml
```

---

TODO