#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
curl -LO "https://get.helm.sh/helm-v3.6.3-linux-amd64.tar.gz"
tar -xvzf helm-v3.6.3-linux-amd64.tar.gz
sudo install -o root -g root -m 0755 linux-amd64/helm /usr/local/bin/helm
sudo apt install -y git exuberant-ctags
#git clone https://github.com/Blixk/vimrc.git
#sudo cp vimrc/.vimrc /etc/vim/vimrc
#sudo mkdir /etc/vim/vim
#sudo cp -r vimrc/.vim/* /etc/vim/vim
#vim +set runtimepath+=/etc/vim/vim
#vim +PlugInstall +qall
