# First run: every piece to PR level

The area that turns a stranger with a friend's link into a member with a first episode ready. Contract: [01-first-run.md](../../contracts/01-first-run.md) (fixtures in `contracts/fixtures/01/`). Cards: [views.md](./views.md), [platform.md](./platform.md), [backend.md](./backend.md). Tree for the build board: [tree.json](./tree.json).

**Bottom line.** 87 PRs: 50 views, 16 Platform (4 of them the integrator's shared-file bytes), 21 backend (4 only if Notion is in). **20 are Beta 1** (the invite and M14: 14 views, 4 Platform, 2 backend); the rest is phase 2. 12 pages, 16 components. The invite (PI1) and M14 (PI2) were checked value by value against the round 2 board in Paper on 21 Oct.

## 1. The big picture

**For the person:** *"a friend kept a place for me. I signed in, a ticket printed, I tore it off, and I was in. Then Retro asked me a few real questions, told me plainly what it does with my data, and while I kept talking it made me a short first episode about my week. I heard the start, decided to become a member (or not yet), and landed in my journal with the episode waiting."*

The founder's words that set the bar: *"you've just been given a gift, don't waste it."* M14 must feel like being handed something precious.

Product principles that apply here:
- **The claim ladder, and "when uncertain, withhold".** The first episode can end quiet ("i don't have enough to make it true yet"), never padded (BEA.8; contract §13 Q3).
- **Guesses asked, never asserted.** ON-9 leads with Retro's recommendation *and its reason*, and you choose.
- **No invented data.** The ticket shows the inviter's name only when the server says the code is live; the recap shows your words, never a summary; the knows-you meter moves only on a server answer; prices only from the store.
- **One lit object per screen.** None on the gate's T1 (Apple's button leads), "begin" at the end of M14, the composer's send in the questions, "continue" on connect once something is connected, the yearly plan on the paywall, the brief card's play on first home.
- **Nothing outward without the founder; nothing personal in logs.** Invite codes, inviter names and answers never appear in logs, analytics or test output.
- **Every notification is written for the person and the moment** (founder, 21 Oct): first run only triggers its one push; the words come from the outside plan's writer.

## 2. Flows

Entry points: an invite link (universal link `retrospect-api.onrender.com/i/<code>` → the router → `InviteCenter`), the app icon (fresh, returning, mid-onboarding), a notification ("your first episode" note), an old version (force update).

1. **The invite, by link** (Beta 1): link → T1 "priya kept a place for you." (public preview) → sign in with Apple → check (nothing spent) → the ticket prints (T2a) → swipe along the line (T2, T3) → redeem at separation → T4 "it's yours." → T5 "you're in, sam." → begin → (Beta 1) the current onboarding · (phase 2) ON-3.
2. **The invite, typed** (Beta 1): sign in with no link → T-alt: type the 13 characters → check → the tear unlocks → as above. Wrong code: the stub shakes and clears. No code: "join the waitlist" → joined ("you're on the list.").
3. **Refusals** (Beta 1): used / expired → the ticket prints with "already used" and no handle → the waitlist; suspended → "your account is paused."; a member opening a link → "you're already in." toast.
4. **Failures inside M14** (Beta 1): offline before print → "waiting for a connection", prints when back; offline at the tear → springs back, "nothing was used"; app killed mid-tear → whole again; killed after the tear → "you're in" still; redeem lost response → retried with the same key, same answer.
5. **Sign in** (phase 2): splash (ON-1/2) → Apple or Google → the resolver: waitlisted → the gate; approved → ON-3 (resuming at the first unanswered question); member → home. Returning after sign-out → AC-1 → restoring → where you were. Old version → PX over everything.
6. **Getting to know you** (phase 2): ON-3 talk or type → the 8 core questions (one per screen, voice first, typing any time) → ON-5 privacy (read aloud) → ON-6 connect (meter: a little → better → well) → ON-7 fallbacks only for missing sources → ON-8 daily brief on/off and time → ON-9 how straight (Retro's pick first). Offline: questions keep coming (they're on the phone), answers wait in the outbox.
7. **The first episode** (phase 2): ON-10 one more warm question while the job runs (reading → writing → voicing), with your new words popping in as tags; "want a note when it's ready?" → Apple's prompt only after "tell me" → ready → ON-11 the tease plays → M06: the player shrinks into a paused pill and the paywall rises. Quiet → ON-13 with the quiet line. Failed → "try again". Leaving the app → the written note brings you back.
8. **Membership** (phase 2): yearly (first month free) or monthly at Apple's localized price; restore; not now → ON-13 (no second paywall). Pending (Ask to Buy), cancelled, failed, offline each said in words.
9. **First home** (phase 2): the journal on day one, "your first episode is ready" card pops once, the setup recap, `onboarding/complete` makes you a member.

