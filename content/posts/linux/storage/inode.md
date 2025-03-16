---
title: "Linux 文件系统之 inode"
date: 2025-03-13T12:08:49+08:00
---

TODO

https://www.ruanyifeng.com/blog/2011/12/inode.html

## inode 是什么

inode 是 Linux 文件系统中的一个重要概念，它是一个文件的元数据，记录了文件的权限、类型、大小、创建时间、修改时间等信息。

## inode 的结构

inode 的结构如下:

```bash
struct inode {
    umode_t i_mode;       // 文件类型和权限
    uid_t i_uid;         // 文件所有者
    gid_t i_gid;         // 文件所属组
    loff_t i_size;       // 文件大小
    struct timespec i_atime; // 文件访问时间
    struct timespec i_ctime; // 文件创建时间
    struct timespec i_mtime; // 文件修改时间
}
```

## 使用场景

### 通过 inode 查找并删除文件

```bash
# ls -li
total 32
   459 -rw-r--r-- 1 root root 20070 Mar 13 11:27 ''$'\033\033'
526984 drwxr-xr-x 5 root root  4096 Jan  1 17:47  charts
   784 drwxr-xr-x 2 root root  4096 Jan 19 20:42  pods
 49203 drwx------ 3 root root  4096 Feb 10  2023  snap
# find . -inum 459
./??
# find . -inum 459 -delete
# ls -li
total 12
526984 drwxr-xr-x 5 root root 4096 Jan  1 17:47 charts
   784 drwxr-xr-x 2 root root 4096 Jan 19 20:42 pods
 49203 drwx------ 3 root root 4096 Feb 10  2023 snap
```

## 参考