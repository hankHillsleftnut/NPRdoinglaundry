# organisation

## Naming
- Tokens are named for their **purpose** (`text.label`, `surface.wash`, `depth.tier.floating`), never their look. Palette steps are private inputs.
- Lowercase everywhere a person reads it: labels, captions, layer names, artboard names.

## Files (the source of truth)
```
design-system/
  tokens/        tokens.json (every value), validate.mjs (checks names, references, dark values), TOKENS.md (generated)
  icons/         one SVG per icon + icons.json
  components/    one spec per component, in Lime's form; craft.md (the checklist); README (the index)
  principles/    the founder's keys (README) and the topic docs
  process.md     how a screen is made: plan top-down, build bottom-up, a pass at every level
  lint.mjs       the script checks for every element
```

## Paper
- **00 · start here:** what the system is, the map, how to read it, the rules in one line each.
- **01 · foundations:** f1 palette · f2 colour roles · f3 type, space, size, radius · f4 depth, surfaces, gradients · f5 icons · f6 motion and haptics · f7 edges and transitions.
- **02 · components:** c1 actions and controls (every state on one grid) · c2 the player · c3 brief card, mini-player, tab bar · c4 title menu, paywall, settings.
- Every artboard opens with: a mono kicker (`c1 · components`), a lowercase serif title, one paragraph of what it is.
- Captions read **name · size · state · the rule behind it**. ✓ marks the way; ✗ appears only to explain why.
- Open decisions are labelled **your call**.

## How a component spec reads (from Lime)
What it is for · use when / don't use when · anatomy (every layer, bottom to top, with its token) · rules (MUST / NEVER / SHOULD, each with *because*) · states (with motion and haptics) · accessibility checklist · edge cases · tokens.