The first time versus the hundredth: M14 plays once per account (a relaunch before "begin" shows it still); first home's pop once per account on this phone; the push ask once ever; AC-1 only after a sign-out.

## 3. The tree (area › flow › page › component › sub-component › PR)

Leaves are PRs: **id** title · size · side · B1 (Beta 1) · needs. Full cards in the side files.

Counter({'views': 50, 'backend': 21, 'platform': 16}) Counter({('views', False): 36, ('backend', False): 19, ('views', True): 14, ('platform', False): 12, ('platform', True): 4, ('backend', True): 2}) 87
- the invite (Beta 1)
  - PI1 · the invite gate
    - **C43** sign-in buttons (Apple, Google) · S · views · B1 · needs T01, PL1.4a
    - **PI1** invite gate page · M · views · B1 · needs UI4.0, C43, C41.4, C42
  - PI2 · M14 you're in
    - C41 · the invite ticket
      - **C41.1** ticket shape and shadow · M · views · B1 · needs FR0.1, #55
      - **C41.2** ticket face · S · views · B1 · needs C41.1, #42
      - **C41.3** perforation and tear handle · M · views · B1 · needs C41.1
      - **C41.4** stub and code tiles · M · views · B1 · needs C41.1
      - **C41.5** torn halves · S · views · B1 · needs C41.3, C41.4
    - **C42** printer slot · S · views · B1 · needs C41.1, FR0.1
    - **PI2.1** the print · M · views · B1 · needs PI1, C42, C41.5
    - **PI2.2** the tear · M · views · B1 · needs PI2.1
    - **PI2.3** separation and you're in · M · views · B1 · needs PI2.2
    - **PI2.4** accessible path, interruptions, visual pass · M · views · B1 · needs PI2.3
  - invite data
    - **FR0.2** invite flow protocol (integrator) · S · platform · B1 · needs PL1.7
    - **UI4.0** SampleInviteData · S · views · B1 · needs FR0.2, T02
    - **PL1.7d** ticket preview, check, redeem at the tear · M · platform · B1 · needs PL1.7b, FR0.2, BE2.0a, BE2.0b
    - **PL1.8** the invite gate in the app root · M · platform · B1 · needs PL1.7d, PL1.4c, PL5.2, PI1, PI2.4
    - **BE2.0a** invite preview (public) · S · backend · B1 · needs BE0.12, BE2.0b
    - **BE2.0b** invite check, serial, idempotent redeem · M · backend · B1 · needs BE0.12
- sign in
  - P01 · ON-1/2 splash
    - **BE2.4** Google sign-in · M · backend · needs BE0.4, BE0.12
    - **S10** the mark · S · views · needs T01
    - **C38.1** you map at rest · M · views · needs T01, #42
    - **P01** splash page · M · views · needs C38.1, C43, UI4.8, PL1.9
    - **M01** the opening · M · views · needs P01
  - P32 · AC-1 welcome back
    - **P32** welcome back page · M · views · needs C38.1, C43, UI4.8, PL1.9
  - PX · force update
    - **PX** force-update page · S · views · needs PL1.6, UI4.8
  - launch
    - **UI4.8** SampleFirstRunData · M · views · needs FR0.3, UI4.0
    - **PL1.9** launch resolver · M · platform · needs PL1.8, PL1.6, FR0.3, BE2.2b, BE2.5b
