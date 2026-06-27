#!/usr/bin/env bash

# Entry point for initialization. Runs under bash so it works on a fresh box
# that does not have zsh yet.

set -euo pipefail

# Ensure zsh is installed before we hand off to the zsh init flow.
sudo pacman -S --needed --noconfirm zsh

# Run the real init script (zsh) relative to this file, regardless of cwd.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
zsh "$DIR/init/init.zsh"
