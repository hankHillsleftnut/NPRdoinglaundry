# The iOS refresh: step-by-step plan

20 October 2026, night. Written from the founder's direction the same night, so every idea in it is kept. It replaces the stage list in [ios-v2-implementation-plan.md](./ios-v2-implementation-plan.md) as the order of work; that document, [ios-v2.md](./ios-v2.md), [ios-v2-opportunities.md](./ios-v2-opportunities.md), [app-audit.md](./app-audit.md), [app-audit-deep.md](./app-audit-deep.md) and [app-audit-research.md](./app-audit-research.md) are its inputs.

**The one-page board** (screens, problems, plan, ideas): https://claude.ai/artifact/9uf2mRH9rk9RKneh4XrQDb

---

## The shape the founder wants (keep this in mind at every step)

**The interaction paradigm stays simple: one feature per page.** A navigation bar at the bottom; each page is dedicated to one feature and shows that feature off fully (founder, 20 Oct, correcting an earlier draft that put every feature on every page). A page doesn't advertise or carry the other features; you reach those through the bar. Nothing powerful is hidden three levels down: every major feature has a page of its own, reachable in one tap.

What this means in practice:
- **Each page has one job,** and everything on it serves that job (search is the Search page; talking to it lives on the page whose feature it is).
- **No cross-feature clutter:** no global search field, chat button or feature menu repeated on every page.
- **Discovery comes from the bar and the guidance,** not from every page listing everything: the bottom bar names the features, and the in-app guidance points a new person to the next one to try.
- **The bar (founder, 20 Oct): Journal · Podcasts · Goals · You.**
  - **Journal:** write or talk, and it replies; journal and chat are one page. **The daily brief is the day's episode: a card at the top you press play on; it briefs you, and keeps playing when you close the app** (founder, 20 Oct).
  - **Podcasts:** listen; why each part is there; past episodes.
  - **Goals:** the brain's view of your goals; said vs did.
  - **You = search + your brain, as a map (founder, 20 Oct).** The page is a visualization of the brain as **nodes and edges**: people, places, projects, goals and themes as nodes, **sized by how much they show up** in your life; edges are the facts linking them, each from your own words. A search field sits on it: searching **highlights and zooms to** the matching part of the map, with the written answer and its sources below. Tap a node for its receipts: the quotes behind it, how sure the brain is, "that's not me" / "still true". Patterns show as clusters growing or fading; "is this the same person?" and "what it's wondering" appear as nodes waiting for your answer. Saved links are nodes too, tied to the goals they bear on. Profile and settings sit behind your picture at the top.
  - To work out in steps 3–5: how the map stays readable as it grows (zoom levels, only the strongest nodes at first), how it reads to someone with a week of data versus a year, the empty state on day one, the 36 answers' place on the map (as regions?), performance on older phones, and VoiceOver (a list view of the same data).
  - Prerequisite (from the earlier constellation idea): people must be matched cleanly, or the map shows the same person twice. The graph is read-only from what the brain already stores; no new storage.

**The north star (founder, 20 Oct, in their words, lightly edited):** *"I tap the app. I see something pretty. I sign in. I start talking to the app, and we have a good conversation: me answering the questions that teach it about me the fastest. From there, the privacy disclosure and the integration page, both built around strong displays of the purpose of the page, continuing to ask the questions. Once we feel we are ready, we show the tease of the podcast and hit them with the paywall. Then we take them to the homepage, and they can see their briefs, search their mind, and everything else on the app."* Every onboarding decision is checked against this.

