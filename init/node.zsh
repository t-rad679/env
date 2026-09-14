#!/usr/bin/zsh

# Install the latest Node via nvm and make it the default.
# nvm itself is the `nvm` pacman package (see config/packages.txt); on Arch it
# loads from /usr/share/nvm/init-nvm.sh, not the ~/.nvm git clone. Each init
# step runs in its own subshell, so nvm is sourced here; later steps that need
# npm (spotify-mcp.zsh) source it again themselves.

if [[ ! -r /usr/share/nvm/init-nvm.sh ]]; then
    print -u2 "node: /usr/share/nvm/init-nvm.sh not found (is the nvm package installed?)"
    return 1
fi
source /usr/share/nvm/init-nvm.sh

nvm install node   # latest release
nvm alias default node
nvm use node
