#!/usr/bin/zsh

# Tint the terminal for as long as an outbound ssh session is up, so a remote
# shell never looks like a local one.
#
# Why a shell wrapper rather than terminal config: the background colour
# belongs to kitty (config/kitty/kitty.conf paints the Skylight indigo), and
# kitty has no idea what is running inside it. The shell is the only thing
# that knows an ssh just started.
#
# Why the Skylight colour does NOT come from zsh in the first place: ~/.zshrc
# is this same repo on both machines. A shell that painted its own background
# would paint it again on the far side of an ssh, so the remote would come up
# Skylight-blue and the tint would be pointless. kitty.conf is read only by the
# terminal in front of you.
#
# OSC 11 sets the background; OSC 111 resets it to whatever the terminal was
# configured with. Resetting rather than setting #161A31 back means this file
# can never drift out of sync with the theme. Terminals that do not understand
# either sequence ignore them.

# Oxblood: dark enough for the Skylight foreground to stay readable, far enough
# from indigo to be unmistakable at a glance. Override it from
# ~/.config/env-secrets.zsh or any later env script if you want a different one.
typeset -g SSH_TINT_BG="${SSH_TINT_BG:-#2A1518}"

_ssh_tint_supported() {
    # Only talk to a terminal we are actually attached to. This also means
    # `ssh host cat file > out` and friends are left alone.
    [[ -t 1 ]] || return 1

    case $TERM in
        (''|dumb|linux|vt100) return 1 ;;
    esac

    # Already inside an ssh session, so the tint belongs to the terminal at the
    # far end of someone else's connection. Restoring it when a nested hop
    # exits would hand the outer session back its Skylight blue while still
    # remote, which is the one state this is meant to make impossible.
    [[ -z $SSH_CONNECTION ]]
}

ssh() {
    _ssh_tint_supported || { command ssh "$@"; return $? }

    local ret=0
    printf '\e]11;%s\a' "$SSH_TINT_BG"

    # An `always` block, not a plain trailing command: it runs on Ctrl-C and on
    # a dropped connection as well as a clean exit, so the terminal cannot get
    # stranded oxblood.
    {
        command ssh "$@" || ret=$?
    } always {
        printf '\e]111\a'
    }

    return $ret
}
