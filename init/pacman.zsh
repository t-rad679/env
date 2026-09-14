#!/usr/bin/zsh

# Sets up pacman and installs packages: the shared list plus this role's list.

source "${ENV_DIR:-$HOME/src/env}/init/lib.zsh"

# Use my pacman.conf. A real /etc/pacman.conf is backed up once (to
# /etc/pacman.conf.bak); on a re-run it's already our symlink, so nothing moves.
sudo_link_path "$ENV_DIR/config/pacman.conf" /etc/pacman.conf

# git is needed to bootstrap yay
sudo pacman -S --needed --noconfirm git

# Bootstrap the yay AUR helper
source "$ENV_DIR/init/yay.zsh"

# Update everything
yay -Syu --noconfirm

# Install packages (one per line, # for comments; yay handles both official-repo
# and AUR packages). config/packages.txt is installed on every machine;
# machines/<role>/packages.txt holds what only this role needs (desktop:
# gaming/NVIDIA).
cat "$ENV_DIR/config/packages.txt" "$ENV_DIR/machines/$MACHINE_ROLE/packages.txt" \
    | grep -vE '^[[:space:]]*(#|$)' \
    | sort -u \
    | yay -S --needed --noconfirm -
