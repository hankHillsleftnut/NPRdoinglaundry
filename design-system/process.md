# design engineering process

How every screen in Retrospect gets made, from the idea to the SwiftUI view.

**Plan top-down, build bottom-up.**

- **Plan (mid-fi), top-down:** flow → page → component → sub-component. Start from what the person is trying to do, and only then decide what pieces it needs.
- **Build, bottom-up:** sub-component → component → page → flow. Each level is built only from finished pieces of the level below. Each level passes every token and every rule before anything is built on top of it.

Craft compounds upward: a page can't be better than its worst sub-component. So the smallest pieces get the most scrutiny, and every level above them is checked again for what only appears at that level (spacing between things, hierarchy, choreography).

---

## The rules this process applies

Every pass below checks against the same written sources. Nothing is judged from memory.

| Source | What it holds |
|---|---|
| [principles/README.md](./principles/README.md) | the founder's 26 keys |
| [principles/screen-rules.md](./principles/screen-rules.md) | the founder's rules from screen reviews: how every remaining screen is built |
| [components/craft.md](./components/craft.md) | the 12 craft sections and the checklist |
| [tokens/tokens.json](./tokens/tokens.json) | every value; nothing is hand-set |
| [icons/](./icons/) | the only icons allowed |
| topic docs in [principles/](./principles/) | surfaces (z-axis), gradients, icons, motion and transitions, accessibility, type, organisation |
| `node design-system/lint.mjs` | the parts a script can check: sections, states, token names, icons, contrast pairs, links, audit rows |

If a pass needs a rule that isn't written down, write the rule first, then apply it. If it needs a value that isn't a token, add the token first, with its purpose, dark value and source.

---

## Part 1 · Plan (mid-fi), top-down

The goal of planning is to know *what* exists and *why* before anything is drawn in detail. Everything stays in grey boxes and real words. There is no polish at this stage.

### 1. Flow
- **Write** the person's goal in one sentence ("hear what my week meant, in two minutes").
- **Write** the steps as pages, in order, with the moment that moves between each pair (tap, swipe, a sheet rising).
- **Decide** the one thing each page is for. Two purposes means two pages.
- **Mark** where data comes from at each step, and what happens when it isn't there (empty, loading, offline, failed).
- **Output:** a flow strip in Paper (grey frames joined by labelled arrows) and a flow section in the goal spec.

### 2. Page
- **List** the content in order of what the person came for (content first, controls after).
- **Name** the one lit action, or say that the page has none.
- **Rough in** the layout with grey boxes on the 8pt grid, at 390 wide and SE width.
- **Assign** each region a level on the z-axis (sunken, page, wash, card, raised, floating, overlay, lit).
- **Output:** a mid-fi page artboard, one line of purpose under it, and its regions labelled with the components they need.

### 3. Component
- For each region, **reuse** an existing component from [components/](./components/README.md) if one fits.
- If none fits, **define** a new one: its purpose, use when / don't use when, and the states it needs.
- **Output:** a list of components per page, marked *existing* or *new*.

### 4. Sub-component
- **Break** each new or changed component into its smallest parts: a label, a glyph well, a track, a thumb, a shadow stack, a status dot.
- **Write** for each part what it says and why it is there.
- **Restraint check (craft §12):** if a part says something another part already says, cut it now, before it's built.
- **Output:** the anatomy list for each component spec, bottom to top.

**Plan gate.** Before building starts, the founder sees the flow and pages in mid-fi and approves the order and the purposes. Visual polish isn't reviewed at this gate.

---

## Part 2 · Build, bottom-up

Each level is drawn in Paper from finished pieces of the level below, then passed against every rule. A level isn't done until its pass is written down.

### 1. Sub-component pass

Build each part alone, at 4× zoom, on the sub-component board. Then go through every row of this table and record the answer.

