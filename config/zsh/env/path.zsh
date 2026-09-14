#!/usr/bin/zsh

# ~/bin is a symlink to the env repo's bin/ (see init/links.zsh).
if [[ -d ~/bin ]]; then
    export PATH=~/bin:$PATH
fi

# Role-only scripts (e.g. the desktop's headless Obsidian / Claude remote-control
# helpers) live under machines/<role>/bin in the env repo.
if [[ -n $MACHINE_ROLE && -d ~/src/env/machines/$MACHINE_ROLE/bin ]]; then
    export PATH=~/src/env/machines/$MACHINE_ROLE/bin:$PATH
fi

if [[ -d ~/.local/bin ]]; then
    export PATH=~/.local/bin:$PATH
fi

if [[ -d ~/.pub-cache/bin ]]; then
    export PATH=~/.pub-cache/bin:$PATH
fi
