# App audit, deep pass: every interaction, state, size and clarity question

20 October 2026, night. Founder: "find every single problem where the app is incoherent, hard to use, broken interactions, weird pixels, confusing onboarding screens, sections that don't make sense, interactions that break, frame rates that drop, gestures that aren't performing correctly, everything."

**How it's run:** debug build on the iPhone 17 Pro simulator, pointed at a local stand-in server that serves a labelled sample week (3 episodes, 4 goals, a connected Google account, a Spotify error, an expired Reddit link) and can be switched to **empty**, **error** and **slow** modes. Nothing is sent to Retrospect's servers; no spend. Sizes: iPhone 17 Pro and iPhone SE (smallest); the 17 Pro Max (largest) was not tested. Text size: the largest accessibility size. Appearance: light and dark.

**Limits, said plainly:** the simulator can't measure real frame rate or haptics, and can't run the recorder, Health, Screen Time, notifications or widgets. Frame-rate findings below come from the code (what redraws every frame, what blocks the main thread) and from what visibly stutters; a phone recording confirms them.

Findings continue the audit's numbering with **Y**. Severity: **B** blocker · **M** major · **m** minor. Each finding says what I did and what happened.

## Summary

**51 entries: 2 blockers · 20 major · 22 minor** (7 are confirmations of earlier findings, corrections or "fine as is"). Combined with [app-audit.md](./app-audit.md): **10 blockers.**

**The two new blockers:**
- **Y26: no episode can be heard in the app after onboarding.** The player only plays files saved on the phone; every episode from the server is a link, and the app never downloads it. Tapping any episode opens a silent player.
- **Y12: deleting an entry only deletes it from the phone.** The server and the brain keep the words and can still use them in episodes and search.

**The worst of the rest, by theme:**
- **Writing:** a half-written thought is sent as a finished entry the moment you leave the box (Y4); sending shows no confirmation, success or failure (Y5, Y29); entries can't be edited or deleted on their page (Y10).
- **Navigation and gestures:** swipe-back doesn't work (Y11); Back goes to a screen you never opened (Y14); the player's only exit is drawn as a menu icon and swipe-down doesn't close it (Y27); the Goals screen jumps under the status bar when you add one (Y19).
- **Showing the brain's work:** every episode is called "Weekly Insights" (Y22); the brain's goals never appear and adding one sends eight writes (Y17, Y18); Journal shows nothing you've written or what came of it (Y1).
- **Failure and slowness:** a failing server looks identical to a working one (Y28); episodes silently vanish when the server fails, and the list never refreshes (Y30, Y31); choosing a host can block for up to ~50 s (Y51).
- **Size and access:** the paywall is one fixed picture shrunk to fit, so it's tiny on the SE (Y41); the app ignores the system text size (681 fixed fonts), has 9 VoiceOver labels for 427 buttons, and stays light in dark mode (Y36–Y38).
- **Risky controls:** one tap on a 34-pt power icon disconnects a source with no confirmation (Y32).
- **Frame rate (to confirm on a phone):** "Learning about you" redraws the whole screen 60 times a second for minutes (Y44); blurred transcript lines (Y45); taps lag about a second (Y47).

**Not covered here (need a phone):** the recorder, Health, Screen Time, notifications, widgets, real frame rate and haptics. Onboarding steps 4–11 on the SE (the debug Skip jumps past them). Profile, Animation and Advanced sub-pages were checked in the earlier pass.

## Journal (home)

