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
