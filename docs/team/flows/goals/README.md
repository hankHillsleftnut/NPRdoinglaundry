# Goals: the plan, every piece to PR level

Area slug `goals`, contract [04](../../contracts/04-goals.md), flow test T05b, ship gate G4. Phase 4, after Beta 1 (first-ship.md: goals stay on the current screens until then). Written 21 Oct to the journal's standard. Cards: [backend.md](./backend.md), [platform.md](./platform.md), [views.md](./views.md). Tree for the board: [tree.json](./tree.json).

**Paper was not running while this was planned.** Every node id comes from `reference/paper-inventory.md` and every value from `reference/design-reference.md` §C28, §C29, §C32 and §E P16/P17. Each views card says "read with `get_jsx` / `get_computed_styles` before building"; nothing here was measured from a screenshot. The one picture read was the old mid-fi `docs/design/core-screens/4-goals.png`, used only to understand intent.

## 1. The big picture

**What it is for the person, in their words:** "see whether I'm doing what I say matters" (mid-fi plan). You say what you're working toward. Retro counts how often you talk about it and what you actually did for it, side by side, and tells you nothing it can't show.

It's the most dangerous screen in the app for honesty. A goals screen wants to cheer ("you're on track!") or scold ("behind"). Ours does neither. The principles that apply, and what they mean here:

| Principle | On the goals screens |
|---|---|
| **The claim ladder** (fact → pattern → why → guess) | a goal is your words (fact); "said" is arithmetic over your entries (fact); "did" is dated things judged to serve it, each correctable (facts with one judged link); Retro's line is a live pattern or arithmetic; a why is a guess (hypothesis) |
| **Guesses asked, never asserted** | "is that a goal?" quotes your exact words and asks; check-ins ask "still working toward this?"; GL-2's guess is a contract 02 `Guess` under the founder's `speak` dial |
| **When uncertain, withhold** | 14 days of "too early to tell"; "nothing to compare yet" when both sides are empty; no line unless one is earned; no verdict words anywhere (contract 04 §0) |
| **No invented data** | the empty state says "nothing yet." and how goals arrive; sample data is fixtures only; no placeholder bars |
| **One lit object per screen** | none on GL-1 or GL-2 (Goals is for reading; adding is a quiet wash +). The add sheet's save is its one lit object |
| **Quitting is a choice** (goal rule 3) | "turn off" is immediate, never a dialog, with an undo toast; ended goals stay, revivable, never called failed |
| **Restraint** | two bars and two numbers; no %, ring, streak, calendar or summary line |

## 2. Flows

### 2.1 Entry points
| Entry | Lands on |
|---|---|
| the goals tab | GL-1, scrolled to the top |
| re-tapping the goals tab | scroll to top (`gentle`), or pop GL-2 back to GL-1 |
| a check-in push (`goal.checkin`) | GL-1 with that question first (PL3.5d, contract 04 §7) |
| a deep link `retrospect://goals` / `retrospect://goals/<id>` | GL-1 / GL-2 (contract 07 registers them; PL3.5d routes) |
| the brief's "here for your goal: …" (JR-2) and an episode's goal mention | GL-2 for that goal (later; contract 03/02 carry the goal id when they do) |
| first run: saying yes to an onboarding goal candidate (contract 01 §2) | the goal exists when GL-1 is first opened, `tooEarly` |

### 2.2 Paths
1. **See your goals** (GL-1): question card first when there is one → goal cards (newest-moving first) → the ended row. Each card: title, said bar, did bar (or "too early to tell"), at most one line.
2. **Answer a question** (GL-1): yes / not quite on "is that a goal?" or "still working toward this?" → M11: the card folds away, the list closes the gap, and a new or kept goal's card eases in; "not quite" on a check-in turns the goal off with an undo toast.
3. **Open one goal** (GL-2): tap a card → the goal inky, "said 14 times · first on … · last on …", "did this week" rows, one grey guess card when the dial is on → "turn off" at the foot.
4. **Turn a goal off**: GL-2 "turn off" → back to GL-1, the card folds away, toast "turned off · undo" (C21-i). Undo restores it in place. Or answer "not quite" to a check-in.
5. **Turn a goal back on**: GL-3 ended → GL-2 (turned off: dated line) → "turn back on" → it returns to GL-1, too early again.
6. **Add a goal**: GL-1 + → the add sheet → type or say it → save (lit) → the sheet closes and the new card eases in at the top, "just started. i'll know more in two weeks."
7. **Rename**: GL-2 "edit" → the title becomes editable (cancel · "rename this goal" · save) → saved.
8. **Not for this goal**: GL-2 long-press a did row → "not for this goal" → the row folds, the counts ease down, undo toast.
9. **Answer GL-2's guess**: contract 02 guess flow (C28's behaviour on the grey look).
10. **Check-ins**: the brain notices a quiet goal → (switch on) a content-free push → tap → GL-1 with the question first.

