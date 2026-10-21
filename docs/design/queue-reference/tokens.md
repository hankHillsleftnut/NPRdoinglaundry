# Queue: design tokens (reference study)

20 October 2026. Extracted from the 7 full-resolution screens on the maker's site (eikedrescher.com/queueapp), measured pixel by pixel. Scale: the iPhone screen is 1,028 px wide in the images, which is 393 pt, so **2.616 px = 1 pt**.

**Confidence:** **M** = measured from pixels (±1 pt / exact hex) · **E** = estimated from measurements (±2 pt) · **I** = inferred from looking (not measurable from images).

**Purpose:** to understand how a highly praised, minimal iOS app is built, as input to Retrospect's own tokens. Not to copy its look.

---

## The one idea underneath everything

**The interface is grayscale; colour comes from the content.** Podcast artwork, host faces and flags carry all the colour. The UI's own colour is limited to Apple's system accents, each with one job: blue to subscribe, green for data highlights, orange for the sleep timer. Everything else is about seven greys on an off-white canvas.

---

## 1. Colour

### Neutrals (light)
| Token | Value | Where it's used | |
|---|---|---|---|
| `bg.canvas` | `#F8F8F8` | every screen's background (not pure white) | M |
| `bg.raised` | `#F6F6F6` | search pill, floating controls | M |
| `fill.control` | `#EEEEEE` | Play / Pause pill, archive button | M |
| `fill.control-alt` | `#EDEDED` | secondary round buttons | M |
| `fill.track` | `#ECECEC` | progress track (list) | M |
| `fill.track-strong` | `#E4E4E4` | progress track (player) | M |
| `fill.bar-idle` | `#DFDFDF` | inactive chart bars | M |
| `text.primary` | `#000000` | titles, headlines, button labels | M |
| `text.secondary-strong` | `#4A4A4A` | podcast name in metadata | M |
| `text.body` | `#7B7B7B` | show notes / descriptions | M |
| `fill.progress` | `#767676` | progress fill in the list | M |
| `text.secondary` | `#959595` | dates, labels, stats copy | M |
| `text.tertiary` | `#A6A6A6`–`#ADADAD` | durations inside pills, meta dates | M |

### Accents (Apple system colours, one job each)
| Token | Value | Job | |
|---|---|---|---|
| `accent.action` | `#0396E5` | the one primary action (Subscribe) | M |
| `accent.link` | `#0095FF` | shared-link bubble / system blue | M |
| `accent.positive` | `#34C85A` | highlighted data (top weekday bar) ≈ iOS `systemGreen` | M |
| `accent.timer` | `#FF9F0A` | sleep timer (dark) = iOS `systemOrange` (dark) | M |
| `gradient.widget` | `#74D0FE` → `#73BBFF` | widget background, top to bottom | M |

### Dark
| Token | Value | |
|---|---|---|
| `bg.canvas.dark` | `#131418` (very slightly blue-black, not pure black) | M |
| `fill.control.dark` | `#2E2E32` | M |

---

## 2. Typography

Three families, each with one role:

| Role | Family | |
|---|---|---|
| **Display** | A **condensed, heavy grotesque** (titles, big episode headlines, the wordmark). Possibly SF Pro's condensed width at Black, or a licensed condensed face; not identifiable from pixels alone | I |
| **Text** | A neutral grotesque (Inter-like or SF Pro Text) for everything readable | I |
| **Numeric** | **Monospace** for times and counts (`29:06`, `−22:54`, `1018`), so digits don't jitter while playing | M (look) |

| Token | Size / weight | Measured from | |
|---|---|---|---|
| `display.xl` | ~44 pt, Black, condensed, line height ~55 pt | episode headline in the player (cap height 32 pt, lines 55 pt apart) | E |
| `display.l` | ~32 pt, Black, condensed | podcast name on its page (cap height 22.5 pt) | E |
| `display.m` | ~30 pt, Black, condensed | "Queue" screen title (cap height 21 pt) | E |
| `headline` | ~17 pt, Semibold | episode title in the list | E |
| `body` | ~17 pt, Regular, `text.body` | show notes | E |
| `subhead` | ~15 pt, Regular, `text.secondary` | date under the title | E |
| `caption` | ~12–13 pt, Medium | podcast name + date row | E |
| `numeric` | ~12 pt mono | elapsed / remaining time | E |
| `numeric.display` | ~30 pt mono | stat numbers ("1018") | E |

**Contrast trick:** the big condensed display face against small, quiet grey text is most of the app's personality.

---

## 3. Spacing and layout

| Token | Value | |
|---|---|---|
| `margin.screen` | **34 pt** left and right, which is generous for iOS (most apps use 16–20) | M |
| `gap.row` | **42 pt** between list items | M |
| `size.art.row` | 20 pt square artwork in list metadata | M |
| `size.art.player` | ~64 pt square artwork on the player | E |
| `size.art.page` | ~120 pt square artwork on a podcast page | E |
| `height.pill` | **34 pt** Play / Pause pill | M |
| `height.pill.search` | ~44 pt search pill | E |
| `height.miniplayer` | ~54 pt floating mini-player | E |
| `height.progress` | **4 pt** progress bar | M |
| Rhythm | Spacing falls on a loose 4 pt grid; layout breathes through large margins and gaps, not dividers | I |

---

## 4. Shape and depth

| Token | Value | |
|---|---|---|
| `radius.pill` | full capsule for every button (Play, Search, Subscribe, mini-player) | M (look) |
| `radius.art` | ~6 pt at 20 pt, ~12 pt at 64 pt+ (about 20% of size) | E |
| `radius.sheet` | ~20 pt on stacked sheets (player, podcast page) | E |
| `radius.widget` | ~30 pt | E |
| Depth | Almost no lines. Separation comes from soft, wide shadows under floating things (mini-player, search pill, artwork) and from stacked sheets that show the one behind | I |

---

## 5. Components the tokens build

- **Episode row:** [art 20 + podcast name + date + "played" check] → headline (2 lines max, truncates) → optional progress bar → [Play/Pause pill with duration] [archive circle] [⋯].
- **Mini-player:** a floating capsule with art, −15, +30 and pause, above a three-icon tab bar.
- **Player sheet:** art, actions top-right, meta, giant display headline, fading show notes, chapter name, segmented progress (chapters as gaps), mono times, transport capsule, speed.
- **Podcast page:** big art, display name, 2-line description, stat strip (Hosts / Episodes / Language / Release) with vertical dividers, one blue Subscribe, search field.
- **Insights:** floating favourite artworks, prose stats with bold numbers, a weekday bar chart with one green bar.

---

## What Retrospect can take from this (principles, not pixels)

1. **Let the content carry the colour.** For Retrospect, that content is the person's own life.
2. **One accent, one job each.**
3. **A big display face against quiet text,** for personality.
4. **Generous margins (~32 pt) instead of dividers.**
5. **Mono numbers wherever time ticks.**

**Next:** decide Retrospect's own token set (canvas, greys, one accent, a display face, the spacing scale), then build components from those tokens.
