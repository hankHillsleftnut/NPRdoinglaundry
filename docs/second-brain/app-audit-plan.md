# App audit (step 1 of 3): plan

20 October 2026. Step 1 of the approach in [ios-v2.md](./ios-v2.md#the-approach-in-three-steps-founder-20-oct): **audit the entire current iOS app**, onboarding and every app screen. Screen by screen, interaction by interaction, pixel by pixel, and psychologically. **This document plans the audit; the audit starts once the plan is agreed.** Steps 2 (where the new functionality enters) and 3 (the new onboarding, carried into the home screen and daily use) come after and aren't planned here.

## What "finding all the problems" means here

Every finding is one of these kinds (ios-v2's nine criteria plus three more):

| Kind | Example from what's already logged |
|---|---|
| Redundant | "Learning about you" *and* a demo podcast doing one job |
| Broken | "Learning about you" hangs at 94% |
| Interaction issue | "Make my podcast" covers the list |
| Doesn't make sense | state labels "Device sync", "First sync queued" |
| Confusing | several Play Podcast buttons |
| Not fun | the questionnaire feel |
| Doesn't feel good | raw "HTTP 500: {…}" errors |
| Not inspiring / flat | canned hosts |
| **Demo or fake** *(new)* | the demo transcript shown as if it were yours; the fake percentage |
| **Dead or unreachable** *(new)* | the four unused onboarding flows |
| **Psychological** *(new)* | a wait with no reason given; a choice asked before trust is earned |

## Scope: the whole app

**A. Onboarding** (the live path, traced from `RetrospectApp.swift`):
1. Welcome and sign-in
2. Voice goals
3. Connections
4. Host picker
5. Closing page
6. First podcast: "Learning about you", demo, paywall
7. Backend sign-in gate
8. Face ID splash

**B. The app** (`DarkAppContainer`), behind the side panel:
- **Journal** (`DarkJournalView`)
- **Podcasts** (`DarkPodcastsView`)
- **Goals** (`DarkGoalsView`)
- **Entries** (`DarkEntriesView`)
- **Settings** (`DarkSettingsView`)
- Plus, from anywhere:
  - the **voice recorder** (full screen);
  - the **full player**;
  - the sheets: share, import, export, sign-in, input, Polaroid;
  - widgets and the Live Activity;
  - notifications and deep links.

**C. Everything else in the code:** all 114 screen files (52,000 lines). Each one is classified as **reachable** (on a path above), **reachable only in debug**, or **dead**, with how it's reached. This is how the "five onboarding flows" and other leftovers get found for certain.

## The five passes, per screen

**1. Purpose.** Before reading a word, can you tell what this screen is for? What does it ask, and what does the person get for it? Could it merge with another screen or disappear?

**2. Interaction.** A table of every element:

| Element | What the person expects | What happens | Feedback (visual · haptic · motion · sound) | States: loading · empty · error · disabled · offline |

Plus the edge paths, every time:
- back and swipe;
- the app closed mid-step and reopened;
- offline;
- a slow server (Render cold start, up to ~50 s);
- a permission denied;
- tapping twice;
- background and return;
- a phone call during recording or playback.

**3. Pixel.** Measured against the new tokens ([design-system/tokens](../../design-system/tokens/README.md)):
- spacing, type, colour and alignment drift;
- overlaps and clipping, safe areas;
- iPhone SE and Pro Max sizes;
- Dynamic Type at its largest;
- dots over text;
- motion and pacing against the paywall reveal (1.22 s, the reference).

**4. Code.** Read each screen's Swift for:
- patches and dead branches;
- fake progress;
- duplicate work (the second episode);
- raw values that should be tokens;
- state that isn't saved;
- raw server errors;
- `DEBUG`-only paths that leak into release.

**5. Psychological.** What is the person thinking and feeling at this exact moment, and does the screen meet it? Judged with well-established principles:

| Lens | The question it asks | Source |
|---|---|---|
| Trust before ask | Is anything asked (data, permission, money) before the person has seen why? | permission-priming practice; reciprocity |
| Waits | Is every wait explained, honest, and as short as it can be? Uncertain and unexplained waits feel longer | Maister 1985, *The Psychology of Waiting Lines* |
| Choice load | How many choices at once? Are defaults chosen for them? | Hick's law; default effects |
| Effort vs reward | Does each step give something back soon after it takes something? | endowed progress (Nunes & Drèze 2006); IKEA effect |
| The arc | Where are the peak and the end of the onboarding, and are they the best moments? People judge an experience by its peak and its end | peak–end rule (Kahneman et al. 1993) |
| Self-image | Does it ever make the person feel examined, judged or behind? | goal 9: "relief, not a performance review" |
| Clarity of state | Do they always know what's happening, what's done, and what's next? | Nielsen's visibility of system status |
| Habit | In daily use, what's the cue, the action and the reward? Is there a reason to open it tomorrow? | habit loop (Wood & Neal 2007) |

These are drawn as a **journey map**: what the person does, thinks and feels, step by step, across onboarding and the first week of use.

## The demo and fake inventory (for demo vs ship)

Every demo, fake, placeholder, sample-data path, `DEV` button and debug layer gets listed (for example: the demo transcript fallback, the fake percentage, canned hosts, "DEV: Go home", `PodcastLayoutDiagnosticsOnboardingLayer`). Each one is marked:
- **remove from ship;**
- **move to the demo account** (the same build, signed into a staged account);
- **replace with the real thing** (it now exists in the core product).

## Re-checking what's already known

All ~25 problems already logged ([ios-v2 §2](./ios-v2.md#2-problems-in-the-current-app), [ios-app-review-log.md](./ios-app-review-log.md)) are re-tested, each marked still there / fixed / changed, with fresh evidence.

## What it produces: two audits (founder, 20 Oct)

**A UI audit** (the pixel and interaction passes: layout, type, colour, motion, states, against the tokens) and **a product audit** (the purpose, code and psychological passes: logic, flows, redundancy, broken promises, demos), reported separately in `app-audit.md`.

### `app-audit.md` contains

1. **The journey on one page:** every screen as a thumbnail, with the times, taps, waits and spend between them (onboarding and a first week).
2. **The psychological journey map:** what the person does, thinks and feels, with the peaks and the drop-off risks marked.
3. **One section per screen:** screenshots of each state; the purpose verdict; the interaction table; pixel notes; code notes; the psychological read; findings.
4. **Cross-app findings:** redundancies between screens, the tangled stories ("Learning about you" + demo + Play buttons), the reachability map, and the demo/fake inventory.
5. **The ranked list:** every finding with its kind, severity (**blocker** · **major** · **minor**), evidence (screenshot, recording time or code line), exact repro steps, and the user impact in one line. **No fixes are designed yet.** That's step 3; this step only finds and proves problems.

## How it's run

- **On the iOS Simulator** for everything it can do. I drive the app myself, tap every path, and screenshot every state. A fresh install for each run, plus runs with a "returning user".
- **On your phone** for what the simulator can't do (Health, Screen Time, the real calendar, the microphone, real speed, widgets and the Live Activity). You record the screen; I review frame by frame.
- **Static pass** over all 114 screen files for reachability and code findings. Free, and needs nothing from you.
- **Spend:** each full onboarding makes a real episode (~$2–4 in voice). Options: a "skip generation" test switch (ios-v2 already asks for one), or an agreed budget.
- **Privacy:** screenshots from your real account stay in the private `.scratch/` folder, never committed.

## Order inside step 1

1. **Static pass** (no app needed): the reachability map, the code findings, and the demo/fake inventory from code.
2. **Onboarding walk-through** on the simulator: every path and edge, then the psychological map.
3. **App walk-through:** each tab, each sheet, the player, the recorder; the first week simulated.
4. **Phone recording review** for the device-only parts.
5. **Re-check the known problems**, then write `app-audit.md` and the ranked list.

## Questions before starting

1. **Simulator plus your phone?** (Recommended: the simulator for everything it can do, plus one screen recording from your phone.)
2. **Which account?** I can't sign into an Apple ID. Your account (screenshots stay private), or a test Apple ID you sign in once on the simulator? This could become the demo account.
3. **Spend:** add the skip-generation test switch first (small), or allow a budget (e.g. 3 full runs, about $10)?
4. **FigJam board** of the journey and psychological map, alongside the document? Useful when you redesign in step 3.
5. **The first week of use:** may I simulate days passing on a test account (entries, a brief, an episode), so the audit covers daily use and not only first launch?
