# The iOS refresh: opportunity audit (step 2)

20 October 2026, night. Step 2 of [the iOS refresh plan](./ios-refresh-plan.md). **Every place new functionality can enter the product**: first the whole picture, then screen by screen, each with a very lo-fi mockup. It replaces the stage-2 draft ([ios-v2-opportunities.md](./ios-v2-opportunities.md)), which put several features on one page; this one follows the founder's rule of **one feature per page**.

Inputs: the problem audits ([app-audit.md](./app-audit.md), [app-audit-deep.md](./app-audit-deep.md); 10 blockers, 60 major), the brain's capabilities (the goal spec and what's built in the agent), and the founder's decisions of 20 Oct:
- the bar is **Journal · Podcasts · Goals · You**;
- **You** is search plus a map of your brain (nodes and edges sized by how much they show up);
- onboarding is **voice-first**, opens with **the mission told by voice**, and runs questions → privacy → integrations → more questions → podcast tease → scrollable paywall with every benefit → into the app, with guidance after;
- colour: beige + sky blue, beige calibrated down.

**What this document is not:** final designs. Mockups are boxes and labels, enough to judge what goes where. Step 3 decides the best version of each screen; step 4 builds them mid-fi.

**Founder's yes/no:** each opportunity has an ID (O-1, O-2 …). Mark each yes, no or change.

---

# Part 1: the whole picture

## 1.1 What the brain can do, and what the app shows of it today

| Capability (built in the brain) | In the app today | Reachable by the app today? |
|---|---|---|
| Capture: entries by text and voice | Journal (sends once, no outbox, no confirmation) | yes (`/content`) |
| Weekly episode, with its outline and why each part is there | Podcasts list, all titled "Weekly Insights", unplayable after onboarding | partly (`/podcasts`; outline unused) |
| **Daily brief** about what changed | nothing | **no** (agent only) |
| **Conversation**: talk to it; replies may be silent | nothing | **no** (agent only) |
| **Search** across everything, sources then a written answer | nothing | **no** (agent only) |
| **What it knows about you**: 36 answers, how sure, the quotes behind them | nothing | **no** (no endpoint anywhere yet) |
| **Corrections**: "that's not me", "still true", changed vs wrong | two backend buttons on old graph routes | partly (`/graph/.../feedback`; the new `/corrections` is agent only) |
| **Goals** as the brain sees them: active, expired, merged; said vs did | Goals shows the phone's list, which overrides the brain | partly (`/goals` exists; the brain's view and said-vs-did don't) |
| **Patterns**: what keeps happening, stronger or weaker | nothing | **no** |
| **People**: who's in your life; "is this the same person?" | nothing | **no** (agent only) |
| **Hypotheses**: what it's wondering, with a framework | nothing | **no** (agent only) |
| **How bold** (appetite), with a first guess from your words | nothing | **no** (agent only) |
| **What it's learned** about how you like things | nothing | **no** (agent only) |
| **Saved links** with your reason; video transcripts | nothing (no share extension) | **no** |
| **Actions** it prepares for your approval | nothing | **no** (agent only) |
| **Sources**: what each read, when, what it's for | Integrations & Data (engineering labels) | yes (`/integrations`) |
| **Ambient switch**: read connected apps in the background, or not | nothing | **no** (agent only) |
| **First-episode readiness** (real stages) | a fake percentage | **no** (agent only) |
| Voice (ElevenLabs, proxied) | first-episode audio only | yes (`/speech/synthesize`) |

