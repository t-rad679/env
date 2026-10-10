#!/usr/bin/zsh

# Spellbook-only init, sourced last by init/init.zsh when MACHINE_ROLE=spellbook
# (also in --links-only mode, so keep everything here idempotent).
#
# Display profiles themselves are files, not setup: machines/spellbook/autorandr/
# is linked to ~/.config/autorandr by init/links.zsh, and the login-time
# `autorandr --change` lives in machines/spellbook/xprofile.sh. What is left here
# is the root-owned half -- the systemd side of dock/undock switching.

source "${ENV_DIR:-$HOME/src/env}/init/lib.zsh"

# Fallback-profile drop-in for the packaged autorandr.service. See the file
# itself for why: the package hardcodes `--default default` and our panel-only
# profile is named "undocked". Same pattern as the desktop's LightDM drop-in --
# the symlink points back into the repo so edits take effect without copying.
sudo_link_path "$ENV_DIR/machines/spellbook/systemd/autorandr.service.d/10-default-profile.conf" \
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

# Backlight keys (F7/F8 in i3/spellbook.conf) write to /sys/class/backlight, which
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
# Spellbook-only for now. The desktop still boots LightDM with its HDMI-3 greeter
# drop-in, and both want to own display-manager.service, so this cannot move to
# a shared init step until that machine moves too. See
# machines/spellbook/greetd/config.toml.
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
    sudo_link_path "$ENV_DIR/machines/spellbook/greetd/config.toml" /etc/greetd/config.toml

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
    local xsession_src="$ENV_DIR/machines/spellbook/xsessions/i3-xprofile.desktop"
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

# --- Noctalia battery plugins --------------------------------------------
#
# Two community plugins, both spellbook-only for the same reason as the rest of
# the niri/Noctalia block in packages.txt -- the desktop has no battery and no
# Noctalia:
#
#   piero-93/battery-power-management  "Battery & Power Management". A BAR
#       widget (charge %, live watts, active power profile) plus a panel that
#       switches the profile and, on hardware exposing
#       charge_control_end_threshold, caps charging. This Framework 16 does
#       NOT expose that attribute, so the charge-limit slider is inert here --
#       which is why init never runs the plugin's bundled
#       setup-threshold-permissions.sh: it would create a battery_ctl group
#       and a udev rule to grant write access to a file that does not exist.
#   yocraft/battery-widget             "Battery Widget". The same numbers as a
#       DESKTOP and lockscreen widget rather than a bar one.
#
# Nothing is downloaded here. Noctalia ships the official and community plugin
# repos as config defaults, keeps their git mirrors under
# ~/.local/state/noctalia/plugins/sources/, and materializes a plugin out of
# the mirror the first time it is enabled -- so "installing" one is exactly
# "putting its id in the enabled list", and the default `auto_update = "all"`
# keeps it current afterwards.
if [[ ! -x /usr/bin/noctalia ]]; then
    print "    noctalia not installed -- skipping the battery plugin setup"
