---
title: "Cloudinit"
date: 2024-06-30T23:56:57+08:00
draft: false
toc: true
tags: [cloudinit]
---

## cloudinit 介绍

> 用于初始化网络, 主机名, 根文件系统, 用户名密码

## cloudinit iso 镜像制作

### 创建脚本

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
```

### 生成 cloudinit iso

```bash
VM=k8s-node01 bash gen-cloudinit-iso.sh
```

### 使用

创建一个k8s节点虚拟机

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

## 参考

- https://cloudinit.readthedocs.io/en/latest/explanation/format.html
- https://github.com/kubevirt/kubevirt/blob/main/pkg/cloud-init/cloud-init.go