#!/usr/bin/zsh

# Create the base directories the rest of init (and the shell config) expect.
# ~/bin is deliberately NOT created here: it is the user's own directory (init
# never links it; config/zsh/env/path.zsh just adds it to PATH if it exists).

mkdir -p "$HOME/src" "$HOME/.config"

# Obsidian vaults live here on both machines (GRIMOIRE_DIR in
# config/zsh/env/globalvars.zsh points inside it). Only the parent is created;
# the vault itself is moved/cloned by hand.
mkdir -p "$HOME/docs/obsidian_vaults"
