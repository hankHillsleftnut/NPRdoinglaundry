# Sample data ledger

Every value the new screens show before live data exists. Each row says where the value lives, where it came from, and which wiring PR removes it. When a flow is wired, the integrator deletes its rows. A row that's still here after its wiring PR is a bug in the seam (ui-engineer.md §4).

Sources: **fixture** means copied exactly from `docs/team/contracts/fixtures/` (and checked by `SampleJournalDataTests`); **invented** means written for the sample (lowercase, plausible, no real person's words; contracts rule 8).

## Journal (UI1.0) · removed by the journal wiring PR (PL3.1)

All in `Retrospect/Retrospect/Features/Journal/Sample/`.

| Screen | Field | Sample value | Source | Contract path |
|---|---|---|---|---|
| JR-1, JR-3 | today's entries 1–3 | "dentist at 3 today, dreading it" (typed, read) · "walked the long way home by the canal. felt lighter after." (voice, reading) · "notes from the planning call: ship the first version friday" (imported, waiting) | fixture `02/entries.today.json` | 02 §2 `GET /v2/entries/today` |
| JR-1, JR-3 | today's entries 4–6 | "lunch outside for once. twenty minutes, no phone." · "can't stop running through the friday demo in my head." (voice) · "booked the next dentist visit before i could talk myself out of it" | invented | 02 §2 |
| JR-3 | earlier days (19 and 20 oct) | five entries: sleep and the deadline; a call with sam; cooking in; a run by the canal; priya's birthday dinner | invented (contract names "sam", "priya") | 02 §5 `GET /v2/entries` |
| JR-1, JR-4 | `long` entry | about 1,200 characters about an evening, a walk and a laptop | invented | 02 §2 |
| JR-3 | `long` drawer | 60 entries, three a day, from twelve short lines | invented | 02 §5 (pages of 50, cursor `cursor-<offset>`) |
| JR-3 | search matches | computed from the sample's own words (UTF-16 ranges); "canal" matches, "kayak" doesn't | fixture shape `02/entries.search.json` | 02 §5 `?q=` |
| JR-1, JR-2 | the brief | three parts, one with "here for your goal: ship the first version" | fixture `02/brief.latest.v1.json` | 02 §3 |
| JR-1 | `long` brief headline | first part lengthened to three lines | invented | 02 §3 |
| JR-1 | quiet day line | "nothing new since your last brief. i'll keep listening." | fixture `02/brief.latest.quiet.json` | 02 §3 |
| JR-1 | brief "ready by" | 8:30 on 21 oct, the phone's time zone | invented (contract 06 supplies it later) | 02 §3 `making(readyBy:)` |
| JR-1 | the guess | "could the short nights be about the friday deadline?" with its framework, rationale and two things it rests on | fixture `02/guesses.json` | 02 §4 |
| JR-4 | what Retro took | three items (two facts, one pattern) and the waiting state | fixtures `02/took.json`, `02/took.waiting.json` | 02 §6 |
| JR-4 | corrections | applied, confirm (two candidates), ask in your own words, not a correction, confirmed | fixtures `02/correction.*.json` | 02 §6 |
| JR-1 | acknowledgements | the seam's four lines ("got it.", "saved.", "it's in.", "kept."), in turn | `Flows.Journal.Acknowledgements` (founder to confirm, 02 §7.6) | 02 §2 |
| all | server failure message | "Something went wrong on our side." | fixture `02/error.internal.json` | 00 §2 |
| JR-1 | ids of entries sent from the sample | `00000000-0000-4000-8000-0000000050NN` | invented | 02 §2 `clientEntryId` |
| all | send delay | one second of the injected clock | invented (the card's one second) | none |
