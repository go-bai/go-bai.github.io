---
title: "make 与 new 区别"
date: 2025-03-05T13:08:26+08:00
# bookComments: false
# bookSearchExclude: false
---

## make 和 new 的区别

> 都是内存分配函数

### 1. 基本用途

make 仅用于创建 `slice`、`map` 和 `channel`，并且会初始化这些类型的内部数据结构，返回初始化后的值类型
new 可用于任何类型，返回指向该类型零值的指针

### 2. 返回值

make返回初始化后的值类型
new返回指向该类型零值的指针

### 3. 内存分配

make会分配内存并初始化数据结构
new只分配内存，并把内存置零，不做初始化