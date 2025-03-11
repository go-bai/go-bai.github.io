---
title: "Vim Tricks"
date: 2021-11-24T21:45:54+08:00
draft: false
---

## 批量替换

批量替换 v1.6.1 为 v2.7.0

```bash
:%s/v1.6.1/v2.7.0/g
```

## 两行合为一行

`NORMAL` 模式下按 `shift + j` 就会将光标下一行合并到当前行行尾
