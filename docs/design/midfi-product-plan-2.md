# mid-fi plan · the rest of the product: Goals, You, Settings, outside the app

20 Oct. This follows the design engineering process ([design-system/process.md](../../design-system/process.md)), Part 1, top-down: flow → page → component → sub-component. Everything stays grey boxes and real words. The plan gate comes next: the founder approves the order and the purposes before any hi-fi build.

Sources read: blueprint GL-1–EX-4; the 16 product goals; screen rules 1–33; component specs (goal, you-map, settings-row, source-row, switch, segmented, guess-card, sheet-and-dialog, lock-screen-and-widget, loading-and-empty); memory (search v1 shape, ambient switch, Settings behind your picture on You); the founder's comments so far (audio first; stage tags pass, they don't stand; draw real content when the purpose isn't obvious).

---

## 1 · Flows

| Flow | The person's goal, in one sentence | Pages, and the move between them | Data, and when it isn't there |
|---|---|---|---|
| **Goals** | "see whether I'm doing what I say matters" | GL-1 goals → (tap a goal) push → GL-2 a goal · (+) sheet: add a goal by voice or text · (tap a guess) answer in place | /goals (✓); said-vs-did (✗ K2). Empty: "nothing yet: say what you're working toward, or wait and i'll notice." Too early: "too early to tell" in place of the numbers. Failing: last known, marked. |
| **You** | "see the picture it has of me, and ask it anything" | YO-1 you → (type or speak) push → YO-2 results → (a source) push → YO-3 a source · YO-1 → (tap a node) sheet → YO-4 a node · YO-1 → (what I know) push → YO-5 · YO-1 → (the waiting node or row) sheet → YO-6 · picture (top-left) → ST-1 | map (✗ K2), search (◐), people/hypotheses (◐), read contract (✗). Day one: a thin map that says so. Search abstains plainly. Offline: last map, search waits. |
| **Settings** | "control what it does, in one calm list" | ST-1 settings → push → ST-2 … ST-9 · destructive rows open a dialog | /integrations ✓, /profile ✓, the rest ◐/✗. Each row shows its value, or says it isn't set. |
| **Outside the app** | "save things, keep listening, and hear when something's ready, without opening it" | EX-1 share sheet (from any app) · EX-2 lock screen while playing · EX-3 a notification → opens the right page · EX-4 widget → plays the brief, or opens the composer | Share offline: queued and marked. Notifications: at most one a day, nothing at night, private by default. Widget: "being made" before the brief exists. |

**One purpose per page** (checked): every page below has one sentence. Where the blueprint had two purposes on a page (none found), it would split.

---

## 2 · Pages

Each page: content in the order the person came for, the one lit action (or none), and its regions with their z-level.

