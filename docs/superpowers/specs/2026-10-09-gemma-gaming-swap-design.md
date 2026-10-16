# Gemma gaming swap — design

Date: 2026-10-09. Desktop role only.

## Goal

The desktop (RTX 4070 Ti, 12 GB VRAM) serves Gemma through Ollama on
`localhost:11434`. Outside gaming, the big model (`gemma3:12b`, ~9.5 GB VRAM)
is loaded at all times, including on a fresh boot before anyone logs in. While
a gamescope session is running, the small model (`gemma3:4b`, ~4 GB VRAM, on
the GPU) answers instead, so games get ~8 GB. Clients keep using the same port
and model name and see only a few seconds of interruption at each swap.

## Decisions

- **Small model runs on the GPU** (`gemma3:4b`). Moving it to the CPU is a
  later option if games need the full card.
- **Only gamescope triggers the swap.** Games launched from i3 do not; outside
  gamescope the big model stays loaded (`OLLAMA_KEEP_ALIVE=-1`).
- **Routing is by alias, by convention.** Clients request the model `gemma`,
  which is an Ollama alias pointing at one of the two models. A client that
  requests `gemma3:12b` by name during gamescope loads the big model into
  whatever VRAM is free (Ollama has no way to refuse a model). Accepted risk;
  a proxy that remaps names was considered and rejected as unnecessary for
  clients under the user's control.

## Components

### 1. `machines/desktop/bin/gemma-swap` (zsh)

`gemma-swap small|big` points the alias `gemma` at `gemma3:4b` or
`gemma3:12b`. On `PATH` via `config/zsh/env/path.zsh`; also usable by hand.
Talks only to the Ollama API/CLI, so it needs no root.

Order (shown for `small`; `big` swaps the two model names):

1. Check `gemma3:4b` is pulled (`ollama show`); if not, exit 1 with
   "run: ollama pull gemma3:4b".
2. If `gemma` already has the target's digest and is loaded, exit 0.
3. `ollama cp gemma3:4b gemma` — from here every new `gemma` request resolves
   to the target.
4. `ollama stop gemma3:12b` — frees the other model's VRAM (ignore "not
   running"). Repointing before stopping closes the window in which a request
   could reload the old model.
5. Preload: `POST /api/generate {"model":"gemma"}` (empty prompt).

Each step's failure exits non-zero with a message on stderr (the journal, when
run from the unit).

### 2. `machines/desktop/systemd/user/gemma-gaming.service` (user unit)

