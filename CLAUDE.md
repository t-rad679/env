# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal environment/dotfiles for two Arch Linux + i3 machines, a **desktop** and a **laptop**. It is cloned to `~/src/env` on both and its scripts assume that location (`ENV_DIR` defaults to `$HOME/src/env`; `git/gitconfig` and `config/i3/config` spell the path out). The two machines have different usernames, so nothing here may assume a username: use `$HOME`/`~`. There is no build, test, or lint step — changes are validated with `zsh -n` and by running the init against a throwaway `HOME`.

## Layout

- **`init/`** — provisioning. `init.sh` is the bash bootstrap (bash because a fresh box has no zsh yet); everything else is zsh step scripts (see below).
- **`config/`** — files that land in the home directory, laid out by where they go: `zsh/` (`.zshrc`, `.zsh_plugins.txt`, `env/*.zsh` → `~/.zshrc`, `~/.zsh_plugins.txt`, `~/env`), `i3/` (→ `~/.config/i3`), `kitty/kitty.conf`, `.xprofile`, `pacman.conf` (→ `/etc/pacman.conf`), `packages.txt` (shared package list), `spotify-mcp/spotify-config.sample.json`, `wallpapers/` (→ `~/pics/wallpapers`, the images `bin/wallpaper` paints on the root window).
- **`machines/desktop/`, `machines/laptop/`** — everything that only one role gets: `machine-role.env` (the role file), `packages.txt` (role-only packages), `i3/*.conf` (role-only i3 config), `xprofile.sh` (role-only X-session startup, a POSIX sh fragment sourced by `config/.xprofile`; the desktop one is where the headless Obsidian / Xvfb startup belongs and is a marked placeholder until it is pasted in), `init.zsh` (role init hook, run last), plus role-only config (desktop: `lightdm.conf.d/`, `systemd/` (the `ollama.service` drop-in, copied to `/etc`, and the `gemma-gaming` user unit), `bin/` with the headless Obsidian / Claude remote-control helpers and `gemma-swap`).
- **`bin/`** — scripts for both machines; `config/zsh/env/path.zsh` puts it (`~/src/env/bin`) on `PATH`. It is never linked to `~/bin`, which stays the user's own hand-written-scripts directory (also on `PATH` when present). `claude-hook-node` is the launcher for the `node` hooks in `claude/settings.json` (`zsh $HOME/src/env/bin/claude-hook-node <hook.js>`): it loads node from nvm when Claude Code was started without an interactive zsh (ulauncher, a .desktop entry, a systemd user unit), where PATH has no node.
- **`git/`** — git helper scripts + the gitconfig include that exposes them.
- **`claude/`** — user-level Claude Code config: `CLAUDE.md`, `settings.json`, `config.sample.json`, `user-skills/*`.

Secrets never live in the repo: `claude/config.json` (Obsidian key) and the Spotify config (client secret + OAuth tokens) are gitignored, and init copies the committed `*.sample.json` into place once for you to fill in.
- **`ide/`** — exported JetBrains configs (binary zips, not editable source).

## Machine roles

`MACHINE_ROLE` is `desktop` or `laptop`. **Desktop is the default everywhere the variable is unset**: `init/init.sh` (`--laptop` selects laptop; `--desktop`/`--desktopMode` are accepted too), `init/init.zsh`, `.zshrc`, `.xprofile`, `path.zsh` and the i3 include all apply `${MACHINE_ROLE:-desktop}`, so a session that never sourced the role file (startx, a display manager that skips `~/.xprofile`) still gets the desktop config rather than silently none. The role is published three ways from one file, `machines/<role>/machine-role.env` (plain `KEY=VALUE`), which `init/role.zsh` links to `~/.config/machine-role.env`:

