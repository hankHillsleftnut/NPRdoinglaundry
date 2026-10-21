---
name: title menu
kind: component
drawn: Paper · components · 04 menus, paywall, settings
measured: from the founder's screen recording, 20 Oct (30fps frames)
---

# title menu

Switches what a page shows, from its own title: podcasts ⇅ → episodes · briefs · saved.

## Use when
- A page has two to four views of the same feature (Podcasts: episodes, briefs, saved. You: map, list).

## Don't use when
- The choice changes a setting: use a row with a [switch](./switch.md).
- There are more than four options, or they need explaining: use a sheet.

## Anatomy
- **source**: the page title (display serif) plus an up-down glyph (12 × 16, `icon.muted`). The whole title is the button (44pt tall at least).
- **menu**: anchored under the title's leading edge; width hugs the longest option (min 196); radius `radius.popover` (22); white (`background.raised` in dark); a 0.5 warm hairline; `elevation.popover` (a wide `0 18 40 -10` cast and a tight `0 2 6` contact); 4pt inner padding.
- **rows**: `size.popoverRow` (50); text 15; the selected row sits on a `surface.wash` pill (radius 18, concentric with the menu's 22 at 4 inset) with the shipped thin ink check (18, `ink.default`, no disc) at the trailing edge. *Founder, 20 Oct: the `surface.control` pill read too dark and the filled check too fat.*
- **veil**: `background.veil` (6%) over the page: enough to separate, not modal.

## Choreography (measured)
| t | What happens |
|---|---|
| 0 | touch down on the title |
| 0–66ms | the title dims to `opacity.sourcePressed` (0.7). Nothing else moves: the press is felt first (`motion.duration.sourceDim`). |
| 66ms | the menu appears at `motion.scale.popoverFrom` (0.86) from its anchor, blurred `motion.blur.enter` (8), at 0 opacity |
| 66–200ms | it grows toward the bottom-trailing corner on `motion.spring.popover` (0.3 / 0.74), sharpening and becoming opaque; the subtitle under the title cross-fades out beneath it; the veil fades in |
| ~200ms | about 3% past full size |
| ~230ms | settled; `haptic.select` |
| select | the chosen row's pill slides to it (spring 0.25 / 0.85); the check cross-fades; the menu closes after 120ms so you see your choice land; the page content cross-fades to the new view |
| close | runs backwards and faster: `motion.duration.popoverExit` (110ms, ease-in), shrinking back into the title with blur; the subtitle fades back in at the same time |

Tap outside, swipe up on the menu, or tap the title again: closes. Long-press the title and slide to an option and release: selects in one gesture (iOS menu behaviour).

## States
| State | What it looks like | Motion | Haptic |
|---|---|---|---|
| rest | title and glyph | — | — |
| pressed | title at `opacity.sourcePressed` | `sourceDim` 66ms | — |
| open | menu, veil | measured choreography above | `haptic.select` on settle |
| selected row | `surface.wash` pill, thin ink check | pill slides | `haptic.select` |
| focused | 2pt `border.focus` around the title; in the menu, around the row | — | — |
| disabled row | `text.tertiary` and a short reason after it ("saved · nothing yet") | — | — |
| pending, error, loading, offline | not applicable: it switches views; the view shows its own state | — | — |
| empty | a view with nothing in it still appears in the menu, with "nothing yet" | — | — |
| dark | menu `background.raised` (dark), hairline white 8%, cast black 45%, veil black 20% | — | — |

## Rules
1. **MUST** let the press register before anything opens. *Because* a menu that appears instantly feels like it opened itself.
2. **MUST** close faster than it opens. *Because* leaving should never make you wait.
3. **MUST** grow from the title, not from the centre of the screen. *Because* the origin tells you what it belongs to.
4. **NEVER** dim the page more than the veil. *Because* this is a quick choice, not a modal decision.

## Accessibility
- [ ] The title is a button: "podcasts, showing episodes, menu".
- [ ] Rows are a list with the selected one marked "selected".
- [ ] Reduce Motion: fades in place at full size (140ms), no blur, no overshoot.
- [ ] Dynamic Type (accessibility 3): rows grow (min 50); the menu widens up to the screen minus margins, then wraps.
- [ ] Increase Contrast: menu gets a 1pt `border.control` ring.
- [ ] Reduce Transparency: the veil becomes 10% solid; the menu has no blur behind it.

## Taken out
- No icons in rows and no descriptions: two to four words are the whole choice.

## Edge cases
- Title near the trailing edge → the menu grows toward the leading side instead (still from the title).
- Rotation or a tab change while open → closes without selecting.

## Tokens
`radius.popover`, `elevation.popover`, `size.popoverRow`, `background.raised/veil`, `surface.control`, `ink.default`, `icon.muted`, `opacity.sourcePressed`, `motion.spring.popover`, `motion.duration.popoverExit/sourceDim`, `motion.scale.popoverFrom`, `motion.blur.enter`, `haptic.select`.