```ini
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

The "Steam Big Picture" session runs `gamescope-session-plus steam`, which
starts and waits on `gamescope-session-plus@steam.service`. `WantedBy=` starts
this unit with it; `BindsTo=` stops it whenever that service stops — logout or
crash — which runs the swap back to big.

Linked into `~/.config/systemd/user/` (fine: the user manager starts after
`/home` is mounted).

### 3. `machines/desktop/systemd/ollama.service.d/10-gemma.conf` (system drop-in)

```ini
[Service]
Environment="OLLAMA_KEEP_ALIVE=-1"
Environment="OLLAMA_CONTEXT_LENGTH=16384"
ExecStartPost=-/usr/bin/curl -sf --retry 30 --retry-delay 1 --retry-connrefused http://127.0.0.1:11434/api/copy -d '{"source":"gemma3:12b","destination":"gemma"}'
ExecStartPost=-/usr/bin/curl -sf --retry 30 --retry-delay 1 --retry-connrefused http://127.0.0.1:11434/api/generate -d '{"model":"gemma"}'
```

- `ollama.service` is a system unit enabled under `multi-user.target`, so this
  loads the big model at boot with no login.
- The copy resets `gemma` to the big model on every service start, covering a
  shutdown in the middle of gamescope (where the swap back can race Ollama
  stopping).
- It calls the API with `curl`, not `gemma-swap`, because the packaged unit
  runs as user `ollama` with `ProtectHome=yes`.
- **Copied, not linked.** `/home` is a separate partition on the desktop, and
  systemd reads unit files and drop-ins before `/home` is mounted; a symlink
  into `~/src/env` would be dangling then, silently dropping the boot preload.
- Both `ExecStartPost` lines are `-`-prefixed: a failure (e.g. `gemma3:12b`
  not pulled yet) is logged but must not fail `ollama.service` itself.
  `--retry-delay 1` keeps the retries well inside the 90 s start timeout.
- `OLLAMA_CONTEXT_LENGTH=16384` must leave the big model at `100% GPU` in
  `ollama ps`; lower it if not.

### 4. `init/lib.zsh`: `sudo_install_file SRC DEST`

New helper beside `sudo_link_path`: no-op if `DEST` already has identical
contents (`sudo cmp -s`); otherwise `sudo install -D -m644 SRC DEST` and print
`installed DEST`. Sets `REPLY=installed` or `REPLY=unchanged` so the caller
knows whether to `daemon-reload`; returns non-zero with a `FAILED ...` line on
stderr when the copy fails — same reporting rules as the link helpers.
A replaced real file is not backed up (the destination is owned by this repo).

Editing the drop-in in the repo takes effect only after re-running init
(`--links-only` is enough) and restarting Ollama; init's `installed` line makes
a stale copy visible.

### 5. `machines/desktop/init.zsh` additions

Replace the current `systemctl enable --now ollama.service` block with:

1. If `ollama.service` exists: `sudo_install_file` the drop-in to
   `/etc/systemd/system/ollama.service.d/10-gemma.conf`; on change,
   `sudo systemctl daemon-reload` and `sudo systemctl restart ollama.service`;
   then `sudo systemctl enable --now ollama.service`.
2. `link_path` the user unit into `~/.config/systemd/user/`,
   `systemctl --user daemon-reload`, `systemctl --user enable gemma-gaming.service`.
3. If `gemma3:12b` or `gemma3:4b` is missing from `ollama list`, print a
   reminder to `ollama pull` it. No pulling from init: the role hook also runs
   in `--links-only` mode, which must not hit the network.

`CLAUDE.md` step 12 and the desktop layout notes are updated to match.

## Failure modes

| Situation | Result |
|---|---|
| Ollama down when gamescope starts | Swap fails, unit marked failed, gaming unaffected; `journalctl --user -u gemma-gaming` |
| gamescope crashes | `BindsTo=` still runs the swap back to big |
| Shutdown during gamescope, swap back fails | Next boot's `ExecStartPost` resets `gemma` to big |
| Request in flight during a swap | Cut off with an error |
| Request arriving during a swap | Waits for the load, answered by the new model |
| Client requests `gemma3:12b` by name while gaming | Loads into free VRAM (accepted risk) |
| A model was never pulled | Swap fails with a pull message; init warns |

## Testing

From Claude's shell (no sudo):

- `zsh -n` on `gemma-swap`, `init/lib.zsh`, `machines/desktop/init.zsh`.
- `systemd-analyze verify` on the user unit and the drop-in.
- `sudo_install_file` against a throwaway directory with `sudo` stubbed.
- `gemma-swap small` / `big` for real, watching `ollama ps` and `nvidia-smi`,
  with a `curl` request to `gemma` sent mid-swap.

By the user:

1. `ollama pull gemma3:4b`.
2. Run init (copies the drop-in; needs sudo).
3. Log into gamescope and out, checking `ollama ps` each time.
4. Simulate a crash: `systemctl --user stop gamescope-session-plus@steam.service`,
   then check `ollama ps`.
5. Reboot; before logging in (e.g. over ssh or a TTY), `ollama ps` should show
   `gemma` at `100% GPU`.

## Out of scope

- Swapping for games launched from i3 (possible later via GameMode hooks).
- A proxy that enforces the swap for clients that hardcode model names.
- The laptop's autorandr drop-in is also linked into `/etc/systemd/system`; if
  the laptop has a separate `/home`, it has the same early-boot problem. To be
  checked separately.
