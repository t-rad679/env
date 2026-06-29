#!/usr/bin/zsh

# Wire my git helper scripts into git as subcommands.
#
# Uses include.path so my aliases are layered onto the user's global config
# without overwriting it. After this, `git update`, `git cleanup`, and
# `git rename-branch` resolve to the scripts in git/.

ENV_DIR="${ENV_DIR:-$HOME/src/env}"

# Add our include once. Using --add (guarded by a membership check) avoids both
# duplicate entries and the "cannot overwrite multiple values" error when the
# user already has other include.path values.
if ! git config --global --get-all include.path 2>/dev/null \
        | grep -qxF "$ENV_DIR/git/gitconfig"; then
    git config --global --add include.path "$ENV_DIR/git/gitconfig"
fi
