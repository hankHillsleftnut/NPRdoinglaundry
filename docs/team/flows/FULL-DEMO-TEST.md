# How to walk the whole app on your iPhone (the Full Demo)

The Full Demo is the whole app on sample data: the first run from the splash, then the app with all four tabs (journal, podcasts, goals, you) and the pages they open, and "welcome back" after you sign out. It has no backend, makes no purchase, and uses no Apple ID sign-in. Nothing you type leaves the phone. The App Store build doesn't contain any of it.

It uses the same screens as the real app and the same first run as the Core Flow scheme. A screen that isn't built yet isn't there: there are no placeholder pages. A drawn button with nothing behind it yet does nothing, and VoiceOver says "not available yet".

## Before the first time (once)
- On the iPhone: **Settings → Privacy & Security → Developer Mode → On**. The phone restarts.
- In Xcode: **Settings → Accounts** shows your Apple ID with the Retrospect team. Signing is already set in the project; don't change it.

## The 6 steps
1. **Plug the iPhone into the Mac** with a cable. Unlock it and tap **Trust** if it asks.
2. **Open `Retrospect/Retrospect.xcodeproj`** in Xcode.
3. **Pick the scheme `Retrospect · Full Demo`** in the bar at the top (the menu left of the device name).
4. **Pick your iPhone** as the device, in the menu next to the scheme.
5. **Press ⌘R.** The first time, the iPhone may say the developer isn't trusted: **Settings → General → VPN & Device Management**, tap your Apple ID, tap **Trust**, then press ⌘R again.
6. **Walk it** (below). Close the app and open it again from Xcode, and it comes back where you were.

## What you can walk

| Part | Start | What to try |
|---|---|---|
| The first run | the splash (the first time) | exactly as the Core Flow guide: sign in, the invite code **7KQ2M9XD4RTAB**, tear the stub, begin, the questions, privacy, then each screen as it is built. It ends at the last built screen; when first home is built, it carries on into the app |
| The app | `-DemoStart app` (below), or the end of the first run once first home is built | the tab bar at the bottom: each tab keeps its place when you come back to it |
| Journal | the journal tab | the drawer button (or swipe from the left edge) opens all entries; an entry opens it, back returns; **settings** at the drawer's foot opens settings; the brief card raises today's brief over the tab bar, the chevron lowers it |
| Podcasts | the podcasts tab | the library on the sample (its play joins the player when the shared play button is built) |
| Goals | the goals tab | "ship the first version" opens the goal; its "your words" opens the entry; back returns |
| You | the you tab | ask a question (the answer shows in place), open a source, tap a person on the map, "what i know about you"; **your picture** (top right) opens settings |
| Settings | your picture, or the drawer's foot | every row opens its page and back returns; daily brief → **play today's** raises today's brief; account → **sign out** → "welcome back" |
| Welcome back | after signing out, or `-DemoStart returning` | **Sign in with Apple** (sample) brings you back to the journal with everything fresh; **new here? get started** starts a new first run from the splash |
| From outside the app | `-DemoOutside share`, `brief` or `talk` (below) | as if another app shared to Retrospect (the share sheet over the app), the brief notification or widget (today's brief), or the widget's "tell me…" (the journal) |

Not joined yet, and why: the podcasts play (waits for the shared play button), a goal row on a source in You (the sample's goal has no goal page drawn), ST-9's plan rows and delete account (not built yet). "your words" on the goal opens the entry page on an entry the entries sample doesn't have, so it says it can't find it (the two samples are being lined up).

## Start somewhere else (the scheme's switches)
In Xcode: **Product → Scheme → Edit Scheme… → Run → Arguments**. Tick ONE of these, press ⌘R once, then untick it again (or every run starts there; ticking changes the shared scheme file, so don't commit that change):
- **`-DemoStart firstRun`**: a new first run from the splash, nothing kept.
- **`-DemoStart app`**: straight into the app.
- **`-DemoStart returning`**: "welcome back", as after signing out.
- **`-FlowStart questions`**: the first run at that screen (change the word to `inviteGate`, `youreIn`, `privacy`, `gettingReady`).
- **`-DemoOutside share`** / **`brief`** / **`talk`**: the app as the system opens it from the share sheet, a notification or a widget.

The quickest full reset: press and hold the Retrospect icon, tap **Remove App**, then press ⌘R.

## Good to know
- **Always start it from Xcode.** The home-screen icon opens the normal app, not the demo, because it doesn't pass the `-Flow demo` setting.
- The demo keeps its place apart from the Core Flow scheme: walking one never moves the other.
