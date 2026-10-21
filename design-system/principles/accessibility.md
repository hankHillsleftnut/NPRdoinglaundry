# accessibility

Beautiful for everyone, without getting heavy. Contrast is **measured by script** from `tokens.json` (this table is generated), not judged by eye. Targets (WCAG 2.2 AA): text 4.5 : 1; large text (24pt+, or 19pt bold) 3 : 1; meaningful icons, control edges, focus rings and status marks 3 : 1. Disabled text is exempt but always sits beside a reason that passes.


## light

| token | needs | canvas | raised | control |
|---|---|---|---|---|
| `color.text.primary` | 4.5 | 16.8 ✓ | 17.5 ✓ | 15.2 ✓ |
| `color.text.secondary` | 4.5 | 5.9 ✓ | 6.1 ✓ | 5.3 ✓ |
| `color.text.label` | 4.5 | 5.0 ✓ | 5.3 ✓ | 4.6 ✓ |
| `color.text.tertiary` | 4.5 | 4.6 ✓ | 4.8 ✓ | 4.2 (on canvas/raised only) |
| `color.text.link` | 4.5 | 6.2 ✓ | 6.5 ✓ | 5.7 ✓ |
| `color.accent.text` | 4.5 | 6.2 ✓ | 6.5 ✓ | 5.7 ✓ |
| `color.status.successText` | 4.5 | 7.1 ✓ | 7.4 ✓ | 6.4 ✓ |
| `color.status.warningText` | 4.5 | 5.3 ✓ | 5.5 ✓ | 4.8 ✓ |
| `color.status.dangerText` | 4.5 | 8.4 ✓ | 8.8 ✓ | 7.6 ✓ |
| `color.icon.default` | 3 | 14.9 ✓ | 15.6 ✓ | 13.5 ✓ |
| `color.icon.muted` | 3 | 3.3 ✓ | 3.5 ✓ | 3.0 ✓ |
| `color.border.control` | 3 | 3.3 ✓ | 3.5 ✓ | 3.0 ✓ |
| `color.border.focus` | 3 | 4.0 ✓ | 4.2 ✓ | 3.6 ✓ |
| `color.accent.border` | 3 | 4.0 ✓ | 4.2 ✓ | 3.6 ✓ |
| `color.player.progress` | 3 | 4.0 ✓ | 4.2 ✓ | 3.6 ✓ |
| `color.source.syncing` | 3 | 4.0 ✓ | 4.2 ✓ | 3.6 ✓ |

## dark

| token | needs | canvas | raised | control |
|---|---|---|---|---|
| `color.text.primary` | 4.5 | 15.3 ✓ | 13.2 ✓ | 11.6 ✓ |
| `color.text.secondary` | 4.5 | 7.5 ✓ | 6.5 ✓ | 5.7 ✓ |
| `color.text.label` | 4.5 | 7.5 ✓ | 6.5 ✓ | 5.7 ✓ |
| `color.text.tertiary` | 4.5 | 6.0 ✓ | 5.2 ✓ | 4.5 ✓ |
| `color.text.link` | 4.5 | 10.6 ✓ | 9.1 ✓ | 8.0 ✓ |
| `color.accent.text` | 4.5 | 10.6 ✓ | 9.1 ✓ | 8.0 ✓ |
| `color.status.successText` | 4.5 | 11.9 ✓ | 10.3 ✓ | 9.0 ✓ |
| `color.status.warningText` | 4.5 | 12.0 ✓ | 10.3 ✓ | 9.1 ✓ |
| `color.status.dangerText` | 4.5 | 8.1 ✓ | 7.0 ✓ | 6.1 ✓ |
| `color.icon.default` | 3 | 10.9 ✓ | 9.4 ✓ | 8.3 ✓ |
| `color.icon.muted` | 3 | 4.0 ✓ | 3.5 ✓ | 3.0 ✓ |
| `color.border.control` | 3 | 5.1 ✓ | 4.4 ✓ | 3.8 ✓ |
| `color.border.focus` | 3 | 10.6 ✓ | 9.1 ✓ | 8.0 ✓ |
| `color.accent.border` | 3 | 10.6 ✓ | 9.1 ✓ | 8.0 ✓ |
| `color.player.progress` | 3 | 10.6 ✓ | 9.1 ✓ | 8.0 ✓ |
| `color.source.syncing` | 3 | 10.6 ✓ | 9.1 ✓ | 8.0 ✓ |

## The lit label: your call
White on today's bright sky glow measures **2.2–2.6 : 1** (fails). Two passing options are drawn in Paper (c1, last row): **b** a deeper sky with the white label (4.9 : 1), or **c** today's bright sky with a deep-sky ink label (7 : 1, how Lime does it; recommended). Until you choose, the paywall keeps today's look.

## Also
- **Not by colour alone:** status pairs colour with a word or shape (guesses are dashed and say "a guess"; source dots come with the state in words and in the accessibility label).
- **Decorative lines are exempt** but never carry meaning alone: card hairlines, the dashed edge of a guess (it always says "a guess"), map edges (the map has a list twin for VoiceOver).
- **Increase Contrast:** every grey one step darker, rings to full opacity, switches get on/off labels and a 1pt control edge.
- **44pt targets** for everything; small visuals get padded frames.
- **Dynamic Type** to accessibility 3 on every screen; nothing below 11pt.
- **VoiceOver:** every control named by what it does; order follows the reading order (content first).
- **Reduce Motion / Reduce Transparency** covered in every spec.

