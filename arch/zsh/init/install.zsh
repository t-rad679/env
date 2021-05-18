#!/usr/bin/zsh

# Installs necessary packages

sudo pacman -S git

# Yay package manager
cd ~/src
sudo git clone https://aur.archlinux.org/yay.git
sudo chown -R tradical:tradical ./yay
cd yay
makepkg -si

