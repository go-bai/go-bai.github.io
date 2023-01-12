---
title: "减小go程序编译后的体积"
date: 2021-11-22T10:29:02+08:00
draft: false
tags: ["golang"]
---

## 编译经典程序

### 程序代码

```go
package main

import "fmt"

func main() {
	fmt.Println("Hello World.")
}
```

### 编译环境

```bash
$ go version
go version go1.16.7 linux/amd64
```

## 0. 直接编译

```
$ go build -o helloword main.go
$ ls -lh helloword 
-rwxrwxr-x 1 gobai gobai 1.9M Nov 23 09:34 helloword
```

## 1. 修改编译选项

除去编译时带的符号表和调试信息

```bash
$ go build -ldflags="-s -w" -o helloword main.go
$ ls -lh helloword 
-rwxrwxr-x 1 gobai gobai 1.3M Nov 23 09:38 helloword

```
## 2. 使用 `UPX`

对直接编译出的二进制使用 [upx](https://github.com/upx/upx) 进一步压缩

```bash
$ go build -o helloword main.go
$ upx -9 helloword 
                       Ultimate Packer for eXecutables
                          Copyright (C) 1996 - 2020
UPX 3.96        Markus Oberhumer, Laszlo Molnar & John Reiser   Jan 23rd 2020

        File size         Ratio      Format      Name
   --------------------   ------   -----------   -----------
   1937143 ->   1105452   57.07%   linux/amd64   helloword                     

Packed 1 file.
$ ls -lh helloword 
-rwxrwxr-x 1 gobai gobai 1.1M Nov 23 09:40 helloword
```

## 1和2组合使用

```bash
$ go build -ldflags="-s -w" -o helloword main.go && upx -9 helloword
                       Ultimate Packer for eXecutables
                          Copyright (C) 1996 - 2020
UPX 3.96        Markus Oberhumer, Laszlo Molnar & John Reiser   Jan 23rd 2020

        File size         Ratio      Format      Name
   --------------------   ------   -----------   -----------
   1355776 ->    543392   40.08%   linux/amd64   helloword                     

Packed 1 file.
$ ls -lh helloword 
-rwxrwxr-x 1 gobai gobai 531K Nov 23 09:42 helloword
```

可以看出，压缩效果显著！



参考链接

- [How to reduce compiled file size?](https://stackoverflow.com/questions/3861634/how-to-reduce-compiled-file-size)
