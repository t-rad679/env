---
name: tarot-export
description: Use when the user invokes /tarot-export — saving a tarot reading interpretation conversation from the current session to the Grimoire and linking it into that reading note's Reflection section.
---

# Tarot Export

## Overview

Thin wrapper around `grimoire-export` for one specific case: a conversation where you interpreted a tarot reading. Exports the conversation, then links the new note into the *original reading note's* `# Reflection` > `## Claude Code` subsection — the vault's fixed slot for exactly this (see `Tarot Reading Template.md`).

## Gate: did you actually interpret a reading this session?

Check first: did you produce a tarot reading interpretation earlier in *this* conversation (via `/interpret-tarot` or an ad hoc walk of a reading's cards)?

- **No** → Make no file changes. Tell the user you haven't interpreted a reading this session, offer to do one now, and ask them to give you the note (e.g. `@TarotReadings/DailyReadings/Daily TarotReading <date>.md`) if they want that.
- **Yes, exactly one** → proceed.
- **Yes, more than one** → ask which reading's interpretation to export before proceeding.

## Workflow

1. Identify the reading note you interpreted (path under `TarotReadings/`).
2. Invoke the `grimoire-export` skill to save this conversation — let it own title/frontmatter/message-format rules, don't duplicate that logic here. For the title specifically, match the pattern already used for tarot interpretation exports in this vault: `YYYY-MM-DD Daily Reading - <Theme A> and <Theme B>` (check a couple of existing `DailyReadings/` notes' `## Claude Code` links for the live pattern before naming — themes are evocative, not generic like "Tarot Interpretation").
3. Note the resulting note's title (the wikilink target).
4. Link it into the reading note: insert a bare `[[<Export Note Title>]]` wikilink **immediately** under the `## Claude Code` heading — no blank line between the heading and the link, matching the existing convention in already-linked `DailyReadings/` notes. Leave everything else untouched, especially `### My Response To Claude's Interpretation` — that's the user's own space.
   - If `## Claude Code` already has a link under it, don't duplicate it — tell the user it's already linked and ask before changing it.
   - Use `obsidian_patch_note` (append under the `Claude Code` heading) if Obsidian is open; raw `Edit` if closed — same rule as `interpret-tarot`'s write guidance.
5. Report the export path and the link you added.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Exporting when no interpretation happened this session | Don't. Offer to interpret, ask for the note instead. |
| Blank line between `## Claude Code` and the link | No blank line — bare wikilink directly under the heading |
| Generic export title ("Tarot Reading Export 2026-07-28") | Match the vault's `YYYY-MM-DD Daily Reading - <Theme> and <Theme>` pattern |
| Writing into `### My Response To Claude's Interpretation` | That's the user's section — only touch `## Claude Code` |
| Re-deriving grimoire-export's frontmatter/format rules here | Just invoke `grimoire-export` — don't duplicate its schema |
| Overwriting an existing link under `## Claude Code` | Check first; ask before replacing |
