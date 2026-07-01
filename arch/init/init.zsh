#!/usr/bin/zsh

# All the stuff I do to get my environment where I want it.
# Entry point: arch/init.sh -> this file.
#
# Steps are sourced by absolute path off $ENV_DIR so they don't depend on the
# current working directory.

export ENV_DIR="${ENV_DIR:-$HOME/src/env}"

source "$ENV_DIR/arch/init/fs.zsh"               # base directories
source "$ENV_DIR/arch/init/install/pacman.zsh"   # pacman.conf, git, yay, update, my packages
source "$ENV_DIR/arch/init/install/antidote.zsh" # antidote zsh plugin manager
source "$ENV_DIR/arch/init/links.zsh"            # symlink ~/.zshrc and env scripts
source "$ENV_DIR/arch/init/claude.zsh"           # symlink Claude config and user skills
source "$ENV_DIR/arch/init/git.zsh"              # wire git helper scripts into git
# Gaming last: big, optional, AUR-heavy -- keep it after the essential setup so a
# flaky package never blocks dotfiles/git wiring.
source "$ENV_DIR/arch/init/gaming.zsh"           # gaming / nvidia packages (needs yay)
