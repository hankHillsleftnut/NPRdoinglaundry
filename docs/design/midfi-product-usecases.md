# mid-fi · the product, chunk 1: Journal (rest) + Podcasts

20 Oct. Before drawing: the use cases each page must serve, what the supporting material says, and the decisions (with the conflicts resolved by the system's own rules). Sources read: the goals doc (outputs, the structure, the brief, corrections, the claim ladder), the blueprint (JR-2, JR-4, PC-1–3), the opportunities (O-3, O-4, O-5, O-10, O-13, O-24, O-30), the problems doc (Journal and entries; Podcasts and the player), the component specs (player, brief card, mini-player, message, guess card, sheet), screen rules 1–33, the instruction ledger.

## Use cases

**Podcasts (PC-1)**
1. Sunday: the weekly episode is ready (a notification opens the player straight on it).
2. A weekday morning: today's brief, here as well as on Journal.
3. Going back to an older episode or brief.
4. First week: only the first episode exists.
5. This week's is still being made; a quiet week; it failed; offline (downloaded ones play).
6. Not subscribed: everything is visible; play opens the paywall (free tier: no listening).
7. Something is playing: the mini-player floats above the tab bar on every tab.

**The player (PC-2), and the brief opened (JR-2)**
1. Listening on a walk, screen off: the transport in the thumb zone, lock-screen controls (O-24).
2. Reading along with the sound off: the transcript is the page.
3. "Why is this in here?": the why line for the whole episode; per part, why this is here (PC-3).
4. "That's not me": not right on any line (long press), or the pill (O-10).
5. Answering the one thing it's wondering: yes / not quite / why do you think that? (O-5, O-13; evidence → a question → your answer).
6. Speed, skip, chapters; close with a swipe down.
7. The brief: what you sent comes first (the brief is your inbox), each item with why it's here; a quiet day says so; tap an item's source.

**Why this is here (PC-3)**
1. See the evidence with dates; open one (an entry, an event, a link).
2. Know whether it was stated (from evidence) or asked (a guess), and how sure.
3. Correct a line.

**An entry (JR-4)**
1. Read back what you said, your words first and large.
2. Play a voice note.
3. Edit it (the brain re-reads it); delete it (the brain forgets it too), with a confirmation.
4. See what Retro took from it, and correct any of it.
5. See Retro's reply to it; jump back to it in the thread.

## Decisions

- **The brief opens in the player** (player.md: "opening any episode or brief"), in brief mode: items instead of chapters, each with why. JR-2 is the player sheet over Journal, not a separate page.
- **Why this is here pushes inside the player sheet**, with a back arrow. The blueprint drew it as a second sheet; sheet-and-dialog rule 3 says never stack two sheets, so the system decides.
- **The player keeps the spec's order** (what it is → hear and read → control): header, inky title, why line, transcript, then the guess card when it reaches it, then scrubber, transport, chapters · not right. No artwork: the title is the cover.
- **The page behind shows as a page** (founder: the player sheet felt off): a 10pt strip of the scaled, dimmed page above the sheet.
- **Podcasts is tiles** (founder): this week's episode as a wide hero tile, then today's brief and earlier ones as square tiles, two across, 12 apart; tiles lag and settle on scroll.
- **Your words lead the entry** in the inky face; the date sits 8 under them. Delete is the destructive action in the bottom zone, behind a dialog.
- **Retro's lines stay inky** (screen rule 5, the founder's latest) though message.md says text 17: the founder's rule wins; flagged for the token pass.
- **Blue**: only the one lit play on Podcasts (this week's hero) and the why links; inside the player the play well is raised, not lit (the glow means start; it's already the thing you opened).

## Open question for the founder
- None for this chunk; the message-state question from Journal (every message vs latest) still stands.
