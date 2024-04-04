---
title: "Rclone"
date: 2024-04-04T15:56:58+08:00
draft: false
toc: true
tags: [rclone]
---

> 使用`rclone`和`alist`提供的`webdav`接口将阿里云盘`mount`到Ubuntu 22.04的目录上

## 下载安装`rclone`

```bash
curl https://rclone.org/install.sh | bash
```

## 配置`rclone config`

```bash
# rclone config
No remotes found, make a new one?
n) New remote
s) Set configuration password
q) Quit config
n/s/q> n

Enter name for new remote.
name> alist

Option Storage.
Type of storage to configure.
Choose a number from below, or type in your own value.
 1 / 1Fichier
   \ (fichier)
...
51 / WebDAV
   \ (webdav)
...
Storage> 51

Option url.
URL of http host to connect to.
E.g. https://example.com.
Enter a value.
url> http://alist.home.lan/dav/

Option vendor.
Name of the WebDAV site/service/software you are using.
Choose a number from below, or type in your own value.
Press Enter to leave empty.
 1 / Fastmail Files
   \ (fastmail)
 2 / Nextcloud
   \ (nextcloud)
 3 / Owncloud
   \ (owncloud)
 4 / Sharepoint Online, authenticated by Microsoft account
   \ (sharepoint)
 5 / Sharepoint with NTLM authentication, usually self-hosted or on-premises
   \ (sharepoint-ntlm)
 6 / rclone WebDAV server to serve a remote over HTTP via the WebDAV protocol
   \ (rclone)
 7 / Other site/service or software
   \ (other)
vendor> 7

Option user.
User name.
In case NTLM authentication is used, the username should be in the format 'Domain\User'.
Enter a value. Press Enter to leave empty.
user> admin

Option pass.
Password.
Choose an alternative below. Press Enter for the default (n).
y) Yes, type in my own password
g) Generate random password
n) No, leave this optional password blank (default)
y/g/n> y
Enter the password:
password:
Confirm the password:
password:

Option bearer_token.
Bearer token instead of user/pass (e.g. a Macaroon).
Enter a value. Press Enter to leave empty.
bearer_token>

Edit advanced config?
y) Yes
n) No (default)
y/n> n

Configuration complete.
Options:
- type: webdav
- url: http://alist.home.lan/dav/
- vendor: other
- user: admin
- pass: *** ENCRYPTED ***
Keep this "alist" remote?
y) Yes this is OK (default)
e) Edit this remote
d) Delete this remote
y/e/d> y

Current remotes:

Name                 Type
====                 ====
alist                webdav

e) Edit existing remote
n) New remote
d) Delete remote
r) Rename remote
c) Copy remote
s) Set configuration password
q) Quit config
e/n/d/r/c/s/q> q
```


### 查看有哪些remote

```bash
# rclone listremotes
alist:
```

### 查看某个`remote`下的目录或文件

```bash
# rclone lsd alist:/ali/video/诛仙
          -1 2024-04-02 12:27:23        -1 诛仙.第1季.2022-2023.4K.全26集
          -1 2024-04-02 12:27:24        -1 诛仙.第2季.2024
# rclone ls alist:/ali/video/诛仙/诛仙.第2季.2024
959919343 第27集-Zhu.Xian-2024-03-29-4k-HEVC-H265.AAC-WEB-DL.mkv
995844543 第28集-Zhu.Xian-2024-03-29-4K-HEVC-H265.AAC-WEB-DL.mkv
1012470661 第29集-Zhu.Xian-2024-03-29-4K-HEVC-H265.AAC-WEB-DL.mkv
```

## 将`alist` mount 到目录

```bash
sudo mkdir -p /mnt/alist
sudo chmod 777 /mnt/alist
# --header "Referer:https://www.aliyundrive.com/" 是必须要有的
rclone mount --cache-dir=/tmp --vfs-cache-mode=writes --header "Referer:https://www.aliyundrive.com/" alist: /mnt/alist/
```

配置开机自动挂载

```bash
cat <<EOF > /etc/systemd/system/mount-mnt-alist.service
[Unit]
Description=Mount alist
After=network.target

[Service]
Type=simple
# 因为我的桌面用户是gobai, 所以需要指定gobai, mount之后/mnt/alist目录的owner会变成执行用户
User=gobai
ExecStart=rclone mount --cache-dir=/tmp --vfs-cache-mode=writes --header "Referer:https://www.aliyundrive.com/" alist: /mnt/alist/
ExecStop=umout /mnt/alist
Restart=on-failure
RestartSec=15

[Install]
WantedBy=default.target
EOF

systemctl start mount-mnt-alist
systemctl enable mount-mnt-alist
```

## 参考

1. https://rclone.org/downloads/
2. https://alist.nn.ci/guide/webdav.html