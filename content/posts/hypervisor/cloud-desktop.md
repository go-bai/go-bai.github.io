---
title: "Cloud Desktop"
date: 2023-10-14T23:10:09+08:00
draft: false
tags: [hypervisor,VDI,IDV,VOI,DaaS]
---

关于云桌面技术架构

### VDI (Virtual Desktop Infrastructure)

集中存储+集中计算，所有的桌面都是运行在服务器端，桌面以图像传输的方式发送到客户端。

优点:

1. 灵活，按需给每个终端分配cpu、硬盘和内存
2. `安全`，数据安全性高
3. 便捷，支持多终端访问，PC、手机、平板、瘦客户机，只要通过网络，随时随地云上办公

缺点:

1. 断网不可用，性能与PC相比有一定差距
2. 外设兼容性不如PC设备
3. 在3D应用和高清视频渲染方面，需要GPU显卡支持，可完成简单的3D渲染

相关产品与技术

- SPICE/RDP/PCoIP/ICA/HDX协议
    - Citrix ICA/HDX协议
        - XenApp and XenDesktop
    - VMware PCoIP协议
        - VMware Horizon
    - Microsoft RDP/RemoteFX
        - Windows Virtual Desktop
    - Red hat `SPICE`协议
- `OpenvSwitch`虚拟网络
- Ceph/Glusterfs分布式存储
- H264/H265
- WebRTC
- QEMU/KVM
- GRID vGPU, GPU Passthrough
- Windows显卡驱动

常见桌面云产品: Citrix, Vmware, 深信服, 华为等

阿里云“无影”云桌面，瘦客户端只有卡片大小

openxt

### VDI (Intelligent Desktop Virtualization)

