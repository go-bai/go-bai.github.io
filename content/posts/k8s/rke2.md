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

## 创建虚拟机

### 准备 cloudinit 镜像

```bash
cat <<EOFALL > gen-cloudinit-iso.sh
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

VM=k8s-node01 bash gen-cloudinit-iso.sh
```

### 准备系统盘并创建虚拟机

```bash
VM=k8s-node01
mkdir -p /var/lib/libvirt/disks/${VM}
qemu-img create -f qcow2 -F qcow2 -b /var/lib/libvirt/images/ubuntu.qcow2 /var/lib/libvirt/disks/${VM}/sysdisk.qcow2 200G
qemu-img create -f qcow2 /var/lib/libvirt/disks/${VM}/datadisk01.qcow2 500G
qemu-img create -f qcow2 /var/lib/libvirt/disks/${VM}/datadisk02.qcow2 500G
qemu-img create -f qcow2 /var/lib/libvirt/disks/${VM}/datadisk03.qcow2 500G

virt-install \
  --name ${VM} \
  --memory 16384 \
  --vcpus 8 \
  --disk /var/lib/libvirt/disks/${VM}/sysdisk.qcow2,device=disk,bus=scsi \
  --disk /var/lib/libvirt/disks/${VM}/datadisk01.qcow2,device=disk,bus=scsi \
  --disk /var/lib/libvirt/disks/${VM}/datadisk02.qcow2,device=disk,bus=scsi \
  --disk /var/lib/libvirt/disks/${VM}/datadisk03.qcow2,device=disk,bus=scsi \
  --disk /var/lib/libvirt/disks/${VM}/cloudinit/init.iso,device=cdrom,bus=scsi \
  --network bridge=br0 \
  --import \
  --os-variant ubuntu22.10 \
  --noautoconsole
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

## 安装 rook ceph

https://rook.io/docs/rook/latest-release/Getting-Started/quickstart/

## 安装 kube-prometheus-stack

## 参考

- [[RKE2 docs] quickstart](https://docs.rke2.io/zh/install/quickstart)
- [[RKE2 docs] CLI 工具](https://docs.rke2.io/zh/reference/cli_tools)