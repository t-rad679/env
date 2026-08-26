#!/usr/bin/zsh

# Install the latest Node via nvm and make it the default for this shell.
# nvm itself is the `nvm` pacman package (see packages.txt); on Arch it loads from
# /usr/share/nvm/init-nvm.sh, not the ~/.nvm git clone. init.zsh *sources* its
# steps, so sourcing nvm here puts its shell functions in scope for the commands
# below.

source /usr/share/nvm/init-nvm.sh

nvm install node   # latest release
nvm use node
