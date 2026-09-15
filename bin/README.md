# bin/

Scripts for every machine. config/zsh/env/path.zsh puts this directory
(`~/src/env/bin`) on `PATH`, so anything dropped here is a command on both
machines. It is never linked to `~/bin`: that stays the user's own directory of
hand-written scripts, which path.zsh also puts on `PATH`.

Role-only scripts live in `machines/<role>/bin/` instead (also on `PATH`, only
on that role).
