# Microinteractions plan

The system behind these moments (every curve, spring, ramp, haptic and part) is in `design-system/principles/motion-system.md`. The build plan is in `docs/design/swift-implementation-plan.md`.

**Bottom line:** twelve signature moments, one per key screen, each built from the motion and haptic tokens we already have. Every moment does one of three jobs: it confirms what you did, it shows Retro listening, or it rewards you for giving Retro more. We storyboard each one in Paper, prove it in a SwiftUI preview on a real phone, and only then build it into the screen. Nothing decorative ships.

## How we decide what earns motion
1. **It answers a question the user just asked.** Did it hear me? Did it save? Did that connect?
2. **It's interruptible and follows the finger.** Springs for gestures, short fades for everything else (principles/motion-and-transitions.md).
3. **One lit thing moves at a time.** The glow (the primary blue) is the hero of every moment; everything else stays calm.
4. **It's felt as well as seen.** We pair it with one haptic from `haptic.*`, and only at the moment it lands.
5. **Reduce Motion gets a 140ms cross-fade.** Same meaning, no scale, blur or overshoot.

## The twelve moments

| # | Screen | Trigger | What happens | Tokens | Haptic |
|---|---|---|---|---|---|
| 1 | ON-1 splash → sign-in | App opens | The orb breathes once, then the satellites drift into orbit, staggered 60ms | `spring.map`, `duration.reveal` | none |
| 2 | ON-3–9 questions | You start talking | The listening field glows from the bottom edge, and the glow's height follows your voice level live | `duration.voicePulse` | `listenStart` / `listenStop` |
| 3 | ON-3–9 questions | Your answer is understood | The key word ("london") sharpens out of a 1.5pt blur into ink | `blurReplace`, `duration.slow` | `confirm` |
| 4 | **ON-6 connect** | Tap "+ connect" | The pill presses (0.94), turns into a spinner, then into "● connected". The *knows you* meter fills one step on a spring and its label rolls ("a little → better → well") | `pressIn/Out`, `numberTick`, `spring.map` | `press`, then `confirm` as the meter lands |
| 5 | ON-10 getting ready | Episode is being made | The tiny progress hairline moves in honest steps (no fake percentage), and each new stage label blur-replaces | `duration.slow` | none |
| 6 | ON-11 the tease | The paywall rises | The player shrinks into the mini-player at the top (shared element) while the paywall rises out of the transcript's strongest line | `spring.sheet` | `sheetSnap` |
| 7 | ON-12 paywall | You pick a plan | The yearly glow slides to the chosen plan (one lit object, it moves), and "save 17%" rolls in | `spring.popover`, `numberTick` | `select` |
| 8 | JR-1 journal | You send an entry | Your bubble lifts from the composer into place; Retro's reply sharpens line by line, 60ms apart | stagger 60ms, `blurReplace` | `confirm` on send |
| 9 | PC-2 player | Play / pause / skip | Play morphs to pause; skipping rolls the time numerals; chapter marks tick as you scrub | `playMorph`, `numberTick` | `skip`, `chapterTick` |
| 10 | PC-1 podcasts | You scroll | Tiles lag behind the scroll and settle (already specified, 20 Oct) | `spring.map` | none |
| 11 | GL-1 goals | Answer "yes / not quite" | The card folds away and the goal's bar eases to its new value | `spring.sheet`, `duration.slow` | `confirm` |
| 12 | YO-1 you | A new fact arrives | A satellite blooms into the map with a soft glow, and the line to "you" draws itself | `spring.map`, `duration.reveal` | `reveal` |
| 13 | ON-3–9 questions (founder, 21 Oct) | Retro types out each question | Each word sharpens in as it's written, and you feel a faint soft tick with each word: one per word, not per letter, never more than about 10 a second, and silent on punctuation and spaces. It stops when you start talking | `duration.typing`, `blurReplace` | `typeOn` (soft impact at 0.35 intensity, one prepared generator) |

The one that matters most for the business is **#4**: every connected app visibly makes Retro know you better, which is the incentive your 21 Oct comment asked for.

## Process (same gates as hi-fi)
1. **Storyboard.** In Paper, each moment gets a 4–6 frame filmstrip with timings written on it, in its component's 02b section. Red dot until you approve.
2. **Prove.** A SwiftUI preview per moment in `DesignSystemV2/Motion/`, using `RNumber` durations and the springs, run on a real iPhone. A screen recording goes next to the filmstrip.
3. **Build.** Only approved moments go into the screens, during M14, as part of each screen's PR.
4. **Check.** Reduce Motion, VoiceOver announcements (#3, #4, #8) and 60fps on the oldest supported phone.

Order: #4 and #7 first (onboarding conversion), then #2, #3 and #8 (the daily loop), then the rest.

## Founder's answers (21 Oct)
- #2: the listening glow **follows your voice level live**, capped so it never jumps.
- #4: reaching "knows you well" gets **a small moment**: the gauge glows once, the label rolls, one `confirm` haptic.