- **zsh** — `config/zsh/.zshrc` sources it (with `set -a`) *before* the `~/env/*.zsh` loop, so env scripts can branch on it regardless of filename order.
- **X session** — `config/.xprofile` (POSIX sh, because LightDM runs it with `sh`; this is the one deliberate exception to the zsh-only rule, shared by the `machines/<role>/xprofile.sh` fragments it sources) exports it, so i3 and everything it launches inherit it, then sources `machines/${MACHINE_ROLE:-desktop}/xprofile.sh` for role-only login setup. `init/links.zsh` warns loudly before backing up a real `~/.xprofile` to `~/.xprofile.bak`: its contents must be moved into the role fragment or they stop running at login.
- **i3** — `config/i3/config` does `include $HOME/src/env/machines/$MACHINE_ROLE/i3/*.conf`. i3 expands include paths with `wordexp(3)` (env vars, `~`, globs) and silently skips a pattern that matches nothing, so each role dir ships at least one `.conf`.

Desktop-only: gaming/NVIDIA packages, the LightDM HDMI-3 greeter drop-in, `xset s off -dpms`, the Spotify screensaver, Steam + its assign rule, the gamescope rule, the local Gemma server (Ollama; the `gemma` alias is swapped to the small model while a gamescope session runs), and the headless Obsidian / Claude remote-control helpers. The laptop role is an empty, ready slot (comment-only files).

## The zsh setup

