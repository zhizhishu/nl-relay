#!/bin/sh
# 在 Scaleway STARDUST 的 alpine-virt live(从DD的ISO启动) 里, 把 Alpine 装进 /dev/vda(1G)。
# 参考 nodeseek lemontea918 教程 + 加 sshd/公钥/IPv6静态网络, 装完可直接 SSH。
# 用法(串口控制台 root): 先配好 live 的临时网络能联网, 再 wget 本脚本 | sh
set -e
IP6="2001:bc8:711:603f:dc00:1ff:fe1c:5867"
GW6="fe80::dc00:1ff:fe1c:5868"
PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJl9z02/koxC572vNzNrgZiKUVdz2aq7qVI4D/EnORfr fr-relay-rescue"

echo "[1] 腾出 /dev/vda (modloop dance)"
mkdir -p /media/setup && cp -a /media/vda/* /media/setup/ 2>/dev/null || true
mkdir -p /lib/setup && cp -a /.modloop/* /lib/setup/ 2>/dev/null || true
/etc/init.d/modloop stop 2>/dev/null || true
umount /dev/vda 2>/dev/null || true
mv /media/setup/* /media/vda/ 2>/dev/null || true
mv /lib/setup/* /.modloop/ 2>/dev/null || true

echo "[2] repos + DNS64"
cat > /etc/apk/repositories <<EOF
https://dl-cdn.alpinelinux.org/alpine/v3.21/main
https://dl-cdn.alpinelinux.org/alpine/v3.21/community
EOF
echo "nameserver 2a00:1098:2c::1" > /etc/resolv.conf

echo "[3] 待装系统的网络配置(IPv6静态)"
cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback
auto eth0
iface eth0 inet6 static
    address ${IP6}
    netmask 64
    gateway ${GW6}
EOF

echo "[4] apk + 引导/ssh 组件"
apk update
apk add dosfstools grub-efi e2fsprogs openssh openssh-server util-linux

echo "[5] sshd + 公钥 + root 登录"
rc-update add sshd default
rc-update add networking boot
mkdir -p /root/.ssh && chmod 700 /root/.ssh
echo "$PUBKEY" > /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config 2>/dev/null || true

echo "[6] 装到 /dev/vda (setup-disk sys 模式, 非交互)"
export BOOTLOADER=grub
yes | setup-disk -m sys -k virt /dev/vda

echo "[7] 把公钥写进目标系统(关键: setup-disk -m sys 不拷 /root, 否则装完 SSH 公钥认证失败)"
for p in /dev/vda3 /dev/vda2 /dev/vda1; do
  [ -b "$p" ] || continue
  mount "$p" /mnt 2>/dev/null || continue
  if [ -e /mnt/etc/os-release ] && [ -d /mnt/root ]; then
    mkdir -p /mnt/root/.ssh && chmod 700 /mnt/root/.ssh
    echo "$PUBKEY" > /mnt/root/.ssh/authorized_keys && chmod 600 /mnt/root/.ssh/authorized_keys
    echo "  ssh key -> $p (target root)"; umount /mnt; break
  fi
  umount /mnt 2>/dev/null
done

echo "[DONE] 安装完成, 即将 reboot 进入硬盘 Alpine"
sync
