# gradients

1. **Mix in OKLCH,** never sRGB. sRGB mixes go grey between hues.
2. **Ease the stops:** smoothstep, five or more stops. Two-stop gradients have a visible "line" where the ramp starts and ends.
3. **Never ramp between distant hues.** Sky to beige goes grey in sRGB and green in OKLCH. Use **mesh** instead: soft blobs that fade in *alpha* over a base colour, so no hue ever travels through another.
4. **Grain on anything larger than 44pt:** fractal noise, soft light, 3–6% (20% on the lit button, as built). It stops banding on OLED screens and gives surfaces a material.
5. **Fades are eased:** 13 stops on a smoothstep curve (`gradient.fadeToCanvas`); used for content dissolving under floating controls and into the transport.
6. **Glow bodies** use five OKLCH-eased stops (`gradient.glowPrimary`, `…Lit`, `…Pressed`, `glowDanger`), plus the lower edge and inner bloom.
7. **Artwork** is mesh: `meshMorning`, `meshEvening`, `meshQuiet` (more to come, one per kind of week), always with grain and its own coloured cast.
8. **In SwiftUI:** `MeshGradient` (iOS 18) for artwork; precomputed OKLCH stops in `LinearGradient` for bodies and fades; a noise shader or a tiled noise image in `.softLight` for grain.

Drawn in Paper: f4 · depth, surfaces, gradients (bad vs good).
