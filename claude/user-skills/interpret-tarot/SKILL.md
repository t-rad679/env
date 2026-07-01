---
name: interpret-tarot
description: Use when the user asks for an interpretation, reading, or "what do you think" about a tarot reading note in their Obsidian vault Grimoire (typically under `TarotReadings/`, including `DailyReadings/` and `MonthlyReadings/`). Triggers on phrases like "interpret this reading", "what does this spread mean", "read this for me", or when the user shares a tarot reading note and asks for input.
---

# Interpreting Tarot Readings in the Grimoire

## Overview

Interpret a tarot reading note from the vault by weaving together the user's own card definitions and relevant context from the Grimoire with established traditions like Rider-Waite-Smith. Both are real inputs — the Grimoire notes carry the user's personal vocabulary and lived context; RWS and other established meanings carry the symbolic load the deck was designed around. If the user already wrote their own interpretation, engage with it specifically.

**Core principle:** The user's `TarotCards/<Card>.md` notes are their personal vocabulary; RWS and other traditions are the broader symbolic vocabulary. Draw on both without ranking them. Where the user's framing departs from convention, surface that — it's interpretively useful. The user's `# Interpretation` section is a real interpretation that deserves a substantive response, not a polite nod.

## What a Reading Note Looks Like

Schema: `Types/TarotReading.md`. Folder: `TarotReadings/` (most daily ones live in `TarotReadings/DailyReadings/`).

**Frontmatter:** `moonPhase`, `querents`, `readers`, `decks`, `dateTime`, `spread` (often empty for free draws). Querents/readers link to `People/`, decks to `TarotDecks/`, spread to `TarotSpreads/`.

**Body sections (in order):**
- `# Cards` — wikilinks to `TarotCards/` notes. Layout varies: numbered list, "First row / Second row / Third row", or labeled positions ("Stay with X:", "Advice:", "Clarifier:"). Read the layout carefully — position matters.
- `# Interpretation` — the user's own first-pass interpretation. May be empty.
- `# Reflection` — for after-the-fact reflection. Usually empty at reading time.
- `# Picture` — embed of the actual cards.

**Reversed cards are separate notes.** `Ace of Cups Reversed.md` is distinct from `Ace of Cups.md`. The wikilink in the reading tells you which one.

## Workflow

1. **Read the reading note in full** — frontmatter, every card link, every section.
2. **Read each card note** at `TarotCards/<Card Name>.md`. The prose body is the user's personal definition — weave it together with RWS / other traditional meanings. Note where they reinforce each other, where one adds nuance the other misses, or where they diverge (divergences are worth surfacing in the interpretation). If a card note is missing or empty, silently lean on tradition for that card — **don't** narrate the gap to the user. They already know what they have and haven't written; calling it out is noise.
3. **Read the spread note** at `TarotSpreads/<Spread>.md` if `spread:` is set. Position meanings matter (e.g., past/present/future, option 1/option 2/advice).
4. **Gather Grimoire context.** Reach for semantic search (`obsidian-tools.search_vault_smart`) smartly to surface relevant notes — it's the right tool when you don't know the exact terms ("anything about feeling disconnected", "recent dreams involving water") and is how you find context the reading is entangled with but isn't named outright. Mix it with exact-match tools as appropriate; not every search has to be semantic. First fix the **reading date** (see below), then search for and read notes for:
   - **People** mentioned in the user's interpretation (e.g., `[[Katie Dukes]]` → `People/Katie Dukes.md`)
   - **Projects/goals** mentioned (e.g., `[[Project Pinstripe]]`)
   - **Recent readings** — for a daily reading, check the 2–3 most recent `DailyReadings/` notes for narrative continuity. Tarot often tells a story across days.
   - **Recent DailyChronicles and DailyWorkLogs leading up to the reading date** — read the few days of `Chronicles/Daily/DailyChronicle <date>.md` and `TinkerTask/DailyWorkLogs/DailyWorkLog <date>.md` notes immediately preceding (and including) the reading date. These are the user's lived day-to-day — what was actually going on, what they were working on, how they felt — and are the single best source of grounding for what the reading is reacting to. Read them by default for a daily reading, not just when the interpretation hints at them.
     - **The reading date** is the date the reading was *done* — default it to the date of the user's query (today's date from session context), **unless** the user says otherwise or the note's `dateTime` frontmatter clearly indicates a different day. "Leading up to" means the handful of days *before and including* that date; don't pull chronicles/worklogs from after it.
   - **Recent ritual logs, dreams, journal entries** if the user's interpretation hints at them or asks "what's going on with me"
   - **Tool choice for searching:**
     - **Semantic / fuzzy / conceptual** ("anything about feeling disconnected from emotions", "recent dreams involving water") → `obsidian-tools.search_vault_smart` (jacksteamdev server) — this is the semantic search and is the right default when you don't know exact terms.
     - **Structured / exact** (a specific filename, tag, frontmatter property, Dataview query) → `obsidian.obsidian_search_notes` (cyanheads server).
     - **Reading a known file** → `obsidian.obsidian_get_note` if Obsidian is open (autosave-safe), or `Read` directly if it's closed.
