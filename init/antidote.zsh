#!/usr/bin/zsh

# Install antidote, the zsh plugin manager, via its official git-clone install.
# (The AUR package named `antidote` is unrelated software -- Druide's writing
# tool; `zsh-antidote` is the real one, but git-clone is upstream-recommended and
# avoids AUR name/path surprises.) The plugins themselves are declared in
# ~/.zsh_plugins.txt and loaded by `antidote load` in the zshrc.

ANTIDOTE_DIR="${ZDOTDIR:-$HOME}/.antidote"

if [[ ! -d $ANTIDOTE_DIR ]]; then
    git clone --depth=1 https://github.com/mattmc3/antidote.git "$ANTIDOTE_DIR"
fi
