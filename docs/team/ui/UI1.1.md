### UI1.1 · Drawer                                                   size: M
Place in the tree: journal › JR-3 › drawer (host, list, foot)
Repo · branch: NPRdoinglaundry · ui/UI1.1-drawer
Needs: C31, #53 (`RSearchField`), UI0.1 (`.drawerFoot`), UI1.0        Unblocks: P11

Why: one swipe from the journal's edge shows everything you've sent, by day, searchable. The journal stays visible beside it as the way back.

Inputs:
- Reference: "Drawer (JR-3)" in extra parts; §C31; screen rule 29 ("slides aside, rounded and shadowed")
- Paper:
  - drawer master `DF8-0` / `DPL-0`; searching `DRA-0`; empty and no results `G7O-0`
  - M3 key states `E4L-0`
  - JR-3 `1FOQ-0`: search `c:search-field/journal/rest` `1FQT-0`, foot `c:row/drawer-foot/rest` `1FOS-0`, sliders glyph `1FOV-0`, label bar `1FPD-0`
- Contract: 02 §5 (`GET /v2/entries?cursor&limit=50&q`)

Spec:
- **Host:**
  - drawer width = screen width − 74 on every device; `background.underlay`
  - the status bar stays fixed over both layers
  - the journal page slides aside under it, rounded (`radius.behindSheet` 12, `RShape.rect`) with a cast shadow
  - one progress value drives the page offset, radius and shadow
  - opened by the drawer button (C17) or an edge swipe from the leading 20pt; closed by tapping the visible journal edge, swiping back, or choosing a row
- **List:**
  - the label bar (C17 `.label`) at the top, then the search field (sunken recipe)
  - entries grouped by day, with a sticky day label (S13 `RSectionLabel`) pinned under the search field (`LazyVStack(pinnedViews: .sectionHeaders)`)
  - pagination at 50; the next page loads 10 rows before the end
- **Foot:** "settings · version", pinned 32 above the home indicator (16 off the bottom on SE); the list fades under it with `.drawerFoot` (56pt, 6pt max, canvas → underlay).
- **Search:**
  - debounce 250ms on the injected clock; empty query → the full list
  - results stagger in 40ms (`stagger` cap 6)
  - "no results" blur-replaces
  - the clear × scales in on `popover`
- **SE:** 20 margins.

State table:

| State | Look | Motion | Haptic |
|---|---|---|---|
| closed | journal only | — | — |
| opening (drag or button) | page slides aside, rounds, shadow grows | `RMotion.sheet` with gesture velocity | none |
| open | as `DPL-0` | — | — |
| searching | results with match highlights | stagger 40ms | — |
| no results | one line (from `G7O-0`) | `.rBlurReplace` | — |
| empty (day one) | "nothing yet" quiet mark (from `G7O-0`) | — | — |
| loading more | skeleton rows at the end (C39.1) | shimmer | — |
| offline | "offline · new notes send when you're back" (C39.4, grey) under the search field | blur-replace | — |
| dark | underlay `night.950` | — | — |

Interaction table:

| Touch | Press | Haptic | Motion | Outcome | Reduce Motion |
|---|---|---|---|---|---|
| drawer button | 0.94 | none | `sheet` | opens | 140 cross-fade, no slide |
| edge swipe | — | none | 1:1, then `sheet` with velocity | opens or springs back (threshold: half the width or 500pt/s) | same drag; release fades |
| tap the journal edge | — | none | `sheet` | closes | fade |
| type in search | — | none | stagger | filtered results | no stagger |
| a row | wash | none | `sheet` close + thread scrolls to the entry on `gentle` | closes, jumps the thread, highlights the entry once (wash pulse 600ms) | no pulse; jump |
| settings in the foot | dims 0.7 | none | push | settings (later flow: shows the old settings until G6) | same |

Accessibility:
- the open drawer is `.isModal`; the journal edge is a button "close drawer"; escape closes
- the search field is labelled "search your journal"
- day labels have the header trait
- AX3: rows grow and the width stays screen − 74 (at AX5, screen − 44 so text fits: a listed decision)

Acceptance:
- Matches `DPL-0`, `DRA-0` and `G7O-0`.
- The page, radius and shadow never disagree mid-drag.
- Search never fires per keystroke (debounced).
- The day label sticks.

Tests:
- (unit) search waits 250ms after the last keystroke
- (unit) clearing the field restores the full list
- (unit) the next page is requested 10 rows before the end, once
- (snapshot) open, searching, no results, empty and offline, light, dark and ax3
- (UI) the edge swipe opens the drawer
- (UI) choosing a row closes the drawer and the thread shows that entry
- (UI) escape closes the drawer

Proof in the PR: standard proof, plus open, close and interrupted-drag recordings.

Watch out:
- The edge swipe must not fight the system back gesture: the journal is a tab root with nothing to go back to, but check after pushes.
- Pagination with sticky headers: keep stable `id`s (entry id), or rows jump when a page lands.
