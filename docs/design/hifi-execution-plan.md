# hi-fi execution plan and progress tracker

**Where we are (20 Oct, latest):** M4 has started. JR-3 (drawer) and JR-4 (entry) are drawn in hi-fi on `04b · pages · hi-fi`, built from clones of the approved masters at three sizes with their key states; you approved both ("yes" on each). JR-1 and JR-2 are drawn and carry red dots, as does the M3 key-states card. JR-1 and JR-2 wait for the other session's player, sheet and dialog. **Before that:** my share of M2 is approved and placed as masters on 02 · components (brief card, tab bar, top bar, you map, voice composer, conversation, player sheet, brief items + recap). Next: the screens that use them (Journal JR-1, brief JR-2), built only from these masters. **Before that (20 Oct, later):** my share of M2 is drawn (parts 03–10); the other session's share (pill, labels, rows, drawer, entry; part 20 onward) is in progress. Conversation A picked. Next: your Paper comments on 07, 09, 10; approved picks (tab bar A, brief card D, top bar, map orbits, conversation A) go into the system as masters. **Earlier:** M0 (wiring) is done. M2 has started: part 00 (the icon set, ink joins, single paths), part 01 (drawer icon), part 02 (icon button) and part 03 (brief card, six versions) are on `02b · in review`. The brief card (A, D, E kept) and the tab bar (A) are picked. Two sessions now split the work: the original owns the icon set, this one builds parts 03 onward. Next: the brief card merged (D at rest, E when playing), then the top bar.
**21 Oct:** M6 end, M11 journey map and M12 dark mode are drawn and wait on you (00 · approvals). M13 sync is proven on the tab bar. M14 has started with generated Swift tokens. Your calls (21 Oct): SF Symbols for ON-6 (drawn, with your other apps after your comment), the app's own brush mark (now in all 27 places), paywall A (decision 06, with the paused pill). Dark mode moved to its own session. New page "06 · everything · latest" shows all 37 current screens in one place; SwiftUI is paused until you've looked at it. Later on 21 Oct you approved ON-1/2, ON-10, ON-11, ON-12 (paywall A), ON-13, GL-2, YO-1, AC-1 and AC-2; their red dots are off. M11 journey map approved too. ON-6 approved 21 Oct, so all of onboarding is approved. Both microinteraction questions are answered. M14 plan approved 21 Oct (design + backend). B0 baseline has started.
This file is updated after every step: tick the box, change the grid, add a line to the change log.

## TL;DR
1. **Wire it first (M0).** The components page holds the masters. Every screen uses named copies of them, and a sync keeps every copy (and later the SwiftUI) matching its master.
2. **Build bottom-up, one area at a time, starting with Journal.** For each area: sub-components → components → pages in hi-fi with their states. Each part passes the 15 checks plus the goals, the wireframe and the tokens, then waits on `02b · in review`. **It enters the design system only after you approve it.**
3. **Then the remaining areas** (Podcasts, Onboarding, Goals, You, Settings, outside the app), each with its own review gate.
4. **Then the journey map** (`06 · journey · hi-fi`): every screen and state along every path.
5. **Then dark mode**: a full second pass with the same checks.
6. **Then prove the sync** (you change a master, and everything follows), and hand off to SwiftUI.

Key: ✅ done · 🟡 in progress · ⬜ not started · 👀 waiting for your review

---