| # | What I did | What happened | Kind | Sev |
|---|---|---|---|---|
| Y1 | Opened the app | Journal is an almost empty screen: a faint "tell me something….." in the middle, an episode pill, "Your next episode is in 3 days". **Nothing shows what you've written, what the brain made of it, or what to do today.** The home of the product has no content | clarity | **M** |
| Y2 | Tapped "tell me something….." | The keyboard took a second or two to come up; **the cursor appears at the top left, not where the prompt was**, so the first tap doesn't land where your eye is. The text box is invisible (2% opacity) until you type | interaction · pixel | m |
| Y4 | Typed "Half written thought about", then opened the menu | **The half-written thought was sent as a finished entry** (the server received it the moment the menu opened). Any way of leaving the box sends it: the menu, the mic, a call, swiping the keyboard away (`onChange(of: isJournalFocused)` → `sendJournalEntry`) | broken | **M** |
| Y5 | Tapped send | **The words vanished with no confirmation.** No "saved", no entry shown, no sign it reached the brain. It did reach the server (seen in the stand-in log), but the person can't know | clarity · feedback | **M** |
| Y6 | Timed the screen | Several seconds between tapping send and the screen clearing, and between taps and the keyboard. Idle CPU is near zero, so it isn't a background drain; to confirm on a phone | performance | m (verify) |
| Y7 | Opened the menu | A "recents" list appears under the sections, every item titled **"Entry from Oct 20, 2026…"** and cut off, so you can't tell entries apart; it duplicates the Entries screen | clarity · redundant | m |
| Y8 | (correction) | An earlier note here said the menu does nothing while typing; that was my tap landing off the button. The menu works | — | — |

## A single entry (from recents or Entries)

| # | What I did | What happened | Kind | Sev |
|---|---|---|---|---|
| Y9 | Opened an entry | **The hierarchy is upside down:** the title is the date and time in 36 pt serif over three lines ("Entry from Oct 20, 2026 at 2:27 AM"), the line below repeats the same date, and **the person's own words are the smallest, greyest text on the page**. The AI title the code expects (`aiGeneratedTitle`) never arrives | pixel · clarity | **M** |
| Y10 | Tapped the words; looked for edit or delete | **The entry can't be edited, and the page has no delete.** Only a back button | missing | **M** |
| Y11 | Swiped from the left edge | **Nothing happened.** The standard iPhone swipe-back gesture doesn't work; only the small round back button does | gesture | **M** |
| Y12 | Read the code for deleting from Entries (long-press menu) | **Deleting an entry only removes it from the phone.** `EntryManager.deleteEntry` deletes the local file and nothing else, so the server and the brain keep the words and can still use them in episodes and search. A person who deletes something private believes it's gone | broken · privacy | **B** |
| Y13 | Read the code | Three different entry-page views exist (`FigmaLightInlineEntryReader` live; `DarkEntryDetailView` and `EntryDetailView` unreachable or legacy), so the J3 "edits never re-sync" problem lives only in the unreachable one | redundant | m |

## Entries

| # | What I did | What happened | Kind | Sev |
|---|---|---|---|---|
| Y14 | Opened an entry from the menu's recents, then tapped back | **Back went to Entries, a screen I had never opened**, not to Journal where I started | navigation | **M** |
| Y15 | Compared titles | Entries titles each entry by its first words ("Half written thought about"); the menu's recents call the same entries "Entry from Oct 20, 2026…"; the entry page uses the date. Three names for one thing | incoherent | m |
| Y16 | Tried to act on actions in quick succession | Screens lag about a second behind each tap, so taps made while a menu is closing land on whatever is underneath (my long-press on an entry opened Goals through the closing menu) | interaction | m (verify) |

## Goals

| # | What I did | What happened | Kind | Sev |
|---|---|---|---|---|
| Y17 | Opened Goals with a server holding 4 sample goals | **It shows the phone's 3 onboarding goals, not the server's 4.** The brain's goals never appear (confirms G3 live) | broken | (G3) |
| Y18 | Added one goal ("Sample: read more") | **One goal sent 8 writes:** a read, 4 creates (every phone goal re-created) and 3 updates switching off the server's goals the phone didn't recognise. Duplicates pile up and the brain's goals are turned off (confirms G1 live) | broken | (G1) |
| Y19 | Tapped "+" | **The whole screen jumps up under the status bar and camera:** the title and menu disappear, goal text runs behind the clock, and the input floats mid-screen over a large blank area | pixel · layout | **M** |
| Y20 | Expanded a goal | The description is indented further than the "Why this matters" label under it; a large empty area; only a small bin icon. **No edit, no progress, nothing the brain has noticed.** "Why this matters" shows the extraction note ("Sample") rather than the person's reason | pixel · missing | m |
| Y21 | Looked at the new goal | A goal added by hand has no description, so its card is a different height from the rest | pixel | m |

