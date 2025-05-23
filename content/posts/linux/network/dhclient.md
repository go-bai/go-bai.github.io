---
title: "dhclient 问题"
date: 2023-10-09T21:37:55+08:00
---

在机器上使用`netplan`+`NetworkManager`配置[bridged network](../creating-a-bridged-network-with-netplan-on-ubuntu-22-04)之后

最近经常电脑用着用着就不能联网了，发现`enp1s0`总是偶尔冒出一个`ipv4`地址，并且路由表会多出一个从`enp1s0`出去的`default`路由。后来看`journalctl`日志发现是`dhclient`搞的事情(学艺不精, 没第一时间联系起来)。

下面是部分日志：

```bash
➜  ~ journalctl -n 1000000 | grep '192.168.1.22\|enp1s0'
...
10月 09 20:14:25 gobai-SER dhclient[107299]: DHCPREQUEST for 192.168.1.22 on enp1s0 to 255.255.255.255 port 67 (xid=0x4745a8ce)
10月 09 20:14:26 gobai-SER dhclient[73666]: DHCPREQUEST for 192.168.1.22 on enp1s0 to 255.255.255.255 port 67 (xid=0x2cfc74b3)
10月 09 20:14:26 gobai-SER dhclient[157839]: DHCPREQUEST for 192.168.1.22 on enp1s0 to 255.255.255.255 port 67 (xid=0x453b8549)
10月 09 20:14:28 gobai-SER dhclient[170251]: DHCPREQUEST for 192.168.1.22 on enp1s0 to 255.255.255.255 port 67 (xid=0x334a15e8)
10月 09 20:14:28 gobai-SER dhclient[237127]: DHCPREQUEST for 192.168.1.22 on enp1s0 to 255.255.255.255 port 67 (xid=0x7fd24947)
10月 09 20:14:32 gobai-SER avahi-autoipd(enp1s0)[307826]: Found user 'avahi-autoipd' (UID 110) and group 'avahi-autoipd' (GID 119).
10月 09 20:14:32 gobai-SER avahi-autoipd(enp1s0)[307826]: Successfully called chroot().
10月 09 20:14:32 gobai-SER avahi-autoipd(enp1s0)[307826]: Successfully dropped root privileges.
10月 09 20:14:32 gobai-SER avahi-autoipd(enp1s0)[307826]: Starting with address 169.254.4.220
10月 09 20:14:32 gobai-SER avahi-autoipd(enp1s0)[307826]: Got SIGTERM, quitting.
10月 09 20:14:32 gobai-SER dhclient[170251]: DHCPDISCOVER on enp1s0 to 255.255.255.255 port 67 interval 3 (xid=0x1f69d35f)
10月 09 20:14:32 gobai-SER dhclient[170251]: DHCPOFFER of 192.168.1.22 from 192.168.1.1
10月 09 20:14:32 gobai-SER dhclient[170251]: DHCPREQUEST for 192.168.1.22 on enp1s0 to 255.255.255.255 port 67 (xid=0x5fd3691f)
10月 09 20:14:32 gobai-SER dhclient[170251]: DHCPACK of 192.168.1.22 from 192.168.1.1 (xid=0x1f69d35f)
10月 09 20:14:32 gobai-SER avahi-daemon[588]: Joining mDNS multicast group on interface enp1s0.IPv4 with address 192.168.1.22.
10月 09 20:14:32 gobai-SER avahi-daemon[588]: New relevant interface enp1s0.IPv4 for mDNS.
10月 09 20:14:32 gobai-SER avahi-daemon[588]: Registering new address record for 192.168.1.22 on enp1s0.IPv4.
10月 09 20:14:32 gobai-SER systemd-resolved[237121]: enp1s0: Bus client set search domain list to: home
10月 09 20:14:32 gobai-SER dhclient[157839]: DHCPDISCOVER on enp1s0 to 255.255.255.255 port 67 interval 3 (xid=0x41cc913f)
10月 09 20:14:32 gobai-SER systemd-resolved[237121]: enp1s0: Bus client set DNS server list to: 192.168.1.1, 223.5.5.5
10月 09 20:14:32 gobai-SER dhclient[157839]: DHCPOFFER of 192.168.1.22 from 192.168.1.1
10月 09 20:14:32 gobai-SER dhclient[157839]: DHCPREQUEST for 192.168.1.22 on enp1s0 to 255.255.255.255 port 67 (xid=0x3f91cc41)
10月 09 20:14:32 gobai-SER dhclient[157839]: DHCPACK of 192.168.1.22 from 192.168.1.1 (xid=0x41cc913f)
10月 09 20:14:32 gobai-SER dhclient[170251]: bound to 192.168.1.22 -- renewal in 32921 seconds.
10月 09 20:14:32 gobai-SER dhclient[157839]: bound to 192.168.1.22 -- renewal in 36989 seconds.
10月 09 20:14:35 gobai-SER avahi-daemon[588]: Withdrawing address record for 192.168.1.22 on enp1s0.
10月 09 20:14:35 gobai-SER avahi-daemon[588]: Leaving mDNS multicast group on interface enp1s0.IPv4 with address 192.168.1.22.
10月 09 20:14:35 gobai-SER avahi-daemon[588]: Interface enp1s0.IPv4 no longer relevant for mDNS.
10月 09 20:14:35 gobai-SER avahi-autoipd(enp1s0)[307982]: Found user 'avahi-autoipd' (UID 110) and group 'avahi-autoipd' (GID 119).
10月 09 20:14:35 gobai-SER avahi-autoipd(enp1s0)[307982]: Successfully called chroot().
10月 09 20:14:35 gobai-SER avahi-autoipd(enp1s0)[307982]: Successfully dropped root privileges.
10月 09 20:14:35 gobai-SER avahi-autoipd(enp1s0)[307982]: Starting with address 169.254.4.220
10月 09 20:14:35 gobai-SER avahi-autoipd(enp1s0)[307982]: Got SIGTERM, quitting.
10月 09 20:14:36 gobai-SER dhclient[73666]: DHCPDISCOVER on enp1s0 to 255.255.255.255 port 67 interval 3 (xid=0x50a89e0e)
10月 09 20:14:36 gobai-SER dhclient[73666]: DHCPOFFER of 192.168.1.22 from 192.168.1.1
10月 09 20:14:36 gobai-SER dhclient[73666]: DHCPREQUEST for 192.168.1.22 on enp1s0 to 255.255.255.255 port 67 (xid=0xe9ea850)
10月 09 20:14:36 gobai-SER dhclient[73666]: DHCPACK of 192.168.1.22 from 192.168.1.1 (xid=0x50a89e0e)
10月 09 20:14:36 gobai-SER avahi-daemon[588]: Joining mDNS multicast group on interface enp1s0.IPv4 with address 192.168.1.22.
10月 09 20:14:36 gobai-SER avahi-daemon[588]: New relevant interface enp1s0.IPv4 for mDNS.
10月 09 20:14:36 gobai-SER avahi-daemon[588]: Registering new address record for 192.168.1.22 on enp1s0.IPv4.
10月 09 20:14:36 gobai-SER systemd-resolved[237121]: enp1s0: Bus client set search domain list to: home
10月 09 20:14:36 gobai-SER systemd-resolved[237121]: enp1s0: Bus client set DNS server list to: 192.168.1.1, 223.5.5.5
10月 09 20:14:36 gobai-SER dhclient[73666]: bound to 192.168.1.22 -- renewal in 34351 seconds.
10月 09 20:14:36 gobai-SER dhclient[107299]: DHCPDISCOVER on enp1s0 to 255.255.255.255 port 67 interval 3 (xid=0x27725347)
10月 09 20:14:36 gobai-SER dhclient[107299]: DHCPOFFER of 192.168.1.22 from 192.168.1.1
10月 09 20:14:36 gobai-SER dhclient[107299]: DHCPREQUEST for 192.168.1.22 on enp1s0 to 255.255.255.255 port 67 (xid=0x47537227)
10月 09 20:14:36 gobai-SER dhclient[107299]: DHCPACK of 192.168.1.22 from 192.168.1.1 (xid=0x27725347)
10月 09 20:14:36 gobai-SER dhclient[107299]: bound to 192.168.1.22 -- renewal in 40122 seconds.
10月 09 20:14:36 gobai-SER avahi-daemon[588]: Withdrawing address record for 192.168.1.22 on enp1s0.
10月 09 20:14:36 gobai-SER avahi-daemon[588]: Leaving mDNS multicast group on interface enp1s0.IPv4 with address 192.168.1.22.
10月 09 20:14:36 gobai-SER avahi-daemon[588]: Interface enp1s0.IPv4 no longer relevant for mDNS.
10月 09 20:14:36 gobai-SER avahi-autoipd(enp1s0)[308110]: Found user 'avahi-autoipd' (UID 110) and group 'avahi-autoipd' (GID 119).
10月 09 20:14:36 gobai-SER avahi-autoipd(enp1s0)[308110]: Successfully called chroot().
10月 09 20:14:36 gobai-SER avahi-autoipd(enp1s0)[308110]: Successfully dropped root privileges.
10月 09 20:14:36 gobai-SER avahi-autoipd(enp1s0)[308110]: Starting with address 169.254.4.220
10月 09 20:14:42 gobai-SER avahi-autoipd(enp1s0)[308110]: Callout BIND, address 169.254.4.220 on interface enp1s0
10月 09 20:14:42 gobai-SER avahi-daemon[588]: Joining mDNS multicast group on interface enp1s0.IPv4 with address 169.254.4.220.
10月 09 20:14:42 gobai-SER avahi-daemon[588]: New relevant interface enp1s0.IPv4 for mDNS.
10月 09 20:14:42 gobai-SER avahi-daemon[588]: Registering new address record for 169.254.4.220 on enp1s0.IPv4.
10月 09 20:14:46 gobai-SER avahi-autoipd(enp1s0)[308110]: Successfully claimed IP address 169.254.4.220
10月 09 20:14:46 gobai-SER avahi-autoipd(enp1s0)[308110]: Got SIGTERM, quitting.
10月 09 20:14:46 gobai-SER avahi-autoipd(enp1s0)[308110]: Callout STOP, address 169.254.4.220 on interface enp1s0
10月 09 20:14:46 gobai-SER avahi-daemon[588]: Withdrawing address record for 169.254.4.220 on enp1s0.
10月 09 20:14:46 gobai-SER avahi-daemon[588]: Leaving mDNS multicast group on interface enp1s0.IPv4 with address 169.254.4.220.
10月 09 20:14:46 gobai-SER avahi-daemon[588]: Interface enp1s0.IPv4 no longer relevant for mDNS.
10月 09 20:14:46 gobai-SER dhclient[237127]: DHCPDISCOVER on enp1s0 to 255.255.255.255 port 67 interval 3 (xid=0x389e944d)
10月 09 20:14:46 gobai-SER dhclient[237127]: DHCPOFFER of 192.168.1.22 from 192.168.1.1
10月 09 20:14:46 gobai-SER dhclient[237127]: DHCPREQUEST for 192.168.1.22 on enp1s0 to 255.255.255.255 port 67 (xid=0x4d949e38)
10月 09 20:14:46 gobai-SER dhclient[237127]: DHCPACK of 192.168.1.22 from 192.168.1.1 (xid=0x389e944d)
10月 09 20:14:46 gobai-SER avahi-daemon[588]: Joining mDNS multicast group on interface enp1s0.IPv4 with address 192.168.1.22.
10月 09 20:14:46 gobai-SER avahi-daemon[588]: New relevant interface enp1s0.IPv4 for mDNS.
10月 09 20:14:46 gobai-SER avahi-daemon[588]: Registering new address record for 192.168.1.22 on enp1s0.IPv4.
10月 09 20:14:47 gobai-SER systemd-resolved[237121]: enp1s0: Bus client set search domain list to: home
10月 09 20:14:47 gobai-SER systemd-resolved[237121]: enp1s0: Bus client set DNS server list to: 192.168.1.1, 223.5.5.5
10月 09 20:14:47 gobai-SER dhclient[237127]: bound to 192.168.1.22 -- renewal in 40782 seconds.

➜  ~ ps -aux | grep dhclient
root       73666  0.0  0.0 101232  6228 ?        Ssl  9月28   0:15 dhclient
root      107299  0.0  0.0 101232  6228 ?        Ssl  10月04   0:09 dhclient
root      157839  0.0  0.0 101232  6112 ?        Ssl  10月06   0:06 dhclient
root      170251  0.0  0.0 101232  6184 ?        Ssl  10月06   0:08 dhclient
root      237127  0.0  0.0 101232  6012 ?        Ssl  10月07   0:06 dhclient
gobai     322905  0.0  0.0  12308  2816 pts/5    S+   21:49   0:00 grep --color=auto --exclude-dir=.bzr --exclude-dir=CVS --exclude-dir=.git --exclude-dir=.hg --exclude-dir=.svn --exclude-dir=.idea --exclude-dir=.tox dhclient
```

