# Questions for you, from the six area plans

The six plans written on 21 Oct asked you about 100 questions. Many were the same question asked twice, and 27 are already answered by your earlier decisions or the design system's rules. That leaves **55**, sorted by what they hold up: Beta 1 first, then each flow in build order.

**Work goes ahead on the lean unless you say otherwise.** A short reply works: "B1 yes, B3 b, N3 shorter".

The engineering detail behind each one is in [plans-consistency.md](./plans-consistency.md).

---

## Beta 1 (these hold up the TestFlight build)

**B1 · Make Beta 1 about 17 PRs bigger?**
- Two plans found work Beta 1 needs that isn't on its list. The bigger part is the invite ticket ("you're in"): drawn as a ticket that prints and tears, it's 15 pieces, not 2. The other is the audio player: nothing yet plays the brief in the new journal.
- Beta 1 would go from about 85 PRs to about 102. Three asks stay out:
  - the inviter's name before sign-in;
  - lock-screen play controls;
  - a second, sample-data invite test.
- **Lean: yes.** Affects first-ship.md, and the PRs PLP.1a, PLP.1b, BE2.0b, PL1.7d, PL1.8, FR0.1, FR0.2, UI4.0, C43, C41.1–5, C42 and PI2.1–4.

**B2 · Show who invited someone before they sign in?**
- A: yes, "priya saved you a place", but only for a code that still works.
- B: no; the name appears on the ticket after sign-in.
- **Lean: A.** But B keeps the preview PR (BE2.0a) out of Beta 1. Affects BE2.0a and PI1.

**B3 · What is the number on the ticket ("no. 0412")?**
- A: the invite's number, in the order invites were made.
- B: your member number (only known after the tear).
- C: no number.
- **Lean: A.** Affects BE2.0b and the ticket face (C41.2).

**B4 · When you invite someone yourself, who is the ticket "from"?**
- A: your first name.
- B: "retrospect".
- C: nothing.
- **Lean: A.** Affects BE2.0a and BE2.0b.

**B5 · In Beta 1, where does "begin" take people after the ticket?**
- A: the current onboarding, which still works.
- B: straight into the new journal.
- **Lean: A.** Affects PL1.8.

**B6 · A sound when the ticket tears?**
- A: none.
- B: a soft rip, off by default.
- C: on.
- **Lean: A.** Affects PI2.4.

**B7 · The ticket's waitlist, "already used", "expired" and "paused" screens aren't drawn. Approve them from screenshots, or draw them first?**
- A: built from your round 1 drawings; you approve the screenshots.
- B: drawn in Paper first. The invite screen waits for that, and so does Beta 1.
- **Lean: A.** Affects PI1.

---

## Notifications (built with first run, before any push goes out)

You decided every notification is written for the person and the moment, with the words fetched on the phone. The plan to do that raised three trade-offs and three settings.

**N1 · Is a settings row that opens iPhone's own "Show Previews" setting the "hide the words on the lock screen" switch?**
- iPhone already hides notification words until you unlock, per app. Our row explains this and opens that page.
- A: yes, use iPhone's setting (it's enforced by the phone, and works even before Retrospect runs).
- B: our own switch as well, which makes the brain send only a neutral line.
- **Lean: A.** Affects the settings notifications page (P23a), PL7.10 and contract 06.

**N2 · Is it all right that a short backup line travels through Apple?**
- The full words are fetched on the phone. But if that fetch fails, something still has to show, so a short backup line written for the person rides with the notification through Apple's servers. It's checked to contain nothing sensitive: no names, health, relationships, money or places. For example: "tuesday, in four minutes".
- A: yes.
- B: no. Then a failed fetch shows "retrospect has something for you." instead.
- **Lean: A.** Affects BE7.4 and BE7.8a.

**N3 · Can the phone's notification key last 7 days?**
- You asked for a short-lived key. The app's normal key lasts 15 minutes, and most notifications arrive hours after the app last ran, so the custom words would rarely show.
- The plan uses a separate key that can only read notification words. It lasts 7 days and is renewed daily.
- A: 7 days.
- B: shorter (say 1 day). Then the words show less often for people who don't open the app daily.
- **Lean: A.** Affects BE7.9b and PL7.12.

**N4 · Which notifications are on by default?**
- **Lean:**
  - the brief: on, but it only sends if the brief itself is on;
  - the weekly episode: on;
  - "one question for you": on;
  - goal check-ins: off.
- Affects BE7.3.

**N5 · At most one notification a day, never between 9pm and 8am, and the less important one is dropped if two are due?**
- Order: episode, then brief, then question, then check-in.
- A: yes, with fixed quiet hours.
- B: let people set their own quiet hours.
- C: carry the lower one to the next day.
- **Lean: A.** Affects BE7.4.

