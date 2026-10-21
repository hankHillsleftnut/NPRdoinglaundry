---
name: lock-screen-and-widget
kind: component
platform: iOS (WidgetKit, Now Playing)
drawn: Paper · components · 06 conversation, you and system
---

# lock screen and widget

Retrospect outside the app: the now-playing card and a home-screen widget for today's brief.

## Use when
- Audio is playing (now playing, system-drawn); the person added the widget.

## Don't use when
- Notifications for everything: one a day at most (the brief is ready).

## Anatomy
- **now playing** (system): title, "retrospect", mesh artwork (`gradient.meshMorning`), skip 15 / 30, chapter as subtitle.
- **widget (small)**: radius `radius.widget`, padding `layout.widget.padding` (16); [the mark](./the-mark.md) at 16; "today's brief" mono 11; the headline in serif 15, three lines; a play button (iOS 17 interactive widget), *wash*.
- **widget (medium)**: adds the one line of what's in it.

## Rules
1. **MUST** look right in tinted and clear Home Screen modes (the serif and mark stay legible in monochrome).
2. **NEVER** show private content on the lock screen unless the person allows it; default is "your brief is ready".

## States
| State | What it looks like |
|---|---|
| rest (ready) | as above |
| pressed | system press |
| playing | play becomes pause; "playing" mono |
| played | headline `text.secondary`, "played" |
| empty (quiet day) | "a quiet day" serif |
| loading (being made) | "being made" mono, no play |
| error, offline | "open retrospect to load today's brief" |
| pending, focused, disabled | system-managed |
| dark | dark tokens; tinted mode uses the system tint |

## Accessibility
- [ ] "today's brief, the week you kept choosing the river, play".
- [ ] Dynamic Type (accessibility 3): system scales; headline two lines.
- [ ] Reduce Motion, Reduce Transparency, Increase Contrast: system-managed; our colours pass in all three modes.

## Taken out
- No progress bar, no date (the system shows it), no count of entries.

## Edge cases
- Brief off → the widget says "turn on your daily brief in retrospect" once, then the episode of the week.

## Tokens
`radius.widget`, `layout.widget.padding`, `gradient.meshMorning`, `surface.wash`, `text.primary/secondary/label`, `font.family.display/mono`.
