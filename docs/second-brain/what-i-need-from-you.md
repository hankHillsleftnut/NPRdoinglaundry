# What I need from you — step by step

Written 19 October 2026. In order of how much each one unblocks. Do them in any
order you like; each one stands alone. When you finish one, just tell me in the
chat (the last line of each step says what to send).

**One rule throughout:** never paste a password, key or "secret" into the chat.
I never need to see them. Where a step creates one, it goes straight into Render.

---

## Now (20 Oct, night): the current list

Render switches: **done by you**. Older items below are kept for the record.

1. **Apply two database changes** (1 min, in a terminal in `retrospect-agent`; the permission check stops me doing it):
   - `npm run db:migrate -- --only 148_claim_rejections.sql --apply`: corrections that never come back. Additive; nothing changes until a correction happens.
   - `npm run db:migrate -- --only 149_hypotheses_and_dials.sql --apply`: where hypotheses are kept, and the boldness dial (ships off). Additive.
   - `npm run db:migrate -- --only 150_conversation_turns.sql --apply`: talking to it. Additive.
   - `npm run db:migrate -- --only 151_action_ledger.sql --apply`: the action ledger (prepare-only). Additive.
   - Then tell me and I merge #115, #121, #122, #124, #125 and NPRdoinglaundry#18.
   - `npm run db:migrate -- --only 147_search_saved_by_meaning.sql --apply`: saved links found by meaning, and contradicted facts no longer show in search (finding 51). This one **replaces the search function**, so it needs your yes. (147 is in PR #116 until then.)
   Or reply "go ahead" and allow it, and I'll run them.
2. **Grade episodes** (the biggest lever, about an hour in total): the blind writer ranking in `.scratch/episode-experiment.md`, then real episodes as they arrive.
3. **A 3–5 minute voice note on your goals right now.** The brain's goals are from June.
4. **The 5 exam questions** (F2.3), low-step days real or phone, and labelling unclear calendar events (all below).
5. **YouTube watch history** (A/B/C in brief-youtube-transcripts.md) and **people matching** (tabled; un-table when you want).

---

## New tonight (19 Oct, late) — the short list

Everything below the line further down was written earlier. Google, Render
and connecting are **done**. These are the open items, smallest first:

1. **Flip one switch in Render** (1 min): `ENABLE_MATERIAL_ARRIVALS` = `true`
   on retrospect-agent, then redeploy. New material is then read and
   researched within minutes, not daily. The database side is already live.
2. **Three database yeses** (reply "yes 127, yes 130, yes F1.4b"):
   - **127**: a note you leave when correcting a fact survives later re-reads (today a re-read erases it).
   - **130**: answers weigh evidence by trust (automated mail counts for little).
   - **F1.4b**: when an answer is re-derived, keep the evidence it used to rest
     on instead of deleting it (so "why did you believe that?" always has an answer).
3. **People: strict or loose?** One decision, explained in
   [brief-w2-people.md](./brief-w2-people.md). I recommend strict.
4. **Evaluation questions about you (F2.3), when you have 10 minutes:** tell
   me 5 things the product got wrong about you, or should know. Each becomes
   a test the brain has to pass from then on.
5. **Do these match your days?** (2 min) The brain can now spot behaviour in
   your records. On your last 120 days it found: under 3,000 steps on **22
   days (11 in the last four weeks, 2 in the four before)**; under 6 hours of
   recorded sleep on 7; 10,000+ steps on 5; booked until 9pm or later on 4;
   30+ minutes of exercise on 3; 5+ hours of meetings on 1. **Question:** are
   the low-step days real, or days your phone sat on a desk? Reply "real",
   "phone", or "mixed". I'll switch it on (`ENABLE_RECORD_PATTERNS`) only once
   you've said, so it can't reach an episode before you've checked.
6. **Label your unclear calendar events?** (3 min) About half your calendar
   time sits under titles neither the rules nor the model can place. Reply
   "show me" and I'll put the ~18 titles in a private file (not committed) for
   you to tag (work, focus, social, personal, health, learning, travel,
   exercise). Your label always wins. Or reply "skip" and they stay
   "unplaced".
7. **Check said-vs-did** (2 min): open `.scratch/said-vs-did-review.txt` (private, not in git). Are the right events and content linked to each of your 3 goals? Reply "right" or say what's off.
8. ~~Two small product calls~~ *(answered 19 Oct: merge + expire; one asked why per episode)*:
   - **Your 31 active goals:** all were created in June and none has expired.
     May I retire any goal you haven't touched or mentioned in 90 days (kept,
     marked "expired", never deleted)? Recommended: yes.
   - **Whys:** none has ever passed its gate (21 are provisional). May a
     provisional why be *asked* in an episode ("I wonder whether…"), never
     stated? Recommended: yes, asked only, at most one per episode.
