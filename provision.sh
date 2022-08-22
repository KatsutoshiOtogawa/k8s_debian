#! /bin/bash

export DEBIAN_FRONTEND=noninteractive

apt update && apt upgrade -y

apt install -y neovim
apt install -y nmap
apt install -y mlocate

# kubernetes is neeed to swap off
# disable swap
swapoff -a
# swapdisk時代をコメントアウトしておくと、使われなくなる。
# [](https://docs.oracle.com/cd/F33069_01/start/swap.html)

cat << END >> /etc/systemd/system/swapoff.service
[Unit]
Description=swapoff for k8s running.
After=network-online.target

[Service]
User=root
ExecStart=/usr/sbin/swapoff -a

[Install]
WantedBy=multi-user.target
END

systemctl enable swapoff.service

# install dependency on crio
apt install -y \
    zstd \
    curl \
    gnupg

# [how to install crio](https://cri-o.io/)
# [search you can use version](http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/)
OS=Debian_11
VERSION=1.24
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
echo "deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.list

curl -L https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$VERSION/$OS/Release.key | apt-key add -
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | apt-key add -

apt-get update
apt-get install -y cri-o cri-o-runc

cat > /etc/modules-load.d/crio.conf <<EOF
# module load for crio
overlay
br_netfilter
EOF

# ここの後の処処のため、即即実行
modprobe br_netfilter

# persistent parameter.
cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system

systemctl daemon-reload
systemctl enable crio
systemctl start crio

apt-get update && apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg |apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# localhostをadmin, master, workerとして実行
# /etc/kubernetes/admin.confなどを作作すす。
kubeadm init  --kubernetes-version=v1.24.4

# defaultはvagrant
user=$(cat /etc/passwd | awk -F: '{if($3==1000){print $1}}')

mkdir /home/${user}/.kube
cp /etc/kubernetes/admin.conf /home/${user}/.kube/config
chown ${user}:${user} /home/${user}/.kube/config

# 設設用のimageをダウンロード
kubeadm config images pull

apt install -y podman
systemctl disable podman

updatedb
