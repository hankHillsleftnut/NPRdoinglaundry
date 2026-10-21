# motion system · how everything moves, sounds and feels

**Bottom line:** nothing in Retrospect moves on a straight line. Things with weight move on springs and settle with a small, calibrated bounce. Fades and colour changes ease on curves. Every haptic lands on the frame where the motion lands. A few quiet moments of life make the app feel awake: a toast that floats, map nodes that breathe, a card that settles a little off-axis. Every motion gets a visual pass on a real phone before it ships.

This is the reference for the Swift build (M14). The SwiftUI names given here are what the code uses. `principles/motion-and-transitions.md` keeps the research and the choreography rules; this file is the system. The per-screen moments are in `docs/design/microinteractions-plan.md`.

Founder's brief, 21 Oct: *"good easing curves, nice springs, elements that feel good and bounce and move around once in a while… little pop-ups that move a little… everything smooth and well calibrated; the ramps are really important… nothing linear… a visual pass for every one when implemented."*

---

## 1. The rules

1. **Never linear.** A linear ramp is only allowed for something tied to real time: audio progress, a recording timer, a scrub that follows your finger 1:1. Everything else uses a spring (§3) or a curve (§2).
2. **Springs for anything that moves; curves for anything that only fades or changes colour.**
3. **Everything is interruptible.** A new touch catches a motion where it is and carries on from that position and velocity. Never jump back to the start, never queue.
4. **Gestures hand their velocity to the spring.** A flick keeps its speed into the settle (§4).
5. **Bounce is earned.** Controls barely overshoot (≤1.5%). Things that pop into view overshoot a little (3–5%). Only celebrations overshoot more (~10%). The lit button never wobbles.
6. **Exits are faster than entrances**, about 65% of the entrance.
7. **Respond on touch down, in the same frame.** The press is felt before anything opens.
8. **One hero per moment.** The glow (the lit blue) moves; everything around it stays calm.
9. **Life is rare and slow** (§7): one ambient motion per screen at most, and it stops the moment you touch.
10. **Haptics land with the visual landing**, not at the start. They're prepared ahead and never fire on scroll.
11. **Reduce Motion keeps the meaning:** a 140ms cross-fade, no scale, no blur, no bounce.

---

## 2. Curves (for fades, colour, blur)

| Token | Bezier | Feel | SwiftUI | Use for |
|---|---|---|---|---|
| `motion.curve.standard` | 0.16, 1, 0.3, 1 | Fast start, long soft landing (expo-out) | `.timingCurve(0.16, 1, 0.3, 1, duration:)` | Anything appearing: fades in, blur-replace, colour changes |
| `motion.curve.exit` | 0.4, 0, 1, 1 | Gathers then leaves | `.timingCurve(0.4, 0, 1, 1, duration:)` | Anything leaving for good |
| `motion.curve.move` *(new)* | 0.65, 0, 0.35, 1 | Symmetric in-out | `.timingCurve(0.65, 0, 0.35, 1, duration:)` | Non-gesture moves that start and end at rest: the knows-you meter fill, progress steps |
| `motion.curve.reveal` | smooth, extraBounce 0.02 | Long and calm | `.smooth(duration: 1.22, extraBounce: 0.02)` | The first-insight moment, the splash |

Durations come only from `motion.duration.*`: 80 instant, 140 fast, 200 base, 280 slow, 1220 reveal, plus the named ones (pressIn 80, pressOut 240, numberTick 320, playMorph 180, popoverExit 110…). Nothing a person waits on runs longer than 450ms; reveals are the only exception.

## 3. Springs (for anything that moves)

SwiftUI: `.spring(response:dampingFraction:)`; overshoot shown as the share of the distance it travels past the target.

