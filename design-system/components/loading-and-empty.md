---
name: loading-and-empty
kind: pattern
platform: iOS (SwiftUI)
drawn: Paper · components · 06 conversation, you and system
---

# loading and empty

How a page waits and how it looks with nothing in it.

## Use when
- Any page or card whose content isn't there yet, or isn't there at all.

## Don't use when
- Waiting under 400ms: show nothing; the content arrives.

## Anatomy
- **skeleton**: bars in the exact shape of the content (`surface.skeleton`, radius 6), a shine sweeping left to right (`surface.skeletonShine`, `motion.duration.shimmer` 1400ms). Only after 400ms.
- **empty**: one serif line saying what will be here and how it fills ("your episodes appear here every sunday."), and at most one action. No illustration.

## Rules
1. **NEVER** show a spinner for page content; skeletons keep the layout still.
2. **NEVER** show a loading indicator for under 400ms. *Because* a flash of loading is a visual distraction.
3. **MUST** say in empty states when it will fill, not just that it's empty.

## States
rest = the skeleton (loading) or the empty line. pressed, focused: the one action, per [button](./button.md). pending: not applicable. error: the empty layout with what went wrong and "try again". offline: "you're offline · showing what's saved" above cached content. disabled: not applicable. dark: skeleton tokens' dark values.

## Accessibility
- [ ] Skeleton reads "loading" once; empty reads the line.
- [ ] Dynamic Type (accessibility 3): skeleton bars follow text sizes.
- [ ] Reduce Motion: no shine; bars pulse opacity. Reduce Transparency: no change. Increase Contrast: bars one step darker.

## Taken out
- No spinners, no percentage bars, no illustrations, no "nothing here yet!" exclamations.

## Edge cases
- Very slow (over 8s) → one line under the skeleton: "still working".

## Tokens
`surface.skeleton/skeletonShine`, `motion.duration.shimmer`, `text.primary/secondary`, `font.family.display`.
