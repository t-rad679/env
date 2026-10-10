#!/usr/bin/zsh

# Install the login-screen avatar -- the picture shown above the username in
# the greeter, in place of the generic person glyph.
#
# There is no greeter setting for this. noctalia-greeter (and lightdm-gtk-
# greeter, and every other greeter that shows faces) asks AccountsService over
# D-Bus for the user's `IconFile` property and renders whatever image it points
# at. With nothing set, AccountsService answers `$HOME/.face`, which does not
# exist here -- hence the fallback glyph.
#
# `$HOME/.face` is the wrong place to fix that: $HOME is 0700, and the greeter
# runs as the unprivileged `greeter` user, which cannot traverse into it. (Same
# trap as the `i3 (xprofile)` .desktop entry, which is copied into
# /usr/local/share/xsessions for exactly this reason.) So the image has to be a
# real copy outside $HOME, not a symlink back into it.
#
# AccountsService already does precisely that: SetIconFile copies the file --
# as root, so it can read out of $HOME at install time -- into
# /var/lib/AccountsService/icons/<user> (0644 in a world-readable directory,
# so the greeter can read it) and persists `Icon=` in its own user file. That
# is the supported API, and it means this step never hand-edits
# /var/lib/AccountsService/users/<user> underneath the running daemon.
#
# Polkit's `org.freedesktop.accounts.change-own-user-data` is allow_active=yes,
# so this needs no sudo when run from a logged-in session.

source "${ENV_DIR:-$HOME/src/env}/init/lib.zsh"

# Committed, so a fresh machine gets the face without any manual step. The
# daemon does the reading as root, so a source inside a 0700 $HOME is fine --
# it is only the installed *copy* that has to live where `greeter` can read it.
# Replace this file to change the picture: square, ~512px, PNG -- the greeter
# decodes PNG/JPEG/WebP/SVG but rejects progressive JPEGs, and AccountsService
# caps the icon at 1 MiB.
AVATAR="$ENV_DIR/config/avatar.png"
INSTALLED="/var/lib/AccountsService/icons/$USER"

# Only reachable if the picture was deleted from the repo on purpose.
if [[ ! -f $AVATAR ]]; then
    print "    no $AVATAR -- skipping (greeter keeps the default person glyph)"
    return 0
fi

if ! command -v busctl >/dev/null; then
    print -u2 "    FAILED to set the greeter avatar: busctl not found (systemd?)"
    return 1
fi

# Idempotent: the installed copy is world-readable, so this needs no privileges.
if [[ -f $INSTALLED ]] && cmp -s "$AVATAR" "$INSTALLED"; then
    print "    greeter avatar already up to date ($INSTALLED)"
    return 0
fi

OBJ=$(busctl --system call org.freedesktop.Accounts /org/freedesktop/Accounts \
        org.freedesktop.Accounts FindUserByName s "$USER" 2>&1) || {
    print -u2 "    FAILED to reach AccountsService: $OBJ"
    print -u2 "    (is accountsservice installed and accounts-daemon running?)"
    return 1
}
OBJ=${${OBJ#o }//\"/}

OUT=$(busctl --system call org.freedesktop.Accounts "$OBJ" \
        org.freedesktop.Accounts.User SetIconFile s "$AVATAR" 2>&1) || {
    print -u2 "    FAILED to set the greeter avatar: $OUT"
    return 1
}

print "    greeter avatar set from $AVATAR -> $INSTALLED"
