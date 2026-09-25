# Laptop-only ~/.xprofile fragment. Sourced (not executed) by config/.xprofile
# after it exports MACHINE_ROLE, so everything here runs in LightDM's login
# session before i3 starts and is inherited by i3 and every program it
# launches.
#
# POSIX sh, not zsh, on purpose: LightDM runs ~/.xprofile with sh, and this
# file is sourced into that same shell. It is the same deliberate exception to
# the zsh-only rule as config/.xprofile itself. No shebang because it is a
# fragment meant to be sourced, never run.

# Apply the display profile matching whatever monitors are attached right now
# (profiles: machines/laptop/autorandr/, linked to ~/.config/autorandr).
#
# This is the BOOT path only. Dock/undock while logged in is handled by the
# udev rule + systemd units the autorandr package ships, which run
# `autorandr --change` on hotplug. But at login nothing has hotplugged, so
# without this line X keeps the layout it guessed on startup: the laptop panel
# on, and any dock monitor left "connected but disabled".
#
# That half-state is the bug this whole setup exists to prevent -- a disabled
# but connected DP connector makes amdgpu fire a hotplug IRQ every few
# seconds, X re-probes on each one, i3 rebuilds its bar, and every window
# resizes twice a second.
#
# --default horizontal: if no profile fingerprint matches (a monitor we have
# never saved a profile for, or one of the pair failing to enumerate), lay the
# connected outputs out side by side rather than leaving the guessed layout in
# place. "horizontal" is an autorandr virtual profile, so it needs no saved
# fingerprint.
#
# NOT --default undocked, which is what this used to be: "undocked" sets every
# DisplayPort `off`, which on a connected monitor is precisely the
# connected-but-disabled half-state described above. Falling back to it blanked
# a working monitor and started the IRQ storm. See the same reasoning in
# machines/laptop/systemd/autorandr.service.d/10-default-profile.conf.
#
# Guarded on the binary existing so a laptop provisioned before
# `init/pacman.zsh` has run still logs in cleanly.
if command -v autorandr >/dev/null 2>&1; then
    autorandr --change --default horizontal
fi

# Tell i3 which connector the Samsung is on this boot, before i3 starts and
# reads its config (the `workspace 2 output` / `workspace 4 output` rules in
# machines/laptop/i3/laptop.conf). Not left to the autorandr postswitch hook:
# autorandr skips hooks when the matching profile is already applied, which is
# common at login. Guarded like the line above.
if [ -x "$HOME/src/env/machines/laptop/bin/samsung-output" ]; then
    "$HOME/src/env/machines/laptop/bin/samsung-output"
fi
