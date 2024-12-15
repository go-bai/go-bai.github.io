---
title: "使用 RKE2 快速搭建 k8s 集群"
date: 2024-07-01T21:24:49+08:00
draft: false
toc: true
tags: [k8s,rke2]
---

根据[创建 bridge 网络](../creating-a-bridged-network-with-netplan-on-ubuntu-22-04/)和[创建虚拟机时使用 cloudinit 初始化](../create-vm-with-cloudinit/)创建虚拟机, 并配置静态ip如下

| 主机名 | 配置 | ip (域名) | 系统盘 / 数据盘 |
| --- | --- | --- | --- |
| k8s-node01 | 8核16G | 192.168.1.218 (`lb.k8s.lan`) | 50GB / 100GB*1 |
| k8s-node02 | 8核16G | 192.168.1.219 | 50GB / 100GB*1 |
| k8s-node03 | 8核16G | 192.168.1.220 | 50GB / 100GB*1 |

## 安装 RKE2

### 安装第一个 server 节点

在 k8s-node01 节点执行

```bash
# 初始化 rke2 配置文件
mkdir -p /etc/rancher/rke2
cat <<EOF > /etc/rancher/rke2/config.yaml
tls-san:
  - lb.k8s.lan
write-kubeconfig-mode: "0600"
etcd-expose-metrics: true
disable-cloud-controller: true
# 为了节省资源使用的 flannel, 也可以使用 calico
cni: flannel
debug: true
# 指定 kube-scheduler debug 日志级别
kube-scheduler-arg:
  - v=4
EOF

curl -sfL https://rancher-mirror.rancher.cn/rke2/install.sh | INSTALL_RKE2_MIRROR=cn sh -
systemctl enable rke2-server.service
systemctl start rke2-server.service
```

配置中的 `tls-san` 在 server 的 TLS 证书中增加了多个地址作为 `Subject Alternative Name`, 这样 apiserver 就可以通过 `lb.k8s.lan` 和 各个 server 节点 ip 访问.

### 安装其他 server 节点

初始化 rke2 配置文件, 需要修改 `/etc/rancher/rke2/config.yaml` 中的 token

```bash
# 从第一个 server 节点的 /var/lib/rancher/rke2/server/node-token 获取
token=<edit-me>
mkdir -p /etc/rancher/rke2
cat <<EOF > /etc/rancher/rke2/config.yaml
server: https://lb.k8s.lan:9345
token: $token
tls-san:
  - lb.k8s.lan
write-kubeconfig-mode: "0600"
etcd-expose-metrics: true
disable-cloud-controller: true
cni: flannel
EOF
```

安装

```bash
curl -sfL https://rancher-mirror.rancher.cn/rke2/install.sh | INSTALL_RKE2_MIRROR=cn sh -
systemctl enable rke2-server.service
systemctl start rke2-server.service
```

### 配置节点

server 和 worker 节点都需要执行

```bash
# kubectl ctr crictl...
CONFIG="PATH=\$PATH:/var/lib/rancher/rke2/bin/"
grep "$CONFIG" ~/.bashrc || echo "$CONFIG" >> ~/.bashrc && source ~/.bashrc

# command auto completiom
CONFIG="source <(kubectl completion bash)"
grep "$CONFIG" ~/.bashrc || echo "$CONFIG" >> ~/.bashrc && source ~/.bashrc

# KUBECONFIG ENV
CONFIG="export KUBECONFIG=/etc/rancher/rke2/rke2.yaml"
grep "$CONFIG" ~/.bashrc || echo "$CONFIG" >> ~/.bashrc && source ~/.bashrc

# CRI_CONFIG_FILE
CONFIG="export CRI_CONFIG_FILE=/var/lib/rancher/rke2/agent/etc/crictl.yaml"
grep "$CONFIG" ~/.bashrc || echo "$CONFIG" >> ~/.bashrc && source ~/.bashrc

# alias ctr="ctr --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
CONFIG="alias ctr=\"ctr --address /run/k3s/containerd/containerd.sock --namespace k8s.io\""
grep "$CONFIG" ~/.bashrc || echo "$CONFIG" >> ~/.bashrc && source ~/.bashrc

# install helm
HELM_LATEST_VERSION=v3.15.2
wget https://get.helm.sh/helm-${HELM_LATEST_VERSION}-linux-amd64.tar.gz
tar -zxvf helm-${HELM_LATEST_VERSION}-linux-amd64.tar.gz
mv linux-amd64/helm /usr/local/bin/helm
rm -f helm-${HELM_LATEST_VERSION}-linux-amd64.tar.gz && rm -rf linux-amd64/
```