**N6 · When do we ask for permission to send notifications?**
- **Lean:** during onboarding, while the first episode is being made ("i'll write it for you, not a ping"), and again if someone turns the brief on later.
- Affects P05, PL5.1 and PL5.4.

---

## First run (phase 2)

**F1 · Is anything in onboarding behind the paywall?**
- **Lean:** no. The first episode is free. Paid-only features come later.
- Affects BE2.8b.

**F2 · If the first episode has nothing to say (a quiet week), what happens?**
- **Lean:** a quiet line, then skip the tease and the paywall and land on the first home.
- Affects P05 and PL1.9.

**F3 · Suggest goals during onboarding?**
- **Lean:** no. That also lets us drop a door that costs a model call for every new member.
- Affects BE2.1.

**F4 · Which onboarding questions?**
- A: the new set (8 core and 2 fallbacks).
- B: today's 18.
- **Lean: A.** Affects P02.

**F5 · Retro asks one follow-up after each answer, written by the model?**
- **Lean:** not in the first build. It costs about a cent each and adds a wait.
- Affects P02.

**F6 · When does the meter say Retro knows you "a little", "better" or "well"?**
- **Lean:**
  - "a little": fewer than 1 source and fewer than 3 answers;
  - "well": 3 or more sources and 7 or more answers;
  - "better": anything in between.
- Affects BE2.3b.

**F7 · Picking the brief time in onboarding: quick answers or a time wheel?**
- A: quick answers: 7, 8, 9 or "not now".
- B: a time wheel.
- **Lean: A.** Affects P02.2.

**F8 · The splash opening (A, B2, B3 or D)?**
- **Lean: D, "the dots connect".** Affects M01.

**F9 · On the paywall, does the glow slide to the plan being bought?**
- A: yes.
- B: no glow motion.
- **Lean: A.** Affects M07.

**F10 · Notion in the connect step for the beta?**
- Your earlier call was to build it. Confirm it's needed for the beta, or after.
- Affects BE2.9a–d.

**F11 · The old app's "magic moments" line during getting ready?**
- **Lean:** leave it out.
- Affects UI4.1.

---

## Podcasts (phase 3)

**P1 · Episodes offline?**
- **Lean:**
  - the newest weekly episode downloads on Wi-Fi by itself;
  - older episodes download by hand;
  - your listening position is kept on this phone only.
- Affects PL3.4c2 and PLP.3.

**P2 · After an episode: "more like this / less like this" and "say more"?**
- **Lean:** yes. It's not turned into a star rating.
- Affects UI5.4 and BE3.2a/b. It also needs a drawing.

**P3 · When a week is quiet, and when the episode arrives.**
- **Lean:**
  - a quiet week sends no notification and shows a quiet row with the next date;
  - episodes arrive Sunday at 9:00 local time.
- Affects BE3.3a/b.

**P4 · Past daily briefs listed in the podcasts tab, with their audio kept for the life of the account?**
- **Lean: yes.** Affects BE3.6 and BE3.4b.

**P5 · Do episode chapter titles show on the lock screen while playing?**
- **Lean:** only if the person turns on "show what's in your brief on the lock screen", which is off by default.
- Affects PLP.2 and PL7.10.

**P6 · Episodes made by the old app on the phone?**
- **Lean:** carry them over, marked "made on this phone".
- Affects XP.1.

**P7 · When does everyone get the new episode writer (chapters and "why" pages)?**
- **Lean:** at the podcasts ship gate.

**P8 · What's in the player's "…" menu?**
- **Lean:** chapters and download only. AirPlay, a sleep timer and share wait.
- Affects C20-p.

---

## Goals (phase 4)

**G1 · What do the goal numbers count, and over what time?**
- **Lean:**
  - the card covers the last 28 days;
  - the goal page header covers everything since you said it;
  - the rows cover this week;
  - all of them count things ("2 times"), not hours.
- Affects BE4.0a.

**G2 · What can Retro's one line on a goal say?**
- **Lean:** only lines it has earned: "too early", "does more than says", or a real pattern. Never written by the model.
- Affects BE4.0a.

**G3 · "Is that a goal?" questions: where from, and on by default?**
- **Lean:** only from goals you've stated in your own words, with the quote, behind a switch that's off until you turn it on.
- Affects BE4.0d.

**G4 · Can people add a goal by hand with "+"?**
- **Lean:** yes, a small sheet: "what are you working toward?". It needs a drawing.
- Affects UIG.1.

**G5 · Can a goal be marked "done", or deleted?**
- **Lean:** neither in v1. Turning a goal off (with undo) covers both.
- Affects P17.2 and BE4.1b.

---

## You (phase 5)