## Podcasts and the player

| # | What I did | What happened | Kind | Sev |
|---|---|---|---|---|
| Y22 | Opened Podcasts with 3 sample episodes on the server | **Every episode is titled "Weekly Insights"**: the title is hard-coded and the server's real titles ("The week you stopped rushing", "What the Sunday calls were for") are thrown away. You can't tell episodes apart | broken · clarity | **M** |
| Y23 | Read the mood under each title | The server's moods ("warm", "curious") show as **"neutral"**: anything outside an old fixed list of eight is replaced (`Transcriptviewmodel.swift:632`) | broken | m |
| Y24 | Counted rows | **4 rows for 3 episodes:** the locally saved first episode sits beside the server's copy | redundant | m |
| Y25 | Looked at a row | **Two play buttons per row** (a round one on the left, a triangle on the right); the date is cut off ("Oct 20, 2…") | pixel · redundant | m |
| Y26 | Played a server episode | **Nothing plays, for any episode:** the app never fetched the audio (no request reached the server). The player only plays files saved on the phone, and server episodes are links, so **no episode can be heard in the app after onboarding.** Extends N20 from the first episode to all of them | broken | **B** |
| Y27 | Looked at the player | It shows a stale "0:37" from an earlier session, no title, no date, no chapters, no speed, no "why this was in it"; the "…" button does nothing; the only way out is a button drawn as a menu icon (≡), which reads as "open menu"; swiping down does nothing | missing · broken | **M** |

## Failure states (server returning errors)

| # | What I did | What happened | Kind | Sev |
|---|---|---|---|---|
| Y28 | Opened the app with the server failing | Journal looks exactly the same as when it works: no banner, no sign anything is wrong | clarity | **M** |
| Y29 | Wrote an entry and sent it while the server was failing | The server returned an error, and **the screen cleared exactly as it does on success.** Nothing says the entry didn't arrive, nothing retries it (confirms J1 live) | broken | (J1) |
| Y30 | Opened Podcasts with the server failing | **Three of four episodes silently disappeared**: no message, no retry, as if they never existed | broken · clarity | **M** |
| Y31 | Pulled down to refresh; reopened Podcasts | **No pull-to-refresh, and the list isn't re-fetched when you open the tab**; it loads once at launch, so a new episode doesn't appear until the app restarts | broken | **M** |

## Integrations & Data (with a connected source, one in error, one expired)

| # | What I did | What happened | Kind | Sev |
|---|---|---|---|---|
| Y32 | Looked at the row actions | **The power button disconnects a source in one tap, with no confirmation**, and sits 2 pt from the "…" menu; both targets are 34 pt, under Apple's 44 pt minimum. Missing the "…" by a few points turns Google off | interaction · risk | **M** |
| Y33 | Read the states | Status is colour-coded green and orange in colours the design system doesn't have; "Verified and connected · Continuous sync" and "Sync needs attention · Continuous sync" wrap mid-phrase; **"needs attention" never says what to do** (the fix, reconnect, is hidden in "…" as "Sync now") | clarity · pixel | **M** |
| Y34 | Compared with onboarding | The same source is "Google Docs" here, "Google Docs/YouTube/Gmail" in onboarding, and "Google" on the server; summary tiles ("1 Verified · 2 Needs attention") don't say which | incoherent | m |
| Y35 | Looked at the sheet | This is a sheet over Settings with its own back button, while every other Settings page is a full screen: two navigation styles one tap apart | incoherent | m |

## Text size, dark mode, accessibility (whole app)

