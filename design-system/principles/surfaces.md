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
