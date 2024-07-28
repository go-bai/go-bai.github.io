---
title: "RKE2"
date: 2024-07-01T21:24:49+08:00
draft: false
toc: true
tags: [k8s,rke2]
---

> 通过RKE2快速搭建测试使用的k8s集群环境

## 环境准备

1. 准备bridge网络br0
2. 准备ubuntu 22.04 server qcow2镜像
3. 准备libvirt环境

### 准备bridge网络

[Creating a bridged network with netplan on Ubuntu 22.04](../creating-a-bridged-network-with-netplan-on-ubuntu-22-04/)

### 配置 gen-cloudinit-iso 脚本

```bash
cat <<EOFALL > /usr/bin/gen-cloudinit-iso
#!/bin/bash

set -eux

CLOUD_INIT_DIR="/var/lib/libvirt/disks/\${VM}/cloudinit"
FILENAME="\${CLOUD_INIT_DIR}/init.iso"

mkdir -p \${CLOUD_INIT_DIR}

cat <<EOF > \${CLOUD_INIT_DIR}/meta-data
instance-id: \${VM}
local-hostname: \${VM}
EOF

# 更多配置参照 https://cloudinit.readthedocs.io/en/latest/explanation/format.html
cat <<EOF > \${CLOUD_INIT_DIR}/user-data
#cloud-config
EOF

# 参考 kubevirt /pkg/cloud-init/cloud-init.go:defaultIsoFunc
xorrisofs -output \$FILENAME -volid cidata -joliet -rock -partition_cyl_align on \${CLOUD_INIT_DIR}/user-data \${CLOUD_INIT_DIR}/meta-data
EOFALL

chmod +x /usr/bin/gen-cloudinit-iso
```

## 创建虚拟机

```bash
for vm in "k8s-node01" "k8s-node02"; do
  export VM=${vm}
  # prepare cloudinit iso
  gen-cloudinit-iso
  # prepare sysdisk and datadisk 
  qemu-img create -f qcow2 -F qcow2 -b /var/lib/libvirt/images/ubuntu.qcow2 /var/lib/libvirt/disks/${VM}/sysdisk.qcow2 200G
  qemu-img create -f qcow2 /var/lib/libvirt/disks/${VM}/datadisk01.qcow2 500G
  qemu-img create -f qcow2 /var/lib/libvirt/disks/${VM}/datadisk02.qcow2 500G

  virt-install \
    --name ${VM} \
    --memory 16384 \
    --vcpus 8 \
    --disk /var/lib/libvirt/disks/${VM}/sysdisk.qcow2,device=disk,bus=scsi \
    --disk /var/lib/libvirt/disks/${VM}/datadisk01.qcow2,device=disk,bus=scsi \
    --disk /var/lib/libvirt/disks/${VM}/datadisk02.qcow2,device=disk,bus=scsi \
    --disk /var/lib/libvirt/disks/${VM}/cloudinit/init.iso,device=cdrom,bus=scsi \
    --network bridge=br0 \
    --import \
    --os-variant ubuntu22.10 \
    --noautoconsole
done
```

## 安装 RKE2

### 脚本在线安装

```bash
# TODO 指定 cni
curl -sfL https://rancher-mirror.rancher.cn/rke2/install.sh | INSTALL_RKE2_MIRROR=cn sh -
systemctl enable rke2-server.service
systemctl start rke2-server.service
```

### 离线安装

TODO

### 配置

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

## 安装 rook ceph

https://rook.io/docs/rook/latest-release/Getting-Started/quickstart/

## 安装 kube-prometheus-stack

## 参考

- [[RKE2 docs] quickstart](https://docs.rke2.io/zh/install/quickstart)
- [[RKE2 docs] CLI 工具](https://docs.rke2.io/zh/reference/cli_tools)