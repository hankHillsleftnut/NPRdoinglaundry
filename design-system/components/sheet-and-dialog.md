---
name: sheet-and-dialog
kind: component
platform: iOS (SwiftUI)
drawn: Paper · components · 06 conversation, you and system
---

# sheet and dialog

A sheet holds a short task on top of a page; a dialog asks one question that must be answered.

## Use when
- **sheet**: sources for "why it's here", a node's story, choosing a time.
- **dialog**: confirming something that can't be undone (delete my account).

## Don't use when
- A full feature: use a page.
- Telling the person something happened: use a [toast](./toast.md).

## Anatomy
- **sheet**: *overlay* tier; top corners `radius.sheet` (38); grabber 36 × 5 (`size.grabber.width/height`); opens to `layout.sheetDetent.medium` or full; the page behind scales to 0.94 and dims (`background.scrim`); max width `layout.sheetMaxWidth`.
- **dialog**: *overlay*; full width inside the screen margins (342 on a 390 screen; drawn in part 24), radius `radius.field` (12: the founder asked for sharper, 20 Oct 2026; the old `radius.panel` 28 no longer matches the token, which is 16), padding 24; title serif 22; one line of what happens; two buttons stacked: the confirming one ([button](./button.md) destructive or primary) above "cancel" (secondary).

## Rules
1. **MUST** drive the sheet, the scale behind and the scrim from one progress value.
2. **MUST** say exactly what will happen in the dialog ("this deletes your journal, episodes and map. it can't be undone.").
3. **NEVER** stack two sheets.
4. **NEVER** use a dialog for a choice that can be undone; do it and offer undo in a toast.

## States
| State | What it looks like | Motion | Haptic |
|---|---|---|---|
| opening / open (rest) | see [player](./player.md) choreography | `motion.spring.sheet` | `haptic.sheetSnap` |
| dragging (pressed) | follows the finger 1:1; background scales back in step | 1:1 | — |
| closing | `motion.spring.sheetDismiss`, with the finger's velocity | — | — |
| pending (dialog confirm) | the button's pending state; cancel disabled | — | — |
| error | dialog stays, one line in `status.dangerText` | — | `haptic.error` |
| focused | focus moves into the sheet and is trapped until it closes | — | — |
| loading, empty | sheet content shows its own; a sheet never opens empty | — | — |
| offline | dialog confirm disabled with "needs a connection" | — | — |
| disabled | not applicable | — | — |
| dark | `background.raised` dark; scrim black 60% | — | — |

## Accessibility
- [ ] Sheet: escape gesture closes; title read first. Dialog: an alert; cancel is the default for destructive.
- [ ] Dynamic Type (accessibility 3): sheet opens full height; dialog scrolls.
- [ ] Reduce Motion: fade and 24pt slide; no scale behind. Reduce Transparency: scrim solid 60%. Increase Contrast: sheet top edge 1pt `border.control`.

## Taken out
- No close button on sheets that have a grabber and drag (except accessibility, which uses escape).
- No icons in dialogs: the words carry it.

## Edge cases
- Keyboard up in a sheet → sheet rises with it; never covers the field.

## Tokens
`radius.sheet/panel`, `size.grabber.width/height`, `layout.sheetDetent.medium`, `layout.sheetMaxWidth` (dialogs are screen width minus the margins), `background.raised/scrim`, `layer.sheet/dialog`, `motion.spring.sheet/sheetDismiss`, `status.dangerText`, `border.control`, `haptic.sheetSnap/error`.