else
    # powerprofilesctl is a soft dependency: the plugin probes for it at load
    # and hides the profile switch when it is absent, so a missing one is a
    # quietly reduced widget rather than a failure. Hence a warning, not a
    # return -- and the pacman line rather than a `yay -S`, because swapping
    # tuned-ppd out is a decision, not a dependency fix (see packages.txt).
    if ! command -v powerprofilesctl >/dev/null 2>&1; then
        print -u2 "    WARNING: powerprofilesctl is missing, so Battery & Power"
        print -u2 "    Management will show the battery but no profile switch."
        print -u2 "    It ships with power-profiles-daemon, which conflicts with"
        print -u2 "    tuned-ppd:"
        print -u2 "        sudo pacman -S power-profiles-daemon"
    elif ! systemctl is-enabled power-profiles-daemon.service >/dev/null 2>&1; then
        # Unlike gnome-keyring next door, this one is not D-Bus activated into
        # the user session -- it is a system service, and powerprofilesctl just
        # errors out when nothing owns net.hadess.PowerProfiles.
        sudo systemctl enable --now power-profiles-daemon.service || return 1
        print "    enabled power-profiles-daemon"
    fi

    # The plugin's battery_device setting has a hard default of "BAT0" and no
    # autodetection, and this machine's battery is BAT1 -- so a plugin left at
    # its default reads a sysfs path that is not there and shows nothing. Take
    # the first BAT* the kernel exposes; (N) so the glob vanishing on a
    # desktop-shaped machine is an empty array rather than an error.
    local -a batteries=( /sys/class/power_supply/BAT*(N) )
    local battery="${batteries[1]:t}"
    : "${battery:=BAT0}"

    # settings.toml is Noctalia's own state file, rewritten wholesale by the
    # shell every time anything changes in its settings UI, and it is
    # deliberately NOT tracked in this repo -- the same call greeter.toml gets
    # above, for stronger reasons: it holds absolute $HOME paths (so two
    # machines with different usernames could never share one), the hand-tuned
    # bar order, the calendar accounts, and a lockscreen widget layout keyed on
    # this dock's monitor names.
    #
    # So this sets the two keys it needs and leaves the rest of the file byte
    # for byte, via noctalia-settings-ensure.awk. On a machine that has never
    # started Noctalia the file does not exist yet, and that is fine: a
    # settings.toml holding nothing but these keys is valid, because Noctalia
    # merges it over its defaults and fills the rest in on its first save.
    #
    # `noctalia msg plugins enable` is the supported way to do this and is not
    # usable here -- it is IPC to a running shell, and on a new spellbook init
    # finishes before anything has ever logged into niri.
    local settings="${XDG_STATE_HOME:-$HOME/.local/state}/noctalia/settings.toml"
    local ensure="$ENV_DIR/machines/spellbook/noctalia-settings-ensure.awk"
    local plugins='yocraft/battery-widget,piero-93/battery-power-management'

    if ! mkdir -p "${settings:h}"; then
        print -u2 "    FAILED to create ${settings:h}"
        return 1
    fi

    # Both temporaries live beside the target so the install is a rename on the
    # same filesystem: a settings.toml truncated half-way through would cost
    # the whole shell configuration.
    local a b
    a="$(mktemp "${settings}.XXXXXX")" || return 1
    b="$(mktemp "${settings}.XXXXXX")" || { rm -f "$a"; return 1; }

    {
        [[ -f $settings ]] && cat "$settings" > "$a"
        awk -f "$ensure" -v section='[plugins]' -v key=enabled -v mode=union \
            -v value="$plugins" "$a" > "$b" &&
        awk -f "$ensure" -v section="[plugin_settings.\"piero-93/battery-power-management\"]" \
            -v key=battery_device -v mode=default -v value="$battery" "$b" > "$a"
    } || {
        print -u2 "    FAILED to rewrite $settings"
        rm -f "$a" "$b"
        return 1
    }
    # Compare against a newline-normalized copy rather than the file itself.
    # awk always terminates its last line and Noctalia writes settings.toml
    # without a trailing newline, so a straight cmp would call every run a
    # change and reload the shell's config for nothing.
    if [[ -f $settings ]]; then
        awk '{ print }' "$settings" > "$b"
    else
        : > "$b"
    fi

    local unchanged=0
    cmp -s "$a" "$b" && unchanged=1
    rm -f "$b"

    if (( unchanged )); then
        rm -f "$a"
        print "    Noctalia battery plugins already enabled (battery $battery)"
    elif ! noctalia config validate "$a" >/dev/null 2>&1; then
        # Never install a settings.toml Noctalia cannot parse: it rejects the
        # whole file, which means a login with no bar and no launcher.
        print -u2 "    FAILED: the generated settings.toml does not validate;"
        print -u2 "    left it at $a and changed nothing"
        return 1
    elif mv "$a" "$settings"; then
        print "    enabled the Noctalia battery plugins (battery $battery)"
        # Only matters when init is run from inside a live niri session; the
        # file watcher would catch it anyway, so a failure here is not one.
        noctalia msg config-reload >/dev/null 2>&1
        # Deliberately not placed for you. Which widgets sit where is bar and
        # desktop-widget layout -- GUI-managed state in the same file, keyed on
        # this dock's monitors -- so init enabling a plugin and then also
        # rearranging the bar would overwrite a hand-tuned list on every run.
        print "    Bar: add 'Battery & Power Management' from the bar's widget picker"
        print "    Desktop/lockscreen: noctalia msg desktop-widgets-edit"
    else
        print -u2 "    FAILED to install $settings"
        rm -f "$a"
        return 1
    fi
fi
