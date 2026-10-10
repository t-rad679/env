# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal environment/dotfiles for two Arch Linux + i3 machines, a **desktop** and a **laptop**. It is cloned to `~/src/env` on both and its scripts assume that location (`ENV_DIR` defaults to `$HOME/src/env`; `git/gitconfig` and `config/i3/config` spell the path out). The two machines have different usernames, so nothing here may assume a username: use `$HOME`/`~`. There is no build, test, or lint step — changes are validated with `zsh -n` and by running the init against a throwaway `HOME`.

## Layout

- **`init/`** — provisioning. `init.sh` is the bash bootstrap (bash because a fresh box has no zsh yet); everything else is zsh step scripts (see below).
- **`config/`** — files that land in the home directory, laid out by where they go: `zsh/` (`.zshrc`, `.zsh_plugins.txt`, `env/*.zsh` → `~/.zshrc`, `~/.zsh_plugins.txt`, `~/env`), `i3/` (→ `~/.config/i3`), `niri/config.kdl` (→ `~/.config/niri/config.kdl`), `kitty/` (`kitty.conf` plus `quick-access-terminal.conf`, the niri dropdown terminal), `ssh/config` (→ `~/.ssh/config`, host aliases only; never keys or `known_hosts`), `.xprofile`, `pacman.conf` (→ `/etc/pacman.conf`), `packages.txt` (shared package list), `spotify-mcp/spotify-config.sample.json`, `wallpapers/` (→ `~/pics/wallpapers`, the images `bin/wallpaper` paints on the root window), `avatar.png` (the login-screen face, installed by `init/avatar.zsh` — not linked anywhere).
- **`machines/desktop/`, `machines/laptop/`** — everything that only one role gets: `machine-role.env` (the role file), `packages.txt` (role-only packages), `i3/*.conf` (role-only i3 config), `niri/role.kdl` (role-only niri config, → `~/.config/niri/role.kdl`), `xprofile.sh` (role-only X-session startup, a POSIX sh fragment sourced by `config/.xprofile`; the desktop one is where the headless Obsidian / Xvfb startup belongs and is a marked placeholder until it is pasted in), `init.zsh` (role init hook, run last), plus role-only config (desktop: `lightdm.conf.d/`, `bin/` with the headless Obsidian / Claude remote-control helpers; laptop: `greetd/config.toml`, `xsessions/i3-xprofile.desktop`, `autorandr/`, `wireplumber/`, `systemd/`, `ulauncher/`, `bin/`).
- **`bin/`** — scripts for both machines; `config/zsh/env/path.zsh` puts it (`~/src/env/bin`) on `PATH`. It is never linked to `~/bin`, which stays the user's own hand-written-scripts directory (also on `PATH` when present). `claude-hook-node` is the launcher for anything Claude Code has to spawn as `node` (`zsh $HOME/src/env/bin/claude-hook-node <script.js> ...`): it loads node from nvm when Claude Code was started without an interactive zsh (ulauncher, a .desktop entry, a systemd user unit), where PATH has no node. Used by the `node` hooks in `claude/settings.json` and by the spotify MCP server registration, which is why a bare `node ...` is never the registered command. `i3-xsession` is the POSIX-sh wrapper that sources `~/.xprofile` before exec'ing i3, for the greetd path that otherwise skips it (installed to `/usr/local/bin`, not run from here).
- **`git/`** — git helper scripts + the gitconfig include that exposes them.
- **`claude/`** — user-level Claude Code config: `CLAUDE.md`, `settings.json`, `config.sample.json`, `user-skills/*`.

Secrets never live in the repo: `claude/config.json` (Obsidian key) and the Spotify config (client secret + OAuth tokens) are gitignored, and init copies the committed `*.sample.json` into place once for you to fill in.
- **`ide/`** — exported JetBrains configs (binary zips, not editable source).

## Machine roles

`MACHINE_ROLE` is `desktop` or `laptop`. **Desktop is the default everywhere the variable is unset**: `init/init.sh` (`--laptop` selects laptop; `--desktop`/`--desktopMode` are accepted too), `init/init.zsh`, `.zshrc`, `.xprofile`, `path.zsh` and the i3 include all apply `${MACHINE_ROLE:-desktop}`, so a session that never sourced the role file (startx, a display manager that skips `~/.xprofile`) still gets the desktop config rather than silently none. The role is published three ways from one file, `machines/<role>/machine-role.env` (plain `KEY=VALUE`), which `init/role.zsh` links to `~/.config/machine-role.env`:

