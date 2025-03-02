---
title: "Linux iptables"
date: 2025-03-02T10:09:37+08:00
draft: false
---

> 持续更新...

## iptables 介绍

四表五链

### 五链

为什么称为 `链`，因为每个 `链` 会有很多规则串在一起，每个经过的报文都要将这条链上的规则匹配一遍，如果有符合条件的规则，则执行规则对应的动作。

每个链会包含多个表的规则，如果包含对应的表，则表之间的执行顺序为：

```bash
# 具体每个表的作用看后面的 "四表" 介绍, 不是每个 "链" 都能包含全部的四个表
raw -> mangle -> nat -> filter
```

#### PREROUTING 链

数据包抵达系统内核空间时，由 PREROUTING 链负责

#### INPUT 链

进入内核空间后，如果检测到目的地址是本机，则由 INPUT 链负责

#### FORWARD 链

数据包如果不是要到本机，只是经过本机路由，就由 FORWARD 链负责

#### OUTPUT 链

数据包如果从本机出去，就由 OUTPUT 链负责

#### POSTROUTING 链

从内核空间出到网卡硬件设备之前做处理

数据包如果要离开本机，或者路由后，还有个 POSTROUTING 链负责

### 四表

具有相同功能的规则的集合叫做 `表`，iptables 定义了 四种表。

最常用的是 filter 表和 nat 表

#### filter 表

过滤数据包

`filter` 表中的规则可以被 `INPUT`, `FORWARD` 和 `OUTPUT` 三个链使用

#### nat 表

网络地址转换

`nat` 表中的规则可以被 `PREROUTING`, `INPUT`, `OUTPUT` 和 `POSTROUTING` 四个链使用

#### mangle 表

TODO

#### raw 表

TODO

## 参考

1. [iptables详解（1）：iptables概念](https://www.zsythink.net/archives/1199)