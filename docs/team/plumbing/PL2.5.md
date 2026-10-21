### PL2.5 · Cached reads for goals, people and what Retro knows             size: S
Place in the tree: product › platform › repositories › CachedRead for goals, you
Repo · branch: NPRdoinglaundry · pl/PL2.5-cached-goals-you
Needs: PL2.4, contracts 04 and 05 merged      Unblocks: PL3.5, PL3.6

Why: your goals and what Retro understands about you open instantly, offline too, the same way the journal does.

Inputs: contract 04 (goals) and 05 (people, portrait, understanding) when written; PL2.4's `CachedRead`.

Spec:
- No new mechanism: one `CachedRead` per read endpoint those contracts define, with keys `goals`, `goals.<id>`, `people`, `portrait`, `understanding`, and max ages set in the contract review (default 5 min).
- Decoding models for each response, from the contract, in `Platform/Backend/Wire/<Contract>.swift`, each decoded from every fixture.
- Writes (a goal's yes / not quite, edits) are not here: they go through the outbox in PL3.5 / PL3.6 as new operations.

Steps: wire models → one `CachedRead` per endpoint → fixture tests.

Acceptance: each endpoint's cache behaves as PL2.4 specifies (same tests, parameterised by key).

Tests (layer 4 + 5): one decode test per fixture in `fixtures/04/` and `fixtures/05/`; PL2.4's behaviour suite run once per key (Swift Testing `arguments:`).

Proof in the PR: test output.

Watch out: the key list follows the contracts as planned; the integrator confirms it when 04 and 05 merge, and the byte doesn't start before then. Don't invent endpoints ahead of the contracts.
