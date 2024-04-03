---
title: "Multi-Bootable USB"
date: 2024-03-28T22:20:22+08:00
draft: false
toc: true
tags: [ventoy]
---

> 从一个USB设备(U盘)启动多个操作系统, 并且U盘还能继续存储其他普通文件

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

查看最终的U盘分区, `sdb1`分区是存放`iso`镜像的

```bash
# fdisk -l /dev/sdb
Disk /dev/sdb: 115.5 GiB, 124017180672 bytes, 242221056 sectors
Disk model: DataTraveler 3.0
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: dos
Disk identifier: 0x7eda2ae4

Device     Boot     Start       End   Sectors   Size Id Type
/dev/sdb1  *         2048 242155519 242153472 115.5G  7 HPFS/NTFS/exFAT
/dev/sdb2       242155520 242221055     65536    32M ef EFI (FAT-12/16/32)
```

## 拷贝`iso`镜像到U盘

为了充分利用U盘的空间, 我这里会在U盘里既存iso镜像(在`image`目录)也存储普通文件(在`data`目录)

但是如果`data`下文件特别多，搜索过程就会非常慢，这里就需要指定搜索路径来解决了

```bash
# 如果操作系统没有自动将sdb1 mount到目录需要先手动mount, 否则跳过就好
mkdir -p /mnt/Ventoy
mount /dev/sdb1 /mnt/Ventoy

# 创建文件夹
cd /mnt/Ventoy
mkdir -p image
mkdir -p data
mkdir -p ventoy

# 编辑 ventoy/ventoy.json 文件
cat <<EOF > ventoy/ventoy.json
{
    "control": [
        { "VTOY_DEFAULT_SEARCH_ROOT": "/image" }
    ]
}
EOF
```

最后拷贝就直接 `cp xx.iso /mnt/Ventoy/image/` 就行了


## 参考

1. [Ventoy Global Control Plugin](https://www.ventoy.net/en/plugin_control.html)
2. [Ventoy Search Configuration](https://www.ventoy.net/en/doc_search_path.html)
3. [Ventoy Github](https://github.com/ventoy/Ventoy)