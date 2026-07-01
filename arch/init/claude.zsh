#!/usr/bin/zsh

# Symlink user-level Claude config into place from the repo.

ENV_DIR="${ENV_DIR:-$HOME/src/env}"
CLAUDE_DIR="$HOME/.claude"
CLAUDE_SRC="$ENV_DIR/claude"

_backup_if_needed() {
    local target="$1"
    if [[ -e "$target" && ! -L "$target" ]]; then
        mv "$target" "${target}.bak"
    fi
}

mkdir -p "$CLAUDE_DIR/skills"

for f in CLAUDE.md settings.json config.json; do
    _backup_if_needed "$CLAUDE_DIR/$f"
    ln -sf "$CLAUDE_SRC/$f" "$CLAUDE_DIR/$f"
done

for skill in grimoire-export interpret-tarot; do
    _backup_if_needed "$CLAUDE_DIR/skills/$skill"
    ln -sfn "$CLAUDE_SRC/user-skills/$skill" "$CLAUDE_DIR/skills/$skill"
done
