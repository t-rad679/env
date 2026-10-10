#!/usr/bin/zsh

# Laptop-only init, sourced last by init/init.zsh when MACHINE_ROLE=laptop
# (also in --links-only mode, so keep everything here idempotent).
#
# Display profiles themselves are files, not setup: machines/laptop/autorandr/
# is linked to ~/.config/autorandr by init/links.zsh, and the login-time
# `autorandr --change` lives in machines/laptop/xprofile.sh. What is left here
# is the root-owned half -- the systemd side of dock/undock switching.

source "${ENV_DIR:-$HOME/src/env}/init/lib.zsh"

# Fallback-profile drop-in for the packaged autorandr.service. See the file
# itself for why: the package hardcodes `--default default` and our panel-only
# profile is named "undocked". Same pattern as the desktop's LightDM drop-in --
# the symlink points back into the repo so edits take effect without copying.
sudo_link_path "$ENV_DIR/machines/laptop/systemd/autorandr.service.d/10-default-profile.conf" \
    /etc/systemd/system/autorandr.service.d/10-default-profile.conf
sudo systemctl daemon-reload

# Dock/undock while logged in already works without this: the udev rule the
# package ships (/usr/lib/udev/rules.d/40-monitor-hotplug.rules) runs
# `systemctl start autorandr.service` on every DRM change, and starting a unit
# does not require it to be enabled.
#
# Enabling it is for the OTHER trigger: autorandr.service is WantedBy=sleep.target,
# so this is what re-applies the right profile on resume. That matters on this
# machine -- docking and then resuming is what started the whole hotplug-storm
# investigation, because the dock comes back before X re-checks its outputs.
sudo systemctl enable autorandr.service

# Backlight keys (F7/F8 in i3/laptop.conf) write to /sys/class/backlight, which
# is root-owned. brightnessctl ships a udev rule granting the video group write
# access there, so membership in that group is the whole permission story --
# without it the keys bind fine and then silently do nothing, which is a
# miserable thing to debug.
#
# usermod -aG is additive, but run it only when needed so re-runs stay quiet.
# The new group doesn't apply to the session that ran this: it's granted at
# login, so it takes a logout (or a reboot) to take effect.
local -a user_groups=( ${=$(id -nG "$USER")} )
if (( ${user_groups[(I)video]} )); then
    print "    $USER is already in the video group"
elif sudo usermod -aG video "$USER"; then
    print "    added $USER to the video group -- log out and back in for it to apply"
else
    print -u2 "    FAILED to add $USER to the video group (brightness keys will no-op)"
    return 1
fi

# --- greetd + Noctalia Greeter -------------------------------------------
#
# The login screen. greetd owns the VT and runs one greeter;
# noctalia-greeter is that greeter, and it offers a session picker listing
# everything in /usr/share/wayland-sessions (niri) and /usr/share/xsessions
# (i3), so this does not commit the machine to niri -- it only changes what
# asks for the password.
#
# Laptop-only for now. The desktop still boots LightDM with its HDMI-3 greeter
# drop-in, and both want to own display-manager.service, so this cannot move to
# a shared init step until that machine moves too. See
# machines/laptop/greetd/config.toml.
#
# Skipped entirely when the greeter is not installed, so --links-only (which
# skips init/pacman.zsh) does not try to switch the login manager on a machine
# that has nothing to switch to.
if [[ ! -x /usr/bin/noctalia-greeter-session ]]; then
    print "    noctalia-greeter not installed -- skipping the greetd setup"
