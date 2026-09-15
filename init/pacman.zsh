#!/usr/bin/zsh

# Sets up pacman and installs packages: the shared list plus this role's list.
#
# Deliberately interactive (no --noconfirm): the desktop gaming packages raise
# provider prompts (steam -> lib32-vulkan-driver, ...) and --noconfirm silently
# takes the first alphabetical provider, an AMD one, instead of NVIDIA. Answer
# the prompts; --needed still keeps re-runs cheap.

source "${ENV_DIR:-$HOME/src/env}/init/lib.zsh"

# Use my pacman.conf. A real /etc/pacman.conf is backed up once (to
# /etc/pacman.conf.bak); on a re-run it's already our symlink, so nothing moves.
sudo_link_path "$ENV_DIR/config/pacman.conf" /etc/pacman.conf

# git is needed to bootstrap yay
sudo pacman -S --needed git

# Bootstrap the yay AUR helper
source "$ENV_DIR/init/yay.zsh"

# Update everything
yay -Syu

# Install packages (one per line, # for comments; yay handles both official-repo
# and AUR packages). config/packages.txt is installed on every machine;
# machines/<role>/packages.txt holds what only this role needs (desktop:
# gaming/NVIDIA). The list goes in on stdin (`-`): yay reads it, then reopens
# /dev/tty as its stdin (pacman does the same), so the prompts above still get
# answered from the terminal.
cat "$ENV_DIR/config/packages.txt" "$ENV_DIR/machines/$MACHINE_ROLE/packages.txt" \
    | grep -vE '^[[:space:]]*(#|$)' \
    | sort -u \
    | yay -S --needed -
