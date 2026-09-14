#!/usr/bin/zsh

# All the stuff I do to get my environment where I want it.
# Entry point: init/init.sh -> this file (init.sh sets MACHINE_ROLE and
# INIT_LINKS_ONLY from its flags; running this file directly works too).
#
# Every step is sourced by absolute path off $ENV_DIR, so nothing depends on
# the current working directory, and each one runs in its own subshell so a
# failing step (or a stray `exit` inside it) reports and moves on instead of
# killing the whole init. Steps are all safe to re-run.

export ENV_DIR="${ENV_DIR:-$HOME/src/env}"
export MACHINE_ROLE="${MACHINE_ROLE:-laptop}"
INIT_LINKS_ONLY="${INIT_LINKS_ONLY:-0}"

case $MACHINE_ROLE in
    desktop|laptop) ;;
    *) print -u2 "init: MACHINE_ROLE must be desktop or laptop (got '$MACHINE_ROLE')"; exit 2 ;;
esac

typeset -a failed_steps
run_step() {
    local step="$1" desc="$2"
    print "==> ${step:t}: $desc"
    ( source "$step" )
    local rc=$?
    if (( rc != 0 )); then
        print -u2 "!!  ${step:t} failed (exit $rc) -- continuing with the next step"
        failed_steps+=("${step:t}")
    fi
}

print "init: role=$MACHINE_ROLE  repo=$ENV_DIR  links-only=$INIT_LINKS_ONLY"

run_step "$ENV_DIR/init/fs.zsh"   "base directories"
run_step "$ENV_DIR/init/role.zsh" "link machine-role.env for $MACHINE_ROLE"

if [[ $INIT_LINKS_ONLY == 0 ]]; then
    run_step "$ENV_DIR/init/pacman.zsh"   "pacman.conf, git, yay, update, shared + $MACHINE_ROLE packages"
    run_step "$ENV_DIR/init/gh-login.zsh" "GitHub CLI login (device code; only prompts when logged out)"
    run_step "$ENV_DIR/init/antidote.zsh" "antidote zsh plugin manager"
    run_step "$ENV_DIR/init/node.zsh"     "node via nvm"
fi

run_step "$ENV_DIR/init/links.zsh"  "symlink ~/bin, zsh files, ~/env, i3, kitty, ~/.xprofile"
run_step "$ENV_DIR/init/claude.zsh" "Claude config, skills, marketplace paths"

if [[ $INIT_LINKS_ONLY == 0 ]]; then
    run_step "$ENV_DIR/init/marketplaces.zsh" "clone local Claude plugin marketplaces"
fi

run_step "$ENV_DIR/init/git.zsh" "wire git helper scripts into git"

if [[ $INIT_LINKS_ONLY == 0 ]]; then
    run_step "$ENV_DIR/init/shell.zsh"       "make zsh the login shell"
    run_step "$ENV_DIR/init/spotify-mcp.zsh" "Spotify MCP server (shared by both roles)"
fi

# Role hook last: whatever only this machine needs (desktop: LightDM greeter
# drop-in; laptop: nothing yet). Also runs in links-only mode, so keep hooks
# idempotent.
run_step "$ENV_DIR/machines/$MACHINE_ROLE/init.zsh" "$MACHINE_ROLE-only setup"

print
if (( ${#failed_steps} )); then
    print -u2 "init finished with failures in: ${(j:, :)failed_steps}"
    exit 1
fi
print "init finished: all steps succeeded"