| Check | Question | Source |
|---|---|---|
| purpose | What does this part tell the person that nothing else does? If nothing, cut it. | craft §12 |
| token: colour | Is every colour a semantic token, with a dark value? | tokens.json |
| token: type | Is it the right family (display, text or mono), size, leading, tracking and ink for its size? Lowercase? | principles/type.md, key 2, key 23 |
| token: space and size | Is every number a space, size or radius token on the 8 / 4 grid? | craft §8 |
| shape | Are the corners concentric (inner = outer − padding) and continuous? Is it a true pill? Does the stroke sit inside? | craft §3 |
| depth | Is it on one level of the z-axis? Does it have the double stroke and double warm shadow for its tier? Is a coloured object casting its own colour? | principles/surfaces.md, craft §4 |
| texture | Is there grain on anything over 44pt? Is the gradient OKLCH, eased, and a mesh rather than a ramp? | principles/gradients.md, craft §6 |
| icon | Is it from the set, on the 24 grid, at stroke 1.75 (or a written optical exception)? | principles/icons.md |
| token pass | Does `token-check.mjs` report 0 raw values, and does every `var(--…)` exist in Paper and `tokens.json`? | the token pass, below |
| optical centring | Is it centred by mass, not by box? Checked at 4×. | craft §2 |
| contrast | Text at least 4.5 : 1, marks at least 3 : 1, in light *and* dark, measured by script? | principles/accessibility.md, lint |
| hit area | Is it at least 44pt, with the frame padded rather than the visual? | craft §1.7 |
| states | Does every state it can have look right: rest, pressed, focused, pending, disabled, error, dark? | craft §11 |
| motion | Does it have a press curve, its enter and exit, and a text transition (blur-replace, numbers roll)? | principles/motion-and-transitions.md |
| haptic | Does it need one? Usually not. | craft §10 |

**Output:**
- the part, drawn and named in Paper;
- its row in the component spec's anatomy (with its tokens);
- one line per failed check saying what was changed.

### 2. Component pass

Assemble the component *only* from passed sub-components, then check what only appears when the parts are together:

