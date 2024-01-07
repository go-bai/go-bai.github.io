---
title: "使用golang计算md5 sum"
date: 2023-01-13T00:50:19+08:00
draft: true
tags: ["golang", "md5"]
---

### 代码

```golang
package main

import (
    "crypto/md5"
    "encoding/hex"
    "fmt"
)

func main() {
    str := `this is the file content`
    md5sum := md5.Sum([]byte(str))
    fmt.Printf("%x\n", md5sum)
    fmt.Printf("%s\n", hex.EncodeToString(md5sum[:]))
}
```

### 输出

```bash
$ go run main.go
89b4f1823325ce4530cc264cc758baa7
89b4f1823325ce4530cc264cc758baa7
```