- getting to know you
  - P02 · ON-3–9 the questions
    - C34 · the onboarding question
      - **C34.1** question types out (M13) · M · views · needs T01, FR0.1
      - **C34.2** your words, live (M03) · S · views · needs C34.1
      - **C34.3** quick answers · S · views · needs C34.1, C05
    - **C35** onboarding progress · S · views · needs T01
    - **C17-o** top bar, onboarding · S · views · needs C17
    - **C44** Retro's recommendation card · S · views · needs T01, C09
    - **M02** listening glow follows your voice · S · views · needs #56
    - **P02.1** questions page · M · views · needs C34.3, C35, C17-o, M02, UI4.8
    - **P02.2** talk or type, brief time, how straight · M · views · needs P02.1, C44, C08
    - **BE2.2a** onboarding answers count as your words (agent) · S · backend
    - **BE2.2b** answers doors and complete · M · backend · needs BE1.1, BE2.2a
    - **BE2.1** onboarding goals door · S · backend · needs BE2.2b, BEA.4
  - P03 · ON-5 privacy
    - **UI4.5** privacy disc · S · views · needs T01
    - **P03** privacy page · S · views · needs UI4.5, C35, C17-o
  - P04 · ON-6 connect
    - **C36** knows-you meter · M · views · needs S08
    - **P04** connect page · M · views · needs C36, C10, UI4.8
    - **M04** connect → connected moment · M · views · needs P04
    - **BE2.3a** understanding summary (agent) · S · backend · needs BEA.2
    - **BE2.3b** knows-you door · S · backend · needs BE2.3a
    - **BE2.10** sources doors · M · backend · needs BE0.1
    - **BE2.9a** Notion OAuth (if D9) · M · backend · needs BE2.10
    - **BE2.9b** Notion connector (agent, if D9) · M · backend · needs BE2.9a
    - **BE2.9c** Notion normalise (agent, if D9) · M · backend · needs BE2.9b
    - **BE2.9d** Notion in the sources list (if D9) · M · backend · needs BE2.9c
- the first episode
  - P05 · ON-10 getting ready
    - **UI4.1** getting-ready card · M · views · needs C26.2, C06
    - **P05** getting-ready page · M · views · needs UI4.1, C34.2, C35, UI4.8
    - **M05** honest steps moment · S · views · needs P05
    - **BE2.5a1** podcast jobs table and runner (agent) · M · backend · needs BEA.4, BEA.5, BEA.7, BEA.8
    - **BE2.5a2** job routes and first-episode wiring (agent) · S · backend · needs BE2.5a1
    - **BE2.5b** episode job and episode doors · M · backend · needs BE2.5a2, BEA.7
  - P06 · ON-11 the tease
    - M06 · player to paywall
      - **M06.1** player shrinks into the mini-player · M · views · needs P06, C22-p
      - **M06.2** paywall rises · S · views · needs M06.1, P07
    - **P06** tease page · M · views · needs C23e, S10, UI4.8
  - push
    - **BE2.6** device tokens · S · backend · needs BE0.2
    - **BE2.7a** APNs sender · M · backend · needs BE2.6
    - **BE2.7b** first-episode note trigger · S · backend · needs BE2.7a, BE2.5b, contract 07 note writer
    - **PL5.1** push registration · M · platform · needs PL1.5, BE2.6
    - **PL5.3** notification taps · M · platform · needs PL5.1, PL5.2
