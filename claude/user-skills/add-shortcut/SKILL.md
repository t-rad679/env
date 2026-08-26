---
name: add-shortcut
description: Use when the user wants to launch a script or executable from Ulauncher by typing a keyword, e.g. "make X launchable from Ulauncher" or "add X to my launcher"
---

# Add Shortcut

## Overview

Ulauncher has a built-in "Shortcuts" feature (separate from its extension system) that maps a keyword to a command. Executables are added by editing `~/.config/ulauncher/shortcuts.json` directly — there is no CLI or UI requirement to use the Preferences window.

## Steps

1. **Verify the executable exists and is executable** before touching `shortcuts.json`:
   ```bash
   test -x /path/to/executable && echo ok
   ```
   If this fails, stop and tell the user — don't create a shortcut pointing at a missing or non-executable file.

2. **Add an entry** to `~/.config/ulauncher/shortcuts.json` via Python (safer than hand-editing — avoids invalid JSON and UUID collisions):
   ```python
   import json, uuid, time, os
   path = os.path.expanduser("~/.config/ulauncher/shortcuts.json")
   with open(path) as f:
       data = json.load(f)
   new_id = str(uuid.uuid4())
   data[new_id] = {
       "id": new_id,
       "name": "Display Name",
       "keyword": "keyword",
       "cmd": "/absolute/path/to/executable",
       "icon": "/absolute/path/to/icon.png",  # or "" if none available
       "is_default_search": False,
       "run_without_argument": True,
       "added": time.time(),
   }
   with open(path, "w") as f:
       json.dump(data, f, indent=4)
   ```
   - `cmd` must be an absolute path, not a URL — Ulauncher writes it verbatim into a temp file, `chmod`s it executable, and shell-execs it. A plain path with no shebang still works (the shell just runs it as a command line).
   - `run_without_argument: true` makes the shortcut fire on Enter with no typed argument.
   - Entries are also fuzzy-matched by `name` in Ulauncher's default search, not just by exact `keyword` — so the keyword doesn't need to be memorable, just unique.
   - `icon` is optional; an empty string falls back to Ulauncher's default executable icon. If the target has a colocated icon/logo image, prefer it.

3. **Restart Ulauncher** so it picks up the change — it reads `shortcuts.json` once into an in-memory singleton at process start and does not watch the file, so edits are invisible to a running instance until restart:
   ```bash
   pkill -f "python.*ulauncher"
   sleep 1
   nohup ulauncher --hide-window > /tmp/ulauncher.log 2>&1 & disown
   sleep 2
   ```
   **Run the relaunch line with your tool's explicit background-execution option** (e.g. Claude Code's Bash tool `run_in_background: true`), not just shell `&`/`disown` in a plain foreground call — a plain foreground call gets its child process killed when the tool call returns, silently leaving Ulauncher dead despite `disown`. Then verify with an unambiguous process match (a loose pattern like `"python.*ulauncher"` will false-positive on your own verification command):
   ```bash
   pgrep -fa "^/bin/python /usr/bin/ulauncher"
   ```
   If nothing matches, the restart didn't take — retry with proper backgrounding before considering the shortcut done.

## Common mistakes

- Using a relative path or shell alias in `cmd` — use the absolute path to the executable.
- Hand-editing the JSON with sed/manual string ops — easy to break JSON syntax or duplicate an `id`; use the Python snippet above.
- Forgetting the restart — the new shortcut silently won't appear no matter how correct the JSON is.