**Onboarding, in this order** (screens ON-1 to ON-13 in the proposal):
1. **Something pretty** (ON-1): a crafted moving moment and one line; no questions, no choices.
2. **Sign in** (ON-2).
3. **The conversation starts** (ON-3): the app speaks first, telling the mission, and asks "talk or type?".
4. **Questions that teach it the most, fastest** (ON-4): one continuous conversation; each next question is the one that would teach the most given what's been said (from the question store); no fixed count.
5. **Privacy** (ON-5) and **integrations** (ON-6, ON-7), each a strong display of its one purpose, **with the conversation carrying on through them**: the voice ties each page to what you said, and asks about what a connection reveals.
6. **More questions until it's ready** (ON-8, ON-9, ON-10): goals and aspirations; how straight to be; whether you want a morning brief. All asked as conversation turns. The first episode is made while you keep talking, so there's no dead wait. It moves on **when it's ready** (the readiness check), not after a set number.
7. **Tease the podcast** (ON-11): the first episode starts playing.
8. **The paywall** (ON-12): it rises out of the podcast; **scrollable**, with every benefit laid out.
9. **The homepage** (ON-13): Journal, with the brief card; one-time guidance pointing to the brief, searching your mind in You, Podcasts and Goals. Nothing between the paywall and home.

**To test: how parasocial it should be (founder, 20 Oct).** How much the app should feel like a someone rather than a something is an open question, and it's tested, not assumed. The dial:
- **Tool-like:** neutral voice, no name, "Retrospect found…", no small talk, no remembering-out-loud.
- **In between (the default to start):** speaks in the first person ("I noticed…"), warm but plain, refers back to what you said ("you mentioned your sister last week"), no claims of feelings.
- **Companion-like:** a named persona, more warmth and personality, more callbacks, asks how you are.

Held at every setting: it never pretends to be human or to have feelings; it never uses guilt or loneliness to bring people back; it's honest about being an AI and about what it's guessing.

Where it shows: the voice and words of the onboarding conversation (ON-3 to ON-10), Journal replies, brief and episode intros, and notifications.

How it's tested: the three variants in onboarding, randomly assigned. Measured on:
- onboarding completion;
- paywall conversion;
- day-7 and day-30 return;
- entries per week;
- "it gets me" (one in-app question at day 7);
- any "this is weird / too much" feedback, read as a stop signal.

Then pick one setting, or let people choose in Settings (ST-6 already sets how straight it is; this would sit beside it).

**Voice onboarding: a conversation, not a form (founder, 20 Oct).** The person can answer every onboarding question by talking, for as long as they like, and the app **talks back**: it asks each question aloud, reacts to what was said, and follows up, so onboarding is a conversation they have with the app. Requirements:
- **Voice in:** speak any answer (typing stays available); live transcription on screen.
- **Voice out:** the app speaks its questions and replies in a natural voice from **ElevenLabs** (already proxied through the backend, NPRdoinglaundry `e1f16b9`), so no keys sit in the app.
- **Haptics** mark the turns: when it starts listening, when it's heard you, when it's speaking.
- **On screen, for now:** the words as text, as today. **Later:** something more visual (a living shape or waveform that reacts to both voices); designed in step 6, not before.
- **Interruptible:** the person can cut in, skip ahead, or switch to typing at any moment; silence never fails a step.
- **The same conversation continues in the app:** the app's conversation page uses the same voice, so onboarding is the first conversation, not a separate mode.
- **Cost and latency** are measured in step 3 (voice per onboarding, time to first spoken word) and recorded in [cost-per-user.md](./cost-per-user.md).

This applies to steps 2–6: it's an opportunity in step 2, a flow in step 3, built in the mid-fi in step 4, reviewed in step 5, and given its visual treatment in step 6.

