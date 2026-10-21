# mid-fi approach · the whole product

20 Oct. The plan level of the design engineering process (goals doc §7, step 4 of §8): every screen and flow at mid fidelity, the proposed solution, before tokens and components are applied. Grey boxes and real words. Approved by the founder at the plan gate, then built bottom-up.

## A. What I took stock of
- The goals doc in full (§1 goal, founder decisions 20 Oct, Paper comments, §2 problems, §3 opportunities and the founder's change list, §4 the new version and principles, §5 flows and pages, §6 design rules, §7 process, §8 build order).
- The blueprint (screen-by-screen, states, K gaps).
- Everything the founder said in chat and in Paper comments (this session and the summary of the last), the memory notes, and `design-system/principles/screen-rules.md`.

## B. The instruction ledger (latest word wins)

**Product and brain**
1. A brain that comes to know you and gives it back as something worth listening to; least taken, fewest questions, most value. Every screen helps it learn, shows what it learned, or gives back something that makes life better.
2. Ambient by default: the default user sends nothing; every tab opens on something already made for you, never an empty box.
3. Evidence → a question → your answer; never a verdict. Facts stated; guesses asked, with how sure and what they rest on.
4. The server owns the brain; the app sends intents. Nothing written is lost; saved → sent → read on every capture.
5. Every wait names what it's doing; every failure says what happened and what's next. No developer tools. No demo content outside the demo account.
6. The daily brief is your inbox: what you send leads it, each item with why.

**Retro**
7. The voice is called Retro: "hello, my name is Retro." Cheeky, excited, honest; wants to understand you and help you live better; information is power; reflection is core.
8. Not a companion, not a person, and it says so; omniscient, never human; respects privacy. No claims about actions (the action slot stays empty).
9. Voice generated live, per person, on the best model; chosen during development. No canned hosts; voice creation later.

**Onboarding**
10. North star: tap → something pretty → sign in → start talking, the fastest-learning questions → privacy and connect as strong purpose displays, still asking → when ready, the tease → the paywall → home (briefs, search your mind, everything else).
11. The splash is the sign-in (K1 constellation). Sign in with Apple standard; Google white raised with a warm hairline; Google asks for everything at once, Gmail included.
12. Voice-first: talk default, a quiet way to type; the iOS feel: one question per screen, haptics, the onboarding text-question pill bar, mute in its corner.
13. Up to 20 turns, stopping when ready; acknowledgements get deeper and more specific; at most one follow-up.
14. Goals from gentle aspiration questions (what you want, regret, are looking for), asked so people feel seen; Retro asks what news they follow.
15. Questions: the set in §5 (0–8, f1–f2), opening inspiring, heavier once trust is built, ending warm.
16. Privacy: one title, one description, one visual; says certain companies process data, moving on-device, never sold; a compliant policy behind it; no separate background consent.
17. Connect: the whole launch set on one page (no "more sources" page, no "skip for now"); real logos; obvious connect actions; a "what Retro can see" meter.
18. How straight: Retro's recommendation first with the reason, the others as options.
19. The brief is on by default (founder testing), 4–5 min, cap 12; notification permission asked in the conversation when the brief is set; local time.
20. First episode about 5 min, arrives without a tap; the paywall rises at its strongest line (~30–40 s). $19.99/mo, $199.99/yr (~17%); no trial; "not now" keeps journal, talk and search, no listening.
21. Global smooth progress bar; quiet back; no skip.

**The app**
22. A bottom bar: Journal · Podcasts · Goals · You; one feature per page, shown off fully; guidance on first visit.
23. Retro replies in Journal when it has something worth saying.
24. Podcasts: episodes and briefs as tiles; tiles respond to scroll; the player sheet shows the page behind it; title in the inky face.
25. Goals: an indicator of how Retro sees you moving toward each; said vs did; "too early to tell" is a designed state.
26. You: search plus the map; day one is a ghosted, personalised outline ("I'm learning about you"), honestly labelled; a clean reader for saved articles, PDFs and transcripts.
27. Share to Retro: links, text, images, PDFs; if no reason, Retro asks, then learns to infer.
28. Face ID on by default with passcode fallback. Notifications always about you: brief ready, weekly episode, a question (max one a day).
29. Light and dark following the phone (drawn light first); iPhone only, iOS 26+.

**How screens look and read (screen rules)**
30. One title, nothing above it, at most one plain description. Almost no mono. Content inky and big; support plain.
31. Your spoken words appear on the page, blurring in.
32. Blue only for the one lit action, listening, links in text; secondary actions are raised neutral pills.
33. Progressive blur where scroll meets a bottom element. Keep the progressive blurs and the selection controls.
34. Every screen purpose-built, its purpose shown visually before a word is read; the paywall moment (1.22 s) is the motion language; keep the shader's dots, never over text.

**Process**
35. Plan top-down in mid-fi (flow → page → component → sub-component), approved at the gate, then build bottom-up with a written pass at every level; tokens are part of building.
36. Best solution per screen, with why. Check in every chunk; ask, don't assume; handle every Paper comment and log it.

## C. Conflicts, resolved
- Brief "off by default" (§4, blueprint) vs founder decision "on by default": **on**, founder decision wins.
- "Not now per source" (blueprint) vs "remove skip for now; connecting is core": **no skip**; a source you don't want is simply left unconnected, and Continue is always there.
- ON-7 More sources (blueprint) vs "all on one page": **merged into Connect**.
- Gmail "asked later in context" (§4) vs "Google asks for everything at once, Gmail included": **at once**, with a note that Gmail waits on Google's verification.
- Persona hosts vs no canned hosts: **one Retro voice**; voice creation later.

## D. The approach
1. **Flows first.** One strip per flow from §5, each page with the move between it and the next: onboarding; a normal day; the weekly episode; searching and deep-diving; correcting something; sharing in; messaging Retro; connecting or fixing a source; privacy and deletion; subscribing, restoring, lapsing; and every failure path.
2. **Then each page, as the best solution.** Each mid-fi screen is a phone with grey boxes and real words, and a note under it:
   - **purpose** in one line,
   - **why this solution**: the options weighed and why this one, against the ledger,
   - **needs**: the components each region uses (existing or new),
   - **states**: every state it can be in; the ones that change the layout are drawn as small variants beside it (loading, empty, error, offline, day one),
   - **ledger + goals doc**: the items it satisfies and the problems it closes.
3. **Then components and sub-components.** A list per page, marked existing or new, with each new one's parts (restraint check: nothing said twice).
4. **Gate.** You review the flow strips and pages; approve order and purposes. Only then are tokens and components applied (the hi-fi already drawn is kept as the reference for the look).
5. **Every screen is checked against B before it is shown to you.**

**Order and check-ins:** (1) onboarding + account, (2) Journal, (3) Podcasts + player, (4) Goals, (5) You, (6) Settings, (7) outside the app + failure paths. A check-in after each.

## E. Pages (from §5 and the ledger)
- Onboarding: splash + sign-in · hello (mission) · your name · Retro replies · a year from now · lately · news · privacy · connect · what you care about · one thing to change · how straight · your brief + notifications · getting ready · the tease · the paywall · home first visit (+ the fallback questions f1/f2, failure paths).
- Account: sign in (returning) · signing out.
- Journal: Journal · today's brief · all entries · an entry.
- Podcasts: Podcasts (tiles) · the player · why this is here.
- Goals: Goals · a goal.
- You: the map (day one ghosted) · search results · a source (the reader) · a node · what I know about you · a question waiting.
- Settings: settings · daily brief · sources · a source · privacy · how straight · voice and listening · what I've learned · account and subscription.
- Outside: share to Retro · lock screen now playing · notifications · widget.
