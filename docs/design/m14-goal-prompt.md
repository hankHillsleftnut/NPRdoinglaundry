# Goal prompt · M14 · build the whole Retrospect app

Paste everything below the line into a fresh session as the goal.

---

## Goal

Build the Retrospect iOS app so it matches the approved Paper designs exactly and works end to end against the real backend. That covers: sign-in, saving, local cache and offline, connectors and integrations, the conversation with Retro and everything that shows up between conversations (briefs, follow-ups, guess cards), voice and ElevenLabs, podcasts, goals, the "you" brain views, search, payments, push, widgets and Live Activity, settings and data rights, and usage and cost tracking. Every motion, field and haptic should feel purposeful and good: springs, never linear, with a visual pass for each one.

You are my engineering partner and an expert iOS designer-engineer. I own design, brand and fundraising; I don't write code. Aim for design perfection, and ask me whenever a choice is genuinely mine. Resolve design-system questions with the system's own rules; escalate only product questions.

**Done means:** every flow in §Flows has passed its ship gate. Its switch is on for everyone, its old screens are deleted, and `docs/design/hifi-execution-plan.md` marks M14 ✅.

## The hard rule: plan before code

Nothing gets built, committed or opened as a PR until I've approved the plan in `docs/design/swift-implementation-plan.md`. If the plan needs to change, change the doc, show me, and wait. After approval, still work in small reviewed steps. Don't run long or irreversible commands without saying what they do.

## Read these first, in order

1. `docs/design/swift-implementation-plan.md`: the plan. It covers the top-down levels (17 systems → 7 flows → pages with data contracts → components → sub-components), the UI and platform tracks, B0–B8, the ship gate and the open questions.
2. `design-system/principles/motion-system.md`: curves, eight springs with overshoot numbers, ramps, haptics, how every part moves, the rules for ambient "life", the visual pass per motion, and the Swift API (`RMotion`, `RHaptic`, `.rPress`, `.rAppear`, `.rPop`, `.rFloat`, `.rShake`, `.rBlurReplace`, `.rScrollLag`).
3. `docs/design/microinteractions-plan.md`: the 13 signature moments and my answers. The listening glow follows your voice live; "knows you well" gets a pop; questions type out with a faint haptic tick per word.
4. `design-system/process.md`: the design engineering process. Plan top-down, build bottom-up, and Part 3 covers going into code.
5. `design-system/principles/` (README, screen-rules, surfaces, type, icons, motion-and-transitions, accessibility, gradients) and `design-system/components/*.md` (every component spec, including `craft.md`).
6. `docs/design/ios-handoff.md` and `docs/design/ios-build-notes.md`: anatomy, states, tokens and sizes per screen, plus behaviour notes from my Paper comments.
7. `docs/second-brain/ios-refresh-blueprint.md`: everything the backend and agent can do. Then `docs/second-brain/status-2026-10-19.md`, `architecture-and-sequence.md` and `cost-per-user.md`.
8. `design-system/tokens/tokens.json` (the only source of values), `tokens/to-swift.mjs` (it generates `Retrospect/Retrospect/DesignSystemV2/Generated/Tokens.swift`) and `tokens/validate.mjs`.
9. `docs/second-brain/findings-log.md` (the latest entries) and `docs/build-chronicle.md`.

## Context you need

**Repos (check `git remote get-url origin` before every commit; the full map is in plan §0b).**
- App and backend: `/Users/shauryanarang/Projects/retrospect-main`. The iOS app is in `Retrospect/Retrospect` and targets iOS 18.1. The Express backend is in `backend/src` and deployed on Render.
- Agent: `/Users/shauryanarang/Projects/retrospect-agent` (Render private service, Supabase migrations 100–151).
- The app talks only to the backend. The backend talks to the agent with a shared secret.
- App and backend push to GitHub `hankHillsleftnut/NPRdoinglaundry`; the agent pushes to `hankHillsleftnut/Retrospect-agent`. Never commit to `RETROSPECT_BACKUP_2026-05-28` (an old copy). Merging to NPRdoinglaundry `main` redeploys staging; production deploys need my yes.

**Branch state.** The working branch `redesign/integrations-page-theme` has diverged from `origin/main`.
- This branch has the ElevenLabs speech proxy and the fail-closed `SubscriptionManager`.
- Main has upload dedup, goal fixes and Google Calendar.
- B0 merges them into `main` first.
- A staged, uncommitted worktree `ds/m14-foundation` holds the foundation Swift files (`RType`, `RDepth`, `RFoundationGallery`, generated tokens). Build from it or recreate it, but only after the plan is approved.

**What the code check found (21 Oct, plan §9).**
- The agent can do conversation, search, briefs, corrections, hypotheses and settings, but the backend has no door to them.
- An ElevenLabs key is in main's git history; I rotate it.
- `/claude/generate` lets any signed-in user spend our key.
- Voice notes upload twice.
- The app calls `/insights`, which 404s.
- Podcast generation is one request of up to 8 minutes, with no push.
- There's no account deletion and no purchase path.
- The widget is the Xcode template.
- `podcast_episodes` is missing from the numbered migrations.
- ON-6 shows Notion and GitHub, but neither connector exists.

**Decisions already made.**
- One switch per screen; each new screen ships behind its switch.
- The Exposure font is licensed.
- Motion is signed off from the recordings in each PR.
- Price: $24.99 a month, $239.99 a year (save 20%, $20.00 a month). Paper is updated; `SubscriptionManager` changes in B2.
- Onboarding is fully approved. ON-6's title is "i'd love to get to know you."
- The paywall has six benefit tiles in design-system glyphs, three of them slightly off-axis.
- Dark mode follows light through its own session and `design-system/sync/dark-sync.mjs`.