- membership
  - P07 · ON-12 paywall
    - C37 · the plan pair
      - **C37.1** plan pair · M · views · needs C01, C06, UI4.8
      - **C37.2** plan states · S · views · needs C37.1
    - **C22-p** paused mini-player · S · views · needs C22
    - **C33** benefit rows · S · views · needs T01
    - **P07** paywall page · M · views · needs C22-p, C33, C37.2
    - **M07** the plan glow · S · views · needs P07
  - purchases
    - **BE2.8a** RevenueCat webhook and table · M · backend · needs BE0.2
    - **BE2.8b** entitlement door · S · backend · needs BE2.8a
    - **PL6.1** RevenueCat in the app · M · platform · needs PL1.5, PL0.4
    - **PL6.2** one source of entitlement · S · platform · needs PL6.1, BE2.8b
    - **PL6.3** bridge the old SubscriptionManager · S · platform · needs PL6.2
- first home
  - P08 · ON-13 first home
    - **UI4.2** setup-recap card · S · views · needs T01
    - **P08** first home page · M · views · needs P09, C26, UI4.2, UI4.8
- foundations
  - first-run live data
    - **FR0.3** first-run flow protocol (integrator) · S · platform · needs PL2.4
    - **FR0.4** first-run wiring: sample to live (integrator) · S · platform · needs P08, PL1.9, PL3.3d, PL5.1, PL6.2
    - **PL3.3a** answers through the outbox · M · platform · needs FR0.3, PL2.2, BE2.2b
    - **PL3.3b** connect and knows-you · M · platform · needs PL3.3a, BE2.3b, BE2.10
    - **PL3.3c** first-episode job follower · M · platform · needs PL3.3b, BE2.5b
    - **PL3.3d** recap, complete, live assembly · S · platform · needs PL3.3c, BE2.2b
  - shared foundations
    - **FR0.1** ticket and first-run tokens and haptics (integrator) · M · platform · B1 · needs #42, #55
- flow tests
  - **T03a** invite flow test · S · views · B1 · needs PI2.4, PL1.8
  - **T03b** first-run flow test · M · views · needs T03a, P08, P32, PX, M07, FR0.4

Cross-area dependencies (owned elsewhere): C17, C22, C26, C26.2, P09 (journal plan); C23e (podcasts plan; P06 needs it); C38 (you plan; C38.1 is built here first and C38 extends it); #42, #44–#56 (in review); BEA.2, BEA.4, BEA.5, BEA.7, BEA.8, BE0.1, BE0.2, BE0.4, BE0.10, BE0.12, BE1.1 (backend phase 0/A/1); PL1.4–PL1.7, PL2.2, PL2.4, PL5.2, T01, T02, T02a (Beta 1 cards); contract 07's note writer and Notification Service Extension (outside plan).

## 4. The queue, in build order

Each PR needs only merged work. Backend and app run at the same time; the cross-side waits are marked ⇄.

**Beta 1 (the invite and M14), about 20 PRs:**
1. backend: BE2.0b (after BE0.12) → BE2.0a.
2. integrator: FR0.1 (tokens, haptics, shaped depth, gift mesh) → FR0.2 (invite protocol).
3. views: UI4.0 → C43 (needs PL1.4a) → C41.1 → C41.2 → C41.3 → C41.4 → C41.5 → C42 → PI1 → PI2.1 → PI2.2 → PI2.3 → PI2.4.
4. Platform: PL1.7d (⇄ BE2.0a, BE2.0b; amends PL1.7b) → PL1.8 (needs PI1, PI2.4).
5. T03a (sample in CI; staging run by the integrator) → the founder's sign-off of M14 from recordings.

