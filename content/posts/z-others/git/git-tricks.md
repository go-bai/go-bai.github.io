---
title: "Git Tricks"
date: 2021-11-12T15:36:19+08:00
draft: false
---

## 暂存当前代码改动

场景是在一个git branch写了不少代码以后发现写错分支了，总不能删了再重新写吧，可以使用 `git stash` 命令解决。

```bash
# 将当前改动的代码暂存
git stash
#  git checkout 到你要工作的分支
git checkout your_workspace_branch
# 把暂存的代码从堆栈弹出到当前分支
git stash pop
```
