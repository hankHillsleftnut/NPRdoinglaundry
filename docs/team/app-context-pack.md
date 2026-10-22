# App context pack: everything both app engineers need

For the **Platform engineer** and the **views engineer**. This collects what the founder and the integrator decided and learned on 21 Oct that is scattered across chat, plans and review findings. Read it after `first-ship.md`, `README.md` and `context.md`, and before every batch. When it disagrees with an older doc, this file wins. When it disagrees with a newer founder decision, the integrator updates it.

## 1. Where everything is

| What | Where |
|---|---|
| Beta 1 scope (overrides every plan) | `docs/team/first-ship.md` |
| Team rules, report format | `docs/team/README.md` §7, §8 |
| Product, decisions, hard rules | `docs/team/context.md` |
| How mistakes become checks | `docs/team/trust-ladder.md` |
| Testing standard | `docs/team/testing.md` |
| What reviewers caught (check before every first push) | `/private/tmp/claude-501/-Users-shauryanarang-Projects-retrospect-main/fa81fd21-82ce-4e36-8766-e74f842ffa6e/scratchpad/first-push-checklist.md` |
| Journal cards (Beta 1) | `docs/team/ui-engineer.md` + `docs/team/ui/*.md` (views); `docs/team/app-plumbing-engineer.md` + `docs/team/plumbing/*.md` (Platform) |
| Every later area, to PR level | `docs/team/flows/<area>/` for first-run, podcasts, goals, you, settings, outside |
| Cross-plan fixes: component owners, renumbered ids, migration numbers, duplicates | `docs/team/plans-consistency.md` (**read §1 and §4 before building any shared component**) |
| Contracts and fixtures | `docs/team/contracts/` (00 platform, 01 first run, 02 journal, 03–07) and `contracts/fixtures/` |
| Founder's open questions (work goes ahead on the lean) | `docs/team/founder-questions.md` |
| Design system rules | `design-system/principles/` (README, screen-rules, surfaces, type, icons, gradients, accessibility, motion-system, motion-and-transitions, organisation), `design-system/components/craft.md` and `README.md`, `design-system/tokens/README.md` |
| Behaviour notes from the founder's Paper comments | `docs/design/ios-build-notes.md` (**the founder writes iOS behaviour into comments; these are requirements**) |
| Component and screen handoff (anatomy, states, tokens, sizes) | `docs/design/ios-handoff.md` |
| Motion | `design-system/principles/motion-system.md`, `docs/design/motion/motion-moments.md`, `docs/design/microinteractions-plan.md`, `docs/design/progressive-blur.md` |
| Field-level references | `docs/team/reference/` (app, design, Paper inventory with node ids, backend, agent API) |
| The invite boards (round 1 and the round 2 ticket tear) | `docs/design/reference/invite/` (exports; Paper is the source) |
| The Flighty ticket-tear reference recording and dense frames (the interaction the founder asked for) | `/private/tmp/claude-501/-Users-shauryanarang-Projects-retrospect-main/fa81fd21-82ce-4e36-8766-e74f842ffa6e/scratchpad/flighty.mov`, `…/scratchpad/flighty-dense/` (third-party, for reference only, never committed) |

## 2. The founder's decisions that touch the app (21 Oct, newest last)

- **Beta 1** is an invite-only TestFlight: invite link → Apple sign-in → the ticket tear and "you're in" (M14) → the **new journal**. Podcasts, goals, you and settings stay on today's screens.
- **The journal v1** is shaped like messaging. You send thoughts, entries and voice notes; Retro answers with a short **canned acknowledgement**. There's no AI reply and no streaming (that's v2).
- **Briefs are audio**, and **off until the person opts in**, at a time they choose.
- **Invites:**
  - You get in only through a link. Each member gets **three single-use links**.
  - The link domain is the free server address for now: `https://retrospect-api.onrender.com/i/<code>`.
  - The code applies itself after sign-in, but **nothing is spent until the ticket is torn**: check after sign-in, redeem at the tear (PL1.7d in the first-run plan).
- **"You're in" (M14) must feel like a premium gift:** "you've just been given a gift, don't waste it."
  - The ticket prints out of a slot with a **continuous rumble haptic**. That's a Core Haptics player behind `RHaptic` (FR0.1, integrator).
  - The finger lands on the left notch and you **swipe left to right to tear it like a movie ticket** (Flighty).
  - The stub peels and curls, detaches with a 12–15° tilt, and **stays as a keepsake**.
  - The notches are real cutouts, and the shadow follows the cut.
  - Motion follows `motion-system.md`, **never linear**.
  - The full cards (PI1, PI2.1–4, C41.x, C42, C43) are in `flows/first-run/` and were checked value by value against Paper.
- **Every notification is custom-written** by the brain for that person and moment, even the brief's. The push carries only ids; a Notification Service Extension fetches the words. (Outside plan, phase 2; not Beta 1.)
- **Prices:** $19.99 a month; $199.99 a year with the first month free. Show **Apple's localized price**, never typed prices. Paper's paywall still shows old prices; ignore them. (Not Beta 1.)
- **Sign-in:** Apple only in Beta 1; Google later. **Sign out everywhere** is v2; Beta 1 has sign out of this device.
- **Workaround comments are banned** (TODO, FIXME, HACK, "workaround", commented-out code) unless they carry a findings-log id.
- **The founder doesn't want to see the simulator.** Never open the Simulator window. Verify headlessly and show screenshots.

## 3. Design rules that decide most questions (the founder's, apply without asking)

