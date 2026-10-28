# How to test the core flow on your iPhone

The core flow is the whole first run, from the splash to first home, on sample data. It has no backend, makes no purchase (both prices are dummies), and uses no Apple ID sign-in. It ends at first home, inside the tab bar with all four tabs.

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
| 5 | The questions | answer each question: speak (the sample listens and fills in words), tap a quick-answer chip, or type, then send; the back arrow goes to the previous question | the next question; after the last one, privacy |
| 6 | Privacy | there is no button on purpose: wait about 8 seconds while "retro is speaking…", or tap anywhere to move on; the back arrow returns to the last question | connect |
| 7 | Connect | the sample starts with 1 of 6 sources connected. Tap **later** to move on at once, or tap **+ connect** on two more sources (sample: nothing leaves the phone): **continue** appears at 3 of 6, then tap it. The back arrow returns to privacy | getting ready |
| 8 | Getting ready | answer the question if you like; there is no back on purpose; the sample episode finishes on its own | the tease |
| 9 | The tease | nothing: the player sheet rises and plays your first episode for 10 seconds, the live line lit as it's read (the chevron at the top ends it early) | the sheet collapses into the paywall |
| 10 | The paywall | tap either price, **$239.99 / year** or **$24.99 / month** (dummies: nothing is charged, no Apple sheet). The mini-player's play only nudges the yearly plan; restore, privacy and terms do nothing yet | first home |
| 11 | First home | the journal tab on its first day: your first episode is ready (tap the card to hear the tease again), a welcome, and what you told Retro while setting up, in your own words. The tab bar shows journal, podcasts, goals and you; each tab opens on sample data | **the end of the first run** |

If a later screen is ever missing from a build, the walk stops where it is and a small pill at the top says "end of what's built · tap to start over"; tap it to walk again from the splash.

Close the app and open it again from Xcode, and it comes back on the same screen with your answers kept.

## Reset (start over with nothing kept)
On the iPhone, press and hold the Retrospect icon, tap **Remove App**, then press ⌘R. Removing the app clears everything the sample flow kept.

Or in Xcode: **Product → Scheme → Edit Scheme… → Run → Arguments**. Tick **`-FlowStart splash`**, then press ⌘R once. Untick it again afterwards, or every run will start over. Ticking it changes the shared scheme file, so don't commit that change.

You can also start from a later screen by changing `splash` to `inviteGate`, `youreIn`, `questions`, `privacy`, `connect`, `gettingReady`, `tease`, `paywall` or `firstHome`. Spell it exactly like that: a misspelled step is ignored, and the flow carries on where it was.

## Good to know
- **After the first run from Xcode, the home-screen icon works too.** Once this test build has been run once with the `Retrospect · Core Flow` scheme, tapping the Retrospect icon opens the sample flow, carrying on where you left off. (Only test builds do this; the App Store app never does. The plain `Retrospect` scheme always opens the normal app.) Removing the app forgets this.
- **Links do nothing in the sample flow.** An invite link, the record button on the lock screen or a notification tap won't open anything while it's on. To try those, run from Xcode with the plain `Retrospect` scheme.
- What you type stays on this phone, in the sample flow only. It is never sent anywhere.
