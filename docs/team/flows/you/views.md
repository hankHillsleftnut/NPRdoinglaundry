# You · view cards (components, pages, motion, the flow test)

The tree for this side: **you** › sample data (UI5.0) › YO-1 you (P18: top bar C17-y, search field C12-y, the map C38.1–C38.5, M12, rows) › the list view (UI6.7, the portrait) › YO-2 search (P19.1, P19.2: the answer card UI6.1a–c, numbered sources C32-n) › YO-3 a source (P20, UI6.6) › YO-4 a node (P21.1, P21.2: claim UI6.2, sureness UI6.3, link chips UI6.4, C32, C19.1, C28 variant) › YO-5 what Retro knows (P22: answer row UI6.5) › the flow test (T05c).

**Paper was not running when this plan was written** (21 Oct). Node ids come from `reference/paper-inventory.md` and `docs/design/ios-handoff.md`; every card says "values from `get_computed_styles`" and its first step is to read them. Any value written here as a number is from the design reference or build notes and is checked against Paper in the PR; Paper wins (newest source).

**Reused, not rebuilt:** C17 top bar, C18 tab bar, C19.1 sheet host, C19.2 dialog, C20 menu, C28 guess card, C32 evidence row, C39.1–C39.4 shared states, C22 mini-player, `RSettingsRow` (switch and nav rows), `RPill` (#45), `RSunkenField` (#53), `RIconButton` (#44), `RSpinner`, `RSymbol`, `RIconWell`, `RMotion`, `RHaptic`, `.rBlurReplace`, `.rPress`, P12 (JR-4: your own words opened from search).

**Shared with other areas (the integrator decides the owner):**
- `c:claim/stated` and `c:claim/asked` (part 41 `G2A-0`, `G3C-0`) are also PC-3's and GL-2's. UI6.2 builds both here unless the podcasts plan's claim card merges first; then UI6.2 shrinks to the YO-4 variant.
- C38's orbits variant without labels is also the splash (UI4.4), AC-1 (P32) and the paywall tile; C38.1–C38.3 are built so those can pass `labels: .hidden`.
- C17-t (the plain tab title) belongs to the podcasts plan; C17-y adds only the You trailing items.

Sizes: S under half a day, M about a day, L two days (none left at L).

---

### UI5.0 · SampleYouData and its ledger                                   size: M
Place in the tree: you › sample data
Repo · branch: NPRdoinglaundry · `ui/UI5.0-sample-you`
Needs: `Platform/Flows/You.swift` (integrator), PL3.6a's wire types (or the protocol's model structs if PL3.6a lands later)      Unblocks: every You view card, T05c

Why: every You screen can be built, screenshotted and tested in every state before the server has a single door.

Inputs: contract 05 (shapes), `fixtures/05/` (the invented people and lines to start from), ui-engineer.md §4 (scenario-driven, deterministic, ledger), T02 (`-Screen YO-n -Data sample -State <name>`).

Spec:
- `Features/You/Sample/SampleYouData.swift`: `@MainActor @Observable final class SampleYouData: YouData`, driven by `YouScenario`:
  - map: `full` (7 nodes, 2 node-to-node lines, a waiting question), `dense` (24 nodes, labels colliding), `dayOne` (empty), `newNode` (one ref unseen → M12), `loading` (never resolves), `offline` (cached map + offline), `error`
  - node: `person`, `personNoFact`, `theme`, `goal`, `answerGuess`, `question`, `confirmed`, `gone`, `long` (a 3-line claim, an 18-character name)
  - search: `idle`, `searching`, `slow` (past 8 s), `found` (3 sentences, 1 guess, 4 sources), `foundCertainOnly`, `nothingFound`, `closest`, `spendLimited`, `offline`, `failed`
  - understanding: `full`, `dayOne` (all silent), `movedThisWeek`, `ax3Long`
  - portrait: `full`, `empty`
- Content: invented, lowercase, from the fixtures' people ("priya", "sam", "dana reyes") and lines; every value logged in `docs/design/sample-data-ledger.md`.
- Deterministic: an injected clock (21 Oct 2026, 08:00 local), no randomness; "loading" is a task that never resolves; `slow` advances the injected clock past 8 s.

Acceptance: every state named in P18–P22's state tables is selectable with T02 flags; nothing on screen comes from a hard-coded string in a view.

Tests: (unit) `every scenario builds without a network` · (unit) `the sample map never has more than 24 nodes` · (unit) `sample content contains no real person's name` (a deny-list check the ledger maintains).

Proof: the ledger diff; a screenshot grid of P18's states once P18 lands (in P18's PR).

---

