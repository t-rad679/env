---
name: grimoire-export
description: Use when the user asks to save, export, or archive a conversation/chat/LLM session as a note in their Obsidian vault Grimoire (typically under "Conversations/LLM Chats/Claude Code/"). Captures specific frontmatter, filename, and message-formatting conventions — do not invent your own.
---

# Exporting Conversations to Grimoire

## Overview

Save the current conversation as an Obsidian note in the user's Grimoire vault following exact conventions. **Do not invent fields, sections, or formatting** — the user has specific patterns and deviations are noise.

## Destination

- **Path**: `Conversations/LLM Chats/Claude Code/<Descriptive Title>.md`
- **Filename**: a descriptive title summarizing the conversation's substance. Date prefix when natural (`2026-05 New Moon Reading - Bridges and Create-X Pivot.md`). **Not** the topic in one word (`sourdough.md`), **not** an auto-timestamp pattern (`Help_me_with_X@20260518_143000.md`).
- **Create parent directories** with `mkdir -p` if missing. Raw `Write` is safe for new files (no Obsidian autosave race).

## Frontmatter — Exact Schema

```yaml
---
participants:
  - "[[Me]]"
  - "[[Claude Code]]"
date: YYYY-MM-DD
medium: Terminal
createdDate: YYYY-MM-DD HH:MM
lastModifiedDate: YYYY-MM-DD HH:MM
relatedGoals:
relatedProjects:
---
```

**Rules:**
- `participants`: user is **always `[[Me]]`** (never their first name). Assistant is `[[Claude Code]]` (with the wikilink brackets).
- `medium`: the interface in title case. `Terminal` for Claude Code CLI. Match the actual surface (`Cursor`, `Zed`, `Web`) if different.
- `createdDate` / `lastModifiedDate`: `YYYY-MM-DD HH:MM` (no seconds). Note the `lastModifiedDate` spelling — not `modifiedDate`.
- `relatedGoals` and `relatedProjects`: **leave empty** (bare key, no value, no `null`, no `[]`). After saving, **suggest** specific values you noticed from the conversation — do not populate silently.
- **Do not add fields not on this list.** No `tags`, `topics`, `summary`, `model`, `source`, `title` — the user does not use these on LLM chat notes.

## Message Format

```markdown
# YYYY-MM-DD HH:MM — Me

[user message body]

---

# YYYY-MM-DD HH:MM — Claude Code

[assistant message body]

---
```

- Each message: a top-level `# heading` with timestamp and sender.
- **Sender labels in headings:** `Me` for the user, `Claude Code` for the assistant. (Yes — `[[Me]]` in frontmatter but bare `Me` in headings.)
- **Separator:** horizontal rule (`---`) between messages.
- **No extra sections.** No `## Conversation` wrapper, no `## Summary`, no `## Takeaways`, no `## Follow-ups`, no `> [!info]` callouts. Just frontmatter, then alternating message blocks.
- Preserve `[[wikilinks]]` from the conversation body. If a notable note/person is referenced without a wikilink (e.g. `Katie Dukes`, `Create-X`), wikilinking it on save is welcome.

## Timestamps

You usually don't know exact send times.

1. Use today's date (from environment `currentDate`).
2. Pick a plausible starting time for the first user message.
3. Increment by a few minutes per subsequent message.
4. After saving, mention you approximated and offer to adjust.

## What to Include / Exclude

**Include**: the user's substantive messages, the assistant's substantive responses, code blocks, diagrams, formatting from responses.

**Exclude**: raw tool-call output, intermediate scratch work, system reminders, hook output, environment metadata. If the assistant showed reasoning/process *as part of the response prose*, keep it.

## Workflow

1. **Pick a title** — brief, descriptive. If unsure between two, pick one and mention it.
2. **`mkdir -p`** the parent if needed.
3. **Write** the file with the exact frontmatter schema above and the message format.
4. **Report**: file path, the choices you made (title, approximated timestamps, sender labels), and specific `relatedGoals`/`relatedProjects` candidates you noticed — phrased as a suggestion, not an action ("I noticed this touches `[[Project Pinstripe]]` — want me to add it?").

## Common Mistakes

| Mistake | Fix |
|---|---|
| User heading says `Trevor` / `User` | Always `Me` |
| Participant says `[[Trevor]]` | Always `[[Me]]` |
| Assistant participant unwrapped (`Claude Code`) | Use `[[Claude Code]]` |
| `modifiedDate` instead of `lastModifiedDate` | Use `lastModifiedDate` exactly |
| `relatedProjects: null` or `[]` | Leave bare: `relatedProjects:` then newline |
| Filename is one-word topic | Use a descriptive summary title |
| Added Summary / Takeaways / Follow-ups | Delete them — body is just messages |
| Added `tags`, `topics`, `model`, etc. | Schema is exactly the 7 fields above |
| Used `### Speaker` for messages | Use `# YYYY-MM-DD HH:MM — Name` + `---` separator |
| Used `terminal CLI` for medium | Use `Terminal` (title case) |
| Populated `relatedProjects` without asking | Leave empty; suggest specific values after saving |

## Example

For a 2026-05-18 conversation about interpreting a tarot reading:

**Path:** `Conversations/LLM Chats/Claude Code/2026-05 New Moon Reading - Bridges and Create-X Pivot.md`

```markdown
---
participants:
  - "[[Me]]"
  - "[[Claude Code]]"
date: 2026-05-18
medium: Terminal
createdDate: 2026-05-18 14:30
lastModifiedDate: 2026-05-18 14:30
relatedGoals:
relatedProjects:
---

# 2026-05-18 14:30 — Me

Help me interpret the [[2026-05 New Moon Reading]]...

---

# 2026-05-18 14:35 — Claude Code

Here's my read on the spread...

---

# 2026-05-18 14:48 — Me

Save this conversation to my Grimoire...
```

After saving: "Saved. I approximated timestamps starting at 14:30. I noticed this touches `[[Create-X]]` and `[[Project Pinstripe]]` — want me to add either to `relatedProjects`?"
