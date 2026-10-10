# Gemma Gaming Swap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** While a gamescope session runs, Ollama serves `gemma3:4b` instead of `gemma3:12b` under the alias `gemma`; outside it (including a fresh boot with no login) `gemma3:12b` is loaded.

**Architecture:** A zsh script `gemma-swap small|big` repoints the Ollama alias and swaps what is on the GPU. A systemd user unit bound to `gamescope-session-plus@steam.service` runs it on session start/stop. A system drop-in for `ollama.service` (copied into `/etc`, never linked) keeps models loaded and resets/preloads the big model at boot. Desktop init wires it up.

**Tech Stack:** zsh, systemd (system + user units), Ollama 0.40 CLI/HTTP API, curl.

**Spec:** `docs/superpowers/specs/2026-10-09-gemma-gaming-swap-design.md`

## Global Constraints

- Desktop role only: everything lives under `machines/desktop/` except the generic helper in `init/lib.zsh`.
- Scripts are zsh (`#!/usr/bin/zsh`). No username in any path: use `$HOME`, `~`, or systemd's `%h`.
- Alias name: `gemma` (Ollama lists it as `gemma:latest`). Big model `gemma3:12b`, small model `gemma3:4b`.
- Ollama API: `http://127.0.0.1:11434`.
- Drop-in values: `OLLAMA_KEEP_ALIVE=-1`, `OLLAMA_CONTEXT_LENGTH=16384`.
- The drop-in is copied to `/etc/systemd/system/ollama.service.d/10-gemma.conf` (`/home` is a separate partition; systemd reads units before it mounts). The user unit is linked into `~/.config/systemd/user/`.
- `sudo` cannot run from Claude's shell. Anything needing it is verified with `sudo` stubbed, and the real run is left to the user.
- The role hook also runs under `init.sh --links-only`: no network (no `ollama pull`) from init.
- Existing uncommitted, unrelated change `machines/desktop/xprofile.sh` must not be committed by this work.

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `init/lib.zsh` | Modify (append) | `sudo_install_file SRC DEST`: copy a repo file into a root-owned path when it differs |
| `machines/desktop/bin/gemma-swap` | Create | Repoint `gemma`, unload other models, preload target |
| `machines/desktop/systemd/user/gemma-gaming.service` | Create | Run `gemma-swap small/big` around the gamescope session |
| `machines/desktop/systemd/ollama.service.d/10-gemma.conf` | Create | Keep-alive, context length, boot reset + preload |
| `machines/desktop/init.zsh` | Modify (replace the ollama block at the end) | Install drop-in, enable service, link + enable user unit, pull reminders |
| `CLAUDE.md` | Modify | Document the new pieces |
| `machines/desktop/packages.txt` | Already modified by the user (`ollama-cuda`) | Commit with Task 4 |

There is no test framework in this repo (by design; see `CLAUDE.md`). Tests are throwaway zsh scripts in the scratchpad (`$SCRATCH` below = `/tmp/claude-1000/-home-tradical-src-env/1fed1e65-248f-482b-aaa7-bebb8df2df00/scratchpad`) plus live checks against the running Ollama.

---

### Task 1: `sudo_install_file` helper

**Files:**
- Modify: `init/lib.zsh` (append at end of file)
- Test: `$SCRATCH/test-install-file.zsh` (throwaway)

**Interfaces:**
- Produces: `sudo_install_file SRC DEST` — sets global `REPLY` to `installed` or `unchanged`; returns 0 on success, 1 (with `    FAILED to install ...` on stderr) on failure; prints `    installed DEST` when it copies.

- [ ] **Step 1: Write the failing test**

`$SCRATCH/test-install-file.zsh`:

