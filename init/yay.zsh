#!/usr/bin/zsh

# Bootstrap the yay AUR helper. No-op if yay is already installed, and safe to
# re-run (won't re-clone over an existing checkout).

if ! command -v yay &> /dev/null; then
    cd ~/src
    [[ -d yay ]] || sudo git clone https://aur.archlinux.org/yay.git
    sudo chown -R "$USER:$USER" ./yay
    cd yay
    makepkg -si --noconfirm
fi