### Goals
- **GL-1 goals** — *What you're working toward, as it sees it.* Content first: goal cards, newest-moving first. Each card: your words, said and did as two plain lines with numbers, one line from Retro. A goal Retro only heard (never said outright) is a dashed guess card with yes / not quite. Then one row: "faded 2 · merged 1 ›". Lit: none (adding is a quiet + in the top bar, because the main job is reading). Regions: page (0) · goal cards (card) · guess card (wash, dashed) · tab bar (floating).
- **GL-2 a goal** — *Everything behind one goal.* Title = the goal in your words. Said: first said, last mentioned, how many times. Did this week: dated evidence rows, each with not right. A pattern Retro sees is a guess (dashed). Bottom: rename · turn off (quiet pills; turning off isn't a failure, goal rule 3). Lit: none.

### You
- **YO-1 you** — *See the picture it has of you, and ask it anything.* Top bar: your picture (opens Settings) · "you" · list view. Search field (mic first) on top, because asking is the most direct use. The map fills the page (24 nodes at most; one waiting node glows quietly). Under it: "what i know about you ›" and, when there is one, "one question waiting ›". Lit: none (the field is the action, raised, not lit).
- **YO-2 results** — *An answer from your own mind, with its receipts.* The query stays in the field. Written synthesis on top: 2–5 sentences, each claim numbered to a source, facts and guesses labelled. "only what's certain" switch. Sources below, numbered rows. Abstains plainly when nothing answers. Lit: none.
- **YO-3 a source** — *One thing you said, did or saved, in full.* Your words first (inky, like an entry), then where and when. A saved link adds your reason and, for a video, the transcript. Lit: none.
- **YO-4 a node** — *Everything it knows about one thing, and why.* Sheet over the map. The kind and name, then what it believes (inky) with how sure in a word plus the dots, the quotes behind it with dates, still true · not right, then linked nodes. For a person: "same person as … in your contacts?". Lit: none.
- **YO-5 what i know about you** — *Its answers to the questions about you.* "moved this week · 2 ›" leads (it's the news), then areas of life, each a serif lowercase section title, with answer rows (question, answer, how sure, from how many). A silent area says so warmly. Lit: none.
- **YO-6 a question waiting** — *Answer one thing it's unsure of.* Sheet, one question only: a guess card, large. Same / different / not sure (for people) or yes / not quite / why do you think that? (for a hypothesis). Lit: none (no answer is the right one to push).

### Settings (behind your picture on You)
- **ST-1 settings** — *Control, in one calm list.* Sections, lowercase serif titles, 40 apart: your brief · listening · you · sources · privacy · account · help. Value rows show the current value. Nothing for developers. Lit: none.
- **ST-2 daily brief** — *When, and whether, your brief arrives.* Each morning (switch) · time (value, local) · length (segmented: short · standard · long) · play today's. Lit: none.
- **ST-3 sources** — *What you've connected, and how it's going.* Source rows (purpose as subline, status in words); one needing attention says what to do (reconnect pill). Then add a source · import a file. Lit: none.
- **ST-4 a source** — *One source: what it reads, and control over it.* Reads / helps me see (plain sentences) · last read + sync now · disconnect… · delete what it read… (danger, last, dialogs). Lit: none.
- **ST-5 privacy** — *What it reads, where, and how to stop it.* Read in the background (switch; subline says what "off" means: only what you send) · where it's processed · download my data · delete my data… (danger, last). Lit: none.
- **ST-6 how straight i am with you** — *How bold it may be.* Four choice rows with a tick; under them, why it picked the current one; "let it decide" hands the choice back. Lit: none.
- **ST-7 voice and listening** — *How it sounds, and how you take things in.* Voice (value + play a sample) · talk or read (segmented) · speed (value). Lit: none.
- **ST-8 what i've learned** — *How it's learning to ask you better.* Read-only sentences. Too early state. Lit: none.
- **ST-9 account** — *Your plan, and your account.* Plan and renewal · manage subscription ↗ · restore · sign out · delete account… (danger, last, dialog that lists what's removed). Lit: none.

### Outside the app
- **EX-1 share to retrospect** — *Save anything, with your reason.* System share sheet: the thing (title, site), "why are you saving this?" (voice composer, mic first), goes with: a goal chip, save. Lit: save (it's the one action).
- **EX-2 lock screen** — *Keep listening without the app open.* Now-playing card: retrospect · tuesday's brief · the part being spoken (audio first) · ↺15 ‖ 30↻; the Live Activity is the same. Lit: n/a (system).
- **EX-3 notifications** — *Tell you when something is ready, then get out of the way.* Three kinds, at most one a day, private by default ("your brief is ready", not its content). Each opens its page. Lit: n/a.
- **EX-4 widget** — *Play today's brief, or talk to it, in one tap.* Small: the mark, "tell me…" (opens the composer). Medium: today's brief headline (serif) · play · talk. Lit: n/a.

---

## 3 · Components per page (existing or new)

| Page | Components |
|---|---|
| GL-1 | goal (existing) · guess-card (existing, as a goal guess) · settings-row: value row (existing) · tab-bar (existing) · mini-player (existing, when playing) |
| GL-2 | goal header (**new variant of goal**: the page title form) · evidence row (**new**, shared with JR-4 and PC-3) · guess-card (existing) · button: quiet pills (existing) |
| YO-1 | search field (**new**) · you-map (existing) · settings-row (existing) · title-menu (existing, list view) · tab-bar |
| YO-2 | search field (new) · cited answer (**new**) · switch row (existing) · source list row (**new variant of source-row**: numbered) |
| YO-3 | entry view (the JR-4 page form, existing as a page) · source line (part of cited answer) |
| YO-4 | sheet (existing) · how sure (**new sub-component**) · evidence row (new) · button pills (existing) · chip (existing, linked nodes) |
| YO-5 | settings-row section title (existing) · answer row (**new**) · how sure (new) · loading-and-empty (existing, the warm silent line) |
| YO-6 | sheet (existing) · guess-card (existing, large) |
| ST-1–ST-9 | settings-row: switch, value, action, leaves-the-app, danger (existing) · source-row (existing) · segmented (existing) · switch (existing) · choice row (**new variant of settings-row**: a tick) · sheet-and-dialog (existing, confirmations) |
| EX-1 | share extension frame (system) · voice-composer (existing) · chip (existing) · button lit (existing) |
| EX-2 | lock-screen-and-widget: now playing (existing) · transport (existing) |
| EX-3 | notification (**new**, mostly system-drawn: what we control is the words and where it opens) |
| EX-4 | lock-screen-and-widget: widget small and medium (existing) |

New: **search field**, **cited answer**, **evidence row**, **answer row**, **how sure**, **notification**; variants: goal header, numbered source row, choice row.

---

## 4 · Sub-components (anatomy of the new ones, bottom to top), with the restraint check

- **how sure** — the word (very sure / fairly sure / not sure yet), mono label; four 6pt dots, filled to the level, `text.label`. *Says:* how much to trust this. *Restraint:* the word carries it; the dots are the one quiet visual; no colour.
- **evidence row** — date (mono label) · what (text, primary) · trailing control ("not right" or "open ›"), 44pt min, wash surface. *Says:* one thing a claim rests on, and lets you correct it. *Restraint:* no icon; the date already says what kind of thing it is in context.
- **search field** — field shell (raised, pill, 48) · mic first (leading, the talk glyph) · placeholder "ask anything about yourself" · clear (only when typed). *Says:* you can ask. *Restraint:* no search glyph next to the mic; one leading glyph.
- **cited answer** — label "what i found" · the synthesis (text, body, inky for facts) · inline citation numbers [1] (mono, link) · a guess sentence marked "a guess" (dashed underline) · not right (long press any line). Abstain variant: "nothing you've said answers this" + what the sources do show. *Restraint:* no "AI" sparkle, no card around it; the numbers are the receipts.
- **answer row** — the question (mono label) · the answer (text, primary) · how sure + "from 6 things" · chevron. *Says:* one thing it believes about you. *Restraint:* no area icon; the section title says the area.
- **notification** — app name (system) · the line (we write: lowercase, one sentence, private by default) · where it opens. *Restraint:* never two in a day; no emoji.
- **choice row (settings-row variant)** — title · subline (what it means) · trailing tick when chosen. *Restraint:* the tick only; no radio circle and a colour.

---

## Decisions (by the system's rules, where sources disagreed)

- **Search layout:** the blueprint puts sources first; the search v1 shape puts the written synthesis on top with sources below. Both are kept: sources *arrive* first (~1 s) and light the map; the *layout* is synthesis on top, sources below.
- **Section titles in Settings:** the blueprint wrote them in capitals; settings-row says lowercase serif 20, 40 above, 12 below. The component spec wins.
- **Adding a goal:** a quiet + in the top bar, not a lit button, because Goals is for reading; a goal can also start from anything you say.
- **Goals Retro hears:** proposed, never assumed: a dashed guess card in the list until you say yes (goal spec: stated vs actual both visible).
- **Lock screen:** follows the founder's audio-first rule: the part being spoken, and where it's from.
- **Notifications:** private by default ("your brief is ready", not what's in it), per lock-screen-and-widget rule 2.

## Plan gate
The founder reviews these 21 pages in mid-fi for order and purpose. Hi-fi build (Part 2) starts after that, bottom-up from the new sub-components above.
