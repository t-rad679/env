#!/usr/bin/zsh

# User-level Claude Code config from the repo's claude/ directory.

source "${ENV_DIR:-$HOME/src/env}/init/lib.zsh"

CLAUDE_DIR="$HOME/.claude"
CLAUDE_SRC="$ENV_DIR/claude"
CONFIG="$CLAUDE_DIR/config.json"
rc=0

# Global instructions and settings are symlinks: Claude Code writes settings
# changes back through the link, so the repo always has the live copy.
link_path "$CLAUDE_SRC/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md" || rc=1
link_path "$CLAUDE_SRC/settings.json" "$CLAUDE_DIR/settings.json" || rc=1

# Every directory under claude/user-skills/ is a user skill.
for skill_dir in "$CLAUDE_SRC"/user-skills/*(/N); do
    link_path "$skill_dir" "$CLAUDE_DIR/skills/${skill_dir:t}" || rc=1
done

# config.json holds the Obsidian Local REST API key, which differs per machine
# and must never enter git: copy the committed sample once, never overwrite,
# and leave the key for you to paste in.
if [[ -L $CONFIG ]]; then
    # An older init linked this into the repo (claude/config.json, since
    # renamed to config.sample.json and gitignored), so on an already
    # provisioned machine the link is usually dangling. Keep the contents if
    # the link still resolves (a real key may be in there), otherwise drop the
    # dangling link and start from the sample.
    if [[ -r $CONFIG ]]; then
        if cp -L "$CONFIG" "$CONFIG.real" && mv "$CONFIG.real" "$CONFIG"; then
            print "    replaced symlink with a real copy: $CONFIG"
        else
            print -u2 "    could not replace symlink $CONFIG with a real copy"
            rc=1
        fi
    else
        print "    removing dangling symlink $CONFIG -> $(readlink "$CONFIG")"
        rm "$CONFIG" || rc=1
    fi
fi
if [[ ! -e $CONFIG ]]; then
    if cp "$CLAUDE_SRC/config.sample.json" "$CONFIG"; then
        print "    created $CONFIG from config.sample.json"
    else
        print -u2 "    could not create $CONFIG from config.sample.json"
        rc=1
    fi
fi
if grep -q 'PASTE-OBSIDIAN-LOCAL-REST-API-KEY-HERE' "$CONFIG" 2>/dev/null; then
    print "    REMINDER: paste the Obsidian Local REST API key (Obsidian -> Settings ->"
    print "              Local REST API -> copy key) into $CONFIG"
fi

return $rc
