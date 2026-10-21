# Design reference for the M14 UI build (C15–C40, S10, extra parts, 37 screens)

Compiled 21 Oct 2026 (read-only research) from the working tree of `/Users/shauryanarang/Projects/retrospect-main` plus `origin/main` (a679fec, #51 merged). Purpose: one place with every spec detail a SwiftUI engineer needs so nothing is assumed. Where sources disagree, section F names the newest source.

## 0. How to read this file

**Source precedence (from `docs/design/m14-agent-checklist.md` §2, founder 21 Oct):**
1. **Paper is the truth.** File `01M5D5J321P5X86ZT58002B7NT` (archive `01M5EJJ62QQ1KG533TDSJR1RFV`, dark file "Retrospect · dark"). Take values with `get_jsx` (includeNodeIds false) and `get_computed_styles`, never from screenshots. Prefer `06 · everything · latest` and the `c · …` masters on `02 · components` over legacy boards. When Paper and a `.md` spec disagree, Paper wins; list every mismatch in the PR.
2. Then the newest founder comment (dated) in `docs/design/ios-build-notes.md` / `docs/second-brain/findings-log.md`.
3. Then `docs/design/progressive-blur.md` (single source of truth for every blur; supersedes build notes).
4. Then `design-system/principles/motion-system.md` (motion), `design-system/principles/screen-rules.md` (founder's latest word over craft/keys).
5. Then the component spec in `design-system/components/*.md` (many are 20 Oct and stale in places, see F).
6. Repo JSX snapshots (`design-system/hifi/p61_onboarding_end.jsx`, `p63_connect_paywall.jsx`) and `docs/design/core-screens/*.png`, `docs/design/onboarding-screens/*.jpg` are **older snapshots / mid-fi** and are superseded by Paper (details in E/F).

**Tokens:** the working tree's `design-system/tokens/tokens.json` is **stale**. `origin/main` adds `motion.spring.snappy/settle/pop/gentle`, `motion.curve.move`, `motion.scale.pressSmall` (0.94), `motion.appear.rise` 8pt, `motion.appear.blurFrom` 8pt, `motion.shake.distance` 6pt, `motion.life.floatAmplitude` 2pt, `motion.life.floatPeriod` 5000ms, `motion.life.resumeAfter` 4000ms, `motion.scrollLag.maxOffset` 6pt, `motion.scrollLag.maxTilt` 1.5, `motion.staggerMax` 6, `size.meter` 4pt. Tokens added only in open PRs (not on main at time of writing): `text.placeholder` (#53), `size.fieldWell` 36 (#53), mic well 40 (#54), top-bar icon button 36 (#44), `radius.style = continuous` → `RShape.rect/RShape.pill` (#55). **No `gradient.*` tokens exist** in tokens.json even though specs cite `gradient.glowPrimary`, `gradient.meshMorning`, `gradient.fadeToCanvas`, `gradient.meshSheetGlow`: gradients/meshes are hand-built (handoff "Tokens in Swift") from palette + `glow.*` tokens; mesh recipes are in `design-system/hifi/mesh.py`.

**Built parts to reuse (never rebuild)** — checklist §4. On main: `RSymbol(name:size:tint:)`, `RIconWell`, `RHairline(.full/.afterIcon)` (border.strong), `RSourceStatus`, `RStatusDot`, `.rPress`, `.rAppear`, `.rPop`, `.rShake`, `.rBlurReplace`, `.rFloat`, `.rLifeHost`, `rWash`, `rSunken`, `rRaised`, `rSecondary`, `rLit(pressed:)`, `RTextStyle`, `RButton` (#43 merged), `RWaveform` (#40 merged). In review: `RProgressHairline`, `RKnowsYouTrack`, `RSpinner(diameter:)` (#38; use for every pending ring, never `ProgressView`), `RArtwork` (#42), `RIconButton` (top bar 36, in field 32, bubble 44; #44), `RPill` neutral/raised/action (#45), tag (#46), settings row (#47), toast `RToast.Look` (#48), C07 switch (#50), C08 segmented (#51 merged), C10 source row (#52), C12 search field `RSunkenField` (#53), C13 composer (#54).

**Status of the components in this file** (m14-progress-map): C15–C20, C22–C40, S10 all `todo`. Checklist queue: C15–C16, C17–C18, C19–C20, C22–C25, C26–C33, C34–C37, C38–C40 all "⚪ free". One agent at a time.

**Global craft defaults that apply to every component below (not repeated per component):** 44pt hit area (pad the frame); squircle corners via `RShape` only; strokes inside (`strokeBorder`); true pills radius = h/2; press 0.98 large / 0.94 small, in 80ms (`pressIn`) out 240ms (`pressOut`) via `.rPress`; springs only from `RMotion`; haptics only where stated; one lit object per screen; Reduce Motion = 140ms cross-fade (modifiers handle it); Reduce Transparency = blurs → solid; Increase Contrast = greys one step darker, 1pt `border.control` rings; Dynamic Type to accessibility 3 (minHeight not fixed height); VoiceOver reads each thing once; never colour alone; lowercase labels; Geist for labels, mono only for figures that count; focus rings are not drawn — rely on system Full Keyboard Access focus (founder 20 Oct: "are these selected states?").

---

# A. Components

Template per component: spec file · Paper ref · anatomy · variants · state table · accessibility · taken out · edge cases · build notes (quoted) · signature moment · screens. "No spec file" is stated explicitly where true.

---

## C15 · talk button

- **Spec:** `design-system/components/talk-button.md` (drawn: Paper "components · 01 actions and controls (talk row) · 05 states, dark and access" — legacy c1/c5 boards).
- **Important status note:** the founder replaced the 72pt talk button in onboarding with the voice composer ("Taken out: the big 72pt talk button, the separate 'type' bubble…" — `voice-composer.md`). Journal uses the composer's mic well, and "Journal opens with the mic off; listening starts only when you tap the mic" (build notes, Journal pages). **No approved hi-fi screen in the 37 is known to use the 72pt talk button.** Confirm in Paper before building; it may be obsolete (see F, founder question).
- **Anatomy:**
  - body: 72 round (`size.voice.button`), primary glow stack: OKLCH body (`gradient.glowPrimary` — hand-built from `glow.primary.gradientTop/Bottom`), lower edge, inner bloom, 2pt ring, halo 16, sky cast (`depth.tint.primary`), grain `material.grain.primary` (seed 19, intensity 0.2).
  - glyph: icon `mic`, 28pt, white, centred by mass (capsule, not the stand).
  - typing alternative: beside it, a 44 *wash* bubble with icon `keyboard` and "type" under it in mono 11 (conflicts with the almost-no-mono rule → would be Geist).
  - hit area: 88 round.
- **Rules:** MUST haptic at each turn (`listenStart`, `listenStop`, `turn` when it hands back); MUST offer typing beside it; NEVER cut off for a short silence — wait 1.4s quiet, then "still listening"; MUST show state in words under it ("your turn", "listening", "thinking", "speaking").
- **States:**

| State | Look | Motion | Haptic |
|---|---|---|---|
| rest (your turn) | as anatomy | none | none |
| pressed | 0.94, pressed gradient (`glow.primary.gradientTopPressed/BottomPressed`) | 80 in / 240 out | `press` |
| listening | lit gradient (`…Lit`); five white bars (3 wide, 2 apart, up to 32 — `size.voice.barWidth/barGap/barMax`) follow your voice; one 88pt 1pt ring at 25% breathes out | `voicePulse` 1200ms | `listenStart` |
| thinking (pending) | bars settle into three dots; halo at half | `typing` 900ms | `listenStop` |
| speaking | body turns ink (`voice.speaking`), no glow; bars follow Retro's voice; tap to interrupt | bars only | `turn` when it ends |
| focused | 2pt `border.focus` ring 4pt outside the halo (not drawn per founder) | — | — |
| disabled (no mic permission) | `surface.control`, icon `mic-off` in `text.label`; "type instead · allow the mic in settings" | — | — |
| error (didn't catch that) | returns to rest; "I didn't catch that, try again" | 200ms | `warning` |
| offline | disabled look; "needs a connection to talk; you can still type" | — | — |
| empty, loading | n/a (conversation shows its own loading) | — | — |
| dark | glow dark values; speaking uses dark ink (lighter); bars stay white | — | — |

- **Accessibility:** labels "talk" / "stop listening" / "interrupt"; announces "listening" and "your turn"; AX3: button keeps 72, words under it grow and wrap; Reduce Motion: rings don't breathe, bars become one level meter; RT: no change; IC: speaking ring 100%, state words `text.primary`; contrast of white glyph on sky = the open lit-label decision (accessibility.md "The lit label: your call": b deeper sky or c ink label, recommended c).
- **Taken out:** two breathing rings + wash → one ring; no timer while listening.
- **Edge cases:** headphones mic → same, haptics matter more; phone call → stops, keeps what was heard, "paused"; answer over 2 min → "still listening" at 1:45, ends at 2:00 keeping what was heard.
- **Tokens:** `glow.primary.*`, `depth.tint.primary`, `material.grain.primary`, `voice.listening/speaking/waveIdle`, `size.voice.button/barWidth/barGap/barMax`, `surface.wash/control`, `text.label/primary`, `border.focus`, `motion.duration.voicePulse/typing`, `haptic.press/listenStart/listenStop/turn/warning`.
- **Motion system:** listening field / talk: `listenStart` and `listenStop` fire (§6).
- **Signature moment:** relates to M02 (listening) only if used.
- **Screens:** none confirmed among the 37 (onboarding and Journal use C14 voice composer). Reuse `RWaveform` (S12) for bars.

---

## C16 · listening field (voice-level glow)

- **Spec file: none.** Defined only by: `motion-system.md` §6 "Listening field"; microinteractions #2; `voice-composer.md` listening state + three founder notes; build notes "Composer · listening look (c-mi7i0c)"; findings c-tmcs3y (ON-4a irregular glow).
- **What it is (best reading of the sources):** the blue "Retro is listening" light around/below the voice composer bar, whose strength follows the live voice level. It is blue job #2 ("Retro is listening"), never a lit action (build notes: "The listening glow is the blue listening job, not a second lit action").
- **Motion (motion-system §6):** "The glow rises from the bottom edge on `gentle`, then follows the voice level live (smoothed over 120ms, capped at 1.3×). `listenStart` and `listenStop` fire." Microinteraction #2: "The listening field glows from the bottom edge, and the glow's height follows your voice level live" (`duration.voicePulse`); founder answer: "follows your voice level live, capped so it never jumps".
- **Look (newest, voice-composer.md third pass + build note c-mi7i0c):** no solid outline / no accent stroke; edge a fine **0.5pt `glow.primary.ring`**; light an **even `glow.primary.halo` all round: radius 24, spread −6, no y offset (0 0 24 −6)**; bar stays raised white inside, **no sky wash inside the bar**; level bars lower and quieter, heights **6/10/14/9/5** (max 14). Thinking uses the same look.
- **Screen-specific variant (ON-4a only, c-tmcs3y):** four offset glows — deeper `sky.400` pooling left, pale `sky.200` lifting right, `sky.500` shadow under the right, faint `amber.200` warmth top-left; "reads as light moving, not a ring". The composer master keeps the even halo "until the founder says this should be the rule".
- **Superseded looks (do not build):** 1.5pt `voice.listening` ring + 4pt `glow.primary.ring` (first); 1pt `voice.listening` hairline + halo below 0 10 28 −10 (second; still in build notes "Composer (more)").
- **States:** off (no glow) → rising (gentle) → live (level-driven, smoothed 120ms, ≤1.3×) → thinking (same look, bars → three dots `typing` 900ms) → off on stop (exit faster than entrance, ~65%; `curve.exit`). Speaking (Retro): no ring, bars in `voice.speaking`.
- **Reduce Motion:** glow appears/disappears with 140ms fade; level becomes one level meter (voice-composer a11y); no live height motion. RT: halo is a shadow, keep; IC: n/a in sources. Pause when app backgrounded.
- **Accessibility:** announce "listening" (composer label "answer field, listening").
- **Signature moment:** **M02** (ON-3–9). Also used in JR-1 talking state.
- **Screens:** ON-3–9 (all question screens), ON-10, JR-1 (talking/thinking states). Built inside/with C14 voice composer; reuse `RWaveform`.
- **Gap:** "glow rises from the bottom edge" (screen bottom vs bar's edge) and the meaning of "height follows voice level" vs "even halo all round" are not reconciled; check Paper part 07 listening tile and ON-4a.

---

## C17 · top bar (entry, settings, tab title)

- **Spec file: none.** `ios-handoff.md` lists "Top bar | title-menu.md" but title-menu.md specifies only the title menu. Sources: handoff §2 + §3 Settings bar; build notes "Top bar"; consistency-pass §3 rule; findings (part 06, onboarding back fix c-zi8796, YO-1 c-j3iuy3); Paper master "c · top bar · journal" (part 06, approved; states collapsed, scrolled).
- **Variants:**
  1. **Tab, Journal** (part 06): drawer (all-journals) button leading (36 visual, 44 hit — screen-rules 33), inky large title "journal" leading after it at rest; **collapsed**: small centred Geist name, drawer button fixed. Trigger: "As soon as the thread scrolls or the composer gets focus, it collapses… Animate the title shrinking into place (a matched-geometry move, ~300ms spring), and reverse when you scroll back to the top with the keyboard down."
  2. **Tab, other tabs**: inky large title leading ("podcasts" — no drawer button, "the drawer is Journal's alone"; "goals" with a wash `+` icon button trailing; "you" with trailing "list" wash pill + your picture (opens settings), avatar aligned to the field's right edge). Podcasts title may host the title menu (C20).
  3. **Settings bar** (ST-2…ST-9, YO-5): back (36 wash in 44) · small centred page name **Geist 14 medium `text.secondary`** · 44 spacer. ST-1 root has back as well (fixed bug c-nvmlvp: wrapper is a flex column under the status bar).
  4. **Entry / single-item pushed** (JR-4, GL-2, YO-3): back · edit; **no title** (rule, consistency pass 21 Oct: "lists and settings pages get the small centred title; single-item screens get none"). Editing JR-4: "cancel · 'edit this entry' · save, with save in plain ink."
  5. **Onboarding**: quiet back arrow top-left (32 wash control on the 24 margin, 44 hit), page label centred (screen-rules 6), right side empty per screen-rules (but part 42 draws "skip" right — see F). Sits `spacing.4` below the 3pt progress bar (c-zi8796).
  6. **Sheet header** (player/PC-3/YO-4): see C23 (mark 22 + "your weekly episode" + `today` tag; share/close 34 visual wash circles in 44; PC-3 has ‹ back + ⌄ close; YO-4 "person · priya" + dismiss chevron).
- **Edge / blur:** Journal top: progressive blur "grows with scroll, up to ~80pt, 8pt max, canvas tint; appears only once content has scrolled under the bar" (progressive-blur.md). Build note: "keep the blend and blur under the bar, but build it properly: one variable blur… never two stacked copies."
- **Icon buttons:** `RIconButton` top-bar size 36 (#44).
- **States:** rest (large) · collapsed/scrolled (small centred) · pressed (button 0.94; title-menu source dims 0.7 for 66ms) · focused (system) · disabled/pending/error/empty/loading: n/a (page owns) · dark (canvas; text tokens).
- **Accessibility:** title is a header trait; buttons named ("all journals", "back", "edit", "settings", "list"); Reduce Motion: collapse is a 140ms cross-fade (no matched move).
- **Signature moment:** none.
- **Screens:** every screen (variants above).
- **Gap:** no written spec for sizes of the large inky tab title (use `type.display.title` 34 Exposure −20 / `tracking.title`) — take from Paper part 06 master.

---

## C18 · tab bar

- **Spec:** `design-system/components/tab-bar.md`. Paper: part 04 A, master "c · tab bar" on 02 · components (approved 20 Oct); synced in M13 (`c:tab-bar/item/selected|rest`).
- **Anatomy:**
  - bar: 49 + home-indicator inset (`size.tabBar`); **no plate, no line**.
  - edge (newest, `progressive-blur.md`): band **~70pt (17 Pro) / 60pt (SE)** above the tabs (shortened 20 Oct c-81biud), max blur **14pt with saturation ×1.5**, canvas tint at `opacity.disabled` over only the bottom ~56pt; **under the tab bar itself the page is opaque canvas**; must keep colour, never grey; eased ramp blur(t)=max×t². iOS 26: `.scrollEdgeEffectStyle(.soft, for: .bottom)`; iOS 17–18: one `UIVisualEffectView` masked by a `CAGradientLayer`, never stacked bands, never a blurred copy, never private `CAFilter` variableBlur. Reduce Transparency: drop the blur, keep tint ending fully opaque.
  - items: four equal slots of 72 (SE: shrink, never < 64); 22pt icon (`journal`, `podcasts`, `goals`, `you`) over Geist 11 lowercase label, 2pt apart; pair centred by mass.
  - selected: icon emphasis (outline grown 0.225 a side = 2.2 stroke; "export both weights per tab icon") + label Geist 500 `text.primary`, icon `text.primary` (handoff M13). Others: 1.75 outline `icon.muted`, label Geist 400 `text.label`. **Selection by weight, never colour/tint.**
  - mini-player floats 12pt above it, never inside.
- **Rules:** MUST stay four tabs; NEVER badge counts; MUST change weight not colour; MUST scroll page to top when its selected tab is tapped again (on `gentle`, motion-system).
- **States:**

| State | What changes | Motion | Haptic |
|---|---|---|---|
| rest / selected | weights above | none | none |
| pressed | icon+label dim to `opacity.pressed` (0.7) | instant, back 240ms | none |
| change | old weight down, new up; page cross-fades | 140ms (+ see motion below) | `tab` (selection) |
| focused | system | — | — |
| disabled/pending/error/empty/loading | n/a | — | — |
| offline | no change | — | — |
| dark | dark tokens; selected `text.primary`; others 3.3 : 1 | — | — |

- **Motion system §6:** "The selected icon does `.symbolEffect(.bounce)`, once, with `tab`. The label weight cross-fades. Tapping the current tab scrolls to top on `gentle`." motion-moments: "one-frame 'emphasis' swap (outline → emphasis) with a tiny scale settle" (`duration.fast`, `scale.press`). NOTE icons are custom template images, not SF Symbols, so `.symbolEffect` won't apply (see F).
- **Accessibility:** "journal, tab, 1 of 4, selected"; AX3: labels hide, long-press large-content viewer, icons stay 22; IC: inactive icons `text.secondary`; RT: `material.reducedTransparency` solid; RM: weight change without cross-fade; contrast inactive icon 3.3, label 5.2.
- **Taken out:** badges, colour selection; labels kept (goals vs you ambiguous).
- **Edge cases:** SE slots shrink ≥ 64; something playing → mini-player above, content insets by both.
- **Build notes:** "no bar plate; … progressive blur that starts ~90pt above the tabs" (superseded by ~70pt); "one variable blur, not stacked bands"; "lets do this (version A): system tab bar position and slots; selection by weight (2.2 emphasis outline) and Geist 500 label, no tint." Handoff: "In SwiftUI: one `TabBarItem(state: .selected/.rest)`. Never recolour an icon on its own."
- **Gap:** emphasis glyphs exist only for journal (findings 20 Oct: "The icon set needs three emphasis glyphs") — check `design-system/icons/shipped`.
- **Tokens:** `material.bar`, `material.reducedTransparency`, `text.primary/label/secondary`, `icon.muted`, `icon.weight/weightEmphasis` (token value "semibold"), `size.tabBar`, `opacity.pressed`, `haptic.tab`, `font.family.label`.
- **Screens:** JR-1, PC-1, GL-1, YO-1, YO-2, ON-13 (and JR-3 page under drawer). Hidden in onboarding, paywall, full player, sheets.

---

## C19 · sheet and dialog

- **Spec:** `design-system/components/sheet-and-dialog.md`; choreography in `player.md`; dialog part 24 (delete dialog, approved master); AC-2 `c:sheet/sign-out`.
- **Anatomy — sheet:** overlay tier (`depth.tier.overlay`); top corners `radius.sheet` 38 continuous; grabber 36 × 5 (`size.grabber.width/height`, `border.strong`, 10pt below top); detents `layout.sheetDetent.medium` (0.5) or full; page behind scales to 0.94 (`motion.scale.behindSheet`), corners `radius.behindSheet` 12, dims (`background.scrim`; player says scrim fades to 40%); a 10pt strip of the page shows above; behind-sheet fill `background.underlay` (new token); max width `layout.sheetMaxWidth` 560; sheet surface **`background.raised`, never canvas** (build notes 21 Oct); 1pt white top edge (`border.highlight`) + hairline `0 −1 0` black 20%.
- **Anatomy — dialog:** overlay; full width inside margins (**342 on a 390 screen**; part 24); radius `radius.field` (12, founder "sharper"); padding 24; title serif 22; one line of what happens; two stacked buttons: confirming (destructive or primary) above "cancel" (secondary). Delete dialog: "centred, over a dimmed page. The destructive button follows the refined danger recipe (no outer ring or halo)." `haptic.warning` on touch down of "delete it" (build notes Entry); "the dialog is the only place a destructive glow appears".
- **Sheet spacing (build notes):** "title+line (8), related note (16), break (32), actions (4 between primary and cancel). Never one even gap for everything."
- **Sheets flex (handoff):** flexible middle (`minHeight: 0`) so bottom controls stay on screen on SE; content scrolls, controls don't. `.scrollClipDisabled()` so raised cards' shadows aren't clipped.
- **Rules:** MUST drive sheet, scale behind and scrim from one progress value; MUST say exactly what will happen ("this deletes your journal, episodes and map. it can't be undone."); NEVER stack two sheets; NEVER dialog for undoable choice (do it, offer undo toast).
- **States:**

| State | Look | Motion | Haptic |
|---|---|---|---|
| opening / open | player choreography | `spring.sheet` (0.40/0.86) | `sheetSnap` (soft) at each resting height |
| dragging | follows finger 1:1; background scales back in step; rubber band past top (0.55) | 1:1 | — |
| closing | past 140pt or 800pt/s (`motion.gesture.dismissDistance/Velocity`), carries velocity | `spring.sheetDismiss` (0.32/0.90) | — |
| pending (dialog confirm) | button pending (dots over kept label); cancel disabled | — | — |
| error | dialog stays; one line `status.dangerText` | — | `error` |
| focused | focus trapped in sheet | — | — |
| loading, empty | content shows its own; a sheet never opens empty | — | — |
| offline | dialog confirm disabled, "needs a connection" | — | — |
| dark | `background.raised` dark; scrim black 60% | — | — |

- **Accessibility:** escape gesture closes; title read first; dialog is an alert, cancel default for destructive; AX3: sheet opens full height, dialog scrolls; **Reduce Motion: "fade and 24pt slide; no scale behind"** (motion-system says plain 140ms cross-fade — see F); RT: scrim solid 60%; IC: sheet top edge 1pt `border.control`.
- **Taken out:** no close button on grabber sheets (except accessibility escape); no icons in dialogs.
- **Edge cases:** keyboard up → sheet rises with it, never covers the field.
- **AC-2 sign-out sheet** (`c:sheet/sign-out`, approved): over ST-9; scrim `night-900` at `opacity.disabled`; grabber 36×5; "sign out?" display `text.2xl` tracking.title leading.tight; what stays (body, secondary: "your entries, episodes and everything retro knows stay safe. sign back in with apple any time."); unsent row only when something is unsent (surface.wash, radius.panel, padding 12/16: spinner + "1 entry hasn't sent yet" text.md medium / "it goes first, so nothing is lost." Geist sm label); lit "send, then sign out" (`size.control.hero` 60 high) or plain "sign out" when nothing waits; text "cancel" (text.link, 44 high). Spacing by group: title+line 8 → unsent 16 → break 32 → actions 4. **Sheet fill must be `background.raised`** (queued Paper fix; snapshot shows canvas).
- **Tokens:** `radius.sheet/panel/field`, `size.grabber.*`, `layout.sheetDetent.medium`, `layout.sheetMaxWidth/dialogWidth` (300 — conflicts with 342 drawn), `background.raised/scrim/underlay`, `layer.sheet/dialog`, `motion.spring.sheet/sheetDismiss`, `motion.scale.behindSheet`, `radius.behindSheet`, `motion.gesture.*`, `status.dangerText`, `border.control/highlight/strong`, `haptic.sheetSnap/error/warning`.
- **Screens:** JR-2, PC-2, PC-3, ON-11 (player sheet); YO-4 (node sheet); AC-2 (sign-out sheet); JR-4, ST-4, ST-5, ST-9 (dialogs: delete entry, disconnect/delete what it read, delete my data, delete account); value pickers (ST-2 time).

---

## C20 · menu / title menu

- **Spec:** `design-system/components/title-menu.md` (measured from the founder's recording, 30fps). Paper c4 title-menu filmstrip. Related menus: player "…" menu (build notes), value-row ↕ menu (decision 04 B), message long-press menu (message.md).
- **Use:** a page with 2–4 views of the same feature (Podcasts: episodes · briefs · saved; You: map · list). Not for settings (switch row) or >4 options (sheet).
- **Anatomy:**
  - source: page title (display serif) + up-down glyph 12 × 16 `icon.muted`; whole title is the button, ≥ 44 tall.
  - menu: anchored under the title's leading edge; width hugs longest option (min 196); radius `radius.popover` 22; white (`background.raised` in dark); 0.5 warm hairline; `elevation.popover` (wide `0 18 40 −10` cast + tight `0 2 6` contact); 4pt inner padding.
  - rows: `size.popoverRow` 50; text 15; selected row on a `surface.wash` pill radius 18 (concentric 22 − 4) with the thin ink check (18, `ink.default`, no disc) trailing.
  - veil: `background.veil` (6%) over the page.
- **Choreography (measured):** 0 touch down → 0–66ms title dims to `opacity.sourcePressed` 0.7 (`motion.duration.sourceDim`), nothing else moves → 66ms menu appears at `motion.scale.popoverFrom` 0.86, blurred `motion.blur.enter` 8, opacity 0 → 66–200ms grows toward bottom-trailing on `spring.popover` (0.30/0.74), sharpening, subtitle cross-fades out, veil fades in → ~200ms ~3% past full size → ~230ms settled + `select` → select: pill slides to the chosen row (spring 0.25/0.85 ≈ `snappy`), check cross-fades, menu closes after 120ms, page content cross-fades → close: backwards and faster, `popoverExit` 110ms ease-in (`curve.exit`), shrinking into the title with blur; subtitle fades back. Tap outside, swipe up, or tap title closes. Long-press + slide + release selects in one gesture.
- **States:**

| State | Look | Motion | Haptic |
|---|---|---|---|
| rest | title + glyph | — | — |
| pressed | title at 0.7 | `sourceDim` 66ms | — |
| open | menu + veil | choreography | `select` on settle |
| selected row | wash pill, thin ink check | pill slides | `select` |
| disabled row | `text.tertiary` + reason ("saved · nothing yet") | — | — |
| empty | a view with nothing still appears, "nothing yet" | — | — |
| pending/error/loading/offline | n/a | — | — |
| dark | `background.raised` dark, hairline white 8%, cast black 45%, veil black 20% | — | — |

- **Rules:** press registers before open; close faster than open; grow from the title, never screen centre; never dim more than the veil.
- **Accessibility:** "podcasts, showing episodes, menu"; rows a list, selected marked; RM: fade in place at full size 140ms, no blur/overshoot; AX3: rows ≥ 50 grow, menu widens to screen − margins then wraps; IC: 1pt `border.control` ring; RT: veil 10% solid, no blur behind.
- **Taken out:** icons and descriptions in rows.
- **Edge cases:** title near trailing edge → grows toward leading; rotation/tab change while open → closes without selecting.
- **Player "…" menu (build notes):** "raised panel, 44pt rows, Geist 500: chapters › (pushes the chapter list), download. Use a native `Menu` styled to match. The founder hasn't confirmed the menu's other items yet." AirPlay lives in more (player.md).
- **Value-row menu (settings):** rows ending ↕ open a menu in place (decision 04 B).
- **Message long press:** "the line lifts (raised card) and a menu: copy · correct this · why you said this ›" — popover spring, `longPress` haptic.
- **Tokens:** `radius.popover`, `elevation.popover`, `size.popoverRow`, `background.raised/veil`, `surface.wash`, `ink.default`, `icon.muted`, `opacity.sourcePressed`, `motion.spring.popover`, `motion.duration.popoverExit/sourceDim`, `motion.scale.popoverFrom`, `motion.blur.enter`, `haptic.select`. (Spec also lists `surface.control` — stale; founder: control pill "read too dark".)
- **Screens:** PC-1 (if Paper shows "podcasts ⇅"), YO-1 (map/list — Paper shows a "list" wash pill instead; confirm), PC-2/JR-2 "…" menu, ST-2/ST-7 value rows, JR-1 message long press.

---

## C22 · mini-player

- **Spec:** `design-system/components/mini-player.md`. Paper part 45 (approved 20 Oct; master on 02), PC-1 board.
- **Variants:**
  - **floating** (app): width = screen − 2 × screen margin (354 on 402; SE: screen − 2 × 20) × **64** high, `radius.control` (pill), floats 12pt above the tab bar.
  - **paywall** (ON-12 option A, approved 21 Oct): the founder chose "the 64pt paused mini-player" at the top of the paywall (paused, play icon, hairline progress) — findings c-5hyjn9. (Spec's older "286 × 42, radius 20, #F9F7F5, elapsed mono 14, 150-wide 3pt scrubber" variant is superseded.)
- **Anatomy (floating, bottom → top):**
  1. soft edge above the tab bar: content under it passes through progressive blur + eased fade (iOS 26 `safeAreaBar`).
  2. shadows: floating tier `depth.tier.floating` — wide warm `0 10 30 −10` 30%, mid `0 4 10 −4`, contact `0 1 1.5` (`depth.shadow.ambient/cast/contact`).
  3. body: `background.raised` at 92% over `material.bar`; 0.5 warm hairline outside; 1pt white inner stroke brighter on top.
  4. artwork: 44, radius 22 (concentric 32 − 10), mesh per kind (S14 `RArtwork`) with grain, casting its colour (`depth.tint.artwork` — not a token on main; see F).
  5. title: text 14 semibold, one line, ellipsis; subline: Geist 12 `text.label` "chapter 2 · the standup · 8 min left" (not mono). Build note: "the title column flexes to fill; both insets 10."
  6. play well: 44, wash (`surface.wash`), icon `play`/`pause`.
  7. progress hairline: **2pt along the bottom inside edge, `player.progress`, clipped by the radius** (option A — the founder liked A; B ring, C fill, D chapters archived, c-4d5kcg). Linear (real time) — allowed exception.
- **Rules:** MUST open the full player on tap with title morphing into the sheet's title; MUST stay visible on every tab while loaded; NEVER cover content without the soft edge; NEVER glow; MUST be the only control for what's playing (hero tile on PC-1 drops its lit play while its episode plays).
- **States:**

| State | Look | Motion | Haptic |
|---|---|---|---|
| rest (paused) | play shown | none | none |
| playing | pause shown; hairline advances | `playMorph` 180ms (`.contentTransition(.symbolEffect(.replace))` — but glyphs are custom; see F) | none |
| pressed (body) | 0.98; shadows tighten toward contact | 80/240 | none |
| pressed (play well) | 0.94; well → `surface.washPressed` | 80/240 | `press` (spec) |
| pending (buffering) | play well shows a 2pt ring turning (`RSpinner`); time holds | `spin` 900ms | none |
| error (failed) | subline "couldn't play · tap to retry" `status.dangerText`; play → icon `retry` | blur-in 220ms | `error` |
| offline | plays if downloaded; else failed with "offline" | — | — |
| focused | system | — | — |
| disabled/empty/loading | n/a (exists only when loaded) | — | — |
| dark | `background.raised` dark 92%, inner stroke white 8%, shadows black 45%; artwork uses dark palette twins | — | — |

- **Motion:** appears: rises 12pt + fades in (standard curve, 280ms) the first time something plays; swipe left/right skips back/forward 15 (content shifts 4pt and returns); swipe down hides it (stays in Podcasts) + `select`; tab change: doesn't move. Mini ↔ player: `matchedGeometryEffect` on artwork, title and play on `spring.sheet` (motion-system §6). motion-moments: "the hero artwork flies down into the mini-player thumb (matched geometry)", `sheetSnap`.
- **Lock screen / background:** now-playing title, "retrospect" artist, artwork, skip 15/30, chapter as subtitle; audio continues when the app closes (brief included).
- **Accessibility:** one element: "now playing, <title>, 4 minutes 12 seconds in; double-tap to open"; custom actions play/pause, skip back 15; AX3: grows to 80 tall, subline hides (in label), title 2 lines; RM: fade only, no swipe shift; RT: body opaque, scroll edge solid band; IC: hairline 1pt `border.control`, progress 2 → 3pt; contrast subline 5.2, play icon 5.8 on wash.
- **Taken out:** skip-back button (swipe does it); rolling time in subline.
- **Edge cases:** long title → ellipsis; queue → current only; small phone → width screen − 2 × 20, artwork stays 44.
- **Tokens:** `background.raised`, `material.bar/reducedTransparency`, `depth.stroke.inner/innerTop/outer`, `depth.shadow.ambient/cast/contact`, `surface.wash/washPressed`, `player.progress`, `text.primary/label`, `status.dangerText`, `border.control`, `size.miniPlayer` (**token = 42pt, wrong for floating 64** — see F), `radius.control`, `motion.duration.playMorph/spin`, `haptic.press/select/error`, `layer.miniPlayer` 10.
- **Signature moment:** M06 (player shrinks into the paywall mini-player).
- **Screens:** PC-1 (playing state), JR-1, GL-1, YO-1 (any tab while loaded), ON-12 (paywall variant, paused).

---

## C23 · player (full-screen sheet)

- **Spec:** `design-system/components/player.md`. Paper part 09 (approved master "c · player sheet": ready, playing, held scrub, "…" menu), part 10 (brief items + recap), PC-2/JR-2 boards.
- **Content order:** (1) header row: the mark 22, "your weekly episode", `today` tag; share and close on the right; (2) title in display serif (inky) — the cover; (3) why-it's-here line: one line with the guess marker ("from 6 entries · calendar · steps"), tap → sources sheet (PC-3); (4) live transcript; (5) "correct this part" pill (between transcript and scrubber, leading-aligned, `correct` speech-bubble glyph; hides while scrubbing or "…" menu open); (6) scrubber + times + chapter name; (7) transport. No large artwork. The "chapters" pill is gone ("…" menu holds chapters), "not right" renamed **"correct this part"** which "opens the correction flow for the part being spoken".
- **Anatomy:**
  - sheet: `background.raised`, top corners 38 continuous, 1pt white top edge `border.highlight`, hairline `0 −1 0` black 20%. **"no blue gradient"** (founder): plain raised surface (spec's `gradient.meshSheetGlow` sky light is superseded).
  - behind: previous screen scaled 0.94, corners 12, dimmed (`background.scrim`, fades to 40%), 10pt strip shows above. Status bar stays visible over the strip.
  - grabber 36 × 5 `border.strong`, 10pt below top.
  - header buttons: 34 visual wash circles in 44 hit frames; icons 17pt drawn stroke 2 on the 24 grid.
  - transcript: Exposure `font.family.displayInky`, weight `inkCard` (399), `text.xl` (token 22pt; build notes say 20pt), `tracking.card` (−0.02em), `leading.snug` (1.3), `spacing.5` (20) between lines, width `layout.readingWidth` 326. **Spoken line `text.primary`; every other line `text.tertiary`** (player.md 21 Oct; build notes 20 Oct said past tertiary / next secondary — superseded).
  - edges: true progressive blur — top band **96pt (64 SE)**, bottom band **140pt (80 SE)**, max 8pt (`motion.blur.enter`), sheet colour easing in (top: 0 → 100% over the top 30% of band; bottom: solid for bottom 15%, easing out by the top); spoken line always in the clear middle (on SE the column scrolls so it does); "At the very start of the episode there is nothing above, so no top blur." Never covers "correct this part" or the scrubber.
  - pills: height 36, radius 18, `background.canvas` + 1pt inset `border.subtle`, mono 12 `text.label` (now only "correct this part"; build as wash pill per Paper).
  - surface levels: sheet overlay(4); header buttons/pills wash(0.5); play well + scrubber thumb raised(2); tray + track sunken(−1).
- **Two layout states (build notes 20 Oct):** "Ready = big inky title + from-line above the transcript. On play, the title and from-line scroll up out of view and the header-left swaps 'your weekly episode · today' for the title in Geist 500 14, one line, truncated (same collapse as the top bar). Animate it as a scroll, not a crossfade; respect Reduce Motion (cut instead)."
- **Brief mode (JR-2, part 10):** items instead of chapters; "now" card labelled "playing now", why line "here for your goal: <goal>", source line "from …" with a chevron; "next" rows; played "played · 3 of 3"; quiet day one inky line, a one-part 40-second scrubber, no correct pill. Middle region flexes; scrubber + transport pinned above the home indicator on every device. Scrubber grouping fix (c-ktepmd): scrubber top padding `spacing-8`, transport top padding `spacing-3`; buffered chunk hidden for briefs (load instantly); track vertically centred.
- **Chapter list (PC-2 state):** numbered rows, moving bars on the playing one, "done" to go back (pushed from "…" → chapters ›).
- **Choreography (opening from mini-player or brief card):** touch down 0.98 (no haptic) → release: sheet rises on `spring.sheet` (0.4/0.86); title morphs (matched geometry) from 14 semibold to the 34pt serif while moving → behind scales 0.94, rounds 12, scrim → 40%, one progress value → transcript fades up 8pt with 60ms stagger after the title; controls last → `sheetSnap` on settle.
- **Dragging down:** 1:1; behind scales back and scrim lightens proportionally; rubber band past top 0.55; release past 140pt or 800pt/s → `sheetDismiss` with velocity, title morphs back; else springs back. Drag only from header, grabber or title; transcript scrolls without fighting the sheet.
- **Playing:** play ↔ pause morph `playMorph` 180ms (shipped glyphs centred by their own frame, no manual offset); transcript glides to keep the spoken line at the same height (`transcriptFollow` 420ms, standard curve), colours cross-fade first (90ms) then the column glides; next line sharpens from a 1.5pt blur; scroll the transcript yourself → following pauses, "back to now" pill above the scrubber, resumes after `followResume` 4s idle; tap any line to jump.
- **Skipping/scrubbing:** see C24/C25. **Speed:** tap cycles 1.0 → 1.25 → 1.5 → 2.0 → 0.8×; number rolls (`numberTick` 320ms), `select` haptic.
- **Leaving the app:** audio continues; returning reopens where the transcript was.
- **Rules:** open on title and content, controls last; title is the same object as the mini-player title; one progress value; NEVER auto-scroll while touched; MUST keep the why line; SHOULD fade the transcript into the controls.
- **States:** rest/paused · playing · pressed (see transport) · focused · pending = buffering (play well thin ring turning, `spin` 900ms, time stops) · disabled (a control that can't act dims to `opacity.disabled`) · empty (no transcript → description in its place, same type) · error = failed ("couldn't load this episode", retry; transcript still readable if loaded) · loading (title and why line at once; transcript skeleton bars, shimmer 1400ms) · ended (last line stays; "play next" or "back to journal") · offline (plays if downloaded; otherwise says so) · dark (`background.raised` dark; transcript inks by token) · PC-2 "a guess arriving" (approved guess card placed in the transcript; "correct this part" steps aside) · chapter list.
- **Accessibility:** VO order close → title → why → transcript (text block; current line announced on change only if asked) → scrubber (adjustable ±15s) → transport → pills; AX3: title and transcript grow, transcript shows two lines, controls fixed; RM: sheet fades and slides 24pt, title cross-fades instead of morphing, transcript jumps line to line; RT: scrim solid 60%; IC: past lines 70% (not 55%), tray and pills 1pt `border.control`; every control ≥ 44, pills 36 in 44.
- **Taken out:** "why it's here" pill; large artwork; queue/volume/AirPlay on the face.
- **Edge cases:** long title → 3 lines then ellipsis (full title in share sheet); no transcript → description; brief under 1 min → no chapter ticks, skip forward 15; phone call → pauses, resume only on tap; headphones removed → pause; SE → transcript area shrinks first, title never truncates to one line.
- **PC-3 header (c-rji9hn):** "‹ goes back one step, to the episode's transcript at this exact part; ⌄ closes the whole player to the mini-player (swiping down does the same)" — founder may drop ⌄ (open).
- **Tokens:** `background.raised/scrim/underlay`, `border.highlight/strong/subtle`, `text.primary/secondary/tertiary/label`, `inference.marker`, `font.family.display/displayInky/text/mono`, `layout.readingWidth`, `motion.spring.sheet/sheetDismiss`, `motion.scale.behindSheet/press/scrubThumb`, `radius.behindSheet/sheet`, `motion.gesture.*`, `motion.duration.transcriptFollow/followResume/playMorph/scrubPreview/numberTick/shimmer/spin`, `haptic.sheetSnap/skip/chapterTick/select`.
- **Signature moments:** M09 (play morph, rolling time, chapter ticks); M06 (ON-11 player shrinks into the paywall mini-player).
- **Screens:** PC-2, JR-2 (brief mode), PC-3 (inside the sheet), ON-11 (auto-playing tease, "the week you started").

---

## C24 · transport

- **Spec:** `design-system/components/transport.md`. Paper part 09; c5 states.
- **Anatomy:** (1) capsule 64 high, radius 32, **sunken**: Paper master: "transport recess = `surface.washPressed` (darker than its parent)" (audit masters table) — spec's `background.sunken` + `depth.shadow.sunken` + 0.5 warm hairline is the older recipe; (2) skip back 15 / forward 30: shipped `skip-back-15` / `skip-forward-30` (numerals are part of the path — don't overlay text), 28pt, `text.secondary` (ship as template images tinted `textSecondary`; the SVG carries a raw `#5F5D5B`), in 44 frames; (3) play well 48 round, **raised** (`background.raised`, double stroke, warm contact + cast), concentric 32 − 8 = 24; (4) play/pause `text.primary` (shipped play path centred by its own frame — **no manual 1.5pt offset**, build notes); (5) outside: more (`more`, 44) left; speed (mono 15 tabular `text.secondary`) right.
- **Rules:** play in the middle and largest; morph play ↔ pause never swap; 15 back / 30 forward; NEVER glow the play.
- **States:**

| State | Look | Motion | Haptic |
|---|---|---|---|
| paused (rest) | play shown | — | — |
| playing | pause shown | `playMorph` 180ms | — |
| pressed (play well) | 0.94; cast collapses to contact | 80/240 | `press` |
| pressed (skip) | arrow turns 20° in its direction and back; time rolls | 160ms (motion-system: rotate on `snappy`) | `skip` |
| pending (buffering) | 2pt `text.label` ring turns around the play glyph (`RSpinner`); time holds | `spin` 900ms | — |
| ended | play → `retry` ("play again"); skip forward disabled | morph | — |
| error (failed) | well shows `retry`; one line above: "couldn't load this episode" | blur-in 220ms | `error` |
| offline | downloaded: normal; else skips disabled + "offline · download it to listen anywhere" | — | — |
| disabled | control that can't act: `opacity.disabled` 0.4 | — | — |
| focused | system | — | — |
| empty, loading | loading: buffering ring; empty: n/a (no audio → no transport) | — | — |
| dark | tray carved, not tinted: canvas colour (dark) + deep inner shade at top (0 3 8 + 0 1 2, `depth.stroke.outer` dark), 0.5 inner rim, 1pt light catch on the bottom lip (`depth.stroke.inner` dark); well `background.raised` dark, inner stroke white 8%; dark `surface.washPressed` = black 30% | — | — |

- **Accessibility:** "skip back 15 seconds", "play"/"pause", "skip forward 30 seconds", "speed, 1 times"; AX3: controls keep size, speed grows and moves under the tray; RM: no arrow turn, play/pause cross-fade 140ms; IC: tray 1pt `border.control`, skip icons `text.primary`; all ≥ 44.
- **Taken out:** glow on play; hold-to-rewind/ff; shuffle/repeat.
- **Edge cases:** brief < 1 min → forward is 15; speed taps cycle once per tap only.
- **Build notes:** "the recess is drawn with inner shadows on the canvas colour (deep top shade, light catch on the bottom lip), not a lighter fill"; "visually center this (dark transport): same as the lit play: shipped glyphs, no offsets."
- **Tokens:** `background.sunken/raised`, `surface.washPressed`, `depth.shadow.sunken/contact/cast`, `depth.stroke.inner/outer`, `text.primary/secondary/label`, `border.control`, `opacity.disabled`, `motion.duration.playMorph/numberTick/spin`, `haptic.press/skip/select/error`, `font.family.mono`.
- **Signature moment:** M09.
- **Screens:** PC-2, JR-2, ON-11.

---

## C25 · scrubber

- **Spec:** `design-system/components/scrubber.md` — **partly superseded by build notes** (segments as pills; bubble).
- **Anatomy (newest, build notes + Paper part 09):**
  - hit area 44 tall over the whole line.
  - track: **each chapter is its own capsule with a 4pt gap**; played and loaded fills live inside each capsule and are clipped by it ("this should not be a clean break, it should be like the segments are pills"). Track height 4 (`size.player.scrubber`), sunken `surface.track`; buffered `player.buffered` (two steps paler, never accent; hidden for briefs); played `player.progress` (3.6 : 1 vs track). (Spec's "2pt gaps cut into one line (`player.chapterMark`)" is superseded.)
  - thumb: 12 round (`size.player.thumb`), white, raised (0.5 white inner edge, 0.5 warm hairline, contact `0 1 1.5`, cast `0 4 10 −3`); x from the playback fraction (never a constant; c-zgzgcy); track vertically centred with the thumb.
  - below: elapsed (mono 13 `text.label`, tabular) · chapter name (`text.tertiary`) · remaining with a true minus (−07:18). No total.
- **Held / scrub (newest build notes):** "on long-press drag, the thumb grows 12 → 20 and a raised bubble rises over it… The bubble is one line, the chapter name only (Geist 500 14), in a raised 32pt capsule centred over the thumb. The times stay in the row below and follow the finger, and that row's own chapter label fades out while you hold… It follows the thumb, clamped to the sheet's margins. A selection haptic fires each time the finger crosses into a new chapter. The audio seeks on release, not while dragging." (Spec: thumb 1.6× = `motion.scale.scrubThumb`, time bubble mono 13 `background.inverse`, radius 8, rises 8pt — superseded.) motion-system: thumb grows on `snappy`, time numerals roll; snaps to a chapter within 12pt.
- **States:**

| State | What changes | Motion | Haptic |
|---|---|---|---|
| rest | as above | none | none |
| pressed (held) | thumb 12 → 20 (1.6× token ≈ 19.2), lifts (cast 0 4 10, 16%); one-line chapter bubble rises; transcript previews that line | `scrubPreview` 120ms; thumb on `snappy` | none |
| crossing a chapter | chapter name rolls 6pt | 160ms | `chapterTick` (selection) |
| release | bubble falls and fades; thumb settles; audio seeks | spring 0.3/0.8 (spec; nearest token `popover`) | none |
| focused | system | — | — |
| pending (buffering) | buffered edge pulses; thumb can't pass it | 900ms | none |
| disabled | still-generating audio past buffered edge: track dashed | — | — |
| error | line freezes; player shows failed | — | — |
| empty | no audio → hidden | — | — |
| loading | track only, no played, no thumb | — | — |
| offline | buffered stops where download ends | — | — |
| dark | track dark, played dark (4.1 : 1), thumb white with black 45% cast | — | — |

- **Rules:** 44 hit area; tabular mono digits; never accent for buffered; remaining not total.
- **Accessibility:** adjustable "4 minutes 12 seconds of 11 minutes 30", swipe ±15s; AX3: times grow and stack (elapsed/remaining row, chapter next row); IC: track one step darker, ticks/gaps 3pt; RM: bubble appears (no rise), no roll; RT: no change.
- **Taken out:** total time; tick labels.
- **Edge cases:** < 1 min → no chapters; dragging off vertically keeps scrubbing (finer further away, like iOS).
- **Tokens:** `surface.track`, `player.progress/buffered/chapterMark`, `background.raised/inverse`, `text.inverse/label/tertiary`, `size.player.scrubber/thumb`, `motion.scale.scrubThumb`, `motion.duration.scrubPreview`, `haptic.chapterTick`, `font.family.mono/label`.
- **Signature moment:** M09 (chapter ticks).
- **Screens:** PC-2, JR-2, ON-11.

---

## C26 · brief card

- **Spec:** `design-system/components/brief-card.md`. Paper part 03 **D** (approved: "token-mesh artwork with the play on the seam"); every state drawn inside part 03 (M3); decision 05 A slim bar; master "c · brief card".
- **Anatomy (bottom → top):** (1) cast warm `0 6 16 −8` + contact `0 1 1.5` (card tier); (2) outer hairline 0.5 warm; (3) body: screen width − margins (342 on 390), radius 20 (`radius.card`), padding 18, `background.raised`, 2% top light; (4) inner stroke white 85% brighter top; (5) top line: "today's brief · tue 21 oct" left, "2 min" right (spec says mono 12 `text.label`; Geist per labels rule except the figure); (6) headline: display serif 22/27 inky (`font.exposure.card`, `tracking.card`), lowercase, ≤ 3 lines; (7) play: 44 round **compact glow** (gradient, lower edge, inner bloom, 1.5pt ring, no halo, grain), shipped play glyph centred by its own frame — **the screen's one lit object**, on the seam of the artwork panel (D); (8) what's in it: one line text 14 `text.secondary`. D adds a mesh **artwork panel** (brief = sky recipe, `mesh.py`). Build note: "the headline keeps 48pt clear on the trailing side so the seam play never covers a word, at any width."
- **Slim bar (scrolled, decision 05 A; c-qo8aha):** "12pt padding, 52pt artwork thumb, 40pt lit play, headline up to two lines. It must be taller than the 'brief being made' row (64pt)" (~80 tall). Collapses with the top bar (motion-moments: "the artwork shrinks into the thumb and the headline slides beside it; the play rides along without leaving its glow", `spring.sheet`).
- **Rules:** keeps playing in background/lock screen; says what it's made of when opened; NEVER shown when the brief is off; MUST turn the play glow off while playing (but founder: playing state "unchanged" — see F).
- **States:**

| State | Look | Motion | Haptic |
|---|---|---|---|
| rest (not started) | as above | none | none |
| pressed (play) | 0.94, pressed gradient; card doesn't move | 80/240 | `press` |
| pressed (card body) | card 0.98 | 80/240 | none |
| playing | **card does not change** (founder: "I still prefer this"); mini-player + sheet show playback | — | none |
| played | headline `text.secondary`; artwork corner reads "played" (Geist 500 12); play → raised replay well (`retry`), no glow | 200ms | none |
| quiet day (empty) | one serif line "nothing much moved. enjoy the quiet."; no play | — | — |
| making (loading) | **compact row** (64): 40 `surface.skeleton` well (`radius.panel`) with `brief` glyph `icon.muted`, "today's brief" (Geist 500 14) over "being made · ready by 8:30" (Geist 12 `text.label`); no play; grows into the full card when ready | shimmer on the well | none |
| pending (starting audio) | play shows a turning ring; card stays | `spin` | none |
| error | "couldn't load today's brief" Geist 500 12 `status.dangerText`; neutral pill "try again" with `retry`; artwork panel plain wash | blur-in 220ms | `error` |
| offline | plays if downloaded; else "it'll be here when you're back online", no play | — | — |
| focused | system; play is a separate focus stop | — | — |
| disabled | n/a | — | — |
| dark | `background.raised` dark, inner stroke white 8%, casts black 45%; sky ring 4 : 1 | — | — |

- **Becoming ready (motion-moments):** "the 'being made' row's quiet well blooms into the mesh artwork; the row grows into the full card (matched geometry) and the play lights last" (`duration.reveal`, `spring.sheet`, `reveal` haptic).
- **Accessibility:** two elements — card ("today's brief, <headline>, 2 minutes; double-tap to open") and play ("play today's brief"); AX3: headline `type.ax3.xl` 44/52, subline `type.ax3.md` 36/43, label `type.ax3.sm`; play stays 44 and moves under the text; RM: cross-fades 140ms; RT: no change; IC: 1pt `border.control` replaces the stroke stack, played headline stays `text.primary`; contrast top line 5.2, headline 15, ring 4.
- **Taken out:** ring + coloured text + rolling time + segment bars while playing; check beside "played"; morphing playing state.
- **Edge cases:** long headline → 3 lines + ellipsis; played on another device → played; midnight passes → stays until next pull/app open, never swaps under the finger.
- **SE:** "72 artwork band, no subline" (headline and play stay).
- **Variants used on screens:** JR-1 (today's brief); ON-13 "your first episode is ready · the week you started · 2 min" with mesh artwork + play (lit; p61 snapshot shows a 40 artwork + Geist md/sm row); ON-10 getting-ready = the being-made card variant (see extra parts).
- **Tokens:** `background.raised`, `depth.stroke.*`, `depth.shadow.contact/cast`, `depth.tint.primary`, `glow.primary.*`, `surface.wash/skeleton/track`, `player.progress`, `text.primary/secondary/label`, `status.dangerText`, `border.control`, `font.family.display/displayInky/label`, `font.exposure.card`, `font.tracking.card`, `radius.card/panel`, `size.briefCard.minHeight` 120, `motion.duration.shimmer/spin`, `haptic.press/error`.
- **Signature moment:** none of its own (M05 uses its being-made state; brief becoming ready is a motion-moment).
- **Screens:** JR-1, ON-13, ON-10 (variant), widget EX-4 echoes it.

---

## C27 · episode tile (scroll lag)

- **Spec file: none.** Sources: handoff part 40; findings part 40 (20 Oct), c-zy9zt2, c-e42cnl/c-scy4k9 meshes; motion-and-transitions "Tiles that feel the scroll"; motion-system §6 Cards and tiles; screen-rules 19. Paper part 40 (approved 20 Oct), PC-1 board.
- **Variants:**
  - **hero** (this week's episode): raised paper card (`depth.tier.raised`/card), mesh artwork (weekly = night/amber dusk), inky **2xl** title, **the seam lit play** = the screen's one lit object; **drops the lit play while its own episode is playing** (mini-player owns playback).
  - **square** (briefs, earlier episodes): two across, 12 apart (`space.inline`), no play, title clamped to **2 lines**, balanced; date line = what it's about + length ("your sister, the job · 4 min"); section header "made for you, sam · since 12 oct" (c-zy9zt2).
  - **being made**: one compact row with the grey syncing ring, "ready sunday 9:00" (never a large empty block).
- **Artwork:** `MeshGradient` 3×3, `smoothsColors: true`, recipes in `design-system/hifi/mesh.py`: weekly dusk (amber sun, amber body, night anchor, rose warmth), brief sky (amber sun, sky-300 light, sky-700/900 depth), first green, older warm grey with a rose corner; sun top-trailing (`amber.200`), body colour, dark anchor bottom-leading, warm accent, small highlight; grain overlay ~3–4%. Dark: each palette stop takes its dark twin (palette `$extensions.retrospect.dark`; Tokens.swift doesn't generate palette — hand-built dynamic colours). Reuse `RArtwork` (#42).
- **Motion:** press 0.98; **scroll lag** (`.rScrollLag`): each tile offset ≤ 6pt along the scroll (`motion.scrollLag.maxOffset`) and tilted ≤ 1.5° (`maxTilt`), proportional to scroll velocity, on `spring.settle` (0.45/0.70), staggered by position so the field ripples; never moves while you hold still; RM off. Opens with the iOS 18 zoom transition. Page open: tiles cascade (stagger 60ms, `scale.enter` 0.97); meshes may "drift a few percent" (motion-moments) — but life rules say one ambient motion per screen.
- **States:** rest · pressed (0.98) · playing (hero loses lit play) · being made (compact row) · dark · loading (skeleton tiles, per C39) · empty ("your episodes appear here every sunday." per loading-and-empty example) · offline (downloaded vs not — not specified; use player offline rules).
- **Accessibility:** tile = one element "<title>, <what about>, 4 minutes, episode"; play separate on hero; AX3: squares become one column (not specified — decide by system: never truncate titles beyond 2 lines on squares).
- **SE:** "112 hero art, 24 gaps, 161 squares, blur starts lower".
- **Signature moment:** **M10** (tiles lag the scroll).
- **Screens:** PC-1 (also miniature on ON-12 benefit "an episode every week").

---

## C28 · guess card

- **Spec:** `design-system/components/guess-card.md`. Paper c6; used in part 08 (inside the exchange), PC-2 "a guess arriving", part 41 asked state, YO-4 guess; goals use a **grey** variant (see C29).
- **Anatomy:** (1) card radius 20, padding 16, `inference.surface`, **1pt dashed `inference.border`** (dash `size.inference.dash` 4; SwiftUI `strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))`), wash level, **no shadow**; (2) guess tag "a guess" top-left (C06 tag; pending decision: softer dash in `border.strong` + 4pt `inference.marker` dot); (3) the guess: text 17/24 `text.primary`; (4) why: "from 9 entries · steps" with icon `guess` (spec mono 12 `text.label` — labels rule says Geist; check Paper); tap → sources; (5) confidence: the word only ("fairly sure") after the why line; (6) actions: two wash pills 36 tall in 44: "that's right" (`check`) · "not quite" (`correct`).
- **Rules:** MUST look unfinished until confirmed; MUST show where it came from; MUST accept correction in the person's words (not quite → composer opens with "actually…"); NEVER guess about health, sexuality, religion or money unasked; one guess per turn.
- **States:**

| State | Look | Motion | Haptic |
|---|---|---|---|
| rest | as above | arrives with blur-in | — |
| pressed (pill) | 0.94 | 80/240 | — |
| confirmed | dash → solid 0.5 hairline; gains card-tier shadows; tag fades out; "kept" | 320ms, settles down onto the page | `confirm` |
| corrected | card dims to 55%; composer opens | 200ms | `select` |
| pending | chosen pill shows turning ring | `spin` | — |
| error | "couldn't save that · try again" | blur-in | `error` |
| focused | system | — | — |
| disabled | after an answer, pills disappear (not greyed) | — | — |
| empty, loading | n/a | — | — |
| offline | answers queue; "saved on this phone" | — | — |
| dark | `inference.surface` dark; dashes 3 : 1 | — | — |

- **Accessibility:** "a guess: <text>. fairly sure. from 9 entries and steps." actions that's right / not quite; AX3: pills stack; IC: dash 1.5pt, confidence word `text.primary`; RM: confirm without the settle; contrast dashed border 3.1, why line 5.2.
- **Taken out:** confidence dots; shadow until confirmed.
- **Edge cases:** ignored → after the conversation it waits in You as an open guess; never repeated more than twice.
- **Variant on PC-3/YO-4 ("asked" claim):** dashed asked card, YO-4 "is this the same sam as sam okafor in your contacts?" with "yes, same · not quite".
- **Tokens:** `inference.surface/border/marker`, `size.inference.dash`, `text.primary/label`, `surface.wash`, `depth.shadow.contact/cast`, `status.dangerText`, `motion.duration.spin`, `haptic.confirm/select/error`.
- **Screens:** JR-1 (inside conversation), PC-2 (guess arriving), PC-3 (asked), YO-4 (guess), YO-2 (guess sentence is text, not a card), GL-1/GL-2 (grey variant).

---

## C29 · goal card

- **Spec:** `design-system/components/goal.md`. Paper part 48 (approved 20 Oct), GL-1/GL-2 boards.
- **Anatomy (part 48, newer than spec):** raised card (card tier), radius 20, padding 18; title = your words (text body 17 semibold, lowercase only if written so); **said** and **did** rows: mono xs label (28 wide) · 4pt track (`surface.track`, fill `goal.said` / `goal.did`) · count in words (64 wide, trailing, e.g. "6 times", "2"); one retro line (text-md / 15, `text.secondary`, "you talk about running most on sundays."). No red, no %, no streaks.
- **Question card (retro asks "is that a goal?")** — leads the goals scroll (c-r3vl19); newest look (c-2hj9da, c-q4xfxt): **grey `surface.wash` card, no dashed outline**; "a guess" label leads with the `guess` icon (dashed circle + spark, 18pt, `accent.text`) in a 32 raised-paper well; yes / not quite = **two equal-width raised-paper buttons, 44pt** (`surface.lifted` per dark recalibration). (Earlier "two equal-width grey buttons (surface-wash, 44 pt, radius-control)" superseded.)
- **States:**

| State | Look | Motion | Haptic |
|---|---|---|---|
| rest | as above | bars fill once on first view (`curve.move`) | — |
| pressed | card 0.98 | 80/240 | — |
| a gap | said ≫ did | — | — |
| too early | "too early to tell" replaces the did bar for 2 weeks ("9 days in. i'll know more next week.") | — | — |
| guess (inferred) | grey question card (above) | — | — |
| empty (no evidence) | bars hidden; "nothing to compare yet" | — | — |
| loading | skeleton bars | shimmer | — |
| ended | collapses into one quiet row "turned off 2 · merged 1 ›" at the bottom | 280ms | `confirm` |
| pending/error/offline | ending: pending ring; error line; offline queues | — | — |
| dark | goal tokens dark | — | — |

- **M11 motion:** "Answer 'yes / not quite': The card folds away and the goal's bar eases to its new value" (`spring.sheet`, `duration.slow`, `confirm`); motion-system: "Goal cards fold away on `sheet` and the list closes the gap on `map`."
- **Accessibility:** "run twice a week. said 6 times, did 2. you talk about running most on sundays."; AX3: bars full width under the text; RM: bars appear filled; IC: bar tracks 1pt ring; contrast did bar raised to 4 : 1.
- **Taken out:** %, ring chart, streaks/calendars, summary line under bars.
- **Edge cases:** did > said → "you do this more than you mention it".
- **Tokens:** `goal.said/did`, `surface.track`, `text.primary/secondary/label`, `background.raised`, `depth.*`, `surface.wash/lifted`, `accent.text`, `haptic.confirm`. (`size.goal.ring/ringStroke` in spec tokens are unused.)
- **Signature moment:** **M11**.
- **Screens:** GL-1; GL-2 (page variant: goal inky 3xl, "said 6 times · first on … · last on …", "did this week" evidence rows, pattern as the grey guess card, foot "turn off" only; turned off state shows a dated line, "turn back on").

---

## C30 · message (yours, Retro's, streaming)

- **Spec:** `design-system/components/message.md`. Paper part 08 A (approved, "SF Pro"), every state inside part 08 (M3), master "c · conversation".
- **Variants:**
  - **theirs (Retro):** no bubble, no mark/avatar/name; text 17/26 `text.primary` **SF Pro** (decision A; not inky) at the leading margin; **full column width**, wrap pretty, no balanced wrap, no fixed width.
  - **mine:** bubble `message.mine` (warm wash), radius 18 (`radius.message`) with trailing-bottom corner 4 (`size.border.inset`) — each corner set on its own; text 17/24, trailing aligned; wash level (no shadow). Width: `.frame(maxWidth: column * 0.8, alignment: .trailing)`, hugging (≈280 on 17 Pro). (Token `layout.messageMaxWidth` = 0.78.)
  - **with a guess:** Retro's line carries a guess card under it.
  - **voice note (mine):** "the same wash bubble as text with a raised play, 3pt level bars (played part darker) and the length in mono."
  - **recap card** (part 10, in the thread: "Sunday's recap"): raised card in the thread — take from Paper.
- **Anatomy:** turns 24 apart; consecutive same-side lines 8 apart; time only on a gap > 10 min, mono 11 `text.label` centred. Journal: 24 between entries (`space.betweenEntries`), 40 between days, day label 8 above first entry.
- **Rules:** keep Retro's text unboxed; NEVER typing dots > 1.2s — stream words instead (blur-in per line); MUST allow correcting any Retro line with a long press.
- **States:**

| State | Look | Motion | Haptic |
|---|---|---|---|
| rest | as above | — | — |
| arriving (theirs) | each line resolves blur 5 → 0, opacity 0 → 1 as it streams (M08: lines 60ms apart; motion-moments: word by word, blur 8 → 0) | 240ms per line | `turn` when the turn ends |
| sending (mine) | bubble at `opacity.pending` 0.7; no spinner, no word | — | — |
| sent (mine, M08) | your text lifts from the composer into the bubble (`matchedGeometryEffect`, `sheet` spring) | — | `confirm` on send (M08/motion-system; composer.md says `select`) |
| error (mine) | "not sent · tap to retry", Geist 12 `status.dangerText` + `retry` glyph, under it | blur-in | `error` |
| long press | line lifts (raised card) + menu: copy · correct this · why you said this › | popover spring | `longPress` (medium) |
| focused | system (not drawn) | — | — |
| loading | three dots `text.label` ≤ 1.2s | `typing` 900ms | — |
| empty | first state is Retro's opening line, never empty | — | — |
| offline | mine stays + "will send when you're back online" (Geist 12 `text.label`, `offline` glyph) | — | — |
| dark | `message.mine` dark; text inverts | — | — |

- **Accessibility:** "retrospect: …" / "you: …"; new Retro lines announced when the turn finishes, not word by word; AX3 `type.ax3.body` 40/48, bubble full width − margins; IC: mine 1pt `border.control`; RM: lines fade in without blur 140ms; contrast 15 : 1.
- **Taken out:** bubble/avatar/mark/name on Retro's lines; read receipts, per-line timestamps, "delivered" (conflicts with screen-rules 27 "saved → sent → read" — see F).
- **Edge cases:** very long reply → no truncation; page scrolls and follows unless scrolled up; emoji-only → bubble hugs, no larger text.
- **Tokens:** `message.mine/theirs`, `radius.message`, `size.border.inset`, `opacity.pending`, `type.ax3.body`, `layout.messageMaxWidth`, `text.primary/label`, `status.dangerText`, `border.control`, `motion.duration.typing`, `haptic.turn/error/longPress/confirm`, `font.family.text/label/mono`.
- **Signature moment:** **M08** (bubble lifts, reply sharpens line by line).
- **Screens:** JR-1; ON-13 (first-day thread); also "show it in the conversation" link from YO-3/JR-4.

---

## C31 · entry row

- **Spec file: none.** Sources: build notes "Drawer (part 23)", "Journal pages (M4)", "Search and type"; handoff "Drawer (search field, entry row, section label, settings foot)" approved master; Paper part 23 (approved, drawer master) + M3 key-states card (drawer nothing yet, no results).
- **Anatomy:** your words (SF Pro 17, `tracking.card`; "SF Pro 17 always gets tracking.card") `lineLimit(2)` + trailing ellipsis, balanced line breaks (`.lineBreakStrategy(.standard)` + balanced-wrap helper); meta line one line (Geist label: time · kind, e.g. "voice note · 1:42", "link · shared from safari"); conversation in view is marked (mid-fi: "the conversation you are in is marked"); rows grouped by day with a **sticky day label** (section label S13) pinned under the search field.
- **States:** rest · pressed (wash highlight 80 in / 240 out; row press per settings row) · **search match**: "mark the matched word with an `AttributedString` run (background surface.wash.pressed, weight medium, 2pt horizontal inset), not blue" (drawer) — NOTE the later founder rule for search results "matched words are accent.text, medium weight" applies to YO-2 search (blue job #4); keep drawer per its own note or confirm in Paper · **unsent**: "not sent · tap to retry", tapping retries, stays until it sends · **queued offline**: "waiting to send" (grey, not red) · empty ("nothing yet" quiet mark, M3 card) · no results (M3 card).
- **Motion:** tapping a row closes the drawer and jumps the thread to it (screen-rules 29). Search results stagger in 40ms; "no results" line blur-replaces; clear × scales in on popover.
- **Accessibility:** one element per row "<words>, <meta>"; AX3 rows grow.
- **Screens:** JR-3 drawer. (Drawer is described below in extra parts.)

---

## C32 · evidence row

- **Spec file: none.** Sources: handoff part 41 (approved), build notes "Evidence row (c-7iso8b)", search part 50 citations, YO-3 "this supports", GL-2 "did this week".
- **Anatomy (part 41):** grouped list using the settings row's shape: **32 kind well** (radius.default 10, `surface.wash`, 20pt inked glyph `icon.default` — decision 02), **date / kind label** (Geist label), **one line of your words** — `.lineLimit(1)`, `.truncationMode(.tail)`, **text.md**, full width between well and chevron, never wraps; **›** (chevron-right, decision 04); rows separated by a **1pt `border.subtle`** line (not a 0.5 hairline).
- **Variants:** search sources (YO-2): a **mono number well** instead of the kind well (numbered to the citation chips); YO-3 "this supports" rows (a belief, a goal); GL-2 "did this week" dated evidence rows (with not right per mid-fi); PC-3 "what it rests on".
- **Related — citation chip (YO-2):** "an `AttributedString` run, a small mono number (text-xs) on a `surface.wash` capsule (18 high), baseline-raised 2pt. Tapping it scrolls to and briefly highlights the matching source row."
- **Related — "where retro says it" card (PC-3, c-9ll481):** raised moment card: Retro's line inky, small weekly mesh thumb, "at 4:12 in this week's", "hear it" wash pill (motion-moments: soft press, thin progress line draws under the quote while playing). Asked state: "where retro asks it". Needs `.scrollClipDisabled()`.
- **States:** rest · pressed (wash, 80/240) · loading (skeleton rows) · offline (cached) · dark (uses `surface.lifted` on tinted parents).
- **Accessibility:** "<date>, <kind>, <excerpt>, button"; full excerpt in label (row truncates visually).
- **Screens:** PC-3, YO-4, YO-2 (numbered), YO-3, GL-2.

---

## C33 · benefit row with tile

- **Spec file: none of its own.** Partially `paywall.md` (anatomy item 3) — stale. Newest sources: findings c-qgaf3d, c-fhi7m4 (21 Oct), chronicle "Paywall tiles redrawn as plain design-system glyphs (old ones archived…)", goal prompt "The paywall has six benefit tiles in design-system glyphs, three of them slightly off-axis", motion-system §6 "Off-axis cards". Paper decision 06 option A master (approved 21 Oct).
- **Content (six rows, in this order):** (1) "wake up to what moved" (brief), (2) "see your life, connected" (map), (3) **"ask your life anything · answers from your days, with sources"** (search, added 21 Oct), (4) "know if you're on track" (said vs did), (5) "a podcast about your week" (weekly episode), (6) "a journal that talks back". Each: a tile (56pt raised tile, originally live mini-drawings; latest: plain design-system glyphs), title + one-line subline (one line each, also for SE).
- **Spacing:** "row padding dropped from spacing-3 to spacing-1, with a spacing-1 gap between rows" to fit six rows above the plan pair (last row must clear the 160pt fade).
- **Off-axis tiles:** three tiles slightly tilted (exact angles from Paper). Motion: "On appear they rotate from 0° to their resting tilt on `settle`, staggered 60ms, so they look placed by hand. They don't move after that." Life rules: settle once, then still.
- **Rules (paywall.md):** NEVER show a benefit the backend can't deliver; NEVER fake data in a drawing (no data → shapes without labels); drawings draw in once as they scroll in (60ms stagger); RM: appear complete; AX3: drawings hide, text stays.
- **Screens:** ON-12.

---

## C34 · onboarding question (types out, haptic per word)

- **Spec:** `design-system/components/onboarding-question.md`; Paper part 42 (approved 20 Oct; master on 02).
- **Anatomy (top → bottom):** progress bar (C35) under the status bar; top bar (back · page label · skip — see F); (1) **the question**: display serif 30/34 inky (`font.exposure.title` −20), lowercase, top third — one title, no subtitle, no "why it asks" line; (2) quick answers (when likely ones exist): up to five pills 36 tall in 44, `surface.wash`, Geist medium, flow layout wrapping 8 apart; selected = lifts onto `background.raised` with the raised depth stack + 14pt check from the set before the word, label `text.primary` (no ink fill); cross-fade 200ms + `select`; tapping adds its words to the composer → composer switches to muted-typing with the lit send (never auto-sends); (3) **your words, live**: under the question, Exposure `font.size.2xl` (28) weight `inkCard`, `text.secondary`; each recognised word appended as its own `Text`, blur 4 → 0 + opacity 0 → 1 over 200ms, staggered, newest still resolving while you talk; composer placeholder just says "listening…"; (4) the voice composer (C14) at the bottom, voice on by default, mute trailing.
- **Type-out (M13, build notes 21 Oct):** question types out word by word, each word sharpens from a 1.5pt blur on `curve.standard` (120ms), with `haptic.typeOn` — `UIImpactFeedbackGenerator(style: .soft)` intensity 0.35, once per word (never per letter), ≤ ~10/s, skip spaces and punctuation, `prepare()` once when the question starts, stops when listening starts (`listenStart` takes over). No typing haptic when RM skips the type-on or system haptics are off.
- **Understood word (M03):** the key word ("london") ink-sharpens out of a 1.5pt blur over 280ms (`duration.slow`) with `confirm`.
- **Rules:** one question per screen as one title; one global progress bar, never a count; fold privacy and integrations into the conversation as purpose displays; "skip" per spec rule 3 (conflict).
- **States:**

| State | Look | Motion | Haptic |
|---|---|---|---|
| asking (rest) | question types out (spec: lines blur in 240ms per line; newer: word by word 120ms each) | M13 | `typeOn` per word |
| listening / thinking / speaking | per voice composer | — | `listenStart`/`listenStop`/`turn` |
| answered | answer above; next question replaces this one, old words blur out upward | exit 180ms, enter 240ms | `turn` |
| pressed | per pill / composer wells | 80/240 | `select` (pills) |
| pending | thinking | — | — |
| error | "I didn't catch that" (composer state words) | blur-in | `warning` |
| offline | "you're offline · we'll pick up here" | — | — |
| loading | first question waits on a blank page with the mark (no spinner under 400ms) | — | — |
| dark | canvas dark, question `text.primary` dark | — | — |

- **Accessibility:** question is a heading, read first each turn; AX3: question wraps, chips stack, composer stays in reach; RM: questions cross-fade 140ms, typing shows whole words at once (no `typeOn`); RT: none; IC: secondary text up a step.
- **Taken out:** step dots, counts, illustration ("the question is the picture"), why line, mono skip.
- **Edge cases:** very long answer kept whole; next question may follow up.
- **Variants per screen:** ON-3 "want to talk, or would you rather type?" uses the segmented control (talk · type) — chosen once (screen-rules 9); ON-9 "how straight" = "lead with Retro's recommendation": one raised card with the reason inside ("because you said you want to be challenged"), alternatives as quiet rows under "or choose another" (screen-rules 12); ON-5 privacy and ON-6 connect are purpose pages in the same frame.
- **Signature moments:** **M13**, **M03**, **M02** (with C16).
- **Screens:** ON-3, ON-4, ON-7?, ON-8, ON-9 (the questions), ON-10 (one more warm question). Progress map lists P02 "ON-3–9".

---

## C35 · onboarding progress

- **Spec file: none.** Sources: screen-rules 7; onboarding-question.md rule 2; build notes "Onboarding question (part 42)"; motion-system §6 "Onboarding progress hairline"; S07 `RProgressHairline` (#38).
- **Anatomy:** one global bar under the status bar: **3pt capsule** (`size.progress` 3), track `surface.track`, fill **`ink.default`** (never blue — meters/progress fill with ink). Top bar sits `spacing.4` below it. Never a count ("3 of 10"); the number of turns adapts.
- **Motion:** "creeps forward each turn and jumps at each stage" (spec); "animates forward each turn (spring)" (build notes); "Advances on `map` per step, never by percentage" (motion-system); motion-moments: "steps forward with a small spring when you answer" (`spring.popover`). Use `spring.map`. ON-10 shows it at ~92%.
- **States:** rest · advancing · dark (dark tokens). No pressed/disabled/error (decorative progress).
- **Accessibility:** S07 review note: "#38 progress hairline reads a percentage to VoiceOver (should be 'step n of m')" — but counts are banned visually; announce as "onboarding progress, almost done" style or step n of m in VO only (decide; see F). RM: jumps without spring (140ms fade).
- **Screens:** ON-3…ON-10 (ON-11 tease? player sheet — not shown), ON-5, ON-6.

---

## C36 · knows-you meter

- **Spec file: none.** Sources: motion-system §6 "Knows-you meter"; microinteractions #4 + founder answer; S08 `RKnowsYouTrack` (#38); `size.meter` 4pt (main); chronicle 21 Oct (ON-6 "reframed … with a knows-you meter"); progress map M04; data contract ON-6 "knows-you = count of connected sources (new small endpoint)" (B2.05).
- **Anatomy:** a 4pt track (`size.meter`) filling with **`ink.default`** (surfaces: meters fill with ink, not blue); label words "a little → better → well" ("knows you a little / better / well"). Exact layout, label type and position: Paper ON-6 (title "i'd love to get to know you.").
- **Motion:** fills one step on **`curve.move`** (0.65, 0, 0.35, 1) over **420ms**; the label rolls (`numberTick` 320ms style roll / blur-replace); at "well": the fill glows once and the label pops on **`spring.pop`** (0.35/0.60, ~10% overshoot) with **`confirm`**. Microinteraction #4 says the meter fills "on a spring" (`spring.map`) and `confirm` fires "as the meter lands" — motion-system's `curve.move` is newer.
- **States:** a little · better · well (+ the "well" pop moment) · loading (track only) · offline (last known).
- **Accessibility:** VoiceOver announces in words: *"Calendar connected. Retro knows you a little better."* RM: steps as 140ms cross-fade, no glow pop.
- **Signature moment:** **M04** (+ connect → connected, meter fills, "knows you well" pop) — business-critical, built first with M07.
- **Screens:** ON-6 (possibly ST-3; not drawn).

---

## C37 · paywall plan pair

- **Spec:** `design-system/components/paywall.md` (stale: "save 33%", "$39.99", benefit list of five) + `button.md` (primary/secondary recipes). Newest: findings decision 06 (c-9z0qns, c-211zqk, c-s6b1rn, c-5hyjn9), founder 21 Oct "paywall A", prices $24.99/$239.99 save 20% (plan §8 Q4; "Prices changed … on 57 texts").
- **Layout (option A, approved 21 Oct — "the plans are the buttons"):** pinned at the bottom with content fading under it (160pt `gradient.fadeToCanvas`, 13 eased stops); **two side-by-side one-line buttons, 52pt tall**, 12 apart (`space.inline`): monthly "$24.99 / month" on **raised paper** (secondary recipe: cream `surface.secondaryAction`, 1pt white inner border brighter top, 2pt `border.secondaryRing` + 0.5 warm hairline, contact `0 1 1.5`, cast `0 4 6 −2`, grain seed 239 at 4.5%) and yearly "$239.99 / year" **lit** (primary glow stack) — the unit at a lighter weight; a **"save 20%" tag** sits on the top edge of the yearly button: small raised-paper capsule, `glow.primary.ring` hairline, `accent.text`; one quiet line above the pair: "yearly works out to $20.00 a month" (pre-price-change text: "$16.67 a month"). Prices always from StoreKit.
- **Links:** restore · privacy · terms · not now — in 44 hit areas; "not now" in `text.link`; "not now" and "restore" visible without scrolling. (button.md link variant newest: SF Pro body medium `text.link`, 44 hit; spec: mono 12.)
- **Rules:** real StoreKit prices; not now + restore visible; never a benefit the backend can't deliver; never fake data; yearly is the one lit object; no second paywall on decline; no trial (mid-fi goal check: "no trial; not now keeps the free tier").
- **States:**

| State | Look | Motion | Haptic |
|---|---|---|---|
| rest | as above | drawings draw in once (60ms stagger); tiles settle to tilt | — |
| pressed (plan) | button pressed (0.98; pressed gradient on lit) | 80/240 | `press` |
| pending (purchase) | dots over the kept label; other plan + links disabled | 900ms pulse | — |
| success | sheet settles away; home | sheet spring | `confirm` |
| error | one line under the pair: "the purchase didn't go through, nothing was charged" | blur-in | `error` |
| cancelled | back to rest, no message | — | — |
| loading (prices) | plan labels 60-wide skeleton bars; not pressable | shimmer | — |
| offline | buttons disabled; "connect to subscribe"; not now works | — | — |
| empty (new person) | benefit drawings as shapes without labels | — | — |
| dark | canvas dark; badge keeps 4 : 1 | — | — |

- **M07 (microinteractions):** "You pick a plan: The yearly glow slides to the chosen plan (one lit object, it moves), and 'save 17%' rolls in" (`spring.popover`, `numberTick`, `select`). In approved option A tapping a plan purchases, so "glow slides to the chosen plan" has no trigger — needs reinterpretation (F). motion-system: the save tag uses `spring.pop`.
- **Accessibility:** reading order line → benefits → plans → links; each plan reads price and period ("yearly, $239.99 a year, $20.00 a month"); AX3: plans stack vertically (yearly first); RM: drawings complete; RT: fade becomes a solid band; IC: as button, links `text.primary`.
- **Edge cases:** trial used → n/a (no trial); family sharing / restored → closes with "you're subscribed"; very small phone → plans stack.
- **Signature moments:** **M07**, **M06** (paywall rises from the tease).
- **Screens:** ON-12 (also "when a free person opens something paid").

---

## C38 · you map (nodes, lines, life)

- **Spec:** `design-system/components/you-map.md` (older), plus build notes "You map" (orbits, frosted, labels, straight lines, hand-crafted), handoff (master "c · you map", part 05 orbits). Paper master is **hand-crafted by the founder** — "don't generate it from a layout algorithm without their sign-off." Versions B (stars) and C (neighbourhoods) on part 50 card awaiting a pick (c-e52ubp) — check status.
- **Anatomy (approved orbits):** canvas = the page (level 0), grain 4%; **you** at the centre (lit you-orb, the splash's orb recipe, 56; `map.node.self` / `map.star.self.core/halo`), not a button; thin orbit rings drawn first, then threads (**straight segments, never curves**; weight and opacity carry strength, `map.edge` / `map.edgeStrong`, width `size.map.edgeMin`–`edgeMax` 0.5–3), then each orb as **frosted glass**: 12% white base under its gradient + ~1.5pt backdrop blur (things behind are softened); orbs are glass spheres (two light gradients, top rim, hairline, soft cast); far ones smaller, blurred and dimmed for depth. Data-as-light rule: stars emit light, no white specular highlight (surfaces.md). Node sizes by importance (`size.map.nodeMin` 8 → `nodeMax` 56 tokens; spec says 12 → 44). Kinds: person/goal/theme/place/source colours. **Labels**: names never sit on a thread or ring — "Place each name on the side of its orb away from you, and give it a canvas-coloured plate (2 × 4 padding, small radius)"; labels under nodes > 20 only (spec mono 11 `map.nodeLabel`). Guess nodes: dashed rings (`inference.border`); "one waiting node glows quietly". Map bleeds past the margins. ≤ 24 nodes at once.
- **States:**

| State | Look | Motion | Haptic |
|---|---|---|---|
| rest | as above | life: nodes breathe ±2pt drift, 6–9s periods, staggered (motion-system §7; spec says ±1pt) | — |
| pressed (node) | 1.1×, 2pt `map.selectedRing`; unrelated nodes to `opacity.dimmed` 0.25; YO-4 sheet rises | `spring.map` | `select` |
| loading | you + rings of skeleton dots appearing in order | stagger 60ms | — |
| empty / day one | only you on the empty orbits; "just you, so far." / "this fills in as you talk to me." | — | — |
| pending | a node being learned pulses once | — | — |
| new fact (M12) | blooms in: scale 0 → 1 on `pop`, halo fades; line to "you" draws itself over 420ms on `curve.standard` | — | `reveal` |
| error / offline | last map + "couldn't update · showing last week's" | — | — |
| dark | dark map tokens; edges white 20%; orbs use dark palette twins | — | — |

- **Map open (motion-moments):** you-orb lands first, then people and threads float in on their orbits (splash A choreography shortened), `spring.map`, stagger. Nodes enter on `map` staggered 60ms. Dragging uses `map` with velocity.
- **Accessibility:** VoiceOver gets a list, not the canvas: "maya, person, closely linked to: work, running"; AX3: labels grow, fewer labels; RM: no drift, selection without spring; RT/IC: edges one step stronger, labels `text.primary`.
- **Taken out:** legend, colour per person, numbers on nodes.
- **Edge cases:** collisions → smaller moves; labels never overlap (hide smaller).
- **SE:** YO-1 map scaled to 0.82 (c-o1stxz; Paper had kept full size earlier); AC-1 map at 0.78.
- **Variants:** paywall mini map (no labels without data); AC-1 / splash constellation without names (never show node names before auth); field stars `map.star.field` behind AC-1.
- **Signature moment:** **M12**; also M01 (splash orb).
- **Screens:** YO-1, ON-1/2 (splash A), AC-1, ON-12 benefit tile, YO-4 (map behind sheet).

---

## C39 · loading, empty, error, offline (shared)

- **Spec:** `design-system/components/loading-and-empty.md`; per-component states above; motion-system §6 "Loading and empty"; craft §12.3.
- **Skeleton:** bars in the exact shape of the content (`surface.skeleton`, radius 6 `radius.small`), shine sweeping left → right (`surface.skeletonShine`, `motion.duration.shimmer` 1400ms; motion-system: shimmer every 1.4s on `curve.move`), only after 400ms; content replaces skeletons with a 140ms cross-fade, no jump.
- **Empty:** one serif line saying what will be here and how it fills ("your episodes appear here every sunday."), at most one action, no illustration; arrives with a stagger, then stays still.
- **Rules:** NEVER a spinner for page content; NEVER loading < 400ms; MUST say when it will fill.
- **States:** rest = skeleton or empty line; pressed/focused: the one action per button; error: the empty layout with what went wrong and "try again"; offline: "you're offline · showing what's saved" above cached content (Journal drawer: one grey line under search "offline · new notes send when you're back"; queued notes "waiting to send", not red); dark: skeleton dark values; slow > 8s: "still working" under the skeleton.
- **Pending rings:** always `RSpinner` (6pt ring for status, 20pt for stage/getting-ready, 2pt rings in wells), never system `ProgressView`. Syncing ring: "a 6pt ring in border.strong with a quarter arc in text.secondary, rotating once a second, linear. Reduce Motion: the arc stays still."
- **Pull to refresh:** resistance follows rubber band (0.55); past threshold `refresh` haptic and "the mark spins on `spin` (900ms)" (motion-system; conflicts with the-mark "never moves" — motion-moments says the splash orb stretches and pops back on `popover`); new items bloom in on `map`.
- **Accessibility:** skeleton reads "loading" once; empty reads the line; AX3 bars follow text sizes; RM: no shine, bars pulse opacity; IC: bars one step darker.
- **Taken out:** spinners, percentages, illustrations, exclamations.
- **Screens:** every data screen. Key states drawn per screen are in section E.

---

## C40 · lock screen and widget views

- **Spec:** `design-system/components/lock-screen-and-widget.md` (older) + handoff EX-2/EX-3/EX-4 (approved 20 Oct "EX outside the app") + build note "make this phone sized".
- **Now playing / Live Activity (EX-2):** system-drawn: brief mesh artwork, **title = the part being spoken**, subtitle "retrospect · tuesday's brief · part 2 of 3", system scrubber and ↺15 ‖ 30↻. Live Activity carries the same. Audio continues in background. System chrome identical in light/dark.
- **Notifications (EX-3):** private by default: "your brief is ready · 4 min", "this week's episode is here.", "one question for you, when you have a minute."; max one a day, never at night; deep links: brief → JR-2, episode → PC-2, question → YO-4. Never private content on the lock screen unless allowed.
- **Widgets (EX-4, newest handoff):** **small** (system size, 170pt on 390pt phones): the mark 16 · "tell me…" inky · "talk to retro" → opens composer. **medium**: mark + "today's brief · 4 min" mono · inky headline · play / talk wash pills (iOS 17 interactive). Radius `radius.widget` 22, padding `layout.widget.padding` 16. Must be legible in tinted and clear Home Screen modes (serif and mark monochrome-safe); follow dark via `containerBackground` with dynamic colours.
- **Spec's older small widget** (mark 16, "today's brief" mono 11, headline serif 15 three lines, wash play) — superseded by handoff (see F).
- **States (spec):** rest (ready) · pressed (system) · playing (play → pause, "playing" label) · played (headline `text.secondary`, "played") · empty quiet day ("a quiet day" serif) · loading ("being made", no play) · error/offline ("open retrospect to load today's brief") · brief off → "turn on your daily brief in retrospect" once, then the episode of the week · pending/focused/disabled system-managed · dark.
- **Accessibility:** "today's brief, <headline>, play"; system scaling; headline two lines at AX3.
- **Taken out:** progress bar, date, entry counts.
- **Screens:** EX-2, EX-3, EX-4 (+ B8.01/B8.02 widget extension, lock-screen widget).

---

## S10 · the mark

- **Spec:** `design-system/components/the-mark.md` + handoff "The mark (21 Oct)" (newer). Paper master "c · the mark" on 02 (sizes 38, 22, 16), now in all 27 placements.
- **Glyph:** use the app's existing asset **`retrospect-loading-mark`** (Assets.xcassets): `Image("retrospect-loading-mark").renderingMode(.template).foregroundStyle(RColor.iconMark)` inside the disc; glyph ≈ **53% of the disc width** (handoff) — spec said "`icon.mark` at 35%, inset 9 at 38" (35% is the opacity in the older spec; use Paper). Dark: `icon.mark` dark = night.400.
- **Sizes:** 38 (paywall, onboarding welcome) — `elevation.mark` `0 6 7` 24% + `0 1 2` 12%; 22 (player header) — `0 2 3` + `0 0.5 1`; 16 (widget corner) — contact only. Token `size.mark` = 38.
- **Anatomy:** warm shadows; disc round `surface.secondaryAction` (cream); ring 1pt `border.secondaryRing` at 75% outside a 1pt white inner border (raised double stroke); grain `material.grain.signature` (seed 7, 6%); glyph centred by mass.
- **Rules:** never a button; one per screen; never recoloured per screen; not beside Retro's messages.
- **States:** rest only; dark: dark `surface.secondaryAction`, shadows black 45%, grain stays.
- **Accessibility:** `accessibilityHidden` where a title already says "retrospect", else "retrospect"; fixed size (not Dynamic Type); IC glyph to 60%; RM: it never moves.
- **Taken out:** animation and state.
- **Edge cases:** never on a dark photo/artwork; sits on a surface.
- **Screens:** PC-2/JR-2/ON-11 header (22), EX-4 widgets (16), ON-12? (38 per spec; approved A has the paused mini-player instead — check), onboarding question loading state (blank page with the mark), AC-1 (placeholder replaced by the you-orb; mark hidden). Motion-system's "splash and the mark… orb breathes" refers to the splash orb, not this disc.

---

## Extra parts (not numbered C-bytes, or folded into screens)

### Getting-ready panel (ON-10) — `c:getting-ready`
- **Spec file: none.** History (newest last — build the last): handoff 20 Oct (label "getting your first episode ready", three stages: done = 20pt success disc + check · now = 20pt spinner, medium weight · next = empty ring at `opacity.disabled`; footnote "about two minutes. keep talking; it all goes in."; no percentage; SE shows only the current stage line + footnote) → c-7qova7 (no box, on the page under one hairline) → c-mss4bm (three-segment bar, inky current step "writing your episode…", "2 of 3" mono) → **c-y8vj32 (newest look): the journal's own brief card in its being-made state**: soft artwork, "your first episode", "writing it now · about two minutes", **2pt accent hairline of progress along the card's bottom edge** (mini-player progress language); under it one line "keep talking; it all goes in."; "It's the same card that becomes 'your first episode is ready' on ON-13, so the wait and the arrival are one object." → **c-koui68 (latest):** "A small raised tag ('+ the investor call on thursday', tilted −2°) is tucked into its top edge… The artwork is now the full-colour brief mesh with a glow ring instead of blurred. The subline reads 'weaving in what you just said · ~2 min', and the hairline progress stays." iOS note: "each new answer pops in as a tag and slides into the card (the splash D language)."
- **Data:** stages from the real pipeline (`/onboarding/readiness` door, B2.03); "honest steps".
- **Motion (M05):** "The tiny progress hairline moves in honest steps (no fake percentage), and each new stage label blur-replaces" (`duration.slow` 280ms); progress steps on `curve.move`. Tags: pop in (`spring.pop`/`popover`) and slide into the card (`spring.sheet`).
- **Conflict:** accent (blue) hairline vs rule "progress fills with ink, not blue" (F).
- **Screens:** ON-10 (P05).

### Setup-recap card (ON-13) — `c:entry/setup-recap`
- **Spec file: none.** Newest (c-g5keu2 then c-mn0d3s): a **raised paper card** (not the grey wash box in the p61 snapshot), label "what you told retro while setting up" + "9 answers", three answers **in the inky card face** ("sam, in london." / "wants: raise the seed, sleep before midnight." / "this week: the investor call on thursday."), link "see all 9" (`text.link` medium). SE: recap shows two lines. Retro's "that's enough to start…" line stays hidden. Data: answers summary door (ON-13 contract).
- **Screens:** ON-13.

### Hint pill (ON-13) — `c:hint/1-of-3`
- **Spec file: none.** Handoff: pill above the composer, mono counter ("1 of 3", `text.xs` `text.label`) + one line ("tap the mic and just talk. retro writes it down." `text.sm`), raised (`background.raised`, radius.control, 8/12 padding), one hint at a time, dismissed by doing it. **Newest: hidden** (c-dnuru5 "decluttered"; c-mn0d3s kept it hidden). Do not build unless Paper shows it again (founder question).

### Drawer (JR-3)
- **Spec file: none.** Approved master (part 23 + M3 key states). Build notes "Journal pages (M4)": **drawer width = screen width − 74** on every device (journal keeps 74pt of its edge visible as the way back) — mid-fi said 276pt; status bar stays fixed over both layers, the journal slides under it; the page slides aside "rounded and shadowed" (screen-rules 29); drawer sits on **`background.underlay`** (light paper.200, dark night.950); search field on top (C12, sunken recipe); entries by day in your own words (C31); sticky day label; **foot: settings · version, pinned to the bottom (16 off on SE, 32 above the home indicator elsewhere)**, list fades out under it with a progressive blur (56pt band, 6pt max, canvas tint — progressive-blur.md; foot fade to the underlay token); opened by the all-journals button top-left or an edge swipe; tapping a row closes it and jumps the thread. States: empty, searching, no results, offline ("offline · new notes send when you're back", grey). SE: 20 margins, foot 16 off the bottom.
- **Motion:** not specified beyond "slides aside"; use `spring.sheet` for the page slide with velocity, page corner radius + shadow in step (sheet-like single progress value) — confirm.
- **Screens:** JR-3.

### Splash (ON-1/2)
- **Spec file: none.** Part 43, approved 21 Oct **"yes for now, mark this as a screen to experiment with"** (tag "approved · experiment"). Look: option **A constellation** (B warm light also kept; C archived): the approved You map (orbits, frosted orbs) bleeding under the status bar, with a **top-only wallpaper** (amber from the top-right, sky from the top-left, pale glow behind the map, fading out by ~40% of the screen; words and buttons on plain canvas — c-yv0fr0); the inky promise "everything about you, finally connected." + Geist subline resting just above the sign-in buttons (spacing-8 apart; c-1wlx4j); **Sign in with Apple** (Apple standard black; dark: white `SignInWithAppleButton(.white)`) then **Google** (white raised button with a warm hairline, never a dark border; dark fill `#131314`, label `#E3E3E3`), both 56 high in the bottom zone; Geist legal line. Use the cloned brand buttons (Google logo colours can't be tokens).
- **Motion:** candidates on Paper page "06 · splash motion · keyframes": **A constellation assembles** (kept), **B2** "the light comes up from below" ("cool, save"), **B3** one warm ray, **D "the dots connect"** (four beats, ~4.5–4.9s; motion preview `docs/design/motion/splash-d.html`, generator `build_splash_d.py`). Motion-system §6 cites "the founder's splash D motion"; M01 says "orb breathes once, satellites drift into orbit, staggered 60ms (`spring.map`, `duration.reveal`)" — which one ships is undecided (F). Tap-to-skip and RM fallback are on each keyframe board. Haptic: none (M01).
- **Data:** Apple live; Google sign-in new (B2.01). AC-1 trigger: Keychain flag `hasSignedInBefore` → AC-1, else splash.
- **Screens:** ON-1/2 (P01).

### Privacy disc (ON-5)
- **Spec file: none.** Part 44 approved; founder picked **C · "held in blue"** ("lets go with this one", c-da04x3): the lock becomes the **lit disc inside a sky glow** — sky bloom, pale glassy inner disc with a sky hairline, lit lock disc with a soft blue halo all round. Screen: lock disc centred above the title (screen-rules 3), inky title, plain paragraph, policy link; Retro reads it aloud. Top bar fix (c-zi8796) applies.
- **Motion (motion-moments):** "the blue disc (C, your pick) fades in, the lock shackle closes with a tiny click motion, and the halo breathes once" (`spring.popover`, `confirm`).
- **Conflict:** a lit disc that is not an action vs "blue has four jobs only" (F). Life: halo breathe once (not ambient).
- **Screens:** ON-5 (P03); privacy echoed in ST-5.

### Force-update screen (X02)
- **Nothing designed.** Only mentions: progress map X02 "Version floor: minimum supported app version + force-update screen (app) and version header (backend)"; plan §6b "checked at launch with a force-update screen"; goal prompt. No Paper board, no spec, not among the 37 screens. **Needs a Paper design (or a decision to reuse a system-rule layout: purpose page = one title + one description + one lit action "update" opening the App Store ↗).**

### Toast (C21, for reference — in review #48)
- toast.md is stale (black `background.inverse`, mono 13, no icon). Founder rounds: rejected black; picked **B frosted**, asked for an icon → B2 icon in a 28 wash well; then "white is too easy to miss… stronger shadow" → four looks built behind `RToast.Look` for the founder to try. 44 high, SF Pro 14 medium, undo semibold 44 hit, sits 12 above mini-player/tab bar (`layer.toast` 60). Motion-system: in on `popover` from the edge (~3% overshoot), floats 2pt on a 5s sine, swipe away with velocity, auto-dismiss 4s on `curve.exit`, success toasts fire `confirm` as they land.

---

# B. The motion system

Source: `design-system/principles/motion-system.md` (the system, 21 Oct) + `motion-and-transitions.md` (research and choreography) + `docs/design/motion/motion-moments.md` (22 "fun" moments, 20 Oct) + tokens on `origin/main`. Measured overshoot from the F09 motion lab (#25): snappy 0.6%, popover 2.5%, pop 8%, settle 4.1%, map 1.2%.

## B1. The rules (motion-system §1)
1. Never linear — except things tied to real time (audio progress, recording timer, 1:1 scrub). The syncing ring "rotating once a second, linear" is the other stated exception.
2. Springs for anything that moves; curves for anything that only fades or changes colour.
3. Everything interruptible — catch mid-flight, continue from position and velocity; never jump back, never queue.
4. Gestures hand their velocity to the spring.
5. Bounce is earned: controls ≤ 1.5%; things popping into view 3–5%; celebrations ~10%; the lit button never wobbles.
6. Exits ≈ 65% of the entrance (craft: 0.5–0.7×).
7. Respond on touch down, same frame.
8. One hero per moment (the glow moves; everything else calm).
9. Life is rare and slow (§7).
10. Haptics land with the visual landing; prepared ahead; never on scroll.
11. Reduce Motion keeps the meaning: 140ms cross-fade, no scale, no blur, no bounce.

## B2. Curves (fades, colour, blur)

| Token | Bezier | Feel | SwiftUI | Use |
|---|---|---|---|---|
| `motion.curve.standard` | 0.16, 1, 0.3, 1 | expo-out | `.timingCurve(0.16, 1, 0.3, 1, duration:)` | anything appearing: fades in, blur-replace, colour changes |
| `motion.curve.exit` | 0.4, 0, 1, 1 | gathers then leaves | `.timingCurve(0.4, 0, 1, 1, duration:)` | anything leaving for good |
| `motion.curve.move` (main) | 0.65, 0, 0.35, 1 | symmetric in-out | `.timingCurve(0.65, 0, 0.35, 1, duration:)` | non-gesture moves start/end at rest: knows-you meter fill, progress steps, shimmer |
| `motion.curve.reveal` | smooth, extraBounce 0.02 | long and calm | `.smooth(duration: 1.22, extraBounce: 0.02)` | first-insight moment, splash |

**Durations** (only from `motion.duration.*`): instant 80 · fast 140 · base 200 · slow 280 · reveal 1220 · audioFade 1050 · spin 900 · expand 240 · toastVisible 4000 · shimmer 1400 · voicePulse 1200 · typing 900 · numberTick 320 · litFade 200 · pressIn 80 · pressOut 240 · transcriptFollow 420 · followResume 4000 · playMorph 180 · scrubPreview 120 · popoverExit 110 · sourceDim 66. Nothing a person waits on runs > 450ms (reveals excepted). Other motion tokens: `scale.press` 0.98, `scale.pressSmall` 0.94 (main), `scale.enter` 0.97, `scale.behindSheet` 0.94, `scale.scrubThumb` 1.6, `scale.popoverFrom` 0.86, `stagger` 60ms, `staggerMax` 6, `blur.enter` 8pt, `appear.rise` 8pt, `appear.blurFrom` 8pt, `shake.distance` 6pt, `gesture.dismissDistance` 140pt, `gesture.dismissVelocity` 800, `gesture.rubberBand` 0.55, `life.floatAmplitude` 2pt, `life.floatPeriod` 5000ms, `life.resumeAfter` 4000ms, `scrollLag.maxOffset` 6pt, `scrollLag.maxTilt` 1.5°, `motion.reduced` "opacity-only, 140ms".

## B3. Springs (anything that moves)

| Token | response · damping | Overshoot (spec / measured) | Feel | Use |
|---|---|---|---|---|
| `snappy` | 0.25 · 0.82 | ~1% / 0.6% | firm, immediate | press release, toggles, segmented thumb, checkmarks, tab icon, scrubber thumb grow, skip rotate, shake |
| `popover` | 0.30 · 0.74 | ~3% / 2.5% | small confident pop | menus, popovers, toasts, tooltips, composer send rising in |
| `sheetDismiss` | 0.32 · 0.90 | ~0% | clean exit | sheets and cards leaving |
| `sheet` | 0.40 · 0.86 | ~0.5% | weighty, settled | sheets, the player, the paywall rising, cards folding away, bubble lift on send |
| `map` | 0.45 · 0.80 | ~1.5% / 1.2% | soft, organic | map nodes, the meter (per microinteraction #4), new items blooming, list reflow, onboarding progress steps |
| `settle` | 0.45 · 0.70 | ~5% / 4.1% | dragged through water | tiles lagging the scroll, off-axis cards settling on appear |
| `pop` | 0.35 · 0.60 | ~10% / 8% | delight, rarely | "knows you well", goal met, first episode ready, badges, the save tag |
| `gentle` | 0.55 · 0.92 | ~0% | big and calm | large layout changes, page behind a sheet, listening glow rise, tab tap scroll-to-top |

Damping below 0.6 is not allowed. Untokenised springs cited in specs: title-menu pill slide 0.25/0.85 (≈ snappy), scrubber release 0.3/0.8 (≈ popover), switch in Paper 0.3/0.75 (motion system says snappy; open on #50), top-bar collapse "~300ms spring" (no token named).

## B4. Ramps (§4)
- **Start** at the gesture's velocity (`DragGesture.velocity`, iOS 17+), `.interactiveSpring` while the finger is down, full spring on release.
- **Where it lands:** project momentum (`predictedEndTranslation`). Sheets close past 140pt or 800pt/s; scrubber snaps to a chapter within 12pt.
- **Rubber band:** past an edge, movement × 0.55; spring back on `snappy`.
- **Stagger:** top to bottom, 40–60ms apart, each on `curve.standard` 280ms with an 8pt rise and blur 8 → 0; at most 6 items, the rest arrive together. Nothing appears before what is above it.
- **Settle:** at rest, no jitter.
- **Chained steps overlap:** next starts at ~70% of the previous (`keyframeAnimator`/`phaseAnimator` with overlapping tracks).
- **Interrupt:** SwiftUI additive animation; never `.transaction { $0.animation = nil }` mid-flight; a tap during a sheet's rise reverses it from where it is.

## B5. Per-component motion assignments (§6, verbatim essentials)
- **Buttons (lit/secondary/text) + icon buttons:** press in 80ms on `curve.standard` to 0.98 (large)/0.94 (small), `press` haptic on lit; release on `snappy`; lit glow dims 15% while pressed and blooms back; loading: label blur-replaces into a spinner, width animates on `snappy`; disabled → enabled: glow fades in 280ms and breathes once (halo 1.0 → 1.04 → 1.0).
- **Pills/chips:** press 0.94; selected: fill cross-fades 140ms, check draws in 200ms on `curve.standard`, `select`.
- **"+ connect" (source rows):** press → pill blur-replaces into spinner → "● connected", dot scales 0 → 1 on `pop`; `confirm` as the dot lands; row width change on `snappy`; failure: pill shakes (three oscillations on `snappy`, 6pt) + `warning`, then "try again".
- **Text fields/composer:** focus: field lifts sunken → field colour over 140ms, focus ring fades in on `curve.standard`, `prepare()`; placeholder fades 80ms as first character lands; character count rolls (`numericText`); send: text becomes your bubble and lifts into place (`matchedGeometryEffect`, `sheet`) with `confirm`; error: 6pt shake on `snappy` + `warning`, message blur-replaces in below; keyboard: content moves with the keyboard's own curve (`.animation(.default)` inside `safeAreaInset`).
- **Search field:** results stagger 40ms; "no results" blur-replaces; clear × scales in on `popover`.
- **Toggle:** thumb on `snappy`, stretching 4pt wider in travel; track colour cross-fades 140ms; `select`.
- **Segmented:** thumb slides on `snappy` (`matchedGeometryEffect`), labels cross-fade weight 140ms, `select`; drag follows 1:1 and snaps.
- **Rows:** wash press highlight in 80ms, out 240ms; chevron nudges 2pt on press; push uses the system navigation transition (iOS 18 zoom where a tile opens its page).
- **Sheets/dialogs:** rise on `sheet`, dismiss on `sheetDismiss`; page behind scales 0.94, rounds 12 and dims on one progress value following the drag 1:1; rubber band past the top; `sheetSnap` at each resting height.
- **Menus/popovers/title menu:** grow from source (0.86, blur 8 → 0) on `popover`; close 110ms on `curve.exit`; source dims 66ms first.
- **Toasts:** in from top/bottom edge on `popover` (~3% overshoot); float 2pt vertical drift on a 5s sine; swipe away follows the finger and flicks with velocity; auto-dismiss after 4s on `curve.exit`; success toasts `confirm` as they land.
- **Tab bar:** selected icon `.symbolEffect(.bounce)` once with `tab`; label weight cross-fades; tapping the current tab scrolls to top on `gentle`.
- **Mini-player ↔ player:** shared element (`matchedGeometryEffect` on artwork, title, play) on `sheet`; progress hairline linear (real time); play ↔ pause `.contentTransition(.symbolEffect(.replace))` 180ms.
- **Scrubber/transport:** thumb grows to 1.6× on touch (`snappy`), time numerals roll; `chapterTick` crossing a chapter; skip ±15/30: icon rotates 20° and back on `snappy`, time rolls, `skip`.
- **Cards/tiles:** press 0.98; in scrolling rows the scroll-lag tilt on `settle`; episode tiles open with the iOS 18 zoom transition; goal cards fold away on `sheet` and the list closes the gap on `map`.
- **Off-axis cards (paywall tiles):** on appear rotate 0° → resting tilt on `settle`, staggered 60ms; never move after.
- **Knows-you meter:** fills one step on `curve.move` over 420ms; label rolls ("a little → better → well"); at "well" the fill glows once and the label pops on `pop` with `confirm`.
- **Onboarding progress hairline:** advances on `map` per step, never by percentage.
- **Listening field:** glow rises from the bottom edge on `gentle`, follows the voice level live (smoothed 120ms, capped 1.3×); `listenStart`/`listenStop`.
- **Onboarding question text:** types out word by word, each word sharpens from a 1.5pt blur on `curve.standard` (120ms) with `typeOn`; the understood answer word ink-sharpens over 280ms with `confirm`.
- **Text that changes:** `blurReplace` 4–6pt, 200–280ms; numbers `.contentTransition(.numericText())` + `.monospacedDigit()`. Transcript: colours cross-fade first (90ms), then the column glides (to 280ms; transcriptFollow 420); next line sharpens from 1.5pt blur. Pure opacity cross-fade double-prints letters — never.
- **Loading/empty:** skeletons shimmer every 1.4s on `curve.move`; content replaces skeletons with a 140ms cross-fade; empty states arrive with a stagger, then stay still.
- **Pull to refresh:** resistance follows the rubber band; past threshold `refresh` fires and the mark spins on `spin` (900ms); new items bloom in on `map`.
- **You map:** nodes enter on `map` staggered 60ms; new fact blooms (scale 0 → 1 on `pop`, halo fades), line to "you" draws over 420ms on `curve.standard`, `reveal`; dragging uses `map` with velocity.
- **Splash and the mark:** the orb breathes once (`curve.reveal`), satellites drift into orbit with overlapping keyframes ("the founder's splash D motion").

**Extra moments from motion-moments.md (20 Oct, "purposeful and fun"; each falls back to opacity-only 140ms):** mic tap → five bars rise from flat one after another (stagger 60ms, `popover`), halo breathes in (`listenStart`); stop talking → bars fold into the three thinking dots (`base`, `curve.standard`, `listenStop`); Retro answers word by word, each word blurring in 8 → 0 (`typing`, `turn`); your message sends → bubble lifts 4pt and settles (`scale.enter` 0.97 → 1, `popover`, `press`); brief becomes ready → being-made well blooms into the mesh, row grows into the full card (matched geometry), play lights last (`reveal`, `sheet`, `reveal` haptic); scrolled → slim bar (`sheet`); play → pause triangle splits into two bars (`playMorph`, `press`); chapter change → segment ticks over with tiny overshoot, chapter name slides up one line (`popover`, `numberTick`, `chapterTick`); transcript line glides, next sharpens from grey (`transcriptFollow`); podcasts page opens → tiles cascade (stagger 60, `scale.enter`), meshes drift a few percent; episode starts → hero artwork flies into the mini-player thumb (`sheet`, `sheetSnap`); "hear it" → soft press then a thin progress line under the quote (`press`); goal hit → ring closes with small overshoot, number ticks, one quiet amber spark, no confetti (`popover`, `numberTick`, `confirm`); map opens → you-orb lands first, then people and threads float in (`map`, stagger); new learning → orb drawn in along its thread (`reveal`, `reveal`); onboarding words blur in, progress steps forward with a small spring (`blur.enter`, `popover`, `turn`); quick answer → pill lifts onto paper, check draws (stroke 0 → 1, 140ms, `select`); privacy → blue disc fades in, shackle closes with a tiny click motion, halo breathes once (`popover`, `confirm`); splash → chosen opening (`reveal`, `reveal`); tab switch → one-frame emphasis swap with tiny scale settle (`fast`, `scale.press`, `tab`); pull to refresh → splash orb stretches on the pull (0.55) and pops back (`popover`, `refresh`); delete → row folds height to 0 while sliding a few points, neighbours close the gap (`base`, `curve.exit`, `warning`). Guardrails: one thing moves for attention at a time; nothing loops forever except slow drift of meshes and maps; press feedback < 80ms; fun lives in the shape (overshoot, stagger, morph), never confetti or bouncing icons.

## B6. Life rules (§7)
- **One ambient motion per screen at most**, only on surfaces you aren't reading.
- **Slow and small:** period ≥ 4s, ≤ 3pt travel and ≤ 1.5° tilt; sine, never linear; elements out of phase.
- **Stops on touch, scroll or type**; resumes 4s after (`life.resumeAfter`).
- **Pauses off-screen, in Low Power Mode, and with Reduce Motion on.** (`.rFloat` checks the gates itself; `.rLifeHost` is a passive window observer — #36 fixed it swallowing taps.)

| Element | Life | Spec |
|---|---|---|
| You map nodes | breathe | ±2pt drift, 6–9s periods, staggered |
| Toasts | float | 2pt drift on a 5s sine |
| Lit button when it becomes available | one-time glow pulse | once, then still |
| The orb on splash and on You | slow halo breath | halo opacity 0.35 ↔ 0.5 every 6s |
| Paywall off-axis tiles | settle once on appear | then still |
| "Your first episode is ready" (ON-13) | one-time pop | `pop` spring, `reveal` haptic |

**Never ambient:** text, the reading column, the player transcript, fields, anything with a number in it.

## B7. Reduce Motion, Reduce Transparency, VoiceOver (§8)
- **Reduce Motion:** every spring and move → 140ms cross-fade; no scale, blur, tilt, ambient motion or scroll lag; typing shows whole words at once. Haptics stay, **except `typeOn`**. Every `.r*` modifier reads `accessibilityReduceMotion` and swaps itself, so screens never branch. Component-specific RM notes (sheet "fade + 24pt slide", player "transcript jumps line to line", scrubber "bubble appears", mini-player "updates in steps") are in each component.
- **Reduce Transparency:** blurs become solid surfaces (progressive blur → tint only, ending opaque; scrim solid 60%; tab bar `material.reducedTransparency`).
- **VoiceOver:** state changes announce in words (*"Calendar connected. Retro knows you a little better."*), never only through motion.

## B8. The visual pass (§9) — every motion, when built
On a real iPhone (ProMotion 120Hz) and the oldest supported phone:
1. Record at 120fps and again with Slow Animations; attach both to the PR.
2. Check the ramp frame by frame: no linear segment, no first-frame jump, no overshoot beyond its spring's row, clean settle.
3. Interrupt it: tap/drag mid-flight; must reverse from where it is.
4. Feel the haptic: lands on the frame the motion lands; never doubles.
5. Reduce Motion on: meaning survives as a cross-fade.
6. Hitches: Instruments Animation Hitches template, 0 hitches over 5 runs.
7. Compare with the storyboard in Paper (timings on the filmstrip); if it feels wrong but matches, fix the storyboard too.
8. Founder sign-off for the 13 signature moments; the rest reviewed in the PR.
(Goal prompt definition of done repeats this; recordings in each PR = founder's motion sign-off method. Simulator-only agents: the checklist uses launch flags + `simctl io screenshot`; founder's rule for C21: "I don't want to see it" — check headlessly.)

## B9. Haptic map (tokens on main → SwiftUI → when)

| Token | Generator | SwiftUI | When it fires |
|---|---|---|---|
| `press` | impact.light | `.impact(weight: .light)` | touch down on a lit or destructive action, once (craft: lit actions only; several specs also put it on raised play wells — see F) |
| `select` | selection | `.selection` | option chosen; settings applied at once; title-menu settle; pill toggle; speed change; mini-player swipe-down hide |
| `tab` | selection | `.selection` | tab changed |
| `turn` | selection | `.selection` | Retro hands the turn back; Retro's message turn ends; onboarding answered |
| `chapterTick` | selection | `.selection` | crossing a chapter while scrubbing |
| `confirm` | notification.success | `.success` | a saved/connected state lands (check appears, dot lands, meter settles at "well"); guess confirmed; goal ended; purchase success; send (M08); understood word (M03); success toast lands |
| `warning` | notification.warning | `.warning` | with the field shake or failure; "didn't catch that"; connect failure; delete touch-down inside the dialog; source error |
| `error` | notification.error | `.error` | failure toast/line (couldn't play/load/save, not sent, purchase failed); never twice in a row |
| `reveal` | impact.soft | `.impact(flexibility: .soft)` | first insight; new fact blooms on the map; first episode ready (ON-13 pop); brief becomes ready |
| `sheetSnap` | impact.soft | `.impact(flexibility: .soft)` | a sheet settling at its height (player, paywall rise M06) |
| `listenStart` | impact.light | `.impact(weight: .light)` | listening starts |
| `listenStop` | impact.medium | `.impact(weight: .medium)` | you stop / thinking |
| `recordStart` | impact.medium | | recording starts |
| `recordStop` | impact.light | | recording stops |
| `skip` | impact.light | | skip ±15/30 |
| `refresh` | impact.light | | pull past threshold |
| `longPress` | impact.medium | | message long press menu |
| `typeOn` | impact.soft @ 0.35 | `UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.35)` | each word of an onboarding question as it types out; ≤ 10/s; silent on spaces/punctuation; stops when listening starts; off under Reduce Motion |

Rules: `prepare()` when likely (field focused, sheet grabbed, question starts); at most one haptic per 80ms; none during scroll; none when system haptics are off; always paired with a visual change; never on every list row.

## B10. In Swift (§10)
`RMotion` generated from tokens (`static let snappy: Animation = .spring(response: 0.25, dampingFraction: 0.82)`, `standard(_:)`, `exit(_:)`, `move(_:)`, `reveal`, `spin`); views never write raw `.spring(...)` or numbers. `RHaptic` maps tokens to `SensoryFeedback` + `RHaptic.typeOn()` on a prepared soft generator. Modifiers: `.rPress(scale:haptic:)`, `.rAppear(index:)`, `.rPop(trigger:)`, `.rFloat(amplitude:period:)`, `.rShake(trigger:)`, `.rBlurReplace()`, `.rScrollLag()`. Each component `#Preview` includes an interaction preview (a button that runs the transition). Motion lab: `-DesignLab` → motion/foundation pages (`RLabPage` enum, `-DesignLabPage <name>`).

---

# C. Signature moments M01–M13

Sources: `docs/design/microinteractions-plan.md` (table + founder answers 21 Oct), `motion-system.md` §6, progress map §8 (M bytes), plan §5 flow passes. **Acceptance for every M (microinteractions "Process"):** (1) Storyboard in Paper: a 4–6 frame filmstrip with timings, in its component's 02b section, red dot until approved; (2) Prove: a SwiftUI preview per moment in `DesignSystemV2/Motion/` using `RNumber` durations and the springs, run on a real iPhone, screen recording next to the filmstrip; (3) Build: only approved moments go into screens, in each screen's PR; (4) Check: Reduce Motion, VoiceOver announcements (#3, #4, #8) and 60fps on the oldest supported phone; plus the §9 visual pass and **founder sign-off** (§9.8). Order: #4 and #7 first (onboarding conversion), then #2, #3, #8, then the rest. Selection rules: answers a question the user just asked; interruptible and follows the finger; one lit thing moves at a time; felt as well as seen (one haptic, at landing); RM = 140ms cross-fade. Each M byte in the progress map is "each with its motion visual pass".

| # | Byte name (progress map) | Screen / where | Trigger | What happens (plan) | Motion-system detail (newer) | Tokens | Haptic | Flow pass |
|---|---|---|---|---|---|---|---|---|
| M01 | orb breathes, satellites drift (splash) | ON-1/2 splash | app opens | the orb breathes once, then satellites drift into orbit, staggered 60ms | orb breathes once on `curve.reveal`; satellites drift with overlapping keyframes ("the founder's splash D motion"); life: halo opacity 0.35 ↔ 0.5 every 6s | `spring.map`, `duration.reveal` | none | (not listed in L1; see F) |
| M02 | listening glow follows your voice | ON-3–9 (and JR-1 talking) | you start talking | the listening field glows from the bottom edge; glow height follows voice level live, **capped so it never jumps** (founder) | rises on `gentle`, smoothed 120ms, capped 1.3× | `duration.voicePulse` | `listenStart` / `listenStop` | L1 |
| M03 | answer word ink-sharpens | ON-3–9 | your answer is understood | the key word ("london") sharpens out of a 1.5pt blur into ink | 280ms ink-sharpen | `blurReplace`, `duration.slow` | `confirm` | L1 |
| M04 | + connect → connected, meter fills (and the "knows you well" pop) | ON-6 | tap "+ connect" | pill presses 0.94 → spinner → "● connected"; knows-you meter fills one step and its label rolls ("a little → better → well"); **reaching "knows you well": gauge glows once, label rolls, one `confirm`** (founder) | dot 0 → 1 on `pop`; meter `curve.move` 420ms; "well" pop on `pop`; failure: shake 6pt ×3 on `snappy` + `warning` | `pressIn/Out`, `numberTick`, `spring.map` | `press`, then `confirm` as the meter lands | L1 — "the one that matters most for the business" |
| M05 | getting ready honest steps | ON-10 | episode being made | the tiny progress hairline moves in honest steps (no fake percentage); each new stage label blur-replaces | progress steps `curve.move`; latest design is the brief-card being-made state with tags popping in and sliding into the card | `duration.slow` | none | (not listed in L1; see F) |
| M06 | player shrinks into mini-player, paywall rises | ON-11 → ON-12 | the paywall rises | the player shrinks into the mini-player at the top (shared element) while the paywall rises out of the transcript's strongest line (paywall.md: "1.22s reveal") | shared element `matchedGeometryEffect`; paywall rises on `sheet` | `spring.sheet` | `sheetSnap` | listed under L3 (podcasts) in the map — belongs to first run (F) |
| M07 | plan glow slides, save 20% rolls | ON-12 | you pick a plan | the yearly glow slides to the chosen plan (one lit object moves) and "save 17%/20%" rolls in | save tag on `pop` | `spring.popover`, `numberTick` | `select` | L1 (needs reinterpretation under option A — F) |
| M08 | your bubble lifts, reply sharpens line by line | JR-1 | you send an entry | your bubble lifts from the composer into place; Retro's reply sharpens line by line, 60ms apart | `matchedGeometryEffect` on `sheet`; lines blur 5 → 0 240ms each | stagger 60ms, `blurReplace` | `confirm` on send | L2 |
| M09 | play morph, rolling time, chapter ticks | PC-2 (also JR-2, ON-11) | play / pause / skip / scrub | play morphs to pause; skipping rolls the time numerals; chapter marks tick as you scrub | playMorph 180ms; skip icon rotates 20° on `snappy`; thumb 1.6× (`snappy`) / 12 → 20 | `playMorph`, `numberTick` | `skip`, `chapterTick` | L3 |
| M10 | tiles lag the scroll | PC-1 | you scroll | tiles lag behind the scroll and settle | offset ≤ 6pt, tilt ≤ 1.5° ∝ velocity, `settle`, staggered by position; never when still; RM off | `spring.map` (plan) / `settle` (system) | none | L3 |
| M11 | goal card folds, bar eases | GL-1 | answer yes / not quite | the card folds away and the goal's bar eases to its new value | fold on `sheet`, list closes the gap on `map` | `spring.sheet`, `duration.slow` | `confirm` | L4 |
| M12 | new fact blooms into the map | YO-1 | a new fact arrives | a satellite blooms into the map with a soft glow; the line to "you" draws itself | scale 0 → 1 on `pop`, halo fades; line 420ms `curve.standard` | `spring.map`, `duration.reveal` | `reveal` | L5 |
| M13 | questions type out with a soft tick per word | ON-3–9 (founder 21 Oct) | Retro types out each question | each word sharpens in as it's written, with a faint soft tick per word (not per letter), ≤ ~10/s, silent on punctuation/spaces; stops when you start talking | 1.5pt blur → 0 on `curve.standard` 120ms per word; RM: whole words, no tick | `duration.typing`, `blurReplace` | `typeOn` (soft 0.35, one prepared generator) | L1 |

Flow passes (progress map §7): L1 first run "#2 #3 #4 #7 #13"; L2 daily loop "#8"; L3 podcasts "#6 #9 #10"; L4 goals "#11"; L5 you "#12"; L6/L7 none named. M01 and M05 aren't assigned to any flow pass.

---

# D. Global rules

## D1. Screen rules (`design-system/principles/screen-rules.md`, founder 20 Oct; these win over keys/craft/process)

**Words**
1. One title per screen; never a subtitle/lead-in above it; at most one short plain description under it.
2. Purpose pages (privacy, connect…) = one title + one plain description, not lists of labelled facts.
3. A purpose page gets one picture (one visual moment centred above the title, e.g. privacy's raised lock in soft rings), not more words.
4. Almost no mono: labels are Geist (`font.family.label`); mono only for figures that count/tick (times, durations, prices). No callouts, hints, "why it asks" lines or state lines in either.
5. Content is inky and big (Retro's question, your words); support is plain sans in `text.secondary`.

**Onboarding shape**
6. No skip: quiet back arrow top-left, page label centred, nothing on the right. (Conflicts with part 42 / spec — F.)
7. One global progress bar under the status bar: 3pt, `surface.track` + `ink.default` fill that creeps each turn; never a count.
8. One question per screen; Retro asks with haptics; answer by voice; type at any moment.
9. Talk or type is chosen once, with the segmented control.

**Answering**
10. The input is the onboarding text-question bar = the voice composer: 56pt pill growing upward, 32pt round button bottom-trailing; voice-first; the corner button is mute, becomes send once you type.
11. Your spoken words appear on the page under the question, inky at 28 in `text.secondary`; every new word blurs in (blur 4 → 0, opacity 0 → 1, 200ms, staggered); the bar only shows its state ("listening…").

**Choices**
12. Lead with Retro's recommendation: one raised card with the reason inside ("because you said…"); alternatives as quiet rows under "or choose another".
13. Everything for one purpose on one page; no "more" sub-pages; cut sections not needed.

**Colour and actions**
14. Blue has four jobs only: the one lit action, Retro listening, a link inside text, matched words in search results (`accent.text`, medium). Meters and progress fill with ink; selection is a raised thumb or ink tick.
15. Secondary actions obvious by depth, not colour: raised neutral pills with an icon, `text.primary` medium (not semibold).
16. Third-party sources use their real logos in their own colours as app-icon tiles (21 Oct: ON-6 uses SF Symbols via `sf:<name>` layers — founder's call).

**Depth and motion**
17. Progressive blur wherever scrolling content meets a bottom element (composer, tab bar, mini-player) — build per progressive-blur.md (one variable blur, not stacked).
18. Keep the progressive blurs and selection controls (the quality bar).
19. Tiles respond to scroll (offset + tilt on a spring); episodes and briefs are tiles, not rows.
20. The player sheet shows the page behind as a page (lighter, rounded, dimmed), title in the inky face.

**Already decided**
21. Splash = K1 constellation with sign-in; cards and gradient orbs stay; data stars emit light, never reflect it.
22. Sign-in buttons: Apple standard black; Google white raised with a warm hairline, never a dark border.
23. Light first; dark per flow after light approval.
24. Components become real 390-wide phone screens when their page is built (now 402 for 17 Pro; three sizes SE 375×667, 17 Pro 402×874, Pro Max 440×956).

**Working**
25. Show work in chunks of 3–4 screens and ask.
26. Address every Paper comment, resolve, log in the findings log.

**Journal**
27. Journal is a conversation with Retro; your messages are raised bubbles on the trailing side, each with saved → sent → read; Retro's replies unboxed on the leading side in the inky face. (Later decisions: bubbles are wash, Retro's lines SF Pro, receipts taken out in message.md — F.)
28. Today's brief anchored at the top of Journal; the thread scrolls under it (progressive blur); scrolled, it compacts to a slim bar that keeps its play.
29. Journal is one continuous thread; the drawer is its index (all-journals button top-left or edge swipe; the page slides aside, rounded and shadowed; drawer lists every conversation/note by day in your words, search on top; tapping jumps the thread).

**Spacing**
30. 8pt grid, 4pt half steps: within a group 4–8 (title + label 8 `space.stackTight`), related blocks 16 (`space.stackDefault`), between groups 24, between sections 40.
31. Screen margin 24 (20 on SE), reading width 326, primary actions in the bottom third; side-by-side items 12 apart (`space.inline`).
32. Journal: 24 between entries (`space.betweenEntries`), 40 between days, day label 8 above its first entry; composer floats 12 above the tab bar.
33. Every tappable thing has a 44pt hit area even when drawn smaller (chips 36, drawer button 36) — pad the frame.

**Paper notes:** Paper draws strokes as box-shadows; ignores colour on inline spans (word-by-word drawing); ignores `<style>` classes; no transform/zoom/mask backdrop blur/line clamp — build intent, not Paper layers.

**Handoff global rules (ios-handoff §1):** three sizes; small screens adapt, never shrink (SE: tighten section gaps one step 32→24, 24→16, drop secondary sublines, compact card versions, primary action in the thumb zone, type never shrinks); one lit object per screen (many have none); facts vs guesses (stated = inky on raised; guess = `inference.surface` + 1pt dashed border, no shadow, "a guess", yes / not quite); sheets flex (`minHeight: 0`); progressive blur at the tabs; balanced wrap for titles/short answers (not for messages); evidence rows stay one line; key states only (AX variants from SwiftUI); no invented data (empty/day-one = shapes + plain lines). Title rule (consistency pass 21 Oct): tabs large inky title; lists and settings get the small centred title; single-item screens get none.

**Dark mode rules (build notes M12):** no per-view dark code (all `RColor` dynamic); sunken darker than parent in both modes (`surface.washPressed` black 30% dark; `background.sunken` night.950); drawer and behind-sheet on `background.underlay`; paper pills/cards on tinted/raised parents use `surface.lifted` (never canvas); outer hairline in dark = white 7%; shadows black, second shadow layers without a dark value build as one layer; lit actions use dark glow set, label stays white; Sign in with Apple white in dark, Google `#131314`/`#E3E3E3`; sheets `backgroundRaised`, never canvas; system chrome unchanged; widgets follow dark; artwork steps down via palette dark twins (hand-built dynamic colours per mesh stop, keep grain); status words use dark text tokens; skip glyphs template-tinted `textSecondary`.

## D2. Craft checklist (`design-system/components/craft.md`, condensed, complete)

**§1 Touch and response** — 1.1 respond on the touch-down frame · 1.2 everything interruptible, reversed from where it is · 1.3 hand gesture velocity to the animation · 1.4 project momentum · 1.5 gestures are springs; only fades use durations · 1.6 never lock input during a transition · 1.7 44pt hit areas, pad the frame · 1.8 exits 0.5–0.7× entrances · 1.9 press weighted: in 80, out 240; small 0.94, large 0.98.

**§2 Visual centring** — 2.1 triangles move toward their point (play 1/12 of its width right; 1pt at 24, 1.5–3pt in a 44–56 circle — but founder: shipped play glyphs are already balanced, no manual offset) · 2.2 circles overshoot squares (circle 20 keyline, square 18) · 2.3 lowercase labels centre on the x-height (nudge 0.5pt) · 2.4 icon beside a label aligns to the label's x-height centre · 2.5 asymmetric padding on the icon side (−2pt: 22/20) · 2.6 ticks/checks up and right 0.5–1pt · 2.7 numbers in skip rings shift toward the arrow's open side (baked into shipped paths) · 2.8 hearts, locks, mics centred by mass · 2.9 text in a circle sits 0.5pt high · 2.10 every new glyph checked at 4×.

**§3 Shape** — 3.1 concentric corners: inner = outer − padding · 3.2 continuous (squircle) corners everywhere (`RShape`) · 3.3 true pills radius = h/2 · 3.4 strokes inside (`strokeBorder`).

**§4 Depth and light** — 4.1 one recipe: double stroke (inner white, outer warm hairline), double shadow (contact + warm cast), one of six tiers · 4.2 warm shadows, coloured objects cast their colour · 4.3 light from above · 4.4 one lit object per screen.

**§5 Colour and contrast** — 5.1 text ≥ 4.5 : 1, large ≥ 3 : 1, icons/control edges ≥ 3 : 1, by script · 5.2 disabled text exempt but beside a passing reason · 5.3 Increase Contrast raises greys a step, rings to full opacity · 5.4 never colour alone.

**§6 Gradients** — 6.1 OKLCH, eased stops (smoothstep, ≥ 5) · 6.2 never ramp distant hues: mesh · 6.3 grain on anything > 44pt (soft light 3–6%; 20% on the lit button) · 6.4 eased fades (13 stops).

**§7 Blur, edges, transitions** — 7.1 progressive scroll edges (iOS 26 soft scroll edge; iOS 18 masked material; never hard under reading text) · 7.2 text arrives with blur (blurReplace / interpolate, 4–6pt, 200–280ms) · 7.3 numbers roll (numericText + monospacedDigit) · 7.4 changing text keeps its width · 7.5 transcript reference case (lines above dim/soften, spoken sharp, next secondary, colours cross-fade, column glides) · 7.6 sheets rise with the page behind scaling/dimming on one progress value · 7.7 shared elements morph · 7.8 RM: no blur/scale, 140ms cross-fade; RT: blurs → solid.

**§8 Layout and reading** — 8.1 8pt grid, 4pt half steps; within 4–8, between groups 24–32, sections 40 · 8.2 content first · 8.3 one feature per page, one primary action per screen · 8.4 reading width 326; margin 24 (20 smallest) · 8.5 primary actions in the thumb zone · 8.6 lowercase labels/buttons/titles/tags; content keeps capitals.

**§9 Type** — 9.1 Dynamic Type everywhere (`relativeTo:`) to accessibility 3 (RType scales text and mono with UIFontMetrics, #49) · 9.2 tabular mono figures · 9.3 never below 11pt · 9.4 titles wrap to 3 lines max then ellipsis. (type.md: hero 64+ −0.04em ink −20; title 28–40 −0.035em ink −20; card headline 20–24 −0.02em ink −10; body 15–17 0 (SF Pro Text; founder: SF Pro 17 gets `tracking.card`/system tracking, never 0); label 11–13 +0.01em Geist 500/400; figure 11–15 SF Mono tabular. Exposure licensed; Hedvig fallback. No faux ink bleed.)

**§10 Haptics** — 10.1 few and meaningful (press on lit only, select, turn-taking, success, warning, error) · 10.2 prepare before the moment · 10.3 never on scroll or every row.

**§11 States** — every component documents rest, pressed, focused, pending, disabled, error, empty, loading, offline, dark, AX3, Reduce Motion, Reduce Transparency, Increase Contrast — or says why not.

**§12 Restraint** — 12.1 every element earns its place · 12.2 say a thing once · 12.3 no indicator for fast things (< 400ms; no unknown-length progress bars; no nagging counts) · 12.4 full, not empty (detail goes into depth/light/type/motion) · 12.5 every spec has a "Taken out" section.

**Checklist (run on every component):** touch-down response · interruptible · velocity handed off · 44pt targets · optical centring checked at 4× · concentric radii · continuous corners · true pills · one depth tier · warm shadows · coloured casts on colour · contrast measured (≥ 4.5 / 3) · OKLCH eased gradients, mesh not ramps, grain over 44pt · progressive scroll edges · text blur-replace · numbers roll · every state light and dark · RM, RT, IC, Dynamic Type covered · haptics only where meaningful · restraint, "Taken out" written.

**M14 ship checklist additions (`m14-agent-checklist.md` §2):** Paper values via get_jsx/computed styles; tokens only (`// literal-ok: reason` for exceptions; new tokens in tokens.json → `to-swift.mjs`; never hand-edit Generated); every drawn state built and seen on the simulator; `RShape` corners only (literal check fails bare `Capsule()`, styleless `RoundedRectangle`, `.cornerRadius(`); field hints `text.placeholder`; checks: swiftformat (excluding Generated), swiftlint, `check-swift-literals.mjs`, `validate.mjs`, `xcodebuild … BUILD SUCCEEDED`; simulator screenshot of every state beside Paper `get_screenshot`; self-review; PR title `feat(design-system): <thing> (M14 Cnn)`; PR body lists Paper nodes, values, states, checks, mismatches, decisions. Mistakes not to repeat: merging with pending checks; committing after a failed build; system `ProgressView`; unwired lab tab; formatting generated code; text styles drifting from Paper on tracking/leading; spinner strokes outside the frame; VoiceOver reading "syncing" twice; parallel agents without a disk check (`df -h /` < 5GB → stop).

**Page interaction sheet (plan §3, every page PR):** (1) how you arrive and leave (transition, spring/curve, shared elements); (2) every touchable thing: press/release, haptic (or none and why), loading/success/error motion; (3) where life is allowed and where nothing moves; (4) which signature moment lives here; (5) what Reduce Motion shows. Passes only if built as written and every motion passes the visual pass.

---

# E. Per-screen table (37 screens, P01–P37)

Sources: `ios-handoff.md` §3 (screens, states, SE decisions), plan §3 (data contracts: **live** works today · **door** agent has it, backend route needed · **new** must be built · **local**), findings/chronicle for latest changes, `midfi-product-plan-2.md` ("Lit:" per page). Approval status (21 Oct): all onboarding approved (ON-1/2 as "experiment"; ON-6 approved 21 Oct per hifi-execution-plan, though the chronicle once said "Not approved: ON-6" — confirm red dot), JR-1–4, PC-1–3, GL-1–2, YO-1–5, ST-1–9, AC-1–2, EX-1–4 approved. Paper reference for all: `06 · everything · latest` (copies; masters on 04b/05/approvals). Every page also gets a sample-data ledger entry (`docs/design/sample-data-ledger.md`) until wired. "Design switch" per screen: `design.v2.<screen>` (F10).

| P | Screen | Components | Key states (drawn) | SE (small screen) decisions | The one lit object | Data needed (§3) | M |
|---|---|---|---|---|---|---|---|
| P01 | **ON-1/2 splash + sign-in** | splash (map C38 constellation, wallpaper), inky promise + Geist subline, Sign in with Apple (system), Google white raised, legal line | rest; sign-in failing (journey map failure branch); tap-to-skip motion | not written in handoff; AC-1 rule: map scaled 0.78 on SE | none (Apple's black button leads; no glow) | Apple token → session **live**; Google sign-in **new** (B2.01); `hasSignedInBefore` Keychain flag decides splash vs AC-1 | M01 |
| P02 | **ON-3–9 the questions** (ON-3 talk/type, ON-4 your story, ON-7 more sources?, ON-8 where you're headed, ON-9 how straight) | C35 progress, C17 onboarding top bar (back · label · skip?), C34 question, quick-answer pills (C05 raised/selected), C14 voice composer + C16 listening field, C08 segmented (ON-3), recommendation card + rows (ON-9) | asking (typing out), listening, thinking, speaking, muted empty, muted typing (send lit), quick answers chosen, didn't catch that, offline, no mic | same layout; question wraps; SE detail not written | composer send only while typing (listening glow is blue job #2, not lit) | question text **door** (agent onboarding); answers **door** (`/onboarding/interpret`, B2.02); structured answers **new** (B2.04); voice **live** (device transcription; ElevenLabs via backend proxy) | M02, M03, M13 |
| P03 | **ON-5 privacy** | progress, top bar, privacy disc (C "held in blue"), inky title, plain paragraph, policy link (text.link), voice composer (Retro reads it aloud) | rest | not written | the lit lock disc (C) — not an action (F) | static **live** | (motion-moment: shackle click, halo breathes once) |
| P04 | **ON-6 connect** "i'd love to get to know you." | progress, top bar, C36 knows-you meter, C10 source rows grouped "on this iPhone" (calendar, health; music moved into "see all") and "your other apps" (google, notion, github hidden until connector exists — decision 5), "see all apps" row, raised "connect" pill / ✓ + "connected", lit "continue" + text "later" | not connected, connecting, connected, failure (shake, try again), meter steps a little/better/well | not written (rows at settings size; music didn't fit) | "continue" (lit once one source is connected); "later" always text | catalogue + connections **live**; Notion **new** (B2.06a–d); GitHub hidden (B2.07); knows-you = count of connected sources, **new** small endpoint (B2.05). SF Symbols from layer names `sf:<name>` (calendar, heart, music.note, envelope, doc.text, chevron.left.forwardslash.chevron.right, checkmark, chevron.right) | **M04** |
| P05 | **ON-10 getting ready** | progress (~92%), top bar, C34 one more warm question ("while i get your first episode ready: what's one thing you want this week to go well?"), getting-ready card (brief-card being-made variant + tilted "+ …" tags + 2pt progress hairline), "keep talking; it all goes in.", voice composer | listening; stages advancing; tags popping in | handoff (older panel): only the current stage line + footnote | none | pipeline stages **door** (`/onboarding/readiness`, B2.03); first episode as a background job (B2.08) | **M05** |
| P06 | **ON-11 the tease** | C23 player sheet (PC-2 recipe) auto-playing, titled "the week you started", ~2 min; transcript inky with progressive blur bands; correct this part; scrubber; transport | auto-playing; the paywall rising from line 2 ("here's the first thing i noticed. it's narrow, because it's day one.") | as PC-2 (transcript flexes, controls stay on screen) | none (transport never glows) | first episode audio + transcript **live** but becomes a job + push (B2.08, B2.10) | **M06** (into ON-12) |
| P07 | **ON-12 paywall** (decision 06 option A) | paused 64pt mini-player (C22 paywall variant) at top, inky one-line pitch ("hear the rest, and one every week." in older snapshot), six benefit rows C33 (three tiles off-axis), C37 plan pair (monthly raised / yearly lit + "save 20%" tag, line "yearly works out to $20.00 a month"), links restore · privacy · terms · not now, 160pt fade | rest, pressed, purchase pending, success, failed, cancelled, prices loading, offline | plans stack on very small phones (spec); six rows had to fit above the fade (row padding spacing-1) | yearly plan button | StoreKit 2 products $24.99/mo, $239.99/yr **new** (B2.11–13: purchase, restore, server validation, entitlement; fail-closed) | **M07**, M06 |
| P08 | **ON-13 first home** | C17 journal top bar, C26 brief card "your first episode is ready · the week you started · 2 min" (mesh + play), "welcome, sam." inky + "this is your journal. say anything, any time; i'll keep it and find the threads.", setup-recap card (raised, inky answers, "see all 9"), C14 composer, C18 tab bar; hint pill hidden | first day | recap shows two lines | the brief-card play (one-time `pop` + `reveal` when the episode is ready) | episode **live**; "what you told Retro" answers summary **door** | (life: one-time pop) |
| P09 | **JR-1 journal** | top bar (drawer button, inky "journal" → collapsed small name), brief card D (slim bar when scrolled), conversation C30 (+ guess card C28, voice note, recap card), C14 voice composer (mic **off** until tapped; send lit while typing), progressive blur (top grows ≤ 80; bottom ~70), C18 tab bar, mini-player if playing | talking, retro thinking, brief being made (64 compact row), first day, scrolled (collapsed bar + slim bar), sending/not sent/offline | "72 brief artwork band, no subline" (headline + play stay) | brief play (or composer send while typing — see F: two lit at once when scrolled + typing) | conversation **door** (`/conversation`, B3.01), streaming **new** (SSE B3.02–03), briefs **door** (B3.04), guesses **door** (B3.05); entries outbox (B1.07) | **M08** |
| P10 | **JR-2 today's brief** | C23 player in brief mode (now card "playing now", why "here for your goal: …", next rows, correct this part, scrubber as pill segments, transport), C19 sheet over Journal | paused, played ("played · 3 of 3"), quiet day (one inky line, one-part 40-second scrubber, no correct pill) | sheet flexes; scrubber + transport pinned above the home indicator | none | brief **door** (briefs) + ElevenLabs **live** | M09 |
| P11 | **JR-3 all entries (drawer)** | drawer (width = screen − 74, underlay), C12 search field, C31 entry rows, S13 sticky day labels, foot settings · version, progressive blur under foot | empty, searching, no results, offline | 20 margins; foot 16 off the bottom | none | **new** entry list endpoint (B3.06, from raw_content + turns), cached locally (B1.06a) | — |
| P12 | **JR-4 one entry** | entry top bar (back · edit; no title), your words inky, meta line (date · kind · state), voice-note play row (36 wash play, 2pt track, duration), "show it in the conversation" link, "what i took" rows + not right (correct glyph), delete row (thumb zone) + C19 delete dialog | voice note, nothing taken yet ("retro hasn't read this yet. it will in a minute."), editing (TextEditor in sunken field, "cancel · edit this entry · save"; delete hides with keyboard; "retro is reading it again"), offline ("waiting to send"), delete dialog | delete in the thumb zone; 20 margins | none (destructive glow only inside the dialog) | facts per entry **door** (graph/lineage, B3.07); corrections **door** (B3.08); not right strikes through 240ms + "noted" | — |
| P13 | **PC-1 podcasts** | top bar (inky "podcasts", title menu?), C27 hero + square tiles ("made for you, sam · since 12 oct"), C22 mini-player, tab bar + progressive blur | playing (mini-player; hero drops lit play), being made (compact row, grey ring, "ready sunday 9:00") | "112 hero art, 24 gaps, 161 squares, blur starts lower" | hero tile's seam play (none while its episode plays) | episodes, briefs **live** | **M10** |
| P14 | **PC-2 the player** | C23 player (episode mode), C25, C24, "…" menu (C20), C28 guess card arriving, chapter list | ready, playing (title scrolls up into header), held scrub, "…" menu, a guess arriving, chapter list | transcript flexes; controls stay on screen; blur bands 64/80 | none | audio, chapters (episode JSON), transcript **live** | **M09** |
| P15 | **PC-3 why this is here** | inside the player sheet: header ‹ back + ⌄ close + episode title; stated claim (inky 3xl + "stated · from what you did · very sure", min height 142) or asked (dashed guess card); C32 evidence rows; "where retro says it" moment card + "hear it"; not right pill | stated, asked | evidence rows one line ("…"), claim keeps its size, sheet minHeight 0 so "not right" stays in the thumb zone; moment card below the fold | none | evidence **door** (brain evidence, B4.02) | — |
| P16 | **GL-1 goals** | top bar (inky "goals" + wash `+` icon button), question card first (grey, guess icon well, two raised-paper buttons), C29 goal cards, ended row "turned off 2 · merged 1 ›", tab bar + blur, toast (end goal · undo) | none yet ("nothing yet." + "say what you're working toward, or wait and i'll notice."), a gap, too early, a guess, ended | full-width cards, 12 gaps, blur starts higher | none | goals **live** (merged main fixes); evidence **door** (B5.01); check-in push (B5.02) | **M11** |
| P17 | **GL-2 one goal** | entry frame (back · edit renames), goal inky 3xl, "said 6 times · first on … · last on …", "did this week" C32 rows, pattern as grey guess card, foot "turn off" only | turned off (dated line, guess gone, "turn back on") | sections 24 apart (32 → 24), foot 16 off the bottom; three evidence rows fit | none | goals **live**; evidence **door** | — |
| P18 | **YO-1 you** | top bar (inky "you", trailing "list" wash pill + your picture → ST-1), C12 search field (mic raised 40), C38 you map (orbits, bleeds past margins), rows "what i know about you" (subline "every fact and guess, each one you can fix") and "one question waiting · about sam", tab bar | day one ("just you, so far." / "this fills in as you talk to me.") | title spacing-2 above, field spacing-4, **map scaled 0.82** so both rows sit above the tabs | none (the field is the action, raised) | people, portrait **door** (B6.01–02); knows-you level | **M12** |
| P19 | **YO-2 search results** (in place in the You tab) | field typed (clear ×), raised result card ("what i found": inky facts, "a guess:" sentence in body/secondary, citation chips), numbered source rows (C32 number well), "only what's certain" switch row (surface.wash, radius.panel; "hides the 1 guess"), tab bar | found, nothing found (abstains, then "the closest: …") | 16 gaps; switch sits just above the tabs; top gaps spacing-4/5 | none | search answer **door** (`/search/answer`, B6.04) + sources (B6.05) | — |
| P20 | **YO-3 a source** | entry frame; your words inky; "tue 14 oct · 7:40 · written · read"; "show it in the conversation"; "this supports" rows (a belief, a goal) | — | as JR-4 | none | evidence and links **door** | — (lean: merge into JR-4, waiting on founder) |
| P21 | **YO-4 a node** | C19 sheet over the map (PC-3 parts): header "person · priya" + dismiss chevron; belief inky 2xl; "fairly sure · from 5 things · moved last week"; evidence rows; linked chips; still true · not right | a guess ("is this the same sam as sam okafor in your contacts?" yes, same · not quite) — where "one question waiting" lands; deep link from EX-3 | sheet flexes like PC-3 | none | **door** (people, facts, corrections) | — |
| P22 | **YO-5 what i know about you** | settings top bar (small centred title, content top padding spacing-4), "moved this week · 2 answers changed" wash row, areas as inky xl sections, answer rows (question label sm · answer body · how-sure word + 4 dots 6pt `text.secondary`/`surface.track` 2 apart · "from n things" · ›), silent area one warm sentence | thin day one (most areas silent) | 20 margins, 24 between areas | none | facts by area with sureness **door** (assertions, trust, B6.03) | — |
| P23 | **ST-1 settings** | settings bar, settings rows with 32 icon wells (approved master): your brief · listening · you · sources · privacy/account | — | — | none | local | — |
| P24 | **ST-2 daily brief** | each morning (switch) · time ↕ (local, menu) · length segmented short/standard/long + caption · play today's (raised pill) | dependent rows disable with reason when off | — | none | settings, briefs enabled **door** (B7.01); brief time **new** (B7.02 replaces the fixed 08:00 UTC cron) | — |
| P25 | **ST-3 sources** | source rows with status (connected · connect pill · reconnect · syncing ring), add a source ›, import a file › (founder: keep as is, not ON-6 grouping) | connected, syncing, needs you (reconnect), not connected | — | none | connections **live** | — |
| P26 | **ST-4 a source** | reads · helps me see (plain sentences) · last read + sync now pill · disconnect… · delete what it read… (danger, last, dialogs) | syncing, error | — | none | **live** | — |
| P27 | **ST-5 privacy** | read in the background (switch = the ambient switch; off means retro only learns from what you send it) · where it's processed › · download my data (export pill) · delete my data… | export pending/ready; delete dialog | — | none | export + delete **new** (B7.03, B1.12); ambient preference **door** | — |
| P28 | **ST-6 how straight** | four choices with one ink tick · "picked by retro" + why · your choice wins ("let it decide") | — | — | none | preference **door** | — |
| P29 | **ST-7 voice and listening** | voice (sample pill) · speed ↕ · talk or read segmented | sample playing | — | none | persona **live**; speed and mode **door** | — |
| P30 | **ST-8 what i've learned** (how Retro adjusts its questions — a different thing from YO-5) | one inky sentence · the plain why · last changed | too early | — | none | onboarding/question stats **door** | — |
| P31 | **ST-9 account** | your plan (yearly · renews on … · price) · manage subscription ↗ ("in apple settings") · restore purchases · sign out (full-width raised secondary + `sign-out` icon + caption "signed in with apple. your entries stay; sign back in any time.") · delete account… (danger, last) | restore pending; delete dialog | — | none | StoreKit **new**; renewal + manage link (B7.04); deletion **new** (B1.11) | — |
| P32 | **AC-1 sign in, returning** | splash wash + you map (orbits, no names) + field stars, "welcome back.", the splash's real Apple/Google buttons | restoring (ring + "bringing back your entries and episodes…", buttons disabled), failed ("that didn't work. nothing is lost; try again." above the buttons) | same 56 buttons, centred words in a shorter middle, 16 bottom padding, map 0.78 | none | session **live**; trigger flag `hasSignedInBefore` | — |
| P33 | **AC-2 signing out** | C19 sign-out sheet over ST-9 | unsent present ("send, then sign out") / nothing waiting ("sign out") | not drawn at SE | "send, then sign out" (lit) | session **live**; outbox **new** (B1.07) | — |
| P34 | **EX-1 share** | system share sheet: cancel · "save to retrospect" · raised card (56 mesh thumb, semibold title, site · length; retro's read inky xl + "goes with" goal chip + change below a hairline) · bottom zone: "add why" compact composer C13 (mic first, raised 40) + **save** | reading, saving, saved ("it'll be in tomorrow's brief"), offline (queued), video (transcript fetched) | — | save | share extension (B8.03), outbox | — |
| P35 | **EX-2 lock screen / Live Activity** | system now-playing (brief mesh, title = part being spoken, "retrospect · tuesday's brief · part 2 of 3", ↺15 ‖ 30↻) | playing, paused | system | n/a | Live Activity **live** | — |
| P36 | **EX-3 notifications** | three private-by-default kinds, ≤ 1/day, never at night; deep links brief → JR-2, episode → PC-2, question → YO-4 | — | system | n/a | push **new** (B2.09–10, B4.01, B5.02, B8.04) | — |
| P37 | **EX-4 widgets** | small (mark 16 · "tell me…" inky · "talk to retro"), medium (mark + "today's brief · 4 min" + inky headline + play / talk wash pills), 170pt small | ready, playing, played, quiet, being made, error/offline, brief off | system sizes | n/a | widgets **new** (B8.01, B8.02) | — |

Not in the 37 but required: **force-update screen** (X02, undesigned); **YO-6 a question waiting** (mid-fi only; folded into YO-4's guess state); **chapter list** (PC-2 state); **"…" menu**; **sources sheet** (from the why line).

---

# F. Conflicts and inconsistencies (with the newest source)

Dates: all 20–21 Oct 2026. "Newest" = the later dated source; Paper wins over all docs (checklist §2).

1. **Prices and saving.** paywall.md: "save 33%", "yearly, $39.99 a year, $3.33 a month". Handoff decision 06 + p63 snapshot + p61 AC-2 snapshot ("renews on 3 march · $199.99"): $19.99 / $199.99, save 17%, "$16.67 a month". motion-system `pop` row and microinteractions #7: "save 17%". **Newest: plan §8 Q4 + goal prompt + chronicle 21 Oct: $24.99/mo, $239.99/yr, save 20% ($20.00/mo); Paper updated on 57 texts; progress map M07 "save 20%".** Real prices always from StoreKit. `SubscriptionManager` changes in B2.
2. **Paywall plan design.** paywall.md: plan buttons 345×60 with a "save 33%" badge (mono 11 `accent.border/text`), five benefit rows with live drawings. **Newest (decision 06 A, approved 21 Oct):** one-line 52pt buttons, unit lighter, "save 20%" raised-paper capsule with `glow.primary.ring` hairline + `accent.text` on the yearly top edge, a quiet line above; paused 64pt mini-player at top; **six** benefit rows (search added third), tiles redrawn as plain design-system glyphs with three off-axis. paywall.md needs rewriting.
3. **M07 vs option A.** microinteractions #7 "the yearly glow slides to the chosen plan" assumes a select-then-subscribe flow (option B, archived). In A the plans are the buttons, so there's no "chosen plan" state. **Founder decision:** drop the slide, or animate only the save tag (`pop`) and the press.
4. **Onboarding "skip".** screen-rules 6 (founder) and mid-fi goal 21: **no skip**. onboarding-question.md rule 3: "MUST allow 'skip' (Geist medium 14, top trailing)"; handoff part 42 "back · skip"; p61 ON-10 snapshot shows "skip". Part 42 was approved with skip drawn. Paper wins by process, but the founder's own rule says no. **Founder decision.**
5. **Message receipts.** screen-rules 27: "each with saved → sent → read"; mid-fi goal 4 "saved → sent → read on every capture… shows on your latest message". message.md (M3, approved part 08): "No read receipts, no timestamps on every line, no 'delivered'"; sending = 70% opacity, no word. **Newest approved drawing = message.md/part 08; check Paper JR-1 for any state word on the latest bubble.**
6. **Your bubble look.** screen-rules 27 "raised bubbles"; message.md + part 08: wash bubble, no shadow. Retro's text: screen-rules "inky face" vs part 08 decision A "SF Pro" (founder: "sexy as hell"). **Newest: part 08 (wash, SF Pro).**
7. **Transcript colours.** craft §7.5: past lines 0.55 opacity, next `text.secondary`. Build notes (20 Oct): past `text.tertiary`, next `text.secondary`. **Newest: player.md 21 Oct: every non-spoken line `text.tertiary`** (founder quote). IC: past lines 70%.
8. **Transcript size.** build notes "Exposure 399, 20pt, −0.02em, 1.3, 20 between lines"; player.md `text.xl`, but token `font.size.xl` = **22pt**. Take the size from Paper.
9. **Scrubber.** scrubber.md: one track with 2pt chapter gaps; thumb 1.6× (`scale.scrubThumb`); time bubble mono 13 on `background.inverse` radius 8. **Newest (build notes 20 Oct, approved part 09): chapter capsules with 4pt gaps; thumb 12 → 20; one-line raised 32pt capsule bubble with the chapter name (Geist 500 14); times follow the finger in the row below, whose chapter label fades out; seek on release.** Also brief scrubber spacing fix (c-ktepmd) applies to JR-2 masters; PC-2 and ON-11 "were not changed yet, pending the founder's call".
10. **Mini-player progress.** mini-player.md: 2pt `player.progress` hairline. Build notes "Mini-player progress · C fill (c-wx86ve)": amber.300 22% pill fill — and handoff part 45 says "(C fill, see build notes)". **Newest: findings c-4d5kcg — C archived; board shows only A (the line), "which the founder liked".** The build note and handoff are stale.
11. **Mini-player size token.** `size.miniPlayer` = 42pt (the old paywall variant) but the floating player is 64 high; spec's paywall variant (286×42) is superseded by the 64pt paused pill. **Needs a token fix** (`size.miniPlayer` 64 or a new name).
12. **Composer send.** composer.md rule 3 "NEVER glow the send" (struck) and build notes Composer bullet 1 "the send stays raised, never lit". **Newest: founder "this button needs color" — send is lit** (build notes later bullet; approved part 07).
13. **Composer min height.** token `size.composer.minHeight` 44; composer.md 48; voice composer 56 (32 + 12 + 12); Paper (per #54 finding) 48. Fix the token or add `size.voiceComposer`.
14. **Listening look.** voice-composer.md anatomy: 1pt `voice.listening` hairline; state table: 1.5pt ring; build notes "Composer (more)": 1pt hairline + halo below 0 10 28 −10. **Newest: c-mi7i0c — 0.5pt `glow.primary.ring` + even halo 0 0 24 −6, bars 6/10/14/9/5.** ON-4a's irregular four-glow is screen-only until the founder makes it the rule.
15. **Talk button (C15) obsolete?** talk-button.md is a full spec, but voice-composer.md took out "the big 72pt talk button" and Journal uses the composer mic. **Founder/main session decision: build C15, or drop the byte.**
16. **Listening field (C16) undefined.** motion-system: "glow rises from the bottom edge on `gentle`… capped at 1.3×"; voice composer: halo all round. No spec or Paper board for a separate field. **Needs a definition (likely the composer halo driven by level).**
17. **Getting-ready panel.** handoff: three stage rows (success disc / spinner / ring). Newest (findings c-y8vj32 → c-koui68): brief card being-made state + tilted tags + 2pt **accent** progress hairline. Conflicts with surfaces.md "progress and meters fill with ink, not blue". **Use Paper; flag the blue hairline.**
18. **Hint pill and recap.** handoff lists `c:hint/1-of-3` and a grey recap. **Newest: hint hidden (c-dnuru5, c-mn0d3s); recap raised paper card with inky answers (c-g5keu2, c-mn0d3s).** p61 snapshot is stale.
19. **ON-6 connect.** handoff: two groups incl. music in "on this iPhone"; "raised 'connect' pill, or a checkmark + 'connected'". Chronicle 21 Oct (later): restyled to match settings, knows-you meter added, music moved into "see all", title "i'd love to get to know you." (after "the more i know, the more i notice" read surveillance-y). microinteractions say "+ connect" → "● connected". GitHub: hide until its connector exists (plan Q5). **Newest: chronicle/Paper.** Approval: hifi-execution-plan says approved 21 Oct; the chronicle's first 21 Oct entry says "Not approved: ON-6" — confirm.
20. **The mark.** the-mark.md: glyph `icon.mark` at 35%, inset 9 at 38; "no animation"; audit "glyph isn't drawn". **Newest: handoff 21 Oct — asset `retrospect-loading-mark`, ≈ 53% of disc width, template-tinted `RColor.iconMark`; now in all 27 places.** motion-system says pull-to-refresh "the mark spins on `spin`" and "Splash and the mark: the orb breathes" — the mark must never move per its spec; motion-moments says the splash **orb** stretches on pull. **Use the orb, not the mark, for refresh** (or founder decides).
21. **Tab bar blur.** tab-bar.md: starts 90pt above, 0.5 → 8pt, one 10pt blur. Build notes: (a) ~120pt, 14pt, saturation 1.5; (b) 150pt, 20pt, saturation 1.6 + amber/sky colour gradient (c-axmhuk); (c) opaque canvas under tabs + ~100pt fade (c-z28ko7). **Newest single source: progressive-blur.md — ~70/60pt band, 14pt, ×1.5, canvas tint bottom ~56pt, opaque canvas under the tab bar** (c-81biud shortened 20 Oct).
22. **Tab bar motion.** tab-bar.md: change = 140ms cross-fade + `tab`. motion-system: `.symbolEffect(.bounce)` once. motion-moments: one-frame emphasis swap with tiny scale settle. Tab icons are custom template SVGs (no SF Symbols for these), so `.symbolEffect` won't apply. **Use a scale settle on `snappy` + weight swap; confirm.** Also only journal has an emphasis glyph so far.
23. **Sheet Reduce Motion.** sheet-and-dialog.md and player.md: "fade and 24pt slide"; motion-system §1/§8: "every spring and move becomes a 140ms cross-fade". Newer: motion-system (21 Oct). Pick one; lean motion-system.
24. **Sheet scrim / dialog width.** player.md: scrim to 40%; sheet-and-dialog dark scrim black 60%; AC-2: `night-900` at `opacity.disabled`. Dialog: `layout.dialogWidth` token 300 vs drawn 342 (screen − margins). **Token should follow the drawing (full width minus margins).**
25. **Dialog radius.** sheet-and-dialog: `radius.field` 12; composer.md says `radius.field` (20) — composer.md is wrong (token = 12; it means 20 = `radius.card`?). Check Paper for the composer's grown radius.
26. **Message width.** token `layout.messageMaxWidth` 0.78 vs build note `column * 0.8` (≈280 on 17 Pro). **Newest: build note c-mjy9uu (0.8).**
27. **You map values.** you-map.md: nodes 12 → 44, you 56, drift ±1pt, labels mono 11, curved/legend-free. Tokens: `size.map.nodeMin` 8, `nodeMax` 56. motion-system life: ±2pt, 6–9s. Build notes: straight threads, frosted orbs, labels on canvas plates, hand-crafted. **Newest: build notes + Paper master; mono labels conflict with the almost-no-mono rule (use Paper's font).** Map versions B/C (part 50) were awaiting a pick.
28. **Guess look.** guess-card.md: dashed `inference.border`, no shadow. Goals (c-2hj9da, c-0py4uz): grey `surface.wash`, no dash, guess icon well, raised-paper buttons; the player guess card, PC-3 asked claim and YO-4 still dashed. The founder was asked "whether grey should become the guess style everywhere" — **open.** Guess tag (#46): softer dash in `border.strong` + 4pt `inference.marker` dot, pending.
29. **Goals question buttons.** build notes "Goals list: two equal-width grey buttons (surface-wash…)" (c-r3vl19) vs later "Goals: retro's question card… raised-paper buttons" (c-2hj9da). **Newest: raised paper (`surface.lifted`).**
30. **Brief card while playing.** brief-card.md rule 4 "MUST turn the play glow off while playing" vs state table "playing: the card does not change" (founder). And JR-1 when scrolled + typing: slim bar's 40 lit play plus the composer's lit send = two lit objects. **Founder/system decision** (lean: the slim bar's play drops its glow while the composer has words, or the send wins).
31. **Brief card / widget labels in mono.** brief-card.md top line mono 12, lock-screen widget "today's brief" mono 11, talk-button "type" mono 11, guess-card why line mono 12, goal labels mono 11, toast mono 13, player pills mono 12 — vs screen-rules 4 / type.md (Geist for labels; mono only for counting figures). **Newest rule: Geist, except figures; follow Paper per element.**
32. **Widgets.** lock-screen-and-widget.md small widget = brief (mark 16, "today's brief" mono 11, serif 15 headline, wash play). **Newest: handoff EX-4 (approved) — small = mark + "tell me…" + "talk to retro"; medium = brief headline + play/talk pills.** Lock screen subtitle: spec "chapter" vs handoff "retrospect · tuesday's brief · part 2 of 3", title = part being spoken.
33. **Transport play centring.** transport.md/player.md: play 1.5pt right of centre. **Newest: build notes — shipped glyph centred by its own frame, no manual offset.**
34. **Transport tray recipe.** transport.md: `background.sunken` + inner shade. **Newest (audit masters table, part 09): `surface.washPressed`, darker than its parent**; dark per build notes.
35. **`press` haptic on non-lit controls.** motion-system/craft: `press` only on lit or destructive actions. Specs put `haptic.press` on the mini-player play well, transport play well and composer wells (all non-lit). **Decide (lean: follow craft; no haptic on non-lit presses).**
36. **Send haptic.** M08 and motion-system: `confirm` on send. composer.md pressed(send): `select`. motion-moments: `press`. **Newest: motion-system (`confirm` when the bubble lands).**
37. **Scroll-lag spring.** microinteractions #10 `spring.map`; motion-and-transitions + motion-system: 0.45/0.7 = `settle`. **Newest: motion-system (`settle`).**
38. **M01 splash motion.** microinteractions #1: orb breathes, satellites drift, `spring.map`/`duration.reveal`. motion-system §6: "(the founder's splash D motion)". Splash keyframes kept: A, B2, B3, D; ON-1/2 approved only as "experiment". **Founder decision: which opening ships.**
39. **Privacy disc is blue.** Part 44 C ("held in blue", founder's pick) makes the lock a lit disc in a sky glow, which isn't one of the four jobs of blue and isn't an action; the voice composer below is also listening (blue). Founder's explicit pick, so build it, but note it in the PR.
40. **Flow-pass assignments.** M06 (ON-11 → ON-12, first run) is listed in L3 (podcasts); M01 and M05 aren't in any L. Fix the progress map.
41. **Onboarding progress semantics.** "creeps forward each turn" (rules) + "jumps at each stage" (spec) + "never by percentage" (motion-system) + S07 VoiceOver reads a percentage (#38 review note). **Decide the VoiceOver wording** (no visible count either way).
42. **Drawer width.** mid-fi 276pt vs build notes "screen width − 74 on every device". **Newest: build notes (M4).**
43. **Drawer search highlight.** drawer note: matched word on `surface.wash.pressed`, medium, "not blue". Later founder rule (search and type, and screen-rules 14): matched words in search results are `accent.text` medium (blue). The later rule is about YO-2 search; for the drawer, check Paper part 23.
44. **Evidence divider.** part 41 rows: 1pt `border.subtle`; settings rows: 0.5 `border.subtle` per settings-row.md; `RHairline` uses `border.strong` (part 22: "hairline moved to border.strong (subtle was invisible)"). Use each part's own drawing.
45. **Dark artwork.** handoff "Dark mode (M12)": artwork meshes keep palette colours. **Newest: build notes 21 Oct — artwork steps down via palette dark twins** (hand-built dynamic colours per mesh stop).
46. **Sign-out sheet fill.** p61 snapshot: `background.canvas`. **Newest: build notes 21 Oct — sheets are `backgroundRaised`, never canvas** (Paper fix queued).
47. **Tokens drift.** Working-tree tokens.json lacks main's motion tokens; specs cite non-existent `gradient.*`, `depth.tint.artwork`, `opacity.grain-*`-style names; `size.searchField` 36 vs Paper field 48 (`size.fieldWell` added on #53); `icon.weightEmphasis` = "semibold" vs the 2.2-stroke outline. **Use origin/main tokens; add missing tokens via tokens.json only.**
48. **Placeholder contrast.** `text.tertiary` on `surface.washPressed` failed AA (3.73 : 1) in light; **resolved by the founder: new `text.placeholder` token (#53), "just passes".**
49. **Toast.** toast.md (black inverse pill, mono 13, no icon, 240ms rise, 160ms leave) vs founder rounds (frosted, icon in a 28 wash well, SF Pro 14 medium, four looks in `RToast.Look`) vs motion-system (popover in, 2pt float, 4s auto-dismiss on `curve.exit`). **Newest: #48 + founder's pick pending.**
50. **YO-3 redundant.** Board lean: merge YO-3 into JR-4 (a tapped source opens JR-4 with a "this supports" section). **Waiting on founder**; YO-3 is approved as a screen.
51. **PC-3 header ⌄.** ‹ back and ⌄ close both in the header; sheet rule "no close button on sheets with a grabber". Founder may drop ⌄ (open).
52. **"…" menu items.** Only "chapters ›" and "download" confirmed; "The founder hasn't confirmed the menu's other items yet" (AirPlay lives in more per player.md).
53. **Too-early copy / goal ring tokens.** goal.md lists `size.goal.ring/ringStroke` (unused by the bar design); motion-moments "the goal's ring closes" — there is no ring in the approved card. Ignore ring references.
54. **Life budget on PC-1.** motion-moments: tile meshes "drift a few percent" plus scroll lag; life rule: one ambient motion per screen and never on content you read. Lean: no mesh drift (scroll lag isn't ambient; it's a response).
55. **Search field token / placement.** YO-2 top bar "still has the old 'list' text and grey mic" (finding) — YO-1 got the pill and raised mic; they should match.

## Founder questions collected (for the main session to ask, one at a time)
- Paywall M07 under option A (3); skip on onboarding (4); receipts on your latest message (5); whether C15 talk button is still needed and what C16 is (15, 16); blue progress hairline on ON-10 (17); grey guess everywhere (28); two lit objects on JR-1 when scrolled + typing (30); `press` haptic on non-lit wells (35); which splash opening ships (38); refresh motion uses the orb, not the mark (20); YO-3 merge (50); PC-3 ⌄ (51); "…" menu items (52); toast look (49); onboarding progress VoiceOver wording (41); force-update screen design (X02, undesigned).