- **`config/zsh/.zshrc`** — the one rc, symlinked to `~/.zshrc`. Reads the role file, then uses [antidote](https://getantidote.github.io/) for plugins (looked for in `~/.antidote`, where `init/antidote.zsh` clones it, then `/usr/share/...` fallbacks) and powerlevel10k for the prompt. Note: the AUR package literally named `antidote` is *unrelated* software (Druide's writing tool), which is why antidote is installed via git clone, not yay.
- **`config/zsh/.zsh_plugins.txt`** — the antidote plugin list (→ `~/.zsh_plugins.txt`). The `ohmyzsh/ohmyzsh path:...` entries are oh-my-zsh plugins loaded *through* antidote; the oh-my-zsh framework itself is gone.
- **`config/zsh/env/*.zsh`** — custom env scripts, sourced from `~/env` (a symlink to the directory) in **alphabetical order**. They have no load-order dependencies; if you add some, prefix filenames (`00-`, `10-`). `globalvars.zsh` exports `EDITOR` and `GRIMOIRE_DIR` (`~/docs/obsidian_vaults/grimoire`, the same on both machines); `path.zsh` adds `~/bin` (the user's own, unmanaged), `~/src/env/bin` and `machines/$MACHINE_ROLE/bin` to `PATH`.

## Provisioning flow

`init/init.sh [--desktop|--laptop] [--links-only]` installs zsh and execs `init/init.zsh` with `MACHINE_ROLE` set. `init.zsh` sources each step **in its own subshell** by absolute path off `ENV_DIR`, so a failing step (or a stray `exit`) is reported and init continues; it prints a summary of failed steps at the end. Every step is safe to re-run. Order:

1. `fs.zsh` — `~/src`, `~/.config`, `~/docs/obsidian_vaults` (never the vault itself)
2. `role.zsh` — link `~/.config/machine-role.env`
3. `pacman.zsh` — link `pacman.conf`, install git, bootstrap yay (`yay.zsh`), `yay -Syu`, install `config/packages.txt` + `machines/<role>/packages.txt`. Interactive on purpose (no `--noconfirm`): the desktop gaming packages raise provider prompts (`lib32-vulkan-driver`) where the default pick is AMD, not NVIDIA
4. `gh-login.zsh` — `gh auth status`; only when logged out, `gh auth login --git-protocol ssh --web` (device code, works from a text console; offers to generate and upload an ssh key), then init continues on its own
5. `antidote.zsh`, `node.zsh` — antidote clone; latest node via the `nvm` package
6. `links.zsh` — zsh files, `~/env`, `~/.config/i3` (whole directory), kitty, `~/.xprofile` (never `~/bin`); returns non-zero if any link failed
7. `claude.zsh` — link `CLAUDE.md`, `settings.json` and every `claude/user-skills/*` dir; copy `config.sample.json` → `~/.claude/config.json` only if missing (never overwritten; prints a reminder to paste the Obsidian key). The local plugin marketplaces stay as the committed `~/src/<name>` directory sources in `settings.json`: Claude Code expands `~` itself when it registers them in `~/.claude/plugins/known_marketplaces.json`, so init never rewrites the tracked file (it used to, with a username-specific absolute path)
8. `marketplaces.zsh` — `gh repo clone` the local plugin marketplaces into `~/src` (skip if present)
9. `git.zsh` — add `git/gitconfig` to the global `include.path` once
10. `shell.zsh` — `chsh` to zsh if needed
11. `spotify-mcp.zsh` — clone `spotify-mcp-server`; `npm install && npm run build` whenever `build/index.js` is missing (so a failed first build is retried on the next run); copy `spotify-config.sample.json` into it once (real file, never a link); `npm run auth` only once the build exists, the client id/secret are filled in and no `refreshToken` is stored
12. `machines/<role>/init.zsh` — role hook (desktop: LightDM drop-in; copy the `ollama.service` drop-in to `/etc` with `sudo_install_file`, enable `ollama.service`, link + enable the `gemma-gaming` user unit, remind to `ollama pull` missing models)

`--links-only` runs only steps 1, 2, 6, 7, 9 and 12: no packages, network, or `chsh`. Steps 3, 4, 8, 11 need sudo/network and are the ones to stub when testing.

### Linking rules (`init/lib.zsh`)

`link_path SRC DEST` (and `sudo_link_path` for `/etc`) is used for every link init makes: no-op if `DEST` already points at `SRC`; a symlink pointing elsewhere is replaced; a real file/dir is moved to `DEST.bak` once (a later run never overwrites an existing backup — it gets a timestamp suffix instead). Symlinks are always replaced, never linked into, so re-running can't create nested links inside a target directory. Every mutation (`mv`, `rm`, `mkdir`, `ln`) is checked: on failure the helper prints `FAILED to link ...` on stderr and returns non-zero, so the step fails and shows up in init's summary instead of printing a `linked` line that never happened.

Files systemd reads at boot from `/etc` (unit drop-ins) are the exception: `/home` is a separate mount on the desktop and systemd reads units before it mounts, so a link into `~/src/env` would dangle. `sudo_install_file SRC DEST` copies them instead (no-op when identical; sets `REPLY=installed|unchanged` so the caller can `daemon-reload`). Editing such a file in the repo takes effect only after re-running init.

## Git helper scripts

`git/*.sh` are exposed as git subcommands via aliases in `git/gitconfig`, which `init/git.zsh` pulls into the global config with `git config --global include.path`. This gives `git update` / `git cleanup` / `git rename-branch`:
- `git-update.sh` — stash, checkout default branch (`master` by default, or `$1`), pull, return to original branch, rebase onto default, re-apply stash.
- `git-cleanup.sh` — prune remote-tracking refs and delete local branches whose upstream is `: gone]`.
- `git-rename-branch.sh` — rename a branch locally and recreate it on the remote (`git rename-branch old new`).

`git-update.sh` defaults the trunk to `master`; this repo's own trunk is `main`, so pass it explicitly when running here.

## Conventions

- New shell scripts are zsh (`#!/usr/bin/zsh`). Exceptions: `init/init.sh` (bash bootstrap), `config/.xprofile` and the `machines/*/xprofile.sh` fragments it sources (POSIX sh). Older files with other shebangs are normalized only when touched.
- `sudo` cannot run from Claude's shell (no TTY); don't run init, package installs, `chsh`, or anything touching `/etc`. Verify with `zsh -n`, `sh -n`/`bash -n`, and by running the link steps against a throwaway `HOME` with `sudo`/`gh` stubbed.
- `alias.zsh` assumes `lsd`, `vim`, and `xclip` are installed.
- `claude/settings.json` is written back to by Claude Code (through the `~/.claude/settings.json` symlink), so expect it to show up modified.