### 2.3 Failures, offline, empty, first time vs hundredth
| Situation | What the person sees |
|---|---|
| first open, no goals, no question | C39.2 empty: "nothing yet." + "say what you're working toward, or wait and i'll notice." (Paper copy, handoff GL-1), and the + |
| a goal's first 14 days | the did bar is replaced by "too early to tell"; line "9 days in. i'll know more next week." |
| nothing on either side after 14 days | bars hidden, "nothing to compare yet" |
| loading over 400ms | skeleton cards in the card's shape (C39.1); under 400ms nothing |
| offline, cached | the cached list as it was, the offline line (C39.4); writes queue (outbox) and show as done at once with "saved on this phone" where C28/C39 draw it |
| offline, never loaded | C39.3 error in place, "try again" |
| a write the server refuses | the change rolls back with the error line ("couldn't save that · try again", `error` haptic) |
| a goal that no longer exists (or a stale link) | GL-2 shows C39.2 "that isn't here any more." with the back button; it never navigates on its own |
| the hundredth visit | the same calm list; the question card appears at most one at a time and at most once a day; check-ins at most weekly |
| many goals | full-width cards, 12 apart; 50 max from the server; the ended row last |
| a very long title | wraps to three lines then ellipsis (craft §9.4), never truncated to one |

## 3. Pages, with their states

| Page | Paper | States (T02 `-State`) | Card |
|---|---|---|---|
| **GL-1 goals** | `1FZO-0` (approved; dark `2JCP-0` waiting) | `full`, `question`, `checkin`, `tooEarly`, `nothingYet`, `gap`, `doesMore`, `ended`, `empty`, `loading`, `error`, `offline`, `answering`, `answerFailed`, `turnedOffToast`, `long`, SE | P16 (P16.1, P16.2) |
| **GL-2 one goal** | `1G3Z-0` (approved, red dot hidden; dark `2JRP-0`) | `full`, `tooEarly`, `noRows`, `withGuess`, `noGuess`, `off`, `faded`, `merged`, `renaming`, `loading`, `error`, `offline`, `notFound`, SE | P17 (P17.1, P17.2) |
| **GL-3 ended goals** | **not drawn** (Q5) | `full`, `loading`, `error`, `offline` | P16b |
| **GL-4 add a goal** (sheet) | **not drawn** (Q6) | `empty`, `typing`, `listening`, `saving`, `saved`, `offline`, `failed` | UIG.1 |

Paper draws no loading, empty, error or offline state for GL-1/GL-2 (paper-inventory §5d); those use the shared C39 states, and the founder sees them in the page PRs.

## 4. Components

