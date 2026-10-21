# Audio script — the whole spec, spoken

Written to be listened to, not read. Conversational, chaptered so you can skip.
Includes my own flags and concerns, not just the decisions.

Roughly 35–40 minutes spoken.

---

## Cold open

This is everything we've decided about Retrospect, read back to you, so you can
check it's actually what you meant.

I'm going to go through the mission, the big architectural calls, all twenty-five
goals, and then the things I'm genuinely worried about. Where I disagree with you,
I'll say so. Where I'm guessing, I'll say that too.

If something in here isn't your vision, that's the point of listening.

Let's start.

---

## Chapter one — the mission

Here's what you said you want.

A companion that knows you and helps you grow. It learns on its own from what you
write and do. You can hand it things — a link, a note, something about your day —
and it takes them in. You talk to it in small pieces, continuously. It quietly
handles the boring admin of your life. And talking to it feels soothing rather
than clinical.

That's coherent, and it's one product. But it's a much bigger product than what
exists today, which is a journaling app that makes a weekly podcast.

Two things run through everything that follows.

First: this gets spoken to every day, not every week. Which means every mistake
gets more chances to repeat itself. Staleness and fabrication stop being
embarrassing and start being corrosive.

Second: the weekly episode is no longer the product. It's one output.

---

## Chapter two — the reversal

This is the most important thing you said, and it changed the architecture.

The default user sends nothing. No links. No progress texts. Maybe no journals at
all. Most people will not do those things, and the product has to be good anyway.

Your words: make this as smart as possible without that information.

So the hierarchy flipped. Onboarding and integrations used to be enrichment —
they're now the substrate. Journals used to be the substrate — they're now
valuable context. Links and progress texts are a power-user bonus.

Three things follow from that.

Integrations move onto the critical path. Earlier drafts said hold them until
extraction was measurable — that was right when journals were the input. It's
wrong now. If passive data is the substrate, the connector fleet is the main
pipeline. And right now it has zero rows and has never run, not once.

Second, there's a confidence threshold before it speaks. It watches what it has
until it knows enough, then starts.

And third, the grounding rule had to change.

Here's the thing about that. The span rule — a fact needs a quote from your own
words — was the foundation of everything. But a calendar event has no words. So
grounding now has two anchors. Either a quote in the person's own words, or a
structured record. A calendar event, a health figure, a screen time total.
Grounded in the row, checkable against it, not inferred.

Both are verifiable. Neither is a guess. But they support different things.

A record tells you what happened. It never tells you why, or how it felt. Only
words do that.

So a product built mostly on records will know an enormous amount about someone's
behaviour and almost nothing about their reasons. That's the honest cost of going
ambient, and it must never let the first thing masquerade as the second.

---

## Chapter three — what I'm most worried about

I'll say this now rather than bury it.

Ambient, proactive, and no words from the user is also the creepiest possible
version of this product.

Think about what it actually is. A system reading someone's calendar, their email,
their screen time, running a web search on them — and then speaking to them about
themselves, having never been told anything directly.

The difference between uncanny insight and surveillance is almost entirely in how
it talks about what it knows.

So two rules, and I'd treat them as non-negotiable. It always says where something
came from when asked. "How do you know that" has a real, specific answer. And it
never implies it was told something it inferred. Noticing a gap in someone's
calendar is not the same as being told they had a hard week.

That's goal nine and goal twenty-two doing safety work, not just tone work.

---

## Chapter four — the claim ladder

You wanted the span rule as the foundation, but you also wanted the product to
hypothesise. To make educated assumptions. That's right, and it needed structure.

So there are four classes of claim, and they're never blurred.

A **fact** comes from a quote or a record. Highest confidence, stated plainly.

A **pattern** comes from the same behaviour repeating. Stated with its instances.

A **why** is a mechanism attached to a live pattern. Low confidence, labelled
inferred.

A **hypothesis** comes from a framework plus enough accumulated knowledge. Lowest
confidence — and it's asked, never asserted.

One protection I added that you didn't ask for, and I'd defend it hard.
Extraction produces facts only. No inference at ingest, ever, not even hedged.
Because the moment inference can happen during extraction, the drop rate stops
meaning anything — and that's the only number that tells you whether the system is
honest.

Three gates on a hypothesis, all must pass.

