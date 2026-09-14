#!/usr/bin/zsh

# Make zsh the login shell (idempotent; prompts for your password the first
# time). Without this you stay in bash on login and the zshrc -- antidote,
# aliases, etc. -- never loads.

zsh_path="$(command -v zsh)"
current_shell="$(getent passwd "$USER" | cut -d: -f7)"
if [[ -n $zsh_path && $current_shell != "$zsh_path" ]]; then
    chsh -s "$zsh_path"
else
    print "    login shell is already $zsh_path"
fi