```zsh
#!/usr/bin/zsh
# Exercises sudo_install_file with sudo stubbed to run the command directly.
sudo() { "$@" }
source "$HOME/src/env/init/lib.zsh"

t=$(mktemp -d -p "${0:h}")
trap 'rm -rf "$t"' EXIT
fail() { print "FAIL: $*"; exit 1 }
dest=$t/etc/x.conf.d/10-x.conf

print a > $t/src
sudo_install_file $t/src $dest || fail "new: returned $?"
[[ $REPLY == installed && $(<$dest) == a ]] || fail "new: REPLY=$REPLY"
[[ $(stat -c %a $dest) == 644 ]] || fail "mode $(stat -c %a $dest)"

sudo_install_file $t/src $dest || fail "same: returned $?"
[[ $REPLY == unchanged ]] || fail "same: REPLY=$REPLY"

print b > $t/src
sudo_install_file $t/src $dest || fail "changed: returned $?"
[[ $REPLY == installed && $(<$dest) == b ]] || fail "changed: REPLY=$REPLY"

# A symlink with identical contents (an older init linked it) must still be
# replaced by a real file.
ln -sf $t/src $dest
sudo_install_file $t/src $dest || fail "symlink: returned $?"
[[ $REPLY == installed && ! -L $dest && $(<$dest) == b ]] || fail "symlink: REPLY=$REPLY"

sudo_install_file $t/missing $dest 2>/dev/null && fail "missing src returned 0"

print PASS
```

- [ ] **Step 2: Run it to verify it fails**

