#!/usr/bin/zsh

# User-level Claude Code config from the repo's claude/ directory.

source "${ENV_DIR:-$HOME/src/env}/init/lib.zsh"

CLAUDE_DIR="$HOME/.claude"
CLAUDE_SRC="$ENV_DIR/claude"

# Global instructions and settings are symlinks: Claude Code writes settings
# changes back through the link, so the repo always has the live copy.
link_path "$CLAUDE_SRC/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
link_path "$CLAUDE_SRC/settings.json" "$CLAUDE_DIR/settings.json"

# Every directory under claude/user-skills/ is a user skill.
for skill_dir in "$CLAUDE_SRC"/user-skills/*(/N); do
    link_path "$skill_dir" "$CLAUDE_DIR/skills/${skill_dir:t}"
done

# config.json holds the Obsidian Local REST API key, which differs per machine
# and must never enter git: copy the committed sample once, never overwrite,
# and leave the key for you to paste in.
if [[ ! -e "$CLAUDE_DIR/config.json" ]]; then
    cp "$CLAUDE_SRC/config.sample.json" "$CLAUDE_DIR/config.json"
    print "    created $CLAUDE_DIR/config.json from config.sample.json"
fi
if grep -q 'PASTE-OBSIDIAN-LOCAL-REST-API-KEY-HERE' "$CLAUDE_DIR/config.json" 2>/dev/null; then
    print "    REMINDER: paste the Obsidian Local REST API key (Obsidian -> Settings ->"
    print "              Local REST API -> copy key) into $CLAUDE_DIR/config.json"
fi

# Local plugin marketplaces are given by absolute path in settings.json, and
# Claude Code is not documented to expand ~ there. The committed file uses
# ~/src/<name>; rewrite every directory-source marketplace to $HOME/src/<name>
# for this user. Idempotent (no write when nothing changes) and written
# through the symlink so settings.json stays a link into the repo.
settings="$CLAUDE_DIR/settings.json"
if command -v jq &> /dev/null && [[ -r $settings ]]; then
    filter='.extraKnownMarketplaces |= (if . == null then . else with_entries(
                if .value.source.source == "directory"
                then .value.source.path = ($home + "/src/" + (.value.source.path | split("/") | last))
                else . end) end)'
    current="$(jq . "$settings" 2>/dev/null)"
    updated="$(jq --arg home "$HOME" "$filter" "$settings" 2>/dev/null)"
    if [[ -n $updated && "$updated" != "$current" ]]; then
        print -r -- "$updated" > "$settings"
        print "    rewrote local marketplace paths in settings.json to $HOME/src/<name>"
    fi
else
    print -u2 "    jq missing or settings.json unreadable; marketplace paths not rewritten"
fi
