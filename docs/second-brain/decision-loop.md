# The decision loop

How a product goal becomes shipped code, and who decides what.

Written 15 October 2026. Companion to [16-product-goals.md](./16-product-goals.md)
and [09-agent-execution-plan.md](./09-agent-execution-plan.md), whose atomicity
test this reuses rather than replacing.

---

## The split

| You own | I own |
|---|---|
| What the goal is, and how it must perform | Finding the candidate methods |
| What "done" looks like for a user | Testing whether they actually work |
| Choosing between the options | Writing the brief that makes the choice possible |
| Saying when something feels wrong | Splitting the choice into atomic tasks, and shipping them |

You cannot choose between methods described in engineering terms. So the brief
below describes every option by **what the user notices**, and treats the
engineering as a footnote. That is the whole point of the format.

---

## Step 0 — context before code

Added 18 October 2026, on founder instruction, after it earned itself twice in
one hour.

**Before writing anything, find out what already exists and what the data
actually says.** Not a nod toward diligence — a required step with a checklist,
because skipping it produced two concrete errors today:

**It nearly rebuilt work that was already done.** The plan called for building a
backlog-drain tool. `scripts/requeue-failed.ts` already existed, already had a
dry-run default, a hard cap, cost estimation and deduplication — better than what
was about to be written. One `ls` of the scripts directory would have found it.

**Reasoning about the data gave the wrong answer; reading it gave the right
one.** A classifier rule was written listing the three skip phrasings I had seen.
Running it against the live backlog turned up a dozen more — *"link list, not
personal writing"*, *"someone else's design brief"*, *"too short to contain a
verifiable claim"*. Enumerating them was never going to converge. The real
contract was a prefix the pipeline uses to announce every skip, and that was only
visible by looking.

**And the headline number was wrong by two orders of magnitude.** The backlog was
described as 2,024 lost entries. Deduplicated, it is roughly 35 distinct
documents — a broken importer had written the same handful hundreds of times. The
drain costs under a dollar, not twenty-five. Every plan built on the larger number
was planning for a problem that did not exist.

### The checklist

Before step 2, and before any task in step 6:

1. **What already exists?** List the scripts, search for the function, read the
   neighbouring module. Assume the problem has been met before.
2. **What does the live data say?** Query it. A count, a distribution, a sample of
   real rows. Never reason about the shape of data that can be looked at.
3. **What are the conventions here?** How tests are written, how scripts take
   arguments, how migrations are commented. Match them rather than inventing.
4. **What does the surrounding system expect?** Constraints, triggers, callers.
   A typecheck cannot see a database CHECK constraint — today that was a real bug,
   caught only by reading the migration.
5. **Has someone solved this better elsewhere?** Where the problem is general —
   agent loops, retrieval, evaluation — look at how it is actually done in
   practice before designing from first principles.

### The rule behind the checklist

**Deliberate beats fast, and context beats cleverness.** A principal engineer's
advantage is rarely a better algorithm; it is knowing what is already there, what
the data really looks like, and what the system will actually do. Every error in
this project so far — the fabricated citation, the wrong reranker, the 5x
mispricing, the two above — came from reasoning where looking was possible.

**Cost of the checklist:** minutes. **Cost of skipping it:** rebuilt work, a wrong
plan, and a bug the type system cannot see.

---

## The loop

```
0. CONTEXT            what exists, what the data says, what the system expects
1. GOAL SPEC          you write it: what, how it must perform, what done looks like
2. SURVEY             I find candidate methods — papers, real implementations
3. VALIDATION GATE    I test them against the bank. Most fail here.
4. DECISION BRIEF     I write the trade-offs in user terms. You choose.
5. SPLIT              the chosen method becomes atomic tasks
6. SHIP               one PR per task, each reviewed before it lands
   └ DRIFT CHECK      before each task: does the decision still hold?
7. AUDIO CHECK        an episode you listen to. You give notes.
8. BACK TO 1          next goal, in dependency order
```

Stop points are steps 4 and 7. Those are yours. Everything else runs without you.

---

## Models and effort

Think hard about what to build. Do not think hard about typing it.

| Step | Model | Effort | Why |
|---|---|---|---|
| 2 — survey | opus | **high** | Finding the right method is the step with the most leverage and the most room to be wrong. |
| 3 — validation gate | opus | **high** | This is where I talk myself into things. It gets the most careful setting. |
| 4 — decision brief | opus | **high** | Naming a trade-off honestly is harder than implementing one. |
| 5 — split | opus | medium | Mechanical once the decision exists. |
| 6 — implementation | opus | **medium** | The judgment was spent at step 4. This is execution. |
| 6 — drift check | opus | medium | A short question, asked often. Cheap on purpose. |
| 6 — code review | opus | **high** on the write path, credentials, routes, migrations; medium elsewhere | A missed bug here is more expensive than the tokens saved. This is my recommendation, not your instruction — say if you want it medium throughout. |
| 7 — audio notes | opus | medium | You are the judge at this step, not me. |

