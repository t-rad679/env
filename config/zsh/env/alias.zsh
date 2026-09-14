#!/usr/bin/zsh

alias ls=lsd
alias la="lsd -al"

alias vi=vim

alias clip="xclip -selection c"

# Grimoire vault; GRIMOIRE_DIR is exported by globalvars.zsh (expanded when the
# alias runs, so load order between the two files doesn't matter).
alias cdg='cd "$GRIMOIRE_DIR"'