Critical mass, and it's per domain rather than global. You might know enough about
someone's work to wonder aloud and nothing about their relationships. Treating it
as one threshold would let it speculate about exactly the areas it knows least.

A named framework. If nothing educates the assumption, it isn't educated. And it
has to be nameable to the person — I'm reading this through such-and-such a lens.
An inference nobody can trace is a guess in a lab coat.

And the person's appetite for being hypothesised about.

Two lines I drew myself. It's never clinical — no diagnosis, no disorder, no
trauma, no pathology, not hedged, not as a question. And lint has to catch
hypothesis hardening, because a guess repeated often enough starts being treated
as known, by the system and by the person. Only confirmation can promote it.

How bold it should be, we deliberately left open. You said you don't know yet, and
that's the right answer. You'll find out from ten or fifteen episodes about
yourself, then from friends. So we build the dial, not a position on the dial.

---

## Chapter five — the two outputs

The daily brief, at nine in the morning.

Not a link reader. Four inputs amalgamated: what your sources show, your goals,
what you care about, and who you are. Plus journals and links when they exist.

The content is external. The selection, the ordering, and the framing are entirely
about you. An article gets covered because it bears on something you're trying to
do, and the brief says why. The same five links sent by two different people
produce two different episodes.

Length is variable — as long as there's something worth saying. I'd put a floor
around forty-five seconds and a ceiling around four minutes, because unbounded
you'll get forty seconds one morning and nine minutes the next, and a morning
habit needs to be predictable.

It has a per-user on-off switch, default off. That does three jobs — consent, cost
control, and staged rollout. A product that starts speaking to you every morning
before you asked is the one that gets deleted.

Then the weekly episode. The intense one. Behaviour patterns, performance against
goals, reflection.

Here's why this split matters more than it looks. The two outputs map almost
exactly onto the two banks. Daily reads the reference bank — the stuff you sent.
Weekly reads the self bank — the stuff about you. That's not a coincidence. It
means the two banks aren't a complication, they're the product structure.

And they fail in opposite directions, which is the part people get wrong.

Daily fails by being boring. That costs attention, and it's recoverable —
regenerate it, nobody's hurt. It needs creative latitude and a check that asks
whether this has a spine.

Weekly fails by being wrong about you. That costs trust, and "that's not me"
doesn't recover the way "that was dull" does. It needs conservative generation and
a grounding check on every claim.

The trap is that both read as "write audio about the user," so sharing a prompt
looks like sensible reuse. It averages them. You get a weekly that's too loose and
a daily that's too stiff.

They don't share a prompt, a model, or a quality gate.

---

## Chapter six — the money

Short chapter, but you should hear it.

Daily audio is the dominant cost line. Roughly eight to twenty-five dollars per
user per month depending on length. At thirty testers that's real money.

Your cost meter is wrong in three places, and the direction matters. It bills
Anthropic at Opus rates while everything runs Sonnet — five times over. It bills
OpenAI at full rates while the outline writer runs a mini model — twenty-five to
thirty-three times over. And it computes ElevenLabs characters with an extra
thousandth in the formula — a thousand times under.

So it overstates thinking and understates speaking. For a product about to speak
every day, that's exactly backwards. It reported fifty-five dollars lifetime when
the real number was about twenty.

Which flips the optimisation. Thinking is nearly free next to speaking. And right
now the thing that decides what the episode is even about runs on the cheapest
model in the fleet. That's the one place you shouldn't be saving.

Fix the meter. Then stop economising on thinking and start economising on words
spoken. Length discipline is where the money is, and it happens to also make the
product better.

---

## Chapter seven — the two banks

The self bank holds claims about you, grounded in your words or your records.

The reference bank holds material that isn't about you. Links, articles, people to
reach out to, investors, jobs, things to look into. Grounded in its own source — an
article's claim is the article's, not yours.

Four areas, all of which you confirmed: outreach and people, investors and
fundraising, content and video ideas, research and reading.

And collections get created by saying them. "I'm going to keep sending you a list
of investors I want to speak with" creates the list. No settings screen. It infers
which project it belongs to. And columns emerge from the items rather than being
invented up front — because the temptation is a nine-column investor table where
seven columns are permanently empty.

Now the wall, which is the whole point of separating them.

Nothing in the reference bank may ever become a fact about you.

Save an article about morning routines and that must never become "he wants to
wake up earlier." You looked at a thing. That's all that happened.

Links between the banks are possible, but always explicit and always yours. The
system can propose. It can never write the connection itself.

