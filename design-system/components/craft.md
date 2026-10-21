# craft: the rules every component follows

The standard is the best 0.1% of iOS apps. Each rule says what to do and *why*. Every spec in this folder is checked against all of them (see the checklist at the end). Sources: Apple's SwiftUI `ScrollEdgeEffectStyle` documentation (soft vs hard edges, iOS 26), `ContentTransition` (numericText, interpolate), Apple's "Designing Fluid Interfaces" (WWDC18) and "Building Interruptible and Responsive Interactions" (WWDC14), the Human Interface Guidelines, Lime (design.how), and what was measured from the founder's reference recordings.

## 1. Touch and response
1. **Respond on the same frame as the touch.** Press states apply on touch down, not on release. *A lag of even one frame reads as a sluggish app.*
2. **Everything is interruptible.** Any animation can be caught mid-flight by a new touch and reversed from wherever it is on screen, never from its target. *Waiting for an animation to finish is the most common reason an app feels heavy.*
3. **Hand gesture velocity to the animation.** When a drag ends, the spring starts with the finger's velocity (normalised by remaining distance). *No seam between dragging and animating.*
4. **Project momentum.** Decide where a flick lands from its projected end, not its release point. *The sheet closes when you flick it, even from near the top.*
5. **Gestures are springs; only fades use durations.** *Springs are velocity-aware and interruptible by nature.*
6. **Never lock input during a transition.**
7. **44pt hit areas, always** — pad the frame, not the visual.
8. **Exits are faster than entrances** (about 0.5–0.7×). *Leaving should never make you wait.*
9. **Press is weighted:** in 80ms, out 240ms. Small things press deeper (0.94) than large ones (0.98).