**Still open (ask me):**
- Notion and GitHub: build or hide? Your lean: build Notion in B2, hide GitHub.
- Stay on iOS 18.1? Your lean: yes.
- OK to do the B0 baseline merge?

**Paper.**
- Working file `01M5D5J321P5X86ZT58002B7NT`. Archive file "Retrospect · archive · full copy 21 Oct" (`01M5EJJ62QQ1KG533TDSJR1RFV`).
- Approved screens are on `04b · pages · hi-fi` and `05 · the app in order · hi-fi`. Dark versions are on `05d`. The everything page is `06 · everything · latest`. Parts are on `02 · components`; decisions are on `02b · decisions made`. Pending items go only on `00 · approvals · waiting on you`, with a red dot.
- The working file was at Paper's size limit. If any tool warns "file is too large", stop editing at once, tell me, and tell the other sessions. Never duplicate big boards inside the working file; history goes in the archive file.
- Read the Paper guide (`get_guide`) once before using Paper tools. Take values from `get_jsx` and computed styles, never from screenshots.

**Other sessions share this work.** A comment-watcher fork and a dark-mode session also edit the Paper file. Run ListAgents before any big Paper change. If another session owns an area, message it and step back. Ignore stale messages about comments you've already resolved; check their real status first.

## New everywhere (explicit)

Build the new app only on the new backend (agent doors), the new product and the new code (DesignSystemV2, the typed client, SwiftData). Never extend an old screen, service or route. Retire everything old on purpose, per plan §6b and the X bytes in the progress map. That means a version floor and force-update, removing a backend route only after 14 days without calls from supported versions, a one-time local-data migration that never strands anyone's entries, and each deletion as its own small PR.

## Approach

Two tracks, joined per flow.
- **UI track, bottom-up:**
  1. Foundation: tokens with motion and haptics generated, type, surfaces, a motion lab.
  2. Sub-components.
  3. Components: variant and state enums, every state, light and dark, interaction previews, loading, empty, error and offline states.
  4. Pages, built only from components.
  5. Flows, with transitions and signature moments.
- **Platform track:** B0 baseline → B1 platform foundation (typed API client, token refresh, SwiftData plus an outbox, analytics, account and data deletion, the safe door pattern for agent routes) → B2–B8, one per flow.

Ship order: first run → daily loop (journal) → podcasts → goals → you → settings and account → outside the app.

**Each flow's ship gate:**
- every data-contract item is live, and `docs/design/sample-data-ledger.md` is at zero for that flow;
- TestFlight on a real account;
- per-user cost logged;
- errors and offline handled;
- App Store rules met (deletion, restore, privacy manifest);
- my sign-off from the recordings.
Then turn the switch on and delete the old screens.

## How every PR is made (definition of done)

1. It's small, on a fresh branch off `main`, in its own worktree. My working copy is never touched.
2. Its screenshot sits beside its Paper board, light and dark, on a 17 Pro and an SE. Every difference is fixed or listed.
3. Tokens only: no literal colours, sizes, durations, springs or haptics in views.
4. Every key state has a preview.
5. Motion visual pass (motion-system §9):
   - a 120fps recording and a slow-animation recording;
   - the ramp checked frame by frame, never linear;
   - an interrupt test;
   - the haptic on the landing frame;
   - Reduce Motion;
   - no hitches in Instruments;
   - recordings attached.
6. Accessibility: Dynamic Type to XXL, VoiceOver labels, hit areas of 44pt or more.
7. Backend PRs: auth on every route, the user ID from the token (never the body), per-user rate and spend limits, a test against a real test account, and migrations for every schema change.
8. I review the diff as a reviewer and fix findings before merging.
9. Docs are updated:
   - `docs/build-chronicle.md`, the step-by-step record;
   - `docs/second-brain/findings-log.md`, every finding including my own mistakes, plainly;
   - `docs/design/ios-handoff.md`;
   - the tracker row in `hifi-execution-plan.md`;
   - `docs/second-brain/cost-per-user.md`, with test spend kept separate.

## Feel (my brief, in my words)

"Good easing curves, nice springs, elements that feel good and bounce and move around once in a while; little pop-ups that move a little; animations here and there; everything smooth and well calibrated; the ramps are really, really important; nothing linear; do a visual pass for every one when it's implemented." And: questions typing out in onboarding have mild haptics. motion-system.md turns this into numbers. Follow it, and tune it in the motion lab before components use it.

## Safety and privacy

- Never print the contents of my email, calendar, journal or any personal data. Debug with counts and types only, unless I say otherwise.
- Never print or commit API keys or secrets. Keys stay on the server, and the client never calls model providers directly.
- Payments must never grant access without a validated transaction. Keep the fail-closed rule in `SubscriptionManager`.
- Confirm with me before anything irreversible or outward-facing: deploys, migrations on production, App Store or TestFlight submissions, deleting branches, or messages to anyone.

## How to talk to me

- Bottom line first, in short, plain English. Long write-ups read as evasion.
- Visual questions come with a screenshot or preview of each option.
- Say when a flow, a phase or M14 is close to done.
- When you're blocked on me, ask one clear question with your lean, then keep moving on whatever isn't blocked.

## First steps once the plan is approved

1. Close the open questions above.
2. B0: the baseline merge, locking down `/claude/generate`, migrations for schema drift, idempotent uploads. I rotate the ElevenLabs key.
3. In parallel, UI foundation PR 1: tokens with the new motion and haptic tokens generated into `RMotion` and `RHaptic`, `RType`, `RDepth`, the gallery, and the motion lab.
4. B1 platform foundation.
5. Then sub-components → components → the first-run flow → its ship gate.
