---
title: "Linux Tricks"
date: 2021-11-14T01:47:04+08:00
draft: false
tags: ["linux"]
---

### `journal` 相关

#### 查看 `journal` 占用磁盘量

```bash
journalctl --disk-usage
```

#### 查看某 `service` 日志

```bash
journalctl -f -u xxx.service
```

#### 限制持久化配置

```bash
vim /etc/systemd/journald.conf
SystemMaxUse=16M
ForwardToSyslog=no
```

参考链接
> https://www.cnsre.cn/posts/210401140104/