## Progress grid
| Area | Flows | Pages (mid-fi) | Component list | Sub-components | Components | Pages hi-fi (light) | States + sizes | Dark |
|---|---|---|---|---|---|---|---|---|
| Shared (used everywhere) | — | — | ✅ | 🟡 icons, icon button, pill, labels, row 👀 | ⬜ | — | — | ⬜ |
| 2 · Journal | ✅ | ✅ 4 | ✅ | 🟡 brief card 👀 | ⬜ | ⬜ 0/4 | ⬜ | ⬜ |
| 3 · Podcasts | ✅ | ✅ 3 | ✅ | ⬜ | ⬜ | ⬜ 0/3 | ⬜ | ⬜ |
| 1 · Onboarding + account | ✅ | ✅ 19 | ✅ | ⬜ | ⬜ | ⬜ 0/19 | 🟡 mid-fi 13/21 rows | ⬜ |
| 4 · Goals | ✅ | ✅ 2 | ✅ | ⬜ | ⬜ | ⬜ 0/2 | ⬜ | ⬜ |
| 5 · You | ✅ | ✅ 6 | ✅ | ⬜ | ⬜ | ⬜ 0/6 | ⬜ | ⬜ |
| 6 · Settings | ✅ | ✅ 9 | ✅ | ⬜ | ⬜ | ⬜ 0/9 | ⬜ | ⬜ |
| 7 · Outside the app | ✅ | ✅ 4 | ✅ | ⬜ | ⬜ | ⬜ 0/4 | ⬜ | ⬜ |
| **Whole product** | ✅ | ✅ **47** | ✅ | ⬜ | ⬜ | ⬜ **0/47** | ⬜ | ⬜ |

---

## Where things live in Paper (20 Oct)
- **00 · approvals · waiting on you:** the only place with anything pending (red dots)
- **05 · the app in order · hi-fi:** approved screens in order of use, states stacked below each; dashed slots for pending
- **02 · components:** approved masters and approved part boards · **02b:** settled decision cards + archive · **04b:** approved page boards with their sizes and page passes

## Milestones
Each milestone has an exit check. Gates marked 👀 need your approval before the next milestone starts.

### M0 · Wiring ✅
- [x] Restructure `02 · components`: one board per component, the master on top and its states under it
- [x] Create a `02b · in review` page for parts waiting on you
- [x] Naming rule `c:<component>/<variant>/<state>`, written into `components/README.md`
- [x] Sync script v1 (`design-system/sync/paper-sync.mjs`): read the masters, find every tagged copy, report drift
- [ ] Add the sync to the regular comment check (once masters exist)

**Exit check:** change a test master and the script finds every copy.

### M1 · References ⬜
- [ ] You sign into Mobbin and Cosmos in the in-app browser
- [ ] Reference notes for each Journal part: what works and why, never a copy (`docs/design/references.md`)

### M2 · Journal + shared sub-components (light) 🟡
- [x] Part 01 · drawer icon · Part 02 · icon button 👀
- [x] Part 20 · pill (neutral · raised · lit), rest + pressed, 15 checks, token-check 0 👀 (round 2 after your comments: medium weight, no focus tiles, tier columns; open question: lit at 48 or 32)
- [x] Part 21 · labels (day, section) 👀
- [x] Part 22 · 56 row + hairline 👀 (hairline moved to border.strong; new chevron-right)
- [x] Part 23 · drawer parts (search field, entry row; the section label is part 21) 👀
- [x] Part 24 · entry parts (words, meta, link, what retro took + not right, delete + dialog) 👀
- [x] ✅ The fork's share: top bar, tab bar (part 04), composer, conversation, brief/player (parts 03/03b, 09, 10). Approved 20 Oct and placed as masters on 02 · components
- [ ] When you approve part 00: the inked icons become the standard everywhere. Swap every glyph on 02b, 02 · components and the screens to `icons/shipped` (24pt) or `icons/shipped-20` (20pt, in buttons), and move the set into 02 · components
- [x] 👀 part 00 icon set (owned by the original session) · part 01 drawer icon · part 02 icon button
- [x] part 03 brief card: you kept A, D, E; B, C, F archived · next: one card that is D at rest and becomes E when playing
- [x] part 04 tab bar: A picked, a real progressive blur (one masked layer); B, C archived
- [x] part 03b merged brief card: archived (you prefer D as drawn); **D goes ahead**
- [x] part 05 you map: **orbits picked**, frosted orbs; five variations archived; the constellation is marked hand-crafted for you
- [x] part 06 top bar ✅ decided: B (inky title) at rest → A (small name) once you scroll or type; blur implementation flagged
- [x] the original session: pill, labels, row + hairline, drawer, entry, switch/segmented, settings rows, settings page → ✅ Gate A (all approved 20 Oct, masters placed)
Each part: drawn at 4× from tokens → 15 checks → goals, wireframe, spacing rules → screenshot, fix, log → `02b`.
- [ ] Shared: top bar ✅ · ~~tab bar~~ ✅ · pill (other session) (neutral, raised, lit) · labels (section, day) · 56 row + hairline
- [x] ✅ Conversation: part 08, A picked (SF Pro); Retro's lines now carry no mark (founder, 20 Oct); recap card drawn in part 10, in context
- [x] ✅ Composer: part 07, voice composer (listening, speaking, muted, typing → send, lit by your call); empty raised again, recess kept as a recipe for other inputs; squircle corners noted for SwiftUI
- [x] ✅ Brief: brief card D · part 09 player sheet, round 2: ready / playing (title scrolls up) / held scrub (one-line chapter bubble) / "…" menu (chapters, download); progressive-blur transcript; correct-this-part above the line · part 10 "now" card, up-next rows, recap card, now shown in context (brief sheet, Journal thread)
- [x] ✅ Drawer: search field · entry row · section label (part 23, master)
- [x] ✅ Entry: your words · meta line · conversation link · "what I took" row · delete row · dialog (part 24, master)
- [ ] 👀 **Gate A:** you approve, then the parts move into the design system (master, spec, tokens, audit row). **Done for my share** (8 boards, audit.md masters table); the main session's parts 20–27 approved 20 Oct, masters placed

