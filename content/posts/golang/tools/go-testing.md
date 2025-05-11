---
title: "Go Testing"
date: 2025-04-11T23:28:54+08:00
# bookComments: false
# bookSearchExclude: false
---

## 介绍

`testing` 包为 `Go` 包自动化测试提供支持，它与 `go test` 命令一起使用，该命令可以自动执行下面这种格式的函数。

```golang
func TestXxx(*testing.T)
```

其中函数名中的 `Xxx` 不能以小写字母开头。

在函数中，使用 `Error`, `Fail` 或相关的函数表示失败。

要编写测试函数，需要县创建一个以 `_test.go` 结尾的文件，该文件会被排除在常规包构建之外，但将在运行 `go test` 命令时被包含在内。

一般将 `_test.go` 文件创建在要被测试的函数的同包下面

## 测试函数示例

比如这里我要验证 `interface` 与 `nil` 是否相等

```golang
// test/interface_test/interface_test.go
package interface_test

import "testing"

func TestInterfaceNil(t *testing.T) {
	var a interface{}
	var b = (*int)(nil)
	a = b
	if a == nil {
		t.Fatal("a == nil")
	}
}
```

### go test 参数

有一些常用参数，可以通过 `go help test` 和 `go help testflag` 查看。

#### go test -run regexp

指定正则匹配到的测试函数，通过 `^` 标记开头和 `$` 标记结尾可以精准匹配。

```bash
$ go test -run ^TestInterfaceNil$ test/interface_test
ok      test/interface_test     0.002s
```

#### go test -v

默认 go test 通过的不会打印详细过程, 加上 -v 显示详细过程

```bash
go test -v -run ^TestInterfaceNil$ test/interface_test
=== RUN   TestInterfaceNil
--- PASS: TestInterfaceNil (0.00s)
PASS
ok      test/interface_test     0.002s
```

#### go test ./...

执行所有包下面的所有测试函数

```bash
$ go test ./...
ok      test/interface_test     0.002s
?       test/lru        [no test files]
```

## 参考

- [pkg.go.dev/testing](https://pkg.go.dev/testing)