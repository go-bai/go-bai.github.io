---
title: "Vim Tricks"
date: 2021-11-24T21:45:54+08:00
draft: false
tags: ["vim"]
---

## 批量替换

批量替换 1.1.1.1 为 2.2.2.2

```bash
:%s+1.1.1.1+2.2.2.2
```

## 两行合为一行

`NORMAL` 模式下按 `shift + j` 就会将光标下一行合并到当前行行尾