else
    # The config first: the greeter's own system setup below shells out to
    # `noctalia-greeter-apply-appearance --print-greeter-user`, which reads
    # /etc/greetd/config.toml to find out which user to chown its state dir to.
    # Run in the other order it falls back to a guess.
    sudo_link_path "$ENV_DIR/machines/laptop/greetd/config.toml" /etc/greetd/config.toml

    # Creates /var/lib/noctalia-greeter/{greeter,sync}.toml owned by the greetd
    # user, and adds a pam_systemd.so session line to /etc/pam.d/greetd if the
    # distro's file lacks one (Arch's has it, so this is a no-op here). Both
    # halves are idempotent and the script backs up anything it edits.
    #
    # greeter.toml is deliberately NOT linked from this repo. It is the
    # declarative appearance file, but it shares a directory with sync.toml,
    # which the greeter itself writes (last session used, wallpaper and
    # palette pushed over from the shell by `noctalia msg greeter-sync`) -- so
    # the directory is state, not config.
    sudo /usr/share/noctalia-greeter/setup_greeter_system.sh >/dev/null || {
        print -u2 "    FAILED: /usr/share/noctalia-greeter/setup_greeter_system.sh"
        return 1
    }
    print "    noctalia-greeter system state prepared"

    # The greeter runs as an unprivileged user that has to open the DRM device
    # itself -- it is a Wayland compositor, not an X client. The package's
    # post-install puts it in the video group; check rather than assume,
    # because the symptom of it missing is a black screen at boot with the
    # real error only in `journalctl -u greetd`.
    local greeter_user
    greeter_user="$(sed -n 's/^[[:space:]]*user[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' \
        /etc/greetd/config.toml | tail -1)"
    : "${greeter_user:=greeter}"
    if ! id -nG "$greeter_user" 2>/dev/null | grep -qw video; then
        print -u2 "    WARNING: user '$greeter_user' is not in the video group;"
        print -u2 "    the greeter will fail to open the display. Fix with:"
        print -u2 "        sudo usermod -aG video $greeter_user"
    fi

    # Hand display-manager.service over from LightDM. Both units carry
    # `Alias=display-manager.service`, and systemd refuses to enable the second
    # one while the first still holds the alias -- so the disable is not
    # optional, and the order matters.
    #
    # LightDM is left installed on purpose: `sudo systemctl disable --now
    # greetd && sudo systemctl enable --now lightdm` from a text console
    # (Ctrl+Alt+F2) is the way back if the greeter does not come up.
    if systemctl is-enabled lightdm.service >/dev/null 2>&1; then
        sudo systemctl disable lightdm.service || return 1
        print "    disabled lightdm (still installed -- it is the fallback)"
    fi
    if ! systemctl is-enabled greetd.service >/dev/null 2>&1; then
        sudo systemctl enable greetd.service || return 1
        print "    enabled greetd -- takes effect at the next boot"
    fi

    # --- the i3-with-xprofile session entry ------------------------------
    #
    # Picking the stock "i3" from the greeter starts an i3 that never sourced
    # ~/.xprofile, because greetd runs X sessions with `startx <wm>` and
    # startx reads ~/.xinitrc only when given no client. bin/i3-xsession is
    # the wrapper that puts it back; see that file for everything it fixes.
    #
    # The wrapper is a symlink into the repo, so edits take effect at once.
    # That is safe for the Exec target specifically: it runs after
    # authentication, as the logging-in user, who can obviously read their own
    # $HOME.
    sudo_link_path "$ENV_DIR/bin/i3-xsession" /usr/local/bin/i3-xsession

    # The .desktop, by contrast, is COPIED. The greeter parses it as the
    # unprivileged `greeter` user, and $HOME is drwx------ -- a symlink into
    # ~/src/env is unreadable to that user, so the entry would simply not
    # appear in the picker, with nothing in the log to say why. Copying is the
    # same concession links.zsh makes for the claude-cli:// URL handler, for a
    # different reason.
    #
    # /usr/local/share is first in the XDG_DATA_DIRS default that
    # noctalia-greeter compiles in ("/usr/local/share:/usr/share"), so no
    # further configuration is needed. `cmp` first so a re-run is silent
    # rather than touching the file's mtime every time.
    local xsession_src="$ENV_DIR/machines/laptop/xsessions/i3-xprofile.desktop"
    local xsession_dest=/usr/local/share/xsessions/i3-xprofile.desktop
    if ! sudo cmp -s "$xsession_src" "$xsession_dest" 2>/dev/null; then
        if sudo install -D -m 0644 "$xsession_src" "$xsession_dest"; then
            print "    installed $xsession_dest (a copy -- the greeter cannot read \$HOME)"
        else
            print -u2 "    FAILED to install $xsession_dest"
            return 1
        fi
    fi

    # `noctalia-greeter sessions` prints the picker's list exactly as the
    # greeter builds it, so it is the one-command check that the entry landed.
    # It de-duplicates by Name=, which is why this entry is "i3 (xprofile)"
    # and not a second "i3".
    if ! noctalia-greeter sessions 2>/dev/null | grep -qx 'i3 (xprofile)'; then
        print -u2 "    WARNING: the greeter does not list 'i3 (xprofile)'."
        print -u2 "    Check with: noctalia-greeter sessions"
    fi
