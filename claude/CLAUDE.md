# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, invoke the Skill tool with `skill: "graphify"` before doing anything else.

# Git Worktrees
- Worktrees should go in `~/src/.worktrees/<project-name>`.
- Use `gwt` to create new worktrees (not `git worktree add` directly).
- Use `wt` to switch between worktrees.

# Obsidian
- **Frontmatter array properties use the multiline (block) format, not inline brackets.** Write each item on its own `-` line:
  ```yaml
  related:
    - "[[Note A]]"
    - "[[Note B]]"
  ```
  Not `related: ["[[Note A]]", "[[Note B]]"]`. Applies to every array-valued property (`related`, `projects`, `contexts`, `tags`, etc.).

# Memory
- **Default to local file-based memory** (the project `memory/` dir + `MEMORY.md` index). Use it freely — record to local memory at will whenever something is worth remembering, and read from it by default.
- **mem0 is available but secondary.** You may read from mem0 when it would genuinely help, but prefer local memory much more often.
- **Only write to mem0 when I explicitly tell you to.** Never record to mem0 on your own initiative; recording to local memory needs no permission.