| Component | Paper | Status | Card |
|---|---|---|---|
| said/did meter row | part 48 `ITY-0` (inside `IXB-0`) | new | C29.1 |
| goal card (rest, gap, too early, nothing yet, loading, pressed) | `IXB-0`, `IY9-0`; GL-1 `1G2R-0`, `1G21-0` | new | C29.2 |
| question card, grey (is that a goal, still on it, GL-2 guess) | `IYO-0`; GL-1 `1G35-0`; GL-2 `1G45-0` | new (the grey variant C28 left out) | C29.3 |
| ended row | `IYZ-0`; GL-1 `1G1X-0` | new | C29.4 |
| goal header (GL-2 title block + said line + foot) | GL-2 `1G3Z-0` | new | C29.5 |
| M11 fold and ease | part 48 | new motion | M11 |
| toast with undo, goals use | approvals `2FI5-0` (pending #48) | integration | C21-i |
| did-row menu ("not for this goal") | C20 menu, C32 row | integration | UIG.3 |
| rename mode | JR-4's editing pattern (`E2U-0` → `G8U-0`) | integration | UIG.2 |
| **reused, not rebuilt:** top bar title + wash + (C17-t), entry top bar (C17), tab bar (C18), evidence row (C32), pills (#45), icon well (S01), tag/guess icon (#46), sheet (C19.1), voice composer (#56), shared states (C39), menu (C20), progressive blur (UI0.1) | | built or planned elsewhere | — |

## 5. The full tree

`area › flow › page › component › sub-component › PR` (size · side · needs). Leaves are PRs. The same tree is in [tree.json](./tree.json).

```
goals
├─ F1 see what you're working toward
│  ├─ data
│  │  ├─ BE4.0a  brain: said counts and the daily progress snapshot ........ M · backend · BEA.4, BEA.2
│  │  ├─ BE4.0b  brain: goal progress and one-goal routes ................. M · backend · BE4.0a
│  │  ├─ BE4.1a  doors: GET /v2/goals, /ended, /:id ........................ M · backend · BE4.0b, BE0.1, BE0.2, BE0.12
│  │  ├─ UIG.0   SampleGoalsData and scenarios ............................. M · views · Platform/Flows/Goals.swift, T02
│  │  └─ PL3.5a  goals repository and reads ................................ M · platform · BE4.1a (fixtures only to start), PL2.5
│  └─ GL-1 goals (P16)
│     ├─ C29 goal card
│     │  ├─ C29.1  said/did meter row ...................................... S · views · T01
│     │  └─ C29.2  goal card ............................................... M · views · C29.1, UIG.0
│     ├─ C29.4  ended row .................................................. S · views · T01
│     ├─ P16.1  GL-1 layout, list and states ................................ M · views · C29.2, C29.4, C17-t, C18, C39, UI0.1
│     ├─ P16.2  GL-1 questions, toast and the fold .......................... M · views · P16.1, C29.3, C21-i, M11
│     └─ M11    the card folds, the bar eases ............................... M · views · C29.2, C29.3
├─ F2 answer retro's questions
│  ├─ BE4.0d  brain: "is that a goal?" from your stated words .............. M · backend · BE4.0b
│  ├─ BE4.4   door: POST /v2/goals/questions/:id ............................ M · backend · BE4.0d, BE4.1b
│  ├─ PL3.5b  goal writes through the outbox ................................ M · platform · PL3.5a, PL2.2, PL3.1c, BE4.1b, BE4.4
│  └─ C29.3   question card, grey ............................................ M · views · #45, S01, #46 glyph, UIG.0
├─ F3 everything behind one goal
│  ├─ BE4.0c  brain: "not for this goal" verdicts ........................... S · backend · BE4.0b
│  ├─ BE4.0f  brain: the guess for one goal .................................. S · backend · BE1.4, BE4.0b
│  ├─ BE4.2   door: not for this goal, and the guess in GL-2 ............... M · backend · BE4.0c, BE4.0f, BE4.1a
│  └─ GL-2 one goal (P17)
│     ├─ C29.5  goal header .................................................. S · views · UIG.0
│     ├─ P17.1  GL-2 layout, said, did rows and states ...................... M · views · C29.5, C32, C17, C39
│     ├─ UIG.3  did-row menu: not for this goal ............................ S · views · P17.1, C20, C21-i
│     └─ P17.2  GL-2 guess, turn off and turn back on ....................... M · views · P17.1, C29.3, C21-i
├─ F4 add and rename
│  ├─ BE4.1b  doors: POST /v2/goals, PATCH /v2/goals/:id ................... M · backend · BE4.1a
│  ├─ PL3.5c  your old goals, reconciled once ............................... S · platform · PL3.5b, PL2.6
│  ├─ GL-4 add a goal
│  │  └─ UIG.1  the add sheet ............................................... M · views · C19.1, #56, UIG.0, Paper drawing (Q6)
│  └─ UIG.2  rename on GL-2 .................................................. S · views · P17.1
├─ F5 turn off, and what ended
│  ├─ C21-i  toast: turned off · undo ....................................... S · views · #48
│  └─ GL-3 ended goals
│     └─ P16b  the ended list ............................................... S · views · C29.4, #47 settings row, Paper drawing (Q5)
├─ F6 check-ins
│  ├─ BE4.0e  brain: quiet goals become check-in questions ................. M · backend · BE4.0d
│  ├─ BE4.3   check-in push and its switch ................................. M · backend · BE4.0e, BE2.7, BE4.4
│  └─ PL3.5d  check-in push: category, tap and route ........................ S · platform · PL3.5a, PL5.1, PL5.3
└─ F7 the flow test
   └─ T05b   goals flow test .................................................. M · views · P16.2, P17.2, P16b, UIG.1, UIG.2, UIG.3
```

Counts: **4 pages** (GL-1, GL-2, GL-3, GL-4), **9 components** (C29.1–C29.5, M11, C21-i, UIG.2, UIG.3; reused ones not counted), **32 PRs**: backend 11, platform 4, views 17 (with T05b).

## 6. The queue, in build order

Each byte needs only merged work. Two in review at once per side.

| # | Backend | Platform | Views |
|---|---|---|---|
| 1 | BE4.0a (after BEA.2, BEA.4) | — (the integrator writes `Platform/Flows/Goals.swift` from contract 04) | UIG.0 |
| 2 | BE4.0b | PL3.5a (against fixtures) | C29.1, C29.4 |
| 3 | BE4.1a | | C29.2, C29.5 |
| 4 | BE4.1b | | C29.3 |
| 5 | BE4.0c → BE4.0f (after BE1.4) | PL3.5b (after BE4.1b) | C21-i (after #48), M11 |
| 6 | BE4.2 | | P16.1 (after C17-t) |
| 7 | BE4.0d → BE4.4 | PL3.5c | P16.2, P17.1 |
| 8 | BE4.0e → BE4.3 (after BE2.7) | PL3.5d (after PL5.1, PL5.3) | UIG.3, P17.2, UIG.2 |
| 9 | | | P16b, UIG.1 (after their Paper drawings) |
| 10 | integrator: the goals wiring PR (Sample → Live) | | T05b, then the local-staging run (layer 9) |

**Cross-side dependencies.**
- Views → integrator: `Platform/Flows/Goals.swift` (the protocol) before UIG.0; C17-t lands with podcasts (phase 3); the add sheet and the ended list need Paper drawings first.
- Platform → backend: PL3.5a builds on fixtures and switches to staging when BE4.1a merges; PL3.5b needs BE4.1b and BE4.4; PL3.5d needs BE4.3.
- Backend → other areas: BEA.2 (ownership), BEA.4 (spend counting for the daily judge), BE1.4 (guess listing), BE2.7 (the push sender).
- Contract 06 must show the check-in switch in settings; contract 07 must register the `goal.checkin` category and the goals deep links.

## 7. Founder questions (work goes ahead on the lean)

**Q1 · Which window do the counts cover?** Paper's card says "6 times" and "2"; GL-2 says "said 6 times · first on … · last on …" and "did this week". The brain gives hours this week and over the four weeks before.
- A. Card: said and did both over the last 28 days. GL-2 header: every mention since stated. GL-2 rows: this week, as drawn. *(lean: the bars compare like with like, and nothing in Paper's copy changes)*
- B. Everything this week. Matches "did this week" exactly, but said counts are tiny and noisy, and most cards would be empty most weeks.
- C. Said all time, did this week. The bars would compare months to days: the gap would look bigger than it is.
- Changes: only the snapshot's windows (BE4.0a) and the C29.1 accessibility label ("in the last four weeks").

**Q2 · What may Retro's one line say?** Paper's example "you talk about running most on sundays." needs a weekday engine that doesn't exist.
- A. Only earned lines: too early (days counted), "you do this more than you mention it" (did ≥ 3 and did ≥ 2 × said), or a live pattern the brain linked to this goal. Otherwise no line. *(lean)*
- B. A plus weekday arithmetic ("most on sundays") once a brain byte counts it, with a threshold (≥ 4 mentions, ≥ 50% on one day).
- C. A model-written line per goal. No: it puts an unchecked sentence on the screen.
- Changes: B adds one brain byte and one `RetroLine.kind`.

**Q3 · Where do "is that a goal?" questions come from, and who turns them on?**
- A. From the brain's `stated_goal` facts with an exact quote from your entry, not already a goal and not declined; behind a new dial `goal_questions.speak`, **off** until you turn it on, like D11. *(lean)*
- B. The same, but on by default (it's your own words, lower on the ladder than a guess).
- C. From hypotheses (Q10, "what they want and never named"). No: those are guesses about wants, not quotes.
- Changes: B removes the dial check; C moves the source to BE4.0f's table.

**Q4 · Check-ins.**
- A. Off by default per person (a switch in settings); a goal counts as quiet after 21 days with no mention and nothing done; at most one a week; 10:00–20:00 local; the push says only "a question about one of your goals."; "yes" restates it, "not quite" turns it off with undo. No model call. *(lean)*
- B. As A, but on by default.
- C. The old `/notifications/generate` (a model call over legacy tables). No: it mostly sees nothing for new users and writes copy we can't check.
- Changes: B flips one default; the 21-day and weekly numbers are constants in BE4.0e.

**Q5 · Where does the ended row's › go?** Not drawn.
- A. GL-3, a plain list in the settings-page layout ("ended", small centred title), each row "run a 10k · turned off 12 oct ›" opening GL-2's turned-off state. *(lean; needs a Paper drawing before P16b)*
- B. Expand the ended goals in place under the row.
- C. No destination: the row is a count only, and "turn back on" lives only in GL-2 when reached from a link.

**Q6 · Adding a goal (+).** Not drawn on hi-fi; mid-fi says "add a goal by voice or text".
- A. A sheet: one title "what are you working toward?", the voice composer (#56), save (lit). *(lean; needs a Paper drawing before UIG.1)*
- B. Say it in the journal and let Retro ask "is that a goal?" (no + at all). Simpler but slower, and the + is already drawn.

**Q7 · Did rows: what does a tap do, and where is "not right"?** Mid-fi had "not right" on each row; hi-fi draws a chevron.
- A. A row opens its source when the app has a page for it (journal entries → JR-4; calendar and videos get one when YO-3 lands), and shows the chevron only then. "not for this goal" is in the long-press menu, with an undo toast. *(lean)*
- B. A visible "not right" on every row, as mid-fi. More honest-looking, but noisier and against the approved drawing.

**Q8 · "Done".** Paper's foot is "turn off" only. A. No "done" in v1. *(lean)* B. Add "done" beside "turn off" (status `done`, its own ended count and a quiet `pop` moment).

**Q9 · Deleting a goal.** A. No delete; rename fixes typos and turn off ends it. *(lean)* B. Delete inside "edit" with a destructive dialog.

**Q10 · The label on a check-in card.** The grey card's label reads "a guess", but "still working toward this?" isn't a guess. A. Label it "a question" for check-ins, "a guess" for "is that a goal?" and GL-2's guess. *(lean)* B. "a guess" on all three, as drawn. C. No label on check-ins.

**Also waiting on the founder, owned elsewhere:** the toast look (#48), whether grey becomes the guess look everywhere (design-reference #28), the D11 `speak` dial for GL-2's guess, and approving the dark boards `2JCP-0` / `2JRP-0`.

## 8. Risks

| Risk | Mitigation |
|---|---|
| The said-vs-did judge links the wrong things, and "did" reads as a fact | every row is correctable (BE4.0c), "when unsure, leave it out" stays in the judge prompt, counts recompute at once |
| `status` and `is_active` disagree (decline sets only `is_active`; readers differ) | BE4.1b moves every write through `lifecycleFor`, adds a check-constraint test, and the doors read `status` only |
| The daily judge scans all calendar rows and costs a model call per person per day | the snapshot (BE4.0a) runs once a day, counted by BEA.4, skipped (not failed) at the cap; cost logged in `cost-per-user.md` |
| UTC in the brain vs local days on screen | the door converts `on` dates with `users.time_zone`; the 7-day window is computed in the brain with the zone passed in (BE4.0a) |
| Old app's goal sync revives merged goals | `blocksRevival` stays; PL3.5c reconciles once and the old sync is switched off with the flow |
| A check-in push leaks a goal on the lock screen | the payload has no goal words (contract 04 §7); a test scans the payload |
| Paper not re-read for this plan | every views card reads values with `get_jsx` before building; the first PR of each component posts side-by-sides |

## 9. Changes needed in shared files (for the integrator)

- `contracts/README.md`: mark 04 as "draft for review" and link it.
- `ui/later.md` Phase 4: replace the four rows with this folder's tree (C29 split into C29.1–C29.5; new P16b, UIG.0–UIG.3).
- `backend/later-phases.md` Phase 4: BE4.1–BE4.3 are now BE4.0a–f, BE4.1a/b, BE4.2, BE4.3, BE4.4; BE4.3 no longer uses `/notifications/generate`.
- `plumbing/outline.md`: PL3.5 splits into PL3.5a–d.
- `contracts/01-first-run.md` §2: `POST /v2/goals` now also takes `clientGoalId` (idempotency) and `quote`.
- Contract 06 (later): the check-in switch; contract 07 (later): `goal.checkin` and the goals deep links.
- `context.md` §5: add "said vs did is computed by a model call on every podcast run and isn't exposed" and "`declineGoal` sets `is_active` without `status`".