fi

# --- gnome-keyring auto-unlock -------------------------------------------
#
# The Secret Service provider (see packages.txt). The daemon needs no starting
# -- D-Bus activates it on the first request -- so all that is left is the
# unlocking, which is pure PAM.
#
# Without these lines the keyring is created with a password of its own and
# gcr-prompter asks for it once per login, which is the thing worth avoiding:
# Noctalia reads its calendar token at startup, so the prompt lands on top of
# the bar every single time you log in.
#
# Guarded on the module rather than on `pacman -Q`, because the module file is
# the thing the PAM lines actually reference -- and because that keeps
# --links-only from editing the login stack on a machine where the package was
# never installed.
if [[ ! -e /usr/lib/security/pam_gnome_keyring.so ]]; then
    print "    gnome-keyring not installed -- skipping the keyring PAM setup"
else
    # Both lines are `optional` on purpose, and not only for style: PAM
    # ignores an optional module that fails *or* cannot be loaded at all, so a
    # gnome-keyring that is removed or renamed out from under this file
    # degrades to "the keyring does not unlock" instead of "the greeter does
    # not accept the password". `required` here would be a lockout waiting for
    # a package rename.
    #
    # The auth line has to come AFTER `auth include system-local-login`: that
    # include is what prompts for and collects the password, and
    # pam_gnome_keyring reads it from the PAM auth token the earlier modules
    # left behind. Placed before it there is nothing to read and the keyring
    # stays locked, silently.
    sudo_pam_add_line /etc/pam.d/greetd \
        'auth       optional     pam_gnome_keyring.so' \
        '^[[:space:]]*auth[[:space:]]+include[[:space:]]+system-local-login' || return 1

    # auto_start makes the session phase start the daemon itself rather than
    # waiting for D-Bus activation, which is what gets the keyring unlocked
    # before the first client asks instead of after. Appended, so it lands
    # after pam_systemd.so -- the session needs its XDG runtime dir first.
    sudo_pam_add_line /etc/pam.d/greetd \
        'session    optional     pam_gnome_keyring.so auto_start' || return 1

    # And the easily-forgotten third one. The keyring is encrypted with the
    # login password, but nothing tells it when that password changes -- so
    # without this, the next `passwd` leaves a keyring that the new password no
    # longer opens, and auto-unlock just quietly stops working. /etc/pam.d/passwd
    # is shipped by pambase, not greetd, so this half is role-neutral and moves
    # to a shared step whenever the desktop gets a keyring too.
    sudo_pam_add_line /etc/pam.d/passwd \
        'password   optional     pam_gnome_keyring.so' || return 1

    # pam_gnome_keyring unlocks the keyring named `login`, and only that one.
    # A keyring created interactively before this was wired up is called
    # `Default_Keyring` and has its own password, and because it also owns the
    # `default` alias the PAM lines above can be correct and still do nothing.
    # There is no way to re-key it from here -- it has to be deleted and
    # recreated -- so this only warns.
    #
    # The test is deliberately "the file exists AND names something else", not
    # "the file says login": with only a login keyring the `default` file is
    # normally ABSENT, because nothing ever set the alias explicitly and
    # gnome-keyring resolves `default` to `login` on its own. Warning on
    # absence would fire on every correctly-configured machine.
    local default_keyring="$HOME/.local/share/keyrings/default"
    if [[ -r "$default_keyring" && "$(<$default_keyring)" != "login" ]]; then
        print -u2 "    WARNING: the default keyring is '$(<$default_keyring)', not 'login';"
        print -u2 "    pam_gnome_keyring only unlocks 'login', so it will still prompt."
        print -u2 "    To migrate (loses stored secrets -- Noctalia and Chrome re-create theirs):"
        print -u2 "        rm ~/.local/share/keyrings/default ~/.local/share/keyrings/Default_*.keyring"
        print -u2 "        systemctl --user restart gnome-keyring-daemon.service"
        print -u2 "    then log out and back in. The restart is not optional: the"
        print -u2 "    running daemon keeps serving a deleted keyring from memory."
    fi
fi
