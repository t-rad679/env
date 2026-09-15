#!/usr/bin/zsh

# Set up marcelmarais/spotify-mcp-server under ~/src (shared by both roles).
# Registering it in Claude (`claude mcp add ...`) is still a manual step.
#
# Re-runnable: skips an existing clone, only runs `npm install && npm run
# build` while the build output (build/index.js, tsc's outDir per upstream
# tsconfig.json; also the package's bin) is missing -- so a clone whose first
# build failed gets rebuilt on the next run instead of skipped -- never touches
# an existing config, never runs `npm run auth` without that build, and skips
# the OAuth dance when a token is already stored. Never exits the parent init.

ENV_DIR="${ENV_DIR:-$HOME/src/env}"

SPOTIFY_DIR="$HOME/src/spotify-mcp-server"
BUILD="$SPOTIFY_DIR/build/index.js"
CONFIG="$SPOTIFY_DIR/spotify-config.json"
CONFIG_SAMPLE="$ENV_DIR/config/spotify-mcp/spotify-config.sample.json"

# npm comes from nvm, which each step has to load itself.
[[ -r /usr/share/nvm/init-nvm.sh ]] && source /usr/share/nvm/init-nvm.sh
if ! command -v npm &> /dev/null; then
    print -u2 "    npm not found (node step failed?); skipping spotify-mcp"
    return 1
fi

if [[ ! -d $SPOTIFY_DIR ]]; then
    if ! gh repo clone marcelmarais/spotify-mcp-server "$SPOTIFY_DIR"; then
        print -u2 "    clone failed; skipping spotify-mcp"
        return 1
    fi
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

# Build whenever the output is missing: a fresh clone, or an earlier run whose
# build failed. Upstream `npm run build` is `tsc && chmod build/index.js`, and
# `npm run auth` (`tsc && node build/auth.js`) needs node_modules from the
# install, so neither is worth attempting past a failed build.
if [[ ! -e $BUILD ]]; then
    if ! ( cd "$SPOTIFY_DIR" && npm install && npm run build ); then
        print -u2 "    build failed; re-run init (or: cd $SPOTIFY_DIR && npm install && npm run build)"
        return 1
    fi
    if [[ ! -e $BUILD ]]; then
        print -u2 "    build finished but $BUILD is still missing; skipping npm run auth"
        return 1
    fi
else
    print "    $BUILD present; skipping npm install/build"
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
