#!/usr/bin/awk -f
#
# Idempotently ensure one key exists in one TOML table, leaving every other
# byte of the file alone. Used by machines/spellbook/init.zsh to enable Noctalia
# plugins by editing Noctalia's own settings.toml -- a file this repo
# deliberately does not track (see init.zsh for why).
#
# Not zsh, unlike every other script here. This is a line-oriented rewrite of a
# file that has to survive byte for byte outside the one key being set, which
# is awk's entire job; the zsh version is a hand-rolled TOML parser, and the
# clean version is a TOML-writing library that is not in base.
#
# Usage:
#     awk -f noctalia-settings-ensure.awk \
#         -v section='[plugins]' -v key=enabled \
#         -v mode=union -v value='author/one,author/two' \
#         settings.toml
#
# The whole file goes to stdout; the caller compares it with the original
# rather than trusting an exit status, so this always exits 0 on readable
# input. A missing section is appended, a missing key is inserted just after
# its section header (valid TOML: keys must precede any sub-table), and a
# missing file yields just the section -- Noctalia merges a partial
# settings.toml over its defaults, so seeding one is safe.
#
#     mode=union    `key` is an array of strings. Adds each comma-separated
#                   entry of `value` that is not already a member, keeping the
#                   existing members and their order.
#     mode=default  `key` is a plain string. Writes it only when the key is
#                   absent, so a hand-edited choice is never overwritten.
#
# Known limit: a `]` inside a string value would be read as the end of a
# multi-line array. Nothing this is pointed at has one, and Noctalia writes
# short arrays on a single line anyway.

BEGIN {
    nwant = split(value, want, ",")
}

# Keep the whole file so END can splice it back together.
{
    line[NR] = $0
}

# Any bracketed line is a table header -- [table] or [[array.of.tables]], at
# any indentation. Matching on the trimmed text means a quoted name works too,
# e.g. [plugin_settings."author/plugin"].
/^[ \t]*\[/ {
    hdr = $0
    sub(/^[ \t]+/, "", hdr)
    sub(/[ \t]+$/, "", hdr)
    if (hdr == section) {
        sstart = NR
        insec = 1
    } else if (insec) {
        # A sub-table such as [[plugins.source]] ends the parent's own keys,
        # and it has its own `enabled` -- so leaving the section here is what
        # keeps this from rewriting the wrong line.
        insec = 0
    }
    next
}

# The key's first line, inside our section only.
insec && !kstart && $0 ~ ("^[ \t]*" key "[ \t]*=") {
    kstart = NR
    kend = NR
    indent = $0
    sub(/[^ \t].*$/, "", indent)
    if (mode == "union" && index($0, "]") == 0) {
        open = 1
    }
    next
}

# Continuation lines of an array that opened on an earlier line.
open {
    kend = NR
    if (index($0, "]")) {
        open = 0
    }
    next
}

END {
    if (mode == "union") {
        # Existing members first, in their original order, then whatever of
        # `value` is new -- so re-running never reshuffles the list.
        nout = 0
        for (i = kstart; i && i <= kend; i++) {
            s = line[i]
            while (match(s, /"[^"]*"/)) {
                v = substr(s, RSTART + 1, RLENGTH - 2)
                s = substr(s, RSTART + RLENGTH)
                if (!(v in seen)) {
                    seen[v] = 1
                    out[++nout] = v
                }
            }
        }
        for (i = 1; i <= nwant; i++) {
            v = want[i]
            sub(/^[ \t]+/, "", v)
            sub(/[ \t]+$/, "", v)
            if (v != "" && !(v in seen)) {
                seen[v] = 1
                out[++nout] = v
            }
        }
        if (nout == 0) {
            rendered = key " = []"
        } else {
            rendered = key " = [ "
            for (i = 1; i <= nout; i++) {
                rendered = rendered "\"" out[i] "\"" (i < nout ? ", " : "")
            }
            rendered = rendered " ]"
        }
    } else {
        rendered = key " = \"" value "\""
    }

    if (kstart && mode == "default") {
        # Already set by hand or by Noctalia itself -- do not second-guess it.
        for (i = 1; i <= NR; i++) {
            print line[i]
        }
    } else if (kstart) {
        for (i = 1; i < kstart; i++) {
            print line[i]
        }
        print indent rendered
        for (i = kend + 1; i <= NR; i++) {
            print line[i]
        }
    } else if (sstart) {
        # Straight after the header, so the key cannot end up stranded below a
        # sub-table, where TOML would read it as that sub-table's.
        for (i = 1; i <= sstart; i++) {
            print line[i]
        }
        print rendered
        for (i = sstart + 1; i <= NR; i++) {
            print line[i]
        }
    } else {
        for (i = 1; i <= NR; i++) {
            print line[i]
        }
        if (NR && line[NR] != "") {
            print ""
        }
        print section
        print rendered
    }
}