worker 节点的 kubeconfig `/etc/rancher/rke2/rke2.yaml` 需要从 server 节点上拷贝, 无需修改

## RKE2架构

RKE2 Server 和 Agent 有利用 k3s 的 agent

### 进程生命周期

rke2进程使用systemd守护运行, rke2生成containerd进程和kubelet进程, 然后apiserver controller-manager scheduler etcd kube-proxy以static pod的形式被kubelet启动

containerd进程退出时rke2也会重启, kubelet进程退出时rke2会再拉起一个kubelet进程

```bash
# ps -e --forest
    899 ?        01:32:51 rke2
   1101 ?        01:58:12  \_ containerd
   1123 ?        05:23:44  \_ kubelet
   1227 ?        00:02:15 containerd-shim
   1344 ?        00:00:00  \_ pause
   1500 ?        05:12:21  \_ etcd
   1228 ?        00:02:22 containerd-shim
   1353 ?        00:00:00  \_ pause
   2516 ?        06:26:44  \_ kube-controller
   1229 ?        00:02:16 containerd-shim
   1342 ?        00:00:00  \_ pause
   2614 ?        00:44:00  \_ cloud-controlle
   1267 ?        00:02:18 containerd-shim
   1363 ?        00:00:00  \_ pause
   1452 ?        00:08:46  \_ kube-proxy
   1920 ?        00:00:00      \_ timeout <defunct>
   1283 ?        00:02:19 containerd-shim
   1341 ?        00:00:00  \_ pause
   1541 ?        00:51:47  \_ kube-scheduler
   1801 ?        00:20:15 containerd-shim
   1821 ?        00:00:00  \_ pause
   1852 ?        15:16:04  \_ kube-apiserver
```

## 一些常用目录/文件

| 目录/文件 | 说明 |
| --- | --- |
| `/var/lib/rancher/rke2/agent/pod-manifests` | static pod 文件 |
| `/var/lib/rancher/rke2/agent/etc/containerd/config.toml` | containerd配置文件 |
| `/var/lib/rancher/rke2/agent/containerd/containerd.log` | containerd日志 |
| `/var/lib/rancher/rke2/agent/logs/kubelet.log` | kubelet日志 |
| `/var/lib/rancher/rke2/server/db/etcd/config` | etcd配置文件 |
| `/etc/rancher/rke2/config.yaml` | [rke2配置文件](https://docs.rke2.io/install/configuration#configuration-file) |

## 连接 etcd

```bash
ETCD_CONTAINER_ID=$(crictl ps --label=io.kubernetes.container.name=etcd --quiet)
ETCD_CA_CERT=/var/lib/rancher/rke2/server/tls/etcd/server-ca.crt
ETCD_CLIENT_CERT=/var/lib/rancher/rke2/server/tls/etcd/server-client.crt
ETCD_CLIENT_KEY=/var/lib/rancher/rke2/server/tls/etcd/server-client.key
```

### 查看 etcd 集群状态

```bash
$ crictl exec -it $ETCD_CONTAINER_ID etcdctl --cacert $ETCD_CA_CERT --cert $ETCD_CLIENT_CERT --key $ETCD_CLIENT_KEY endpoint status --cluster --write-out=table
+----------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|          ENDPOINT          |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+----------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| https://192.168.1.219:2379 | a6bc98228859ce05 |  3.5.13 |  5.5 MB |     false |      false |         3 |      14026 |              14026 |        |
| https://192.168.1.220:2379 | b3d0ba8f8abb8a75 |  3.5.13 |  5.4 MB |     false |      false |         3 |      14026 |              14026 |        |
| https://192.168.1.218:2379 | d61af8cc4ec4d5b1 |  3.5.13 |  8.5 MB |      true |      false |         3 |      14026 |              14026 |        |
+----------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

## 参考

- [[RKE2 docs] quickstart](https://docs.rke2.io/zh/install/quickstart)
- [[RKE2 docs] CLI 工具](https://docs.rke2.io/zh/reference/cli_tools)