| Token | response · damping | Overshoot | Feel | Use for |
|---|---|---|---|---|
| `motion.spring.snappy` *(new)* | 0.25 · 0.82 | ~1% | Firm, immediate | Press release, toggles, segmented thumb, checkmarks, tab icon |
| `motion.spring.popover` | 0.30 · 0.74 | ~3% | A small, confident pop | Menus, popovers, toasts, tooltips growing from their source |
| `motion.spring.sheetDismiss` | 0.32 · 0.90 | ~0% | Clean exit | Sheets and cards leaving |
| `motion.spring.sheet` | 0.40 · 0.86 | ~0.5% | Weighty, settled | Sheets, the player, the paywall rising, cards folding away |
| `motion.spring.map` | 0.45 · 0.80 | ~1.5% | Soft, organic | Map nodes, the meter, new items blooming in, list reflow |
| `motion.spring.settle` *(new)* | 0.45 · 0.70 | ~5% | Dragged through water | Tiles lagging behind the scroll, off-axis cards settling on appear |
| `motion.spring.pop` *(new)* | 0.35 · 0.60 | ~10% | Delight; use rarely | "Knows you well", a goal met, the first episode ready, badges, the "save 17%" tag |
| `motion.spring.gentle` *(new)* | 0.55 · 0.92 | ~0% | Big and calm | Large layout changes, the page behind a sheet scaling |

`motion.spring.*` already exists in tokens.json for map, sheet, sheetDismiss and popover. Snappy, settle, pop and gentle get added in the first Swift PR, along with `curve.move` and `haptic.typeOn`, all generated into `RMotion`.

## 4. Ramps (how a motion starts, travels and lands)

The founder called these out as the part that matters most.

