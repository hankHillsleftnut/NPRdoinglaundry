# icons

- **Grid:** 24pt, 20pt live area, 2pt padding.
- **Keylines:** circle 20, square 18 (radius 1), portrait 16 × 20, landscape 20 × 16. Shapes are drawn to their keyline so they carry the same visual weight.
- **Stroke:** 1.75 at 24pt (1.5 at 16, 2 for the selected tab and emphasis), round caps, round joins, `currentColor`.
- **Filled glyphs** (play, pause, more, guess) are used where a stroke would look weak; they share the stroke icons' optical size.
- **Ink joins (founder, 20 Oct: "a little bleed, like they are ink"):** wherever two strokes meet at an angle (a stem into a frame, a line into a circle), the inside corners get a concave fillet of 0.75 at 24pt (0.5 at 16), filled in currentColor, as if the ink pooled into the joint. They're geometry, never a blur or a shadow, so they stay crisp at 3×. Free ends stay round caps; outer corners keep their radius. *Because* a sharp inside corner reads as a vector drawn by a machine; a pooled joint reads as ink on paper, the same feel as Exposure's ink axis in the titles.
- **Optical rules:** play sits 1/12 of its width right of centre; numbers in rings shift toward the arrow's open side; checks sit up and right; hearts, locks and mics centre by mass.
- **Meaning first:** every icon is exactly what it says (`external` only for links that leave the app; `guess` only for inferences; `correct` for "that's not right").
- **Names** are lowercase, hyphenated, purpose-named.
- **Check at 4× on the keylines** before shipping (Paper f5).
- **SF Symbols** are the reference for weight and proportion; we draw our own so the set is consistent with our stroke and our domain (map, brief, guess).
- **Source:** `design-system/icons/*.svg` (28) and `icons.json`.
- **Small components get the same care:** tags, chips and badges are drawn to the same optical rules (dots 6pt, 6pt from text; badges on the x-height).
