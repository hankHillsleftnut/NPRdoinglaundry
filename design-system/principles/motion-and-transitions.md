# motion and transitions

Research: Apple, "Designing Fluid Interfaces" (WWDC18) and "Building Interruptible and Responsive Interactions" (WWDC14); SwiftUI `ScrollEdgeEffectStyle` (iOS 26: soft vs hard edges) and `ContentTransition` (numericText, interpolate); Lime's interaction rules; and frame-by-frame measurements of the founder's reference recording (the title menu).

## Touch
- Respond on touch down, the same frame. Press: in 80ms, out 240ms; 0.98 for large things, 0.94 for small.
- Everything is interruptible: catch it mid-flight, reverse from where it is.
- Hand gesture velocity to the spring; project momentum to decide where a flick lands.
- Springs for anything gesture-driven; durations only for fades.
- Exits are faster than entrances (the title menu opens in ~230ms, closes in 110ms).
- The press is felt before anything opens (the tapped title dims for 66ms first).

## Choreography
- **Sheets:** the page behind scales to 0.94, rounds to 12 and dims, all on one progress value; drag follows 1:1; rubber band past the top; close past 140pt or 800pt/s.
- **Shared elements morph:** the mini-player title becomes the player title.
- **Stagger** 60ms, top to bottom; nothing appears before what is above it.
- **Menus** grow from their source (0.86, blur 8 → 0, slight overshoot), never from the screen centre.

## Edges (where scrolling meets something that stays)
- Never a hard cut under reading text. Soft edges: a progressive blur (0 → 8pt over ~40pt) plus an eased fade.
- iOS 26: `scrollEdgeEffectStyle(.soft, for: .top / .bottom)` on the ScrollView; `safeAreaBar` for our own floating bars (the mini-player) so they get the same edge. iOS 18: a material masked by the eased fade.

## Text
- Changing text blurs out and in (`blurReplace`, 4–6pt, 200–280ms); a pure opacity cross-fade double-prints letters.
- Numbers roll (`.contentTransition(.numericText())` with `.monospacedDigit()`); only the changing digit moves, and the width never changes.
- The transcript: colours cross-fade first (90ms), then the column glides (to 280ms); the next line sharpens from a 1.5pt blur.

## Haptics
Few, meaningful, prepared ahead: press (lit actions only), select, listening start/stop and turn, skip, chapter tick, sheet snap, success, warning, error. Never on scroll.

## Reduce Motion / Transparency
No scale, no blur, no overshoot: 140ms cross-fades. Blurs become solid surfaces.

Drawn in Paper: f6 · motion and haptics, f7 · edges and transitions, c4 · title menu filmstrip.

## Tiles that feel the scroll (founder, 20 Oct)
Tiles in a scrolling grid or row (episodes and briefs on Podcasts) lag a little behind the scroll and settle, as if dragged through water: each tile is offset by up to 6pt along the scroll and tilted up to 1.5°, proportional to scroll velocity, on a soft spring (response 0.45, damping 0.7), staggered by position so the field ripples. They never move while you hold still. Reduce Motion: off.
