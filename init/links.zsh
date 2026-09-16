#!/usr/bin/zsh

# Symlink my dotfiles into place. Idempotent; real files that are in the way
# are backed up once (see init/lib.zsh for the exact rules).
#
# ~/bin is deliberately NOT linked: it stays the user's own directory of
# hand-written scripts. The repo's bin/ is put on PATH directly by
# config/zsh/env/path.zsh instead.

source "${ENV_DIR:-$HOME/src/env}/init/lib.zsh"

# Every link is attempted even if an earlier one fails; the step's exit status
# reports whether any of them failed.
rc=0

# Main zshrc + the antidote plugin list it loads (`antidote load` reads
# ~/.zsh_plugins.txt).
link_path "$ENV_DIR/config/zsh/.zshrc" "$HOME/.zshrc" || rc=1
link_path "$ENV_DIR/config/zsh/.zsh_plugins.txt" "$HOME/.zsh_plugins.txt" || rc=1

# Env scripts -> ~/env. The zshrc sets ZSH_CUSTOM=~/env and sources ~/env/*.zsh
# (alphabetical order). Symlink the whole directory.
link_path "$ENV_DIR/config/zsh/env" "$HOME/env" || rc=1

# i3: the whole ~/.config/i3 directory is the repo's config/i3, so the
# `include conf.d/*.conf` in config/i3/config resolves no matter how i3
# resolves relative includes through a symlink. Role-specific i3 config is
# pulled in by config/i3/config via $MACHINE_ROLE (see machines/<role>/i3/).
link_path "$ENV_DIR/config/i3" "$HOME/.config/i3" || rc=1

# kitty terminal config (font, etc).
link_path "$ENV_DIR/config/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf" || rc=1

# autorandr display profiles, per role. Only the laptop has a set (it docks);
# the desktop's single monitor needs no profile at all, so the link is skipped
# when the role ships no autorandr/ directory rather than dangling.
#
# The whole directory is linked (like i3 above) because autorandr writes into
# it: `autorandr --save <name>` creates ~/.config/autorandr/<name>/, which
# lands in the repo and shows up in `git status` ready to commit.
if [[ -d "$ENV_DIR/machines/$MACHINE_ROLE/autorandr" ]]; then
    link_path "$ENV_DIR/machines/$MACHINE_ROLE/autorandr" "$HOME/.config/autorandr" || rc=1
fi

# ~/.xprofile: sourced by LightDM before i3 starts; exports MACHINE_ROLE into
# the X session and sources machines/<role>/xprofile.sh. (POSIX sh, not zsh,
# because LightDM runs it with sh.) A hand-maintained real ~/.xprofile (the
# desktop's starts headless Obsidian under Xvfb) gets backed up by link_path,
# which silently disables whatever it did -- so shout about it first.
if [[ -e $HOME/.xprofile && ! -L $HOME/.xprofile ]]; then
    print -u2 ""
    print -u2 "!!  WARNING: $HOME/.xprofile is a real file, not a link."
    print -u2 "!!  It is being backed up to $HOME/.xprofile.bak and replaced with a link to"
    print -u2 "!!  $ENV_DIR/config/.xprofile, which only exports MACHINE_ROLE and sources"
    print -u2 "!!  $ENV_DIR/machines/$MACHINE_ROLE/xprofile.sh."
    print -u2 "!!  Anything the old file did at login (headless Obsidian / Xvfb for the"
    print -u2 "!!  Obsidian MCP server, etc.) STOPS HAPPENING until you move its contents"
    print -u2 "!!  from $HOME/.xprofile.bak into machines/$MACHINE_ROLE/xprofile.sh."
    print -u2 ""
fi
link_path "$ENV_DIR/config/.xprofile" "$HOME/.xprofile" || rc=1

return $rc
