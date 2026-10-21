# Retrospect design system: plan

20 October 2026, v2: your decisions are in. Replaces [retrospect-tokens-proposal.md](./retrospect-tokens-proposal.md) and v1 of this plan.

## Decisions (yours, 20 Oct)

| # | Decision |
|---|---|
| 1 | **Hedvig Letters Serif, used tastefully:** display moments only (the first insight, an episode title, a screen's one headline), never body or UI |
| 2 | **One accent: a nice sky blue,** the paywall's blue family |
| 3 | **Monospace for all labels:** buttons, tags, metadata, times, prices, captions |
| 4 | **Grain and rim light are special:** only the primary (sky glow) button and a few signature moments, never ordinary controls |
| 5 | **Light and dark ship together; light first.** Dark follows each step, never blocks it |
| 6 | **iOS only for now** |
| 7 | **Tokens lead.** They're defined once, named by purpose, then mirrored to Figma and Swift |
| 8 | **Then a large component pass for the new app** (from [ios-v2.md](../second-brain/ios-v2.md) and the core product) |

## Three sources, three roles

| Source | Role |
|---|---|
| **Lime** (design.how) | Structure and coverage: token categories, the component inventory, blocks, written rules, the lint and the agent skill |
| **Queue** | Restraint: content carries colour; one accent, one job; space instead of lines; mono where time ticks ([study](./queue-reference/tokens.md)) |
| **Your paywall screen** (`PodcastPaywallFlow.swift`, Figma node 303:711) | Style: warm paper, the Hedvig serif, mono labels, the lit sky-blue glow button, the cream secondary, the motion of the buttons sliding up |

---

## Part 1: Tokens

### 1.1 How they're named: by purpose, in three tiers

| Tier | Says | Example | Used by |
|---|---|---|---|
| **Palette** (primitives) | what the value *is* | `palette.sky.500`, `palette.paper.100`, `palette.ink.900` | only the semantic tier, never a screen |
| **Semantic** | what it's *for* | `color.background.canvas`, `color.text.secondary`, `color.action.primary.fill` | every screen and component |
| **Component** | one component's own decision | `button.primary.height`, `episodeRow.gap` | only that component |

**Naming rules:**
- **Never name a semantic token after its look.** No `blue`, `cream` or `grey40`. A token's name must survive a palette change: if sky blue became green tomorrow, `color.accent.default` stays correct, but `color.blue` would lie.
- Pattern: `category.role.variant.state`, as in `color.action.primary.fill.pressed`.
- **States are always the same words:** `default · pressed · focused · disabled · selected · loading`.
- **Light and dark share one name;** the value changes by mode. Screens never mention a mode.
- **Every token has a one-line purpose** in the docs ("the page behind everything"). A token whose purpose can't be written in one line is two tokens, or none.

### 1.2 The inventory: the "wide enough array"

Values marked **from paywall** are measured from the existing code. Values marked **to set** are defaults for you to refine. *(Light / dark.)*

**Colour: backgrounds**
| Token | Purpose | Light / dark |
|---|---|---|
| `color.background.canvas` | the page behind everything | `#F4F2EE` from paywall / warm near-black, to set |
| `color.background.raised` | things that float: mini-player, sheets, pills | `#F9F7F5` from paywall / to set |
| `color.background.sunken` | wells: search field, input | to set |
| `color.background.scrim` | dims the page behind a sheet or dialog | ink at 40% / black at 60% |
| `color.background.inverse` | the rare dark block on a light page | to set |

**Colour: surfaces**
| Token | Purpose |
|---|---|
| `color.surface.card` | grouped content |
| `color.surface.control` | ordinary buttons and pills (the paywall "bubble" `#EAE7E3`) |
| `color.surface.control.pressed` | that, pressed |
| `color.surface.selected` | a selected row or chip |
| `color.surface.track` | progress and scrubber tracks (`#E9E7E2` from paywall) |
| `color.surface.secondaryAction` | the cream button (`#F7F3EE` from paywall) |

**Colour: text** (mono labels use these too)
| Token | Purpose |
|---|---|
| `color.text.primary` | headlines and body (`#121212` or `#000`, to set) |
| `color.text.secondary` | supporting text |
| `color.text.label` | mono labels (`#9E9E9E` from paywall) |
| `color.text.tertiary` | hints, timestamps at rest |
| `color.text.disabled` | |
| `color.text.onAccent` | text on the sky button (white, from paywall) |
| `color.text.inverse` | text on `background.inverse` |
| `color.text.link` | inline links (accent, darkened for contrast) |

**Colour: lines**
| Token | Purpose |
|---|---|
| `color.border.subtle` | the rare divider |
| `color.border.strong` | field outlines |
| `color.border.focus` | the focus ring (accent) |
| `color.border.highlight` | the white top-lit rim (from paywall, white at 50–100%) |
| `color.border.secondaryRing` | the cream button's warm ring (`#E4DBCE`) |

**Colour: accent** (the one sky blue)
| Token | Purpose |
|---|---|
| `color.accent.default` | the accent as a flat colour (to set; within the paywall family) |
| `color.accent.pressed` | |
| `color.accent.subtle` | a tinted background (selected, highlighted) |
| `color.accent.text` | accent used as text, with readable contrast |

**Colour: status** (never decoration)
`color.status.success`, `.warning`, `.danger`, each with `.subtle` (background) and `.text`.

**Colour: content** (Queue's lesson: content carries the colour)
| Token | Purpose |
|---|---|
| `color.content.artworkFallback` | when an episode or person has no image |
| `color.content.personTint.*` | a small set of soft tints for people's initials (to set) |

**Glow** (the signature: the sky button as tokens, Lime's structure)
| Token | Purpose |
|---|---|
| `glow.primary.gradientTop` / `gradientBottom` | `#43B7FF` → `#2899DF` (from paywall) |
| `glow.primary.ring` | outer ring `#50A4EC` at 40% |
| `glow.primary.rim` | top-lit white edge, 50% fading down |
| `glow.primary.halo` | the blue bloom `#2FB3FF` at 46%, blur 16 |
| `glow.primary.lit` / `.pressed` | brighter on focus, deeper when pressed (to set) |

**Material** (special only, per decision 4)
| Token | Purpose |
|---|---|
| `material.grain.primary` | the sky button's grain (seed 19, intensity 0.2) |
| `material.grain.secondary` | the cream button's faint grain (intensity 0.045) |
| `material.grain.signature` | the mark and the first-insight moment |
| `material.dots` | the shader's dots: density, size, colour, and never over text (ios-v2 rule 3) |

**Type** (three families, one job each)
| Token | Family / size / weight / leading | Purpose |
|---|---|---|
| `type.display.hero` | Hedvig 40, −1.5% tracking | the first insight, the onboarding close |
| `type.display.title` | Hedvig 30, −2% tracking (from paywall) | a screen's one headline, an episode title |
| `type.display.quote` | Hedvig 22 | a quoted line of their own words |
| `type.text.headline` | sans semibold 17 | list titles |
| `type.text.body` | sans regular 16, leading 1.45 | reading |
| `type.text.bodySmall` | sans regular 14 | supporting copy |
| `type.label.button` | **mono** 14 (from paywall) | every button label |
| `type.label.default` | **mono** 12 (from paywall) | metadata, tags, section labels |
| `type.label.small` | **mono** 11 | tab bar, dense metadata |
| `type.numeric.time` | **mono** 14, tabular | elapsed / remaining (from the mini-player) |
| `type.numeric.stat` | **mono** 28 | big numbers in insights |

Plus: `type.tracking.*`, `type.leading.*`, and Dynamic Type limits per role.

**Space** (4-point scale)
`space.0` 0 · `space.1` 4 · `space.2` 8 · `space.3` 12 · `space.4` 16 · `space.5` 20 · `space.6` 24 · `space.8` 32 · `space.10` 40 · `space.12` 48 · `space.16` 64

Purpose aliases: `space.screen.margin` (to set: 24, 28 or 32) · `space.section.gap` · `space.list.rowGap` · `space.stack.tight` / `.default` / `.loose` · `space.inline.default`.

**Size**
| Token | Value | Purpose |
|---|---|---|
| `size.control.small` | 32 | chips, small icon buttons |
| `size.control.default` | 44 | ordinary buttons (Apple's minimum touch size) |
| `size.control.hero` | 60 | the paywall-scale primary (from paywall) |
| `size.icon.small` / `default` / `large` | 16 / 20 / 24 | |
| `size.artwork.row` / `card` / `player` / `hero` | 40 / 64 / 120 / 240 | to set |
| `size.miniPlayer.height` | 42 | from paywall |
| `size.progress.height` | 3 | from paywall |
| `size.mark` | 38 | the logo mark (from paywall) |

**Radius**
`radius.small` 8 · `radius.default` 12 · `radius.card` 20 (the mini-player, from paywall) · `radius.sheet` 28 · `radius.control` capsule (the paywall buttons at 29–30 on 60) · `radius.artwork` about 20% of size.

**Elevation**
| Token | Purpose | From |
|---|---|---|
| `elevation.flat` | | |
| `elevation.raised` | pills, mini-player | black 12%, blur 4, y 1 (paywall mini-player) |
| `elevation.card` | | Lime-style, to set |
| `elevation.overlay` | sheets, dialogs | to set |
| `elevation.primary` | the sky button's two drops + halo | paywall |
| `elevation.secondary` | the cream button | black 15%, blur 4, y 4 (paywall) |
| `elevation.mark` | the logo disc | black 24% y 6, plus 12% y 1 (paywall) |

**Motion** (the paywall moment is the reference, ios-v2 change 2)
| Token | Purpose |
|---|---|
| `motion.duration.instant` / `fast` / `base` / `slow` / `reveal` | 80 / 140 / 200 / 280 / the slide-up reveal (to measure from the paywall) |
| `motion.curve.standard` / `enter` / `exit` / `spring.reveal` | the buttons sliding up from the bottom |
| `motion.scale.press` | 0.98 |
| `motion.stagger.reveal` | delay between elements arriving |
| `motion.reduced.*` | what each motion becomes with Reduce Motion on |

**Haptics** (iOS-specific, not in Lime)
`haptic.select` · `haptic.confirm` · `haptic.reveal` (the first-insight moment) · `haptic.warning`

**Layers and layout**
`layer.base` · `layer.miniPlayer` · `layer.sheet` · `layer.toast` · `layer.dialog`, and `layout.readingWidth` (the 326-wide transcript column, from paywall) · `layout.controlsWidth` (310, from paywall).

That's **about 120 tokens across 14 categories**, the wide array to build the components on.

### 1.3 Where they live

1. **One source file:** `tokens.json` in the W3C design-tokens format, with names, values (light/dark) and purpose lines.
2. **Generated, never hand-edited:**
   - Swift (`RetroTokens`, plus typed `Color`, `Font` and `Animation` accessors);
   - Figma variables (the collections: Color, Type, Space, Size, Radius, Elevation, Motion), with light and dark as Figma modes.
3. **A check** that fails if the Swift, Figma or JSON copies disagree.
4. **The old names** (`FigmaLightTheme`, `OnboardingStyle`, `Pod.*`) become aliases, so nothing breaks; they're retired screen by screen.

---

## Part 2: Components (the large pass, after tokens)

Built only from tokens, in the order the new app needs them. Each has every state, light and dark, Dynamic Type, VoiceOver, a gallery page, a Figma component, and a one-paragraph "when to use it".

| Tier | Components | Serves |
|---|---|---|
| **Foundations** | `PrimaryButton` (sky glow) · `SecondaryButton` (cream) · `QuietButton` (text) · `IconButton` · `Label` (mono) · `Mark` · `Divider` · `Grain` / `Rim` / `Glow` modifiers · `DotsField` (shader, never under text) | everything |
| **Inputs** | `TextField` · `TextArea` · `SearchField` · `Switch` · `Segmented` · `Chip` · `Slider` | search, settings, onboarding |
| **Display** | `Card` · `ListRow` · `Avatar` (people) · `Artwork` · `Badge` · `ProgressBar` / `Ring` · `Stat` (mono number + label) · `EmptyState` · `Skeleton` · `Toast` (with Undo) | everywhere |
| **Audio** | `MiniPlayer` · `Scrubber` (chapters as gaps) · `Transport` · `Transcript` (reading column, current line highlighted) · `EpisodeRow` · `BriefItem` ("why this is here") | Today, Episodes |
| **Brain** | `AnswerCard` (what it knows, how sure, *why*: tap for the quote) · `SourceRow` (last read, what it read, what it's for) · `SilentArea` ("I don't know much about your days yet") · `CorrectionReceipt` ("I'll stop saying…", Undo) · `QuestionCard` (a hypothesis: Yes / No in one word) · `SamePersonCard` · `AppetiteLadder` (0–3, plain words) | You, Sources, Settings |
| **Conversation** | `ChatInput` (voice-first) · `Message` (theirs / its) · `Silence` (an acknowledgement, not a bubble) · `FollowUps` | the conversation surface |
| **Actions** | `ApprovalCard` (what it's about to do, from what you said; Approve · Edit · Decline) · `ActionReceipt` (what it did, Undo) | acting (drafts only) |
| **Search** | `FoundSummary` ("What we found", with numbered citations) · `SourceResult` (openable) | Search |
| **Onboarding** | `StoryQuestion` (voice-first, one follow-up) · `ConnectCard` ("Calendar → what your weeks look like", clear state) · `VoiceMaker` · `FirstInsight` (the paywall moment: the line plays, then the buttons slide up) | Onboarding |
| **Blocks** (whole screens) | Journal (with the brief card) · Podcasts · Player · Goals · You (search + map) · Settings · Sign in · Onboarding · Paywall *(updated 20 Oct to the four-tab bar)* | the new app |

**Proof the system works:** the existing paywall rebuilt from tokens and components only, matching the current screen pixel for pixel.

---

## Part 3: Rules, lint and skill

- **Rulebook:**
  - one sky glow per screen;
  - colour only from semantic tokens;
  - mono for every label;
  - Hedvig only for display moments (at most one display style per screen);
  - grain and rim only where the tokens say;
  - dots never under text;
  - space before lines;
  - content carries the colour;
  - every screen's purpose readable before a word is read (ios-v2 rule).
- **Lint** (SwiftLint custom rules): no raw `Color(…)`, `Font.custom`, `.shadow(…)`, `cornerRadius:` or numeric padding outside the token layer; flag a second primary button in a view.
- **Agent skill** at `.claude/skills/retrospect-design/SKILL.md`, so every future change follows the system.
- **Gallery:** an in-app (debug) catalogue of every token and component in every state, light and dark, mirrored in Figma.

---

## Part 4: Order of work (this matches ios-v2's process)

| Step | Output | Your part |
|---|---|---|
| 1 | Answer the questions below | ✅ mostly done |
| 2 | **Token set v1:** `tokens.json` with all ~120 tokens, every name and purpose line, light and dark | review the names: do they say what each is *for*? |
| 3 | Generate Swift + Figma from it; the sync check | |
| 4 | **Your refinement pass on tokens** (values, the exact sky, the dark set) | the craft |
| 5 | Signature primitives: glow, rim, grain, dots, the reveal motion | |
| 6 | **Large component pass** (Part 2), foundations first, each with a gallery page + Figma component | approve each tier |
| 7 | Rules, lint, skill | |
| 8 | Paywall rebuilt from the system (proof), then the new app's screens, one at a time | before/after |

---

## Questions

1. **The exact sky blue.** The paywall glow runs `#43B7FF` → `#2899DF`. For the flat accent (links, selected, focus), I'd propose its middle, about **`#2FA8F0`**. Or do you want it lighter and softer, a "nice sky" closer to `#5CC2FF`? I can render 3 swatches side by side.
2. **Screen margin:** 24, 28 (what the paywall's button row implies) or 32?
3. **The sans for body text:** SF Pro (system, free, Dynamic Type for free), or a chosen face to pair with Hedvig?
4. **The mono:** SF Mono (what the paywall uses now) or a characterful mono (e.g. one with warmer forms)?
5. **Dark canvas:** a warm near-black (paper at night, ~`#151412`) or a cooler one?
6. **Figma:** the paywall lives in file `oehDunVlItAgXdzLNekHon`, while the token foundation is bound to `xWR4UGYyQEiWPrQ2SjCRed`. Which file becomes the design system's home, or a new one?
7. **The new app project** (ios-v2: "a separate new project"): should the design system be its own Swift package that both the old and new apps can use? I recommend yes; it lets the old app adopt tokens gradually.

## Founder, 20 Oct (late): calibrate the beige
Beige + blue stays the system, but the beige is turned down a little and made consistent: one hue for every neutral, low and even chroma (surfaces ≈ 0.003–0.006 OKLCH, rings ≈ 0.008–0.010; today's values range 0.003–0.020 across hues 68°–106°), stepped by lightness only, judged next to the sky blue in light and dark. Applied in step 6 of [the iOS refresh plan](../second-brain/ios-refresh-plan.md); v1 primitives `palette.paper.*` are superseded then.
