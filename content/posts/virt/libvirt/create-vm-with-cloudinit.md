---
title: "创建虚拟机时使用 cloudinit 初始化"
date: 2024-07-01T01:56:57+08:00
---

## cloudinit 介绍

> 用于在新建的虚拟机中进行时间设置、密码设置、扩展根文件系统所在分区、设置主机名、运行脚本、安装软件包等初始化设置

## 宿主机配置脚本

此脚本会用来在 `/var/lib/libvirt/disks/${VM}/cloudinit` 目录生成 cloudinit iso 镜像

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

## 创建虚拟机时使用 cloudinit

创建虚拟机之前创建 cloudinit iso, 并通过 cdrom 挂载

```bash
for vm in "k8s-node01" "k8s-node02" "k8s-node03"; do
  export VM=${vm}
  # 生成 cloudinit iso
  gen-cloudinit-iso
  # prepare sysdisk and datadisk 
  qemu-img create -f qcow2 -F qcow2 -b /var/lib/libvirt/images/ubuntu.qcow2 /var/lib/libvirt/disks/${VM}/sysdisk.qcow2 50G
  qemu-img create -f qcow2 /var/lib/libvirt/disks/${VM}/datadisk01.qcow2 100G

  virt-install \
    --name ${VM} \
    --memory 16384 \
    --vcpus 8 \
    --disk /var/lib/libvirt/disks/${VM}/sysdisk.qcow2,device=disk,bus=scsi \
    --disk /var/lib/libvirt/disks/${VM}/datadisk01.qcow2,device=disk,bus=scsi \
    --disk /var/lib/libvirt/disks/${VM}/cloudinit/init.iso,device=cdrom,bus=scsi \
    --network bridge=br0 \
    --import \
    --os-variant ubuntu22.10 \
    --noautoconsole
done
```

## 参考

- https://cloudinit.readthedocs.io/en/latest/explanation/format.html
- https://github.com/kubevirt/kubevirt/blob/main/pkg/cloud-init/cloud-init.go