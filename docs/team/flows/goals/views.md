# Goals · view cards

The tree on this side: **goals** › sample data (UIG.0) › GL-1 (C29.1 meter, C29.2 card, C29.4 ended row, P16.1, P16.2, M11) › questions (C29.3) › GL-2 (C29.5 header, P17.1, UIG.3, P17.2) › add and rename (UIG.1, UIG.2) › turn off and ended (C21-i, P16b) › the flow test (T05b). Contract: [04-goals.md](../../contracts/04-goals.md). Seam: `Platform/Flows/Goals.swift` ([platform.md](./platform.md) seam table).

**Verified against Paper, 21 Oct** (light file `01M5D5J321P5X86ZT58002B7NT`, tokens hash `e8f98ba6`): GL-1 `1FZO-0` and GL-2 `1G3Z-0` were read with `get_jsx` / `get_computed_styles` / `get_tokens`, and every value below for C29.1–C29.5, P16.1, P17.1 and P17.2 is Paper's, with its token. The list of what changed from the first draft is at the end of this file. The part-48 masters (`ITY-0`) and the approvals boards weren't re-read; the GL-1/GL-2 instances are the approved screens. Every card's first step is still: open the named nodes with `get_jsx` (includeNodeIds false) and `get_computed_styles`, write each value's token into the PR body, and stop and ask if Paper disagrees with this card (the newest Paper wins; tell the integrator).

Rules that apply to every card here: tokens only (the literal check); squircles (`RShape`); one lit object per screen (none on GL-1/GL-2); lowercase labels, the person's words keep their case; Geist for labels and mono only for figures (screen rule 4: where Paper draws "said"/"did" in mono, follow Paper per element and note it in the PR; design-reference finding 31); 44pt hit areas; Reduce Motion = opacity-only 140ms; no verdict words ever (contract 04 §0.3).

---