### M3 · Journal components 🟡 → 👀 Gate B
- [x] Before drawing: Dynamic Type AX3 tokens added from Apple's HIG table (`type.ax3.*`, `--text-ax3-*`, `--leading-ax3-*`), plus `opacity.pending`
- [x] 👀 message: every state, inside part 08 (11 drawn, 4 excused with reasons, dark → M12); message.md brought in line with the approved board; audit row; lint clean
- [x] 👀 voice composer: every other state, inside part 07 (thinking, pressed, no mic, didn't catch that, offline, AX3, Increase Contrast, Reduce Motion); generator synced to the master
- [x] 👀 brief card D: every other state, inside part 03 (pressed, starting, played, quiet day, being made, couldn't load, offline, AX3, Increase Contrast); playing unchanged by your call; brief-card.md fixed (the morphing playing state and the mono labels removed)
- [ ] player (brief mode) · sheet · dialog (mine) · drawer · entry (main session)
- [x] ✅ drawer · entry key states (main session, approved 20 Oct, folded into the drawer and entry masters): the three not yet drawn (drawer empty, search no results, entry editing) on the card "M3 · key states · drawer and entry" (02b, decision row). Every other state is already in the masters
- [ ] Assembled only from approved parts: message, composer, brief card, player (brief mode), drawer, entry, sheet, dialog
- [x] ~~All 14 states each~~ → **the key states in each flow only** (founder, 20 Oct: "ios will handle it… not meant to think about every little edge case now"). Accessibility variants (AX3, Increase Contrast, Reduce Motion/Transparency) come from SwiftUI's system styles, so they're not drawn.
- [ ] Spec complete, audit row, `lint.mjs` clean

### M4 · Journal pages, hi-fi 🟡 → 👀 Gate C1
Pages live on Paper page `04b · pages · hi-fi`, one board per page, each with a red dot until you approve it.
- [x] ✅ JR-3 drawer (approved 20 Oct): clones of the approved drawer master at SE, 17 Pro and Pro Max; key states empty, searching, no results, offline (empty and no results match the M3 card, with their quiet marks); page pass under it
- [x] ✅ JR-4 entry (approved 20 Oct): clones of the approved entry master at three sizes; key states voice note, nothing taken yet, editing ("edit this entry", as on the M3 card), offline (didn't send), delete dialog; page pass under it
- [x] ✅ JR-1 journal: clones of the approved top bar, brief card D, conversation, composer and tab bar at three sizes; key states talking, retro thinking, brief being made (compact row, your comment), first day; mic off until you tap (your call); sizes approved. scrolled state = decision 05 A (chosen)
- [x] 👀 JR-2 brief: the approved brief-mode sheet (part 10) at three sizes, made to flex (controls at the bottom on every size) with a status bar; key states paused, played, quiet day drawn (the other session moved to comment duty, so these are mine)
- [x] Every page state → **key states only** (your cut). Loading and error skipped for JR-3: the list lives on the phone. Largest text comes from SwiftUI
- [x] SE, 17 Pro and Pro Max sizes (JR-3, JR-4)
- [x] Imagery from tokens (no generated images): none needed on JR-3/JR-4
- [x] Page-level fixes folded back into the masters (balanced wrap, the drawer's settings foot, the complete status bar) and into p23/p24 generators

### M5–M10 · The other areas, the same three steps each (sub-components → components → pages) ⬜
| Milestone | Area | New parts beyond what's already approved | Gate |
|---|---|---|---|
| M5 🟡 | Podcasts | tile (hero and square), mini-player, transcript lines, chapter list, "why this is here" | C2 |
| M6 🟡 | Onboarding + account | the mark, splash constellation, question title, live words, segmented control, connect rows, privacy, paywall plans, stage tag, sign-in buttons | C3 |
| M7 🟡 | Goals | goal card (said vs did), evidence row, goal guess | C4 |
| M8 🟡 | You | search field, the map (nodes, edges, waiting ring), cited answer, numbered source row, answer row, how sure | C5 |
| M9 🟡 | Settings | settings rows (switch, value, action, leaves the app, danger, choice), switch, segmented control, source row | C6 |
| M10 🟡 | Outside the app | share sheet, lock-screen card, notification, widgets (small, medium) | C7 |

### M7 progress · Goals
- [x] ✅ Part 48 · goal card (02b): your words, said vs did as two quiet bars with counts in words, one line from retro; states rest, a gap, too early, a guess (dashed), ended (one quiet row) · approved 20 Oct
- [x] 👀 GL-1 · goals (04b, new "goals" group): built in the podcasts page's frame; three sizes (SE: full-width cards, 12 gaps, blur starts higher); key state none yet; red dot
- [x] 👀 GL-2 · one goal (04b, goals group): the entry page's frame; your words (inky), said in one label line, did this week as part 41's evidence rows, a pattern as a guess; "edit" renames, the foot holds only "turn off"; three sizes; key state turned off; red dot
- M7 is drawn end to end; it waits on your approval of part 48, GL-1 and GL-2

### M8 progress · You
- [x] ✅ Part 50 · search (02b): the field (mic first, sunken), the written answer (inky facts, a guess labelled and set in body type), numbered sources (part 41 rows with a number well), "only what's certain", nothing found · approved 20 Oct
- [x] 👀 YO-1 · you (04b, new "you" group): field, the approved You map (orbits), two quiet rows; "you" large like every tab with "list" and your picture (settings) trailing; three sizes (SE keeps the map whole, rows rise from under the tabs); key state day one; red dot
- [x] 👀 YO-2 · search results (04b): in place in the You tab; three sizes; key state nothing found; red dot
- [x] 👀 YO-4 · a node (04b): a sheet over the map built from PC-3's sheet (claim, evidence rows, correct pill); a person (still true · not right, linked chips) and a guess (same as … in your contacts? yes, same · not quite); red dot
- [x] 👀 YO-3 · a source (04b): the entry frame with "this supports" rows; red dot
- [x] 👀 YO-5 · what i know about you (04b): what moved leads, areas as inky sections, answer rows with how-sure dots, a warm silent area; red dot (`p51_known.py`)
- M8 is drawn end to end; it waits on your approval of part 50 and YO-1 to YO-5
- [x] iOS handoff started: docs/design/ios-handoff.md (founder: "keep notes… we are going to turn this into an iOS app tomorrow"), updated after every step

### M10 progress · outside the app
- [x] 👀 EX-1 share to retrospect · EX-2 lock screen · EX-3 notifications · EX-4 widgets (on the approvals page; `p53_outside.py`)

### M9 progress (started early, while Gate A waits)
- [x] ✅ **ST-1 to ST-9 · settings pages (04b, new "settings" group):** composed only from the approved bar, rows, switch, segmented and raised pill; danger rows last; approved 20 Oct (`p52_settings_pages.py`)
- [x] Part 25 · switch + segmented 👀 (on = ink, not blue)
- [x] 👀 **M5 started.** Part 40 · episode tiles (hero + square, being made as a compact row) on 02b with PC-1 in context, red dot. Split with the other session: mine = tiles, PC-3 claim + evidence rows, PC-1/PC-3 pages; theirs = mini-player, transcript lines, chapter list, PC-2
- [x] 👀 PC-1 · podcasts page (04b): three sizes with SE decisions (shorter hero art, tighter rhythm, lower blur), states playing and being made; red dot
- [x] 👀 PC-2 · the player page (04b): the approved sheet at three sizes, made to flex (SE controls stay on screen, transcript wraps), states: a guess arriving, the chapter list; red dot
- [x] ✅ PC-3 · why this is here (04b): the evidence page inside the player sheet at three sizes (sheet flexes; on SE the evidence rows stay one line and the claim keeps its size), states: stated, asked (dashed guess) · approved 20 Oct
- [x] ✅ Part 45 · mini-player: playing and failed, on PC-1 above the tabs; the hero drops its lit play while its episode plays · approved 20 Oct
- [x] ✅ Part 44 · privacy moment (ON-5): lock in a raised disc with two soft rings, one inky title, the plain paragraph, the policy link, retro reading it aloud · approved 20 Oct
- [x] 👀 Decision 06 · paywall (ON-12): how you pick a plan. A the plans are the buttons (spec, my lean) · B choose, then subscribe (mid-fi). Mini-player, inky line, five benefits with token drawings, plans + links in the thumb zone; red dot
- [x] 👀 AC-1 · sign in, returning (04b): the splash's own sign-in zone without the pitch; the mark (38) and "welcome back." in the middle; three sizes (SE: same buttons, tighter, no home indicator), states restoring and failed; red dot
- [ ] Part 45 · connect (ON-6): waiting on your answer about logos (real brand marks vs our glyph wells)
- [x] 👀 Part 43 · splash + sign-in (ON-1/2): the approved You map (orbits) bleeding under the status bar, the inky promise, Apple then Google in the bottom zone, a Geist legal line; red dot
- [x] ✅ **M6 started.** Part 42 · onboarding question (ON-3 to ON-9): progress bar, back · skip, one inky question, your words blurring in, quick-answer pills that feed the composer's send · approved 20 Oct
- [x] 👀 **M6 end drawn.** ON-10 getting ready, ON-11 tease, ON-13 first home, AC-2 signing out · one board on 00 · approvals, red dot · token-check 0 · waiting on approval
- [x] 👀 Part 41 · why this is here (PC-3): the claim (stated = inky title · asked = dashed guess, per guess-card.md) and the evidence list (32 kind wells, date label, your words, ›), shown inside the player sheet; red dot
- [x] ✅ Decision 05 · brief card when scrolled: **A chosen** ("def A"), B archived; A added to JR-1 as the scrolled state
- [x] Part 26 · settings rows 👀 (switch, choice, value, leaves-the-app, danger, source; open question: syncing dot is blue)
- [x] Part 27 · settings page → decision card 04 👀 (approve + › vs ↕)
- [x] Decisions answered 20 Oct: 02 icons → A (applied) · 03 syncing → A grey + rotating ring (drawn) · 04 value rows → B ↕/› (applied); 01 → A cards with a pill (your call); syncing ring stays 6pt. all four decision cards closed
- [x] Gate A cards up: 8 approval cards (parts 20–27) on 02b, row 2
- [x] Gate A · parts 20–23 approved → masters on 02 · components (pill, label, settings row, drawer)
- [x] Gate A · parts 25, 26, 27 approved → masters (switch·segmented, settings rows, settings page)
- [x] Gate A · part 24 approved after the claim-card fix → master (c · entry page · what i took · delete). **Gate A complete for parts 20–27**
- [x] Review format → one decision card per open choice (02b, row at y 0 right of the archive): 01 what-i-took · 02 settings icons · 03 syncing dot, all open
- [x] 02 · components overlap fixed (masters row at y −2,600)
- [x] Comment round 2 (20 Oct): parts 21–26 threads resolved; in-app phones for 22 and 24; danger-row options A/B waiting on you
- [x] Rule: every part ships with an "in the app" 390×844 phone tile (from your "what is this" comments). Backfilled: 22 settings page (also shows 21, 25, 26 in place), 23 journal drawer open, 24 entry page + delete dialog, 20 points to its pills in those phones

### M11 · Journey map (light) ✅ Gate D · approved 21 Oct; rebalanced after your comment (steps are raised pills, failure notes sit under their screens)
- [x] 👀 Drawn as one board on `00 · approvals` (moves to `06 · journey` on approval): 35 real 17 Pro screens as nodes, labelled moves (what you do + how it moves), ON-6 and ON-12 as dashed "not drawn yet" nodes with the reason
- [x] Paths:
  - first run
  - daily: brief, journal, entry
  - weekly episode
  - search
  - goals
  - settings
  - outside the app
- [x] Failure branches dashed (red): sign-in fails, calendar denied, payment fails, offline, mic denied, episode not ready, offline not downloaded, nothing found, sending fails while signing out
- [x] States: each screen's states stay stacked under it on `05 · the app in order` (the map links there instead of duplicating 150 states)

### M12 · Dark mode 👀 Gate E · now run by the dark-mode session (v2 board SX8); my v1 is archived
- [x] 👀 The whole journey map in dark (every screen, so every component in use), using the `--color-dark-*` pairs only: 1,269 style swaps + 409 icon paths, by script (`hifi/dark_updates.py`). Six missing dark pairs added to Paper from tokens.json. Artwork meshes and system chrome keep palette colours on purpose. The parts boards on 02 stay light; their dark is checked in place
- [x] Contrast measured in dark: all 44 component pairs pass (`tokens/contrast-pairs.cjs`)

### M13 · Prove the sync ✅ Gate F
- [x] Proven on the tab bar: the sync read the master and 24 copies from Paper exports and found 22 differences (the selected tab's layer names and styles disagreed on podcasts, goals, you, search). `sync/push-tab-bar.py` pushed the master onto all 120 tab items in 30 tab bars (light, dark, source boards); the re-check found 0. The push reads the master's values from its export, so editing the master and re-exporting moves every copy

### M14 · Hand-off to SwiftUI 🟡 · plan approved 21 Oct, B0 under way: docs/design/swift-implementation-plan.md; motion system: design-system/principles/motion-system.md
- [x] Swift generated from tokens.json: `tokens/to-swift.mjs` → `tokens/build/Tokens.swift` (120 light/dark colours, 106 dimensions, 34 numbers; type-checks against the iOS SDK). Type styles, shadows, gradients, springs and haptics are hand-built per process.md Part 3
- [ ] Components as SwiftUI views (variant + state enums, previews light and dark): approved masters first, from docs/design/ios-handoff.md
- [ ] Pages built from them: each waits on its approval

---

## Rules for every step (your calls, 20 Oct)
- **Current components are a starting point.** Design fresh from tokens and the rules, and do better where possible. A better part replaces the old one, and its spec is rewritten with the reason.
- **Nothing enters the design system without your approval.** It waits on `02b · in review`.
- **No generated images** unless you say yes. Artwork comes from tokens: OKLCH meshes, grain, shapes.
- **Light mode first, then dark mode with equal care.**
- **Journal first.** The plan covers the whole product.
- Every finding goes in `docs/second-brain/findings-log.md`. Paper comments are checked every few minutes, and boards are always created with an explicit page.

## Scale
- About 40 sub-components, then about 37 components, then 47 pages with roughly 150 states, then the map.
- Then the same again in dark.

## Change log
- **20 Oct** · Plan written. Your answers added: wiring is our own, current components are inspiration only, you'll sign into Mobbin and Cosmos, no generated images, light then dark, Journal first, approval before anything enters the system. Rewritten as a milestone tracker. Mid-fi: all 47 pages and both flow strips are done, and the Paper file is reorganised.
- **20 Oct** · M0 done. M2 started: parts 00–03 on 02b. Icons have ink joins and ship as single paths. Eight Paper comments resolved: Geist labels (new `--font-label` token; mono only for figures), skip numerals centred, mini-player insets, pill scrubber segments, lighter title-menu selection, six brief-card versions, and the fade-and-float direction.
- **20 Oct** · Split the work across two sessions. Brief card: A, D, E kept; tab bar: A with a progressive blur; unchosen versions archived, never deleted. Eight 02 · components comments fixed: sheet gradient, spacing, scrubber pills, "correct this part", composer focus lift, widget at true size.
- **20 Oct, late** · M0 done. Icon set rebuilt from your comments: slashes ink-joined, skip arrows run into the tip with numerals centred by weight, new guess icon (dashed ring), exact fillets and fitted Bézier curves so joints stay smooth at any zoom. Work split with the forked session: this one has part 00 and icons; the fork has part 03 onward and the 02 · components comments.
- **20 Oct** · The you map is redrawn as a constellation (cores, halos, weighted threads), with a miniature for the paywall. Old versions archived.
- **20 Oct** · Parts 03b and 05 added. The tab bar blur is now a real progressive blur. Dark transport recess and play centring fixed. M2 split by part between the two sessions.
- **20 Oct** · Picks: brief card D, you map orbits (frosted), tab bar A. Part 06 top bar on 02b. Unchosen versions archived.
- **20 Oct, evening** · Parts 20 (pill), 21 (labels) and 22 (row + hairline) on 02b. Your rulings: label weight is medium, not semibold; focus rings aren't drawn on boards. New icon: chevron-right. Hairline raised to border.strong (subtle was invisible). Work split with the fork: it builds top bar, tab bar, composer, conversation and brief/player; this session builds pills, labels, rows, drawer and entry parts, and handles the comments on its own parts.
- **20 Oct** · Part 07 voice composer on 02b.
- **20 Oct** · Part 08 conversation on 02b.
- **20 Oct** · Parts 09 (player sheet) and 10 (brief items, recap) on 02b. My M2 share complete; waiting on picks and Gate A.
- **20 Oct** · Conversation A picked. Plain-English notes on every part under review (your rule).
- **20 Oct** · Founder comment round on 07–10: nine threads resolved. 09 has four states; 07 empty is raised; 08 drops the mark; 10 is shown in context. Open question: the "…" menu items.
- **20 Oct** · Founder approved 03 D, 04 A, 05 orbits, 06, 07, 08 A, 09 and 10. Eight master boards placed on 02 · components (master on top, states below). Send is lit; the scrub bubble is one line; recesses are darker than their parent; SF Pro body gets tracking.card.
- **20 Oct, night** · M3 started. AX3 type tokens from Apple's table; the message component drawn in every state (02b part 30); its spec fixed where it had drifted from your approvals.
- **20 Oct, night** · M3: the message, voice composer and brief card are drawn in every state, each inside its own approved section (after you flagged the separate sections as duplicates). AX3 means every line grows, not only the headline (caught at 1×). Lint is clean apart from the main session's icon candidates.
- **20 Oct, late** · Scope cut by you: M3 draws only the key states in each flow. Removed from the boards: the accessibility tiles, offline/no-permission/pressed variants, the "not drawn" lists, and the half-built player states. Kept: message (arriving, sending, not sent, long press), composer (thinking), brief card (being made, played, quiet day).
