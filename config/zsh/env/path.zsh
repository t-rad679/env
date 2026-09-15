#!/usr/bin/zsh

# ~/bin is the user's own directory of hand-written scripts (not managed by
# the env repo, never linked by init).
if [[ -d ~/bin ]]; then
    export PATH=~/bin:$PATH
fi

# Scripts for both machines live in the env repo's bin/.
if [[ -d ~/src/env/bin ]]; then
    export PATH=~/src/env/bin:$PATH
fi

# Role-only scripts (e.g. the desktop's headless Obsidian / Claude remote-control
# helpers) live under machines/<role>/bin in the env repo. The role defaults to
# desktop when unset (same default as everywhere else).
if [[ -d ~/src/env/machines/${MACHINE_ROLE:-desktop}/bin ]]; then
    export PATH=~/src/env/machines/${MACHINE_ROLE:-desktop}/bin:$PATH
fi

if [[ -d ~/.local/bin ]]; then
    export PATH=~/.local/bin:$PATH
fi

if [[ -d ~/.pub-cache/bin ]]; then
    export PATH=~/.pub-cache/bin:$PATH
fi