This is the highest contamination risk in the product, and the nastiest, because
it would be invisible. Every poisoned claim would still have a real source — just
in somebody else's words.

---

## Chapter eight — the twenty-five goals

Your original sixteen, rewritten for this mission, plus nine I derived from what
you've described. Cut any of mine that aren't real.

Tier zero. The foundation.

**Goal three, making meaning.** Done when you write anything and the true parts
come back. Nothing invented, nothing silently dropped, every domain of your life
has somewhere to land, long entries read to the end.

**Goal one, data sources.** Passive sources, pointed input, and intent — what you
want done with the thing you handed over. Input channel is the iOS share sheet.
Links split into three tiers by whether they can actually be read; TikTok and
anything behind a login is a separate project.

Tier one. The integrity of the bank.

**Goal two, ingestion.** Done when you never wonder whether something made it in.
This is the best-built thing in the product already.

**Goal four, connections.** It never confuses two people with the same first name,
and never raises a goal you quit.

**Goal twenty-three, the reference bank.** Just covered.

**Goal twenty, correction that sticks.** Done when you correct it once. Corrections
propagate, and nothing you rejected comes back.

**Goal five, linting.** It stops repeating what stopped being true. Twenty-six
checks are written and have never run, not once.

**Goal twenty-two, calibration.** How growth-inclined, how sensitive, how open
someone is. Start safe, earn upward, never assume upward. Being too cautious costs
engagement; being too bold costs the person.

Tier two. The read path.

**Goal ten, current state.** It knows where you are today and admits what it
doesn't know. Unknown slots stay empty rather than holding last month's answer.

**Goal six, search.** This used to be plumbing. Under this mission it is the
conversation. Everything carries its source, and it says "I don't know" rather
than approximating.

**Goal twenty-four, cold start.** Onboarding ends with something true that you
recognise. The sequence: a couple of questions, then the privacy conversation,
then the integrations, then more questions, then the first insight. Asked in voice
with typing always available. All four sources at once plus a web search.

Tier three. Understanding.

**Goal seven, reported goals.** January's marathon isn't this week's topic.

**Goal eight, real goals.** It shows the gap between what you said and what you did
without editorialising. This is where the line between pattern and hypothesis
sits: observed pursuit is evidence, what you actually want underneath it is a
guess with gates.

**Goal twelve, impediments.** It names what's in your way and you don't feel
accused. Delivered as a question before a verdict.

Tier four. The companion.

**Goal eighteen, conversation.** It feels continuous rather than a new session
every time. Knows when to say nothing.

**Goal nine, communication style.** Talking to it feels like relief, not a
performance review. I'll come back to this one, because you've asked for two
things that pull against each other.

**Goal eleven, relevance and research.** It brings you something useful you didn't
ask for, and you can see why it thought so.

Tier five. Inference and output.

**Goal twenty-one, hypothesis.** It names something about you that you hadn't put
into words, and you recognise it as true. And when it's wrong you feel invited to
correct it rather than examined.

**Goal thirteen, the outline.** The shape traces to your actual life.

**Goal fourteen, the story.** Nothing in it makes you think "that's not me." It
carries two registers without blurring them — "you skipped it three times" and "I
wonder whether it's the mornings rather than the gym" cannot sound alike.

**Goal fifteen, voice.** Produced quality first. ElevenLabs with expressive
delivery. Talking back is version two — and the honest constraint there is
latency, not switching. Answering needs speech to text, a lookup, generation, and
speech again. At produced quality that's several seconds of silence, which breaks
the exact feeling you want. So the answer is two voices. A real presenter doesn't
answer in their prepared delivery either.

**Goal sixteen, delivery.** You can use it standing in a queue.

**Goal twenty-five, visible pattern change.** You watch a pattern weaken and you
believe it. This is the only goal about change rather than detection, and you said
it's the actual point. It has to be able to say a pattern got worse — a product
that only reports improvement is one nobody believes.

Tier six and last.

**Goal nineteen, learning from itself.** It gets better at asking without being
rebuilt. The hard line: it learns about its own performance, never treats its own
output as a fact about you.

**Goal seventeen, acting on the world.** The boring things happen and you trust
they happened correctly. Built last, by your decision — which keeps every
integration credential read-only for the whole plan, and removes the biggest
security surface from everything before it.

---

## Chapter nine — the canonical questions