**The headline:** most of what the brain now does can't reach the app at all. The agent's routes are internal (they need the server's secret), and the backend the app talks to passes through only content, goals, podcasts, profile, speech, integrations and an old graph. **Opportunity O-0 is the foundation for everything else:** a backend route, behind the person's sign-in, for each capability the app needs (search, conversation, briefs, understanding, corrections, people, hypotheses, actions, settings, readiness, links).

## 1.2 The shape, in one picture

```
ONBOARDING (voice-first, one conversation)
  Mission (voice) → Questions → Privacy → Connect → More questions
     → First episode plays (tease) → Paywall rises, scroll for every benefit
     → Into the app → Guidance

THE APP  (one feature per page)
 ┌──────────┬──────────┬──────────┬──────────┐
 │ Journal  │ Podcasts │  Goals   │   You    │
 │ write ·  │ listen · │ yours ·  │ search · │
 │ talk ·   │ why it's │ said vs  │ the map  │
 │ brief    │ in it    │ did      │ of you   │
 └──────────┴──────────┴──────────┴──────────┘
  Outside the bar: Share to Retrospect (from any app) · notifications
  · widget and Live Activity · settings (behind your picture on You)
```

## 1.3 Where each capability lives (one owner each)

| ID | Capability | Owner page | Why there |
|---|---|---|---|
| O-1 | Capture (text and voice) | **Journal** | writing is what Journal is for |
| O-2 | Conversation | **Journal** | founder: journal and chat are one page; a reply is the natural answer to an entry |
| O-3 | **Daily brief = the day's episode** (founder, 20 Oct): an audio briefing | **a card at the top of Journal** you press play on; it also lists under Podcasts | it's the first thing of the day; it keeps playing when you close the app or lock the phone |
| O-4 | Weekly episode, outline, "why this is here" | **Podcasts** | listening |
| O-5 | Episode feedback, and the question an episode asks | **Podcasts**, under the player | answered where it was asked |
| O-6 | Goals: the brain's view, said vs did, add, rename, turn off, revive | **Goals** | its own page |
| O-7 | Search: sources first, then a written answer | **You** | founder: search and You are combined |
| O-8 | The map: people, places, projects, goals, themes, sized by presence | **You** | founder |
| O-9 | What it knows (the 36 answers, how sure, the quotes) | **You**, inside the map (regions or a layer) | it is the picture of you |
| O-10 | Corrections | wherever a claim appears; filed under **You** | a claim is fixed where you see it |
| O-11 | Patterns | **You**, as clusters on the map | they are shapes in your life |
| O-12 | People and "same person?" | **You**, as nodes waiting for an answer | people are nodes |
| O-13 | Hypotheses ("what it's wondering") | **You**, as nodes waiting for an answer; one at a time in an episode | they're guesses about you |
| O-14 | Saved links (with your reason, transcripts) | **You**, as nodes tied to goals; saved via the share sheet | they belong to what they bear on |
| O-15 | Actions it prepared | **Journal**, as a reply that asks to approve | it was asked for in conversation |
| O-16 | How bold | **onboarding** (first guess), then settings | a preference |
| O-17 | Sources, privacy, ambient, delete | **settings**, behind your picture | control, not daily use |
| O-18 | What it's learned | **settings** (transparency) | rarely visited |
| O-19 | Voice (the app talks) | onboarding, conversation, the brief | one voice everywhere |
| O-20 | Guidance for a new person | each page's first-visit state | one feature per page means each page teaches itself |

## 1.4 Opportunities that cut across pages

| ID | Opportunity | Fixes |
|---|---|---|
| O-0 | Backend routes for every capability above, behind sign-in | the gap in 1.1 |
| O-21 | **An outbox:** every capture is saved, sent, confirmed ("read by the brain"), retried, never lost; edits and deletes reach the server | J1–J3, Y4, Y5, Y12, Y29 |
| O-22 | **Plain states everywhere:** loading, empty, error, slow, offline, each named in words with a next step | A1, X3, Y28, Y30, Y51 |
| O-23 | **The server owns the brain's data**; the app sends intents | G1, Y17, Y18 |
| O-24 | **Audio that plays, and keeps playing:** stream or download every episode and brief; play continues with the app closed or the phone locked; lock-screen and Control Center controls; a now-playing Live Activity. (Background audio is already switched on in the app's settings; the lock-screen controls aren't built: 0 uses of `MPNowPlayingInfoCenter`) | N20, Y26 |
| O-25 | **One navigation model:** a bar, standard swipe-back, sheets that close by swiping down | Y11, Y14, Y27, Y35 |
| O-26 | **Accessible by default:** Dynamic Type, VoiceOver labels, 44-pt targets, reduced motion, light and dark | Y36–Y40 |
| O-27 | **Layout that fits any phone** (no fixed-picture screens) | Y41 |
| O-28 | **Nothing for developers in the shipped app**; demo content only in the demo account | T1–T6, N1, L2, L6 |
| O-29 | **Real subscriptions** (StoreKit, server-checked), a way out of the paywall, working Privacy and Terms | N19, L3, L4 |
| O-30 | **Notifications that lead somewhere real**: brief ready, episode ready, something to approve, a question waiting | A6 |
| O-31 | **Share to Retrospect** from any app, asking "why are you saving this?" | — (new) |
| O-32 | **Widget and Live Activity:** capture in one tap; now playing | — |

---

# Part 2: screen by screen

Each screen lists: its **one feature**; **today** (the closest current screen and its worst problems); the **opportunities** that enter it; **what it gives and what it asks**; **server** (✓ exists for the app, ◐ exists in the brain only, ✗ to build); and a **lo-fi mockup**.

## Onboarding

### S1. The mission (voice)
- **One feature:** say what Retrospect is for, before asking anything.
- **Today:** "Your life, turned into a weekly podcast" (the old promise, W1), then a sign-in button.
- **Opportunities:** O-19 voice; the mission in the person's terms, under 30 s, every word true today; skippable, replayable, works muted.
- **Gives:** understanding and a reason to trust. **Asks:** nothing.
- **Server:** ✓ `/speech/synthesize` (or pre-recorded, since the words are the same for everyone).

```
┌───────────────────────────┐
│                           │
│        (the mark)         │
│                           │
│  "Retrospect is a mind    │
│   that gets to know you…" │  ← words appear as spoken
│                           │
│        ∿∿∿ speaking       │
│                           │
│  [ Continue ]   Replay ↺  │
└───────────────────────────┘
```

### S2. Sign in
- **One feature:** create the account.
- **Today:** a restyled Apple button; "Retrospect-2026" in Apple's sheet; no feedback on tap (W3, W6, W7).
- **Opportunities:** Apple's standard button; Google sign-in that also connects Google (ios-v2 change 11); a pressed state; plain errors.
- **Asks:** one tap. **Server:** ✓ `/auth/signin`; ✗ Google sign-in.

```
┌───────────────────────────┐
│  "To remember you,        │
│   I need an account."     │
│                           │
│  [  Sign in with Apple  ] │
│  [ Continue with Google ] │
│    (also connects Google) │
└───────────────────────────┘
```

### S3. The conversation: questions (voice-first)
- **One feature:** get to know the person by talking.
- **Today:** 18 typed questions, demographics first, orientation, a dream house; answers lost on close; the same "Thank you. That helps." each time (V1–V5, N6, N9, O2).
- **Opportunities:** voice in and out; the 8 story questions + goals and aspirations asked to inspire; a real acknowledgement that proves it heard; one follow-up when it would settle a lot (v2 idea); each answer saved instantly; Back always works; the name taken from Apple.
- **Gives:** the feeling of being heard. **Asks:** stories, not data. **Server:** ◐ `/onboarding/advance`, `/onboarding/interpret`; ✓ `/speech`.

```
┌───────────────────────────┐
│ ‹ Back            3 of 8  │
│                           │
│  "Tell me about a moment  │
│   this year you felt most │
│   like yourself."         │
│                           │
│      ◉ listening…         │  ← haptic tick on start/stop
│  "…it was the morning I…" │  ← live transcript
│                           │
│  [ type instead ]  [Done] │
└───────────────────────────┘
```

### S4. Privacy, shown off
- **One feature:** earn trust before asking for data.
- **Today:** missing; old dead screens make false claims (D1).
- **Opportunities:** a voiced callback ("here's why I ask"); what it reads, where it's processed (our server + named AI providers), what it never does; the ambient switch; delete anytime.
- **Asks:** one choice (ambient on/off). **Server:** ◐ `/settings/ambient`.

```
┌───────────────────────────┐
│  What I read   · only what│
│                  you connect
│  Where         · our server
│                  + named AI │
│  Never         · sold, ads │
│                           │
│  Read in the background?  │
│  ( on )  ( only what I    │
│            send )         │
│  Delete everything anytime│
│           [ Continue ]    │
└───────────────────────────┘
```

### S5. Connect
- **One feature:** connect the sources that help it understand.
- **Today:** 17 cards, three for Google, engineering labels, file imports mid-flow; "Make my podcast" just moves on (C1–C10, N14, N15).
- **Opportunities:** up to 5 recommended sources, each saying what it helps it understand; one Google card; plain states; "Not now" per source; **the first episode starts here** (one, not two).
- **Server:** ✓ `/integrations`; ◐ readiness; ✗ one-first-episode guard.

```
┌───────────────────────────┐
│  "These let me see what   │
│   words can't."           │
│  ┌─────────────────────┐  │
│  │♥ Health  → your      │  │
│  │  sleep and energy   ✓│  │
│  ├─────────────────────┤  │
│  │▦ Calendar → the shape│  │
│  │  of your weeks  [Add]│  │
│  ├─────────────────────┤  │
│  │G Google → mail, docs,│  │
│  │  calendar     [Add]  │  │
│  └─────────────────────┘  │
│  More sources ›           │
│           [ Continue ]    │
└───────────────────────────┘
```

### S6. More questions (voice)
- **One feature:** fill what the sources won't tell it.
- **Opportunities:** questions chosen *after* seeing what was connected (it never asks what a source will say); how bold, with our guess preselected (O-16); how they like to listen.
- **Server:** ◐ `/onboarding/advance`, `/settings/appetite` (with `suggested`).

```
┌───────────────────────────┐
│  "How straight should I   │
│   be with you?"           │
│  ○ Gentle                 │
│  ● Honest, kindly  ← our  │
│  ○ Direct            guess│
│  ○ Push me                │
│  "You said you want to be │
│   challenged, so I picked │
│   this."     [ Continue ] │
└───────────────────────────┘
```

### S7. Your first episode (tease)
- **One feature:** the first thing it gives back.
- **Today:** "Learning about you" with an invented percentage and canned claims about you (A5, N1, N23).
- **Opportunities:** real stages from readiness; a line from their own answers while they wait; it plays inside onboarding; the voice callback "here's what that was for".
- **Server:** ◐ `/onboarding/readiness`; ✓ `/podcasts`.

```
┌───────────────────────────┐
│  Reading your calendar  ✓ │
│  Writing your episode   ◌ │
│  Recording the voice      │
│                           │
│  "You said the mornings   │
│   are when you think      │
│   best."  ← their words   │
├───────────────────────────┤
│  ▶ (plays when ready)     │
│  transcript, line by line │
└───────────────────────────┘
```

### S8. The paywall (scrollable, every benefit)
- **One feature:** the choice to subscribe.
- **Today:** a fixed picture shrunk to fit; no way out in release; placeholder prices; dead Privacy link (N19, L3, L4, Y41).
- **Opportunities:** the episode slides up and the page scrolls to **every benefit** (the daily brief, the weekly episode, search and the map, goals, the conversation); real StoreKit prices; "Not now"; Privacy and Terms; restore.
- **Server:** ✗ StoreKit + server-checked receipts.

```
┌───────────────────────────┐
│  ▶ episode (mini, fading) │
│  "Subscribe to hear the   │
│   rest, and one every     │
│   week."                  │
│  [ Monthly ] [ Yearly  ]  │
│  Not now                  │
│ ─ scroll ──────────────── │
│  ◇ A brief every morning  │
│  ◇ An episode every week  │
│  ◇ Search your own mind   │
│  ◇ Goals: said vs did     │
│  ◇ Talk to it anytime     │
│  Restore · Privacy · Terms│
└───────────────────────────┘
```

### S9. Into the app, with guidance
- **One feature:** the first step in the app.
- **Today:** an empty Journal (Y1).
- **Opportunities:** each tab's first-visit state teaches its one feature (O-20): Journal asks "Tell me about today", Podcasts shows the first episode, Goals shows what it heard, You shows the first few nodes.

## The app

### S10. Journal (write · talk · brief)
- **One feature:** say what's on your mind, and hear back.
- **Today:** a faint prompt on an empty page; half-written thoughts sent on leaving; no confirmation; a fake "next episode in 3 days" (Y1–Y6, L6, J1).
- **Opportunities:** O-1 capture by voice or text; O-2 replies (sometimes silent); O-3 **today's brief as a card at the top: press play and it briefs you, and it keeps playing when you close the app** (background audio, lock-screen and Control Center controls, a now-playing Live Activity); O-15 actions to approve as replies; O-21 each entry shows sent → read by the brain; your entries as a thread you can scroll back through; drafts kept, never auto-sent.
- **Server:** ✓ `/content`; ◐ `/conversation`, `/briefs`, `/actions`.

```
┌───────────────────────────┐
│ Journal             🎙    │
│ ┌ Today · your brief ──┐  │
│ │ ▶  3 things · 2 min   │  │
│ │ keeps playing if you  │  │
│ │ close the app         │  │
│ └───────────────────────┘ │
│  Mon                      │
│  You: slept badly, long…  │
│                 ✓ read    │
│  Retrospect: That's the   │
│  third Monday like this.  │
│  Want me to move your     │
│  10am?   [Approve] [No]   │
│                           │
│ ┌───────────────────────┐ │
│ │ Tell me…        🎙 ↑  │ │
│ └───────────────────────┘ │
│ [Journal] Podcasts Goals You
└───────────────────────────┘
```

### S11. An entry
- **One feature:** read, edit or delete one thing you said.
- **Today:** the date as a 3-line title, your words smallest; no edit, no delete, no swipe-back (Y9–Y12).
- **Opportunities:** your words first; edit and delete that reach the server (O-21); "what it took from this" (the facts it drew, each correctable, O-10).
- **Server:** ✓ `/content` (✗ edit/delete routes).

```
┌───────────────────────────┐
│ ‹                ⋯ edit   │
│ Slept badly, long day of  │
│ meetings, felt flat.      │
│ Mon 20 Oct · 2:27         │
│ ─ What I took from this ─ │
│ · sleep was poor   ✕ wrong│
│ · meetings drain you  ✕   │
└───────────────────────────┘
```

### S12. Podcasts
- **One feature:** listen to your episodes: the weekly episode and each day's brief.
- **Today:** every episode titled "Weekly Insights", unplayable, two play buttons per row, no refresh (Y22–Y26, Y30, Y31).
- **Opportunities:** O-4 real titles, this week's as the hero; O-24 audio that plays; past episodes; pull to refresh; new-episode notification (O-30).
- **Server:** ✓ `/podcasts`.

```
┌───────────────────────────┐
│ Podcasts                  │
│ ┌ This week ────────────┐ │
│ │ The week you stopped  │ │
│ │ rushing   · 12 min  ▶ │ │
│ └───────────────────────┘ │
│ Earlier                   │
│ What the Sunday calls… ▶  │
│ Your first episode     ▶  │
│ Journal [Podcasts] Goals You
└───────────────────────────┘
```

### S13. The player
- **One feature:** listen to one episode and understand it.
- **Today:** silent, no title, exit drawn as a menu icon, "…" does nothing (Y26, Y27).
- **Opportunities:** title, date, chapters, speed; the transcript following along; "why this was in it" per chapter (the outline); the episode's one question as Yes / No / Why? (O-5, O-13); feedback; swipe down to close.
- **Server:** ✓ `/podcasts/:id`; ◐ `/feedback`, `/hypotheses`.

```
┌───────────────────────────┐
│ ⌄                1x  ⋯    │
│ The week you stopped      │
│ rushing                   │
│ ── Ch 2: Mornings ──      │
│ "…three of your best days │
│  started before 8…"       │
│ Why this is here ›        │
│ ━━━━━━○──────── 4:12      │
│     ↺15    ▶    15↻       │
│ ┌ It asked ─────────────┐ │
│ │ Are mornings when you │ │
│ │ do your best work?    │ │
│ │ [Yes] [No] [Why ask?] │ │
│ └───────────────────────┘ │
└───────────────────────────┘
```

### S14. Goals
- **One feature:** your goals as the brain sees them.
- **Today:** the phone's list overrides the brain; one add sends eight writes; the screen jumps under the clock (G1–G3, Y17–Y21).
- **Opportunities:** O-6 active, expired, merged; said vs did as two numbers; what it noticed for each; add by voice or text (an intent); rename, turn off, revive; the goals heard in onboarding, shown as heard.
- **Server:** ✓ `/goals` (✗ the brain's view, said-vs-did, intents only).

```
┌───────────────────────────┐
│ Goals               +     │
│ ┌ Ship the first version┐ │
│ │ said 6× · did 4× wk   │ │
│ │ ▁▃▅▆ stronger         │ │
│ └───────────────────────┘ │
│ ┌ Sleep before midnight ┐ │
│ │ said 3× · did 1×      │ │
│ │ "You've been up past  │ │
│ │  1 four nights."      │ │
│ └───────────────────────┘ │
│ Faded · 2   Merged · 1  › │
│ Journal Podcasts [Goals] You
└───────────────────────────┘
```

### S15. You: search and the map
- **One feature:** see (and ask about) the picture it has of you.
- **Today:** nothing.
- **Opportunities:** O-7 search; O-8 the map sized by presence; O-9 the 36 answers as regions; O-11 patterns as clusters; O-12/13 nodes waiting for an answer; O-14 saved links tied to goals; settings behind your picture.
- **Server:** ◐ `/search`, `/people/held`, `/hypotheses`; ✗ a graph read endpoint, ✗ "what I know about you".

```
┌───────────────────────────┐
│ (pic)        You          │
│ ┌ Ask anything ───── 🎙 ┐ │
│ └───────────────────────┘ │
│        ◯ Priya            │
│   ●────────⬤ Work         │
│  Sleep ●     \            │
│        ◯ Sam? ← waiting   │
│     ●Running   ⬤ Ship v1  │
│ (size = how much it shows │
│  up; tap a node)          │
│ Journal Podcasts Goals [You]
└───────────────────────────┘
```

### S16. Search results (on You)
- **One feature:** an answer from your own mind, with its sources.
- **Opportunities:** sources first (~1 s), then the written answer with numbered citations; the matching part of the map lit; open any source; "that's not right" on any line (O-10); abstains when it doesn't know.
- **Server:** ◐ `/search/sources`, `/search/answer`, `/search/:userId/source/:kind/:id`.

```
┌───────────────────────────┐
│ ‹ "when do I sleep best?" │
│ What I found              │
│ After days you run [1],   │
│ and when you stop work    │
│ before 9 [2].  ✕ not right│
│ Sources                   │
│ [1] Health · 14 nights    │
│ [2] Journal · 3 entries › │
│ (map below, lit)          │
└───────────────────────────┘
```

### S17. A node (on You)
- **One feature:** everything it knows about one thing, and why.
- **Opportunities:** what it believes, how sure, the quotes behind it; "that's not me" / "still true"; linked nodes; for a person, "same person?"; for a goal, said vs did; for a pattern, stronger or weaker.
- **Server:** ◐ `/corrections`, `/people/held`; ✗ node detail endpoint.

```
┌───────────────────────────┐
│ ⌄  Priya                  │
│ Comes up 14× this month   │
│ ─ What I think ─          │
│ A close colleague; you    │
│ feel better after talking │
│ fairly sure ●●●○          │
│ "had coffee with Priya,   │
│  felt lighter" · 12 Oct   │
│ [Still true] [Not right]  │
│ Linked: Work · Ship v1    │
└───────────────────────────┘
```

### S18. Settings (behind your picture)
- **One feature:** control.
- **Today:** dev tools for everyone, settings that do nothing, a surprise permission ask (T1–T6, L9–L11).
- **Opportunities:** O-17 sources (last read, what for; file imports with instructions; YouTube history), privacy and ambient, delete data and account; how bold; voice; brief on/off; subscription; what it's learned (O-18). Nothing for developers.
- **Server:** ✓ `/integrations`, `/profile`; ◐ `/settings/*`, `/preferences`.

```
┌───────────────────────────┐
│ ‹ Settings                │
│ Sources        4 · 1 needs│
│                attention ›│
│ Privacy & background  On ›│
│ How bold     Honest, kind›│
│ Voice          Warm      ›│
│ Daily brief    Off       ›│
│ Subscription   Yearly    ›│
│ What I've learned        ›│
│ Delete my data           ›│
└───────────────────────────┘
```

### S19. Share to Retrospect (from any app)
- **One feature:** save something, with your reason.
- **Opportunities:** O-31; "Why are you saving this?" (voice or text); it ties to a goal if one fits; transcripts for videos.
- **Server:** ✗ share extension + a backend route to the reference store.

```
┌───────────────────────────┐
│ Save to Retrospect        │
│ youtube.com/… "How to …"  │
│ Why are you saving this?  │
│ ┌───────────────────🎙┐   │
│ └─────────────────────┘   │
│ Goes with: Ship v1 (▾)    │
│               [ Save ]    │
└───────────────────────────┘
```

### S20. Notifications, widget, Live Activity
- **Opportunities:** O-30 brief ready / episode ready / something to approve / a question waiting, each opening the right page; O-32 a capture widget and now-playing.
- **Server:** ◐ `/notifications/generate`; ✗ push delivery wiring.

---

# Part 3: what has to be built for this

| Layer | Work | Size |
|---|---|---|
| Backend | Routes behind sign-in for search, conversation, briefs, corrections, people, hypotheses, actions, settings, preferences, readiness, feedback (proxies to the agent) | medium (many, each small) |
| Backend | Entry edit and delete that reach the brain; one first episode per person | small |
| Agent | A graph read endpoint for the map; a "what I know about you" read; node detail | medium |
| Agent | Goals: the brain's view and said-vs-did, exposed | small–medium |
| App | Outbox, plain states, audio download/stream, navigation model, accessibility, layout | (step 4) |
| App | Share extension; widget; push | medium |
| Store | StoreKit products, server-checked receipts | medium |

## Open for the founder

1. Each opportunity O-0 to O-32: yes, no or change.
2. ~~The daily brief's home~~ decided: a play card at the top of Journal, listed under Podcasts, keeps playing in the background.
3. Actions as replies in Journal (O-15): right home?
4. The 36 answers as regions on the map (O-9), or a separate list view under the map?
5. Voice everywhere it speaks: the same voice as the podcast host, or a separate "app" voice?