### UIG.0 · SampleGoalsData and its scenarios                             size: M
Place in the tree: goals › data seam › sample implementation
Repo · branch: NPRdoinglaundry · `ui/UIG.0-sample-goals-data`
Needs: `Platform/Flows/Goals.swift` (integrator, from contract 04), T02, UI1.0 (the ledger's format)      Unblocks: C29.2, C29.3, C29.5, every goals page, T05b

Why: every goals screen can be built and tested in every state before the real data exists, and swapping in the real data changes nothing on screen.

Inputs: contract 04 §1–§7 and every `fixtures/04/*.json`; ui-engineer.md §4 (the seam rules); `docs/design/sample-data-ledger.md`.

Spec:
- `Features/Goals/Sample/SampleGoalsData.swift`: `@MainActor @Observable final class SampleGoalsData: GoalsData`, built from a `GoalsScenario`.
- **Content comes from the fixtures**, decoded at build time from `fixtures/04/*.json` (bundled into the test and debug targets only): "learn the cello", "walk to work on tuesdays", "finish the garden shed", "read before bed", the "call home more often" question. Never a real person's goal.
- `enum GoalsScenario: String, CaseIterable` — one per state any goals screen draws: `full`, `question`, `checkin`, `tooEarly`, `nothingYet`, `gap`, `doesMore`, `ended`, `empty`, `loading`, `error`, `offline`, `answering`, `answerFailed`, `turnedOffToast`, `long` (a 3-line title, AX3 text), `detailFull`, `detailTooEarly`, `detailNoRows`, `detailGuess`, `detailOff`, `detailFaded`, `detailMerged`, `detailNotFound`, `endedList`, `addEmpty`, `addTyping`, `addSaving`, `addFailed`.
- Actions behave like the contract on an injected clock: `answer` resolves after 600ms with the matching `question.answer.*` fixture; `setActive(false)` returns the `goal.update` shape; `add` returns `goal.create.response.json`; `answerFailed` returns `upstream_unavailable`; `loading` never resolves. No randomness.
- Every value logged in the sample-data ledger under "goals".

Acceptance: T02 opens every goals screen in every scenario; the wiring PR can swap to `LiveGoalsData` in one line.

Tests: (unit) "every scenario builds from the fixtures without a hand-written value" · (unit) "answering a question in the question scenario yields the goal-created fixture" · (unit) "loading never resolves".

Watch out: no counting or wording in the sample: the same rule as live (the door decides `card.state` and `line.text`).

---

### C29.1 · Said/did meter row                                           size: S
Place in the tree: goals › GL-1 › goal card › said/did meter row
Repo · branch: NPRdoinglaundry · `ui/C29.1-goal-meter`
Needs: T01      Unblocks: C29.2

Why: the gap between what you say and what you do is visible in one glance, in words as well as bars.

Inputs:
- Paper: part 48 `ITY-0` (inside `c:goal-card/rest` `IXB-0`); GL-1 instance `1G2R-0`
- Spec: design-reference §C29 anatomy; `goal.md` rules 1–2
- Code anchors: `RTextStyle`, `RProgressHairline` (#38, for the track's corner and fill behaviour to match), tokens `goal.said`, `goal.did`, `surface.track`

Spec:
- `RGoalMeter(label: String, countText: String, fill: Double, tint: .said | .did, replacement: String?)`, one `HStack(spacing: space.3 = 12)`, centred vertically:
  - label "said" / "did": **mono** (`font.mono`) `text.xs` 11, `tracking.label`, `leading.snug`, `text.label`, fixed width 28 (Paper keeps mono here, against screen rule 4; follow Paper and note it in the PR);
  - track: 4 high, `surface.track`, `radius.control` (a true pill), clips its fill; fill `goal.said` / `goal.did`, same radius, full height;
  - the count in words: **Geist** (`font.label`) `text.sm` 12, `text.secondary`, `leading.snug`, trailing-aligned in a fixed 64 width, wraps rather than truncates ("6 times", "4 hours", "1 night").
- The two rows stack with `space.2` = 8 between them.
- `fill` is a 0…1 value the card passes; a count above 0 always shows at least a 4pt fill (a pill end), a count of 0 shows the bare track.
- `replacement`: when set (too early), the track **and** the count are replaced by one text filling the rest of the row: "too early to tell", Geist `text.sm` 12, `text.label` (Paper `1G25-0`).
- Increase Contrast: the track gets a 1pt ring (`border.control`); the did fill is the 4 : 1 value (`goal.did` already raised, design-reference).
- AX3: label above, bar full width, count trailing under it.

State table:

| State | Look | Motion | Haptic |
|---|---|---|---|
| rest | as above | the fill grows from 0 once on first appearance (`curve.move`, `duration.slow`) | — |
| value changed | the fill eases to its new width; the count rolls (`.numericText`, `.monospacedDigit`) | `spring.sheet` (M11 drives it) | — |
| too early | "too early to tell" in place of the bar | — | — |
| zero | the bare track, "0" | — | — |
| dark | goal tokens' dark values | — | — |
| Reduce Motion | fill appears at its width; counts swap | — | — |

Accessibility: the row isn't its own element; the card reads it ("said 6 times, did 2").

Acceptance: matches `ITY-0`'s rows in light, dark and AX3; a 0 shows no fill; a 1 shows a visible end.

Tests: (snapshot) said and did rows at 0, 1, mid and full, light, dark and ax3 · (snapshot) the too-early replacement · (unit) "a count above zero always draws at least a pill end".

Watch out: the bar's width comes from `fill`, never computed here from counts (C29.2 owns the shared scale).

---

### C29.2 · Goal card                                                    size: M
Place in the tree: goals › GL-1 › goal card
Repo · branch: NPRdoinglaundry · `ui/C29.2-goal-card`
Needs: C29.1, UIG.0      Unblocks: P16.1, M11

Why: each goal you're working toward shows, honestly, how often you talk about it and what you did for it, with nothing added it can't show.

Inputs:
- Paper: part 48 `ITY-0`: rest `IXB-0`, too early `IY9-0`; GL-1 instances `c:goal-card/rest` `1G2R-0`, `c:goal-card/too early` `1G21-0`; unchosen styles `LOV-0`, `LP2-0`, `LQ4-0` (archived, don't build)
- Spec: design-reference §C29 (anatomy, states, accessibility, taken out); `goal.md`; contract 04 §1 `GoalCard`
- Code anchors: `rRaised`/card tier in `RDepth.swift`, `.rPress`

Spec:
- `RGoalCard(goal: Goal)`: `background.raised`, `radius.card` 20, the full card depth stack (inner-top 1pt, inner 1pt, outer 0.5pt hairline, contact 0/1/2, cast 0/12/28/−12, ambient 0/24/60/−20: `RDepth.card`); padding **top 16 (`space.4`), sides and bottom 20 (`space.5`)**; a `VStack(spacing: space.3 = 12)`: title = the goal's words, SF Pro (`font.text`) `text.body` 17 semibold, `tracking.card`, `leading.snug`, balanced wrap, 3 lines then ellipsis; the two meter rows (C29.1); the line when `card.line` exists: SF Pro `text.md` **14**, `text.secondary`, `leading.snug`, balanced wrap. Width = the column (354 on a 402 phone).
- **Shared scale:** `scale = max(said.count, did.count, 1)`; `fill = count / scale` for each row. That's presentation of the server's two numbers, not a judgement; it's written once here and unit-tested.
- **States from `card.state`** (the view never decides them):
  - `compared`: both bars, counts in words ("6 times" / "2").
  - `tooEarly`: said bar as usual; did row replaced by "too early to tell"; the line is the door's too-early line.
  - `nothingYet`: no bars; one line "nothing to compare yet" (`text.secondary`) in the bars' place; no Retro line.
  - "a gap" isn't a state: it's `compared` with uneven numbers; there's no word, colour or icon for it (`goal.md` rule 2).
- Whole card is one button (pushes GL-2), press 0.98 (80/240).

State table:

| State | Look | Motion | Haptic |
|---|---|---|---|
| rest | as above | bars fill once on first view (C29.1) | — |
| pressed | 0.98 | 80 / 240 | — |
| too early | did row "too early to tell" | — | — |
| nothing yet | no bars, "nothing to compare yet" | — | — |
| loading | skeleton in the card's shape (C39.1: title bar, two track bars) | shimmer | — |
| folding (M11) | see M11 | `sheet` | — |
| focused | system focus ring | — | — |
| dark | goal tokens dark | — | — |
| disabled, error, offline, empty, pending | n/a on the card: the page owns them (P16.1) | — | — |

Interaction table:

| Touch | Press | Haptic | Motion | Outcome | Reduce Motion |
|---|---|---|---|---|---|
| tap | 0.98 | — | push (system) | GL-2 for this goal | push without zoom |

Accessibility: one element, button trait; label "<title>. said 6 times, did 2. <line>." (in the last four weeks, per Q1's lean, as a hint); too early: "<title>. said once. too early to tell. 9 days in. i'll know more next week."; nothing yet: "<title>. nothing to compare yet."; AX3: bars full width under the text; contrast checked by script.

Acceptance: rest, too early and nothing yet match `IXB-0`, `IY9-0` and the handoff copy in light, dark and AX3; a 3-line title ellipsises on the third line; nothing on the card reads as praise or blame.

Tests: (snapshot) compared (a gap and does-more), too early, nothing yet, loading, long title; light, dark, ax3 · (unit) "the bars share one scale and the larger count fills the track" · (unit) "nothing yet shows no bars" · (UI) "VoiceOver reads the card as one sentence with both counts".

Proof: standard proof against `IXB-0`, `IY9-0`, `1G2R-0`, `1G21-0`.

Watch out: Paper names the state "too early" with a space (`c:goal-card/too early`): name-matching scripts must quote it (paper-inventory finding 8).

---

### C29.3 · Question card, grey                                            size: M
Place in the tree: goals › questions › question card (used on GL-1 for "is that a goal?" and "still working toward this?", and on GL-2 for the goal's guess)
Repo · branch: NPRdoinglaundry · `ui/C29.3-goal-question-card`
Needs: #45 (`RPill` raised), S01 (`RIconWell`), the `guess` glyph (#46's icon request; `c:icon/guess` has no master: read `1G3G-0`), UIG.0, T01      Unblocks: P16.2, P17.2, M11

Why: when Retro isn't sure, it asks, quoting you, and one tap answers it.

Inputs:
- Paper: part 48 guess `IYO-0`; GL-1 `c:goal-card/guess` `1G35-0` with `c:icon-well/guess` `1G3F-0`, `c:icon/guess` `1G3G-0`, `c:pill/raised` `1G39-0`; GL-2 `c:claim/asked · a pattern` `1G45-0` with `1G4F-0`, `1G4G-0`, `1G49-0`
- Spec: design-reference §C29 "question card" (grey `surface.wash`, no dashed outline; "a guess" label led by the guess icon in a 32 raised-paper well; two equal-width raised-paper buttons, 44, `surface.lifted`); build notes "Goals: retro's question card"; C28's behaviour (states, rules) for everything the grey look doesn't change
- Code anchors: C28 `RGuessCard` (behaviour to mirror, not colours: C28's card says "don't parametrise colours for the grey variant"; this byte is that variant, a separate view sharing C28's state enum)

Spec:
- `RGoalQuestionCard(kind: .isThisAGoal(question, quote) | .stillOnIt(question, goalTitle) | .guess(Guess), state:)`.
- Anatomy (Paper `1G35-0`, `1G45-0`): `surface.wash` card, `radius.card` 20, no shadow, no stroke; a `VStack(spacing: space.3 = 12)`.
  - Padding: on GL-1 **top 16, sides and bottom 20** (same as the goal card beside it); on GL-2 **16 all round**. The view takes the padding from its page (`.list` / `.page`).
  - Label row (`HStack(spacing: space.2 = 8)`): a 32 well, **`background.canvas`** (in light; `surface.lifted` per the dark recalibration), `radius.control` (round), 0.5pt `depth.stroke.outer` hairline, holding the `guess` glyph at 18 in `accent.text`; then the label, Geist `text.sm` 12 **medium**, `text.label`, `leading.snug`. The label names the kind: **"a guess · a goal?"** on is-that-a-goal, **"a guess · a pattern"** on GL-2's guess (lean for check-ins, Q10: "a question · still on it?").
  - The question in the **inky display face** (`font.displayInky`) `text.xl` 22, weight `ink.card`, `tracking.card`, `leading.tight`, balanced wrap, `text.primary`.
  - Paper draws **no quote line and no why line**: the paraphrase is in the question itself. The contract's `quote` and the guess's `restsOn` stay in the data for VoiceOver and a later "where from" tap; don't draw them (newest Paper wins; noted in README Q3).
  - Buttons: an `HStack(spacing: space.2 = 8)` with `space.1` = 4 extra above it; two equal-width (flex 1) **true pills** (`radius.control`), 44 high (`size.navBar`), `background.canvas` with a 0.5pt `depth.stroke.outer` and a contact shadow 0/1/1.5 (`depth.shadow.contact`), label SF Pro `text.md` 14 semibold `text.primary`. Copy **"yes" · "not quite" on every kind**, including GL-2's guess (not C28's "that's right").
- Never dashed: grey is the goals look (build notes); C28's dashed look stays for the journal until the founder decides "grey everywhere" (design-reference finding 28).

State table:

| State | Look | Motion | Haptic |
|---|---|---|---|
| rest | as above | arrives with `.rAppear` (blur-in) | — |
| pressed (button) | 0.94 | 80 / 240 | — |
| pending | the chosen button shows `RSpinner(diameter: 16)`, the other dims to `opacity.pending` | `spin` | — |
| answered | buttons vanish (never greyed); the card hands over to M11 | M11 | `confirm` (yes), `select` (not quite) |
| error | "couldn't save that · try again" under the buttons, buttons back | blur-in | `error` |
| offline | answers queue; the card folds as usual (the outbox sends later) | M11 | as answered |
| focused | system | — | — |
| dark | `surface.wash` and `surface.lifted` dark values | — | — |
| loading, empty, disabled | n/a (no card without a question) | — | — |

Interaction table:

| Touch | Press | Haptic | Motion | Outcome | Reduce Motion |
|---|---|---|---|---|---|
| yes | 0.94 | `confirm` on success | M11 fold | goal created / kept / guess confirmed | fade 140 |
| not quite | 0.94 | `select` | M11 fold | declined / turned off (P16.2's toast) / guess declined | fade 140 |
| (the quote isn't drawn) | — | — | — | VoiceOver reads it; a visible "where from" waits for a drawing | — |

Accessibility: one container: "a guess: you keep saying you want to call home more. is that a goal? you wrote on 17 october: i really want to call home more often." with two buttons "yes" and "not quite"; AX3: buttons stack, full width; Increase Contrast: the card gets a 1pt `border.control`; contrast of `accent.text` on the lifted well checked by script.

Acceptance: matches `1G35-0` and `1G45-0` in light, dark and AX3; both buttons equal width at every size; nothing dashed.

Tests: (snapshot) is-that-a-goal, still-on-it and guess, rest, pending and error; light, dark, ax3 · (UI) "VoiceOver reads the question with its quote and offers yes and not quite" · (unit) "answered hides the buttons instead of greying them".

Watch out: GL-2's instance is named `c:claim/asked · a pattern`: the description is part of the name (paper-inventory finding 8).

---

### C29.4 · Ended row                                                     size: S
Place in the tree: goals › GL-1 › ended row
Repo · branch: NPRdoinglaundry · `ui/C29.4-goals-ended-row`
Needs: T01      Unblocks: P16.1, P16b

Why: goals you've ended aren't gone or hidden; they're one quiet line away.

Inputs: Paper part 48 `c:goal-row/faded` `IYZ-0`, GL-1 `1G1X-0` with `c:icon/chevron-right` `1G1Y-0`; design-reference §C29 ("ended: one quiet row 'turned off 2 · merged 1 ›' at the bottom").

Spec: `RGoalsEndedRow(counts: EndedCounts)`: a **`surface.wash` panel**, `radius.panel` 16, min height 56 (`size.rowDefault`), padding 12 vertical (`space.3`) and 16 horizontal (`space.4`), `HStack(spacing: 12)`; the text SF Pro `text.md` 14, `text.secondary`, the non-zero counts in order turned off · faded · merged · done ("turned off 2 · merged 1"); the chevron at 14, `icon.muted`. No divider (Paper draws none). All zero → `EmptyView` (P16.1 doesn't draw it). Press: the panel darkens to `surface.washPressed`, 80/240.

States: rest · pressed (wash) · dark · AX3 (wraps, chevron stays centred on the first line) · count changed (`.numericText` roll, `confirm` is the page's).

Accessibility: "ended goals: 2 turned off, 1 merged. button."

Tests: (snapshot) one kind, three kinds, ax3, dark · (unit) "zero counts are left out and all zero draws nothing".

---

### C29.5 · Goal header (GL-2)                                            size: S
Place in the tree: goals › GL-2 › goal header
Repo · branch: NPRdoinglaundry · `ui/C29.5-goal-header`
Needs: UIG.0, T01      Unblocks: P17.1, UIG.2

Why: one goal's page opens on the goal itself, in your words, big, with how often you've said it.

Inputs: Paper GL-2 `1G3Z-0` (the title block and the said line; no separate master); design-reference §C29 "GL-2 page variant: goal inky 3xl, 'said 6 times · first on … · last on …'"; screen rule 5 (content inky and big).

Spec: `RGoalHeader(title:, said:, ended:)`: the title in the inky display face (`font.displayInky`) `text.3xl` 30, weight `ink.title`, `tracking.title`, `leading.tight`, balanced wrap, `text.primary`, never truncated; 8 below (`space.2`), the said line **Geist `text.sm` 12, `text.label`**, `leading.snug`: "said 14 times · first on 30 sep · last on sunday" (dates: "today", "yesterday", weekday within 6 days, else "d mmm"; `firstOn`/`lastOn` from the contract as days); said 0 → "not said yet"; ended → the dated line replaces it ("turned off on 12 oct", "faded on 1 aug: not mentioned for 90 days", "merged into learn the cello on 4 sep").

States: rest · long title (3+ lines wraps fully) · ended · dark · AX3 · renaming (UIG.2 swaps the title for a field).

Accessibility: the title is a header; the said line is its value.

Tests: (snapshot) active, ended (three kinds), long title, ax3, dark · (unit) "dates within a week read as weekdays, older ones as day and month".

---

### C21-i · Toast: "turned off · undo"                                       size: S
Place in the tree: goals › turn off › toast
Repo · branch: NPRdoinglaundry · `ui/C21-i-goals-toast`
Needs: #48 (`RToast`, the founder's chosen look)      Unblocks: P16.2, P17.2, UIG.3

Why: ending a goal or removing something is instant and undoable, instead of a dialog asking "are you sure?".

Inputs: approvals `2FI5-0` (toast/undo/rest `2FIL-0`, pressed `2FIR-0`, plain `2FIX-0`, ax3 `2FJ3-0`, dark `2FJB-0`/`2FJF-0`); design-reference §toast (44 high, SF Pro 14 medium, undo semibold with a 44 hit, 12 above the tab bar or mini-player, `layer.toast` 60; in on `popover`, 2pt float on a 5s sine, swipe away, auto-dismiss after 4 s on `curve.exit`); sheet rules ("never a dialog for an undoable choice").

Spec: a goals-wide `GoalsToast` host on the goals tab's root, presenting `RToast(.undo(text:action:))` for: "turned off · undo" (after GL-2's turn off or a check-in's not quite), "removed · undo" (UIG.3), and the error variant "couldn't save that · try again". One toast at a time; a new one replaces the old (the old one's undo window ends). The undo calls `undoTurnOff` / `undoRemoveDid`. Survives the pop from GL-2 to GL-1 (the host sits above the navigation stack).

Interaction table:

| Touch | Press | Haptic | Motion | Outcome | Reduce Motion |
|---|---|---|---|---|---|
| (appears) | — | `confirm` as it lands | `popover` in | — | fade 140 |
| undo | 0.94 | `select` | toast out on `curve.exit`; the goal's card unfolds back (M11 reversed) | undone | fade |
| swipe away | follows the finger | — | velocity flick | dismissed | fade |
| (4 s) | — | — | out on `curve.exit` | dismissed | fade |

Accessibility: announced once ("turned off learn the cello. undo available."); undo is an action; the toast stays while VoiceOver focus is on it.

Tests: (snapshot) turned off, removed, error; light, dark, ax3 · (UI) "turning a goal off shows a toast whose undo brings it back" · (UI) "a second toast replaces the first".

Watch out: the toast look is the founder's pending pick (#48); build against `RToast.Look` and don't hard-code one.

---

### M11 · The card folds, the bar eases                                     size: M
Place in the tree: goals › GL-1 › motion › M11 (signature moment)
Repo · branch: NPRdoinglaundry · `ui/M11-goal-fold`
Needs: C29.2, C29.3      Unblocks: P16.2

Why: answering Retro feels settled and physical: the question folds away, the list closes up, and what changed eases into place.

Inputs: design-reference §M11 ("answer yes / not quite: the card folds away and the goal's bar eases to its new value", `spring.sheet`, `duration.slow`, `confirm`); motion-system ("goal cards fold away on `sheet` and the list closes the gap on `map`"); part 48 `ITY-0`; motion-moments' delete fold (height to 0 while sliding a few points, neighbours close the gap).

Spec:
- `.rGoalFold(isFolded:)` modifier and a `GoalsListTransition` used by P16.1's `LazyVStack`:
  1. the answered card's buttons vanish (C29.3 answered);
  2. the card folds: height → 0 on `spring.sheet` while it slides up 4pt and fades to 0 (opacity on `curve.exit`, ~0.6 of the fold's duration);
  3. the list closes the gap on `RMotion.map`;
  4. if the answer created or kept a goal, its card appears at the top with `.rAppear` (blur 8 → 0, rise 8pt), and its said bar eases from 0 to its value on `spring.sheet`, `duration.slow`; `confirm` fires as the bar settles.
- The same transition, reversed, for undo.
- Interruptible: a second tap mid-fold (on another card) never waits; the fold retargets from where it is.

Interaction table:

| Moment | Motion | Haptic | Reduce Motion |
|---|---|---|---|
| yes on is-that-a-goal | fold (1–3), new card in (4) | `confirm` on settle | the card fades out 140, the new card fades in 140, bars appear filled |
| not quite on is-that-a-goal | fold (1–3) | `select` on tap | fade out 140 |
| yes on still-on-it | fold, the goal's card re-renders too early (its did row cross-fades to "too early to tell" with `.rBlurReplace`) | `confirm` | fade |
| not quite on still-on-it | fold the question and the goal's card together, toast in | `confirm` with the toast | fade |
| turn off from GL-2 | on return to GL-1 the goal's card folds (1–3) | the toast's `confirm` | fade |
| undo | the reverse: the card unfolds into its old slot | `select` | fade |

Acceptance: the recording matches part 48's intent; nothing jumps; a fold can be interrupted; Reduce Motion is opacity-only.

Tests: (motion) "folding a card keeps the hitch ratio within baseline" (Instruments, trend) · (UI) "answering a question removes its card and closes the gap" (asserts frames of neighbours) · (snapshot) the mid-fold frame frozen with `.rFrozen`.

Proof: recordings of each row, one interrupted mid-fold, and Reduce Motion.

---

### P16.1 · GL-1: layout, the list and its states                        size: M
Place in the tree: goals › GL-1 › page (layout, list, states)
Repo · branch: NPRdoinglaundry · `ui/P16.1-goals-list`
Needs: C29.2, C29.4, C17-t (top bar title with the wash +; phase 3), C18, C39 (C39.1–C39.4), UI0.1      Unblocks: P16.2

Why: one calm place shows what you're working toward, newest-moving first, and never pretends when it doesn't know.

Inputs:
- Contract: 04 §2
- Paper: GL-1 `1FZO-0` (approved): top bar `1G3J-0` with `c:icon-button/wash/add` `1G3K-0` and `c:icon/add` `1G3M-0`; cards `1G2R-0`, `1G21-0`; ended row `1G1X-0`; tab bar `1FZS-0`. Dark `2JCP-0` (waiting for approval: build from tokens, compare when approved)
- Reference: §E P16 ("full-width cards, 12 gaps, blur starts higher" on SE; empty copy); `ios-handoff.md` §3 GL-1

Spec (layout):
- `GoalsPage`: one `ScrollView` with a `LazyVStack(spacing: space.4 = 16)`, 12 above the first item (`space.3`), margins 24 (`space.screenMargin`; 20 on SE); the top bar (C17-t, 44 high: "goals" leading at the screen margin, the wash + as a 36 well in a 44 hit area, 16 from the trailing edge); the progressive blur at the tab edge (`.tabEdge`): Paper draws the scroll masked from solid at 620pt to 50% at 655 to clear at 690, over a blurred copy, under a light tint behind the tab labels (150 high).
- SE: Paper's handoff note says "12 gaps" on SE: use 12 there, 16 on every other phone.
- Order: the question slot (P16.2), then the goal cards in the server's order, then the ended row (C29.4) when any count is above 0, at the same 16 gap (Paper draws no extra space before it).
- **No lit object** on this page. The + is a quiet wash icon button (UIG.1 opens from it).
- The mini-player floats above the tab bar when something is loaded; the list's bottom inset grows with it.

State table (page):

| State (T02 `-State`) | What shows |
|---|---|
| `full` | as Paper `1FZO-0` |
| `tooEarly` / `nothingYet` / `gap` / `doesMore` | C29.2's states in place |
| `ended` | the ended row with counts |
| `empty` | C39.2: "nothing yet." (inky) + "say what you're working toward, or wait and i'll notice." (`text.secondary`); the + still in the top bar. No sample cards, no illustrations of fake goals |
| `loading` | after 400ms: three skeleton cards (C39.1); before that, nothing |
| `error` | C39.3 in the list's place: "couldn't load your goals." + "try again" |
| `offline` | the cached list + the offline line (C39.4) under the top bar; with no cache, C39.3 with the offline wording |
| `long` | a 3-line title; AX3 throughout |
| SE | 20 margins, 12 gaps, the blur starts higher |

Interaction sheet:

| # | Moment | What happens | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|---|
| 1 | arrive (tab) | the list at the top; bars fill once (first view per session) | C29.1 fill | — | filled |
| 2 | load > 400ms | skeleton cards | shimmer | — | pulse |
| 3 | pull to refresh | the refresh moment (motion-moments: orb stretch) | `popover` | `refresh` | fade |
| 4 | tap a card | push GL-2 | system push | — | no zoom |
| 5 | tap + | the add sheet (UIG.1) | `sheet` | — | fade |
| 6 | tap the ended row | push GL-3 (P16b) | push | — | — |
| 7 | re-tap the goals tab | scroll to top on `gentle`; on GL-2, pop to GL-1 | `gentle` | `tab` | jump |
| 8 | come back from GL-2 | scroll position kept | — | — | — |
| 9 | data refreshes while visible | changed counts roll, bars ease; new cards `.rAppear`; gone ones fold (M11's fold) | `spring.sheet` | — | fade |

Accessibility: rotor order top bar → question (P16.2) → cards → ended row → tab bar; the + reads "add a goal"; `performAccessibilityAudit()` passes in `full`, `empty` and `offline`.

Acceptance: every state matches Paper (`1FZO-0`; others against component nodes) in light, dark (when `2JCP-0` is approved) and AX3, plus SE; the empty state shows no invented goals.

Tests: (snapshot) full, empty, loading, error, offline, tooEarly, nothingYet, long; light, dark, ax3, SE (full) · (UI) "tapping a goal opens that goal" · (UI) "the ended row opens the ended list" · (UI) "re-tapping the tab scrolls to the top" · (accessibility) the audit in full, empty and offline.

Proof: page proof (ui-engineer §5) and recordings of rows 1, 3, 7 and 9.

Watch out: `LazyVStack` identity must be the goal id (stable across refresh) or M11 animates the wrong card.

---

### P16.2 · GL-1: the question, the toast and the fold                    size: M
Place in the tree: goals › GL-1 › page (questions, toast, M11)
Repo · branch: NPRdoinglaundry · `ui/P16.2-goals-questions`
Needs: P16.1, C29.3, C21-i, M11      Unblocks: T05b

Why: when Retro has a question, it's the first thing on the page, and answering it changes the list in front of you.

Inputs: contract 04 §2 (`questions`, at most one), §5, §7 (a check-in arrives first); build notes "Goals list: questions lead"; Paper `1G35-0`.

Spec:
- The question slot at the top of the list holds `list.question` (a check-in first, by the server's choice) using C29.3; with none, the slot is absent (no space reserved).
- Answers call `answer(questionId:_:)` and drive M11 by outcome (M11's table). `turnedOff` shows C21-i's "turned off · undo". `.failed` restores the card with C29.3's error line. `.queued` folds as if answered.
- A check-in opened from a push (PL3.5d's `pinnedQuestionId`) is scrolled to and gets one `pop` emphasis (scale 1 → 1.02 → 1 on `pop`), no haptic.

State table (adds to P16.1's): `question`, `checkin`, `answering` (pending), `answerFailed`, `turnedOffToast`.

Interaction sheet:

| # | Moment | What happens | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|---|
| 1 | arrive with a question | the question card leads the scroll | `.rAppear` | — | fade |
| 2 | yes / not quite | M11 per outcome | M11 | M11 | M11 |
| 3 | answer fails | the card returns with its error line | blur-in | `error` | same |
| 4 | not quite on a check-in | the question and its goal fold; toast "turned off · undo" | M11 + toast | `confirm` | fade |
| 5 | undo | the goal unfolds into its old place | reverse | `select` | fade |
| 6 | open from a check-in push | GL-1 with that question first, one soft pop | `pop` | — | none |

Accessibility: a new question is announced once when the page appears; after an answer, focus moves to the next element (the first card).

Tests: (snapshot) question, checkin, answering, answerFailed, turnedOffToast · (UI) "saying yes to is-that-a-goal adds the goal at the top" · (UI) "not quite on a check-in turns the goal off and undo brings it back" · (UI) "a failed answer keeps the question with a retry" · (accessibility) the audit with a question showing.

Proof: page proof plus recordings of rows 2, 4 and 5.

---

### P17.1 · GL-2: layout, said, did rows and states                       size: M
Place in the tree: goals › GL-2 › page (layout, rows, states)
Repo · branch: NPRdoinglaundry · `ui/P17.1-goal-page`
Needs: C29.5, C32 (evidence row), C17 (entry top bar), C39      Unblocks: UIG.3, P17.2, UIG.2

Why: everything behind one goal on one page: your words, how often you've said it, and what you did this week, each with where it came from.

Inputs:
- Contract: 04 §3
- Paper: GL-2 `1G3Z-0` (approved, red dot hidden): top bar `c:top-bar/entry/rest` `1G5F-0` (back `1G5K-0`/`1G5L-0`, "edit" `c:button/text/rest` `1G5G-0`); rows `c:evidence-row/rest` `1G52-0` with `c:icon/calendar` `1G59-0`, `c:icon/journal` `1G4R-0`, chevron `1G53-0`; foot `c:pill/neutral` `1G42-0`. Dark `2JRP-0` (waiting)
- Reference: §E P17 ("sections 24 apart (32 → 24 on SE), foot 16 off the bottom; three evidence rows fit"); design-reference §C32 (grouped rows: 32 kind well, date/kind label, one line `text.md` with `.lineLimit(1)`, chevron, 1pt `border.subtle` separators); top bar rule (single-item screens get no title)

Spec (layout):
- `GoalPage(goalId:, titleHint:)`: top bar (44, 16 side padding): back as a 36 `surface.wash` round well in a 44 hit area (chevron-left 20, `icon.default`), "edit" trailing as a text button (Geist `text.md` 14 medium, `tracking.label`, `text.primary`, 44 high, 8 side padding); no title. Content: margins 24, **16 below the top bar**, sections `VStack(spacing: space.8 = 32)` (24 on SE): C29.5 header; the did section; the guess (P17.2). The foot sits outside the scroll (P17.2).
- The did section: `VStack(spacing: 8)`: the label "did this week · 4 hours" in **Geist `text.sm` 12 medium, `tracking.label`, `text.label`** (no mono: the hours are part of the label line); then one grouped panel: `background.canvas`, `radius.panel` 16, a 0.5pt `depth.stroke.outer` hairline, rows inside.
- Did rows (C32 as Paper draws it here): min height 56, padding 12 / 16, `HStack(spacing: 12)`; a 32 well, `surface.wash`, `radius.default` 10, glyph 18 `icon.default` by `kind` (`calendar`; `journal` for entries; `play` for watched, an asset request; `journal` for unknown); a `VStack(spacing: 2)` of the label (Geist `text.sm` 12, `text.label`: "tue 14 oct · calendar", **"fri 17 oct · your words"** for entries) and the one line (SF Pro `text.md` 14, `tracking.card`, `text.primary`, one line, tail truncation; entries in quotes: "\"finally fixed the sync bug\""); the chevron 14 `icon.muted`. Separators: a 1pt `border.subtle` line on the bottom of every row but the last.
- Paper draws the chevron on **every** row, calendar ones included. Q7's lean (chevron and tap only when `opens` is present; entry → JR-4) differs from the drawing: build the lean, and the PR shows both for the founder.
- No rows this week: one line in the rows' place, "nothing this week yet." (`text.secondary`). During `tooEarly`, rows still list (they're facts).
- `titleHint` (from the list) shows at once while the detail loads; the rest is skeleton after 400ms.

State table (page):

| State | What shows |
|---|---|
| `detailFull` | as `1G3Z-0` |
| `detailTooEarly` | header + rows, no guess |
| `detailNoRows` | "nothing this week yet." |
| `detailGuess` / no guess | P17.2 |
| `detailOff` / `detailFaded` / `detailMerged` | the ended header line; no rows section; foot "turn back on" (P17.2) |
| `loading` | the title from the list + skeleton rows after 400ms |
| `error` | C39.3 under the header |
| `offline` | the cached page + the offline line; no cache → C39.3 offline |
| `detailNotFound` | C39.2 "that isn't here any more." with back; never navigates on its own |
| SE | sections 24 apart, foot 16 off the bottom |

Interaction sheet:

| # | Moment | What happens | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|---|
| 1 | arrive (push) | header first, rows after | system push | — | — |
| 2 | tap a row with a source | JR-4 for that entry | push | — | — |
| 3 | long press a row | UIG.3's menu | `popover` | `longPress` | fade |
| 4 | tap edit | UIG.2 | — | — | — |
| 5 | back / edge swipe | GL-1, scroll kept | system | — | — |

Accessibility: rotor order back → edit → title → said line → rows → guess → foot; each row "tuesday 14 october, calendar, cello lesson, 1 hour" (+ ", button" when it opens); the audit passes in detailFull, detailOff and offline.

Tests: (snapshot) every state above; light, dark, ax3, SE (full) · (UI) "an entry row opens that entry" · (UI) "a calendar row doesn't pretend to open" · (UI) "a turned-off goal shows its date and turn back on" · (accessibility) the audit.

Proof: page proof against `1G3Z-0`.

---

### UIG.3 · Did-row menu: "not for this goal"                              size: S
Place in the tree: goals › GL-2 › did rows › menu
Repo · branch: NPRdoinglaundry · `ui/UIG.3-did-row-menu`
Needs: P17.1, C20, C21-i      Unblocks: T05b

Why: when Retro counted something that had nothing to do with your goal, you tell it in two taps, and you can take it back.

Inputs: contract 04 §6; C20's menu (popover host, rows); Q7's lean; mid-fi plan ("each with not right").

Spec: long press (or the VoiceOver action) on a did row → C20 menu with "open" (only when `opens`) and "not for this goal" (`correct` glyph). Choosing it: the row folds (M11's fold, row-sized), the header's counts and the hours roll when the recounted card arrives (PL3.5b), toast "removed · undo" (C21-i).

Interaction table:

| Touch | Press | Haptic | Motion | Outcome | Reduce Motion |
|---|---|---|---|---|---|
| long press row | lift | `longPress` | `popover` | menu | fade |
| not for this goal | wash | `confirm` with the toast | row folds, `map` close | removed | fade |
| undo | 0.94 | `select` | row unfolds | restored | fade |

Accessibility: a custom action "not for this goal" on every row.

Tests: (UI) "removing a row folds it and undo restores it" · (UI) "VoiceOver offers not for this goal on a did row" · (snapshot) the menu open.

---

### P17.2 · GL-2: the guess, turn off and turn back on                    size: M
Place in the tree: goals › GL-2 › page (guess, foot)
Repo · branch: NPRdoinglaundry · `ui/P17.2-goal-guess-and-foot`
Needs: P17.1, C29.3, C21-i      Unblocks: T05b

Why: Retro asks its one thought about this goal here, and ending a goal is one calm tap that you can undo.

Inputs: contract 04 §3 (`guess`), §4 (`active`); contract 02 §4 (answering a guess); Paper `1G45-0` (guess), `1G42-0` (foot pill); design-reference §C29 GL-2 ("foot 'turn off' only; turned off state shows a dated line, 'turn back on'"); goal rule 3.

Spec:
- Guess: C29.3 `.guess(guess)` 32 under the rows when `guess` is present; answering goes through the journal's `answer(_:verdict:)`; answered → the card folds (M11's fold) and doesn't return.
- Foot (Paper `1G40-0`, outside the scroll): centred, margins 24, **32 above the bottom** (`space.8`; 16 on SE per the handoff); one pill 32 high (`surface.wash`, `radius.control`, 16 side padding, SF Pro `text.md` 14 medium `text.primary`) in a 44 hit area: "turn off" on an active goal; "turn back on" on an ended one. No dialog (sheet rule: never a dialog for an undoable choice).
- "turn off": `setActive(false)` → pop to GL-1 → the card folds there → C21-i "turned off · undo".
- "turn back on": `setActive(true)` → the header's dated line cross-fades (`.rBlurReplace`) to "said … · not said yet", the foot becomes "turn off", the page reloads too early; `confirm`.

Interaction sheet:

| # | Moment | What happens | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|---|
| 1 | yes / not quite on the guess | C29.3 → fold | M11 fold | `confirm` / `select` | fade |
| 2 | turn off | pop, fold on GL-1, toast | push back + M11 | `confirm` (toast) | fade |
| 3 | turn back on | header and foot swap in place | `.rBlurReplace` | `confirm` | fade 140 |
| 4 | either write fails | the change rolls back, the toast's error variant | blur-in | `error` | same |

Tests: (snapshot) withGuess, noGuess, off, faded, merged · (UI) "turning off returns to the list, folds the goal and offers undo" · (UI) "turning a faded goal back on shows it too early" · (UI) "answering the guess folds it away for good".

---

### UIG.2 · Rename on GL-2                                                  size: S
Place in the tree: goals › add and rename › rename
Repo · branch: NPRdoinglaundry · `ui/UIG.2-goal-rename`
Needs: P17.1 (and JR-4's editing pattern from P12)      Unblocks: T05b

Why: if the goal's words aren't quite right, you fix them where you read them.

Inputs: Paper GL-2 "edit" `1G5G-0`; handoff "'edit' renames"; JR-4 editing (`c:entry/words/editing` `G8U-0`; "cancel · 'edit this entry' · save, with save in plain ink").

Spec: "edit" → the top bar becomes cancel · "rename this goal" (small centred) · save (plain ink, enabled when the trimmed title differs and is 1–200 characters); the title becomes an editable field in the same inky face, cursor at the end, keyboard up; save → `rename(id:title:)`, the field returns to text with `.rBlurReplace`; cancel restores. Failure → the field stays with "couldn't save that · try again".

Tests: (UI) "renaming saves the new words and keeps the counts" · (UI) "cancel restores the old title" · (snapshot) renaming, light, dark, ax3.

Watch out: the title is the person's words: no auto-capitalisation or autocorrect changes on save beyond trimming.

---

### UIG.1 · The add sheet (GL-4)                                          size: M
Place in the tree: goals › add and rename › GL-4 add a goal
Repo · branch: NPRdoinglaundry · `ui/UIG.1-add-goal-sheet`
Needs: C19.1 (sheet host), #56 (`RVoiceComposer`), UIG.0; **a Paper drawing of this sheet approved by the founder** (Q6)      Unblocks: T05b

Why: you can name a goal the moment you think of it, by talking or typing.

Inputs: mid-fi plan ("(+) sheet: add a goal by voice or text"); Q6's lean; sheet rules ("say exactly what will happen"; spacing by group: title+line 8, break 32); the voice composer spec.

Spec (on the lean, to be matched to the drawing):
- C19.1 sheet at a fitted detent; title "what are you working toward?" (inky, one line); the voice composer (#56) focused for typing, mic available; your words appear in the field as you type or speak; save (lit, the one lit object) enabled with 1–200 trimmed characters; cancel by swipe or the grabber.
- Save → `add(title:description: nil)` → the sheet closes; on GL-1 the new card `.rAppear`s at the top, too early.
- Offline → saves to the outbox; the sheet closes the same way.
- Failure (permanent) → the sheet stays with "couldn't save that · try again".

State table: `addEmpty`, `addTyping`, listening (the composer's), `addSaving` (save shows `RSpinner`), saved (closes), `addFailed`.

Tests: (UI) "adding a goal by typing puts it at the top of the list" · (UI) "adding offline still shows it at once" · (snapshot) empty, typing, saving, failed; light, dark, ax3.

Watch out: don't build before the drawing is approved; if it's late, P16.1 ships with the + hidden behind a flag and a findings-log entry.

---

### P16b · GL-3 ended goals                                               size: S
Place in the tree: goals › turn off and ended › GL-3
Repo · branch: NPRdoinglaundry · `ui/P16b-ended-goals`
Needs: C29.4, #47 (`RSettingsRow`), C17 (small centred title); **a Paper drawing approved by the founder** (Q5)      Unblocks: T05b

Why: every goal you ended is still there, with when and why, and can come back.

Inputs: contract 04 §2 (`GET /v2/goals/ended`); Q5's lean (the settings-page layout: lists get the small centred title); settings row value variant (`DVT-0`).

Spec (on the lean): top bar back · "ended" (small centred); one grouped list of `RSettingsRow` nav rows: title (your words) and a value line "turned off 12 oct" / "faded 1 aug" / "merged 4 sep"; tap → GL-2 in its ended state. States: full, loading (skeleton rows), error, offline (cached), empty (never reached from GL-1, which hides the row at zero; via a stale link → "nothing ended.").

Tests: (snapshot) full, loading, error; light, dark, ax3 · (UI) "an ended goal opens its page with turn back on".

---

### T05b · Goals flow test                                                 size: M
Place in the tree: goals › flow test (layer 8, then layer 9 by the integrator)
Repo · branch: NPRdoinglaundry · `ui/T05b-goals-flow` (with the integrator)
Needs: P16.2, P17.2, P16b, UIG.1, UIG.2, UIG.3 (and PL3.5d for the push step on live)      Unblocks: ship gate G4

Why: one test proves the whole goals flow works end to end on sample data, then on local staging.

Inputs: every goals card above; T02's launcher; T04's structure (the journal flow test).

Spec: one XCUITest class `GoalsFlowTests` on `-Data sample` (and `-Data live -Environment local` for the integrator's layer-9 run), each step asserting identifiers, never copy:
1. GL-1 empty shows "nothing yet." and the +; no card exists.
2. Add "learn the cello" → it appears first, too early.
3. A question arrives (`question` scenario) → yes → the goal is created at the top; the question is gone.
4. Open a compared goal → GL-2 shows the said line, rows and the guess; answer the guess → it folds away.
5. Long-press a did row → not for this goal → the row folds; undo → it's back.
6. Rename → the title changes; the counts don't.
7. Turn off → back on GL-1 the card folds and the toast offers undo; undo → it's back; turn off again and let the toast go.
8. The ended row → GL-3 → the goal → turn back on → it's on GL-1, too early.
9. Offline (`isOnline` flips): turn a goal off → it's off at once; back online → sent once (the sample counts sends).
10. A check-in push (sample tap) opens GL-1 with the check-in first; not quite → turned off with undo.
11. Accessibility audit on GL-1, GL-2 and GL-3.

Acceptance: green on sample data in CI (nightly and on page PRs); green on local staging before the wiring PR merges; no assertion depends on copy.

Proof: the test run; the integrator's staging recording (test account, counts only).

---

## Verified against Paper (21 Oct): what changed from the first draft

| Where | First draft (from the reference docs) | Paper (GL-1 `1FZO-0`, GL-2 `1G3Z-0`) |
|---|---|---|
| C29.2 card padding | 18 all round | top 16 (`space.4`), sides and bottom 20 (`space.5`) |
| C29.2 card line | SF Pro 15 | SF Pro `text.md` 14, balanced wrap |
| C29.2 depth | "card tier" | the full stack: inner-top, inner, outer 0.5, contact, cast, ambient |
| C29.1 count | mono figure | Geist `text.sm` 12 `text.secondary`, 64 wide, wraps |
| C29.1 label | Geist or mono | mono `text.xs` 11 `tracking.label` (Paper keeps mono) |
| C29.1 did count | a number ("2") | words with a unit: "4 hours", "1 night" (contract question Q11, README) |
| C29.1 row gap | — | 8 between said and did; 12 inside a row |
| C29.1 too early | replaces the bar | replaces the bar **and** the count, Geist 12 `text.label` |
| C29.3 well | `surface.lifted` | `background.canvas` (lifted in dark), round, 0.5 hairline |
| C29.3 label | "a guess" | "a guess · a goal?" / "a guess · a pattern" (Geist 12 medium) |
| C29.3 question | SF Pro 17/24 | inky display `text.xl` 22, `ink.card`, `leading.tight` |
| C29.3 quote and why lines | drawn under the question | not drawn; kept in data only |
| C29.3 buttons | raised-paper, 12 apart | true pills, `background.canvas`, hairline + contact, 44 high, 8 apart, 4 extra above; SF Pro 14 semibold |
| C29.3 GL-2 copy | "that's right" · "not quite" | "yes" · "not quite" |
| C29.3 padding | — | GL-1: 16 / 20 / 20; GL-2: 16 all round |
| C29.4 ended row | a line with a divider, 44 min | a `surface.wash` panel, `radius.panel` 16, 56 min, 12/16 padding, SF Pro 14, chevron 14 |
| C29.5 said line | SF Pro 15 `text.secondary` | Geist `text.sm` 12 `text.label` |
| C29.5 title | `type.3xl` | `text.3xl` 30, `ink.title`, `tracking.title`, `leading.tight` |
| P16.1 list gap | 12 | 16 (`space.4`); 12 above the first card; 12 on SE per the handoff |
| P16.1 ended row spacing | 24 above | the list's 16 |
| P17.1 top of content | — | 16 below the top bar; sections 32 apart |
| P17.1 section label | "did this week" + mono hours | "did this week · 4 hours", all Geist 12 medium |
| P17.1 rows | C32 defaults | 56 min, 32 well radius 10, label Geist 12, text SF Pro 14, entries labelled "your words" and quoted, 1pt `border.subtle` separators, a grouped `background.canvas` panel radius 16 |
| P17.1 chevrons | only on rows that open | Paper draws one on every row (Q7 lean kept; shown in the PR) |
| P17.2 foot | 16 above the bottom | 32 (`space.8`); a 32-high wash pill in a 44 hit area |