**Y1 · What does the map show?**
- **Lean:**
  - "themes" are live patterns;
  - at most 10 people, 8 themes and 6 goals;
  - a person with no fact yet shows "comes up n times";
  - "is this the same person?" questions come before guesses.
- You'd draw up to 24 places on the map; Paper has 9 today.
- Affects BE5.5a and C38.

**Y2 · Show your own entries on the journal's entry page, rather than a separate You page?**
- **Lean:** yes. The You page stays for records and saved links.
- Affects UI6.6 and P20.

**Y3 · Where does the written portrait live?**
- **Lean:** behind the "list" pill on You. It needs a drawing.
- Affects UI6.7 and BE5.2.

**Y4 · The big line at the top of a person or theme?**
- **Lean:** the single best-supported fact, with no model call. A written summary waits.
- Affects BE5.1a.

**Y5 · The areas on "what i know"?**
- **Lean:** the brain's 8 areas, with titles you name. Paper's "work / health / family" would need new brain work.
- Affects P22.

**Y6 · Search sources one per item, or grouped ("apple health · 14 nights")?**
- **Lean:** one per item for v1.
- Affects BE5.4b.

---

## Settings (phase 6)

**S1 · Ship the App Store must-haves right after payments, before submission?**
- These are: delete account (with Apple sign-out), restore purchases, and manage subscription.
- **Lean: yes.** Affects the App Store lane.

**S2 · When deleting an account that signed in with Apple long ago, ask Apple to confirm?**
- **Lean:** only when we don't hold their Apple token.
- Affects BE6.6a.

**S3 · "Delete my data" keeps your choices?**
- **Lean:**
  - it keeps: brief on/off and time, ambient, how straight, and voice;
  - it deletes everything learned.
- Affects BE6.6c.

**S4 · Brief length and playback speeds.**
- **Lean:**
  - brief lengths: short, standard and long (about 2, 4 or 6 minutes). Long costs about half as much again in audio;
  - speeds: 0.8, 1, 1.25 and 1.5.
- Affects BE6.1a and BE6.2c.

**S5 · When you turn ambient off for everyone, what do people see?**
- **Lean:** their own switch keeps its value, with the line "paused for everyone right now".
- Affects P27.

**S6 · Where does "your invites" live?**
- **Lean:** a row on settings: "invite friends · 2 left". It needs a drawing.
- Affects PI3.

**S7 · "Where it's processed"?**
- Paper says "europe", but our server's default region is Oregon.
- A: a checked page of places and providers.
- B: drop the row.
- **Lean: A, once it's verified.** Affects P27a.

**S8 · How "download my data" is delivered?**
- **Lean:** a zip saved from the share sheet, and a notification when it's ready.
- Affects BE6.3c.

**S9 · After you pick how straight Retro is, can you hand the choice back ("let it decide")?**
- **Lean: yes.** It needs a drawing.
- Affects C49.

---

## Outside the app (phase 7)

**O1 · A Live Activity on the lock screen while an episode plays?**
- **Lean:** no. The standard lock-screen player is enough.
- Affects P35.

**O2 · What can people share into Retro from other apps in v1?**
- **Lean:** links and text. Images and files come later. "Goes with" offers only Retro's suggestion, or nothing.
- Affects the share extension.

---

## C1 · Copy to approve, in one sitting

- The invite share line ("i saved you a place on retrospect.").
- The hidden-preview line ("retrospect has something for you.").
- The quiet-week line, and the podcasts empty line.
- The feedback thanks.
- The share "saved" line when the brief is off ("it's in your journal.").
- The force-update words.
- The 36 onboarding-style questions rewritten in the second person (for "what i know").
- The You area titles, portrait section titles and search "nothing found" lines; "linked." and "kept apart.".
- The source descriptions in settings, and the voice names (warm, steady, bright).
- The four danger-dialog texts (disconnect, delete what it read, delete my data, delete account).

## Things only you can do (not questions)

- **Apple:**
  - the push key (.p8) and the Sign in with Apple key;
  - confirm the App Store product ids (`retro.monthly`, `retro.yearly`).
- **RevenueCat:** its keys, webhook secret and entitlement.
- **Google:** the sign-in client (after Beta 1).
- **Voice:** three recorded voice samples.
- **Paper:**
  - drawings: the invite's missing screens if B7 = B, the notifications page, your invites, add a source, the goal add sheet, the portrait, and the moment filmstrips;
  - stale text on the paywall and account screens ("$24.99", "$239.99", "save 20%", "$20.00 a month"). The prices are $19.99 and $199.99, "save 17%", "works out to $16.67 a month", and the first month free on yearly.
- **Old pull requests:** close #13 and #14. They build "sign out everywhere", which you've moved to v2, and their database file numbers clash with the new plan's.