### C17-y · Top bar, You variant (title · list pill · your picture)        size: S
Place in the tree: you › YO-1 › top bar
Repo · branch: NPRdoinglaundry · `ui/C17-y-top-bar-you`
Needs: C17, C17-t (podcasts plan), `RPill` (#45)      Unblocks: P18, P19.1

Why: "you" sits where every tab's title sits; the list view and your settings are one tap away, without competing with the search field.

Inputs: Paper YO-1 `c:top-bar/title/rest` `1G7X-0`, YO-2 `1GAB-0`; design-reference §C17 variant 2 ("you" with a trailing "list" wash pill + your picture, avatar aligned to the field's right edge); finding 55 (YO-2's bar still shows the old "list" text and grey mic: match YO-1).

Spec:
- Trailing group: a wash `RPill` "list" (opens the list view, UI6.7) and your picture (a 36 circle in a 44 hit area, opening ST-1). The picture is the person's initial on `surface.wash` when there's no photo (text 0.5pt high, craft §2.9). Its right edge aligns to the search field's right edge (one shared leading/trailing guide in P18).
- On YO-2 the bar is the same; the pill's label is "list" while the map shows and is hidden while a search result shows (the list view is the map's alternative, not the result's).
- Values from `get_computed_styles` on `1G7X-0`.

State table: rest · pill pressed (0.94, 80/240) · picture pressed (0.94) · AX3 (the title wraps to two lines; pill and picture stay one line, the pill's label never truncates) · dark.

Interaction table:

| Touch | Press | Haptic | Motion | Outcome | Reduce Motion |
|---|---|---|---|---|---|
| list pill | 0.94 | none | `RMotion.press` | the list view pushes (UI6.7) | no scale |
| your picture | 0.94 | none | push | ST-1 settings | no scale |

Accessibility: "list view, button"; "settings, button" (the picture's label); rotor order title → list → settings.

Acceptance: matches `1G7X-0` in light, dark and AX3; YO-2's bar matches YO-1's.
Tests: (snapshot) rest, AX3, dark · (UI) the picture opens settings.
Proof: standard proof.
Watch out: the "list" pill is a page action, not the lit object: wash, never lit.

---

### C12-y · Search field, You variant (mic well, typed, clear)            size: S
Place in the tree: you › YO-1 / YO-2 › search field
Repo · branch: NPRdoinglaundry · `ui/C12-y-search-you`
Needs: `RSunkenField` (#53), `RIconButton` (#44)      Unblocks: P18, P19.1

Why: you can ask anything about your life, by typing or talking, from the top of You.

Inputs: Paper YO-1 `c:search-field/rest` `1G7R-0` + mic `1G7U-0`; YO-2 `c:search-field/typed` `1GA2-0`, mic `1GA8-0`, clear `1GA4-0`; part 50 masters `K0B-0` (rest), `K0J-0` (typed), `K0D-0` (mic), `K0P-0` (close); handoff part 50 ("48 high, `surface.control`, sunken inner shadow, 36 mic well first, placeholder `text.tertiary`, clear × when typed"); build notes "Search and type" (sunken = translucent dark wash over its parent, `surface.washPressed`; SF Pro body tracking, never 0).

Spec:
- `RSunkenField` with a leading 36 raised mic well (YO-1 draws the mic **raised 40**; take the size from `1G7U-0`), the placeholder (copy from Paper), and a trailing clear × (`RIconButton` 32 in field) once there's text.
- Submit on return (`.submitLabel(.search)`); no search-as-you-type (each search costs money and seconds).
- Mic (founder question 10, lean A): starts on-device dictation into the field (the composer's speech recogniser through its existing protocol); the well shows the listening job (blue, the only blue here) while listening; stopping leaves the words in the field for you to send.
- Focused: the field's ring per `RSunkenField`; the keyboard rises.

State table: rest · focused · typed (clear ×) · listening (mic lit-listening, words appear) · disabled (offline: placeholder "search needs a connection", mic disabled) · AX3 (field grows to fit, mic stays 36) · dark (sunken darker than its parent).

Interaction table:

| Touch | Press | Haptic | Motion | Outcome | Reduce Motion |
|---|---|---|---|---|---|
| tap field | — | none | keyboard curve | focus | same |
| return | — | none | — | `search(query)` | same |
| clear × | 0.94 | none | × scales in on `popover`, out on `snappy` | text cleared; YO-2 returns to YO-1 (P19.1) | fade |
| mic | 0.94 | `listenStart` / `listenStop` | the composer's listening look | dictation | no pulse |

Accessibility: "search your life, search field"; mic "dictate"; clear "clear search"; announces "listening".
Acceptance: matches `1G7R-0` and `1GA2-0` in light, dark, AX3.
Tests: (snapshot) rest, typed, listening, offline, dark, ax3 · (UI) return submits the query once · (UI) clear empties the field.
Proof: standard proof; a recording of dictation (headless, injected recogniser).
Watch out: never log or persist the field's text; the field is `.privacySensitive()`.

---

### C38.1 · You map: canvas, orbits, the you-orb and the slot table        size: M
Place in the tree: you › YO-1 › the map › canvas
Repo · branch: NPRdoinglaundry · `ui/C38.1-map-canvas`
Needs: T01, `RArtwork`'s orb recipe (the splash's you-orb, `1GYN-0`)      Unblocks: C38.2–C38.5, P18, UI4.4, P32

Why: the map is a hand-made picture of your life with you at the centre; it has to look like the founder's drawing, with your data placed into it.

Inputs:
- Paper: part 05 `9BS-0` (master, approved), YO-1 instance `c:you-map/orbits/rest` `1G6Z-0`, AC-1 `1GYO-0`, splash `1F5K-0`; hi-fi board `K2D-0` on `p-D-0`
- Spec: `design-system/components/you-map.md` (older), design-reference §C38 (newer: orbits, frosted glass, straight lines, label plates), build notes "You map" and "You map (more)": **hand-crafted by the founder; never generated from a layout algorithm without their sign-off**
- Tokens: `map.node.self`, `map.star.self.core/halo`, orbit ring colour, grain 4%

Spec:
- `RYouMap` canvas: the page (level 0), grain 4%, bleeds past the margins (`.ignoresSafeArea(edges: .horizontal)` inside its frame).
- The orbit rings (count, radii and stroke from `get_computed_styles` on `9BS-0`), drawn first.
- The you-orb, 56, centred, not a button (`accessibilityHidden`, the list carries meaning).
- **The slot table** (founder question 2, lean A): `YouMapSlots.swift`, the orb positions read from Paper's `1G6Z-0` children as unit coordinates on the rings (angle + ring index), at most 24, grouped by kind as drawn; the data fills slots in `weight` order per kind. The PR body shows the slot table drawn over the Paper screenshot for the founder's sign-off. No force layout, no randomness.
- Scale: YO-1 0.82 on SE (c-o1stxz, by container height, never the device model); AC-1 0.78.
- Variant `labels: .shown | .hidden` (hidden for the splash, AC-1 and the paywall tile: "never show node names before auth").

State table: rest (rings + you-orb) · dark (dark map tokens) · SE (0.82) · Reduce Transparency (rings solid at the same contrast).
Accessibility: the canvas is `accessibilityHidden`; C38.4 supplies the list.
Acceptance: the empty canvas overlays `1G6Z-0`'s rings and centre within 1pt at 1×; the slot table is reviewed by the founder.
Tests: (snapshot) canvas light, dark, SE scale · (unit) `the slot table has at most 24 slots and none overlaps another's label side`.
Proof: overlay screenshot against Paper; the slot table image.
Watch out: the slot table is data from Paper, kept in one file; a change in Paper is a new PR to that file only.

---

### C38.2 · You map: the orb (frosted glass, kinds, sizes, guesses, label plates)   size: M
Place in the tree: you › YO-1 › the map › orb
Repo · branch: NPRdoinglaundry · `ui/C38.2-map-orb`
Needs: C38.1      Unblocks: C38.4, M12

Why: each person, theme and goal is a small glass sphere sized by how much it matters, and a guess looks like a guess.

Inputs: design-reference §C38 anatomy; build notes ("frosted glass: a 12% white base under its gradient and ~1.5pt backdrop blur"; "glass spheres: two light gradients, a top rim, a hairline, a soft cast; far ones smaller, blurred and dimmed"; "names never sit on a thread or a ring: on the side away from you, on a canvas-coloured plate, 2 × 4 padding"); tokens `map.node.person/goal/theme`, `size.map.nodeMin/nodeMax`, `inference.border`, `map.nodeLabel`.

Spec:
- `RMapOrb(kind:, weight:, isGuess:, label:, depth:)`: diameter = lerp(`size.map.nodeMin`, `size.map.nodeMax`, weight) (tokens; Paper's values win over the older spec's 12 → 44); fill by kind; 12% white base + backdrop blur ~1.5pt clipped to the circle (iOS 26: a material; iOS 18: a blurred snapshot of the layer behind, measured for cost); two light gradients + top rim + hairline + soft cast (card tier only when > 24, per spec).
- Guess: dashed ring `inference.border` and no fill change (never colour alone).
- Label: under or beside on the side away from you, mono 11 `map.nodeLabel` (Geist if Paper shows Geist: screen rule 4 "almost no mono"; check `1G6Z-0`), on a canvas plate (2 × 4, small radius); only for nodes over 20pt; smaller ones label on press. Collisions: the smaller label hides.
- Depth: `depth` 0…1 from the slot (far = smaller, blurred, dimmed).

State table: rest · pressed (1.1×, 2pt `map.selectedRing`) · dimmed (`opacity.dimmed` 0.25) · guess · waiting (one quiet glow, `map.star.self.halo` at low opacity, still: no pulse; life rules) · dark · Increase Contrast (labels `text.primary`, ring full opacity) · Reduce Transparency (solid base).
Accessibility: orbs are not individually focusable on the canvas (C38.4's list is).
Acceptance: an orb of each kind at min and max, guess and waiting, matches part 05 in light and dark at 4×.
Tests: (snapshot) each kind × min/max, guess, waiting, pressed, dimmed, light/dark · (unit) `labels never sit on the line toward you`.
Watch out: data stars emit light, no white specular highlight (surfaces.md); the frosting must not grey the orb in dark mode (measure contrast).

---

### C38.3 · You map: threads                                                size: S
Place in the tree: you › YO-1 › the map › threads
Repo · branch: NPRdoinglaundry · `ui/C38.3-map-threads`
Needs: C38.1      Unblocks: C38.4, M12

Spec: one `Canvas` pass under the orbs: straight segments only ("straight lines", never curves); width lerp(`size.map.edgeMin` 0.5, `edgeMax` 3, strength); colour `map.edge`, strong links (≥ 0.67) `map.edgeStrong`; dark: white 20%. Threads stop at each orb's edge and never cross a label plate (the plate is drawn above). Increase Contrast: one step stronger.
State table: rest · dimmed (with unrelated orbs) · drawing (M12 owns the draw-on) · dark.
Tests: (snapshot) light, dark, increase contrast · (unit) `a thread's width follows its strength`.

---

### C38.4 · You map: touch, states and the VoiceOver list                   size: M
Place in the tree: you › YO-1 › the map › interaction and states
Repo · branch: NPRdoinglaundry · `ui/C38.4-map-interaction`
Needs: C38.2, C38.3, C39.1, C39.2, C39.4, UI5.0      Unblocks: P18

Why: tap anything to see what Retro believes about it; the map reads as a list for anyone who can't see it.

Spec:
- `RYouMap(map: Loadable<YouMap>, newRefs:, onSelect:)`.
- Tap an orb: it scales 1.1× with the 2pt ring, unrelated orbs and threads dim to 0.25, `select` haptic, then `onSelect(ref)` (P18 raises YO-4). Dismissing YO-4 restores the map on `spring.map`.
- Hit areas: 44 around every orb (small orbs pad the frame); overlapping hit areas resolve to the nearest centre.
- States: loading → you + rings, skeleton dots appearing ring by ring (stagger 60ms, after 400ms only; C39.1 rule); empty → you alone, "just you, so far." / "this fills in as you talk to me." (Paper copy, C39.2's empty style); error/offline → the cached map + "couldn't update · showing what's saved" (C39.4; the spec's "showing last week's" is wrong when the cache is from today); waiting → that orb's quiet glow.
- **VoiceOver:** the canvas is hidden; a list sorted by kind then weight: "priya, person, closely linked to: sunday planning, run the half in march", "late meetings push the run, theme, a guess" …, each an element that opens YO-4; plus "one question waiting about sam" when waiting.
- Dynamic Type at AX3: labels grow and fewer are shown (largest orbs only).

Interaction table:

| Touch | Press | Haptic | Motion | Outcome | Reduce Motion |
|---|---|---|---|---|---|
| orb | 1.1× + ring; others dim | `select` | `spring.map` | YO-4 rises over the map | no scale; ring and dim only, 140 fade |
| drag the map | (none) | none | `spring.map` with velocity, rubber-banded within the bleed | pans a little; springs back | no pan |
| dismiss YO-4 | — | none | `spring.map` back | map restored | 140 fade |

Acceptance: every state matches Paper (`1G6Z-0`, YO-1's day one in the handoff) in light, dark and AX3; VoiceOver reaches every node.
Tests: (snapshot) full, dense (24), dayOne, loading, offline, selected, dark, ax3 · (UI) tapping an orb opens its node (identifier `map.node.<kind>.<id>`) · (accessibility) the audit passes with VoiceOver's list · (unit) `the nearest orb wins an overlapping tap`.
Proof: standard; a recording of select and dismiss.
Watch out: never put names in accessibility identifiers (ids only).

---

### C38.5 · You map: life and the map opening                               size: M
Place in the tree: you › YO-1 › the map › motion
Repo · branch: NPRdoinglaundry · `ui/C38.5-map-life`
Needs: C38.4      Unblocks: P18 (recorded pass)

Spec:
- Life (motion-system §7, design-reference B6): orbs breathe ±2pt drift, periods 6–9 s, staggered by slot; one life per screen (the map is YO-1's one); paused when YO-4 is up, when the app is inactive, and under Reduce Motion; `TimelineView(.animation)` at 30 fps budget, no per-orb timers.
- Map open (motion-moments): the you-orb lands first, then rings, then orbs float in on their orbits staggered 60ms on `spring.map`; threads draw after their two ends land. Runs on the first appearance per launch only; tab re-entry shows the map at rest.
Tests: (motion, layer 10) the hitch ratio stays within baseline over 10 s of life on 17 Pro · (unit) `life stops under Reduce Motion and while a sheet is up`.
Proof: recordings of the open and of 10 s of life; Instruments trace.

---

### M12 · A new thing blooms into the map                                   size: M
Place in the tree: you › YO-1 › the map › signature moment M12
Repo · branch: NPRdoinglaundry · `ui/M12-map-bloom`
Needs: C38.5, UI5.0's `newNode` scenario (live: PL3.6b's `newNodeRefs`)      Unblocks: P18's recorded pass, G5

Why: when Retro learns something new about your life, you see it arrive.

Inputs: design-reference B5 row M12 ("a satellite blooms into the map with a soft glow; the line to 'you' draws itself; scale 0 → 1 on `pop`, halo fades; line 420ms `curve.standard`; `spring.map`, `duration.reveal`; `reveal` haptic"); Paper `1G6Z-0`.

Spec: after the map settles, each new ref (≤ 3 at once; more bloom without the haptic) scales 0 → 1 on `RMotion.pop` with a halo that fades over `duration.reveal`; its line to you draws from you outward over 420ms `curve.standard`; one `reveal` haptic for the first. Then `markMapSeen()`. Reduce Motion: a 140 fade-in, no haptic. VoiceOver: announces "new on your map: <label>" once.
Tests: (UI) the new node blooms once and not on the next visit · (snapshot) the frame at halfway, light/dark.
Proof: a recording next to the motion system's M12 description; the integrator's recorded pass.

---

### C32-n · Evidence row, numbered (search sources) and matched words       size: S
Place in the tree: you › YO-2 › sources › numbered row
Repo · branch: NPRdoinglaundry · `ui/C32-n-numbered-row`
Needs: C32      Unblocks: UI6.1b, P19.1

Why: each source under the answer carries the number its citation uses, and your search words stand out in it.

Inputs: Paper YO-2 `c:source-result/rest` `1G9P-0`, chevron `1G9Q-0`, part 50 master `K14-0`; design-reference §C32 variants; build notes "Search and type" (matched words `accent.text`, medium, one `AttributedString` run per match; blue job 4).

Spec: C32's `leading: .number(Int)` case: a 32 well with a mono figure (text-xs, tabular) instead of the glyph; the label line "date · via" (Geist 12 `text.label`); the snippet one line with `matches` rendered as `accent.text` medium runs (ranges converted safely; past-the-end ranges dropped). A `highlighted: Bool` state for UI6.1b (a `surface.washPressed` wash fading out over 1.2 s).
State table: rest · pressed · highlighted · no matches · dark · AX3 (two lines, C32's rule).
Accessibility: "source 2, 20 october, calendar, board prep until 8, button".
Tests: (snapshot) rest, with matches, highlighted, dark, ax3 · (unit) `a match past the end of the snippet is dropped`.

---

### UI6.1a · Search answer card: shell and states                           size: M
Place in the tree: you › YO-2 › answer › card
Repo · branch: NPRdoinglaundry · `ui/UI6.1a-answer-card`
Needs: T01, C39.1, C39.4, UI5.0      Unblocks: UI6.1b, UI6.1c, P19.1

Why: what Retro found sits on top in plain words; when there's nothing, it says so plainly.

Inputs: Paper YO-2 `c:answer/found` `1G9Y-0`, part 50 master `K0U-0`, board `JZQ-0`; handoff part 50 ("'what i found' label, facts inky xl, guess sentence starts 'a guess:' in body/secondary"; states found, nothing found "abstains, then 'the closest: …'"); craft §7.2 (text arrives with blur).

Spec:
- `RAnswerCard(state:)`: a raised card (card tier, `radius.card`, padding from `1G9Y-0`); the label "what i found" (Geist label); sentences as one flowing paragraph in the inky face at `text.xl` (certain) with guess sentences handled by UI6.1c.
- States:
  - `writing`: the label + three skeleton lines in the paragraph's shape (C39.1, only after 400ms); after 8 s "still working" under them (C39.4).
  - `found`: sentences arrive with a 4pt blur → 0 over 240ms, staggered 60ms per sentence (craft §7.2).
  - `nothingFound`: no card; one serif line on the page: "nothing in your bank speaks to this yet." (copy from the agent's fixed text, lowercased; founder to confirm).
  - `notAnswered` / `ownWordsOnly`: the card holds one plain line ("nothing here really answers that." / the brain's `why`), then a label "the closest:" above the sources (P19.1 places the sources).
  - `couldNotWrite`: "i couldn't write this one; the sources are below."
  - `failed`, `offline`, `spendLimited`: C39.3 / C39.4 with the contract 00 message and "try again" (none for spend).
State table: as above × light, dark, AX3 (paragraph grows; card never clips).
Accessibility: the card reads as one element "what i found: <sentences>"; announced once when it arrives.
Tests: (snapshot) writing, slow, found, nothingFound, closest, couldNotWrite, spendLimited, dark, ax3 · (unit) `an abstained result never shows sentences`.
Watch out: never show a sentence the server didn't send; no "summary" fallback text in the view.

---

### UI6.1b · Citation chips                                                 size: M
Place in the tree: you › YO-2 › answer › citation chips
Repo · branch: NPRdoinglaundry · `ui/UI6.1b-citation-chips`
Needs: UI6.1a, C32-n      Unblocks: P19.2

Why: every sentence shows which source it rests on; tap the number and you're looking at it.

Inputs: build notes "Search answer citations" ("an `AttributedString` run, a small mono number (text-xs) on a `surface.wash` capsule (18 high), baseline-raised 2pt. Tapping it scrolls to and briefly highlights the matching source row"); Paper draws ¹ ² ³ because it flattens runs.

Spec:
- Each sentence ends with its `cites` as chips: a mono text-xs figure on a `surface.wash` capsule 18 high, baseline +2, 2pt apart. Built so the paragraph keeps wrapping naturally: `Text` concatenation with an inline capsule image per number (rendered once per number and cached), or an `AttributedString` with a custom attribute drawn by a `TextRenderer` (iOS 18+); pick the one that keeps VoiceOver order and Dynamic Type, written in the PR.
- Hit area: each chip gets a 44 tap target via an overlay mapped from the text layout's run bounds (`Text.Layout`); taps between chips fall to the nearer one.
- Tap: `select` haptic off (haptics are few; craft §10); the page scrolls to source n (`ScrollViewReader`, `spring.sheet`) and sets C32-n's `highlighted` for 1.2 s.
State table: rest · pressed (capsule `surface.washPressed`) · AX3 (chips scale with text; never below 11pt) · dark.
Accessibility: each chip is a link "source 2"; the rotor lists them as links; the sentence reads "…, sources 1 and 2".
Tests: (snapshot) a sentence with 1 and 3 chips wrapping across lines, ax3 · (UI) tapping a chip scrolls to and highlights its source.
Watch out: chips are the only taps inside the paragraph; nothing else in the answer is a link.

---

### UI6.1c · Guess sentences and "only what's certain"                     size: S
Place in the tree: you › YO-2 › answer › guess sentences + switch row
Repo · branch: NPRdoinglaundry · `ui/UI6.1c-only-certain`
Needs: UI6.1a, `RSettingsRow` switch, C07 switch (#50)      Unblocks: P19.1

Why: a guess never reads like a fact; you can hide guesses entirely.

Inputs: build notes ("a guess sentence starts with 'a guess:' in the label style and is set in body type (text-secondary), not the inky answer type"); Paper `c:settings-row/switch · only certain` `1G91-0`, `c:switch/default/off` `1G92-0`, part 50 `K1V-0`; handoff ("'only what's certain' row with the switch ('hides the 1 guess')"; "switch sits just above the tabs"); build notes "Switch" (no pending visual; toggles at once).

Spec:
- A `sure == .guess` sentence: "a guess:" (Geist label) + the sentence in body `text-secondary`, after the certain sentences' flow (keeps its citation chips).
- The switch row: `surface.wash`, `radius.panel`; title "only what's certain"; subline "hides the 1 guess" / "hides 2 guesses" (plural rule). The row is hidden when `guessCount == 0` (nothing to hide; restraint, craft §12). Placement per P19.1.
- Toggling hides/shows guess sentences with a 200ms blur-replace, `select` haptic; the choice is `onlyCertain` (remembered).
- When everything is a guess and the switch is on: the card says "nothing certain here; turn this off to see the guess." (copy for the founder).
Tests: (snapshot) guess shown, hidden, all-guess hidden, dark · (UI) the switch hides the guess and stays on after relaunch.

---

### UI6.2 · Claim block (stated and asked) with its sureness line           size: S
Place in the tree: you › YO-4 › claim
Repo · branch: NPRdoinglaundry · `ui/UI6.2-claim`
Needs: UI6.3, T01      Unblocks: P21.1 (and PC-3, GL-2 if not built there)

Why: the one thing Retro believes, large, with how sure it is in words, so you can judge it.

Inputs: Paper YO-4 `c:claim/stated` `1GDS-0`, part 41 masters `G2A-0` (stated), `G3C-0` (asked); handoff YO-4 ("belief inky 2xl; 'fairly sure · from 5 things · moved last week'").

Spec: `RClaim(text:, sureness:, dots:, sourceCount:, movedAt:, isGuess:)`: the claim in the inky display face `text.2xl`, wrapping; a claim is never truncated; the line under it (Geist 12 `text.label`): sureness word + UI6.3 dots · "from 5 things" · "moved last week" (relative, from `movedAt`, today injected). `isGuess`: the asked variant (`G3C-0`): dashed card, a question form ("is this right?" framing per part 41), never the stated look. `claim == nil` (person with no fact): the line "comes up 5 times" only.
State table: stated · asked (guess) · confirmed (the line gains "you said this is still true") · long · AX3 · dark.
Tests: (snapshot) stated, asked, confirmed, no-claim, long, dark, ax3 · (unit) `moved last week reads relative to the injected today`.
Watch out: "guesses never look like facts" (context.md §2): the asked variant must differ in shape, not only colour.

---

### UI6.3 · Sureness: the word and four dots                                size: S
Place in the tree: you › YO-4 / YO-5 › sureness
Repo · branch: NPRdoinglaundry · `ui/UI6.3-sureness`
Needs: T01      Unblocks: UI6.2, UI6.5

Spec: `RSureness(word:, dots:)`: the word (Geist 12) + 4 dots, 6pt, 2 apart, filled `text.secondary`, empty `surface.track` (handoff YO-5); dots centred on the word's x-height (craft §2.4). Increase Contrast: empty dots get a 1pt ring. The dots are decorative for VoiceOver (the word carries it).
Tests: (snapshot) 1–4 dots, each word, dark, increase contrast.

---

### UI6.4 · Link chips (what this connects to)                              size: S
Place in the tree: you › YO-4 › linked chips
Repo · branch: NPRdoinglaundry · `ui/UI6.4-link-chip`
Needs: T01      Unblocks: P21.1

Inputs: Paper `c:chip/link` `1GCV-0`; `design-system/components/chip.md` (32 visual in 44, raised, mono 13 label, optional 20 icon well with a kind glyph).
Spec: `RChip(.link(kind:, label:))` per chip.md (no status dot); a wrapping row (`Layout` flow, 12 apart `space.inline`); tapping replaces the sheet's content with that node (P21.1 owns the transition); long labels ellipsise after 18 characters, full name read aloud.
State table: rest · pressed (0.94) · focused · dark · AX3 (rows wrap).
Tests: (snapshot) rest, pressed, long label, wrapped row, dark, ax3.

---

### UI6.5 · Answer row (what Retro knows)                                   size: S
Place in the tree: you › YO-5 › answer row
Repo · branch: NPRdoinglaundry · `ui/UI6.5-answer-row`
Needs: UI6.3, T01      Unblocks: P22

Inputs: Paper `c:answer-row/rest` `1T0Z-0` (no master on 02: take everything from the instance); handoff YO-5 ("question (label sm) · answer (body) · how sure word + 4 dots · 'from n things' · ›").
Spec: the question (Geist sm `text.label`), the answer (body `text.primary`, wraps, never truncates), a meta line (UI6.3 + "from 3 things"), a trailing chevron; the settings row's press. `isGuess`: the answer in `text-secondary` with "a guess:" before it (the same language as search, UI6.1c). `movedThisWeek`: a small "moved" word in the meta line (Geist 12 `text.label`; no colour, no dot: restraint).
State table: rest · pressed · guess · moved · confirmed · long · dark · AX3.
Accessibility: one element "what have you said you want? to run the half in march. very sure, from 3 things. button".
Tests: (snapshot) each state, dark, ax3.

---

### UI6.6 · "This supports" on the entry page (YO-3 merged into JR-4)      size: S
Place in the tree: you › YO-3 › this supports
Repo · branch: NPRdoinglaundry · `ui/UI6.6-this-supports`
Needs: P12, C32, founder question 4 answered (lean A)      Unblocks: P19.2 (opening an own-words source)

Why: open something you wrote from search and see what it backs up: a belief, a goal.

Inputs: Paper YO-3 `1GAS-0`, its `c:settings-row/nav` `1GB2-0` rows; handoff YO-3 ("**this supports** rows (a belief, a goal)"); contract 02 §6 (`took` gives the claims taken from an entry).
Spec: when JR-4 is opened from search (`origin: .search(query)`), it shows "this supports" (section label) with one C32 row per item from `took(id:)` that is still live (belief → YO-4 kind fact/answer; goal → YO-4 kind goal), above "what i took"'s correction controls; the matched query words are not re-highlighted in the full text (founder rule only covers result lists). Under option B (YO-3 stays its own page), this becomes P20's content instead.
Tests: (snapshot) JR-4 from search with two supports, dark · (UI) a support row opens its node.

---

### UI6.7 · The list view: the portrait                                      size: M
Place in the tree: you › YO-1 list › portrait sections
Repo · branch: NPRdoinglaundry · `ui/UI6.7-portrait-list`
Needs: **a Paper drawing approved by the founder** (founder question 5; nothing is drawn today), UI5.0 (`portrait` sample; live from PL3.6b), C39.2      Unblocks: P18 (the list pill's destination)

Why: the same picture as the map, as words: what you're working toward, what keeps coming up, the people around you, what changed.

Spec (to be finalised against the drawing): a pushed page with the settings bar ("you, in words"? copy from Paper); sections in the portrait's order with inky lines (≤ 6 each), each line a row opening YO-4 through its `ref`; self-talk lines in quotes in your own words; empty sections omitted, and a fully empty portrait shows the map's day-one line. Counts ("and 26 more people") from the map's `counts` as the last row of people.
Tests: (snapshot) full, empty, dark, ax3 · (UI) a line opens its node.
Watch out: do not build before the drawing is approved; the card is filled in full against it.

---

### P18 · YO-1 you                                                          size: M
Place in the tree: you › YO-1
Repo · branch: NPRdoinglaundry · `ui/P18-you`
Needs: C17-y, C12-y, C38.4, C38.5, C18, C39, UI5.0, `RSettingsRow`      Unblocks: P19.1, P21.1, M12's recorded pass, T05c

Why: you, at a glance: a map of your life, a way to ask anything about it, and what Retro knows, one tap away.

Inputs: Paper YO-1 `1G5Y-0` (approved), its instances (top bar `1G7X-0`, field `1G7R-0`, map `1G6Z-0`, rows `1G6S-0` "what i know about you" with subline "every fact and guess, each one you can fix", `1G6M-0` "one question waiting · about sam", tab bar `1G62-0`); hi-fi board `K2D-0`; design-reference §E P18 ("title spacing-2 above, field spacing-4, map scaled 0.82 so both rows sit above the tabs" on SE; "lit: none, the field is the action, raised"); handoff YO-1 day one.

Spec (layout): top bar (C17-y) · search field (C12-y) · the map (C38), bleeding past the margins · the two rows (`RSettingsRow` nav with their 32 glyph wells) · tab bar with the progressive edge. The "one question waiting" row appears only when `map.waiting` exists; its subline is the waiting node's label ("about sam"). No lit object (Paper: none).

Interaction sheet:

| # | Moment | What happens | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|---|
| 1 | arrive (tab) | cached map at once; fresh map replaces it without a jump | map open (C38.5) on first appearance per launch | — | 140 fade |
| 2 | first load > 400ms | skeleton dots (C38.4) | stagger 60 | — | pulse |
| 3 | new things | M12 bloom after the map settles | M12 | `reveal` | fade |
| 4 | tap an orb | YO-4 rises over the map (P21.1) | `spring.map` + `sheet` | `select` | fade |
| 5 | tap the field | YO-2 begins in place (P19.1): the field focuses, the map stays until submit | keyboard | — | same |
| 6 | "what i know about you" | YO-5 pushes | push | — | fade |
| 7 | "one question waiting" | YO-4 opens in its question state (P21.2) | `sheet` | `sheetSnap` | fade |
| 8 | "list" pill | the list view pushes (UI6.7) | push | — | fade |
| 9 | your picture | settings (ST-1) | push | — | fade |
| 10 | pull to refresh | refetches the map | C39 refresh | `refresh` past threshold | no stretch |
| 11 | re-tap the you tab | scroll to top; closes YO-4 if up | `gentle` | — | jump |
| 12 | offline | cached map + offline line (C39.4) | `.rBlurReplace` | — | same |

State table (T02 `-State`): `full` (as `1G5Y-0`), `dayOne`, `waiting`, `noWaiting`, `newNode`, `loading`, `offline`, `error`, `dense`, SE (map 0.82, both rows above the tabs).

Accessibility: rotor order title → list → settings → search → map list (C38.4) → rows → tab bar; `performAccessibilityAudit()` passes in full, dayOne, offline.

Acceptance: every state matches Paper in light, dark, AX3 and SE; every row of the interaction sheet is built and recorded; no lit object.
Tests: (snapshot) full, dayOne, waiting, loading, offline; light, dark, ax3, SE · (UI) tapping an orb opens its node · (UI) the waiting row opens the question · (UI) the field opens search in place · (accessibility) audit in full, dayOne, offline · (motion) map open and life within hitch baseline.
Proof: page proof plus recordings of rows 1, 3, 4, 7.
Watch out: SE: the map scales, never clips; the rows must stay above the tabs (layout by container height).

---

### P19.1 · YO-2 search: in place, the answer and its sources                size: M
Place in the tree: you › YO-2 › layout and states
Repo · branch: NPRdoinglaundry · `ui/P19.1-search`
Needs: P18, C12-y, UI6.1a, UI6.1c, C32-n, C39      Unblocks: P19.2, T05c

Why: ask anything about your life and read what Retro found, with every source underneath.

Inputs: Paper YO-2 `1G8E-0` "found" (approved) and its instances; part 50 `JZQ-0`; handoff ("**in place** in the You tab: the map gives way to the answer; clearing the field brings it back"; "16 gaps; switch sits just above the tabs"); design-reference §E P19; finding 55 (match YO-1's bar and mic).

Spec (layout): same top bar and field as YO-1 (typed, clear ×); below, one scroll: the answer card (UI6.1a/c) · the sources (C32-n rows, numbered; under "the closest:" when abstained) · the "only what's certain" row pinned just above the tab bar (when there are guesses), content fading under it (progressive blur, screen rule 17). 16 between groups (Paper), 24 margins.
- Submitting: the map cross-fades out (blur-replace 200ms) and the answer card's `writing` state takes its place; the sources appear with the answer (one response).
- Clearing the field (×) or emptying it: the result fades and the map returns (at rest, no open choreography).
- The result survives going to YO-4/JR-4 and back.

Interaction sheet:

| # | Moment | What happens | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|---|
| 1 | submit | map → writing card | blur-replace 200 | — | 140 fade |
| 2 | > 8 s | "still working" | `.rBlurReplace` | — | same |
| 3 | answer arrives | sentences blur in, sources stagger 40ms | craft §7.2 | none | fade |
| 4 | nothing found | the one line, no card, no switch | blur-in | — | fade |
| 5 | toggle only certain | guess hides/shows | 200 blur-replace | `select` | fade |
| 6 | clear × | back to the map | 200 | — | fade |
| 7 | new submit while searching | the old one cancels; writing restarts | — | — | — |
| 8 | spend limited / offline / failed | C39 states with their copy; "try again" re-sends the same search | — | `error` on failure | same |

State table (`-State`): `idle` (= YO-1), `searching`, `slow`, `found` (as `1G8E-0`), `foundCertainOnly` (no switch row), `onlyCertainOn`, `nothingFound`, `closest`, `couldNotWrite`, `offline`, `spendLimited`, `failed`, `long` (5 sentences, 15 sources), SE.

Accessibility: the answer is announced once when it arrives; rotor: field → answer → chips (links) → sources → switch; audit passes in found, nothingFound, offline.

Acceptance: every state matches Paper in light, dark, AX3, SE; the result is never shown before the response; nothing found never shows a card.
Tests: (snapshot) every state above, light/dark/ax3, SE (found) · (UI) searching then a found result shows sentences and numbered sources · (UI) clearing returns the map · (UI) only certain hides the guess · (UI) offline says search needs a connection · (accessibility) audit.
Proof: page proof plus recordings of rows 1, 3, 5, 6.

---

### P19.2 · YO-2 search: citations, and opening a source                    size: S
Place in the tree: you › YO-2 › citations and opening
Repo · branch: NPRdoinglaundry · `ui/P19.2-search-open`
Needs: P19.1, UI6.1b, P20, P21.1, P12 (+ UI6.6 under lean A)      Unblocks: T05c

Spec: wires UI6.1b's chip taps to the page's scroll; a source row opens: own words → JR-4 pushed (with "this supports", UI6.6); record or saved → YO-3 (P20) pushed; fact or answer → YO-4 sheet (P21.1) over the result. Back returns to the same scroll position.
Tests: (UI) a chip scrolls to its source and highlights it · (UI) each source kind opens its page · (UI) back restores the scroll position.
Proof: recordings of a chip tap and of each open.

---

### P20 · YO-3 a source (records and saved links)                          size: S
Place in the tree: you › YO-3
Repo · branch: NPRdoinglaundry · `ui/P20-a-source`
Needs: C17 entry variant, UI5.0 (live data: PL3.6e's `source(_:)`), founder question 4 (lean A)      Unblocks: P19.2

Why: open a calendar event, an email or a saved link that search used, and see exactly what it says.

Inputs: Paper YO-3 `1GAS-0` ("a journal entry"): top bar `1GBJ-0` (back only; no edit for things you didn't write), words `1GBI-0`, meta line "tue 14 oct · 7:40 · written · read", link `1GBA-0`, rows `1GB2-0`; handoff YO-3.
Spec (under lean A, YO-3 shows only what isn't your own words): the entry frame; the body in the inky face if it's a record's text (`text.primary` sans if Paper's record look differs: confirm with the integrator, as Paper only draws a journal entry); the meta line "date · via"; for a saved link: title inky, "why you saved it: <yourReason>" in your words, the url as a `text.link` opening Safari (`SFSafariViewController`, never fetched by the app); no "show it in the conversation" (records were never in it); no edit, no delete (deleting a source is ST-4's job).
State table: record · saved · saved without a reason · loading (C39.1) · gone (`not_found`: "this isn't here any more.") · offline (cached if opened before, else C39.4) · long · dark · AX3.
Tests: (snapshot) record, saved, gone, dark, ax3 · (UI) the link opens outside the app.
Watch out: a record's body may be long mail text: never truncate, never render HTML (plain text only).

---

### P21.1 · YO-4 a node: person, theme, goal, belief                         size: M
Place in the tree: you › YO-4 › node sheet
Repo · branch: NPRdoinglaundry · `ui/P21.1-node`
Needs: C19.1, UI6.2, UI6.4, C32, `RPill` (#45), UI5.0, P18 (live data arrives with PL3.6c and the wiring PR)      Unblocks: P21.2, P19.2, T05c

Why: one thing Retro believes about your life, how sure it is, every piece of your own record behind it, and a way to say it's right or wrong.

Inputs: Paper YO-4 `1GC2-0` "a person" (approved): sheet `c:player-sheet/brief/playing` `1GCD-0` (the sheet frame), dismiss `1GDY-0`, claim `1GDS-0`, evidence `1GDI-0` (+ glyphs `1GDP-0`, `1GD7-0`), chip `1GCV-0`, "still true" `1GCK-0` + check `1GCM-0`, "not right" `1GCG-0` + correct glyph `1GCI-0`; hi-fi `KWP-0`; handoff ("sheet over the map, PC-3's parts; header 'person · priya' + dismiss chevron; … sheet flexes like PC-3"); build notes "Why sheet: raised cards inside the scroll" (`.scrollClipDisabled()`), "Sheets: spacing by group".

Spec:
- C19.1 sheet over the map (the map stays visible behind, scaled and dimmed); header "<kindLabel> · <name>" (Geist) + dismiss chevron (34 visual in 44).
- Content: UI6.2 claim · "what it rests on" C32 rows (≤ 20, "see all 12" when `evidenceTotal` > shown, loading the rest in place) · linked chips (UI6.4) · the action pair at the bottom: "still true" (`RPill` neutral with check) and "not right" (`RPill` neutral with the correct glyph). Neither is lit (Paper: no lit object).
- "still true": optimistic; the pill becomes "still true ✓" (`1GCK-0`'s look), `confirm` haptic, the claim's line gains "you said this is still true"; queued offline shows the same with "will send when you're back" in the line. Hidden when `canConfirm` is false.
- "not right": opens the journal's correction flow (UI1.2's states, contract 02 §6) inside the sheet with `about = claim.ref`; after `.applied`, the claim shows "noted" (struck through per contract 02 decision 2) and the map refreshes behind.
- A chip tap replaces the sheet's content with that node (cross-fade 200 + slide 8pt; back chevron appears in the header to return; one level of history only).
- Evidence row tap: own words → JR-4 (the sheet stays under it); records → P20.
- Sheet height flexes with content (medium detent, full when content needs it; PC-3's behaviour).

Interaction sheet:

| # | Moment | What happens | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|---|
| 1 | open from an orb | sheet rises; map scales 0.94 and dims | `sheet` | `sheetSnap` | fade |
| 2 | drag down / chevron | sheet closes; map restores | `sheetDismiss` with velocity | — | fade |
| 3 | still true | pill confirms; line updates | 200 blur-replace | `confirm` | fade |
| 4 | not right | correction flow in the sheet | `sheet` content swap | per UI1.2 | fade |
| 5 | chip | the sheet shows that node | 200 cross-fade + 8pt | `select` | fade |
| 6 | evidence row | the source opens | push | — | fade |
| 7 | node gone | "this isn't here any more."; dismiss closes | blur-in | — | same |

State table (`-State`): `person` (as `1GC2-0`), `personNoFact`, `theme`, `goal`, `belief`, `beliefGuess` (asked claim), `confirmed`, `queuedOffline`, `noted`, `gone`, `loading`, `long`, dark, AX3, SE.
Accessibility: the sheet is a modal with "close" escape; rotor: header → claim → evidence → chips → actions; audit passes in person, theme, beliefGuess.
Acceptance: matches `1GC2-0` and the claim/evidence/chip masters in light, dark, AX3, SE; no "still true" on themes and goals.
Tests: (snapshot) every state, light/dark/ax3, SE (person) · (UI) still true confirms once and survives relaunch offline-then-online · (UI) not right on a belief reaches the confirm step · (UI) a chip swaps to that node and back returns · (accessibility) audit.
Proof: page proof; recordings of rows 1, 3, 5.
Watch out: never stack a second sheet (C19 rule): the correction flow and chip navigation happen inside this one.

---

### P21.2 · YO-4 the question state ("is this the same sam?")              size: S
Place in the tree: you › YO-4 › question
Repo · branch: NPRdoinglaundry · `ui/P21.2-node-question`
Needs: P21.1, C28 (guess card, dashed asked variant)      Unblocks: T05c, EX-3's deep link (PL3.6f)

Why: where "one question waiting" lands: one honest question, two answers, and it never asks twice.

Inputs: handoff YO-4 ("a guess ('is this the same sam as sam okafor in your contacts?' yes, same · not quite); this is where 'one question waiting' lands; deep link from EX-3"); design-reference §C28 variant "asked" on PC-3/YO-4.
Spec: when the node has a `question` (or the sheet is opened from the waiting row), C28's dashed asked card sits above the claim: the app-built sentence (contract 05 §5), answers "yes, same" · "not quite" (`RPill`s). "yes, same" → `answer(.same)`, the card folds away, "linked." blur-replaces in its place for 1.2 s, the map behind merges the two orbs on return; "not quite" → `.different`, "kept apart." Optimistic; offline queued. When the waiting item is a contract 02 guess instead, C28 shows that guess with its yes/no (contract 02 §4).
Tests: (snapshot) question, linked, kept apart, guess variant, dark · (UI) answering removes the question and the waiting row on YO-1.
Watch out: "same" merges people in the brain and is hard to undo: the buttons are equal weight, never lit, and the sentence names both people in full.

---

### P22 · YO-5 what i know about you                                        size: M
Place in the tree: you › YO-5
Repo · branch: NPRdoinglaundry · `ui/P22-what-i-know`
Needs: C17 settings variant, UI6.5, C39, UI5.0 (live data arrives with PL3.6d)      Unblocks: T05c

Why: everything Retro has concluded about you, area by area, how sure it is, and every answer one tap from being fixed.

Inputs: Paper YO-5 `1SZX-0` (approved): top bar `1T1K-0` (back `1T1O-0`), answer row `1T0Z-0`; hi-fi `LBO-0`; handoff YO-5 ("pushed frame (back only); title inky 3xl; 'moved this week · 2 answers changed' wash row; areas as inky xl sections; silent area = one warm sentence; thin day one: most areas silent; SE: 20 margins, 24 between areas"); design-reference §E P22 ("settings top bar (small centred title, content top padding spacing-4)"); note the two disagree on the title (handoff: inky 3xl title; reference: small centred title): **Paper `1SZX-0` decides**, checked at build.

Spec: the settings bar · the "moved this week · 2 answers changed" wash row (only when `answersChanged` > 0; not tappable, founder question 12) · eight areas in order, each an inky xl section title (app copy per area id) followed by UI6.5 rows, or the area's one warm sentence when silent (app copy per area, founder to approve) · 24 between areas.
Row tap → YO-4 for that answer (kind `answer`), as a sheet over this page.

Interaction sheet: arrive (cached at once, then fresh) · row → YO-4 sheet (`sheet`, `sheetSnap`) · back · pull to refresh · offline line · after a verdict or correction in YO-4 the row updates in place (blur-replace).
State table (`-State`): `full`, `dayOne` (all silent but one), `allSilent`, `moved`, `loading`, `offline`, `error`, `long`, dark, AX3, SE.
Accessibility: each area is a heading; rows as UI6.5; audit passes in full and dayOne.
Tests: (snapshot) every state, light/dark/ax3, SE · (UI) a row opens its answer and "still true" updates the row · (accessibility) audit.
Proof: page proof.
Watch out: never show the brain's third-person labels ("Who they are") or question text; only `question` (second person) and the app's area titles.

---

### T05c · The You flow test                                                size: M
Place in the tree: you › flow test
Repo · branch: NPRdoinglaundry · `ui/T05c-you-flow` (with the integrator)
Needs: P18, P19.1, P19.2, P20, P21.1, P21.2, P22, UI6.6 (lean A), PL3.6f      Unblocks: ship gate G5

Why: one test proves the whole of You works end to end: the map, search with its sources, a node and its verdicts, what Retro knows, and a question from a notification.

Spec (XCUITest on sample data, `-Data sample`; then again on local staging, layer 9, the integrator's):
1. Launch to YO-1 (`full`); the map shows; VoiceOver list has the nodes.
2. Tap an orb → YO-4 person; "still true" → confirmed; dismiss → map restored.
3. Tap a theme → no "still true"; a chip → the linked goal; back.
4. Tap the field, type "when did i stop running", return → writing → found: 3 sentences, 1 "a guess:", 4 sources; tap chip 2 → source 2 highlighted.
5. Turn on "only what's certain" → the guess hides; relaunch → still on.
6. Open source 1 (own words) → JR-4 with "this supports"; back → same scroll; open source 2 (calendar) → YO-3; back; clear → map.
7. Search "lisbon" → "nothing in your bank speaks to this yet."; no card, no switch.
8. Go offline (sample `isOnline` false) → search says it needs a connection; "still true" on a belief waits; back online → sends once (the sample's send counter is 1).
9. "what i know about you" → YO-5; tap a guess answer → YO-4 asked claim; "not right" reaches the confirm step.
10. Open `retrospect://you/question/<id>` → YO-4 question; "yes, same" → linked; YO-1's waiting row is gone.
Acceptance: passes three runs in a row on the integrator's simulator; on local staging with the seeded you-test account (BE0.S/T08), each step's server effect is checked by counts (verdict rows, resolution status), never by reading content.
Tests: the flow above as one test with named steps; plus `each You page passes the accessibility audit` (sweep).
Proof: the test log, a recording of the full run, the staging run's counts.
Watch out: search on staging costs real model money: the staging run uses at most 3 searches and records them as test spend (cost-per-user.md keeps test spend separate).
