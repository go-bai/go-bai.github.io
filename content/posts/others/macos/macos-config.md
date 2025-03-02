---
title: "MacOS Config"
date: 2023-09-24T10:56:13+08:00
draft: false
---

## 安装`iproute2mac`

可以和在linux操作系统一样使用`ip`命令查看和管理网络, 赞!!!

```bash
brew install iproute2mac
```

## ssh配置alive

配置`ServerAliveInterval`, 防止长时间没有数据交互后连接断掉

```bash
# cat ~/.ssh/config
Host *
    ServerAliveInterval 30

Host home
    HostName 192.168.1.100
    User root
...
```