- **zsh** — `config/zsh/.zshrc` sources it (with `set -a`) *before* the `~/env/*.zsh` loop, so env scripts can branch on it regardless of filename order.
- **X session** — `config/.xprofile` (POSIX sh, because LightDM runs it with `sh`; this is the one deliberate exception to the zsh-only rule, shared by the `machines/<role>/xprofile.sh` fragments it sources) exports it, so i3 and everything it launches inherit it, then sources `machines/${MACHINE_ROLE:-desktop}/xprofile.sh` for role-only login setup. `init/links.zsh` warns loudly before backing up a real `~/.xprofile` to `~/.xprofile.bak`: its contents must be moved into the role fragment or they stop running at login.
- **i3** — `config/i3/config` does `include $HOME/src/env/machines/$MACHINE_ROLE/i3/*.conf`. i3 expands include paths with `wordexp(3)` (env vars, `~`, globs) and silently skips a pattern that matches nothing, so each role dir ships at least one `.conf`.

Desktop-only: gaming/NVIDIA packages, the LightDM HDMI-3 greeter drop-in, `xset s off -dpms`, the Spotify screensaver, Steam + its assign rule, the gamescope rule, and the headless Obsidian / Claude remote-control helpers. The laptop role is an empty, ready slot (comment-only files).

## The zsh setup