9. ~~Check 12 people~~ *(tabled by you, 20 Oct. Nothing links until you bring it back)*: open
   `.scratch/people-review.txt` (private, not in git). 6 people you write
   about will be linked to a contact; 6 I can't tell. Reply with the numbers
   of any wrong links, and yes/no for each held one. Nothing moves until you do.
10. **Read your first new-style episode** (3 min): `.scratch/episode-draft-v2.md`. Does anything in it feel untrue? A blind three-way comparison follows.
11. **Hear the new episode** (after 10): in Render, set `EPISODE_PLANNER_V2_USERS` to your user id (I'll give it to you), redeploy, then generate an episode. That's W7, your listen.
12. **Get the new daily brief**: in Render, set `DAILY_PLANNER_V2_USERS` to your user id too. The spec's gate is your verdict on 7 briefs.
13. **YouTube links: how to read them** (1 min): [brief-youtube-transcripts.md](./brief-youtube-transcripts.md). Reply A (transcript service, recommended), B (scrape) or C (titles only).
14. **Your call on one disagreement:** "other updates" in the weekly episode
   only when tied to your patterns or goals
   ([podcast-behaviour-analysis.md](./podcast-behaviour-analysis.md)).

---

## 1. Let Retrospect sign in to Google — about 15 minutes

**Why:** Retrospect has never been able to connect to anyone's Google account,
because Google was never told the app exists. Until it is, it can't read your
calendar or your mail — and most of what the product is meant to know about
you comes from those two.

**What you're doing:** registering Retrospect with Google, and getting back an
ID and a password for the app.

### If you already set something up for Google Docs — use that (about 10 minutes)

You don't need a new project. The one you made for Google Docs just needs the
other Google services switched on and one address added.

**a. Find your old project.**
1. Open **console.cloud.google.com** and sign in with the account you used
   before.
2. Click the project dropdown at the top of the page. Your existing project(s)
   are listed. Pick the one you made for Docs. Not sure which? Pick each in
   turn and do step b — the right one has a credential in it.

**b. Find the ID and secret.**
1. In the left menu go to **APIs & Services → Credentials** (or **Google Auth
   Platform → Clients**).
2. Look under **OAuth 2.0 Client IDs**. Click the one listed.
3. Check **Application type** says **Web application**. If it says iOS,
   Android or Desktop, it won't work for this — use the "starting fresh" steps
   below, but inside this same project.
4. The **Client ID** is shown on that page — a long string ending in
   `.apps.googleusercontent.com`. Copy it somewhere safe (not this chat).
5. The **Client secret:** if you can see it, copy it. Google now hides secrets
   after they're first made — if it's hidden or shows only the last few
   characters, click **Add secret** (or **Reset secret**), and copy the new
   one it shows you. That's safe: nothing else is using it yet.

**c. Add the address Google sends you back to.** On the same page, under
**Authorized redirect URIs**, click **Add URI** and paste exactly:
`https://retrospect-api.onrender.com/integrations/google/connect/callback`
Leave any old addresses there. Click **Save**.

**d. Switch on the other Google services.** Your old setup was only for Docs.
Go to **APIs & Services → Library**, search each of these, and click
**Enable** (if it says **Manage**, it's already on):
Google Calendar API · Google Docs API · Google Drive API · Gmail API ·
YouTube Data API v3

**e. Check you're allowed in.** Go to **OAuth consent screen** (or **Google
Auth Platform → Audience**). If it says **Testing**, make sure your Gmail
address is in **Test users** — add it if not.

Then go on to step 2 with that ID and secret. If anything looks different
from this, screenshot it and send it — but blur or crop out the secret.

### Starting fresh instead

1. Open **console.cloud.google.com** in your browser. Sign in with the Google
   account you want to own Retrospect.
2. At the top of the page, click the project dropdown (it may say "Select a
   project"). Click **New project**. Name it `Retrospect`. Click **Create**.
   Wait a few seconds, then make sure `Retrospect` is selected at the top.
3. In the left menu, go to **APIs & Services → Library**. For each of these,
   type the name in the search box, click it, and click **Enable**:
   - Google Calendar API
   - Google Docs API
   - Google Drive API
   - Gmail API
   - YouTube Data API v3
4. In the left menu, go to **APIs & Services → OAuth consent screen**. (Google
   sometimes calls this **Google Auth Platform**, with sections called
   Branding, Audience and Clients.) This is the screen people see when they tap
   "Connect Google".
   - If asked for a user type, choose **External**.
   - App name: `Retrospect`. User support email: yours. Developer contact
     email: yours. Save.
   - Find **Audience** (or **Test users**). Click **Add users** and add your
     own Gmail address, plus anyone else who will test the app.
   - Leave the app in **Testing**. That lets up to 100 test users in without
     Google reviewing the app — enough for your beta.
5. In the left menu, go to **Credentials** (or **Clients**). Click **Create
   credentials → OAuth client ID** (or **Create client**).
   - Application type: **Web application**.
   - Name: `Retrospect backend`.
   - Under **Authorized redirect URIs**, click **Add URI** and paste exactly:
     `https://retrospect-api.onrender.com/integrations/google/connect/callback`
     (This is where Google sends you back after you say yes.)
   - Click **Create**.
6. A box appears with a **Client ID** and a **Client secret**. Keep this tab
   open — you need both in step 2.

**Send me:** "Google done". If any screen doesn't look like this, send a
screenshot instead — Google renames these menus often.

---

## 2. Put those into Render and switch connections on — about 5 minutes

**Why:** Render is where Retrospect runs. It has two parts: the **backend**
(`retrospect-api`, what the app talks to) and the **agent**
(`retrospect-agent`, what reads and understands your data). Both need the
Google ID and secret, and the agent needs its connection switch turned on.

1. Go to **dashboard.render.com** and sign in.
2. Click **retrospect-api**. In its left menu click **Environment**. Click
   **Add environment variable** twice and fill in:

   | Key | Value |
   |---|---|
   | `GOOGLE_OAUTH_CLIENT_ID` | the Client ID from step 1 |
   | `GOOGLE_OAUTH_CLIENT_SECRET` | the Client secret from step 1 |

   Click **Save changes**.
3. Make a random password for the agent to lock your Google login with. On
   your Mac, open the **Terminal** app (press ⌘+Space, type Terminal, press
   Enter). Paste this line and press Enter:

   ```
   openssl rand -base64 32
   ```

   It prints a line of random letters and numbers. Copy it.
4. Back in Render, click **retrospect-agent** → **Environment**. Add four:

   | Key | Value |
   |---|---|
   | `GOOGLE_OAUTH_CLIENT_ID` | same Client ID as above |
   | `GOOGLE_OAUTH_CLIENT_SECRET` | same Client secret as above |
   | `ENABLE_INTEGRATION_RUNTIME` | `true` |
   | `INTEGRATION_LOCAL_ENCRYPTION_KEY` | the random line from Terminal |

   Click **Save changes**.
5. Both restart by themselves. Wait about 3 minutes.

**Send me:** "Render done".

---

## 3. Connect your Google account in the app — 2 minutes

1. Open Retrospect on your phone and go to the integrations / connections
   screen.
2. Tap **Google** and sign in.
3. Google will warn **"Google hasn't verified this app"**. That's expected
   while it's in testing. Tap **Advanced** (or **Continue**), then allow the
   read-only access it asks for.
4. You should land back in the app.

**Send me:** "connected". I'll check that the connection exists and the first
calendar sync ran. (I check that it happened — I never see your Google login.)

---

## 4. Why your iPhone calendar never arrived — 2 minutes

**Why:** your phone sends Health data fine, but calendar, music, photos and
contacts have never once arrived. Either the app on your phone is older than
8 August, or the server is rejecting it. One of these tells me which.

**Either:**
- Tell me your app's version: open **TestFlight**, tap Retrospect, and read the
  version and build number. Or check Retrospect's own settings screen.

**Or:**
1. In **dashboard.render.com**, click **retrospect-api** → **Logs**.
2. In the search box type `device-batches`.
3. Screenshot whatever shows up, even if it's nothing.

**Send me:** the version number, or the screenshot.

---

## 5. Export your Notion — 5 minutes *(no longer needed: you're feeding it through the app, 19 Oct)*

**Why:** your Notion holds months of daily hours, tasks, people you're talking
to and links you saved — exactly the day-by-day material the product is
missing. A one-time export is cleaner than me clicking through dozens of pages.

1. Open Notion on your computer (not your phone).
2. Click **Settings** (bottom of the left sidebar, or under your workspace
   name).
3. Find **Export all workspace content** (or **Export**, under General or
   Workspace).
4. Choose **Markdown & CSV**. Turn on **Include subpages** if it's offered.
   Click **Export**.
5. Notion emails you a download link, or downloads a `.zip` file directly.
   Download it.
6. Move the `.zip` into this folder on your Mac:
   `Projects / retrospect-main`
   (Finder → your home folder → Projects → retrospect-main.)

Before anything is saved I'll show you how I've sorted it — what you wrote,
what Instinct (the AI that set your Notion up) wrote, and what's just logged
numbers — and you approve it. Reading it in will cost roughly $1–3; I'll tell
you the exact number first.

**Send me:** "Notion exported".

---

## 6. Which iPhone app do you mean? — 1 minute

You said you have an iOS app already built to connect this to.

**Send me:** either "the Retrospect app in the repo", or where the other one
lives — a folder on your Mac, or a GitHub link.

---

## 7. Which Google Docs did you write? — 1 minute

**Why:** the system only treats a document as "you talking" if it knows you
wrote it — otherwise someone else's brief could be mistaken for your opinions.
Right now your own Design Doc, SFP application and presentation script are
being held back.

**Send me:** the titles of the Google Docs you wrote yourself. Just a list.

---

## 8. Approve the new onboarding questions — 5 minutes

**Why:** the new sign-up asks 8 questions that each reveal several things about
someone, instead of 18 that mostly don't. Changing what every new user sees is
your call.

1. Open `docs/second-brain/brief-onboarding-questions.md` and read the table of
   8 questions.
2. Change any wording you'd say differently.

**Send me:** "onboarding approved", or your edits.

---

## 9. Three yes/no answers — 1 minute

Reply with all three in one message:

- **"Apply 127" — yes or no?** When you correct a fact and leave a note, a
  later re-read of your writing currently erases the note. The fix is ready;
  switching it on in the live database needs your yes.
- **Fix how the iPhone reads your calendar — yes or no?** Today it squeezes
  your whole calendar into one short summary — too thin to understand your
  week. The fix reads each event on its own and leaves out private event notes
  and video-call links. About $2 the first time for 30 days of events, then
  pennies.
- **Build the daily brief around "one thing that changed about you" — yes or
  no?** That's the recommendation from the test (step 10 lets you judge it).

---

## 10. Optional, but they make it right about *you* — 10 minutes total

- **Read the practice briefs.** Open `.scratch/practice-briefs.md` in this
  folder. Read two or three. Do they hang together? Do they sound like
  something you'd want to hear? A model graded them; you're the real test.
  **Send me:** a one-line reaction to each you read.
- **Your most important people.** Name the 3–5 people who matter most to you
  right now, with a few words on why. Until mail and calendar are flowing,
  this anchors who the product thinks is in your life.
  **Send me:** the list.

---

## If you only have 20 minutes

Do **1, 2 and 3** (Google + Render + connect). Everything else gets better once
your calendar is flowing in.