**Phase 2 (contract 01), about 67 PRs**, in four waves:
1. *Data and launch:* backend BE2.2a → BE2.2b → BE2.3a → BE2.3b → BE2.10 → BE2.4; integrator FR0.3; views UI4.8, S10, C38.1, C35, C17-o, C34.1–C34.3, C44, M02, UI4.5, C36; Platform PL1.9 (⇄ BE2.2b, BE2.5b), PL3.3a (⇄ BE2.2b).
2. *Pages to connect:* P01 → M01 → P32 → PX (drawing first) → P02.1 → P02.2 → P03 → P04 → M04; Platform PL3.3b (⇄ BE2.3b, BE2.10).
3. *The first episode and push:* backend BE2.5a1 → BE2.5a2 → BE2.5b → BE2.6 → BE2.7a → BE2.7b (⇄ contract 07's writer); views UI4.1 → P05 → M05 → P06 (⇄ C23e) → M06.1; Platform PL3.3c, PL5.1, PL5.3.
4. *Membership and home:* backend BE2.8a → BE2.8b → BE2.1; Platform PL6.1 → PL6.2 → PL6.3 → PL3.3d; views C22-p, C33, C37.1, C37.2, P07, M06.2, M07, UI4.2, P08; integrator FR0.4; T03b → ship gate G1. BE2.9a–d only on D9's yes.

## 5. Risks

| # | Risk | Answer |
|---|---|---|
| R1 | M14 is the founder's signature moment and its design is still "in review" (red dot on `2HXA-0`) | Build on the round 2 board (three founder comments already folded in); the founder signs off from recordings (PI2.4); every disagreement is listed (question I5 for the glow) |
| R2 | PL1.7b (Beta 1, already carded) redeems right after sign-in; the board says nothing is spent until the tear | PL1.7d amends it: check after sign-in, redeem at separation; if PL1.7b hasn't merged, build it to PL1.7d |
| R3 | Continuous haptics (the rumble) aren't `SensoryFeedback` | FR0.1 adds a Core Haptics player behind `RHaptic`, gated on hardware and the system setting |
| R4 | P06 needs the podcasts area's C23e | If first run ships first, C23e moves into this plan (the podcasts planner is told) |
| R5 | App Review: an invite gate after sign-in | The review invite (BE0.12) prints like any ticket (`kind: review`, no name); the waitlist is always offered |
| R6 | Paywall prices and trial in Paper are stale ($24.99 / $239.99, no trial line) | Prices come from the store; the layout is Paper's; the trial line is new copy for the founder (F10); the integrator updates the three Paper texts |
| R7 | A first episode spends real money in tests | Staging runs use `skipTTS` except one deliberate run per gate; spend logged separately |
| R8 | The old onboarding asks for sign-in again after "begin" in Beta 1 | PL1.8 marks the old flow signed in through its own writer |

## 6. Questions for the founder (work goes ahead on the lean)

**Beta 1 (the invite):**

| # | Question | Options | Lean | What changes |
|---|---|---|---|---|
| I1 | Show the inviter's name before sign-in? | A yes, for a live code only · B no name until signed in | **A** (the link page already does) | B: T1 always says "a place, kept for you."; BE2.0a returns no face |
| I2 | What is "no. 0412"? | A the invite's place in the order invites were made · B your member number (known only after the tear) · C no number | **A** | B: the face can't show it before the tear (prints blank, fills at separation); C: drop `serial` |
| I3 | The waitlist, used/expired and suspended states aren't drawn | A build from round 1 D in the ticket's style, approve the snapshots · B draw a small board first | **A**, with a quick approval board from the integrator | B: PI1 waits for the board |
| I4 | A sound at separation (the board: optional, off by default) | A none · B a soft paper rip, off by default with a setting · C on | **A** | B/C: an audio asset and a setting |
| I5 | The body's warm glow after the tear (board text says yes; the drawn T4/T5 don't) | A no glow (as drawn) · B a soft amber halo, once | **A** (Paper wins) | B: PI2.3 adds the halo on `pop` |
| I6 | Who a founder invite is "from" | A your first name · B "retrospect" · C nothing | **A** | B/C: BE2.0a's `from` |
| I7 | After "begin" in Beta 1 | A the current onboarding · B straight to the new journal | **A** (the current onboarding still works; first-ship) | B: PL1.8 marks onboarding complete and skips it |
| I8 | Google on the gate in Beta 1 (T1 draws it; first-ship defers Google) | A Apple only in Beta 1 · B both | **A** | B: BE2.4 and PL1.4b move into Beta 1 |

