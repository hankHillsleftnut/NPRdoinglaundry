---
name: paywall
kind: pattern
platform: iOS (SwiftUI)
drawn: Paper · components · 01 (buttons), 04 (benefits, plan pair) · 05 states, dark and access
---

# paywall

Rises out of the first episode; scrolls to show every benefit; asks once.

## Use when
- After the first episode teaser at the end of onboarding, and when a free person opens something paid.

## Don't use when
- Mid-conversation or mid-episode. It never interrupts something the person is doing.

## Anatomy (top to bottom)
1. The episode, still playing, shrinks into the paywall [mini-player](./mini-player.md) (1.22s reveal).
2. One line of what subscribing gives you, display serif, inky.
3. **Benefit rows**, one feature each, in north-star order: the brief, the map, said vs did, the weekly episode, the journal that talks back. Each has a tiny drawing made from the person's own data where it exists; with no data, the shape with no labels. Never fake data.
4. **Plan pair**, pinned with the content fading under it (160pt `gradient.fadeToCanvas`): monthly (secondary, raised) and yearly (primary, lit) side by side. A "save 33%" badge breaks the yearly button's top edge: `background.raised`, 1pt `accent.border`, mono 11 `accent.text`, card shadow.
5. restore · privacy · terms · not now, mono 12 in 44 hit areas; "not now" in `text.link`.

## Rules
1. **MUST** show real prices from StoreKit, never typed into the design.
2. **MUST** have "not now" and "restore" visible without scrolling.
3. **NEVER** show a benefit the backend can't deliver yet.
4. **NEVER** use fake data in a benefit drawing. *Because* a made-up map promises what the app hasn't learned.
5. **MUST** make the yearly plan the one lit object.

## States
| State | What it looks like | Motion | Haptic |
|---|---|---|---|
| rest | as above | drawings draw in once as they scroll in (60ms stagger) | — |
| pressed (plan) | see [button](./button.md) | 80 / 240 | `haptic.press` |
| pending (purchase) | dots over the kept label; other plan and links disabled | 900ms pulse | — |
| success | the sheet settles away; home | sheet spring | `haptic.confirm` |
| error (purchase failed) | one line under the pair: "the purchase didn't go through, nothing was charged" | blur-in | `haptic.error` |
| cancelled | back to rest, no message | — | — |
| loading (prices) | plan labels show 60-wide skeleton bars; buttons not pressable | shimmer | — |
| offline | buttons disabled; "connect to subscribe"; not now still works | — | — |
| empty (new person, no data) | benefit drawings use shapes without labels | — | — |
| disabled | see pending and offline | — | — |
| focused | see [button](./button.md) | — | — |
| dark | canvas dark; drawings take their dark tokens; the badge keeps 4 : 1 | — | — |

## Accessibility
- [ ] Reading order: line → benefits → plans → links. Each plan reads its price and period ("yearly, $39.99 a year, $3.33 a month").
- [ ] Dynamic Type (accessibility 3): plans stack vertically (yearly first); benefit drawings hide, text stays.
- [ ] Reduce Motion: drawings appear complete.
- [ ] Reduce Transparency: the fade over content becomes a solid band.
- [ ] Increase Contrast: as button; links `text.primary`.

## Taken out
- No comparison table, no countdown, no testimonials, no "most popular" badge beside the save badge.
- No second paywall on decline: "not now" is final for this session.

## Edge cases
- Trial already used → "start" becomes "subscribe"; StoreKit decides eligibility.
- Family sharing / restored purchase → paywall closes with "you're subscribed".
- Very small phone → plans stack.

## Tokens
`glow.primary.*`, `surface.secondaryAction`, `border.secondaryRing`, `accent.border/text`, `map.*`, `goal.said/did`, `background.canvas/raised`, `gradient.fadeToCanvas`, `text.link/label/primary`, `surface.skeleton`, `haptic.press/confirm/error`.
