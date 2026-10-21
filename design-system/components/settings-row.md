---
name: settings-row
kind: component
platform: iOS (SwiftUI)
drawn: Paper · components · 04 menus, paywall, settings · 05 states, dark and access
---

# settings row

One setting, one action, or one place to go.

## Use when
- Settings, You, and the privacy page: a list of things the person controls.

## Don't use when
- Content (entries, episodes): those have their own rows and cards.
- A single important choice in the middle of a flow: use a [button](./button.md).

## Variants
- **switch row**: title (text 17, `text.primary`) + subline (text 15, `text.secondary`) + a trailing [switch](./switch.md).
- **action row**: title + subline + a trailing *wash* pill (height 36, radius 18, `surface.wash`, mono 13 `text.primary`: "add", "connect", "export") inside a 44 hit area.
- **value row**: title + the current value in mono `text.label` + icon `chevron-up-down`; opens a sheet or a [title menu](./title-menu.md).
- **leaves-the-app row**: title + icon `external` (16pt, `icon.muted`). ↗ means "this opens outside Retrospect".
- **story card**: a small tilted card (−4°, radius 14, *raised*, its own warm `0 10 20 −8` cast) beside a line of text 19 and icon `arrow-right`. At most once per page.

## Anatomy
- height ≥ `size.row.default` (56); padding 16 vertical, 24 horizontal (screen margin); title and subline 2pt apart; trailing control centred on the title's x-height when there is one line, on the pair when there are two.
- rows sit on the *page* (level 0); groups are separated by space, not boxes; a 0.5 `border.subtle` between rows inset to the text.
- section title above a group: the part 21 section label (Geist 12 medium, text.label, lowercase; founder 20 Oct 2026), 32 between groups, 4 above its rows.

## Rules
1. **MUST** write titles as what the setting does, lowercase ("autoplay the next episode"); the subline says when or what "on" means.
2. **MUST** use ↗ only for links that leave the app; a chevron for places inside.
3. **NEVER** show anything for developers. Production settings only.
4. **MUST** put destructive rows (delete my account) last, alone in their group, in `status.dangerText`, opening a dialog.

## States
| State | What changes | Motion | Haptic |
|---|---|---|---|
| rest | as above | none | none |
| pressed | row background `surface.subtle` at once | fades back 240ms | none |
| focused | 2pt `border.focus` inset around the row | — | — |
| pending (connect) | the pill shows a turning ring and keeps its width | `spin` | none |
| error | subline turns `status.dangerText` with what to do ("reconnect calendar") | blur-in 220ms | `haptic.warning` |
| disabled | title and subline `text.tertiary`; the subline says why ("needs a connection") | — | — |
| empty | a group with nothing in it is not shown | — | — |
| loading | the trailing value shows a 40-wide skeleton bar | shimmer | — |
| offline | rows that need the network show disabled with "needs a connection" | — | — |
| dark | page `background.canvas` (dark); separators white 8%; story card `background.raised` (dark) | — | — |

## Accessibility
- [ ] One element per row: "autoplay the next episode, when the current one ends, switch, on".
- [ ] Dynamic Type (accessibility 3): trailing control moves under the text; the row grows; nothing truncates.
- [ ] Increase Contrast: separators 1pt `border.control`; sublines `text.primary`.
- [ ] Reduce Motion: pressed state without the fade.
- [ ] Reduce Transparency: no change.
- [ ] Contrast: subline 6.1 : 1; ↗ 3.3 : 1.

## Taken out
- No leading icons on ordinary rows: a list of icons is visual noise. Sources keep theirs because the logo is how people find them.
- No boxes around groups: space groups them.

## Edge cases
- Very long title in another language → wraps; never truncated.
- Two rows that depend on each other (brief on → brief time) → the dependent row disables with the reason, never hides.

## Tokens
`text.primary/secondary/label/tertiary`, `surface.subtle/wash`, `icon.muted`, `border.subtle/focus/control`, `status.dangerText`, `background.canvas/raised`, `size.row.default`, `motion.duration.spin`, `haptic.warning`, `font.family.display/text/mono`.
