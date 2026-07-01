#!/usr/bin/zsh

# Arch-only: nvm here lives at /usr/share/nvm. macOS gets nvm via nvm.zsh.
[[ "$OSTYPE" == linux* ]] || return 0

source /usr/share/nvm/init-nvm.sh