对比上面五个进程(`DHCP Client`)和日志发现，五个进程都干了同样的事：


- DHCP DISCOVER
    - 将该报文放入目的端口67(DHCP Server)和源端口68(DHCP Client)的UDP报文段
    - 该UDP报文段放置在一个具有广播IP目的地址(255.255.255.255)和源IP地址0.0.0.0的IP数据报中, 因为此时enp1s0还没有ip地址
    - IP数据报又被放置在以太网帧中, 该以太网帧目的MAC地址为FF:FF:FF:FF:FF:FF使该帧将广播到与路由器/交换机连接的所有设备, 该帧的源MAC地址是enp1s0的MAC地址
- DHCP OFFER
    - DHCP Server用来响应DHCP DISCOVER报文，此报文携带了分给enp1s0的地址192.168.1.22和DHCP Server的地址192.168.1.1。
- DHCP REQUEST
    - 发送广播的DHCP REQUEST报文来回应服务器的DHCP OFFER报文。表示要给enp1s0申请ip 192.168.1.22
- DHCP ACK
    - 服务器对客户端的DHCP REQUEST报文的确认响应报文，客户端收到此报文后，才真正获得了IP地址和相关的配置信息。

出现5个dhclient进程的原因就是之前测试执行dhclient命令后没有停止运行它

将上面5个进程全kill后就一切正常了，后面有时间再详细读一下dhclient的manual

#### 参考

- 计算机网络 自顶向下方法 第七版
- [Understanding the Basic Operations of DHCP](https://www.netmanias.com/en/post/techdocs/5998/dhcp-network-protocol/understanding-the-basic-operations-of-dhcp)