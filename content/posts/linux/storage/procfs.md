---
title: "proc filesystem"
date: 2025-04-09T21:28:03+08:00
# bookComments: false
# bookSearchExclude: false
---

`procfs` 是一个特殊的文件系统，包含一个伪文件系统（启动时动态生成的文件系统），用于通过内核访问进程信息。这个文件系统通常被挂载到 `/proc` 目录。由于 `proc` 不是一个真正的文件系统，它也就不占用存储空间，只是占用有限的内存。

下面以 `bash` 进程为例查看 `/proc/PID/` 下的信息。

## /proc/PID/exe

指向原始的可执行文件

```bash
$ ls -lh /proc/3553026/exe 
lrwxrwxrwx 1 root root 0  4月 10 22:09 /proc/3553026/exe -> /usr/bin/bash
```

## /proc/PID/fd

是一个目录, 包含此进程打开的所有文件描述符 (file descriptors)

```bash
$ ls -lhv /proc/3553026/fd
total 0
lrwx------ 1 root root 64  4月 10 22:06 0 -> /dev/pts/14
lrwx------ 1 root root 64  4月 10 22:06 1 -> /dev/pts/14
lrwx------ 1 root root 64  4月 10 22:06 2 -> /dev/pts/14
lrwx------ 1 root root 64  4月 10 22:06 255 -> /dev/pts/14
```

## TODO

## 参考

- [The /proc Filesystem](https://docs.kernel.org/filesystems/proc.html)
- [wiki/Procfs](https://zh.wikipedia.org/wiki/Procfs)
