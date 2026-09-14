#!/usr/bin/zsh

# Symlink my dotfiles into place. Idempotent; real files that are in the way
# are backed up once (see init/lib.zsh for the exact rules).

source "${ENV_DIR:-$HOME/src/env}/init/lib.zsh"

# ~/bin is the repo's bin/ (config/zsh/env/path.zsh puts it on PATH). A real
# ~/bin is moved to ~/bin.bak -- anything in there needs to be re-homed by hand.
link_path "$ENV_DIR/bin" "$HOME/bin"

# Main zshrc + the antidote plugin list it loads (`antidote load` reads
# ~/.zsh_plugins.txt).
link_path "$ENV_DIR/config/zsh/.zshrc" "$HOME/.zshrc"
link_path "$ENV_DIR/config/zsh/.zsh_plugins.txt" "$HOME/.zsh_plugins.txt"

# Env scripts -> ~/env. The zshrc sets ZSH_CUSTOM=~/env and sources ~/env/*.zsh
# (alphabetical order). Symlink the whole directory.
link_path "$ENV_DIR/config/zsh/env" "$HOME/env"

# i3: the whole ~/.config/i3 directory is the repo's config/i3, so the
# `include conf.d/*.conf` in config/i3/config resolves no matter how i3
# resolves relative includes through a symlink. Role-specific i3 config is
# pulled in by config/i3/config via $MACHINE_ROLE (see machines/<role>/i3/).
link_path "$ENV_DIR/config/i3" "$HOME/.config/i3"

# kitty terminal config (font, etc).
link_path "$ENV_DIR/config/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"

# ~/.xprofile: sourced by LightDM before i3 starts; exports MACHINE_ROLE into
# the X session. (POSIX sh, not zsh, because LightDM runs it with sh.)
link_path "$ENV_DIR/config/.xprofile" "$HOME/.xprofile"
