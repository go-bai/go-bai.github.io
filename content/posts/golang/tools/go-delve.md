---
title: "Delve"
date: 2025-04-12T00:00:41+08:00
# bookComments: false
# bookSearchExclude: false
---

## 介绍

[Delve](https://github.com/go-delve/delve) 是 Go 编程语言的调试器。

## 原理

TODO

## 在 vscode 中使用

将 `request` 设置为 `attach` 并且 `processId` 设置为 0, 这样就会每次执行

在 go 项目根目录下设置 `.vscode/launch.json` 文件如下:

- `"type": "go"`: 配置类型为 go
- `"request": "attach"`: 这里配置为 attach 到一个已经运行的进程
- `"mode": "local"`: 相当于 attach 到本地进程
- `"processId": 0`: 相当于没指定 pid, 每次启动 debug 会让选择进程

```json
{
    // Use IntelliSense to learn about possible attributes.
    // Hover to view descriptions of existing attributes.
    // For more information, visit: https://go.microsoft.com/fwlink/?linkid=830387
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Attach to Process",
            "type": "go",
            "request": "attach",
            "mode": "local",
            "processId": 0
        }
    ]
}
```

## 参考

- [github.com/golang/vscode-go/docs/debugging](https://github.com/golang/vscode-go/blob/master/docs/debugging.md)