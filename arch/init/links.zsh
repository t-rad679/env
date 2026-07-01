#!/usr/bin/zsh

# Symlink my dotfiles into place.

ENV_DIR="${ENV_DIR:-$HOME/src/env}"

# Main zshrc + the antidote plugin list it loads (`antidote load` reads
# ~/.zsh_plugins.txt).
ln -sf "$ENV_DIR/zsh/.zshrc" "$HOME/.zshrc"
ln -sf "$ENV_DIR/zsh/.zsh_plugins.txt" "$HOME/.zsh_plugins.txt"

# Env scripts -> ~/env. The zshrc sets ZSH_CUSTOM=~/env and sources ~/env/*.zsh
# (alphabetical order). Symlink the whole directory.
ln -sfn "$ENV_DIR/zsh/env" "$HOME/env"

# i3 window manager config. Back up a pre-existing real config the same way
# pacman.zsh handles pacman.conf -- only if it isn't already our symlink, so
# repeat runs don't clobber the backup with our own symlink target.
mkdir -p "$HOME/.config/i3"
if [[ -e "$HOME/.config/i3/config" && ! -L "$HOME/.config/i3/config" ]]; then
    mv "$HOME/.config/i3/config" "$HOME/.config/i3/config.bak"
fi
ln -sf "$ENV_DIR/arch/i3/config" "$HOME/.config/i3/config"

# Make zsh the login shell (idempotent; prompts for password). Without this you
# stay in bash on login and the zshrc -- antidote, aliases, etc. -- never loads.
zsh_path="$(command -v zsh)"
if [[ -n $zsh_path && "$(getent passwd "$USER" | cut -d: -f7)" != "$zsh_path" ]]; then
    chsh -s "$zsh_path"
fi
unset zsh_path