## 2. Visual centring (optical, not mathematical)
1. **Triangles move toward their point.** A play glyph sits 1/12 of its width right of the box centre (1pt at 24, 1.5–3pt in a 44–56 circle). *The flat side carries the mass; box-centred play looks shifted left.*
2. **Circles overshoot squares.** A circle icon fills the 20pt keyline; a square only 18. *Same box, the circle otherwise looks smaller.*
3. **Lowercase labels centre on the x-height, not the line box.** In a pill, the space above the x-height and below the baseline is balanced by eye; with SF Mono lowercase this means nudging the text down 0.5pt when the label has no descenders, up 0.5pt when it has several. *Line-box centring makes lowercase sit high.*
4. **Icon beside a label aligns to the x-height centre of the label,** not the text box.
5. **Asymmetric padding where an icon leads or trails:** the icon side gets 2pt less (22 / 20). *The icon's soft edges read as space.*
6. **Ticks and checks move up and right by 0.5–1pt** in their box. *Their mass sits low-left.*
7. **Numbers in rings (skip 15 / 30) shift toward the open side of the arrow** by 0.5–0.6 of a unit. *The arrowhead adds mass on its side.*
8. **Hearts, locks and mics are centred by mass,** not by bounding box (a lock's body is the mass; its shackle is light).
9. **Text in a circle (avatars, initials) sits 0.5pt high.** *Caps-heavy initials look low when centred.*
10. **Every new glyph is checked at 4× on its keylines** (components · 05 · icons) before it ships.

## 3. Shape
1. **Concentric corners:** inner radius = outer radius − padding (a 32 pill with 10 padding holds a 22 corner). *Mismatched radii look like they were dropped in.*
2. **Continuous (squircle) corners** everywhere (`RoundedRectangle(style: .continuous)`).
3. **Pills are true pills:** radius = height / 2, never "almost round".
4. **Strokes sit inside** shapes (`strokeBorder`), so the size never changes when a stroke appears.

## 4. Depth and light
1. **One recipe** (components · 00 · depth): double stroke (inner white, outer warm hairline), double shadow (shallow contact + warm cast), **one of six tiers** per component.
2. **Shadows are warm, never grey;** coloured objects cast their own colour.
3. **Light comes from above:** the top inner edge is the brightest; lower edges darken.
4. **One lit object per screen.**

## 5. Colour and contrast
1. **Text ≥ 4.5 : 1** against whatever it sits on (WCAG AA); large text (≥ 24pt, or 19pt bold) ≥ 3 : 1; meaningful icons and control edges ≥ 3 : 1. Checked by script, not by eye.
2. **Disabled text is exempt** but must sit beside a reason that passes.
3. **Increase Contrast** raises every grey one step and every ring to full opacity.
4. **Never colour alone:** status always pairs colour with a word or a shape (the guess is dashed *and* marked).

## 6. Gradients
1. **Mix in OKLCH; ease the stops** (smoothstep, five or more).
2. **Never ramp between distant hues.** Use mesh: blobs that fade in alpha over a base.
3. **Grain on anything larger than 44pt** (soft light 3–6%), so nothing bands on OLED.
4. **Fades are eased** (13 stops); a two-stop fade draws a line.

## 7. Blur, edges and transitions (scroll and text)
1. **Scroll edges blur progressively, not abruptly.** Under a floating control or the top bar, content passes through a variable blur (0 → 8pt over 40pt) *and* an eased fade; on iOS 26 use the system's soft scroll-edge effect (`scrollEdgeEffectStyle(.soft, for: .top/.bottom)` on the ScrollView, and `safeAreaBar` for our own floating bars such as the mini-player so they get the same soft edge); never `.hard` under reading text. On iOS 18, a material masked by the eased fade. *A hard material edge cuts text in half.*
2. **Text arrives with blur, not just opacity.** New text (a transcript line becoming "now", a reply appearing, a label changing) cross-fades with a 4–6pt blur that resolves as it lands (`.blurReplace` / `contentTransition(.interpolate)`), 200–280ms. *Pure opacity cross-fades double-print letters mid-way.*
3. **Numbers roll** (`.contentTransition(.numericText(countsDown:))` with `.monospacedDigit()`) — times, counts, prices.
4. **Changing text keeps its width** where it can (tabular figures, reserved space), so nothing around it jumps.
5. **The transcript is the reference case:** lines above the spoken one dim and soften (opacity 0.55, blur 0); the spoken line is sharp; the next is secondary; the one after fades out through the eased fade into the transport. As the voice advances, the colours cross-fade and the column glides — never jumps.
6. **Sheets rise with the page behind them scaling down and dimming in step,** driven by one progress value.
7. **Shared elements morph** (matched geometry): the mini-player's title *becomes* the player's title.
8. **Reduce Motion:** no blur in transitions, no scale; cross-fade 140ms. **Reduce Transparency:** blurs become solid surfaces.

## 8. Layout and reading
1. **8pt grid, 4pt half steps.** Group by proximity: within a group 4–8, between groups 24–32, between sections 40.
2. **Content first.** A page opens on what the person came for; controls come after content.
3. **One feature per page, one primary action per screen.**
4. **Reading width 326;** the screen margin is 24 (20 on the smallest phones).
5. **Primary actions in the thumb zone** (bottom third).
6. **Lowercase** for labels, buttons, titles, tags; content keeps its capitals.

## 9. Type
1. Dynamic Type everywhere (`relativeTo:`), tested to accessibility 3.
2. Tabular mono figures for anything that counts.
3. Never below 11pt.
4. Titles wrap to three lines max, then ellipsis; never truncated to one.

## 10. Haptics
1. Few, and they mean something: press (lit actions only), select, turn-taking, success, warning, error.
2. Prepare the generator before the moment, so it lands on the frame.
3. Never on scroll; never on every list row.

## 11. States
Every component documents **rest, pressed, focused, pending, disabled, error, empty, loading, offline, dark, Dynamic Type at accessibility 3, Reduce Motion, Reduce Transparency, Increase Contrast** — or says why a state doesn't apply.

## 12. Restraint (the simplest form that still does the job)
1. **Every element earns its place.** For each piece ask: what does this tell the person that nothing else on the component already tells them? If the answer is "nothing", take it out.
2. **Say a thing once.** A ring *and* a colour change *and* a label *and* a bar for "playing" is four ways of saying one thing. Keep the one that is clearest without colour (usually the word), plus at most one quiet visual.
3. **No indicator for fast things.** No loading under 400ms, no progress bar when the length is unknown, no counts that nag.
4. **Full, not empty.** Restraint is not bareness: the detail goes into the depth, light, type and motion of the few things that stay, so the component still feels complete and crafted.
5. **Write it down.** Every spec has a "Taken out" section naming what was removed and why it wasn't needed.

## Checklist (run on every component)
- [ ] responds on touch down · interruptible · velocity handed off · 44pt targets
- [ ] optically centred (glyphs, labels, icon pairs) — checked at 4×
- [ ] concentric radii · continuous corners · true pills
- [ ] one depth tier · warm shadows · coloured casts on colour
- [ ] contrast measured (≥ 4.5 / 3)
- [ ] gradients in OKLCH, eased, mesh not ramps, grain over 44pt
- [ ] scroll edges blurred progressively; text changes blur-replace; numbers roll
- [ ] every state drawn, light and dark
- [ ] Reduce Motion, Reduce Transparency, Increase Contrast, Dynamic Type covered
- [ ] haptics only where they mean something
- [ ] restraint: nothing says the same thing twice; "Taken out" written
