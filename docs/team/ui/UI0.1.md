### UI0.1 · Progressive-blur modifier: the request and its consumer check      size: S (yours) + M (integrator's)
Place in the tree: product › foundations › motion and depth › progressive blur
Repo · branch: the integrator writes `DesignSystemV2/RProgressBlur.swift` in its own shared-file PR; you write the gallery page and its tests on `ui/UI0.1-blur-gallery`
Needs: T01        Unblocks: C18 tab bar, C17's journal edge, C23b transcript bands, UI1.1 drawer foot

Why: content softens as it slides under the tab bar, the top bar, the player's controls and the drawer foot, without a hard line or greyed colour. One modifier makes every edge the same.

Inputs:
- Spec: `docs/design/progressive-blur.md` (all of it; it supersedes the build notes)
- Reference: design-reference §C18 "edge", §C23 blur bands
- Paper: the tab edge on JR-1 `1FKB-0` (an approximation; build the intent, not the layers); build note c-81biud (~70pt)

Spec (what you ask the integrator for, word for word in the request):
- **API:**
  `.rProgressiveBlur(edge: .top | .bottom, band: CGFloat, maxRadius: CGFloat, saturation: CGFloat = 1, tint: Color?, tintCoverage: ClosedRange<CGFloat>, active: Bool = true)`
  plus named presets:

  | Preset | Edge | Band (17 Pro / SE) | Max | Saturation | Tint |
  |---|---|---|---|---|---|
  | `.tabEdge` | bottom | 70 / 60 | 14 | 1.5 | `background.canvas` at `opacity.disabled`, bottom 56pt only |
  | `.journalTop` | top | grows with scroll, 0 → 80 | 8 | 1 | canvas |
  | `.transcriptTop` | top | 96 / 64 | 8 | 1 | `background.raised`, 0 → 100% over the top 30% |
  | `.transcriptBottom` | bottom | 140 / 80 | 8 | 1 | `background.raised`, solid for the bottom 15% |
  | `.drawerFoot` | bottom | 56 | 6 | 1 | canvas → `background.underlay` |

- **Ramp:** blur(t) = max × t², eased, never linear.
- **iOS 26:** `.scrollEdgeEffectStyle(.soft, for:)` on the scroll view, with the tint as a separate gradient on top.
- **iOS 18.1:** one `UIVisualEffectView` (thinnest material, vibrancy and tint removed), masked by a `CAGradientLayer` with the ramp's stops, and the tint above it.
- **Never:** private `CAFilter` variableBlur; stacked fixed bands; a blurred copy of the content.
- **Reduce Transparency:** no blur; the tint only, ending fully opaque at the outer edge.
- **Performance:** one blur view per edge. Its effect is set to nil when nothing is under the band (`active: false`, driven by `onScrollGeometryChange`).
- **SE:** band heights come from the preset by vertical size, never by device model (`containerRelativeFrame` or a geometry read).

Your half:
- a gallery page `gallery.UI0.1` showing each preset over a striped and coloured test pattern (warm artwork plus text) in a scroll view, with a toggle to force the iOS 18 path on iOS 26
- snapshots of each preset at rest over the pattern
- a recording of a slow scroll under each band

Steps:
1. Write the request (above) to the integrator.
2. Review their PR as the consumer: API, ramp, Reduce Transparency, the forced fallback.
3. Gallery and snapshots.
4. Recordings.

Acceptance:
- No visible line where any band starts (frame-by-frame on the slow-scroll recording).
- No doubled glyphs mid-ramp.
- Artwork keeps its colour at the strongest end: a sampled pixel's saturation at the band's outer edge is ≥ the same pixel unblurred.
- Reduce Transparency shows a solid tint and no blur.
- The forced iOS 18 path and the iOS 26 path look alike side by side (listed differences only).
- The instrumented scroll test shows no hitch increase with blur on versus off beyond the noise of three runs.

Tests:
- (snapshot) each preset over the test pattern matches its image
- (snapshot) Reduce Transparency replaces the blur with an opaque tint
- (snapshot) the forced fallback path renders one effect view, not a stack (view-hierarchy assertion on the hosting controller)
- (UI) scrolling under the tab edge keeps the hitch ratio within the no-blur baseline (layer 10, trend only)

Proof in the PR: the gallery in light and dark; the slow-scroll recordings; the before and after hitch numbers.

Watch out:
- Paper fakes this with stacked copies. Never measure the blur from Paper's layers.
- Material views pick up the system tint unless you remove it, which turns the edge grey. The founder flagged grey as wrong.
- The tab edge sits **above** the tab bar; under the bar itself the page is opaque canvas.