- **Start:** springs start at the gesture's velocity, never from a standstill: `withAnimation(.spring(...).speed(1))` plus `DragGesture.velocity` (iOS 17+), or `.interactiveSpring` while the finger is down and the full spring on release.
- **Where it lands:** project momentum to decide where a flick ends up (`predictedEndTranslation`). Sheets close past 140pt or 800pt/s; the scrubber snaps to a chapter within 12pt.
- **Rubber band:** past an edge, movement scales by `motion.gesture.rubberBand` (0.55), and it springs back on `snappy`.
- **Stagger:** lists and groups appear top to bottom, 40–60ms apart, each on `curve.standard` at 280ms, with an 8pt rise and a blur of 8 → 0. Stagger at most 6 items, then the rest arrive together.
- **Settle:** every spring ends at rest with no visible jitter. Damping below 0.6 is not allowed.
- **Chained steps overlap** (they don't run in blocks): the next one starts when the previous is about 70% done. `keyframeAnimator` or `phaseAnimator` with overlapping tracks.
- **Interrupt:** use SwiftUI's default additive animation, never `.transaction { $0.animation = nil }` mid-flight. A tap during a sheet's rise reverses it from where it is.

## 5. Haptics

SwiftUI `.sensoryFeedback(_:trigger:)`; UIKit generators only where SwiftUI can't do it (per-word typing).

| Token | Feedback | SwiftUI | When it fires |
|---|---|---|---|
| `press` | light impact | `.impact(weight: .light)` | Touch down on a lit or destructive action, once |
| `select` / `tab` / `turn` / `chapterTick` | selection | `.selection` | Option chosen, tab changed, the turn handed back, crossing a chapter |
| `confirm` | success | `.success` | The moment a saved or connected state lands (the check appears, the meter settles) |
| `warning` / `error` | warning / error | `.warning` / `.error` | With the field shake or the failure toast, never twice in a row |
| `reveal` / `sheetSnap` | soft impact | `.impact(flexibility: .soft)` | First insight; a sheet settling at its height |
| `listenStart` / `recordStop` / `skip` / `refresh` | light impact | `.impact(weight: .light)` | |
| `listenStop` / `recordStart` / `longPress` | medium impact | `.impact(weight: .medium)` | |
| `typeOn` *(new)* | soft impact at 0.35 | `UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.35)` | Each word of an onboarding question as it types out; at most 10 a second; silent on spaces and punctuation; stops when listening starts |

Rules: call `prepare()` when a haptic is likely (field focused, sheet grabbed). At most one haptic per 80ms. None during scroll. None when system haptics are off. Pair a haptic with a visual change, never on its own.

## 6. Every part, how it moves

States use the component's own spec in `design-system/components/`.

**Buttons (lit, secondary, text) and icon buttons.** Press in 80ms on `curve.standard` to scale 0.98 (large) or 0.94 (small), with `press` haptic on lit. Release on `snappy`. The lit button's glow dims 15% while pressed and blooms back. Loading: the label blur-replaces into a spinner, and the width animates on `snappy` (never jumps). Disabled → enabled: the glow fades in over 280ms and breathes once (one 1.0 → 1.04 → 1.0 halo pulse).

**Pills and chips.** Press as above at 0.94. Selected: fill cross-fades in 140ms and the check draws in 200ms on `curve.standard`, with `select`.

**"+ connect" (source rows).** Press → the pill blur-replaces into a spinner → "● connected", with the dot scaling 0 → 1 on `pop`. `confirm` fires as the dot lands. The row's width change rides `snappy`. Failure: the pill shakes (three oscillations on `snappy`, 6pt) with `warning`, then shows "try again".

**Text fields and the composer.** Focus: the field lifts from sunken to field colour over 140ms, the focus ring fades in on `curve.standard`, and `prepare()` runs. Placeholder fades out over 80ms as the first character lands. Character count rolls with `numericText()`. Send: the text becomes your bubble and lifts into place (`matchedGeometryEffect`, `sheet` spring) with `confirm`. Error: a 6pt horizontal shake on `snappy` with `warning`, and the message blur-replaces in below. The keyboard: content moves with the keyboard's own curve (`.animation(.default)` inside `safeAreaInset`), never a separate animation.

**Search field.** Results stagger in (40ms). The "no results" line blur-replaces. Clear (×) scales in on `popover`.

**Toggle (switch).** The thumb moves on `snappy`, stretching 4pt wider during travel, and the track colour cross-fades in 140ms. `select` fires on the change.

**Segmented control.** The thumb slides on `snappy` (`matchedGeometryEffect`), labels cross-fade weight in 140ms, `select` fires. Dragging the thumb follows 1:1 and snaps on release.

**Rows (settings, value, nav).** The wash press highlight comes in at 80ms and goes out at 240ms. The chevron nudges 2pt on press. Push uses the system navigation transition (iOS 18 zoom where a tile opens its page).

**Sheets and dialogs.** Rise on `sheet`, dismiss on `sheetDismiss`. The page behind scales to 0.94, rounds to 12 and dims, all on one progress value that follows the drag 1:1. Rubber band past the top. `sheetSnap` fires at each resting height.

**Menus, popovers, title menu.** Grow from their source (from 0.86, blur 8 → 0) on `popover`, and close in 110ms on `curve.exit`. The tapped source dims for 66ms first.

**Toasts and little pop-ups.** In from the top or bottom edge on `popover`, overshooting ~3%. While visible they float: a 2pt vertical drift on a 5s sine. Swipe away follows the finger and flicks out with its velocity. Auto-dismiss after 4s on `curve.exit`. Success toasts fire `confirm` as they land.

**Tab bar.** The selected icon does `.symbolEffect(.bounce)`, once, with `tab`. The label weight cross-fades. Tapping the current tab scrolls to top on `gentle`.

**Mini-player ↔ player.** Shared element (`matchedGeometryEffect` on artwork, title and play) on `sheet`. Progress hairline is linear (real time). Play ↔ pause morphs with `.contentTransition(.symbolEffect(.replace))` in 180ms.

**Scrubber and transport.** The thumb grows to 1.6× on touch (`snappy`), and the time numerals roll. `chapterTick` fires when crossing a chapter. Skip ±15/30: the icon rotates 20° and back on `snappy`, the time rolls, `skip` fires.

**Cards and tiles.** Press 0.98. In scrolling rows: the scroll-lag tilt on `settle`. Episode tiles open with the iOS 18 zoom transition. Goal cards fold away on `sheet` and the list closes the gap on `map`.

**Off-axis cards** (the paywall's three tilted tiles). On appear they rotate from 0° to their resting tilt on `settle`, staggered 60ms, so they look placed by hand. They don't move after that.

**Knows-you meter.** Fills one step on `curve.move` over 420ms. The label rolls ("a little → better → well"). At "well": the fill glows once and the label pops on `pop`, with `confirm`.

**Onboarding progress hairline.** Advances on `map` per step, never by percentage.

**Listening field.** The glow rises from the bottom edge on `gentle`, then follows the voice level live (smoothed over 120ms, capped at 1.3×). `listenStart` and `listenStop` fire.

**Onboarding question text.** It types out word by word: each word sharpens from a 1.5pt blur on `curve.standard` (120ms), with `typeOn`. The understood answer word ("london") ink-sharpens over 280ms with `confirm`.

**Text that changes.** `blurReplace`, 4–6pt, 200–280ms. Numbers use `.contentTransition(.numericText())` with `.monospacedDigit()`.

**Loading and empty.** Skeletons shimmer every 1.4s on `curve.move`. Content replaces skeletons with a 140ms cross-fade, no jump. Empty states arrive with a stagger, then stay still.

**Pull to refresh.** Resistance follows the rubber band. Past the threshold, `refresh` fires and the mark spins on `spin` (900ms). New items bloom in on `map`.

**The you map.** Nodes enter on `map`, staggered 60ms. A new fact blooms in (scale 0 → 1 on `pop`, halo fades), the line to "you" draws itself over 420ms on `curve.standard`, and `reveal` fires. Dragging the map uses `map` with velocity.

**Splash and the mark.** The orb breathes once (`curve.reveal`), and satellites drift into orbit with overlapping keyframes (the founder's splash D motion).

## 7. Life (motion that isn't a response)

The founder wants things to "move around once in a while". The rules keep that charming rather than noisy:

- **One ambient motion per screen at most**, and only on surfaces you aren't reading.
- **Slow and small:** a period of 4s or more, at most 3pt of travel and 1.5° of tilt. Sine, never linear. Elements are out of phase with each other.
- **It stops when you touch, scroll or type,** and resumes 4s after.
- **It pauses off-screen**, in Low Power Mode, and with Reduce Motion on.

Where it lives:

| Element | Life | Spec |
|---|---|---|
| You map nodes | They breathe | ±2pt drift, 6–9s periods, staggered |
| Toasts | They float | 2pt drift on a 5s sine |
| Lit button when it becomes available | A one-time glow pulse | Once, then still |
| The orb on splash and on you | A slow halo breath | Halo opacity 0.35 ↔ 0.5 every 6s |
| Paywall off-axis tiles | They settle once on appear | Then still |
| "Your first episode is ready" (first home) | A one-time pop | `pop` spring, `reveal` haptic |

Never ambient: text, the reading column, the player transcript, fields, anything with a number in it.

## 8. Reduce Motion, Reduce Transparency, VoiceOver

- Reduce Motion: every spring and move becomes a 140ms cross-fade. There's no scale, blur, tilt, ambient motion or scroll lag, and typing shows whole words at once. Haptics stay, except `typeOn`.
- Reduce Transparency: blurs become solid surfaces.
- VoiceOver: state changes announce in words (*"Calendar connected. Retro knows you a little better."*), never only through motion.

## 9. The visual pass (every motion, when it's built)

No motion is done until it passes this on a real iPhone (ProMotion 120Hz) and on the oldest supported phone:

1. **Record it** at 120fps, and again with Slow Animations on. Attach both to the PR.
2. **Check the ramp frame by frame:** no linear segment, no jump on the first frame, no overshoot beyond its spring's row in §3, a clean settle.
3. **Interrupt it:** tap or drag mid-flight. It must reverse from where it is.
4. **Feel the haptic:** it lands on the frame the motion lands, and never doubles.
5. **Turn on Reduce Motion:** the meaning survives as a cross-fade.
6. **Check for hitches:** Instruments, Animation Hitches template, with 0 hitches over 5 runs.
7. **Compare with the storyboard** in Paper (timings written on the filmstrip). If it feels wrong but matches, fix the storyboard, not just the code.
8. **Founder sign-off** for the 13 signature moments; the rest are reviewed in the PR.

## 10. In Swift (how the code expresses all this)

- `RMotion` (generated from tokens): `static let snappy: Animation = .spring(response: 0.25, dampingFraction: 0.82)`, `standard(_ duration:)`, `exit(_:)`, `move(_:)`, `reveal`. Views never write a raw `.spring(...)` or a number.
- `RHaptic`: maps each token to `SensoryFeedback`, plus `RHaptic.typeOn()` on a prepared soft generator.
- Modifiers: `.rPress(scale:haptic:)`, `.rAppear(index:)` (the stagger), `.rPop(trigger:)`, `.rFloat(amplitude:period:)` (ambient, which checks the §7 gates itself), `.rShake(trigger:)`, `.rBlurReplace()`, `.rScrollLag()`.
- Every modifier reads `@Environment(\.accessibilityReduceMotion)` and swaps itself for the cross-fade, so screens never branch on it.
- Each component's `#Preview` includes an interaction preview (a button that runs the transition) so the motion can be judged in Xcode before it reaches a screen.
