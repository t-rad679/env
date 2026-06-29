# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal environment/dotfiles for the user (`tradical`). It is cloned to `~/src/env` and its scripts assume that location (e.g. `arch/init/install/pacman.zsh` symlinks `$HOME/src/env/arch/config/pacman.conf`). There is no build, test, or lint step — changes are validated by sourcing the scripts in a real shell.

## The zsh setup

There is a single, cross-platform shell config under `zsh/`, used on both Arch and macOS. oh-my-zsh has been retired — the framework is gone; only some of its *plugins* are still pulled in (via antidote).

- **`zsh/.zshrc`** — the one rc, symlinked to `~/.zshrc`. Uses [antidote](https://getantidote.github.io/) for plugin management and powerlevel10k for the prompt. It locates `antidote.zsh` across machines (Homebrew on macOS; `~/.antidote` git clone on Arch — see below; plus `/usr/share/...` fallbacks if installed via a package), then `antidote load` reads `~/.zsh_plugins.txt`. Note: the AUR package literally named `antidote` is *unrelated* software (Druide's writing tool), which is why Arch installs antidote via git clone, not yay.
- **`zsh/.zsh_plugins.txt`** — the antidote plugin list (symlinked to `~/.zsh_plugins.txt`). Includes some `ohmyzsh/ohmyzsh path:...` entries — those are oh-my-zsh plugins loaded *through* antidote, not the oh-my-zsh framework.
- **`zsh/env/*.zsh`** — custom env scripts (see next section).

## Env-script load order

`zsh/.zshrc` sets `ZSH_CUSTOM=~/env` and sources every `~/env/*.zsh` in **alphabetical order** (`alias`, `highlight`, `path`, `startup`). On Arch, `links.zsh` symlinks the whole `zsh/env/` directory to `~/env`. There is no `env_setup.zsh` chainloader.

The four current scripts have no load-order dependencies. If you add scripts that do, prefix filenames (`00-`, `10-`) since alphabetical order is the contract. When changing env behavior, edit `zsh/env/`.

## Arch provisioning flow

`arch/init.sh` is the bootstrap entry point (installs zsh, then sources `init/init.zsh` relative to its own location). `arch/init/init.zsh` sets `ENV_DIR=$HOME/src/env` and sources each step by absolute path (so steps don't depend on cwd), in order:
1. `fs.zsh` — create `~/src`, `~/bin`
2. `install/pacman.zsh` — swap in this repo's `pacman.conf`, install git, bootstrap yay (`install/yay.zsh`), `yay -Syu`, then install everything in `arch/config/packages.txt`
3. `install/antidote.zsh` — install the antidote zsh plugin manager (git clone to `~/.antidote`; idempotent)
4. `links.zsh` — symlink `zsh/.zshrc` → `~/.zshrc`, `zsh/.zsh_plugins.txt` → `~/.zsh_plugins.txt`, and `zsh/env/` → `~/env`; also `chsh` to zsh (login shell). Note: `antidote` is a zsh *function* loaded by the zshrc, not a binary — it only exists inside an interactive zsh once `~/.antidote` is cloned.
5. `git.zsh` — wire git helper scripts into git via `git config --global include.path`
6. `gaming.zsh` — gaming/nvidia packages via yay (runs last: big, optional, AUR-heavy)

These scripts are destructive/system-level (move `/etc/pacman.conf`, install packages) and are meant to run once on a fresh Arch install. To always install a package, add it to `arch/config/packages.txt` (one per line, `#` for comments; repo or AUR).

## Git helper scripts

`git/*.sh` are exposed as git subcommands via aliases in `git/gitconfig`, which `arch/init/git.zsh` pulls into the global config with `git config --global include.path`. This gives `git update` / `git cleanup` / `git rename-branch`:
- `git-update.sh` — stash, checkout default branch (`master` by default, or `$1`), pull, return to original branch, rebase onto default, re-apply stash.
- `git-cleanup.sh` — prune remote-tracking refs and delete local branches whose upstream is `: gone]`.
- `git-rename-branch.sh` — rename a branch locally and recreate it on the remote (`git rename-branch old new`).

`git-update.sh` defaults the trunk to `master`; this repo's own trunk is `main`, so pass it explicitly when running here.

## IDE settings

`ide/keymaps.zip` and `ide/settings.zip` are exported JetBrains/IntelliJ configs (the repo is itself an IntelliJ project — see `.idea/`). They are binary archives, not editable source.

## Conventions

- Shebangs are inconsistent (`#!/usr/bin/zsh`, `#!/bin/zsh`, `#!/bin/bash`); match the surrounding file rather than normalizing.
- `alias.zsh` assumes `lsd`, `vim`, and `xclip` are installed.
