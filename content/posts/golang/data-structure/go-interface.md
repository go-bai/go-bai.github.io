---
title: "interface"
date: 2025-04-10T23:33:00+08:00
# bookComments: false
# bookSearchExclude: false
---

## `interface` 底层结构

`interface{}` 底层存储结构如下所示：

```golang
// ----------- runtime/runtime2.go -----------------

type iface struct {
	tab  *itab
	data unsafe.Pointer
}

type eface struct {
	_type *_type
	data  unsafe.Pointer
}

type itab = abi.ITab
type _type = abi.Type

// ----------- internal/abi/iface.go -----------------

// The first word of every non-empty interface type contains an *ITab.
// It records the underlying concrete type (Type), the interface type it
// is implementing (Inter), and some ancillary information.
//
// allocated in non-garbage-collected memory
type ITab struct {
	Inter *InterfaceType
	Type  *Type
	Hash  uint32     // copy of Type.Hash. Used for type switches.
	Fun   [1]uintptr // variable sized. fun[0]==0 means Type does not implement Inter.
}
```

可以看到 `interface{}` 底层被存储为两种类型:

- `iface` 表示有方法集的接口类型变量
- `eface` 表示没有方法的空接口类型变量，也就是 `interface{}` 类型的变量

## `interface` 注意要点

### 判断 interface{} 是否等于 nil

比如以下函数 `returnError` 返回 `error`, 处理返回的 `error` 时要判断是不是 `nil`

```golang
type MyError string

func (e *MyError) Error() string { return string(*e) }

func bad() bool { return false }

func returnError() error {
	var err *MyError = nil
	if bad() {
		badErr := MyError("bad error")
		err = &badErr
	}
	return err
}
```

既然是注意点，那就肯定不是简单的 `v == nil` 的方式比较。

> 首先简化一下上述函数，因为一直不会进入 `if bad() {}`, 所以简化为
```golang
func returnError() error {
	var err *MyError = nil
	return err
}
```

> 这里也要注意，上述代码和和**直接 `var err *MyError = nil` 然后比较 `err` 是否为 `nil` 是不一样的。**这种 `err`是 `*MyError` 类型，可以直接与 `nil` 比较并且`相等`，不是 `interface{}`


而 `func returnError() error` 相当与如下代码，返回的是 `interface{}`:

```golang
var ret error
var err *MyError = nil
ret = err
return ret
```

> 上述代码中, 相当于把一个类型为 `*MyError` 但是值为 `nil` 的变量赋值给了 `inerface{}` 类型的 `ret`，因为 `ret` 有实现 `error` 接口的方法 `func Error() string`，所以底层使用 `iface` 存储，其中:
>
> - `iface.tab.Type` 会存储 `*MyError` 类型
> - `iface.data` 为 nil
>
> 当 `ret ` 直接与 `nil` 比较时会先比较类型，`*MyError` 和 `nil` 不相等，**如果直接比较就容易被坑!!!**

---
---
---

所以：

当调用一些奇怪函数返回 `interface{}` 类型变量或者函数接收 `interface{}` 类型变量并且需要判断是否为 `nil` 时就要张个心眼。可以使用如下函数判断一个 `interface{}` 是否为 `nil`：

```golang
func IsNil(v interface{}) bool {
	if v == nil {
		return true
	}
	switch reflect.TypeOf(v).Kind() {
	case reflect.Chan, reflect.Func, reflect.Slice,
		reflect.Map, reflect.Ptr:
		return reflect.ValueOf(v).IsNil()
	default:
		return false
	}
}
```

## 参考

- [理解Go interface的两种底层实现:iface和eface](https://blog.frognew.com/2018/11/go-interface-iface-eface.html)
- [Go: Check Nil interface the right way](https://mangatmodi.medium.com/go-check-nil-interface-the-right-way-d142776edef1)
- [Why is my nil error value not equal to nil?](https://go.dev/doc/faq#nil_error)