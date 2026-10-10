#!/usr/bin/zsh

# Desktop-only init, sourced last by init/init.zsh when MACHINE_ROLE=desktop
# (also in --links-only mode, so keep everything here idempotent).
#
# Headless Obsidian + Claude remote-control: the helper scripts are in
# machines/desktop/bin (config/zsh/env/path.zsh puts it on PATH), and the
# login-time Xvfb/Obsidian startup has its home in machines/desktop/xprofile.sh
# (sourced by config/.xprofile) -- but that fragment is still a placeholder
# until the desktop's hand-written ~/.xprofile (or ~/.xprofile.bak once init
# has run) is pasted into it. The systemd user unit is not in the repo yet.

source "${ENV_DIR:-$HOME/src/env}/init/lib.zsh"

# LightDM drop-in: force the greeter (login screen) to 1080p on HDMI-3 -- see
# machines/desktop/lightdm.conf.d/50-resolution.conf. LightDM reads every
# *.conf in /etc/lightdm/lightdm.conf.d/, so our drop-in sits alongside whatever
# the package ships. Like pacman.conf, the symlink points back into this repo so
# edits here take effect without re-copying.
sudo_link_path "$ENV_DIR/machines/desktop/lightdm.conf.d/50-resolution.conf" \
    /etc/lightdm/lightdm.conf.d/50-resolution.conf || return 1

# Local LLM server: ollama-cuda (machines/desktop/packages.txt) ships
# ollama.service but leaves it disabled. Our drop-in keeps models loaded and
# preloads the big Gemma at every service start, so it is loaded at boot with
# nobody logged in. The drop-in is COPIED (sudo_install_file), not linked:
# /home is its own mount and systemd reads drop-ins before it mounts.
# Skipped when the unit is missing -- e.g. --links-only on a box that never
# ran the package step.
if systemctl cat ollama.service &>/dev/null; then
    sudo_install_file "$ENV_DIR/machines/desktop/systemd/ollama.service.d/10-gemma.conf" \
        /etc/systemd/system/ollama.service.d/10-gemma.conf || return 1
    # restart/enable block until the drop-in's preload has loaded the model.
    # Enable only when not already enabled and active, so a re-run with nothing
    # changed never asks for a sudo password.
    local restart=0 enable=0
    [[ $REPLY == installed ]] && restart=1
    systemctl is-enabled --quiet ollama.service && systemctl is-active --quiet ollama.service || enable=1
    (( restart || enable )) && print "    loading gemma3:12b into ollama (can take a few minutes)..."
    if (( restart )); then
        if ! { sudo systemctl daemon-reload && sudo systemctl try-restart ollama.service }; then
            print -u2 "    FAILED to reload/restart ollama.service"
            return 1
        fi
    fi
    if (( enable )) && ! sudo systemctl enable --now ollama.service; then
        print -u2 "    FAILED to enable ollama.service"
        return 1
    fi

    # Pulling is ~11 GB of network, which --links-only (this hook runs there
    # too) must not do -- so only remind.
    local -a pulled=( ${(f)"$(ollama list 2>/dev/null | awk 'NR > 1 { print $1 }')"} )
    local model
    for model in gemma3:12b gemma3:4b; do
        (( ${pulled[(Ie)$model]} )) || print "    $model not pulled -- run: ollama pull $model"
    done
else
    print "    ollama.service not installed (ollama-cuda missing?) -- skipping"
fi

# While a gamescope session runs, swap the "gemma" alias to the small model so
# games get the VRAM (machines/desktop/bin/gemma-swap). A user unit, so a link
# is fine: the user manager starts after /home is mounted.
link_path "$ENV_DIR/machines/desktop/systemd/user/gemma-gaming.service" \
    "$HOME/.config/systemd/user/gemma-gaming.service" || return 1
if ! { systemctl --user daemon-reload && systemctl --user enable gemma-gaming.service }; then
    print -u2 "    FAILED to enable gemma-gaming.service"
    return 1
fi
