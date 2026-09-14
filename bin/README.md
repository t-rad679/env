# bin/

Scripts for every machine. init/links.zsh symlinks `~/bin` to this directory and
config/zsh/env/path.zsh puts `~/bin` on `PATH`, so anything dropped here is a
command on both machines.

Role-only scripts live in `machines/<role>/bin/` instead (also on `PATH`, only
on that role).
