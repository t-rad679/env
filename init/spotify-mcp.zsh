#!/usr/bin/zsh

# Set up marcelmarais/spotify-mcp-server under ~/src (shared by both roles).
# Registering it in Claude (`claude mcp add ...`) is still a manual step.
#
# Re-runnable: skips an existing clone, never touches an existing config, and
# skips the OAuth dance when a token is already stored. Never exits the parent
# init.

ENV_DIR="${ENV_DIR:-$HOME/src/env}"

SPOTIFY_DIR="$HOME/src/spotify-mcp-server"
CONFIG="$SPOTIFY_DIR/spotify-config.json"
CONFIG_SAMPLE="$ENV_DIR/config/spotify-mcp/spotify-config.sample.json"

# npm comes from nvm, which each step has to load itself.
[[ -r /usr/share/nvm/init-nvm.sh ]] && source /usr/share/nvm/init-nvm.sh
if ! command -v npm &> /dev/null; then
    print -u2 "    npm not found (node step failed?); skipping spotify-mcp"
    return 1
fi

fresh_clone=0
if [[ ! -d $SPOTIFY_DIR ]]; then
    if ! gh repo clone marcelmarais/spotify-mcp-server "$SPOTIFY_DIR"; then
        print -u2 "    clone failed; skipping spotify-mcp"
        return 1
    fi
    fresh_clone=1
else
    print "    $SPOTIFY_DIR already present"
fi

# The server reads/writes spotify-config.json next to its build/ directory
# (src/utils.ts: CONFIG_FILE = ../spotify-config.json) and stores the OAuth
# result (accessToken/refreshToken) in it, so it holds secrets and is a real
# file, never a link into the repo. Copy the committed sample once and leave
# the client id/secret for you to paste in.
if [[ -L $CONFIG ]]; then
    # Older layout linked this into the repo. Keep the contents if the link
    # still resolves, otherwise drop the dangling link and start from the sample.
    if [[ -r $CONFIG ]]; then
        cp -L "$CONFIG" "$CONFIG.real" && mv "$CONFIG.real" "$CONFIG"
        print "    replaced repo symlink with a real copy: $CONFIG"
    else
        rm "$CONFIG"
    fi
fi
if [[ ! -e $CONFIG ]]; then
    cp "$CONFIG_SAMPLE" "$CONFIG"
    print "    created $CONFIG from spotify-config.sample.json"
fi

if (( fresh_clone )); then
    ( cd "$SPOTIFY_DIR" && npm install && npm run build ) || return 1
fi

if grep -q 'PASTE-SPOTIFY-CLIENT' "$CONFIG"; then
    print "    REMINDER: paste the Spotify app client id/secret (developer.spotify.com"
    print "              -> Dashboard -> your app) into $CONFIG, then run:"
    print "              cd $SPOTIFY_DIR && npm run auth"
    return 0
fi

# A stored refreshToken means we're authenticated; only run the interactive
# auth when it's missing.
token="$(jq -r '.refreshToken // ""' "$CONFIG" 2>/dev/null)"
if [[ -z $token || $token == "run-npm auth to get this" ]]; then
    ( cd "$SPOTIFY_DIR" && npm run auth ) || return 1
else
    print "    Spotify token already stored; skipping npm run auth"
fi
