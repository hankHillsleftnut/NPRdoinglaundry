# How to test the core flow on your iPhone

The core flow is the first run, from the splash to first home, on sample data. Merge PR #238 before this guide: it joins the questions, privacy, connect and getting ready. It has no backend, makes no purchase, and uses no Apple ID sign-in. It ends at the last screen that is built so far, where a small "start over" pill appears. There are no placeholder pages.

## Before the first time (once)
- On the iPhone: **Settings → Privacy & Security → Developer Mode → On**. The phone restarts.
- In Xcode: **Settings → Accounts** shows your Apple ID with the Retrospect team. Signing is already set in the project; don't change it.

## The 6 steps
1. **Plug the iPhone into the Mac** with a cable. Unlock it and tap **Trust** if it asks.
2. **Open `Retrospect/Retrospect.xcodeproj`** in Xcode.
3. **Pick the scheme `Retrospect · Core Flow`** in the bar at the top. It's the menu left of the device name.
4. **Pick your iPhone** as the device, in the menu next to the scheme.
5. **Press ⌘R** (or the ▶ button). The first time, the iPhone may say the developer isn't trusted. Go to **Settings → General → VPN & Device Management**, tap your Apple ID, tap **Trust**, then press ⌘R again.
6. **Walk the flow** (below). To try it again from the start, **reset** (below) and press ⌘R.

## What to tap, and what you should see

| # | Screen | What you do | What happens next |
|---|---|---|---|
| 1 | Splash + sign-in | tap **Sign in with Apple** (sample: no Apple sheet opens) | the invite gate |
| 2 | Invite gate | type the sample code **7KQ2M9XD4RTAB** (the field refuses letters a code never has, such as U) | the ticket prints |
| 3 | The ticket | **swipe along the line** to tear the stub (the hint says "swipe along the line to tear") | "you're in" |
| 4 | You're in | tap **begin** | the first question |
| 5 | The questions | answer each question and send it (today you type; once the simulated listening lands, PRs #242/#244, the sample fills in spoken words and quick-answer chips, and this row will be updated); the back arrow goes to the previous question | the next question; after the last one, privacy |
| 6 | Privacy | there is no button on purpose: wait about 8 seconds while "retro is speaking…", or tap anywhere to move on; the back arrow returns to the last question | connect |
| 7 | Connect | the sample starts with 1 of 6 sources connected. Tap **later** to move on at once, or tap **+ connect** on two more sources (sample: nothing leaves the phone): **continue** appears at 3 of 6, then tap it. The back arrow returns to privacy | getting ready |
| 8 | Getting ready | answer the question if you like; the sample episode finishes on its own | **the end of what's built**: a small pill at the top says "end of what's built · tap to start over". Tap it to walk again from the splash with nothing kept |

Coming next, in this order, as each one is built: the tease (the episode plays for 10 seconds) → the paywall (both prices are dummies; nothing is charged) → first home. Each one moves the "end of what's built" pill one screen further.

Close the app and open it again from Xcode, and it comes back on the same screen with your answers kept.

## Reset (start over with nothing kept)
At the end of what's built, tap the **start over** pill. From anywhere else: on the iPhone, press and hold the Retrospect icon, tap **Remove App**, then press ⌘R. Removing the app clears everything the sample flow kept.

Or in Xcode: **Product → Scheme → Edit Scheme… → Run → Arguments**. Tick **`-FlowStart splash`**, then press ⌘R once. Untick it again afterwards, or every run will start over. Ticking it changes the shared scheme file, so don't commit that change.

You can also start from a later screen by changing `splash` to `inviteGate`, `youreIn`, `questions`, `privacy`, `connect` or `gettingReady`. Spell it exactly like that: a misspelled step is ignored, and the flow carries on where it was.

## Good to know
- **After the first install, the home-screen icon works too.** In this test build, tapping the Retrospect icon opens the sample flow, carrying on where you left off. (Only test builds do this; the App Store app never does.) Running from Xcode with the `Retrospect · Core Flow` scheme does the same.
- What you type stays on this phone, in the sample flow only. It is never sent anywhere.