- **Grouping and spacing:** 4–8 inside a group, 24–32 between groups. Do the parts read as one object?
- **Concentricity across parts:** does the inner well follow the outer radius minus the padding?
- **One level:** does the whole component sit on one z-level, with nothing inside it louder than it?
- **Restraint:** read the finished component aloud. Is anything said twice (a ring *and* a colour *and* a label)? Keep the word plus one quiet visual.
- **Every state drawn:** all fourteen from craft §11, or excused with a reason. That includes dark, accessibility 3, Increase Contrast, Reduce Motion and Reduce Transparency.
- **Spec complete:** all sections (use when, don't use when, anatomy, rules with *because*, states, accessibility, taken out, edge cases, tokens).
- **`node design-system/lint.mjs` passes.**
- **Audit row** added to [components/audit.md](./components/audit.md).

**Output:** the component drawn on its board in every state, its spec, its audit row, and a clean lint run.

### 3. Page pass

Assemble the page only from passed components, then check what only appears at page level:

- **Content first:** does the page open on what the person came for?
- **One lit object at most;** one primary action, in the thumb zone.
- **Hierarchy:** squint at it. Does the eye land where the purpose says it should?
- **Rhythm:** sections 40 apart; reading width 326; screen margins 24 (20 on SE).
- **Edges:** scroll edges soft (blur plus eased fade) under every floating thing; nothing cut in half.
- **Real data:** real lengths, long names, a quiet week, a new person with no data. Never placeholder text that flatters.
- **Every page state:** loading (skeleton after 400ms), empty (says when it fills), error, offline, and largest text.
- **Device sizes:** SE, 17 Pro, Pro Max.
- **Dark mode,** checked as a whole page, not tile by tile.

**Output:** the hi-fi page in Paper, in its states and sizes, with its pass written under it.

### 4. Flow pass

Join the passed pages, then check what only appears in motion:

- **Choreography:** each move between pages is specified (what moves first, what follows, springs or durations from tokens). Shared elements morph rather than cut.
- **Interruptible:** every transition can be caught and reversed mid-way.
- **Continuity:** the thing tapped is the thing that opens (the mini-player title *becomes* the player title).
- **Haptics across the flow:** few, and each one means something; never two in a row for one action.
- **Failure paths:** walk the flow with no network, a denied permission and a failed payment. Each step says what happened and what to do.
- **Accessibility walk:** do the whole flow with VoiceOver, then at the largest text, then with Reduce Motion.
- **Time:** count the taps and seconds to the goal sentence from Plan step 1. Could it be one fewer?

**Output:** a flow board in Paper with the transitions drawn as frames (or a prototype), the pass written down, and the founder's review.

---

## The token pass (every level, every screen)

Every screen is made of tokens. No colour, type value, radius, spacing or opacity is typed by hand; each is a `var(--…)` that traces back to `tokens/tokens.json`. Tokens are part of making the screen, not a coat applied afterwards.

**How a screen is made with tokens:**
1. **Before drawing:** list the tokens the screen needs. If one is missing (a size, a colour role, a sign-in button), add it to `tokens.json` first, with its purpose, its dark value and its source, then create it in Paper with the same name. Never draw with a value that isn't a token yet.
2. **Generate, don't type:** screens are written from shared, token-only building blocks (status bar, sign-in stack, titles, body, orb, grain). A block is fixed once and reused, never copied by hand.
3. **Check before sending:** run `node design-system/token-check.mjs <screen>.html`. It must report 0 raw values. It flags any raw colour, type value, radius, spacing or opacity, and any named colour.
4. **Check every name exists:** every `var(--…)` the screen uses must exist in Paper (and in `tokens.json`).
5. **Check after drawing:** read the screen back from Paper (`get_jsx`) and run the checker on it. This catches anything edited in Paper by hand.
6. **Dark mode from tokens:** the dark version swaps each token for its `--color-dark-…` pair; no new values.

**What may stay raw, and why:**
- Frame width, height and position.
- Shadow geometry (offsets and blur), because Paper has no shadow token type. Every shadow's colour is still a token.
- Gradient stop positions. Gradient colours come from tokens: mesh recipes use the palette steps named in their `gradient.*` token, because Paper has no gradient token type.
- Brand marks: the Google G keeps Google's colours, wrapped in `<svg data-brand>`.
- Icon and illustration path data.

**When the pass finds a gap:** decide it by the design system's rules, add the token everywhere, and log it. The first pass (20 Oct) found that the type scale lacked body 17, title 34 and hero 64; the inky face and its tracking weren't in Paper; the sheet radius was 24 in tokens but 38 in the spec and drawings; and the sign-in buttons had no tokens.

---

## Part 3 · Into code

A level is handed to SwiftUI only after it has passed in Paper.

1. **Tokens first:** generated Swift from `tokens.json`. No literal colours, sizes or durations in views.
2. **Sub-components** become small views or modifiers (`DepthTier`, `Grain`, `GlowStack`, `PressStyle`).
3. **Components** become one view with a variant enum and a state enum, previews for every state, light and dark.
4. **Pages** become feature screens built only from those components.
5. **Flows** are built with the navigation and transitions specified, checked on device.
6. **Review:** each PR is read against the same pass tables before merge. The screenshot in the PR has to match the Paper board.

---

## Where things live

| Level | Paper | Docs |
|---|---|---|
| flow | page `03 · flows`, one board per flow | goal spec, flow section |
| page | page `04 · pages`, one board per page with states and sizes | goal spec, page section with its pass |
| component | page `02 · components` (c1–c6 and onward) | `components/<name>.md` + audit row |
| sub-component | a sub-component strip on each component's board, at 4× | the anatomy section of the component spec |

## Definition of done

A flow is done when every page in it, every component on those pages, and every sub-component in those components has:

- passed its level's checks, with the pass written down;
- a clean `lint.mjs` run;
- an audit row;
- the founder's review at the plan gate and the flow pass.

If anything fails, it goes back down to the level where it was made, gets fixed there, and the levels above it are rechecked.
