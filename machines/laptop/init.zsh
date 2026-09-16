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
