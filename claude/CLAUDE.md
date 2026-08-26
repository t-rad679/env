# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, invoke the Skill tool with `skill: "graphify"` before doing anything else.

# Git Worktrees
- Worktrees should go in `~/src/.worktrees/<project-name>`.
- Use `gwt` to create new worktrees (not `git worktree add` directly).
- Use `wt` to switch between worktrees.

# Obsidian
- **Reads: prefer the Obsidian MCP servers** (`obsidian`, `obsidian-tools`) over built-in tools — search, get/list notes, tags, semantic search, etc.
- **Writes: use built-in tools (Read/Edit/Write), not the Obsidian MCP write tools** (`obsidian_write_note`, `obsidian_patch_note`, `obsidian_append_to_note`, `obsidian_replace_in_note`, `obsidian_delete_note`, `obsidian_manage_frontmatter`, etc.). The vault is a plain git repo of Markdown files on disk, so built-in tools work fine and — unlike the MCP write tools — surface a diff/permission prompt before the change lands.
- **Frontmatter array properties use the multiline (block) format, not inline brackets.** Write each item on its own `-` line:
  ```yaml
  related:
    - "[[Note A]]"
    - "[[Note B]]"
  ```
  Not `related: ["[[Note A]]", "[[Note B]]"]`. Applies to every array-valued property (`related`, `projects`, `contexts`, `tags`, etc.).

# Memory
- **mem0 is the primary memory store.** Write learnings, decisions, project state, and my preferences there via `add_memory` as they come up — no need to ask permission first.
- **Be proactive, not just reactive to bugs/gotchas.** Capture ongoing project state (in-progress reorgs, workflow changes, structural decisions) and my preferences (what I like when you do, tone/formatting/process choices I confirm or correct) — not only hard technical gotchas. If unsure whether something is memory-worthy, ask me rather than silently deciding either way.
- **Check mem0 often.** At minimum: when starting a new task, and whenever significant new information is revealed mid-conversation. Don't wait to be asked.
- **Mind the query budget.** mem0 search/write calls are rate-limited, so don't fire off redundant or overlapping searches — batch a few well-angled queries (e.g. 2-4 varied `search_memories` calls) when you genuinely need them rather than querying reflexively on every turn.
- **Local file-based memory (project `memory/` dir + `MEMORY.md`) is legacy.** Existing entries there are still valid context and worth reading, but don't write new ones — the `block_memory_write.sh` hook enforces this by blocking Edit/Write to `MEMORY.md`/`.claude/memory/*` and redirecting to mem0.
