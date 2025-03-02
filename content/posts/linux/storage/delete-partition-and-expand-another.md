---
title: "删除分区并扩容另一个分区和根文件系统"
date: 2023-10-02T16:54:05+08:00
draft: false
---

> 现在要将 `/dev/sda3` 分区删掉并扩容到 `/dev/sda2`, 并且在不重启服务器的情况下扩容根文件系统(跟文件系统 `/` 挂载在 `/dev/sda2` 上, 并且 filesystem 是 `ext4`)

## 磁盘初始分区和挂载情况

```bash
➜  ~ lsblk /dev/sda
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda      8:0    0  100G  0 disk 
├─sda1   8:1    0  512M  0 part /boot/efi
├─sda2   8:2    0 98.5G  0 part /
└─sda3   8:3    0  976M  0 part 

➜  ~ fdisk -l /dev/sda
Disk /dev/sda: 100 GiB, 107374182400 bytes, 209715200 sectors
Disk model: BlockVolume     
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 4096 bytes
I/O size (minimum/optimal): 4096 bytes / 1048576 bytes
Disklabel type: gpt
Disk identifier: 40BED670-8B91-4520-9785-DB1F1035C039

Device         Start       End   Sectors  Size Type
/dev/sda1       2048   1050623   1048576  512M EFI System
/dev/sda2    1050624 207714303 206663680 98.5G Linux filesystem
/dev/sda3  207714304 209713151   1998848  976M Linux swap

➜  ~ df -hT /dev/sda2
Filesystem     Type  Size  Used Avail Use% Mounted on
/dev/sda2      ext4   97G   28G   64G  31% /
```

## 删除分区 `/dev/sda3`

```bash
➜  ~ fdisk /dev/sda

Welcome to fdisk (util-linux 2.36.1).
Changes will remain in memory only, until you decide to write them.
Be careful before using the write command.


Command (m for help): d
Partition number (1-3, default 3): 3

Partition 3 has been deleted.

Command (m for help): p
Disk /dev/sda: 100 GiB, 107374182400 bytes, 209715200 sectors
Disk model: BlockVolume     
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 4096 bytes
I/O size (minimum/optimal): 4096 bytes / 1048576 bytes
Disklabel type: gpt
Disk identifier: 40BED670-8B91-4520-9785-DB1F1035C039

Device       Start       End   Sectors  Size Type
/dev/sda1     2048   1050623   1048576  512M EFI System
/dev/sda2  1050624 207714303 206663680 98.5G Linux filesystem

Command (m for help): w # 保存退出
The partition table has been altered.
Syncing disks.
```

## 扩容分区 `/dev/sda2` 和 根文件系统

使用 `fdisk` 扩容 `/dev/sda2`, 前提是 `/dev/sda2` 后面没有其他分区了，可以这样扩容(先删除不退出并重建分区, 分区 `Start` 不变, `End` 增大)

```bash
➜  ~ fdisk /dev/sda

Welcome to fdisk (util-linux 2.36.1).
Changes will remain in memory only, until you decide to write them.
Be careful before using the write command.


Command (m for help): p
Disk /dev/sda: 100 GiB, 107374182400 bytes, 209715200 sectors
Disk model: BlockVolume     
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 4096 bytes
I/O size (minimum/optimal): 4096 bytes / 1048576 bytes
Disklabel type: gpt
Disk identifier: 40BED670-8B91-4520-9785-DB1F1035C039

Device       Start       End   Sectors  Size Type
/dev/sda1     2048   1050623   1048576  512M EFI System
/dev/sda2  1050624 207714303 206663680 98.5G Linux filesystem

Command (m for help): d # 删除第二个分区, 不要保存退出, 退出就凉了
Partition number (1,2, default 2): 2

Partition 2 has been deleted.

Command (m for help): p
Disk /dev/sda: 100 GiB, 107374182400 bytes, 209715200 sectors
Disk model: BlockVolume     
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 4096 bytes
I/O size (minimum/optimal): 4096 bytes / 1048576 bytes
Disklabel type: gpt
Disk identifier: 40BED670-8B91-4520-9785-DB1F1035C039

Device     Start     End Sectors  Size Type
/dev/sda1   2048 1050623 1048576  512M EFI System

Command (m for help): n # 紧接着重新创建
Partition number (2-128, default 2): 2 # 因为使用的是GPT分区表, 所以最多可以有128个分区, MBR的只能有4个分区
First sector (1050624-209715166, default 1050624): 
Last sector, +/-sectors or +/-size{K,M,G,T,P} (1050624-209715166, default 209715166): 

Created a new partition 2 of type 'Linux filesystem' and of size 99.5 GiB.
Partition #2 contains a ext4 signature.

Do you want to remove the signature? [Y]es/[N]o: N

Command (m for help): p

Disk /dev/sda: 100 GiB, 107374182400 bytes, 209715200 sectors
Disk model: BlockVolume     
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 4096 bytes
I/O size (minimum/optimal): 4096 bytes / 1048576 bytes
Disklabel type: gpt
Disk identifier: 40BED670-8B91-4520-9785-DB1F1035C039

Device       Start       End   Sectors  Size Type
/dev/sda1     2048   1050623   1048576  512M EFI System
/dev/sda2  1050624 209715166 208664543 99.5G Linux filesystem

Command (m for help): w # 保存退出
The partition table has been altered.
Syncing disks.
```

reload partition table

```bash
apt install parted -y
partprobe /dev/sda
```

resize文件系统

```bash
➜  ~ resize2fs /dev/sda2
resize2fs 1.46.2 (28-Feb-2021)
Filesystem at /dev/sda2 is mounted on /; on-line resizing required
old_desc_blocks = 13, new_desc_blocks = 13
The filesystem on /dev/sda2 is now 26083067 (4k) blocks long.

➜  ~ df -hT /dev/sda2
Filesystem     Type  Size  Used Avail Use% Mounted on
/dev/sda2      ext4   98G   28G   65G  31% /
```

至此, 在不重启的情况下 `/` 目录的容量从最初的 `97G` 变成了 `98G` 👏

## 参考

- [How can I resize an ext root partition at runtime?](https://askubuntu.com/questions/24027/how-can-i-resize-an-ext-root-partition-at-runtime)
- [Re-read The Partition Table Without Rebooting Linux System](https://www.cyberciti.biz/tips/re-read-the-partition-table-without-rebooting-linux-system.html)
- [调整ext4根文件系统大小](https://cloud-atlas.readthedocs.io/zh_CN/latest/linux/storage/filesystem/ext/resize_ext4_rootfs.html#ext4)