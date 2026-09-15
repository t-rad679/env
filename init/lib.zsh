#!/usr/bin/zsh

# Shared helpers for init steps. Every step sources this file.
#
# The linking rules every step follows:
#   * idempotent -- a second run changes nothing;
#   * a pre-existing real file/directory is backed up once, and a later run
#     never overwrites that backup;
#   * an existing symlink is replaced in place (never "linked into"), so
#     re-linking a directory symlink can't create a nested link inside the
#     target;
#   * a failed mutation (mv, rm, mkdir, ln) is reported on stderr and makes
#     the call return non-zero, so the step -- and init's summary -- shows the
#     failure instead of a "linked" line that never happened.

export ENV_DIR="${ENV_DIR:-$HOME/src/env}"

# backup_once PATH
# If PATH is a real (non-symlink) file or directory, move it aside. The first
# backup goes to PATH.bak; if that already exists it is left alone and the new
# backup gets a timestamp suffix instead. Returns non-zero if the move fails.
backup_once() {
    _link_impl_backup "" "$1"
}

# link_path SRC DEST
# Make DEST a symlink to SRC. No-op if it already is. A symlink pointing
# elsewhere (or dangling) is replaced; a real file/dir is backed up first.
# Returns non-zero (after a FAILED line on stderr) if any of that fails.
link_path() {
    _link_impl "" "$1" "$2"
}

# sudo_link_path SRC DEST -- same as link_path, for root-owned targets (/etc).
sudo_link_path() {
    _link_impl sudo "$1" "$2"
}

# Every check and mutation goes through the optional sudo prefix, so root-owned
# targets are inspected the same way they are changed.
_link_impl_backup() {
    local pfx="$1" target="$2"
    ${=pfx} test -e "$target" && ! ${=pfx} test -L "$target" || return 0
    local backup="$target.bak"
    if ${=pfx} test -e "$backup" || ${=pfx} test -L "$backup"; then
        backup="$target.bak.$(date +%Y%m%d%H%M%S)"
    fi
    if ! ${=pfx} mv "$target" "$backup"; then
        print -u2 "    FAILED to back up $target -> $backup (mv failed)"
        return 1
    fi
    print "    backed up $target -> $backup"
}

_link_impl() {
    local pfx="$1" src="$2" dest="$3"
    if ${=pfx} test -L "$dest"; then
        [[ "$(${=pfx} readlink "$dest")" == "$src" ]] && return 0
        if ! ${=pfx} rm "$dest"; then
            print -u2 "    FAILED to link $dest -> $src (rm of the old symlink failed)"
            return 1
        fi
    elif ! _link_impl_backup "$pfx" "$dest"; then
        print -u2 "    FAILED to link $dest -> $src (backup failed)"
        return 1
    fi
    if ! ${=pfx} mkdir -p "${dest:h}"; then
        print -u2 "    FAILED to link $dest -> $src (mkdir -p ${dest:h} failed)"
        return 1
    fi
    if ! ${=pfx} ln -s "$src" "$dest"; then
        print -u2 "    FAILED to link $dest -> $src (ln -s failed)"
        return 1
    fi
    print "    linked $dest -> $src"
}
