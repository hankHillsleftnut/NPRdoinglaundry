---
name: player
kind: component (full screen sheet)
platform: iOS (SwiftUI)
drawn: Paper · components · 02 the player (full)
---

# player

Listen to an episode or a brief, and read along with it.

## What the person came for, in order
Someone who opens an episode wants to know **what it is**, then **hear and read it**, then **control it**. So the page reads top to bottom in that order:

1. **header row**: the mark, "your weekly episode", a `today` tag; share and close on the right. Small, mono, quiet.
2. **title**: the episode's one line, in the display serif. The first thing the eye lands on.
3. **why it's here**: one mono line with the guess marker: what it was made from ("from 6 entries · calendar · steps"). Tap → the sources sheet.
4. **the content: the live transcript.** The spoken line is full ink (`text.primary`); every other line, coming or already said, is the same dim `text.tertiary` (founder, 21 Oct: "the text being read should be dark, the text about to show up or already read should be dim"), and the edge blur fades them further into the bars. It *is* the page; nothing decorative competes with it.
5. **scrubber** with chapter ticks, then times and the chapter name.
6. **transport**: skip back 15 · play / pause · skip forward 30, in one capsule; more (···) on the left, speed on the right.
7. **chapters · not right**: two quiet pills. ("why it's here" is already the line under the title; a pill for it said it twice.)