5. **Read the user's `# Interpretation`** carefully. Note what they connected, what they didn't, what they seemed uncertain about, what they explicitly left out.
6. **Compose the interpretation.** Default to a conversational reply. Structure:
   - **Engage with the user's interpretation first** if it exists — agree, expand, gently push back, or surface something they missed. Be specific: quote or paraphrase a particular line of theirs. Don't restate their interpretation back to them.
   - **Walk the spread** — card by card or row by row, using *their* card definitions and the spread's positions. Note pairings and contradictions across the spread.
   - **Weave in Grimoire context** — when [[Katie Dukes]] is in the interpretation, draw on what's in her note and recent readings about her. Cite the source so the user can follow up (`from your recent [[Daily TarotReading 2026-05-13]]…`).
   - **Be honest about uncertainty.** When the symbolism is ambiguous or the spread position underdetermined, hedge the interpretation rather than overstating. (But don't surface *which card notes* are sparse — that's noise. Hedging is about the *reading*, not the source materials.)

## Where to Write the Output

**Default:** conversational reply in chat. Don't modify the note unless asked.

**If asked to save it:** offer the `# Reflection` section, not `# Interpretation` (which is the user's space). Use `obsidian_patch_note` (append under heading) to avoid racing Obsidian's autosave. If Obsidian is closed, `Edit` is fine.

## What "Relevant Context" Means Here

This vault tracks ritual observances, dreams, synchronicities, relationships, and projects. Tarot readings are entangled with all of it. Good context-gathering looks like:
- Check `People/<Name>.md` for anyone the user mentions in their interpretation
- Check the few `DailyChronicle` entries under `Chronicles/Daily/` and `DailyWorkLog` entries under `TinkerTask/DailyWorkLogs/` for the days leading up to (and including) the reading date — by default for a daily reading, since they're the best record of what the reading is reacting to. The reading date defaults to the day of the user's query unless they say otherwise
- Check the prior 2–3 daily readings — recurring cards or themes matter
- Don't dump everything you find. Cite what's load-bearing for the interpretation.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Treating Grimoire notes and tradition as either/or | Weave both together. Use the user's card notes for personal vocabulary and lived framing; use RWS/tradition for symbolic depth. Surface divergences |
| Narrating that a card note is missing or sparse ("you don't have a Nine of Swords Reversed note…") | Silently fall back to RWS/tradition. The user knows what they have and haven't written — calling it out is noise |
| Defaulting to `Read` / grep for vague conceptual searches | Use `obsidian-tools.search_vault_smart` for semantic queries; reach for exact-match tools only when you know the precise term |
| Treating reversed cards as the upright + "but reversed" | They have their own notes. Read them. |
| Ignoring the user's `# Interpretation` | Engage with it specifically — quote a line, agree/expand/push back |
| Restating the user's interpretation back as if it were yours | Build on it, don't paraphrase it |
| Skipping `# Cards` layout (rows, position labels) | Position is meaning. "Advice" cards mean something different than "Outcome" cards |
| Not searching for `[[People]]` and `[[Projects]]` referenced | Those notes are the context that makes the reading personal |
| Writing into `# Interpretation` | That's the user's section. Use `# Reflection` if asked to save |
| Confabulating context ("you mentioned X recently") without checking | Search first. If you can't find it, don't claim it |
| Treating a free-draw (no `spread:`) like a Celtic Cross | When `spread:` is empty, position meaning is whatever the user said it is in their interpretation — or just card order |
| Generic "this card represents X energy" prose | Specific: "Your note on the Two of Wands frames it as 'planning following inspiration' — that fits where you wrote you're trying to escape the anxiety of the Nine of Swords Reversed" |

## Quick Reference

- **Card meanings:** `TarotCards/<Card Name>.md` (reversed is a separate note) woven together with RWS/tradition — neither ranks over the other
- **Spread positions:** `TarotSpreads/<Spread>.md` when `spread:` is set
- **People:** `People/<Name>.md` for anyone in the interpretation
- **Recent context:** 2–3 prior notes in `TarotReadings/DailyReadings/` for daily reads, plus the few `Chronicles/Daily/DailyChronicle <date>.md` and `TinkerTask/DailyWorkLogs/DailyWorkLog <date>.md` notes leading up to the reading date
- **Reading date:** the date the reading was done — defaults to the day of the user's query unless they say otherwise (or the note's `dateTime` says so)
- **Write destination:** chat by default; `# Reflection` if asked to save
- **Search tools:**
  - Semantic / fuzzy → `obsidian-tools.search_vault_smart`
  - Structured / exact (tags, paths, frontmatter, Dataview) → `obsidian.obsidian_search_notes`
  - Known file → `obsidian.obsidian_get_note` (Obsidian open) or `Read` (Obsidian closed)
- **Write tools:** `obsidian.obsidian_patch_note` (append under heading) if Obsidian is open; `Edit` if closed

## Example Opening (Style Reference)

> Read your spread. Before I walk it, one thing on your interpretation — you read the Two of Wands as the way *out* of the Nine of Swords Reversed anxiety, but your card note frames Two of Wands as the *beginning* of a journey, post-inspiration. That reframes it: the planning isn't the relief, it's what the relief is *for*. The anxiety lifting (Nine of Swords Reversed) is what's freeing you to plan in the first place.
>
> On Strength Reversed in that first row — you wondered if it's telling you not to rely on Strength right now. Your Strength note says [whatever it says]. Combined with the [[Katie Dukes]] thread that's been running through your last three daily readings ([[Daily TarotReading 2026-05-13]], [[Daily TarotReading 2026-05-16]]…), I'd read it as…
