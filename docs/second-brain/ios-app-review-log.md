# iOS app — problems log and redesign direction

A running list. The founder adds problems as they find them; nothing is fixed
from here until the screen-by-screen review and the new onboarding plan are
agreed. Started 19 October 2026.

## Direction

- **Visual language to build toward:** the paywall moment — tap the podcast,
  the first insight plays, then the buttons slide up from the bottom. That
  motion and pacing is the reference for the whole app. *(Founder to point out
  specifics.)*
- **Keep:** the shader's dots.
- **Every screen gets asked:** is this really conducive to a proper
  experience? Flow-wise — is it illogical, redundant, broken, or patched
  together?
- **Onboarding gets restructured** around what the product now actually does
  (the 36 questions it answers about you, connections, how intelligent it is).
  Pairs with the new onboarding questions
  ([brief](./brief-onboarding-questions.md)).

## Problems logged

### Connections screen — "Here's what would help me know you best"
1. **Unclear purpose.** It doesn't say this is a core part of the experience —
   it reads as optional setup.
2. **Integration styles are inconsistent and unclear.** States like "Device
   sync", "First sync queued" and a tick mean different things with no
   explanation. The AI-chat sources (Claude, ChatGPT, Grok) are file uploads,
   which isn't a good experience.
3. **"Make my podcast" overlaps the list** — the button cuts into the cards
   (Calendar is half hidden behind it).

### Podcast host / voice choice
4. **Picking a canned host** (wise mentor, energetic host, thoughtful friend) is
   low-tech. Replace with a short **voice conversation**: a few pointed
   questions about what they listen to and watch, then the product **creates**
   a voice for them.

### "Play Podcast" and "Learning about you"
5. **Redundant:** after Play Podcast, the "Learning about you" sequence runs,
   and there is also a demo podcast playing — two things doing one job.
6. **Dots draw over the text** in the shader area at the bottom.
7. **No way out of the demo player** — fixed in
   [NPRdoinglaundry#11](https://github.com/hankHillsleftnut/NPRdoinglaundry/pull/11)
   (Continue for everyone; Skip in debug builds).

### Loading screen (particles collapsing into one core)
8. **Takes a long time and hangs at 94%.** To investigate. First suspicion: it
   waits on the server, and the server sleeps when idle on Render's free plan
   (up to ~50 s to wake), plus the agent's own work. Needs measuring.

### Launch
9. **~90 s to launch after a rebuild,** white screen, then slow Face ID. Likely
   mostly the debugger over Wi-Fi; to confirm by launching from the home
   screen without Xcode.
10. **Broken font files** — the three Libre Baskerville files are saved web
    pages, and Adamina is listed but missing. Unused by the code; to clean up.
11. **Audio set up in a way Apple warns can freeze the screen** (home screen
    playback). To fix.

### Two versions of the app
12. `main` and the `redesign/integrations-page-theme` branch have each moved on
    without the other (September design work vs the October fixes). To merge
    into one before any redesign starts.

## Next

1. Founder keeps adding to this list.
2. Screen-by-screen review: every page, what it's for, what's wrong (flow,
   redundancy, broken, patched), with screenshots.
3. New onboarding structure, built on the product as it now works.
4. Then build, in small pieces, starting with the merged single version.

## Queued: the new iOS app (after the goal-spec work)

Founder, 19 October 2026: build a new iOS app that reflects the product as it
now works — **after** the goal-spec work, not before. Agreed shape so far:

- A **separate new project** beside the old one, not a "redesign" folder inside
  it. The old app stays untouched and runnable until the new one covers the
  core loop (non-destructive). XcodeGen is installed for a clean project file.
- Reuse what works: the server connection, Apple sign-in, Health and calendar
  readers, sleep maths. Design language: the paywall moment
  (`PodcastPaywallFlow.swift` colours and motion).
- Every screen maps to a goal in the spec. Plan to be written when this starts.
- Needs the backend to accept the new app's ID at sign-in.
