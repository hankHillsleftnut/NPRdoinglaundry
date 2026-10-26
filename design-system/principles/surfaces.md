# surfaces: height is purpose

Every component sits at exactly one height. The height tells you what it is before you read it, and how much attention it should get. The higher it sits, the more it asks for; attention is spent, not sprinkled.

| Level | Name | Looks like | Purpose | Components |
|---|---|---|---|---|
| −1 | **sunken** | `background.sunken`, inner shade (inset 0 1 2, warm 8%), 0.5 hairline | you put something into it | text field, composer, search, scrubber and switch tracks, the transport tray, the segmented track |
| 0 | **page** | `background.canvas`, nothing | content | text, the transcript, list rows, entries |
| 0.5 | **wash** | `surface.wash` (warm 6%, translucent), no shadow, no stroke | quiet and low-commitment: informs or offers a light choice | tags, status, bubbles (share, like, close), "chapters / why it's here / not right", the "add" pill, selected-row highlights, the menu's selected row |
| 1 | **card** | `depth.tier.card`: double stroke, contact + cast | belongs together; can be opened | brief card, chips, benefit drawings, list cards |
| 2 | **raised** | `depth.tier.raised` | what your finger grabs, or the real alternative | switch / scrubber / segmented thumbs, the play well, the cream secondary, the mark |
| 3 | **floating** | `depth.tier.floating` (+ ambient) | persistent tools above content | mini-player, menus, toasts |
| 4 | **overlay** | `depth.tier.overlay`; the page behind scales to 0.94 and dims | temporary and modal | sheets, the player, dialogs |
| 5 | **lit** | `depth.tier.lit`: the glow stack with its own coloured cast | the one next step | primary action, talk button, brief play |

## The recipe (levels 1–4)
- **Double stroke:** inner 1pt white (85%), brightest on top (`depth.stroke.innerTop`); outer 0.5pt warm hairline (`depth.stroke.outer`).
- **Double shadow:** a shallow contact (`0 1 1.5`, warm 10%) and a warm cast that grows with height (`0 6 16 −8` card → `0 24 48 −16` overlay), plus a wide ambient layer from floating up.
- **Top light:** a 2% lift in the top 40% of the surface.
- **Warm, never grey:** shadows are `rgba(58–70, 44–52, 28–30, …)`, never black on paper.
- **Coloured things cast their own colour:** lit actions cast sky (`depth.tint.primary`), artwork casts its dominant colour.

## Rules
1. **One level per component.** States move within a level (a pressed card sinks its shadow), never jump levels, except dragging, which lifts one level while held.
2. **Never raise reading text.** Content lives on the page.
3. **Wash before raise.** If something only informs or is a light choice, it is a tint, not an object.
4. **Sunken means input.** Nothing is sunken unless you put something into it.
5. **One lit object per screen.**
6. **Inner radius = outer radius − padding** for anything nested (a raised thumb in a sunken track, a raised play well in a sunken tray).
7. **Dark mode keeps the ladder:** surfaces get lighter as they rise (night.900 → 850 → 800 → 750); shadows deepen to black; strokes invert to faint white.

## Data as light (the map and the constellation)

Things that stand for what Retrospect knows (people, places, goals, what you wrote, you) are drawn as stars, not as objects on the page. **Stars emit light; they never reflect it.** So they get no white specular highlight and no top-lit rim in either mode. A lead star can be a gradient orb, but the gradient stays within its own hue (lighter centre, deeper edge), with a halo of the same hue (`color.map.star.<kind>.core` / `.halo`).
- **Because:** a white key-light spot reads as a glossy bead on paper and as a hard white dot on night. In dark mode it was the brightest thing on screen and pulled the eye away from the shape of the data.
- **Dark mode:** cores step lighter (300/200) and halos widen, so the stars glow against night. Light mode: cores step deeper (500–700), halos stay faint, so they read as ink with a soft bloom.
- **Size is importance:** the most-connected star in a group gets the second, wider halo; the rest stay small. You are the largest, with one thin ring.
- **The field** (`color.map.star.field`) is what isn't connected yet, always under an opacity token.

## Where blue goes (founder, 20 Oct: "better rules around the usage of blue")

Blue (`accent.*`, `glow.primary.*`, `voice.listening`) means one of three things, and nothing else:
1. **The one lit action on the screen** (the glow): play your brief, subscribe, the talk button when it leads. One per screen, never two.
2. **Retro is listening**: the listening edge and the voice level in the composer.
3. **A link inside text** (`text.link`), when the words themselves are the action.

Everything else is neutral, however important:
- **Secondary actions** (connect, add, how, retry) are raised neutral pills: `surface.secondaryAction`, double stroke, `text.primary`, an icon from the set. Obvious by depth and weight, not by colour.
- **Progress and meters** (onboarding progress, "what Retro can see") fill with `ink.default`, not blue.
- **Selection** is shown by the raised thumb or an ink tick, not by tinting blue.
- **Status** keeps its own colours (connected green, problem red), always with words.
*Because* when blue appears in seven places, it stops meaning "this is the one thing to do next".

## Drawing shadows exactly: the box-shadow look (SH.composer, founder 26 Oct)
Paper writes every shadow as a CSS box-shadow: `x y blur spread`, with `inset` for layers painted inside the edge. Read the **spread** first. A negative spread pulls the shadow in before it is blurred, which is what keeps a soft shadow under the object instead of around it.

