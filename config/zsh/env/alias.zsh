#!/usr/bin/zsh

alias ls=lsd
alias la="lsd -al"

alias vi=vim

# Clipboard. This is an X-vs-Wayland split, NOT a per-machine one: the
# spellbook boots either i3 on X or niri on Wayland, so a machines/<role>/
# answer would be wrong every time it came up under i3. xclip still runs under
# niri through xwayland-satellite, but it only sees the XWayland clipboard --
# which is not the selection a native Wayland app reads or writes.
if [[ -n $WAYLAND_DISPLAY ]]; then
    alias clip="wl-copy"
else
    alias clip="xclip -selection c"
fi

# Grimoire vault; GRIMOIRE_DIR is exported by globalvars.zsh (expanded when the
# alias runs, so load order between the two files doesn't matter).
alias cdg='cd "$GRIMOIRE_DIR"'
