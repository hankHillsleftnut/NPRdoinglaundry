---
name: composer
kind: component
platform: iOS (SwiftUI)
drawn: Paper · components · 06 conversation, you and system
---

# composer

Where the person types: a reply in the conversation, a journal entry, a search.

## Use when
- Free text is the answer: replying to Retrospect, writing an entry, searching your mind.

## Don't use when
- The answer is one of a few choices: offer [chips](./chip.md) above the composer instead.
- Speaking is the main way in: the [talk button](./talk-button.md) leads and the composer is one tap away.

## Anatomy (bottom to top)
1. **field**: min height 48 (`size.composer.minHeight`), grows to `size.composer.maxHeight` then scrolls; radius 24 while one line, `radius.field` (20) once it grows (the corner stays concentric with the send well: 24 − 4 = 20). *Raised at rest* (`background.raised`, top stroke, hairline, contact + cast). *Founder, 20 Oct: "the message area should not be recessed… this will not be the main input card on the home screen."* The recess below is kept for other inputs, never for the home composer.

   **Recess recipe (other inputs: search, inline fields):** `surface.washPressed` laid over the parent (always darker than what it sits on; never a lighter solid such as `background.sunken`, system rule from the founder, 20 Oct: "it needs to be darker than the background that it is on"), inset `depth.shadow.sunken` 0 1 3, inset 0.5 `depth.stroke.outer`, and a 1pt `depth.stroke.innerTop` catch on the bottom lip. Founder liked it, 20 Oct; reference copy on the archive board, "recess recipe".
2. **placeholder**: text 17 `text.tertiary`, lowercase, a question not an instruction ("what's on your mind?").
3. **text**: text 17/24 `text.primary`; caret `accent.default`.
4. **leading**: icon `mic` in a 40 *wash* well (switches to voice).
5. **send well**: 40 round inside the 48 field (4pt inset), *lit* when there is text (`glow.primary` gradient, rim, edge, bloom, 1pt ring, halo, cast; founder 20 Oct), icon `send` in `glow.primary.foreground`; hidden (not disabled) when empty.
6. **soft edge above**: the conversation scrolls under the composer through the eased fade.

## Rules
1. **MUST** never lose what was typed: drafts survive leaving the screen and the app closing.
2. **MUST** hide send when empty rather than show it disabled. *Because* a dead button with no reason looks broken.
3. ~~NEVER glow the send.~~ **Superseded by the founder, 20 Oct ("this button needs color"):** send is lit (the glow.primary recipe of the brief-card play, scaled to its well). It is the one blue thing on the bar, and appears only once there are words.
4. **SHOULD** keep the keyboard up after sending; the conversation continues.

## States
| State | What it looks like | Motion | Haptic |
|---|---|---|---|
| rest (empty) | placeholder; mic shown; no send | — | — |
| focused | (superseded 20 Oct: the field is already raised at rest; focus shows only the caret and send) the field lifts: sunken → raised (`background.raised`, top stroke, hairline, contact + cast); no coloured ring. *Founder, 20 Oct: the 1.5pt blue outline read crude.* The 2pt `border.focus` ring stays only for keyboard / Full Keyboard Access focus | 160ms ease-out | — |
| typing | send rises in (scale 0.86 → 1, blur 4 → 0) | `motion.spring.popover` | — |
| pressed (send) | 0.94 | 80 / 240 | `haptic.select` |
| pending (sending) | the text lifts into a message bubble (matched geometry); field clears | 280ms | — |
| error | the message stays with "not sent · tap to retry" under it; the draft is kept | blur-in | `haptic.error` |
| disabled | while Retrospect is speaking: placeholder "listening to retrospect…", still typeable to interrupt | — | — |
| offline | sends queue: "will send when you're back online" under the message | — | — |
| empty, loading | rest is the empty state; loading not applicable | — | — |
| dark | field `background.field` (dark), inner shade black 30%, hairline white 6% | — | — |

## Accessibility
- [ ] Text field "reply to retrospect"; send "send"; mic "talk instead".
- [ ] Dynamic Type (accessibility 3): text grows; the field grows to 40% of the screen before scrolling.
- [ ] Increase Contrast: 1pt `border.control` ring at rest; placeholder `text.secondary`.
- [ ] Reduce Motion: send appears without scale or blur.
- [ ] Reduce Transparency: no change.
- [ ] Contrast: placeholder 4.6 : 1 on the field; the field edge 3 : 1 with the ring.

## Taken out
- No attach, camera or emoji buttons: Retrospect learns from connected sources, not attachments.
- No disabled send: it isn't there until there's something to send.
- No character count.

## Edge cases
- Pasting a very long text → field scrolls; a soft fade at its top edge.
- Hardware keyboard → return sends, shift-return adds a line.
- Dictation from the keyboard → allowed; it is not the talk button.

## Tokens
`background.field/raised`, `depth.shadow.sunken/cast`, `depth.stroke.inner/outer`, `border.fieldFocus/control`, `text.primary/tertiary/secondary`, `accent.default`, `surface.wash`, `radius.field`, `size.composer.minHeight/maxHeight`, `motion.spring.popover`, `haptic.select/error`.
