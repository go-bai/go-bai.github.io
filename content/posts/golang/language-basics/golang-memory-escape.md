---
title: "内存逃逸"
date: 2025-03-05T13:23:47+08:00
# bookComments: false
# bookSearchExclude: false
---

## 内存逃逸

可以通过 `go build -gcflags=-m main.go` 分析内存逃逸

编译阶段不能确定大小的变量以及生命周期超出函数的局部变量数据都会逃逸到堆中。

### 1. 指针逃逸

算是最常见的了，函数中初始化一个局部变量，返回了这个变量的指针，因为指针的存在，变量的内存不能随着函数结束而回收，因此只能分配在堆上。

### 2. `interface{}` 动态类型逃逸

如果函数参数为 `interface{}`，编译期间很难确定其参数的类型以及大小，也会发生逃逸。

如传递给 `fmt.Println()` 的参数

### 3. 栈空间不足

分配大变量，如大 slice，会有可能栈空间不足，然后编译器将其分配在堆上

tcmalloc

### 4. 闭包

当一个闭包函数引用了外部变量并且会执行后续读写操作，则变量会被逃逸到堆上。

```golang
package main

func Increase() func() int {
	n := 0 // move to heap
	return func() int {
		n++
		return n
	}
}

func main() {
	in := Increase()
	println(in()) // 1
}
```