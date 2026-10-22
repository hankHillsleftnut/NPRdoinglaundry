# Outside the app · view cards

Contract: [07-outside.md](../../contracts/07-outside.md). Read `design-system/principles/` (especially `screen-rules.md` and `motion-system.md`) and `design-system/components/craft.md` before any card here. Values come from tokens only: `radius.widget` 22, `layout.widget.padding` 16, `motion.spring.*`, `motion.duration.*`, `haptic.*`.

**Paper:** the EX-1, EX-2, EX-3 and EX-4 values below were read from the light file (`get_jsx` on `1H1O-0`, `1H2N-0`, `1H4D-0`; `get_tree_summary` on `1H1M-0`, `1H2J-0`, `1H3E-0`) on 21 Oct. Where Paper disagrees with the reference docs, Paper wins, and each difference is listed under "Paper vs the references" in its card. The moment cards' nodes weren't read (they belong to other areas' pages), so each moment PR re-reads its nodes first. The dark twins (dark file, page 05d, group `2KTI-0`) weren't read; each page PR checks them.

**The tree on this side:**
- **EX-1 share:** P34 › the item card C41 (C41.1 face, C41.2 read and goes-with) · the compact composer C42
- **EX-2 lock screen:** P35 › the Now Playing artwork C40.4
- **EX-3 notifications:** P36 (copy and landings)
- **EX-4 widgets:** P37 › widget views C40 (C40.1 small, C40.2 medium, C40.3 states)
- **signature moments:** M01–M13, each attached to its page in another area
- **retiring the old:** the force-update page X02b · experiments X03a–d · old design system X04 · old screens per ship gate X10a–g
- **proof:** T05d

**Order:**
1. C40.1 → C40.2 → C40.3 → P37
2. C40.4 → P35
3. C41.1 → C41.2 → C42 → P34
4. P36
5. T05d

The moments follow their pages. The X cards follow their gates.

---

## EX-4 widgets

### C40 · Widget and lock-screen views                       4 bytes: C40.1 S, C40.2 M, C40.3 S, C40.4 S
Place in the tree: outside › EX-4 widgets › widget views (C40.4 sits under EX-2)
Repo · branches: NPRdoinglaundry · `ui/C40.1-widget-small`, `ui/C40.2-widget-medium`, `ui/C40.3-widget-states`, `ui/C40.4-now-playing-artwork`
Needs: T01, S10 (the mark at 16), #42 `RArtwork`, #45 `RPill`, PL7.2 (snapshot types), INT7.1 (widget target 18.1)      Unblocks: P37, P35

Why: Retro is on your home screen as a quiet way to talk and a way to play today's brief, legible in every home-screen style, and private when the phone is locked.

Inputs:
- Spec:
  - `design-system/components/lock-screen-and-widget.md` (older)
  - reference §C40 and §F item 32: **the newest handoff wins**, so the small widget is the talk widget
  - build note "make this phone sized" (system size: 170 on a 390 phone)
- Paper:
  - EX-4 `1H4D-0`, with `c:widget/164x164` `1H55-0`, `c:widget/344x164` `1H4L-0`, `c:the-mark/16` `1H59-0`, `c:the-mark/glyph` `1H5A-0`, `c:pill/neutral · play` `1H4P-0`, `c:pill/neutral · talk` `1H4N-0`
  - dark twin on dark file page 05d (`2KTI-0` group)
  - EX-2 `1H2J-0` for C40.4
- Contract 07 §3 (`WidgetSnapshot`, actions, privacy).

Spec (values read from `1H55-0` and `1H4L-0`):
- **Both:**
  - `containerBackground(for: .widget) { RColor.backgroundRaised }` (Paper: `background.raised`, not canvas; dynamic, so it follows dark)
  - padding `spacing.4` (16, which is `layout.widget.padding`); the system clips to `radius.widget` 22
  - Paper's 0.5 outer stroke and `0 8 24 −8` cast shadow are the home screen's; the system draws widget depth, so don't reproduce them
  - Paper draws the small at 164×164 and the medium at 344×164. Ship at the system sizes (170 on a 390pt phone, build note) and lay out with flexible space, never fixed sizes
- **The mark at 16:**
  - disc `surface.secondaryAction`, ring 1pt `border.secondaryRing` plus contact shadow `0 1 1`
  - glyph 9×7 in `icon.mark`
  - S10's 16 size: use `RMark(size: .s16)`, never a local copy
- **C40.1 `RWidgetTalk` (small), a vertical stack:**
  - the mark at top-leading, then flexible space
  - "tell me…" in `font.display.inky`, `text.lg`, weight `ink.card`, `leading.tight`, `text.primary`
  - "talk to retro" in Geist (`font.label`), `text.sm`, `leading.snug`, `text.label`
  - **no pill**: Paper draws a plain label and the whole widget is the tap target (`widgetURL(retrospect://compose)`)
  - no personal content, so no privacy marking
- **C40.2 `RWidgetBrief` (medium), a vertical stack:**
  - **top row** (gap `spacing.2`): the mark at 16, then "today's brief · 4 min" in **mono** (`font.mono`), `text.xs`, `leading.snug`, `text.label`. Paper sets the whole line in mono; screen rule 4 would allow mono only on "4 min". Paper wins (it's the newest approved drawing), and this is listed below
  - **headline** (padding-top `spacing.2`): `font.display.inky`, `text.lg`, `ink.card`, `leading.tight`, `text.primary`, balanced wrap, three lines at most, `.privacySensitive()` when `lockScreenDetail == false`
  - flexible space
  - **bottom row** (gap `spacing.2`) with two pills, each 32 high:
    - `surface.wash`, `radius.control`, padding-inline `spacing.3`, gap `spacing.1`
    - label Geist `text.md` medium `text.primary`
    - "▶ play" (`Button(intent: PlayBriefIntent(briefId:))`): Paper writes the triangle as a text glyph, so build it as the `play` symbol from the icon set at the label's cap height, swapping to `pause` while `playing`
    - "talk" (`Link` to `retrospect://compose`), with no icon
  - `widgetURL(retrospect://brief)`
- **Paper vs the references:**
  1. the background is `background.raised`, not canvas
  2. the small widget's "talk to retro" is a label, not a pill
  3. the medium label is all mono (the reference said "Geist except figures")
  4. the talk pill has no mic glyph
- **C40.3 states** (the medium widget, from `brief.state`), each a separate `#Preview` and snapshot:

| state | look |
|---|---|
| ready | as Paper |
| playing | play → pause, "today's brief · playing" (mono, like the label it replaces) |
| played | headline `text.secondary`, "played" |
| quiet | "a quiet day" in the display face, then `quietLine` in `text.secondary`; no play |
| making | "today's brief · being made" (mono), no headline, no play; the talk pill stays |
| off (first day) | "turn on your daily brief in retrospect" (display face), the body opens `retrospect://settings/brief` |
| off (afterwards) | the episode: "this week's episode · 11 min" and its title (privacy-sensitive), with play opening PC-2 |
| unavailable / unknown / signed out | "open retrospect to load today's brief" (signed out: "open retrospect"), no pills except talk when signed in |

- **Rendering modes:**
  - `.accented` (tinted): the mark and the text use `.widgetAccentable()` on the headline group only, and pills render as outlines
  - `.vibrant` (lock screen and StandBy): monochrome-safe, with no reliance on the warm wash
  - every mode is checked in the snapshots
- **C40.4 `NowPlayingArtwork.render(seed:size:) -> UIImage`:**
  - the brief mesh as drawn on `1H35-0`: base `sky.500`, a radial `amber.300` from (85%, 10%) fading out by 55%, and a radial `sky.800` from (0%, 100%) fading out by 80%
  - grain as `RArtwork`, rendered offscreen at 600×600 with `ImageRenderer`
  - the same in light and dark (system chrome doesn't change, handoff), cached by the caller
  - no text and no mark
  - the system rounds it (Paper shows `radius.default` at 48pt, which is the system's look)

**Paper vs EX-2 (`1H2N-0`):** the drawn title is "the fundraise article you sent". That's a brief part's words on the lock screen, which is exactly what founder question 1 asks about. The subtitle is "retrospect · tuesday's brief · part 2 of 3" and the times are mono. Everything else (the 4pt scrubber, 28/36/28 controls, spacing 12) is system chrome and isn't built by us.

State table (snapshots, every row in `.fullColor`, `.accented` and `.vibrant` where the family supports it, light and dark, at the default and AX3 sizes): the C40.3 table plus the small widget's single state.

Interaction table (the system draws the press):

| Touch | Haptic | Motion | Outcome | Reduce Motion |
|---|---|---|---|---|
| play pill | system | `.contentTransition(.symbolEffect(.replace))` on the glyph | plays in place (intent) | the system's |
| talk pill (medium) / anywhere on the small widget | system | system launch | JR-1, composer focused | — |
| medium body | system | system launch | JR-2 | — |

Accessibility:
- the medium widget reads "today's brief, <headline>, 4 minutes"; with detail off and the phone locked it reads "today's brief, 4 minutes", the play reads "play today's brief", and talk reads "talk to retro"
- the small widget reads "talk to retro"
- AX3: the headline drops to two lines (reference §C40); the system scales the rest
- contrast is checked in all three modes (Increase Contrast keeps `text.primary` on the played headline)

Acceptance:
- Each state matches `1H55-0` / `1H4L-0` (or the C40.3 table where Paper draws nothing) in light, dark, tinted and clear.
- The headline is redacted on the locked lock screen and StandBy when detail is off, and visible when on.
- The artwork renders at 600×600 in under 50 ms on the integrator's simulator.

Tests (layer 6, `swift-snapshot-testing` with `WidgetPreviewContext` hosting):
- `(snapshot) the talk widget in light, dark, tinted and clear`
- `(snapshot) the brief widget in every C40.3 state, light and dark`
- `(snapshot) the brief widget tinted and clear in ready and playing`
- `(snapshot) the brief widget at ax3`
- `(unit) privacy-sensitive is applied exactly when detail is off`
- `(unit) the artwork renderer gives the same image for the same seed`

Proof in the PR: each widget next to `1H55-0` / `1H4L-0`, in a home-screen context (build note), plus the tinted and clear modes.

Watch out:
- Widgets can't animate beyond `contentTransition`, so no custom springs here.
- Fonts: the widget target needs the Exposure font files registered (`UIAppFonts` in the widget's `Info.plist`, an INT7.1 line), or the headline falls back to the system serif silently. A snapshot test catches it.

---

### P37 · EX-4 widgets                                                       size: M
Place in the tree: outside › EX-4 widgets
Repo · branch: NPRdoinglaundry · `ui/P37-widgets`
Needs: C40.1–C40.3, PL7.8b      Unblocks: T05d

Why: today's brief and a way to talk to Retro, at a glance on your home screen.

Inputs: EX-4 `1H4D-0`; contract 07 §3; PL7.8b (provider, intents).

Spec:
- Wire `RetroTalkWidget` and `RetroBriefWidget` to C40's views in `RetrospectWidgetsBundle`:
  - `configurationDisplayName` "talk to retro" / "today's brief"
  - descriptions "a quick way to tell retro something." / "play today's brief from your home screen."
  - `supportedFamilies` `[.systemSmall]` / `[.systemMedium]`
  - `contentMarginsDisabled()` with our own 16 padding
- The template widget in `RetrospectWidgets.swift` is removed in X10g, not here, so the founder's current home screen keeps working until G7.
- The widget gallery preview uses invented content ("a test day with two meetings and a long walk").

State table: as C40.3, now driven by real snapshots (T02-style: a debug launch option `-WidgetSnapshot <fixture name>` writes that fixture into the app group, for proof and UI tests).

Interaction sheet:

| # | Moment | What happens | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|---|
| 1 | add from the gallery | the preview shows invented content | system | system | system |
| 2 | tap play (medium) | the brief plays without opening the app; the pill shows pause within a second | glyph replace | system | same |
| 3 | tap talk | JR-1 opens with the composer focused | system | — | — |
| 4 | brief becomes ready (app closed) | the widget changes within the system's budget after the silent push or the next refresh | system | — | — |
| 5 | phone locked, detail off | the headline is redacted in StandBy and on the lock screen | — | — | — |

Life allowed: none (widgets are still).

Accessibility: as C40; the rotor order is mark → label → headline → play → talk.

Acceptance:
- Both widgets install on iOS 18.1 and 26.
- Every state is reachable from fixtures.
- Play from the widget plays the brief without opening the app.
- Talk lands in the composer.

Tests:
- `(UI) adding the brief widget from a fixture shows the ready state` (springboard UI test)
- `(UI) tapping talk opens the journal with the composer focused`
- `(accessibility) the widget's elements are labelled`
- snapshots are C40's

Proof in the PR: device screenshots (founder's phone, layer 11) of both widgets on a real home screen in light, dark, tinted and clear; a recording of widget play.

Watch out: a widget extension's memory limit is about 30 MB, so never load the mesh artwork at full size in the widget. C40.2 has no artwork, as drawn.

---

## EX-2 lock screen

### P35 · EX-2 lock screen, Now Playing                                      size: S
Place in the tree: outside › EX-2 lock screen
Repo · branch: NPRdoinglaundry · `ui/P35-lock-screen`
Needs: C40.4, PL7.6      Unblocks: T05d

Why: you can see what's playing and control your brief without unlocking.

Inputs: EX-2 `1H2J-0` (with `c:icon/skip-back-15` `1H2T-0`, `c:icon/pause` `1H2R-0`, `c:icon/skip-forward-30` `1H2P-0`: these are drawn **system** controls, not ours); contract 07 §6.

Spec: this page is drawn by the system. Our work is to make the system draw what Paper approved:
- the artwork (C40.4)
- the title and subtitle per contract 07 §6. Paper draws the title as a part's words ("the fundraise article you sent"); that becomes the **detail-on** look, and detail off is the default pending founder question 1
- ↺15 ‖ 30↻, through PL7.6's command choice (skip intervals 15 and 30 set on `skipBackwardCommand.preferredIntervals = [15]` and `skipForwardCommand.preferredIntervals = [30]`)

The page PR is the end-to-end check plus a single settings preview.

State table: playing, paused, part changed, detail on, detail off, and stopped (cleared).

Interaction sheet:

| # | Moment | What happens | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|---|
| 1 | lock the phone while the brief plays | Now Playing shows the artwork, "tuesday's brief", "retrospect · part 2 of 3" | system | — | system |
| 2 | pause / play | the player pauses or plays; the app's own transport matches when you return | system | system | system |
| 3 | ↺15 / 30↻ | skips; the time on the lock screen jumps | system | system | system |
| 4 | scrub | seeks | system | system | system |
| 5 | the spoken part changes | "part 3 of 3" (detail off) or the new part's title (detail on) | system | — | — |

Acceptance: the lock screen in each state matches `1H2J-0`'s layout (system chrome, so judged on content: artwork, title, subtitle, the 15/30 skips), and detail off shows no words from the brief.

Tests: `(UI) after playing then backgrounding, now playing has the brief's title and the 15 and 30 skips` (reads `MPNowPlayingInfoCenter` through a debug hook) · PL7.6's unit tests.

Proof in the PR: device screenshots (lock screen, Control Center, Dynamic Island), detail off and on, light and dark.

---

## EX-3 notifications

### P36 · EX-3 notifications: how they look and where taps land          size: S
Place in the tree: outside › EX-3 notifications
Repo · branch: NPRdoinglaundry · `ui/P36-notifications`
Needs: PL5.3, PL7.11, PL7.10, the landing pages (P10 JR-2, P14 PC-2, P21 YO-4, P17 GL-2), and EX-3 redrawn in Paper (below)      Unblocks: T05d

Why: the few notifications Retro sends are written for you about that moment, are safe for anyone to glance at, and open exactly the right thing.

Inputs:
- EX-3 `1H3E-0` (system UI only, read with `get_tree_summary`): three system banners, each with the app icon at 20, "retrospect", a time and **one fixed line** ("this week's episode is here." at sunday 9:00, "your brief is ready · 4 min" at 8:30, "one question for you, when you have a minute." at 6:10 pm), plus an annotation reading "at most one a day…".
- **Founder decision 21 Oct (newer than Paper): every notification is written custom, title and body.** So EX-3's fixed lines are superseded.
- **EX-3 needs a redraw.** The integrator draws a banner with a bold custom title, a one-line body, and the hidden-preview look ("retrospect has something for you."), with a red dot on the approvals page.
- Contract 07 §5.1–§5.7.

Spec:
- **No fixed notification copy in the app.** The only strings are:
  - `notify.hiddenPreview` "retrospect has something for you." (the categories' hidden-preview placeholder)
  - the action title `notify.action.play` "play"
  - the settings row's words (contract 06)
- The banner is the system's: the bold title (≤ 40 characters) and the body (≤ 110) as written by the brain (BE7.8a) and set by the service extension (PL7.11), or the payload's custom fallback.
- **Where taps land** (PL5.3 routes them; this card proves the landings look right):
  - brief → JR-2 sheet over the journal; with PLAY, it opens playing
  - episode → PC-2
  - question → YO-4 with the guess
  - a gone item → the page's own gone state, plus the toast "that's not here any more." (C21)

Interaction sheet:

| # | Moment | What happens | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|---|
| 1 | a push arrives, unlocked | the custom title and body (or the custom fallback if the fetch failed) | system | system | system |
| 2 | a push arrives, previews hidden (When Unlocked) | "retrospect has something for you."; the custom text on unlock | system | system | system |
| 3 | tap brief | the app opens on the journal and the JR-2 sheet rises | the sheet's `sheet` spring | `sheetSnap` | fade |
| 4 | long press → play | as 3, already playing | as 3, then `playMorph` | `sheetSnap` | fade |
| 5 | tap a question | YO-4 sheet over the you map | `sheet` | `sheetSnap` | fade |
| 6 | tap a notification for something deleted | the journal, with the toast | toast `popover` | none | fade |

Acceptance:
- No fixed notification wording exists in the app beyond the two strings above.
- Every landing matches its page's Paper node.
- With previews set to When Unlocked, the locked banner shows only the placeholder.

Tests:
- `(unit) the app's string catalog contains no notification copy other than the hidden-preview line and play` (a scan for `notify.` keys)
- `(UI) a brief push opens today's brief` (`simctl push` with the fixture)
- `(UI) play from the notification opens the brief playing`
- `(UI) a question push opens the guess`
- `(UI) a push for a deleted brief shows the gone toast`

Proof in the PR: a device recording of a staging push showing the custom text (founder's phone, test account), the same push with previews hidden, and a recording of each landing.

---

## EX-1 share

### C41 · Share item card                                   2 bytes: C41.1 S, C41.2 S
Place in the tree: outside › EX-1 share › item card
Repo · branches: NPRdoinglaundry · `ui/C41.1-share-card`, `ui/C41.2-share-read`
Needs: T01, #42 `RArtwork`, #45 `RPill`, C39.1 (skeleton)      Unblocks: P34

Why: you see at once what you're saving, then what Retro makes of it, and which of your goals it might go with, as a question you can change.

Inputs:
- Paper: `c:share/item-card` `1H1Z-0` on EX-1 `1H1M-0`, and the chip `c:pill/neutral` `1H23-0`. There's no master on 02 (inventory §7.1), so the instance is the source.
- handoff EX-1; reference §E P34.

Spec:
- **C41.1 the card face** (`1H1Z-0`, `1H28-0`):
  - the card: `background.raised`, `radius.card`, depth stack `inset 0 1 0 depth.strokeInnerTop`, `0 0 0 0.5 depth.strokeOuter`, `0 1 2 depth.shadowContact`, `0 10 24 −12 depth.shadowCast` (the `RDepth` raised recipe; check it matches, and otherwise ask the integrator for the token, never a local shadow)
  - the "thing" row: padding `spacing.4`, gap `spacing.3`, centred
  - the 56 thumb: `radius.panel`; `RArtwork` seeded from the URL in the paper palette as drawn (`paper.450` base, `amber.200` from (85%, 10%) to 55%, `paper.700` from (0%, 100%) to 80%). Never a downloaded image (contract 07 §1)
  - the text column (gap `size.border.ring`):
    - the title in SF Pro (`font.text`) `text.md` semibold `text.primary`, **one line** with tail truncation (Paper clamps to 1)
    - the meta line in Geist `text.sm` `text.label`: "youtube.com · 40 min video" (video), "example.com · 12 min read" (page), "example.com" (no length)
  - `reading`: the title area is a skeleton (C39.1); the site shows at once
  - `unreadable`: the URL's path as the title, in `text.secondary`
  - `textOnly`: the text itself, four lines then "…", no thumb
- **C41.2 the read and goes-with** (`1H20-0`):
  - a section under a top hairline (`inset 0 1 0 border.subtle`), padding `spacing.4`, gap `spacing.2`
  - the label "retro's read" in Geist `text.sm` medium `text.label`
  - the read in `font.display.inky` `text.xl`, `ink.card`, `tracking.card`, `leading.tight`, balanced, arriving with `.rBlurReplace`
  - the goes-with row (gap `spacing.2`, margin-top and padding-top `spacing.1`):
    - "goes with" in Geist `text.sm` `text.label`
    - the goal as `RPill` neutral (`surface.wash`, `radius.control`, 32 high, padding-inline `spacing.3`, Geist `text.md` medium `text.primary`)
    - "change" as a text link (`font.text` `text.md` medium `text.link`), which opens a menu (C20) with the suggested goal ✓ and "nothing" (v1 offers no other goals, because the extension has no goals list; founder question 5b, lean)
  - no read → the section hides; no `goesWith` → the row hides
  - **Honesty:** Paper draws the goal as a plain pill, not a guess marker. The suggestion is the person's to keep or change before saving, and saving is the confirmation (contract 07 §2.1), so the plain pill stands as drawn. The VoiceOver label says "might go with", and that's recorded as a founder check in README §8 Q5b
- **Paper vs the references:**
  1. the title is one line, not two
  2. the meta line says "40 min video", not "40 min watch"
  3. the chip has no "x"; removal is through "change"
  4. no dashed guess outline

State table: reading · read · read with goal · goal set to nothing · unreadable · text only · video ("40 min video") · long title (truncates) · dark.

Interaction table:

| Touch | Press | Haptic | Motion | Outcome | Reduce Motion |
|---|---|---|---|---|---|
| "change" | text press | none | menu grows from the link on `popover` | the suggested goal ✓ / nothing | fade |
| choose "nothing" | menu row | `select` | the pill collapses on `snappy`; the row closes on `map` | `goalChoice = none` | 140 fade |

Accessibility: the card reads "<title>, <site>, 12 minute read"; the read reads "retro's read: <read>"; the pill reads "might go with: raise the seed"; "change" reads "change the goal it goes with".

Acceptance: matches `1H1Z-0` in light and dark at the default and AX3 sizes; the suggested goal never reads as a statement.

Tests: (snapshot) every state row, light and dark, ax3 · (UI) removing the goal leaves none.

Watch out: the extension has about 120 MB. `RArtwork` must render the 56 thumb at 2× without the full-size grain texture (use its small-size path, or add one in this PR if #42 lacks it).

---

### C42 · Compact composer for the share sheet                               size: S
Place in the tree: outside › EX-1 share › compact composer
Repo · branch: NPRdoinglaundry · `ui/C42-compact-composer`
Needs: #54 `RComposer`, #56 `RVoiceComposer`      Unblocks: P34

Why: you can add a quick "why", by voice or by typing, without the share sheet becoming a second app.

Inputs: Paper `1H1R-0` (label + `c:composer/compact` `1H1S-0`, mic well `1H1U-0` with `c:icon/mic` `1H1V-0`); reference §E P34.

Spec (values from `1H1R-0`):
- **The group:** gap `spacing.2`. The label "add why (optional)" sits **above** the field, in Geist `text.sm` medium `text.label`.
- **The field:**
  - 48 high, `surface.control`, `radius.control`
  - sunken depth: `inset 0 1 2 depth.shadowSunken` plus `inset 0 0 0 0.5 depth.strokeOuter`
  - padding-inline `spacing.1`, gap `spacing.3`
- **The mic well** (leading): 40×40, `background.canvas`, `radius.control`, raised (`0 0 0 0.5 depth.strokeOuter`, `0 1 1.5 depth.shadowContact`), with the mic glyph 18 in `icon.default`.
- **Text:**
  - SF Pro (`font.text`) `text.body`; typed text is `text.primary`
  - Paper shows sample words ("for the raise, the bit on angels…") in `text.tertiary`. The empty field shows the hint "say or type why" in `text.placeholder` (context: field hints are `text.placeholder`; `text.tertiary` in Paper is the sample's colour, recorded below)
  - the field grows to three lines (AX3: five)
- `RComposer` gets a `.compact` variant if #54 doesn't have one. Send is never shown: the sheet's lit **save** is the one action.
- The mic uses on-device recognition (PL7.5b). While listening, the well shows `RVoiceComposer`'s listening glyph state, with no M02 glow (too big for the sheet). If recognition is unavailable, the mic is hidden and the text starts at `spacing.4`.
- **Paper vs the references:** the label sits above the field, not a placeholder inside it, and the sample text is `text.tertiary` (versus `text.placeholder` for hints).

State table: empty · typing · listening · transcribed · mic unavailable · dark · AX3.

Interaction table:

| Touch | Press | Haptic | Motion | Outcome | Reduce Motion |
|---|---|---|---|---|---|
| mic | well 0.94 | `listenStart` | — | listening | no scale |
| stop | well 0.94 | `listenStop` | the transcript `.rBlurReplace` | the note is the transcript | fade |
| type | — | — | the field grows on `snappy` | — | no grow animation |

Accessibility: "add why, optional, text field"; the mic is "say why", announcing "listening" and "stopped".

Tests: (snapshot) each state, light and dark, ax3 · (unit) the compact variant never shows send.

---

### P34 · EX-1 share to Retrospect                                           size: M
Place in the tree: outside › EX-1 share
Repo · branch: NPRdoinglaundry · `ui/P34-share-sheet`
Needs: C41.1, C41.2, C42, PL7.5a, PL7.5b, INT7.1 (target)      Unblocks: T05d

Why: save anything from any app into your bank in two taps, with a reason if you like, and always know whether it's in.

Inputs: EX-1 `1H1M-0` (cancel · "save to retrospect" · card · composer · lit save `c:button/lit/save` `1H1P-0`); contract 07 §2, §4, §8; handoff EX-1 states.

Spec:
- A SwiftUI view hosted in the extension's `UIHostingController`. Values from `1H1O-0`:
  - **the sheet:** `background.canvas` (Paper; not raised), top corners `radius.sheet`, padding-inline `spacing.screenMargin`, padding-top `spacing.2`, padding-bottom `spacing.10`, a column with gap `spacing.6`
  - **the grabber:** 36×5, `border.strong`, `radius.control`, centred
  - **the header** (44 high): "cancel" in SF Pro `text.body` `text.link` in a 72 slot; "save to retrospect" centred in Geist `text.md` semibold `text.primary`; an empty 72 slot on the right
  - **the card** (C41), margin-top `spacing.2`
  - **flexible space**
  - **the "add why" group** (C42)
  - **save:** `RButton` lit at `size.control.hero` (60) high, full width, `radius.control`, label SF Pro `text.body` semibold `glow.primary.foreground`. It's the one lit object
- Sheet height: the system's share sheet with our content. On open it fits the content above the keyboard and grows with the keyboard.
- States (from `ShareModel`):
  - reading
  - read
  - saving (save → spinner, `RButton` loading)
  - saved: the card stays, save becomes a check, and the line is "it'll be in tomorrow's brief" or "it's in your journal."; it closes after `toastVisible` 4 s or on tap
  - queued: "it'll send next time you open retrospect", with an `offline` glyph
  - refused: the server's plain message; save is replaced by "close"
  - signed out: "open retrospect to finish signing in" plus "close"
  - text only
  - video

Interaction sheet:

| # | Moment | What happens | Motion | Haptic | Reduce Motion |
|---|---|---|---|---|---|
| 1 | open from another app | the system sheet rises; the card shows the site at once | system | — | system |
| 2 | the read arrives | the read and the goes-with row blur in | `.rBlurReplace` 280 | none | 140 fade |
| 3 | tap save | press 0.98, then spinner | `rPress`, `snappy` | `press` | no scale |
| 4 | saved | the check lands and the line blurs in | `pop` on the check | `confirm` | fade |
| 5 | queued | the line blurs in with the offline glyph | `.rBlurReplace` | none | fade |
| 6 | refused | the message blurs in and save becomes close | `.rBlurReplace` | `error` | fade |
| 7 | cancel | the sheet closes; nothing is saved or queued | system | — | system |

Life allowed: none.

Accessibility: the rotor order is cancel → title → card → read → goes-with → composer → save. The saved, queued and refused lines are announced once. `performAccessibilityAudit()` passes in reading, read and saved.

Acceptance:
- Every state matches `1H1M-0` (or the state rules above where Paper draws nothing; inventory §5 says no states are drawn for EX-1). Each undrawn state's look is shown to the founder in the PR for approval, with a red dot on the approvals page.
- Save is never disabled while reading.
- Cancel never leaves an inbox file.

Tests:
- `(snapshot) the sheet in reading, read, saving, saved, queued, refused, signed out, text only and video; light and dark; ax3 (read)`
- `(UI) sharing a link from Safari shows the card and saves it` (a UI test with `XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")` on a local test page)
- `(UI) saving in airplane mode says it'll send later`
- `(UI) cancel saves nothing`
- `(accessibility) the audit passes in read and saved`

Proof in the PR: screenshots next to `1H1M-0`; recordings of save (online), save (offline) and the read arriving.

Watch out: the extension can be killed as soon as it's off screen. Every write happens before any wait (PL7.5b).

---

## Signature moments M01–M13

**What a moment card is.** The parts of each moment are built inside their components (C30's lift, C24's morph, C36's meter and so on). A moment card is **the moment as a whole**:
- the choreography across those parts, with its timing written down as frames
- a proving preview in `DesignSystemV2/Motion/M<nn>Preview.swift`, using the real components and tokens (motion-from-real-components rule)
- the lab page (`RLabPage.m<nn>`, added by the integrator to `RMotionLab.swift`, a shared file)
- the wiring of the choreography into its page
- the visual pass (motion-system §9) with recordings and the founder's sign-off

Each card is one PR **after its page** has merged. Founder rule (first-ship): M01–M13 come with their flows. M14 is the first-run planner's.

**The gate before any moment PR:** a 4–6 frame filmstrip in Paper with timings written on it, in its component's 02b section, red dot until the founder approves (microinteractions-plan "Process" 1). **No filmstrip exists yet for M02–M13**: a search of the light file on 21 Oct for "filmstrip" and "storyboard" found none, and M01 has only the splash keyframe page. The integrator draws them, and the frames below are the proposal to draw from.

**The standard every moment meets** (motion-system §1, §8, §9):
- **Springs and curves:** only `RMotion` tokens, never linear except real-time progress, never `.easeInOut(duration:)` (the lint rule G0.1).
- **Interrupt:** a tap or drag mid-flight reverses from where it is (additive animation; never `.transaction { $0.animation = nil }` mid-flight).
- **Haptics:** only `RHaptic` tokens, prepared ahead, fired on the frame the motion lands, at most one per 80 ms, never during scroll, never twice.
- **Reduce Motion:** the meaning survives as a 140 ms cross-fade, with no scale, blur, tilt or bounce. Haptics stay except `typeOn`. Every `.r*` modifier swaps itself; the page doesn't branch.
- **VoiceOver:** state changes are announced in words, never only through motion.
- **Hitch budget** (Instruments "Animation Hitches", 5 runs of the moment):
  - **0 hitches** on the integrator's iPhone 17 Pro simulator **and** on the founder's iPhone (ProMotion 120 Hz)
  - **hitch time ratio under 5 ms/s** on the oldest supported phone (iOS 18.1, the iPhone XS / XR class)
  - main-thread work under 4 ms per frame during the moment (Time Profiler)
  - a moment over budget isn't merged; it's simplified (fewer layers, no offscreen blur) and re-measured
- **Proof in every moment PR:**
  - a 120 fps recording and a Slow Animations recording, side by side with the filmstrip
  - a Reduce Motion recording
  - the Instruments trace summary (hitch count and ratio per run)
  - an interrupt recording
  - the haptic timing (a debug overlay that flashes on each `RHaptic` call, recorded)
- **Tests in every moment PR:**
  - `(snapshot) the first and last frames in light, dark and reduce motion` (via `-MotionFrame first|last`, a T02 option)
  - `(UI) the moment completes and lands in its end state` (identifier `moment.<nn>.done`)
  - `(UI) with reduce motion on, the end state is reached by a cross-fade` (identifier check plus no transform on the element)
  - `(unit) the haptic fires once per trigger` (a fake `RHaptic` sink)
  - `(motion) the hitch count over five runs is zero` (layer 10, a trend in CI on the simulator; the device numbers go in the PR)

Spring timings below are the token's settle time measured in the F09 lab (#25), rounded. "t" is milliseconds from the trigger.

---

### M01 · The splash: the orb breathes, the satellites drift in           size: M
Place in the tree: outside › signature moments › M01 (on first run › ON-1/2 › splash)
Repo · branch: NPRdoinglaundry · `ui/M01-splash-opening`
Needs: P01, UI4.4 (splash), C38 (you map orbits), the splash opening chosen (README §8, "also asked elsewhere"), the filmstrip approved      Unblocks: G1's flow pass

Why: the first thing you ever see feels alive and calm, and never makes you wait to sign in.

Inputs:
- Paper: splash `1F4Q-0`, `c:you-map/orbits/rest` `1F5K-0`; keyframes on "06 · splash motion · keyframes" (light) / `p-E-0` (dark file); states board `5ZQ-0` (idle `5ZT`, reduced motion `61F`)
- motion preview `docs/design/motion/splash-a.html`, `splash-d.html`
- reference §C M01, §F 38

Frames (lean: the approved A constellation, assembling):

| t | Frame |
|---|---|
| 0 | canvas and the wallpaper at full; the words and both sign-in buttons are already in place and **tappable** (nothing a person waits on is animated) |
| 0–1220 | the orb breathes once: scale 0.96 → 1.0 and its halo opacity 0 → 0.5 on `curve.reveal` (`duration.reveal`) |
| 200 + 60·i | satellite i (at most 6, `staggerMax`) drifts 12pt in from its rest offset and fades in, on `spring.map` (settles ≈ 520) |
| ≈ 1020 | the last satellite settles; everything is still |
| 1220 + | life: the halo breathes 0.35 ↔ 0.5 every 6 s (B6), paused on touch, in Low Power Mode and with Reduce Motion on |

- Haptics: none (M01).
- Interrupt: a tap anywhere on the map jumps every satellite to rest on `snappy`. Tapping a sign-in button never waits for the moment.
- Reduce Motion: the final frame, cross-faded in over 140 ms, with no breathing life.
- VoiceOver: nothing announced. The map is `accessibilityHidden`, and the promise is the first element.
- Hitch budget: the standard. Satellites are flat layers (no live blur), and the frosted orbs use pre-rendered images, never `.blur` per frame.

Acceptance: matches the approved filmstrip; the sign-in buttons respond on the first frame; Reduce Motion matches `61F`.
Tests: the standard, plus `(UI) sign in with apple is hittable at launch before the moment ends`.

Watch out: if the founder picks D ("the dots connect", about 4.6 s), the buttons still mustn't wait. D plays behind live buttons with tap-to-skip.

---

### M02 · The listening glow follows your voice                            size: M
Place in the tree: outside › signature moments › M02 (on first run › ON-3–9 › listening; also JR-1 talking)
Repo · branch: NPRdoinglaundry · `ui/M02-listening-glow`
Needs: P02, #56 `RVoiceComposer` listening state (C16 folded into it), a live mic level stream from the recorder (`Media.LevelMeter`; part of #56's recorder, or a Platform S byte if missing), the filmstrip      Unblocks: L1 flow pass

Why: while you talk, the screen visibly listens: the glow rises and falls with your voice, so you know it's hearing you.

Inputs: Paper `c:voice-composer/listening` `1F6E-0`; reference §C M02, §B5 "Listening field"; founder 21 Oct: follows the level live, capped so it never jumps.

Frames:

| t | Frame |
|---|---|
| 0 (mic touch-down) | `listenStart`; the mic presses 0.94 |
| 0–550 | the glow rises from the bottom edge to its base height on `spring.gentle` (settles ≈ 550) |
| 550 + | the height follows the level: `base × (1 + 0.3 × level)`, where level is 0…1, smoothed with a 120 ms one-pole filter and capped at 1.3×. Its opacity follows at 50% of the same curve |
| stop tap | `listenStop` on touch-down; the glow falls to 0 on `spring.sheetDismiss` (≈ 65% of the rise) |

- Haptics: `listenStart` on start, `listenStop` on stop, nothing while following.
- Interrupt: stop mid-rise reverses from the current height.
- Reduce Motion: the glow appears at base height with a 140 ms fade and doesn't follow the level; the "listening…" label is the signal.
- VoiceOver: "listening" announced on start, "stopped" on stop.
- Hitch budget: the standard. The glow is one gradient layer whose height is driven by a single `@State` at no more than 60 Hz (the level stream is throttled), with no re-layout of the composer.

Tests: the standard, plus `(unit) the glow never exceeds 1.3 times its base` and `(unit) a sudden loud level moves the glow no more than the 120 ms filter allows`.

---

### M03 · The understood word ink-sharpens                                 size: S
Place in the tree: outside › signature moments › M03 (on first run › ON-3–9 › your words)
Repo · branch: NPRdoinglaundry · `ui/M03-ink-sharpen`
Needs: P02, C34 (`c:onboarding/your-words`), the filmstrip      Unblocks: L1 flow pass

Why: when Retro understands the key word in your answer, you see it settle into ink, so you know it got it.

Inputs: Paper `1F6R-0`; reference §C M03, §C34.

Frames: t 0, the key word is in `text.secondary` with a 1.5pt blur · 0–280 the blur goes 1.5 → 0 and the colour goes `text.secondary` → `text.primary` on `curve.standard` (`duration.slow`) · 280, `confirm`, landing with the ink.

- Interrupt: a new answer cancels the sharpen at its current value, and the next word starts from there.
- Reduce Motion: the colour cross-fades over 140 ms with no blur, and `confirm` stays.
- VoiceOver: "understood: london" (the word), announced once.
- Hitch budget: the standard. The blur is applied to the one word's `Text` run only (the word-by-word drawing, screen rule notes), never to the paragraph.

Tests: the standard.

---

### M04 · Connect → connected, the meter fills, "knows you well"           size: M
Place in the tree: outside › signature moments › M04 (on first run › ON-6 › connect)
Repo · branch: NPRdoinglaundry · `ui/M04-connect-meter`
Needs: P04, C36 (knows-you meter), #52 `RSourceRow`, the filmstrip. **Built first** among the moments with M07 (microinteractions order: "the one that matters most for the business")      Unblocks: L1 flow pass

Why: every app you connect visibly makes Retro know you better, and reaching "knows you well" feels like a small reward.

Inputs: Paper `21C1-0` (meter `c:knows-you-meter/1-of-6`), `21BN-0`; reference §C M04, §B5 "+ connect", "Knows-you meter"; founder 21 Oct.

Frames:

| t | Frame |
|---|---|
| 0 (touch-down) | the connect pill presses to 0.94 (`pressIn` 80, `curve.standard`); `press` |
| release | back on `snappy`; the label blur-replaces into a spinner (`duration.base`) |
| (permission or OAuth, any length) | spinner |
| success, s | the spinner blur-replaces into "● connected"; the dot scales 0 → 1 on `spring.pop` (≈ 8% overshoot, settles ≈ 450); the row width changes on `snappy` |
| s + 450 | the meter fills one step on `curve.move` over 420 ms; its label rolls (`numberTick` 320, `.contentTransition(.numericText())`) "a little → better" |
| s + 870 | `confirm`, landing with the meter |
| at "well" | instead of the plain landing: the fill glows once (halo opacity 0 → 0.6 → 0 over 600 on `curve.standard`) and the label pops on `spring.pop`, with **one** `confirm` (never two) |
| failure | the pill shakes 6pt × 3 on `snappy` (`.rShake`), `warning`, and "try again" blur-replaces in |

- Interrupt: tapping another source while the meter fills retargets the fill from its current value.
- Reduce Motion: the dot and label cross-fade, the meter steps with a 140 ms fade, no glow, no shake (a `warning` plus the "try again" line), and the haptics stay.
- VoiceOver: "calendar connected. retro knows you a little better." / "… retro knows you well." (B7).
- Hitch budget: the standard.

Tests: the standard, plus `(UI) reaching well fires one confirm` and `(UI) a failed connect shakes and offers try again`.

---

### M05 · Getting ready: honest steps, tags pop in                         size: M
Place in the tree: outside › signature moments › M05 (on first run › ON-10 › getting ready)
Repo · branch: NPRdoinglaundry · `ui/M05-getting-ready`
Needs: P05, UI4.1 (getting-ready card), PL3.3 (real stages), the filmstrip      Unblocks: G1's flow pass

Why: while your first episode is made, you see real progress, never a fake percentage, and what you keep saying visibly goes into it.

Inputs: Paper `26LV-0` (`c:getting-ready`), `26LZ-0` (`c:stage/next`), `26ML-0`; reference "Getting-ready panel" (newest look c-koui68: the brief card in its being-made state, tags tucked into its top edge, the 2pt hairline).

Frames:
- **A stage advances:** the hairline moves to the stage's fixed point (1/3, 2/3) on `curve.move` over 420. The stage label blur-replaces over 280 (`duration.slow`).
- **You say something new:** a tag "+ the investor call on thursday" pops in above the card, tilted −2°, on `spring.popover` (≈ 3%). After 600 ms it slides into the card's top edge on `spring.sheet` and settles tucked.
- Never more than one tag moving at a time; others wait 60 ms (`stagger`).

- Haptics: none (M05).
- Reduce Motion: the hairline jumps with a 140 ms fade, tags fade in already tucked, and the label cross-fades.
- VoiceOver: "step 2 of 3: writing your episode" on each stage (the progress wording is a later-phase founder question, lean "step 2 of 3").
- Hitch budget: the standard.
- **Conflict:** the hairline is blue in Paper, but "progress fills with ink" (reference §F 17). Lean ink, per the later.md questions.

Tests: the standard, plus `(unit) the hairline only ever sits at a real stage's point`.

---

### M06 · The player shrinks into the mini-player; the paywall rises       size: L (split if it runs over: M06.1 the shrink, M06.2 the rise)
Place in the tree: outside › signature moments › M06 (on first run › ON-11 → ON-12)
Repo · branch: NPRdoinglaundry · `ui/M06-tease-to-paywall`
Needs: P06, P07, C22-p (paywall mini-player), C23e (episode player), the filmstrip      Unblocks: G1's flow pass

Why: the moment your first episode's free part ends, it tucks itself away, still yours, while the offer to hear the rest rises from what you just heard.

Inputs: Paper `26NZ-0` (`c:player-sheet/brief/playing` on ON-11) → `22TR-0` (`c:mini-player/paused`); reference §C M06 (paywall.md: "1.22s reveal"); §F 40 (M06 belongs to first run, not podcasts).

Frames:

| t | Frame |
|---|---|
| 0 | the tease ends (or the person taps "hear the rest"); playback pauses (`playMorph`) |
| 0–400 | shared element (`matchedGeometryEffect` on artwork, title, play) from the player to the 64pt paused mini-player at the top, on `spring.sheet` (settles ≈ 400) |
| 120–520 | the paywall body rises from the transcript's strongest line on `spring.sheet`; the page behind dims on the same progress value |
| ≈ 520 | `sheetSnap` as the paywall settles |
| 520–1220 | the benefit rows arrive top to bottom (`stagger` 60, ≤ 6, `curve.standard` 280, 8pt rise, blur 8 → 0); the off-axis tiles settle once on `spring.settle` |

- Interrupt: dragging the paywall down mid-rise follows the finger and reverses on release (sheet rules, B4).
- Reduce Motion: the mini-player and the paywall cross-fade in over 140 ms, with no stagger and no tile settle.
- VoiceOver: "your first episode is paused. become a member to hear the rest." announced once.
- Hitch budget: the standard. This is the heaviest moment, so it's measured on the oldest phone first.

Tests: the standard, plus `(UI) the mini-player keeps the paused position after the paywall rises`.

---

### M07 · The plans: the save tag rolls in                                 size: S
Place in the tree: outside › signature moments › M07 (on first run › ON-12 › plans)
Repo · branch: NPRdoinglaundry · `ui/M07-plan-save-tag`
Needs: P07, C37 (plan pair), PL6.1 (localized prices), the M07 founder question (README §8, "also asked elsewhere"; lean below), the filmstrip      Unblocks: G1's flow pass

Why: the yearly saving lands with a small, honest flourish, and choosing a plan feels firm.

Inputs: Paper decision 06 `IFL-0`, `c:button/lit/plan-yearly` `22MH-0`, `c:button/secondary/plan-monthly` `22MM-0`, `c:badge/save` `22MI-0`; reference §C M07, §F 1 and 3.

Frames (lean: option A has no "chosen plan" state, so the glow doesn't slide):
- **Prices load:** the save tag pops in on `spring.pop` with its figure rolling up (`numberTick` 320, `.numericText()`) to the saving **computed from StoreKit's two prices** (17% with $19.99 / $199.99; never a typed number, context D6; Paper's "save 20%" is stale).
- **Press on a plan:** 0.98 in 80 and `press` (lit plan) or no haptic (secondary). StoreKit's sheet takes over.
- **Success:** `confirm` (purchase success, B9) after StoreKit returns; the paywall leaves on `sheetDismiss`.

- Reduce Motion: the tag fades in with the final figure.
- VoiceOver: "yearly, $199.99 a year, save 17 percent".
- Hitch budget: the standard.

Tests: the standard, plus `(unit) the save figure comes from the two prices, never a constant`.

---

### M08 · Your bubble lifts (v1)                                           size: S
Place in the tree: outside › signature moments › M08 (on journal › JR-1 › send)
Repo · branch: NPRdoinglaundry · `ui/M08-bubble-lift`
Needs: P09 (which builds the lift, interaction row 5), C30.1 (accepts the namespace), the filmstrip      Unblocks: the journal flow pass (G2)

Why: sending feels like letting go of something into a safe place: your words lift into the thread, and Retro's line follows only once it's really in.

Inputs: Paper part 08 `9W3-0` (states `C3A-0`), JR-1 `1FKB-0`, `c:message/mine/rest` `1FLH-0`; P09 interaction sheet row 5; C30 state table; reference §F 36 (`confirm` when the bubble lands, newest).

Frames:

| t | Frame |
|---|---|
| 0 (send) | the composer's text becomes the bubble: `matchedGeometryEffect` from the field to the thread's newest slot, on `spring.sheet` (settles ≈ 400); the bubble is at `opacity.pending` 0.7 (sending) |
| ≈ 400 | lands; `confirm` |
| on sent (server) | opacity 0.7 → 1 over 140 |
| sent + 0–200 | Retro's acknowledgement fades in on `curve.standard` (`duration.base`) |

- **v2** (line-by-line sharpening of a streamed reply, 60 ms apart) is deferred with the conversation (PL3.2). It's not in this card.
- Interrupt: sending again mid-lift lands the first bubble at once (no queue) and lifts the second.
- Reduce Motion: the bubble fades in at its slot over 140 ms with no lift, and `confirm` stays.
- VoiceOver: "sent" when sent; the acknowledgement is announced once (C30).
- Hitch budget: the standard, measured with a 200-entry thread (the bottom-anchored scroll is the risk).

Tests: the standard, plus `(UI) the acknowledgement never appears before the entry is sent` (offline, then online).

---

### M09 · Play morph, rolling time, chapter ticks                          size: M
Place in the tree: outside › signature moments › M09 (on journal › JR-2 player; podcasts › PC-2)
Repo · branch: NPRdoinglaundry · `ui/M09-player-transport`
Needs: P10 (first host), C24, C25, the filmstrip; P14 adopts it when podcasts ship      Unblocks: the journal flow pass, then L3

Why: the player feels physical: play becomes pause, skipping visibly moves time, and you can feel each chapter as you scrub past it.

Inputs: Paper part 09 `A38-0`; JR-2 `1FMG-0` (`1FMR-0`); `c:scrubber/chapters` `26OM-0`; C24 and C25 cards; reference §C M09.

Frames:
- **Play ↔ pause:** a custom glyph morph (scale 0.8 + opacity cross) over `playMorph` 180 on `curve.standard`; `press` on the lit play only.
- **Skip:** the arrow turns 20° in its direction and back on `snappy`; the time numerals roll (`numberTick` 320, `.numericText()`, `.monospacedDigit()`); `skip`.
- **Scrub:**
  - touch-down: the thumb grows to 1.6× (`scale.scrubThumb`) on `snappy`
  - drag: the thumb follows 1:1 (linear: real time, B1's exception)
  - crossing a chapter: `chapterTick` (at most one per 80 ms) and the chapter name slides up one line on `popover`
  - release: the thumb returns on `popover`; within 12pt of a chapter, it snaps to it
- **Playing:** the progress line moves linearly with real time (allowed).

- Reduce Motion: the glyph swaps instantly with a 140 fade; no turn; no thumb growth (a value bubble appears); the chapter name cross-fades. `skip` and `chapterTick` stay.
- VoiceOver: "playing" / "paused"; "skipped forward 30 seconds, 2 minutes 10"; scrubbing is an adjustable action announcing chapter names.
- Hitch budget: the standard, with the scrub measured on a 40-minute episode with 8 chapters.

Tests: the standard, plus `(unit) crossing three chapters quickly ticks at most once per 80 ms` and `(unit) release within 12 points snaps to the chapter`.

---

### M10 · Tiles lag the scroll                                             size: M
Place in the tree: outside › signature moments › M10 (on podcasts › PC-1)
Repo · branch: NPRdoinglaundry · `ui/M10-tile-scroll-lag`
Needs: P13, C27 (`.rScrollLag()` already exists in the motion modifiers), the filmstrip      Unblocks: L3

Why: your episodes feel like objects: they trail your scroll a touch and settle, like cards in water.

Inputs: Paper part 40 `FWU-0`, `c:episode-tile/hero/rest` `1FUK-0`, `square` `1FUE-0`; reference §C M10 (`settle` per the system, newest); B6 life rules.

Frames: while scrolling at velocity v, each tile is offset by `min(6, k·v)` pt against the scroll and tilted `min(1.5°, k′·v)`, staggered by its row (lower rows lag 20 ms more). On stop, everything returns on `spring.settle` (≈ 4% overshoot, settles ≈ 600). At rest nothing moves, ever.

- Haptics: none (never on scroll).
- Off: with Reduce Motion, in Low Power Mode, and when VoiceOver is focused on a tile.
- Hitch budget (**stricter**, since this runs on every scroll): 0 hitches over 5 runs of a 3-screen fling, a hitch time ratio within the same list's no-lag baseline + 1 ms/s, and no per-frame layout. Offsets are applied with `visualEffect` (render-only, no layout invalidation).

Tests: the standard, plus `(unit) the offset never exceeds 6 points or 1.5 degrees` and `(UI) with reduce motion on, tiles never move while scrolling`.

---

### M11 · The goal card folds, the bar eases                               size: M
Place in the tree: outside › signature moments › M11 (on goals › GL-1 › card)
Repo · branch: NPRdoinglaundry · `ui/M11-goal-fold`
Needs: P16, C29, the filmstrip      Unblocks: L4

Why: answering "yes" or "not quite" visibly does something: the question folds away and your goal moves.

Inputs: Paper part 48 `ITY-0`, `1G2R-0`; reference §C M11, §C29.

Frames:

| t | Frame |
|---|---|
| 0 (answer) | the button presses; `press` (lit) or none (secondary) |
| 0–400 | the question card folds (height → 0, content fades on `curve.exit` 140) on `spring.sheet` |
| 200–720 | the list closes the gap on `spring.map` (starts at ~50%, overlapping chained steps, B4) |
| 400–680 | the goal's bar eases to its new value on `curve.move` (`duration.slow` 280) |
| 680 | `confirm` as the bar lands |

- Interrupt: undo (the toast, C21) reverses the fold from where it is.
- Reduce Motion: the card fades out over 140 ms, the list cross-fades to its new layout, the bar steps, and `confirm` stays.
- VoiceOver: "noted. sleep before midnight: 4 of 7 this week."
- Hitch budget: the standard.

Tests: the standard, plus `(UI) undo during the fold brings the card back`.

---

### M12 · A new fact blooms into the map                                   size: M
Place in the tree: outside › signature moments › M12 (on you › YO-1 › map)
Repo · branch: NPRdoinglaundry · `ui/M12-fact-bloom`
Needs: P18, C38, the filmstrip      Unblocks: L5

Why: when Retro learns something new about you, you see it arrive and connect to you, quietly.

Inputs: Paper `1G6Z-0` (`c:you-map/orbits/rest`), part 05 `9BS-0`; reference §C M12, §B5 "You map".

Frames:

| t | Frame |
|---|---|
| 0 | the node scales 0 → 1 on `spring.pop` (≈ 8%, settles ≈ 450); its halo fades in to 0.5 on `curve.standard` 280; `reveal` |
| 450–870 | the line to "you" draws itself (stroke 0 → 1) on `curve.standard` over 420 |
| 870–2090 | the halo fades back to its life level on `curve.reveal` |

At most one bloom at a time; others wait their turn (`stagger` 60 after the previous line lands).

- Reduce Motion: the node and line appear complete with a 140 fade, with no halo pulse; `reveal` stays.
- VoiceOver: "new: <fact's short label>" announced once (the label is the map's own; no new copy).
- Hitch budget: the standard. The halo is a pre-rendered radial image whose opacity animates, never a live blur.

Tests: the standard, plus `(unit) two new facts bloom one after the other, never together`.

---

### M13 · Questions type out, a soft tick per word                         size: M
Place in the tree: outside › signature moments › M13 (on first run › ON-3–9 › question)
Repo · branch: NPRdoinglaundry · `ui/M13-question-type-on`
Needs: P02, C34, the filmstrip      Unblocks: L1

Why: Retro asks each question as if writing it to you, and you can feel it being written.

Inputs: Paper part 42 `GD2-0`, `c:onboarding/question` `1F6V-0`; reference §C M13, §C34 build notes 21 Oct; B9 (`typeOn`).

Frames: words appear one at a time, at most 10 a second. Each word's interval is `max(100, 40 + 18 × letters)` ms. Each word sharpens from a 1.5pt blur and opacity 0 → 1 on `curve.standard` over 120 ms. A `typeOn` (soft impact at 0.35, one prepared generator, `prepare()` when the question starts) fires on each word that has a letter, silent for punctuation and spaces.

- Interrupt: tapping the mic (or starting to speak) completes the question at once and stops the ticks (`listenStart` takes over). Tapping the question completes it.
- Reduce Motion: the whole question appears with a 140 fade and no `typeOn`.
- VoiceOver: the full question is read once it's complete; it isn't read word by word.
- Hitch budget: the standard. Each word is its own `Text` (screen-rule note), and words already sharp aren't re-rendered.

Tests: the standard, plus `(unit) typing never exceeds ten words a second`, `(unit) punctuation fires no tick` and `(UI) starting to talk completes the question and stops the ticks`.

---

## Retiring the old (views)

### X02b · The force-update page                                             size: S
Place in the tree: outside › retiring the old › version floor › force-update page
Repo · branch: NPRdoinglaundry · `ui/X02b-force-update`
Needs: PL1.6 (`updateRequired`), a Paper drawing approved by the founder (none exists: a search of the light file for "force update" on 21 Oct found nothing) (the integrator draws it; ui-engineer.md "force-update and invite screens: drawn in Paper first"; lean: a splash-style purpose page with one title, one line and one lit "update")      Unblocks: X02a (the floor may only be raised above a version that has this page)

Why: if your version is too old to work, you're told plainly and taken to the update, instead of the app breaking.

Spec:
- A full-screen page shown by the root when `updateRequired` is true, over everything, with no way past it:
  - title "time to update." (founder copy)
  - one line "this version of retrospect can't reach your journal any more. nothing is lost."
  - **update** (`RButton` lit) opens the App Store page (`itms-apps://apps.apple.com/app/id<id>`, the id from build configuration), or TestFlight on beta builds (`itms-beta://`)
- Outbox entries are kept (they send after updating), so the line "nothing is lost" is true.

State table: rest · dark · AX3 · SE.

Interaction: update → `press` → opens the store.

Accessibility: the title is a header; "update, opens the app store".

Tests: `(snapshot) the page in light, dark, ax3 and SE` · `(UI) a 426 from any door shows the page` · `(UI) the page can't be dismissed`.

Rollback: lowering the floor (X02a) makes the page disappear on the next check, with no app change needed.

---

### X03a–X03d · Remove experiments with no new design                      size: S each
Place in the tree: outside › retiring the old › experiments
Repo · branch: NPRdoinglaundry · `ui/X03<x>-remove-<experiment>`
Needs (each): G1 shipped (progress map), X01's ledger rows, the experiment unreachable from the shipped navigation (its design switch off for every user for one TestFlight build)

| Byte | Removes (X01 confirms the exact list) | Data care |
|---|---|---|
| X03a | video journal: `VideoJournalView`, `VideoJournalingView`, `VideoJournalListView`, `VideoLogView`, `FramedCameraView`, `CameraPreview`, `Representables/CameraPreviewViewRepresentable`, `ViewModels/CameraViewModel`, `ViewModels/VideoJournalViewModel`, `Models/VideoJournalEntry`, `Extensions/CIImage+Extension`, `CMSampleBuffer+Extension` | old video files stay on disk for X06e; the text of video entries was imported by PL2.6 |
| X03b | Polaroid: `PolaroidHomeView`, `Components/PolaroidFrame`, `PolaroidPlayingControls`, `SimplePolaroid` | none |
| X03c | iMessage onboarding: `iMessageOnboardingView` | it calls `PodcastNotificationService.requestAuthorization` and `scheduleAllRecurringNotifications` (app-reference §9): move nothing, the new first run owns permission |
| X03d | extra Home variants and previews: `LegacyHomeScreen`, `MinimalHomeScreen`, `OptimizedHomeScreen`, `AnimationPreviewView`, `FluidDotsView`, `CoStarTextInput`, `Examples/KeyboardBehaviorExamples`, `Components/FontPreviewTile` | none |

Tests (each): the app builds; the full suite passes; `no reference to <type> remains` (grep test); `NSCameraUsageDescription` is removed in X03a only if nothing else uses the camera (integrator line).

Rollback: revert the PR (code only).

---

### X04 · Remove the old design system                                      size: M
Place in the tree: outside › retiring the old › old design system
Repo · branch: NPRdoinglaundry · `ui/X04-remove-old-design-system`
Needs: X10f (the last old screen is gone, G6)      Unblocks: X09

Removes:
- `Utilities/Button Styles/*`
- `Utilities/DesignSystem.swift`, `Typography.swift`, `LinearColors.swift`, `HapticManager.swift`, `SpringHapticController.swift`, `RotateModifier.swift`, `ThemeManager.swift`
- `Views/Components/ClickyButton`, `MinimalPillButton`, `ExpandableCard`, `OnboardingDesignSystem`, `FigmaLightPageSystem`, `DarkPageScaffold`
- `Views/Components/ExposureFont.swift` **only if** `RType` no longer references it. It's locally modified in the founder's checkout (git status, 21 Oct), so check before deleting.
- The SwiftLint scope widens to the whole app in the same PR (trust-ladder G0.1: "the old app stays out until it's retired"), as an integrator line.

Tests: the app builds; the full suite passes; grep tests for each type. Rollback: revert.

---

### X10a–X10g · Delete each old flow's screens after its ship gate          size: M each (split by file group if a PR passes ~800 deleted lines of mixed concerns)
Place in the tree: outside › retiring the old › old screens › <flow>
Repo · branch: NPRdoinglaundry · `ui/X10<x>-retire-<flow>-screens`
Needs (every one):
- the flow's ship gate signed off (README §5)
- its design switches on for everyone for **one full TestFlight build** (the soak)
- X01's symbol grep showing the files unreferenced once the listed entry points go
- the integrator's go

**Safe order inside each PR:**
1. remove the switch branch that shows the old screen
2. remove the screens
3. remove their view models and services used only by them
4. build and test

Data is never touched here (that's X06).

**Rollback:** before the PR, flip the switch back. After the PR, revert it: code only, so a revert restores the old screens exactly.

| Byte | Gate | Removes (candidates; X01 is the truth) | Special care |
|---|---|---|---|
| X10a | G2 journal | `HomeScreen`, `DarkVoiceRecordingView`, `VoiceRecordingView`, `DarkEntriesView`, `DarkEntryDetailView`, `EntriesView`, `EntryDetailView`, `Components/EntryCard`, `MinimalJournalInput`, `FloatingInputBar`, `ReflectionsInputCard`, `AttachmentPickerSheet`, `ImageAttachmentPicker`, `VoiceEntryPlayerView`, `DarkTeleprompterView`; `EntryManager`'s file-writing path (the bridge PL2.3 made it outbox-backed; the type goes when its last caller does) | `StopRecordingIntent` and `StartVoiceRecordingIntent` are re-pointed to the new recorder (PL7.7), not deleted |
| X10b | G1 first run | `DarkOnboardingFlow`, `VoiceGoalsPage`, `WelcomeSignInPage`, `Components/AuthenticationScreen`, `BackendAuthGateView`, `OnboardingPrivacyPage`, `PersonaPickerPage`, `Components/OnboardingScreenTemplate`, `WelcomeCardScreen`, `DataExplanationScreen`, `AppleHealthOnboardingScreen`, `DarkVoicePersonaOnboardingScreen`, `PrivacyScreen`, `DarkSplashScreen`, `SplashScreenView`, `FirstPodcastExperience`, `PodcastPaywallFlow`, `Components/PaywallView`, `NewPodcastArrivalView`, `GeneratingLoadingView`, `State/OnboardingState`, `Services/FirstPodcastOrchestrator`; `SubscriptionManager` after PL6.3 | `hasCompletedOnboarding` is still read by the root ladder; the integrator's root PR replaces it first |
| X10c | G3 podcasts | `DarkPodcastsView`, `DarkAudioPlayerView`, `AudioPlayerView`, `MiniPlayerView`, `PodcastFlowPreview`, `Components/PodcastPlayer`, `OptimizedAudioPlayer`, `AudioPlayerContainer`, `BottomMiniPlayer`, `DarkMiniPlayer`, `DarkFeaturedPodcastCard`, `FullscreenPodcastCard`, `ViewModels/Transcriptviewmodel`, `Models/TranscriptModel` (after X06b's mirror struct exists) | the ten `podcasts.json` writers go here; X06b runs after |
| X10d | G4 goals | `DarkGoalsView`, `GoalsView`, `Models/GoalsManager` (after PL3.5 reconciles) | `rich_goals` is kept until X06c |
| X10e | G5 you | `LearningAboutYouView`, `ProfilePersonalizationView`, `ScreenTimeDetailView` (if ST moved), `MardownView` | — |
| X10f | G6 settings and the old shell | `DarkSettingsView`, `SettingsView`, `AdvancedSettingsView`, `AppearanceSettingsView`, `AudioSettingsView`, `PrivacyAndSecurityView`, `SupportAndDataView`, `DataManagementSection`, `StorageInfoView`, `IntegrationsView`, `IntegrationsDataView`, `IntegrationsSetupPage`, `Components/SettingsCategoryCard`; then `DarkAppContainer`, `OptimizedTabView`, `MinimalTabBar`, `TopNavigationBar`, `SideOverPanel`, `StackingScrollView` | the old shell goes last, in its own commit; the root becomes the new tabs only |
| X10g | G7 outside | the template widget in `RetrospectWidgets.swift`, the duplicate `Widgets/VoiceRecordingLiveActivityWidget.swift` (app target), `Views/AudioPlaybackLiveActivity.swift`, `Models/AudioPlaybackAttributes.swift`, `RetrospectWidgets/WidgetLinearColors.swift`, `Services/PodcastNotificationService.swift` | **Scheduled local notifications outlive their code.** The same version must remove the old pending requests once (`removePendingNotificationRequests(withIdentifiers: ["weekly-reflection-reminder", "midweek-checkin"])` and every `podcast-` prefix) before the service file goes, or old reminders keep firing with emoji copy and taps that route nowhere. The `ShowPodcastFromNotification` bridge (PL5.3) goes too. The founder re-adds the new widgets if the system dropped the template one |

Tests (each): the app builds; the full suite passes; `no reference to <type> remains` (grep per removed type); the flow's UI test (T03–T06) still passes; X10g adds `(unit) upgrading removes the old local reminders once`.

Proof: the deleted line count; the flow's UI test output; the ledger diff.

---

## Proof

### T05d · The outside flow test                                            size: M
Place in the tree: outside › proof › T05d
Repo · branch: NPRdoinglaundry · `ui/T05d-outside-flow` (with the integrator, who runs the device half)
Needs: P34, P35, P36, P37, PL7.4, PL7.9, PL7.11      Unblocks: ship gate G7

Why: one test proves Retro works outside the app: saving from another app exactly once, the widget, the lock screen and notification taps.

Spec, the scenarios (XCUITest on sample data first, then `-Environment local` on staging, layer 9):
1. **Share online:** Safari on a local test page → share → Retrospect → the card shows the site, then the read (fixture) → add a typed why → save → "saved" → open the app → the journal shows the entry once.
2. **Share offline:** airplane mode → share → save → "it'll send next time" → back online → open the app → the entry appears once; the server has one entry (staging check by count).
3. **Share signed out:** sign out → share → "open retrospect to finish signing in"; the inbox is empty.
4. **Widget:** `-WidgetSnapshot widget.snapshot.ready` → add the medium widget → tap play → the brief plays without the app opening (the player's debug state) → the widget shows pause.
5. **Widget talk:** tap talk → JR-1 with the composer focused.
6. **Lock screen:** play the brief → background → Now Playing shows "today's brief" with no words (detail off) → turn detail on in debug → the title becomes the part.
7. **Notifications:** `simctl push` each push fixture → tap → the right page (brief → JR-2, play → JR-2 playing, question → YO-4, unknown kind → the app with nothing routed).
7b. **Custom text:** with the content door stubbed, a pushed fixture shows the door's custom title and body. With the door down, it shows the payload's custom fallback (on a device; the simulator runs service extensions on iOS 18+, so check it there first).
8. **One a day** (staging, backend): schedule a brief-ready and a question on the same local day → one alert arrives.

Acceptance: all eight pass on sample data in CI (nightly) and once on staging before G7, with the device-only parts (4, 6) recorded on the founder's phone.

Tests: the eight above, named as sentences in the test file:
- `a link shared online arrives once`
- `a link shared offline arrives once after reconnecting`
- `sharing while signed out saves nothing`
- `play from the widget plays the brief`
- `talk from the widget opens the composer`
- `the lock screen shows no words by default`
- `each notification opens the right page`
- `a notification shows its custom words, or its custom fallback when they can't be fetched`
- `two notifications on one day deliver one`

Proof: test output; recordings of 1, 2, 4, 6 and 7; the staging count for 2 and 8.
