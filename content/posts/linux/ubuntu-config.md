---
title: "Ubuntu Config"
date: 2023-09-24T10:56:12+08:00
draft: false
toc: true
tags: [ubuntu]
---

## 配置中文输入法

1. Open Settings, go to `Region & Language` -> `Manage Installed Languages` -> `Install / Remove languages`.
2. Select `Chinese (Simplified)`. Make sure `Keyboard Input method system` has `Ibus` selected. Apply.
3. Reboot
4. Log back in, reopen Settings, go to `Keyboard`.
5. Click on the "+" sign under `Input sources`.
6. Select `Chinese (China)` and then `Chinese (Intelligent Pinyin)`.

[ubuntu-22-04-chinese-simplified-pinyin-input-support](https://askubuntu.com/questions/1408873/ubuntu-22-04-chinese-simplified-pinyin-input-support)

## 换`apt`源

https://mirrors.tuna.tsinghua.edu.cn/help/ubuntu/

```bash
sudo su -

cat <<EOF > /etc/apt/sources.list
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy main restricted universe multiverse
deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse
deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse
deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse

deb http://security.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse
deb-src http://security.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse

# 预发布软件源，不建议启用
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-proposed main restricted universe multiverse
deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-proposed main restricted universe multiverse
EOF
```

## 安装 oh my zsh

```bash
sudo apt install zsh curl -y
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

[ohmyz.sh](https://ohmyz.sh/)

## 安装 golang

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

## 安装 hugo

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

## 安装 openssh-server

```bash
sudo apt install openssh-server
```

sudo vim /etc/ssh/sshd_config

```diff
- #PermitRootLogin prohibit-password
+ PermitRootLogin yes
```

```bash
sudo systemctl restart ssh
```

## 安装 gnome 插件

需要先安装有`GNOME Shell extension`

```bash
sudo apt install gnome-shell-extension-manager
```

- 划词翻译插件(可选辞典web地址,我选择的bing) [Screen work translate](https://extensions.gnome.org/extension/1849/screen-word-translate/)
- 在 top bar 上显示当前网络上下行速度和总流量 [Net speed Simplified](https://extensions.gnome.org/extension/3724/net-speed-simplified/)
- 允许连接锁着的远程桌面[Allow Locked Remote Desktop](https://extensions.gnome.org/extension/4338/allow-locked-remote-desktop/)
  - 默认情况下不允许连接已经锁屏的终端`tty0` [askubuntu](https://askubuntu.com/questions/1411504/connect-when-remote-desktop-is-on-login-screen-or-screen-locked-without-autolog)

## 所有网卡都禁用ipv6

vim /etc/sysctl.conf

```diff
+ net.ipv6.conf.all.disable_ipv6 = 1
```

## 安装`VLC`媒体播放器

https://www.videolan.org/vlc/download-ubuntu.html

```bash
sudo snap install vlc
```

### 快捷键

|快捷键|功能|
|:--|:--|
|`v`|切换字幕|

## 安装 `docker`

https://docs.docker.com/engine/install/ubuntu/
https://github.com/docker/docker-install

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh ./get-docker.sh
```

## 安装`virt-manager`

```bash
sudo apt install virt-manager -y
```

## 设置所有`sudo`组下的用户执行`sudo`命令不需要密码

`EDITOR=vim visudo`

```diff
# Allow members of group sudo to execute any command
- %sudo   ALL=(ALL:ALL) ALL
+ %sudo   ALL=(ALL:ALL) NOPASSWD:ALL
```

## 删除用户密码

> 危险操作, 具有`sudo`权限的普通用户就更是危险操作了, 不过自己在家用时, 每次解锁或登录不用输入一长串密码真的`很方便!!!`, 这样就可以把`Screen Blank`的时间调短一点了😄

`passwd`有一个`-d`参数

```bash
# passwd -h | grep -e "-d"
  -d, --delete                  delete the password for the named account
```

删除某个账户的密码

```bash
sudo passwd -d {username}
```