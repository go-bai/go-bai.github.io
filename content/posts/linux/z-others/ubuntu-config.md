---
title: "Ubuntu Config"
date: 2023-09-24T10:56:12+08:00
---

> 以下配置都是在 `Ubuntu 22.04` 系统配置

## 配置中文输入法

> 现在已经换成 fcitx5 + 雾凇拼音，好用很多，见 [Ubuntu 22.04 GNOME Wayland 配置 fcitx5 + 雾凇拼音](/posts/fcitx5-rime-ice/)，下面是之前 ibus 的配置方式

1. Open Settings, go to `Region & Language` -> `Manage Installed Languages` -> `Install / Remove languages`.
2. Select `Chinese (Simplified)`. Make sure `Keyboard Input method system` has `Ibus` selected. Apply.
3. Reboot
4. Log back in, reopen Settings, go to `Keyboard`.
5. Click on the "+" sign under `Input sources`.
6. Select `Chinese (China)` and then `Chinese (Intelligent Pinyin)`.

[ubuntu-22-04-chinese-simplified-pinyin-input-support](https://askubuntu.com/questions/1408873/ubuntu-22-04-chinese-simplified-pinyin-input-support)

## 修正简体中文显示为异体(日文)字形

> ubuntu/linux对中文支持的不太好, 在选择汉字字体时, 优先选择的是日文或者韩文, 需要手动调整优先级后重启操作系统解决

root权限编辑 `/etc/fonts/conf.avail/64-language-selector-prefer.conf` 配置文件

```diff
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
        <alias>
                <family>sans-serif</family>
                <prefer>
+                       <family>Noto Sans CJK SC</family>
                        <family>Noto Sans CJK JP</family>
                        <family>Noto Sans CJK KR</family>
-                       <family>Noto Sans CJK SC</family>
                        <family>Noto Sans CJK TC</family>
                        <family>Noto Sans CJK HK</family>
                        <family>Lohit Devanagari</family>
                        <family>Noto Sans Sinhala</family>
                </prefer>
        </alias>
        <alias>
                <family>serif</family>
                <prefer>
+                       <family>Noto Serif CJK SC</family>
                        <family>Noto Serif CJK JP</family>
                        <family>Noto Serif CJK KR</family>
-                       <family>Noto Serif CJK SC</family>
                        <family>Noto Serif CJK TC</family>
                        <family>Lohit Devanagari</family>
                        <family>Noto Serif Sinhala</family>
                </prefer>
        </alias>
        <alias>
                <family>monospace</family>
                <prefer>
+                       <family>Noto Sans Mono CJK SC</family>
                        <family>Noto Sans Mono CJK JP</family>
                        <family>Noto Sans Mono CJK KR</family>
-                       <family>Noto Sans Mono CJK SC</family>
                        <family>Noto Sans Mono CJK TC</family>
                        <family>Noto Sans Mono CJK HK</family>
                </prefer>
        </alias>
</fontconfig>
```

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

apt update -y
```

## 使用`X11`替换`Wayland`

`Wayland`目前在我的`AMD 5700U`小机器上还是不太好用, 鼠标指针会有卡顿

编辑 `/etc/gdm3/custom.conf`

```diff
- #WaylandEnable=false
+ WaylandEnable=false
```

## 合上盖子不暂停系统(笔记本)

[Make Ubuntu Not Go in Suspend When Laptop Lid is Closed](https://itsfoss.com/laptop-lid-suspend-ubuntu/)

如果是在笔记本上安装的, 那么这个设置可以防止合上盖子`Lid`后`Suspend`系统

编辑`/etc/systemd/logind.conf`文件

```diff
- #HandleLidSwitch=suspend
+ HandleLidSwitch=ignore
- #HandleLidSwitchExternalPower=suspend
+ HandleLidSwitchExternalPower=ignore
- #HandleLidSwitchDocked=ignore
+ HandleLidSwitchDocked=ignore
```

然后重启 `systemd-logind` 生效

```bash
systemctl restart systemd-logind
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

### 修改`/etc/sysctl.conf`

```diff
+ net.ipv6.conf.all.disable_ipv6 = 1
```

然后执行`sysctl -p`加载新的配置生效

### 修改`/etc/default/grub`

```diff
- GRUB_CMDLINE_LINUX="..."
+ GRUB_CMDLINE_LINUX="... ipv6.disable=1"
```

然后执行`update-grub`更新`GRUB`, 这种指定`传递给内核命令行的参数`的方式需要`重启`系统之后才能生效 

## 安装`VLC`媒体播放器

https://www.videolan.org/vlc/download-ubuntu.html

```bash
sudo apt install vlc
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