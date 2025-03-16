---
title: "Linux 磁盘分区"
date: 2025-03-15T20:31:35+08:00
---

https://www.baeldung.com/linux/partitioning-disks
https://en.wikipedia.org/wiki/Master_boot_record
https://www.cnblogs.com/god-of-death/p/18221794

## 概览

通常安装 Linux 系统的第一步就是磁盘分区。在我们创建任何文件前需要先存在文件系统。

分区被用来将原始存储空间分割成大块，可以用来隔离文件系统故障。

## 磁盘类型 (Disk Types)



### 分区表格式 MBR 和 GPT

[MBR](https://en.wikipedia.org/wiki/Master_boot_record) (Master Boot Record) 和 [GPT](https://en.wikipedia.org/wiki/GUID_Partition_Table) (GUID Partition Table) 是最广泛使用的分区表，相较于 GPT，MBR 是一个老的标准并且有一些限制。

### BIOS 和 UEFI

### 分区工具

`fdisk` 和 `parted`

TODO