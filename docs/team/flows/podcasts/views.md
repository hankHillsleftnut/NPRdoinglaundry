# Podcasts · view cards (components, pages, motion, the flow test)

The app engineer's view cards for the podcasts area, in full byte-card form. Contract: [../../contracts/03-podcasts.md](../../contracts/03-podcasts.md). Rules from [ui-engineer.md](../../ui-engineer.md) §5 (one `public struct R<Name>`, tokens only, `RShape`, `RMotion`, `RHaptic` through `.sensoryFeedback`, a preview per state, a gallery page). Design rules: `design-system/principles/` (keys, screen rules), `components/craft.md`, `player.md`, reference §C20, §C22–§C28, §C32, §C39.

**Values below were read from Paper on 21 Oct** (`get_jsx` and `get_computed_styles`, read-only) on PC-1 `1FSA-0`, PC-2 `1FV9-0`, the player master's states row `B33-0` (ready `BB9-0`/`BBA-0`, menu `BFC-0`), part 40 making `FZ1-0`, PC-3 `1FXG-0` and part 41 stated `G2A-0`. Each card still re-reads its nodes as its first step and lists any change since. **Where Paper and the reference docs disagree, Paper wins**, and every disagreement is listed in the README §9. Light file `01M5D5J321P5X86ZT58002B7NT`, dark file `01M5EK9MGGWHX9H05V9MENVB6P` (dark twins: PC-1 `2HZY-0`, PC-2 `2IFN-0`, PC-3 `2GV0-0`, part 40 `2P6Q-0`, part 41 `2PBS-0`; all still waiting for approval). Part 09 (the player, `A38-0`) is still on the approvals page with the question "does the '…' menu hold the right things?" (founder Q-6).

**Reused, never redone:** C22 mini-player, C23b brief-mode player (frame, transcript column, blur bands, choreography), C24 transport, C25 scrubber, C19.1 sheet host, C20 menu host, C28 guess card, C32 evidence row, C39 shared states, C17 top bar, C18 tab bar, UI1.2's correction sheet, UI3.0 `SamplePlayback`, `RArtwork` (#42). Episode mode is built **on** C23b: new parts plug into its frame.

**Tree:** podcasts › PC-1 (P13.1, P13.2 · C17-t · C27.1 hero · C27.2 square · C27.3 upcoming row · M10) › PC-2 (P14.1, P14.2 · UI5.6 the player on every tab · C23e.1 header and title · C23e.2 transcript lines · C23e.3 a guess arriving · C24-s speed · C20-p "…" menu · UI5.1 chapter list · UI5.4 feedback · M09) › PC-3 (P15 · UI5.3 the claim · UI5.2 "where retro says it") › sample data (UI5.0) › flow test (T05a) › M06 (shared with first run).

---

### UI5.0 · SamplePodcastsData and episode playback scenarios               size: M
Place in the tree: podcasts › sample data
Repo · branch: NPRdoinglaundry · `ui/UI5.0-sample-podcasts`
Needs: `Platform/Flows/Podcasts.swift` and the `Playback` additions (integrator, platform.md §0), UI3.0, T02      Unblocks: every podcasts view card

Why: every podcasts state can be built, compared with Paper and tested without a server or audio.

Inputs: contract 03 (every type; fixtures `fixtures/03/` as the shapes); platform.md §0 (the seam); ui-engineer.md §4 rules (invented, lowercase, deterministic, ledgered)

