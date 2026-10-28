# Progressive blur: the build spec

The one source of truth for every progressive blur in the app. It supersedes the scattered notes in `ios-build-notes.md`; where they disagree, this file wins.

**Founder, 20 Oct:** "make sure the progressive blur docs here are very good, because Paper's implementation is bad."

Paper can't draw a true variable blur. On the boards, every blurred edge is approximated: either a backdrop blur at one radius faded in with a mask, or (in older boards) a second blurred copy of the content. **Build the intent described here, never the Paper layers.**

## What it is

A progressive blur is one blur whose **radius** grows smoothly from 0 to its maximum across a band at the edge of a scrolling area. Content sliding into the band softens gradually, with no visible line where the blur starts. It is not:

- a colour fade or gradient overlay on its own (that greys the content out);
- a material plate with a hard top edge (the system tab-bar plate);
- several bands stacked at fixed radii (you can see the steps);
- a blurred second copy of the content (it doubles text mid-ramp, costs twice the layout, and goes out of sync while scrolling).

## Where it's used, and its values

| Surface | Edge | Band height (17 Pro / SE) | Max blur | Tint on top | Notes |
|---|---|---|---|---|---|
| Player transcript (PC-2, ON-11 tease, JR-2 brief) | top | 96 / 64 pt | 8 pt | sheet colour (`background.raised`), 0 → 100% over the top 30% of the band | the spoken line always sits in the clear middle; on SE the column scrolls so it does |
| Player transcript | bottom, into the transport | 140 / 80 pt | 8 pt | sheet colour, solid for the bottom 15%, easing out by the top | never covers "correct this part" or the scrubber |
| Tab screens (journal, podcasts, goals, you) | bottom, above the tab bar | **~70 / 60 pt** (shortened 20 Oct, c-81biud) | 14 pt, saturation ×1.5 | canvas, opacity.disabled, only the bottom ~56 pt | must keep colour (never grey); under the tab bar itself the page is opaque canvas |
| The shell's tab bar (every tab page inside the shell; TABBAR.blend, founder 27 Oct) | bottom, from where the page's scroll ends (the bar's top; the journal's composer; the mini-player's room) | **90 / 72 pt** (`blur.tabBlend.rise`, tab-bar.md "starts 90pt above the tabs") | 14 pt, saturation ×1.5 (the tab screens') | canvas, 0 → **100%** on `gradient.fadeToCanvas` across the whole band; the bar sits on the shell's canvas with no plate | replaces the tab screens' edge inside the shell (`\.rShellTabEdge`), so there is one edge; content dissolves into the bar's canvas, never a hard cut; drawn with the masked material on every iOS (a band above a bar is not a scroll view's inset, where the system edge lives); the mini-player floats on the opaque end |
| Journal (JR-1) | top, under the bar | grows with scroll, up to ~80 pt | 8 pt | canvas | appears only once content has scrolled under the bar |
| Drawer (JR-3) | bottom, under the foot | 56 pt | 6 pt | canvas | |

The radius ramp is eased, not linear: blur(t) = max × t² across the band (t = 0 at the inner edge, 1 at the outer edge), so the first third stays almost sharp.

## How to build it (SwiftUI)

**iOS 26 and later:** use the system soft scroll edge (`.scrollEdgeEffectStyle(.soft, for: .bottom)` on the scroll view; `.top` where listed). It is a true variable blur, tracks scrolling for free, and matches the platform. Add the tint in the table as a separate gradient on top if the system edge doesn't carry it.

**iOS 17–18 fallback: one masked backdrop blur.**

1. Over the edge band, place a single `UIVisualEffectView` with a blur effect, wrapped for SwiftUI. Use the thinnest material, with its tint/vibrancy removed, so it only blurs.
2. Mask it with a `CAGradientLayer` (clear → opaque) using the eased ramp above, so the blur's strength rises across the band. This gives the progressive look from one blur, with no copy of the content.
3. Put the tint gradient above it, per the table.
4. Keep the content in one scroll view underneath, and never duplicate it.

**Do not:**

- use the private `CAFilter` "variableBlur" (App Review risk);
- stack several fixed-radius blurs;
- blur a second copy of the content (what the older Paper boards do).

## Accessibility and performance

- **Reduce Transparency on:** drop the blur and keep only the tint gradient, ending fully opaque at the outer edge so text never sits on blurred noise.
- **Reduce Motion:** no change (the blur doesn't move by itself).
- **Performance:** one blur view per edge, never per row. Pause it (set the effect to nil) when the scroll view is at rest at the top and there's nothing under the band.
- **Contrast:** text that is fully inside the band is decorative (it's leaving). The interactive elements next to the band (the tab bar, transport, correct pill) must pass contrast on the tinted end of the band.

## Checking it in the app

1. Scroll slowly through each surface. There must be no visible line where the blur starts, and no doubled glyphs mid-ramp.
2. At the strongest end, colour must still read: artwork stays warm and blue, never grey.
3. On SE, the spoken line or the last row must still be in the clear area.
