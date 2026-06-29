#!/usr/bin/zsh

# Sets up pacman and installs packages

ENV_DIR="${ENV_DIR:-$HOME/src/env}"

# Use my pacman.conf. Back up the original only once -- on a re-run
# /etc/pacman.conf is already our symlink, so don't clobber the real backup.
if [[ ! -L /etc/pacman.conf ]]; then
    sudo mv /etc/pacman.conf /etc/pacman.conf.bak
fi
sudo ln -sf "$ENV_DIR/arch/config/pacman.conf" /etc/pacman.conf

# git is needed to bootstrap yay
sudo pacman -S --needed --noconfirm git

# Bootstrap the yay AUR helper
source "$ENV_DIR/arch/init/install/yay.zsh"

# Update everything
yay -Syu --noconfirm

# Install my always-on packages (one per line in packages.txt, # for comments).
# yay handles both official-repo and AUR packages.
grep -vE '^[[:space:]]*(#|$)' "$ENV_DIR/arch/config/packages.txt" \
    | yay -S --needed --noconfirm -
