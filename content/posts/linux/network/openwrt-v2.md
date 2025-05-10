---
title: "OpenWrt v2"
date: 2024-01-06T17:38:38+08:00
---

最近更新了家中 `OpenWrt` 的网络, 在宿主机增加一个 USB 网卡连通互联网, 拓扑图如下:

![穷人版家庭网络拓扑图](/posts/linux/imgs/allinone.drawio.png)

## 准备 qcow2 镜像

首先下载最新的[镜像](https://downloads.openwrt.org/releases), 截止目前最新版为`23.05.3`, 我这里下载的是x86-64的镜像
[text](openwrt.md)

```bash
wget https://mirror-03.infra.openwrt.org/releases/23.05.3/targets/x86/64/openwrt-23.05.3-x86-64-generic-ext4-combined.img.gz
gunzip openwrt-23.05.3-x86-64-generic-ext4-combined.img.gz
qemu-img convert -f raw openwrt-23.05.3-x86-64-generic-ext4-combined.img -O qcow2 /var/lib/libvirt/images/openwrt.qcow2
```

## 配置宿主机桥接网络

`/etc/netplan/` 目录只放 `01-all.yaml` 配置文件并执行 `netplan apply` 应用配置。

因为 USB 网卡重启后名称会变, 所以我这里通过 mac match 作了一个别名

```yaml
network:
  version: 2
  renderer: NetworkManager

  ethernets:
    enp1s0:
      dhcp4: false
      dhcp6: false
    usb-nic:
      match:
        macaddress: "68:da:73:a1:c7:13"
      dhcp4: false
      dhcp6: false

  bridges:
    br0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 192.168.1.100/24
      routes:
        - to: default
          via: 192.168.1.99
      nameservers:
        addresses:
          - 192.168.1.99
        search:
          - lan
      interfaces:
        - enp1s0
      parameters:
        stp: false
    br1:
      dhcp4: false
      dhcp6: false
      addresses:
        - 192.168.31.100/24
      interfaces:
        - usb-nic
      parameters:
        stp: false
```

## 启动 OpenWrt 虚拟机

我是用 `libvirt` 来管理qemu/kvm虚拟机, 如果没安装要先安装

```bash
apt install virt-manager qemu bridge-utils -y
```

我这里将镜像复制到了 `/var/lib/libvirt/disks/` 目录下

```bash
qemu-img create -f qcow2 -F qcow2 -b /var/lib/libvirt/images/openwrt.qcow2 /var/lib/libvirt/disks/openwrt.qcow2 1G
```

使用`virt-install`运行虚拟机, 这里网卡使用`virtio`类型并桥接到之前文档里创建的 `br0` 和 `br1` 上, 选择`virtio`是因为性能好, 可以达到 `20Gbps`

```bash
virt-install \
  --name openwrt \
  --memory 512 \
  --vcpus 1 \
  --network bridge=br0,model=virtio \
  --network bridge=br1,model=virtio \
  --disk path=/var/lib/libvirt/disks/openwrt.qcow2,bus=virtio \
  --os-type linux \
  --os-variant generic \
  --machine q35 \
  --import \
  --autostart \
  --graphics none \
  --noautoconsole
```

## 配置 OpenWrt 网络

连接`console`配置网络

```bash
virsh console openwrt
```

修改网络配置文件 `/etc/config/network`

```bash
config interface 'loopback'
  option device 'lo'
  option proto 'static'
  option ipaddr '127.0.0.1'
  option netmask '255.0.0.0'

config device 'lan_br'
  option name 'br-lan'
  option type 'bridge'
  list ports 'eth0'
  list ports 'phy0-ap0'

config interface 'lan'
  option device 'br-lan'
  option proto 'static'
  option ipaddr '192.168.1.99'
  option netmask '255.255.255.0'
  option ipv6 '0'
  list dns '223.5.5.5'

config interface 'wan'
  option device 'eth1'
  option proto 'static'
  option ipaddr '192.168.31.88'
  option netmask '255.255.255.0'
  option ipv6 '0'
  option gateway '192.168.31.1'
  option type 'bridge'
```

修改之后重启网络

```bash
service network restart
```

测试路由和DNS解析是否正常: `ping baidu.com`, 一切OK再继续下面的

## 更换 OpenWrt 软件源

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

[openwrt.org/docs/guide-user/advanced/expand_root](https://openwrt.org/docs/guide-user/advanced/expand_root)

扩容之后就使用起来就不用扣扣搜搜的了

```bash
root@OpenWrt:~# df -hT /
Filesystem           Type            Size      Used Available Use% Mounted on
/dev/root            ext4          994.8M     56.9M    921.9M   6% /
```

## 配置 LAN 口 DHCP 服务

修改配置文件 `/etc/config/dhcp`

```bash
config dhcp 'lan'
        option interface 'lan'
        option start '150'
        option limit '100'
        option leasetime '12h'
        option ignore '0'
```

修改之后重启 `service dnsmasq restart`, 配置之后有段时间dhcp server没正常运行, 可通过 `logread -e dnsmasq` 查看服务日志排查.

正常运行之后dhcp server会监听67端口

```bash
root@OpenWrt:~# netstat -anp | grep :67
udp        0      0 0.0.0.0:67              0.0.0.0:*                           27573/dnsmasq
```

## 配置无线网

### 将 AX200 无线网卡直通到虚拟机

直接在 Virtual Machine Manager 中选择 `Add Hardware` -> `PCI Host Device` 即可

```bash
$ lspci -D | grep AX200
0000:02:00.0 Network controller: Intel Corporation Wi-Fi 6 AX200 (rev 1a)
```

- `0000`: 这是 Domain 号, 通常是 0000
- `02`: 这是 Bus 号
- `00`: 这是 Device 号, 在 libvirt XML 中对应 slot
- `0`: 这是 Function 号

也可以通过命令行的方式, 先创建一个 `pci-device.xml` 文件, 其中 `bus` `slot` 和 `function` 从上面 lspci 结果获取

```xml
<hostdev mode='subsystem' type='pci' managed='yes'>
  <source>
    <address domain='0x0000' bus='0x02' slot='0x00' function='0x0'/>
  </source>
</hostdev>
```

然后热添加到虚拟机中并持久化进配置

```bash
virsh attach-device openwrt pci-device.xml --live --config
```

### 配置 AX200 无线网卡为 AP 模式

默认情况下, OpenWrt 的系统(system)菜单下面找不到无线(wireless)选项，需要进行下面的安装

无线网卡型号是 AX200 的驱动安装:

```bash
opkg update
# 针对 intel 网卡
opkg install kmod-iwlwifi
opkg install iwlwifi-firmware-ax200
# 需要重启
reboot
```

修改文件 `/etc/config/wireless` 设置 AP 模式, AX200型号网卡受iwlwifi驱动限制, 只能在2.4GHz带宽下工作

```bash
config wifi-device 'radio0'
  option type 'mac80211'
  option path 'pci0000:00/0000:00:01.4/0000:05:00.0'
  option htmode 'HT20'
  option disable '0'
  option cell_density '0'
  option band '2g'
  option channel '11'
  option country 'CN'

config wifi-iface 'default_radio0'
  option device 'radio0'
  option network 'lan'
  option mode 'ap'
  option ssid 'OpenWrt'
  option encryption 'psk2'
  option key '88888888'
  option disable '0'
```

重新加载

```bash
wifi
```

## 安装`OpenClash`

和 [OpenWrt](../openwrt) 中配置一样

## 参考

1. [OpenWrt in QEMU](https://openwrt.org/docs/guide-user/virtualization/qemu#virtualization_proper)
2. [OpenWrt: Expanding root partition and filesystem](https://openwrt.org/docs/guide-user/advanced/expand_root)
3. [OpenWrt: DHCP and DNS configuration /etc/config/dhcp](https://openwrt.org/docs/guide-user/base-system/dhcp)
4. [OpenWrt: Clarifying the term "Interface"](https://openwrt.org/docs/guide-user/base-system/clarifying_interface_usage)
5. [OpenClash 安装](https://github.com/vernesong/OpenClash/wiki/%E5%AE%89%E8%A3%85)