Spec:
- `Features/Podcasts/Sample/SamplePodcastsData.swift`: `@MainActor @Observable`, conforms to `PodcastsData`, built from a `PodcastsScenario`:
  `full` (hero + 2 briefs + 4 episodes), `dayOne` (empty, nothing made), `making` (first job running, no hero), `makingWithHero`, `quietWeek`, `heroPlaying`, `longTitles` (3-line hero title, 2-line clamps), `legacyOnPhone` (X3.1's "made on this phone" squares), `offlineCached`, `offlineEmpty`, `loading` (never resolves), `error.network`, `manyPages` (paging), `noAudio`, `legacyEpisode` (no chapters), `claimStated`, `claimAsked`, `claimAskedWhy`, `claimNoEvidence` (total 0), `feedbackGiven`, `downloaded`, `downloading`.
- `SamplePlayback` (UI3.0) gains episode scenarios: `episodeReady` (5 chapters, 10:12), `episodePlaying`, `episodeHeldScrub`, `episodeGuessArriving` (position at the hypothesis chapter's start), `episodeEnded`, `episodeBuffering`, `episodeOfflineNotDownloaded`, `episodeRate125`, `episodeLegacy` (no chapters).
- Content is invented and lowercase-titled ("the week the plan met the calendar"); people are "sam" and "priya"; every value logged in `docs/design/sample-data-ledger.md`.

Acceptance: every scenario reachable through T02 (`-Screen PC-1|PC-2|PC-3 -Data sample -State <name>`); no wall clock, no randomness.

Tests: (unit) "every scenario decodes into the contract's shapes" (sample values pass through the same encoders as fixtures) · (unit) "the guess-arriving scenario starts at the hypothesis chapter" · (unit) "loading never resolves".

Proof in the PR: test output; ledger rows.

Watch out: never reuse a fixture's text as sample text in screenshots without logging it; never a real person's words.

---

### C17-t · Top bar, tab title (podcasts, goals, you)                        size: S
Place in the tree: every tab › top bar › tab title (podcasts first)
Repo · branch: NPRdoinglaundry · `ui/C17-t-tab-title`
Needs: C17      Unblocks: P13 (and goals P16, you P18)

Why: each tab says where you are in the same quiet inky title, and it gets out of the way as you scroll.

Inputs: reference §C17 (tab title variant; collapse); Paper `c:top-bar/title/rest` on PC-1 `1FUX-0`, GL-1 `1G3J-0`, YO-1 `1G7X-0`; master `B19-0` states `B2I-0`

Spec:
- The C17 title variant with no leading button on PC-1 (Paper `1FUX-0` has no drawer and no trailing button; GL-1 adds a trailing `add`, YO-1 none): inky title "podcasts" (display serif, the C17 title style), lowercase.
- Collapses on scroll past 8pt into the small centred name, exactly like C17's journal title, driven by a `collapsed` Bool from the page.
- A trailing slot (optional `RIconButton`) for GL-1's add; empty on PC-1.

State table: rest · collapsed (small name, `snappy`) · dark · AX3 (title wraps to two lines, never truncates) · Reduce Motion (140 cross-fade).

Interaction table: re-tapping the tab scrolls to top on `gentle` (owned by the page) · nothing else is tappable on PC-1's bar.

Accessibility: header trait; "podcasts"; collapsed keeps the same label.

Acceptance: matches `1FUX-0` light and dark (dark from `2HZY-0`), AX3.

Tests: (snapshot) rest, collapsed, dark, ax3 · (UI) the title has the header trait.

Proof in the PR: standard proof next to `1FUX-0`.

Watch out: the consistency pass says lists get the small centred title when collapsed; don't add a subtitle (screen rule 1).

---

### C27.1 · Episode tile, hero                                               size: M
Place in the tree: podcasts › PC-1 › tiles › hero
Repo · branch: NPRdoinglaundry · `ui/C27.1-hero-tile`
Needs: #42 (`RArtwork`), RButton lit (merged), T01, UI5.0      Unblocks: P13.1, M10

Why: this week's episode waits at the top of the podcasts tab like a cover you want to open, with the one glowing play.

Inputs:
- Reference: §C27 (no spec file), handoff part 40, build notes "Episode artwork · mesh gradients" (c-e42cnl, c-scy4k9), screen rules 19
- Paper: part 40 `FWU-0` (master hero/rest `FXR-0`, lit play `FXV-0`), read 21 Oct; PC-1 instances `c:episode-tile/hero/rest` `1FUK-0`, `c:button/lit/play` `1FUR-0`; dark part 40 `2P6Q-0`
- Contract: 03 §1 `EpisodeSummary` (title, about, durationSeconds), §2 `hero`

Spec (from Paper `1FUK-0`, the PC-1 instance; the part 40 master `FXR-0` is re-checked in the PR):
1. body `background.raised`, `radius.card`, padding `spacing.2`, gap `spacing.3`, width 354 (column); depth: `depth.stroke.innerTop` 1pt inset, `depth.stroke.inner` 1pt inset ring, `depth.stroke.outer` 0.5 ring, `depth.shadow.contact` 0 1 2, `depth.shadow.cast` 0 12 28 −12, **plus `depth.shadow.ambient` 0 24 60 −20** (the hero sits one step higher than the squares, which have no ambient layer)
2. artwork panel: height 180 (SE 112, handoff), `radius.panel`, `RArtwork` weekly dusk recipe (base `night.800`; amber.200 sun at 92% 0%; amber.600 70% body at 55% 40%; night.950 anchor at 0% 100%; red.300 30% warmth at 20% 20%; amber.50 60% highlight at 82% 12%; all OKLab radial, as `1FUP-0`), grain 3–4%
3. on the artwork, top-leading at `spacing.4`/`spacing.3`: "this week · 12 min" (Geist `text.sm` medium, `glow.primary.foreground`); older heroes read "<d mmm> · 12 min"
4. the lit play (`RButton` lit 44, the full glow stack from `1FUR-0`; play glyph 18) hanging off the artwork's bottom edge: bottom −22, trailing `spacing.4`: **the screen's one lit object**
5. text block (padding `spacing.2`, gap `spacing.1`): the title in `font.display.inky`, `text.2xl`, `font.weight.inkCard`, `tracking.card`, `leading.tight`, balanced, with `spacing.12` clear on the trailing side (under the play), ≤ 3 lines then ellipsis
6. the line under it: `about` ("mornings, the standup, sleep": up to three chapter titles) in SF `text.md` `text.secondary` `leading.snug`; no `about` → no line (the length is already on the artwork)
- Played (PLP.3 `finished_at`): the title `text.secondary`, the artwork corner reads "played" (Geist 500 12), the lit play becomes a raised replay well with no glow (as C26 played).
- **While its own episode is loaded in the player** (playing or paused): the lit play is removed, not dimmed; the mini-player owns playback (reference §C22 rule). The tile is otherwise unchanged.

State table:

| State | Look | Motion | Haptic |
|---|---|---|---|
| rest | as above | — | — |
| card pressed | 0.98 | `.rPress` 80/240 | none |
| play pressed | 0.94, pressed gradient | `.rPress` | `press` (lit) |
| pending (starting audio) | the play shows a 2pt `RSpinner` | `spin` 900 | none |
| loaded in player | no play | play fades out 140 | — |
| played | as above | 200 `curve.standard` | — |
| offline, not downloaded | the play stays; tapping it shows the player's offline state | — | — |
| no audio | no play; the line reads "<about> · words only" (founder copy, listed in the PR) | — | — |
| dark | raised dark, inner stroke white 8%, casts black 45%, the dusk palette's dark twins | — | — |

Interaction table:

| Touch | Press | Haptic | Motion | Outcome | Reduce Motion |
|---|---|---|---|---|---|
| play | 0.94 | `press` | `.rPress`, then the player opens (C23b choreography from the tile's title) | plays and opens PC-2 | press; the sheet cross-fades |
| card body | 0.98 | none | zoom transition into the player (iOS 18 `navigationTransition(.zoom)`) | opens PC-2 paused | 140 fade |
| replay (played) | 0.94 | none | `.rPress` | plays from the start | same |

Accessibility: two elements: the card ("<title>, <about>, 10 minutes, this week's episode. double tap to open") and the play ("play <title>"); played adds "played"; AX3: the title `type.ax3.xl`, the play moves under the text and stays 44; Increase Contrast: 1pt `border.control` replaces the stroke stack; contrast: line 5.2, title 15.

Acceptance: matches `FXR-0` and `1FUK-0` light, dark, AX3, SE (112 art); the title never runs under the play; the play disappears while its episode is loaded.

Tests: (snapshot) rest, pressed, pending, loaded in player, played, no audio, dark, ax3, SE · (unit) the artwork label reads "this week" within seven days, else the date · (UI) VoiceOver finds the card and the play as two elements.

Proof in the PR: standard proof, plus a recording of play → player opening.

Watch out: one `RArtwork` instance per tile, paused off-screen (`.onScrollVisibilityChange`); don't let the mesh drift (life budget F54: scroll lag is the screen's only motion).

---

### C27.2 · Episode tile, square (earlier episodes and briefs)               size: S
Place in the tree: podcasts › PC-1 › tiles › square
Repo · branch: NPRdoinglaundry · `ui/C27.2-square-tile`
Needs: C27.1 (shares the artwork and depth), UI5.0      Unblocks: P13.1, M10

Why: everything earlier sits below as small covers, two across, so you can find last week's episode or Tuesday's brief at a glance.

Inputs: part 40 square master `FYG-0`; PC-1 instance `1FUE-0`; reference §C27 (two across, 12 apart, no play, 2-line titles, "your sister, the job · 4 min"); SE "161 squares"

Spec:
- From Paper `1FUE-0`: width 171 (half the column minus 6; the grid gap is `spacing.3` 12), padding `spacing.2`, gap `spacing.2`, card depth as the hero **without** the ambient shadow; artwork 155 tall, `radius.panel`: `RArtwork` **brief sky** for briefs (`1FUI-0`), **first green** for `kind: first` (`1FUD-0`), **older** (night.300 base, paper.50 light, red.300 corner, `1FU8-0`) for earlier episodes; text block (padding top `spacing.1`, inline `spacing.1`, bottom `spacing.2`, gap `spacing.1`): the title in `font.display.inky` `text.base` `inkCard` `tracking.card` `leading.tight`, 2 lines, balanced; under it "<ddd d mmm> · <n> min" (Geist `text.sm` `text.label`). **Briefs are titled by day, not by their headline:** "today's brief", "monday's brief" (Paper `1FUH-0`, `1FU2-0`); the first episode "your first episode".
- No play (the mini-player and the player own playback).
- Played: title `text.secondary` + "played" in the artwork corner.
- "Made on this phone" (X3.1 `legacy_episodes`): older recipe, the line "made on this phone", no length if unknown.
- AX3: one column (the system decides: never truncate a title beyond 2 lines; reference §C27 says "not specified"; listed as a decision in the PR).

States: rest · pressed (0.98) · played · loading (C39.1 skeleton in the tile's shape) · dark · ax3 one column.

Interaction table: tap → zoom transition into the player paused (episodes: PC-2; briefs: C23b brief mode via `brief(id:)`) · `.rPress` · no haptic · Reduce Motion 140 fade.

Accessibility: one element: "<title>, <line>, episode|brief, double tap to open".

Acceptance: matches `FYG-0`/`1FUE-0` light and dark; two across on 402, SE 161 wide.

Tests: (snapshot) episode, brief, first, made on this phone, played, dark, ax3 one column · (unit) the width is half the column minus six.

Proof in the PR: standard proof.

---

### C27.3 · The upcoming row: being made, or a quiet week                     size: S
Place in the tree: podcasts › PC-1 › upcoming row
Repo · branch: NPRdoinglaundry · `ui/C27.3-upcoming-row`
Needs: C27.1, `RSpinner` (merged)      Unblocks: P13.1

Why: you can see this week's episode is on its way, or that it was a quiet week, in one honest line, never a big empty box.

Inputs: part 40 hero/making `FZ1-0` (approved); reference §C27 "being made: one compact row with the grey syncing ring, 'ready sunday 9:00'"; C39 syncing ring; contract 03 §1 `Upcoming`

Spec:
- **making** (Paper `FZ1-0`): a raised card (the square's depth), width 354, padding `spacing.3`/`spacing.4`, no well and no artwork: "this week's episode" (Geist `text.md` medium, `tracking.label`, `text.primary`) over a row (gap `spacing.2`) of the 6pt syncing ring (`border.strong` ring, `text.secondary` quarter arc, stroke 3, one turn a second, linear) and "being made · ready sunday 9:00" (Geist `text.sm` `text.label`; the time from `readyAt` in the person's zone; without it, "being made").
- **quietWeek** (founder Q-3, lean; **not drawn in Paper**: the integrator draws it next to `FZ1-0` before this PR): the same card without the ring: "a quiet week" (Geist `text.md` medium) over the brain's `line` and "next one sunday 9:00" (Geist `text.sm` `text.label`, up to 2 lines).
- Becoming ready while on screen: the row blooms into the hero (matched geometry on `RMotion.sheet`, `duration.reveal`), the play lights last, `reveal` haptic (the C26.2 pattern).

States: making · quiet · becoming ready · dark · AX3 (the line wraps) · Reduce Motion (the arc stays still; bloom → 140 fade).

Accessibility: "this week's episode, being made, ready sunday 9 a.m." / "a quiet week. <line>. next one sunday 9 a.m."

Acceptance: matches `FZ1-0`; the quiet variant matches its approved drawing; the bloom plays the reveal haptic once.

Tests: (snapshot) making, quiet, dark, ax3 · (UI) becoming ready fires the reveal haptic once (haptic recorder) · (unit) ready time formats in the person's zone.

Proof in the PR: standard proof plus the bloom recording.

Watch out: never a percentage or a progress bar (craft 12.3: the length is unknown).

---

### P13.1 · PC-1 podcasts: the page and its states                            size: M
Place in the tree: podcasts › PC-1
Repo · branch: NPRdoinglaundry · `ui/P13.1-podcasts`
Needs: C17-t, C18, C27.1, C27.2, C27.3, C39, C22, UI5.0, UI0.1      Unblocks: P13.2, P14.1, M10, T05a

Why: your episodes, newest first: this week's at the top, everything earlier below, briefs among them.

Inputs: Paper PC-1 `1FSA-0` (approved; hi-fi board `HGX-0` on 04b); reference §E P13 ("112 hero art, 24 gaps, 161 squares, blur starts lower" on SE); contract 03 §2; screen rules 17–19, 30–33

Spec (layout):
- From Paper `1FTW-0`: one `ScrollView`, padding inline `spacing.screenMargin`, top `spacing.3`, gap `spacing.8` between groups: C17-t "podcasts" (44 bar) → upcoming row (when `making`/`quietWeek`) → hero (C27.1) → the "earlier" group (gap `spacing.3`): the section label "earlier" (Geist `text.sm` medium `text.label` `tracking.label`) and a two-column grid of squares, 12 apart both ways → paging (`loadMore` when the last row appears; a skeleton row while loading more). **Paper's label is "earlier"**, not the reference's "made for you, sam · since 12 oct" (c-zy9zt2); Paper wins and `since` is dropped from the contract.
- Margins 24 (20 on SE); 24 between groups; reading the content first (screen rule: content first).
- The mini-player (C22) floats 12 above the tab bar while something is loaded; the scroll's bottom inset grows by 64 + 12.
- Re-tapping the podcasts tab scrolls to the top on `gentle`.
- Life allowed: none ambient; M10's scroll lag is a response (P13.2/M10).

**Interaction sheet:**

| # | Moment | What happens | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|---|
| 1 | arrive (tab) | cached library at once; fresh replaces it without a flash | tiles cascade in, 60 stagger, `scale.enter` 0.97, first visit per launch only | — | 140 fade |
| 2 | first load > 400ms | skeleton tiles in the hero and square shapes (C39.1) | shimmer | — | pulse |
| 3 | scroll past 8pt | the title collapses (C17-t) | `snappy` | — | 140 |
| 4 | tap the hero's play | plays; the player opens (P14.1 row 1) | C23b choreography | `press`, `sheetSnap` | fade |
| 5 | tap a tile | the player opens paused | zoom transition | `sheetSnap` | fade |
| 6 | pull to refresh | the system refresh, resistance 0.55; the mark doesn't spin (F conflict: lean the system control) | — | `refresh` past threshold | — |
| 7 | this week's episode becomes ready | C27.3 bloom | `sheet`, `reveal` | `reveal` | fade |
| 8 | scroll to the end | loads the next page; skeleton row | — | — | — |
| 9 | re-tap the tab | scroll to top | `gentle` | — | jump |
| 10 | leave and come back | scroll position kept | — | — | — |

State table (page, T02 `-State`):

| State | What shows |
|---|---|
| `full` | as Paper `1FSA-0` |
| `dayOne` | C39.2 empty line "your episodes appear here every sunday." (reference §C27; founder copy) and nothing else; no invented tiles |
| `making` (no hero) | the upcoming row alone, then the empty line under it |
| `makingWithHero` | the upcoming row above last week's hero |
| `quietWeek` | the quiet row above the hero |
| `heroPlaying` | the hero without its play; the mini-player |
| `loading` | skeleton after 400ms |
| `offlineCached` | C39.4 "you're offline · showing what's saved" under the top bar; downloaded episodes play, others open to the player's offline state |
| `offlineEmpty` | the C39.3 layout with "you're offline" and no try again until online |
| `error.network` | C39.3 "couldn't load your episodes" + try again, in the content's place |
| `longTitles` | a three-line hero title; two-line squares |
| `legacyOnPhone` | "made on this phone" squares at the end |
| SE | 112 hero art, 24 gaps, 161 squares |

Accessibility: rotor: title → upcoming → hero card → hero play → section header → squares in reading order → mini-player → tab bar; `performAccessibilityAudit()` passes in full, dayOne and offlineCached.

Acceptance: every state matches Paper (`1FSA-0`; others against their component nodes, and the C39 drawings where PC-1 has none: listed) in light, dark (`2HZY-0`) and AX3, plus SE; one lit object (the hero's play, or none while it plays).

Tests: (snapshot) full, dayOne, making, quietWeek, heroPlaying, offlineCached, error, loading; light, dark, ax3, SE (full) · (UI) tapping the hero's play opens the player playing · (UI) tapping a square opens it paused · (UI) scrolling to the end loads more · (UI) offline shows the saved line · (accessibility) the audit passes in full, dayOne, offlineCached.

Proof in the PR: page proof plus recordings of rows 1, 4, 5 and 7, and SE.

Watch out: no loading, empty, error or offline state is drawn for PC-1 in Paper (inventory §5): use C39's and list each one for the founder; the quiet row needs its drawing first (C27.3).

---

### P13.2 · PC-1 edges and the mini-player                                    size: S
Place in the tree: podcasts › PC-1 › bottom edge, mini-player hand-off
Repo · branch: NPRdoinglaundry · `ui/P13.2-podcasts-edges`
Needs: P13.1, UI0.1, C22      Unblocks: T05a

Why: tiles dissolve into the tab bar in their own colours instead of being cut, and whatever's playing stays one tap away.

Inputs: build notes "Podcasts bottom edge · final" (c-z28ko7: opaque canvas under the tab bar, a ~100pt canvas-to-clear fade over a variable blur, stronger toward the tabs; replaces c-w1pgjf and c-axmhuk), progressive-blur.md, C22's appearing rules; SE "blur starts lower"

Spec: the bottom edge per c-z28ko7 through UI0.1's modifier (never grey); with the mini-player showing, the edge starts above the mini-player (12 + 64) and the mini-player sits on the soft edge (`safeAreaBar`). Hiding the mini-player (C22 swipe down) brings the hero's lit play back if the hidden item is the hero.

Interaction: swipe the mini-player down → hidden, `select`; the hero's play fades in 140 (if it's the hero's episode).

Acceptance: the edge matches the build note in light and dark; never grey; the mini-player never overlaps the tab bar.

Tests: (snapshot) the edge over the artwork tiles, with and without the mini-player, light and dark · (UI) hiding the mini-player brings back the hero's play.

Proof in the PR: screenshots next to `1FSA-0`'s bottom, both themes.

---

### M10 · Tiles lag the scroll                                                size: M
Place in the tree: podcasts › PC-1 › signature moment M10
Repo · branch: NPRdoinglaundry · `ui/M10-tile-scroll-lag`
Needs: P13.1, `.rScrollLag` (merged)      Unblocks: the L3 flow pass

Why: the covers feel like physical cards: they trail your scroll by a hair and settle, then sit perfectly still.

Inputs: reference §C27 motion and §C M10 (offset ≤ 6pt `motion.scrollLag.maxOffset`, tilt ≤ 1.5° `maxTilt`, ∝ velocity, `spring.settle` 0.45/0.70, staggered by position, never when still, RM off); microinteractions acceptance (filmstrip in Paper's 02b part 40 section with a red dot until approved, a preview in `DesignSystemV2/Motion/`, then the screen)

Spec: apply `.rScrollLag` to the hero and squares with a per-tile phase from its grid position (row × 0.04 + column × 0.02 of the response); velocity from `onScrollGeometryChange`; nothing moves at rest; Reduce Motion: none.

Acceptance: 60 fps on the oldest supported phone (Instruments hitch ratio within baseline); the founder's sign-off from a recording next to the filmstrip.

Tests: (unit) offset and tilt clamp at 6pt and 1.5° at any velocity · (unit) zero velocity gives zero offset · (motion) hitch ratio trend.

Proof in the PR: the recording next to the filmstrip; Instruments summary.

Watch out: the meshes don't drift (F54 lean): scroll lag is the screen's only motion.

---

### UI5.6 · The player opens from any tab                                     size: M
Place in the tree: podcasts › PC-2 › presentation (shared with the journal's JR-2)
Repo · branch: NPRdoinglaundry · `ui/UI5.6-player-anywhere`
Needs: P10 (the journal's player presentation), C22, C19.1; **the integrator's app-shell PR** (the tab container hosts one player sheet and one mini-player above all tabs)      Unblocks: P14.1

Why: an episode started in podcasts keeps playing in the mini-player on the journal tab, and opens back into the same player from anywhere.

Inputs: P10's watch-out ("the player as a presentation state of the journal tab… confirm against Paper"); reference §C22 ("MUST stay visible on every tab while loaded"); player.md (the behind page)

Spec:
- Move the player's presentation state from the journal page to one `PlayerPresentation` (`@Observable`: `isPresented`, `item`, `route: .player | .chapters | .claim(id)`), injected at the tab container. The sheet's "behind" is whichever tab is showing; the shared `@Namespace` lives with it (title ↔ mini-player ↔ the source tile or brief card).
- Opening from a tile, the brief card, the mini-player or a link all go through `PlayerPresentation.open(_:startPlaying:)`.
- Switching tabs with the sheet up (only reachable by a link or a notification tap while it's open): the sheet closes to the mini-player and the new tab shows. This settles P10's open question by the system's rule (a sheet covers the tab bar, so a tab change means leaving it); listed in the PR.
- Restorable after relaunch: closed, with the mini-player paused (PLP.3).

Acceptance: start an episode on PC-1, switch to the journal: the mini-player shows and opens the same player; the brief still opens from the journal; one sheet ever exists.

Tests: (UI) an episode started in podcasts shows in the journal's mini-player · (UI) the mini-player on any tab opens the same player at the same position · (unit) opening a second item replaces the first, never stacks.

Proof in the PR: recording across two tabs.

Watch out: this moves code that P10 owns; do it in one PR with P10's tests still green, no behaviour change on the journal.

---

### C23e.1 · Player, episode mode: header, title and the why line              size: M
Place in the tree: podcasts › PC-2 › player › header and title
Repo · branch: NPRdoinglaundry · `ui/C23e.1-episode-header`
Needs: C23b, UI5.0      Unblocks: P14.1, C23e.2

Why: an episode opens on its title, with one line saying what it was made from, and the title tucks into the header as soon as it starts.

Inputs:
- Reference §C23 (content order; two layout states, build note 20 Oct "i want the title to scroll up"); player.md
- Paper: PC-2 `1FV9-0` (sheet `1FVK-0`, the mark `1FXB-0`/`1FXC-0`, share `1FX6-0`, close `1FX3-0`); master `B1C-0` (ready `BBA-0`, playing `B99-0`); dark `2IFN-0`
- Contract 03 §3 (`title`, `madeFrom`, `kind`, `createdAt`)

Spec:
- Header (Paper `BCR-0`): the mark 22, "your weekly episode" (Geist 12 `text.label`, **not** the reference's Geist 500 14) and a `today` tag (20 high, radius 10, padding 7, `accent.subtle`) only when made today; "your first episode" for `kind: first`; share and ⌄ as 34 wash circles. While playing (`1FX8-0`): the mark 22 + the title in Geist `text.md` medium, one line, 220 wide.
- **Ready** (Paper `BCP-0`/`BCM-0`): the title in `font.display.inky`, `text.title`, `font.weight.inkTitle`, `tracking.title`, line height 37, ≤ 3 lines; the why line under it (padding top 12, gap 8): a 6pt `inference.marker` dot + "from 6 entries · calendar · steps" (Geist 12 `text.label`; at most three kinds from `madeFrom`, words: entries, voice notes, calendar, steps, sleep, health, saved, watched, listened, mail). Empty `madeFrom` → no why line.
- **Playing:** the title and why line scroll up and the header-left swaps to the title (Geist 500 14, one line, truncated) as a scroll, not a cross-fade (Reduce Motion: a cut); re-entering ready (scroll the transcript to the very top while paused) reverses it.
- Tapping the why line → PC-3 for the current chapter's claim (or the first claim when at 0); legacy episodes (no claims): the why line isn't tappable.
- Share: the system share sheet with the episode title only (no words, no audio, no link): C23b's rule.

States: ready · playing (collapsed) · loading (title + why at once, transcript skeleton) · no audio (header unchanged) · dark · AX3 (the title wraps to 3 lines then ellipsis; the collapsed title stays one line) · SE.

Interaction table:

| Touch | Press | Haptic | Motion | Outcome | Reduce Motion |
|---|---|---|---|---|---|
| why line | dims 0.7 | none | push inside the sheet | PC-3 | fade |
| collapsed title in the header | dims 0.7 | none | the column scrolls to the top on `gentle` | ready layout (paused) or just the top (playing) | jump |
| share | 0.94 | none | system sheet | shares the title | same |
| close ⌄ | as C23b | | | | |

Accessibility: header trait on the title; the why line "made from 6 entries, calendar and steps. double tap for why this is here"; VoiceOver order as C23b.

Acceptance: matches `BBA-0` (ready) and `B99-0` (playing) light and dark; the swap is a scroll; never two titles visible at once.

Tests: (snapshot) ready, playing, loading, first episode, no why line, dark, ax3, SE · (unit) the why line picks the three largest kinds · (UI) tapping the why line opens why this is here.

Proof in the PR: standard proof plus the collapse recording.

---

### C23e.2 · Player, episode mode: the transcript by line                       size: M
Place in the tree: podcasts › PC-2 › player › transcript lines
Repo · branch: NPRdoinglaundry · `ui/C23e.2-episode-transcript`
Needs: C23b (the column, blur bands, follow and back-to-now), C20 (the line menu), UI5.0      Unblocks: P14.1, C23e.3, M09

Why: you read along with the episode line by line; the spoken line is dark and in the clear middle, and a long press on any line lets you ask why it's there or correct it.

Inputs: C23b spec (column, `transcriptFollow` 420, `followResume` 4s, blur bands 96/140, SE 64/80); build notes "Player transcript (20 Oct)" (Exposure 20/1.3, 20 between lines); player.md (spoken `text.primary`, every other line `text.tertiary`, founder 21 Oct); contract 03 §3 `lines`

Spec:
- C23b's column fed with `lines` (Paper `1FWU-0`): padding top `spacing.6`, `spacing.5` (20) between lines, each line `font.display.inky` `text.xl` `inkCard` `tracking.card` `leading.snug`. **Colours from Paper:** said lines `text.tertiary`, the spoken line `text.primary`, **the next line `text.secondary`** (`1FWV-0`). player.md (founder, 21 Oct) says every other line is tertiary: the two disagree; this card follows Paper per the integrator's rule and the README asks the founder (Q-18), and C23b should match whichever wins. A chapter boundary adds no heading (the scrubber's "chapter 2 · the river" carries it).
- The spoken line comes from `Playback.currentLineIndex`; lines without times (legacy, estimated) → no following: the column scrolls freely and every line is `text.secondary`, so nothing pretends to be "now" (a decision by the system, listed in the PR).
- Asked lines (`register: asked`) are set the same as stated ones (the audio asks; the card in C23e.3 marks a guess). Craft lines the same.
- Tap a line → seek to its start (C23b), `select`.
- **Long press a line** (founder Q-7 lean) → C20 menu anchored to the line: "why this is here ›" (lines with a `claimId`) · "correct this part" (any line with a claim; opens UI1.2's flow with the claim's `correct` target, or free text) · nothing for craft lines (no menu, no haptic).
- "correct this part" pill (C23b) acts on the current line's claim; hidden when the current line is craft or the episode is legacy.
- No transcript (`lines` empty): the description in the column's type (C23 "no transcript").

States: following · user scrolled (back to now) · line pressed · menu open (the pill hides) · legacy (no follow) · no transcript · loading (skeleton) · dark · AX3 (two lines visible) · SE.

Interaction table:

| Touch | Press | Haptic | Motion | Outcome | Reduce Motion |
|---|---|---|---|---|---|
| tap a line | dims 0.7 | `select` | glide 420 | seeks there | jump |
| long press a claim line | the line lifts (raised) | `longPress` | `popover` (C20) | menu | fade |
| why this is here › | row | `select` | push in the sheet | PC-3 for that claim | fade |
| correct this part | row | `select` | UI1.2 flow inside the sheet | correction | fade |
| scroll yourself | — | none | — | following pauses; back to now | same |

Accessibility: the transcript is one text block (C23b); custom actions on it: "why is this here", "correct this part" for the current line; current line announced on change only when asked (C23b).

Acceptance: the spoken line stays in the clear middle on 402 and SE; following never runs while touching; the long-press menu offers only what applies.

Tests: (snapshot) following, user scrolled, menu open, legacy, no transcript, dark, ax3, SE · (unit) the current line from position across chapter gaps · (UI) long-pressing a claim line offers why this is here and correct this part · (UI) a craft line has no menu · (UI) tapping a line seeks to it.

Proof in the PR: standard proof plus the follow and long-press recordings.

Watch out: hundreds of lines: `LazyVStack` with stable ids (line index), and the follow scroll uses `scrollPosition(id:)`, never manual offsets.

---

### C23e.3 · Player, episode mode: a guess arriving                             size: M
Place in the tree: podcasts › PC-2 › player › a guess arriving
Repo · branch: NPRdoinglaundry · `ui/C23e.3-guess-arriving`
Needs: C28, C23e.2, UI5.0      Unblocks: P14.2

Why: when the episode reaches its one question, the guess appears right there in the words, so you can answer "that's right" or "not quite" without stopping.

Inputs: reference §C23 states ("PC-2 'a guess arriving' (approved guess card placed in the transcript; 'correct this part' steps aside)"), §C28 (rules, states); contract 03 §3 (`claims[].guessId`), contract 02 §4

Spec:
- When `currentChapterIndex` enters a chapter whose claim is a hypothesis with a `guessId`, and the guess is `offered`, a C28 card is inserted after that chapter's last line (in the column, full reading width), arriving with blur-in; "correct this part" steps aside (hides) while the card is on screen.
- Answering: C28's states (confirmed settles; not quite → the composer sheet with "actually…" as C28 says, inside the player sheet); already answered (journal or earlier) → the card shows its answered state ("kept") without pills, or doesn't appear if declined (lean: show nothing once declined, so it isn't asked twice).
- One guess per episode at most (the brain's rule); `speaking == false` → no card.
- Doesn't pause playback; the column keeps following (the card is a line-sized item in the follow).

States: arriving · rest · pending (pill ring) · confirmed · corrected · offline (queued: "saved on this phone") · error · already answered · dark · AX3 (pills stack).

Interaction table: C28's, plus the card's arrival: `blur-in` 220 with no haptic (a buzz mid-listen would startle; restraint) · Reduce Motion: fade.

Accessibility: arrival announced once ("a guess: <question>"), its actions as C28.

Acceptance: matches PC-2's guess state on `B33-0`/`1FVK-0` (state board) light and dark; the card appears once, at its chapter; the answer reaches the journal's guess state.

Tests: (snapshot) arriving, confirmed, already answered, dark, ax3 · (UI) reaching the question's chapter shows the guess card · (UI) answering in the episode marks it answered in the journal (sample shared state) · (unit) no card when speaking is off.

Proof in the PR: standard proof plus the arriving recording.

---

### C24-s · Speed                                                             size: S
Place in the tree: podcasts › PC-2 › transport › speed
Repo · branch: NPRdoinglaundry · `ui/C24-s-speed`
Needs: C24      Unblocks: P14.1

Why: listen faster or slower with one tap, and the number rolls so you see it change.

Inputs: reference §C23 "Speed" (1.0 → 1.25 → 1.5 → 2.0 → 0.8, `numberTick` 320, `select`); C24 (speed sits right of the tray, mono 15 tabular `text.secondary`, episode mode only)

Spec (Paper `1FVN-0`): a 44 × 44 hit area right of the tray: "1.0×", "1.25×", "1.5×", "2.0×", "0.8×" in `font.mono` 15/18 tabular `text.secondary`, centred; tap cycles; the number rolls (`.contentTransition(.numericText())`, `numberTick` 320); `select`; calls `Playback.setRate`. Paper draws it on the brief sheet too (`BBD-0` sits in the shared master), so C24's "hidden for briefs" check resolves to: shown for both.

States: rest · pressed (dims 0.7) · each step · disabled (no audio) · dark · AX3 (fixed size, the label grows inside 44).

Accessibility: "playback speed, 1.25 times, button"; adjustable action up/down cycles.

Tests: (snapshot) 1×, 1.25×, 2×, dark · (unit) the cycle order wraps from 0.8 to 1 · (UI) VoiceOver reads the speed.

Proof in the PR: standard proof plus the roll recording.

---

### C20-p · The player's "…" menu                                            size: S
Place in the tree: podcasts › PC-2 › "…" menu
Repo · branch: NPRdoinglaundry · `ui/C20-p-player-more`
Needs: C20, C24 (the "…" button outside the tray), UI5.0      Unblocks: P14.2

Why: more without clutter: the chapters, keeping the episode on your phone, and where it plays.

Inputs: build note 20 Oct (raised panel, 44 rows, Geist 500: "chapters ›", "download"; "use a native Menu styled to match"; founder hasn't confirmed other items); reference §C20 player menu, F52; master `B1C-0` "menu open" `BFB-0`, `menu/more/open` `BFC-0`; contract 03 §8; founder Q-6

Spec:
- From Paper `BFC-0`: a raised panel 220 wide, `radius.card`, padding `spacing.1`, the card depth plus `depth.shadow.ambient` 0 24 48 −16; rows 44 tall, `radius.control`, padding inline `spacing.3`, gap `spacing.3`: an 18 glyph (`icon.default`) + label (Geist `text.md` medium `text.primary`). Drawn rows: **"chapters"** (list glyph, a 16 `chevron-right` `icon.muted` trailing; absent when `chapters` is empty) and **"download"** (download glyph). States not drawn (to draw with the founder's answer to Q-6): "downloading · 40%" with a 2pt `RSpinner`, "downloaded" with the thin ink check (then the row reads "remove download"). AirPlay isn't drawn: lean, leave it to Control Center (Q-6).
- Values from `BFC-0`; "correct this part" hides while the menu is open (C23).
- Offline: "download" disabled with the reason "you're offline" (`text.tertiary` + reason, C20 disabled row).

States: rest (`BFC-0`) · open · download states (none as drawn; queued, downloading, downloaded, failed "couldn't download · try again" to be drawn) · offline · dark.

Interaction table: C20's choreography (grow from the button toward top-trailing, `select` on settle, close 110) · chapters › pushes UI5.1 inside the sheet · download starts and the menu closes after 120 · remove download asks nothing (undoable by downloading again) · Reduce Motion as C20.

Accessibility: "more, menu"; rows as a list; download row reads its state.

Acceptance: matches `BFC-0`; rows only for what applies; download progress updates live without reopening.

Tests: (snapshot) open with each download state, no chapters, offline, dark · (UI) chapters › opens the chapter list · (UI) download then remove download.

Proof in the PR: standard proof plus the open recording.

---

### UI5.1 · Chapter list                                                       size: S
Place in the tree: podcasts › PC-2 › chapters
Repo · branch: NPRdoinglaundry · `ui/UI5.1-chapter-list`
Needs: C20-p, UI5.0      Unblocks: P14.2

Why: see every topic in the episode and jump straight to one.

Inputs: reference §C23 "Chapter list (PC-2 state): numbered rows, moving bars on the playing one, 'done' to go back (pushed from '…' → chapters ›)"; state board `B33-0`; contract 03 §3 `chapters`

Spec: pushed inside the sheet; header: ‹ back + "chapters" + "done" (text button, trailing); rows (settings-row shape, 56): mono number well (the C32 numbered well), chapter title (17 `text.primary`, 2 lines), start time (mono 13 `text.label`, trailing); the playing chapter shows three moving level bars (`RWaveform` mini, `text.primary`) in place of its number; played chapters' titles `text.secondary`.

States: rest · playing row · played rows · pressed · dark · AX3 (time moves under the title) · Reduce Motion (bars still).

Interaction: tap a row → seek to its start, pop back to the player, `select` · done/back → pop · Reduce Motion fade.

Accessibility: "chapter 2 of 5, sunday walks, starts at 3 minutes 24, playing".

Acceptance: matches `B33-0`'s chapter list; the playing row follows playback live.

Tests: (snapshot) mid-episode, first chapter playing, dark, ax3 · (UI) tapping a chapter seeks and returns to the player.

Proof in the PR: standard proof.

---

### UI5.4 · Episode feedback                                                   size: S
Place in the tree: podcasts › PC-2 › after the episode › feedback
Repo · branch: NPRdoinglaundry · `ui/UI5.4-episode-feedback`
Needs: **a Paper drawing approved by the founder** (not drawn yet; the integrator draws it on the approvals page from founder Q-2's lean), RPill, RVoiceComposer (#56), UI5.0      Unblocks: P14.2

Why: when an episode ends you can tell Retro, in a tap or in your own words, what you want more or less of, and next week's episode is written with it.

Inputs: contract 03 §5; founder Q-2 (lean A); reference §C23 "ended (last line stays; 'play next' or 'back to journal')"; C28's pill pattern

Spec (lean A, to be replaced by the approved drawing's values):
- In the ended state, under the last line: one plain line "how was this one?" (Geist 14 `text.secondary`) and two wash pills "more like this" · "less like this" (36 in 44), then "say more" (text button) which opens the composer sheet (voice or type) inside the player sheet.
- After a verdict: the pills fold into one line "thanks. next week's will hear it." (founder copy) with the `check` glyph; `confirm`.
- Already given (`episode.feedback`): the line shows the given verdict ("you asked for more like this") with "change" (text button).
- Offline: queued ("saved on this phone"), never blocks.

States: ended ask · verdict given · say more (composer) · sent · queued offline · already given · dark · AX3.

Interaction: pill 0.94, `confirm` on send · say more → composer sheet, `sheetSnap` · Reduce Motion fade.

Accessibility: "how was this one? more like this, button; less like this, button".

Acceptance: matches the approved drawing; a verdict is one tap; nothing about the person is shown back.

Tests: (snapshot) each state · (UI) a verdict sends once and folds the pills · (UI) say more opens the composer.

Proof in the PR: standard proof next to the approved drawing.

Watch out: the copy must not promise more than BE3.2a does ("next week's will hear it" is true once BE3.2a ships; until then this card waits).

---

### P14.1 · PC-2 the player: opening, playing, closing, states                 size: M
Place in the tree: podcasts › PC-2
Repo · branch: NPRdoinglaundry · `ui/P14.1-player-episode`
Needs: UI5.6, C23e.1, C23e.2, C24-s, C22, P13.1, UI5.0      Unblocks: P14.2, M09, T05a

Why: the weekly episode, in full: its title, its words as they're spoken, its chapters on the scrubber, the controls under your thumb.

Inputs: Paper PC-2 `1FV9-0` (approved; hi-fi board `H1F-0`), master `B1C-0` (ready `BBA-0`, playing `B99-0`, holding scrubber `BDA-0`); reference §E P14 (transcript flexes; controls stay on screen; bands 64/80 on SE), §C23; contract 03 §3

Spec: C23b's frame in episode mode through `PlayerPresentation` (UI5.6), with C23e.1's header and title, C23e.2's transcript, C25 with one capsule per chapter (none for legacy: one capsule), C24 with "…" and speed outside the tray. The page behind is whichever tab opened it.

**Interaction sheet:**

| # | Moment | What happens | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|---|
| 1 | open from the hero's play | the sheet rises, the title morphs from the tile, the behind recedes, the transcript staggers in, controls last; playing | `sheet`, stagger 60 | `press`, `sheetSnap` | 140 fade |
| 2 | open from a tile or a push | the same, paused at the start (or the remembered position) | zoom / `sheet` | `sheetSnap` | fade |
| 3 | open from the mini-player | artwork, title and play morph from C22 | `sheet` | `sheetSnap` | fade |
| 4 | play | the title scrolls into the header (C23e.1) | scroll | `press` | cut |
| 5 | playing | the spoken line follows (C23e.2) | `transcriptFollow` 420 | — | jump |
| 6 | scrub | C25 with chapter capsules and ticks | C25 | `chapterTick` | C25 |
| 7 | skip, play/pause, speed | C24, C24-s | C24 | `skip`, `press`, `select` | C24 |
| 8 | the link expires during a long pause | resumes silently with a fresh link (PL3.4c1) | — | — | — |
| 9 | the episode ends | the last line stays; replay; UI5.4's ask (P14.2) | morph | — | — |
| 10 | close (⌄, drag, escape) | the title morphs into the mini-player; playback continues | `sheetDismiss` | — | fade |
| 11 | leave the app | audio continues; the lock screen shows the chapter (PLP.2) | — | — | — |
| 12 | a phone call | pauses; resumes only on tap (PLP.1a) | play morph | — | glyph swap |

State table (page, T02 `-State`): `episodeReady`, `episodePlaying`, `episodeHeldScrub`, `episodeBuffering`, `episodeEnded`, `episodeLegacy` (one capsule, no follow), `noAudio` (words only: the transport is replaced by one line "this episode is words only" and the transcript reads freely; founder copy), `offlineNotDownloaded` ("offline · it'll play when you're back online", C24), `offlineDownloaded` (plays), `failed` ("couldn't load this episode" + retry; the words stay readable if loaded), `loading`, SE.

Accessibility: `performAccessibilityAudit()` passes in ready, playing and legacy; escape closes; VoiceOver order as C23b.

Acceptance: every row built and recorded; every state against `1FV9-0`/`B1C-0` (others against C23b's and C39's, listed) in light, dark (`2IFN-0`), AX3, SE; closing and reopening keeps the position; one sheet ever.

Tests: (UI) playing this week's episode from podcasts opens the player and shows pause · (UI) closing leaves the mini-player playing · (UI) the mini-player reopens at the same position · (UI) a legacy episode plays with no chapter ticks · (UI) offline and not downloaded says so and doesn't play · (accessibility) the audit passes in ready, playing, legacy · (snapshot) ready, playing, held scrub, ended, legacy, no audio, offline, failed; light, dark, ax3, SE.

Proof in the PR: page proof plus recordings of rows 1, 3, 4, 6 and 10, and SE.

---

### P14.2 · PC-2 the player: menu, chapters, a guess, correcting, feedback      size: M
Place in the tree: podcasts › PC-2 › everything behind the first touch
Repo · branch: NPRdoinglaundry · `ui/P14.2-player-more`
Needs: P14.1, C20-p, UI5.1, C23e.3, UI5.4 (or without it, with its row deferred), UI1.2      Unblocks: P15, T05a

Why: everything else the player can do, without leaving it: chapters, downloads, the guess, correcting a part, and telling Retro how it went.

Spec: the in-sheet routes (`PlayerPresentation.route`): `.chapters` (UI5.1), `.claim(id)` (P15), the correction flow (UI1.2's sheet content pushed inside the player sheet: never two sheets), the composer for "not quite" and "say more". ‹ back always returns to the transcript at the same part (founder c-rji9hn).

**Interaction sheet:**

| # | Moment | What happens | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|---|
| 1 | "…" | C20-p opens | popover | `select` | fade |
| 2 | chapters › | the list pushes in | push | — | fade |
| 3 | a chapter | seeks, pops back | glide | `select` | jump |
| 4 | download | the row shows progress; the menu closes | — | — | — |
| 5 | the question's chapter arrives | the guess card (C23e.3) | blur-in | — | fade |
| 6 | that's right / not quite | C28 | C28 | `confirm` / `select` | C28 |
| 7 | long press a line | the line menu (C23e.2) | popover | `longPress` | fade |
| 8 | correct this part | UI1.2 pushed in the sheet; done returns | push | — | fade |
| 9 | why this is here › | P15 pushed in the sheet | push | — | fade |
| 10 | the episode ends | UI5.4 ask | blur-in | — | fade |

Acceptance: every row built and recorded; one sheet; back always lands on the same part.

Tests: (UI) the chapter list seeks to a chapter · (UI) answering the guess in the episode shows it kept · (UI) correct this part opens the correction for that part and returns · (UI) why this is here opens from a long press and back returns to the same line · (UI) feedback at the end sends once.

Proof in the PR: recordings of rows 1–3, 5–9.

---

### UI5.3 · The claim: stated or asked (shared component, built here)          size: S
Place in the tree: podcasts › PC-3 › claim. **Shared:** `c:claim/stated` and `c:claim/asked` are also used by goals (GL-2, `1G45-0`) and you (YO-4, `1GDS-0`). It is built once, here, because PC-3 ships first; the goals and you plans reuse it and add only their label variants.
Repo · branch: NPRdoinglaundry · `ui/UI5.3-claim`
Needs: C28 (the asked card's dashed recipe), T01      Unblocks: P15 (and P17, P21 later)

Why: what Retro claims is shown big and plain when it's stated, and as a dashed question when it's only a guess, so a guess never looks like a fact.

Inputs: part 41 `G1E-0` (stated `G2A-0`, asked `G3C-0`); PC-3 instance `c:claim/asked` `1FZ6-0`; 05 states `NDK-0` (stated), `NBD-0` (asked); handoff part 41 ("stated claim = inky 3xl + label line 'stated · from what you did · very sure'. asked = dashed guess card"); reference §E P15 (min height 142, claim keeps its size); contract 03 §4

Spec:
- **Stated** (Paper `G2A-0`, no card): `font.display.inky` `text.3xl` `font.weight.inkTitle` `tracking.title` `leading.tight`, balanced, lowercase as given; gap `spacing.2`; the label line Geist `text.sm` `text.label`: "stated · from what you did · very sure" (basis said/did/both; no sureness → omitted); min height 142.
- **Asked** (Paper `1FZ6-0`): `inference.surface`, `radius.card`, 1pt dashed `inference.border` (inset), padding `spacing.4`, gap `spacing.2`: "a guess" (Geist `text.sm` medium `text.label`), the question in `font.display.inky` `text.2xl` `inkCard` `tracking.card` `leading.tight` balanced, and "asked · fairly sure · rests on 3 mornings" (Geist `text.sm` `text.label`). **Paper shows sureness on asked claims and no answer pills here**: the guess is answered where it arrives in the transcript (C23e.3), and PC-3's own action is "not right". The contract is changed to carry sureness on asked claims. "rests on 3 mornings" uses a noun the brain doesn't produce: the app writes "rests on <total> <kind word>" ("3 entries", "4 things" when mixed); listed in README §9.
- The variant's name and values come from `G2A-0`/`G3C-0`; GL-2's "asked · a pattern" (`1G45-0`) is the same component with a label change (that page's card adds it).

States: stated · asked · long (4 lines) · no sureness · dark · AX3 · Increase Contrast (dash 1.5). No pressed state: the claim isn't tappable.

Accessibility: stated: "stated, from what you did, very sure: <text>"; asked: "a guess, asked, fairly sure: <text>".

Acceptance: matches `G2A-0` and `G3C-0` light and dark (`2PBS-0`); a guess never renders as stated.

Tests: (snapshot) stated, asked, long, no sureness, dark, ax3 · (unit) an asked claim can't be built with the stated style (the initializer takes the register) · (unit) "rests on" picks the kind word, or "things" when mixed.

Proof in the PR: standard proof.

---

### UI5.2 · "Where retro says it": the moment card                               size: S
Place in the tree: podcasts › PC-3 › moment card
Repo · branch: NPRdoinglaundry · `ui/UI5.2-moment-card`
Needs: #42 (`RArtwork`), RPill (#45), UI5.0      Unblocks: P15

Why: hear the exact moment Retro said it, in its own voice, with one tap.

Inputs: reference §C32 related ("where retro says it" card, c-9ll481: raised moment card, Retro's line inky, small weekly mesh thumb, "at 4:12 in this week's", "hear it" wash pill; motion-moments: soft press, a thin progress line draws under the quote while playing; asked state "where retro asks it"; `.scrollClipDisabled()`); PC-3 instance `c:episode-moment/rest` `1FY2-0` (**no master on 02 components**: inventory §2); contract 03 §4 `moments`

Spec:
- From Paper `1FY1-0`/`1FY2-0`: the label above the card ("where retro says it" / "where retro asks it", Geist `text.sm` medium `text.label` `tracking.label`, gap `spacing.2`); the card: `background.raised`, `radius.panel`, padding `spacing.4`, gap `spacing.3`, depth inner-top + outer 0.5 + contact 0 1 2 + cast 0 10 24 −12; the quote in curly quotes, `font.display.inky` `text.xl` `inkCard` `tracking.card` `leading.tight`, pretty wrap, ≤ 3 lines; a row (gap `spacing.3`): a 32 `RArtwork` thumb at `radius.default` (weekly or older recipe), "at 4:12 in this week's" / "at 4:12 in <episode title>" (Geist `text.sm` `text.label`, flexes), and a "hear it" wash pill (32 high, `radius.control`, padding inline `spacing.3`, gap `spacing.1`, 14 play glyph, Geist `text.sm` medium). The reference's "40 thumb" is superseded by Paper's 32.
- "hear it": plays from `startSeconds` (this episode: seeks the current player and returns to the transcript at that line; an earlier episode: loads it into the player at that moment and returns to its transcript). No `startSeconds` → no pill.
- Playing: a 2pt `player.progress` line draws under the quote, linear in real time, until the quote's line ends.
- Several moments: this episode's card, then earlier ones below it (at most 3).

States: rest · pressed (0.98 card, 0.94 pill) · playing (line drawing) · no time (no pill) · dark · AX3.

Interaction: "hear it" 0.94, no haptic (non-lit), seeks and plays, the line draws · Reduce Motion: the line appears full, no draw.

Accessibility: "where retro says it: <quote>, at 4 minutes 12 in this week's episode. hear it, button".

Acceptance: matches `1FY2-0` light and dark; the shadow isn't clipped (the page sets `.scrollClipDisabled()`).

Tests: (snapshot) this episode, an earlier episode, asked, no time, playing, dark, ax3 · (UI) hear it plays from that moment.

Proof in the PR: standard proof; the integrator asks the founder whether the moment card should get a master on 02 (inventory finding).

---

### P15 · PC-3 why this is here                                                 size: M
Place in the tree: podcasts › PC-3
Repo · branch: NPRdoinglaundry · `ui/P15-why-this-is-here`
Needs: P14.2, UI5.3, UI5.2, C32, UI1.2 (not right), UI5.0      Unblocks: T05a

Why: any part of an episode can show you what it claims, how sure Retro is, where it said it, and every source it rests on, in your own words.

Inputs: Paper PC-3 `1FXG-0` (approved; hi-fi board `I0Q-0`): sheet `1FXR-0`, ‹ `1FZI-0`/`1FZJ-0`, ⌄ `1FZD-0`, claim/asked `1FZ6-0`, evidence rows `1FYW-0` (journal `1FZ3-0`, calendar `1FYL-0` glyphs, › `1FYX-0`), moment `1FY2-0`, pill `1FY4-0` + `correct` `1FXW-0`; 05 stated `NDK-0`, asked `NBD-0`; dark `2GV0-0`; reference §E P15 (rows one line, claim keeps its size, sheet `minHeight 0` so "not right" stays in the thumb zone; moment card below the fold); C23 note c-rji9hn (‹ goes back to the transcript at this exact part; ⌄ closes the whole player; founder may drop ⌄, later.md lean: keep ‹ only, swipe down closes); contract 03 §4

Spec:
- Pushed inside the player sheet (Paper `1FXR-0`: padding inline 28, bottom `spacing.10`; grabber 36 × 5 with 18 under it). Header (`1FZA-0`): a 32 wash ‹ (`radius.control`, 20 glyph), the episode title (Geist `text.md` medium, one line, 220 wide), and a 34 wash ⌄ on the trailing side. Paper still draws ⌄; later.md's lean (drop it) is founder Q-12 and the card builds what Paper draws until answered.
- Content order (`1FY0-0`, padding top `spacing.6`, gap `spacing.8`): UI5.3 claim → "what it rests on" (label, gap `spacing.2`) over the rows in one `background.canvas` group at `radius.panel` with a 0.5 outer stroke; C32 rows (min height `size.row.default`, padding 12/16, gap 12; 32 wash well at `radius.default` with an 18 glyph; label "14 oct · your words" / "17 oct · calendar" (Geist `text.sm` `text.label`, gap `size.border.ring`); one line of excerpt in SF `text.md` `tracking.card` `text.primary`; a 14 `chevron-right` `icon.muted`; a 1pt `border.subtle` divider inset at the bottom, none on the last) → "and <n> more" row loading the next page when `total` > shown (not drawn: a C32 row variant, listed) → "where retro says it" (UI5.2) → the "not right" pill (`1FXU-0`: 36 high, wash, `radius.control`, padding inline `spacing.4`, gap `spacing.2`, 16 `correct` glyph, Geist `text.md` medium), padding top `spacing.4`, pinned in the thumb zone (`minHeight: 0` on the scroll).
- "not right" (stated and asked alike, as Paper draws) → UI1.2's flow with `about = claim.correct` when present, else free text. An asked claim's guess is answered where it arrives in the transcript (C23e.3), not here.
- A row with `opens` → JR-4 (the entry page, pushed over the player? lean: closes the player to the mini-player and pushes JR-4 on the journal tab; listed).
- `total: 0`: "nothing to show yet" line (C39.2 style) and no rows: never invented.
- `.scrollClipDisabled()` for the raised moment cards.

**Interaction sheet:**

| # | Moment | What happens | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|---|
| 1 | arrive (why line, line menu, link) | pushes in; the claim first, rows stagger 40 | push, stagger | — | fade |
| 2 | ‹ back | returns to the transcript at the same part | pop | — | fade |
| 3 | swipe down | closes the whole player to the mini-player | `sheetDismiss` | — | fade |
| 4 | a row › | opens the entry (see above) | — | — | fade |
| 5 | and n more | the next rows bloom in | `map` | — | fade |
| 6 | hear it | UI5.2 | — | — | — |
| 7 | not right | UI1.2 flow, pushed | push | — | fade |

State table: `claimStated` · `claimAsked` (a hypothesis) · `claimAskedWhy` (a why question) · `claimNoEvidence` · `loading` (claim at once if cached, rows skeleton) · `offline` (cached or the C39.3 line) · `error` · long excerpt (one line, truncated; full text in the label) · SE · dark · AX3.

Accessibility: rotor: back → claim → rows → moments → not right; the audit passes in stated and asked.

Acceptance: every state against `1FXG-0`, `NDK-0`, `NBD-0` (light, dark `2GV0-0`, AX3, SE); rows never wrap; not right stays in the thumb zone on SE.

Tests: (UI) the why line opens why this is here and back returns to the same line · (UI) a stated claim lists its evidence and loads more · (UI) an asked claim shows dashed with its sureness and no answer pills · (UI) not right opens the correction for this claim · (accessibility) the audit passes in stated and asked · (snapshot) every state; light, dark, ax3, SE.

Proof in the PR: page proof plus recordings of rows 1, 2, 5, 7.

Watch out: excerpts are the person's words: never in logs or analytics; screenshots use sample data only.

---

### M09 · Play morph, rolling time, chapter ticks                               size: M
Place in the tree: podcasts › PC-2 › signature moment M09 (also JR-2, ON-11)
Repo · branch: NPRdoinglaundry · `ui/M09-player-moment`
Needs: P14.1 (and P10)      Unblocks: the L3 flow pass

Why: the player feels alive in your hand: play melts into pause, the time rolls when you skip, and you feel each chapter as you scrub across it.

Inputs: reference §C M09 (playMorph 180, skip icon rotates 20° on `snappy`, thumb 12 → 20, `numberTick`, `skip`, `chapterTick`); part 09 `A38-0`; microinteractions acceptance (filmstrip in 02b with a red dot, preview in `DesignSystemV2/Motion/`, real-iPhone recording, then screens)

Spec: tie together what C24/C25 built: the play/pause glyph morph (scale 0.8 + opacity cross, centred by frame); elapsed and remaining roll on skip (`.numericText`, `numberTick` 320); `chapterTick` once per capsule crossing during a held scrub (fast drags fire each); skip arrows turn 20° and back. Audit every part for one haptic at landing and Reduce Motion (glyph cross-fade, no roll, no turn; ticks stay: they're haptic, not motion).

Acceptance: the founder's sign-off from the recording next to the filmstrip; 60 fps on the oldest phone.

Tests: (unit) two capsule crossings in one move fire two ticks · (motion) hitch ratio during a held scrub · (UI) Reduce Motion: no roll.

Proof in the PR: recording next to the filmstrip; Instruments summary.

---

### M06 · The player shrinks into the mini-player (shared with first run)        size: L
Place in the tree: first run › ON-11 → ON-12 (the paywall) · and podcasts › PC-2 close
Repo · branch: NPRdoinglaundry · `ui/M06-player-to-mini`
Needs: P07 (first run's paywall), P14.1, C22-p (first run)      Unblocks: the L1/L3 flow passes

Why: when the tease ends, the player you were listening to shrinks into the paused mini-player at the top while the paywall rises from the strongest line, one continuous motion.

**Owner:** first run's paywall (reference F40: M06 belongs to first run, though the progress map lists it under podcasts). Listed here because its morph is PC-2's close morph run upward; the first-run planner builds it. The podcasts part is only: P14.1's close morph must expose the same matched-geometry ids (`player.title`, `player.artwork`, `player.play`) so M06 can reuse them.

Acceptance (podcasts side): P14.1's close morph uses those ids; a test asserts them.

---

### T05a · The podcasts flow test                                                size: M
Place in the tree: podcasts › flow test (layer 8; then layer 9 with the integrator)
Repo · branch: NPRdoinglaundry · `ui/T05a-podcasts-flow` (with the integrator)
Needs: P13.1, P13.2, P14.1, P14.2, P15, PL3.4g (links)      Unblocks: ship gate G3

Why: one test proves the weekly episode works end to end: find it, play it, read along, jump chapters, answer its question, see why a part is there, keep it offline, and come back to it.

Inputs: testing.md (layers 8, 9); every page card's states; contract 03 fixtures

Spec (XCUITest with T02, `-Data sample`, then `-Environment local` on the integrator's run):
1. Launch on PC-1 `full` → the hero shows with its play (one lit object).
2. Play the hero → the player opens playing; the title moves into the header.
3. Scrub across two chapters (a held drag) → two ticks recorded; release seeks.
4. "…" → chapters › → choose chapter 3 → back in the player at chapter 3.
5. Reach the question's chapter → the guess card → "that's right" → kept; the journal's guess shows answered.
6. Long-press a stated line → why this is here › → the stated claim, evidence rows, "and n more" → back → the same line.
7. "…" → download → downloaded; go offline (sample `isOnline` off) → the episode still plays; another episode says it'll play when you're back.
8. Close → the mini-player plays on the journal tab → tap it → the same position.
9. Relaunch → the mini-player is back, paused, at the position.
10. Open `retrospect://podcasts/episodes/<id>` → that episode, paused.
11. The episode ends → feedback "more like this" → sent once (sample outbox count).
12. Accessibility audit on PC-1, PC-2 and PC-3 in their main states.

Layer 9 (local staging, integrator): the same on a seeded account with a v2 episode made by the job runner (BE3.3a), chapters measured (BE3.0b), a real signed link and its renewal after a 2-minute staging TTL, and the push sandbox tap (BE3.3b) on the founder's phone at the ship gate.

Acceptance: green three runs in a row; no flaky step (testing.md §4).

Tests: the flow above, each step an assertion with an identifier.

Proof in the PR: test output; the staging run's recording (integrator).
