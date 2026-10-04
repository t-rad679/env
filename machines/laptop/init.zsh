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
fi
