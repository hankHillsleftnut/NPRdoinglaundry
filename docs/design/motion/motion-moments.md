# Motion moments: purposeful, fun, everywhere

Founder, 20 Oct (c-husrfl, on the JR-1 key states): "make sure components like these are well animated, and have some fun with their animations. In fact, you should sprinkle fun animations all across the product that are elegant and already fit intended flows. Make the animations purposeful and fun."

**The rule this adds:** every moment where something *changes state for you* gets one small, characterful motion. The motion has to say what happened, and it has a little personality on top. No motion is purely decorative: if you can't name what it tells the person, it goes. Each one uses the existing motion tokens (`motion.*`, `haptic.*`). Under Reduce Motion, each one falls back to `motion.reduced` (opacity only, 140ms).

| Where | Moment | The motion (fun, but it says something) | Tokens | Haptic |
|---|---|---|---|---|
| Journal · composer | you tap the mic | the five level bars rise from flat one after another (stagger 60ms), like an orchestra lifting bows; the soft blue halo breathes in | spring.popover, stagger | listenStart |
| Journal · composer | you stop talking | the bars fold down into the three thinking dots: each dot is two bars merging | duration.base, curve.standard | listenStop |
| Journal · thread | Retro answers | the reply arrives word by word, each word blurring in (blur.enter 8 → 0), so it feels spoken, not printed | duration.typing, blur.enter | turn |
| Journal · thread | your message sends | the bubble lifts 4pt and settles (scale.enter 0.97 → 1) as if placed on the page | spring.popover | press |
| Journal · brief card | the brief becomes ready | the "being made" row's quiet well blooms into the mesh artwork; the row grows into the full card (matched geometry) and the play lights last | duration.reveal, spring.sheet | reveal |
| Journal · brief card | scrolled → slim bar | the artwork shrinks into the thumb and the headline slides beside it; the play rides along without leaving its glow | spring.sheet | — |
| Brief / player | play → pause | the play triangle splits into two bars (playMorph 180ms), never a cross-fade | duration.playMorph | press |
| Player | a chapter changes | the scrubber segment ticks over with a tiny overshoot, and the chapter name slides up one line | spring.popover, duration.numberTick | chapterTick |
| Player · transcript | the spoken line moves | the ink line glides up and the next one sharpens from grey (transcriptFollow 420ms) | duration.transcriptFollow | — |
| Podcasts · tiles | the page opens | tiles arrive in a short cascade (stagger 60ms, scale.enter) and their meshes drift a few percent, alive but calm | stagger, scale.enter | — |
| Podcasts · mini-player | an episode starts | the hero artwork flies down into the mini-player thumb (matched geometry) | spring.sheet | sheetSnap |
| Why this is here | "hear it" | the moment card gives a soft press, then a thin progress line draws under the quote while it plays | scale.press, duration.base | press |
| Goals | you hit a goal | the goal's ring closes with a small overshoot and the number ticks up, with one quiet amber spark (no confetti) | spring.popover, duration.numberTick | confirm |
| You · map | the map opens | the you-orb lands first, then the people and threads float in on their orbits (the splash A choreography, shortened) | spring.map, stagger | — |
| You · map | something new is learned | a new orb is drawn in along its thread from you, like a line being written | duration.reveal | reveal |
| Onboarding · question | your words land | each word blurs in under the question as you say it (already approved), and the progress bar steps forward with a small spring when you answer | blur.enter, spring.popover | turn |
| Onboarding · quick answers | you pick a pill | the pill lifts onto paper and the check draws itself (stroke 0 → 1 in 140ms) | duration.fast | select |
| Privacy | the lock appears | the blue disc (C, your pick) fades in, the lock shackle closes with a tiny click motion, and the halo breathes once | spring.popover | confirm |
| Splash | first open | the chosen opening from page 06 (A constellation or a B warm-light idea), always landing on the real splash | duration.reveal | reveal |
| Tab bar | you switch tab | the selected glyph does a one-frame "emphasis" swap (outline → emphasis) with a tiny scale settle | duration.fast, scale.press | tab |
| Pull to refresh | you pull | the orb from the splash stretches on the pull (rubberBand 0.55) and pops back when released | gesture.rubberBand, spring.popover | refresh |
| Delete | you confirm | the row folds its height to 0 while sliding a few points, and the neighbours close the gap | duration.base, curve.exit | warning |

**Guardrails** (from the design system's motion rules):
- Only one thing moves for attention at a time.
- Nothing loops forever except the slow drift of meshes and maps.
- Press feedback is always under 80ms (`duration.pressIn`).
- Fun lives in the *shape* of the motion (overshoot, stagger, morph), never in extra objects such as confetti or bouncing icons.
- Next step: these get drawn as keyframe strips on page 06 (one strip per area) as each area reaches hi-fi, the same way the splash was.
