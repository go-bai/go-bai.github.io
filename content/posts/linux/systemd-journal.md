---
title: "About Systemd"
date: 2021-11-14T01:47:04+08:00
draft: false
tags: ["linux", 'systemd', 'journalctl']
---

记录一下查看和操作 `systemd` 日志的几个常用命令

### 1 常用过滤日志日志的命令

#### 1.1 根据时间约束过滤日志

##### 1.1.1 获取 `2023-01-15 00:00:00` 之后的日志

```bash
journalctl --since '2023-01-15 00:00:00'
```

##### 1.1.2 获取 `2023-01-15 00:00:00` 之后, `2023-01-15 12:00:00` 之前的日志

```bash
journalctl --since '2023-01-15 00:00:00' --until '2023-01-15 12:00:00'
```

#### 1.2 只查看一个服务(Unit)的日志

```bash
journalctl -u nginx
```

#### 1.3 自由组合约束条件

```bash
journalctl -u nginx --since '2023-01-15 00:00:00' --until '2023-01-15 12:00:00'
```

### 2 查看日志占用磁盘量

```bash
journalctl --disk-usage
```

```bash
Output
Archived and active journals take up 3.9G in the file system.
```

### 3 删除旧的日志

#### 3.1 只保留最近 `一个月` 的日志

```bash
journalctl --vacuum-time=1month
```

#### 3.2 只保留最近 `1G` 的日志

```bash
journalctl --vacuum-size=1G
```

### 4 list all systemd service

```bash
systemctl list-units --type=service --all
```