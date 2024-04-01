---
title: "Multi-Bootable USB"
date: 2024-03-28T22:20:22+08:00
draft: false
toc: true
tags: [ventoy]
---

> 从一个USB设备(U盘)启动多个操作系统

## 下载并解压`ventoy`

```bash
wget https://github.com/ventoy/Ventoy/releases/download/v1.0.97/ventoy-1.0.97-linux.tar.gz
tar -xvzf ventoy-1.0.97-linux.tar.gz
cd ventoy-1.0.97/
```

`Ventoy2Disk.sh`用来安装`ventor`到U盘

```bash
./Ventoy2Disk.sh -h

**********************************************
      Ventoy: 1.0.97  x86_64
      longpanda admin@ventoy.net
      https://www.ventoy.net
**********************************************

Usage:  Ventoy2Disk.sh CMD [ OPTION ] /dev/sdX
  CMD:
   -i  install Ventoy to sdX (fails if disk already installed with Ventoy)
   -I  force install Ventoy to sdX (no matter if installed or not)
   -u  update Ventoy in sdX
   -l  list Ventoy information in sdX

  OPTION: (optional)
   -r SIZE_MB  preserve some space at the bottom of the disk (only for install)
   -s/-S       enable/disable secure boot support (default is enabled)
   -g          use GPT partition style, default is MBR (only for install)
   -L          Label of the 1st exfat partition (default is Ventoy)
   -n          try non-destructive installation (only for install)
```

## 安装ventoy

```bash
# ./Ventoy2Disk.sh -I /dev/sdb

**********************************************
      Ventoy: 1.0.97  x86_64
      longpanda admin@ventoy.net
      https://www.ventoy.net
**********************************************

Disk : /dev/sdb
Model: Kingston DataTraveler 3.0 (scsi)
Size : 115 GB
Style: MBR


Attention:
You will install Ventoy to /dev/sdb.
All the data on the disk /dev/sdb will be lost!!!

Continue? (y/n) y

All the data on the disk /dev/sdb will be lost!!!
Double-check. Continue? (y/n) y

Create partitions on /dev/sdb by parted in MBR style ...
Done
Wait for partitions ...
partition exist OK
create efi fat fs /dev/sdb2 ...
mkfs.fat 4.2 (2021-01-31)
success
Wait for partitions ...
/dev/sdb1 exist OK
/dev/sdb2 exist OK
partition exist OK
Format partition 1 /dev/sdb1 ...
mkexfatfs 1.3.0
Creating... done.
Flushing... done.
File system created successfully.
mkexfatfs success
writing data to disk ...
sync data ...
esp partition processing ...

Install Ventoy to /dev/sdb successfully finished.
```

## 拷贝`iso`镜像到U盘

将`/dev/sdb1` mount到目录上(如果是有桌面的Linux环境, 应该会自动mount), 然后就可以将iso文件拷贝过去了

之后就可以通过这一个`U盘`去启动多个系统的iso镜像了.