| # | What I did | What happened | Kind | Sev |
|---|---|---|---|---|
| Y36 | Set the largest accessibility text size | **Nothing in the app got bigger.** 681 fonts are fixed sizes; 21 follow the system text size. Anyone who needs larger text can't get it (an App Store accessibility expectation) | accessibility | **M** |
| Y37 | Switched the phone to dark mode | **The app stays light**: it's forced to light in 24 places (while every main file is named "Dark…"); a couple of player error screens force dark instead. The founder's decision is light and dark together | incoherent · pixel | m (decided for v2) |
| Y38 | Counted VoiceOver labels | **9 accessibility labels for 427 buttons.** Icon-only buttons (menu, mic, +, send, power, "…", the two-arrow icon) are unnamed to VoiceOver | accessibility | **M** |
| Y39 | Checked reduced motion | Respected in 2 places only; the shader, the dots and the onboarding animations ignore it | accessibility | m |
| Y40 | Measured touch targets | Several key controls are under 44 pt: the integration row buttons (34 pt), the player's "…", the debug Skip | interaction | m |

## iPhone SE (smallest screen)

| # | What I did | What happened | Kind | Sev |
|---|---|---|---|---|
| Y41 | Reached the paywall on the SE | **The paywall is one fixed 402 × 874 picture shrunk to fit** (16 hard-coded positions inside): on the SE everything is drawn at about 76%, so the price buttons and the "Restore · Privacy notice" links are smaller than designed (the links are around 9 pt), with empty bands at the sides. It's laid out for one phone, not any phone | pixel · layout | **M** |
| Y42 | Played the episode on the SE | The first-episode player fits; the transcript's lower lines are blurred deliberately, but on the small screen only one sentence is readable at a time | pixel | m |
| Y43 | The SE's simulator uses no Dynamic Island; the welcome, intro and closing screens fit; nothing was cut off on those | — | ok | — |

## Frame rate and smoothness (from the code; confirm on a phone)

The simulator can't measure real frame rate, so these are the places in the code most likely to drop frames, ranked. A phone screen recording with the frame-rate overlay confirms or clears each one.

| # | Where | Why it can stutter | Kind | Sev |
|---|---|---|---|---|
| Y44 | "Learning about you" | A 60-times-a-second timer on the main thread updates SwiftUI state every frame (`@State hold/release/dissolve`), which re-renders the whole screen including a Metal shader, and drives continuous haptics, for the minutes the episode takes. On an older phone this is the most likely place for dropped frames and battery drain | performance | **M** (verify) |
| Y45 | Transcript in the player and paywall | Every line except the current one is blurred (`.blur(radius: 1.8)`), plus 10–22 pt blurs on the paywall veil; blur on many text layers is expensive and the transcript scrolls while playing | performance | m (verify) |
| Y46 | Onboarding acknowledgements | Each acknowledgement dissolves into particles drawn by a `Canvas` at 60 fps; fine for a moment, but it runs on top of the typing keyboard | performance | m (verify) |
| Y47 | Journal and menu | Taps take about a second to register and the keyboard is slow to appear (Y2, Y6, Y16). Idle CPU is near zero, so the likely cause is work done on the tap itself (the side panel's shadow and scale animation, focus changes) rather than background load | performance | m (verify) |
| Y48 | Whole app | 83 timed delays (`asyncAfter`) choreograph animations by the clock; on a slow phone they fall out of step with what's actually ready (S2) | performance · logic | m |

## Onboarding edge paths (slow server, closing, going back)

| # | What I did | What happened | Kind | Sev |
|---|---|---|---|---|
| Y49 | Closed the app at Connections and reopened | **Resumed at Connections**: step-level progress is saved (good). Within the questions, answers are not (O2) | ok · (O2) | — |
| Y50 | Swiped from the left edge on Connections | **No way back** to the questions, by gesture or button (confirms O1 live) | navigation | (O1) |
| Y51 | Picked a host with the server responding slowly | **"Saving…" blocks the screen for the whole server wait** (25 s in the test; a sleeping Render server takes ~50 s) just to save a preference, with no way to continue and no explanation. A preference should save in the background | interaction · waits | **M** |
| Y52 | Opened Connections with a slow server | The list renders immediately from a list built into the app, and real connection states arrive later with no sign of loading, so a source can appear "not connected" and then change | clarity | m |
