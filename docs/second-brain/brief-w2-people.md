# Brief — W2 People: when two mentions are the same person

19 October 2026. Stop point W2.1 in the [build plan](./build-plan.md). One
decision for you; everything after it runs without you.

## TL;DR

**Recommendation: be strict.** Link two mentions only on decisive evidence (the
same email, or one unambiguous name across your data). Separate them on
decisive conflict. **Everything in between is held and asked, never guessed.**

A wrong link ("you met Sam twice", when it was two different Sams) is the
error goal 4 forbids. A missed link only makes something feel smaller than it
is, and one question fixes it. **Your call:** strict as recommended, or looser
(fewer questions, some risk of mixing people up).

## What exists today (counts only, live data)

- **555 people:** 300 from contacts, 211 named in writing, 8 from calendars. *(Corrected 20 Oct: the brief first said all came from journals.)* Calendar and mail contacts already match by email. **The gap:** people you write about aren't connected to the same people in your contacts.
- Matching is **exact name only**, so "Francis" and "Francis Chen" are two people.
- **193** are single names. **49 groups share a first name** within one account (118 people): some are duplicates, some are genuinely different people.
- The "unsure: hold and ask" queue exists in the database and has **never been used** (0 entries).
- So today it **never wrongly merges people** (good) but **misses true matches** (bad), above all between the people you write about and the same people in your contacts.

## The approach (research: Fellegi–Sunter record linkage)

Each pair of mentions is compared field by field, and each field adds or
subtracts evidence:

| Field | Agrees | Disagrees |
|---|---|---|
| Email or phone | **decisive: link** | strong: separate |
| Full name | strong | strong |
| First name only | weak, and only if they're the **only** person with that name in your data | weak |
| Nickname (Alex / Alexander) | medium | n/a |
| Seen in the same places (an event, a thread, an activity) | medium | n/a |
| A role word ("Mom", "my manager") | **never** links on its own | n/a |

The total goes into three bands: **link**, **hold**, **separate**. A model
breaks ties only inside the hold band, and only to suggest, never to link.
Pairs are compared only within blocks (same first-name initial, same email
domain), so it stays fast.

## The bar, declared before code (gate W2, 12 cases already written, #54)

- **0 wrong links.**
- **≥ 80% of true links found.**
- **All ambiguous cases held.**

Then on your data, counts only: how many duplicates merge, and how many get
held. The held ones are yours to review (W2.6).

## What "held" looks like for you

Occasionally, one short question: *"Is the Sam in your journal Sam Ortiz from
your calendar?"* Yes links them; no separates them for good; skip leaves them
apart. "Mom", "my manager" and the like are linked only when you say who they
are, once.

## Options

| | Strict (recommended) | Loose |
|---|---|---|
| Wrong links | ~0 (gate requires it) | some: one name, two people |
| Questions to you | a handful at first, then rare | almost none |
| Fits goal 4 ("never confuses two people") | yes | no |

**Send me:** "strict" or "loose", and whether role words ("Mom") should be
asked about once or left alone.