There is no large artwork. A personal episode has no cover worth the top of the screen; the title is the cover. (The inspiration app leads with art because its shows are someone else's brands.)

## Use when
- Opening any episode or brief from the brief card, the mini-player, Podcasts or a notification.

## Don't use when
- The person only wants to start or pause: the mini-player and the brief card do that in place.

## Anatomy
- **sheet**: `background.raised`, top corners 38 (continuous), a 1pt white top edge (`border.highlight`) and a hairline `0 -1 0` black 20% above it where it meets the dimmed screen.
- **behind it**: the previous screen scaled to `motion.scale.behindSheet` (0.94), corners `radius.behindSheet`, dimmed by `background.scrim`; a 10pt strip of it shows above the sheet, which is what tells you it's a layer you can push away.
- **grabber**: 36 × 5, `border.strong`, 10pt below the sheet's top.
- **transcript**: `font.family.displayInky` (Exposure) at `font.weight.inkCard`, `text.xl`, `tracking.card`, `leading.snug`; `spacing.5` between lines; width `layout.readingWidth`. Founder, 20 Oct: the semibold sans read heavy and "off"; retro's spoken words are set in its inky voice, like a book.
- **scrubber**: see [scrubber](./scrubber.md). **transport**: see [transport](./transport.md): a *sunken* tray holding a *raised* play well.
- **edges:** a true progressive blur, not a duplicate blurred copy of the text: a band over the top (96pt; 64 on SE) and over the bottom (140pt; 80 on SE) blurs what is behind it (8pt, `motion.blur.enter`) under a mask that ramps 0 → full, with the sheet colour easing in on top. iOS: a variable-blur material (or `.blur` on a masked layer) on those bands. The spoken line always sits in the clear middle; on SE the column scrolls so it does. Never a hard cut.
- **sheet light:** a faint sky glow (`gradient.meshSheetGlow`) at the top left of the sheet, behind the header.
- **surface levels:** sheet = overlay (4); header buttons and pills = wash (0.5); play well and scrubber thumb = raised (2); tray and track = sunken (−1).
- **header buttons** (share, close): 34 visual *wash* circles inside 44 hit frames; icons at 17pt drawn with stroke 2 on the 24 grid (optical compensation: 1.75 would render under 1.25pt at this size).
- **pills**: height 36, radius 18, `background.canvas` with a 1pt inset `border.subtle`, mono 12 in `text.label`.

## Choreography

**Opening (from the mini-player or the brief card)**
1. Touch down on the mini-player: it scales to 0.98 (`pressIn`), no haptic.
2. Release: the sheet rises with `motion.spring.sheet` (response 0.4, damping 0.86). The mini-player's title text morphs into the sheet's title (matched geometry): it grows from 14 semibold to the 34pt serif *while moving*, so it is clearly the same thing.
3. In step with the rise, the screen behind scales to 0.94, rounds its corners to 12, and the scrim fades in to 40%. All three are driven by the same progress value, so they never drift apart.
4. The transcript fades up 8pt with a 60ms stagger after the title; the controls come last. Nothing appears before the thing above it.
5. `haptic.sheetSnap` (soft) when the sheet settles.

**Dragging down**
- The sheet follows the finger 1:1. The screen behind scales back toward 1 and the scrim lightens in proportion, so the gesture always shows where it leads.
- Pulling up past the top resists (`motion.gesture.rubberBand` 0.55).
- Release past `dismissDistance` (140pt) or faster than `dismissVelocity` (800pt/s): it leaves with `motion.spring.sheetDismiss`, carrying the finger's velocity. The title morphs back into the mini-player. Otherwise it springs back up.
- Dragging starts only from the header, the grabber or the title. The transcript scrolls; it never fights the sheet.

**Playing**
- Play ↔ pause morphs (two bars ↔ triangle) in `motion.duration.playMorph`; never a swap. The icon is optically centred: the triangle sits 1.5pt right.
- The transcript glides to keep the spoken line at the same height (`transcriptFollow` 420ms, standard curve). The colours cross-fade as a line becomes "now": no jump.
- If you scroll the transcript yourself, following pauses. A "back to now" pill appears above the scrubber, and following resumes after `followResume` (4s) of no touching.
- Tap any line to jump there; the scrubber and times move with it.

**Skipping and scrubbing**
- Skip back 15 or forward 30: the arrow turns 20° in its direction and back (160ms); `haptic.skip`.
- Hold the thumb: it grows to 1.6× (`scale.scrubThumb`), a time bubble rises above it (`scrubPreview` 120ms), and the transcript previews the line at that time.
- Crossing a chapter tick gives `haptic.chapterTick`.
- On release, the bubble falls away and play resumes from there.

**Speed**
Tap cycles 1.0× → 1.25× → 1.5× → 2.0× → 0.8×. The number rolls vertically (`numberTick` 320ms), with a `selection` haptic on each change.

**Leaving the app**
Audio keeps playing (background audio and the lock-screen player, see [mini-player](./mini-player.md)). Coming back reopens exactly where the transcript was.

## Rules
1. **MUST** open on the title and the content; controls come last. *Because* people come to an episode for what it says.
2. **MUST** move the title from the mini-player into the sheet as the same object. *Because* a cut between them breaks the sense of one thing opening.
3. **MUST** drive the sheet, the scale behind it and the scrim from one progress value. *Because* separate animations drift and the motion feels cheap.
4. **NEVER** auto-scroll the transcript while the person is touching it. *Because* fighting their finger is the worst feeling an app can give.
5. **MUST** keep the "why it's here" line on every episode. *Because* every item says where it came from (goal 11).
6. **SHOULD** fade the transcript into the controls rather than clip it.

## States
`rest`/`paused` (play shown) · `pressed` (controls: see [transport](./transport.md)) · `focused` (2pt `border.focus` on the focused control) · `pending` = `buffering` · `disabled` (not applicable to the sheet; a control that can't act, e.g. skip forward at the end, dims to `opacity.disabled`) · `empty` (no transcript: the description in its place) · `error` = `failed` · `dark` (sheet `background.raised` dark; the sky light at 60%; transcript inks invert by token) · `loading` (title and why line show at once; transcript lines as skeleton bars, shimmer 1400ms) · `playing` · `paused` · `buffering` (the play well shows a thin ring turning, `spin` 900ms; time stops) · `ended` (the last line stays; "play next" or "back to journal") · `failed` ("couldn't load this episode", retry; the transcript still readable if it loaded) · `offline` (plays if downloaded; otherwise says so).

## Accessibility
- [ ] VoiceOver order: close → title → why → transcript (as a text block, current line announced on change only if the person asks) → scrubber (adjustable: swipe up/down = ±15s) → transport → pills.
- [ ] Dynamic Type: the title and transcript grow; at accessibility 3 the transcript shows two lines and the controls stay fixed.
- [ ] Reduce Motion: the sheet fades and slides 24pt instead of springing; the title cross-fades instead of morphing; the transcript jumps line to line.
- [ ] Reduce Transparency: the scrim is solid 60%.
- [ ] Increase Contrast: past lines at 70% (not 55%); the tray and pills get a 1pt `border.control` ring.
- [ ] Every control is at least 44pt; the pills are 36 tall inside a 44 hit area.

## Taken out
- The "why it's here" pill: the line under the title already does it.
- No large artwork: the title is the cover.
- No queue, volume or AirPlay button on the face: AirPlay lives in more (···), volume is the phone's.

## Edge cases
- Very long title → wraps to three lines max, then ellipsis; the full title shows in the share sheet.
- No transcript (old episode) → the description shows in its place, same type.
- A very short brief (under a minute) → no chapter ticks; skip forward is 15, not 30.
- Phone call interrupts → pauses; resumes only if the person taps play.
- Headphones removed → pauses (iOS rule).
- SE-sized phone → the transcript area shrinks first; the title never truncates to one line.

## Tokens
`background.raised`, `background.scrim`, `border.highlight`, `border.strong`, `border.subtle`, `text.primary/secondary/tertiary/label`, `accent.subtle/text`, `inference.marker`, `font.family.display/text/mono`, `layout.readingWidth`, `motion.spring.sheet/sheetDismiss`, `motion.scale.behindSheet/press/scrubThumb`, `radius.behindSheet`, `motion.gesture.*`, `motion.duration.transcriptFollow/followResume/playMorph/scrubPreview/numberTick/shimmer/spin`, `haptic.sheetSnap/skip/chapterTick/select`.
