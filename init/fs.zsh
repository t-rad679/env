#!/usr/bin/zsh

# Create the base directories the rest of init (and the shell config) expect.
# ~/bin is deliberately NOT created here: it is the user's own directory (init
# never links it; config/zsh/env/path.zsh just adds it to PATH if it exists).

mkdir -p "$HOME/src" "$HOME/.config"

# ~/.ssh must exist before links.zsh links ~/.ssh/config into it, and must be
# 0700 -- link_path's own `mkdir -p` would make it 0755. -m only applies when
# the directory is created, so an existing ~/.ssh keeps its mode.
mkdir -p -m 700 "$HOME/.ssh"

# Obsidian vaults live here on both machines (GRIMOIRE_DIR in
# config/zsh/env/globalvars.zsh points inside it). Only the parent is created;
# the vault itself is moved/cloned by hand.
mkdir -p "$HOME/docs/obsidian_vaults"
