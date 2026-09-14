#!/usr/bin/zsh

# Shared helpers for init steps. Every step sources this file.
#
# The linking rules every step follows:
#   * idempotent -- a second run changes nothing;
#   * a pre-existing real file/directory is backed up once, and a later run
#     never overwrites that backup;
#   * an existing symlink is replaced in place (never "linked into"), so
#     re-linking a directory symlink can't create a nested link inside the
#     target.

export ENV_DIR="${ENV_DIR:-$HOME/src/env}"

# backup_once PATH
# If PATH is a real (non-symlink) file or directory, move it aside. The first
# backup goes to PATH.bak; if that already exists it is left alone and the new
# backup gets a timestamp suffix instead.
backup_once() {
    _link_impl_backup "" "$1"
}

# link_path SRC DEST
# Make DEST a symlink to SRC. No-op if it already is. A symlink pointing
# elsewhere (or dangling) is replaced; a real file/dir is backed up first.
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
    print "    backing up $target -> $backup"
    ${=pfx} mv "$target" "$backup"
}

_link_impl() {
    local pfx="$1" src="$2" dest="$3"
    if ${=pfx} test -L "$dest"; then
        [[ "$(${=pfx} readlink "$dest")" == "$src" ]] && return 0
        ${=pfx} rm "$dest"
    else
        _link_impl_backup "$pfx" "$dest"
    fi
    ${=pfx} mkdir -p "${dest:h}"
    ${=pfx} ln -s "$src" "$dest"
    print "    linked $dest -> $src"
}
