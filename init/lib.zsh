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

# sudo_pam_add_line FILE LINE [AFTER_REGEX]
# Add LINE to the PAM service file FILE: appended at the end, or inserted
# directly after the last line matching AFTER_REGEX. Returns non-zero (after a
# FAILED line on stderr) if FILE does not exist or any mutation fails.
#
# Idempotent on the (type, module) pair rather than on the literal line, so a
# hand-edited control flag -- `required` where this repo writes `optional` --
# is left alone instead of being shadowed by a second line for the same
# module. The match ignores comments by anchoring on the type field.
#
# /etc/pam.d files are edited in place rather than linked, because they belong
# to the package that ships them (greetd, pambase): a symlink into this repo
# would be clobbered on the next upgrade, and a missing file is a login
# failure. The one-time backup therefore has to be a copy, not the `mv` that
# backup_once does. It lands next to the original as FILE.bak, which is inert:
# PAM resolves a service by exact filename, so nothing ever reads `greetd.bak`.
sudo_pam_add_line() {
    local file="$1" line="$2" after="$3"
    local -a fields=( ${(z)line} )
    local type="${fields[1]}"
    # The module is the pam_*.so field, found by pattern rather than by
    # position, because the control field is one word (`optional`) or several
    # (`[success=1 default=ignore]`). Matched with the (r) subscript and not
    # ${(M)fields:#pam_*.so}, which yields nothing here. The leading * also
    # accepts the absolute-path spelling some distro files use.
    local module="${fields[(r)*pam_*.so]}"

    if [[ -z "$type" || -z "$module" ]]; then
        print -u2 "    FAILED to patch $file (cannot parse '$line')"
        return 1
    fi
    if ! sudo test -f "$file"; then
        print -u2 "    FAILED to patch $file (no such PAM service file)"
        return 1
    fi
    # ${type} and ${module} are braced because zsh -- unlike bash -- parses
    # `$type[[:space:]]` as a SUBSCRIPT on $type, which fails to parse rather
    # than interpolating.
    if sudo grep -qE "^[[:space:]]*${type}[[:space:]]+.*${module}" "$file"; then
        print "    $file already has a $type line for $module"
        return 0
    fi

    local backup="$file.bak"
    if ! sudo test -e "$backup"; then
        if ! sudo cp -a "$file" "$backup"; then
            print -u2 "    FAILED to patch $file (backup to $backup failed)"
            return 1
        fi
        print "    backed up $file -> $backup"
    fi

    if [[ -n "$after" ]]; then
        local lineno
        lineno="$(sudo grep -nE "$after" "$file" | tail -1 | cut -d: -f1)"
        if [[ -z "$lineno" ]]; then
            print -u2 "    FAILED to patch $file (no line matching /$after/ to insert after)"
            return 1
        fi
        if ! sudo sed -i "${lineno}a $line" "$file"; then
            print -u2 "    FAILED to patch $file (sed insert after line $lineno failed)"
            return 1
        fi
    elif ! print -r -- "$line" | sudo tee -a "$file" >/dev/null; then
        print -u2 "    FAILED to patch $file (append failed)"
        return 1
    fi
    print "    added '$line' to $file"
}

# sudo_install_file SRC DEST
# Copy SRC to the root-owned DEST (mode 644, parent dirs created) unless DEST
# is already a real file with the same contents. For files that must not be
# symlinks into $HOME: systemd reads units and drop-ins before /home is
# mounted, so a link into ~/src/env would dangle at boot. DEST belongs to
# this repo, so a differing DEST is overwritten, not backed up.
# Sets REPLY to "installed" or "unchanged" so the caller can daemon-reload
# only on change; returns non-zero (after a FAILED line on stderr) on failure.
sudo_install_file() {
    local src="$1" dest="$2"
    REPLY=unchanged
    [[ ! -L "$dest" ]] && cmp -s "$src" "$dest" && return 0
    if [[ -L "$dest" ]] && ! sudo rm "$dest"; then
        print -u2 "    FAILED to install $src -> $dest (rm of the old symlink failed)"
        return 1
    fi
    if ! sudo install -D -m644 "$src" "$dest"; then
        print -u2 "    FAILED to install $src -> $dest (install failed)"
        return 1
    fi
    REPLY=installed
    print "    installed $dest"
}
