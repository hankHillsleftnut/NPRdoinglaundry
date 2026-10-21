# UI engineer · outline cards (phases 2–8)

These are outline cards: the header, why, place in the tree, needs/unblocks and Paper nodes. Each one is filled in to a full [byte card](../byte-card.md) before its phase starts, against its contract (01, 03–07) and the latest Paper. Values and states live in [design-reference.md](../reference/design-reference.md) (component sections, §C moments, §E rows). Page node ids are the approved phones on `p-J-0` "06 · everything · latest", and component ids are the instances on those phones.

---

## T04 · Journal flow test {#t04}
Size M · journal › flow test · `ui/T04-journal-flow` (with the integrator) · Needs: P09–P12 · Unblocks: ship gate G2
Why: one test proves the whole journal works end to end on sample data. It covers sending typed and voice entries, sending offline and then online exactly once, playing the brief, answering a guess, and "not right". It then runs again on local staging (layer 9, the integrator's).
Paper: JR-1 `1FKB-0`, JR-2 `1FMG-0`, JR-3 `1FOQ-0`, JR-4 `1FQX-0`.

---

## Phase 2 · First run (contract 01) · flow test T03

| ID | Title | Size | Place | Needs → Unblocks | Why | Paper |
|---|---|---|---|---|---|---|
| S10 | the mark (16, 22, glyph) | S | first run › shared › mark | T01 → UI4.4, C23 header, EX-4 | Retro's one quiet sign, the same everywhere | master "c · the mark" `SUL-0`; instances `1FOL-0`, `1FOM-0` |
| C35 | onboarding progress (3pt bar) | S | first run › ON-3–10 › progress | T01 → P02–P05 | you always know how far along setup you are | `c:onboarding-progress` `1F74-0`, `26NA-0` |
| C17-o | top bar, onboarding variant (back · label · skip?) | S | first run › ON-3–10 › top bar | C17 → P02 | a quiet way back on every question | `c:top-bar/onboarding` `1F6W-0`, `26N2-0` |
| C34 | onboarding question (types out, M13) | M | first run › ON-3–9 › question | T01 → P02, P05, M13 | Retro asks one question at a time, as if writing it to you | part 42 `GD2-0`; `c:onboarding/question` `1F6V-0`; `c:onboarding/your-words` `1F6R-0` |
| C16 | listening field (voice-level glow) | M | first run › ON-3–9 › listening | #56 → M02 | the screen shows it's listening to your voice | `c:voice-composer/listening` `1F6E-0`; founder Q: needed beyond #56? (lean: fold into #56's listening state) |
| C36 | knows-you meter | M | first run › ON-6 › meter | S08 → P04, M04 | you see how well Retro can know you grow as you connect things | `c:knows-you-meter/1-of-6` `21C1-0` |
| UI4.5 | privacy disc | S | first run › ON-5 › privacy mark | T01 → P03 | the promise about your data is the one thing lit on that page | part 44 `GJJ-0`; `c:privacy-mark` `1F82-0` |
| UI4.1 | getting-ready panel | M | first run › ON-10 › panel | C26.2 → P05, M05 | honest steps while your first episode is made | `c:getting-ready` `26LV-0`; `c:stage/next` `26LZ-0`; `26ML-0` |
| UI4.2 | setup-recap card | S | first run › ON-13 › recap | T01 → P08 | what you told Retro, waiting on your first home | `c:entry/setup-recap` `1FJ6-0` |
| UI4.3 | hint pill | S | first run › ON-13 › hint | #45 → P08 | one gentle pointer, three times at most | `c:hint/1-of-3` `1FJ0-0` |
| C33 | benefit row with tile | S | first run › ON-12 › benefits | T01 → P07 | what membership gives, row by row | `c:benefit-row` `22S1-0` |
| C37 | paywall plan pair (M07) | M | first run › ON-12 › plans | RButton (merged), #46 → P07 | choose yearly or monthly, with Apple's localized prices ($19.99 / $199.99, first month free on yearly) | decision 06 `IFL-0`; `c:button/lit/plan-yearly` `22MH-0`; `c:button/secondary/plan-monthly` `22MM-0`; `c:badge/save` `22MI-0` |
| C22-p | mini-player, paywall variant | S | first run › ON-12 › paused player | C22 → P07, M06 | the tease you just heard waits, paused, at the top | `c:mini-player/paused` `22TR-0` |
| UI4.4 | splash (map, promise, sign-in buttons) | M | first run › ON-1/2 › splash | C38 orbits, S10 → P01, M01 | the first thing you see: who Retro is, and one way in | `1F4Q-0`; `c:you-map/orbits/rest` `1F5K-0` (opening A/B/C: founder question) |
| PI1 | invite gate: code applied, code field, waitlist | M | first run › invite › gate | Paper approval of the invite board `2H3N-0` (being drawn by another session; read-only) → PI2, T03 | only invited people get in, and anyone else can join the waitlist, never a dead end | `2H3N-0` "review · the invite · round 1 · keyframes" |
| PI2 | M14 "you're in" | L | first run › invite › moment | PI1, S10, `RMotion.pop` → T03 | being let in feels like a gift: "you've just been given a gift, don't waste it" | `2H3N-0` keyframes once approved; plays once per account; Reduce Motion: calm cross-fade; VoiceOver announces once |
| PX | force-update screen | S | first run › gate › force update | Paper drawing (integrator) → ship gate G1 | an old app version stops cleanly and points to the App Store | not drawn yet (founder question: its design) |
| P01 | ON-1/2 splash + sign-in | M | first run › ON-1/2 | UI4.4, PL1.4 sign-in (plumbing) → T03 | sign in with Apple or Google | `1F4Q-0` |
| P02 | ON-3–9 the questions | L (split per question type) | first run › ON-3–9 | C34, C35, C17-o, #56, #45, #51 → T03 | Retro gets to know you in your own words | `1F6C-0` |
| P03 | ON-5 privacy | S | first run › ON-5 | UI4.5 → T03 | the plain promise, read aloud | `1F7I-0` |
| P04 | ON-6 connect | M | first run › ON-6 | C36, #52 → T03, M04 | connect what you want Retro to read | `2190-0` |
| P05 | ON-10 getting ready | M | first run › ON-10 | UI4.1, C34 → T03, M05 | keep talking while your first episode is made | `26LG-0` |
| P06 | ON-11 the tease | M | first run › ON-11 | C23e → P07, M06 | hear the start of your first episode | `26NO-0` |
| P07 | ON-12 paywall (option A) | M | first run › ON-12 | C37, C33, C22-p → T03, M07 | become a member to hear the rest, every week | `22M4-0` |
| P08 | ON-13 first home | M | first run › ON-13 | P09, UI4.2, UI4.3 → T03 | your journal on day one, with your first episode ready | `1FI8-0` |
| P32 | AC-1 sign in, returning | M | first run › AC-1 | UI4.4 → T03 | welcome back, with everything restored | `1GXR-0`; `c:you-orb/56` `1GYN-0` |
| T03 | first-run flow test | M | first run › flow test | all of the above → G1 | the invite link → sign-in → code applied → you're in → questions → connect → paywall → first home, in one test | — |

## Phase 3 · Podcasts (contract 03) · T05a

| ID | Title | Size | Place | Needs → Unblocks | Why | Paper |
|---|---|---|---|---|---|---|
| C27 | episode tile (hero, square; scroll lag M10) | M | podcasts › PC-1 › tile | #42 → P13, M10 | your episodes as covers you want to open | part 40 `FWU-0`; `c:episode-tile/hero/rest` `1FUK-0`, `square` `1FUE-0` |
| C17-t | top bar, other tab titles (podcasts, goals, you) | S | every tab › top bar | C17 → P13, P16, P18 | the same quiet title on every tab | `1FUX-0`, `1G3J-0`, `1G7X-0` |
| C23e | player sheet, episode mode (title collapse, chapters, guess arriving) | L | podcasts › PC-2 › player | C23b → P14, P06 | listen to your weekly episode with its words | master `B1C-0`; PC-2 `1FVK-0` |
| C20-p | player "…" menu (chapters ›, download) | S | podcasts › PC-2 › menu | C20 → P14 | more without clutter | build notes; founder question: the "…" items |
| UI5.1 | chapter list | S | podcasts › PC-2 › chapters | C23e → P14 | jump to any chapter | PC-2 state (part 09 states `B33-0`) |
| UI5.2 | "where retro says it" moment card | S | podcasts › PC-3 › moment | C32 → P15 | hear the exact moment a claim was said | part 41 `G1E-0`; `c:episode-moment/rest` `1FY2-0` |
| P13 | PC-1 podcasts | M | podcasts › PC-1 | C27, C22, C18 → T05a | your episodes, newest first | `1FSA-0` |
| P14 | PC-2 the player | L | podcasts › PC-2 | C23e, C20-p, UI5.1, C28 → T05a, M09 | the weekly episode, in full | `1FV9-0` |
| P15 | PC-3 why this is here | M | podcasts › PC-3 | C32, UI5.2, C28 asked → T05a | see what a claim rests on | `1FXG-0`; `c:claim/asked` `1FZ6-0` (founder question: ⌄ close) |

## Phase 4 · Goals (contract 04) · T05b

| ID | Title | Size | Place | Needs → Unblocks | Why | Paper |
|---|---|---|---|---|---|---|
| C29 | goal card (rest, gap, too early, guess; M11) | M | goals › GL-1 › card | #45, C28 → P16, M11 | each goal with honest progress | part 48 `ITY-0`; `1G2R-0`, `1G21-0`, `1G35-0`, `c:goal-row/faded` `1G1X-0` |
| C21-i | toast integration (end goal · undo) | S | goals › GL-1 › toast | #48 (the toast look: founder question) → P16 | undo instead of a dialog | approvals `2FI5-0` |
| P16 | GL-1 goals | M | goals › GL-1 | C29, C17-t, C21-i → T05b | what you're working toward | `1FZO-0` |
| P17 | GL-2 one goal | M | goals › GL-2 | C32, C29 grey guess → T05b | the evidence for one goal | `1G3Z-0` |

## Phase 5 · You (contract 05) · T05c

| ID | Title | Size | Place | Needs → Unblocks | Why | Paper |
|---|---|---|---|---|---|---|
| C38 | you map (orbits, frosted orbs, life; M12) | L | you › YO-1 › map | T01 → P18, UI4.4, P32, M12 | a living picture of what Retro knows | part 05 `9BS-0`; `c:you-map/orbits/rest` `1G6Z-0` |
| UI6.1 | search answer with citation chips | M | you › YO-2 › answer | C32 numbered → P19 | answers with every source, and silence when there's nothing | part 50 `JZQ-0`; `c:answer/found` `1G9Y-0`; `c:source-result/rest` `1G9P-0` |
| C32-n | evidence row, numbered well | S | you › YO-2 › sources | C32 → UI6.1 | sources numbered to the citations | `1G9P-0` |
| P18 | YO-1 you | M | you › YO-1 | C38, #53 → T05c | you, at a glance | `1G5Y-0` |
| P19 | YO-2 search | M | you › YO-2 | UI6.1, #50 → T05c | ask anything about yourself | `1G8E-0` |
| P20 | YO-3 a source | S | you › YO-3 | P12 parts → T05c | one source in your words (founder question: merge with JR-4) | `1GAS-0` |
| P21 | YO-4 a node | M | you › YO-4 | C19.1, C32, C28 → T05c | one thing Retro believes, and why | `1GC2-0`; `c:claim/stated` `1GDS-0`; `c:chip/link` `1GCV-0` |
| P22 | YO-5 what i know | M | you › YO-5 | C17 settings → T05c | every answer, each one fixable | `1SZX-0`; `c:answer-row/rest` `1T0Z-0` |

## Phase 6 · Settings and account (contract 06) · T06

| ID | Title | Size | Place | Needs → Unblocks | Why | Paper |
|---|---|---|---|---|---|---|
| P23 | ST-1 settings | S | settings › ST-1 | C17 settings, merged rows (C09) → T06 | every setting in one calm list | `1GGA-0` |
| P24 | ST-2 daily brief (off by default; pick the time) | M | settings › ST-2 | #50, #51, C20 value rows → T06 | turn the brief on and choose when | `1GJK-0` |
| P25 | ST-3 sources | M | settings › ST-3 | #52 → T06 | what Retro reads, and its state | `1GL7-0` |
| P26 | ST-4 a source | S | settings › ST-4 | C19.2 → T06 | disconnect or delete what it read | `1GNV-0` |
| P27 | ST-5 privacy (ambient switch, export, delete my data) | M | settings › ST-5 | C19.2 → T06 | control what Retro learns and keeps | `1GP6-0` |
| P28 | ST-6 how straight | S | settings › ST-6 | rows → T06 | choose how direct Retro is | `1GQM-0` |
| P29 | ST-7 voice | S | settings › ST-7 | rows, UI3.0 → T06 | choose Retro's voice and speed | `1GS3-0` |
| P30 | ST-8 what i've learned | S | settings › ST-8 | C39.2 → T06 | how Retro is adjusting its questions | `1GTG-0` |
| P31 | ST-9 account (plan, restore, sign out, delete account) | M | settings › ST-9 | C19.2, plumbing purchases → T06 | your plan and your account, including leaving | `1GU5-0` |
| P33 | AC-2 signing out (unsent first) | S | settings › AC-2 | C19.1 → T06 | nothing is lost when you sign out | `1GVP-0`; `c:sheet/sign-out` `1GVR-0` (fill `background.raised`) |
| PI3 | your invites (three single-use links) | M | settings › invites | Paper drawing (integrator) → T06 | give three friends a way in | invite board `2H3N-0` |
| T06 | settings and account flow test | M | settings › flow test | P23–P33, PI3 → G6 | including delete account, restore (sandbox) and sign-out | — |

## Phase 7 · Outside the app (contract 07) · T05d

| ID | Title | Size | Place | Needs → Unblocks | Why | Paper |
|---|---|---|---|---|---|---|
| C40 | lock screen and widget views | M | outside › widgets › views | S10, #42 → P35, P37 | Retro on your home and lock screen | `c:widget/164x164` `1H55-0`, `c:widget/344x164` `1H4L-0` |
| P34 | EX-1 share extension (integrator adds the target) | M | outside › EX-1 | #54 compact → T05d | save anything from any app | `1H1M-0`; `c:share/item-card` `1H1Z-0` |
| P35 | EX-2 lock screen / Live Activity / Now Playing | M | outside › EX-2 | C40, plumbing Now Playing → T05d | control the brief without opening the app | `1H2J-0` |
| P36 | EX-3 notifications | S | outside › EX-3 | plumbing push → T05d | at most one a day, private by default, opening the right screen | `1H3E-0` |
| P37 | EX-4 widgets | M | outside › EX-4 | C40 → T05d | today's brief and a way to talk, at a glance | `1H4D-0` |

## Signature moments (each its own PR after its page, recorded and compared with the motion system)

| ID | Moment | Size | After | Paper / spec |
|---|---|---|---|---|
| M01 | orb breathes, satellites drift (splash) | M | P01 | splash `1F4Q-0`; reference §C M01 |
| M02 | listening glow follows your voice (capped) | M | P02 | `1F6E-0` |
| M03 | answer word ink-sharpens | S | P02 | `1F6R-0` |
| M04 | connect → connected, meter fills, "knows you well" pop | M | P04 | `21C1-0`, `21BN-0` |
| M05 | getting ready: honest steps, tags pop in | M | P05 | `26LV-0` |
| M06 | the player shrinks into the mini-player; the paywall rises | L | P07 | `26NZ-0` → `22TR-0` |
| M07 | the plan glow slides (option A reinterpretation: founder question) | S | P07 | `IFL-0` |
| M08 | the bubble lifts (v1); line-by-line sharpening (v2) | S | P09 | part 08 `9W3-0` |
| M09 | play morph, rolling time, part/chapter ticks | M | P10, P14 | part 09 `A38-0` |
| M10 | tiles lag the scroll | M | P13 | part 40 `FWU-0` |
| M11 | the goal card folds, the bar eases | M | P16 | part 48 `ITY-0` |
| M12 | a new fact blooms into the map | M | P18 | `1G6Z-0` |
| M13 | questions type out with a soft tick per word | M | P02 | part 42 `GD2-0` |
| M14 | "you're in", the invitation moment (built as PI2) | L | PI1 | `2H3N-0` |

## Later-phase founder questions (with leans)

| Question | Lean |
|---|---|
| Onboarding "skip" on the right of the top bar (part 42 draws it; the screen rules say empty) | no skip; "later" lives in the page where Paper draws it |
| Splash opening A/B/C | the founder picks from recordings |
| M07 under paywall option A (one lit plan) | the lit glow moves to the chosen plan; "17% off" rolls in |
| ON-10 blue hairline | keep the 2pt `player.progress` line; no blue |
| YO-3 merge with JR-4 | merge: one entry page for both |
| PC-3 ⌄ close | keep ‹ back only; swipe down closes |
| The player's "…" items | chapters ›, download |
| Toast look (#48) | as drawn on `2FI5-0` |
| Progress VoiceOver wording | "step 2 of 6" |
| Force-update design | a splash-style page, one line, "update" (lit) to the App Store |
| C15/C16 | C15 dropped; C16 folded into #56 |