This was your best idea in the whole conversation.

Instead of measuring whether we know someone by counting rows, we keep a bank of
questions about a person and measure how many we can answer.

Thirty-six drafted. And two separate numbers that must never be merged — coverage,
meaning can we answer it at all, and accuracy, meaning did they confirm it.
Coverage alone is what a dishonest system optimises.

To be completely clear, because the first draft was ambiguous: the system answers
these itself. It's an investigation the product runs. The user never sees the list
and is never asked to fill it in. Unanswered means we haven't figured it out yet,
not that we need to ask.

It does four jobs at once. It defines "confident enough to speak." It ranks the
connector backlog, because a source is worth exactly the questions it answers. It
gives hypothesis a real definition of critical mass. And the questions are the
test bank's expectations.

And it already corrected me on something.

Thirteen of the thirty-six need the person's own words. I'd been treating that as
meaning journals — things you have to persuade someone to write. That's wrong.
Words already exist in quantity. Sent mail is years of how someone actually talks.
Notion and documents are what they write while thinking. Public writing.
Onboarding answers.

Which re-ranks the connectors. I'd listed Gmail as a metadata source — who you
meet, how often. That badly undersells it. Google is three sources in one:
calendar for what you do, mail metadata for who with, and sent mail for how you
talk and what you care about. That last one is the expensive third of the question
list, the part I'd written off.

So Google is first, and not because it's partly built.

The two that stay genuinely hard for a silent user are how they're doing right
now, and what's weighing on them. Those need recent words. You pointed out we can
probably get those in the first conversation — and you're right, it's the strongest
argument for voice onboarding. The caveat is that it answers them as of day one,
and "right now" decays. By week six the onboarding answer is history, and lint
should treat it that way.

---

## Chapter ten — the psychology

You asked me to research what questions psychology says you need to understand
someone. I searched this rather than recalling it, because I've fabricated a
citation in this project before.

The finding reframes the approach.

Psychology has two kinds of instrument. Ones that ask — questionnaires, scales,
someone sitting down and rating things. And ones that code — systems for scoring
text a person already produced.

For an ambient product, the coding systems are worth far more, and they're the
part of this literature nobody in this space seems to use. You already have the
words. You don't want to interrogate anyone. The coding tradition was built
exactly for that — researchers scoring transcripts of people who'd already stopped
talking.

Which also answers your question underneath the question. You asked what we need
to ask. The better answer is: mostly nothing. We need to know what to look for in
what they already said.

Four things worth adopting.

McAdams' Life Story Interview. Think of your life as a book with chapters. Then a
high point, a low point, a turning point — and for each one, what happened, who
was there, what were you thinking, and why does it matter. Nobody's sitting for
two hours at onboarding, but those four probes are a near-perfect template for the
extractor, and three scene types organise a life better than a date range does.

Redemption and contamination coding. Whether someone's hard stories move toward
resolution or away from it. Applied to text, not asked. A study of a hundred and
twenty-one adults found redemption appears spontaneously in three quarters of
turning points — which means its absence is the signal. Someone whose low points
consistently stay low is telling you something real about how they're doing.

Agency and communion coding. Two numbers from text. Does this person narrate
themselves as in control or acted upon. As connected or alone.

And the Aspirations Index, from self-determination theory. Seven categories of
life goal — three extrinsic, wealth, fame, image; three intrinsic, relationships,
growth, contribution. Each rated three ways: how important it is, how likely you
think you are to get it, and how much you already have.

That triple is the stated-versus-real gap you're building around, already
formalised and validated. And the intrinsic-extrinsic split gives hypothesis
something it badly needs — a principled basis rather than a vibe. "You describe
growth as what matters and spend your time on image" is a framework-grounded
observation.

One more, from Emmons. He studied conflict between someone's own goals. That's
worth taking, because the thing impeding progress is often not a behaviour, it's
another goal. "You want to ship this and you want to be present at home, and those
are fighting" is a better impediment than "you skipped three Thursdays."

Now the part you asked for that I'm saying no to.

You asked for trauma. The literature's own position makes that a clear no, and the
sources are unusually direct about it.

The ACE questionnaire — the instrument you'd reach for — should not be
self-administered. Its own creator has said it was designed to research, not to
screen. Public health guidance states plainly that it cannot diagnose anything and
isn't predictive at the individual level. And it specifically names
self-administration as a potential harm — distressing, retraumatising,
stigmatising. One review notes the score inherently over- and underestimates
individual risk by construction. Another researcher argues screening is premature
without a clinical response available, which a phone app definitionally doesn't
have.