**One honest limitation.** Subagents take a model *family* — `opus`, `sonnet`,
`haiku`, `fable` — not a pinned version. So "Opus 5.5" in practice means
"whatever this account's `opus` resolves to," which is currently the 5.5
generation. I cannot enforce a version number from inside the loop. If the
account default moves, the loop moves with it silently.

Effort is only set when you have asked for it. You asked on 15 October 2026, so
the table above is standing instruction until you change it.

---

## Step 3 — the validation gate

This step exists because I have a documented record of recommending things that
sound robust and are not. In this project specifically:

- I recommended Chain-of-Verification as the fact gate. Wrong family — self-consistency
  never checks a source.
- I recommended adding a cross-encoder reranker to Cook B. The measured result in
  conversational memory is that an off-the-shelf reranker **hurt** Hit@1 by 6.9 points.
- I cited `arXiv:1903.07161` as a plan-recognition survey. It is a pointer-networks
  note. The citation was fabricated.

Each of those came from the same move: reasoning about whether something *sounds*
robust instead of checking. So the gate is not my judgment. It is three questions
I can fail:

1. **Does the code exist and run?** A paper with no runnable implementation is a
   "not yet," not a candidate. Link to the repo and the commit I ran.
2. **Does it run on our bank?** Not on the authors' benchmark. On your writing.
3. **Does it beat what we have, on a number we wrote down before I went looking?**
   The metric is declared in the goal spec, at step 1. Choosing the metric after
   seeing results is how everything passes.

A method that fails any of the three goes on a **not-yet list** with the reason
and the date. It is not discarded — it is parked with its failure recorded, so we
do not re-litigate it in three months.

Nothing enters the product on the strength of a paper alone.

---

## Step 4 — the decision brief

One per product goal. This is the artifact you actually read.

```markdown
# Goal N — <name>

## The requirement
<your spec, restated in one paragraph>

## What a user cannot do today
<concrete, from the current system>

## Metric declared before the survey
<the number that decides this>

## Options

### Option A — <plain name>
**What it is:** one sentence, no jargon.
**What the user notices:** the thing that changes for a person using the app.
**What it costs:** latency, money per run, new moving parts.
**How it fails:** the specific bad day, and what the user sees on that day.
**What it forecloses:** what gets harder later if we pick this.
**Gate result:** code exists? ran on our bank? beat the metric? — with numbers.

### Option B — ...
### Option C — ...

## Recommendation
One option, with the reason stated as a trade-off you are accepting.

## If you pick this, it splits into
- task 1 — one sentence
- task 2 — one sentence
```

Rules for the brief:

- **Two to four options.** One option is not a decision. Five is me avoiding one.
- **"How it fails" is mandatory.** Every method has a bad day. If I cannot name
  it, I do not understand the method well enough to recommend it.
- **No option is described only by its upside.**
- **Doing nothing is an option** whenever it is genuinely viable, and it is named.

---

## Step 5 — the split

An atomic task is one task when all four hold. This is doc 09's test, unchanged:

1. It produces **one commit** with a title naming the object it touches.
2. It has **one gate** that can fail, and I can run that gate myself.
3. It requires **no product decision** — every judgment call was settled at step 4.
4. A reviewer can read the diff in one sitting.

If a task needs a product decision mid-flight, it was not atomic. It goes back to
step 4.

---

## Step 6 — the drift check

Before starting each task, three questions. Short, cheap, asked every time:

1. **Does the decision from step 4 still hold**, given what the last task taught us?
2. **Is this still the best next task**, or did something more important surface?
3. **Does this still fit the framework** — the object ladder, the locked product
   behaviour, the goals below it in dependency order?

Three outcomes. *Continue* — most of the time, and it costs one paragraph. *Reorder*
— the plan holds, the sequence does not. *Back to step 4* — the decision itself
stopped making sense, which is rare and worth catching early.

This exists because the expensive failure is not a wrong task. It is finishing a
seven-task plan that stopped being right at task three and nobody asked.

---

## Step 6 — trade-offs inside a task

Step 4 chooses the method. But choices remain inside each task, and they are
**stated in the same register**: what it means for the person using the product.

Not "I chose fail-fast over retry." That is a preference.
**"If the upload fails, the entry is lost without the user knowing. The
alternative is they wait four more seconds."** That is a trade-off.

```
Trade-off taken
  What I did: <the choice> → <what the user gets, and what they lose>
  Alternative: <the other option> → <what they would have got instead>
  Chose this because <the experiential reason>.
```

Worked examples of the register:

| The code choice | Stated experientially |
|---|---|
| retry vs fail fast | they wait longer on a bad day, or they lose the entry and never find out |
| strict vs lenient validation | fewer wrong facts about them, or more facts about them |
| inline vs background processing | the app pauses while saving, or the entry shows up a minute late |
| cached vs live portrait read | it answers instantly from a slightly old picture, or slowly from the current one |
| truncate vs segment long entries | the end of a long dump is silently lost, or ingest takes minutes |

**The filter.** If I cannot trace the fork to something a person would notice,
feel, or lose, it is not a trade-off — it is a preference, and it stays out of the
PR. Most tasks have no fork and the section is omitted entirely. If every PR has
one, I am manufacturing them.

This is the test, and it is strict: **a trade-off that can only be explained in
engineering terms has not been understood well enough to be worth your attention.**

---

## Step 6 — the quality bar

Every PR, no exceptions:

- Traces upward in its description: **task → method → decision → goal**. A PR that
  cannot name the goal it serves does not get opened.
- Typecheck and tests pass before it is opened, not after review.
- The gate from step 5 is stated in the PR and its result pasted in.
- Engineering trade-off named, if the task had one.
- No secrets, ever. `.env.example` with placeholders only.

### The checks, and when each runs

| Check | Runs on | What it catches |
|---|---|---|
| `/code-review` | every PR | correctness — inverted conditions, off-by-one, missing `await`, dropped error handling, broken callers |
| `/security-review` | credentials, routes, external writes, auth, storage | the class of thing that does not show up as a failing test |
| `/simplify` | any PR over ~200 lines | reuse and altitude — the cleanup pass, not bug hunting |
| `/better-writing` | anything with user-facing copy | the words a person actually reads |
| `/better-interface` | any UI change | accessibility, layout, typography, colour, polish, in one pass |
| `/ios-code-review` | any Swift change | the Architecture Bible as a review checklist |

`/code-review` takes its own effort level. Use **high** on the write path,
migrations, credentials and routes. Medium elsewhere.

### Automatic escalation

A PR gets the full review pass whether or not it feels necessary when it:

- changes more than ~200 lines
- touches the ingest write path
- adds or alters a migration
- reads or writes credentials
- changes an HTTP route
- changes anything a user sees

### What "quality" means beyond correctness

You said it should feel good and look good, so those are checks too, not taste:

- **Copy** goes through `/better-writing`. Error states and empty states included —
  those are where products feel careless.
- **UI** goes through `/better-interface`, which covers accessibility and layout
  rather than leaving them to notice later.
- **Swift** goes through `/ios-code-review` against the Architecture Bible already
  written for this project.

### What I will not do

Mark a PR reviewed because a tool ran. A review that found nothing says so, and
says what it looked for. A finding gets fixed or answered in the PR — never
deferred to a follow-up that does not exist yet.

---

## Step 7 — the audio check

Audio is the right review surface and it lags by ten stages. A bad episode tells
you something is wrong and nothing about where.

So every audio check ships with an **intermediate dump**:

- what facts came out of the run
- what was dropped, and the reason for each
- what was in the evidence pack the writer actually saw
- which pulls were called

Audio answers *does this sound like me*. The dump answers *where did it break*.
Your notes land on whichever one is actually at fault.

---

## Order

The loop runs in **dependency order, not goal order**. The goals are not
independent: facts precede patterns, patterns precede why, the bank precedes the
story.

Running 1→16 in list order would build goal 12 on an extractor that drops half the
input.

First goal through the loop is **goal 3, making meaning from data**. It is the
current bottleneck, everything downstream eats its output, and it is measurable
today.

Before that, one prerequisite: **the test bank**. Nothing at step 3 is real
without it.

---

## The test bank

Your own writing, with known right answers. The format:

```
bank/
  entries/
    2026-10-01-journal.md        raw text, exactly as you would have written it
  expected/
    2026-10-01-journal.yaml      what should come out
```

Each expectation file lists the facts a correct extractor would produce from that
entry, and — as important — what it should **not** produce. A deliberately
ambiguous sentence with "no fact here" as the expected answer is worth more than
ten easy ones.

Twenty entries is enough to start. It wants to include:

- a long multi-topic dump (the truncation case)
- something about work rather than your personal life (the dropped-domain case)
- a contradiction across two entries (the supersession case)
- two different people with the same first name (the identity case)
- a voice note transcript with a plausible mishearing (the quote-confidence case)
- an entry where the honest answer is that nothing can be concluded

That last category is the one that catches a system telling you what you want to hear.

---

## What is still open

**Does it act, or prepare?** Whether the companion performs actions on external
services or stages them for one-tap approval. This decides whether integration
credentials are read-only, which changes the security review on every PR that
touches them. Unanswered as of this writing.