- **`config/zsh/.zshrc`** — the one rc, symlinked to `~/.zshrc`. Reads the role file, then uses [antidote](https://getantidote.github.io/) for plugins (looked for in `~/.antidote`, where `init/antidote.zsh` clones it, then `/usr/share/...` fallbacks) and powerlevel10k for the prompt. Note: the AUR package literally named `antidote` is *unrelated* software (Druide's writing tool), which is why antidote is installed via git clone, not yay.
- **`config/zsh/.zsh_plugins.txt`** — the antidote plugin list (→ `~/.zsh_plugins.txt`). The `ohmyzsh/ohmyzsh path:...` entries are oh-my-zsh plugins loaded *through* antidote; the oh-my-zsh framework itself is gone.
- **`config/zsh/env/*.zsh`** — custom env scripts, sourced from `~/env` (a symlink to the directory) in **alphabetical order**. They have no load-order dependencies; if you add some, prefix filenames (`00-`, `10-`). `globalvars.zsh` exports `EDITOR` and `GRIMOIRE_DIR` (`~/docs/obsidian_vaults/grimoire`, the same on both machines); `path.zsh` adds `~/bin` (the user's own, unmanaged), `~/src/env/bin` and `machines/$MACHINE_ROLE/bin` to `PATH`.

## The niri / Wayland session (laptop only, so far)

The laptop can boot either i3 on X or **niri** on Wayland; the desktop is still i3-only. What changes on the Wayland side:

- **Login manager.** `greetd` replaces LightDM, running **noctalia-greeter** (`machines/laptop/greetd/config.toml` → `/etc/greetd/config.toml`, linked by the laptop's `init.zsh`). The command is `noctalia-greeter-session`, never the bare `noctalia-greeter`: the greeter is a Wayland client, and the wrapper is what starts the bundled wlroots compositor it draws into. The session picker lists everything in `/usr/share/wayland-sessions` and `/usr/share/xsessions`, so i3 stays selectable. greetd and LightDM both claim `display-manager.service`, so only one can be enabled — which is why the greetd half is laptop-only and why LightDM is disabled, not removed (`sudo systemctl disable --now greetd && sudo systemctl enable --now lightdm` from a text console is the way back).
- **The avatar above the username is not a greeter setting.** `greeter.toml` has no key for it; noctalia-greeter asks AccountsService for the user's `IconFile` and draws whatever that points at, so the picture is set with `init/avatar.zsh` from the committed `config/avatar.png`, not with greeter config. Two things make the obvious approaches fail. AccountsService's default answer is `$HOME/.face`, which the greeter — running as the unprivileged `greeter` user — can never read through a 0700 `$HOME`, the same trap as the `i3 (xprofile)` `.desktop` entry below; and the image must therefore be a real copy outside `$HOME`, never a symlink back into the repo. `SetIconFile` handles both: the daemon reads the source as root and copies it to `/var/lib/AccountsService/icons/<user>`, world-readable. It also caps the icon at 1 MiB, and the greeter rejects progressive JPEGs, so the source is a square ~512px PNG. lightdm-gtk-greeter reads the same property, which is why this step is shared rather than laptop-only.
- **Shell.** **Noctalia Shell** (`noctalia --daemon`, started by `spawn-at-startup`) is bar, launcher, notifications, control centre, lock screen, OSDs and wallpaper in one process. It replaces i3bar/i3status, dunst, nm-applet, Ulauncher and `bin/wallpaper`; none of those are started under niri. Keybinds drive it through `noctalia msg …`.
- **Role config works differently from i3's.** i3 pulls its role file in with `include $HOME/src/env/machines/${MACHINE_ROLE:-desktop}/i3/*.conf`, which works because i3 expands include paths with `wordexp(3)` and silently skips an empty glob. **niri's `include` expands `~` and nothing else** — no environment variables, no globs — and a file it cannot read is a parse error that rejects the entire config. So the role cannot be named from inside the config, and the indirection lives in `init/links.zsh` instead: it links `machines/<role>/niri/role.kdl` to the fixed path `~/.config/niri/role.kdl`, which `config/niri/config.kdl` includes on its last line. Both roles therefore ship a `niri/role.kdl` (the desktop's is comment-only) for the same reason every role ships at least one `i3/*.conf`.
- **Two file links, not one directory link.** `~/.config/i3` is a single directory symlink; niri gets `config.kdl` and `role.kdl` linked individually, because they come from different places in the repo.
- **Validation.** `niri validate -c <file>` is the closest thing this repo has to a test for it, and it is worth running on both roles after a change (point `HOME` at a throwaway directory holding a `.config/niri/role.kdl` link to check the other role's). niri also watches the live config and reloads on save, keeping the last good version when a new one fails to parse.
- **What does not survive the move.** `~/.xprofile` is a display-manager convention, so nothing in it runs under niri — that is fine, since the role split no longer needs `MACHINE_ROLE` and niri handles hotplug itself (no autorandr). X-only tools lose their bindings: `flameshot` (its legacy X11 grab sees only XWayland), `autorandr`, and `machines/laptop/bin/monitor-output`'s X resources. Noctalia covers screenshots and display settings. X *applications* still work — niri spawns `xwayland-satellite` on demand and exports `DISPLAY` itself, so there is nothing to configure beyond installing the package.
- **Picking i3 from the greeter needs the `i3 (xprofile)` entry, not the stock `i3`.** greetd starts X sessions with `startx <wm>`, and an explicit client means `startx` reads neither `~/.xinitrc` nor `~/.xprofile` — so the stock entry gives an i3 with no `MACHINE_ROLE` (the laptop silently loads the *desktop* role), no `autorandr --change`, and no `monitor-output`. `bin/i3-xsession` sources `~/.xprofile` and then execs i3; `machines/laptop/xsessions/i3-xprofile.desktop` is the picker entry that runs it. Three details, each found the hard way and each worth not re-deriving:
  - **The `.desktop` is copied into `/usr/local/share/xsessions`, not symlinked into the repo.** The greeter parses it as the unprivileged `greeter` user, and `$HOME` is `drwx------` — a symlink into `~/src/env` is unreadable to that user and the entry just never appears. Only the `Exec` target can be a repo symlink, because that runs after authentication as the logging-in user.
  - **The entry is named `i3 (xprofile)`, not `i3`.** The greeter de-duplicates the picker by `Name=`, and nothing reveals which of two same-named entries wins — so shadowing the stock entry would be a coin flip between the fixed session and the broken one.
  - **No `TryExec=`.** The greeter ignores it; a greeter that honours it would evaluate it as its own unprivileged user, fail to stat the symlink target inside `$HOME`, and hide the entry for the wrong reason.

  `noctalia-greeter sessions` prints the picker list exactly as the greeter builds it, and is the way to check any of this (the laptop's `init.zsh` warns if the entry is missing). It also honours `NoDisplay=true` but ignores a missing `Exec`.
- **The dropdown terminal is `kitten quick-access-terminal`, not tdrop.** Same key as i3 (`Mod+grave`), config in `config/kitty/quick-access-terminal.conf`. It is a wlr-layer-shell surface, so niri never tiles it, and it serialises on kitty's single-instance socket, so the `flock` and the monitor/offset arithmetic the i3 binding needs all go away. Two gotchas: `lines` takes cells / `Npx` / `Nc` but **not** a percentage — an unparseable value silently becomes one line — and a layer-shell surface cannot be moved between outputs after creation, so unlike tdrop's `-m` it does not follow focus to another monitor.

## Provisioning flow

`init/init.sh [--desktop|--laptop] [--links-only]` installs zsh and execs `init/init.zsh` with `MACHINE_ROLE` set. `init.zsh` sources each step **in its own subshell** by absolute path off `ENV_DIR`, so a failing step (or a stray `exit`) is reported and init continues; it prints a summary of failed steps at the end. Every step is safe to re-run. Order:

1. `fs.zsh` — `~/src`, `~/.config`, `~/.ssh` (0700), `~/docs/obsidian_vaults` (never the vault itself)
2. `role.zsh` — link `~/.config/machine-role.env`
3. `pacman.zsh` — link `pacman.conf`, install git, bootstrap yay (`yay.zsh`), `yay -Syu`, install `config/packages.txt` + `machines/<role>/packages.txt`. Interactive on purpose (no `--noconfirm`): the desktop gaming packages raise provider prompts (`lib32-vulkan-driver`) where the default pick is AMD, not NVIDIA
4. `gh-login.zsh` — `gh auth status`; only when logged out, `gh auth login --git-protocol ssh --web` (device code, works from a text console; offers to generate and upload an ssh key), then init continues on its own
5. `antidote.zsh`, `node.zsh` — antidote clone; latest node via the `nvm` package
6. `links.zsh` — zsh files, `~/env`, `~/.config/i3` (whole directory), the two niri files, kitty (including the dropdown terminal's conf), `~/.ssh/config` (file only), `~/.xprofile` (never `~/bin`); returns non-zero if any link failed
7. `claude.zsh` — link `CLAUDE.md`, `settings.json` and every `claude/user-skills/*` dir; copy `config.sample.json` → `~/.claude/config.json` only if missing (never overwritten; prints a reminder to paste the Obsidian key). The local plugin marketplaces stay as the committed `~/src/<name>` directory sources in `settings.json`: Claude Code expands `~` itself when it registers them in `~/.claude/plugins/known_marketplaces.json`, so init never rewrites the tracked file (it used to, with a username-specific absolute path)
8. `avatar.zsh` — set the login-screen avatar from the committed `config/avatar.png` via AccountsService's `SetIconFile`, which copies it to `/var/lib/AccountsService/icons/<user>` and persists `Icon=` itself; a no-op when the installed copy already matches
9. `marketplaces.zsh` — `gh repo clone` the local plugin marketplaces into `~/src` (skip if present)
10. `git.zsh` — add `git/gitconfig` to the global `include.path` once
11. `shell.zsh` — `chsh` to zsh if needed
12. `spotify-mcp.zsh` — clone `spotify-mcp-server`; `npm install && npm run build` whenever `build/index.js` is missing (so a failed first build is retried on the next run); copy `spotify-config.sample.json` into it once (real file, never a link); register the server with Claude Code at user scope via `bin/claude-hook-node`, guarded on `claude mcp get spotify` because re-adding an existing name errors; `npm run auth` only once the build exists, the client id/secret are filled in and no `refreshToken` is stored
13. `machines/<role>/init.zsh` — role hook (desktop: LightDM drop-in via `sudo`; laptop: autorandr drop-in, `video` group, the greetd / Noctalia Greeter setup that hands `display-manager.service` over from LightDM, and the `i3 (xprofile)` session entry)

`--links-only` runs only steps 1, 2, 6, 7, 8, 10 and 13: no packages, network, or `chsh`. Steps 3, 4, 9, 12 need sudo/network and are the ones to stub when testing.

### Linking rules (`init/lib.zsh`)

`link_path SRC DEST` (and `sudo_link_path` for `/etc`) is used for every link init makes: no-op if `DEST` already points at `SRC`; a symlink pointing elsewhere is replaced; a real file/dir is moved to `DEST.bak` once (a later run never overwrites an existing backup — it gets a timestamp suffix instead). Symlinks are always replaced, never linked into, so re-running can't create nested links inside a target directory. Every mutation (`mv`, `rm`, `mkdir`, `ln`) is checked: on failure the helper prints `FAILED to link ...` on stderr and returns non-zero, so the step fails and shows up in init's summary instead of printing a `linked` line that never happened.

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