**Why the old recipe spilled above the top edge (the "lip").** SwiftUI's `.shadow(color:radius:x:y:)` has no spread. The older recipes in `RDepth.swift` (`rRaised`, `rSecondary`, `rLit`, `rSheet`, …) either dropped the spread and kept the blur, or shrank the blur to "carry" the spread. Take the composer's cast, `0 12 28 −12`. Without its −12 it reaches about 16pt above the top edge (Paper: about 4), and its ambient `0 24 60 −20` reaches about 36 (Paper: about 16). That grey band sits right over the white top line, and the eye reads the pair as a lip. Three smaller misses add to it:
- The top light was a 1pt strip masked to the flat top. Paper's `inset 0 1 0` is a crescent that follows the corner curve and thins out.
- The 0.5pt outer hairline was stroked centred on the edge, so half of it was hidden under the inner ring. Paper's sits fully outside.
- In dark mode the shadow colours are black 55% / 25%, so the spill is about three times darker.

**The new recipe (the "box-shadow look").** `rBoxShadows(_ stack:radius:)` in `RDepth.swift` draws a token stack layer for layer, the way a browser does:
- **Pull-in technique (outer layers):** take the shape, grow it by the spread (negative shrinks it, with its corner radius), offset it by x/y, and blur it by half the CSS blur (a Gaussian of radius blur/2 matches CSS). Then mask the whole stack to **outside** the shape, so a translucent or cross-fading surface never shows its own shadow through itself.
- **Inset layers:** fill everything inside the shape except the shape itself, pulled in by the spread and offset by x/y. Blur it and clip to the shape. `inset 0 1 0` gives the crescent top light; `inset 0 0 0 1` gives the 1pt inner ring.
- **Rings:** `0 0 0 w` (outer) is a ring fully outside the edge; `inset 0 0 0 w` is fully inside.

**Tokens (new; existing tokens are unchanged and frozen by `tokens/tokens.test.mjs`):**

| token | layers (first on top) | Paper source |
|---|---|---|
| `depth.boxShadow.stroke.innerTop` | inset 0 1 0 `depth.stroke.innerTop` | layer 1 of 1F7K-0, B0C-0, D9Z-0, DA6-0 |
| `depth.boxShadow.stroke.inner` | inset 0 0 0 1 `depth.stroke.inner` | layer 2 of the same |
| `depth.boxShadow.stroke.outer` | 0 0 0 0.5 `depth.stroke.outer` | layer 3 of the same |
| `depth.boxShadow.composer.rest` | the three strokes · 0 1 2 contact · 0 12 28 −12 cast · 0 24 60 −20 ambient | c:voice-composer/speaking 1F7K-0 (ON-5), B0C-0, B0R-0, B10-0 |
| `depth.boxShadow.composer.listening` | inset 0 1 0 innerTop · 0 0 0 0.5 `glow.primary.ring` · 0 1 2 contact · −64 10 34 −16 `voice.glowPool` · 72 −6 30 −14 `voice.glowLift` · 18 20 36 −18 `voice.glowUnder` · −10 −12 26 −16 `voice.glowTop` | 26LI-0 (ON-10), 1F6E-0 (ON-3..9), GEG-0 |
| `depth.boxShadow.pill.raised.rest` | the three strokes · 0 1 1.5 contact · 0 4 6 −2 cast | c:pill/raised/rest D9Z-0, 219H-0 (ON-6) |
| `depth.boxShadow.pill.raised.pressed` | the three strokes · 0 0.5 1 contact · 0 1 2 −1 cast | c:pill/raised/pressed DA6-0 |
| `depth.glow.listening` | the listening stack's outer shadows only (contact + four glows) | 26LI-0, 1F6E-0, GEG-0 |
| `depth.pill.raised.rest` / `.pressed` | the pill's contact + cast only | D9Z-0 / DA6-0 |

Swift: `RElevation.boxShadowComposerRest`, `…ComposerListening`, `…PillRaisedRest`, `…PillRaisedPressed`, `…StrokeInnerTop/Inner/Outer`, `RElevation.glowListening`, `RElevation.pillRaisedRest/Pressed` (generated), plus the existing tiers now also emitted as layer stacks (`RElevation.tierCard/Raised/Floating/Overlay`, same values).

**Which component uses which look (26 Oct).** Both looks exist side by side, and today's stays the default until the founder picks per component:
- Voice composer: `RVoiceComposer(look: .current)` (default, `rRaised` + the lit cross-fade) or `.paper` (`depth.boxShadow.composer.rest/.listening`).
- Raised pill: `RPill(look: .current)` (default, `rSecondary`) or `.paper` (`rSecondaryPaper` → `depth.boxShadow.pill.raised.*`). CN.connect will use `.paper` for `+ connect` once this merges.
- Everything else still uses the older recipes. Lab page: `-DesignLab -DesignLabPage composer`.

**Audit (no changes made; `pipeline/qa/SH.composer/shadow-audit.md`):**
1. Every `RDepth` recipe drops the spread. The blur is either kept (too wide, climbing above the top edge) or shrunk (too hard).
2. One recipe is reused for parts Paper draws differently:
   - `rRaised` is on the scrub bubble and the lifted message bubble.
   - `rLit` (the small play button's recipe) is on the 60pt primary CTA.
   - `rSecondary` is on the 60pt secondary, which has a 2pt ring in Paper.
3. Outer rings are centred, so only half of each shows.
4. Dark mode makes the spill about three times darker.
5. Inset bottom shades (lit buttons) aren't drawn.
6. `.opacity` cross-fades over shadowed stacks show both shadows mid-fade.
7. The ticket and source rows match Paper.

Each is a founder question before any change.
