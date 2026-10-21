---
name: message
kind: component
platform: iOS (SwiftUI)
drawn: Paper · components · 06 conversation, you and system
---

# message

One turn in the conversation with Retrospect: onboarding, Journal replies, "why it's here".

## Use when
- A turn in a back-and-forth with Retrospect.

## Don't use when
- A journal entry: entries are pages, not bubbles.
- A system notice: use a [toast](./toast.md).

## Variants
- **theirs (Retrospect)**: no bubble. Text 17/26 `text.primary` straight on the page at the leading margin, with no mark or icon (founder, 20 Oct: "there should not be a icon here. that is not needed"). Retrospect's words are content, so they read like a page, not a chat app.
- **mine**: a bubble, `message.mine` (a warm wash), radius 18 (`radius.message`) with the trailing-bottom corner 4 (`size.border.inset`), each corner set on its own, max width `layout.messageMaxWidth`, text 17/24, trailing aligned, *wash* level (no shadow).
- **with a guess**: Retrospect's line carries a [guess card](./guess-card.md) under it.

## Anatomy
- turns 24 apart; consecutive lines from the same side 8 apart.
- time appears only on a gap over 10 minutes, mono 11 `text.label`, centred.

## Rules
1. **MUST** keep Retrospect's text unboxed. *Because* the north star is a conversation that feels like being understood, not a support chat.
2. **NEVER** use typing dots longer than 1.2s; stream the words instead (blur-in per line). *Because* waiting on dots feels like a bot.
3. **MUST** let any Retrospect line be corrected ("not right") with a long press.

## States
| State | What it looks like | Motion | Haptic |
|---|---|---|---|
| rest | as above | — | — |
| arriving (theirs) | each line resolves from blur 5 → 0 and opacity 0 → 1 as it streams | 240ms per line | `haptic.turn` when the turn ends |
| sending (mine, pending) | bubble at `opacity.pending` (70%); no spinner, no word | — | — |
| error (mine) | "not sent · tap to retry", Geist 12 `status.dangerText` with the `retry` glyph, under it | blur-in | `haptic.error` |
| pressed (long press) | the line lifts (raised card) and a menu: copy · correct this · why you said this › | popover spring | `haptic.longPress` |
| focused | drawn by iOS (Full Keyboard Access); not drawn on boards (founder, 20 Oct: rings read as "selected") | — | — |
| loading | three dots in `text.label` for at most 1.2s | `typing` | — |
| empty | the conversation's first state is Retrospect's opening line, never an empty screen | — | — |
| offline | mine stays, with "will send when you're back online" (Geist 12 `text.label`, `offline` glyph) | — | — |
| disabled | not applicable | — | — |
| dark | `message.mine` dark; text tokens invert (drawn in M12) | — | — |

## Accessibility
- [ ] "retrospect: …" / "you: …"; new Retrospect lines announced when the turn finishes, not word by word.
- [x] Dynamic Type (accessibility 3): text grows to `type.ax3.body` (40/48, Apple's AX3 table); your bubble takes the full width minus margins. Drawn in 02b part 08.
- [x] Increase Contrast: mine gets a 1pt `border.control` edge. Drawn.
- [x] Reduce Motion: lines fade in without blur, 140ms. Drawn.
- [x] Reduce Transparency: nothing translucent, so no change.
- [ ] Contrast: 15 : 1 for both.

## Taken out
- No bubble, avatar, mark or name on Retrospect's lines: being unboxed is the tell.
- No read receipts, no timestamps on every line, no "delivered".

## Edge cases
- A very long reply → no truncation; the page scrolls and follows unless the person scrolled up.
- Emoji-only message → bubble hugs; no larger text.

## Tokens
`message.mine/theirs`, `radius.message`, `size.border.inset`, `opacity.pending`, `type.ax3.body`, `layout.messageMaxWidth`, `text.primary/label`, `status.dangerText`, `border.focus/control`, `motion.duration.typing`, `haptic.turn/error/longPress`, `font.family.text/mono`.
> Founder, 20 Oct (c-mjy9uu): "why is the line width in these messages so short?" Message text never uses `text-wrap: balance` or a fixed width. Retro's (unboxed) replies fill the column; your bubble hugs its words up to ~80% of the column (280 on 17 Pro). Lines break where they naturally fill (wrap: pretty, avoiding a one-word last line where possible).
