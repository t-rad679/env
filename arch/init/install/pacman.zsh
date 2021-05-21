#!/usr/bin/zsh

# Sets up pacman and installs necessary packages

sudo mv /etc/pacman.conf /etc/pacman.conf.bak
sudo ln -s $HOME/src/env/arch/config/pacman.conf /etc/pacman.conf

sudo pacman -S git

source yay.zsh

yay -Syu