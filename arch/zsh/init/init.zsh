#!/usr/bin/zsh

# Initializes the ZSH environment (plugins, themes, etc)
# Assumes it is being run from the containing directory

# TODO: Figure out a better way to get ZSH_CUSTOM set
ZSH_CUSTOM=~/.oh-my-zsh/custom

source ./install.zsh
echo $ZSH_CUSTOM
yay -S oh-my-zsh-git
yay -S zsh-syntax-highlighting

ln -s "$(pwd)/custom" "$ZSH_CUSTOM/env/"
ln -s "$(pwd)/env.zsh" "$ZSH_CUSTOM/env.zsh"
