---
title: "OpenWrt"
date: 2024-01-06T17:38:38+08:00
draft: false
toc: true
tags: [openwrt,linux,openclash,kvm,virt-install,network]
---

很久没折腾`OpenWrt`了, 囊中羞涩, 没有其他合适的设备, 这次是在KVM虚机中运行使用(`ALL IN BOOM!`)

先亮个当前的穷人版家庭网络拓扑图

![穷人版家庭网络拓扑图](/posts/linux/imgs/home-network-topology-diagram.svg)

## 准备`qcow2`镜像

首先下载最新的[镜像](https://downloads.openwrt.org/releases), 截止目前最新版为`23.05.3`, 我这里下载的是x86-64的镜像

```bash
wget https://mirror-03.infra.openwrt.org/releases/23.05.3/targets/x86/64/openwrt-23.05.3-x86-64-generic-ext4-combined.img.gz
# 解压
gunzip openwrt-23.05.3-x86-64-generic-ext4-combined.img.gz
# 这里因为我要作为KVM虚拟机的镜像, 所以转换为qcow2格式. 如果是在物理机上部署, 可以直接直接刷到U盘上.
qemu-img convert -f raw openwrt-23.05.3-x86-64-generic-ext4-combined.img -O qcow2 /var/lib/libvirt/images/openwrt.qcow2
```

## 运行虚机

我是用`libvirt`来管理qemu/kvm虚拟机, 如果没安装要先安装

```bash
apt install virt-manager qemu bridge-utils -y
```

我这里将镜像复制到了`/var/lib/libvirt/disks/`目录下

```bash
qemu-img create -f qcow2 -F qcow2 -b /var/lib/libvirt/images/openwrt.qcow2 /var/lib/libvirt/disks/openwrt.qcow2 1G
```

使用`virt-install`运行

```bash
# 运行, 这里网络指定的之前文章中创建的网桥网络br0
virt-install \
  --name openwrt \
  --memory 256 \
  --vcpus 1 \
  --network bridge=br0,model=virtio \
  --disk path=/var/lib/libvirt/disks/openwrt.qcow2,bus=ide \
  --import \
  --autostart \
  --osinfo detect=on,require=off \
  --noautoconsole
```

## 配置网络

连接`console`配置网络

```bash
virsh console openwrt
```

修改网络配置文件 `/etc/config/network`
只修改了`lan`配置和删除了`br-lan`网桥, 其他都是默认的, 因为我的使用场景比较简单, 虚拟机只有一个网卡, 直接使用`eth0`作为`lan`口连接器的物理网卡设备
具体修改了`lan`配置的`ipaddr`, 增加`gateway`和`dns`

```bash
config interface 'loopback'
	option device 'lo'
	option proto 'static'
	option ipaddr '127.0.0.1'
	option netmask '255.0.0.0'

config globals 'globals'
	option ula_prefix 'fd5d:6ea2:93e4::/48'

# config interface is not the configuration of a physical interface, but rather the specification of a connector to some network.
config interface 'lan'
	# device is usually not the name of something configured with config interface, but the name of a physical interface.
	option device 'eth0'
	option proto 'static'
	option ipaddr '192.168.1.99'
	option netmask '255.255.255.0'
	option gateway '192.168.1.1'
	list dns '223.5.5.5'
```

修改之后重启网络

```bash
service network restart
```

测试路由和DNS解析是否正常: `ping baidu.com`, 一切OK再继续下面的

## 换源

大陆码农生存必备技能了, 这里使用的中科大的源, 配置文件位于 `/etc/opkg/distfeeds.conf`

```bash
src/gz openwrt_core http://mirrors.ustc.edu.cn/openwrt/releases/23.05.3/targets/x86/64/packages
src/gz openwrt_base http://mirrors.ustc.edu.cn/openwrt/releases/23.05.3/packages/x86_64/base
src/gz openwrt_luci http://mirrors.ustc.edu.cn/openwrt/releases/23.05.3/packages/x86_64/luci
src/gz openwrt_packages http://mirrors.ustc.edu.cn/openwrt/releases/23.05.3/packages/x86_64/packages
src/gz openwrt_routing http://mirrors.ustc.edu.cn/openwrt/releases/23.05.3/packages/x86_64/routing
src/gz openwrt_telephony http://mirrors.ustc.edu.cn/openwrt/releases/23.05.3/packages/x86_64/telephony
```

然后更新一下

```bash
opkg update
```

## 扩容根分区和文件系统

如果觉得默认的100M左右就够用了可以跳过这步

这个文档里的脚本只支持x86的ext4和squashfs镜像创建的虚机, 自动检测根分区和文件系统, 将空闲空间分给根分区和文件系统

https://openwrt.org/docs/guide-user/advanced/expand_root

扩容之后就使用起来就不用扣扣搜搜的了

```bash
root@OpenWrt:~# df -hT /
Filesystem           Type            Size      Used Available Use% Mounted on
/dev/root            ext4          994.8M     56.9M    921.9M   6% /
```

## 安装`OpenClash`

主要是跟着[官方wiki](https://github.com/vernesong/OpenClash/wiki/%E5%AE%89%E8%A3%85)执行, 部分`Github`文件下载使用文件代理加速下载服务 https://mirror.ghproxy.com/

先卸载`dnsmasq`, 否则会和`dnsmasq-full`冲突, `openclash`依赖`dnsmasq-full`

```bash
# 如果提示dhcp配置文件(/etc/config/dhcp)没修改, 可以手动删了, 将新的(/etc/config/dhcp-opkg)覆盖过去
opkg remove dnsmasq && opkg install dnsmasq-full
```

下载安装安装包和各依赖

```bash
# 下载安装包
cd /tmp && wget https://mirror.ghproxy.com/https://github.com/vernesong/OpenClash/releases/download/v0.46.011-beta/luci-app-openclash_0.46.011-beta_all.ipk
# 安装所有依赖
opkg install coreutils-nohup bash iptables dnsmasq-full curl ca-certificates ipset ip-full iptables-mod-tproxy iptables-mod-extra libcap libcap-bin ruby ruby-yaml kmod-tun kmod-inet-diag unzip luci-compat luci luci-base
# 安装
opkg install /tmp/luci-app-openclash_0.46.011-beta_all.ipk
```

下载clash内核

```bash
# 下载
wget https://mirror.ghproxy.com/https://github.com/vernesong/OpenClash/releases/download/Clash/clash-linux-amd64.tar.gz
# 解压
tar -zxvf clash-linux-amd64.tar.gz
# 放置到执行目录下
mv clash /etc/openclash/core/clash
# 如果没有可执行权限设置执行权限
chmod +x /etc/openclash/core/clash
```

## 打开登录 `OpenWrt` web界面配置

默认密码为空, 第一次登录后可以修改一下

打开`Services`下的`OpenClash`进行配置即可.

此处省略1w字...

验证`OpenWrt`的DHCP服务没问题后, 关闭主路由器的DHCP服务.

关于为什么关闭主路由的DHCP功能: 因为我的主路由不支持设置DHCP服务器的默认网关, 所以只有设置静态ip并手动填写网关和DNS为`OpenWrt`的ip才能魔法上网. 不如直接不使用主路由的DHCP服务, 然后开启`OpenWrt` lan口的DHCP服务.

至此大功告成, 连接wifi之后即可魔法上网, (手动撒花).


---

分割线

---

## 其他小修改

### 修改dhcp分配ip范围

修改配置文件 `/etc/config/dhcp`

```bash
config dhcp 'lan'
        option interface 'lan'
        option start '150'
        option limit '100'
        option leasetime '12h'
```

修改之后重启 `service dnsmasq restart`, 配置之后有段时间dhcp server没正常运行, 可通过 `logread -e dnsmasq` 查看服务日志排查.

正常运行之后dhcp server会监听67端口

```bash
root@OpenWrt:~# netstat -anp | grep :67
udp        0      0 0.0.0.0:67              0.0.0.0:*                           27573/dnsmasq
```

### 修改br0的网关和dns

为了小主机三层网络也路由到代理网关, 这里修改之前br0的netplan配置后执行`netplan apply`生效


```diff
network:
  bridges:
    br0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 192.168.1.100/24
      routes:
        - to: default
-         via: 192.168.1.1
+         via: 192.168.1.99
      nameservers:
        addresses: 
-         - 192.168.1.1
-         - 223.5.5.5
+         - 192.168.1.99
+       search:
+         - lan
      interfaces:
        - enp1s0
      parameters:
        stp: false
```

## 参考

1. [OpenWrt in QEMU](https://openwrt.org/docs/guide-user/virtualization/qemu#virtualization_proper)
2. [OpenWrt: Expanding root partition and filesystem](https://openwrt.org/docs/guide-user/advanced/expand_root)
3. [OpenWrt: DHCP and DNS configuration /etc/config/dhcp](https://openwrt.org/docs/guide-user/base-system/dhcp)
4. [OpenClash 安装](https://github.com/vernesong/OpenClash/wiki/%E5%AE%89%E8%A3%85)