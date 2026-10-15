# Git Worktrees
- Worktrees should go in `~/src/.worktrees/<project-name>`.
- Use `gwt` to create new worktrees (not `git worktree add` directly).
- Use `wt` to switch between worktrees.

# Obsidian
- **Reads: prefer the Obsidian MCP servers** (`obsidian`, `obsidian-tools`) over built-in tools — search, get/list notes, tags, semantic search, etc.
- **Writes: use built-in tools (Read/Edit/Write), not the Obsidian MCP write tools** (`obsidian_write_note`, `obsidian_patch_note`, `obsidian_append_to_note`, `obsidian_replace_in_note`, `obsidian_delete_note`, `obsidian_manage_frontmatter`, etc.). The vault is plain Markdown files on disk, so built-in tools work fine and — unlike the MCP write tools — surface a diff/permission prompt before the change lands.
- **Frontmatter array properties use the multiline (block) format, not inline brackets.** Write each item on its own `-` line:
  ```yaml
  related:
    - "[[Note A]]"
    - "[[Note B]]"
  ```
  Not `related: ["[[Note A]]", "[[Note B]]"]`. Applies to every array-valued property (`related`, `projects`, `contexts`, `tags`, etc.).

# Trilium
- Refer to Trilium notes by their names, not their IDs. If there is ambiguity, give a partial path (e.g. `Decisions → Cycle 2 → [Note Name]`).

# Machines
- I use two Arch Linux machines running i3: a desktop and a spellbook. Both are provisioned from the env repo at `~/src/env` (i3 config at `~/src/env/config/i3/`, with role-only i3 config under `~/src/env/machines/<role>/i3/`).
- `$MACHINE_ROLE` (`desktop` or `spellbook`, from `~/.config/machine-role.env`; defaults to `desktop` when unset) says which machine a shell is on; desktop-only things (gaming, headless Obsidian, Claude remote control, the HDMI-3 greeter config) live under `~/src/env/machines/desktop/`.
- **Check which machine you're on whenever it could matter — never assume.** Read `$MACHINE_ROLE`, or `cat ~/.config/machine-role.env` when the variable is unset. An unset variable is *not* evidence of a desktop: the `${MACHINE_ROLE:-desktop}` fallback throughout the repo is a provisioning default, so check the role file instead of inferring from the empty value. It's relevant more often than it looks — which packages and binaries are installed, i3-on-X vs niri-on-Wayland, which `machines/<role>/` files apply, monitor layout, and whether something you found running locally exists on the other box at all.

# Shell Scripts
- Always write shell scripts in zsh (`#!/usr/bin/zsh`) whenever possible, not bash. This applies to every script file you create or edit, in any project, unless something specifically requires bash/sh (e.g. a tool only sources `.bashrc`-style files, or a system hook like `.xprofile` must stay POSIX-compatible) — if so, say why before deviating.

# Sudo
- `sudo` in the Claude Code Bash tool has no TTY to read a password — it always fails with "a password is required." Don't attempt sudo commands directly (including retries, askpass tricks, or the `!` prefix — that doesn't work for this either).
- Instead, just give me the exact command(s) to run myself in a separate terminal.

# Memory
- **mem0 is the primary memory store.** Learnings, decisions, project state, and my preferences belong there.
- **Check mem0 often.** At minimum: when starting a new task, and whenever significant new information is revealed mid-conversation. Don't wait to be asked.
- **Mind the query budget.** mem0 search/write calls are rate-limited, so don't fire off redundant or overlapping searches — batch a few well-angled queries (e.g. 2-4 varied `search_memories` calls) when you genuinely need them rather than querying reflexively on every turn.
- **Local file-based memory (project `memory/` dir + `MEMORY.md`) is legacy.** Existing entries there are still valid context and worth reading, but don't write new ones — put new memories in mem0 instead.
