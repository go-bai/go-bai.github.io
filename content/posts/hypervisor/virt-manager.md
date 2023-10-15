---
title: "Virt Manager"
date: 2023-09-23T22:28:35+08:00
draft: false
tags: [hypervisor,kvm,qemu,virsh]
---

### 环境

#### 操作系统 Ubuntu 22.04.3 LTS Desktop

```bash
➜  ~ cat /etc/os-release 
PRETTY_NAME="Ubuntu 22.04.3 LTS"
NAME="Ubuntu"
VERSION_ID="22.04"
VERSION="22.04.3 LTS (Jammy Jellyfish)"
VERSION_CODENAME=jammy
ID=ubuntu
ID_LIKE=debian
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
UBUNTU_CODENAME=jammy
```

#### 网络环境

已创建`bridged network`, [Creating a bridged network with netplan on Ubuntu 22.04](../creating-a-bridged-network-with-netplan-on-ubuntu-22-04/)

### 安装配置

#### 安装

```bash
sudo apt install virt-manager qemu bridge-utils -y
```

#### 配置 `bridge` 类型网络

TODO

#### 修改`libvirtd`配置文件并重启

`sudo vim /etc/libvirt/qemu.conf`

```diff
- #user = "root"
+ user = "gobai"

- #group = "root"
+ group = "gobai"
```

`sudo systemctl restart libvirtd`

#### 启动 `virt-manager`

```bash
sudo virt-manager
```

### 运行 openwrt

现有镜像文件在`Documents`目录下

```bash
➜  Documents ls -lh
total 855M
-rw-r--r-- 1 gobai gobai 855M  9月 23 23:06 openwrt-x86-64-generic-ext4-combined-efi.img
```

查看镜像文件类型并转换为 qcow2

```bash
➜  Documents qemu-img info openwrt-x86-64-generic-ext4-combined-efi.img 
image: openwrt-x86-64-generic-ext4-combined-efi.img
file format: raw
virtual size: 854 MiB (895778304 bytes)
disk size: 854 MiB
➜  Documents qemu-img convert -f raw -O qcow2 openwrt-x86-64-generic-ext4-combined-efi.img openwrt-x86-64-generic-ext4-combined-efi.qcow2
➜  Documents qemu-img info openwrt-x86-64-generic-ext4-combined-efi.qcow2 
image: openwrt-x86-64-generic-ext4-combined-efi.qcow2
file format: qcow2
virtual size: 854 MiB (895778304 bytes)
disk size: 544 MiB
cluster_size: 65536
Format specific information:
    compat: 1.1
    compression type: zlib
    lazy refcounts: false
    refcount bits: 16
    corrupt: false
    extended l2: false
```

修改镜像文件所属用户和用户组为`libvirt-qemu`

```bash
➜  Documents sudo chown libvirt-qemu:libvirt-qemu openwrt-x86-64-generic-ext4-combined-efi.qcow2 
[sudo] password for gobai: 
➜  Documents ls -lh
total 1.4G
-rw-r--r-- 1 gobai        gobai        855M  9月 23 23:06 openwrt-x86-64-generic-ext4-combined-efi.img
-rw-r--r-- 1 libvirt-qemu libvirt-qemu 545M  9月 23 23:31 openwrt-x86-64-generic-ext4-combined-efi.qcow2
```

#### `virt-viewer`连接vm

```bash
sudo virt-viewer --connect qemu:///session openwrt
```

#### `virsh`命令行工具

```bash
# ========== domain ==========
# 虚机列表
virsh list --all
# 关闭虚机
virsh shutdown domain
# 启动虚机
virsh start domain

# ========== network ==========
# 网络列表
virsh net-list

# ========== other ==========
# 更改root用户密码, 此命令会和虚机内的qemu guest agent(qga)进程通过串口进行交互
virsh set-user-password --domain domain --user root --password 123456
```