**Phase 2 (first run):**

| # | Question | Options | Lean | What changes |
|---|---|---|---|---|
| F1 | Magic moments (legacy `interpret`) | A leave out · B one "moment" line on ON-10/11 | **A** | B: a door and a line on the card |
| F2 | "skip" on onboarding questions (part 42 draws it; your rule says no) | A no skip · B skip top-right | **A** | B: C17-o gets a trailing text button; answers `given: skipped` |
| F3 | The question set | A the v2 set (8 core + 2 fallbacks) · B today's 18 · C another set | **A** | the `QuestionKey` list in contract 01 §1 |
| F4 | One model-written follow-up per answer | A not in the first build · B yes (~$0.01 each, a wait per answer) | **A** | B: a new door and a "thinking" state on every question |
| F5 | The splash opening | A constellation assembles · B2 light from below · B3 one ray · D the dots connect | **D** (motion-system cites it) | M01's beats |
| F6 | Knows-you thresholds | as contract §13 Q2 | `little` < 1 source or 3 answers; `well` ≥ 3 and ≥ 7 | one constant |
| F7 | ON-8 brief time (not drawn) | A quick answers 7:00 / 8:00 / 9:00 / not now · B a time picker | **A** | B: a picker component |
| F8 | ON-10's progress hairline colour (drawn blue; rule: ink) | A ink · B blue as drawn | **A** | one token |
| F9 | Force-update design | A a purpose page: the mark, one title, one line, lit "update" · B other | **A**, drawn in Paper first | PX |
| F10 | Paywall copy for D6 | the trial line ("first month free, then $199.99 a year · works out to $16.66 a month"), "save 17%", and whether "a journal that talks back" stays (v1 is canned acknowledgements) | trial line as written; drop the sixth benefit until v2 | C33, C37 |
| F10b | M07 under option A | A the glow slides to the plan being bought · B no M07 | **A** | M07 dropped |
| F11 | C16 listening field | A fold into the composer's halo (M02) · B a separate field | **A** | B: a new component |
| F12 | Progress for VoiceOver | A "step 3 of 9" (never on screen) · B "almost done" style | **A** | C35's value |
| F13 | The hint pill on first home (hidden in Paper) | A stays hidden · B one hint, three times at most | **A** | B: UI4.3 card |
| F14 | Quiet first episode | contract §13 Q3 | the quiet line; skip ON-11 and the paywall; land on ON-13 | P05, PL1.9 |
| F15 | The paid gate | contract §13 Q4 | nothing in first run refused; `subscription_required` later | BE2.8b |
| F16 | Goals in onboarding | contract §13 Q6 | not in first run | BE2.1 only feeds contract 04 |
| F17 | Notion in ON-6 (D9) | A build it (BE2.9a–d) · B hide it | your earlier call was build; confirm for the beta | four backend PRs |

## 7. What couldn't be verified

- Paper was read for the invite (round 2) and spot-checked for the splash and paywall; the other phase 2 nodes are cited from `paper-inventory.md` and each card's first step reads them.
- No dark board exists for the invite; dark is the token swap, checked by the founder from snapshots.
- Whether `raw_content.content_type` has a check constraint (BE2.2a's migration may be unnecessary).
- How the old onboarding resumes after `markSignedIn()` in Beta 1 (PL1.8 must confirm on a device).
- The print timing ("about 2.5 s … about 1.8 s") is read as the sequence ending ~2.5 s after sign-in with a 1.8 s rise; the recording is checked against the board.
