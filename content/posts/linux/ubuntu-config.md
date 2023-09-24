---
title: "Ubuntu Config"
date: 2023-09-24T10:56:12+08:00
draft: false
tags: [ubuntu]
---

### 配置中文输入法

1. Open Settings, go to `Region & Language` -> `Manage Installed Languages` -> `Install / Remove languages`.
2. Select `Chinese (Simplified)`. Make sure `Keyboard Input method system` has `Ibus` selected. Apply.
3. Reboot
4. Log back in, reopen Settings, go to `Keyboard`.
5. Click on the "+" sign under `Input sources`.
6. Select `Chinese (China)` and then `Chinese (Intelligent Pinyin)`.

[ubuntu-22-04-chinese-simplified-pinyin-input-support](https://askubuntu.com/questions/1408873/ubuntu-22-04-chinese-simplified-pinyin-input-support)

### 安装 oh my zsh

```bash
sudo apt install zsh curl -y
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

[ohmyz.sh](https://ohmyz.sh/)

### 安装 golang

下载并解压到 `/usr/local/go`目录下

```bash
sudo apt install wget -y
wget https://go.dev/dl/go1.21.1.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.21.1.linux-amd64.tar.gz
```

修改所有`user`和所有`shell`的`PATH`环境变量，
下面文件都添加一行 `export PATH=$PATH:/usr/local/go/bin`

```bash
/etc/zsh/zshenv
/etc/profile
/etc/bash.bashrc
```

新开一个`shell`会话验证

```bash
➜  ~ go version
go version go1.21.1 linux/amd64
```

[Download and install](https://go.dev/doc/install)

### 安装 hugo

```bash
sudo apt install build-essential -y
CGO_ENABLED=1 go install -tags extended github.com/gohugoio/hugo@latest
```

设置当前用户`zsh`的`PATH`环境变量

vim ~/.zshrc

```diff
+ export PATH=${PATH}:`go env GOPATH`/bin
```

新开一个`zsh shell`会话验证

```bash
➜  ~ hugo version
hugo v0.118.2+extended linux/amd64 BuildDate=unknown
```