So the product never scores trauma. That's not me being cautious — it's the
instrument's authors and the bodies that publish it saying so.

But there's a responsible version of what you were reaching for. Contamination
sequences and low agency are validated, text-derived, non-diagnostic reads on
exactly that territory — someone for whom difficult things stay difficult, who
narrates themselves as powerless. The product can notice that, speak to it gently,
and never name a cause.

Noticing that someone's hard chapters don't resolve is observation. Naming why is
diagnosis. The line is clean, and this literature draws it in the same place I did.

One important caveat on all of that. Those coding systems were designed for
trained human raters with reliability checks. Whether a language model reproduces
their judgements on journal text is an open question, and it's the single most
important thing to test — because three of my strongest recommendations depend on
it.

---

## Chapter eleven — where I'd push back

Four things.

The daily brief. Stripped down, it's "read my saved links to me, nicely." That's a
real product people want, but the brain only contributes selection and framing. So
its defensibility rides entirely on choosing well — not on the audio. If the
picking isn't visibly smart, it's text-to-speech with extra steps.

Goal twenty-five and suggesting actions. You said once patterns are breaking, we
can start suggesting actions. That's the one part your own research measures as
ineffective. AI goal suggestions produced no measurable effect at five hundred and
forty-three people. AI-authored goals were more specific but less owned.
Implementation intentions work well — but only when the person forms them
themselves. So the version that works isn't "here's what to do," it's "you've
skipped three Thursdays, what would make next Thursday different" — and then
holding them to their own answer. The product supplies noticing, evidence and
accountability. The person supplies the action.

Goal nine, and this is the real one. You've asked for two things in the same
conversation. Emotionally soothing to speak with. And catch them on their
bullshit.

That's not a contradiction — it's a description of a good coach. It's also the
hardest thing in this product to get right, because the two fail in opposite
directions. Soothing alone is flattery. Blunt alone is a performance review nobody
opens twice.

What makes both possible: warmth in the delivery, precision in the content. The
softness goes in how it's said, never in what's claimed — because hedged content
delivered kindly is just vague. Evidence instead of judgement; "three Thursdays"
lands differently from "you're avoiding the gym," and it's the same observation.
Ask rather than tell, because a question can't condescend the way a verdict can.
And earn the right over time — bluntness that lands in month three is a betrayal in
week one.

And the fourth. You're designing from your own usage, and you're an outlier. You
said it yourself — aggressive power user. A normal user sends three links a week
and texts twice. You've already taken that note by making the product ambient, and
that was the right call. I'd just keep pushing it: design for the quiet person,
use your own volume as the stress test.

---

## Chapter twelve — what's still open

Four things block a goal from finishing.

The canonical questions themselves — which are missing, and which are off-limits.
I've flagged one for cutting: what someone consumes that they'd say they
shouldn't. It's answerable and it's unkind, and it's the question that makes a
product feel like it's watching.

Which frameworks are allowed, since hypothesis requires named ones.

Whether the coverage threshold is global or per domain. I recommend per domain.

And Composio or direct connectors. My recommendation is direct for Google,
Composio for the long tail — but one fact decides it, and I don't know it yet.
Whether Composio actually returns usable sent-mail bodies or only metadata. If
bodies, Composio gets much more attractive. If metadata only, it caps your best
source.

Three things get decided by testing rather than discussion. Hypothesis boldness.
Goal nine's balance. And what success for the beta actually means — you said that
one's yours to think about, and I've left it rather than guessing.

Two are deferred by choice. Goal seventeen's fork, act or prepare. And privacy
architecture and on-device, which you explicitly put later. Disclosure is not
later.

---

## Closing

That's all of it.

If the twenty-five goals have nothing missing, and the decisions log has nothing
wrong in it, the spec is finished and I can start.

The first thing I'd build is instrumentation — the cost meter, the drop rate, and
question coverage. It's small, maybe a day or two. But every decision after that
needs numbers, and right now there are none. The drop rate is computed and thrown
away. The meter is wrong three ways. Coverage doesn't exist yet.

After that, Google end to end, because ambient-by-default makes it the substrate
and it has never run.

Tell me what's wrong in here.