Run: `zsh $SCRATCH/test-install-file.zsh`
Expected: `FAIL: new: returned 127` (command not found — the helper doesn't exist yet).

- [ ] **Step 3: Implement the helper**

Append to `init/lib.zsh`:

```zsh

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
```

- [ ] **Step 4: Run the test and the syntax check**

Run: `zsh -n init/lib.zsh && zsh $SCRATCH/test-install-file.zsh`
Expected: `installed` lines, then `PASS`.

- [ ] **Step 5: Commit**

```bash
git add init/lib.zsh
git commit -m "init/lib: add sudo_install_file for files that can't be links into /home"
```

---

### Task 2: `gemma-swap` script

**Files:**
- Create: `machines/desktop/bin/gemma-swap` (mode 755)

**Interfaces:**
- Produces: `gemma-swap small|big` — exit 0 when the alias points at the target and it is the only loaded model; exit 1 with `gemma-swap: ...` on stderr otherwise. Used by Task 3's unit as `%h/src/env/machines/desktop/bin/gemma-swap`.

- [ ] **Step 1: Prerequisites and a format check**

Run: `ollama pull gemma3:4b` (~3.3 GB; no sudo needed).
Then confirm `ollama ps` IDs match `ollama list` IDs (the script relies on it):

```bash
curl -s http://127.0.0.1:11434/api/generate -d '{"model":"gemma3:12b"}' >/dev/null
ollama list; ollama ps
```

Expected: the `ID` column for `gemma3:12b` is the same in both (`b92b218582c5`). If it isn't, stop and report — Step 3's ID matching must change.

- [ ] **Step 2: Confirm the script doesn't exist yet**

Run: `machines/desktop/bin/gemma-swap small`
Expected: `no such file or directory`.

- [ ] **Step 3: Write the script**

`machines/desktop/bin/gemma-swap`:

```zsh
#!/usr/bin/zsh
# gemma-swap small|big -- point the Ollama alias "gemma" at the small or big
# Gemma, unload every other model from the GPU, and preload the new one.
# Run by gemma-gaming.service (small while a gamescope session runs, big when
# it ends) or by hand. Clients should request the model "gemma".
# Design: docs/superpowers/specs/2026-10-09-gemma-gaming-swap-design.md

readonly ALIAS=gemma:latest
readonly API=http://127.0.0.1:11434
typeset -A MODELS=( small gemma3:4b big gemma3:12b )

die() { print -u2 "gemma-swap: $*"; exit 1 }

# id_of NAME -- NAME's model ID as `ollama list` shows it (empty: not pulled)
id_of() { ollama list | awk -v n="$1" '$1 == n { print $2 }' }
# name_for ID -- a name to stop a loaded model by. Never the alias: once it is
# repointed, "gemma" resolves to the new target, not the model still loaded.
name_for() { ollama list | awk -v i="$1" -v a=$ALIAS '$2 == i && $1 != a { print $1; exit }' }

(( $# == 1 )) && [[ -n ${MODELS[$1]} ]] || die "usage: gemma-swap small|big"
target=$MODELS[$1]

target_id=$(id_of $target)
[[ -n $target_id ]] || die "$target is not pulled -- run: ollama pull $target"

loaded=( ${(f)"$(ollama ps | awk 'NR > 1 { print $2 }')"} )
if [[ $(id_of $ALIAS) == $target_id && $loaded == $target_id ]]; then
    print "gemma-swap: gemma is already $target and loaded"
    exit 0
fi

# Repoint first, unload second: from here on every request for "gemma" gets
# the target, so nothing can reload the old model in between.
ollama cp $target $ALIAS || die "ollama cp $target $ALIAS failed"

for id in $loaded; do
    [[ $id == $target_id ]] && continue
    name=$(name_for $id)
    if [[ -z $name ]]; then
        print -u2 "gemma-swap: loaded model $id has no name to stop it by -- skipping"
        continue
    fi
    ollama stop $name || print -u2 "gemma-swap: ollama stop $name failed"
done

# Preload, so the first real request doesn't wait for the load.
curl -sf --max-time 120 $API/api/generate -d "{\"model\":\"$ALIAS\"}" >/dev/null \
    || die "preloading $target as gemma failed"
print "gemma-swap: gemma -> $target, loaded"
```

Run: `chmod 755 machines/desktop/bin/gemma-swap && zsh -n machines/desktop/bin/gemma-swap`
Expected: no output.

- [ ] **Step 4: Verify against the live Ollama**

```bash
machines/desktop/bin/gemma-swap; echo "exit=$?"
```
Expected: `gemma-swap: usage: gemma-swap small|big`, `exit=1`.

```bash
machines/desktop/bin/gemma-swap small; echo "exit=$?"; ollama list; ollama ps
```
Expected: `gemma-swap: gemma -> gemma3:4b, loaded`, `exit=0`. `ollama list` shows `gemma:latest` with the same ID as `gemma3:4b`. `ollama ps` shows exactly one row, with the `gemma3:4b` ID and `100% GPU` (the 12b loaded in Step 1 is gone).

```bash
machines/desktop/bin/gemma-swap small; echo "exit=$?"
```
Expected: `gemma-swap: gemma is already gemma3:4b and loaded`, `exit=0`.

Mid-swap request (the client should either get an error or an answer, and the script must still succeed):

```bash
curl -s http://127.0.0.1:11434/api/generate -d '{"model":"gemma","prompt":"Count from 1 to 200.","stream":false}' | head -c 200 & 
sleep 1; machines/desktop/bin/gemma-swap big; echo "exit=$?"; wait; echo; ollama ps
```
Expected: `gemma-swap: gemma -> gemma3:12b, loaded`, `exit=0`; the curl prints either a JSON response or an error; `ollama ps` shows one row with the `gemma3:12b` ID at `100% GPU`.

- [ ] **Step 5: Commit**

```bash
git add machines/desktop/bin/gemma-swap
git commit -m "desktop: add gemma-swap to point the gemma alias at the small or big model"
```

---

### Task 3: systemd user unit and Ollama drop-in

**Files:**
- Create: `machines/desktop/systemd/user/gemma-gaming.service`
- Create: `machines/desktop/systemd/ollama.service.d/10-gemma.conf`

**Interfaces:**
- Consumes: `gemma-swap small|big` from Task 2.
- Produces: the two files Task 4 installs, at exactly these repo paths.

- [ ] **Step 1: Write the user unit**

`machines/desktop/systemd/user/gemma-gaming.service`:

```ini
# Swap Ollama's "gemma" alias to the small model while a gamescope session
# runs, and back to the big one when it ends, so games get most of the VRAM.
# Linked into ~/.config/systemd/user/ and enabled by machines/desktop/init.zsh.
#
# The "Steam Big Picture" session runs `gamescope-session-plus steam`, which
# starts and waits on gamescope-session-plus@steam.service. WantedBy= starts
# this unit with it; BindsTo= stops it whenever that service stops -- logout
# or crash -- which runs ExecStop.
[Unit]
Description=Swap Gemma to the small model while gamescope runs
BindsTo=gamescope-session-plus@steam.service
After=gamescope-session-plus@steam.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=%h/src/env/machines/desktop/bin/gemma-swap small
ExecStop=%h/src/env/machines/desktop/bin/gemma-swap big

[Install]
WantedBy=gamescope-session-plus@steam.service
```

- [ ] **Step 2: Write the drop-in**

`machines/desktop/systemd/ollama.service.d/10-gemma.conf`:

```ini
# Drop-in for the packaged ollama.service (ollama-cuda). COPIED, not linked,
# to /etc/systemd/system/ollama.service.d/ by machines/desktop/init.zsh:
# /home is its own partition and systemd reads drop-ins before it mounts.
# Edits here take effect after re-running init and restarting ollama.
#
# Keep models loaded until gemma-swap swaps them, and at every service start
# (so at boot, before any login) point the "gemma" alias back at the big model
# and preload it -- this also undoes a swap-to-small that never got swapped
# back because the machine shut down mid-gamescope. curl talks to the API
# because the unit runs as user ollama with ProtectHome=yes and can't run
# gemma-swap. "-": a failure (e.g. model not pulled) is logged but doesn't
# fail the service. --retry-delay 1 stays well inside the 90 s start timeout.
[Service]
Environment="OLLAMA_KEEP_ALIVE=-1"
Environment="OLLAMA_CONTEXT_LENGTH=16384"
ExecStartPost=-/usr/bin/curl -sf --retry 30 --retry-delay 1 --retry-connrefused http://127.0.0.1:11434/api/copy -d '{"source":"gemma3:12b","destination":"gemma"}'
ExecStartPost=-/usr/bin/curl -sf --retry 30 --retry-delay 1 --retry-connrefused http://127.0.0.1:11434/api/generate -d '{"model":"gemma"}'
```

- [ ] **Step 3: Verify both with systemd-analyze**

```bash
systemd-analyze verify --user machines/desktop/systemd/user/gemma-gaming.service
t=$(mktemp -d -p $SCRATCH)
cp /usr/lib/systemd/system/ollama.service $t/
mkdir $t/ollama.service.d && cp machines/desktop/systemd/ollama.service.d/10-gemma.conf $t/ollama.service.d/
SYSTEMD_UNIT_PATH="$t:" systemd-analyze verify $t/ollama.service
rm -rf $t
```

Expected: no errors about either file. (Warnings about unrelated system units are fine; any line naming `gemma-gaming.service` or `10-gemma.conf` is not.) If the user-unit verify complains that `gamescope-session-plus@steam.service` can't be found, that's a real problem — it's installed by `gamescope-session-git` at `/usr/lib/systemd/user/`.

- [ ] **Step 4: Commit**

```bash
git add machines/desktop/systemd
git commit -m "desktop: systemd units for the gamescope Gemma swap and boot preload"
```

---

### Task 4: Wire into desktop init and document

**Files:**
- Modify: `machines/desktop/init.zsh` (replace the trailing `# Local LLM server` block)
- Modify: `CLAUDE.md`
- Commit also: `machines/desktop/packages.txt` (user's `ollama-cuda` line)
- Test: `$SCRATCH/test-desktop-init.zsh` (throwaway) with stubs in `$SCRATCH/stubs/`

**Interfaces:**
- Consumes: `sudo_install_file` (Task 1, sets `REPLY`), `link_path` (existing), the two unit files (Task 3).

- [ ] **Step 1: Write stubs and the failing test**

`$SCRATCH/stubs/sudo` — logs instead of running anything as root:

```zsh
#!/usr/bin/zsh
print -r -- "STUB sudo $*" >> $STUB_LOG
```

`$SCRATCH/stubs/systemctl`:

```zsh
#!/usr/bin/zsh
print -r -- "STUB systemctl $*" >> $STUB_LOG
```

`$SCRATCH/stubs/ollama` — only `gemma3:12b` pulled:

```zsh
#!/usr/bin/zsh
print -r -- "STUB ollama $*" >> $STUB_LOG
[[ $1 == list ]] && print "NAME          ID              SIZE      MODIFIED\ngemma3:12b    b92b218582c5    8.2 GB    1 hour ago"
```

`$SCRATCH/test-desktop-init.zsh`:

```zsh
#!/usr/bin/zsh
# Runs the desktop role hook against a throwaway HOME with sudo/systemctl/ollama stubbed.
s=${0:h}
chmod +x $s/stubs/*
export HOME=$(mktemp -d -p $s) STUB_LOG=$s/stub.log ENV_DIR=/home/tradical/src/env PATH=$s/stubs:$PATH
: > $STUB_LOG
trap 'rm -rf "$HOME"' EXIT
fail() { print "FAIL: $*"; print "--- stub log"; cat $STUB_LOG; exit 1 }

out=$(zsh -c 'source $ENV_DIR/machines/desktop/init.zsh' 2>&1) || fail "hook returned $?: $out"
print -r -- $out

grep -q 'STUB sudo install -D -m644 .*/machines/desktop/systemd/ollama.service.d/10-gemma.conf /etc/systemd/system/ollama.service.d/10-gemma.conf' $STUB_LOG || fail "drop-in not installed"
grep -q 'STUB sudo systemctl daemon-reload' $STUB_LOG || fail "no daemon-reload"
grep -q 'STUB sudo systemctl enable --now ollama.service' $STUB_LOG || fail "ollama not enabled"
[[ $(readlink $HOME/.config/systemd/user/gemma-gaming.service) == $ENV_DIR/machines/desktop/systemd/user/gemma-gaming.service ]] || fail "user unit not linked"
grep -q 'STUB systemctl --user enable gemma-gaming.service' $STUB_LOG || fail "user unit not enabled"
[[ $out == *'gemma3:4b not pulled -- run: ollama pull gemma3:4b'* ]] || fail "no pull reminder for 4b"
[[ $out != *'gemma3:12b not pulled'* ]] || fail "false pull reminder for 12b"
print PASS
```

(The stubbed `sudo` makes `sudo_install_file` take the install path because `/etc/systemd/system/ollama.service.d/10-gemma.conf` doesn't exist yet on this machine. Run this before the user runs the real init.)

- [ ] **Step 2: Run it to verify it fails**

Run: `zsh $SCRATCH/test-desktop-init.zsh`
Expected: `FAIL: drop-in not installed`.

- [ ] **Step 3: Replace the ollama block in `machines/desktop/init.zsh`**

Replace everything from `# Local LLM server: ollama-cuda` to the end of the file with:

```zsh
# Local LLM server: ollama-cuda (machines/desktop/packages.txt) ships
# ollama.service but leaves it disabled. Our drop-in keeps models loaded and
# preloads the big Gemma at every service start, so it is loaded at boot with
# nobody logged in. The drop-in is COPIED (sudo_install_file), not linked:
# /home is its own partition and systemd reads drop-ins before it mounts.
# Skipped when the unit is missing -- e.g. --links-only on a box that never
# ran the package step.
if systemctl cat ollama.service &>/dev/null; then
    sudo_install_file "$ENV_DIR/machines/desktop/systemd/ollama.service.d/10-gemma.conf" \
        /etc/systemd/system/ollama.service.d/10-gemma.conf || return 1
    if [[ $REPLY == installed ]]; then
        sudo systemctl daemon-reload
        sudo systemctl try-restart ollama.service
    fi
    sudo systemctl enable --now ollama.service

    # Pulling is ~11 GB of network, which --links-only (this hook runs there
    # too) must not do -- so only remind.
    local -a pulled=( ${(f)"$(ollama list 2>/dev/null | awk 'NR > 1 { print $1 }')"} )
    local model
    for model in gemma3:12b gemma3:4b; do
        (( ${pulled[(Ie)$model]} )) || print "    $model not pulled -- run: ollama pull $model"
    done
else
    print "    ollama.service not installed (ollama-cuda missing?) -- skipping"
fi

# While a gamescope session runs, swap the "gemma" alias to the small model so
# games get the VRAM (machines/desktop/bin/gemma-swap). A user unit, so a link
# is fine: the user manager starts after /home is mounted.
link_path "$ENV_DIR/machines/desktop/systemd/user/gemma-gaming.service" \
    "$HOME/.config/systemd/user/gemma-gaming.service" || return 1
if ! { systemctl --user daemon-reload && systemctl --user enable gemma-gaming.service }; then
    print -u2 "    FAILED to enable gemma-gaming.service"
    return 1
fi
```

Note `try-restart` (restart only if running): on a first install, `enable --now` right after starts it with the drop-in already loaded.

- [ ] **Step 4: Run the test and syntax check**

Run: `zsh -n machines/desktop/init.zsh && zsh $SCRATCH/test-desktop-init.zsh`
Expected: hook output (including `installed /etc/systemd/system/ollama.service.d/10-gemma.conf`, `linked ...gemma-gaming.service`, `gemma3:4b not pulled ...`), then `PASS`.

- [ ] **Step 5: Update `CLAUDE.md`**

In the Layout bullet for `machines/desktop/`, `machines/laptop/`, change
`plus role-only config (desktop: `lightdm.conf.d/`, `bin/` with the headless Obsidian / Claude remote-control helpers).`
to
`plus role-only config (desktop: `lightdm.conf.d/`, `systemd/` (the `ollama.service` drop-in, copied to `/etc`, and the `gemma-gaming` user unit), `bin/` with the headless Obsidian / Claude remote-control helpers and `gemma-swap`).`

In "Desktop-only:", after `the gamescope rule,` insert `the local Gemma server (Ollama; the `gemma` alias is swapped to the small model while a gamescope session runs),`.

Replace step 12 with:
`12. `machines/<role>/init.zsh` — role hook (desktop: LightDM drop-in; copy the `ollama.service` drop-in to `/etc` with `sudo_install_file`, enable `ollama.service`, link + enable the `gemma-gaming` user unit, remind to `ollama pull` missing models)`

In "Linking rules", append:
`Files systemd reads at boot from `/etc` (unit drop-ins) are the exception: `/home` is a separate partition on the desktop and systemd reads units before it mounts, so a link into `~/src/env` would dangle. `sudo_install_file SRC DEST` copies them instead (no-op when identical; sets `REPLY=installed|unchanged` so the caller can `daemon-reload`). Editing such a file in the repo takes effect only after re-running init.`

- [ ] **Step 6: Commit**

```bash
git add machines/desktop/init.zsh machines/desktop/packages.txt CLAUDE.md
git commit -m "desktop init: install the Ollama drop-in and enable the gamescope Gemma swap"
```

(Do not add `machines/desktop/xprofile.sh`.)

---

### Task 5: User-run verification (needs sudo / a real session)

Not for the implementer — hand this checklist to the user after Task 4:

1. `ollama pull gemma3:4b` (skip if Task 2 already did).
2. `~/src/env/init/init.sh --links-only` — expect `installed /etc/systemd/system/ollama.service.d/10-gemma.conf`. Then `ollama ps`: `gemma:latest` at `100% GPU`, `UNTIL Forever`, context 16384. If it isn't `100% GPU`, lower `OLLAMA_CONTEXT_LENGTH`.
3. Log into the Steam Big Picture session; from another machine/TTY: `ollama ps` shows the 4b ID. `systemctl --user status gemma-gaming` is `active (exited)`.
4. Log out; `ollama ps` shows the 12b ID again.
5. Log in to gamescope, then `systemctl --user stop gamescope-session-plus@steam.service` (simulated crash); `ollama ps` shows the 12b ID.
6. Reboot and don't log in; from a TTY or ssh, `ollama ps` shows `gemma:latest` with the 12b ID at `100% GPU`.
