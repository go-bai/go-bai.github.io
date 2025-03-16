---
title: "Linux 启动流程 (BIOS)"
date: 2025-03-13T11:46:16+08:00
---

## 启动流程

开机自检(POST) -> 主板固件(BIOS) -> Boot Loader 引导(grub2) vmlinuz运行 -> 内核挂载文件系统 -> 初始化(systemd)  

### 开机自检 (POST)

当计算机开机时，BIOS(Basic Input Output System) 首先进行自检 POST(Power-On Self Test)，检查硬件组件（如内存、硬盘、显卡等）是否正常工作

### 加载引导程序

TODO

## 其他

### **使用 initial RAM disk (initrd)**

`initrd` 提供了通过 `boot loader` 程序加载 RAM 磁盘的能力，然后这个 RAM 磁盘可以被挂载为根文件系统，并可以从中运行程序。之后，可以从不同的设备挂载新的文件系统，然后将前一个根目录(来自initrd)移动到一个目录，然后可以卸载。

`initrd` 主要设计为允许系统启动分为两个阶段进行，其中内核携带最少的编译进去的驱动程序集，从 `initrd` 加载其他模块。

当时用 `initrd`，系统通常按照下面顺序启动：

1. `boot loader`(一般是`grub`) 加载内核 `vmlinuz` 和 initial RAM disk `initrd.img`, 具体的文件名要看 `/boot/grub/grub.cfg` 中的 menu 设置。

TODO

### **initrd 与 microcode 微码加载**

内核可以在启动的非常早期阶段更新微码，早期加载微码可以在内核启动阶段发现CPU问题之前修复问题。

微码也会被存储在 initrd 文件中。在启动时，它被读出来并加载到CPU核中。

微码文件在 initrd image 中存储如下

```bash
lsinitramfs /boot/initrd.img | grep -E 'microcode.*bin'
kernel/x86/microcode/AuthenticAMD.bin
kernel/x86/microcode/GenuineIntel.bin
```

更新微码步骤一般为：

1. 在 intel 或 amd 网站下载微码并解压
2. 复制到对应位置 `/lib/firmware/{amd-ucode,intel-ucode}`
3. 使用 `cpio` 将微码打包成但文件后输出到 `/boot/initrd.img` 中, 也可以直接使用 `update-initramfs -u -k all`

## 参考

- [Using the initial RAM disk (initrd)](https://docs.kernel.org/admin-guide/initrd.html)
- [23. The Linux Microcode Loader](https://docs.kernel.org/arch/x86/microcode.html)
- [Guide to the Boot Process of a Linux System](https://www.baeldung.com/linux/boot-process)
- [Boot Process In Linux – Detailed Steps For  Beginners](https://cyberpanel.net/blog/boot-process-in-linux)