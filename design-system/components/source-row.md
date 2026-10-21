---
name: source-row
kind: component
platform: iOS (SwiftUI)
drawn: Paper · components · 06 conversation, you and system
---

# source row

One place Retrospect learns from (calendar, health, notes), with what it's for and whether it's working.

## Use when
- Connect in onboarding, the privacy page, "why it's here" sheets.

## Don't use when
- Inline in text: use a [chip](./chip.md).

## Anatomy
- [settings row](./settings-row.md) structure; leading 32 source icon well (radius 10, `size.sourceIcon`), title "calendar", subline = **its purpose**, not its permission ("so your brief knows what today holds").
- trailing: "connect" *wash* pill, or the status in words with a 6pt dot (`source.connected/syncing/problem/unavailable`).

## Rules
1. **MUST** say what the source is for in the subline. *Because* the north star makes privacy a purpose display, not a permission list.
2. **MUST** pair status colour with words.
3. **NEVER** pre-connect anything.

## States
| State | What it looks like | Motion | Haptic |
|---|---|---|---|
| rest (not connected) | "connect" pill | — | — |
| pressed | row `surface.subtle` | 240 back | — |
| pending (connecting) | pill ring turning, keeps width | `spin` | — |
| connected | "connected" + dot | cross-fade 200ms | `haptic.confirm` |
| syncing | "syncing" + dot | — | — |
| error | subline becomes what happened in `status.dangerText` ("stopped syncing on monday"); trailing becomes a "reconnect" pill (no dot) | blur-in | `haptic.warning` |
| disabled | "coming soon", `text.tertiary` | — | — |
| offline | status kept; connect disabled with "needs a connection" | — | — |
| focused | as settings row | — | — |
| empty, loading | loading: subline skeleton; empty: not applicable | — | — |
| dark | as settings row | — | — |

## Accessibility
- [ ] "calendar, so your brief knows what today holds, connected".
- [ ] Dynamic Type (accessibility 3): pill moves under the text. Increase Contrast, Reduce Motion, Reduce Transparency: as settings row.

## Taken out
- No "last synced 3 minutes ago": status in one word is enough; the time is in the source's own sheet.
- On error, no red dot *and* red text *and* "stopped": the subline says it once, the pill says what to do.
- No toggle: connected is managed in one place (the source sheet), not flicked from a list.

## Edge cases
- Apple Health partially allowed → "connected · some data" with a link to fix.

## Tokens
`source.connected/syncing/problem/unavailable`, `size.sourceIcon`, `surface.wash/subtle`, `status.dangerText`, `text.primary/secondary/tertiary`, `motion.duration.spin`, `haptic.confirm/warning`.
