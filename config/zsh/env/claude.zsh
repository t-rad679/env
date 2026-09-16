#!/bin/zsh

# Setup for Claude plugins and such.
#
# NO CREDENTIALS IN THIS FILE. ~/src/env is a public GitHub repo; three mem0
# API keys lived here in plaintext from 2026-06-28 until 2026-09-16 and had to
# be rotated. Commenting a key out does not hide it -- the text is still in the
# file, and still on GitHub.
#
# Real values live in ~/.config/env-secrets.zsh (mode 600, outside the repo, so
# git cannot see it whatever happens to .gitignore). Sourced here rather than
# dropped in ~/env/ directly because that whole directory IS the repo --
# .zshrc sources $ZSH_CUSTOM/*.zsh and ZSH_CUSTOM=~/env is a symlink to
# config/zsh/env, so a secrets file placed there would sit inside a public
# working tree.
#
# To add a credential: export it from ~/.config/env-secrets.zsh. Nothing else
# needs changing here.
if [[ -r ~/.config/env-secrets.zsh ]]; then
    source ~/.config/env-secrets.zsh
else
    print -u2 "claude.zsh: ~/.config/env-secrets.zsh is missing -- MEM0_API_KEY and"
    print -u2 "            any other real credentials are not set in this shell."
fi
