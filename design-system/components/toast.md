---
name: toast
kind: component
platform: iOS (SwiftUI)
drawn: Paper · components · 06 conversation, you and system
---

# toast

Says something just happened, offers undo, and goes away.

## Use when
- An action finished somewhere the person can't see ("saved", "ended the goal · undo").

## Don't use when
- An error that needs fixing: show it where the problem is.
- Anything the person must read: toasts disappear.

## Anatomy
- pill, height 44, radius 22, max width `layout.toastMaxWidth`; *floating* tier; `background.inverse` with `text.inverse` mono 13; optional "undo" in `accent.subtle` text at the trailing side with a 44 hit area.
- sits 12pt above the mini-player or tab bar (`layer.toast`).

## Rules
1. **MUST** be one short line.
2. **MUST** offer undo for anything undoable.
3. **NEVER** show two at once; the new one replaces the old.

## States
| State | What it looks like | Motion | Haptic |
|---|---|---|---|
| arriving / visible (rest) | rises 12pt, blur 6 → 0 | 240ms; stays `toastVisible` | — |
| pressed (undo) | undo dims | — | `haptic.select` |
| leaving | fades and drops 6pt | 160ms | — |
| held (touching it) | stays while touched | — | — |
| focused | VoiceOver focus keeps it visible | — | — |
| pending, error, loading, empty, offline, disabled | not applicable: a toast reports a result | — | — |
| dark | `background.inverse` becomes light paper, text dark | — | — |

## Accessibility
- [ ] Announced politely; stays until VoiceOver leaves it.
- [ ] Dynamic Type (accessibility 3): wraps to two lines, grows in height.
- [ ] Reduce Motion: fade only. Reduce Transparency: no change. Increase Contrast: already 15 : 1.

## Taken out
- No icon: the words say it. No close button: it leaves on its own; swipe down to dismiss early.

## Edge cases
- Keyboard up → sits above the keyboard.

## Tokens
`background.inverse`, `text.inverse`, `accent.subtle`, `layout.toastMaxWidth`, `layer.toast`, `motion.duration.toastVisible`, `haptic.select`.
