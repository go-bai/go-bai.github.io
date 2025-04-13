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

1. 函数返回指向局部变量的指针，变量内存不能随着函数结束而回收，只能分配在堆上
2. 函数调用其他寿命更长的函数时，将局部变量指针传递过去，同理。

### 2. 将变量存储到 `interface{}` 变量中

TODO 如果函数参数为 `interface{}`，编译期间很难确定其参数的类型以及大小，也会发生逃逸。

https://goperf.dev/01-common-patterns/interface-boxing/

### 3. 栈空间不足

每个 `goroutine` 都维护着一个自己的栈区，初始大小 `2KB`，栈结构经过了分段栈到[连续栈](https://docs.google.com/document/d/1wAaf1rYoM4S4gtnPh0zOlGzWtrZFQ5suE8qr2sD8uWQ/pub)的发展。

分配大变量，如大 slice，或者大小不确定的变量，会有可能栈空间不足，然后编译器将其分配在堆上，虽然栈会自动增长，但是也有大小限制(TODO)。

### 4. 闭包捕获变量

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

### 5. 变量地址存储在引用类型对象中

如将变量地址保存在 切片(slice)、映射(map)、通道(channel)、 接口(interface) 以及 函数(func) 中，那么此变量会逃逸到堆上.

```golang
func main() {
	a := make([]*int, 100)
	b := int(1)
	a = append(a, &b)
}
```

slice 和 map 的值不是指针类型时不会逃逸

### 6. 初始化 chennel

`channel` 一定是跨 `goroutine` 使用的，直接初始化在堆中

---

## 参考

- [Go栈内存管理](https://www.happy2coding.com/49218/)
- [7.3 栈空间管理](https://draven.co/golang/docs/part3-runtime/ch07-memory/golang-stack-management/)
- [Contiguous stacks](https://docs.google.com/document/d/1wAaf1rYoM4S4gtnPh0zOlGzWtrZFQ5suE8qr2sD8uWQ/pub)