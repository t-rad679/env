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

# niri: two file links rather than one directory link, which is the opposite
# of i3 above and is forced by how niri resolves `include`.
#
# i3 pulls in its role config with `include .../machines/${MACHINE_ROLE}/i3/*.conf`
# -- wordexp(3) expands the variable and the glob, and an empty match is
# skipped. niri's include does neither: it expands `~` and nothing else, takes
# no globs, and treats a file it cannot read as a parse error that rejects the
# whole config. So the role cannot be named from inside the config file, and
# the indirection moves here instead: config/niri/config.kdl ends with
# `include "~/.config/niri/role.kdl"`, and this is what makes that path mean
# the right role. (Verified that niri resolves the include against the
# symlink's own path rather than canonicalising it first -- but the include is
# spelled absolutely, so it does not depend on that.)
#
# Every role ships a niri/role.kdl, the desktop's comment-only, so the link is
# unconditional: a role without one would be a dangling link and a niri
# session that will not start, which is worth failing loudly over.
link_path "$ENV_DIR/config/niri/config.kdl" "$HOME/.config/niri/config.kdl" || rc=1
link_path "$ENV_DIR/machines/$MACHINE_ROLE/niri/role.kdl" "$HOME/.config/niri/role.kdl" || rc=1

# kitty terminal config (font, etc).
link_path "$ENV_DIR/config/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf" || rc=1

# ssh client config: host aliases only (e.g. `ssh tradical@deepthought`). A
# file link, never the whole ~/.ssh directory -- keys, known_hosts and agent
# sockets are per-machine and must not end up in the repo. ~/.ssh itself is
# created 0700 by init/fs.zsh before this runs; ssh follows the link and only
# requires the target not be group/world-writable, which the repo's 644 isn't.
link_path "$ENV_DIR/config/ssh/config" "$HOME/.ssh/config" || rc=1

# flameshot. The setting that matters is useX11LegacyScreenshot=true.
#
# Flameshot 14 captures through the xdg-desktop-portal Screenshot interface by
# default, and nothing under i3 implements it: the only backend installed is
# xdg-desktop-portal-gtk, whose gtk.portal declares no
# org.freedesktop.impl.portal.Screenshot, and every other backend in the repos
# is a shim over a compositor we do not run (gnome-shell, KWin, wlroots). So
# the D-Bus call is never answered, flameshot gives up after 30s and prints
# "Unable to capture screen" -- i.e. the Print binding in i3/conf.d/fnrow.conf
# does nothing at all. The legacy path is Qt's direct X11 grab; flameshot's own
# help text names i3 as the case for enabling it.
#
# Linked as a whole directory (like autorandr below) rather than as a single
# file: flameshot rewrites flameshot.ini through Qt's QSettings whenever a
# setting changes in its GUI, and that rewrite replaces the file instead of
# writing through the symlink -- so a file link would silently detach from the
# repo the first time a setting is touched.
link_path "$ENV_DIR/config/flameshot" "$HOME/.config/flameshot" || rc=1

# Wallpapers -> ~/pics/wallpapers. The image itself has to be provisioned, not
# just the config that points at it: bin/wallpaper (run from i3's autostart)
# only prints to stderr when the file is missing, so a fresh machine would come
# up with the black root window this was meant to fix.
#
# The whole directory is linked, like i3 above and autorandr below: dropping a
# new image into ~/pics/wallpapers then puts it in the repo, ready to commit,
# instead of leaving it behind on one machine. ~/pics is not created by fs.zsh
# because link_path already mkdir -p's the parent of its destination.
link_path "$ENV_DIR/config/wallpapers" "$HOME/pics/wallpapers" || rc=1

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

# WirePlumber drop-in config, per role. Only the laptop ships one: the CUBILUX
# CA7 USB DAC on its dock needs a rule to be usable at all (ALSA's card profile
# points "Analog Stereo Output" at the wrong PCM device, so the jack stays
# silent -- see the file itself for the full story). Linked as a whole
# directory like autorandr above, and skipped when the role ships no
# wireplumber/ directory rather than dangling.
if [[ -d "$ENV_DIR/machines/$MACHINE_ROLE/wireplumber" ]]; then
    link_path "$ENV_DIR/machines/$MACHINE_ROLE/wireplumber" "$HOME/.config/wireplumber" || rc=1
fi

# Ulauncher shortcuts (keyword -> command/URL entries), per role. Only the
# laptop ships a set -- its "The Grimoire" entry runs a laptop-only script --
# so the link is skipped when the role has no file, leaving that machine's own
# shortcuts.json alone.
#
# A file link, not the whole ~/.config/ulauncher directory: settings.json and
# extensions.json are not tracked. A file link is safe here (unlike
# flameshot's above) because Ulauncher 5 saves shortcuts.json with a plain
# open(path, 'w'), which writes through the symlink rather than replacing it.
#
# Commands in the file use $HOME rather than a literal home path, since the
# two machines have different usernames. That works because Ulauncher writes
# each command into a temporary shell script and runs it, so the shell expands
# it. Ulauncher only reads the file at startup, so restart it after an edit.
if [[ -f "$ENV_DIR/machines/$MACHINE_ROLE/ulauncher/shortcuts.json" ]]; then
    link_path "$ENV_DIR/machines/$MACHINE_ROLE/ulauncher/shortcuts.json" "$HOME/.config/ulauncher/shortcuts.json" || rc=1
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

# The claude-cli:// URL handler, pointed at bin/claude-env so a deep link
# opened from the browser gets the credentials in ~/.config/env-secrets.zsh
# (a .desktop entry is launched by the desktop, not by a shell, so it never
# sources ~/env and mem0 silently records nothing).
#
# Rendered, not linked: a .desktop Exec is not run through a shell, so it
# cannot expand $HOME, and a literal path cannot be committed because the two
# machines have different usernames. Written only when the result differs, so
# re-running init is a no-op rather than a fresh mtime every time.
desktop_src="$ENV_DIR/config/applications/claude-code-url-handler.desktop"
desktop_dest="$HOME/.local/share/applications/claude-code-url-handler.desktop"
if [[ -r "$desktop_src" ]]; then
    rendered="${$(<"$desktop_src")//@ENV_DIR@/$ENV_DIR}"
    if [[ ! -e "$desktop_dest" || "$(<"$desktop_dest")" != "$rendered" ]]; then
        if mkdir -p "${desktop_dest:h}" && print -r -- "$rendered" > "$desktop_dest"; then
            print "rendered $desktop_dest"
        else
            print -u2 "FAILED to render $desktop_dest"
            rc=1
        fi
    fi
fi

return $rc