- **Paper's approved node wins** over any doc. Read values with `get_jsx` and `get_computed_styles`, never from screenshots. Note every difference in your PR.
- **Tokens only.** No raw colours, sizes, shadows or springs in components. A missing token is a report, never a literal.
- **Every corner is a squircle** through `RShape` (`RShape.rect`, `RShape.pill`). CI fails anything else.
- **Field hints** use `text.placeholder`.
- **One lit object per screen.** On the journal while typing, send is lit and the brief's play button gives up its glow.
- **Lowercase labels.**
- **Guesses never look like facts:** always asked, with the guess tag, never a fact's look.
- **No invented data in empty states**, and no invented personal content in examples.
- **Small screens adapt, never just shrink:** at SE size, use compact parts, drop secondary lines and tighten the rhythm.
- **Key states only:** draw and build the important states and their flows. iOS handles accessibility variants such as Dynamic Type and Increase Contrast through the system.
- **Components are high craft:** every state, exact Paper values, motion, haptics, accessibility, and checked on the simulator.
- **Haptics:** press haptics only on lit and destructive buttons (the haptic token's own rule).
- **When the design system answers a question, apply it; don't ask.** Ask the integrator only product questions.

## 4. What reviewers caught in our components (so it doesn't happen again)

From the #58 review of the merged design-system components. Each one now has a fix, and most now have a check:
- A toast that never left for VoiceOver users (it waited on the global VoiceOver flag). Pause while VoiceOver **focus** is on it, with a ceiling.
- A VoiceOver action that did nothing ("undo" with no undo; a row's default action with no destination). Add actions only when they act.
- A switch whose VoiceOver toggle skipped the haptic and the failed-save detection. **VoiceOver paths take the same code path as touch.**
- A drag gesture that stole the page's scroll and could flip a switch. Use `simultaneousGesture` and ignore mostly-vertical drags.
- A composer that raised the keyboard after every voice turn. **No focus the person didn't ask for.**
- An infinite long-press that swallowed a child button's tap.
- Corners drawn outside `RShape`, and raw shadow numbers in components.

## 5. Platform facts the engineers must not rediscover

- **Audio** (podcasts plan, PLP.1a/b, now Beta 1):
  - The app already has players. `StreamingPodcastPlayback` (in `Views/Components/PodcastPlayer.swift`) is the sound base; extract it behind `Media.Player`.
  - `DarkAudioManager` mixes with other audio (`.mixWithOthers`), so the app never becomes Now Playing. It has no lock-screen controls, stays "playing" after a call, and logs file paths.
  - `TTS.swift` and `AudioSessionManager` grab the session at launch.
  - Four old player views are dead code.
  - The rule: **one engine only**, never mix, set the session before each play, pause for calls and when headphones come out, and recover from a media-services reset.
- **Local store: GRDB, not SwiftData.** The outbox writes the entity row and the outbox row in one transaction. `Idempotency-Key` = the entry id. The background task id is `com.shauryanarang.Retrospect.outbox.drain`. Old open PR #6 ("durable note capture") overlaps the outbox; read it for lessons, don't merge it.
- **Keychain:** use `AfterFirstUnlockThisDeviceOnly` (today the token is unreadable while the phone is locked), a reinstall sentinel and a "signed in before" flag.
- **Sessions:** a 15-minute access token and a 60-day rotating refresh token with a 30-second grace window. Refresh is single-flight. A 401 never signs you out by itself.
- **Every request** carries `X-Time-Zone` (IANA) and `X-App-Version`. JSON is camelCase, with explicit `CodingKeys` only where names differ, never `convertFromSnakeCase`. Enums have an `unknown` case.
- **Environments:** three. `NSAllowsLocalNetworking` is in DEBUG only. Local staging runs on the Mac against the `retrospect-staging` Supabase project.
- **The design lab** opens any page with `-DesignLabPage <page>` (`motion`, `foundation`, `parts`, `artwork`, `toast`) and `-DesignLabToast`. Extend it for proof screenshots until T02, the screen launcher, lands.
- **Simulators:** the views engineer uses `agent-a 17 Pro` (3E962F9F-E537-4C97-9F2E-134B3FD8B992); the Platform engineer uses `agent-b 17 Pro` (6F5A82DF-2979-4DE6-B9E2-C968FE1D51DA). Never create or delete simulators or runtimes.
- **Builds:** only one iOS build at a time on this Mac, shared by both of you and CI's iOS job. Wait while another `xcodebuild … derivedDataPath` is running. Keep `df -h /` above 15 GB, and delete your derived data after each byte.
- **CI:** two runners on the Mac. The quick checks (lint, format, tokens, secrets, backend) run on either; the iOS build runs on the first only. CodeRabbit is rate-limited, so don't wait on it.

## 6. The seam between you (who owns what)

| | Views engineer | Platform engineer |
|---|---|---|
| Folders | `DesignSystemV2/Components`, `Parts`, `Features/<flow>` views, sample data | `Platform/` (Backend, Session, Store, Push, Purchases, Routing, Media, Analytics), live data, tests, entitlements |
| The contract between you | `Platform/Flows/Journal.swift` and `Playback.swift`: protocols and models (written by the integrator). Views build on sample data in these shapes, and Platform implements the live side | |
| Never touch | `Platform/`, backend | views, components |
| Shared files (integrator only) | tokens, `Generated/`, the app shell, `.github/`, contracts | |

If one of you needs the other's file, say so in your report; the integrator routes it.