**The mission, told by voice in onboarding (founder, 20 Oct).** Onboarding opens by *telling* the person what Retrospect is for, in the app's own voice, before it asks anything: why it exists, what it will do with what they share, and what they get back. To think through deeply in step 3, not just script:
- **Where it sits:** at the very start (before the first question, so trust comes before asking), with short callbacks at the moments that need it: before privacy ("here's why I ask"), before integrations ("here's what these let me understand"), and before the paywall ("here's what you've just heard is for").
- **What it says:** the mission in the person's terms, not the product's: a brain that comes to know you and gives it back as something worth listening to. Short (under 30 s for the opening), spoken warmly, never a pitch; every claim true today (no promise the product can't keep, unlike the current "with me, anything is possible").
- **How it's carried:** the ElevenLabs voice, the words appearing on screen as they're spoken, haptics on the key line; skippable and replayable; works muted (text alone carries it).
- **How we judge it:** does a new person, after the opening, know what this is for and want to answer the first question? Tested by listening, in step 5.

**Inside the app, guidance.** Once they're in, the app shows them how to go further, so they always know what's going on and what to try next.

**The goal of every design choice:** the least taken from the person and the fewest questions asked, for the most output and value given back.

**The goals the structure must serve:** understand the person; understand their goals; give them content that makes their life better. And get the specifics right: how journals are stored, how you message the app, the share sheet, search and what an insight looks like when you search (and how you deep-dive for more), settings, and everything else.

---

## The order of work

Each step finishes, is checked, and is shown to the founder before the next starts. **Tokens are applied only after the structure has passed its review (step 5).**

| # | Step | What it produces | Done when | Founder |
|---|---|---|---|---|
| 1 | Deep audit of the current app | every problem, on a running build | every screen, control, state, size and gesture checked | reads it |
| 2 | Opportunity audit and spec | every place new functionality can enter, with lo-fi mockups of every screen | every capability has a home and a sketch | yes/no per opportunity |
| 3 | Best solution for every screen and flow | the new structure, written screen by screen | every problem closed, every opportunity used, least take and most value | approves the structure |
| 4 | The new screen set, mid-fi | every screen and flow of the new app, at mid fidelity | it reflects every change and every new capability | looks through it |
| 5 | Structure review | a written pass asking "is this the best structure, and why or why not" for every screen | each screen passes the goals and fits the interaction style | agrees |
| 6 | Tokens, then components | a sophisticated token set with Lime's breadth, applied page by page and component by component | spacing, hierarchy, interaction and flow are all handled | does the high-craft polish |

---

## Step 1: Deep audit of the current app (in progress)

**Purpose:** find every problem: where the app is incoherent or hard to use, interactions that break, odd pixels, confusing onboarding screens, sections that don't make sense, frame rates that drop, gestures that don't work.

**How:** a debug build on the simulator, pointed at a local stand-in server that serves a labelled sample week and can be switched to empty, error and slow modes. Nothing reaches Retrospect's servers; no spend.

**Checklist, per screen (all 32):**
- every control tapped; every gesture tried (swipe back, swipe down, long-press, scroll, drag);
- every state: first time, filled, empty, loading, error, slow, offline;
- closing the app mid-step and reopening; going back from every step;
- sizes: iPhone SE and 17 Pro Max; the largest text size; dark mode;
- pixels against the tokens: spacing, type, alignment, contrast, overlap, safe areas;
- frame rate: what redraws every frame or blocks the main thread (from code), and visible stutter (on a phone recording);
- clarity: before reading a word, can you tell what this is for and what to do next?

**Output:** [app-audit-deep.md](./app-audit-deep.md), merged into the ranked list in [app-audit.md](./app-audit.md) and onto the board.

**Limits:** real frame rate, haptics, the recorder, Health, Screen Time, notifications and widgets need a phone; one screen recording covers them.

---

## Step 2: Opportunity audit and spec

**Purpose:** list every opportunity to bring new functionality into the product, within the simple paradigm (bottom navigation bar, one feature per page).

**Inputs:** everything the brain can now do (from the goal spec and [ios-v2-opportunities.md](./ios-v2-opportunities.md)):
- the conversation (chat with it; replies may be silent);
- search across the whole mind, with sources and a written answer, and deep-dives;
- the daily brief and the weekly episode, each saying why each item is there;
- what it knows about you, with how sure it is and why; corrections anywhere;
- goals as the brain sees them (active, expired, merged; said vs did);
- patterns; people ("same person?"); hypotheses ("what it's wondering");
- how bold it is with you; what it has learned about how you like things;
- saved links with your reason (share sheet), and transcripts for videos;
- actions it prepares for your approval;
- sources: what each one read, when, and what it's for; the ambient switch; privacy and deletion.

**For each opportunity, the spec records:**
- what it is, in one line;
- where it can live (which tab, which screen, which moment in onboarding);
- **which page owns it:** a page of its own in the bar, or a part of another feature's page (and why it belongs there);
- what the person gives and what they get back;
- the server route behind it (built, or still to build);
- the audit problems it also fixes;
- **a very lo-fi mockup** of every screen it touches: boxes and labels only, enough to judge placement and flow.

**Note on the stage-2 draft:** [ios-v2-opportunities.md](./ios-v2-opportunities.md) puts several features on Home (capture, today's brief, talking to it, things waiting on you) and many on You. Under one feature per page, that draft is reworked here: each of those is placed on the page that owns it.

**Output:** `ios-refresh-opportunities.md` (replacing the stage-2 draft) plus the lo-fi mockups on the board, one per screen, side by side with today's screen.

**Done when:** every capability has at least one home and a sketch, and the founder has said yes or no to each.

---

## Step 3: The best solution for every screen, pixel and flow

**Purpose:** given every problem (step 1) and every opportunity (step 2), decide the best solution for each screen and flow. The test: **the least taken from the person, the fewest questions, the most value back.**

**It works to the founder's shape** (above): onboarding as questions → privacy → integrations → more questions → podcast tease → scrollable paywall with every benefit → into the app → play around, with guidance inside the app.

**For each screen it writes:**
- its job in one sentence, and what the person should feel;
- what's on it, in order of importance (the hierarchy);
- every action, and what each one does (exact labels);
- every state: first time, filled, empty, loading, error, offline;
- the one feature it shows off, and how it shows it off fully;
- how a person gets to it (which tab, and from where inside the app);
- the guidance it gives a new person (what to try next);
- the problems it closes (by audit number) and the opportunities it uses;
- what it asks of the person, and why that's the least it can ask.

**For each flow:** onboarding end to end; a normal day; the weekly episode; searching and deep-diving into an insight; correcting something; sharing a link in from another app; messaging the app; connecting or fixing a source; privacy and deletion; subscribing, restoring and lapsing; every failure path.

**Output:** `ios-refresh-structure.md`. The founder approves the structure before mid-fi starts.

---

## Step 4: The new screen set, mid-fi

**Purpose:** a mid-fidelity version of the new iOS app: every screen and every flow, reflecting every change and every new capability from steps 2 and 3.

**Recommendation (founder to confirm):** build the mid-fi as **real SwiftUI screens in the new app project**, running on the simulator against the stand-in server's sample data, so the founder can tap through every flow on a phone-sized screen. Mid-fi means real layout, real content and real interactions, in plain greys, without the final visual craft. The alternative is clickable HTML screens on the board: faster to make, but they don't carry over into the app.

**Includes:**
- onboarding with the scrollable podcast-and-benefits paywall;
- the four-tab app (Journal, Podcasts, Goals, You; settings behind your picture), each page dedicated to one feature;
- in-app guidance for a new person;
- every state from step 3 (empty, error, loading, offline), not only the happy path.

**Output:** the mid-fi app, plus screenshots of every screen and state on the board.

---

## Step 5: Structure review (before any tokens)

**Purpose:** a deliberate second look. For every screen and flow, ask: **is this the best structure, and why or why not?** Judged against:
- **Understanding the person:** does this screen help the brain learn, or show what it has learned?
- **Understanding their goals:** are goals visible, honest (said vs did), and easy to correct?
- **Content that makes life better:** is what it gives back worth the person's time?
- **The specifics:**
  - journals: how they're stored, and that nothing is ever lost;
  - messaging the app: how a conversation feels, and where it lives;
  - the share sheet: saving from anywhere, with a reason;
  - search: what an insight looks like in a result, how you deep-dive for more, and how sources are shown;
  - settings: what's there, and that every setting is real;
  - everything else in the goal spec.
- **The interaction style:** bottom bar; one feature per page, shown off fully; nothing important more than one tap from the bar; least take, most value.

**Output:** a review section in `ios-refresh-structure.md`, every screen marked keep, change or rethink, with the reason; changes made in the mid-fi before step 6.

---

## Step 6: Tokens, then components

**Starts only when step 5 is done.**

**6a. A sophisticated token set.** Inspired by the breadth of the Lime design system the founder shared: tokens that span as many visual details as possible, not only colour and type. Built on the decisions already made ([design-system-plan.md](../design/design-system-plan.md)):
- Hedvig serif used with restraint; mono for all labels;
- one accent, a sky blue; grain and rim only for special moments;
- light and dark together, light first; iOS only;
- tokens lead, named by purpose.

Coverage, at least: colour (surfaces, text, borders, states, the accent and its washes) · type scale and roles · spacing scale and layout rhythm · radii · borders and hairlines · elevation and shadow · blur and materials · grain and rim · opacity · iconography sizes · motion (durations, curves, the 1.22 s reveal) · haptics · touch targets · focus and pressed states · Dynamic Type steps · safe areas and edge padding. Starting point: the v1 set ([design-system/tokens](../../design-system/tokens/README.md), 272 tokens).

**Colour direction: beige + blue, with the beige calibrated down (founder, 20 Oct).** The design system stays two colours, a beige ground and the sky-blue accent, but the beige is turned down a little and made consistent. Today's paper and cream values drift between hues 68° and 106° and reach a chroma of 0.020 (OKLCH) on the cream ring, which reads yellow next to the blue. In step 6: one beige hue for all neutrals, chroma held low and even (surfaces ≈ 0.003–0.006, borders and rings ≈ 0.008–0.010), stepped in lightness only, and checked side by side with the sky blue in light and dark. This replaces the warm-paper values in v1 of the tokens.

**Making the tokens easy to edit (founder, 20 Oct).** The goal: you change one value in one place, and Paper and the app both follow. Nothing downstream is edited by hand. What's in the way today, and the change:

| Today | Why it's hard to edit | Change |
|---|---|---|
| The app has **no tokens at all**: 276 hand-typed `Color(red:…)`, 680 `.system(size:)`, 896 padding numbers and 337 corner radii, across the Swift; no asset-catalog colours | Changing the beige means finding hundreds of call sites; light and dark are hard-coded separately or not at all | Generate Swift from `tokens.json`: an asset-catalog colourset per semantic colour (Any + Dark in one file, so dark is automatic), and `Font`, `Spacing`, `Radius`, `Elevation`, `Motion`, `Haptic` enums. Screens use only semantic names (`.textPrimary`, `Spacing.screenMargin`); a lint fails the build on a raw number or colour in a view |
| The 19 beige steps are **hand-picked hex**: hues drift 61°–90° (OKLCH), chroma 0–0.020, three are pure grey (600, 900, 950), and some are near-duplicates (200/250 differ by 0.001 in lightness; 500/550/600 by 0.008) | Calibrating the beige means re-picking 19 colours by eye, and they still won't sit together | **Generate the neutrals from three numbers:** one hue, one chroma curve, a lightness ramp. Editing the beige = changing the hue or chroma once; every step follows. Drop the near-duplicates, so roughly 12 steps instead of 19. Same for night (dark) |
| Glow, pressed and lit states are **separate hand-typed hex** (e.g. `#5CC2FF`, `#1F8BCC`) | Changing the blue leaves its pressed and lit versions behind | Derive states from the base: lit = +lightness, pressed = −lightness, ring/halo = base at an opacity token. One blue to edit |
| **Light and dark live in different places**: `$value` vs `$extensions.retrospect.dark`; in Paper as a parallel `--color-dark-*` set | Easy to change one and forget the other | Keep both in one entry in `tokens.json` (as now); every output is generated from it: Swift colourset (Any/Dark), Paper light + `dark-` sets. The validator already fails a colour with no dark value |
| **Shadows, type styles, motion and haptics** have no Paper type: shadows are split into parts, motion and haptics are a reference artboard | The parts can drift apart; the artboard can go stale | Generated too: a script writes the split shadow tokens and redraws the reference artboards from `tokens.json`. In Swift they're whole styles (`.elevation(.card)`, `.type(.labelButton)`) |
| The display font has **two names**: the iOS PostScript name `HedvigLettersSerif-24ptRegular` vs the family "Hedvig Letters Serif" in Paper; units in `pt` vs `px` | Copying a value across breaks it silently | Store family, PostScript name and unit once; each output picks the one it needs |
| Many values are still marked **"to set"** (the dark canvas, the dots, the signature grain) | It's not clear which values are decided | Keep the `source` field (paywall · lime · to set · **founder**); a value becomes "founder" when you approve it, and the token pages in Paper show which are which |

**Afterwards, every token is named by its purpose (founder, 20 Oct).** Once the clean-up above is done, the names say what a token is *for*, never what it looks like or where it sits on a scale:

| Today's name | Problem | Afterwards |
|---|---|---|
| `paper.300`, `sky.500`, `night.750` (palette steps) | Says nothing about use; people pick steps by eye | Palette steps become private inputs to the generator. Only purpose names are editable or usable: `background.canvas`, `text.label`, `accent.default`, `border.secondaryRing` |
| `space.1`–`space.16` | A number, not a job | `space.screenMargin`, `space.betweenSections`, `space.betweenRows`, `space.insideControl`, `space.labelToValue` (the scale stays underneath) |
| `font.size.xs`–`4xl`, `radius.small`/`default` | Sizes, not roles | `type.label.button`, `type.display.hero`; `radius.control`, `radius.card`, `radius.sheet`, `radius.field` |
| `size.*` filed under spacing in Paper (`--spacing-size-touch-target`); `--container-focus-offset` filed as a container | Wrong group, so hard to find | Their own groups: `size.touchTarget`, `size.icon.default`; `focus.offset` |
| `--spacing-shadow-card-1-blur`, `--color-shadow-card-1` | Mechanics of a shadow in pieces | One purpose per elevation: `elevation.card`, `elevation.menu`, `elevation.primaryAction`; the pieces are generated beneath it |
| `glow.primary.gradientTopLit` | Describes the rendering | `action.primary.rest / focused / pressed` (the gradient and lit values derived inside) |
| `motion.duration.base`, `motion.curve.standard` | Generic | `motion.arrive`, `motion.leave`, `motion.sheet`, `motion.press`, `motion.reveal`; `haptic.choose`, `haptic.done`, `haptic.firstInsight`, `haptic.attention` |

The validator already rejects names that describe a look; afterwards it also rejects palette names used outside the generator. Paper and Swift get the same purpose names, so a token reads the same in both.

**How an edit flows:** change `tokens.json` (or, later, the token in Paper, pulled back with one command) → `node design-system/tokens/validate.mjs` checks names, references, dark values and contrast → the generator writes Swift, Paper tokens and the token pages → the app and Paper both update. One command, run in a PR like any other change.

**The design system as built (20 Oct).** It lives in `design-system/`: `tokens/tokens.json` (483 tokens, validated), `icons/` (28 SVGs on one grid), `components/` (a spec per component, `craft.md` rules, `audit.md`), `principles/` (the founder's 24 keys and topic docs: surfaces, gradients, icons, motion and transitions, accessibility, type, organisation). In Paper (file "Retrospect"): 00 start here · 01 foundations (f1–f7, f3b) · 02 components (c1–c4). Open decisions: the lit label (contrast) and the display face (Exposure −20 or Hedvig).

**6b. Components, page by page.** Apply the tokens systematically, component by component, to the mid-fi app, so that **spacing, hierarchy, interaction and flow are all addressed**. The components should look good and follow the design system closely enough that **all that's left for the founder is the high-craft polish pass.**

**Output:** the token set (validated), the component inventory with every state in light and dark, and the mid-fi app re-skinned with them.

**Then the founder** does the high-craft pass.

---

## Rules that hold at every step

- Every claim about the current app is backed by a screenshot, a server log line or a code line.
- Every claim about a person rests on their own data. Predictions and inferences are welcome, and they're shown as what they are: a guess comes with how sure it is and what it rests on, and a weak guess is asked as a question, never stated. What's banned is content not grounded in their data at all (canned lines, made-up episodes). Demo content lives only in the demo account.
- No developer tools in the shipped app.
- The server owns what the brain knows; the app sends intents and never overwrites.
- Nothing written is ever lost, and you can always see that it arrived.
- Every wait names what it's doing; every failure says what happened and what's next.
- Each step ends with something the founder can look at (the board), and waits for their yes before the next.
