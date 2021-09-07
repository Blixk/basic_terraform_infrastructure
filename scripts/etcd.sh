#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

cd /usr/local/src
sudo wget "https://github.com/coreos/etcd/releases/download/v3.5.0/etcd-v3.5.0-linux-amd64.tar.gz"
sudo tar vxzf etcd-v3.5.0-linux-amd64.tar.gz
sudo mv etcd-v3.5.0-linux-amd64/etcd* /usr/local/bin
sudo mkdir -p /etc/etcd /var/lib/etcdgroupadd -f -g 1501 etcd
useradd -c "etcd user" -d /var/lib/etcd -s /bin/false -g etcd -u 1501 etcd
chown -R etcd:etcd /var/lib/etcd

